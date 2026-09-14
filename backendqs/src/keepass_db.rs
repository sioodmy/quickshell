use keepass::{
    Database, DatabaseKey,
    db::{EntryRef, GroupRef},
};
use secrecy::ExposeSecret;
use std::{
    env,
    fs::File,
    io::{Read, Write},
    process::{Child, Command, Stdio},
    sync::{LazyLock, Mutex, MutexGuard, Once, mpsc},
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tokio::sync::mpsc::Sender;
use zeroize::{Zeroize, Zeroizing};

const SESSION_LIFETIME: Duration = Duration::from_secs(5 * 60);
const CLIPBOARD_LIFETIME: Duration = Duration::from_secs(30);
const CLIPBOARD_READY_TIMEOUT: Duration = Duration::from_secs(2);
const MAX_CLIPBOARD_BYTES: usize = 64 * 1024;

static STATE: LazyLock<Mutex<State>> = LazyLock::new(|| Mutex::new(State::default()));
static INIT: Once = Once::new();
static KDF: Mutex<()> = Mutex::new(());

#[derive(Default)]
struct State {
    db: Option<Database>,
    unlocked_until: Option<Instant>,
    generation: u64,
    pending: Option<u64>,
    unlock_request: String,
    clipboard: Option<Clipboard>,
    next_copy: u64,
    tx: Option<tokio::sync::mpsc::UnboundedSender<crate::api::DaemonEvent>>,
}

struct Clipboard {
    child: Child,
    expires: Instant,
    id: u64,
}

impl Drop for Clipboard {
    fn drop(&mut self) {
        // Disconnect only our source. Never clear the current global selection:
        // another application may already have replaced it.
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

impl State {
    fn emit(&self, event: crate::api::DaemonEvent) {
        if let Some(tx) = &self.tx {
            let _ = tx.send(event);
        }
    }

    fn begin_unlock(&mut self) -> u64 {
        self.generation = self.generation.wrapping_add(1);
        self.pending = Some(self.generation);
        self.generation
    }

    fn lock(&mut self) {
        self.generation = self.generation.wrapping_add(1);
        self.pending = None;
        self.unlock_request.clear();
        self.db = None;
        self.unlocked_until = None;
        self.clipboard = None;
        self.emit(crate::api::DaemonEvent::KeepassLocked);
    }

    fn expire(&mut self, now: Instant) {
        if self.unlocked_until.is_some_and(|deadline| now >= deadline) {
            self.lock();
        } else if self
            .clipboard
            .as_ref()
            .is_some_and(|copy| now >= copy.expires)
        {
            self.clipboard = None;
        }
    }

    fn finish_unlock(
        &mut self,
        generation: u64,
        result: Result<Database, String>,
        now: Instant,
    ) -> Result<(), String> {
        self.expire(now);
        if self.pending != Some(generation) || self.generation != generation {
            // Stale completions must not overwrite either state or the UI event stream.
            return Err("Unlock superseded or locked".into());
        }
        self.pending = None;
        let result = result.map(|db| {
            self.clipboard = None;
            self.db = Some(db);
            self.unlocked_until = Some(now + SESSION_LIFETIME);
        });
        self.emit(crate::api::DaemonEvent::KeepassUnlockResult {
            request_id: self.unlock_request.clone(),
            success: result.is_ok(),
            error: result.as_ref().err().cloned(),
        });
        result
    }
}

fn state() -> MutexGuard<'static, State> {
    let mut state = STATE
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    state.expire(Instant::now());
    state
}

/// Call once during daemon startup, not in the clipboard-only subprocess.
pub fn init(tx: Sender<crate::api::DaemonEvent>) {
    INIT.call_once(|| {
        // Preserve security-state event order even when the shared output queue
        // is temporarily full, without blocking a lock on frontend I/O.
        let (events, mut receiver) = tokio::sync::mpsc::unbounded_channel();
        state().tx = Some(events);
        tokio::spawn(async move {
            while let Some(event) = receiver.recv().await {
                if tx.send(event).await.is_err() {
                    break;
                }
            }
        });
        thread::spawn(|| {
            loop {
                thread::sleep(Duration::from_millis(100));
                drop(state());
            }
        });
    });
}

/// Call at request receipt, before queuing the blocking KDF work.
pub fn begin_unlock(request_id: String) -> u64 {
    let mut state = state();
    state.unlock_request = request_id;
    state.begin_unlock()
}

/// Emits the authoritative result under the state mutex; callers must not emit it again.
pub fn unlock(password: &str, generation: u64) -> Result<(), String> {
    // Serialize memory-hard KDFs; cancelled queued attempts are rejected before
    // allocating the database's decryption workspace.
    let _kdf = KDF.lock().unwrap_or_else(|e| e.into_inner());
    {
        let state = state();
        if state.pending != Some(generation) || state.generation != generation {
            return Err("Unlock superseded or locked".into());
        }
    }
    // Opening and deriving the key must not prevent a concurrent lock/new request.
    let result = (|| {
        let path = env::var("LENINSHELL_KEEPASS").unwrap_or_else(|_| {
            let home = env::var("HOME").unwrap_or_else(|_| "/root".to_string());
            format!("{home}/.keepass/database.kdbx")
        });
        let mut file = File::open(path).map_err(|_| "Failed to open database".to_string())?;
        let key = DatabaseKey::new().with_password(password);
        Database::open(&mut file, key).map_err(|_| "Failed to unlock database".to_string())
    })();
    state().finish_unlock(generation, result, Instant::now())
}

pub fn lock() {
    state().lock();
}

pub fn lock_request(request_id: String) {
    let mut state = state();
    state.lock();
    state.emit(crate::api::DaemonEvent::KeepassLockResult { request_id });
}

pub fn generation() -> u64 {
    state().generation
}

pub fn handle_request(request: crate::api::DaemonRequest, generation: u64) {
    use crate::api::{DaemonEvent, DaemonRequest};
    let event = match request {
        DaemonRequest::KeepassSearch {
            query,
            client_title,
        } => DaemonEvent::KeepassSearchResult {
            results: search(&query, client_title.as_deref(), generation),
        },
        DaemonRequest::KeepassCopy {
            id,
            field,
            request_id,
        } => {
            let success = copy_field(&id, &field, generation).is_ok();
            DaemonEvent::KeepassCopyResult {
                id,
                field,
                request_id,
                success,
            }
        }
        DaemonRequest::KeepassGetOtp { id } => {
            let Ok((code, remaining)) = get_otp(&id, generation) else {
                return;
            };
            DaemonEvent::KeepassOtpResult {
                id,
                code,
                remaining,
            }
        }
        _ => return,
    };
    let state = state();
    if state.generation == generation && state.db.is_some() {
        state.emit(event);
    }
}

fn get_totp_raw<'a>(entry: &'a EntryRef<'_>) -> Option<&'a str> {
    for key in ["TOTP", "totp", "otp", "TimeOtp-Secret-Base32", "totpSeed"] {
        if let Some(value) = entry.fields.get(key) {
            return Some(match value {
                keepass::db::Value::Unprotected(s) => s.as_str(),
                keepass::db::Value::Protected(s) => s.expose_secret().as_str(),
            });
        }
    }
    None
}

fn search_group(
    group: GroupRef<'_>,
    out: &mut Vec<(f64, crate::api::KeepassEntryDto)>,
    query: &str,
    client_title: Option<&str>,
) {
    for entry in group.entries() {
        let title = entry.get_title().unwrap_or("");
        let lower = title.to_lowercase();

        let url = entry.get_url().unwrap_or("").to_lowercase();
        let domain = url
            .strip_prefix("http://")
            .unwrap_or(&url)
            .strip_prefix("https://")
            .unwrap_or(&url)
            .trim_start_matches("www.")
            .split('/')
            .next()
            .unwrap_or("");

        let naked_domain = domain.split('.').max_by_key(|p| p.len()).unwrap_or(domain);

        let mut is_smart = false;
        let mut score = 0.0;

        if let Some(ct) = client_title {
            let ct_lower = ct.to_lowercase();
            if !lower.is_empty() && ct_lower.contains(&lower) {
                is_smart = true;
                score += 100.0 + lower.len() as f64;
            } else if !domain.is_empty() && ct_lower.contains(domain) {
                is_smart = true;
                score += 90.0 + domain.len() as f64;
            } else if !naked_domain.is_empty()
                && naked_domain.len() >= 3
                && ct_lower.contains(naked_domain)
            {
                is_smart = true;
                score += 80.0 + naked_domain.len() as f64;
            } else if !lower.is_empty() {
                for word in ct_lower.split(|c: char| !c.is_alphanumeric()) {
                    if word.len() >= 3 && strsim::jaro_winkler(&lower, word) > 0.85 {
                        is_smart = true;
                        score += 70.0 + lower.len() as f64;
                        break;
                    }
                }
            }
        }

        if query.is_empty() {
            // score += 0.0;
        } else if lower.contains(query) {
            score += 10.0 + query.len() as f64 / lower.len() as f64;
        } else if !lower.is_empty() && query.contains(&lower) {
            score += 5.0;
        } else {
            let fuzzy_lower = strsim::jaro_winkler(&lower, query);
            let fuzzy_domain = strsim::jaro_winkler(domain, query);
            let fuzzy_naked = strsim::jaro_winkler(naked_domain, query);

            let max_fuzzy = fuzzy_lower.max(fuzzy_domain).max(fuzzy_naked);
            if max_fuzzy > 0.85 {
                score += max_fuzzy * 10.0;
            } else if !is_smart {
                continue;
            }
        }

        out.push((
            score,
            crate::api::KeepassEntryDto {
                id: entry.id().to_string(),
                title: title.to_string(),
                username: entry.get_username().unwrap_or("").to_string(),
                has_otp: get_totp_raw(&entry).is_some_and(|raw| !raw.is_empty()),
                is_smart,
            },
        ));
    }
    for child in group.groups() {
        search_group(child, out, query, client_title);
    }
}

fn search(
    query: &str,
    client_title: Option<&str>,
    generation: u64,
) -> Vec<crate::api::KeepassEntryDto> {
    let mut state = state();
    if state.generation != generation {
        return Vec::new();
    }
    let Some(db) = &state.db else {
        return Vec::new();
    };
    let mut results = Vec::new();
    search_group(db.root(), &mut results, &query.to_lowercase(), client_title);
    results.sort_by(|a, b| b.0.total_cmp(&a.0));
    state.expire(Instant::now());
    if state.db.is_none() {
        return Vec::new();
    }
    results.into_iter().map(|(_, dto)| dto).take(20).collect()
}

fn copy_from_group(
    group: GroupRef<'_>,
    id: &str,
    field: &str,
) -> Option<Result<Zeroizing<String>, String>> {
    for entry in group.entries() {
        if entry.id().to_string() == id {
            return Some(match field {
                "username" => Ok(Zeroizing::new(
                    entry.get_username().unwrap_or("").to_string(),
                )),
                "password" => Ok(Zeroizing::new(
                    entry.get_password().unwrap_or("").to_string(),
                )),
                "otp" => otp_for_entry(&entry).map(|(code, _)| Zeroizing::new(code)),
                _ => Err("Unsupported field".into()),
            });
        }
    }
    for child in group.groups() {
        if let Some(value) = copy_from_group(child, id, field) {
            return Some(value);
        }
    }
    None
}

fn copy_field(id: &str, field: &str, expected_generation: u64) -> Result<(), String> {
    if !matches!(field, "username" | "password" | "otp") {
        return Err("Unsupported field".into());
    }
    let (copy_id, generation, value, mut input, mut output) = {
        let mut state = state();
        if state.generation != expected_generation {
            return Err("Copy superseded or locked".into());
        }
        let db = state.db.as_ref().ok_or("Database not unlocked")?;
        let value = copy_from_group(db.root(), id, field).ok_or("Entry not found")??;
        if value.is_empty() || value.len() > MAX_CLIPBOARD_BYTES {
            return Err("Field empty, missing, or too large".into());
        }
        state.expire(Instant::now());
        if state.db.is_none() {
            return Err("Database not unlocked".into());
        }
        state.clipboard = None;
        let child = Command::new(env::current_exe().map_err(|e| e.to_string())?)
            .arg("keepass-clipboard")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("Clipboard process: {e}"))?;
        state.next_copy = state.next_copy.wrapping_add(1);
        let mut copy = Clipboard {
            child,
            expires: Instant::now() + CLIPBOARD_LIFETIME,
            id: state.next_copy,
        };
        let input = copy
            .child
            .stdin
            .take()
            .ok_or("Clipboard stdin unavailable")?;
        let output = copy
            .child
            .stdout
            .take()
            .ok_or("Clipboard stdout unavailable")?;
        let copy_id = copy.id;
        state.clipboard = Some(copy);
        // Register ownership before releasing the mutex or sending any plaintext.
        state.expire(Instant::now());
        if state.db.is_none() {
            return Err("Database not unlocked".into());
        }
        (copy_id, state.generation, value, input, output)
    };

    // Both pipe writes and readiness reads may block. Keep them off the mutex and
    // bound the whole exchange, not just the read (large fields can fill a pipe).
    let (tx, rx) = mpsc::sync_channel(1);
    let worker = thread::Builder::new()
        .name("keepass-copy".into())
        .spawn(move || {
            let result = (|| -> std::io::Result<()> {
                input.write_all(&(value.len() as u32).to_be_bytes())?;
                input.write_all(value.as_bytes())?;
                drop(value);
                let mut ready = [0];
                output.read_exact(&mut ready)?;
                if ready != [1] {
                    return Err(std::io::Error::other("Invalid clipboard readiness"));
                }
                Ok(())
            })();
            // Keep stdin open for the child's parent-liveness monitor.
            let _ = tx.send((result, input));
        });
    let ready = if worker.is_ok() {
        rx.recv_timeout(CLIPBOARD_READY_TIMEOUT).ok()
    } else {
        None
    };
    let mut state = state();
    if !state
        .clipboard
        .as_ref()
        .is_some_and(|copy| copy.id == copy_id)
    {
        return Err("Clipboard copy revoked".into());
    }
    if state.generation == generation && state.db.is_some() {
        if let Some((Ok(()), input)) = ready {
            if let Some(copy) = state.clipboard.as_mut() {
                copy.child.stdin = Some(input);
            }
            return Ok(());
        }
    }
    state.clipboard = None;
    Err("Clipboard copy failed, timed out, or was superseded".into())
}

/// Entry point for the hidden `keepass-clipboard` subcommand ONLY. Dispatch this
/// before initializing daemon services. Stdin is a big-endian u32 byte length,
/// then plaintext bytes; leave it open until revocation. Stdout byte 1 means ready.
pub fn serve_clipboard() -> anyhow::Result<()> {
    use wl_clipboard_rs::copy::{MimeSource, MimeType, Options, Source};

    // Process exit cancels even a blocked Wayland dispatch/preparation. This is
    // intentionally confined to the dedicated child, never the daemon process.
    thread::Builder::new()
        .name("clipboard-expiry".into())
        .spawn(|| {
            thread::sleep(CLIPBOARD_LIFETIME);
            std::process::exit(0);
        })?;
    let mut input = std::io::stdin();
    let mut length = [0; 4];
    input.read_exact(&mut length)?;
    let length = u32::from_be_bytes(length) as usize;
    anyhow::ensure!(
        (1..=MAX_CLIPBOARD_BYTES).contains(&length),
        "Invalid clipboard size"
    );
    let mut value = Zeroizing::new(vec![0; length]);
    input.read_exact(&mut value)?;
    thread::Builder::new()
        .name("clipboard-parent".into())
        .spawn(move || {
            // No further bytes are part of the protocol. EOF/error (or unexpected
            // input) means the source must be disconnected immediately.
            let mut byte = Zeroizing::new([0; 1]);
            let _ = input.read(&mut *byte);
            std::process::exit(0);
        })?;
    let mut options = Options::new();
    options.foreground(true);
    let marker = format!("application/x-quickshell-keepass-{}", uuid::Uuid::new_v4());
    let prepared = options.prepare_copy_multi(vec![
        MimeSource {
            // The library owns this copy until process exit; it exposes no
            // zeroizing storage API. Our transport buffer is wiped immediately.
            source: Source::Bytes(value.to_vec().into_boxed_slice()),
            mime_type: MimeType::Text,
        },
        MimeSource {
            source: Source::Bytes(b"secret".as_slice().into()),
            mime_type: MimeType::Specific("x-kde-passwordManagerHint".into()),
        },
        MimeSource {
            source: Source::Bytes(Vec::new().into_boxed_slice()),
            mime_type: MimeType::Specific(marker.clone()),
        },
    ])?;
    drop(value);
    // Preparation only queues set_selection. Observe our unique, non-secret
    // MIME marker from the compositor before acknowledging readiness. This
    // checks metadata only, never reads a credential or a previous selection.
    thread::Builder::new()
        .name("clipboard-ready".into())
        .spawn(move || {
            use wl_clipboard_rs::paste::{ClipboardType, Seat, get_mime_types};
            loop {
                if get_mime_types(ClipboardType::Regular, Seat::Unspecified)
                    .is_ok_and(|types| types.contains(&marker))
                {
                    let _ = std::io::stdout().write_all(&[1]);
                    let _ = std::io::stdout().flush();
                    break;
                }
                thread::sleep(Duration::from_millis(10));
            }
        })?;
    prepared.serve()?;
    Ok(())
}

fn otp_from_group(group: GroupRef<'_>, id: &str) -> Option<Result<(String, u64), String>> {
    for entry in group.entries() {
        if entry.id().to_string() == id {
            return Some(otp_for_entry(&entry));
        }
    }
    for child in group.groups() {
        if let Some(value) = otp_from_group(child, id) {
            return Some(value);
        }
    }
    None
}

fn get_otp(id: &str, generation: u64) -> Result<(String, u64), String> {
    let mut state = state();
    if state.generation != generation {
        return Err("OTP request superseded or locked".into());
    }
    let db = state.db.as_ref().ok_or("Database not unlocked")?;
    let mut result = otp_from_group(db.root(), id).ok_or("Entry not found")?;
    state.expire(Instant::now());
    if state.db.is_none() {
        if let Ok((code, _)) = &mut result {
            code.zeroize();
        }
        return Err("Database not unlocked".into());
    }
    result
}

fn otp_for_entry(entry: &EntryRef<'_>) -> Result<(String, u64), String> {
    let raw = get_totp_raw(entry).ok_or("No OTP configured")?;
    let (secret, period) = parse_totp(raw)?;
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| "System clock before Unix epoch")?
        .as_secs();
    Ok((compute_totp(&secret, now / period)?, period - now % period))
}

