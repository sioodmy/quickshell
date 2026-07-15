use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

const LAMBDA: f64 = 0.95;
const MAX_TIMESTAMPS: usize = 50;
const MIN_QUICKKEY_LENGTH: usize = 2;
const STALE_DAYS: u64 = 90;

#[derive(Serialize, Deserialize, Default, Clone)]
pub struct AppEntry {
    pub launches: Vec<u64>,
    #[serde(rename = "totalLaunches")]
    pub total_launches: u64,
}

#[derive(Serialize, Deserialize, Default, Clone)]
pub struct FrecencyData {
    #[serde(default)]
    pub apps: HashMap<String, AppEntry>,
    #[serde(default)]
    pub quickkeys: HashMap<String, HashMap<String, AppEntry>>,
}

#[derive(Serialize, Default, Clone)]
pub struct FrecencyScores {
    pub apps: HashMap<String, f64>,
    pub quickkeys: HashMap<String, Vec<QuickkeyScore>>,
}

#[derive(Serialize, Clone)]
pub struct QuickkeyScore {
    pub id: String,
    pub score: f64,
}

pub fn compute_frecency_score(launches: &[u64], now: u64) -> f64 {
    let mut score = 0.0;
    for &ts in launches {
        let age_days = (now.saturating_sub(ts)) as f64 / 86_400_000.0;
        score += LAMBDA.powf(age_days.max(0.0));
    }
    score
}

pub fn check_exists(id: &str) -> bool {
    if id.starts_with('/') || id.starts_with('~') {
        let expanded = if id.starts_with('~') {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/home".into());
            id.replacen('~', &home, 1)
        } else {
            id.to_string()
        };
        std::path::Path::new(&expanded).exists()
    } else {
        true
    }
}

pub fn get_scores(data: &FrecencyData) -> FrecencyScores {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
    let mut apps = HashMap::new();
    for (id, entry) in &data.apps {
        if !check_exists(id) { continue; }
        apps.insert(id.clone(), compute_frecency_score(&entry.launches, now));
    }

    let mut quickkeys = HashMap::new();
    for (query, mapping) in &data.quickkeys {
        let mut scores = Vec::new();
        for (id, entry) in mapping {
            if !check_exists(id) { continue; }
            let score = compute_frecency_score(&entry.launches, now);
            if score > 0.1 {
                scores.push(QuickkeyScore { id: id.clone(), score });
            }
        }
        scores.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
        if !scores.is_empty() {
            quickkeys.insert(query.clone(), scores);
        }
    }

    FrecencyScores { apps, quickkeys }
}

pub fn record_launch(data: &mut FrecencyData, id: &str, query: Option<&str>) {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
    
    let app_entry = data.apps.entry(id.to_string()).or_insert_with(AppEntry::default);
    app_entry.launches.push(now);
    app_entry.total_launches += 1;
    if app_entry.launches.len() > MAX_TIMESTAMPS {
        let skip = app_entry.launches.len() - MAX_TIMESTAMPS;
        app_entry.launches = app_entry.launches.clone().into_iter().skip(skip).collect();
    }

    if let Some(q) = query {
        let q = q.trim().to_lowercase();
        if q.len() >= MIN_QUICKKEY_LENGTH {
            let qk_entry = data.quickkeys
                .entry(q)
                .or_insert_with(HashMap::new)
                .entry(id.to_string())
                .or_insert_with(AppEntry::default);
            qk_entry.launches.push(now);
            qk_entry.total_launches += 1;
            if qk_entry.launches.len() > MAX_TIMESTAMPS {
                let skip = qk_entry.launches.len() - MAX_TIMESTAMPS;
                qk_entry.launches = qk_entry.launches.clone().into_iter().skip(skip).collect();
            }
        }
    }
}

pub fn prune_stale_data(data: &mut FrecencyData) {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
    let cutoff = now.saturating_sub(STALE_DAYS * 86_400_000);

    data.apps.retain(|id, entry| {
        if !check_exists(id) { return false; }
        entry.launches.retain(|&ts| ts > cutoff);
        !entry.launches.is_empty()
    });

    data.quickkeys.retain(|_, mapping| {
        mapping.retain(|id, entry| {
            if !check_exists(id) { return false; }
            entry.launches.retain(|&ts| ts > cutoff);
            !entry.launches.is_empty()
        });
        !mapping.is_empty()
    });
}

fn get_frecency_path() -> PathBuf {
    let mut path = std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));
    path.push(".local");
    path.push("state");
    path.push("quickshell");
    path.push("frecency.json");
    path
}

fn get_old_frequencies_path() -> PathBuf {
    let mut path = std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("."));
    path.push(".cache");
    path.push("quickshell");
    path.push("app_frequencies.json");
    path
}

pub fn load_or_migrate() -> FrecencyData {
    let path = get_frecency_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(data) = serde_json::from_str::<FrecencyData>(&content) {
            return data;
        }
    }

    // Try migration
    let old_path = get_old_frequencies_path();
    let mut data = FrecencyData::default();
    if let Ok(content) = fs::read_to_string(&old_path) {
        if let Ok(old_freqs) = serde_json::from_str::<HashMap<String, u64>>(&content) {
            let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64;
            for (id, count) in old_freqs {
                if count > 0 {
                    let mut launches = Vec::new();
                    let synth_count = count.min(MAX_TIMESTAMPS as u64);
                    for j in 0..synth_count {
                        let age_ms = (7 * 86_400_000) * j / synth_count;
                        launches.push(now.saturating_sub(age_ms));
                    }
                    data.apps.insert(id, AppEntry { launches, total_launches: count });
                }
            }
        }
    }
    data
}

pub fn save(data: &FrecencyData) {
    let path = get_frecency_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(data) {
        let _ = fs::write(path, json);
    }
}
