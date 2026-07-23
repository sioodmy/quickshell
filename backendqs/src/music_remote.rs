use axum::{
    extract::{Path, State},
    response::{Html, IntoResponse, Json},
    routing::{get, post},
    Router,
};
use serde::Serialize;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use uuid::Uuid;
use crate::music;

pub struct MusicRemoteState {
    pub token: String,
    pub is_active: AtomicBool,
    pub client_connected: AtomicBool,
}

#[derive(Serialize)]
pub struct RemoteStateDto {
    pub playing: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_us: i64,
    pub position_us: i64,
    pub loop_album: bool,
    pub has_player: bool,
    pub art_url: String,
}

pub struct MusicRemoteHandle {
    pub url: String,
    pub qr_svg: String,
}

pub async fn start_server() -> anyhow::Result<(MusicRemoteHandle, Arc<MusicRemoteState>)> {
    let token = Uuid::new_v4().to_string();
    
    let local_ip = detect_local_ip().unwrap_or_else(|| "127.0.0.1".to_string());
    
    let port = 45455;
    let url = format!("http://{}:{}/remote/{}", local_ip, port, token);

    let qr_code = qrcode::QrCode::new(url.as_bytes())?;
    let qr_svg = qr_code.render::<qrcode::render::svg::Color>()
        .min_dimensions(200, 200)
        .dark_color(qrcode::render::svg::Color("#1c1b1f"))
        .light_color(qrcode::render::svg::Color("#ffffff"))
        .build();

    let state = Arc::new(MusicRemoteState {
        token: token.clone(),
        is_active: AtomicBool::new(true),
        client_connected: AtomicBool::new(false),
    });

    let app = Router::new()
        .route("/remote/{token}", get(serve_ui))
        .route("/remote/{token}/state", get(get_state))
        .route("/remote/{token}/library", get(get_library))
        .route("/remote/{token}/cover/{index}", get(get_cover))
        .route("/remote/{token}/current_art", get(get_current_art))
        .route("/remote/{token}/lyrics", get(get_lyrics))
        .route("/remote/{token}/cmd/{action}", post(cmd_action))
        .route("/remote/{token}/seek", post(seek_action))
        .with_state(state.clone());

    tokio::spawn(async move {
        let addr = format!("0.0.0.0:{}", port);
        if let Ok(listener) = tokio::net::TcpListener::bind(&addr).await {
            let _ = axum::serve(listener, app).await;
        }
    });

    let state_clone = state.clone();
    tokio::spawn(async move {
        let mut idle_minutes = 0;
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
            if !state_clone.is_active.load(Ordering::Relaxed) {
                break;
            }
            let playing = music::PLAYER.get()
                .map(|p| p.state.lock().unwrap().playing)
                .unwrap_or(false);
            
            if !playing {
                idle_minutes += 1;
                if idle_minutes >= 15 {
                    state_clone.is_active.store(false, Ordering::Relaxed);
                    break;
                }
            } else {
                idle_minutes = 0;
            }
        }
    });

    Ok((MusicRemoteHandle { url, qr_svg }, state))
}

async fn serve_ui(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return Html("Not Found or inactive".to_string());
    }
    state.client_connected.store(true, Ordering::Relaxed);
    Html(html_page(&token))
}

async fn seek_action(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
    axum::extract::Query(query): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return axum::http::StatusCode::NOT_FOUND.into_response();
    }
    if let Some(pct_str) = query.get("pct") {
        if let Ok(pct) = pct_str.parse::<f64>() {
            let pct = pct.clamp(0.0, 1.0);
            if let Some(p) = crate::music::PLAYER.get() {
                let dur = p.state.lock().unwrap().duration_us as f64;
                if dur > 0.0 {
                    let pos_secs = (dur * pct) / 1_000_000.0;
                    p.seek(pos_secs);
                }
            }
        }
    }
    axum::http::StatusCode::OK.into_response()
}

