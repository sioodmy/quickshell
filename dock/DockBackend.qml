import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import qs.services

pragma Singleton

Singleton {
    id: root

    property var pinnedIds: []
    property var dockModel: []

    signal focusSwitched()

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/dock_pinned.json"

    readonly property string cacheDir: "/tmp/quickshell_app_previews"

    Process {
        Component.onCompleted: running = true
        command: ["bash", "-c", "rm -rf \"$1\" && mkdir -p \"$1\"", "_", root.cacheDir]
    }

    Process {
        id: screenshotProcess
        property string targetWinId: ""
        command: ["bash", "-c", "out=\"$1/win_$2.png\"; tmp=\"$out.tmp.png\"; grim -c - | magick - -sample 320x \"$tmp\" && mv \"$tmp\" \"$out\"", "_", root.cacheDir, targetWinId]
    }

    Timer {
        id: enterCaptureTimer
        interval: 1000
        repeat: false
        property string pendingWinId: ""
        onTriggered: {
            if (pendingWinId !== "") {
                screenshotProcess.targetWinId = pendingWinId;
                screenshotProcess.running = true;
            }
        }
    }

    Timer {
        id: periodicCaptureTimer
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            var map = root._runningWindowsMap;
            for (var id in map) {
                if (map[id].isFocused) {
                    screenshotProcess.targetWinId = id;
                    screenshotProcess.running = true;
                    break;
                }
            }
        }
    }

    Process {
        id: loadProcess
        command: ["bash", "-c", 'cat "$1" 2>/dev/null || echo "[]"', "_", root.statePath]
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.pinnedIds = JSON.parse(this.text.trim() || "[]");
                } catch (e) {
                    console.error("Dock: failed to parse pinned apps:", e);
                    root.pinnedIds = [];
                }
                root.rebuildModel();
            }
        }
    }

    function savePinned() {
        BackendDaemon.send({
            "action": "save_json",
            "path": root.statePath,
            "data": root.pinnedIds
        });
    }

    function pinApp(desktopId) {
        var list = root.pinnedIds.slice();
        if (list.indexOf(desktopId) === -1) {
            list.push(desktopId);
            root.pinnedIds = list;
            savePinned();
            rebuildModel();
        }
    }

    function unpinApp(desktopId) {
        var list = root.pinnedIds.filter(function(id) { return id !== desktopId; });
        root.pinnedIds = list;
        savePinned();
        rebuildModel();
    }

    function isPinned(desktopId) {
        return root.pinnedIds.indexOf(desktopId) !== -1;
    }

    function movePin(fromIndex, toIndex) {
        var list = root.pinnedIds.slice();
        if (fromIndex < 0 || fromIndex >= list.length) return;
        if (toIndex < 0 || toIndex >= list.length) return;
        var item = list.splice(fromIndex, 1)[0];
        list.splice(toIndex, 0, item);
        root.pinnedIds = list;
        savePinned();
        rebuildModel();
    }

    property var _runningWindowsMap: ({})

    Instantiator {
        model: NiriService.windows
        delegate: QtObject {
            id: winObj
            property string winId: model.id || ""
            property string winTitle: model.title || ""
            property string winAppId: model.appId || ""
            property int winWorkspaceId: model.workspaceId !== undefined ? model.workspaceId : -1
            property bool winIsFocused: model.isFocused !== undefined ? model.isFocused : false

            onWinIsFocusedChanged: {
                if (root._runningWindowsMap[winId]) {
                    var map = Object.assign({}, root._runningWindowsMap);
                    map[winId].isFocused = winIsFocused;
                    root._runningWindowsMap = map;
                    root.rebuildModel();
                    
                    if (winIsFocused) {
                        root.focusSwitched();
                        enterCaptureTimer.pendingWinId = winId;
                        enterCaptureTimer.restart();
                    }
                }
            }

            onWinWorkspaceIdChanged: {
                if (root._runningWindowsMap[winId]) {
                    var map = Object.assign({}, root._runningWindowsMap);
                    map[winId].workspaceId = winWorkspaceId;
                    root._runningWindowsMap = map;
                    root.rebuildModel();
                }
            }

            Component.onCompleted: {
                var map = Object.assign({}, root._runningWindowsMap);
                map[winId] = {
                    id: winId,
                    title: winTitle,
                    appId: winAppId,
                    workspaceId: winWorkspaceId,
                    isFocused: winIsFocused
                };
                root._runningWindowsMap = map;
                root.rebuildModel();
            }
            Component.onDestruction: {
                var map = Object.assign({}, root._runningWindowsMap);
                delete map[winId];
                root._runningWindowsMap = map;
                root.rebuildModel();
            }
        }
    }

    function getRunningWindows() {
        return Object.values(root._runningWindowsMap);
    }

    function findDesktopEntry(appId) {
        if (!appId) return null;
        var allApps = DesktopEntries.applications.values;
        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];
            if (entry.id === appId) return entry;
        }
        var lower = appId.toLowerCase();
        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];
            if (entry.id && entry.id.toLowerCase() === lower) return entry;
        }
        return null;
    }

    property string _lastFingerprint: ""

    function rebuildModel() {
        var result = [];
        var runningWindows = getRunningWindows();

        var windowsByApp = {};
        for (var w = 0; w < runningWindows.length; w++) {
            var win = runningWindows[w];
            var aid = win.appId || "";
            if (!windowsByApp[aid]) windowsByApp[aid] = [];
            windowsByApp[aid].push(win);
        }

        // Pinned apps
        for (var p = 0; p < root.pinnedIds.length; p++) {
            var pid = root.pinnedIds[p];
            var entry = findDesktopEntry(pid);
            var windows = windowsByApp[pid] || [];

            result.push({
                desktopId: pid,
                entry: entry,
                name: entry ? entry.name : pid,
                icon: entry ? entry.icon : "",
                pinned: true,
                running: windows.length > 0,
                windows: windows,
                minWorkspaceId: windows.length > 0
                    ? Math.min.apply(null, windows.map(function(w) { return w.workspaceId || 9999; }))
                    : 9999
            });

            delete windowsByApp[pid];
        }

        var unpinnedList = [];
        var remainingApps = Object.keys(windowsByApp);
        for (var r = 0; r < remainingApps.length; r++) {
            var aid = remainingApps[r];
            if (!aid) continue;
            var windows = windowsByApp[aid];
            var entry = findDesktopEntry(aid);
            var minWs = Math.min.apply(null, windows.map(function(w) { return w.workspaceId || 9999; }));

            unpinnedList.push({
                desktopId: aid,
                entry: entry,
                name: entry ? entry.name : aid,
                icon: entry ? entry.icon : "",
                pinned: false,
                running: true,
                windows: windows,
                minWorkspaceId: minWs
            });
        }

        unpinnedList.sort(function(a, b) {
            if (a.minWorkspaceId !== b.minWorkspaceId)
                return a.minWorkspaceId - b.minWorkspaceId;
            return (a.name || "").localeCompare(b.name || "");
        });

        for (var u = 0; u < unpinnedList.length; u++) {
            result.push(unpinnedList[u]);
        }

        var fingerprint = result.map(function(item) {
            var focused = item.windows.some(function(w) { return w.isFocused; });
            return item.desktopId + ":" + (item.pinned ? "P" : "R") +
                   ":" + (item.running ? "1" : "0") + ":" + item.windows.length +
                   ":" + item.minWorkspaceId + ":" + focused;
        }).join("|");

        if (fingerprint !== root._lastFingerprint) {
            root._lastFingerprint = fingerprint;
            root.dockModel = result;
        }
    }

    Timer {
        id: rebuildTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: root.rebuildModel()
    }

    function launchApp(desktopId) {
        var entry = findDesktopEntry(desktopId);
        if (!entry) return;

        var finalCommand = ["run-as-service"];
        if (entry.runInTerminal) {
            finalCommand.push("foot");
            finalCommand.push("--");
        }
        finalCommand = finalCommand.concat(entry.command);
        Quickshell.execDetached({
            command: finalCommand,
            workingDirectory: entry.workingDirectory
        });
    }

    function focusWindow(windowId) {
        NiriService.focusWindow(windowId);
    }

    function activateApp(desktopId) {
        var windows = getWindowsForApp(desktopId);
        if (windows.length > 0) {
            focusWindow(windows[0].id);
        } else {
            launchApp(desktopId);
        }
    }

    function getWindowsForApp(desktopId) {
        var runningWindows = getRunningWindows();
        return runningWindows.filter(function(w) { return w.appId === desktopId; });
    }
}
