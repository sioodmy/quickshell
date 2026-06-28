use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;
use lofty::file::{AudioFile, TaggedFileExt};
use lofty::probe::Probe;
use lofty::tag::ItemKey;
use lofty::picture::PictureType;
use sha2::{Sha256, Digest};
use std::env;
use std::thread;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;

// ── Player commands ──────────────────────────────────────────────────

pub enum PlayerCmd {
    PlayAlbum { paths: Vec<String>, start_index: usize },
    Pause,
    Resume,
    Stop,
    Next,
    Previous,
    Seek { position_secs: f64 },
    SetVolume { volume: f32 },
    ToggleLoop,
}

// ── Shared state between player thread and MPRIS ─────────────────────

#[derive(Clone, Debug)]
pub struct PlaybackState {
    pub playing: bool,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub duration_us: i64,
    pub playlist: Vec<String>,
    pub playlist_index: usize,
    // For computing live position
    pub position_at: Instant,
    pub position_snapshot_us: i64,
    pub volume: f32,
    pub loop_album: bool,
}

impl Default for PlaybackState {
    fn default() -> Self {
        Self {
            playing: false,
            title: String::new(),
            artist: String::new(),
            album: String::new(),
            art_url: String::new(),
            duration_us: 0,
            playlist: Vec::new(),
            playlist_index: 0,
            position_at: Instant::now(),
            position_snapshot_us: 0,
            volume: 1.0,
            loop_album: false,
        }
    }
}

impl PlaybackState {
    pub fn live_position_us(&self) -> i64 {
        if self.playing {
            let elapsed = self.position_at.elapsed().as_micros() as i64;
            self.position_snapshot_us + elapsed
        } else {
            self.position_snapshot_us
        }
    }
}

pub type SharedState = Arc<Mutex<PlaybackState>>;

// ── Player ───────────────────────────────────────────────────────────

pub struct Player {
    tx: mpsc::UnboundedSender<PlayerCmd>,
    pub state: SharedState,
}

