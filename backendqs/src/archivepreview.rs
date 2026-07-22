//! Fast archive listing for launcher file preview (central-directory / header only).
//!
//! Caps work aggressively so large archives never stall the UI thread
//! (`spawn_blocking` still applies). ZIP/7z read metadata only; tar streams
//! headers and skips payloads.

use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::Path;
use std::process::{Command, Stdio};

const MAX_VISIBLE_ROWS: usize = 48;
const MAX_COLLECT_ENTRIES: usize = 512;
const MAX_TAR_BYTES: u64 = 64 * 1024 * 1024;

#[derive(Clone, Serialize)]
pub struct ArchiveEntryDto {
    pub name: String,
    pub depth: u8,
    pub is_dir: bool,
    pub size: u64,
    pub mime_cat: String,
}

#[derive(Clone, Serialize)]
pub struct ArchiveListing {
    pub entries: Vec<ArchiveEntryDto>,
    pub file_count: u32,
    pub dir_count: u32,
    pub uncompressed_size: u64,
    pub total_entries: u32,
    pub truncated: bool,
    pub format: String,
}

struct RawEntry {
    path: String,
    size: u64,
    is_dir: bool,
}

#[derive(Clone, Copy)]
enum Kind {
    Zip,
    Tar,
    TarGz,
    TarBz2,
    TarXz,
    TarZst,
    TarLz4,
    SevenZ,
    Rar,
    Gz,
    Bz2,
    Xz,
    Zst,
    Lz4,
    Unknown,
}

pub fn list_archive(path: &Path) -> Option<ArchiveListing> {
    let kind = detect_kind(path);
    let format = kind_label(kind).to_string();
    let raw = match kind {
        Kind::Zip => list_zip(path).ok()?,
        Kind::Tar => list_tar_plain(path).ok()?,
        Kind::TarGz => list_tar_gz(path).ok()?,
        Kind::TarBz2 => list_tar_bz2(path).ok()?,
        Kind::TarXz => list_tar_xz(path).ok()?,
        Kind::TarZst => list_tar_zst(path).ok()?,
        Kind::TarLz4 => list_tar_lz4(path).ok()?,
        Kind::SevenZ => list_7z(path).ok()?,
        Kind::Rar => list_rar(path)?,
        Kind::Gz => list_single_compressed(path, "gz")?,
        Kind::Bz2 => list_single_compressed(path, "bz2")?,
        Kind::Xz => list_single_compressed(path, "xz")?,
        Kind::Zst => list_single_compressed(path, "zst")?,
        Kind::Lz4 => list_single_compressed(path, "lz4")?,
        Kind::Unknown => return None,
    };
    Some(build_listing(raw, format))
}

fn detect_kind(path: &Path) -> Kind {
    let name = path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_lowercase();

    if name.ends_with(".tar.gz") || name.ends_with(".tgz") {
        Kind::TarGz
    } else if name.ends_with(".tar.bz2") || name.ends_with(".tbz2") || name.ends_with(".tbz") {
        Kind::TarBz2
    } else if name.ends_with(".tar.xz") || name.ends_with(".txz") {
        Kind::TarXz
    } else if name.ends_with(".tar.zst") || name.ends_with(".tzst") {
        Kind::TarZst
    } else if name.ends_with(".tar.lz4") {
        Kind::TarLz4
    } else if name.ends_with(".tar") {
        Kind::Tar
    } else if name.ends_with(".zip")
        || name.ends_with(".jar")
        || name.ends_with(".apk")
        || name.ends_with(".whl")
        || name.ends_with(".aar")
        || name.ends_with(".epub")
    {
        Kind::Zip
    } else if name.ends_with(".7z") {
        Kind::SevenZ
    } else if name.ends_with(".rar") {
        Kind::Rar
    } else if name.ends_with(".gz") {
        Kind::Gz
    } else if name.ends_with(".bz2") {
        Kind::Bz2
    } else if name.ends_with(".xz") || name.ends_with(".lzma") {
        Kind::Xz
    } else if name.ends_with(".zst") {
        Kind::Zst
    } else if name.ends_with(".lz4") {
        Kind::Lz4
    } else {
        Kind::Unknown
    }
}

