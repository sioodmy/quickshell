import QtQuick
import Quickshell
import qs.theme
import qs.services
import "../popups/calendar"

Item {
    id: root

    implicitWidth: 28
    implicitHeight: timeCol.implicitHeight + 24

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property bool calendarOpen: CalendarState.open || CalendarState.openProgress > 0.01

    function captureSource() {
        const g = timeCol.mapToGlobal(0, 0);
        CalendarState.sourceX = g.x;
        CalendarState.sourceY = g.y;
        CalendarState.sourceW = timeCol.width;
        CalendarState.sourceH = timeCol.height;
        CalendarState.hoursText = Qt.formatDateTime(clock.date, "HH");
        CalendarState.minutesText = Qt.formatDateTime(clock.date, "mm");
    }

    function toggleCalendar() {
        if (calendarWidget.animating)
            return;
        if (CalendarState.open || calendarWidget.visible) {
            calendarWidget.closeAnimated();
        } else {
            captureSource();
            calendarWidget.openAnimated();
        }
    }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: 28
        implicitHeight: root.implicitHeight
        radius: width / 2

        color: {
            if (root.calendarOpen)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12));
            if (pillMouse.containsMouse)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08));
            return Theme.surface_container;
        }

        scale: pillMouse.pressed && !root.calendarOpen ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        Column {
            id: timeCol
            anchors.centerIn: parent
            spacing: 0
            // Dock digits hand off to the flying morph as soon as open begins
            opacity: {
                if (CalendarState.open && CalendarState.openProgress < 0.02)
                    return 0;
                return Math.max(0, 1.0 - CalendarState.openProgress * 2.8);
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
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
            onClicked: root.toggleCalendar()
        }
    }

    CalendarWidget {
        id: calendarWidget
        visible: false
    }
}
