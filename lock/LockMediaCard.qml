import QtQuick

import qs.theme
import qs.components
import qs.services

/**
 * Compact Now Playing view for the expanded lock shell.
 * Uses no layer effects: album color from Playerctl supplies depth while the
 * asynchronously decoded cover remains cheap to upload.
 */
Item {
    id: root

    property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0
    property real presentationProgress: 1

    implicitWidth: 420
    implicitHeight: mediaActive ? 88 : 0
    visible: height > 0.5
    opacity: mediaActive ? Math.max(0, Math.min(1, presentationProgress)) : 0
    clip: true

    Behavior on implicitHeight {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 21
        color: Qt.rgba(1, 1, 1, 0.09)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        clip: true

        BubbleSheen {}

        // A restrained album-color wash gives the card identity without blur.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Playerctl.artPrimary, 0.1)

            Behavior on color { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            z: 1

            Rectangle {
                id: artworkFrame
                width: 68
                height: 68
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Playerctl.artPrimary, 0.28)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.26)
                clip: true

                // Kept slightly inset so square image corners disappear into the
                // dark rounded frame without requiring a shader mask.
                Image {
                    id: artwork
                    anchors.fill: parent
                    anchors.margins: 3
                    source: root.mediaActive ? Playerctl.artUrl : ""
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 220 } }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: artwork.status !== Image.Ready
                    icon: "music_note"
                    fill: 0
                    grade: -25
                    weight: 300
                    font.pixelSize: 22
                    color: Qt.rgba(1, 1, 1, 0.64)
                }
            }

            Column {
                width: Math.max(80, parent.width - artworkFrame.width - controls.width - 36)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    text: Playerctl.title
                    color: Qt.rgba(1, 1, 1, 0.95)
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 14
                        weight: Font.DemiBold
                    }
                }

                Text {
                    width: parent.width
                    text: Playerctl.artist.length > 0 ? Playerctl.artist : "Now Playing"
                    color: Qt.rgba(1, 1, 1, 0.58)
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 11
                        weight: Font.Medium
                    }
                }

                Item {
                    width: parent.width
                    height: 9
                    visible: Playerctl.length > 0

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.16)

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1,
                                Playerctl.length > 0 ? Playerctl.position / Playerctl.length : 0))
                            color: Playerctl.artPrimary

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            Row {
                id: controls
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter

                component MediaButton: Rectangle {
                    id: button

                    required property string icon
                    property bool primary: false
                    signal triggered

                    width: primary ? 38 : 32
                    height: width
                    radius: width / 2
                    color: primary
                        ? Qt.alpha(Playerctl.artPrimary, mouse.containsMouse ? 0.72 : 0.52)
                        : (mouse.containsMouse ? Theme.bubble_hover : Theme.bubble)
                    border.width: 1
                    border.color: primary
                        ? Qt.alpha(Playerctl.artPrimary, 0.8)
                        : Theme.bubble_border_soft
                    scale: mouse.pressed ? 0.9 : 1
                    clip: true

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    BubbleSheen {}

                    MaterialIcon {
                        anchors.centerIn: parent
                        z: 1
                        icon: button.icon
                        fill: 0
                        grade: -25
                        weight: 300
                        font.pixelSize: button.primary ? 17 : 14
                        color: Qt.rgba(1, 1, 1, 0.94)
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: button.triggered()
                    }
                }

                MediaButton {
                    icon: "skip_previous"
                    onTriggered: Playerctl.previous()
                }

                MediaButton {
                    icon: Playerctl.isPlaying ? "pause" : "play_arrow"
                    primary: true
                    onTriggered: Playerctl.playPause()
                }

                MediaButton {
                    icon: "skip_next"
                    onTriggered: Playerctl.next()
                }
            }
        }
    }
}
