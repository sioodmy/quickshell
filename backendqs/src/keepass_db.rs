use keepass::{
    db::{EntryRef, GroupRef},
    Database, DatabaseKey,
};
use std::env;
use std::fs::File;
use std::sync::{Arc, Mutex};

lazy_static::lazy_static! {
    pub static ref KEEPASS_STATE: Arc<Mutex<Option<Database>>> = Arc::new(Mutex::new(None));
}

use secrecy::ExposeSecret;

fn get_totp_raw(e: &EntryRef<'_>) -> Option<String> {
    let keys_to_check = ["TOTP", "totp", "otp", "TimeOtp-Secret-Base32", "totpSeed"];
    for k in keys_to_check {
        if let Some(val) = e.fields.get(k) {
            match val {
                keepass::db::Value::Unprotected(s) => return Some(s.clone()),
                keepass::db::Value::Protected(p) => return Some(p.expose_secret().clone()),
            }
        }
    }
    None
}

pub fn unlock(password: &str) -> Result<(), String> {
    let path = env::var("LENINSHELL_KEEPASS").unwrap_or_else(|_| {
        let home = env::var("HOME").unwrap_or_else(|_| "/root".to_string());
        format!("{}/.keepass/database.kdbx", home)
    });

    let mut file = File::open(&path).map_err(|e| format!("Failed to open DB: {}", e))?;
    let key = DatabaseKey::new().with_password(password);
    let db = Database::open(&mut file, key).map_err(|e| format!("Failed to parse DB: {}", e))?;

    *KEEPASS_STATE.lock().unwrap() = Some(db);
    Ok(())
}

pub fn lock() {
    *KEEPASS_STATE.lock().unwrap() = None;
}

fn get_helium_title() -> Option<String> {
    if let Ok(mut socket) = niri_ipc::socket::Socket::connect() {
        if let Ok(Ok(niri_ipc::Response::Windows(windows))) =
            socket.send(niri_ipc::Request::Windows)
        {
            // Find the window with the highest focus_timestamp
            let latest_window = windows.iter().max_by(|a, b| {
                let ta = a
                    .focus_timestamp
                    .as_ref()
                    .map(|t| (t.secs, t.nanos))
                    .unwrap_or((0, 0));
                let tb = b
                    .focus_timestamp
                    .as_ref()
                    .map(|t| (t.secs, t.nanos))
                    .unwrap_or((0, 0));
                ta.cmp(&tb)
            });

            if let Some(win) = latest_window {
                if win.app_id.as_deref() == Some("helium") {
                    let title = win.title.clone().unwrap_or_default();
                    let cleaned = title.strip_suffix(" - Helium").unwrap_or(&title);
                    return Some(cleaned.to_string());
                }
            }
        }
    }
    None
}

// Simple Jaro-Winkler alternative using substrings and length
fn score_match(title: &str, query: &str) -> f64 {
    let t = title.to_lowercase();
    let q = query.to_lowercase();
    if t.contains(&q) {
        return 10.0 + (q.len() as f64 / t.len() as f64);
    }
    if q.contains(&t) {
        return 5.0;
    }
    -1.0
}

fn search_group(
    group: GroupRef<'_>,
    out: &mut Vec<(f64, crate::api::KeepassEntryDto)>,
    q_lower: &str,
    h_lower: &str,
) {
    for e in group.entries() {
        let title = e.get_title().unwrap_or("").to_string();
        let username = e.get_username().unwrap_or("").to_string();
        let t_lower = title.to_lowercase();

        let mut score = 0.0;
        let mut is_smart = false;

        if !q_lower.is_empty() {
            let s = score_match(&t_lower, q_lower);
            if s > 0.0 {
                score += s;
            }
        }

        if !h_lower.is_empty() && q_lower.is_empty() {
            // Only smart match if the title is meaningful and matches
            if t_lower.len() > 2 && (t_lower.contains(h_lower) || h_lower.contains(&t_lower)) {
                is_smart = true;
                score += 20.0;
                if t_lower.contains(h_lower) {
                    score += 5.0;
                }
            }
        }

        if !q_lower.is_empty() && score <= 0.0 {
            score = -1.0;
        }

        let has_otp = get_totp_raw(&e).is_some();

        if score >= 0.0 {
            out.push((
                score,
                crate::api::KeepassEntryDto {
                    id: e.id().to_string(),
                    title,
                    username,
                    has_otp,
                    is_smart,
                },
            ));
        }
    }

    for g in group.groups() {
        search_group(g, out, q_lower, h_lower);
    }
}

pub fn search(query: &str) -> Vec<crate::api::KeepassEntryDto> {
    let guard = KEEPASS_STATE.lock().unwrap();
    let db = match guard.as_ref() {
        Some(db) => db,
        None => return vec![],
    };

    let helium_title = get_helium_title().unwrap_or_default();
    let helium_title_lower = helium_title.to_lowercase();
    let q_lower = query.to_lowercase();

    let root = db.root();
    let mut results = Vec::new();
    search_group(root, &mut results, &q_lower, &helium_title_lower);

    results.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    results.into_iter().map(|(_, dto)| dto).take(20).collect()
}

