import QtQuick
import Quickshell
import qs.services
import "../../theme"

Item {
    id: root

    // --- Public surface used by the launcher shell ---
    property string filterQuery: ""
    property real revealProgress: 1.0
    property int selectedIndex: 0

    signal closeRequested()
    signal copied(string label)

    // --- Internal state ---
    // Clipboard history is now owned by the Rust backend (list/decode/OCR).
    readonly property var entries: BackendDaemon.cliphistItems
    property bool loading: false

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    // Close the launcher once the backend confirms the copy landed on the
    // Wayland selection.
    Connections {
        target: BackendDaemon
        function onCliphistCopied() { root.closeRequested(); }
    }

    onEntriesChanged: {
        root.loading = false;
        clampSelection();
    }

    // ─────────────────────────────────────────────
    //  Filtering (matches text content *and* image OCR text)
    // ─────────────────────────────────────────────
    function matchScore(text, query) {
        if (!query)
            return 0;
        if (!text)
            return -1;
        var t = text.toLowerCase();
        var q = query.toLowerCase();
        if (t === q)
            return 1000;
        if (t.startsWith(q))
            return 800;
        if (t.indexOf(q) !== -1)
            return 500;
        // fuzzy subsequence
        var i = 0, j = 0;
        while (i < t.length && j < q.length) {
            if (t[i] === q[j])
                j++;
            i++;
        }
        return j === q.length ? 200 : -1;
    }

    function entrySearchText(entry) {
        // Text entries match their content; images match extracted OCR text.
        return entry.kind === "image" ? (entry.search_text || "") : (entry.display || "");
    }

    readonly property var filteredEntries: {
        var q = filterQuery.trim();
        if (q === "")
            return entries;
        var scored = [];
        for (var i = 0; i < entries.length; i++) {
            var s = matchScore(entrySearchText(entries[i]), q);
            if (s >= 0)
                scored.push({ entry: entries[i], score: s, order: i });
        }
        scored.sort(function(a, b) {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.order - b.order;
        });
        return scored.map(function(x) { return x.entry; });
    }

    readonly property var selectedEntry: (filteredEntries.length > 0 && selectedIndex >= 0 && selectedIndex < filteredEntries.length)
        ? filteredEntries[selectedIndex] : null

    onFilterQueryChanged: selectedIndex = 0
    onFilteredEntriesChanged: clampSelection()

    function clampSelection() {
        if (filteredEntries.length === 0)
            selectedIndex = 0;
        else if (selectedIndex >= filteredEntries.length)
            selectedIndex = filteredEntries.length - 1;
        else if (selectedIndex < 0)
            selectedIndex = 0;
    }

    // ─────────────────────────────────────────────
    //  Keyboard interface (mirrors other launcher views)
    // ─────────────────────────────────────────────
    function incrementSelection() {
        if (filteredEntries.length === 0)
            return;
        selectedIndex = (selectedIndex + 1) % filteredEntries.length;
    }

    function decrementSelection() {
        if (filteredEntries.length === 0)
            return;
        selectedIndex = selectedIndex <= 0 ? filteredEntries.length - 1 : selectedIndex - 1;
    }

    function activateSelected() {
        if (!selectedEntry)
            return false;
        copyEntry(selectedEntry);
        return true;
    }

    function activateTopMatch() {
        if (filteredEntries.length === 0)
            return false;
        copyEntry(filteredEntries[0]);
        return true;
    }

    function removeSelected() {
        if (!selectedEntry)
            return;
        deleteEntry(selectedEntry);
    }

    function copyEntry(entry) {
        if (!entry)
            return;
        BackendDaemon.send({
            action: "cliphist_copy",
            raw: entry.raw,
            image_path: entry.kind === "image" ? entry.image_path : ""
        });
        root.copied(entry.kind === "image" ? "Image" : entry.display);
    }

    function deleteEntry(entry) {
        if (!entry)
            return;
        BackendDaemon.send({ action: "cliphist_delete", raw: entry.raw });
    }

    // ─────────────────────────────────────────────
    //  Data loading
    // ─────────────────────────────────────────────
    function refresh() {
        root.loading = true;
        BackendDaemon.send({ action: "cliphist_list" });
    }

    function wipe() {
        root.selectedIndex = 0;
        BackendDaemon.send({ action: "cliphist_wipe" });
    }

    Component.onCompleted: refresh()

    // ─────────────────────────────────────────────
    //  UI
    // ─────────────────────────────────────────────

    // ─── Header ───
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        height: 44

        Rectangle {
            id: headerIcon
            width: 36
            height: 36
            radius: 12
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)

            Text {
                anchors.centerIn: parent
                text: "󰅍"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                color: Theme.primary
            }
        }

        Column {
            anchors.left: headerIcon.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "Clipboard"
                color: Theme.on_surface
                font { family: "Google Sans Medium"; pixelSize: 16 }
            }
            Text {
                text: {
                    var n = root.filteredEntries.length;
                    if (root.entries.length === 0)
                        return root.loading ? "Loading…" : "History is empty";
                    if (root.filterQuery.trim() !== "")
                        return n + (n === 1 ? " match" : " matches");
                    return n + (n === 1 ? " item" : " items");
                }
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 11 }
            }
        }

        Rectangle {
            id: clearBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.entries.length > 0
            width: clearRow.implicitWidth + 26
            height: 34
            radius: 17
            color: clearMouse.containsMouse
                ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.14)
                : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.05)

            Behavior on color { ColorAnimation { duration: 120 } }
            scale: clearMouse.pressed ? 0.94 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            Row {
                id: clearRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰩹"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    color: clearMouse.containsMouse ? Theme.critical : Theme.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear all"
                    color: clearMouse.containsMouse ? Theme.critical : Theme.on_surface_variant
                    font { family: "Google Sans Medium"; pixelSize: 13 }
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.wipe()
            }
        }
    }

    // ─── List ───
    ListView {
        id: listView
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        spacing: 8
        model: root.filteredEntries
        currentIndex: root.selectedIndex
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        cacheBuffer: 800

        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: clipDelegate
            required property var modelData
            required property int index

            readonly property bool isImage: modelData.kind === "image"
            property bool isSelected: index === root.selectedIndex

            width: ListView.view.width
            // Image entries get a large, readable preview card; text stays compact.
            height: isImage ? 232 : 60
            radius: 18
            color: isSelected
                ? Theme.secondary_container
                : (rowMouse.containsMouse
                    ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.05)
                    : "transparent")

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = clipDelegate.index
                onClicked: root.copyEntry(clipDelegate.modelData)
            }

            // ─────────── IMAGE LAYOUT ───────────
            Item {
                anchors.fill: parent
                anchors.margins: 10
                visible: clipDelegate.isImage

                // Large preview surface
                Rectangle {
                    id: previewFrame
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height - imageFooter.height - 8
                    radius: 12
                    clip: true
                    color: Theme.surface_container_highest

                    Image {
                        id: previewImage
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: status === Image.Ready
                        source: clipDelegate.isImage ? ("file://" + clipDelegate.modelData.image_path) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        smooth: true
                        // Decode at a crisp-but-bounded resolution.
                        sourceSize.width: Math.min(clipDelegate.modelData.width > 0 ? clipDelegate.modelData.width : 1400, 1400)
                    }

                    // Placeholder while decoding
                    Text {
                        anchors.centerIn: parent
                        visible: previewImage.status !== Image.Ready
                        text: "󰋩"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 40 }
                        color: Theme.on_surface_variant
                        opacity: 0.4
                    }
                }

                // Footer: metadata + actions
                Item {
                    id: imageFooter
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 30

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.right: imageActions.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: clipDelegate.modelData.subtitle
                        color: clipDelegate.isSelected
                            ? Theme.on_secondary_container
                            : Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 12 }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Row {
                        id: imageActions
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        opacity: clipDelegate.isSelected ? 1.0 : 0.0
                        visible: opacity > 0.02
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: imgDeleteMouse.containsMouse
                                ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.18)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰩹"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                                color: imgDeleteMouse.containsMouse ? Theme.critical : Theme.on_secondary_container
                            }
                            MouseArea {
                                id: imgDeleteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteEntry(clipDelegate.modelData)
                            }
                        }

                        Rectangle {
                            width: imgCopyRow.implicitWidth + 20; height: 30; radius: 15
                            color: imgCopyMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Row {
                                id: imgCopyRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰆏"
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                    color: imgCopyMouse.containsMouse ? Theme.on_primary : Theme.primary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Copy"
                                    color: imgCopyMouse.containsMouse ? Theme.on_primary : Theme.primary
                                    font { family: "Google Sans Medium"; pixelSize: 12 }
                                }
                            }
                            MouseArea {
                                id: imgCopyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyEntry(clipDelegate.modelData)
                            }
                        }
                    }
                }
            }

            // ─────────── TEXT LAYOUT ───────────
            Item {
                anchors.fill: parent
                visible: !clipDelegate.isImage

                // Selection accent bar
                Rectangle {
                    width: 3
                    height: clipDelegate.isSelected ? 30 : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1.5
                    color: Theme.primary
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: textLeading
                    width: 40
                    height: 40
                    radius: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "󰊄"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: Theme.primary
                    }
                }

                Text {
                    anchors.left: textLeading.right
                    anchors.leftMargin: 14
                    anchors.right: textActions.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: clipDelegate.modelData.display
                    color: clipDelegate.isSelected ? Theme.on_secondary_container : Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 14 }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Row {
                    id: textActions
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: clipDelegate.isSelected ? 1.0 : 0.0
                    visible: opacity > 0.02
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: txtDeleteMouse.containsMouse
                            ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.18)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰩹"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                            color: txtDeleteMouse.containsMouse ? Theme.critical : Theme.on_secondary_container
                        }
                        MouseArea {
                            id: txtDeleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteEntry(clipDelegate.modelData)
                        }
                    }

                    Rectangle {
                        width: txtCopyRow.implicitWidth + 20; height: 30; radius: 15
                        color: txtCopyMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row {
                            id: txtCopyRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰆏"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                color: txtCopyMouse.containsMouse ? Theme.on_primary : Theme.primary
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Copy"
                                color: txtCopyMouse.containsMouse ? Theme.on_primary : Theme.primary
                                font { family: "Google Sans Medium"; pixelSize: 12 }
                            }
                        }
                        MouseArea {
                            id: txtCopyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyEntry(clipDelegate.modelData)
                        }
                    }
                }
            }
        }

        // Bottom fade
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.surface }
            }
        }
    }

    // ─── Empty state ───
    Column {
        anchors.centerIn: listView
        spacing: 12
        visible: root.filteredEntries.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.loading ? "󰔟" : "󰅍"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 44 }
            color: Theme.on_surface_variant
            opacity: 0.4
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.loading
                ? "Loading clipboard…"
                : (root.entries.length === 0
                    ? "Your clipboard history is empty"
                    : "No matching clips")
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 14 }
            opacity: 0.8
        }
    }
}
