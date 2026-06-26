use anyhow::Result;
use reqwest::Client;
use std::fs;
use std::path::PathBuf;

pub async fn fetch_lyrics(client: &Client, artist: &str, title: &str) -> Result<String> {
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
