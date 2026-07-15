pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/** Keeps a persisted history of recent notifications for the control center. */
Singleton {
    id: root

    // Array of { summary, body, appName, appIcon, image, time }
    property var items: []
    property int maxItems: 50

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell"

    function add(n) {
        let isKdeConnect = n.appName && n.appName.toLowerCase().indexOf("kde connect") !== -1;
        
        let recent = root.items.slice(0, 10);
        for (let i = 0; i < recent.length; i++) {
            let old = recent[i];
            let oldIsKdeConnect = old.appName === "Phone" || (old.appName && old.appName.toLowerCase().indexOf("kde connect") !== -1);
            
            let sameSummary = n.summary && old.summary && n.summary === old.summary;
            let sameBody = n.body && old.body && n.body === old.body;
            let bodyLongEnough = n.body && n.body.length > 5;
            
            if ((sameSummary && sameBody) || (sameBody && bodyLongEnough)) {
                if (isKdeConnect && !oldIsKdeConnect) return; // Ignore KDE connect duplicate
            }
        }

        let entry = {
            "summary": n.summary || "",
            "body": n.body || "",
            "appName": isKdeConnect ? "Phone" : (n.appName || ""),
            "appIcon": isKdeConnect ? "smartphone" : (n.appIcon || ""),
            "image": (n.image || "").toString(),
            "time": Date.now()
        };
        let arr = [entry, ...root.items];
        if (arr.length > root.maxItems)
            arr = arr.slice(0, root.maxItems);
        root.items = arr;
        root.save();
    }

    function removeAt(index) {
        if (index < 0 || index >= root.items.length)
            return;
        let arr = root.items.slice();
        arr.splice(index, 1);
        root.items = arr;
        root.save();
    }

    function clear() {
        root.items = [];
        root.save();
    }

    function save() {
        cache.json = JSON.stringify(root.items);
        cacheView.writeAdapter();
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.cacheDir]
    }

    Connections {
        target: NotifServer
        function onNotification(notification) {
            root.add(notification);
        }
    }

    FileView {
        id: cacheView
        path: root.cacheDir + "/notifications.json"
        printErrors: false
        onLoaded: {
            try {
                root.items = JSON.parse(cache.json) || [];
            } catch (e) {
                root.items = [];
            }
        }

        JsonAdapter {
            id: cache
            property string json: "[]"
        }
    }
}
