use serde::Serialize;
use std::collections::BinaryHeap;
use std::cmp::Reverse;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use nucleo_matcher::{Matcher, Utf32String, pattern::{Pattern, CaseMatching, Normalization}};
use reqwest::Client;
use sha2::{Sha256, Digest};

#[derive(Clone)]
pub struct BookmarkEntry {
    pub name: String,
    pub name_utf32: Utf32String,
    pub url: String,
    pub icon_path: String,
}

#[derive(Serialize)]
pub struct BookmarkResult {
    pub name: String,
    pub url: String,
    pub icon_path: String,
    pub score: i32,
}

pub type BookmarkIndex = Arc<RwLock<Vec<BookmarkEntry>>>;

pub fn new_index() -> BookmarkIndex {
    Arc::new(RwLock::new(Vec::new()))
}

fn get_cache_dir() -> PathBuf {
    let mut path = PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/home".into()));
    path.push(".cache");
    path.push("quickshell");
    path.push("favicons");
    let _ = fs::create_dir_all(&path);
    path
}

fn safe_filename(domain: &str) -> String {
    domain.replace(|c: char| !c.is_ascii_alphanumeric() && c != '.' && c != '-', "_")
}

pub async fn build_index(client: Client, index: BookmarkIndex) {
    let mut path = PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/home".into()));
    path.push(".config/net.imput.helium/Default/Bookmarks");
    
    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to read bookmarks: {}", e);
            return;
        },
    };
    
    let parsed: serde_json::Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Failed to parse bookmarks: {}", e);
            return;
        },
    };
    
    eprintln!("Bookmarks loaded and parsed successfully.");
    
    let mut new_list = Vec::new();
    let cache_dir = get_cache_dir();
    
    fn extract(node: &serde_json::Value, list: &mut Vec<(String, String)>) {
        if let Some(t) = node.get("type").and_then(|v| v.as_str()) {
            if t == "url" {
                if let (Some(name), Some(url)) = (node.get("name").and_then(|v| v.as_str()), node.get("url").and_then(|v| v.as_str())) {
                    list.push((name.to_string(), url.to_string()));
                }
            } else if t == "folder" {
                if let Some(children) = node.get("children").and_then(|v| v.as_array()) {
                    for child in children {
                        extract(child, list);
                    }
                }
            }
        }
    }
    
    let mut raw_bookmarks = Vec::new();
    if let Some(roots) = parsed.get("roots") {
        if let Some(bar) = roots.get("bookmark_bar") { extract(bar, &mut raw_bookmarks); }
        if let Some(other) = roots.get("other") { extract(other, &mut raw_bookmarks); }
        if let Some(synced) = roots.get("synced") { extract(synced, &mut raw_bookmarks); }
    }
    
    for (name, url) in raw_bookmarks {
        let domain = match url.split('/').nth(2) {
            Some(d) => d.to_string(),
            None => continue,
        };
        
        let hash = safe_filename(&domain);
        let icon_path = cache_dir.join(format!("{}.png", hash));
        let icon_path_str = icon_path.to_string_lossy().to_string();
        
        if !icon_path.exists() {
            let dl_url = format!("https://icons.duckduckgo.com/ip3/{}.ico", domain);
            if let Ok(resp) = client.get(&dl_url).send().await {
                if let Ok(bytes) = resp.bytes().await {
                    let mut hasher = Sha256::new();
                    hasher.update(&bytes);
                    let result = hasher.finalize();
                    let hash = result.iter().map(|b| format!("{:02x}", b)).collect::<String>();
                    
                    // The standard DuckDuckGo fallback globe icon
                    if hash != "e5db88ea2322863ca17817b99d60006c625a31cff0dad49cf05d3c6d16a75c17" {
                        let _ = fs::write(&icon_path, bytes);
                    }
                }
            }
        }
        
        new_list.push(BookmarkEntry {
            name: name.clone(),
            name_utf32: Utf32String::from(name.as_str()),
            url,
            icon_path: icon_path_str,
        });
    }
    
    eprintln!("Bookmarks index built with {} entries", new_list.len());
    let mut idx = index.write().unwrap();
    *idx = new_list;
}

pub fn search(index: &BookmarkIndex, q: &str) -> Vec<BookmarkResult> {
    let q_trimmed = q.trim();
    if q_trimmed.is_empty() { return vec![]; }
    
    let data = index.read().unwrap();
    let mut matcher = Matcher::default();
    let pattern = Pattern::parse(q_trimmed, CaseMatching::Ignore, Normalization::Smart);
    
    let mut heap: BinaryHeap<Reverse<(u32, usize)>> = BinaryHeap::with_capacity(10);
    
    for (i, entry) in data.iter().enumerate() {
        let haystack = entry.name_utf32.slice(..);
        if let Some(score) = pattern.score(haystack, &mut matcher) {
            if heap.len() < 10 {
                heap.push(Reverse((score, i)));
            } else if let Some(Reverse((min_score, _))) = heap.peek() {
                if score > *min_score {
                    heap.pop();
                    heap.push(Reverse((score, i)));
                }
            }
        }
    }
    
    let mut top: Vec<(u32, usize)> = heap.into_iter().map(|Reverse(p)| p).collect();
    top.sort_unstable_by(|a, b| b.0.cmp(&a.0));
    
    top.into_iter().map(|(score, idx)| {
        let e = &data[idx];
        BookmarkResult {
            name: e.name.clone(),
            url: e.url.clone(),
            icon_path: e.icon_path.clone(),
            score: score as i32,
        }
    }).collect()
}
