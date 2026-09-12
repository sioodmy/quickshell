import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

/**
 * Fullscreen now-playing + lyrics — album-tinted frosted glass.
 * Palette comes from the rust daemon; QML only crossfades it.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fullscreen_media"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        visible: Lyrics.showFullscreen || opacityAnim.running

        readonly property color artPrimary: Playerctl.artPrimary
        readonly property color artSecondary: Playerctl.artSecondary
        readonly property color artAccent: Playerctl.artAccent
        readonly property color artBg: Playerctl.artBg
        readonly property color artFg: Playerctl.artFg

        Item {
            anchors.fill: parent

            opacity: Lyrics.showFullscreen ? 1.0 : 0.0
            scale: Lyrics.showFullscreen ? 1.0 : 1.06

            Behavior on opacity {
                NumberAnimation { id: opacityAnim; duration: 420; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }

            AlbumBackdrop {
                artUrl: Playerctl.artUrl
                primary: artPrimary
                secondary: artSecondary
                accent: artAccent
                bg: artBg
                alive: Lyrics.showFullscreen
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Lyrics.showFullscreen = false

                MouseArea {
                    anchors.fill: parent
                    onClicked: Lyrics.showFullscreen = false
                }
            }

            Row {
                id: mainRow
                property bool hasLyrics: Lyrics.parsedLyrics.length > 0

                anchors.fill: parent
                anchors.margins: 48
                spacing: hasLyrics ? 36 : 0

                Behavior on spacing { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                // LEFT: media card
                Item {
                    width: mainRow.hasLyrics ? (parent.width - 36) / 2 : parent.width
                    height: parent.height

                    Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                    MouseArea {
                        anchors.fill: mediaCard
                    }

                    Rectangle {
                        id: mediaCard
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.92, 460)
                        height: mediaCol.implicitHeight + 48
                        radius: 32
                        color: Qt.rgba(1, 1, 1, 0.24)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.4)
                        Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }

                        BubbleSheen {}

                        // Keep title/artist readable over bright frosted glass
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            z: 0
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.12) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                            }
                        }

                        Column {
                            id: mediaCol
                            anchors.centerIn: parent
                            width: parent.width - 48
                            spacing: 22
                            z: 1

                            Item {
                                width: Math.min(parent.width, 320)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 22
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    opacity: (BackendDaemon.musicRemoteUrl === "" || BackendDaemon.musicRemoteConnected) ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    clip: true

                                    Image {
                                        id: mainArt
                                        anchors.fill: parent
                                        source: Playerctl.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(480, 480)
                                        visible: Playerctl.artUrl !== ""
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: Playerctl.artUrl === ""
                                        icon: "music_note"
                                        font.pixelSize: 72
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 22
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                    opacity: (BackendDaemon.musicRemoteUrl !== "" && !BackendDaemon.musicRemoteConnected) ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 14

                                        Rectangle {
                                            width: 168
                                            height: 168
                                            radius: 20
                                            color: "white"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            clip: true

                                            Image {
                                                anchors.centerIn: parent
                                                width: 140
                                                height: 140
                                                source: BackendDaemon.musicRemoteQrSvg !== ""
                                                    ? "data:image/svg+xml;utf8," + encodeURIComponent(BackendDaemon.musicRemoteQrSvg)
                                                    : ""
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(200, 200)
                                            }
                                        }

                                        Text {
                                            text: "Scan to Control Music"
                                            font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                                            color: Qt.rgba(1, 1, 1, 0.85)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: Playerctl.title !== "" ? Playerctl.title : "No Media"
                                    font { family: "Google Sans"; pixelSize: 26; weight: Font.Bold }
                                    color: Qt.rgba(1, 1, 1, 0.95)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: parent.width
                                    text: Playerctl.artist !== "" ? Playerctl.artist : "Unknown Artist"
                                    font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // Progress (always under art when lyrics present)
                            Item {
                                width: parent.width
                                height: 28
                                visible: Playerctl.length > 0

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.28)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: parent.height
                                        radius: 2
                                        color: artAccent
                                        width: parent.width * (Playerctl.length > 0
                                            ? Math.min(1, Playerctl.position / Playerctl.length) : 0)
                                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.Linear } }
                                        Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: -10
                                        anchors.bottomMargin: -10
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (width > 0)
                                                Playerctl.setPosition(Math.max(0, Math.min(1, mouse.x / width)) * Playerctl.length);
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 16

                                component TransportBtn: Rectangle {
                                    property string iconName
                                    property real size: 48
                                    property bool accent: false
                                    signal triggered

                                    width: size
                                    height: size
                                    radius: size / 2
                                    color: {
                                        if (accent)
                                            return Qt.alpha(Playerctl.artAccent, Playerctl.isPlaying ? 0.62 : 0.4);
                                        return hover.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.4)
                                            : Qt.rgba(1, 1, 1, 0.28);
                                    }
                                    border.width: 1
                                    border.color: accent
                                        ? Qt.rgba(1, 1, 1, 0.45)
                                        : Qt.rgba(1, 1, 1, 0.38)
                                    clip: true
                                    scale: hover.pressed ? 0.92 : (hover.containsMouse ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    BubbleSheen { visible: accent }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        z: 1
                                        icon: parent.iconName
                                        font.pixelSize: Math.round(parent.size * 0.42)
                                        color: parent.accent ? Playerctl.artFg : Qt.rgba(1, 1, 1, 0.85)
                                    }

                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.triggered()
                                    }
                                }

                                TransportBtn {
                                    iconName: "skip_previous"
                                    onTriggered: Playerctl.previous()
                                }
                                TransportBtn {
                                    iconName: Playerctl.isPlaying ? "pause" : "play_arrow"
                                    size: 64
                                    accent: true
                                    onTriggered: Playerctl.playPause()
                                }
                                TransportBtn {
                                    iconName: "skip_next"
                                    onTriggered: Playerctl.next()
                                }
                            }
                        }
                    }
                }

                // RIGHT: lyrics glass pane
                Rectangle {
                    width: mainRow.hasLyrics ? (parent.width - 36) / 2 : 0
                    height: parent.height
                    radius: 32
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.38)
                    opacity: mainRow.hasLyrics ? 1.0 : 0.0
                    Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
                    scale: mainRow.hasLyrics ? 1.0 : 0.96
                    visible: opacity > 0 || width > 0
                    clip: true

                    Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }
                    Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                    BubbleSheen {}
                    MouseArea { anchors.fill: parent }

                    // Soft dark wash so white lyrics stay readable on bright glass
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        z: 0
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
                            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.1) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
                        }
                    }

                    ListView {
                        id: lyricsView
                        anchors.fill: parent
                        anchors.margins: 56
                        anchors.topMargin: 64
                        anchors.bottomMargin: 64
                        clip: true
                        z: 1

                        model: Lyrics.parsedLyrics
                        interactive: true

                        preferredHighlightBegin: height * 0.28
                        preferredHighlightEnd: height * 0.35
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        highlightMoveDuration: 520

                        currentIndex: Math.max(0, Lyrics.currentIndex)

                        delegate: Item {
                            width: ListView.view.width
                            height: contentCol.implicitHeight + 28

                            property bool isCurrent: index === lyricsView.currentIndex

                            MouseArea {
                                id: lyricMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Playerctl.setPosition(modelData.time)
                            }

                            Column {
                                id: contentCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.text
                                    color: Qt.rgba(1, 1, 1, 1)
                                    wrapMode: Text.WordWrap

                                    font {
                                        family: "Google Sans"
                                        pixelSize: isCurrent ? 34 : 22
                                        weight: isCurrent ? Font.Bold : Font.Medium
                                    }

                                    opacity: Math.min(1.0, (isCurrent ? 1.0 : 0.28) + (lyricMouse.containsMouse ? 0.3 : 0.0))
                                    scale: isCurrent ? 1.0 : 0.94
                                    transformOrigin: Item.Left

                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.textTranslit !== undefined ? modelData.textTranslit : ""
                                    visible: text !== ""
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    wrapMode: Text.WordWrap

                                    font {
                                        family: "Google Sans"
                                        pixelSize: isCurrent ? 18 : 14
                                        weight: Font.Medium
                                    }

                                    opacity: Math.min(1.0, (isCurrent ? 0.75 : 0.2) + (lyricMouse.containsMouse ? 0.25 : 0.0))
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        z: 1
                        visible: Lyrics.parsedLyrics.length === 0
                        text: Playerctl.isPlaying ? "Fetching lyrics…" : "No Media"
                        font { family: "Google Sans"; pixelSize: 20; weight: Font.Medium }
                        color: Qt.rgba(1, 1, 1, 0.4)
                    }
                }
            }

            // Cast / sync — floating bubble
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 40
                anchors.bottomMargin: 40
                width: 52
                height: 52
                radius: 26
                color: remoteMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.4)
                    : Qt.rgba(1, 1, 1, 0.28)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.4)
                opacity: Playerctl.hasPlayer ? 1.0 : 0.0
                visible: opacity > 0
                clip: true

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                BubbleSheen {}

                MaterialIcon {
                    anchors.centerIn: parent
                    z: 1
                    icon: BackendDaemon.musicRemoteUrl !== "" ? "cast" : "sync"
                    font.pixelSize: 22
                    color: Qt.rgba(1, 1, 1, 0.75)
                }

                MouseArea {
                    id: remoteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (BackendDaemon.musicRemoteUrl !== "")
                            BackendDaemon.send({action: "music_remote_stop"});
                        else
                            BackendDaemon.send({action: "music_remote_start"});
                    }
                }
            }
        }
    }
}
