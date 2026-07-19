import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    readonly property int barRadius: 22
    readonly property int visibleWidth: 44

    // Match launcher nature palette
    readonly property color leaf: "#a6d189"
    readonly property color mint: "#81c8be"
    readonly property color sun: "#e5c890"

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
        return "#1a2e20";
    }

    // Same left-edge trick as the dock notch / recording indicator:
    // half the radius sits off-screen so only the right side shows rounded.
    width: visibleWidth + barRadius
    height: contentCol.implicitHeight + 16
    x: -barRadius
    visible: Pomodoro.shouldShow
    opacity: visible ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Connections {
        target: Pomodoro
        function onTimeUp() { popAnim.start(); }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: root; property: "scale"; to: 1.12; duration: 140; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 240; easing.type: Easing.OutBounce }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.barRadius
        color: Pomodoro.isRunning ? root.accent : Theme.surface_container_high

        Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Column {
            id: contentCol
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.barRadius / 2
            spacing: 6

            // Circular progress — hover swaps mode icon for pause/play, click toggles
            Item {
                id: ringHit
                width: 32
                height: 32
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    id: miniRing
                    anchors.fill: parent
                    property real prog: Pomodoro.remainingProgress
                    property color ringColor: Pomodoro.isRunning ? root.accentOn : root.accent
                    property color trackColor: Pomodoro.isRunning
                        ? Qt.rgba(root.accentOn.r, root.accentOn.g, root.accentOn.b, 0.28)
                        : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)

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
                        var r = (Math.min(width, height) / 2) - 2.5;
                        var lw = 2.8;

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

                Text {
                    id: ringIcon
                    anchors.centerIn: parent
                    text: {
                        if (ringMouse.containsMouse)
                            return Pomodoro.isRunning ? "󰏤" : "󰐊";
                        return Pomodoro.modeIcon;
                    }
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    color: Pomodoro.isRunning ? root.accentOn : root.accent
                    scale: ringMouse.containsMouse ? 1.12 : 1.0

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: ringMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.toggle()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Pomodoro.formattedTime
                font { family: "Google Sans Medium"; pixelSize: 10 }
                color: Pomodoro.isRunning ? root.accentOn : Theme.on_surface_variant
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }
}
