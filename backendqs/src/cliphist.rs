use anyhow::Result;
use serde::Serialize;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::io::Write;

#[derive(Serialize, Debug, Clone)]
pub struct CliphistItem {
    pub raw: String,
    pub display: String,
    pub image_path: String,
}

pub fn get_history() -> Result<Vec<CliphistItem>> {
    let output = Command::new("cliphist").arg("list").output()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut items = Vec::new();
    
    let tmp_dir = PathBuf::from("/tmp/cliphist");
    let _ = fs::create_dir_all(&tmp_dir);

    for line in stdout.lines() {
        if line.trim().is_empty() { continue; }
        let mut parts = line.splitn(2, '\t');
        let id = parts.next().unwrap_or("");
        let display = parts.next().unwrap_or("");
        
        let mut image_path = String::new();
        if display.starts_with("[[ binary") || display.starts_with("[[binary") {
            let ext = if display.contains("jpg") || display.contains("jpeg") {
                "jpg"
            } else if display.contains("png") {
                "png"
            } else if display.contains("bmp") {
                "bmp"
            } else if display.contains("webp") {
                "webp"
            } else {
                "png"
            };
            
            let img_file = tmp_dir.join(format!("{}.{}", id, ext));
            image_path = img_file.to_string_lossy().to_string();
            
            if !img_file.exists() || fs::metadata(&img_file).map(|m| m.len() == 0).unwrap_or(true) {
                if let Ok(mut child) = Command::new("cliphist")
                    .arg("decode")
                    .stdin(Stdio::piped())
                    .stdout(Stdio::piped())
                    .spawn() 
                {
                    if let Some(mut stdin) = child.stdin.take() {
                        let _ = stdin.write_all(line.as_bytes());
                    }
                    if let Ok(out) = child.wait_with_output() {
                        let _ = fs::write(&img_file, out.stdout);
                    }
                }
            }
        }
        
        items.push(CliphistItem {
            raw: line.to_string(),
            display: display.to_string(),
            image_path,
        });
    }
    
    Ok(items)
}
