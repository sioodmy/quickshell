use crate::api::DaemonRequest;
use crate::context::AppContext;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use crate::*;

pub async fn handle_request(req: DaemonRequest, ctx: AppContext, assigned_search_gen: Option<u64>) {
    match req {
                        api::DaemonRequest::Math { query, out, color } => {
                            handle_math(query, out, color, ctx.tx.clone()).await;
                        }
                        api::DaemonRequest::Dictionary { query } => {
                            match dictionary::lookup_word(&ctx.client, &query).await {
                                Ok(res) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::DictionaryResult {
                                        status: "ok".into(),
                                        error: None,
                                        word: Some(res.word),
                                        phonetic: Some(res.phonetic),
                                        definition: Some(res.definition),
                                    }).await;
                                }
                                Err(e) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::DictionaryResult {
                                        status: "error".into(),
                                        error: Some(e.to_string()),
                                        word: None,
                                        phonetic: None,
                                        definition: None,
                                    }).await;
                                }
                            }
                        }
                        api::DaemonRequest::Calc { query } => {
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
                                    let _ = ctx.tx.send(api::DaemonEvent::CalcResult { status: "error".into(), error: Some(result_str), result: None, query: "".into() }).await;
                                } else {
                                    let _ = ctx.tx.send(api::DaemonEvent::CalcResult { status: "ok".into(), error: None, result: Some(result_str), query: "".into() }).await;
                                }
                            }
                        }
                        api::DaemonRequest::SaveJson { path, data } => {
                            let _ = state::save_json(&path, &data);
                        }
                        api::DaemonRequest::Lyrics { artist, title } => {
                            match lyrics::fetch_lyrics(&ctx.client, &artist, &title).await {
                                Ok(l) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::LyricsResult { status: "ok".into(), error: None, lyrics: Some(l) }).await;
                                }
                                Err(e) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::LyricsResult { status: "error".into(), error: Some(e.to_string()), lyrics: None }).await;
                                }
                            }
                        }
                        api::DaemonRequest::LyricsPrefetch { artist, title } => {
                            let _ = lyrics::fetch_lyrics(&ctx.client, &artist, &title).await;
                        }
                        api::DaemonRequest::WeatherRefresh => {
                            match weather::fetch_weather(&ctx.client).await {
                                Ok(data) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::WeatherResult { status: "ok".into(), error: None, data: Some(data) }).await;
                                }
                                Err(e) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::WeatherResult { status: "error".into(), error: Some(e.to_string()), data: None }).await;
                                }
                            }
                        }
                        api::DaemonRequest::AgendaRefresh => {
                            if let Ok(items) = agenda::parse_directory(&ctx.notes_dir) {
                                let _ = ctx.tx.send(api::DaemonEvent::AgendaUpdate { data: items }).await;
                            }
                        }
                        api::DaemonRequest::MusicLibrary => {
                            let res = tokio::task::spawn_blocking(|| music::scan_library()).await.unwrap();
                            match res {
                                Ok(lib) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::MusicLibraryResult { status: "ok".into(), error: None, library: Some(lib) }).await;
                                }
                                Err(e) => {
                                    let _ = ctx.tx.send(api::DaemonEvent::MusicLibraryResult { status: "error".into(), error: Some(e.to_string()), library: None }).await;
                                }
                            }
                        }
                        api::DaemonRequest::MusicPlayAlbum { tracks, start_index } => {
                            if let Some(player) = music::PLAYER.get() {
                                player.play_album(tracks, start_index);
                            }
                        }
                        api::DaemonRequest::MusicPause => {
                            if let Some(player) = music::PLAYER.get() {
                                player.pause();
                            }
                        }
                        api::DaemonRequest::MusicResume => {
                            if let Some(player) = music::PLAYER.get() {
                                player.resume();
                            }
                        }
                        api::DaemonRequest::MusicNext => {
                            if let Some(player) = music::PLAYER.get() {
                                player.next();
                            }
                        }
                        api::DaemonRequest::MusicPrevious => {
                            if let Some(player) = music::PLAYER.get() {
                                player.previous();
                            }
                        }
                        api::DaemonRequest::MusicSeek { position } => {
                            if let Some(player) = music::PLAYER.get() {
                                player.seek(position);
                            }
                        }
                        api::DaemonRequest::MusicSetVolume { volume } => {
                            if let Some(player) = music::PLAYER.get() {
                                player.set_volume(volume);
                            }
                        }
                        api::DaemonRequest::MusicToggleLoop => {
                            if let Some(player) = music::PLAYER.get() {
                                player.toggle_loop();
                            }
                        }
                        api::DaemonRequest::FrecencyLoad => {
                            let scores = {
                                let mut state = ctx.frecency_state.lock().unwrap();
                                // Recompute once on explicit load so scores stay fresh.
                                state.refresh_scores();
                                state.scores.clone()
                            };
                            let _ = ctx.tx.send(api::DaemonEvent::FrecencyUpdate { scores }).await;
                        }
                        api::DaemonRequest::FrecencyRecord { id, query } => {
                            let scores = {
                                let mut state = ctx.frecency_state.lock().unwrap();
                                frecency::record_launch(&mut state.data, &id, query.as_deref());
                                frecency::prune_stale_data(&mut state.data);
                                frecency::save(&state.data);
                                state.refresh_scores();
                                state.scores.clone()
                            };
                            let _ = ctx.tx.send(api::DaemonEvent::FrecencyUpdate { scores }).await;
                        }
                        api::DaemonRequest::FileSearch { query } => {
                            let generation = assigned_search_gen.expect("file search gen assigned");
                            let frecency_apps = {
                                let state = ctx.frecency_state.lock().unwrap();
                                Arc::clone(&state.app_scores)
                            };
                            if let Some(results) = filesearch::search(
                                &ctx.file_index,
                                &query,
                                Some(frecency_apps),
                                generation,
                                Arc::clone(&ctx.file_search_generation),
                            )
                            .await
                            {
                                if ctx.file_search_generation.load(Ordering::Relaxed) == generation {
                                    let _ = ctx.tx
                                        .send(api::DaemonEvent::FileSearchResult { query, results })
                                        .await;
                                }
                            }
                        }
                        api::DaemonRequest::BookmarkSearch { query } => {
                            let results = tokio::task::spawn_blocking({
                                let idx = ctx.bookmark_index.clone();
                                let q = query.clone();
                                move || bookmarks::search(&idx, &q)
                            }).await.unwrap();
                            let _ = ctx.tx.send(api::DaemonEvent::BookmarkSearchResult { query, results }).await;
                        }
                        api::DaemonRequest::FilePreview { path } => {
                            let result = tokio::task::spawn_blocking(move || {
                                filesearch::load_preview(&path)
                            }).await.unwrap();
                            let _ = ctx.tx.send(api::DaemonEvent::FilePreviewResult(result)).await;
                        }
                        api::DaemonRequest::FileOpen { path } => {
                            let _ = tokio::task::spawn_blocking(move || {
                                std::process::Command::new("xdg-open")
                                    .arg(&path)
                                    .spawn()
                            }).await;
                        }
                        api::DaemonRequest::SysctlList { kind } => {
                            let devices = if kind == "bluetooth" {
                                sysctl::get_bluetooth_devices()
                            } else if kind == "wifi" || kind == "net" {
                                sysctl::get_wifi_networks()
                            } else {
                                vec![]
                            };
                            let _ = ctx.tx.send(api::DaemonEvent::SysctlListResult { kind, devices }).await;
                        }
                        api::DaemonRequest::CliphistList => {
                            handle_cliphist_list(ctx.cliphist_state, ctx.ocr_sem, ctx.tx.clone()).await;
                        }
                        api::DaemonRequest::CliphistCopy { raw, image_path } => {
                            let img = image_path.unwrap_or_default();
                            let _ = tokio::task::spawn_blocking(move || cliphist::copy_item(&raw, &img)).await;
                            let _ = ctx.tx.send(api::DaemonEvent::CliphistActionDone { action: "copy".into() }).await;
                        }
                        api::DaemonRequest::CliphistDelete { raw } => {
                            let _ = tokio::task::spawn_blocking(move || cliphist::delete_item(&raw)).await;
                            handle_cliphist_list(ctx.cliphist_state, ctx.ocr_sem, ctx.tx.clone()).await;
                        }
                        api::DaemonRequest::CliphistWipe => {
                            let _ = tokio::task::spawn_blocking(|| cliphist::wipe()).await;
                            handle_cliphist_list(ctx.cliphist_state, ctx.ocr_sem, ctx.tx.clone()).await;
                        }
                        api::DaemonRequest::FileShareAdd { path } => {
                            let mut guard = ctx.file_share.lock().await;
                            if guard.is_none() {
                                match fileshare::start_server().await {
                                    Ok(h) => *guard = Some(h),
                                    Err(e) => {
                                        let _ = ctx.tx
                                            .send(api::DaemonEvent::FileShareStarted {
                                                status: "error".into(),
                                                error: Some(e.to_string()),
                                                id: None,
                                                url: None,
                                                qr_svg: None,
                                                name: None,
                                                size: None,
                                            })
                                            .await;
                                        return;
                                    }
                                }
                            }
                            let handle = guard.as_ref().unwrap();
                            match handle.add_share(&path).await {
                                Ok(started) => {
                                    ctx.file_share_progress_active.store(true, Ordering::Relaxed);
                                    let _ = ctx.tx
                                        .send(api::DaemonEvent::FileShareStarted {
                                            status: "ok".into(),
                                            error: None,
                                            id: Some(started.id),
                                            url: Some(started.url),
                                            qr_svg: Some(started.qr_svg),
                                            name: Some(started.name),
                                            size: Some(started.size),
                                        })
                                        .await;
                                    let shares = handle.list_shares().await;
                                    let _ = ctx.tx
                                        .send(api::DaemonEvent::FileShareProgress { shares })
                                        .await;
                                }
                                Err(e) => {
                                    let _ = ctx.tx
                                        .send(api::DaemonEvent::FileShareStarted {
                                            status: "error".into(),
                                            error: Some(e.to_string()),
                                            id: None,
                                            url: None,
                                            qr_svg: None,
                                            name: None,
                                            size: None,
                                        })
                                        .await;
                                }
                            }
                        }
                        api::DaemonRequest::FileShareRemove { id } => {
                            let guard = ctx.file_share.lock().await;
                            if let Some(ref h) = *guard {
                                h.remove_share(&id).await;
                                let shares = h.list_shares().await;
                                if shares.is_empty() {
                                    ctx.file_share_progress_active
                                        .store(false, Ordering::Relaxed);
                                }
                                let _ = ctx.tx
                                    .send(api::DaemonEvent::FileShareProgress { shares })
                                    .await;
                            }
                        }
                        api::DaemonRequest::FileShareRemoveAll => {
                            let guard = ctx.file_share.lock().await;
                            if let Some(ref h) = *guard {
                                h.remove_all().await;
                            }
                            ctx.file_share_progress_active.store(false, Ordering::Relaxed);
                            let _ = ctx.tx
                                .send(api::DaemonEvent::FileShareProgress { shares: vec![] })
                                .await;
                        }
                        api::DaemonRequest::MusicRemoteStart => {
                            let mut guard = ctx.music_remote_state.lock().await;
                            if guard.is_none() {
                                match music_remote::start_server().await {
                                    Ok((handle, state)) => {
                                        let _ = ctx.tx.send(api::DaemonEvent::MusicRemoteStarted {
                                            status: "ok".into(),
                                            error: None,
                                            url: Some(handle.url.clone()),
                                            qr_svg: Some(handle.qr_svg.clone()),
                                        }).await;
                                        
                                        let state_clone = state.clone();
                                        let tx_clone = ctx.tx.clone();
                                        let remote_state_arc = std::sync::Arc::clone(&ctx.music_remote_state);
                                        tokio::spawn(async move {
                                            let mut notified_connected = false;
                                            loop {
                                                tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                                                
                                                if !notified_connected && state_clone.client_connected.load(Ordering::Relaxed) {
                                                    notified_connected = true;
                                                    let _ = tx_clone.send(api::DaemonEvent::MusicRemoteConnected).await;
                                                }
                                                
                                                if !state_clone.is_active.load(Ordering::Relaxed) {
                                                    let mut st = remote_state_arc.lock().await;
                                                    if let Some((_, ref s)) = *st {
                                                        if std::ptr::eq(s.as_ref(), state_clone.as_ref()) {
                                                            *st = None;
                                                        }
                                                    }
                                                    let _ = tx_clone.send(api::DaemonEvent::MusicRemoteStopped).await;
                                                    break;
                                                }
                                            }
                                        });
                                        
                                        *guard = Some((handle, state));
                                    }
                                    Err(e) => {
                                        let _ = ctx.tx.send(api::DaemonEvent::MusicRemoteStarted {
                                            status: "error".into(),
                                            error: Some(e.to_string()),
                                            url: None,
                                            qr_svg: None,
                                        }).await;
                                    }
                                }
                            } else {
                                let handle = &guard.as_ref().unwrap().0;
                                let _ = ctx.tx.send(api::DaemonEvent::MusicRemoteStarted {
                                    status: "ok".into(),
                                    error: None,
                                    url: Some(handle.url.clone()),
                                    qr_svg: Some(handle.qr_svg.clone()),
                                }).await;
                            }
                        }
                        api::DaemonRequest::MusicRemoteStop => {
                            let mut guard = ctx.music_remote_state.lock().await;
                            if let Some((_, state)) = guard.take() {
                                state.is_active.store(false, Ordering::Relaxed);
                            }
                            let _ = ctx.tx.send(api::DaemonEvent::MusicRemoteStopped).await;
                        }
                    }
}