impl Player {
    pub fn new() -> Self {
        let (tx, mut rx) = mpsc::unbounded_channel::<PlayerCmd>();
        let state: SharedState = Arc::new(Mutex::new(PlaybackState::default()));
        let state_clone = state.clone();

        thread::spawn(move || {
            let device_handle = match rodio::DeviceSinkBuilder::open_default_sink() {
                Ok(h) => h,
                Err(e) => {
                    eprintln!("rodio: failed to open audio output: {}", e);
                    return;
                }
            };
            let player = rodio::Player::connect_new(&device_handle.mixer());
            player.set_volume(1.0);

            // Helper: load metadata for a file path
            let load_meta = |path: &str| -> (String, String, String, String, i64) {
                let p = Path::new(path);
                let (mut title, mut artist, mut album, mut art) =
                    (String::new(), String::new(), String::new(), String::new());
                let mut dur: i64 = 0;

                if let Ok(tagged) = Probe::open(p).and_then(|pr| pr.read()) {
                    dur = tagged.properties().duration().as_micros() as i64;
                    if let Some(tag) = tagged.primary_tag().or_else(|| tagged.first_tag()) {
                        title = tag.get_string(ItemKey::TrackTitle).unwrap_or("").to_string();
                        artist = tag.get_string(ItemKey::TrackArtist)
                            .or(tag.get_string(ItemKey::AlbumArtist))
                            .unwrap_or("").to_string();
                        album = tag.get_string(ItemKey::AlbumTitle).unwrap_or("").to_string();

                        // Extract embedded cover art to cache
                        for pic in tag.pictures() {
                            if pic.pic_type() == PictureType::CoverFront || pic.pic_type() == PictureType::Other {
                                let home = env::var("HOME").unwrap_or_default();
                                let covers_dir = PathBuf::from(&home).join(".cache/quickshell/covers");
                                let _ = fs::create_dir_all(&covers_dir);
                                let mut hasher = Sha256::new();
                                hasher.update(pic.data());
                                let hash: String = hasher.finalize().iter().map(|b| format!("{:02x}", b)).collect();
                                let out = covers_dir.join(format!("{}.jpg", hash));
                                if !out.exists() {
                                    if let Ok(img) = image::load_from_memory(pic.data()) {
                                        let _ = img.save(&out);
                                    }
                                }
                                art = format!("file://{}", out.display());
                                break;
                            }
                        }
                    }
                }

                // Fallback cover from directory
                if art.is_empty() {
                    if let Some(parent) = p.parent() {
                        for f in &["cover.jpg","cover.png","folder.jpg","folder.png","Folder.jpg","Cover.jpg","front.jpg","Front.jpg"] {
                            let fp = parent.join(f);
                            if fp.exists() {
                                art = format!("file://{}", fp.display());
                                break;
                            }
                        }
                    }
                }

                if title.is_empty() {
                    title = p.file_stem().and_then(|s| s.to_str()).unwrap_or("Unknown").to_string();
                }
                (title, artist, album, art, dur)
            };

            // Helper: play track at index
            let play_index = |player: &rodio::Player, state: &SharedState, idx: usize| {
                let s = state.lock().unwrap();
                if idx >= s.playlist.len() { return; }
                let path = s.playlist[idx].clone();
                drop(s);

                player.stop();
                if let Ok(file) = fs::File::open(&path) {
                    if let Ok(source) = rodio::Decoder::try_from(file) {
                        player.append(source);
                        player.play();

                        let (title, artist, album, art, dur) = load_meta(&path);
                        let mut s = state.lock().unwrap();
                        s.playing = true;
                        s.title = title;
                        s.artist = artist;
                        s.album = album;
                        s.art_url = art;
                        s.duration_us = dur;
                        s.position_snapshot_us = 0;
                        s.position_at = Instant::now();
                        s.playlist_index = idx;
                    }
                }
            };

            loop {
                // Auto-advance: check if player is empty and advance to next track
                if player.empty() {
                    let next_idx = {
                        let mut s = state_clone.lock().unwrap();
                        if s.playing {
                            if s.playlist_index + 1 < s.playlist.len() {
                                Some(s.playlist_index + 1)
                            } else if s.loop_album && !s.playlist.is_empty() {
                                Some(0)
                            } else {
                                s.playing = false;
                                s.position_snapshot_us = s.duration_us;
                                None
                            }
                        } else { None }
                    };
                    if let Some(i) = next_idx {
                        play_index(&player, &state_clone, i);
                    }
                }

                match rx.try_recv() {
                    Ok(cmd) => {
                        match cmd {
                            PlayerCmd::PlayAlbum { paths, start_index } => {
                                {
                                    let mut s = state_clone.lock().unwrap();
                                    s.playlist = paths;
                                    s.playlist_index = start_index;
                                }
                                play_index(&player, &state_clone, start_index);
                            }
                            PlayerCmd::Pause => {
                                player.pause();
                                let mut s = state_clone.lock().unwrap();
                                s.position_snapshot_us = s.live_position_us();
                                s.playing = false;
                            }
                            PlayerCmd::Resume => {
                                player.play();
                                let mut s = state_clone.lock().unwrap();
                                s.position_at = Instant::now();
                                s.playing = true;
                            }
                            PlayerCmd::Stop => {
                                player.stop();
                                let mut s = state_clone.lock().unwrap();
                                *s = PlaybackState::default();
                            }
                            PlayerCmd::Next => {
                                let idx = {
                                    let s = state_clone.lock().unwrap();
                                    if s.playlist_index + 1 < s.playlist.len() {
                                        Some(s.playlist_index + 1)
                                    } else if s.loop_album && !s.playlist.is_empty() {
                                        Some(0)
                                    } else { None }
                                };
                                if let Some(i) = idx { play_index(&player, &state_clone, i); }
                            }
                            PlayerCmd::Previous => {
                                let idx = {
                                    let s = state_clone.lock().unwrap();
                                    if s.playlist_index > 0 {
                                        Some(s.playlist_index - 1)
                                    } else { Some(0) }
                                };
                                if let Some(i) = idx { play_index(&player, &state_clone, i); }
                            }
                            PlayerCmd::Seek { position_secs } => {
                                let seek_pos = Duration::from_secs_f64(position_secs);
                                let _ = player.try_seek(seek_pos);
                                let mut s = state_clone.lock().unwrap();
                                s.position_snapshot_us = (position_secs * 1_000_000.0) as i64;
                                s.position_at = Instant::now();
                            }
                            PlayerCmd::SetVolume { volume } => {
                                player.set_volume(volume);
                                let mut s = state_clone.lock().unwrap();
                                s.volume = volume;
                            }
                            PlayerCmd::ToggleLoop => {
                                let mut s = state_clone.lock().unwrap();
                                s.loop_album = !s.loop_album;
                            }
                        }
                    }
                    Err(tokio::sync::mpsc::error::TryRecvError::Empty) => {
                        thread::sleep(Duration::from_millis(50));
                    }
                    Err(tokio::sync::mpsc::error::TryRecvError::Disconnected) => {
                        break;
                    }
                }
            }
        });

        Self { tx, state }
    }

