use anyhow::Result;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex, OnceLock};

/// Where decoded clipboard images are cached for previews / copying.
pub const THUMB_DIR: &str = "/tmp/quickshell-clip-thumbs";

/// A single clipboard history entry as consumed by the QML launcher view.
#[derive(Serialize, Clone, Debug)]
pub struct ClipItem {
    /// cliphist numeric id (first column of `cliphist list`).
    pub id: String,
    /// Full `id\tpreview` line, required by `cliphist decode`/`delete`.
    pub raw: String,
    /// "text" | "image".
    pub kind: String,
    /// Human readable title (text content, or "Image").
    pub display: String,
    /// Secondary line (image dimensions/size, or OCR snippet).
    pub subtitle: String,
    /// Decoded image path on disk (images only, else empty).
    pub image_path: String,
    pub width: u32,
    pub height: u32,
    /// Text extracted from an image via OCR (empty until OCR completes).
    pub ocr_text: String,
    /// True once OCR has been attempted (or the entry is plain text).
    pub ocr_done: bool,
    /// Lowercased text used by the launcher fuzzy matcher.
    pub search_text: String,
}

/// A queued OCR job produced while listing history.
#[derive(Clone, Debug)]
pub struct OcrJob {
    pub id: String,
    pub hash: String,
    pub image_path: String,
}

pub struct CliphistState {
    /// content-hash -> extracted OCR text (persisted across sessions).
    ocr_cache: HashMap<String, String>,
    /// hashes with an OCR pass currently in flight (dedup guard).
    in_progress: HashSet<String>,
}

pub type SharedState = Arc<Mutex<CliphistState>>;

pub fn new_state() -> SharedState {
    Arc::new(Mutex::new(CliphistState {
        ocr_cache: load_cache(),
        in_progress: HashSet::new(),
    }))
}

// ─────────────────────────────────────────────────────────────
//  Persistent OCR cache
// ─────────────────────────────────────────────────────────────
fn cache_path() -> PathBuf {
    let base = std::env::var("XDG_CACHE_HOME")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".cache")
        });
    base.join("quickshell").join("cliphist_ocr.json")
}

