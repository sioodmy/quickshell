import QtQuick
import Quickshell.Services.Mpris
import qs.services

Item {
    id: root

    readonly property bool fromMusicPlayer: Playerctl.hasPlayer

    // Prefer a playing external player; otherwise any non-quickshell player
    // that still has a track (paused). Ignore our own MPRIS export.
    readonly property var externalPlayer: {
        var list = Mpris.players.values;
        var fallback = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (root.isQuickshellMusic(p))
                continue;
            var playing = p.isPlaying;
            var title = p.trackTitle || "";
            if (playing)
                return p;
            if (!fallback && title !== "")
                fallback = p;
        }
        return fallback;
    }

    readonly property bool isVisible: fromMusicPlayer || externalPlayer !== null
    readonly property bool isPlaying: fromMusicPlayer
        ? Playerctl.isPlaying
        : !!(externalPlayer && externalPlayer.isPlaying)

    function isQuickshellMusic(player) {
        if (!player)
            return false;
        var dbus = (player.dbusName || "").toLowerCase();
        if (dbus.indexOf("quickshell") !== -1)
            return true;
        var identity = (player.identity || "").toLowerCase();
        return identity.indexOf("quickshell") !== -1;
    }

    function onActivate() {
        if (root.fromMusicPlayer) {
            LauncherState.openWithQuery("music");
            return;
        }
        if (root.externalPlayer) {
            if (root.externalPlayer.canTogglePlaying)
                root.externalPlayer.togglePlaying();
            else
                root.externalPlayer.isPlaying = !root.externalPlayer.isPlaying;
        }
    }

    implicitWidth: isVisible ? bars.implicitWidth + 10 : 0
    implicitHeight: 22

    clip: true
    opacity: isVisible ? 1 : 0

    Behavior on implicitWidth { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent
        width: bars.implicitWidth + 10
        height: 22
        radius: height / 2

        color: {
            if (pillMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.1);
            return "transparent";
        }

        scale: pillMouse.pressed ? 0.95 : 1.0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Row {
            id: bars
            anchors.centerIn: parent
            spacing: 2
            height: 14

            Repeater {
                model: 3
                Item {
                    width: 2.5
                    height: 14

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 2.5
                        height: 4
                        radius: 1.25
                        color: "#ffffff"
                        opacity: root.isPlaying ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            running: root.isVisible
                            paused: !root.isPlaying
                            NumberAnimation {
                                to: index === 0 ? 8 : (index === 1 ? 14 : 10)
                                duration: index === 0 ? 700 : (index === 1 ? 600 : 800)
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: index === 0 ? 14 : (index === 1 ? 6 : 14)
                                duration: index === 0 ? 600 : (index === 1 ? 700 : 500)
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: index === 0 ? 6 : (index === 1 ? 12 : 6)
                                duration: index === 0 ? 800 : (index === 1 ? 500 : 600)
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.onActivate()
        }
    }
}
