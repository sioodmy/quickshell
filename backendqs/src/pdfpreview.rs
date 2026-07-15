use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::{Mutex, OnceLock};

const MAX_PDF_BYTES: u64 = 80 * 1024 * 1024;
const THUMB_SCALE: u32 = 480;
const JPEG_QUALITY: u8 = 72;
const MEMORY_CACHE_CAP: usize = 24;

struct MemEntry {
    key: String,
    path: String,
}

static MEM_CACHE: OnceLock<Mutex<VecDeque<MemEntry>>> = OnceLock::new();

fn mem_cache() -> &'static Mutex<VecDeque<MemEntry>> {
    MEM_CACHE.get_or_init(|| Mutex::new(VecDeque::with_capacity(MEMORY_CACHE_CAP)))
}

fn cache_dir() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(home).join(".cache/quickshell/previews")
}

fn disk_cache_path(source: &str, modified: u64) -> PathBuf {
    let mut hasher = Sha256::new();
    hasher.update(source.as_bytes());
    let hash: String = hasher.finalize()[..8]
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect();
    cache_dir().join(format!("{hash}_{modified}.jpg"))
}

fn lookup_mem(key: &str) -> Option<String> {
    let mut cache = mem_cache().lock().ok()?;
    let pos = cache.iter().position(|e| e.key == key)?;
    let entry = cache.remove(pos)?;
    let path = entry.path.clone();
    cache.push_front(MemEntry {
        key: key.to_string(),
        path: path.clone(),
    });
    Some(path)
}

fn store_mem(key: String, path: String) {
    if let Ok(mut cache) = mem_cache().lock() {
        if let Some(pos) = cache.iter().position(|e| e.key == key) {
            cache.remove(pos);
        }
        cache.push_front(MemEntry {
            key,
            path: path.clone(),
        });
        while cache.len() > MEMORY_CACHE_CAP {
            cache.pop_back();
        }
    }
}

fn render_thumbnail(source: &str, out: &PathBuf) -> bool {
    let tmp_stem = out.with_extension("");
    let tmp_stem_str = tmp_stem.to_string_lossy().to_string();

    let quality = JPEG_QUALITY.to_string();
    let scale = THUMB_SCALE.to_string();

    let status = match Command::new("pdftocairo")
        .args([
            "-jpeg",
            "-jpegopt",
            &format!("quality={quality}"),
            "-f",
            "1",
            "-l",
            "1",
            "-scale-to",
            &scale,
            "-singlefile",
            source,
            &tmp_stem_str,
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
    {
        Ok(s) => s,
        Err(_) => return false,
    };

    if !status.success() {
        let _ = fs::remove_file(format!("{tmp_stem_str}.jpg"));
        return false;
    }

    let rendered = format!("{tmp_stem_str}.jpg");
    if fs::rename(&rendered, out).is_err() {
        if fs::copy(&rendered, out).is_err() {
            let _ = fs::remove_file(&rendered);
            return false;
        }
        let _ = fs::remove_file(&rendered);
    }

    out.exists()
}

/// Return cached JPEG thumbnail path for the first page of a PDF.
/// Uses an in-memory LRU (24 entries) plus disk cache keyed by path hash + mtime.
pub fn thumbnail_path(source: &str, modified: u64, size: u64) -> Option<String> {
    if size == 0 || size > MAX_PDF_BYTES {
        return None;
    }

    let mem_key = format!("{source}:{modified}");

    if let Some(path) = lookup_mem(&mem_key) {
        if std::path::Path::new(&path).is_file() {
            return Some(path);
        }
    }

    let out = disk_cache_path(source, modified);
    if out.is_file() {
        let path_str = out.to_string_lossy().to_string();
        store_mem(mem_key, path_str.clone());
        return Some(path_str);
    }

    if fs::create_dir_all(cache_dir()).is_err() {
        return None;
    }

    if !render_thumbnail(source, &out) {
        return None;
    }

    let path_str = out.to_string_lossy().to_string();
    store_mem(mem_key, path_str.clone());
    Some(path_str)
}