fn load_cache() -> HashMap<String, String> {
    fs::read_to_string(cache_path())
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

fn save_cache(cache: &HashMap<String, String>) {
    let path = cache_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string(cache) {
        let _ = fs::write(path, json);
    }
}

// ─────────────────────────────────────────────────────────────
//  tesseract availability (probed once, lazily)
// ─────────────────────────────────────────────────────────────
static TESSERACT_OK: OnceLock<bool> = OnceLock::new();

fn tesseract_available() -> bool {
    *TESSERACT_OK.get_or_init(|| {
        Command::new("tesseract")
            .arg("--version")
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    })
}

// ─────────────────────────────────────────────────────────────
//  History listing (+ image decoding + OCR job discovery)
// ─────────────────────────────────────────────────────────────

/// Runs `cliphist list`, decodes image entries into the thumbnail cache and
/// returns the parsed items alongside any OCR jobs that still need running.
///
/// This is blocking (spawns `cliphist`, hashes files) and should be called
/// from `spawn_blocking`.
pub fn get_history(state: &SharedState) -> Result<(Vec<ClipItem>, Vec<OcrJob>)> {
    let _ = fs::create_dir_all(THUMB_DIR);

    let output = Command::new("cliphist")
        .arg("list")
        .stderr(Stdio::null())
        .output()?;
    let listing = String::from_utf8_lossy(&output.stdout);

    let mut items = Vec::new();
    let mut jobs = Vec::new();
    let ocr_enabled = tesseract_available();

    for line in listing.lines() {
        if line.is_empty() {
            continue;
        }
        let (id, preview) = match line.split_once('\t') {
            Some(pair) => pair,
            None => continue,
        };
        let id = id.trim();
        if id.is_empty() {
            continue;
        }

        let ext = image_ext(preview);
        let is_image = is_binary_preview(preview) && ext.is_some();

        if is_image {
            let ext = ext.unwrap();
            let file = format!("{THUMB_DIR}/{id}.{ext}");
            let path = Path::new(&file);

            // Decode lazily: reuse the cached file when it already exists.
            let needs_decode = fs::metadata(path).map(|m| m.len() == 0).unwrap_or(true);
            if needs_decode {
                if let Err(e) = decode_entry(line, path) {
                    eprintln!("cliphist: decode failed for {id}: {e}");
                    continue;
                }
            }

            let bytes = fs::read(path).unwrap_or_default();
            if bytes.is_empty() {
                continue;
            }
            // Prefer the dimensions cliphist already reports; only fall back to a
            // cheap header-only read (never a full decode) when they're missing.
            let (width, height) = {
                let (pw, ph) = dims_from_preview(preview);
                if pw > 0 && ph > 0 {
                    (pw, ph)
                } else {
                    image::image_dimensions(path).unwrap_or((0, 0))
                }
            };

            let hash = hash_bytes(&bytes);
            let (ocr_text, ocr_done) = {
                let mut st = state.lock().unwrap();
                match st.ocr_cache.get(&hash) {
                    Some(text) => (text.clone(), true),
                    None => {
                        // Queue an OCR pass unless one is already running.
                        if ocr_enabled && st.in_progress.insert(hash.clone()) {
                            jobs.push(OcrJob {
                                id: id.to_string(),
                                hash: hash.clone(),
                                image_path: file.clone(),
                            });
                        }
                        (String::new(), false)
                    }
                }
            };

            let subtitle = build_image_subtitle(width, height, bytes.len() as u64);

            items.push(ClipItem {
                id: id.to_string(),
                raw: line.to_string(),
                kind: "image".into(),
                display: "Image".into(),
                subtitle,
                image_path: file,
                width,
                height,
                search_text: ocr_text.to_lowercase(),
                ocr_text,
                ocr_done,
            });
        } else {
            let display = preview.trim().to_string();
            items.push(ClipItem {
                id: id.to_string(),
                raw: line.to_string(),
                kind: "text".into(),
                search_text: display.to_lowercase(),
                display: display.clone(),
                subtitle: String::new(),
                image_path: String::new(),
                width: 0,
                height: 0,
                ocr_text: String::new(),
                ocr_done: true,
            });
        }
    }

    Ok((items, jobs))
}

/// Runs tesseract against a decoded image. Blocking; returns the recognised
/// text (possibly empty) or `None` when tesseract failed to run.
pub fn run_ocr(image_path: &str) -> Option<String> {
    let output = Command::new("tesseract")
        .arg(image_path)
        .arg("stdout")
        .arg("-l")
        .arg("eng")
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout);
    // Collapse the noisy whitespace tesseract emits into single spaces so the
    // fuzzy matcher sees a clean, single-line blob.
    let cleaned = text
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    Some(cleaned)
}

/// Stores an OCR result in the persistent cache and clears the in-flight flag.
pub fn store_ocr(state: &SharedState, hash: &str, text: &str) {
    let mut st = state.lock().unwrap();
    st.in_progress.remove(hash);
    st.ocr_cache.insert(hash.to_string(), text.to_string());
    save_cache(&st.ocr_cache);
}

/// Releases an in-flight OCR slot without caching (used when tesseract failed),
/// so the entry can be retried on a later open.
pub fn clear_in_progress(state: &SharedState, hash: &str) {
    state.lock().unwrap().in_progress.remove(hash);
}

// ─────────────────────────────────────────────────────────────
//  Mutations
// ─────────────────────────────────────────────────────────────

