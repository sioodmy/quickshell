import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services

Item {
    id: root

    function formatTime(secs) {
        if (isNaN(secs) || secs < 0) return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property real topSectionWidth: width - 32
    readonly property real artSize: Math.min((topSectionWidth - 12) / 2, 140)

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.03)
    }

    Flickable {
        id: controlsScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, controlsCol.height + 32)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: controlsCol
            width: parent.width
            y: Math.max(16, (controlsScroll.height - height) / 2)
            spacing: 0

            // ── Album art + metadata (50/50) ──
            Row {
                width: root.topSectionWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                height: artSize

                Item {
                    width: (parent.width - parent.spacing) / 2
                    height: artSize

                    Rectangle {
                        id: artContainer
                        anchors.centerIn: parent
                        width: root.artSize
                        height: root.artSize
                        radius: 16
                        color: Theme.surface_variant
                        clip: true

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: BackendDaemon.musicState.artUrl !== "" ? BackendDaemon.musicState.artUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: albumArt.width
                                        height: albumArt.height
                                        radius: 16
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: root.artSize * 0.32
                            color: Theme.on_surface_variant
                            visible: albumArt.status !== Image.Ready
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lyrics.showFullscreen = true
                        }
                    }
                }

                Column {
                    id: metaCol
                    width: (parent.width - parent.spacing) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        width: parent.width
                        text: BackendDaemon.musicState.title !== "" ? BackendDaemon.musicState.title : "Not Playing"
                        font.family: "Google Sans"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.on_surface
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: BackendDaemon.musicState.artist !== "" ? BackendDaemon.musicState.artist : ""
                        font.family: "Google Sans"
                        font.pixelSize: 12
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        visible: text !== ""
                    }

                    Text {
                        width: parent.width
                        text: BackendDaemon.musicState.album !== "" ? BackendDaemon.musicState.album : ""
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        color: Theme.on_surface_variant
                        opacity: 0.7
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                        visible: text !== ""
                    }
                }
            }

            Item { width: 1; height: 20 }

            // ── Progress bar ──
            Column {
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Item {
                    id: progressTrack
                    width: parent.width
                    height: 20

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        radius: 4
                        color: Theme.surface_variant
                    }

                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        radius: 4
                        color: Theme.primary
                        width: BackendDaemon.musicState.duration > 0
                            ? Math.max(8, parent.width * Math.min(BackendDaemon.musicState.position / BackendDaemon.musicState.duration, 1.0))
                            : 0
                    }

                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        x: progressFill.width - width / 2
                        visible: seekMouse.containsMouse || seekMouse.pressed
                        scale: seekMouse.pressed ? 1.2 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (BackendDaemon.musicState.duration <= 0) return;
                            var frac = Math.max(0, Math.min(1, mouse.x / width));
                            MusicService.setPosition(frac * BackendDaemon.musicState.duration);
                        }
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        id: posLabel
                        text: formatTime(BackendDaemon.musicState.position)
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        color: Theme.on_surface_variant
                    }

                    Item { width: parent.width - posLabel.width - durLabel.width; height: 1 }

                    Text {
                        id: durLabel
                        text: formatTime(BackendDaemon.musicState.duration)
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        color: Theme.on_surface_variant
                    }
                }
            }

            Item { width: 1; height: 16 }

            // ── Transport controls ──
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // Loop
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: BackendDaemon.musicState.loopAlbum
                        ? Theme.secondary_container
                        : (loopHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰑖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: BackendDaemon.musicState.loopAlbum ? Theme.on_secondary_container : Theme.on_surface_variant
                    }

                    MouseArea {
                        id: loopHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicService.toggleLoop()
                    }
                }

                // Previous
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: Theme.on_surface
                    }

                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicService.previous()
                    }
                }

                // Play / Pause
                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: BackendDaemon.musicState.playing ? Theme.primary : Theme.primary_container
                    scale: ppHover.pressed ? 0.92 : (ppHover.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        id: ppIcon
                        anchors.centerIn: parent
                        text: BackendDaemon.musicState.playing ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 26
                        color: BackendDaemon.musicState.playing ? Theme.on_primary : Theme.on_primary_container
                        scale: 1.0
                        onTextChanged: ppBounce.restart()
                        SequentialAnimation {
                            id: ppBounce
                            NumberAnimation { target: ppIcon; property: "scale"; to: 0.7; duration: 80; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ppIcon; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        }
                    }

                    MouseArea {
                        id: ppHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicService.toggle()
                    }
                }

                // Next
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: Theme.on_surface
                    }

                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MusicService.next()
                    }
                }

                // Lyrics / fullscreen
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: lyricsHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰨖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: Theme.on_surface_variant
                    }

                    MouseArea {
                        id: lyricsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Lyrics.showFullscreen = true
                    }
                }
            }

            Item { width: 1; height: 16 }

            // ── Volume ──
            Row {
                id: volRow
                width: parent.width - 48
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    id: volIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: BackendDaemon.musicState.volume >= 0.5 ? "󰕾"
                        : (BackendDaemon.musicState.volume > 0 ? "󰖀" : "󰕿")
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: Theme.on_surface_variant
                }

                Item {
                    id: volTrack
                    width: volRow.width - volIcon.width - volRow.spacing
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: Theme.surface_variant
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 4
                        radius: 2
                        color: Theme.primary
                        width: Math.max(4, parent.width * BackendDaemon.musicState.volume)
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            MusicService.setVolume(Math.max(0, Math.min(1, mouse.x / width)));
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                MusicService.setVolume(Math.max(0, Math.min(1, mouse.x / width)));
                        }
                    }
                }
            }

            Item { width: 1; height: 16 }
        }
    }
}
