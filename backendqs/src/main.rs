mod agenda;
mod api;
mod appsearch;
mod artpalette;
mod archivepreview;
mod bookmarks;
mod cliphist;
mod context;
mod dictionary;
mod filesearch;
mod fileshare;
mod frecency;
mod handler;
mod idle_manager;
pub mod keepass_db;
mod logind_listener;
mod lyrics;
mod music;
mod music_remote;
mod pdfpreview;
mod state;
mod sysctl;
mod videopreview;
mod weather;

pub mod battery;
pub mod org_renderer;
pub mod polkit;

#[macro_export]
macro_rules! debug_log {
    ($($arg:tt)*) => {
        if std::env::var_os("LENINSHELL_DEBUG").is_some() {
            eprintln!($($arg)*);
        }
    }
}
use anyhow::Result;
use clap::{Parser, Subcommand};
use reqwest::Client;
use tokio::io::{AsyncBufReadExt, BufReader};

use notify::{Event, RecursiveMode, Watcher};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
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
    #[command(hide = true)]
    KeepassClipboard,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::KeepassClipboard => keepass_db::serve_clipboard()?,
        Commands::Run { query, out, color } => {
            match mathtosvg::process_query(&query, out.as_deref(), color.as_deref(), None) {
                Ok((content, path)) => {
                    if let Some(p) = path {
                        println!("SVG saved to: {}", p);
                    } else {
                        println!("{}", content);
                    }
                }
                Err(e) => {
                    crate::debug_log!("Error: {:?}", e);
                    std::process::exit(1);
                }
            }
        }
        Commands::Daemon => {
            // Parent (quickshell) death closes our stdout. Ignoring SIGPIPE
            // keeps incidental writes from aborting the whole daemon.
            #[cfg(unix)]
            unsafe {
                extern "C" {
                    fn signal(sig: i32, handler: usize) -> usize;
                }
                const SIGPIPE: i32 = 13;
                const SIG_IGN: usize = 1;
                let _ = signal(SIGPIPE, SIG_IGN);
            }

            idle_manager::spawn_idle_manager();

            tokio::spawn(async move {
                logind_listener::start_logind_listener().await;
            });

            let player = music::PLAYER.get_or_init(music::Player::new);
            // Start MPRIS D-Bus server
            let mpris_state = player.state.clone();
            tokio::spawn(async move {
                if let Err(e) = music::start_mpris(mpris_state).await {
                    crate::debug_log!("MPRIS init error: {}", e);
                }
            });
            let client = Client::new();
            let (tx_event, mut rx_event) = tmpsc::channel::<api::DaemonEvent>(100);
            keepass_db::init(tx_event.clone());

            // Output task. Never use println!: a broken pipe (parent died)
            // panics the whole daemon and takes the shell's IPC with it.
            tokio::spawn(async move {
                use std::io::{self, Write};
                while let Some(ev) = rx_event.recv().await {
                    if let Ok(json) = serde_json::to_string(&ev) {
                        let mut out = io::stdout().lock();
                        if writeln!(out, "{}", json).is_err() {
                            break;
                        }
                        let _ = out.flush();
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
                                palette: state.palette.clone(),
                            }
                        };
                        let _ = tx_event_clone
                            .send(api::DaemonEvent::MusicStateUpdate { state: dto })
                            .await;
                    }
                }
            });

            // Setup file watcher for Agenda
            let notes_dir = std::env::var("HOME")
                .map(|h| PathBuf::from(h).join("Notes"))
                .unwrap_or_default();
            if notes_dir.exists() {
                let (tx_notify, rx_notify) = std::sync::mpsc::channel();
                if let Ok(mut watcher) = notify::recommended_watcher(tx_notify) {
                    let _ = watcher.watch(&notes_dir, RecursiveMode::Recursive);
                    let tx_ev = tx_event.clone();
                    let ndir = notes_dir.clone();
                    tokio::task::spawn_blocking(move || {
                        let _w = watcher; // Keep alive
                        for res in rx_notify {
                            match res {
                                Ok(Event { kind, .. }) => {
                                    if kind.is_modify() || kind.is_create() || kind.is_remove() {
                                        if let Ok(items) = agenda::parse_directory(&ndir) {
                                            let _ = tx_ev.blocking_send(
                                                api::DaemonEvent::AgendaUpdate { data: items },
                                            );
                                        }
                                    }
                                }
                                Err(_) => {}
                            }
                        }
                    });
                }
            }

            // Trigger initial agenda load
            let initial_items = agenda::parse_directory(&notes_dir).unwrap_or_default();
            let _ = tx_event
                .send(api::DaemonEvent::AgendaUpdate {
                    data: initial_items,
                })
                .await;

            // Setup Frecency state (scores cached; refreshed only on load/record)
            let frecency_state = Arc::new(std::sync::Mutex::new(
                crate::frecency::FrecencyState::new(frecency::load_or_migrate()),
            ));
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
            let file_share: Arc<tokio::sync::Mutex<Option<fileshare::FileShareHandle>>> =
                Arc::new(tokio::sync::Mutex::new(None));
            let file_share_progress_active = Arc::new(std::sync::atomic::AtomicBool::new(false));
            let music_remote_state: Arc<
                tokio::sync::Mutex<
                    Option<(
                        music_remote::MusicRemoteHandle,
                        std::sync::Arc<music_remote::MusicRemoteState>,
                    )>,
                >,
            > = Arc::new(tokio::sync::Mutex::new(None));

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

            // Build app search index in background
            let app_index = appsearch::new_index();
            {
                let idx = app_index.clone();
                tokio::spawn(async move {
                    appsearch::build_index(idx).await;
                });
            }

            // Start polkit agent
            {
                let tx = tx_event.clone();
                tokio::spawn(async move {
                    polkit::start_agent(tx).await;
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
                    let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
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

            // Setup rink
            let rink = rink_core::Context::new();
            let rink_ctx = Arc::new(tokio::sync::Mutex::new(rink));

            // Stdin reading loop
            let mut reader = BufReader::new(tokio::io::stdin()).lines();

            while let Ok(Some(line)) = reader.next_line().await {
                let line = zeroize::Zeroizing::new(line);
                if line.trim().is_empty() {
                    continue;
                }

                let req: api::DaemonRequest = match serde_json::from_str(&line) {
                    Ok(r) => r,
                    Err(_) => {
                        crate::debug_log!("Invalid backend request");
                        continue;
                    }
                };
                drop(line);

                // Assign generations and process locks at receipt, not in scheduled
                // tasks. Slow decryption/copy work must never undo a later lock.
                let req = match req {
                    api::DaemonRequest::KeepassUnlock {
                        password,
                        request_id,
                    } => {
                        let password = zeroize::Zeroizing::new(password);
                        let generation = keepass_db::begin_unlock(request_id);
                        tokio::task::spawn_blocking(move || {
                            let _ = keepass_db::unlock(&password, generation);
                        });
                        continue;
                    }
                    api::DaemonRequest::KeepassLock { request_id } => {
                        keepass_db::lock_request(request_id);
                        continue;
                    }
                    req @ (api::DaemonRequest::KeepassSearch { .. }
                    | api::DaemonRequest::KeepassCopy { .. }
                    | api::DaemonRequest::KeepassGetOtp { .. }) => {
                        let generation = keepass_db::generation();
                        tokio::task::spawn_blocking(move || {
                            keepass_db::handle_request(req, generation);
                        });
                        continue;
                    }
                    req => req,
                };

                // Fast path for polkit routing to avoid spawning task overhead for password passing
                match &req {
                    api::DaemonRequest::PolkitSubmit { cookie, response } => {
                        let ch = polkit::POLKIT_CHANNELS.lock().await;
                        if let Some(tx) = ch.get(cookie) {
                            let _ = tx.send(response.clone()).await;
                        }
                        continue;
                    }
                    api::DaemonRequest::PolkitCancel { cookie } => {
                        let mut ch = polkit::POLKIT_CHANNELS.lock().await;
                        if let Some(_tx) = ch.remove(cookie) {
                            // Channel drop will abort waiting agent
                        }
                        continue;
                    }
                    _ => {}
                }

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
                    app_index: app_index.clone(),
                    file_search_generation: file_search_generation.clone(),
                    cliphist_state: cliphist_state.clone(),
                    ocr_sem: ocr_sem.clone(),
                    file_share: file_share.clone(),
                    file_share_progress_active: file_share_progress_active.clone(),
                    music_remote_state: music_remote_state.clone(),

                    rink_ctx: rink_ctx.clone(),
                };

                tokio::spawn(async move {
                    handler::handle_request(req, ctx, assigned_search_gen).await;
                });
            }
            keepass_db::lock();
        }
    }
    std::process::exit(0);
}