fn kind_label(kind: Kind) -> &'static str {
    match kind {
        Kind::Zip => "ZIP",
        Kind::Tar => "TAR",
        Kind::TarGz => "TAR.GZ",
        Kind::TarBz2 => "TAR.BZ2",
        Kind::TarXz => "TAR.XZ",
        Kind::TarZst => "TAR.ZST",
        Kind::TarLz4 => "TAR.LZ4",
        Kind::SevenZ => "7Z",
        Kind::Rar => "RAR",
        Kind::Gz => "GZIP",
        Kind::Bz2 => "BZIP2",
        Kind::Xz => "XZ",
        Kind::Zst => "ZSTD",
        Kind::Lz4 => "LZ4",
        Kind::Unknown => "ARCHIVE",
    }
}

fn normalize_path(raw: &str) -> Option<String> {
    let mut s = raw.replace('\\', "/");
    while s.starts_with("./") {
        s = s[2..].to_string();
    }
    while s.starts_with('/') {
        s = s[1..].to_string();
    }
    if s.is_empty() || s == "." {
        return None;
    }
    // Zip-slip / nonsense
    if s.split('/').any(|p| p == "..") {
        return None;
    }
    Some(s)
}

fn push_raw(out: &mut Vec<RawEntry>, path: &str, size: u64, is_dir: bool) {
    if out.len() >= MAX_COLLECT_ENTRIES {
        return;
    }
    let Some(path) = normalize_path(path) else {
        return;
    };
    let is_dir = is_dir || path.ends_with('/');
    let path = path.trim_end_matches('/').to_string();
    if path.is_empty() {
        return;
    }
    out.push(RawEntry {
        path,
        size: if is_dir { 0 } else { size },
        is_dir,
    });
}

fn list_zip(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let mut archive = zip::ZipArchive::new(BufReader::new(file)).map_err(|_| ())?;
    let mut out = Vec::with_capacity(archive.len().min(MAX_COLLECT_ENTRIES));
    let n = archive.len().min(MAX_COLLECT_ENTRIES);
    for i in 0..n {
        // Prefer central-directory metadata; fall back if a member codec isn't linked.
        let meta = {
            match archive.by_index(i) {
                Ok(entry) => Some((entry.name().to_string(), entry.size(), entry.is_dir())),
                Err(_) => None,
            }
        };
        let (name, size, is_dir) = if let Some(m) = meta {
            m
        } else {
            let name = archive.name_for_index(i).unwrap_or("").to_string();
            if name.is_empty() {
                continue;
            }
            let is_dir = name.ends_with('/');
            (name, 0, is_dir)
        };
        push_raw(&mut out, &name, size, is_dir);
    }
    Ok(out)
}

fn list_tar_entries<R: Read>(reader: R) -> Result<Vec<RawEntry>, ()> {
    let mut archive = tar::Archive::new(reader);
    let mut out = Vec::new();
    let mut bytes_seen: u64 = 0;
    let entries = archive.entries().map_err(|_| ())?;
    for entry in entries {
        if out.len() >= MAX_COLLECT_ENTRIES || bytes_seen > MAX_TAR_BYTES {
            break;
        }
        let mut entry = entry.map_err(|_| ())?;
        let size = entry.size();
        bytes_seen = bytes_seen.saturating_add(size);
        let is_dir = entry.header().entry_type().is_dir();
        let path_str = entry
            .path()
            .map(|p| p.to_string_lossy().into_owned())
            .map_err(|_| ())?;
        push_raw(&mut out, &path_str, size, is_dir);
        // Drain payload so the next header is reachable on non-seekable streams.
        let mut sink = std::io::sink();
        let _ = std::io::copy(&mut entry, &mut sink);
    }
    Ok(out)
}

fn list_tar_plain(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    list_tar_entries(BufReader::new(file))
}

fn list_tar_gz(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let dec = flate2::read::GzDecoder::new(BufReader::new(file));
    list_tar_entries(dec)
}

fn list_tar_bz2(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let dec = bzip2::read::BzDecoder::new(BufReader::new(file));
    list_tar_entries(dec)
}

