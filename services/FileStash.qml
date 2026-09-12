pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

/** Drag Queen — temporary file holding tray for paths dropped onto the dropzone. */
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
            return "image";
        if (["mp4", "mkv", "webm", "mov", "avi", "gif"].indexOf(ext) !== -1)
            return "videocam";
        if (["mp3", "flac", "wav", "ogg", "m4a", "aac", "opus"].indexOf(ext) !== -1)
            return "music_note";
        if (ext === "pdf")
            return "picture_as_pdf";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].indexOf(ext) !== -1)
            return "folder_zip";
        if (["doc", "docx", "odt", "rtf", "pages"].indexOf(ext) !== -1)
            return "description";
        if (["txt", "md", "json", "xml", "yml", "yaml", "toml", "csv", "log"].indexOf(ext) !== -1)
            return "article";
        return "draft";
    }

    function typeCategory(name) {
        const ext = extensionOf(name);
        if (isImageName(name)) return "image";
        if (["mp4", "mkv", "webm", "mov", "avi", "m4v"].indexOf(ext) !== -1) return "video";
        if (["mp3", "flac", "wav", "ogg", "m4a", "aac", "opus"].indexOf(ext) !== -1) return "audio";
        if (["pdf", "doc", "docx", "odt", "rtf", "pages", "txt", "md", "csv"].indexOf(ext) !== -1) return "document";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].indexOf(ext) !== -1) return "archive";
        if (["js", "ts", "qml", "py", "rs", "cpp", "c", "h", "sh", "json", "html", "css", "nix"].indexOf(ext) !== -1) return "code";
        return "file";
    }

    function accentColor(name) {
        const cat = typeCategory(name);
        switch (cat) {
            case "image": return "#F59E0B";
            case "video": return "#EC4899";
            case "audio": return "#10B981";
            case "document": return "#3B82F6";
            case "archive": return "#8B5CF6";
            case "code": return "#06B6D4";
            default: return "#A855F7";
        }
    }

    function categoryTag(name) {
        const ext = extensionOf(name);
        if (ext) return ext.toUpperCase().slice(0, 4);
        return typeCategory(name).toUpperCase().slice(0, 4);
    }

    function openFile(pathOrUrl) {
        const p = toLocalPath(pathOrUrl);
        if (p) {
            Quickshell.execDetached({ command: ["xdg-open", p] });
        }
    }

    function copyPath(pathOrUrl) {
        const p = toLocalPath(pathOrUrl);
        if (p) {
            Quickshell.execDetached({ command: ["bash", "-c", "printf '%s' " + JSON.stringify(p) + " | wl-copy"] });
        }
    }

    function copyAllPaths() {
        if (stashModel.count === 0) return false;
        const paths = [];
        for (let i = 0; i < stashModel.count; i++) {
            paths.push(stashModel.get(i).path);
        }
        const text = paths.join("\n");
        Quickshell.execDetached({ command: ["bash", "-c", "printf '%s' " + JSON.stringify(text) + " | wl-copy"] });
        return true;
    }

    function openFolder(pathOrUrl) {
        const p = toLocalPath(pathOrUrl);
        if (p) {
            const dir = p.substring(0, p.lastIndexOf("/"));
            if (dir) {
                Quickshell.execDetached({ command: ["xdg-open", dir] });
            }
        }
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
            isImage: isImageName(name),
            category: typeCategory(name),
            accentColor: accentColor(name),
            tag: categoryTag(name)
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
