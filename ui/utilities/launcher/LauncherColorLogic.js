.pragma library

function isHexColor(text) {
    if (!text)
        return false;
    var t = text.trim();
    if (/^#[0-9a-fA-F]{3}$/.test(t) || /^#[0-9a-fA-F]{6}$/.test(t) || /^#[0-9a-fA-F]{8}$/.test(t))
        return true;
    return /^[0-9a-fA-F]{6}$/.test(t) || /^[0-9a-fA-F]{8}$/.test(t);
}

function isRgbColor(text) {
    if (!text)
        return false;
    return /^rgb\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*\)$/i.test(text.trim());
}

function isColorQuery(text) {
    return isColorPickerQuery(text) || isHexColor(text) || isRgbColor(text);
}

function isColorPickerQuery(text) {
    if (!text)
        return false;
    var t = text.trim().toLowerCase();
    return t === "color picker" || t === "colorpicker" || t === "colour picker";
}

function normalizeHex(text) {
    if (!text)
        return null;
    var t = text.trim();
    if (!t.startsWith("#"))
        t = "#" + t;
    if (/^#[0-9a-fA-F]{3}$/.test(t))
        t = "#" + t[1] + t[1] + t[2] + t[2] + t[3] + t[3];
    if (/^#[0-9a-fA-F]{6}$/.test(t) || /^#[0-9a-fA-F]{8}$/.test(t))
        return t.toUpperCase();
    return null;
}

function hexToRgb(hex) {
    hex = normalizeHex(hex);
    if (!hex)
        return null;
    var r = parseInt(hex.substring(1, 3), 16);
    var g = parseInt(hex.substring(3, 5), 16);
    var b = parseInt(hex.substring(5, 7), 16);
    return { r: r, g: g, b: b };
}

function parseRgbString(text) {
    if (!text)
        return null;
    var m = text.trim().match(/^rgb\s*\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$/i);
    if (!m)
        return null;
    return {
        r: Math.max(0, Math.min(255, parseInt(m[1], 10))),
        g: Math.max(0, Math.min(255, parseInt(m[2], 10))),
        b: Math.max(0, Math.min(255, parseInt(m[3], 10)))
    };
}

function parseColorQuery(text) {
    if (!text)
        return null;
    var trimmed = text.trim();
    if (isHexColor(trimmed))
        return hexToRgb(trimmed);
    return parseRgbString(trimmed);
}

function rgbToHsv(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    var max = Math.max(r, g, b);
    var min = Math.min(r, g, b);
    var d = max - min;
    var h = 0;
    var s = max === 0 ? 0 : d / max;
    var v = max;
    if (d !== 0) {
        switch (max) {
        case r: h = (g - b) / d + (g < b ? 6 : 0); break;
        case g: h = (b - r) / d + 2; break;
        default: h = (r - g) / d + 4; break;
        }
        h /= 6;
    }
    return { h: h * 360, s: s, v: v };
}

function hsvToRgb(h, s, v) {
    h = ((h % 360) + 360) % 360;
    s = Math.max(0, Math.min(1, s));
    v = Math.max(0, Math.min(1, v));
    var c = v * s;
    var x = c * (1 - Math.abs((h / 60) % 2 - 1));
    var m = v - c;
    var rp = 0, gp = 0, bp = 0;
    if (h < 60) { rp = c; gp = x; }
    else if (h < 120) { rp = x; gp = c; }
    else if (h < 180) { gp = c; bp = x; }
    else if (h < 240) { gp = x; bp = c; }
    else if (h < 300) { rp = x; bp = c; }
    else { rp = c; bp = x; }
    return {
        r: Math.round((rp + m) * 255),
        g: Math.round((gp + m) * 255),
        b: Math.round((bp + m) * 255)
    };
}

function rgbToHex(r, g, b) {
    function pad(n) {
        var s = n.toString(16).toUpperCase();
        return s.length === 1 ? "0" + s : s;
    }
    return "#" + pad(r) + pad(g) + pad(b);
}

function colorToHex(color) {
    return rgbToHex(Math.round(color.r * 255), Math.round(color.g * 255), Math.round(color.b * 255));
}

function contrastOnColor(color) {
    var lum = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    return lum > 0.55 ? "#1a1c20" : "#f4f3fa";
}
