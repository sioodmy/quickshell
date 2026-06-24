import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.services

/**
 * A unified system status indicator for Audio (Pipewire) and Power (UPower).
 * Clicking anywhere on the bubble opens the control center sidebar.
 */
Rectangle {
    id: root

    // --- Layout Configuration ---
    implicitWidth: contentLayout.width + 30
    implicitHeight: 28
    radius: height / 2
    color: ccTap.pressed
        ? Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12))
        : (ccHover.hovered
            ? Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06))
            : Theme.surface_container)

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

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

    /** Ensures Pipewire sink stays reactive to external system changes. */
    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Row {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 16

        // --- Audio Module ---
        Row {
            id: volumeModule
            spacing: 8

            Text {
                id: volumeIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 14
                }
                color: root.isMuted ? Theme.critical : Theme.primary

                text: {
                    if (!root.activeSink?.audio)
                        return ""; // No device
                    if (root.isMuted)
                        return "";           // Muted
                    if (root.volumeLevel >= 0.6)
                        return ""; // High
                    if (root.volumeLevel >= 0.3)
                        return ""; // Mid
                    return "";                              // Low
                }
            }

            Text {
                id: volumeLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pixelSize: 14
                }
                text: root.activeSink?.audio ? Math.round(root.volumeLevel * 100) + "%" : "--%"
            }
        }

        // --- Separator ---
        Rectangle {
            visible: batteryModule.isVisible
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Battery Module ---
        Row {
            id: batteryModule
            spacing: 8

            // Internal logic to keep UI bindings clean
            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            Item {
                id: batteryIconItem
                width: 26
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                // Battery body
                Rectangle {
                    id: batteryBody
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        rightMargin: 2
                    }
                    radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: {
                        if (batteryModule.capacity <= 20 && !batteryModule.isCharging)
                            return Theme.critical;
                        if (batteryModule.isCharging)
                            return "#259b50";
                        return Theme.primary;
                    }
                    
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                }

                // Battery nub (terminal)
                Rectangle {
                    width: 2
                    height: 4
                    anchors {
                        left: batteryBody.right
                        verticalCenter: parent.verticalCenter
                    }
                    radius: 1
                    color: batteryBody.border.color
                }

                // Battery level fill
                Rectangle {
                    id: batteryFill
                    anchors {
                        left: batteryBody.left
                        top: batteryBody.top
                        bottom: batteryBody.bottom
                        margins: 2
                    }
                    radius: 1
                    width: Math.max(0, (batteryBody.width - 4) * (batteryModule.capacity / 100))
                    color: {
                        if (batteryModule.capacity <= 20 && !batteryModule.isCharging)
                            return Theme.critical;
                        if (batteryModule.isCharging)
                            return "#259b50";
                        return Theme.primary;
                    }
                    opacity: 1.0

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                // Charging bolt icon
                Text {
                    visible: batteryModule.isCharging
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: Theme.on_surface
                }
            }

            Text {
                id: batteryLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pixelSize: 14
                }
                text: Math.round(batteryModule.capacity) + "%"
            }
        }

        // --- Separator ---
        Rectangle {
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Network Module ---
        Network {
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Separator ---
        Rectangle {
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Bluetooth Module ---
        Bluetooth {
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
