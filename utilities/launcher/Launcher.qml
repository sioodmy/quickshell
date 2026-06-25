import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: launcherWindow

    // Add any apps you want to hide to this list
    property var hiddenKeywords: ["avahi", "uuctl", "bssh", "bvnc"]

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
        var results = [];

        // --- App results ---
        if (query === "") {
            // No query: show all apps, but completely hide any app matching hiddenKeywords
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

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            var freqA = ctrl.appFrequencies[a.entry.id] || 0;
            var freqB = ctrl.appFrequencies[b.entry.id] || 0;
            if (freqB !== freqA)
                return freqB - freqA;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });

        // Get running windows to check for focus targets
        var runningWindows = ctrl.getRunningWindows();

        for (var i = 0; i < scored.length; i++) {
            var appEntry = scored[i].entry;

            // Check if this app has a running window
            // Match desktop entry id to niri appId
            var entryId = appEntry.id || "";
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
            var maxEmojis = Math.min(emojiResults.length, 20);
            for (var i = 0; i < maxEmojis; i++) {
                results.push({
                    type: "emoji",
                    emoji: emojiResults[i].emoji,
                    display: emojiResults[i].display
                });
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
                ctrl.searchText = "";
                ctrl.calcResult = "";
                ctrl.calcExpression = "";
                ctrl.selectionBuffer = "";
                ctrl.dictWord = "";
                ctrl.dictPhonetic = "";
                ctrl.dictDefinition = "";
                ctrl.dictStatus = "";
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
                    anchors.fill: parent
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

                    Item {
                        id: edgeBanner
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 180
                        clip: true

                        // Solid base background (Catppuccin Macchiato Pink)
                        Rectangle {
                            anchors.fill: parent
                            color: "#f5bde6"
                        }

                        // Floating Pastel Circles (High Contrast, Reduced count)
                        // Circle 1: Large White Highlight
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
                                paused: !launcherWindow.visible
                                NumberAnimation { to: 180; duration: 16000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -60; duration: 18000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -20; duration: 15000; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                paused: !launcherWindow.visible
                                NumberAnimation { to: -100; duration: 17000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 40; duration: 16000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -50; duration: 16000; easing.type: Easing.InOutSine }
                            }
                            NumberAnimation on rotation {
                                from: 0; to: 360; duration: 30000; loops: Animation.Infinite; paused: !launcherWindow.visible
                            }
                        }

                        // Circle 2: Deep Mauve Contrast
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
                                paused: !launcherWindow.visible
                                NumberAnimation { to: 150; duration: 18000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 480; duration: 19000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 350; duration: 17000; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                paused: !launcherWindow.visible
                                NumberAnimation { to: 60; duration: 16000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -120; duration: 18000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: -40; duration: 16000; easing.type: Easing.InOutSine }
                            }
                            NumberAnimation on rotation {
                                from: 360; to: 0; duration: 35000; loops: Animation.Infinite; paused: !launcherWindow.visible
                            }
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
                        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
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
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    mainUi.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
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
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    if (listView.currentItem) {
                                        listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
                                    } else if (ctrl.calcResult !== "") {
                                        ctrl.copyResult();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                                    listView.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                                    listView.decrementCurrentIndex();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // --- Calculator Result Card ---
                    Item {
                        id: calcCard
                        visible: ctrl.calcResult !== ""
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
                        id: listContainer
                        anchors.top: calcCard.visible ? calcCard.bottom : searchArea.bottom
                        anchors.topMargin: 16
                        anchors.bottom: footer.top
                        anchors.left: parent.left
                        anchors.right: parent.right
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
                                values: launcherWindow.buildFilteredList()
                            }
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
                            right: parent.right
                        }
                        height: 48

                        Text {
                            anchors.centerIn: parent
                            text: "[/] Search  •  [Enter] Launch  •  [J/K] Navigate  •  [Esc] Close"
                            color: Theme.on_surface_variant
                            opacity: 0.7
                            font {
                                family: "Google Sans"
                                pixelSize: 12
                                weight: Font.Medium
                                letterSpacing: 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