    pub fn play_album(&self, paths: Vec<String>, start_index: usize) {
        let _ = self.tx.send(PlayerCmd::PlayAlbum { paths, start_index });
    }
    pub fn pause(&self) { let _ = self.tx.send(PlayerCmd::Pause); }
    pub fn resume(&self) { let _ = self.tx.send(PlayerCmd::Resume); }
    pub fn stop(&self) { let _ = self.tx.send(PlayerCmd::Stop); }
    pub fn next(&self) { let _ = self.tx.send(PlayerCmd::Next); }
    pub fn previous(&self) { let _ = self.tx.send(PlayerCmd::Previous); }
    pub fn seek(&self, pos: f64) { let _ = self.tx.send(PlayerCmd::Seek { position_secs: pos }); }
    pub fn set_volume(&self, vol: f32) { let _ = self.tx.send(PlayerCmd::SetVolume { volume: vol }); }
    pub fn toggle_loop(&self) { let _ = self.tx.send(PlayerCmd::ToggleLoop); }
}

pub static PLAYER: OnceLock<Player> = OnceLock::new();

// ── MPRIS D-Bus Interface ────────────────────────────────────────────

pub struct MprisRoot;

#[zbus::interface(name = "org.mpris.MediaPlayer2")]
impl MprisRoot {
    #[zbus(property)]
    fn can_quit(&self) -> bool { false }
    #[zbus(property)]
    fn can_raise(&self) -> bool { false }
    #[zbus(property)]
    fn has_track_list(&self) -> bool { false }
    #[zbus(property)]
    fn identity(&self) -> String { "Quickshell Music".into() }
    #[zbus(property)]
    fn supported_uri_schemes(&self) -> Vec<String> { vec!["file".into()] }
    #[zbus(property)]
    fn supported_mime_types(&self) -> Vec<String> {
        vec!["audio/mpeg".into(), "audio/flac".into(), "audio/ogg".into(), "audio/opus".into()]
    }
    fn quit(&self) {}
    fn raise(&self) {}
}

pub struct MprisPlayer {
    state: SharedState,
}

impl MprisPlayer {
    pub fn new(state: SharedState) -> Self { Self { state } }
}

