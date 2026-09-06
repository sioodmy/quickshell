import QtQuick
import qs.components

Item {
    id: root

    property real osdDockWidth: 300
    property real osdDockHeight: 42
    property real osdProgress: 0.0
    property string osdIcon: "volume_up"
    property string osdTitle: "Volume"
    property string osdText: "100%"
    property color osdColor: "#ffffff"

    implicitWidth: osdDockWidth
    implicitHeight: osdDockHeight

    // Base Unclipped Labels Overlay (white/light text over dark dock background)
    Item {
        anchors.top: parent.top
        anchors.topMargin: 14
        height: 28
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.osdIcon
                font.pixelSize: 16
                color: "#ffffff"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.osdTitle
                color: "#ffffff"
                font.family: "Google Sans"
                font.pointSize: 10
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.osdText
            color: "#ffffff"
            font.family: "Google Sans"
            font.pointSize: 10
            font.weight: Font.Bold
        }
    }

    // Full-bleed Progress Fill Bar (rounded left dock edge, sharp plain vertical right edge)
    Item {
        id: progressClipper
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1.0, Math.max(0.0, root.osdProgress))
        clip: true

        Behavior on width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.osdDockWidth
            color: root.osdColor
            radius: 14
        }

        // Clipped Dark Labels Overlay (dark gray text over white fill bar)
        Item {
            width: root.osdDockWidth
            height: root.osdDockHeight
            anchors.left: parent.left
            anchors.top: parent.top

            Item {
                anchors.top: parent.top
                anchors.topMargin: 14
                height: 28
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.osdIcon
                        font.pixelSize: 16
                        color: "#1e1e1e"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.osdTitle
                        color: "#1e1e1e"
                        font.family: "Google Sans"
                        font.pointSize: 10
                        font.weight: Font.Medium
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.osdText
                    color: "#1e1e1e"
                    font.family: "Google Sans"
                    font.pointSize: 10
                    font.weight: Font.Bold
                }
            }
        }
    }
}
