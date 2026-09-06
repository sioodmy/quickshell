import QtQuick
import Quickshell
import qs.theme
import qs.services
Item {
    id: root

    implicitWidth: timeRow.implicitWidth + 12
    implicitHeight: 22

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property bool calendarOpen: typeof dynamicIsland !== "undefined" && dynamicIsland.activeMode === "calendar"

    function toggleCalendar() {
        if (dynamicIsland.activeMode === "calendar") {
            dynamicIsland.activeMode = "dock";
        } else {
            dynamicIsland.activeMode = "calendar";
        }
    }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: root.implicitWidth
        implicitHeight: 22
        radius: height / 2

        color: {
            if (root.calendarOpen)
                return Qt.rgba(1, 1, 1, 0.15);
            if (pillMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.1);
            return "transparent";
        }

        scale: pillMouse.pressed && !root.calendarOpen ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        Row {
            id: timeRow
            anchors.centerIn: parent
            spacing: 2
            opacity: {
                if (dynamicIsland.activeMode === "calendar") return 0.5;
                return 1.0;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: "#ffffff"
                font {
                    family: "Google Sans"
                    pixelSize: 12
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
