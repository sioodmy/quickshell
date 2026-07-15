import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

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

    readonly property bool weatherModeActive: ctrl.searchText.trim().toLowerCase() === "weather"
    readonly property bool colorPickerModeActive: ctrl.isColorPickerQuery(ctrl.searchText.trim())
    readonly property bool specialViewActive: weatherModeActive || colorPickerModeActive

    onHasFileSelectedChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onWeatherModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onColorPickerModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0

    Behavior on fileSplitBlend {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.closeMenu()
    }

    function scoreMatch(text, query) {
        if (!text)
            return -1;
        var textLower = text.toString().toLowerCase();
        var queryLower = query.toLowerCase();

        // Exact match
        if (textLower === queryLower)
            return 1000;

        // Full string starts with query
        if (textLower.startsWith(queryLower))
            return 800;

        // Any word in the string starts with query
        var words = textLower.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(queryLower))
                return 600;
        }

        // single/double letter matches polluting short queries
        if (query.length >= 3 && textLower.indexOf(queryLower) !== -1)
            return 200;

        return -1;
    }

    function buildFilteredList() {
        var allApps = DesktopEntries.applications.values;
        var query = ctrl.searchText.trim();
        var queryLower = query.toLowerCase();
        
        // Track async search results to force QML to re-evaluate this function
        var _fileSearchDep = ctrl.fileSearchResults;
        
        var results = [];

        // --- App results ---
        if (query === "") {
            // No query: show all apps sorted by frecency, hide blacklisted
            var sortedApps = allApps.filter(app => {
                if (!app.name)
                    return false;
                var n = app.name.toLowerCase();
                return !hiddenKeywords.some(keyword => n.includes(keyword));
            }).sort((a, b) => {
                var freqA = ctrl.appFrequencies[a.id] || 0;
                var freqB = ctrl.appFrequencies[b.id] || 0;
                if (freqB !== freqA)
                    return freqB - freqA;
                return (a.name || "").localeCompare(b.name || "");
            });

            for (var i = 0; i < sortedApps.length; i++) {
                results.push({ type: "app", entry: sortedApps[i] });
            }
            return results;
        }

        // Check if the user's search explicitly contains any of the hidden keywords
        var isSearchingHidden = hiddenKeywords.some(keyword => queryLower.includes(keyword));
        var scored = [];

        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];

            // Hide apps matching hiddenKeywords unless explicitly searched for
            var nameLower = entry.name ? entry.name.toLowerCase() : "";
            var isHiddenApp = hiddenKeywords.some(keyword => nameLower.includes(keyword));

            if (isHiddenApp && !isSearchingHidden) {
                continue;
            }

            var best = scoreMatch(entry.name, query);

            // Check generic name (e.g., "Web Browser")
            if (entry.genericName) {
                var s = scoreMatch(entry.genericName, query);
                if (s >= 200)
                    best = Math.max(best, s - 50);
            }

            // Check comments
            if (entry.comment) {
                var s = scoreMatch(entry.comment, query);
                if (s >= 200)
                    best = Math.max(best, s - 100);
            }

            // Check keywords
            if (entry.keywords) {
                for (var j = 0; j < entry.keywords.length; j++) {
                    var s = scoreMatch(entry.keywords[j], query);
                    if (s >= 200)
                        best = Math.max(best, s - 20); // High weight for exact alias hits
                }
            }

            // Check the executable command
            if (entry.execString && entry.execString.toLowerCase().includes(queryLower)) {
                best = Math.max(best, 180);
            }

            if (best >= 0) {
                scored.push({
                    entry: entry,
                    score: best
                });
            }
        }

        // ──── Tier 1: Quickkey-boosted results ────
        // Look up learned abbreviation mappings for this exact query
        var quickkeyMatches = ctrl.getQuickkeyMatches(query);
        var quickkeyBoostedIds = {};  // track which appIds were boosted

        // Build a lookup from appId → entry for fast access
        var appById = {};
        for (var i = 0; i < allApps.length; i++) {
            if (allApps[i].id) appById[allApps[i].id] = allApps[i];
        }

        // Get running windows to check for focus targets
        var runningWindows = ctrl.getRunningWindows();

        // Insert quickkey matches as Tier 1
        for (var qk = 0; qk < quickkeyMatches.length; qk++) {
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

            // Add focus entries for running windows of this app
            for (var w = 0; w < runningWindows.length; w++) {
                var win = runningWindows[w];
                if (win.appId && win.appId === qkId) {
                    results.push({
                        type: "focus",
                        entry: qkEntry,
                        windowId: win.id,
                        windowTitle: win.title || ""
                    });
                }
            }

            results.push({ type: "app", entry: qkEntry });
        }

        // ──── Tier 2: Standard fuzzy-match results ────
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            // Use frecency as tiebreaker
            var freqA = ctrl.appFrequencies[a.entry.id] || 0;
            var freqB = ctrl.appFrequencies[b.entry.id] || 0;
            if (freqB !== freqA)
                return freqB - freqA;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });

        for (var i = 0; i < scored.length; i++) {
            var appEntry = scored[i].entry;
            var entryId = appEntry.id || "";

            // Skip apps already in Tier 1
            if (quickkeyBoostedIds[entryId]) continue;

            // Check if this app has a running window
            for (var w = 0; w < runningWindows.length; w++) {
                var win = runningWindows[w];
                if (win.appId && entryId && win.appId === entryId) {
                    results.push({
                        type: "focus",
                        entry: appEntry,
                        windowId: win.id,
                        windowTitle: win.title || ""
                    });
                }
            }

            results.push({ type: "app", entry: appEntry });
        }

        // --- System Commands ---
        if (query !== "") {
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
                results.push({ type: "system_command", actionId: "sleep", name: "Sleep", description: "Suspend to RAM", icon: "󰤓" });
            } else if (queryLower === "lock" || queryLower === "lockscreen") {
                results.push({ type: "system_command", actionId: "lock", name: "Lock Screen", description: "Lock the session", icon: "󰌾" });
            } else if (queryLower === "audio out hdmi") {
                results.push({ type: "system_command", actionId: "audio_out_hdmi", name: "Audio Out HDMI", description: "Set default audio output to HDMI", icon: "󰡁" });
            } else if (queryLower.startsWith("bt") || queryLower.startsWith("bluetooth")) {
                var btDeps = ctrl.bluetoothDevices;
                if (btDeps) {
                    for (var b = 0; b < btDeps.length; b++) {
                        results.push({
                            type: "system_command", actionId: "bt_connect", actionValue: btDeps[b].id,
                            name: btDeps[b].name, description: "Bluetooth Device" + (btDeps[b].active ? " (Connected)" : ""), icon: "󰂯"
                        });
                    }
                }
            } else if (queryLower.startsWith("wifi") || queryLower.startsWith("net")) {
                var wifiDeps = ctrl.wifiNetworks;
                if (wifiDeps) {
                    for (var w = 0; w < wifiDeps.length; w++) {
                        results.push({
                            type: "system_command", actionId: "wifi_connect", actionValue: wifiDeps[w].id,
                            name: wifiDeps[w].name, description: wifiDeps[w].kind + (wifiDeps[w].active ? " (Active)" : ""), icon: "󰖩"
                        });
                    }
                }
            }
        }

        // --- Music results ---
        if (query !== "") {
            var library = BackendDaemon.musicLibrary ? BackendDaemon.musicLibrary.albums : [];
            var musicScored = [];
            for (var m = 0; m < library.length; m++) {
                var album = library[m];
                var albumScore = Math.max(scoreMatch(album.title, query), scoreMatch(album.artist, query));
                if (albumScore >= 0) {
                    musicScored.push({ type: "music_album", album: album, score: albumScore + 10 });
                }
                
                for (var t = 0; t < album.tracks.length; t++) {
                    var track = album.tracks[t];
                    var trackScore = scoreMatch(track.title, query);
                    if (trackScore >= 0) {
                        musicScored.push({ type: "music_track", album: album, trackIndex: t, track: track, score: trackScore });
                    }
                }
            }
            musicScored.sort((a, b) => b.score - a.score);
            var maxMusic = Math.min(musicScored.length, 10);
            for (var ms = 0; ms < maxMusic; ms++) {
                results.push(musicScored[ms]);
            }
        }

        // --- File search results (from Rust backend) ---
        if (query !== "" && query.length >= 3) {
            var fileResults = ctrl.fileSearchResults;
            console.log("QML File Search: Query=" + query + " length=" + (fileResults ? fileResults.length : "null") + " backendQuery=" + ctrl.fileSearchQuery);
            if (fileResults && ctrl.fileSearchQuery.toLowerCase() === queryLower) {
                var maxFiles = Math.min(fileResults.length, 10);
                for (var fi = 0; fi < maxFiles; fi++) {
                    results.push({
                        type: "file",
                        file: fileResults[fi]
                    });
                }
                console.log("QML File Search: Pushed " + maxFiles + " files.");
            }
        }

        // --- Fallback action: Open in WolframAlpha ---
        if (query !== "" && ctrl.looksLikeMath(query)) {
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
        if (query !== "" && query.indexOf(" ") === -1 && (ctrl.dictStatus === "ok" || ctrl.dictStatus === "loading")) {
            results.push({
                type: "action",
                actionId: "dictionary",
                name: "Dictionary",
                description: query,
                icon: "󰗊",
                iconFamily: "JetBrainsMono Nerd Font"
            });
        }

        // --- Emoji results (only when actively searching) ---
        if (query !== "") {
            var emojiResults = ctrl.filterEmojis(query);
            
            // Sort by frecency score
            emojiResults.sort((a, b) => {
                var freqA = ctrl.getAppFrecency("emoji:" + a.emoji);
                var freqB = ctrl.getAppFrecency("emoji:" + b.emoji);
                return freqB - freqA;
            });

            var maxEmojis = Math.min(emojiResults.length, 20);
            for (var i = 0; i < maxEmojis; i++) {
                var eId = "emoji:" + emojiResults[i].emoji;
                if (!quickkeyBoostedIds[eId]) {
                    results.push({
                        type: "emoji",
                        emoji: emojiResults[i].emoji,
                        display: emojiResults[i].display
                    });
                }
            }
        }

        // --- Fallback action: Search the web ---
        if (query !== "") {
            results.push({
                type: "action",
                actionId: "websearch",
                name: "Search the web",
                description: "\"" + query + "\" — DuckDuckGo",
                icon: "helium",
                iconFamily: "__icon_theme__"
            });
        }

        return results;
    }

    LauncherBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (launcherWindow.visible) {
                closeMenu();
            } else {
                ctrl.clearStates();
                launcherWindow.visible = true;
            }
        }

        onCloseMenuRequested: closeMenu()
    }

    function closeMenu() {
        launcherWindow.visible = false;
        ctrl.commitRecents();
    }

    LazyLoader {
        id: contentLoader

        activeAsync: launcherWindow.visible

        component: Component {
            Item {
                id: lazyContentRoot

                parent: launcherWindow.contentItem
                width: 640
                height: 609
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 220

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

                Component.onCompleted: {
                    searchField.forceActiveFocus();
                }

                Rectangle {
                    id: shadowCaster
                    anchors.fill: mainUi
                    anchors.margins: 2
                    radius: 26
                    color: "black"
                    visible: false
                }

                MultiEffect {
                    anchors.fill: shadowCaster
                    source: shadowCaster
                    shadowEnabled: true
                    shadowBlur: 1.5
                    shadowColor: "#60000000"
                    shadowVerticalOffset: 16
                }

                Rectangle {
                    id: mainUiMask
                    anchors.fill: mainUi
                    radius: 28
                    color: "black"
                    visible: false
                    layer.enabled: true
                    layer.smooth: true
                }

                Rectangle {
                    id: mainUi
                    width: 640
                    
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: Theme.surface_container
                    radius: 28
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
                        height: 180
                        clip: true

                        property real bannerBlend: launcherWindow.weatherModeActive ? 1 : 0

                        Behavior on bannerBlend {
                            NumberAnimation { duration: 340; easing.type: Easing.InOutCubic }
                        }

                        Connections {
                            target: launcherWindow
                            function onWeatherModeActiveChanged() {
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
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 180; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -60; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -20; duration: 15000; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
                                    NumberAnimation { to: -100; duration: 17000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 40; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -50; duration: 16000; easing.type: Easing.InOutSine }
                                }
                                NumberAnimation on rotation {
                                    from: 0; to: 360; duration: 30000; loops: Animation.Infinite
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
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
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 150; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 480; duration: 19000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 350; duration: 17000; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
                                    NumberAnimation { to: 60; duration: 16000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -120; duration: 18000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -40; duration: 16000; easing.type: Easing.InOutSine }
                                }
                                NumberAnimation on rotation {
                                    from: 360; to: 0; duration: 35000; loops: Animation.Infinite
                                    paused: !launcherWindow.visible || launcherWindow.weatherModeActive
                                }
                            }
                        }

                        // --- Weather reactive background ---
                        Item {
                            id: weatherBannerLayer
                            anchors.fill: parent
                            opacity: edgeBanner.bannerBlend
                            scale: 1.04 - 0.04 * edgeBanner.bannerBlend
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
                                visible: edgeBanner.bannerBlend > 0.02
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
                            anchors.bottomMargin: 76
                            z: 2
                            weather: launcherWeatherData
                            headerReveal: edgeBanner.bannerBlend
                            visible: edgeBanner.bannerBlend > 0.02
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
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
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
                        anchors.leftMargin: 32
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
                                } else {
                                    Qt.callLater(syncFilePreviewForCurrentItem);
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    mainUi.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
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
                                } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                    if (listView.currentItem) {
                                        listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
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
                        visible: ctrl.calcResult !== "" && !launcherWindow.colorPickerModeActive
                        anchors.top: searchArea.bottom
                        anchors.topMargin: 12
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 32
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

                            Item {
                                id: listContainer
                                anchors.top: parent.top
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

                                    highlightMoveDuration: 120
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
                                            color: Theme.surface_container
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
                    }
                    // ──── Separator ────
                    Rectangle {
                        x: listContainer.width
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
                        width: parent.width - listContainer.width
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
                            visible: ctrl.filePreview && (ctrl.filePreview.preview_type === "image" || (ctrl.filePreview.preview_type === "pdf" && !!ctrl.filePreview.preview_path))
                            source: {
                                if (!ctrl.filePreview) return "";
                                if (ctrl.filePreview.preview_type === "image")
                                    return "file://" + ctrl.filePreview.path;
                                if (ctrl.filePreview.preview_type === "pdf" && ctrl.filePreview.preview_path)
                                    return "file://" + ctrl.filePreview.preview_path;
                                return "";
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: ctrl.filePreview && ctrl.filePreview.preview_type === "pdf"
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
                                color: Theme.on_surface
                                wrapMode: Text.WrapAnywhere
                                font {
                                    family: "JetBrains Mono"
                                    pixelSize: 11
                                }
                                lineHeight: 1.4
                                textFormat: Text.PlainText
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
                                GradientStop { position: 1.0; color: Theme.surface_container }
                            }
                        }

                        // Fallback icon for non-previewable files
                        Item {
                            id: fallbackIcon
                            anchors.centerIn: parent
                            visible: {
                                if (!ctrl.filePreview) return true;
                                var pt = ctrl.filePreview.preview_type;
                                if (pt === "pdf" && ctrl.filePreview.preview_path) return false;
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
