mod music;
mod parser;
mod math;
mod dictionary;
mod agenda;
mod lyrics;
mod state;
mod weather;
mod frecency;
mod filesearch;
mod archivepreview;
mod pdfpreview;
mod videopreview;
mod sysctl;
mod cliphist;
mod bookmarks;
mod fileshare;
mod music_remote;
mod api;
mod context;
mod handler;

use anyhow::Result;
use clap::{Parser, Subcommand};
use tokio::io::{AsyncBufReadExt, BufReader};
use reqwest::Client;

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
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
            let (tx_event, mut rx_event) = tmpsc::channel::<api::DaemonEvent>(100);

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
                            api::MusicStateDto {
                                playing: state.playing,
                                title: state.title.clone(),
                                artist: state.artist.clone(),
                                album: state.album.clone(),
                                art_url: state.art_url.clone(),
                                duration_us: state.duration_us,
                                position_us: state.live_position_us(),
                                volume: state.volume,
                                loop_album: state.loop_album,
                                has_player: !state.title.is_empty(),
                            }
                        };
                        let _ = tx_event_clone.send(api::DaemonEvent::MusicStateUpdate { state: dto }).await;
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
                                        let _ = tx_ev.blocking_send(api::DaemonEvent::AgendaUpdate { data: items });
                                    }
                                }
                            }
                            Err(_) => {}
                        }
                    }
                });

                // Trigger initial agenda load
                if let Ok(items) = agenda::parse_directory(&notes_dir) {
                    let _ = tx_event.send(api::DaemonEvent::AgendaUpdate { data: items }).await;
                }
            }

            // Setup Frecency state (scores cached; refreshed only on load/record)
            let frecency_state = Arc::new(std::sync::Mutex::new(crate::frecency::FrecencyState::new(
                frecency::load_or_migrate(),
            )));
            // Initial frecency load event
            {
                let state = frecency_state.lock().unwrap();
                let _ = tx_event
                    .send(api::DaemonEvent::FrecencyUpdate {
                        scores: state.scores.clone(),
                    })
                    .await;
            }

            // Clipboard history state + a single-permit gate so at most one
            // tesseract OCR pass runs at a time (battery friendly).
            let cliphist_state = cliphist::new_state();
            let ocr_sem = std::sync::Arc::new(tokio::sync::Semaphore::new(1));
            let file_share: Arc<tokio::sync::Mutex<Option<fileshare::FileShareHandle>>> = Arc::new(tokio::sync::Mutex::new(None));
            let file_share_progress_active = Arc::new(std::sync::atomic::AtomicBool::new(false));
            let music_remote_state: Arc<tokio::sync::Mutex<Option<(music_remote::MusicRemoteHandle, std::sync::Arc<music_remote::MusicRemoteState>)>>> = Arc::new(tokio::sync::Mutex::new(None));

            // Build file search index in background
            let file_index = filesearch::new_index();
            {
                let idx = file_index.clone();
                tokio::spawn(async move {
                    filesearch::build_index(idx).await;
                });
            }

            // Warm syntect so the first code preview isn't a hitch.
            tokio::task::spawn_blocking(filesearch::warmup_highlighter);

            // Build bookmark index in background
            let bookmark_index = bookmarks::new_index();
            {
                let idx = bookmark_index.clone();
                let c = client.clone();
                tokio::spawn(async move {
                    bookmarks::build_index(c, idx).await;
                });
            }

            // Monotonic generation so stale file_search tasks can abort.
            let file_search_generation = Arc::new(AtomicU64::new(0));

            // Progress poller: emits share state at most every 500ms while active.
            {
                let fs = file_share.clone();
                let tx_prog = tx_event.clone();
                let active = file_share_progress_active.clone();
                tokio::spawn(async move {
                    let mut interval =
                        tokio::time::interval(std::time::Duration::from_millis(500));
                    loop {
                        interval.tick().await;
                        if !active.load(Ordering::Relaxed) {
                            continue;
                        }
                        let shares = {
                            let guard = fs.lock().await;
                            if let Some(ref h) = *guard {
                                h.list_shares().await
                            } else {
                                vec![]
                            }
                        };
                        if shares.is_empty() {
                            active.store(false, Ordering::Relaxed);
                            continue;
                        }
                        let _ = tx_prog
                            .send(api::DaemonEvent::FileShareProgress { shares })
                            .await;
                    }
                });
            }

            // Stdin reading loop
            let mut reader = BufReader::new(tokio::io::stdin()).lines();

            while let Ok(Some(line)) = reader.next_line().await {
                if line.trim().is_empty() { continue; }
                
                let req: api::DaemonRequest = match serde_json::from_str(&line) {
                    Ok(r) => r,
                    Err(e) => {
                        eprintln!("Error deserializing: {} for line: {}", e, line);
                        continue;
                    }
                };

                let assigned_search_gen = match &req {
                    api::DaemonRequest::FileSearch { .. } => {
                        Some(file_search_generation.fetch_add(1, Ordering::Relaxed) + 1)
                    }
                    _ => None,
                };


                let ctx = context::AppContext {
                    tx: tx_event.clone(),
                    client: client.clone(),
                    notes_dir: notes_dir.clone(),
                    frecency_state: frecency_state.clone(),
                    file_index: file_index.clone(),
                    bookmark_index: bookmark_index.clone(),
                    file_search_generation: file_search_generation.clone(),
                    cliphist_state: cliphist_state.clone(),
                    ocr_sem: ocr_sem.clone(),
                    file_share: file_share.clone(),
                    file_share_progress_active: file_share_progress_active.clone(),
                    music_remote_state: music_remote_state.clone(),
                };

                tokio::spawn(async move {
                    handler::handle_request(req, ctx, assigned_search_gen).await;
});
            }
        }
    }

    Ok(())
}

