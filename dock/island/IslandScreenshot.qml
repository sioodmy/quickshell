import QtQuick
import qs.theme
import qs.services
import qs.components

Row {
    id: root
    spacing: 8

    signal finished()

    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root.finished();
            Screenshot.overlayActive = false;
        }
    }

    component Btn: Rectangle {
        property string icon
        property string label
        signal clicked()
        width: 80
        height: 32
        radius: height / 2
        color: m.containsMouse ? Theme.bubble_hover : Theme.bubble
        border.color: Theme.bubble_border
        border.width: 1
        clip: true
        scale: m.pressed ? 0.94 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        BubbleSheen {}

        Row {
            anchors.centerIn: parent
            spacing: 4
            z: 1
            MaterialIcon {
                icon: parent.parent.icon
                font.pixelSize: 14
                color: m.containsMouse ? Theme.primary : Theme.on_surface
            }
            Text {
                text: parent.parent.label
                font.family: "Google Sans Medium"
                font.pixelSize: 12
                color: m.containsMouse ? Theme.primary : Theme.on_surface
            }
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Btn {
        icon: "fullscreen"
        label: "Full"
        onClicked: Screenshot.finishFullscreen()
    }
    Btn {
        icon: "crop"
        label: "Area"
        onClicked: Screenshot.finishArea()
    }
    Btn {
        icon: "window"
        label: "Window"
        onClicked: Screenshot.finishWindow()
    }
    Btn {
        icon: "close"
        label: "Close"
        onClicked: {
            root.finished();
            Screenshot.overlayActive = false;
        }
    }
}