fn parse_totp(raw: &str) -> Result<(Zeroizing<Vec<u8>>, u64), String> {
    let Some(uri) = raw.strip_prefix("otpauth://totp/") else {
        return base32_decode(raw).map(|secret| (secret, 30));
    };
    if !uri.is_ascii()
        || uri
            .bytes()
            .any(|b| b.is_ascii_control() || b == b' ' || b == b'#')
    {
        return Err("Invalid OTP URI".into());
    }
    let (label, params) = uri.split_once('?').ok_or("Missing OTP parameters")?;
    if label.is_empty() || label.contains('/') || label.contains('?') {
        return Err("Invalid OTP label".into());
    }
    let _label = decode_uri_component(label)?;
    let mut secret = None;
    let mut period = None;
    let mut algorithm = false;
    let mut digits = false;
    let mut issuer = false;
    for param in params.split('&') {
        let (key, value) = param.split_once('=').ok_or("Invalid OTP parameter")?;
        let value = decode_uri_component(value)?;
        match key {
            "secret" if secret.is_none() => secret = Some(base32_decode(&value)?),
            "period" if period.is_none() => {
                if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
                    return Err("Invalid OTP period".into());
                }
                let parsed = value.parse::<u64>().map_err(|_| "Invalid OTP period")?;
                if !(1..=300).contains(&parsed) {
                    return Err("OTP period must be 1..=300".into());
                }
                period = Some(parsed);
            }
            "algorithm" if !algorithm && *value == "SHA1" => algorithm = true,
            "digits" if !digits && *value == "6" => digits = true,
            "issuer" if !issuer && !value.is_empty() => issuer = true,
            _ => return Err("Unsupported or duplicate OTP parameter".into()),
        }
    }
    Ok((secret.ok_or("Missing OTP secret")?, period.unwrap_or(30)))
}