async fn handle_cliphist_list(
    state: cliphist::SharedState,
    ocr_sem: std::sync::Arc<tokio::sync::Semaphore>,
    tx: tokio::sync::mpsc::Sender<crate::api::DaemonEvent>,
) {
    let state_for_list = state.clone();
    let res = tokio::task::spawn_blocking(move || cliphist::get_history(&state_for_list)).await;

    let (items, jobs) = match res {
        Ok(Ok(v)) => v,
        Ok(Err(e)) => {
            eprintln!("cliphist list error: {e}");
            (Vec::new(), Vec::new())
        }
        Err(e) => {
            eprintln!("cliphist list join error: {e}");
            (Vec::new(), Vec::new())
        }
    };

    let _ = tx.send(api::DaemonEvent::CliphistListResult { items }).await;

    // Kick off any pending OCR passes. They are serialized by the semaphore so
    // only one tesseract process runs at a time; results stream back as they
    // finish and are cached persistently for future opens.
    for job in jobs {
        let sem = ocr_sem.clone();
        let st = state.clone();
        let tx = tx.clone();
        tokio::spawn(async move {
            let _permit = match sem.acquire().await {
                Ok(p) => p,
                Err(_) => return,
            };
            let path = job.image_path.clone();
            let ocr = tokio::task::spawn_blocking(move || cliphist::run_ocr(&path))
                .await
                .ok()
                .flatten();
            match ocr {
                Some(text) => {
                    cliphist::store_ocr(&st, &job.hash, &text);
                    let _ = tx
                        .send(api::DaemonEvent::CliphistOcrUpdate {
                            id: job.id,
                            search_text: text.to_lowercase(),
                            ocr_text: text,
                        })
                        .await;
                }
                None => cliphist::clear_in_progress(&st, &job.hash),
            }
        });
    }
}

async fn handle_math(query: String, out: Option<String>, color: Option<String>, tx: tokio::sync::mpsc::Sender<crate::api::DaemonEvent>) {
    let res = tokio::task::spawn_blocking(move || {
        math::process_query(&query, out.as_deref(), color.as_deref(), None)
    }).await.unwrap();

    match res {
        Ok((content, path)) => {
            let _ = tx.send(api::DaemonEvent::MathResult {
                status: "ok".into(),
                error: None,
                svg_file: path,
                svg_content: Some(content),
            }).await;
        }
        Err(e) => {
            let _ = tx.send(api::DaemonEvent::MathResult {
                status: "error".into(),
                error: Some(e.to_string()),
                svg_file: None,
                svg_content: None,
            }).await;
        }
    }
}