fn copy_from_group(group: GroupRef<'_>, id: &str, field: &str) -> Result<String, ()> {
    for e in group.entries() {
        if e.id().to_string() == id {
            let val = match field {
                "password" => e.get_password().unwrap_or("").to_string(),
                "username" => e.get_username().unwrap_or("").to_string(),
                "otp" => {
                    let raw = get_totp_raw(&e).unwrap_or_default();
                    if raw.is_empty() {
                        "".to_string()
                    } else {
                        // Generate the code on the fly for copying
                        match parse_totp_secret(&raw) {
                            Ok(secret) => {
                                let period = parse_totp_period(&raw).unwrap_or(30);
                                let now = std::time::SystemTime::now()
                                    .duration_since(std::time::UNIX_EPOCH)
                                    .unwrap()
                                    .as_secs();
                                compute_totp(&secret, now / period)
                                    .unwrap_or_else(|_| "".to_string())
                            }
                            Err(_) => "".to_string(),
                        }
                    }
                }
                other => e.get(other).unwrap_or("").to_string(),
            };
            return Ok(val);
        }
    }
    for g in group.groups() {
        if let Ok(v) = copy_from_group(g, id, field) {
            return Ok(v);
        }
    }
    Err(())
}

pub fn copy_field(id: &str, field: &str) -> Result<(), String> {
    let guard = KEEPASS_STATE.lock().unwrap();
    let db = guard.as_ref().ok_or("Database not unlocked")?;

    let root = db.root();
    let value = copy_from_group(root, id, field).map_err(|_| "Entry not found")?;

    if value.is_empty() {
        return Err("Field empty or missing".to_string());
    }

    use wl_clipboard_rs::copy::{MimeType, MimeSource, Options, Source};

    let opts = Options::new();
    opts.copy_multi(vec![
        MimeSource {
            source: Source::Bytes(value.as_bytes().into()),
            mime_type: MimeType::Text,
        },
        MimeSource {
            source: Source::Bytes("secret".as_bytes().into()),
            mime_type: MimeType::Specific("x-kde-passwordManagerHint".to_string()),
        }
    ])
    .map_err(|e| format!("wl-clipboard failed: {}", e))?;

    Ok(())
}

/// Retrieve the raw TOTP secret for an entry, compute the current code natively,
/// and return (code, seconds_remaining). OTP codes are ephemeral 6-digit tokens
/// and are safe to display in the UI (they are NOT passwords).
fn get_totp_secret_from_group(group: GroupRef<'_>, id: &str) -> Option<String> {
    for e in group.entries() {
        if e.id().to_string() == id {
            return get_totp_raw(&e);
        }
    }
    for g in group.groups() {
        if let Some(v) = get_totp_secret_from_group(g, id) {
            return Some(v);
        }
    }
    None
}

pub fn get_otp(id: &str) -> Result<(String, u64), String> {
    let guard = KEEPASS_STATE.lock().unwrap();
    let db = guard.as_ref().ok_or("Database not unlocked")?;

    let root = db.root();
    let raw = get_totp_secret_from_group(root, id).unwrap_or_default();

    if raw.is_empty() {
        return Err("No OTP configured".to_string());
    }

    // Parse the otpauth:// URI or bare secret
    let secret = parse_totp_secret(&raw)?;
    let period = parse_totp_period(&raw).unwrap_or(30);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_secs();
    let counter = now / period;
    let remaining = period - (now % period);

    let code = compute_totp(&secret, counter)?;
    Ok((code, remaining))
}

fn parse_totp_secret(raw: &str) -> Result<Vec<u8>, String> {
    if let Some(uri) = raw.strip_prefix("otpauth://totp/") {
        // Extract secret= parameter
        if let Some(q) = uri.find('?') {
            let params = &uri[q + 1..];
            for param in params.split('&') {
                if let Some(val) = param.strip_prefix("secret=") {
                    return base32_decode(val);
                }
            }
        }
        Err("No secret= in otpauth URI".into())
    } else {
        // Treat as bare base32 secret
        base32_decode(raw.trim())
    }
}

fn parse_totp_period(raw: &str) -> Option<u64> {
    if let Some(q) = raw.find('?') {
        for param in raw[q + 1..].split('&') {
            if let Some(val) = param.strip_prefix("period=") {
                return val.parse().ok();
            }
        }
    }
    None
}

fn base32_decode(input: &str) -> Result<Vec<u8>, String> {
    let input = input.trim_end_matches('=').to_uppercase();
    let alphabet = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    let mut bits: u64 = 0;
    let mut bit_count: u32 = 0;
    let mut out = Vec::new();

    for ch in input.bytes() {
        if ch == b' ' || ch == b'\n' || ch == b'\r' || ch == b'\t' || ch == b'-' {
            continue;
        }
        let val = match alphabet.iter().position(|&c| c == ch) {
            Some(v) => v as u64,
            None => {
                // Ignore invalid characters instead of failing
                continue;
            }
        };
        bits = (bits << 5) | val;
        bit_count += 5;
        if bit_count >= 8 {
            bit_count -= 8;
            out.push((bits >> bit_count) as u8);
            bits &= (1 << bit_count) - 1;
        }
    }
    Ok(out)
}

fn compute_totp(secret: &[u8], counter: u64) -> Result<String, String> {
    use hmac::{Hmac, Mac};
    use sha1::Sha1;

    let counter_bytes = counter.to_be_bytes();
    let mut mac = Hmac::<Sha1>::new_from_slice(secret).map_err(|e| format!("HMAC init: {}", e))?;
    mac.update(&counter_bytes);
    let result = mac.finalize().into_bytes();

    let offset = (result[19] & 0x0f) as usize;
    let code = ((result[offset] as u32 & 0x7f) << 24)
        | ((result[offset + 1] as u32) << 16)
        | ((result[offset + 2] as u32) << 8)
        | (result[offset + 3] as u32);
    let code = code % 1_000_000;
    Ok(format!("{:06}", code))
}