async fn cmd_action(
    Path((token, action)): Path<(String, String)>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return Json("error");
    }

    if let Some(player) = music::PLAYER.get() {
        match action.as_str() {
            "play" => player.resume(),
            "pause" => player.pause(),
            "next" => player.next(),
            "prev" => player.previous(),
            "loop" => player.toggle_loop(),
            _ => {
                if action.starts_with("play_album_") {
                    let parts: Vec<&str> = action.split('_').collect();
                    if parts.len() == 4 {
                        if let (Ok(album_idx), Ok(track_idx)) = (parts[2].parse::<usize>(), parts[3].parse::<usize>()) {
                            if let Ok(lib) = music::scan_library() {
                                if let Some(album) = lib.albums.get(album_idx) {
                                    let paths = album.tracks.iter().map(|t| t.path.clone()).collect();
                                    player.play_album(paths, track_idx);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Json("ok")
}

async fn get_state(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return Json(RemoteStateDto {
            playing: false, title: String::new(), artist: String::new(), album: String::new(),
            duration_us: 0, position_us: 0, loop_album: false, has_player: false, art_url: String::new(),
        });
    }

    if let Some(player) = music::PLAYER.get() {
        let pstate = player.state.lock().unwrap();
        Json(RemoteStateDto {
            playing: pstate.playing,
            title: pstate.title.clone(),
            artist: pstate.artist.clone(),
            album: pstate.album.clone(),
            duration_us: pstate.duration_us,
            position_us: pstate.live_position_us(),
            loop_album: pstate.loop_album,
            has_player: !pstate.title.is_empty(),
            art_url: pstate.art_url.clone(),
        })
    } else {
        Json(RemoteStateDto {
            playing: false, title: String::new(), artist: String::new(), album: String::new(),
            duration_us: 0, position_us: 0, loop_album: false, has_player: false, art_url: String::new(),
        })
    }
}

async fn get_library(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return Json(music::Library { albums: vec![] });
    }
    Json(music::scan_library().unwrap_or(music::Library { albums: vec![] }))
}

async fn get_cover(
    Path((token, index)): Path<(String, usize)>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return (axum::http::StatusCode::NOT_FOUND, vec![]).into_response();
    }
    let lib = match music::scan_library() {
        Ok(l) => l,
        Err(_) => return (axum::http::StatusCode::NOT_FOUND, vec![]).into_response(),
    };
    if let Some(album) = lib.albums.get(index) {
        if let Some(ref path) = album.cover_path {
            if let Ok(data) = std::fs::read(path) {
                let mime = if path.ends_with(".png") { "image/png" } else { "image/jpeg" };
                return ([(axum::http::header::CONTENT_TYPE, mime)], data).into_response();
            }
        }
    }
    (axum::http::StatusCode::NOT_FOUND, vec![]).into_response()
}

async fn get_current_art(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return (axum::http::StatusCode::NOT_FOUND, vec![]).into_response();
    }
    if let Some(player) = music::PLAYER.get() {
        let pstate = player.state.lock().unwrap();
        let art_url = pstate.art_url.clone();
        if art_url.starts_with("file://") {
            let path = art_url.trim_start_matches("file://");
            if let Ok(data) = std::fs::read(path) {
                let mime = if path.ends_with(".png") { "image/png" } else { "image/jpeg" };
                return ([(axum::http::header::CONTENT_TYPE, mime)], data).into_response();
            }
        }
    }
    (axum::http::StatusCode::NOT_FOUND, vec![]).into_response()
}

async fn get_lyrics(
    Path(token): Path<String>,
    State(state): State<Arc<MusicRemoteState>>,
) -> impl IntoResponse {
    if token != state.token || !state.is_active.load(Ordering::Relaxed) {
        return Json(serde_json::json!({"lyrics": ""}));
    }

    if let Some(player) = music::PLAYER.get() {
        let (artist, title) = {
            let st = player.state.lock().unwrap();
            (st.artist.clone(), st.title.clone())
        };
        if artist.is_empty() || title.is_empty() {
            return Json(serde_json::json!({"lyrics": ""}));
        }
        
        let cache_dir = std::env::var("HOME").map(|h| std::path::PathBuf::from(h).join(".cache").join("quickshell").join("lyrics"))
            .unwrap_or_else(|_| std::path::PathBuf::from("/tmp/quickshell_lyrics"));
        let filename = format!("{}-{}.lrc", artist.replace(|c: char| !c.is_alphanumeric(), "_"), title.replace(|c: char| !c.is_alphanumeric(), "_"));
        let cache_file = cache_dir.join(&filename);
        
        if let Ok(content) = std::fs::read_to_string(&cache_file) {
            return Json(serde_json::json!({"lyrics": content}));
        }
    }
    Json(serde_json::json!({"lyrics": ""}))
}

fn html_page(token: &str) -> String {
    format!(r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Quickshell Music Remote</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;700&family=JetBrains+Mono:wght@400;700&display=swap');
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        html, body {{ height: 100%; }}
        body {{
            font-family: "Google Sans", system-ui, -apple-system, sans-serif;
            color: #e6e1e5;
            background: #1c1b1f;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }}
        .player-section {{
            flex-shrink: 0;
            background: #1c1b1f;
            z-index: 10;
            box-shadow: 0 4px 20px rgba(0,0,0,0.5);
            border-bottom-left-radius: 32px;
            border-bottom-right-radius: 32px;
            padding-bottom: 24px;
        }}
        .header {{
            padding: 24px 24px 12px;
            display: flex;
            align-items: center;
            gap: 16px;
        }}
        .album-art-placeholder {{
            width: 80px;
            height: 80px;
            border-radius: 16px;
            background: #49454f;
            display: grid;
            place-items: center;
            font-size: 32px;
            color: #cac4d0;
            flex-shrink: 0;
            overflow: hidden;
            position: relative;
            background-size: cover;
            background-position: center;
        }}
        .album-art-placeholder.empty::after {{
            content: "♪";
        }}
        .meta {{
            flex: 1;
            min-width: 0;
        }}
        .title {{
            font-size: 22px;
            font-weight: 500;
            color: #e6e1e5;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            margin-bottom: 4px;
        }}
        .artist {{
            font-size: 15px;
            color: #cac4d0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }}
        .controls-container {{
            padding: 16px 24px 0;
            display: flex;
            flex-direction: column;
            align-items: center;
        }}
        .progress-container {{
            width: 100%;
            max-width: 400px;
            margin-bottom: 16px;
        }}
        .progress-bar {{
            height: 8px;
            background: #49454f;
            border-radius: 4px;
            position: relative;
            margin-bottom: 8px;
            cursor: pointer;
        }}
        .progress-fill {{
            position: absolute;
            left: 0;
            top: 0;
            height: 100%;
            background: #d0bcff;
            border-radius: 4px;
            width: 0%;
        }}
        .progress-handle {{
            position: absolute;
            top: 50%;
            right: 0;
            transform: translate(50%, -50%);
            width: 16px;
            height: 16px;
            border-radius: 50%;
            background: #d0bcff;
            box-shadow: 0 0 10px rgba(208, 188, 255, 0.4);
        }}
        .time-row {{
            display: flex;
            justify-content: space-between;
            font-size: 13px;
            color: #cac4d0;
        }}
        .buttons-row {{
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 16px;
        }}
        .btn {{
            border: none;
            background: transparent;
            color: #e6e1e5;
            width: 52px;
            height: 52px;
            border-radius: 26px;
            display: grid;
            place-items: center;
            font-size: 24px;
            cursor: pointer;
            transition: background 0.15s, transform 0.15s;
            fill: #e6e1e5;
        }}
        .btn:active {{
            background: rgba(230, 225, 229, 0.08);
            transform: scale(0.92);
        }}
        .btn.play-pause {{
            width: 64px;
            height: 64px;
            border-radius: 32px;
            background: #d0bcff;
            fill: #381e72;
        }}
        .btn.play-pause:active {{
            background: #b69df8;
            transform: scale(0.92);
        }}
        .btn.loop.active {{
            fill: #d0bcff;
            background: rgba(208, 188, 255, 0.12);
        }}
        .tabs-row {{
            display: flex;
            margin-bottom: 16px;
            border-bottom: 1px solid #49454f;
        }}
        .tab-btn {{
            flex: 1;
            padding: 12px;
            background: none;
            border: none;
            color: #cac4d0;
            font-size: 16px;
            font-weight: 500;
            cursor: pointer;
            border-bottom: 2px solid transparent;
        }}
        .tab-btn.active {{
            color: #d0bcff;
            border-bottom: 2px solid #d0bcff;
        }}
        .content-section {{
            flex: 1;
            overflow-y: auto;
            background: #141218;
            padding: 16px;
            display: none;
        }}
        .content-section.active {{
            display: block;
        }}
        .search-input {{
            width: 100%;
            padding: 12px 16px;
            border-radius: 24px;
            background: #2b2930;
            border: none;
            color: #e6e1e5;
            font-size: 16px;
            margin-bottom: 16px;
            outline: none;
        }}
        .search-input::placeholder {{
            color: #cac4d0;
        }}
        .album-card {{
            background: #2b2930;
            border-radius: 20px;
            padding: 16px;
            margin-bottom: 16px;
            display: flex;
            flex-direction: column;
            gap: 16px;
        }}
        .album-card-header {{
            display: flex;
            gap: 16px;
            align-items: center;
            cursor: pointer;
        }}
        .album-cover {{
            width: 72px;
            height: 72px;
            border-radius: 12px;
            background: #49454f;
            object-fit: cover;
        }}
        .album-info {{
            flex: 1;
            min-width: 0;
        }}
        .album-title {{
            font-size: 18px;
            font-weight: 500;
            color: #e6e1e5;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            margin-bottom: 4px;
        }}
        .album-artist {{
            font-size: 14px;
            color: #cac4d0;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }}
        .track-list {{
            display: flex;
            flex-direction: column;
            gap: 4px;
        }}
        .track-item {{
            padding: 12px 16px;
            border-radius: 12px;
            background: rgba(255, 255, 255, 0.03);
            display: flex;
            align-items: center;
            gap: 12px;
            cursor: pointer;
            transition: background 0.15s;
        }}
        .track-item:active {{
            background: rgba(208, 188, 255, 0.15);
        }}
        .track-num {{
            font-size: 14px;
            color: #cac4d0;
            width: 20px;
            text-align: right;
        }}
        .track-title {{
            font-size: 15px;
            color: #e6e1e5;
            flex: 1;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }}
        .lyrics-container {{
            text-align: left;
            font-size: 24px;
            font-weight: 700;
            line-height: 1.4;
            color: rgba(255, 255, 255, 0.3);
            padding: 24px 16px 120px;
        }}
        .lyrics-line {{
            margin-bottom: 20px;
            transition: color 0.3s;
        }}
        .lyrics-line.active {{
            color: #ffffff;
        }}
    </style>
</head>
<body>
    <div class="player-section">
        <div class="header">
            <div class="album-art-placeholder empty" id="main-art"></div>
            <div class="meta">
                <div class="title" id="title">Not Playing</div>
                <div class="artist" id="artist"></div>
            </div>
        </div>
        
        <div class="controls-container">
            <div class="progress-container">
                <div class="progress-bar" id="progress-bar">
                    <div class="progress-fill" id="progress-fill"><div class="progress-handle"></div></div>
                </div>
                <div class="time-row">
                    <span id="pos">0:00</span>
                    <span id="dur">0:00</span>
                </div>
            </div>
            
            <div class="buttons-row">
                <button class="btn loop" id="btn-loop">
                    <svg width="24" height="24" viewBox="0 0 24 24"><path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z"/></svg>
                </button>
                <button class="btn" id="btn-prev">
                    <svg width="24" height="24" viewBox="0 0 24 24"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>
                </button>
                <button class="btn play-pause" id="btn-play">
                    <svg width="32" height="32" viewBox="0 0 24 24" id="icon-play" style="display:none;"><path d="M8 5v14l11-7z"/></svg>
                    <svg width="32" height="32" viewBox="0 0 24 24" id="icon-pause"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
                </button>
                <button class="btn" id="btn-next">
                    <svg width="24" height="24" viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>
                </button>
            </div>
        </div>
    </div>
    
    <div style="background: #141218; flex: 1; display: flex; flex-direction: column; overflow: hidden; min-height: 0;">
        <div class="tabs-row">
            <button class="tab-btn active" id="tab-library" onclick="switchTab('library')">Library</button>
            <button class="tab-btn" id="tab-lyrics" onclick="switchTab('lyrics')">Lyrics</button>
        </div>
        
        <div class="content-section active" id="sec-library">
            <input type="text" id="search-input" class="search-input" placeholder="Search albums or artists...">
            <div id="albums-container">
                <div style="color: #cac4d0; padding-left: 8px;">Loading...</div>
            </div>
        </div>

        <div class="content-section" id="sec-lyrics">
            <div class="lyrics-container" id="lyrics-container">
                No lyrics found
            </div>
        </div>
    </div>

    <script>
        const token = "{token}";
        let playing = false;
        let lastTitle = "";
        let parsedLyrics = [];

        function formatTime(us) {{
            let secs = Math.floor(us / 1000000);
            if (isNaN(secs) || secs < 0) return "0:00";
            let m = Math.floor(secs / 60);
            let s = Math.floor(secs % 60);
            return m + ":" + (s < 10 ? "0" : "") + s;
        }}

        function switchTab(tab) {{
            document.getElementById('tab-library').classList.toggle('active', tab === 'library');
            document.getElementById('tab-lyrics').classList.toggle('active', tab === 'lyrics');
            document.getElementById('sec-library').classList.toggle('active', tab === 'library');
            document.getElementById('sec-lyrics').classList.toggle('active', tab === 'lyrics');
        }}

        async function cmd(action) {{
            await fetch(`/remote/${{token}}/cmd/${{action}}`, {{ method: 'POST' }});
            updateState();
        }}

        document.getElementById('btn-loop').onclick = () => cmd('loop');
        document.getElementById('btn-prev').onclick = () => cmd('prev');
        document.getElementById('btn-play').onclick = () => cmd(playing ? 'pause' : 'play');
        document.getElementById('btn-next').onclick = () => cmd('next');
        
        let pbar = document.getElementById('progress-bar');
        pbar.onclick = async (e) => {{
            let rect = pbar.getBoundingClientRect();
            let pct = (e.clientX - rect.left) / rect.width;
            await fetch(`/remote/${{token}}/seek?pct=${{pct}}`, {{ method: 'POST' }});
            updateState();
        }};

        document.getElementById('search-input').addEventListener('input', function(e) {{
            let q = e.target.value.toLowerCase();
            let cards = document.querySelectorAll('.album-card');
            cards.forEach(c => {{
                let text = c.innerText.toLowerCase();
                c.style.display = text.includes(q) ? 'flex' : 'none';
            }});
        }});

        let lastArtUrl = "";

        async function updateState() {{
            try {{
                let res = await fetch(`/remote/${{token}}/state`);
                let state = await res.json();
                
                document.getElementById('title').innerText = state.title || "Not Playing";
                document.getElementById('artist').innerText = state.artist || "";
                
                if (state.title !== lastTitle) {{
                    lastTitle = state.title;
                    loadLyrics();
                }}
                
                playing = state.playing;
                document.getElementById('icon-play').style.display = playing ? 'none' : 'block';
                document.getElementById('icon-pause').style.display = playing ? 'block' : 'none';
                
                document.getElementById('pos').innerText = formatTime(state.position_us);
                document.getElementById('dur').innerText = formatTime(state.duration_us);
                
                let pct = state.duration_us > 0 ? (state.position_us / state.duration_us) * 100 : 0;
                document.getElementById('progress-fill').style.width = pct + "%";
                document.getElementById('btn-loop').classList.toggle('active', state.loop_album);
                
                if (state.art_url !== lastArtUrl) {{
                    lastArtUrl = state.art_url;
                    let artEl = document.getElementById('main-art');
                    if (state.art_url) {{
                        artEl.style.backgroundImage = `url('/remote/${{token}}/current_art?_t=${{Date.now()}}')`;
                        artEl.classList.remove('empty');
                    }} else {{
                        artEl.style.backgroundImage = '';
                        artEl.classList.add('empty');
                    }}
                }}

                // update lyrics sync
                if (parsedLyrics.length > 0) {{
                    let sec = state.position_us / 1000000;
                    let activeIdx = -1;
                    for (let i = 0; i < parsedLyrics.length; i++) {{
                        if (parsedLyrics[i].time <= sec) {{
                            activeIdx = i;
                        }} else {{
                            break;
                        }}
                    }}
                    
                    let lines = document.querySelectorAll('.lyrics-line');
                    lines.forEach((l, i) => {{
                        if (i === activeIdx) {{
                            if (!l.classList.contains('active')) {{
                                l.classList.add('active');
                                l.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
                            }}
                        }} else {{
                            l.classList.remove('active');
                        }}
                    }});
                }}

            }} catch (e) {{}}
        }}

        async function loadLyrics() {{
            try {{
                let res = await fetch(`/remote/${{token}}/lyrics`);
                let data = await res.json();
                let txt = data.lyrics;
                parsedLyrics = [];
                let html = "";
                
                if (!txt || txt.trim() === "") {{
                    document.getElementById('lyrics-container').innerHTML = "No lyrics found";
                    return;
                }}
                
                let lines = txt.split(/\r?\n/);
                let rgx = /^\[(\d+):(\d+\.?\d*)\](.*)/;
                lines.forEach(l => {{
                    let m = rgx.exec(l);
                    if (m) {{
                        let m_part = parseInt(m[1]);
                        let s_part = parseFloat(m[2]);
                        let time = m_part * 60 + s_part;
                        let text = m[3].trim();
                        if (text) {{
                            parsedLyrics.push({{ time, text }});
                        }}
                    }}
                }});
                
                if (parsedLyrics.length > 0) {{
                    parsedLyrics.forEach((l, i) => {{
                        html += `<div class="lyrics-line" id="lyric-${{i}}">${{l.text}}</div>`;
                    }});
                }} else {{
                    html = lines.join('<br>');
                }}
                
                document.getElementById('lyrics-container').innerHTML = html;
            }} catch(e) {{
                document.getElementById('lyrics-container').innerHTML = "No lyrics found";
            }}
        }}

        function toggleAlbum(el) {{
            let list = el.nextElementSibling;
            if (list.style.display === 'none') {{
                list.style.display = 'flex';
            }} else {{
                list.style.display = 'none';
            }}
        }}

        async function loadLibrary() {{
            try {{
                let res = await fetch(`/remote/${{token}}/library`);
                let lib = await res.json();
                let html = "";
                if (lib.albums.length === 0) {{
                    html = `<div style="color: #cac4d0; padding-left: 8px;">No music found.</div>`;
                }} else {{
                    lib.albums.forEach((album, i) => {{
                        html += `<div class="album-card">
                            <div class="album-card-header" onclick="toggleAlbum(this)">
                                <div style="width: 72px; height: 72px; border-radius: 12px; background: #49454f; display: grid; place-items: center; font-size: 28px; color: #cac4d0; flex-shrink: 0; overflow: hidden; position: relative;">
                                    <span>♪</span>
                                    <img src="/remote/${{token}}/cover/${{i}}" style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; z-index: 1;" onerror="this.style.display='none'">
                                </div>
                                <div class="album-info">
                                    <div class="album-title">${{album.title}}</div>
                                    <div class="album-artist">${{album.artist}}</div>
                                </div>
                            </div>
                            <div class="track-list" style="display: none;">`;
                        album.tracks.forEach((track, j) => {{
                            html += `<div class="track-item" onclick="cmd('play_album_${{i}}_${{j}}')">
                                <div class="track-num">${{track.track_number || j+1}}</div>
                                <div class="track-title">${{track.title}}</div>
                            </div>`;
                        }});
                        html += `</div></div>`;
                    }});
                }}
                document.getElementById('albums-container').innerHTML = html;
            }} catch (e) {{
                document.getElementById('albums-container').innerHTML = `<div style="color: #f2b8b5; padding-left: 8px;">Failed to load library.</div>`;
            }}
        }}

        setInterval(updateState, 1000);
        updateState();
        loadLibrary();
        loadLyrics();
    </script>
</body>
</html>"#, token=token)
}

fn detect_local_ip() -> Option<String> {
    let socket = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:80").ok()?;
    let addr = socket.local_addr().ok()?;
    match addr.ip() {
        std::net::IpAddr::V4(v4) if !v4.is_loopback() => Some(v4.to_string()),
        _ => None,
    }
}
