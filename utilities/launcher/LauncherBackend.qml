import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../emoji/EmojiLogic.js" as EmojiLogic
import "LauncherColorLogic.js" as ColorLogic
Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""
    property string calcExpression: backend.searchText.trim()

    // Aliased to BackendDaemon
    property string dictWord: BackendDaemon.dictWord
    property string dictPhonetic: BackendDaemon.dictPhonetic
    property string dictDefinition: BackendDaemon.dictDefinition
    property string dictStatus: BackendDaemon.dictStatus

    property string calcResult: BackendDaemon.calcResult
    property string backendqsSvg: BackendDaemon.backendqsSvg
    property string backendqsError: BackendDaemon.backendqsError
    property string backendqsStatus: BackendDaemon.backendqsStatus

    // Emoji data
    property string emojiListPath: "~/.cache/quickshell/emojis.json"
    property string recentsCachePath: "~/.local/state/quickshell/recent_emojis.json"
    property string oldFrequenciesCachePath: "~/.cache/quickshell/app_frequencies.json"
    property var allEmojis: []
    property var filteredEmojis: []
    property var recentEmojis: []
    property var pendingRecents: []
    property var emojiDisplayByChar: ({})
    
    // Frecency is now fully managed by the Rust backend.
    property var frecencyScores: BackendDaemon.frecencyScores
    property var appFrequencies: frecencyScores.apps || ({})
    property string selectionBuffer: ""

    // File search (delegated to Rust backend)
    property var fileSearchResults: BackendDaemon.fileSearchResults
    property string fileSearchQuery: BackendDaemon.fileSearchQuery
    property var filePreview: BackendDaemon.filePreview
    property string selectedFilePath: ""

    // Terminal emulator to launch apps in
    property string myTerminal: "foot"

    function clearStates() {
        searchText = "";
        selectionBuffer = "";
        BackendDaemon.calcResult = "";
        BackendDaemon.calcStatus = "";
        BackendDaemon.dictWord = "";
        BackendDaemon.dictPhonetic = "";
        BackendDaemon.dictDefinition = "";
        BackendDaemon.dictStatus = "";
        BackendDaemon.backendqsSvg = "";
        BackendDaemon.backendqsError = "";
        BackendDaemon.backendqsStatus = "";
        BackendDaemon.fileSearchResults = [];
        BackendDaemon.fileSearchQuery = "";
        BackendDaemon.filePreview = null;
        backend.selectedFilePath = "";
        BackendDaemon.filePreviewPath = "";
    }

    function launchApp(desktopEntry) {
        if (desktopEntry.id) {
            var query = backend.searchText.trim();
            BackendDaemon.send({
                "action": "frecency_record",
                "id": desktopEntry.id,
                "query": query
            });
        }

        var finalCommand = [];

        // Wrap the launch in UWSM so systemd tracks the app properly
        finalCommand.push("run-as-service");

        if (desktopEntry.runInTerminal) {
            finalCommand.push(myTerminal);
            finalCommand.push("--");
        }

        finalCommand = finalCommand.concat(desktopEntry.command);

        Quickshell.execDetached({
            command: finalCommand,
            workingDirectory: desktopEntry.workingDirectory
        });

        backend.closeMenuRequested();
    }

    // Get quickkey matches for a query string
    function getQuickkeyMatches(query) {
        var q = (query || "").trim().toLowerCase();
        if (q.length < 2) return [];
        return backend.frecencyScores.quickkeys[q] || [];
    }

    // Get frecency score for a specific app
    function getAppFrecency(appId) {
        return backend.frecencyScores.apps[appId] || 0;
    }

    // Get the display name for an emoji
    function getEmojiDisplay(emojiChar) {
        return backend.emojiDisplayByChar[emojiChar] || "Emoji";
    }

    // --- URL encoding helper ---
    function urlEncode(str) {
        // Encode special characters for URL query parameters
        var encoded = "";
        for (var i = 0; i < str.length; i++) {
            var c = str.charAt(i);
            if (/[A-Za-z0-9\-_.~]/.test(c)) {
                encoded += c;
            } else if (c === " ") {
                encoded += "+";
            } else {
                var code = str.charCodeAt(i);
                encoded += "%" + code.toString(16).toUpperCase().padStart(2, "0");
            }
        }
        return encoded;
    }

    // --- Fallback actions ---
    function openWolframAlpha() {
        var query = backend.searchText.trim();
        if (query === "") return;
        var url = "https://www.wolframalpha.com/input?i=" + urlEncode(query);
        xdgOpenProcess.targetUrl = url;
        xdgOpenProcess.running = true;
        backend.closeMenuRequested();
    }

    function openWebSearch() {
        var query = backend.searchText.trim();
        if (query === "") return;
        var url = "https://duckduckgo.com/?q=" + urlEncode(query);
        xdgOpenProcess.targetUrl = url;
        xdgOpenProcess.running = true;
        backend.closeMenuRequested();
    }

    function looksLikeMath(query) {
        if (ColorLogic.isColorQuery(query))
            return false;
        return /[0-9]/.test(query) || /^[\(\-\+]/.test(query) || query.indexOf("int") !== -1 || query.indexOf("sum") !== -1 || query.indexOf("det") !== -1 || query.indexOf("sqrt") !== -1;
    }

    function isColorPickerQuery(query) {
        return ColorLogic.isColorQuery(query);
    }

    function copyColorText(text) {
        copyCalcResult.resultText = text;
        copyCalcResult.running = true;
    }

    // --- Focus window via niri ---
    function focusWindow(windowId) {
        NiriService.focusWindow(windowId);
        backend.closeMenuRequested();
    }

    function getRunningWindows() {
        var windows = [];
        var model = NiriService.windows;
        if (!model) return windows;
        for (var i = 0; i < model.count; i++) {
            var idx = model.index(i, 0);
            windows.push({
                id: model.data(idx, 257),       // IdRole = Qt::UserRole + 1
                title: model.data(idx, 258),     // TitleRole
                appId: model.data(idx, 259),     // AppIdRole
            });
        }
        return windows;
    }

    // --- Emoji functions ---
    function filterEmojis(query) {
        if (query === "" || backend.allEmojis.length === 0)
            return [];
        return EmojiLogic.filterEmojis(backend.allEmojis, query);
    }

    function copyEmoji(emojiChar, isShift) {
        if (backend.pendingRecents.length > 100) {
            backend.pendingRecents.shift();
        }
        backend.pendingRecents.push(emojiChar);

        if (isShift) {
            backend.selectionBuffer += emojiChar;
        } else {
            var query = backend.searchText.trim();
            BackendDaemon.send({
                "action": "frecency_record",
                "id": "emoji:" + emojiChar,
                "query": query
            });

            var finalEmoji = backend.selectionBuffer + emojiChar;
            copyEmojiProcess.selectedEmoji = finalEmoji;
            copyEmojiProcess.running = true;
            backend.selectionBuffer = "";
            backend.closeMenuRequested();
        }
    }

    function commitRecents() {
        if (backend.pendingRecents.length === 0)
            return;

        var updatedList = backend.recentEmojis;
        for (var i = 0; i < backend.pendingRecents.length; i++) {
            updatedList = EmojiLogic.updateRecents(backend.pendingRecents[i], backend.allEmojis, updatedList);
        }

        backend.recentEmojis = updatedList;
        saveRecentEmojis();
        backend.pendingRecents = [];
    }

    function saveRecentEmojis() {
        var rawChars = backend.recentEmojis.map(function(item) { return item.emoji; });
        BackendDaemon.send({
            "action": "save_json",
            "path": backend.recentsCachePath,
            "data": rawChars
        });
    }

    onSearchTextChanged: {
        calcDebounce.restart();
        dictDebounce.restart();
        fileSearchDebounce.restart();
    }

    Timer {
        id: dictDebounce
        interval: 300
        onTriggered: {
            var query = backend.searchText.trim();
            if (query === "" || query.indexOf(" ") !== -1) {
                return;
            }
            BackendDaemon.send({"action": "dictionary", "query": query});
        }
    }

    function copyDictResult() {
        if (backend.dictStatus === "ok") {
            copyCalcResult.resultText = backend.dictWord + " - " + backend.dictDefinition;
            copyCalcResult.running = true;
            backend.closeMenuRequested();
        }
    }

    Timer {
        id: calcDebounce
        interval: 200
        onTriggered: {
            var query = backend.searchText.trim();
            if (query === "") {
                return;
            }
            if (backend.looksLikeMath(query)) {
                BackendDaemon.send({"action": "calc", "query": query});
                var colStr = String(Theme.on_surface);
                if (colStr.length === 9 && colStr.startsWith("#ff")) {
                    colStr = "#" + colStr.substring(3);
                }
                BackendDaemon.send({"action": "math", "query": query, "out": "/tmp/quickshell_math.svg", "color": colStr});
            }
        }
    }

    Process {
        id: copyCalcResult
        property string resultText: ""
        command: ["bash", "-c", 'printf "%s" "$1" | wl-copy', "_", resultText]
    }

    function copyResult() {
        if (backend.calcResult !== "") {
            var clean = backend.calcResult;
            var parenIdx = clean.indexOf(" (");
            if (parenIdx !== -1)
                clean = clean.substring(0, parenIdx).trim();
            copyCalcResult.resultText = clean;
            copyCalcResult.running = true;
        }
    }

    Process {
        id: xdgOpenProcess
        property string targetUrl: ""
        command: ["xdg-open", targetUrl]
    }

    Process {
        id: updateEmojisProcess
        command: ["bash", Quickshell.shellPath("scripts/download_emojis.sh")]
        Component.onCompleted: running = true
        onRunningChanged: if (!running)
            fetchEmojis.running = true
    }

    Process {
        id: fetchEmojis
        command: ["bash", "-c", "cat " + backend.emojiListPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var textBody = this.text.trim();
                    if (!textBody) return;
                    backend.allEmojis = EmojiLogic.parseEmojiJson(textBody);
                    var displayMap = {};
                    for (var i = 0; i < backend.allEmojis.length; i++) {
                        displayMap[backend.allEmojis[i].emoji] = backend.allEmojis[i].display;
                    }
                    backend.emojiDisplayByChar = displayMap;
                    loadRecentsProcess.running = true;
                } catch (e) {
                    console.error("Failed to parse emoji list:", e);
                }
            }
        }
    }

    Process {
        id: loadRecentsProcess
        command: ["bash", "-c", 'cat ' + backend.recentsCachePath + ' 2>/dev/null || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var savedChars = JSON.parse(this.text.trim() || "[]");
                    if (Array.isArray(savedChars)) {
                        backend.recentEmojis = savedChars.map(function(char) {
                            return backend.allEmojis.find(function(item) { return item.emoji === char; });
                        }).filter(Boolean);
                    }
                } catch (e) {
                    console.error("Failed to parse recents:", e);
                }
            }
        }
    }

    Process {
        id: copyEmojiProcess
        property string selectedEmoji: ""
        command: ["bash", "-c", 'printf "%s" "$1" | wl-copy', "_", selectedEmoji]
        onRunningChanged: {
            if (!running && selectedEmoji !== "") {
                selectedEmoji = "";
            }
        }
    }

    // --- File search and Sysctl ---
    Timer {
        id: fileSearchDebounce
        interval: 150
        onTriggered: {
            var query = backend.searchText.trim();
            if (query.length >= 3) {
                BackendDaemon.send({"action": "file_search", "query": query});
            } else {
                BackendDaemon.fileSearchResults = [];
            }
        }
    }

    function openFile(path) {
        BackendDaemon.send({"action": "file_open", "path": path});
        BackendDaemon.send({
            "action": "frecency_record",
            "id": path,
            "query": backend.searchText.trim()
        });
        backend.closeMenuRequested();
    }

    function requestFilePreview(path) {
        if (!path) return;
        backend.selectedFilePath = path;
        BackendDaemon.filePreviewPath = path;
        BackendDaemon.filePreview = null;
        BackendDaemon.send({"action": "file_preview", "path": path});
    }

    Process {
        id: copyFileProcess
        property string filePath: ""
        command: ["bash", "-c", 'wl-copy < "$1"', "_", filePath]
    }

    function copyFile(path) {
        copyFileProcess.filePath = path;
        copyFileProcess.running = true;
        backend.closeMenuRequested();
    }

    function copyFilePath(path) {
        copyCalcResult.resultText = path;
        copyCalcResult.running = true;
        backend.closeMenuRequested();
    }

    function formatFileSize(bytes) {
        if (bytes < 1024) return bytes + " B";
        var kb = bytes / 1024;
        if (kb < 1024) return kb.toFixed(1) + " KB";
        var mb = kb / 1024;
        if (mb < 1024) return mb.toFixed(1) + " MB";
        var gb = mb / 1024;
        return gb.toFixed(2) + " GB";
    }

    function mimeIcon(cat) {
        if (cat === "image") return "󰋩";
        if (cat === "video") return "󰕧";
        if (cat === "audio") return "󰝚";
        if (cat === "pdf") return "󰈦";
        if (cat === "archive") return "󰀼";
        if (cat === "document") return "󱎒";
        if (cat === "text") return "󰈙";
        return "󰈔";
    }

    IpcHandler {
        target: "appLauncher"
        function toggle() {
            backend.openMenuRequested();
        }
    }

    IpcHandler {
        target: "emojiMenu"
        function toggle() {
            backend.openMenuRequested();
        }
    }

    function executeSystemCommand(actionId, value) {
        if (actionId === "vol_mute") {
            Process.run("wpctl", ["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        } else if (actionId === "vol_set") {
            Process.run("wpctl", ["set-volume", "@DEFAULT_AUDIO_SINK@", (value / 100).toFixed(2)]);
        } else if (actionId === "bl_set") {
            Process.run("brightnessctl", ["set", `${value}%`]);
        } else if (actionId === "shutdown") {
            Process.run("systemctl", ["poweroff"]);
        } else if (actionId === "reboot") {
            Process.run("systemctl", ["reboot"]);
        } else if (actionId === "sleep") {
            Process.run("systemctl", ["suspend"]);
        } else if (actionId === "lock") {
            Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "lock", "lock"] });
        } else if (actionId === "audio_out_hdmi") {
            Process.run("bash", ["-c", "wpctl status | awk '/Sinks:/,/Sources:/ {print}' | grep -i hdmi | grep -Eo '[0-9]+' | head -n 1 | xargs -r wpctl set-default"]);
        } else if (actionId === "bt_connect") {
            Process.run("bluetoothctl", ["connect", value]);
        } else if (actionId === "wifi_connect") {
            Process.run("nmcli", ["device", "wifi", "connect", value]);
        } else if (actionId === "night_on") {
            NightLight.enable();
        } else if (actionId === "night_off") {
            NightLight.disable();
        } else if (actionId === "night_toggle") {
            NightLight.toggle();
        } else if (actionId === "night_set") {
            NightLight.setIntensity(value);
            if (!NightLight.enabled) NightLight.enable();
        } else if (actionId === "ss_fullscreen") {
            Screenshot.finishFullscreen();
        } else if (actionId === "ss_area") {
            Screenshot.finishArea();
        } else if (actionId === "ss_window") {
            Screenshot.finishWindow();
        } else if (actionId === "ss_menu") {
            Screenshot.take_menu();
        } else if (actionId === "rec_fullscreen") {
            ScreenRecord.startFullscreen();
        } else if (actionId === "rec_area") {
            ScreenRecord.startArea();
        } else if (actionId === "rec_stop") {
            ScreenRecord.stop();
        } else if (actionId === "rec_audio_toggle") {
            ScreenRecord.toggleAudio();
            return;
        }
        backend.closeMenuRequested();
    }
}
