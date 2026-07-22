pragma Singleton

import QtQuick
import Quickshell
import qs.services

/** Tracks active WiFi file shares served by backendqs. */
Singleton {
    id: root

    ListModel {
        id: shareModel
    }

    readonly property alias items: shareModel
    readonly property int count: shareModel.count
    readonly property bool active: shareModel.count > 0
    readonly property var activeShare: shareModel.count > 0 ? shareModel.get(0) : null

    // Combined progress across all shares (0..1)
    readonly property real totalProgress: {
        if (shareModel.count === 0)
            return 0;
        var sent = 0, total = 0;
        for (var i = 0; i < shareModel.count; i++) {
            var s = shareModel.get(i);
            sent += s.bytes_sent;
            total += s.size;
        }
        return total > 0 ? Math.min(1, sent / total) : 0;
    }

    readonly property string statusLabel: {
        if (shareModel.count === 0)
            return "";
        return shareModel.get(0).name;
    }

    function indexOfId(id) {
        for (var i = 0; i < shareModel.count; i++) {
            if (shareModel.get(i).id === id)
                return i;
        }
        return -1;
    }

    function updateFromBackend(shares) {
        // Incremental sync to avoid model clear/rebuild hitches.
        var incomingById = {};
        for (var i = 0; i < shares.length; i++) {
            incomingById[shares[i].id] = shares[i];
        }

        for (var rm = shareModel.count - 1; rm >= 0; rm--) {
            var curRow = shareModel.get(rm);
            if (!incomingById[curRow.id])
                shareModel.remove(rm);
        }

        for (var j = 0; j < shares.length; j++) {
            var sh = shares[j];
            var idx = indexOfId(sh.id);
            if (idx < 0) {
                shareModel.append({
                    id: sh.id,
                    path: sh.path,
                    name: sh.name,
                    size: sh.size,
                    bytes_sent: sh.bytes_sent,
                    status: sh.status,
                    url: sh.url
                });
                continue;
            }

            var cur = shareModel.get(idx);
            if (cur.path !== sh.path)
                shareModel.setProperty(idx, "path", sh.path);
            if (cur.name !== sh.name)
                shareModel.setProperty(idx, "name", sh.name);
            if (cur.size !== sh.size)
                shareModel.setProperty(idx, "size", sh.size);
            if (cur.bytes_sent !== sh.bytes_sent)
                shareModel.setProperty(idx, "bytes_sent", sh.bytes_sent);
            if (cur.status !== sh.status)
                shareModel.setProperty(idx, "status", sh.status);
            if (cur.url !== sh.url)
                shareModel.setProperty(idx, "url", sh.url);
        }
    }

    function addShare(data) {
        // Single-file mode: always replace existing entry.
        shareModel.clear();
        shareModel.append({
            id: data.id,
            path: data.path || "",
            name: data.name,
            size: data.size,
            bytes_sent: 0,
            status: "waiting",
            url: data.url
        });
    }

    function removeShare(id) {
        var idx = indexOfId(id);
        if (idx >= 0)
            shareModel.remove(idx);
    }

    function clearAll() {
        shareModel.clear();
    }

    function startShare(path) {
        // Single-file mode: replace any ongoing share first.
        BackendDaemon.send({ action: "file_share_remove_all" });
        clearAll();
        BackendDaemon.send({ action: "file_share_add", path: path });
    }

    function cancelShare(id) {
        BackendDaemon.send({ action: "file_share_remove", id: id });
        removeShare(id);
    }

    function cancelAll() {
        BackendDaemon.send({ action: "file_share_remove_all" });
        clearAll();
    }

    function formatSize(bytes) {
        bytes = Number(bytes) || 0;
        if (bytes < 1024)
            return bytes + " B";
        var kb = bytes / 1024;
        if (kb < 1024)
            return kb.toFixed(1) + " KB";
        var mb = kb / 1024;
        if (mb < 1024)
            return mb.toFixed(1) + " MB";
        return (mb / 1024).toFixed(2) + " GB";
    }

    function progressOf(item) {
        if (!item || !item.size)
            return item && item.status === "complete" ? 1 : 0;
        return Math.min(1, item.bytes_sent / item.size);
    }

    function statusText(item) {
        if (!item)
            return "";
        if (item.status === "waiting")
            return "Waiting";
        if (item.status === "downloading")
            return "Downloading";
        if (item.status === "complete")
            return "Complete";
        if (item.status === "cancelled")
            return "Cancelled";
        return "Unknown";
    }
}
