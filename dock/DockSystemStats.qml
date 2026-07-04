import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.services

Rectangle {
    id: root
    
    signal requestTooltip(string text, real globalY)
    signal hideTooltip()
    
    implicitWidth: 40
    implicitHeight: layout.implicitHeight + 20
    radius: 20

    color: ccTap.pressed
        ? Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12))
        : (ccHover.hovered
            ? Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06))
            : Theme.surface_container)

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    
    scale: ccTap.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    HoverHandler {
        id: ccHover
    }

    TapHandler {
        id: ccTap
        onTapped: ControlCenter.toggle()
        cursorShape: Qt.PointingHandCursor
    }

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
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        var nw = netIcon.activeNetwork;
                        var txt = nw ? (nw.ssid || "Connected") : "Disconnected";
                        root.requestTooltip("Wi-Fi: " + txt, mapToItem(null, 0, 0).y);
                    } else {
                        root.hideTooltip();
                    }
                }
            }
        }
        
        // --- Bluetooth ---
        Item {
            width: btIcon.width; height: btIcon.height
            anchors.horizontalCenter: parent.horizontalCenter
            DockBluetooth { id: btIcon; anchors.centerIn: parent }
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        var isEnabled = btIcon.adapter && btIcon.adapter.enabled;
                        var txt = !isEnabled ? "Off" : (btIcon.connectedDevices.length > 0 ? btIcon.connectedDevices[0].name : "Disconnected");
                        root.requestTooltip("Bluetooth: " + txt, mapToItem(null, 0, 0).y);
                    } else {
                        root.hideTooltip();
                    }
                }
            }
        }

        // --- Audio ---
        Canvas {
            id: audioIcon
            width: 16
            height: 16
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
                ctx.lineWidth = 3;
                ctx.strokeStyle = Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.4);
                ctx.stroke();
                
                if (root.volumeLevel > 0) {
                    ctx.beginPath();
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (Math.min(root.volumeLevel, 1.0) * 2 * Math.PI);
                    ctx.arc(cx, cy, r, startAngle, endAngle);
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = root.isMuted ? Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.5) : Theme.primary;
                    ctx.stroke();
                }
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        var txt = root.activeSink?.audio ? Math.round(root.volumeLevel * 100) + "%" : "--%";
                        root.requestTooltip("Volume: " + txt, audioIcon.mapToItem(null, 0, 0).y);
                    } else {
                        root.hideTooltip();
                    }
                }
            }
        }

        // --- Battery ---
        Item {
            id: batteryIconItem
            width: 12
            height: 26
            anchors.horizontalCenter: parent.horizontalCenter

            // Internal logic
            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            // Battery nub (terminal)
            Rectangle {
                id: batteryNub
                width: 6
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
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
                color: Theme.on_surface
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        root.requestTooltip("Battery: " + Math.round(batteryIconItem.capacity) + "%", batteryIconItem.mapToItem(null, 0, 0).y);
                    } else {
                        root.hideTooltip();
                    }
                }
            }
        }
    }
}
