use anyhow::{anyhow, Context, Result};
use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, StatusCode},
    response::{Html, IntoResponse, Response},
    routing::get,
    Router,
};
use futures::StreamExt;
use qrcode::QrCode;
use serde::Serialize;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::{Path as FsPath, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;
use tokio_util::io::ReaderStream;
use uuid::Uuid;

pub const MAX_SHARES: usize = 1;
const STALE_WAIT_TIMEOUT: Duration = Duration::from_secs(5 * 60);
const COMPLETE_RETENTION: Duration = Duration::from_secs(20);

#[derive(Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ShareStatus {
    Waiting,
    Downloading,
    Complete,
    Cancelled,
}

#[derive(Serialize, Clone)]
pub struct ShareInfo {
    pub id: String,
    pub path: String,
    pub name: String,
    pub size: u64,
    pub bytes_sent: u64,
    pub status: ShareStatus,
    pub url: String,
}

#[derive(Serialize)]
pub struct ShareStarted {
    pub id: String,
    pub url: String,
    pub qr_svg: String,
    pub name: String,
    pub size: u64,
}

struct ShareEntry {
    path: PathBuf,
    name: String,
    size: u64,
    bytes_sent: Arc<AtomicU64>,
    status: ShareStatus,
    cancelled: Arc<std::sync::atomic::AtomicBool>,
    created_at: Instant,
    completed_at: Option<Instant>,
}

#[derive(Clone)]
struct AppState {
    token: String,
    shares: Arc<RwLock<HashMap<String, ShareEntry>>>,
}

pub struct FileShareHandle {
    port: u16,
    local_ip: String,
    token: String,
    shares: Arc<RwLock<HashMap<String, ShareEntry>>>,
    _shutdown_tx: tokio::sync::oneshot::Sender<()>,
}

impl FileShareHandle {


    fn make_url(&self, share_id: &str) -> String {
        format!(
            "http://{}:{}/s/{}/{}",
            self.local_ip, self.port, self.token, share_id
        )
    }

    pub async fn add_share(&self, path: &str) -> Result<ShareStarted> {
        let canonical = validate_file_path(path)?;
        let meta = std::fs::metadata(&canonical).context("read file metadata")?;
        let size = meta.len();
        let name = canonical
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("download")
            .to_string();

        {
            let shares = self.shares.read().await;
            if shares.len() >= MAX_SHARES {
                return Err(anyhow!("too many active shares (max {MAX_SHARES})"));
            }
        }

        let share_id = Uuid::new_v4().simple().to_string();
        let url = self.make_url(&share_id);

        let entry = ShareEntry {
            path: canonical,
            name: name.clone(),
            size,
            bytes_sent: Arc::new(AtomicU64::new(0)),
            status: ShareStatus::Waiting,
            cancelled: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            created_at: Instant::now(),
            completed_at: None,
        };

        self.shares
            .write()
            .await
            .insert(share_id.clone(), entry);

        let qr_svg = generate_qr_svg(&url)?;

        Ok(ShareStarted {
            id: share_id,
            url,
            qr_svg,
            name,
            size,
        })
    }

    pub async fn remove_share(&self, id: &str) -> bool {
        let mut shares = self.shares.write().await;
        if let Some(entry) = shares.get_mut(id) {
            entry.cancelled.store(true, Ordering::Relaxed);
            entry.status = ShareStatus::Cancelled;
            shares.remove(id);
            return true;
        }
        false
    }

    pub async fn remove_all(&self) {
        let mut shares = self.shares.write().await;
        for (_, entry) in shares.iter_mut() {
            entry.cancelled.store(true, Ordering::Relaxed);
            entry.status = ShareStatus::Cancelled;
        }
        shares.clear();
    }

    pub async fn list_shares(&self) -> Vec<ShareInfo> {
        let shares = self.shares.read().await;
        shares
            .iter()
            .map(|(id, e)| {
                let sent = e.bytes_sent.load(Ordering::Relaxed);
                let status = if e.status == ShareStatus::Downloading && sent >= e.size {
                    ShareStatus::Complete
                } else {
                    e.status
                };
                ShareInfo {
                    id: id.clone(),
                    path: e.path.display().to_string(),
                    name: e.name.clone(),
                    size: e.size,
                    bytes_sent: sent,
                    status,
                    url: self.make_url(id),
                }
            })
            .collect()
    }


}

