import QtQuick
import "../../theme"

Item {
    id: calcCard
    property string calcResult: ""
    property string calcExpression: ""
    signal copyRequested()

    height: visible ? calcCardContent.height : 0
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: calcCardContent
        width: parent.width
        height: 72
        radius: 20
        color: Theme.primary_container

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            spacing: 12

            // Calculator icon
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰃬"
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 24
                }
                color: Theme.on_primary_container
            }

            // Expression and result
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 130
                spacing: 2

                Text {
                    width: parent.width
                    text: calcCard.calcExpression
                    color: Theme.on_primary_container
                    opacity: 0.7
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 13
                    }
                }
                Text {
                    width: parent.width
                    text: calcCard.calcResult
                    color: Theme.on_primary_container
                    elide: Text.ElideRight
                    font {
                        family: "Google Sans"
                        pixelSize: 18
                        weight: Font.Bold
                    }
                }
            }

            // Copy button
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 32
                radius: 16
                color: calcCopyMouse.containsMouse ? Theme.primary : Qt.tint(Theme.primary_container, Qt.rgba(Theme.on_primary_container.r, Theme.on_primary_container.g, Theme.on_primary_container.b, 0.12))

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copy"
                        color: calcCopyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                        font {
                            family: "Google Sans"
                            pixelSize: 12
                            weight: Font.Medium
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰆏"
                        color: calcCopyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 14
                        }
                    }
                }

                MouseArea {
                    id: calcCopyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calcCard.copyRequested()
                }
            }
        }
    }
}
