use anyhow::Result;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn expand_tilde(path: &str) -> PathBuf {
    if path.starts_with("~/") {
        let home = std::env::var("HOME").unwrap_or_default();
        PathBuf::from(path.replacen("~", &home, 1))
    } else {
        PathBuf::from(path)
    }
}

pub fn save_json(path_str: &str, value: &Value) -> Result<()> {
    let path = expand_tilde(path_str);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let data = serde_json::to_string(value)?;
    fs::write(path, data)?;
    Ok(())
}