fn decode_uri_component(input: &str) -> Result<Zeroizing<String>, String> {
    let mut bytes = Zeroizing::new(Vec::with_capacity(input.len()));
    let mut iter = input.bytes();
    while let Some(byte) = iter.next() {
        let byte = if byte == b'%' {
            let high = iter.next().and_then(|b| (b as char).to_digit(16));
            let low = iter.next().and_then(|b| (b as char).to_digit(16));
            match (high, low) {
                (Some(high), Some(low)) => (high * 16 + low) as u8,
                _ => return Err("Invalid OTP percent encoding".into()),
            }
        } else {
            byte
        };
        if byte.is_ascii_control() {
            return Err("Invalid OTP URI character".into());
        }
        bytes.push(byte);
    }
    let decoded = std::str::from_utf8(&bytes).map_err(|_| "Invalid OTP UTF-8")?;
    Ok(Zeroizing::new(decoded.to_string()))
}

fn base32_decode(input: &str) -> Result<Zeroizing<Vec<u8>>, String> {
    let data = input.trim_end_matches('=');
    let padding = input.len() - data.len();
    let remainder = data.len() % 8;
    let expected_padding = match remainder {
        0 => 0,
        2 => 6,
        4 => 4,
        5 => 3,
        7 => 1,
        _ => return Err("Invalid base32 length".into()),
    };
    if data.is_empty() || (padding != 0 && padding != expected_padding) {
        return Err("Invalid base32 padding".into());
    }
    let mut bits = Zeroizing::new(0u16);
    let mut count = 0u32;
    let mut out = Zeroizing::new(Vec::with_capacity(data.len() / 8 * 5 + 5));
    for byte in data.bytes() {
        let value = match byte.to_ascii_uppercase() {
            b'A'..=b'Z' => byte.to_ascii_uppercase() - b'A',
            b'2'..=b'7' => byte - b'2' + 26,
            _ => return Err("Invalid base32 character".into()),
        };
        *bits = (*bits << 5) | u16::from(value);
        count += 5;
        if count >= 8 {
            count -= 8;
            out.push((*bits >> count) as u8);
            *bits &= (1 << count) - 1;
        }
    }
    if *bits != 0 {
        return Err("Noncanonical base32 trailing bits".into());
    }
    Ok(out)
}

