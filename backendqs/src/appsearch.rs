use nucleo_matcher::{
    pattern::{CaseMatching, Normalization, Pattern},
    Matcher, Utf32String,
};
use serde::Serialize;
use std::cmp::Reverse;
use std::collections::{BinaryHeap, HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

#[derive(Clone, Debug)]
pub struct AppEntry {
    pub id: String,         // e.g. "kitty.desktop"
    pub stem_id: String,    // e.g. "kitty"
    pub name: String,
    pub name_utf32: Utf32String,
    pub search_text_utf32: Utf32String,
}

#[derive(Serialize, Clone, Debug)]
pub struct AppSearchResult {
    pub id: String,
    pub name: String,
    pub score: i32,
}

pub type AppIndex = Arc<RwLock<Vec<AppEntry>>>;

pub fn new_index() -> AppIndex {
    Arc::new(RwLock::new(Vec::new()))
}

fn get_app_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();

    if let Ok(home) = std::env::var("HOME") {
        dirs.push(PathBuf::from(&home).join(".local/share/applications"));
        dirs.push(PathBuf::from(&home).join(".nix-profile/share/applications"));
    }

    dirs.push(PathBuf::from("/run/current-system/sw/share/applications"));

    if let Ok(xdg_data_dirs) = std::env::var("XDG_DATA_DIRS") {
        for part in xdg_data_dirs.split(':') {
            if !part.trim().is_empty() {
                dirs.push(PathBuf::from(part).join("applications"));
            }
        }
    }

    dirs.push(PathBuf::from("/usr/share/applications"));
    dirs.push(PathBuf::from("/usr/local/share/applications"));

    dirs
}

fn parse_desktop_file(path: &Path) -> Option<AppEntry> {
    let filename = path.file_name()?.to_str()?;
    if !filename.ends_with(".desktop") {
        return None;
    }

    let stem_id = filename.trim_end_matches(".desktop").to_string();
    let id = filename.to_string();

    let content = fs::read_to_string(path).ok()?;
    let mut in_desktop_entry = false;
    let mut name = String::new();
    let mut generic_name = String::new();
    let mut comment = String::new();
    let mut keywords = String::new();
    let mut no_display = false;
    let mut is_application = true;

    for line in content.lines() {
        let line = line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_desktop_entry {
            continue;
        }

        if let Some((key, val)) = line.split_once('=') {
            let key = key.trim();
            let val = val.trim();
            match key {
                "Type" => {
                    if val != "Application" {
                        is_application = false;
                    }
                }
                "NoDisplay" => {
                    if val.eq_ignore_ascii_case("true") {
                        no_display = true;
                    }
                }
                "Name" if name.is_empty() => {
                    name = val.to_string();
                }
                "GenericName" if generic_name.is_empty() => {
                    generic_name = val.to_string();
                }
                "Comment" if comment.is_empty() => {
                    comment = val.to_string();
                }
                "Keywords" if keywords.is_empty() => {
                    keywords = val.to_string();
                }
                _ => {}
            }
        }
    }

    if !is_application || no_display || name.is_empty() {
        return None;
    }

    let search_text = format!("{} {} {} {}", name, generic_name, comment, keywords);
    Some(AppEntry {
        name_utf32: Utf32String::from(name.as_str()),
        search_text_utf32: Utf32String::from(search_text.as_str()),
        id,
        stem_id,
        name,
    })
}

pub async fn build_index(index: AppIndex) {
    tokio::task::spawn_blocking(move || {
        let mut entries = Vec::new();
        let mut seen_ids = HashSet::new();

        for dir in get_app_dirs() {
            if let Ok(read_dir) = fs::read_dir(dir) {
                for item in read_dir.flatten() {
                    let path = item.path();
                    if path.is_file() {
                        if let Some(entry) = parse_desktop_file(&path) {
                            if seen_ids.insert(entry.id.clone()) {
                                entries.push(entry);
                            }
                        }
                    }
                }
            }
        }

        crate::debug_log!("App index built with {} entries", entries.len());
        if let Ok(mut lock) = index.write() {
            *lock = entries;
        }
    })
    .await
    .ok();
}

pub fn search(
    index: &AppIndex,
    query: &str,
    app_scores: Option<Arc<HashMap<String, f64>>>,
    limit: usize,
) -> Vec<AppSearchResult> {
    let q_trimmed = query.trim();
    if q_trimmed.is_empty() {
        return vec![];
    }

    let data = match index.read() {
        Ok(d) => d,
        Err(_) => return vec![],
    };

    let mut matcher = Matcher::default();
    let pattern = Pattern::parse(q_trimmed, CaseMatching::Ignore, Normalization::Smart);

    let mut heap: BinaryHeap<Reverse<(i64, usize)>> = BinaryHeap::with_capacity(limit);

    for (i, entry) in data.iter().enumerate() {
        let name_score = pattern.score(entry.name_utf32.slice(..), &mut matcher);
        let text_score = pattern.score(entry.search_text_utf32.slice(..), &mut matcher);

        let best_raw = match (name_score, text_score) {
            (Some(n), Some(t)) => (n as i64).max((t as i64).saturating_sub(50)),
            (Some(n), None) => n as i64,
            (None, Some(t)) => (t as i64).saturating_sub(50),
            (None, None) => continue,
        };

        let frecency_boost = if let Some(ref scores) = app_scores {
            let f = scores
                .get(&entry.id)
                .or_else(|| scores.get(&entry.stem_id))
                .copied()
                .unwrap_or(0.0);
            (f * 10.0) as i64
        } else {
            0
        };

        let total_score = best_raw + frecency_boost;

        if heap.len() < limit {
            heap.push(Reverse((total_score, i)));
        } else if let Some(Reverse((min_score, _))) = heap.peek() {
            if total_score > *min_score {
                heap.pop();
                heap.push(Reverse((total_score, i)));
            }
        }
    }

    let mut top: Vec<(i64, usize)> = heap.into_iter().map(|Reverse(p)| p).collect();
    top.sort_unstable_by(|a, b| b.0.cmp(&a.0));

    top.into_iter()
        .map(|(score, idx)| {
            let e = &data[idx];
            AppSearchResult {
                id: e.id.clone(),
                name: e.name.clone(),
                score: score as i32,
            }
        })
        .collect()
}
