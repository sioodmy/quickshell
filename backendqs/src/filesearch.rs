use serde::Serialize;
use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, RwLock};
use std::time::UNIX_EPOCH;
use ignore::WalkBuilder;
use notify::{Watcher, RecursiveMode, EventKind};
use nucleo_matcher::Utf32String;

const MAX_RESULTS: usize = 15;
const MAX_INDEX_ENTRIES: usize = 200_000;
const MAX_PREVIEW_BYTES: usize = 8192;
const MAX_PREVIEW_LINES: usize = 60;
const MAX_DEPTH: usize = 8;
/// Abort a superseded search after this many entries.
const CANCEL_CHECK_INTERVAL: usize = 4096;

#[derive(Clone)]
pub struct FileEntry {
    pub name: String,
    /// Presegmented basename for nucleo (avoids UTF-32 work per query).
    pub name_utf32: Utf32String,
    pub path: String,
    pub dir: String,
    pub size: u64,
    pub modified: u64,
    pub mime_cat: &'static str,
    pub ext: String,
}

#[derive(Serialize)]
pub struct FileResult {
    pub name: String,
    pub path: String,
    pub dir: String,
    pub size: u64,
    pub modified: u64,
    pub mime_cat: String,
    pub ext: String,
    pub score: i32,
}

#[derive(Serialize)]
pub struct PreviewResult {
    pub path: String,
    pub preview_type: String,
    pub preview_path: Option<String>,
    pub content: Option<String>,
    pub line_count: u32,
    pub size: u64,
    pub modified: u64,
    pub mime_cat: String,
}

pub struct FileIndexData {
    pub map: HashMap<String, FileEntry>,
    pub list: Vec<FileEntry>,
}

pub type FileIndex = Arc<RwLock<FileIndexData>>;

pub fn new_index() -> FileIndex {
    Arc::new(RwLock::new(FileIndexData {
        map: HashMap::new(),
        list: Vec::new(),
    }))
}

fn make_entry(path: &Path, home_path: &Path) -> Option<FileEntry> {
    if !path.is_file() { return None; }
    
    let name = path.file_name()?.to_str()?.to_string();
    if name.starts_with('.') { return None; }
    
    let path_str = path.to_str()?.to_string();
    let dir = path.parent()
        .and_then(|p| p.strip_prefix(home_path).ok())
        .map(|p| {
            let s = p.to_string_lossy();
            if s.is_empty() { "~".into() } else { format!("~/{s}") }
        })
        .unwrap_or_else(|| "~".into());

    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
    let meta = path.metadata().ok()?;
    let size = meta.len();
    let modified = meta.modified().ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let mime_cat = categorize_ext(&ext);
    if mime_cat == "audio" { return None; }
    let name_utf32 = Utf32String::from(name.as_str());

    Some(FileEntry {
        name, name_utf32, path: path_str, dir, size, modified, mime_cat, ext
    })
}

pub async fn build_index(index: FileIndex) {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home".into());
    let home_path = PathBuf::from(&home);
    
    let docs = home_path.join("Documents");
    let notes = home_path.join("Notes");
    let dls = home_path.join("Downloads");
    
    let mut dirs_to_watch = vec![];
    if docs.exists() { dirs_to_watch.push(docs.clone()); }
    if notes.exists() { dirs_to_watch.push(notes.clone()); }
    if dls.exists() { dirs_to_watch.push(dls.clone()); }

    let index_clone = index.clone();
    let hp_clone = home_path.clone();
    let d_watch = dirs_to_watch.clone();

    tokio::task::spawn_blocking(move || {
        let mut local_map = HashMap::with_capacity(50_000);
        let mut local_list = Vec::with_capacity(50_000);
        
        if let Some(first) = d_watch.first() {
            let mut builder = WalkBuilder::new(first);
            for d in d_watch.iter().skip(1) {
                builder.add(d);
            }
            builder.hidden(true).ignore(true).git_ignore(true).max_depth(Some(MAX_DEPTH));
            
            for result in builder.build() {
                if local_map.len() >= MAX_INDEX_ENTRIES { break; }
                if let Ok(entry) = result {
                    if let Some(f) = make_entry(entry.path(), &hp_clone) {
                        if !local_map.contains_key(&f.path) {
                            local_map.insert(f.path.clone(), f.clone());
                            local_list.push(f);
                        }
                    }
                }
            }
        }
        
        eprintln!("File index built: {} entries", local_map.len());
        
        let mut idx = index_clone.write().unwrap();
        idx.map = local_map;
        idx.list = local_list;
    }).await.unwrap();

    start_watcher(index, dirs_to_watch, home_path);
}