#[zbus::interface(name = "org.mpris.MediaPlayer2.Player")]
impl MprisPlayer {
    fn play(&self) {
        if let Some(p) = PLAYER.get() { p.resume(); }
    }
    fn pause(&self) {
        if let Some(p) = PLAYER.get() { p.pause(); }
    }
    fn play_pause(&self) {
        if let Some(p) = PLAYER.get() {
            let playing = p.state.lock().unwrap().playing;
            if playing { p.pause(); } else { p.resume(); }
        }
    }
    fn stop(&self) {
        if let Some(p) = PLAYER.get() { p.stop(); }
    }
    fn next(&self) {
        if let Some(p) = PLAYER.get() { p.next(); }
    }
    fn previous(&self) {
        if let Some(p) = PLAYER.get() { p.previous(); }
    }
    fn seek(&self, offset: i64) {
        if let Some(p) = PLAYER.get() {
            let current = p.state.lock().unwrap().live_position_us();
            let new_pos = ((current + offset) as f64) / 1_000_000.0;
            if new_pos >= 0.0 { p.seek(new_pos); }
        }
    }
    fn set_position(&self, _track_id: zbus::zvariant::ObjectPath<'_>, position: i64) {
        if let Some(p) = PLAYER.get() {
            p.seek(position as f64 / 1_000_000.0);
        }
    }

    #[zbus(property)]
    fn playback_status(&self) -> String {
        let s = self.state.lock().unwrap();
        if s.title.is_empty() { "Stopped".into() }
        else if s.playing { "Playing".into() }
        else { "Paused".into() }
    }

    #[zbus(property)]
    fn metadata(&self) -> HashMap<String, zbus::zvariant::Value<'_>> {
        let s = self.state.lock().unwrap();
        let mut m = HashMap::new();
        m.insert("mpris:trackid".into(),
            zbus::zvariant::Value::new(zbus::zvariant::ObjectPath::try_from("/org/quickshell/track").unwrap()));
        m.insert("mpris:length".into(), zbus::zvariant::Value::new(s.duration_us));
        m.insert("xesam:title".into(), zbus::zvariant::Value::new(s.title.clone()));
        m.insert("xesam:artist".into(), zbus::zvariant::Value::new(vec![s.artist.clone()]));
        m.insert("xesam:album".into(), zbus::zvariant::Value::new(s.album.clone()));
        if !s.art_url.is_empty() {
            m.insert("mpris:artUrl".into(), zbus::zvariant::Value::new(s.art_url.clone()));
        }
        m
    }

    #[zbus(property)]
    fn position(&self) -> i64 {
        self.state.lock().unwrap().live_position_us()
    }

    #[zbus(property)]
    fn can_go_next(&self) -> bool {
        let s = self.state.lock().unwrap();
        s.playlist_index + 1 < s.playlist.len()
    }
    #[zbus(property)]
    fn can_go_previous(&self) -> bool {
        let s = self.state.lock().unwrap();
        s.playlist_index > 0
    }
    #[zbus(property)]
    fn can_play(&self) -> bool { true }
    #[zbus(property)]
    fn can_pause(&self) -> bool { true }
    #[zbus(property)]
    fn can_seek(&self) -> bool { true }
    #[zbus(property)]
    fn can_control(&self) -> bool { true }
    #[zbus(property)]
    fn minimum_rate(&self) -> f64 { 1.0 }
    #[zbus(property)]
    fn maximum_rate(&self) -> f64 { 1.0 }
    #[zbus(property)]
    fn rate(&self) -> f64 { 1.0 }
    #[zbus(property)]
    fn volume(&self) -> f64 { 1.0 }
    #[zbus(property)]
    fn set_volume(&self, _vol: f64) {}
}

/// Spawn the MPRIS D-Bus server on the session bus.
pub async fn start_mpris(state: SharedState) -> anyhow::Result<()> {
    let conn = zbus::connection::Builder::session()?
        .name("org.mpris.MediaPlayer2.quickshell")?
        .serve_at("/org/mpris/MediaPlayer2", MprisRoot)?
        .serve_at("/org/mpris/MediaPlayer2", MprisPlayer::new(state))?
        .build()
        .await?;

    // Keep connection alive
    std::future::pending::<()>().await;
    Ok(())
}

