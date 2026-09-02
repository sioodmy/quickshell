import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.components

Rectangle {
    id: root

    implicitWidth: layout.implicitWidth + 8
    implicitHeight: 22
    radius: height / 2
    color: "transparent"

    // --- Audio State Management ---
    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property bool isMuted: activeSink?.audio?.muted ?? true
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // --- Audio ---
        Item {
            width: 11
            height: 11
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: audioIcon
                anchors.fill: parent
                visible: !(root.isMuted || root.volumeLevel <= 0.0)

                property real _v: root.volumeLevel
                property bool _m: root.isMuted

                on_VChanged: requestPaint()
                on_MChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = (width / 2) - 1.0;

                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = 1.8;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.3);
                    ctx.stroke();

                    if (root.volumeLevel > 0) {
                        ctx.beginPath();
                        var startAngle = -Math.PI / 2;
                        var endAngle = startAngle + (Math.min(root.volumeLevel, 1.0) * 2 * Math.PI);
                        ctx.arc(cx, cy, r, startAngle, endAngle);
                        ctx.lineWidth = 1.8;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = root.isMuted ? Qt.rgba(1, 1, 1, 0.5) : "#ffffff";
                        ctx.stroke();
                    }
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.isMuted || root.volumeLevel <= 0.0
                icon: "volume_off"
                font.pixelSize: 10
                color: "#ffffff"
            }
        }

        // --- Battery ---
        Item {
            id: batteryIconItem
            width: 22
            height: 12
            anchors.verticalCenter: parent.verticalCenter

            // Internal logic
            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            // Battery nub (terminal on the right)
            Rectangle {
                id: batteryNub
                width: 2
                height: 5
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                radius: 1
                color: batteryBody.border.color
            }

            Rectangle {
                id: batteryBody
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    right: batteryNub.left
                    rightMargin: 1
                }
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: {
                    if (batteryIconItem.capacity <= 10 && !batteryIconItem.isCharging)
                        return Theme.critical;
                    if (batteryIconItem.capacity <= 20 && !batteryIconItem.isCharging)
                        return "#ea999c";
                    if (batteryIconItem.isCharging)
                        return "#259b50";
                    return "#ffffff";
                }
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }

            Rectangle {
                id: batteryFill
                anchors {
                    left: batteryBody.left
                    top: batteryBody.top
                    bottom: batteryBody.bottom
                    margins: 2
                }
                radius: 1.5
                width: Math.max(0, (batteryBody.width - 4) * (batteryIconItem.capacity / 100))
                color: batteryBody.border.color
                opacity: 0.4

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            Text {
                visible: !batteryIconItem.isCharging
                anchors.centerIn: batteryBody
                text: Math.round(batteryIconItem.capacity)
                font.family: "Google Sans"
                font.pixelSize: 7
                font.bold: true
                color: "#ffffff"
            }

            MaterialIcon {
                visible: batteryIconItem.isCharging
                anchors.centerIn: batteryBody
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                icon: "bolt"
                font.pixelSize: 8
                color: "#ffffff"
            }
        }
    }
}
