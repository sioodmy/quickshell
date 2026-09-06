import QtQuick
import QtQuick.Effects
import "../theme"
import qs.components
import qs.services

Rectangle {
    id: root

    property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0

    width: parent.width
    height: mediaActive ? 72 : 0
    radius: 16
    color: Theme.surface_container
    clip: true
    visible: height > 0.5
    opacity: mediaActive ? 1 : 0

    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Row {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        opacity: root.mediaActive ? 1 : 0

        // Album Art
        Rectangle {
            width: 52
            height: 52
            radius: 12
            color: Theme.surface_container_highest
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: artImg
                anchors.fill: parent
                source: Playerctl.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(104, 104)
                visible: status === Image.Ready

                layer.enabled: root.mediaActive && status === Image.Ready
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Rectangle {
                id: artMask
                anchors.fill: parent
                radius: 12
                visible: false
                layer.enabled: artImg.layer.enabled
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                icon: "music_note"
                font.pixelSize: 20
                color: Theme.on_surface_variant
            }
        }

        // Track Info & Progress
        Column {
            width: parent.width - 52 - 12 - transport.width - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: Playerctl.title
                elide: Text.ElideRight
                color: Theme.on_surface
                font { family: "Google Sans"; pixelSize: 14; weight: Font.DemiBold }
            }

            Text {
                width: parent.width
                text: Playerctl.artist
                elide: Text.ElideRight
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 12 }
                visible: text.length > 0
            }

            Item {
                width: parent.width
                height: 7
                visible: Playerctl.length > 0

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Theme.surface_container_highest

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * (Playerctl.length > 0
                            ? Math.min(1, Playerctl.position / Playerctl.length) : 0)
                        color: Theme.primary
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // Playback Controls
        Row {
            id: transport
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            component MediaBtn: Rectangle {
                property string icon
                property bool accent: false
                signal triggered

                width: 36
                height: 36
                radius: 10
                color: {
                    if (accent)
                        return Theme.primary;
                    return btnMouse.containsMouse
                        ? Theme.surface_container_highest
                        : "transparent";
                }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: parent.icon
                    font.pixelSize: 15
                    color: parent.accent ? Theme.on_primary : Theme.on_surface
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.triggered()
                }
            }

            MediaBtn {
                icon: "skip_previous"
                onTriggered: Playerctl.previous()
            }
            MediaBtn {
                icon: Playerctl.isPlaying ? "pause" : "play_arrow"
                accent: true
                onTriggered: Playerctl.playPause()
            }
            MediaBtn {
                icon: "skip_next"
                onTriggered: Playerctl.next()
            }
        }
    }
}
