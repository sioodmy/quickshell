use anyhow::Result;
use serde::{Deserialize, Serialize};
use reqwest::Client;
use std::fs;
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DictionaryResult {
    pub word: String,
    pub phonetic: String,
    pub definition: String,
}

pub async fn lookup_word(client: &Client, word: &str) -> Result<DictionaryResult> {
    let cache_dir = std::env::var("HOME").map(|h| PathBuf::from(h).join(".cache").join("quickshell").join("dictionary"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/quickshell_dictionary"));
    let _ = fs::create_dir_all(&cache_dir);
    
    let filename = format!("{}.json", word.replace(|c: char| !c.is_alphanumeric(), "_").to_lowercase());
    let cache_file = cache_dir.join(&filename);
    
    if cache_file.exists() {
        if let Ok(content) = fs::read_to_string(&cache_file) {
            if let Ok(cached_res) = serde_json::from_str::<DictionaryResult>(&content) {
                return Ok(cached_res);
            }
        }
    }

    let url = format!("https://api.dictionaryapi.dev/api/v2/entries/en/{}", urlencoding::encode(word));
    let resp = client.get(&url).send().await?;
    
    if resp.status() == reqwest::StatusCode::NOT_FOUND {
        return Err(anyhow::anyhow!("Not found"));
    }
    
    let resp = resp.error_for_status()?;
    let json: serde_json::Value = resp.json().await?;

    let array = json.as_array().ok_or_else(|| anyhow::anyhow!("Not an array"))?;
    let first = array.first().ok_or_else(|| anyhow::anyhow!("Empty array"))?;

    let fetched_word = first.get("word").and_then(|v| v.as_str()).unwrap_or(word).to_string();
    
    let mut phonetic = String::new();
    if let Some(phonetic_str) = first.get("phonetic").and_then(|v| v.as_str()) {
        phonetic = phonetic_str.to_string();
    } else if let Some(phonetics) = first.get("phonetics").and_then(|v| v.as_array()) {
        for p in phonetics {
            if let Some(text) = p.get("text").and_then(|v| v.as_str()) {
                if !text.is_empty() {
                    phonetic = text.to_string();
                    break;
                }
            }
        }
    }

    let mut definition = String::new();
    if let Some(meanings) = first.get("meanings").and_then(|v| v.as_array()) {
        for m in meanings {
            if let Some(defs) = m.get("definitions").and_then(|v| v.as_array()) {
                if let Some(def_obj) = defs.first() {
                    if let Some(def_str) = def_obj.get("definition").and_then(|v| v.as_str()) {
                        definition = def_str.to_string();
                        break;
                    }
                }
            }
        }
    }

    if definition.is_empty() {
        return Err(anyhow::anyhow!("No definition found"));
    }

    let res = DictionaryResult {
        word: fetched_word,
        phonetic,
        definition,
    };
    
    if let Ok(json_str) = serde_json::to_string(&res) {
        let _ = fs::write(&cache_file, json_str);
    }

    Ok(res)
}
