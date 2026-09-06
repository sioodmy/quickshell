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
        radius: 16
        color: m.containsMouse ? Theme.primary_container : "transparent"
        border.color: Theme.surface_variant
        border.width: 1
        Row {
            anchors.centerIn: parent
            spacing: 4
            MaterialIcon {
                icon: parent.parent.icon
                font.pixelSize: 14
                color: m.containsMouse ? Theme.on_primary_container : "#ffffff"
            }
            Text {
                text: parent.parent.label
                font.family: "Google Sans Medium"
                font.pixelSize: 12
                color: m.containsMouse ? Theme.on_primary_container : "#ffffff"
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