/// Copies an entry to the Wayland clipboard. Images are copied straight from
/// the decoded file with the right MIME type; text is re-decoded via cliphist.
pub fn copy_item(raw: &str, image_path: &str) -> Result<()> {
    if !image_path.is_empty() {
        if let Ok(meta) = fs::metadata(image_path) {
            if meta.len() > 0 {
                let mime = mime_for_path(image_path);
                let bytes = fs::read(image_path)?;
                let mut child = Command::new("wl-copy")
                    .arg("--type")
                    .arg(mime)
                    .stdin(Stdio::piped())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn()?;
                if let Some(mut stdin) = child.stdin.take() {
                    stdin.write_all(&bytes)?;
                }
                // wl-copy daemonises itself; don't wait for it.
                return Ok(());
            }
        }
    }

    // Text path: cliphist decode <raw>  |  wl-copy
    let mut decode = Command::new("cliphist")
        .arg("decode")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;
    {
        let mut stdin = decode.stdin.take().unwrap();
        stdin.write_all(raw.as_bytes())?;
    }
    let decoded = decode.wait_with_output()?;

    let mut copy = Command::new("wl-copy")
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    if let Some(mut stdin) = copy.stdin.take() {
        stdin.write_all(&decoded.stdout)?;
    }
    Ok(())
}

/// Deletes a single entry from cliphist history.
pub fn delete_item(raw: &str) -> Result<()> {
    let mut child = Command::new("cliphist")
        .arg("delete")
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    {
        let mut stdin = child.stdin.take().unwrap();
        stdin.write_all(raw.as_bytes())?;
    }
    child.wait()?;
    Ok(())
}

/// Wipes the whole history and the decoded-thumbnail cache.
pub fn wipe() -> Result<()> {
    let _ = Command::new("cliphist")
        .arg("wipe")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
    let _ = fs::remove_dir_all(THUMB_DIR);
    Ok(())
}

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
fn decode_entry(raw: &str, path: &Path) -> Result<()> {
    let mut child = Command::new("cliphist")
        .arg("decode")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;
    {
        let mut stdin = child.stdin.take().unwrap();
        stdin.write_all(raw.as_bytes())?;
    }
    let output = child.wait_with_output()?;
    fs::write(path, &output.stdout)?;
    Ok(())
}

fn hash_bytes(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    hasher.finalize().iter().map(|b| format!("{:02x}", b)).collect()
}

fn is_binary_preview(preview: &str) -> bool {
    let p = preview.trim_start();
    p.starts_with("[[ binary data") || p.starts_with("[[binary data")
}

fn image_ext(preview: &str) -> Option<&'static str> {
    if !is_binary_preview(preview) {
        return None;
    }
    let p = preview.to_lowercase();
    if p.contains("jpeg") || p.contains("jpg") {
        Some("jpg")
    } else if p.contains("png") {
        Some("png")
    } else if p.contains("gif") {
        Some("gif")
    } else if p.contains("bmp") {
        Some("bmp")
    } else if p.contains("webp") {
        Some("webp")
    } else {
        None
    }
}

fn dims_from_preview(preview: &str) -> (u32, u32) {
    // e.g. "[[ binary data 211 KiB png 2560x1600 ]]"
    for token in preview.split_whitespace() {
        if let Some((w, h)) = token.split_once('x') {
            if let (Ok(w), Ok(h)) = (w.parse::<u32>(), h.parse::<u32>()) {
                return (w, h);
            }
        }
    }
    (0, 0)
}

fn mime_for_path(path: &str) -> &'static str {
    match path.rsplit('.').next().unwrap_or("").to_lowercase().as_str() {
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "bmp" => "image/bmp",
        "webp" => "image/webp",
        _ => "image/png",
    }
}

fn human_size(bytes: u64) -> String {
    const UNITS: [&str; 4] = ["B", "KiB", "MiB", "GiB"];
    let mut value = bytes as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{bytes} B")
    } else {
        format!("{value:.1} {}", UNITS[unit])
    }
}

fn build_image_subtitle(width: u32, height: u32, size: u64) -> String {
    let mut parts: Vec<String> = Vec::new();
    if width > 0 && height > 0 {
        parts.push(format!("{width}×{height}"));
    }
    if size > 0 {
        parts.push(human_size(size));
    }
    if parts.is_empty() {
        "Image".into()
    } else {
        parts.join("  ·  ")
    }
}
