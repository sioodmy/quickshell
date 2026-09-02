import QtQuick
import Quickshell
import qs.theme
import qs.services
import "../popups/calendar"

Item {
    id: root

    implicitWidth: timeRow.implicitWidth + 24
    implicitHeight: 32

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property bool calendarOpen: CalendarState.open || CalendarState.openProgress > 0.01

    function captureSource() {
        const g = root.mapToGlobal(0, 0);
        CalendarState.sourceX = g.x;
        CalendarState.sourceY = g.y;
        CalendarState.sourceW = root.width;
        CalendarState.sourceH = root.height;
        CalendarState.hoursText = Qt.formatDateTime(clock.date, "HH");
        CalendarState.minutesText = Qt.formatDateTime(clock.date, "mm");
    }

    function toggleCalendar() {
        // Disabled since Calendar is now integrated in DynamicIsland.
    }

    Rectangle {
        id: visualPill
        anchors.fill: parent
        radius: height / 2

        color: {
            if (root.calendarOpen)
                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12);
            if (pillMouse.containsMouse)
                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
            return "transparent";
        }

        scale: pillMouse.pressed && !root.calendarOpen ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        Row {
            id: timeRow
            anchors.centerIn: parent
            spacing: 2
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.on_surface
                font {
                    family: "Google Sans"
                    pixelSize: 14
                    weight: Font.Bold
                }
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleCalendar()
        }
    }
}
