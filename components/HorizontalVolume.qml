import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme

Item {
    id: root

    implicitWidth: layout.implicitWidth + 16
    implicitHeight: 32

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

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 14
            color: Theme.on_surface_variant
            icon: {
                if (!root.activeSink?.audio) return "volume_off";
                if (root.isMuted) return "volume_off";
                if (root.volumeLevel >= 0.6) return "volume_up";
                if (root.volumeLevel >= 0.3) return "volume_down";
                return "volume_mute";
            }
        }
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeSink?.audio ? Math.round(root.volumeLevel * 100) + "%" : "--%"
            color: Theme.on_surface_variant
            font {
                family: "Google Sans"
                pixelSize: 13
                weight: Font.Medium
            }
        }
    }
}