fn list_tar_xz(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let dec = xz2::read::XzDecoder::new(BufReader::new(file));
    list_tar_entries(dec)
}

fn list_tar_zst(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let dec = zstd::stream::read::Decoder::new(BufReader::new(file)).map_err(|_| ())?;
    list_tar_entries(dec)
}

fn list_tar_lz4(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let file = File::open(path).map_err(|_| ())?;
    let dec = lz4_flex::frame::FrameDecoder::new(BufReader::new(file));
    list_tar_entries(dec)
}

fn list_7z(path: &Path) -> Result<Vec<RawEntry>, ()> {
    let mut file = File::open(path).map_err(|_| ())?;
    let password = sevenz_rust2::Password::empty();
    let archive = sevenz_rust2::Archive::read(&mut file, &password).map_err(|_| ())?;
    let mut out = Vec::with_capacity(archive.files.len().min(MAX_COLLECT_ENTRIES));
    for entry in archive.files.iter().take(MAX_COLLECT_ENTRIES) {
        let name = entry.name();
        if name.is_empty() {
            continue;
        }
        push_raw(&mut out, name, entry.size, entry.is_directory());
    }
    Ok(out)
}

/// RAR has no solid pure-Rust lister we can depend on; try libarchive CLIs briefly.
fn list_rar(path: &Path) -> Option<Vec<RawEntry>> {
    list_via_cli(&["bsdtar", "-tf"], path)
        .or_else(|| list_via_cli(&["unar", "-l", "-quiet"], path))
        .or_else(|| list_via_cli(&["unrar", "lb"], path))
}

fn list_via_cli(argv: &[&str], path: &Path) -> Option<Vec<RawEntry>> {
    if argv.is_empty() {
        return None;
    }
    let bin = argv[0];
    let path_str = path.to_str()?;

    // `timeout` keeps a pathological RAR from blocking the preview worker.
    let mut cmd = Command::new("timeout");
    cmd.arg("0.8").arg(bin);
    for a in &argv[1..] {
        cmd.arg(a);
    }
    cmd.arg(path_str);

    let output = cmd
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout);
    let mut out = Vec::new();
    for line in text.lines() {
        if out.len() >= MAX_COLLECT_ENTRIES {
            break;
        }
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let name = if bin == "unar" {
            line.split_whitespace().last().unwrap_or(line)
        } else {
            line
        };
        let is_dir = name.ends_with('/');
        push_raw(&mut out, name, 0, is_dir);
    }
    if out.is_empty() {
        None
    } else {
        Some(out)
    }
}

fn list_single_compressed(path: &Path, ext: &str) -> Option<Vec<RawEntry>> {
    let name = path.file_name()?.to_str()?.to_string();
    let inner = name
        .strip_suffix(&format!(".{ext}"))
        .unwrap_or(&name)
        .to_string();
    let size = match ext {
        "gz" => gzip_isize(path).unwrap_or(0),
        _ => 0,
    };
    Some(vec![RawEntry {
        path: inner,
        size,
        is_dir: false,
    }])
}

fn gzip_isize(path: &Path) -> Option<u64> {
    let mut file = File::open(path).ok()?;
    let meta = file.metadata().ok()?;
    if meta.len() < 8 {
        return None;
    }
    use std::io::{Seek, SeekFrom};
    file.seek(SeekFrom::End(-4)).ok()?;
    let mut buf = [0u8; 4];
    file.read_exact(&mut buf).ok()?;
    Some(u32::from_le_bytes(buf) as u64)
}

fn categorize_name(name: &str, is_dir: bool) -> &'static str {
    if is_dir {
        return "folder";
    }
    let ext = name
        .rsplit('.')
        .next()
        .filter(|e| !e.is_empty() && e.len() <= 8 && *e != name)
        .unwrap_or("")
        .to_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "svg" | "bmp" | "ico" | "avif" => "image",
        "mp4" | "mkv" | "avi" | "mov" | "webm" | "m4v" => "video",
        "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus" => "audio",
        "pdf" => "pdf",
        "zip" | "tar" | "gz" | "bz2" | "xz" | "7z" | "rar" | "zst" | "tgz" | "lz4" => "archive",
        "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "odt" | "ods" | "odp" | "rtf" => {
            "document"
        }
        "txt" | "md" | "rs" | "py" | "js" | "ts" | "json" | "toml" | "yaml" | "yml" | "xml"
        | "html" | "css" | "qml" | "nix" | "sh" | "go" | "c" | "cpp" | "h" | "java" | "rb"
        | "lua" | "sql" | "vue" | "svelte" | "tsx" | "jsx" => "text",
        _ => "other",
    }
}

