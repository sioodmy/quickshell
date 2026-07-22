import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../theme"
import qs.services

/**
 * Top-right Drag Queen dropzone (Dropzone-style file holding tray).
 *
 * Geometry matches the dock notch: radius 22 with half the pill parked past the
 * top and right screen edges, so the visible free curve sits on the bottom
 * (bottom-right meeting the screen edge).
 *
 * The corner drop zone stays live while empty so external file drags can reveal
 * the panel; it auto-hides again once Drag Queen is empty and the drag leaves.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: stashWindow

        required property var modelData
        screen: modelData

        readonly property int barRadius: 22
        readonly property int contentWidth: 300
        readonly property bool hasItems: FileStash.count > 0
        readonly property bool dragHovering: dropArea.containsDrag

        // Soft M3-toned pride palette (classic 6-stripe, container-weight)
        readonly property color prideRed: "#E57373"
        readonly property color prideOrange: "#FFB74D"
        readonly property color prideYellow: "#FFF176"
        readonly property color prideGreen: "#81C784"
        readonly property color prideBlue: "#64B5F6"
        readonly property color prideViolet: "#BA68C8"

        property bool panelVisible: false

        function updateVisibility() {
            if (hasItems || dragHovering) {
                hideTimer.stop();
                panelVisible = true;
            } else {
                hideTimer.restart();
            }
        }

        onHasItemsChanged: updateVisibility()
        onDragHoveringChanged: updateVisibility()

        Timer {
            id: hideTimer
            interval: 280
            onTriggered: {
                if (!stashWindow.hasItems && !stashWindow.dragHovering)
                    stashWindow.panelVisible = false;
            }
        }

        color: "transparent"
        visible: true

        // While empty, only a small corner hotspot receives input so normal
        // clicks still reach windows. During an external drag into that corner
        // (or when Drag Queen has files) the panel expands and takes a full hitbox.
        readonly property int emptySensorSize: 88

        implicitWidth: contentWidth + barRadius + 16
        implicitHeight: panelVisible
            ? Math.min(modelData.height * 0.6, stashPanel.implicitHeight + 8)
            : (emptySensorSize + barRadius)

        mask: Region {
            item: inputHitbox
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "drag_queen"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        Item {
            id: inputHitbox
            anchors.top: parent.top
            anchors.right: parent.right
            width: panelVisible ? (contentWidth + barRadius) : emptySensorSize
            height: panelVisible ? stashPanel.height : emptySensorSize
        }

        Item {
            id: stashPanel
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -barRadius
            anchors.rightMargin: -barRadius

            width: contentWidth + barRadius
            implicitHeight: barRadius + panelBody.implicitHeight + 16
            height: panelVisible ? implicitHeight : (emptySensorSize + barRadius)

            opacity: panelVisible ? 1 : 0
            scale: panelVisible ? 1 : 0.94
            transformOrigin: Item.TopRight

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }
            }

            // Pride gradient border ring — visible on drag hover
            property int borderInset: dropArea.containsDrag ? 2 : 0
            Behavior on borderInset {
                NumberAnimation {
                    duration: 120
                }
            }

            Rectangle {
                id: prideBorder
                anchors.fill: parent
                radius: stashWindow.barRadius
                opacity: dropArea.containsDrag ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: stashWindow.prideRed }
                    GradientStop { position: 0.20; color: stashWindow.prideOrange }
                    GradientStop { position: 0.40; color: stashWindow.prideYellow }
                    GradientStop { position: 0.60; color: stashWindow.prideGreen }
                    GradientStop { position: 0.80; color: stashWindow.prideBlue }
                    GradientStop { position: 1.00; color: stashWindow.prideViolet }
                }
            }

            Rectangle {
                id: panelBg
                anchors.fill: parent
                anchors.margins: stashPanel.borderInset
                radius: stashWindow.barRadius - (stashPanel.borderInset > 0 ? 1 : 0)
                color: Theme.surface

                layer.enabled: panelVisible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#50000000"
                    shadowVerticalOffset: 6
                    shadowHorizontalOffset: -2
                }
            }

            // Soft pride wash while dragging
            Rectangle {
                anchors.fill: panelBg
                radius: panelBg.radius
                opacity: dropArea.containsDrag ? 0.10 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: stashWindow.prideRed }
                    GradientStop { position: 0.20; color: stashWindow.prideOrange }
                    GradientStop { position: 0.40; color: stashWindow.prideYellow }
                    GradientStop { position: 0.60; color: stashWindow.prideGreen }
                    GradientStop { position: 0.80; color: stashWindow.prideBlue }
                    GradientStop { position: 1.00; color: stashWindow.prideViolet }
                }
            }

            Column {
                id: panelBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: stashWindow.barRadius + 14
                anchors.topMargin: stashWindow.barRadius + 12
                spacing: 10
                visible: panelVisible || dropArea.containsDrag

                // Thick pride bar with header chips overlaid
                Item {
                    width: parent.width
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: stashWindow.prideRed }
                            GradientStop { position: 0.20; color: stashWindow.prideOrange }
                            GradientStop { position: 0.40; color: stashWindow.prideYellow }
                            GradientStop { position: 0.60; color: stashWindow.prideGreen }
                            GradientStop { position: 0.80; color: stashWindow.prideBlue }
                            GradientStop { position: 1.00; color: stashWindow.prideViolet }
                        }
                    }

                    Rectangle {
                        id: statusChip
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: headerChipRow.width + 14
                        height: 26
                        radius: 13
                        color: Theme.surface_container_high

                        Row {
                            id: headerChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰆥"
                                font {
                                    family: "JetBrainsMono Nerd Font"
                                    pixelSize: 13
                                }
                                color: stashWindow.prideViolet
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (dropArea.containsDrag && FileStash.count === 0)
                                        return "Drop to Drag Queen";
                                    if (FileStash.count === 0)
                                        return "Drag Queen";
                                    return FileStash.count === 1 ? "1 file" : (FileStash.count + " files");
                                }
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 11
                                }
                                color: Theme.on_surface
                            }
                        }
                    }

                    Rectangle {
                        id: clearChip
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: FileStash.count > 0
                        width: clearLabel.implicitWidth + 14
                        height: 26
                        radius: 13
                        color: clearMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear"
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 11
                            }
                            color: Theme.on_surface_variant
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: FileStash.clear()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 14
                    visible: FileStash.count === 0
                    color: Theme.surface_container
                    clip: true

                    // Soft pride tint behind empty-state copy
                    Rectangle {
                        anchors.fill: parent
                        opacity: dropArea.containsDrag ? 0.18 : 0.08
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }
                        }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: stashWindow.prideRed }
                            GradientStop { position: 0.20; color: stashWindow.prideOrange }
                            GradientStop { position: 0.40; color: stashWindow.prideYellow }
                            GradientStop { position: 0.60; color: stashWindow.prideGreen }
                            GradientStop { position: 0.80; color: stashWindow.prideBlue }
                            GradientStop { position: 1.00; color: stashWindow.prideViolet }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dropArea.containsDrag ? "󰛒" : "󰇚"
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 20
                            }
                            color: dropArea.containsDrag ? stashWindow.prideViolet : Theme.on_surface_variant
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dropArea.containsDrag ? "Release to Drag Queen" : "Drag files here"
                            font {
                                family: "Google Sans"
                                pixelSize: 12
                            }
                            color: dropArea.containsDrag ? Theme.on_surface : Theme.on_surface_variant
                        }
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    visible: FileStash.count > 0

                    Repeater {
                        model: FileStash.items

                        delegate: Item {
                            id: chipRoot

                            required property int index
                            required property string path
                            required property string url
                            required property string name
                            required property string glyph
                            required property bool isImage

                            // Cycle soft pride accents across chips
                            readonly property var prideColors: [
                                stashWindow.prideRed,
                                stashWindow.prideOrange,
                                stashWindow.prideYellow,
                                stashWindow.prideGreen,
                                stashWindow.prideBlue,
                                stashWindow.prideViolet
                            ]
                            readonly property color accent: prideColors[index % 6]

                            width: 84
                            height: 96

                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.proposedAction: Qt.CopyAction
                            Drag.mimeData: {
                                "text/uri-list": chipRoot.url
                            }
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            Rectangle {
                                id: chipBg
                                anchors.fill: parent
                                radius: 14
                                color: chipMouse.containsMouse || chipRoot.Drag.active
                                    ? Theme.surface_container_highest
                                    : Theme.surface_container_high

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                // Tiny pride accent bar on each chip
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 2
                                    radius: 1
                                    color: chipRoot.accent
                                    opacity: 0.85
                                }

                                Item {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.topMargin: 8
                                    width: 52
                                    height: 52

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: Theme.surface_container

                                        Image {
                                            id: thumb
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            visible: chipRoot.isImage
                                            source: chipRoot.isImage ? ("file://" + chipRoot.path) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: ShaderEffectSource {
                                                    sourceItem: Rectangle {
                                                        width: thumb.width
                                                        height: thumb.height
                                                        radius: 10
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !chipRoot.isImage || thumb.status !== Image.Ready
                                            text: chipRoot.glyph
                                            font {
                                                family: "JetBrainsMono Nerd Font"
                                                pixelSize: 22
                                            }
                                            color: Theme.on_surface_variant
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    anchors.bottomMargin: 8
                                    text: chipRoot.name
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 10
                                    }
                                    color: Theme.on_surface
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 1
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: chipRoot.Drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                acceptedButtons: Qt.LeftButton
                                z: 1

                                property real pressX: 0
                                property real pressY: 0

                                onPressed: function (mouse) {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                }

                                onPositionChanged: function (mouse) {
                                    if (!pressed || chipRoot.Drag.active)
                                        return;
                                    if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) < 12)
                                        return;
                                    chipRoot.grabToImage(function (result) {
                                        chipRoot.Drag.imageSource = result.url;
                                        chipRoot.Drag.active = true;
                                    });
                                }

                                onReleased: function () {
                                    if (chipRoot.Drag.active)
                                        chipRoot.Drag.active = false;
                                }

                                onCanceled: function () {
                                    if (chipRoot.Drag.active)
                                        chipRoot.Drag.active = false;
                                }
                            }

                            Rectangle {
                                id: removeBtn
                                z: 2
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                width: 20
                                height: 20
                                radius: 10
                                color: removeMouse.containsMouse ? Theme.critical : Theme.surface_container_highest

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font {
                                        family: "JetBrainsMono Nerd Font"
                                        pixelSize: 11
                                    }
                                    color: removeMouse.containsMouse ? Theme.on_critical : Theme.on_surface_variant
                                }

                                MouseArea {
                                    id: removeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: FileStash.removePath(chipRoot.path)
                                }
                            }
                        }
                    }
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: function (drag) {
                    if (drag.hasUrls) {
                        drag.accept(Qt.CopyAction);
                        return;
                    }
                    if (drag.hasText && String(drag.text).indexOf("file:") !== -1)
                        drag.accept(Qt.CopyAction);
                }

                onDropped: function (drop) {
                    if (drop.hasUrls) {
                        FileStash.addUrls(drop.urls);
                        drop.acceptProposedAction();
                        return;
                    }
                    if (drop.hasText && drop.text) {
                        const parts = String(drop.text).split(/\s+/).filter(function (p) {
                            return p.indexOf("file:") === 0;
                        });
                        if (parts.length > 0) {
                            FileStash.addUrls(parts);
                            drop.acceptProposedAction();
                        }
                    }
                }
            }
        }
    }
}
