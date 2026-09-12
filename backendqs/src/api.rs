use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug)]
#[serde(tag = "action")]
pub enum DaemonRequest {
    #[serde(rename = "math")]
    Math {
        query: String,
        out: Option<String>,
        color: Option<String>,
    },
    #[serde(rename = "dictionary")]
    Dictionary { query: String },
    #[serde(rename = "calc")]
    Calc { query: String },
    #[serde(rename = "save_json")]
    SaveJson {
        path: String,
        data: serde_json::Value,
    },
    #[serde(rename = "lyrics")]
    Lyrics { artist: String, title: String },
    #[serde(rename = "lyrics_prefetch")]
    LyricsPrefetch { artist: String, title: String },
    #[serde(rename = "weather_refresh")]
    WeatherRefresh,
    #[serde(rename = "agenda_refresh")]
    AgendaRefresh,
    #[serde(rename = "agenda_toggle_todo")]
    AgendaToggleTodo { file: String, title: String },
    #[serde(rename = "music_library")]
    MusicLibrary,
    #[serde(rename = "music_play_album")]
    MusicPlayAlbum {
        tracks: Vec<String>,
        start_index: usize,
    },
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
    #[serde(rename = "music_set_volume")]
    MusicSetVolume { volume: f32 },
    #[serde(rename = "music_toggle_loop")]
    MusicToggleLoop,
    #[serde(rename = "frecency_load")]
    FrecencyLoad,
    #[serde(rename = "frecency_record")]
    FrecencyRecord { id: String, query: Option<String> },
    #[serde(rename = "file_search")]
    FileSearch { query: String },
    #[serde(rename = "bookmark_search")]
    BookmarkSearch { query: String },
    #[serde(rename = "file_preview")]
    FilePreview { path: String },
    #[serde(rename = "file_open")]
    FileOpen { path: String },
    #[serde(rename = "sysctl_list")]
    SysctlList { kind: String },
    #[serde(rename = "cliphist_list")]
    CliphistList,
    #[serde(rename = "cliphist_copy")]
    CliphistCopy {
        raw: String,
        image_path: Option<String>,
    },
    #[serde(rename = "cliphist_delete")]
    CliphistDelete { raw: String },
    #[serde(rename = "cliphist_wipe")]
    CliphistWipe,
    #[serde(rename = "file_share_add")]
    FileShareAdd { path: String },
    #[serde(rename = "file_share_remove")]
    FileShareRemove { id: String },
    #[serde(rename = "file_share_remove_all")]
    FileShareRemoveAll,
    #[serde(rename = "music_remote_start")]
    MusicRemoteStart,
    #[serde(rename = "music_remote_stop")]
    MusicRemoteStop,

    #[serde(rename = "cocaine_enable")]
    CocaineEnable,
    #[serde(rename = "cocaine_disable")]
    CocaineDisable,
    #[serde(rename = "brightness_set")]
    BrightnessSet { percent: f64 },
    #[serde(rename = "app_search")]
    AppSearch { query: String },
    #[serde(rename = "polkit_submit")]
    PolkitSubmit { cookie: String, response: String },
    #[serde(rename = "polkit_cancel")]
    PolkitCancel { cookie: String },
    #[serde(rename = "keepass_unlock")]
    KeepassUnlock {
        password: String,
        request_id: String,
    },
    #[serde(rename = "keepass_search")]
    KeepassSearch {
        query: String,
        #[serde(default)]
        client_title: Option<String>,
    },
    #[serde(rename = "keepass_copy")]
    KeepassCopy {
        id: String,
        field: String,
        request_id: String,
    },
    #[serde(rename = "keepass_lock")]
    KeepassLock { request_id: String },
    #[serde(rename = "keepass_get_otp")]
    KeepassGetOtp { id: String },
}

