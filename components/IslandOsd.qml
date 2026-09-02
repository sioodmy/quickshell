import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import qs.services

Item {
    id: root

    property bool active: false
    property real progress: 0
    property string iconName: "volume_up"
    property color barColor: Theme.primary

    // Audio & Brightness Logic
    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0
    readonly property bool isMuted: activeSink?.audio?.muted ?? true

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.active = false
    }

    onVolumeLevelChanged: {
        root.progress = volumeLevel;
        root.iconName = isMuted ? "volume_off" : (volumeLevel > 0.5 ? "volume_up" : "volume_down");
        root.barColor = Theme.primary;
        root.active = true;
        hideTimer.restart();
    }
    
    onIsMutedChanged: {
        root.iconName = isMuted ? "volume_off" : (volumeLevel > 0.5 ? "volume_up" : "volume_down");
        root.barColor = Theme.primary;
        root.active = true;
        hideTimer.restart();
    }

    Connections {
        target: Brightness
        function onValueChanged() {
            root.progress = Brightness.value;
            root.iconName = Brightness.value > 0.5 ? "brightness_5" : "brightness_6";
            root.barColor = Theme.tertiary; // Give brightness a slightly different color if desired, or Theme.primary
            root.active = true;
            hideTimer.restart();
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
        clip: true

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1.0, Math.max(0.0, root.progress))
            color: root.barColor
            radius: parent.radius
            
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            icon: root.iconName
            color: (fill.width > 24) ? Theme.on_primary : Theme.on_surface
            font.pixelSize: 16
        }
    }
}
