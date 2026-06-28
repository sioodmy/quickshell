mod music;
mod parser;
mod math;
mod dictionary;
mod agenda;
mod lyrics;
mod state;
mod cliphist;
mod weather;

use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use tokio::io::{self, AsyncBufReadExt, BufReader};
use reqwest::Client;
use std::path::PathBuf;
use notify::{Watcher, RecursiveMode, Event};
use tokio::sync::mpsc as tmpsc;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run a single query
    Run {
        #[arg(short, long)]
        query: String,
        #[arg(short, long)]
        out: Option<String>,
        #[arg(short, long)]
        color: Option<String>,
    },
    /// Run in daemon mode (reads JSON from stdin)
    Daemon,
}

#[derive(Deserialize, Debug)]
#[serde(tag = "action")]
enum DaemonRequest {
    #[serde(rename = "math")]
    Math { query: String, out: Option<String>, color: Option<String> },
    #[serde(rename = "dictionary")]
    Dictionary { query: String },
    #[serde(rename = "calc")]
    Calc { query: String },
    #[serde(rename = "save_json")]
    SaveJson { path: String, data: serde_json::Value },
    #[serde(rename = "lyrics")]
    Lyrics { artist: String, title: String },
    #[serde(rename = "lyrics_prefetch")]
    LyricsPrefetch { artist: String, title: String },
    #[serde(rename = "weather_refresh")]
    WeatherRefresh,
    #[serde(rename = "agenda_refresh")]
    AgendaRefresh,
    #[serde(rename = "cliphist")]
    Cliphist,
    #[serde(rename = "music_library")]
    MusicLibrary,
    #[serde(rename = "music_play_album")]
    MusicPlayAlbum { tracks: Vec<String>, start_index: usize },
    #[serde(rename = "music_pause")]
    MusicPause,
    #[serde(rename = "music_resume")]
    MusicResume,
    #[serde(rename = "music_next")]
    MusicNext,
    #[serde(rename = "music_previous")]
    MusicPrevious,
    #[serde(rename = "music_seek")]
    MusicSeek { position: f64 },
}

#[derive(Serialize)]
#[serde(tag = "type")]
enum DaemonEvent {
    #[serde(rename = "math_result")]
    MathResult { status: String, error: Option<String>, svg_file: Option<String>, svg_content: Option<String> },
    #[serde(rename = "dictionary_result")]
    DictionaryResult { status: String, error: Option<String>, word: Option<String>, phonetic: Option<String>, definition: Option<String> },
    #[serde(rename = "calc_result")]
    CalcResult { status: String, error: Option<String>, result: Option<String>, query: String },
    #[serde(rename = "lyrics_result")]
    LyricsResult { status: String, error: Option<String>, lyrics: Option<String> },
    #[serde(rename = "weather_result")]
    WeatherResult { status: String, error: Option<String>, data: Option<weather::WeatherData> },
    #[serde(rename = "agenda_update")]
    AgendaUpdate { data: Vec<agenda::AgendaItem> },
    #[serde(rename = "cliphist_result")]
    CliphistResult { status: String, error: Option<String>, data: Vec<cliphist::CliphistItem> },
    #[serde(rename = "music_library_result")]
    MusicLibraryResult { status: String, error: Option<String>, library: Option<music::Library> },
    #[serde(rename = "music_state_update")]
    MusicStateUpdate { state: MusicStateDto },
}

