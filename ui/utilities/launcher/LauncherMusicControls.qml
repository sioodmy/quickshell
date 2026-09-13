import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.components

Item {
    id: root
    anchors.fill: parent

    readonly property var state: BackendDaemon.musicState || ({})
    readonly property real pad: 12
    readonly property real innerWidth: Math.max(0, width - pad * 2)
    // Transport must always fit: five buttons + gaps inside innerWidth.
    readonly property real btnGap: 6
    readonly property real btnSize: Math.max(28, Math.min(36, (innerWidth - btnGap * 4) / 5.6))
    readonly property real playSize: Math.min(btnSize + 8, innerWidth * 0.22)
    readonly property real artSize: Math.min(52, Math.max(40, Math.min(innerWidth * 0.22, height * 0.18)))

    function formatTime(secs) {
        secs = Number(secs);
        if (isNaN(secs) || secs < 0)
            return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function safeStr(v) {
        return (v === undefined || v === null) ? "" : ("" + v);
    }

    component TransportBtn: Rectangle {
        property string iconName
        property real size: root.btnSize
        property int iconPx: Math.round(size * 0.48)
        property bool accent: false
        property bool active: false
        signal triggered

        width: size
        height: size
        radius: size / 2
        color: {
            if (accent)
                return root.state.playing ? Theme.bubble_accent : Theme.bubble_accent_soft;
            if (active)
                return Theme.bubble_accent_soft;
            return hover.containsMouse ? Theme.bubble_hover : Theme.bubble;
        }
        border.width: 1
        border.color: accent || active ? Theme.bubble_border : Theme.bubble_border_soft
        clip: true
        scale: hover.pressed ? 0.92 : (hover.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        BubbleSheen {
            visible: accent
        }

        MaterialIcon {
            anchors.centerIn: parent
            z: 1
            icon: parent.iconName
            font.pixelSize: parent.iconPx
            color: parent.accent || parent.active ? Theme.primary : Theme.on_surface
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.on_surface, 0.03)
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        anchors.topMargin: 10
        spacing: 10

        // ── Art + metadata ──
        Row {
            width: parent.width
            spacing: 10
            height: root.artSize

            ClippingRectangle {
                width: root.artSize
                height: root.artSize
                radius: 12
                color: Theme.glass_raised
                contentUnderBorder: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: {
                        var url = root.safeStr(root.state.artUrl);
                        return url !== "" ? url : "";
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(root.artSize * 2, root.artSize * 2)
                    visible: status === Image.Ready
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "music_note"
                    font.pixelSize: root.artSize * 0.4
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

            Column {
                width: Math.max(0, parent.width - root.artSize - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: {
                        var t = root.safeStr(root.state.title);
                        return t !== "" ? t : "Not Playing";
                    }
                    font.family: "Google Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.on_surface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    text: root.safeStr(root.state.artist)
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    width: parent.width
                    text: root.safeStr(root.state.album)
                    font.family: "Google Sans"
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                    opacity: 0.7
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // ── Progress ──
        Column {
            width: parent.width
            spacing: 4

            Item {
                width: parent.width
                height: 14

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Theme.glass_raised
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Theme.primary
                    width: {
                        var dur = Number(root.state.duration) || 0;
                        var pos = Number(root.state.position) || 0;
                        if (dur <= 0)
                            return 0;
                        return Math.max(4, parent.width * Math.min(pos / dur, 1.0));
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        var dur = Number(root.state.duration) || 0;
                        if (dur <= 0)
                            return;
                        var frac = Math.max(0, Math.min(1, mouse.x / Math.max(1, width)));
                        MusicService.setPosition(frac * dur);
                    }
                }
            }

            Row {
                width: parent.width

                Text {
                    id: posLabel
                    text: root.formatTime(root.state.position)
                    font.family: "Google Sans"
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                }

                Item {
                    width: Math.max(0, parent.width - posLabel.width - durLabel.width)
                    height: 1
                }

                Text {
                    id: durLabel
                    text: root.formatTime(root.state.duration)
                    font.family: "Google Sans"
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                }
            }
        }

        // ── Transport ──
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.btnGap
            height: Math.max(root.playSize, root.btnSize)

            TransportBtn {
                iconName: "repeat"
                size: root.btnSize
                anchors.verticalCenter: parent.verticalCenter
                active: !!root.state.loopAlbum
                onTriggered: MusicService.toggleLoop()
            }
            TransportBtn {
                iconName: "skip_previous"
                size: root.btnSize
                anchors.verticalCenter: parent.verticalCenter
                onTriggered: MusicService.previous()
            }
            TransportBtn {
                iconName: root.state.playing ? "pause" : "play_arrow"
                size: root.playSize
                iconPx: Math.round(root.playSize * 0.46)
                anchors.verticalCenter: parent.verticalCenter
                accent: true
                onTriggered: MusicService.toggle()
            }
            TransportBtn {
                iconName: "skip_next"
                size: root.btnSize
                anchors.verticalCenter: parent.verticalCenter
                onTriggered: MusicService.next()
            }
            TransportBtn {
                iconName: "lyrics"
                size: root.btnSize
                anchors.verticalCenter: parent.verticalCenter
                onTriggered: Lyrics.showFullscreen = true
            }
        }

        // ── Volume ──
        Row {
            id: volRow
            width: parent.width
            spacing: 8

            MaterialIcon {
                id: volIcon
                anchors.verticalCenter: parent.verticalCenter
                icon: {
                    var v = Number(root.state.volume) || 0;
                    if (v >= 0.5)
                        return "volume_up";
                    if (v > 0)
                        return "volume_down";
                    return "volume_mute";
                }
                font.pixelSize: 15
                color: Theme.on_surface_variant
            }

            Item {
                width: Math.max(0, volRow.width - volIcon.width - volRow.spacing)
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3
                    radius: 1.5
                    color: Theme.glass_raised
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 3
                    radius: 1.5
                    color: Theme.primary
                    width: Math.max(3, parent.width * Math.max(0, Math.min(1, Number(root.state.volume) || 0)))
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        MusicService.setVolume(Math.max(0, Math.min(1, mouse.x / Math.max(1, width))));
                    }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            MusicService.setVolume(Math.max(0, Math.min(1, mouse.x / Math.max(1, width))));
                    }
                }
            }
        }
    }
}
