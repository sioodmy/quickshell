import QtQuick
import "../../theme"
import qs.components

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
        color: Theme.glass_accent_soft
        border.width: 1
        border.color: Theme.glass_border

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            spacing: 12

            // Calculator icon
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "calculate"
                font.pixelSize: 24
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
                radius: height / 2
                color: calcCopyMouse.containsMouse ? Theme.bubble_accent : Theme.bubble_accent_soft
                border.width: 1
                border.color: Theme.bubble_border
                clip: true

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                BubbleSheen {}

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    z: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copy"
                        color: Theme.primary
                        font {
                            family: "Google Sans"
                            pixelSize: 12
                            weight: Font.Medium
                        }
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "content_copy"
                        color: Theme.primary
                        font.pixelSize: 14
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
