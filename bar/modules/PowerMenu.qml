import QtQuick
import qs.theme
import qs.bar.widgets.powermenu

Item {
    id: root

    implicitWidth: visualPill.implicitWidth
    implicitHeight: visualPill.implicitHeight

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: 28
        implicitHeight: 28
        radius: height / 2

        color: {
            if (powerWidget.visible)
                return Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.25);
            if (pillMouse.containsMouse)
                return Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.15);

            return "transparent";
        }

        scale: pillMouse.pressed ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: powerWidget.visible = !powerWidget.visible
        }

        Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.critical

            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 14
                weight: Font.Medium
            }
        }
    }

    PowerMenuWidget {
        id: powerWidget
        visible: false
    }
}