fn compute_totp(secret: &[u8], counter: u64) -> Result<String, String> {
    use hmac::{Hmac, Mac};
    use sha1::Sha1;

    if secret.is_empty() {
        return Err("Empty OTP secret".into());
    }
    let mut mac = Hmac::<Sha1>::new_from_slice(secret).map_err(|_| "HMAC initialization failed")?;
    mac.update(&counter.to_be_bytes());
    let mut result = mac.finalize().into_bytes();
    let offset = (result[19] & 0x0f) as usize;
    let mut code = ((result[offset] as u32 & 0x7f) << 24)
        | ((result[offset + 1] as u32) << 16)
        | ((result[offset + 2] as u32) << 8)
        | result[offset + 3] as u32;
    let formatted = format!("{:06}", code % 1_000_000);
    result[..].zeroize();
    code.zeroize();
    Ok(formatted)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rfc4226_hotp_vectors() {
        for (counter, expected) in [
            "755224", "287082", "359152", "969429", "338314", "254676", "287922", "162583",
            "399871", "520489",
        ]
        .iter()
        .enumerate()
        {
            assert_eq!(
                compute_totp(b"12345678901234567890", counter as u64).unwrap(),
                *expected
            );
        }
    }

    #[test]
    fn rfc6238_sha1_vectors_six_digits() {
        // RFC 6238's eight-digit SHA1 vectors reduced to the supported six digits.
        for (time, expected) in [
            (59, "287082"),
            (1111111109, "081804"),
            (1111111111, "050471"),
            (1234567890, "005924"),
            (2000000000, "279037"),
            (20000000000, "353130"),
        ] {
            assert_eq!(
                compute_totp(b"12345678901234567890", time / 30).unwrap(),
                expected
            );
        }
    }

    #[test]
    fn strict_base32() {
        for (encoded, decoded) in [
            ("MY======", "f"),
            ("MZXQ====", "fo"),
            ("MZXW6===", "foo"),
            ("MZXW6YQ=", "foob"),
            ("MZXW6YTB", "fooba"),
            ("mzxw6ytboi", "foobar"),
        ] {
            assert_eq!(&*base32_decode(encoded).unwrap(), decoded.as_bytes());
        }
        for invalid in [
            "",
            "=",
            "A",
            "AAA",
            "AAAAAA",
            "MY=",
            "MY=======",
            "M=Y=====",
            "MZ",
            "MZXW7",
            "MZXW6YTB=",
            "M0",
            "M1",
            "M8",
            "MY!",
            " MY",
            "MY\n",
            "M-Y",
            "\u{00e9}",
        ] {
            assert!(base32_decode(invalid).is_err(), "accepted {invalid:?}");
        }
    }

    #[test]
    fn strict_otp_parameters() {
        let valid = "otpauth://totp/Test%20Account?secret=MY%3D%3D%3D%3D%3D%3D&algorithm=SHA1&digits=6&issuer=Test";
        assert_eq!(parse_totp(valid).unwrap().1, 30);
        for period in [1, 300] {
            assert_eq!(
                parse_totp(&format!("{valid}&period={period}")).unwrap().1,
                period
            );
        }
        for params in [
            "secret=MY&period=0",
            "secret=MY&period=301",
            "secret=MY&period=-1",
            "secret=MY&period=+30",
            "secret=MY&period=18446744073709551616",
            "secret=MY&period=",
            "secret=MY&period=30&period=30",
            "secret=MY&secret=MY",
            "secret=MY&digits=8",
            "secret=MY&digits=0",
            "secret=MY&algorithm=SHA256",
            "secret=MY&algorithm=SHA512",
            "secret=MY&algorithm=SHA1&algorithm=SHA1",
            "secret=MY&digits=6&digits=6",
            "secret=MY&counter=1",
            "secret=MY&unknown=x",
            "secret=MY&",
            "secret=MY#fragment",
            "secret=",
            "period=30",
            "secret=M%",
            "secret=M%XY",
            "secret=MY%00",
            "secret=%FF",
        ] {
            assert!(
                parse_totp(&format!("otpauth://totp/Test?{params}")).is_err(),
                "accepted {params}"
            );
        }
        for uri in [
            "otpauth://hotp/Test?secret=MY",
            "otpauth://totp/?secret=MY",
            "otpauth://totp/Test",
            "otpauth://totp/Test%?secret=MY",
            "otpauth://totp/A/B?secret=MY",
        ] {
            assert!(parse_totp(uri).is_err(), "accepted {uri}");
        }
    }

    #[test]
    fn newer_request_and_lock_invalidate_pending_unlocks() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut state = State {
            tx: Some(tx),
            ..State::default()
        };
        let first = state.begin_unlock();
        let second = state.begin_unlock();
        assert!(
            state
                .finish_unlock(first, Ok(Database::new()), Instant::now())
                .is_err()
        );
        assert!(state.db.is_none());
        assert!(rx.try_recv().is_err());
        state.lock();
        assert!(
            state
                .finish_unlock(second, Ok(Database::new()), Instant::now())
                .is_err()
        );
        assert!(state.db.is_none());
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassLocked
        ));
        assert!(rx.try_recv().is_err());
    }

    #[test]
    fn unlock_result_is_correlated_and_lock_notification_is_distinct() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut state = State {
            tx: Some(tx),
            unlock_request: "unlock-7".into(),
            ..State::default()
        };
        let generation = state.begin_unlock();
        state
            .finish_unlock(generation, Ok(Database::new()), Instant::now())
            .unwrap();
        assert!(
            matches!(rx.try_recv().unwrap(), crate::api::DaemonEvent::KeepassUnlockResult {
            request_id, success: true, ..
        } if request_id == "unlock-7")
        );
        state.lock();
        state.emit(crate::api::DaemonEvent::KeepassLockResult {
            request_id: "lock-8".into(),
        });
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassLocked
        ));
        assert!(
            matches!(rx.try_recv().unwrap(), crate::api::DaemonEvent::KeepassLockResult {
            request_id
        } if request_id == "lock-8")
        );
    }

    #[test]
    fn session_expiry_is_absolute_and_invalidates_pending_work() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut state = State {
            tx: Some(tx),
            ..State::default()
        };
        let now = Instant::now();
        let generation = state.begin_unlock();
        state
            .finish_unlock(generation, Ok(Database::new()), now)
            .unwrap();
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassUnlockResult { success: true, .. }
        ));
        for seconds in 1..300 {
            state.expire(now + Duration::from_secs(seconds));
            assert!(state.db.is_some());
            assert_eq!(state.unlocked_until, Some(now + SESSION_LIFETIME));
        }
        let pending = state.begin_unlock();
        state.expire(now + SESSION_LIFETIME);
        assert!(state.db.is_none());
        assert!(state.pending.is_none());
        assert!(
            state
                .finish_unlock(pending, Ok(Database::new()), now + SESSION_LIFETIME)
                .is_err()
        );
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassLocked
        ));
        assert!(rx.try_recv().is_err());
    }

    #[test]
    fn completion_checks_expiry_and_failed_unlock_emits_once() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut state = State {
            tx: Some(tx),
            ..State::default()
        };
        let now = Instant::now();
        let failed = state.begin_unlock();
        assert!(
            state
                .finish_unlock(failed, Err("Failed to unlock database".into()), now)
                .is_err()
        );
        assert!(state.pending.is_none());
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassUnlockResult { success: false, .. }
        ));
        assert!(
            state
                .finish_unlock(failed, Ok(Database::new()), now)
                .is_err()
        );
        assert!(rx.try_recv().is_err());

        let generation = state.begin_unlock();
        state
            .finish_unlock(generation, Ok(Database::new()), now)
            .unwrap();
        let _ = rx.try_recv().unwrap();
        let pending = state.begin_unlock();
        // No expiry-thread tick: completion must enforce the deadline itself.
        assert!(
            state
                .finish_unlock(pending, Ok(Database::new()), now + SESSION_LIFETIME)
                .is_err()
        );
        assert!(state.db.is_none());
        assert!(matches!(
            rx.try_recv().unwrap(),
            crate::api::DaemonEvent::KeepassLocked
        ));
        assert!(rx.try_recv().is_err());
    }

    #[test]
    fn search_never_recommends_and_copy_rejects_arbitrary_fields() {
        let mut db = Database::new();
        let id = {
            let mut root = db.root_mut();
            let mut entry = root.add_entry();
            entry.set_unprotected("Title", "Example");
            entry.set_protected("otp", "MY");
            entry.set_protected("PrivateField", "not copyable");
            entry.id().to_string()
        };
        let mut results = Vec::new();
        search_group(db.root(), &mut results, "", None);
        assert_eq!(results.len(), 1);
        assert!(!results[0].1.is_smart);
        assert!(results[0].1.has_otp);
        assert!(
            copy_from_group(db.root(), &id, "PrivateField")
                .unwrap()
                .is_err()
        );
    }
}