// ── Library scanning (unchanged) ─────────────────────────────────────

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Track {
    pub title: String,
    pub path: String,
    pub track_number: u32,
    pub duration_secs: u64,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Album {
    pub title: String,
    pub artist: String,
    pub cover_path: Option<String>,
    pub tracks: Vec<Track>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Library {
    pub albums: Vec<Album>,
}

pub fn scan_library() -> anyhow::Result<Library> {
    let home = env::var("HOME").unwrap_or_else(|_| "/home/sioodmy".to_string());
    let cache_dir = Path::new(&home).join(".cache").join("quickshell");
    let covers_dir = cache_dir.join("covers");
    let cache_file = cache_dir.join("music_library.json");

    if cache_file.exists() {
        if let Ok(content) = fs::read_to_string(&cache_file) {
            if let Ok(library) = serde_json::from_str::<Library>(&content) {
                return Ok(library);
            }
        }
    }

    let music_dir = Path::new(&home).join("Music");
    fs::create_dir_all(&covers_dir)?;

    let mut albums_map: HashMap<String, Album> = HashMap::new();

    for entry in WalkDir::new(music_dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if !path.is_file() { continue; }

        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
        if !["flac", "mp3", "m4a", "ogg", "wav", "opus"].contains(&ext.as_str()) {
            continue;
        }

        let tagged_file = match Probe::open(path).and_then(|p| p.read()) {
            Ok(t) => t,
            Err(_) => continue,
        };

        let tag = match tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
            Some(t) => t,
            None => continue,
        };

        let title = tag.get_string(ItemKey::TrackTitle).unwrap_or("Unknown Title").to_string();
        let artist = tag.get_string(ItemKey::AlbumArtist).or(tag.get_string(ItemKey::TrackArtist)).unwrap_or("Unknown Artist").to_string();
        let album_title = tag.get_string(ItemKey::AlbumTitle).unwrap_or("Unknown Album").to_string();
        let track_number = tag.get(ItemKey::TrackNumber).and_then(|i| i.value().text()).and_then(|s| s.parse().ok()).unwrap_or(0);
        let duration_secs = tagged_file.properties().duration().as_secs();

        // Group by directory path to keep multi-artist albums together
        let album_key = path.parent().and_then(|p| p.to_str()).unwrap_or("Unknown Dir").to_string();

        let album = albums_map.entry(album_key).or_insert_with(|| {
            // Try to extract cover art
            let mut cover_path = None;
            for pic in tag.pictures() {
                if pic.pic_type() == PictureType::CoverFront || pic.pic_type() == PictureType::Other {
                    let mut hasher = Sha256::new();
                    hasher.update(&artist);
                    hasher.update(&album_title);
                    let hash: String = hasher.finalize().iter().map(|b| format!("{:02x}", b)).collect();
                    let out_path = covers_dir.join(format!("{}.jpg", hash));

                    if !out_path.exists() {
                        if let Ok(img) = image::load_from_memory(pic.data()) {
                            let _ = img.save(&out_path);
                        }
                    }
                    cover_path = Some(out_path.to_string_lossy().to_string());
                    break;
                }
            }

            if cover_path.is_none() {
                if let Some(parent) = path.parent() {
                    let fallbacks = ["cover.jpg", "cover.png", "folder.jpg", "folder.png", "Folder.jpg", "Cover.jpg"];
                    for f in fallbacks.iter() {
                        let fallback_path = parent.join(f);
                        if fallback_path.exists() {
                            cover_path = Some(fallback_path.to_string_lossy().to_string());
                            break;
                        }
                    }
                }
            }

            Album {
                title: album_title,
                artist,
                cover_path,
                tracks: Vec::new(),
            }
        });

        album.tracks.push(Track {
            title,
            path: path.to_string_lossy().to_string(),
            track_number,
            duration_secs,
        });
    }

    let mut albums: Vec<Album> = albums_map.into_values().collect();
    albums.sort_by(|a, b| a.artist.cmp(&b.artist).then(a.title.cmp(&b.title)));

    for album in &mut albums {
        album.tracks.sort_by_key(|t| t.track_number);
    }

    let library = Library { albums };
    if let Ok(json) = serde_json::to_string(&library) {
        let _ = fs::write(&cache_file, json);
    }

    Ok(library)
}
