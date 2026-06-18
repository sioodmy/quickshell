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

            Text {
                id: batteryIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 14
                }

                // Color logic: Alert user if charging (active state) or critically low
                color: (batteryModule.isCharging && batteryModule.capacity < 100) || batteryModule.capacity <= 20 ? Theme.critical : Theme.primary

                text: {
                    if (!batteryModule.isVisible)
                        return "";
                    if (batteryModule.isCharging && batteryModule.capacity < 100)
                        return "";

                    // Capacity breakpoints
                    if (batteryModule.capacity >= 90)
                        return "󰂂";
                    if (batteryModule.capacity >= 70)
                        return "󰂀";
                    if (batteryModule.capacity >= 50)
                        return "󰁾";
                    if (batteryModule.capacity >= 30)
                        return "󰁼";
                    if (batteryModule.capacity >= 10)
                        return "󰁺";
                    return "󰂃";
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
