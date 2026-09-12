import QtQuick
import QtQuick.Effects
import "../theme"
import qs.components
import qs.services

Rectangle {
    id: root

    property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0

    width: parent.width
    height: mediaActive ? 68 : 0
    radius: 18
    color: Qt.rgba(1, 1, 1, 0.28)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.4)
    clip: true
    visible: height > 0.5
    opacity: mediaActive ? 1 : 0

    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    BubbleSheen {}

    Row {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 10
        opacity: root.mediaActive ? 1 : 0
        z: 1

        Rectangle {
            width: 48
            height: 48
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.22)
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: artImg
                anchors.fill: parent
                source: Playerctl.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(96, 96)
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
                font.pixelSize: 18
                color: Qt.rgba(1, 1, 1, 0.45)
            }
        }

        Column {
            width: parent.width - 48 - 10 - transport.width - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: Playerctl.title
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.92)
                font { family: "Google Sans"; pixelSize: 13; weight: Font.DemiBold }
            }

            Text {
                width: parent.width
                text: Playerctl.artist
                elide: Text.ElideRight
                color: Qt.rgba(1, 1, 1, 0.62)
                font { family: "Google Sans"; pixelSize: 11 }
                visible: text.length > 0
            }

            Item {
                width: parent.width
                height: 6
                visible: Playerctl.length > 0

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.22)

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

        Row {
            id: transport
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            component MediaBtn: Rectangle {
                property string icon
                property bool accent: false
                signal triggered

                width: 34
                height: 34
                radius: width / 2
                color: {
                    if (accent)
                        return Qt.alpha(Theme.primary, 0.5);
                    return btnMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.4)
                        : Qt.rgba(1, 1, 1, 0.26);
                }
                border.width: 1
                border.color: accent ? Qt.alpha(Theme.primary, 0.55) : Qt.rgba(1, 1, 1, 0.4)
                clip: true
                Behavior on color { ColorAnimation { duration: 120 } }

                BubbleSheen { visible: accent }

                MaterialIcon {
                    anchors.centerIn: parent
                    z: 1
                    icon: parent.icon
                    font.pixelSize: 14
                    color: parent.accent ? Theme.on_primary : Qt.rgba(1, 1, 1, 0.92)
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
