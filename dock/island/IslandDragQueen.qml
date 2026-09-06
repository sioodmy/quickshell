import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

Item {
    id: dqRoot

    property bool dragHover: false
    signal requestClose()

    readonly property real cardWidth: 104
    readonly property real cardHeight: 116
    readonly property real cardSpacing: 10
    readonly property real maxTrayWidth: 540
    readonly property real contentWidth: FileStash.count > 0 
        ? Math.min(maxTrayWidth, FileStash.count * (cardWidth + cardSpacing) - cardSpacing)
        : 280

    implicitWidth: Math.max(320, contentWidth + 28)
    implicitHeight: FileStash.count > 0 ? 170 : 128

    Column {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // --- HEADER BAR ---
        Item {
            id: headerBar
            width: parent.width
            height: 26

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.rgba(0.96, 0.35, 0.65, 0.18)
                    border.color: Qt.rgba(0.96, 0.35, 0.65, 0.35)
                    border.width: 1

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "move_to_inbox"
                        font.pixelSize: 14
                        color: "#F472B6"
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Drag Queen"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: Theme.on_surface
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: countText.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Theme.surface_container_highest
                    border.color: Theme.outline_variant
                    border.width: 1

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: FileStash.count + (FileStash.count === 1 ? " item" : " items")
                        font.family: "Google Sans"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: Theme.on_surface_variant
                    }
                }
            }

            // Header Quick Actions (Copy All, Clear)
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: FileStash.count > 0

                property bool copiedFeedback: false

                Timer {
                    id: copyTimer
                    interval: 1500
                    onTriggered: parent.copiedFeedback = false
                }

                // Copy All Pill Button
                Rectangle {
                    width: copyRow.implicitWidth + 14
                    height: 24
                    radius: 12
                    color: copyMouse.containsMouse 
                        ? Theme.surface_container_highest 
                        : Theme.surface_container_high
                    border.color: parent.copiedFeedback ? "#10B981" : Theme.outline_variant
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Row {
                        id: copyRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: parent.parent.parent.copiedFeedback ? "check" : "content_copy"
                            font.pixelSize: 12
                            color: parent.parent.parent.copiedFeedback ? "#10B981" : Theme.on_surface_variant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.parent.copiedFeedback ? "Copied" : "Copy All"
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: parent.parent.parent.copiedFeedback ? "#10B981" : Theme.on_surface_variant
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (FileStash.copyAllPaths()) {
                                parent.parent.copiedFeedback = true;
                                copyTimer.restart();
                            }
                        }
                    }
                }

                // Clear Stash Button
                Rectangle {
                    width: clearRow.implicitWidth + 12
                    height: 24
                    radius: 12
                    color: clearMouse.containsMouse 
                        ? Qt.rgba(0.9, 0.2, 0.2, 0.18) 
                        : Theme.surface_container_high
                    border.color: clearMouse.containsMouse 
                        ? Qt.rgba(0.9, 0.2, 0.2, 0.4) 
                        : Theme.outline_variant
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "delete_sweep"
                            font.pixelSize: 13
                            color: clearMouse.containsMouse ? "#EF4444" : Theme.on_surface_variant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear"
                            font.family: "Google Sans"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: clearMouse.containsMouse ? "#EF4444" : Theme.on_surface_variant
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            FileStash.clear();
                            dqRoot.requestClose();
                        }
                    }
                }
            }
        }

        // --- EMPTY STATE / DROP TARGET BANNER ---
        Rectangle {
            width: parent.width
            height: 74
            radius: 14
            visible: FileStash.count === 0
            color: dqRoot.dragHover 
                ? Qt.rgba(0.96, 0.35, 0.65, 0.15) 
                : Theme.surface_container_low
            border.color: dqRoot.dragHover 
                ? "#F472B6" 
                : Theme.outline_variant
            border.width: dqRoot.dragHover ? 2 : 1

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: Theme.surface_container_highest

                    MaterialIcon {
                        id: dropIcon
                        anchors.centerIn: parent
                        icon: "file_download"
                        font.pixelSize: 20
                        color: "#F472B6"

                        SequentialAnimation on anchors.verticalCenterOffset {
                            running: dqRoot.dragHover
                            loops: Animation.Infinite
                            NumberAnimation { to: -3; duration: 400; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 3; duration: 400; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: dqRoot.dragHover ? "Release to Stash Files" : "Drop Files Here to Stash"
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: "Keep files handy for quick drag & drop"
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }
                }
            }
        }

        // --- STASHED ITEMS LISTVIEW TRAY ---
        Item {
            width: parent.width
            height: dqRoot.cardHeight
            visible: FileStash.count > 0

            ListView {
                id: stashListView
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: dqRoot.cardSpacing
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: FileStash.items

                delegate: Item {
                    id: chipRoot

                    required property int index
                    required property string path
                    required property string url
                    required property string name
                    required property string glyph
                    required property bool isImage
                    property string category: model.category || FileStash.typeCategory(name)
                    property string accentColor: model.accentColor || FileStash.accentColor(name)
                    property string tag: model.tag || FileStash.categoryTag(name)

                    width: dqRoot.cardWidth
                    height: dqRoot.cardHeight

                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.mimeData: {
                        "text/uri-list": chipRoot.url,
                        "text/plain": chipRoot.path
                    }
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    // Card Outer Background
                    Rectangle {
                        id: cardBg
                        anchors.fill: parent
                        radius: 14
                        color: cardMouse.containsMouse || chipRoot.Drag.active
                            ? Theme.surface_container_highest
                            : Theme.surface_container_high
                        border.color: cardMouse.containsMouse 
                            ? chipRoot.accentColor 
                            : Qt.rgba(1, 1, 1, 0.08)
                        border.width: cardMouse.containsMouse ? 1.5 : 1

                        opacity: chipRoot.Drag.active ? 0.6 : 1.0
                        scale: chipRoot.Drag.active ? 0.95 : 1.0

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        Column {
                            z: 1
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 5

                            // Preview Frame
                            Item {
                                width: parent.width
                                height: 70

                                // Image or Gradient Icon Box
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Theme.surface_container_lowest 
                                    border.color: Theme.surface_container_high
                                    border.width: 1

                                    // Image Thumbnail
                                    Image {
                                        id: thumb
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        visible: chipRoot.isImage
                                        source: chipRoot.isImage ? ("file://" + chipRoot.path) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(200, 200)
                                        layer.enabled: chipRoot.isImage && thumb.status === Image.Ready
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: thumbMask
                                        }
                                    }

                                    Rectangle {
                                        id: thumbMask
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: 9
                                        visible: false
                                        layer.enabled: thumb.layer.enabled
                                    }

                                    // Material Icon for Non-Images or Image Loading
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: !chipRoot.isImage || thumb.status !== Image.Ready
                                        icon: chipRoot.glyph
                                        font.pixelSize: 26
                                        color: chipRoot.accentColor
                                    }

                                    // Top Right File Category Tag Badge
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 4
                                        width: tagText.implicitWidth + 6
                                        height: 14
                                        radius: 4
                                        color: Qt.rgba(0, 0, 0, 0.7)
                                        border.color: chipRoot.accentColor
                                        border.width: 1

                                        Text {
                                            id: tagText
                                            anchors.centerIn: parent
                                            text: chipRoot.tag
                                            font.family: "Google Sans"
                                            font.pixelSize: 7
                                            font.weight: Font.Bold
                                            color: chipRoot.accentColor
                                        }
                                    }
                                }

                                // Hover Glass Action Overlay (Open, Copy, Remove)
                                Rectangle {
                                    id: actionOverlay
                                    anchors.fill: parent
                                    radius: 10
                                    color: Qt.rgba(0.05, 0.05, 0.08, 0.85)
                                    opacity: (cardMouse.containsMouse || openBtnMouse.containsMouse || copyBtnMouse.containsMouse || removeBtnMouse.containsMouse) && !chipRoot.Drag.active ? 1.0 : 0.0

                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        // Open File Button
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: openBtnMouse.containsMouse ? Theme.primary : Theme.surface_container_highest

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                icon: "open_in_new"
                                                font.pixelSize: 11
                                                color: openBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: openBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: FileStash.openFile(chipRoot.path)
                                            }
                                        }

                                        // Copy Path Button
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: copyBtnMouse.containsMouse ? Theme.primary : Theme.surface_container_highest

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                icon: "content_copy"
                                                font.pixelSize: 11
                                                color: copyBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: copyBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: FileStash.copyPath(chipRoot.path)
                                            }
                                        }

                                        // Remove Button
                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: removeBtnMouse.containsMouse ? "#EF4444" : Theme.surface_container_highest

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                icon: "close"
                                                font.pixelSize: 12
                                                color: removeBtnMouse.containsMouse ? "#FFFFFF" : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: removeBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: FileStash.removePath(chipRoot.path)
                                            }
                                        }
                                    }
                                }
                            }

                            // Filename Label
                            Text {
                                width: parent.width
                                text: chipRoot.name
                                font.family: "Google Sans"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Theme.on_surface
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                maximumLineCount: 1
                            }
                        }

                        // Interactive Drag & Click Area
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: chipRoot.Drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton

                            property real pressX: 0
                            property real pressY: 0

                            onPressed: function (mouse) {
                                pressX = mouse.x;
                                pressY = mouse.y;
                            }

                            onPositionChanged: function (mouse) {
                                if (!chipRoot.Drag.active && pressed) {
                                    if (Math.abs(mouse.x - pressX) > 6 || Math.abs(mouse.y - pressY) > 6) {
                                        chipRoot.Drag.active = true;
                                    }
                                }
                            }

                            onReleased: function (mouse) {
                                if (chipRoot.Drag.active) {
                                    chipRoot.Drag.active = false;
                                }
                            }

                            onDoubleClicked: {
                                FileStash.openFile(chipRoot.path);
                            }
                        }
                    }
                }
            }
        }
    }
}
