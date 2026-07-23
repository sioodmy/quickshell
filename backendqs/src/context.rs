use std::sync::Arc;

#[derive(Clone)]
pub struct AppContext {
    pub tx: tokio::sync::mpsc::Sender<crate::api::DaemonEvent>,
    pub client: reqwest::Client,
    pub notes_dir: std::path::PathBuf,
    pub frecency_state: Arc<std::sync::Mutex<crate::frecency::FrecencyState>>,
    pub file_index: crate::filesearch::FileIndex,
    pub bookmark_index: crate::bookmarks::BookmarkIndex,
    pub file_search_generation: Arc<std::sync::atomic::AtomicU64>,
    pub cliphist_state: crate::cliphist::SharedState,
    pub ocr_sem: Arc<tokio::sync::Semaphore>,
    pub file_share: Arc<tokio::sync::Mutex<Option<crate::fileshare::FileShareHandle>>>,
    pub file_share_progress_active: Arc<std::sync::atomic::AtomicBool>,
    pub music_remote_state: Arc<tokio::sync::Mutex<Option<(crate::music_remote::MusicRemoteHandle, Arc<crate::music_remote::MusicRemoteState>)>>>,
}
