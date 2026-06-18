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
    property string calcResult: ""
    property string calcExpression: ""

    // Emoji data
    property string emojiListPath: "~/.cache/quickshell/emojis.json"
    property string recentsCachePath: "~/.local/state/quickshell/recent_emojis.json"
    property var allEmojis: []
    property var filteredEmojis: []
    property var recentEmojis: []
    property var pendingRecents: []
    property string selectionBuffer: ""

    // CHANGE THIS TO YOUR ACTUAL TERMINAL
    property string myTerminal: "foot"

    function launchApp(desktopEntry) {
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

        backend.calcResult = "";
        backend.calcExpression = "";
        backend.closeMenuRequested();
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
        return /[0-9]/.test(query) || /^[\(\-\+]/.test(query);
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
        saveRecentsProcess.jsonString = JSON.stringify(rawChars);
        saveRecentsProcess.running = true;
    }

    onSearchTextChanged: {
        calcDebounce.restart();
    }

    Timer {
        id: calcDebounce
        interval: 200
        onTriggered: {
            var query = backend.searchText.trim();
            if (query === "") {
                backend.calcResult = "";
                backend.calcExpression = "";
                return;
            }
            // Only evaluate if it looks like a math/conversion expression
            if (/[0-9]/.test(query) || /^[\(\-\+]/.test(query)) {
                rinkProcess.expressionArg = query;
                rinkProcess.running = true;
            } else {
                backend.calcResult = "";
                backend.calcExpression = "";
            }
        }
    }

    Process {
        id: rinkProcess
        property string expressionArg: ""
        command: ["rink", expressionArg]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim();
                var lines = raw.split("\n");
                // rink outputs: "> expression", "Input: parsed expression", then "result"
                // Take the last non-empty line as the result
                if (lines.length >= 2) {
                    var result = "";
                    for (var i = lines.length - 1; i >= 0; i--) {
                        var l = lines[i].trim();
                        if (l !== "" && !l.startsWith(">")) {
                            result = l;
                            break;
                        }
                    }
                    // Filter out error messages
                    if (result.indexOf("No such") !== -1 ||
                        result.indexOf("Expected") !== -1 ||
                        result.indexOf("Could not") !== -1 ||
                        result.indexOf("Unknown") !== -1 ||
                        result.indexOf("did you mean") !== -1 ||
                        result.indexOf("error") !== -1) {
                        backend.calcResult = "";
                        backend.calcExpression = "";
                    } else {
                        backend.calcExpression = rinkProcess.expressionArg;
                        backend.calcResult = result;
                    }
                } else {
                    backend.calcResult = "";
                    backend.calcExpression = "";
                }
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
            // Extract just the numeric value (before the parenthetical unit description)
            var clean = backend.calcResult;
            var parenIdx = clean.indexOf(" (");
            if (parenIdx !== -1)
                clean = clean.substring(0, parenIdx).trim();
            copyCalcResult.resultText = clean;
            copyCalcResult.running = true;
        }
    }

    // --- xdg-open process for fallback actions ---
    Process {
        id: xdgOpenProcess
        property string targetUrl: ""
        command: ["xdg-open", targetUrl]
    }

    // --- Emoji processes ---
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
                    if (!textBody)
                        return;
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
        id: saveRecentsProcess
        property string jsonString: "[]"
        command: ["bash", "-c", 'mkdir -p "$(dirname ' + backend.recentsCachePath + ')" && printf "%s" "$1" > ' + backend.recentsCachePath, "_", jsonString]
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

    // Keep backward compat: emojiMenu toggle now opens the unified launcher
    IpcHandler {
        target: "emojiMenu"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