fn build_listing(raw: Vec<RawEntry>, format: String) -> ArchiveListing {
    // Merge duplicates; synthesize parent directories.
    let mut files: BTreeMap<String, u64> = BTreeMap::new();
    let mut dirs: BTreeSet<String> = BTreeSet::new();

    for e in &raw {
        if e.is_dir {
            dirs.insert(e.path.clone());
        } else {
            files.insert(e.path.clone(), e.size);
        }
        // Parent dirs
        let mut acc = String::new();
        let parts: Vec<&str> = e.path.split('/').collect();
        let end = if e.is_dir {
            parts.len()
        } else {
            parts.len().saturating_sub(1)
        };
        for (i, part) in parts.iter().enumerate() {
            if i >= end {
                break;
            }
            if !acc.is_empty() {
                acc.push('/');
            }
            acc.push_str(part);
            dirs.insert(acc.clone());
        }
    }

    // Don't treat a path as both file and dir
    for p in files.keys() {
        dirs.remove(p);
    }

    let file_count = files.len() as u32;
    let dir_count = dirs.len() as u32;
    let uncompressed_size: u64 = files.values().sum();
    let total_entries = file_count + dir_count;

    // Children map for depth-first flatten (dirs before files, then alpha).
    let mut children: BTreeMap<String, Vec<(bool, String, String)>> = BTreeMap::new();
    for d in &dirs {
        let (parent, name) = split_parent(d);
        children
            .entry(parent)
            .or_default()
            .push((false, name, d.clone()));
    }
    for f in files.keys() {
        let (parent, name) = split_parent(f);
        children
            .entry(parent)
            .or_default()
            .push((true, name, f.clone()));
    }
    for v in children.values_mut() {
        v.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.cmp(&b.1)));
    }

    let mut flat: Vec<(String, bool)> = Vec::with_capacity(files.len() + dirs.len());
    fn walk(
        parent: &str,
        children: &BTreeMap<String, Vec<(bool, String, String)>>,
        flat: &mut Vec<(String, bool)>,
        limit: usize,
    ) {
        if flat.len() >= limit {
            return;
        }
        let Some(kids) = children.get(parent) else {
            return;
        };
        for (is_file, _name, full) in kids {
            if flat.len() >= limit {
                return;
            }
            flat.push((full.clone(), *is_file));
            if !*is_file {
                walk(full, children, flat, limit);
            }
        }
    }
    walk("", &children, &mut flat, MAX_VISIBLE_ROWS);

    let truncated = flat.len() >= MAX_VISIBLE_ROWS
        || (file_count as usize + dir_count as usize) > flat.len()
        || raw.len() >= MAX_COLLECT_ENTRIES;

    let mut entries = Vec::with_capacity(flat.len());
    for (full, is_file) in flat {
        let depth = full.bytes().filter(|&b| b == b'/').count().min(255) as u8;
        let is_dir = !is_file;
        let name = split_parent(&full).1;
        let size = if is_dir {
            0
        } else {
            *files.get(&full).unwrap_or(&0)
        };
        entries.push(ArchiveEntryDto {
            name,
            depth,
            is_dir,
            size,
            mime_cat: categorize_name(&full, is_dir).to_string(),
        });
    }

    ArchiveListing {
        entries,
        file_count,
        dir_count,
        uncompressed_size,
        total_entries,
        truncated,
        format,
    }
}

fn split_parent(path: &str) -> (String, String) {
    match path.rfind('/') {
        Some(i) => (path[..i].to_string(), path[i + 1..].to_string()),
        None => (String::new(), path.to_string()),
    }
}
