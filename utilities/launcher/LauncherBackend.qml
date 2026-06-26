import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../emoji/EmojiLogic.js" as EmojiLogic

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
    property string frequenciesCachePath: "~/.cache/quickshell/app_frequencies.json"
    property var allEmojis: []
    property var filteredEmojis: []
    property var recentEmojis: []
    property var pendingRecents: []
    property var appFrequencies: ({})
    property string selectionBuffer: ""

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
    }

    function launchApp(desktopEntry) {
        if (desktopEntry.id) {
            var freqs = backend.appFrequencies;
            freqs[desktopEntry.id] = (freqs[desktopEntry.id] || 0) + 1;
            backend.appFrequencies = freqs;
            saveFrequencies();
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

    Process {
        id: loadFrequenciesProcess
        command: ["bash", "-c", 'cat ' + backend.frequenciesCachePath + ' 2>/dev/null || echo "{}"']
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var textBody = this.text.trim();
                    backend.appFrequencies = JSON.parse(textBody || "{}");
                } catch (e) {
                    console.error("Failed to parse app frequencies:", e);
                }
            }
        }
    }

    function saveFrequencies() {
        BackendDaemon.send({
            "action": "save_json",
            "path": backend.frequenciesCachePath,
            "data": backend.appFrequencies
        });
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
        return /[0-9]/.test(query) || /^[\(\-\+]/.test(query) || query.indexOf("int") !== -1 || query.indexOf("sum") !== -1 || query.indexOf("det") !== -1 || query.indexOf("sqrt") !== -1;
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
}