fn start_watcher(index: FileIndex, dirs: Vec<PathBuf>, home_path: PathBuf) {
    std::thread::spawn(move || {
        let (tx, rx) = std::sync::mpsc::channel();
        let mut watcher = match notify::recommended_watcher(tx) {
            Ok(w) => w,
            Err(_) => return,
        };
        
        for dir in dirs {
            let _ = watcher.watch(&dir, RecursiveMode::Recursive);
        }
        
        for res in rx {
            if let Ok(event) = res {
                let paths = event.paths;
                match event.kind {
                    EventKind::Create(_) | EventKind::Modify(_) => {
                        let mut idx = index.write().unwrap();
                        for p in paths {
                            if let Some(f) = make_entry(&p, &home_path) {
                                if !idx.map.contains_key(&f.path) {
                                    idx.list.push(f.clone());
                                } else {
                                    if let Some(pos) = idx.list.iter().position(|x| x.path == f.path) {
                                        idx.list[pos] = f.clone();
                                    }
                                }
                                idx.map.insert(f.path.clone(), f);
                            }
                        }
                    }
                    EventKind::Remove(_) => {
                        let mut idx = index.write().unwrap();
                        for p in paths {
                            let path_str = p.to_string_lossy().to_string();
                            if idx.map.remove(&path_str).is_some() {
                                idx.list.retain(|x| x.path != path_str);
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    });
}

/// Fuzzy-search the index. Returns `None` if this request was superseded by a newer query.
pub async fn search(
    index: &FileIndex,
    q: &str,
    frecency: Option<Arc<HashMap<String, f64>>>,
    generation: u64,
    current_generation: Arc<AtomicU64>,
) -> Option<Vec<FileResult>> {
    let q_trimmed = q.trim().to_string();
    if q_trimmed.len() < 2 {
        return Some(vec![]);
    }
    if current_generation.load(Ordering::Relaxed) != generation {
        return None;
    }

    let index = index.clone();

    tokio::task::spawn_blocking(move || {
        if current_generation.load(Ordering::Relaxed) != generation {
            return None;
        }

        let data = index.read().unwrap();
        if data.list.is_empty() {
            return Some(vec![]);
        }

        use nucleo_matcher::{
            pattern::{CaseMatching, Normalization, Pattern},
            Matcher,
        };
        let mut matcher = Matcher::default();
        let pattern = Pattern::parse(&q_trimmed, CaseMatching::Ignore, Normalization::Smart);

        // Min-heap of the top-K scores: peek is the smallest score currently kept.
        let mut heap: BinaryHeap<Reverse<(u32, usize)>> =
            BinaryHeap::with_capacity(MAX_RESULTS);

        for (i, entry) in data.list.iter().enumerate() {
            if i % CANCEL_CHECK_INTERVAL == 0
                && current_generation.load(Ordering::Relaxed) != generation
            {
                return None;
            }

            let haystack = entry.name_utf32.slice(..);
            let Some(mut score) = pattern.score(haystack, &mut matcher) else {
                continue;
            };

            if let Some(ref frec) = frecency {
                if let Some(boost) = frec.get(&entry.path) {
                    score = score.saturating_add((boost * 200.0) as u32);
                }
            }

            if heap.len() < MAX_RESULTS {
                heap.push(Reverse((score, i)));
            } else if let Some(Reverse((min_score, _))) = heap.peek() {
                if score > *min_score {
                    heap.pop();
                    heap.push(Reverse((score, i)));
                }
            }
        }

        if current_generation.load(Ordering::Relaxed) != generation {
            return None;
        }

        let mut top: Vec<(u32, usize)> = heap.into_iter().map(|Reverse(pair)| pair).collect();
        top.sort_unstable_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));

        let mut results = Vec::with_capacity(top.len());
        for (score, idx) in top {
            let e = &data.list[idx];
            results.push(FileResult {
                name: e.name.clone(),
                path: e.path.clone(),
                dir: e.dir.clone(),
                size: e.size,
                modified: e.modified,
                mime_cat: e.mime_cat.to_string(),
                ext: e.ext.clone(),
                score: score as i32,
            });
        }
        Some(results)
    })
    .await
    .ok()
    .flatten()
}


pub fn load_preview(path: &str) -> PreviewResult {
    let p = std::path::Path::new(path);
    let meta = std::fs::metadata(p).ok();
    let size = meta.as_ref().map(|m| m.len()).unwrap_or(0);
    let modified = meta.as_ref()
        .and_then(|m| m.modified().ok())
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let ext = p.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
    let cat = categorize_ext(&ext);

    // Images are previewed directly by QML; we just confirm the type
    if cat == "image" {
        return PreviewResult {
            path: path.into(), preview_type: "image".into(),
            preview_path: None, content: None, line_count: 0, size, modified, mime_cat: cat.into(),
        };
    }

    if cat == "pdf" {
        let preview_path = crate::pdfpreview::thumbnail_path(path, modified, size);
        return PreviewResult {
            path: path.into(), preview_type: "pdf".into(),
            preview_path, content: None, line_count: 0, size, modified, mime_cat: cat.into(),
        };
    }

    // Text-like files: read first N bytes
    if cat == "text" {
        if size > 5_000_000 {
            // Too large, don't preview content
            return PreviewResult {
                path: path.into(), preview_type: "text_too_large".into(),
                preview_path: None, content: None, line_count: 0, size, modified, mime_cat: cat.into(),
            };
        }
        match std::fs::read(p) {
            Ok(bytes) => {
                let read_len = bytes.len().min(MAX_PREVIEW_BYTES);
                let slice = &bytes[..read_len];

                // Quick binary check: if >10% non-text bytes in first 512, treat as binary
                let check_len = slice.len().min(512);
                let non_text = slice[..check_len].iter()
                    .filter(|&&b| b < 0x09 || (b > 0x0d && b < 0x20 && b != 0x1b))
                    .count();
                if non_text > check_len / 10 {
                    return PreviewResult {
                        path: path.into(), preview_type: "binary".into(),
                        preview_path: None, content: None, line_count: 0, size, modified, mime_cat: cat.into(),
                    };
                }

                let text = String::from_utf8_lossy(slice);
                let lines: Vec<&str> = text.lines().take(MAX_PREVIEW_LINES).collect();
                let line_count = lines.len() as u32;
                let content = lines.join("\n");

                return PreviewResult {
                    path: path.into(), preview_type: "text".into(),
                    preview_path: None, content: Some(content), line_count, size, modified, mime_cat: cat.into(),
                };
            }
            Err(_) => {}
        }
    }

    PreviewResult {
        path: path.into(), preview_type: "none".into(),
        preview_path: None, content: None, line_count: 0, size, modified, mime_cat: cat.into(),
    }
}


// ── Extension → category mapping ──

fn categorize_ext(ext: &str) -> &'static str {
    match ext {
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "svg" | "bmp" | "ico"
        | "tiff" | "tif" | "avif" | "heic" | "heif" => "image",

        "mp4" | "mkv" | "avi" | "mov" | "wmv" | "flv" | "webm"
        | "m4v" | "ogv" => "video",

        "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus"
        | "wma" | "ape" | "alac" => "audio",

        "pdf" => "pdf",

        "zip" | "tar" | "gz" | "bz2" | "xz" | "7z" | "rar" | "zst"
        | "lz4" | "lzma" | "deb" | "rpm" => "archive",

        "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx"
        | "odt" | "ods" | "odp" | "rtf" => "document",

        "txt" | "md" | "rst" | "org" | "log" | "csv" | "tsv"
        | "json" | "yaml" | "yml" | "toml" | "xml" | "html" | "htm"
        | "css" | "scss" | "less" | "js" | "ts" | "jsx" | "tsx" | "mjs"
        | "py" | "rs" | "go" | "java" | "c" | "cpp" | "h" | "hpp"
        | "cs" | "rb" | "php" | "sh" | "bash" | "zsh" | "fish"
        | "lua" | "vim" | "el" | "clj" | "hs" | "ml" | "ex" | "exs"
        | "erl" | "scala" | "kt" | "swift" | "r" | "sql" | "graphql"
        | "nix" | "conf" | "ini" | "cfg" | "env" | "qml" | "qss"
        | "diff" | "patch" | "lock" | "cmake" | "make" | "makefile"
        | "dockerfile" | "gitignore" | "editorconfig" | "tf" | "hcl"
        | "svelte" | "vue" | "astro" | "mdx" | "tex" | "bib"
        | "service" | "desktop" | "rules" => "text",

        _ => "other",
    }
}

// ── Human-readable file size ──

pub fn format_size(bytes: u64) -> String {
    if bytes < 1024 { return format!("{bytes} B"); }
    let kb = bytes as f64 / 1024.0;
    if kb < 1024.0 { return format!("{kb:.1} KB"); }
    let mb = kb / 1024.0;
    if mb < 1024.0 { return format!("{mb:.1} MB"); }
    let gb = mb / 1024.0;
    format!("{gb:.2} GB")
}
