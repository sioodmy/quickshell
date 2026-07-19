import QtQuick
import QtQuick.Effects
import "../../theme"
import qs.services

Item {
    id: root

    property bool active: false
    property int pendingMinutes: -1

    // Nature palette — Catppuccin-frappe greens with soft sun accents, M3 surfaces underneath
    readonly property color leaf: "#a6d189"
    readonly property color moss: "#8fcf9a"
    readonly property color mint: "#81c8be"
    readonly property color sun: "#e5c890"
    readonly property color canopy: "#3d5c45"
    readonly property color soil: "#1a2e20"

    readonly property color accent: {
        if (Pomodoro.mode === 1)
            return mint;
        if (Pomodoro.mode === 2)
            return sun;
        return leaf;
    }
    readonly property color accentOn: {
        if (Pomodoro.mode === 1)
            return "#0e2a28";
        if (Pomodoro.mode === 2)
            return "#2a2110";
        return soil;
    }
    readonly property color accentContainer: {
        if (Pomodoro.mode === 1)
            return "#2a4a48";
        if (Pomodoro.mode === 2)
            return "#4a3f28";
        return canopy;
    }
    readonly property color onAccentContainer: {
        if (Pomodoro.mode === 1)
            return "#c8efe9";
        if (Pomodoro.mode === 2)
            return "#f5e6c4";
        return "#d8f0c8";
    }

    readonly property int displayMinutes: pendingMinutes > 0
        ? pendingMinutes
        : Math.round(Pomodoro.currentDuration / 60)

    readonly property real sliderValue: {
        var mins = displayMinutes;
        return Math.max(0, Math.min(1, (mins - 5) / 55));
    }

    implicitHeight: active ? 176 : 0
    opacity: active ? 1 : 0
    visible: opacity > 0.02
    clip: true

    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    function applyPendingDuration() {
        if (pendingMinutes > 0) {
            Pomodoro.setDuration(pendingMinutes);
            pendingMinutes = -1;
        }
    }

    function setSliderMinutes(mins) {
        pendingMinutes = Math.max(5, Math.min(60, Math.round(mins)));
        if (!Pomodoro.isRunning)
            Pomodoro.setDuration(pendingMinutes);
    }

    function previewMinutes(mins) {
        pendingMinutes = Math.max(5, Math.min(60, Math.round(mins)));
    }

    function commitMinutes(mins) {
        var snapped = Math.round(mins / 5) * 5;
        pendingMinutes = Math.max(5, Math.min(60, snapped));
        if (!Pomodoro.isRunning)
            Pomodoro.setDuration(pendingMinutes);
    }

    Item {
        id: cardHost
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32

        // Rounded mask — Rectangle.clip does not honor radius
        Item {
            id: cardMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: "black"
            }
        }

        Item {
            id: card
            anchors.fill: parent

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.surface_container_high
            }

            // Soft forest wash — gradients only
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.canopy.r, root.canopy.g, root.canopy.b, 0.58)
                    }
                    GradientStop {
                        position: 0.35
                        color: Qt.rgba(root.moss.r, root.moss.g, root.moss.b, 0.16)
                    }
                    GradientStop {
                        position: 0.7
                        color: Qt.rgba(root.mint.r, root.mint.g, root.mint.b, 0.06)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.sun.r, root.sun.g, root.sun.b, 0.07)
                    }
                    GradientStop {
                        position: 0.55
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.canopy.r, root.canopy.g, root.canopy.b, 0.18)
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 16
                z: 1

                // —— Left: breathing circular timer ——
                Item {
                    id: ringArea
                    width: 148
                    height: parent.height

                    Rectangle {
                        id: glow
                        anchors.centerIn: ringItem
                        width: ringItem.width - 4
                        height: ringItem.height - 4
                        radius: width / 2
                        color: root.accent
                        opacity: Pomodoro.isRunning ? 0.22 : 0.10
                        scale: pulseAnim.running ? pulseScale.value : 1.0
                        transformOrigin: Item.Center

                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 280 } }
                    }

                    Rectangle {
                        anchors.centerIn: ringItem
                        width: ringItem.width + 18
                        height: ringItem.height + 18
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                        opacity: Pomodoro.isRunning ? 0.8 : 0.35
                        scale: pulseAnim.running ? (0.97 + (pulseScale.value - 1.0) * 0.6) : 1.0
                        transformOrigin: Item.Center

                        Behavior on opacity { NumberAnimation { duration: 400 } }
                        Behavior on border.color { ColorAnimation { duration: 280 } }
                    }

                    Item {
                        id: ringItem
                        width: 140
                        height: 140
                        anchors.centerIn: parent

                        Canvas {
                            id: ringCanvas
                            anchors.fill: parent
                            property real prog: Pomodoro.remainingProgress
                            property color ringColor: root.accent
                            property color trackColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)

                            onProgChanged: requestPaint()
                            onRingColorChanged: requestPaint()
                            onTrackColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2;
                                var cy = height / 2;
                                var lw = 10;
                                var r = (Math.min(width, height) / 2) - (lw / 2) - 1;

                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                                ctx.lineWidth = lw;
                                ctx.strokeStyle = trackColor;
                                ctx.stroke();

                                if (prog > 0.001) {
                                    ctx.beginPath();
                                    var start = -Math.PI / 2;
                                    var end = start + (prog * 2 * Math.PI);
                                    ctx.arc(cx, cy, r, start, end);
                                    ctx.lineWidth = lw;
                                    ctx.lineCap = "round";
                                    ctx.strokeStyle = ringColor;
                                    ctx.stroke();
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Pomodoro.formattedTime
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 28; weight: Font.Bold }
                                color: Theme.on_surface
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Pomodoro.isRunning
                                    ? Pomodoro.modeLabel
                                    : (root.pendingMinutes > 0 ? root.pendingMinutes + " min" : Pomodoro.modeLabel)
                                font { family: "Google Sans"; pixelSize: 11 }
                                color: root.accent
                                opacity: 0.95

                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }
                }

                // —— Right: controls ——
                Column {
                    width: parent.width - ringArea.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                { modeId: 0, label: "Focus", icon: "󱎫" },
                                { modeId: 1, label: "Break", icon: "󰅶" },
                                { modeId: 2, label: "Long", icon: "󰒲" }
                            ]

                            Rectangle {
                                required property var modelData
                                width: (parent.width - 12) / 3
                                height: 32
                                radius: 16
                                color: Pomodoro.mode === modelData.modeId
                                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                                    : Qt.rgba(0, 0, 0, 0.22)
                                border.color: Pomodoro.mode === modelData.modeId ? root.accent : "transparent"
                                border.width: Pomodoro.mode === modelData.modeId ? 1 : 0

                                Behavior on color { ColorAnimation { duration: 160 } }
                                Behavior on border.color { ColorAnimation { duration: 160 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon
                                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                        color: Pomodoro.mode === modelData.modeId ? root.accent : Theme.on_surface_variant
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font { family: "Google Sans Medium"; pixelSize: 12 }
                                        color: Pomodoro.mode === modelData.modeId ? root.accent : Theme.on_surface_variant
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingMinutes = -1;
                                        Pomodoro.setMode(modelData.modeId);
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: track
                        width: parent.width
                        height: 40
                        radius: 20
                        color: Qt.rgba(0, 0, 0, 0.28)
                        opacity: Pomodoro.isRunning ? 0.5 : 1.0
                        property real dragT: -1

                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle {
                            id: fill
                            height: parent.height
                            radius: parent.radius
                            width: {
                                var t = track.dragT >= 0 ? track.dragT : root.sliderValue;
                                return Math.max(height, parent.width * t);
                            }
                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

                            Behavior on width {
                                enabled: track.dragT < 0
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰔟  Duration"
                            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                            color: Theme.on_surface
                            z: 1
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.displayMinutes + "m"
                            font { family: "Google Sans Medium"; pixelSize: 14 }
                            color: root.accent
                            z: 1

                            Behavior on color { ColorAnimation { duration: 220 } }
                        }

                        MouseArea {
                            id: sliderDrag
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !Pomodoro.isRunning

                            function preview(mx) {
                                var t = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                                track.dragT = t;
                                root.previewMinutes(5 + t * 55);
                            }

                            function commit() {
                                var mins = root.pendingMinutes > 0
                                    ? root.pendingMinutes
                                    : Math.round(Pomodoro.currentDuration / 60);
                                root.commitMinutes(mins);
                                track.dragT = -1;
                            }

                            onPressed: mouse => preview(mouse.x)
                            onPositionChanged: mouse => { if (pressed) preview(mouse.x); }
                            onReleased: commit()
                            onCanceled: commit()
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: resetMouse.containsMouse
                                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                                : Qt.rgba(0, 0, 0, 0.22)
                            border.width: 1
                            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)

                            Text {
                                anchors.centerIn: parent
                                text: "󰑐"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                                color: root.accent
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingMinutes = -1;
                                    Pomodoro.reset();
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - 40 - 40 - 16
                            height: 44
                            radius: 22
                            anchors.verticalCenter: parent.verticalCenter
                            color: Pomodoro.isRunning ? root.accentContainer : root.accent

                            Text {
                                anchors.centerIn: parent
                                text: Pomodoro.isRunning ? "󰏤  Pause" : "󰐊  Start"
                                font { family: "Google Sans Medium"; pixelSize: 14 }
                                color: Pomodoro.isRunning ? root.onAccentContainer : root.accentOn
                            }

                            MouseArea {
                                id: playMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.applyPendingDuration();
                                    Pomodoro.toggle();
                                }
                            }

                            scale: playMouse.pressed ? 0.96 : (playMouse.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: Pomodoro.completedSessions > 0
                                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                                : Qt.rgba(0, 0, 0, 0.22)
                            border.width: 1
                            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b,
                                Pomodoro.completedSessions > 0 ? 0.4 : 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: Pomodoro.completedSessions.toString()
                                font { family: "Google Sans Medium"; pixelSize: 14 }
                                color: root.accent
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Pomodoro.isRunning ? 0.45 : 0.22)

            Behavior on border.color { ColorAnimation { duration: 280; easing.type: Easing.OutCubic } }
        }
    }

    QtObject {
        id: pulseScale
        property real value: 1.0
    }

    SequentialAnimation {
        id: pulseAnim
        running: Pomodoro.isRunning && root.active
        loops: Animation.Infinite
        NumberAnimation {
            target: pulseScale
            property: "value"
            from: 1.0
            to: 1.08
            duration: 1600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: pulseScale
            property: "value"
            from: 1.08
            to: 1.0
            duration: 1600
            easing.type: Easing.InOutSine
        }
    }
}
