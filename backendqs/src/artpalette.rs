use image::imageops::FilterType;
use serde::Serialize;
use std::collections::HashMap;
use std::path::Path;
use std::sync::{Mutex, OnceLock};

/// Album-art colours for the lyrics overlay. All values are `#rrggbb`.
/// `bg` is forced dark and `fg` is forced light so QML never has to guess contrast.
#[derive(Clone, Debug, Serialize, PartialEq)]
pub struct ArtPalette {
    pub primary: String,
    pub secondary: String,
    pub accent: String,
    pub bg: String,
    pub fg: String,
}

impl Default for ArtPalette {
    fn default() -> Self {
        Self {
            primary: "#ff5aa8".into(),
            secondary: "#7a5cf0".into(),
            accent: "#c76ad9".into(),
            bg: "#24143a".into(),
            fg: "#ffffff".into(),
        }
    }
}

fn cache() -> &'static Mutex<HashMap<String, ArtPalette>> {
    static CACHE: OnceLock<Mutex<HashMap<String, ArtPalette>>> = OnceLock::new();
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Resolve `file://` / local paths and return a cached palette.
pub fn extract(art_url: &str) -> ArtPalette {
    if art_url.is_empty() {
        return ArtPalette::default();
    }
    if let Ok(guard) = cache().lock() {
        if let Some(hit) = guard.get(art_url) {
            return hit.clone();
        }
    }
    let path = art_url.strip_prefix("file://").unwrap_or(art_url);
    let palette = extract_from_path(Path::new(path)).unwrap_or_default();
    if let Ok(mut guard) = cache().lock() {
        guard.insert(art_url.to_string(), palette.clone());
    }
    palette
}

fn extract_from_path(path: &Path) -> Option<ArtPalette> {
    let img = image::open(path).ok()?;
    let thumb = img.resize_exact(48, 48, FilterType::Triangle).to_rgb8();

    const BUCKETS: usize = 4096;
    let mut weight = [0u32; BUCKETS];
    let mut sum_r = [0u64; BUCKETS];
    let mut sum_g = [0u64; BUCKETS];
    let mut sum_b = [0u64; BUCKETS];

    for p in thumb.pixels() {
        let r = p[0] as f32 / 255.0;
        let g = p[1] as f32 / 255.0;
        let b = p[2] as f32 / 255.0;
        let l = luma(r, g, b);
        if l < 0.07 || l > 0.93 {
            continue;
        }
        let s = sat(r, g, b);
        let w = (1.0 + s * 2.8) as u32;
        let qi = ((p[0] as usize >> 4) << 8) | ((p[1] as usize >> 4) << 4) | (p[2] as usize >> 4);
        weight[qi] += w;
        sum_r[qi] += p[0] as u64 * w as u64;
        sum_g[qi] += p[1] as u64 * w as u64;
        sum_b[qi] += p[2] as u64 * w as u64;
    }

    let mut ranked: Vec<(u32, usize)> = weight
        .iter()
        .enumerate()
        .filter(|(_, w)| **w > 0)
        .map(|(i, w)| (*w, i))
        .collect();
    if ranked.is_empty() {
        return None;
    }
    ranked.sort_by(|a, b| b.0.cmp(&a.0));

    let mut picked: Vec<[f32; 3]> = Vec::with_capacity(3);
    for &(_, qi) in ranked.iter() {
        let w = weight[qi] as f32;
        let rgb = [
            sum_r[qi] as f32 / w / 255.0,
            sum_g[qi] as f32 / w / 255.0,
            sum_b[qi] as f32 / w / 255.0,
        ];
        let h = hue(rgb[0], rgb[1], rgb[2]);
        if picked
            .iter()
            .any(|c| hue_dist(h, hue(c[0], c[1], c[2])) < 28.0)
        {
            continue;
        }
        picked.push(rgb);
        if picked.len() == 3 {
            break;
        }
    }
    while picked.len() < 3 {
        picked.push(picked.last().copied().unwrap_or([0.7, 0.35, 0.65]));
    }

    let primary = picked[0];
    let secondary = picked[1];
    let accent = picked
        .iter()
        .copied()
        .max_by(|a, b| {
            sat(a[0], a[1], a[2])
                .partial_cmp(&sat(b[0], b[1], b[2]))
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .unwrap_or(primary);

    Some(ArtPalette {
        primary: hex_rgb(lift(primary, 0.22, 0.55)),
        secondary: hex_rgb(lift(secondary, 0.20, 0.50)),
        accent: hex_rgb(lift(accent, 0.28, 0.62)),
        bg: hex_rgb(dark_wash(primary)),
        fg: "#ffffff".into(),
    })
}

fn luma(r: f32, g: f32, b: f32) -> f32 {
    0.2126 * r + 0.7152 * g + 0.0722 * b
}

fn sat(r: f32, g: f32, b: f32) -> f32 {
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    if max < 1e-4 { 0.0 } else { (max - min) / max }
}

fn hue(r: f32, g: f32, b: f32) -> f32 {
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let d = max - min;
    if d < 1e-4 {
        return 0.0;
    }
    let h = if max == r {
        ((g - b) / d) % 6.0
    } else if max == g {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    let deg = h * 60.0;
    if deg < 0.0 { deg + 360.0 } else { deg }
}

fn hue_dist(a: f32, b: f32) -> f32 {
    let d = (a - b).abs();
    d.min(360.0 - d)
}

fn clamp01(v: f32) -> f32 {
    v.clamp(0.0, 1.0)
}

/// Keep a colour readable as a glow: enough value, enough saturation.
fn lift(rgb: [f32; 3], min_l: f32, min_s: f32) -> [f32; 3] {
    let mut r = rgb[0];
    let mut g = rgb[1];
    let mut b = rgb[2];
    let l = luma(r, g, b);
    if l < min_l && l > 1e-4 {
        let k = min_l / l;
        r = clamp01(r * k);
        g = clamp01(g * k);
        b = clamp01(b * k);
    }
    let s = sat(r, g, b);
    if s < min_s {
        let max = r.max(g).max(b).max(1e-4);
        let mean = (r + g + b) / 3.0;
        let t = ((min_s - s) / (1.0 - s + 1e-4)).clamp(0.0, 0.65);
        r = clamp01(r + (r - mean) * t + (max - r) * t * 0.25);
        g = clamp01(g + (g - mean) * t + (max - g) * t * 0.25);
        b = clamp01(b + (b - mean) * t + (max - b) * t * 0.25);
    }
    [r, g, b]
}

/// Dark, saturated wash — always sits under white lyrics.
fn dark_wash(rgb: [f32; 3]) -> [f32; 3] {
    let lifted = lift(rgb, 0.18, 0.45);
    let l = luma(lifted[0], lifted[1], lifted[2]).max(1e-4);
    let k = 0.20 / l;
    [
        clamp01(lifted[0] * k),
        clamp01(lifted[1] * k),
        clamp01(lifted[2] * k),
    ]
}

fn hex_rgb(rgb: [f32; 3]) -> String {
    format!(
        "#{:02x}{:02x}{:02x}",
        (rgb[0] * 255.0).round() as u8,
        (rgb[1] * 255.0).round() as u8,
        (rgb[2] * 255.0).round() as u8
    )
}