#[derive(Serialize)]
pub struct MusicStateDto {
    pub playing: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub duration_us: i64,
    pub position_us: i64,
    pub has_player: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Run { query, out, color } => {
            match math::process_query(&query, out.as_deref(), color.as_deref(), None) {
                Ok((content, path)) => {
                    if let Some(p) = path {
                        println!("SVG saved to: {}", p);
                    } else {
                        println!("{}", content);
                    }
                }
                Err(e) => {
                    eprintln!("Error: {:?}", e);
                    std::process::exit(1);
                }
            }
        }
        Commands::Daemon => {
            let player = music::PLAYER.get_or_init(music::Player::new);
            // Start MPRIS D-Bus server
            let mpris_state = player.state.clone();
            tokio::spawn(async move {
                if let Err(e) = music::start_mpris(mpris_state).await {
                    eprintln!("MPRIS init error: {}", e);
                }
            });
            let client = Client::new();
            let (tx_event, mut rx_event) = tmpsc::channel::<DaemonEvent>(100);

            // Output task
            tokio::spawn(async move {
                while let Some(ev) = rx_event.recv().await {
                    if let Ok(json) = serde_json::to_string(&ev) {
                        println!("{}", json);
                    }
                }
            });

            // State updater task
            let tx_event_clone = tx_event.clone();
            tokio::spawn(async move {
                let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
                loop {
                    interval.tick().await;
                    if let Some(player) = music::PLAYER.get() {
                        let dto = {
                            let state = player.state.lock().unwrap();
                            MusicStateDto {
                                playing: state.playing,
                                title: state.title.clone(),
                                artist: state.artist.clone(),
                                album: state.album.clone(),
                                art_url: state.art_url.clone(),
                                duration_us: state.duration_us,
                                position_us: state.live_position_us(),
                                has_player: !state.title.is_empty(),
                            }
                        };
                        let _ = tx_event_clone.send(DaemonEvent::MusicStateUpdate { state: dto }).await;
                    }
                }
            });

            // Setup file watcher for Agenda
            let notes_dir = std::env::var("HOME").map(|h| PathBuf::from(h).join("Notes")).unwrap_or_default();
            if notes_dir.exists() {
                let (tx_notify, rx_notify) = std::sync::mpsc::channel();
                let mut watcher = notify::recommended_watcher(tx_notify)?;
                watcher.watch(&notes_dir, RecursiveMode::Recursive)?;

                let tx_ev = tx_event.clone();
                let ndir = notes_dir.clone();
                tokio::task::spawn_blocking(move || {
                    let _w = watcher; // Keep alive
                    for res in rx_notify {
                        match res {
                            Ok(Event { kind, .. }) => {
                                if kind.is_modify() || kind.is_create() || kind.is_remove() {
                                    if let Ok(items) = agenda::parse_directory(&ndir) {
                                        let _ = tx_ev.blocking_send(DaemonEvent::AgendaUpdate { data: items });
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    }
                });

                // Trigger initial agenda load
                if let Ok(items) = agenda::parse_directory(&notes_dir) {
                    let _ = tx_event.send(DaemonEvent::AgendaUpdate { data: items }).await;
                }
            }

            // Stdin reading loop
            let stdin = io::stdin();
            let mut reader = BufReader::new(stdin).lines();

            while let Ok(Some(line)) = reader.next_line().await {
                if line.trim().is_empty() { continue; }
                
                let req: DaemonRequest = match serde_json::from_str(&line) {
                    Ok(r) => r,
                    Err(e) => {
                        eprintln!("Error deserializing: {} for line: {}", e, line);
                        // Fallback parsing for old requests
                        if let Ok(old_req) = serde_json::from_str::<serde_json::Value>(&line) {
                            if let Some(query) = old_req.get("query").and_then(|v| v.as_str()) {
                                let out = old_req.get("out").and_then(|v| v.as_str()).map(|s| s.to_string());
                                let color = old_req.get("color").and_then(|v| v.as_str()).map(|s| s.to_string());
                                handle_math(query.to_string(), out, color, tx_event.clone()).await;
                            }
                        }
                        continue;
                    }
                };

                let tx = tx_event.clone();
                let client = client.clone();
                let notes_dir = notes_dir.clone();

                tokio::spawn(async move {
                    match req {
                        DaemonRequest::Math { query, out, color } => {
                            handle_math(query, out, color, tx).await;
                        }
                        DaemonRequest::Dictionary { query } => {
                            match dictionary::lookup_word(&client, &query).await {
                                Ok(res) => {
                                    let _ = tx.send(DaemonEvent::DictionaryResult {
                                        status: "ok".into(),
                                        error: None,
                                        word: Some(res.word),
                                        phonetic: Some(res.phonetic),
                                        definition: Some(res.definition),
                                    }).await;
                                }
                                Err(e) => {
                                    let _ = tx.send(DaemonEvent::DictionaryResult {
                                        status: "error".into(),
                                        error: Some(e.to_string()),
                                        word: None,
                                        phonetic: None,
                                        definition: None,
                                    }).await;
                                }
                            }
                        }
                        DaemonRequest::Calc { query } => {
                            let res = tokio::task::spawn_blocking(move || {
                                std::process::Command::new("rink")
                                    .arg(&query)
                                    .output()
                            }).await.unwrap();

                            if let Ok(out) = res {
                                let stdout = String::from_utf8_lossy(&out.stdout).to_string();
                                let lines: Vec<&str> = stdout.trim().split('\n').collect();
                                let mut result_str = String::new();
                                for l in lines.iter().rev() {
                                    let trimmed = l.trim();
                                    if !trimmed.is_empty() && !trimmed.starts_with('>') {
                                        result_str = trimmed.to_string();
                                        break;
                                    }
                                }
                                
                                if result_str.contains("No such") || result_str.contains("Expected") || result_str.contains("error") {
                                    let _ = tx.send(DaemonEvent::CalcResult { status: "error".into(), error: Some(result_str), result: None, query: "".into() }).await;
                                } else {
                                    let _ = tx.send(DaemonEvent::CalcResult { status: "ok".into(), error: None, result: Some(result_str), query: "".into() }).await;
                                }
                            }
                        }
                        DaemonRequest::SaveJson { path, data } => {
                            let _ = state::save_json(&path, &data);
                        }
                        DaemonRequest::Lyrics { artist, title } => {
                            match lyrics::fetch_lyrics(&client, &artist, &title).await {
                                Ok(l) => {
                                    let _ = tx.send(DaemonEvent::LyricsResult { status: "ok".into(), error: None, lyrics: Some(l) }).await;
                                }
                                Err(e) => {
                                    let _ = tx.send(DaemonEvent::LyricsResult { status: "error".into(), error: Some(e.to_string()), lyrics: None }).await;
                                }
                            }
                        }
                        DaemonRequest::LyricsPrefetch { artist, title } => {
                            let _ = lyrics::fetch_lyrics(&client, &artist, &title).await;
                        }
                        DaemonRequest::WeatherRefresh => {
                            match weather::fetch_weather(&client).await {
                                Ok(data) => {
                                    let _ = tx.send(DaemonEvent::WeatherResult { status: "ok".into(), error: None, data: Some(data) }).await;
                                }
                                Err(e) => {
                                    let _ = tx.send(DaemonEvent::WeatherResult { status: "error".into(), error: Some(e.to_string()), data: None }).await;
                                }
                            }
                        }
                        DaemonRequest::AgendaRefresh => {
                            if let Ok(items) = agenda::parse_directory(&notes_dir) {
                                let _ = tx.send(DaemonEvent::AgendaUpdate { data: items }).await;
                            }
                        }
                        DaemonRequest::Cliphist => {
                            let res = tokio::task::spawn_blocking(move || cliphist::get_history()).await.unwrap();
                            match res {
                                Ok(data) => {
                                    let _ = tx.send(DaemonEvent::CliphistResult { status: "ok".into(), error: None, data }).await;
                                }
                                Err(e) => {
                                    let _ = tx.send(DaemonEvent::CliphistResult { status: "error".into(), error: Some(e.to_string()), data: vec![] }).await;
                                }
                            }
                        }
                        DaemonRequest::MusicLibrary => {
                            let res = tokio::task::spawn_blocking(|| music::scan_library()).await.unwrap();
                            match res {
                                Ok(lib) => {
                                    let _ = tx.send(DaemonEvent::MusicLibraryResult { status: "ok".into(), error: None, library: Some(lib) }).await;
                                }
                                Err(e) => {
                                    let _ = tx.send(DaemonEvent::MusicLibraryResult { status: "error".into(), error: Some(e.to_string()), library: None }).await;
                                }
                            }
                        }
                        DaemonRequest::MusicPlayAlbum { tracks, start_index } => {
                            if let Some(player) = music::PLAYER.get() {
                                player.play_album(tracks, start_index);
                            }
                        }
                        DaemonRequest::MusicPause => {
                            if let Some(player) = music::PLAYER.get() {
                                player.pause();
                            }
                        }
                        DaemonRequest::MusicResume => {
                            if let Some(player) = music::PLAYER.get() {
                                player.resume();
                            }
                        }
                        DaemonRequest::MusicNext => {
                            if let Some(player) = music::PLAYER.get() {
                                player.next();
                            }
                        }
                        DaemonRequest::MusicPrevious => {
                            if let Some(player) = music::PLAYER.get() {
                                player.previous();
                            }
                        }
                        DaemonRequest::MusicSeek { position } => {
                            if let Some(player) = music::PLAYER.get() {
                                player.seek(position);
                            }
                        }
                    }
                });
            }
        }
    }

    Ok(())
}

async fn handle_math(query: String, out: Option<String>, color: Option<String>, tx: tmpsc::Sender<DaemonEvent>) {
    let res = tokio::task::spawn_blocking(move || {
        math::process_query(&query, out.as_deref(), color.as_deref(), None)
    }).await.unwrap();

    match res {
        Ok((content, path)) => {
            let _ = tx.send(DaemonEvent::MathResult {
                status: "ok".into(),
                error: None,
                svg_file: path,
                svg_content: Some(content),
            }).await;
        }
        Err(e) => {
            let _ = tx.send(DaemonEvent::MathResult {
                status: "error".into(),
                error: Some(e.to_string()),
                svg_file: None,
                svg_content: None,
            }).await;
        }
    }
}