pub async fn start_server() -> Result<FileShareHandle> {
    let local_ip = detect_local_ip().unwrap_or_else(|| "127.0.0.1".to_string());
    let token: String = Uuid::new_v4().simple().to_string();
    let shares: Arc<RwLock<HashMap<String, ShareEntry>>> = Arc::new(RwLock::new(HashMap::new()));
    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();

    let state = AppState {
        token: token.clone(),
        shares: shares.clone(),
    };

    let app = Router::new()
        .route("/s/{token}/{id}", get(share_page))
        .route("/s/{token}/{id}/dl", get(share_download))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(SocketAddr::from(([0, 0, 0, 0], 45454)))
        .await
        .context("bind file share server")?;
    let port = listener.local_addr()?.port();

    tokio::spawn(async move {
        let server = axum::serve(listener, app);
        tokio::select! {
            res = server => {
                if let Err(e) = res {
                    eprintln!("file share server error: {e}");
                }
            }
            _ = shutdown_rx => {}
        }
    });

    // Remove stale waiting shares and finished shares after a short retention.
    {
        let shares = shares.clone();
        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_secs(15));
            loop {
                ticker.tick().await;
                let now = Instant::now();
                let mut shares_guard = shares.write().await;
                shares_guard.retain(|_, entry| {
                    if entry.cancelled.load(Ordering::Relaxed) {
                        return false;
                    }
                    match entry.status {
                        ShareStatus::Waiting => now.duration_since(entry.created_at) < STALE_WAIT_TIMEOUT,
                        ShareStatus::Complete => entry
                            .completed_at
                            .map(|t| now.duration_since(t) < COMPLETE_RETENTION)
                            .unwrap_or(false),
                        ShareStatus::Downloading => true,
                        ShareStatus::Cancelled => false,
                    }
                });
            }
        });
    }

    Ok(FileShareHandle {
        port,
        local_ip,
        token,
        shares,
        _shutdown_tx: shutdown_tx,
    })
}

fn constant_time_eq(a: &str, b: &str) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut result = 0;
    for (x, y) in a.bytes().zip(b.bytes()) {
        result |= x ^ y;
    }
    result == 0
}

