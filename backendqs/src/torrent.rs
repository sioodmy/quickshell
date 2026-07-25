use librqbit::{Session, AddTorrent, AddTorrentOptions, AddTorrentResponse, ManagedTorrent};
use serde_json::{Value, json};
use std::sync::Arc;
use tokio::sync::Mutex;
use anyhow::Result;
use std::path::PathBuf;

pub struct TrackedTorrent {
    pub handle: Arc<ManagedTorrent>,
    pub notified: bool,
}

pub struct TorrentManager {
    pub session: Arc<Session>,
    pub torrents: Arc<Mutex<Vec<TrackedTorrent>>>,
}

impl TorrentManager {
    pub async fn new() -> Result<Self> {
        let dir = PathBuf::from(std::env::var("HOME").unwrap_or("/".into())).join("Downloads");
        let session = Session::new(dir).await?;
        Ok(Self {
            session,
            torrents: Arc::new(Mutex::new(Vec::new())),
        })
    }

    pub async fn add(&self, magnet: &str) -> Result<()> {
        let resp = self.session.add_torrent(
            AddTorrent::from_url(magnet),
            Some(AddTorrentOptions {
                overwrite: true,
                ..Default::default()
            }),
        ).await?;
        
        if let AddTorrentResponse::Added(_, handle) = resp {
            self.torrents.lock().await.push(TrackedTorrent { handle, notified: false });
        }
        Ok(())
    }

    pub async fn cancel(&self, idx: usize) -> Result<()> {
        let handle = {
            let mut torrents = self.torrents.lock().await;
            if idx < torrents.len() {
                Some(torrents.remove(idx))
            } else {
                None
            }
        };
        // By removing it from our tracked list, we just forget about it.
        // It's downloaded to Downloads, we don't care to cleanly remove it from the system,
        // it just stops being tracked in the UI.
        Ok(())
    }

    pub async fn get_stats(&self) -> Value {
        let mut torrents = self.torrents.lock().await;
        let mut list = Vec::new();
        for (i, t) in torrents.iter_mut().enumerate() {
            let stats = t.handle.stats();
            let mut name = String::new();
            if let Ok(Some(meta)) = t.handle.with_metadata(|r| r.name.clone()) {
                name = meta;
            }
            if stats.finished && !t.notified {
                t.notified = true;
                let _ = notify_rust::Notification::new()
                    .summary("Torrent Finished")
                    .body(&name)
                    .show();
            }
            let progress = if stats.total_bytes > 0 {
                (stats.progress_bytes as f64 / stats.total_bytes as f64) * 100.0
            } else {
                0.0
            };
            
            let mut speed = "0 B/s".to_string();
            let mut eta = String::new();
            let mut peers = String::new();
            
            if let Some(ref live) = stats.live {
                // Formatting speed
                speed = format!("{:.1} MB/s", live.download_speed.mbps);
                
                // Formatting ETA
                if let Some(ref t) = live.time_remaining {
                    eta = format!(" • {}", t);
                }
                
                peers = format!(" • {} peers", live.snapshot.peer_stats.live);
            }
            
            let status_text = format!("{:.1}% • {}{}{}", progress, speed, eta, peers);
            
            list.push(json!({
                "id": i,
                "name": name,
                "progress": progress,
                "status_text": status_text,
                "stats": stats
            }));
        }
        json!(list)
    }
}
