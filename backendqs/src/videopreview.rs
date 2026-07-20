use sha2::{Digest, Sha256};
use std::collections::VecDeque;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::{Mutex, OnceLock};

const THUMB_SCALE: u32 = 480;
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
    cache_dir().join(format!("{hash}_vid_{modified}.jpg"))
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
    let out_str = out.to_string_lossy().to_string();
    let scale = THUMB_SCALE.to_string();

    // Try ffmpegthumbnailer first (blazingly fast, grabs frame at 10%)
    let status = Command::new("ffmpegthumbnailer")
        .args([
            "-i", source,
            "-o", &out_str,
            "-s", &scale,
            "-c", "jpeg",
            "-q", "7",
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    if let Ok(s) = status {
        if s.success() && out.exists() {
            return true;
        }
    }

    let _ = fs::remove_file(&out_str);

    // Fallback to ffmpeg
    let status = Command::new("ffmpeg")
        .args([
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", "00:00:02.000",
            "-i", source,
            "-vframes", "1",
            "-vf", &format!("scale=-1:{scale}"),
            "-q:v", "6",
            &out_str,
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    if let Ok(s) = status {
        if s.success() && out.exists() {
            return true;
        }
    }

    let _ = fs::remove_file(&out_str);

    // Fallback to ffmpeg at 00:00:00 (for very short videos)
    let status = Command::new("ffmpeg")
        .args([
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", "00:00:00.000",
            "-i", source,
            "-vframes", "1",
            "-vf", &format!("scale=-1:{scale}"),
            "-q:v", "6",
            &out_str,
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    if let Ok(s) = status {
        if s.success() && out.exists() {
            return true;
        }
    }

    let _ = fs::remove_file(&out_str);
    false
}

/// Return cached JPEG thumbnail path for a video.
/// Uses an in-memory LRU (24 entries) plus disk cache keyed by path hash + mtime.
pub fn thumbnail_path(source: &str, modified: u64, size: u64) -> Option<String> {
    if size == 0 {
        return None;
    }

    let mem_key = format!("vid:{source}:{modified}");

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
