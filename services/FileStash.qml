pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/** Temporary file stash — holds paths dropped onto the dropzone until cleared. */
Singleton {
    id: root

    ListModel {
        id: stashModel
    }

    readonly property alias items: stashModel
    readonly property int count: stashModel.count
    readonly property bool empty: stashModel.count === 0

    function basename(path) {
        const cleaned = String(path).replace(/\/+$/, "");
        const parts = cleaned.split("/");
        return parts[parts.length - 1] || cleaned;
    }

    function toLocalPath(url) {
        let s = String(url);
        if (s.startsWith("file://")) {
            s = s.slice("file://".length);
            // Prefer decodeURIComponent; fall back if malformed.
            try {
                s = decodeURIComponent(s);
            } catch (e) {
                // keep undecoded
            }
        }
        return s;
    }

    function toFileUrl(path) {
        const s = String(path);
        if (s.startsWith("file://"))
            return s;
        return "file://" + s;
    }

    function indexOfPath(path) {
        const target = toLocalPath(path);
        for (let i = 0; i < stashModel.count; i++) {
            if (stashModel.get(i).path === target)
                return i;
        }
        return -1;
    }

    function extensionOf(name) {
        const n = String(name);
        const dot = n.lastIndexOf(".");
        if (dot <= 0 || dot === n.length - 1)
            return "";
        return n.slice(dot + 1).toLowerCase();
    }

    function isImageName(name) {
        const ext = extensionOf(name);
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "jxl"].indexOf(ext) !== -1;
    }

    function mimeGlyph(name) {
        const ext = extensionOf(name);
        if (isImageName(name))
            return "󰋩";
        if (["mp4", "mkv", "webm", "mov", "avi", "gif"].indexOf(ext) !== -1)
            return "󰕧";
        if (["mp3", "flac", "wav", "ogg", "m4a", "aac", "opus"].indexOf(ext) !== -1)
            return "󰝚";
        if (ext === "pdf")
            return "󰈦";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].indexOf(ext) !== -1)
            return "󰀼";
        if (["doc", "docx", "odt", "rtf", "pages"].indexOf(ext) !== -1)
            return "󱎒";
        if (["txt", "md", "json", "xml", "yml", "yaml", "toml", "csv", "log"].indexOf(ext) !== -1)
            return "󰈙";
        return "󰈔";
    }

    function addPath(pathOrUrl) {
        const path = toLocalPath(pathOrUrl);
        if (!path)
            return false;
        if (indexOfPath(path) !== -1)
            return false;

        const name = basename(path);
        stashModel.append({
            path: path,
            url: toFileUrl(path),
            name: name,
            glyph: mimeGlyph(name),
            isImage: isImageName(name)
        });
        return true;
    }

    function addUrls(urls) {
        let added = 0;
        if (!urls)
            return 0;
        for (let i = 0; i < urls.length; i++) {
            if (addPath(urls[i]))
                added++;
        }
        return added;
    }

    function removeAt(index) {
        if (index < 0 || index >= stashModel.count)
            return;
        stashModel.remove(index, 1);
    }

    function removePath(path) {
        const idx = indexOfPath(path);
        if (idx !== -1)
            removeAt(idx);
    }

    function clear() {
        stashModel.clear();
    }

    /** Build a text/uri-list payload for external drag-out. */
    function uriListForIndices(indices) {
        const lines = [];
        for (let i = 0; i < indices.length; i++) {
            const idx = indices[i];
            if (idx < 0 || idx >= stashModel.count)
                continue;
            lines.push(stashModel.get(idx).url);
        }
        return lines.join("\n");
    }

    IpcHandler {
        target: "fileStash"
        function clear(): void {
            root.clear();
        }
        function add(path: string): void {
            root.addPath(path);
        }
    }
}