#[derive(Serialize)]
#[serde(tag = "type")]
pub enum DaemonEvent {
    #[serde(rename = "math_result")]
    MathResult {
        status: String,
        error: Option<String>,
        svg_file: Option<String>,
        svg_content: Option<String>,
    },
    #[serde(rename = "dictionary_result")]
    DictionaryResult {
        status: String,
        error: Option<String>,
        word: Option<String>,
        phonetic: Option<String>,
        definition: Option<String>,
    },
    #[serde(rename = "calc_result")]
    CalcResult {
        status: String,
        error: Option<String>,
        result: Option<String>,
        query: String,
    },
    #[serde(rename = "lyrics_result")]
    LyricsResult {
        status: String,
        error: Option<String>,
        lyrics: Option<String>,
    },
    #[serde(rename = "weather_result")]
    WeatherResult {
        status: String,
        error: Option<String>,
        data: Option<crate::weather::WeatherData>,
    },
    #[serde(rename = "agenda_update")]
    AgendaUpdate {
        data: Vec<crate::agenda::AgendaItem>,
    },
    #[serde(rename = "music_library_result")]
    MusicLibraryResult {
        status: String,
        error: Option<String>,
        library: Option<crate::music::Library>,
    },
    #[serde(rename = "music_state_update")]
    MusicStateUpdate { state: MusicStateDto },
    #[serde(rename = "frecency_update")]
    FrecencyUpdate {
        scores: crate::frecency::FrecencyScores,
    },
    #[serde(rename = "file_search_result")]
    FileSearchResult {
        query: String,
        results: Vec<crate::filesearch::FileResult>,
    },
    #[serde(rename = "app_search_result")]
    AppSearchResult {
        query: String,
        results: Vec<crate::appsearch::AppSearchResult>,
    },
    #[serde(rename = "bookmark_search_result")]
    BookmarkSearchResult {
        query: String,
        results: Vec<crate::bookmarks::BookmarkResult>,
    },
    #[serde(rename = "file_preview_result")]
    FilePreviewResult(crate::filesearch::PreviewResult),
    #[serde(rename = "sysctl_list_result")]
    SysctlListResult {
        kind: String,
        devices: Vec<crate::sysctl::DeviceItem>,
    },
    #[serde(rename = "cliphist_list_result")]
    CliphistListResult {
        items: Vec<crate::cliphist::ClipItem>,
    },
    #[serde(rename = "cliphist_ocr_update")]
    CliphistOcrUpdate {
        id: String,
        ocr_text: String,
        search_text: String,
    },
    #[serde(rename = "cliphist_action_done")]
    CliphistActionDone { action: String },
    #[serde(rename = "file_share_started")]
    FileShareStarted {
        status: String,
        error: Option<String>,
        id: Option<String>,
        url: Option<String>,
        qr_svg: Option<String>,
        name: Option<String>,
        size: Option<u64>,
    },
    #[serde(rename = "file_share_progress")]
    FileShareProgress {
        shares: Vec<crate::fileshare::ShareInfo>,
    },

    #[serde(rename = "music_remote_started")]
    MusicRemoteStarted {
        status: String,
        error: Option<String>,
        url: Option<String>,
        qr_svg: Option<String>,
    },
    #[serde(rename = "music_remote_stopped")]
    MusicRemoteStopped,
    #[serde(rename = "music_remote_connected")]
    MusicRemoteConnected,
    #[serde(rename = "polkit_show_auth")]
    PolkitShowAuth {
        action_id: String,
        message: String,
        icon_name: String,
        cookie: String,
        user_name: String,
        prompt: String,
    },
    #[serde(rename = "polkit_result")]
    PolkitResult { cookie: String, success: bool },
    #[serde(rename = "polkit_dismiss")]
    PolkitDismiss { cookie: String },
    #[serde(rename = "keepass_unlock_result")]
    KeepassUnlockResult {
        request_id: String,
        success: bool,
        error: Option<String>,
    },
    #[serde(rename = "keepass_search_result")]
    KeepassSearchResult { results: Vec<KeepassEntryDto> },
    #[serde(rename = "keepass_copy_result")]
    KeepassCopyResult {
        request_id: String,
        id: String,
        field: String,
        success: bool,
    },
    #[serde(rename = "keepass_locked")]
    KeepassLocked,
    #[serde(rename = "keepass_lock_result")]
    KeepassLockResult { request_id: String },
    #[serde(rename = "keepass_otp_result")]
    KeepassOtpResult {
        id: String,
        code: String,
        remaining: u64,
    },
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
    pub volume: f32,
    pub loop_album: bool,
    pub has_player: bool,
    pub palette: crate::artpalette::ArtPalette,
}

#[derive(Serialize, Clone)]
pub struct KeepassEntryDto {
    pub id: String,
    pub title: String,
    pub username: String,
    pub has_otp: bool,
    pub is_smart: bool,
}
