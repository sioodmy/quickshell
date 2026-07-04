import QtQuick
import Quickshell
import qs.theme
import "../popups/calendar"

Item {
    id: root

    implicitWidth: 40
    implicitHeight: timeCol.implicitHeight + 16

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: 40
        implicitHeight: root.implicitHeight
        radius: width / 2

        color: {
            if (calendarWidget.visible)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12));
            if (pillMouse.containsMouse)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08));
            return Theme.surface_container;
        }

        scale: pillMouse.pressed ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        Column {
            id: timeCol
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "hh")
                color: Theme.on_surface
                font {
                    family: "Google Sans"
                    pixelSize: 17
                    weight: Font.Bold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.on_surface
                font {
                    family: "Google Sans"
                    pixelSize: 17
                    weight: Font.Bold
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarWidget.visible = !calendarWidget.visible
        }
    }

    CalendarWidget {
        id: calendarWidget
        visible: false
    }
}
