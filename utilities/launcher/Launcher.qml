import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"
import "../../popups/weather"
import qs.services

PanelWindow {
    id: launcherWindow

    // Add any apps you want to hide to this list
    property var hiddenKeywords: ["avahi", "uuctl", "bssh", "bvnc"]

    // Track whether a file result is currently selected for preview
    property bool hasFileSelected: false
    property var selectedFileData: null
    property real fileSplitBlend: 0

    readonly property string trimmedQuery: ctrl.searchText.trim()
    readonly property string normalizedQuery: trimmedQuery.toLowerCase()

    readonly property bool weatherModeActive: normalizedQuery === "weather"
    readonly property bool colorPickerModeActive: ctrl.isColorPickerQuery(trimmedQuery)
    readonly property var connectivityQuery: parseConnectivityQuery(trimmedQuery)
    readonly property var musicQuery: parseMusicQuery(trimmedQuery)
    readonly property bool btModeActive: connectivityQuery && connectivityQuery.mode === "bt"
    readonly property bool wifiModeActive: connectivityQuery && connectivityQuery.mode === "wifi"
    readonly property bool connectivityModeActive: btModeActive || wifiModeActive
    readonly property bool musicModeActive: musicQuery !== null

    readonly property var sliderQuery: parseSliderQuery(trimmedQuery)
    readonly property bool volSliderActive: sliderQuery && sliderQuery.mode === "vol"
    readonly property bool blSliderActive: sliderQuery && sliderQuery.mode === "bl"
    readonly property bool sliderModeActive: volSliderActive || blSliderActive
    readonly property bool sliderHasValue: sliderModeActive && sliderQuery.value >= 0

    readonly property var nightQuery: parseNightQuery(trimmedQuery)
    readonly property bool nightModeActive: nightQuery !== null

    readonly property var dndQuery: parseDndQuery(trimmedQuery)
    readonly property bool dndModeActive: dndQuery !== null

    readonly property var pomQuery: parsePomQuery(trimmedQuery)
    readonly property bool pomModeActive: pomQuery !== null

    readonly property var clipQuery: parseClipQuery(trimmedQuery)
    readonly property bool clipModeActive: clipQuery !== null

    readonly property var ssQuery: parseSsQuery(trimmedQuery)
    readonly property bool ssModeActive: ssQuery !== null

    readonly property var recQuery: parseRecQuery(trimmedQuery)
    readonly property bool recModeActive: recQuery !== null

    readonly property bool captureModeActive: ssModeActive || recModeActive

    property int appActionIndex: -1

    readonly property bool specialViewActive: weatherModeActive || colorPickerModeActive || connectivityModeActive || musicModeActive || nightModeActive || clipModeActive

    readonly property var pipewireSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: launcherWindow.pipewireSink ? [launcherWindow.pipewireSink] : [] }

    onHasFileSelectedChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onWeatherModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onColorPickerModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onNightModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onClipModeActiveChanged: {
        fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0;
        if (clipModeActive && contentLoader.item)
            contentLoader.item.refreshClipboard();
    }
    onMusicModeActiveChanged: {
        fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
        if (musicModeActive && !BackendDaemon.musicLibrary)
            BackendDaemon.send({ action: "music_library" });
    }

    Behavior on fileSplitBlend {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    property real openProgress: 0.0
    property bool menuOpen: false
    property string bluetoothConnectedDeviceLabel: ""

    color: "transparent"
    visible: menuOpen || openAnim.running || closeAnim.running

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "launcher_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    NumberAnimation {
        id: openAnim
        target: launcherWindow
        property: "openProgress"
        from: 0; to: 1
        duration: 200
        easing.type: Easing.OutCubic
        onStarted: LauncherState.open = true
        onFinished: LauncherState.openProgress = 1.0
    }

    NumberAnimation {
        id: closeAnim
        target: launcherWindow
        property: "openProgress"
        from: 1; to: 0
        duration: 150
        easing.type: Easing.InCubic
        onFinished: {
            launcherWindow.menuOpen = false;
            LauncherState.open = false;
            LauncherState.openProgress = 0.0;
        }
    }

    onOpenProgressChanged: LauncherState.openProgress = openProgress

    // Ensure the notification appears right after the launcher has closed.
    Timer {
        id: bluetoothConnectedNotifTimer
        interval: 170
        repeat: false
        running: false
        onTriggered: {
            if (!bluetoothConnectedDeviceLabel)
                return;
            Quickshell.execDetached({
                command: [
                    "notify-send",
                    "-a", "Quickshell",
                    "-u", "normal",
                    "-t", "800",
                    "Bluetooth",
                    "Connected to " + bluetoothConnectedDeviceLabel
                ]
            });
            bluetoothConnectedDeviceLabel = "";
        }
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.closeMenu()
    }

    // Keep the visible list small — uncapped matches flood ListView with heavy delegates.
    readonly property int maxEmptyApps: 12
    readonly property int maxAppResults: 8
    readonly property int maxMusicResults: 5
    readonly property int maxFileResults: 8
    readonly property int maxEmojiResults: 6

    // queryLower must already be lowercased; queryLen avoids re-reading the string.
    function scoreMatch(text, queryLower, queryLen) {
        if (!text)
            return -1;
        var textLower = text.toString().toLowerCase();

        // Exact match
        if (textLower === queryLower)
            return 1000;

        // Full string starts with query
        if (textLower.startsWith(queryLower))
            return 800;

        // Any word in the string starts with query
        if (textLower.indexOf(" " + queryLower) !== -1 || textLower.indexOf("-" + queryLower) !== -1 || textLower.indexOf("_" + queryLower) !== -1)
            return 600;

        // single/double letter matches polluting short queries
        if (queryLen >= 3 && textLower.indexOf(queryLower) !== -1)
            return 200;

        return -1;
    }

    function parseConnectivityQuery(query) {
        var q = query.trim().toLowerCase();
        if (q.startsWith("bluetooth"))
            return { mode: "bt", filter: q.substring(9).trim() };
        if (q.startsWith("bt"))
            return { mode: "bt", filter: q.substring(2).trim() };
        if (q.startsWith("wifi"))
            return { mode: "wifi", filter: q.substring(4).trim() };
        if (q.startsWith("net"))
            return { mode: "wifi", filter: q.substring(3).trim() };
        return null;
    }

    function parseSliderQuery(query) {
        var q = query.trim().toLowerCase();
        if (q === "vol" || q.startsWith("vol ")) {
            var rest = q === "vol" ? "" : q.substring(4).trim();
            if (rest === "" || rest === "mute")
                return { mode: "vol", value: -1, mute: rest === "mute" };
            var num = parseInt(rest);
            if (!isNaN(num) && num >= 0 && num <= 100)
                return { mode: "vol", value: num, mute: false };
            return { mode: "vol", value: -1, mute: false };
        }
        if (q === "bl" || q.startsWith("bl ")) {
            var rest = q === "bl" ? "" : q.substring(3).trim();
            if (rest === "")
                return { mode: "bl", value: -1, mute: false };
            var num = parseInt(rest);
            if (!isNaN(num) && num >= 0 && num <= 100)
                return { mode: "bl", value: num, mute: false };
            return { mode: "bl", value: -1, mute: false };
        }
        return null;
    }

    function parseMusicQuery(query) {
        var q = query.trim().toLowerCase();
        if (!q.startsWith("music"))
            return null;
        var rest = q.substring(5).trim();
        var commands = ["stop", "pause", "play", "resume", "next", "prev", "previous"];
        if (commands.indexOf(rest) !== -1)
            return { filter: "", command: rest };
        return { filter: rest, command: null };
    }

    function parseNightQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "night" && !q.startsWith("night "))
            return null;
        var rest = q === "night" ? "" : q.substring(6).trim();
        if (rest === "")
            return { command: null, value: -1 };
        if (rest === "on")
            return { command: "on", value: -1 };
        if (rest === "off")
            return { command: "off", value: -1 };
        if (rest === "toggle")
            return { command: "toggle", value: -1 };
        var num = parseInt(rest);
        if (!isNaN(num) && num >= 0 && num <= 100)
            return { command: "set", value: num };
        return { command: null, value: -1 };
    }

    function parseDndQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "dnd" && !q.startsWith("dnd "))
            return null;
        var rest = q === "dnd" ? "" : q.substring(4).trim();
        if (rest === "")
            return { command: null };
        if (rest === "on" || rest === "enable")
            return { command: "on" };
        if (rest === "off" || rest === "disable")
            return { command: "off" };
        if (rest === "toggle")
            return { command: "toggle" };
        return { command: null };
    }

    function parsePomQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "pom" && q !== "pomodoro" && !q.startsWith("pom ") && !q.startsWith("pomodoro "))
            return null;

        var rest = "";
        if (q.startsWith("pomodoro "))
            rest = q.substring(9).trim();
        else if (q.startsWith("pom "))
            rest = q.substring(4).trim();
        else if (q === "pomodoro" || q === "pom")
            rest = "";

        if (rest === "")
            return { command: null, minutes: -1 };

        if (rest === "start" || rest === "go")
            return { command: "start", minutes: -1 };
        if (rest === "stop" || rest === "pause")
            return { command: "stop", minutes: -1 };
        if (rest === "toggle")
            return { command: "toggle", minutes: -1 };
        if (rest === "reset")
            return { command: "reset", minutes: -1 };
        if (rest === "work" || rest === "focus")
            return { command: "work", minutes: -1 };
        if (rest === "break" || rest === "short")
            return { command: "break", minutes: -1 };
        if (rest === "long")
            return { command: "long", minutes: -1 };

        if (rest.startsWith("+") || rest.startsWith("-")) {
            var adj = parseInt(rest);
            if (!isNaN(adj) && adj !== 0)
                return { command: "adjust", minutes: adj };
        }

        var num = parseInt(rest);
        if (!isNaN(num) && num >= 1 && num <= 120)
            return { command: "set", minutes: num };

        return { command: null, minutes: -1 };
    }

    function parseClipQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "clip" && !q.startsWith("clip "))
            return null;
        var rest = q === "clip" ? "" : query.trim().substring(5).trim();
        return { filter: rest };
    }

    function parseSsQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "ss" && q !== "screenshot" && !q.startsWith("ss ") && !q.startsWith("screenshot "))
            return null;
        var rest = "";
        if (q.startsWith("screenshot "))
            rest = q.substring(11).trim();
        else if (q.startsWith("ss "))
            rest = q.substring(3).trim();
        else if (q === "screenshot" || q === "ss")
            rest = "";

        if (rest === "" || rest === "menu")
            return { command: rest === "menu" ? "menu" : null };
        if (rest === "area" || rest === "region" || rest === "select")
            return { command: "area" };
        if (rest === "full" || rest === "fullscreen" || rest === "screen")
            return { command: "fullscreen" };
        if (rest === "window" || rest === "win")
            return { command: "window" };
        return { command: null };
    }

    function parseRecQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "rec" && q !== "record" && !q.startsWith("rec ") && !q.startsWith("record "))
            return null;
        var rest = "";
        if (q.startsWith("record "))
            rest = q.substring(7).trim();
        else if (q.startsWith("rec "))
            rest = q.substring(4).trim();

        if (rest === "")
            return { command: null };
        if (rest === "area" || rest === "region" || rest === "select")
            return { command: "area" };
        if (rest === "full" || rest === "fullscreen" || rest === "screen")
            return { command: "fullscreen" };
        if (rest === "stop" || rest === "end")
            return { command: "stop" };
        if (rest === "audio" || rest === "mic")
            return { command: "audio" };
        return { command: null };
    }

    function executeMusicCommand(command) {
        if (command === "stop" || command === "pause") {
            if (Playerctl.isPlaying)
                Playerctl.playPause();
        } else if (command === "play" || command === "resume") {
            if (!Playerctl.isPlaying && Playerctl.hasPlayer)
                Playerctl.playPause();
        } else if (command === "next") {
            Playerctl.next();
        } else if (command === "prev" || command === "previous") {
            Playerctl.previous();
        }
    }

    function executeNightCommand() {
        var nq = launcherWindow.nightQuery;
        if (!nq) return;
        if (nq.command === "on") {
            NightLight.enable();
            launcherWindow.closeMenu();
        } else if (nq.command === "off") {
            NightLight.disable();
            launcherWindow.closeMenu();
        } else if (nq.command === "toggle") {
            NightLight.toggle();
            launcherWindow.closeMenu();
        } else if (nq.command === "set" && nq.value >= 0) {
            NightLight.setIntensity(nq.value);
            if (!NightLight.enabled) NightLight.enable();
            launcherWindow.closeMenu();
        }
    }

    function executeDndCommand() {
        var dq = launcherWindow.dndQuery;
        if (!dq || !dq.command) return;
        if (dq.command === "on") {
            DoNotDisturb.enable();
            launcherWindow.closeMenu();
        } else if (dq.command === "off") {
            DoNotDisturb.disable();
            launcherWindow.closeMenu();
        } else if (dq.command === "toggle") {
            DoNotDisturb.toggle();
            launcherWindow.closeMenu();
        }
    }

    function executePomCommand() {
        var pq = launcherWindow.pomQuery;
        if (!pq || !pq.command) return;

        if (pq.command === "set" && pq.minutes > 0) {
            Pomodoro.setDuration(pq.minutes);
            if (!Pomodoro.isRunning)
                Pomodoro.isRunning = true;
            launcherWindow.closeMenu();
        } else if (pq.command === "start") {
            if (!Pomodoro.isRunning)
                Pomodoro.isRunning = true;
            launcherWindow.closeMenu();
        } else if (pq.command === "stop") {
            Pomodoro.isRunning = false;
            launcherWindow.closeMenu();
        } else if (pq.command === "toggle") {
            Pomodoro.toggle();
            launcherWindow.closeMenu();
        } else if (pq.command === "reset") {
            Pomodoro.reset();
            launcherWindow.closeMenu();
        } else if (pq.command === "work") {
            Pomodoro.setMode(0);
            launcherWindow.closeMenu();
        } else if (pq.command === "break") {
            Pomodoro.setMode(1);
            launcherWindow.closeMenu();
        } else if (pq.command === "long") {
            Pomodoro.setMode(2);
            launcherWindow.closeMenu();
        } else if (pq.command === "adjust" && pq.minutes !== 0) {
            Pomodoro.adjustTime(pq.minutes);
            launcherWindow.closeMenu();
        }
    }

    function buildFilteredList() {
        var allApps = DesktopEntries.applications.values;
        var query = ctrl.searchText.trim();
        var queryLower = query.toLowerCase();
        var queryLen = queryLower.length;

        // Track async search results to force QML to re-evaluate this function
        var _fileSearchDep = ctrl.fileSearchResults;
        var _bookmarkSearchDep = ctrl.bookmarkSearchResults;
        var _recStateDep = ScreenRecord.recording;
        var _recAudioDep = ScreenRecord.recordAudio;
        var _dndDep = DoNotDisturb.enabled;
        var _pomRunDep = Pomodoro.isRunning;
        var _pomModeDep = Pomodoro.mode;
        var _pomSessionsDep = Pomodoro.completedSessions;
        var _pomShowDep = Pomodoro.shouldShow;

        var results = [];

        // --- App results ---
        if (query === "") {
            // No query: top apps by frecency only — full catalog floods the list
            var sortedApps = allApps.filter(app => {
                if (!app.name)
                    return false;
                var n = app.name.toLowerCase();
                for (var k = 0; k < hiddenKeywords.length; k++) {
                    if (n.includes(hiddenKeywords[k])) return false;
                }
                return true;
            }).sort((a, b) => {
                var freqA = ctrl.appFrequencies[a.id] || 0;
                var freqB = ctrl.appFrequencies[b.id] || 0;
                if (freqB !== freqA)
                    return freqB - freqA;
                return (a.name || "").localeCompare(b.name || "");
            });

            var emptyCap = Math.min(sortedApps.length, launcherWindow.maxEmptyApps);
            for (var i = 0; i < emptyCap; i++) {
                results.push({ type: "app", entry: sortedApps[i] });
            }
            return results;
        }

        if (launcherWindow.connectivityModeActive)
            return [];

        if (launcherWindow.musicModeActive)
            return [];

        if (launcherWindow.nightModeActive)
            return [];

        if (launcherWindow.clipModeActive)
            return [];

        if (launcherWindow.dndModeActive) {
            var dq = launcherWindow.dndQuery;
            var dndResults = [];
            if (!dq.command || dq.command === "on")
                dndResults.push({ type: "system_command", actionId: "dnd_on", name: "Enable Do Not Disturb", description: "Silence notification popups", icon: "󰂛" });
            if (!dq.command || dq.command === "off")
                dndResults.push({ type: "system_command", actionId: "dnd_off", name: "Disable Do Not Disturb", description: "Show notification popups again", icon: "󰂚" });
            if (dq.command === "toggle")
                dndResults.push({
                    type: "system_command",
                    actionId: "dnd_toggle",
                    name: DoNotDisturb.enabled ? "Disable Do Not Disturb" : "Enable Do Not Disturb",
                    description: "Toggle notification popups",
                    icon: DoNotDisturb.enabled ? "󰂛" : "󰂚"
                });
            return dndResults;
        }

        if (launcherWindow.pomModeActive) {
            var pq = launcherWindow.pomQuery;
            var pomResults = [];

            if (pq.command === "set" && pq.minutes > 0) {
                pomResults.push({
                    type: "system_command",
                    actionId: "pom_set",
                    actionValue: pq.minutes,
                    name: "Start " + pq.minutes + " min " + Pomodoro.modeLabel,
                    description: "Set duration and start the timer",
                    icon: "󱎫"
                });
                return pomResults;
            }

            if (pq.command === "adjust") {
                var sign = pq.minutes > 0 ? "+" : "";
                pomResults.push({
                    type: "system_command",
                    actionId: "pom_adjust",
                    actionValue: pq.minutes,
                    name: "Adjust by " + sign + pq.minutes + " min",
                    description: "Change the current session length",
                    icon: "󰔟"
                });
                return pomResults;
            }

            if (pq.command === "work") {
                pomResults.push({ type: "system_command", actionId: "pom_work", name: "Focus Mode", description: "Switch to a focus session", icon: "󱎫" });
                return pomResults;
            }
            if (pq.command === "break") {
                pomResults.push({ type: "system_command", actionId: "pom_break", name: "Short Break", description: "Switch to a short break", icon: "󰅶" });
                return pomResults;
            }
            if (pq.command === "long") {
                pomResults.push({ type: "system_command", actionId: "pom_long", name: "Long Break", description: "Switch to a long break", icon: "󰒲" });
                return pomResults;
            }
            if (pq.command === "reset") {
                pomResults.push({ type: "system_command", actionId: "pom_reset", name: "Reset Timer", description: "Restore full duration for this mode", icon: "󰑐" });
                return pomResults;
            }

            // Bare "pom" / start / stop / toggle — keep the list light; modes live in the widget chips
            pomResults.push({
                type: "system_command",
                actionId: Pomodoro.isRunning ? "pom_stop" : "pom_start",
                name: Pomodoro.isRunning ? "Pause Timer" : "Start Timer",
                description: Pomodoro.modeLabel
                    + (Pomodoro.completedSessions > 0 ? " · " + Pomodoro.completedSessions + " done" : ""),
                icon: Pomodoro.isRunning ? "󰏤" : "󰐊"
            });
            if (Pomodoro.shouldShow)
                pomResults.push({ type: "system_command", actionId: "pom_reset", name: "Reset Timer", description: "Restore full duration for this mode", icon: "󰑐" });
            return pomResults;
        }

        if (launcherWindow.sliderModeActive) {
            var sq = launcherWindow.sliderQuery;
            var sliderResults = [];
            if (sq.mode === "vol") {
                if (sq.mute) {
                    sliderResults.push({ type: "system_command", actionId: "vol_mute", name: "Mute Volume", description: "Mute system audio", icon: "󰖁" });
                } else if (sq.value >= 0) {
                    sliderResults.push({ type: "system_command", actionId: "vol_set", actionValue: sq.value, name: "Set Volume", description: "Set system volume to " + sq.value + "%", icon: "󰕾" });
                }
            } else if (sq.mode === "bl" && sq.value >= 0) {
                sliderResults.push({ type: "system_command", actionId: "bl_set", actionValue: sq.value, name: "Set Backlight", description: "Set screen brightness to " + sq.value + "%", icon: "󰃠" });
            }
            return sliderResults;
        }

        if (launcherWindow.ssModeActive) {
            var ssCmd = launcherWindow.ssQuery ? launcherWindow.ssQuery.command : null;
            var ssResults = [];
            if (!ssCmd || ssCmd === "fullscreen")
                ssResults.push({ type: "system_command", actionId: "ss_fullscreen", name: "Screenshot Fullscreen", description: "Capture the entire screen", icon: "󰊓" });
            if (!ssCmd || ssCmd === "area")
                ssResults.push({ type: "system_command", actionId: "ss_area", name: "Screenshot Area", description: "Select a region to capture", icon: "󰆞" });
            if (!ssCmd || ssCmd === "window")
                ssResults.push({ type: "system_command", actionId: "ss_window", name: "Screenshot Window", description: "Capture the focused window", icon: "󰖯" });
            if (!ssCmd || ssCmd === "menu")
                ssResults.push({ type: "system_command", actionId: "ss_menu", name: "Screenshot Menu", description: "Open the capture overlay", icon: "󰍜" });
            return ssResults;
        }

        if (launcherWindow.recModeActive) {
            var recCmd = launcherWindow.recQuery ? launcherWindow.recQuery.command : null;
            var recResults = [];
            if (ScreenRecord.recording) {
                if (!recCmd || recCmd === "stop")
                    recResults.push({ type: "system_command", actionId: "rec_stop", name: "Stop Recording", description: "Finish and save the recording", icon: "󰓛" });
            } else {
                if (!recCmd || recCmd === "fullscreen")
                    recResults.push({ type: "system_command", actionId: "rec_fullscreen", name: "Record Fullscreen", description: "Record the entire screen", icon: "󰊓" });
                if (!recCmd || recCmd === "area")
                    recResults.push({ type: "system_command", actionId: "rec_area", name: "Record Area", description: "Select a region to record", icon: "󰆞" });
            }
            if (!recCmd || recCmd === "audio")
                recResults.push({ type: "system_command", actionId: "rec_audio_toggle", name: ScreenRecord.recordAudio ? "Disable Audio" : "Enable Audio", description: ScreenRecord.recordAudio ? "Record without microphone/system audio" : "Include audio in the recording", icon: ScreenRecord.recordAudio ? "󰍬" : "󰍭" });
            return recResults;
        }

        // Check if the user's search explicitly contains any of the hidden keywords
        var isSearchingHidden = false;
        for (var k = 0; k < hiddenKeywords.length; k++) {
            if (queryLower.includes(hiddenKeywords[k])) {
                isSearchingHidden = true;
                break;
            }
        }
        var scored = [];
        var appById = {};

        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];
            if (entry.id)
                appById[entry.id] = entry;

            // Hide apps matching hiddenKeywords unless explicitly searched for
            var nameLower = entry.name ? entry.name.toLowerCase() : "";
            var isHiddenApp = false;
            for (var hk = 0; hk < hiddenKeywords.length; hk++) {
                if (nameLower.includes(hiddenKeywords[hk])) {
                    isHiddenApp = true;
                    break;
                }
            }

            if (isHiddenApp && !isSearchingHidden) {
                continue;
            }

            var best = scoreMatch(entry.name, queryLower, queryLen);

            // Exact / prefix name hits don't need expensive secondary fields
            if (best < 800) {
                if (entry.genericName) {
                    var s = scoreMatch(entry.genericName, queryLower, queryLen);
                    if (s >= 200)
                        best = Math.max(best, s - 50);
                }

                if (best < 800 && entry.comment) {
                    var s = scoreMatch(entry.comment, queryLower, queryLen);
                    if (s >= 200)
                        best = Math.max(best, s - 100);
                }

                if (best < 800 && entry.keywords) {
                    for (var j = 0; j < entry.keywords.length; j++) {
                        var s = scoreMatch(entry.keywords[j], queryLower, queryLen);
                        if (s >= 200)
                            best = Math.max(best, s - 20);
                        if (best >= 800)
                            break;
                    }
                }

                if (best < 180 && entry.execString && entry.execString.toLowerCase().includes(queryLower)) {
                    best = Math.max(best, 180);
                }
            }

            if (best >= 0) {
                scored.push({
                    entry: entry,
                    score: best
                });
            }
        }

        // ──── Tier 1: Quickkey-boosted results ────
        var quickkeyMatches = ctrl.getQuickkeyMatches(query);
        var quickkeyBoostedIds = {};
        var appSlotsUsed = 0;
        var runningWindows = ctrl.getRunningWindows();
        var runningWindowsById = {};
        for (var w = 0; w < runningWindows.length; w++) {
            var win = runningWindows[w];
            if (win.appId) {
                if (!runningWindowsById[win.appId])
                    runningWindowsById[win.appId] = [];
                runningWindowsById[win.appId].push(win);
            }
        }

        for (var qk = 0; qk < quickkeyMatches.length; qk++) {
            if (appSlotsUsed >= launcherWindow.maxAppResults)
                break;

            var qkId = quickkeyMatches[qk].id;

            if (qkId.startsWith("emoji:")) {
                var emojiChar = qkId.substring(6);
                quickkeyBoostedIds[qkId] = true;
                results.push({
                    type: "emoji",
                    emoji: emojiChar,
                    display: ctrl.getEmojiDisplay(emojiChar)
                });
                continue;
            }

            var qkEntry = appById[qkId];
            if (!qkEntry) continue;

            quickkeyBoostedIds[qkId] = true;
            appSlotsUsed++;

            var qkWins = runningWindowsById[qkId];
            if (qkWins) {
                for (var qw = 0; qw < qkWins.length; qw++) {
                    results.push({
                        type: "focus",
                        entry: qkEntry,
                        windowId: qkWins[qw].id,
                        windowTitle: qkWins[qw].title || ""
                    });
                }
            }

            results.push({ type: "app", entry: qkEntry });
        }

        // ──── Tier 2: Standard fuzzy-match results ────
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            var freqA = ctrl.appFrequencies[a.entry.id] || 0;
            var freqB = ctrl.appFrequencies[b.entry.id] || 0;
            if (freqB !== freqA)
                return freqB - freqA;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });

        var maxAppActions = 3;
        var appActionsUsed = 0;

        for (var i = 0; i < scored.length; i++) {
            if (appSlotsUsed >= launcherWindow.maxAppResults)
                break;

            var appEntry = scored[i].entry;
            var entryId = appEntry.id || "";

            if (quickkeyBoostedIds[entryId]) continue;

            appSlotsUsed++;

            var appWins = runningWindowsById[entryId];
            if (appWins) {
                for (var aw = 0; aw < appWins.length; aw++) {
                    results.push({
                        type: "focus",
                        entry: appEntry,
                        windowId: appWins[aw].id,
                        windowTitle: appWins[aw].title || ""
                    });
                }
            }

            results.push({ type: "app", entry: appEntry });
        }

        // --- System Commands ---
        var valStr = "";
        var num = 0;
        if (queryLower.startsWith("vol ")) {
            valStr = queryLower.substring(4).trim();
            if (valStr === "mute") {
                results.push({ type: "system_command", actionId: "vol_mute", name: "Mute Volume", description: "Mute system audio", icon: "󰖁" });
            } else {
                num = parseInt(valStr);
                if (!isNaN(num) && num >= 0 && num <= 100) {
                    results.push({ type: "system_command", actionId: "vol_set", actionValue: num, name: "Set Volume", description: "Set system volume to " + num + "%", icon: "󰕾" });
                }
            }
        } else if (queryLower.startsWith("bl ")) {
            num = parseInt(queryLower.substring(3).trim());
            if (!isNaN(num) && num >= 0 && num <= 100) {
                results.push({ type: "system_command", actionId: "bl_set", actionValue: num, name: "Set Backlight", description: "Set screen brightness to " + num + "%", icon: "󰃠" });
            }
        } else if (queryLower === "shutdown" || queryLower === "poweroff") {
            results.push({ type: "system_command", actionId: "shutdown", name: "Shutdown", description: "Turn off the computer", icon: "󰐥" });
        } else if (queryLower === "reboot" || queryLower === "restart") {
            results.push({ type: "system_command", actionId: "reboot", name: "Reboot", description: "Restart the computer", icon: "󰜉" });
        } else if (queryLower === "sleep" || queryLower === "suspend") {
            results.push({ type: "system_command", actionId: "sleep", name: "Sleep", description: "Suspend to RAM", icon: "󰒲" });
        } else if (queryLower === "lock" || queryLower === "lockscreen") {
            results.push({ type: "system_command", actionId: "lock", name: "Lock Screen", description: "Lock the session", icon: "󰌾" });
        } else if (queryLower === "audio out hdmi") {
            results.push({ type: "system_command", actionId: "audio_out_hdmi", name: "Audio Out HDMI", description: "Set default audio output to HDMI", icon: "󰡁" });
        }

        // --- Music results (only outside music mode) ---
        if (!launcherWindow.musicModeActive && queryLen >= 2) {
            var library = BackendDaemon.musicLibrary ? BackendDaemon.musicLibrary.albums : [];
            if (library && library.length > 0) {
                var musicScored = [];
                for (var m = 0; m < library.length; m++) {
                    var album = library[m];
                    var albumScore = Math.max(
                        scoreMatch(album.title, queryLower, queryLen),
                        scoreMatch(album.artist, queryLower, queryLen)
                    );
                    if (albumScore >= 0) {
                        musicScored.push({ type: "music_album", album: album, score: albumScore + 10 });
                    }

                    var tracks = album.tracks || [];
                    for (var t = 0; t < tracks.length; t++) {
                        var track = tracks[t];
                        var trackScore = scoreMatch(track.title, queryLower, queryLen);
                        if (trackScore >= 0) {
                            musicScored.push({ type: "music_track", album: album, trackIndex: t, track: track, score: trackScore });
                        }
                    }
                }
                musicScored.sort((a, b) => b.score - a.score);
                var maxMusic = Math.min(musicScored.length, launcherWindow.maxMusicResults);
                for (var ms = 0; ms < maxMusic; ms++) {
                    results.push(musicScored[ms]);
                }
            }
        }

        // --- File search results (from Rust backend) ---
        if (queryLen >= 3) {
            var fileResults = ctrl.fileSearchResults;
            if (fileResults && ctrl.fileSearchQuery.toLowerCase() === queryLower) {
                var maxFiles = Math.min(fileResults.length, launcherWindow.maxFileResults);
                for (var fi = 0; fi < maxFiles; fi++) {
                    results.push({
                        type: "file",
                        file: fileResults[fi]
                    });
                }
            }
        }

        // --- Bookmark search results (from Rust backend) ---
        if (queryLen >= 2) {
            var bookmarkResults = ctrl.bookmarkSearchResults;
            if (bookmarkResults && ctrl.bookmarkSearchQuery.toLowerCase() === queryLower) {
                var maxBookmarks = Math.min(bookmarkResults.length, 5);
                for (var bi = 0; bi < maxBookmarks; bi++) {
                    results.push({
                        type: "bookmark",
                        bookmark: bookmarkResults[bi]
                    });
                }
            }
        }

        // --- Fallback action: Open in WolframAlpha ---
        if (ctrl.looksLikeMath(query)) {
            results.push({
                type: "action",
                actionId: "wolfram",
                name: "Open in WolframAlpha",
                description: query,
                icon: "󰃬",
                iconFamily: "JetBrainsMono Nerd Font"
            });
        }

        // --- Fallback action: Dictionary ---
        if (query.indexOf(" ") === -1 && (ctrl.dictStatus === "ok" || ctrl.dictStatus === "loading")) {
            results.push({
                type: "action",
                actionId: "dictionary",
                name: "Dictionary",
                description: query,
                icon: "󰗊",
                iconFamily: "JetBrainsMono Nerd Font"
            });
        }

        // --- Emoji results (skip 1-char queries — they match nearly everything) ---
        var isEmojiQuery = queryLower.indexOf("emoji") !== -1;
        var emojiSearchQuery = isEmojiQuery ? queryLower.replace(/emojis?/g, "").trim() : query;
        if (emojiSearchQuery === "") {
            emojiSearchQuery = query;
        }

        var emojiQueryLen = emojiSearchQuery.length;
        if (emojiQueryLen >= 2 || (isEmojiQuery && emojiQueryLen > 0)) {
            var emojiResults = ctrl.filterEmojis(emojiSearchQuery);

            for (var e = 0; e < emojiResults.length; e++) {
                emojiResults[e]._freq = ctrl.getAppFrecency("emoji:" + emojiResults[e].emoji);
            }

            emojiResults.sort((a, b) => {
                return b._freq - a._freq;
            });

            var maxEmojis = Math.min(emojiResults.length, launcherWindow.maxEmojiResults);
            var emojiItemsToInsert = [];

            for (var ei = 0; ei < maxEmojis; ei++) {
                var eId = "emoji:" + emojiResults[ei].emoji;
                if (!quickkeyBoostedIds[eId]) {
                    var eItem = {
                        type: "emoji",
                        emoji: emojiResults[ei].emoji,
                        display: emojiResults[ei].display
                    };
                    
                    if (isEmojiQuery) {
                        emojiItemsToInsert.push(eItem);
                    } else {
                        results.push(eItem);
                    }
                }
            }

            if (isEmojiQuery && emojiItemsToInsert.length > 0) {
                for (var j = emojiItemsToInsert.length - 1; j >= 0; j--) {
                    results.unshift(emojiItemsToInsert[j]);
                }
            }
        }

        // --- Fallback action: Search the web ---
        results.push({
            type: "action",
            actionId: "websearch",
            name: "Search the web",
            description: "\"" + query + "\" — DuckDuckGo",
            icon: "helium",
            iconFamily: "__icon_theme__"
        });

        return results;
    }

    LauncherBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (launcherWindow.menuOpen) {
                closeMenu();
            } else {
                ctrl.clearStates();
                closeAnim.stop();
                launcherWindow.menuOpen = true;
                openAnim.start();
            }
        }

        onCloseMenuRequested: closeMenu()
    }

    function closeMenu() {
        if (contentLoader.item)
            contentLoader.item.resetSpecialViewState();
        bluetoothConnectedNotifTimer.stop();
        openAnim.stop();
        LauncherState.open = false;
        closeAnim.start();
        ctrl.commitRecents();
    }

    LazyLoader {
        id: contentLoader

        activeAsync: launcherWindow.menuOpen

        component: Component {
            Item {
                id: lazyContentRoot

                parent: launcherWindow.contentItem
                width: 640 + 48
                height: 609
                x: 0
                anchors.verticalCenter: parent.verticalCenter

                function syncFilePreviewForCurrentItem() {
                    if (launcherWindow.specialViewActive)
                        return;
                    var item = searchModel.values[listView.currentIndex];
                    if (item && item.type === "file") {
                        launcherWindow.hasFileSelected = true;
                        launcherWindow.selectedFileData = item.file;
                        ctrl.requestFilePreview(item.file.path);
                    } else {
                        launcherWindow.hasFileSelected = false;
                        launcherWindow.selectedFileData = null;
                    }
                }

                function activeConnectivityView() {
                    if (launcherWindow.btModeActive)
                        return btView;
                    if (launcherWindow.wifiModeActive)
                        return wifiView;
                    return null;
                }

                function activeSpecialView() {
                    if (launcherWindow.clipModeActive)
                        return clipboardView;
                    if (launcherWindow.musicModeActive)
                        return musicView;
                    return activeConnectivityView();
                }

                function refreshClipboard() {
                    clipboardView.refresh();
                }

                function cycleSpecialSelection(forward) {
                    var view = activeSpecialView();
                    if (!view)
                        return;
                    if (forward)
                        view.incrementSelection();
                    else
                        view.decrementSelection();
                    scrollSpecialToSelection();
                }

                function scrollSpecialToSelection() {
                    if (launcherWindow.musicModeActive) {
                        var maxY = Math.max(0, musicScroll.contentHeight - musicScroll.height);
                        musicScroll.contentY = Math.max(0, Math.min(musicView.selectedScrollY - musicScroll.height * 0.25, maxY));
                        return;
                    }
                    scrollConnectivityToSelection();
                }

                function activateSpecialSelection() {
                    if (launcherWindow.clipModeActive)
                        return clipboardView.activateSelected();
                    if (launcherWindow.musicModeActive)
                        return activateMusicSelection();
                    return activateConnectivitySelection();
                }

                function activateMusicSelection() {
                    var mq = launcherWindow.musicQuery;
                    if (!mq)
                        return false;
                    if (mq.command) {
                        launcherWindow.executeMusicCommand(mq.command);
                        return true;
                    }
                    if (mq.filter !== "")
                        return musicView.activateTopMatch();
                    return musicView.activateSelected();
                }

                function cycleConnectivitySelection(forward) {
                    var view = activeConnectivityView();
                    if (!view)
                        return;
                    if (forward)
                        view.incrementSelection();
                    else
                        view.decrementSelection();
                    scrollConnectivityToSelection();
                }

                function scrollConnectivityToSelection() {
                    // Views handle their own scroll position internally
                }

                function activateConnectivitySelection() {
                    var view = activeConnectivityView();
                    if (!view)
                        return false;
                    if (!view.activateSelected())
                        return false;
                    // Bluetooth should close when the device reports `connected`;
                    // Wi-Fi keeps the fixed close timer.
                    if (launcherWindow.wifiModeActive)
                        connectivityCloseTimer.restart();
                    return true;
                }

                function resetSpecialViewState() {
                    connectivityCloseTimer.stop();
                    btView.resetConnecting();
                    wifiView.resetConnecting();
                }

                function resetConnectivityState() {
                    resetSpecialViewState();
                }

                Timer {
                    id: connectivityCloseTimer
                    interval: 850
                    onTriggered: launcherWindow.closeMenu()
                }

                function handleSpecialNavigationKey(event) {
                    if (launcherWindow.clipModeActive) {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            var clipForward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                            if (clipForward)
                                clipboardView.incrementSelection();
                            else
                                clipboardView.decrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Down) {
                            clipboardView.incrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Up) {
                            clipboardView.decrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            clipboardView.activateSelected();
                            event.accepted = true;
                            return true;
                        }
                        return false;
                    }
                    if (launcherWindow.musicModeActive) {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            var forward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                            cycleSpecialSelection(forward);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Down) {
                            cycleSpecialSelection(true);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Up) {
                            cycleSpecialSelection(false);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            activateMusicSelection();
                            event.accepted = true;
                            return true;
                        }
                        return false;
                    }
                    return handleConnectivityNavigationKey(event);
                }

                function handleConnectivityNavigationKey(event) {
                    if (!launcherWindow.connectivityModeActive)
                        return false;
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        var forward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                        cycleConnectivitySelection(forward);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Down) {
                        cycleConnectivitySelection(true);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Up) {
                        cycleConnectivitySelection(false);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        activateConnectivitySelection();
                        event.accepted = true;
                        return true;
                    }
                    return false;
                }

                Component.onCompleted: {
                    searchField.forceActiveFocus();
                }

                // Shadow tracks the revealed area, offset past the dock so the
                // launcher feels connected to the bar on the left edge.
                Rectangle {
                    id: shadowCaster
                    x: 44
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: Math.max(0, (688 - 44) * launcherWindow.openProgress)
                    radius: 26
                    color: "black"
                    visible: false
                }

                MultiEffect {
                    anchors.fill: shadowCaster
                    source: shadowCaster
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 8
                    shadowHorizontalOffset: 4
                    opacity: launcherWindow.openProgress
                }

                // Reveal mask: flat left edge, rounded right leading edge
                Item {
                    id: mainUiMask
                    anchors.fill: mainUi
                    visible: false
                    layer.enabled: true
                    layer.smooth: true

                    // Rounded reveal area that grows from left
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: 0
                        width: Math.max(0, parent.width * launcherWindow.openProgress)
                        radius: 28
                        color: "black"
                    }
                    // Flat left edge filler (covers the left rounded corners)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: 0
                        width: Math.min(48, Math.max(0, parent.width * launcherWindow.openProgress))
                        color: "black"
                    }
                }

                Rectangle {
                    id: mainUi
                    width: 688

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: Theme.surface
                    radius: 28
                    border.width: 1
                    border.color: Theme.surface_container_high
                    focus: true

                    // Swallow clicks on the card so it doesn't dismiss
                    MouseArea { anchors.fill: parent }

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mainUiMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    LauncherWeatherData {
                        id: launcherWeatherData
                    }

                    Item {
                        id: edgeBanner
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 200
                        clip: true

                        property real bannerBlend: (launcherWindow.weatherModeActive || launcherWindow.colorPickerModeActive || launcherWindow.nightModeActive) ? 1 : 0
                        property real weatherBlend: launcherWindow.weatherModeActive ? 1 : 0
                        property real colorBlend: launcherWindow.colorPickerModeActive ? 1 : 0
                        property real nightBlend: launcherWindow.nightModeActive ? 1 : 0

                        Behavior on bannerBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                        Behavior on weatherBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                        Behavior on colorBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                        Behavior on nightBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

                        Connections {
                            target: launcherWindow
                            function onWeatherModeActiveChanged() {
                                bannerShimmer.restart();
                            }
                            function onNightModeActiveChanged() {
                                bannerShimmer.restart();
                            }
                        }

                        // --- Pink launcher background ---
                        Item {
                            id: pinkLayer
                            anchors.fill: parent
                            opacity: 1 - edgeBanner.bannerBlend
                            scale: 1 - 0.05 * edgeBanner.bannerBlend
                            transformOrigin: Item.Center

                            Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                            Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                color: "#f5bde6"
                            }

                            Rectangle {
                                width: 320
                                height: 320
                                radius: 160
                                color: "#ffffff"
                                opacity: 0.40
                                x: -20
                                y: -50
                                transformOrigin: Item.Center

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 180; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -60; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -20; duration: 15000; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                    NumberAnimation { to: -100; duration: 17000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 40; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -50; duration: 16000; easing.type: Easing.InOutSine }
                                }
                                NumberAnimation on rotation {
                                    from: 0; to: 360; duration: 30000; loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                }
                            }

                            Rectangle {
                                width: 300
                                height: 300
                                radius: 150
                                color: "#c6a0f6"
                                opacity: 0.60
                                x: 350
                                y: -40
                                transformOrigin: Item.Center

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 150; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 480; duration: 19000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 350; duration: 17000; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 60; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -120; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -40; duration: 16000; easing.type: Easing.InOutSine }
                                }
                                NumberAnimation on rotation {
                                    from: 360; to: 0; duration: 35000; loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || launcherWindow.weatherModeActive
                                }
                            }
                        }

                        // --- Weather reactive background ---
                        Item {
                            id: weatherBannerLayer
                            anchors.fill: parent
                            opacity: edgeBanner.weatherBlend
                            scale: 1.04 - 0.04 * edgeBanner.weatherBlend
                            transformOrigin: Item.Center

                            Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: launcherWeatherData.gradTop
                                        Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: launcherWeatherData.gradBottom
                                        Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                                    }
                                }
                            }

                            WeatherBackground {
                                id: bannerWeatherAnim
                                anchors.fill: parent
                                weatherCode: launcherWeatherData._code
                                temperature: launcherWeatherData._temp
                                visible: edgeBanner.weatherBlend > 0.02
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.7; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                                }
                            }
                        }

                        // --- Color Picker background ---
                        Item {
                            id: colorPickerBannerLayer
                            anchors.fill: parent
                            opacity: edgeBanner.colorBlend
                            scale: 1.04 - 0.04 * edgeBanner.colorBlend
                            transformOrigin: Item.Center
                            visible: opacity > 0.02

                            Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                color: colorPickerView.selectedColor
                            }
                        }

                        // --- Night Light background ---
                        Item {
                            id: nightBannerLayer
                            anchors.fill: parent
                            opacity: edgeBanner.nightBlend
                            scale: 1.04 - 0.04 * edgeBanner.nightBlend
                            transformOrigin: Item.Center
                            visible: opacity > 0.02

                            Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
                            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#1a1040" }
                                    GradientStop { position: 0.4; color: "#2d1b69" }
                                    GradientStop { position: 0.7; color: "#4a1942" }
                                    GradientStop { position: 1.0; color: "#e65100" }
                                }
                            }

                            Rectangle {
                                width: 180
                                height: 180
                                radius: 90
                                color: "#ffb74d"
                                opacity: 0.12
                                x: parent.width - 140
                                y: -30

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || !launcherWindow.nightModeActive
                                    NumberAnimation { to: 0.20; duration: 3000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.08; duration: 3000; easing.type: Easing.InOutSine }
                                }
                            }

                            Rectangle {
                                width: 120
                                height: 120
                                radius: 60
                                color: "#ff8f00"
                                opacity: 0.10
                                x: 60
                                y: 40

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.menuOpen || !launcherWindow.nightModeActive
                                    NumberAnimation { to: 0.18; duration: 4000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.06; duration: 3500; easing.type: Easing.InOutSine }
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 40
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: -10
                                text: "󰖔"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 64 }
                                color: Qt.rgba(1, 0.72, 0.3, 0.35)
                            }
                        }

                        // --- Transition shimmer ---
                        Rectangle {
                            id: shimmerBar
                            z: 3
                            width: parent.width * 0.45
                            height: parent.height
                            y: 0
                            x: -width
                            opacity: 0
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.22) }
                                GradientStop { position: 0.65; color: Qt.rgba(1, 1, 1, 0.0) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }

                            SequentialAnimation {
                                id: bannerShimmer
                                running: false

                                PropertyAnimation {
                                    target: shimmerBar
                                    property: "opacity"
                                    from: 0; to: 0.85; duration: 80
                                }
                                NumberAnimation {
                                    target: shimmerBar
                                    property: "x"
                                    from: -shimmerBar.width
                                    to: edgeBanner.width + shimmerBar.width
                                    duration: 420
                                    easing.type: Easing.InOutQuad
                                }
                                PropertyAnimation {
                                    target: shimmerBar
                                    property: "opacity"
                                    to: 0; duration: 160
                                }
                            }
                        }

                        LauncherWeatherHeader {
                            anchors.fill: parent
                            anchors.margins: 24
                            anchors.leftMargin: 72
                            anchors.bottomMargin: 76
                            z: 2
                            weather: launcherWeatherData
                            headerReveal: edgeBanner.weatherBlend
                            visible: edgeBanner.weatherBlend > 0.02
                            enabled: false
                        }
                    }

                    Keys.onPressed: event => {
                        if (searchField.activeFocus)
                            return;

                        if (event.key === Qt.Key_Escape) {
                            launcherWindow.closeMenu();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_I) {
                            searchField.forceActiveFocus();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
                            if (!launcherWindow.specialViewActive && listView.currentItem && listView.currentItem.hasActions) {
                                var count = listView.currentItem.actionCount;
                                if (event.modifiers & Qt.ShiftModifier) {
                                    launcherWindow.appActionIndex = launcherWindow.appActionIndex <= 0 ? count - 1 : launcherWindow.appActionIndex - 1;
                                } else {
                                    launcherWindow.appActionIndex = launcherWindow.appActionIndex >= count - 1 ? 0 : launcherWindow.appActionIndex + 1;
                                }
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            if (lazyContentRoot.handleSpecialNavigationKey(event))
                                return;
                            if (launcherWindow.specialViewActive) {
                                event.accepted = true;
                                return;
                            }
                            if ((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab) {
                                if (listView.currentIndex <= 0) {
                                    listView.currentIndex = listView.count - 1;
                                } else {
                                    listView.decrementCurrentIndex();
                                }
                            } else {
                                if (listView.currentIndex >= listView.count - 1) {
                                    listView.currentIndex = 0;
                                } else {
                                    listView.incrementCurrentIndex();
                                }
                            }
                            event.accepted = true;
                        } else if (lazyContentRoot.handleSpecialNavigationKey(event)) {
                            return;
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.connectivityModeActive) {
                            lazyContentRoot.activateConnectivitySelection();
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_J || event.key === Qt.Key_Down)) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_K || event.key === Qt.Key_Up)) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (launcherWindow.colorPickerModeActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            colorPickerView.copyColor(colorPickerView.hexValue, "HEX");
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (listView.currentItem) {
                                listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
                            } else if (ctrl.calcResult !== "") {
                                ctrl.copyResult();
                            }
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        id: searchArea
                        z: 3
                        height: 64
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 48 + 32
                        anchors.rightMargin: 32

                        anchors.verticalCenter: edgeBanner.bottom

                        radius: height / 2
                        color: Theme.surface_container_highest

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowBlur: 1.0
                            shadowColor: "#40000000"
                            shadowVerticalOffset: 4
                        }

                        TextField {
                            id: searchField
                            // Prevent `onAccepted` from firing when we handle Return in `Keys.onReturnPressed`.
                            property bool suppressAcceptedNext: false
                            anchors.fill: parent
                            leftPadding: 60
                            rightPadding: 24

                            font {
                                family: "Google Sans"
                                pixelSize: 22
                                weight: Font.Medium
                            }
                            color: Theme.on_surface
                            selectionColor: Theme.primary_container
                            selectedTextColor: Theme.on_primary_container

                            placeholderText: "Search"
                            placeholderTextColor: Theme.on_surface_variant

                            onAccepted: {
                                if (suppressAcceptedNext) {
                                    suppressAcceptedNext = false;
                                    return;
                                }
                                if (launcherWindow.clipModeActive) {
                                    clipboardView.activateSelected();
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                } else if (launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                } else if (launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                } else if (launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                } else if (launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                } else if (launcherWindow.colorPickerModeActive) {
                                    colorPickerView.copyColor(colorPickerView.hexValue, "HEX");
                                } else if (!launcherWindow.specialViewActive) {
                                    if (listView.currentItem)
                                        listView.currentItem.activate(false);
                                    else if (ctrl.calcResult !== "")
                                        ctrl.copyResult();
                                }
                            }

                            Keys.onReturnPressed: event => {
                                // Ensure we don't also run `onAccepted` for the same keypress.
                                suppressAcceptedNext = true;
                                if (launcherWindow.clipModeActive) {
                                    clipboardView.activateSelected();
                                    event.accepted = true;
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                    event.accepted = true;
                                } else if (launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                    event.accepted = true;
                                } else if (launcherWindow.colorPickerModeActive) {
                                    colorPickerView.copyColor(colorPickerView.hexValue, "HEX");
                                    event.accepted = true;
                                } else if (!launcherWindow.specialViewActive) {
                                    if (listView.currentItem) {
                                        if (listView.currentItem.hasActions && launcherWindow.appActionIndex >= 0) {
                                            listView.currentItem.activateAction(launcherWindow.appActionIndex);
                                        } else {
                                            listView.currentItem.activate(false);
                                        }
                                    } else if (ctrl.calcResult !== "") {
                                        ctrl.copyResult();
                                    }
                                    event.accepted = true;
                                }
                            }

                            background: Item {
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    font {
                                        family: "JetBrainsMono Nerd Font"
                                        pixelSize: 28
                                    }
                                    color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }

                            onTextChanged: {
                                ctrl.searchText = text;
                                listView.currentIndex = 0;
                                if (launcherWindow.weatherModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                    BackendDaemon.send({ action: "weather_refresh" });
                                } else if (launcherWindow.colorPickerModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.connectivityModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.musicModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.sliderModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.dndModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.pomModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                    if (launcherWindow.pomQuery.minutes > 0)
                                        pomWidget.pendingMinutes = launcherWindow.pomQuery.minutes;
                                    else
                                        pomWidget.pendingMinutes = -1;
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.clipModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else {
                                    Qt.callLater(syncFilePreviewForCurrentItem);
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    mainUi.forceActiveFocus();
                                    event.accepted = true;
                                } else if (launcherWindow.nightModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                    var step = event.key === Qt.Key_Right ? 5 : -5;
                                    NightLight.setIntensity(NightLight.intensity + step);
                                    if (!NightLight.enabled) NightLight.enable();
                                    event.accepted = true;
                                } else if (launcherWindow.sliderModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                    var delta = event.key === Qt.Key_Right ? 0.05 : -0.05;
                                    if (launcherWindow.volSliderActive) volSliderWidget.nudge(delta);
                                    else if (launcherWindow.blSliderActive) blSliderWidget.nudge(delta);
                                    event.accepted = true;
                                } else if (launcherWindow.pomModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && !Pomodoro.isRunning) {
                                    var step = event.key === Qt.Key_Right ? 5 : -5;
                                    var base = pomWidget.pendingMinutes > 0
                                        ? pomWidget.pendingMinutes
                                        : Math.round(Pomodoro.currentDuration / 60);
                                    pomWidget.commitMinutes(base + step);
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
                                    if (!launcherWindow.specialViewActive && listView.currentItem && listView.currentItem.hasActions) {
                                        var count = listView.currentItem.actionCount;
                                        if (event.modifiers & Qt.ShiftModifier) {
                                            launcherWindow.appActionIndex = launcherWindow.appActionIndex <= 0 ? count - 1 : launcherWindow.appActionIndex - 1;
                                        } else {
                                            launcherWindow.appActionIndex = launcherWindow.appActionIndex >= count - 1 ? 0 : launcherWindow.appActionIndex + 1;
                                        }
                                        event.accepted = true;
                                    }
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    if (lazyContentRoot.handleSpecialNavigationKey(event))
                                        return;
                                    if (launcherWindow.specialViewActive) {
                                        event.accepted = true;
                                        return;
                                    }
                                    if ((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab) {
                                        if (listView.currentIndex <= 0) {
                                            listView.currentIndex = listView.count - 1;
                                        } else {
                                            listView.decrementCurrentIndex();
                                        }
                                    } else {
                                        if (listView.currentIndex >= listView.count - 1) {
                                            listView.currentIndex = 0;
                                        } else {
                                            listView.incrementCurrentIndex();
                                        }
                                    }
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                    event.accepted = true;
                                } else if (lazyContentRoot.handleSpecialNavigationKey(event)) {
                                    return;
                                } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                    if (listView.currentItem) {
                                        if (listView.currentItem.hasActions && launcherWindow.appActionIndex >= 0) {
                                            listView.currentItem.activateAction(launcherWindow.appActionIndex);
                                        } else {
                                            listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
                                        }
                                    } else if (ctrl.calcResult !== "") {
                                        ctrl.copyResult();
                                    }
                                    event.accepted = true;
                                } else if (launcherWindow.colorPickerModeActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                    colorPickerView.copyColor(colorPickerView.hexValue, "HEX");
                                    event.accepted = true;
                                } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier)))) {
                                    listView.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)))) {
                                    listView.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // --- Calculator Result Card ---
                    Item {
                        id: calcCard
                        visible: ctrl.calcResult !== "" && !launcherWindow.colorPickerModeActive && !launcherWindow.connectivityModeActive && !launcherWindow.musicModeActive && !launcherWindow.sliderModeActive && !launcherWindow.nightModeActive && !launcherWindow.clipModeActive && !launcherWindow.captureModeActive && !launcherWindow.dndModeActive && !launcherWindow.pomModeActive
                        anchors.top: searchArea.bottom
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 48 + 32
                        anchors.rightMargin: 32
                        height: visible ? calcCardContent.height : 0
                        clip: true

                        Behavior on height {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            id: calcCardContent
                            width: parent.width
                            height: 72
                            radius: 20
                            color: Theme.primary_container

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 16
                                spacing: 12

                                // Calculator icon
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰃬"
                                    font {
                                        family: "JetBrainsMono Nerd Font"
                                        pixelSize: 24
                                    }
                                    color: Theme.on_primary_container
                                }

                                // Expression and result
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 130
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: ctrl.calcExpression
                                        color: Theme.on_primary_container
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                        font {
                                            family: "Google Sans"
                                            pixelSize: 13
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        text: ctrl.calcResult
                                        color: Theme.on_primary_container
                                        elide: Text.ElideRight
                                        font {
                                            family: "Google Sans"
                                            pixelSize: 18
                                            weight: Font.Bold
                                        }
                                    }
                                }

                                // Copy button
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 70
                                    height: 32
                                    radius: 16
                                    color: calcCopyMouse.containsMouse ? Theme.primary : Qt.tint(Theme.primary_container, Qt.rgba(Theme.on_primary_container.r, Theme.on_primary_container.g, Theme.on_primary_container.b, 0.12))

                                    Behavior on color {
                                        ColorAnimation { duration: 100 }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Copy"
                                            color: calcCopyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                            font {
                                                family: "Google Sans"
                                                pixelSize: 12
                                                weight: Font.Medium
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰆏"
                                            color: calcCopyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                            font {
                                                family: "JetBrainsMono Nerd Font"
                                                pixelSize: 14
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: calcCopyMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ctrl.copyResult()
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: belowSearchArea
                        anchors.top: calcCard.visible ? calcCard.bottom : searchArea.bottom
                        anchors.topMargin: launcherWindow.specialViewActive ? 0 : 16
                        Behavior on anchors.topMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true

                        Item {
                            id: launcherResultsLayer
                            anchors.fill: parent
                            opacity: launcherWindow.specialViewActive ? 0 : 1
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            Column {
                                id: sliderWidgetArea
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: sliderWidgetArea.visible ? implicitHeight : 0
                                visible: launcherWindow.sliderModeActive || launcherWindow.captureModeActive || launcherWindow.dndModeActive || launcherWindow.pomModeActive
                                spacing: 8
                                topPadding: 8
                                bottomPadding: 4

                                Behavior on height {
                                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                                }

                                LauncherSliderWidget {
                                    id: volSliderWidget
                                    width: parent.width
                                    active: launcherWindow.volSliderActive
                                    label: "Volume"
                                    accent: Theme.primary
                                    value: Math.min(1, launcherWindow.pipewireSink?.audio?.volume ?? 0)
                                    icon: {
                                        if (launcherWindow.pipewireSink?.audio?.muted ?? true)
                                            return "󰖁";
                                        if (value >= 0.6)
                                            return "󰕾";
                                        if (value >= 0.3)
                                            return "󰖀";
                                        return "󰕿";
                                    }
                                    onMoved: v => {
                                        if (launcherWindow.pipewireSink?.audio) {
                                            launcherWindow.pipewireSink.audio.muted = false;
                                            launcherWindow.pipewireSink.audio.volume = v;
                                        }
                                    }
                                }

                                LauncherSliderWidget {
                                    id: blSliderWidget
                                    width: parent.width
                                    active: launcherWindow.blSliderActive
                                    label: "Brightness"
                                    accent: Theme.tertiary
                                    value: Brightness.value
                                    icon: {
                                        if (value >= 0.7) return "󰃠";
                                        if (value >= 0.3) return "󰃝";
                                        return "󰃞";
                                    }
                                    onMoved: v => Brightness.setPercent(v * 100)
                                }

                                LauncherScreenshotWidget {
                                    id: ssWidget
                                    width: parent.width
                                    active: launcherWindow.ssModeActive
                                    onAction: id => {
                                        if (id === "fullscreen")
                                            ctrl.executeSystemCommand("ss_fullscreen");
                                        else if (id === "area")
                                            ctrl.executeSystemCommand("ss_area");
                                        else if (id === "window")
                                            ctrl.executeSystemCommand("ss_window");
                                        else if (id === "menu")
                                            ctrl.executeSystemCommand("ss_menu");
                                    }
                                }

                                LauncherRecordWidget {
                                    id: recWidget
                                    width: parent.width
                                    active: launcherWindow.recModeActive
                                    onAction: id => {
                                        if (id === "fullscreen")
                                            ctrl.executeSystemCommand("rec_fullscreen");
                                        else if (id === "area")
                                            ctrl.executeSystemCommand("rec_area");
                                        else if (id === "stop")
                                            ctrl.executeSystemCommand("rec_stop");
                                    }
                                }

                                LauncherDndWidget {
                                    id: dndWidget
                                    width: parent.width
                                    active: launcherWindow.dndModeActive
                                }

                                LauncherPomodoroWidget {
                                    id: pomWidget
                                    width: parent.width
                                    active: launcherWindow.pomModeActive
                                }
                            }

                            Item {
                                id: listContainer
                                anchors.top: sliderWidgetArea.visible ? sliderWidgetArea.bottom : parent.top
                                anchors.bottom: footer.top
                                anchors.left: parent.left
                                width: parent.width * (1 - 0.48 * launcherWindow.fileSplitBlend)
                                Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                                clip: true

                                ListView {
                                    id: listView
                                    anchors.fill: parent
                                    topMargin: 12
                                    bottomMargin: 24
                                    spacing: 4
                                    clip: true

                                    // Recycle heavy delegates across keystroke model swaps
                                    reuseItems: true
                                    cacheBuffer: 160
                                    highlightMoveDuration: 80
                                    highlightFollowsCurrentItem: true
                                    delegate: LauncherDelegate {}

                                    model: ScriptModel {
                                        id: searchModel
                                        values: launcherWindow.buildFilteredList()
                                    }

                                    onCurrentIndexChanged: syncFilePreviewForCurrentItem()

                                    onCountChanged: Qt.callLater(syncFilePreviewForCurrentItem)
                                }

                                Rectangle {
                                    anchors {
                                        bottom: parent.bottom
                                        left: parent.left
                                        right: parent.right
                                    }
                                    height: 48
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: "transparent"
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: Theme.surface
                                        }
                                    }
                                }
                            }

                            Text {
                                id: emptyMessage
                                anchors.centerIn: listContainer
                                text: "No results found"
                                visible: listView.count === 0
                                color: Theme.on_surface_variant
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 18
                                }
                            }

                            Item {
                                id: footer
                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                }
                                width: listContainer.width
                                height: 32
                            }
                        }

                        LauncherWeatherView {
                            id: weatherView
                            z: launcherWindow.weatherModeActive ? 2 : 0
                            enabled: launcherWindow.weatherModeActive
                            weather: launcherWeatherData
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 20
                            anchors.bottomMargin: 20
                            revealProgress: launcherWindow.weatherModeActive ? 1 : 0
                            visible: revealProgress > 0.02
                        }

                        LauncherColorPickerView {
                            id: colorPickerView
                            z: launcherWindow.colorPickerModeActive ? 2 : 0
                            enabled: launcherWindow.colorPickerModeActive
                            searchQuery: ctrl.searchText
                            defaultColor: Theme.primary
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 12
                            anchors.bottomMargin: 20
                            revealProgress: launcherWindow.colorPickerModeActive ? 1 : 0
                            visible: revealProgress > 0.02

                            onCopyRequested: function(text, label) {
                                ctrl.copyColorText(text);
                            }
                        }

                        Flickable {
                            id: musicScroll
                            z: launcherWindow.musicModeActive ? 2 : 0
                            enabled: launcherWindow.musicModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 12
                            anchors.bottomMargin: 20
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: width
                            contentHeight: musicView.height
                            opacity: launcherWindow.musicModeActive ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            LauncherMusicView {
                                id: musicView
                                width: musicScroll.width
                                height: musicScroll.height
                                filterQuery: launcherWindow.musicQuery ? launcherWindow.musicQuery.filter : ""
                                revealProgress: launcherWindow.musicModeActive ? 1 : 0

                                onSelectedIndexChanged: {
                                    if (launcherWindow.musicModeActive)
                                        lazyContentRoot.scrollSpecialToSelection();
                                }
                            }
                        }

                        Item {
                            id: connectivityContainer
                            z: launcherWindow.connectivityModeActive ? 2 : 0
                            enabled: launcherWindow.connectivityModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 12
                            anchors.bottomMargin: 20
                            opacity: launcherWindow.connectivityModeActive ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            LauncherBluetoothView {
                                id: btView
                                anchors.fill: parent
                                visible: launcherWindow.btModeActive
                                filterQuery: launcherWindow.connectivityQuery ? launcherWindow.connectivityQuery.filter : ""
                                revealProgress: launcherWindow.btModeActive ? 1 : 0
                                onConnectionSucceeded: function(deviceLabel) {
                                    bluetoothConnectedDeviceLabel = deviceLabel;
                                    launcherWindow.closeMenu();
                                    bluetoothConnectedNotifTimer.restart();
                                }
                            }

                            LauncherWifiView {
                                id: wifiView
                                anchors.fill: parent
                                visible: launcherWindow.wifiModeActive
                                filterQuery: launcherWindow.connectivityQuery ? launcherWindow.connectivityQuery.filter : ""
                                revealProgress: launcherWindow.wifiModeActive ? 1 : 0

                                onRefocusSearchRequested: searchField.forceActiveFocus()
                                onConnectionAttemptFailed: lazyContentRoot.resetConnectivityState()
                            }
                        }

                        Item {
                            id: nightLightContainer
                            z: launcherWindow.nightModeActive ? 2 : 0
                            enabled: launcherWindow.nightModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 12
                            anchors.bottomMargin: 20
                            opacity: launcherWindow.nightModeActive ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            LauncherNightLightView {
                                id: nightLightView
                                anchors.fill: parent
                                revealProgress: launcherWindow.nightModeActive ? 1 : 0
                            }
                        }

                        Item {
                            id: clipboardContainer
                            z: launcherWindow.clipModeActive ? 2 : 0
                            enabled: launcherWindow.clipModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 32
                            anchors.rightMargin: 32
                            anchors.topMargin: 12
                            anchors.bottomMargin: 20
                            opacity: launcherWindow.clipModeActive ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            LauncherClipboardView {
                                id: clipboardView
                                anchors.fill: parent
                                filterQuery: launcherWindow.clipQuery ? launcherWindow.clipQuery.filter : ""
                                revealProgress: launcherWindow.clipModeActive ? 1 : 0

                                onCloseRequested: launcherWindow.closeMenu()
                            }
                        }

                        Connections {
                            target: launcherWindow
                            function onConnectivityModeActiveChanged() {
                                if (launcherWindow.connectivityModeActive)
                                    Qt.callLater(lazyContentRoot.scrollConnectivityToSelection);
                            }
                            function onMusicModeActiveChanged() {
                                if (launcherWindow.musicModeActive)
                                    Qt.callLater(lazyContentRoot.scrollSpecialToSelection);
                            }
                        }
                    }
                    // ──── Separator ────
                    Rectangle {
                        x: 48 + listContainer.width
                        anchors.top: belowSearchArea.top
                        anchors.bottom: parent.bottom
                        width: 1
                        opacity: launcherWindow.fileSplitBlend
                        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop {
                                position: 0.15
                                color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
                            }
                            GradientStop {
                                position: 0.85
                                color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
                            }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // ──── File Preview Panel (Split View) ────
                    Item {
                        id: previewPanel
                        visible: launcherWindow.fileSplitBlend > 0.02
                        opacity: launcherWindow.fileSplitBlend
                        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                        anchors.right: parent.right
                        anchors.top: belowSearchArea.top
                        anchors.bottom: parent.bottom
                        width: parent.width - 48 - listContainer.width
                        clip: true

                        transform: [
                            Translate {
                                id: previewSlide
                                x: (1 - launcherWindow.fileSplitBlend) * 18
                                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                            },
                            Scale {
                                id: previewScale
                                origin.x: 0
                                origin.y: 0
                                xScale: 0.97 + 0.03 * launcherWindow.fileSplitBlend
                                yScale: 0.98 + 0.02 * launcherWindow.fileSplitBlend
                                Behavior on xScale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                                Behavior on yScale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                            }
                        ]

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.03)
                        }

                    // Preview content area
                    Item {
                        id: previewContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: previewMeta.top
                        clip: true

                        // Image preview
                        Image {
                            id: imagePreview
                            anchors.fill: parent
                            anchors.margins: 16
                            visible: ctrl.filePreview && (ctrl.filePreview.preview_type === "image" || ((ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video") && !!ctrl.filePreview.preview_path))
                            source: {
                                if (!ctrl.filePreview) return "";
                                if (ctrl.filePreview.preview_type === "image")
                                    return "file://" + ctrl.filePreview.path;
                                if ((ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video") && ctrl.filePreview.preview_path)
                                    return "file://" + ctrl.filePreview.preview_path;
                                return "";
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: ctrl.filePreview && (ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video")
                            smooth: true
                            mipmap: true

                            // Handle broken images
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    imagePreview.visible = false;
                                    fallbackIcon.visible = true;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                                border.width: 1
                                radius: 12
                                visible: imagePreview.status === Image.Ready
                            }
                        }

                        // Text preview
                        Flickable {
                            id: textFlickable
                            anchors.fill: parent
                            anchors.margins: 16
                            visible: ctrl.filePreview && ctrl.filePreview.preview_type === "text"
                            contentWidth: width
                            contentHeight: textPreview.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: textPreview
                                width: textFlickable.width
                                text: (ctrl.filePreview && ctrl.filePreview.content) || ""
                                // Mocha foreground for code so unstyled tokens match the theme;
                                // markdown keeps the panel's surface contrast color.
                                color: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md")
                                    ? Theme.on_surface
                                    : "#cdd6f4"
                                wrapMode: Text.Wrap
                                font {
                                    family: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? "Inter" : "JetBrains Mono"
                                    pixelSize: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? 13 : 11
                                }
                                lineHeight: 1.4
                                textFormat: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? Text.MarkdownText : Text.RichText
                            }
                        }

                        // Truncation indicator for text
                        Rectangle {
                            visible: textFlickable.visible && ctrl.filePreview && ctrl.filePreview.line_count >= 60
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Theme.surface }
                            }
                        }

                        // Fallback icon for non-previewable files
                        Item {
                            id: fallbackIcon
                            anchors.centerIn: parent
                            visible: {
                                if (!ctrl.filePreview) return true;
                                var pt = ctrl.filePreview.preview_type;
                                if ((pt === "pdf" || pt === "video") && ctrl.filePreview.preview_path) return false;
                                return pt !== "image" && pt !== "text";
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: launcherWindow.selectedFileData ? ctrl.mimeIcon(launcherWindow.selectedFileData.mime_cat) : ""
                                    color: Theme.primary
                                    opacity: 0.6
                                    font {
                                        family: "JetBrainsMono Nerd Font"
                                        pixelSize: 72
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (!ctrl.filePreview) return "Loading...";
                                        if (ctrl.filePreview.preview_type === "text_too_large") return "File too large to preview";
                                        if (ctrl.filePreview.preview_type === "binary") return "Binary file";
                                        if (ctrl.filePreview.preview_type === "pdf") return "PDF preview unavailable";
                                        if (ctrl.filePreview.preview_type === "video") return "Video preview unavailable";
                                        return "No preview available";
                                    }
                                    color: Theme.on_surface_variant
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 13
                                    }
                                }
                            }
                        }

                        // Loading spinner
                        Text {
                            anchors.centerIn: parent
                            visible: !ctrl.filePreview && launcherWindow.hasFileSelected
                            text: "Loading..."
                            color: Theme.on_surface_variant
                            opacity: 0.6
                            font {
                                family: "Google Sans"
                                pixelSize: 14
                            }
                        }
                    }

                    // ── File metadata + action buttons ──
                    Rectangle {
                        id: previewMeta
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: metaColumn.implicitHeight + 32
                        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04)
                        radius: 28

                        // Only round bottom corners
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            color: parent.color
                        }

                        Column {
                            id: metaColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            anchors.bottomMargin: 16
                            spacing: 6

                            Text {
                                width: parent.width
                                text: launcherWindow.selectedFileData ? launcherWindow.selectedFileData.name : ""
                                color: Theme.on_surface
                                elide: Text.ElideMiddle
                                font {
                                    family: "Google Sans"
                                    pixelSize: 15
                                    weight: Font.DemiBold
                                }
                            }

                            Text {
                                width: parent.width
                                text: launcherWindow.selectedFileData ? launcherWindow.selectedFileData.dir : ""
                                color: Theme.on_surface_variant
                                elide: Text.ElideMiddle
                                font {
                                    family: "Google Sans"
                                    pixelSize: 12
                                }
                            }

                            Text {
                                text: {
                                    if (!launcherWindow.selectedFileData) return "";
                                    var f = launcherWindow.selectedFileData;
                                    var parts = [ctrl.formatFileSize(f.size)];
                                    if (f.ext) parts.push(f.ext.toUpperCase());
                                    return parts.join("  •  ");
                                }
                                color: Theme.on_surface_variant
                                opacity: 0.7
                                font {
                                    family: "Google Sans"
                                    pixelSize: 11
                                }
                            }

                            Item { width: 1; height: 6 }

                            // Action buttons row
                            Row {
                                spacing: 8

                                Rectangle {
                                    width: copyFileRow.width + 20
                                    height: 32
                                    radius: 16
                                    color: copyFileMouse.containsMouse ? Theme.primary : Theme.primary_container

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        id: copyFileRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰆏"
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                                            color: copyFileMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Copy File"
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: copyFileMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                        }
                                    }

                                    MouseArea {
                                        id: copyFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (launcherWindow.selectedFileData)
                                                ctrl.copyFile(launcherWindow.selectedFileData.path);
                                        }
                                    }
                                }

                                Rectangle {
                                    width: copyPathRow.width + 20
                                    height: 32
                                    radius: 16
                                    color: copyPathMouse.containsMouse ? Theme.secondary : Theme.secondary_container

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        id: copyPathRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰉒"
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                                            color: copyPathMouse.containsMouse ? Theme.on_secondary : Theme.on_secondary_container
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Copy Path"
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: copyPathMouse.containsMouse ? Theme.on_secondary : Theme.on_secondary_container
                                        }
                                    }

                                    MouseArea {
                                        id: copyPathMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (launcherWindow.selectedFileData)
                                                ctrl.copyFilePath(launcherWindow.selectedFileData.path);
                                        }
                                    }
                                }
                            }
                        }
                    }
                } // End of previewPanel
                } // End of mainUi
            }
        }
    }
}