fn validate_file_path(path: &str) -> Result<PathBuf> {
    let p = FsPath::new(path);
    if !p.is_absolute() {
        return Err(anyhow!("path must be absolute"));
    }
    let canonical = p.canonicalize().context("file not found")?;
    if !canonical.is_file() {
        return Err(anyhow!("not a regular file"));
    }
    let home = std::env::var("HOME").map(PathBuf::from).unwrap_or_default();
    if !home.as_os_str().is_empty() {
        let home_canon = home.canonicalize().unwrap_or(home);
        if !canonical.starts_with(&home_canon) {
            return Err(anyhow!("file outside home directory"));
        }
    }
    Ok(canonical)
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

fn generate_qr_svg(url: &str) -> Result<String> {
    let code = QrCode::new(url.as_bytes()).context("qr encode")?;
    let image = code
        .render::<qrcode::render::svg::Color>()
        .min_dimensions(200, 200)
        .dark_color(qrcode::render::svg::Color("#1c1b1f"))
        .light_color(qrcode::render::svg::Color("#ffffff"))
        .build();
    Ok(image)
}

fn html_page(name: &str, size_label: &str, download_url: &str, qr_svg: &str) -> String {
    format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{name}</title>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{height:100%}}
body{{font-family:system-ui,-apple-system,"Google Sans",Roboto,sans-serif;color:#e6e1e5;min-height:100dvh;display:flex;align-items:center;justify-content:center;padding:24px;overflow-x:hidden;background:#f5bde6}}
.bg{{position:fixed;inset:0;z-index:-2;background:#f5bde6}}
.orb{{position:absolute;border-radius:9999px;transform:translate3d(0,0,0)}}
.orb.one{{width:56vmax;height:56vmax;left:-8vmax;top:-10vmax;background:rgba(255,255,255,.40);animation:floatOne 8s ease-in-out infinite alternate}}
.orb.two{{width:52vmax;height:52vmax;right:-10vmax;top:-9vmax;background:rgba(198,160,246,.55);animation:floatTwo 10s ease-in-out infinite alternate}}
.orb.three{{width:34vmax;height:34vmax;left:14vmax;bottom:-9vmax;background:rgba(245,194,231,.35);animation:floatThree 12s ease-in-out infinite alternate}}
@keyframes floatOne{{0%{{transform:translate(0,0) rotate(0deg)}}100%{{transform:translate(12vmax,10vmax) rotate(22deg)}}}}
@keyframes floatTwo{{0%{{transform:translate(0,0) rotate(0deg)}}100%{{transform:translate(-14vmax,14vmax) rotate(-25deg)}}}}
@keyframes floatThree{{0%{{transform:translate(0,0)}}100%{{transform:translate(10vmax,-12vmax)}}}}
.scrim{{position:fixed;inset:0;z-index:-1;background:linear-gradient(180deg,rgba(18,16,26,.18),rgba(18,16,26,.06) 45%,rgba(18,16,26,.28))}}
.card{{background:#1c1b1f;border:1px solid #2b2930;border-radius:28px;padding:24px;max-width:420px;width:100%;box-shadow:0 10px 20px rgba(0,0,0,.31);text-align:center}}
.qr{{display:grid;place-items:center;width:180px;height:180px;margin:2px auto 14px;border-radius:22px;background:#fff;box-shadow:inset 0 0 0 1px #2b2930}}
.qr svg{{width:152px;height:152px}}
h1{{font-size:22px;font-weight:600;margin-bottom:3px;word-break:break-word;color:#e6e1e5}}
.meta{{font-size:13px;color:#cac4d0;margin-bottom:16px}}
.actions{{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}}
.btn{{display:inline-flex;align-items:center;justify-content:center;gap:8px;border:0;cursor:pointer;background:#6750a4;color:#fff;text-decoration:none;padding:11px 18px;border-radius:12px;font-size:14px;font-weight:600;transition:transform .12s ease,background .15s ease,box-shadow .15s ease;box-shadow:0 4px 12px rgba(0,0,0,.15)}}
.btn:hover{{transform:translateY(-1px);background:#5a3c91}}
.btn.secondary{{background:#36343b;color:#e6e1e5;box-shadow:inset 0 0 0 1px #49454f}}
.btn.secondary:hover{{background:#49454f}}
.status{{margin-top:10px;min-height:16px;font-size:13px;color:#cac4d0}}
.footer{{margin-top:14px;font-size:11px;color:#cac4d0;opacity:0.6}}
@media (max-width:480px){{
body{{padding:16px}}
.card{{padding:20px;border-radius:24px}}
.qr{{width:150px;height:150px}}
.qr svg{{width:126px;height:126px}}
h1{{font-size:19px}}
.actions{{flex-direction:column;gap:8px}}
.btn{{width:100%;padding:13px 18px}}
}}
</style>
</head>
<body>
<div class="bg">
  <div class="orb one"></div>
  <div class="orb two"></div>
  <div class="orb three"></div>
</div>
<div class="scrim"></div>
<div class="card">
<div class="qr">{qr_svg}</div>
<h1>{name}</h1>
<p class="meta">{size_label}</p>
<div class="actions">
<a class="btn" href="{download_url}" download>Download</a>
<button class="btn secondary" id="copyBtn" type="button">Copy Link</button>
</div>
<p class="status" id="copyStatus"></p>
<p class="footer">Shared via Leninshell</p>
</div>
<script>
const copyBtn = document.getElementById("copyBtn");
const copyStatus = document.getElementById("copyStatus");
copyBtn?.addEventListener("click", async () => {{
  const link = window.location.href;
  try {{
    if (navigator.clipboard && navigator.clipboard.writeText) {{
      await navigator.clipboard.writeText(link);
    }} else {{
      const input = document.createElement("input");
      input.value = link;
      document.body.appendChild(input);
      input.select();
      document.execCommand("copy");
      input.remove();
    }}
    copyStatus.textContent = "Link copied";
  }} catch (_) {{
    copyStatus.textContent = "Copy failed";
  }}
}});
</script>
</body>
</html>"#
    )
}

async fn share_page(
    State(state): State<AppState>,
    Path((token, id)): Path<(String, String)>,
) -> impl IntoResponse {
    if !constant_time_eq(&token, &state.token) {
        return StatusCode::NOT_FOUND.into_response();
    }
    let shares = state.shares.read().await;
    let Some(entry) = shares.get(&id) else {
        return StatusCode::NOT_FOUND.into_response();
    };
    if entry.cancelled.load(Ordering::Relaxed) {
        return StatusCode::GONE.into_response();
    }
    let size_label = format_size(entry.size);
    let download_url = format!("/s/{}/{}/dl", token, id);
    let qr_svg = generate_qr_svg(&download_url).unwrap_or_default();
    Html(html_page(&entry.name, &size_label, &download_url, &qr_svg)).into_response()
}

async fn share_download(
    State(state): State<AppState>,
    Path((token, id)): Path<(String, String)>,
) -> Response {
    if !constant_time_eq(&token, &state.token) {
        return StatusCode::NOT_FOUND.into_response();
    }

    let entry = {
        let mut shares = state.shares.write().await;
        let Some(entry) = shares.get_mut(&id) else {
            return StatusCode::NOT_FOUND.into_response();
        };
        if entry.cancelled.load(Ordering::Relaxed) {
            return StatusCode::GONE.into_response();
        }
        entry.status = ShareStatus::Downloading;
        ShareEntry {
            path: entry.path.clone(),
            name: entry.name.clone(),
            size: entry.size,
            bytes_sent: entry.bytes_sent.clone(),
            status: entry.status,
            cancelled: entry.cancelled.clone(),
            created_at: entry.created_at,
            completed_at: entry.completed_at,
        }
    };

    let file = match tokio::fs::File::open(&entry.path).await {
        Ok(f) => f,
        Err(_) => return StatusCode::NOT_FOUND.into_response(),
    };

    let bytes_sent = entry.bytes_sent.clone();
    let cancelled = entry.cancelled.clone();
    let total = entry.size;

    let stream = ReaderStream::new(file).map(move |result| {
        result.map(|chunk| {
            if !cancelled.load(Ordering::Relaxed) {
                bytes_sent.fetch_add(chunk.len() as u64, Ordering::Relaxed);
            }
            chunk
        })
    });

    let mut resp = Response::new(Body::from_stream(stream));
    *resp.status_mut() = StatusCode::OK;
    let headers = resp.headers_mut();
    headers.insert(
        header::CONTENT_TYPE,
        "application/octet-stream".parse().unwrap(),
    );
    headers.insert(
        header::CONTENT_DISPOSITION,
        format!("attachment; filename=\"{}\"", sanitize_filename(&entry.name))
            .parse()
            .unwrap(),
    );
    if total > 0 {
        headers.insert(header::CONTENT_LENGTH, total.to_string().parse().unwrap());
    }

    // Mark complete once fully sent.
    let shares = state.shares.clone();
    let id_clone = id.clone();
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            let mut shares = shares.write().await;
            if let Some(e) = shares.get_mut(&id_clone) {
                let sent = e.bytes_sent.load(Ordering::Relaxed);
                if sent >= e.size {
                    e.status = ShareStatus::Complete;
                    if e.completed_at.is_none() {
                        e.completed_at = Some(Instant::now());
                    }
                    break;
                }
                if e.cancelled.load(Ordering::Relaxed) {
                    break;
                }
            } else {
                break;
            }
        }
    });

    resp
}

fn sanitize_filename(name: &str) -> String {
    name.chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect()
}

pub fn format_size(bytes: u64) -> String {
    if bytes < 1024 {
        return format!("{bytes} B");
    }
    let kb = bytes as f64 / 1024.0;
    if kb < 1024.0 {
        return format!("{kb:.1} KB");
    }
    let mb = kb / 1024.0;
    if mb < 1024.0 {
        return format!("{mb:.1} MB");
    }
    format!("{:.2} GB", mb / 1024.0)
}
