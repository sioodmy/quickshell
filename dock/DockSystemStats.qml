import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme

Rectangle {
    id: root
    
    implicitWidth: 28
    implicitHeight: layout.implicitHeight + 20
    radius: width / 2
    color: Theme.surface_container

    // --- Audio State Management ---
    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property bool isMuted: activeSink?.audio?.muted ?? true
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Column {
        id: layout
        anchors.centerIn: parent
        spacing: 12

        // --- Network ---
        Item {
            width: netIcon.width; height: netIcon.height
            anchors.horizontalCenter: parent.horizontalCenter
            DockNetwork { id: netIcon; anchors.centerIn: parent }
        }
        
        // --- Bluetooth ---
        Item {
            width: btIcon.width; height: btIcon.height
            anchors.horizontalCenter: parent.horizontalCenter
            DockBluetooth { id: btIcon; anchors.centerIn: parent }
        }

        // --- Audio ---
        Canvas {
            id: audioIcon
            width: 12
            height: 12
            anchors.horizontalCenter: parent.horizontalCenter

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
                var r = (width / 2) - 1.5;
                
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.lineWidth = 2.5;
                ctx.strokeStyle = Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.4);
                ctx.stroke();
                
                if (root.volumeLevel > 0) {
                    ctx.beginPath();
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (Math.min(root.volumeLevel, 1.0) * 2 * Math.PI);
                    ctx.arc(cx, cy, r, startAngle, endAngle);
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = root.isMuted ? Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.5) : Theme.primary;
                    ctx.stroke();
                }
            }
        }

        // --- Battery ---
        Item {
            id: batteryIconItem
            width: 10
            height: 20
            anchors.horizontalCenter: parent.horizontalCenter

            // Internal logic
            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            // Battery nub (terminal)
            Rectangle {
                id: batteryNub
                width: 4
                height: 2
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }
                radius: 1
                color: batteryBody.border.color
            }

            Rectangle {
                id: batteryBody
                anchors {
                    left: parent.left
                    top: batteryNub.bottom
                    bottom: parent.bottom
                    right: parent.right
                }
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: {
                    if (batteryIconItem.capacity <= 20 && !batteryIconItem.isCharging)
                        return Theme.critical;
                    if (batteryIconItem.isCharging)
                        return "#259b50";
                    return Theme.primary;
                }
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }

            Rectangle {
                id: batteryFill
                anchors {
                    left: batteryBody.left
                    right: batteryBody.right
                    bottom: batteryBody.bottom
                    margins: 2
                }
                radius: 1
                height: Math.max(0, (batteryBody.height - 4) * (batteryIconItem.capacity / 100))
                color: batteryBody.border.color
                opacity: 1.0

                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            Text {
                visible: batteryIconItem.isCharging
                anchors.centerIn: batteryBody
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 7
                color: Theme.on_surface
            }
        }
    }
}
