use anyhow::Result;
use reqwest::Client;
use std::fs;
use std::path::PathBuf;

fn convert_yaml_lyrics(yaml: &str) -> String {
    let mut lrc = String::new();
    let mut current_time = None;
    for line in yaml.lines() {
        let line = line.trim();
        if let Some(t_str) = line.strip_prefix("- time: ") {
            if let Ok(t_sec) = t_str.parse::<f64>() {
                let min = (t_sec / 60.0).floor() as u32;
                let sec = t_sec % 60.0;
                current_time = Some(format!("{:02}:{:05.2}", min, sec));
            }
        } else if let Some(text_str) = line.strip_prefix("text: ") {
            let mut t = text_str.trim();
            if t.starts_with('\'') && t.ends_with('\'') {
                t = &t[1..t.len()-1];
            } else if t.starts_with('"') && t.ends_with('"') {
                t = &t[1..t.len()-1];
            }
            if let Some(time) = current_time.take() {
                lrc.push_str(&format!("[{}] {}\n", time, t));
            }
        }
    }
    lrc
}

pub async fn fetch_lyrics(client: &Client, artist: &str, title: &str) -> Result<String> {
    if let Ok(conn) = crate::music::get_db_connection() {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/sioodmy".to_string());
        let music_dir = std::path::Path::new(&home).join("Music");
        
        if let Ok(mut stmt) = conn.prepare("
            SELECT tracks.lyrics_path 
            FROM tracks 
            JOIN albums ON tracks.album_id = albums.id 
            JOIN artists ON albums.artist_id = artists.id 
            WHERE tracks.title = ?1 AND artists.name = ?2
        ") {
            if let Ok(mut rows) = stmt.query(rusqlite::params![title, artist]) {
                if let Ok(Some(row)) = rows.next() {
                    let lyrics_path: Option<String> = row.get(0).unwrap_or(None);
                    if let Some(lp) = lyrics_path {
                        let abs_lp = music_dir.join(lp);
                        if let Ok(content) = fs::read_to_string(&abs_lp) {
                            return Ok(convert_yaml_lyrics(&content));
                        }
                    }
                }
            }
        }
    }

    let cache_dir = std::env::var("HOME").map(|h| PathBuf::from(h).join(".cache").join("quickshell").join("lyrics"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/quickshell_lyrics"));
    let _ = fs::create_dir_all(&cache_dir);
    
    let filename = format!("{}-{}.lrc", artist.replace(|c: char| !c.is_alphanumeric(), "_"), title.replace(|c: char| !c.is_alphanumeric(), "_"));
    let cache_file = cache_dir.join(&filename);
    
    if cache_file.exists() {
        if let Ok(content) = fs::read_to_string(&cache_file) {
            return Ok(content);
        }
    }

    let url = format!(
        "https://lrclib.net/api/get?track_name={}&artist_name={}",
        urlencoding::encode(title),
        urlencoding::encode(artist)
    );
    let resp = client.get(&url)
        .timeout(std::time::Duration::from_secs(10))
        .send().await?;
        
    if resp.status() == reqwest::StatusCode::NOT_FOUND {
        let _ = fs::write(&cache_file, "");
        return Ok(String::new());
    }
    
    let resp = resp.error_for_status()?;
        
    let json: serde_json::Value = resp.json().await?;

    let lyrics = if let Some(synced) = json.get("syncedLyrics").and_then(|v| v.as_str()) {
        synced.to_string()
    } else {
        String::new()
    };
    
    let _ = fs::write(&cache_file, &lyrics);
    Ok(lyrics)
}
