import QtQuick
import "../theme"
import qs.services

Item {
    id: root
    width: 32
    // total height includes 32 (icon) + 12 (margin above it)
    height: FileShare.active ? 44 : 0
    opacity: FileShare.active ? 1 : 0

    // Always visible so the anchors can smoothly interpolate
    visible: true
    clip: true // to prevent drawing outside when shrinking

    Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

    Rectangle {
        width: 32
        height: 32
        anchors.bottom: parent.bottom // Pin to the bottom of the container
        anchors.horizontalCenter: parent.horizontalCenter
        radius: width / 2
        color: hoverArea.hovered ? "#f38ba8" : "#2b2930"
        border.color: hoverArea.hovered ? "#f38ba8" : "#45475a"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: hoverArea.hovered ? "󰅖" : "" // share icon or X
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: hoverArea.hovered ? "#11111b" : "#cdd6f4"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    HoverHandler {
        id: hoverArea
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: FileShare.cancelAll()
    }
}
