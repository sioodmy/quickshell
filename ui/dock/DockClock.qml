import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

Item {
    id: root

    property bool osdActive: false
    property string osdIcon: "volume_up"

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
            if (root.osdActive)
                return "transparent";
            if (root.calendarOpen)
                return Qt.rgba(1, 1, 1, 0.15);
            if (pillMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.1);
            return "transparent";
        }

        scale: pillMouse.pressed && !root.calendarOpen && !root.osdActive ? 0.95 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        Item {
            id: swapHost
            anchors.centerIn: parent
            width: timeRow.implicitWidth
            height: timeRow.implicitHeight

            Row {
                id: timeRow
                anchors.centerIn: parent
                spacing: 2
                opacity: root.calendarOpen ? 0.5 : 1.0
                scale: 1
                transformOrigin: Item.Center

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

            MaterialIcon {
                id: osdGlyph
                anchors.centerIn: parent
                icon: root.osdIcon
                fill: 1
                font.pixelSize: 16
                color: "#ffffff"
                opacity: 0
                scale: 0.35
                transformOrigin: Item.Center
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.osdActive
            cursorShape: root.osdActive ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: root.toggleCalendar()
        }
    }

    states: State {
        name: "osd"
        when: root.osdActive
        PropertyChanges { target: timeRow; opacity: 0; scale: 0.35 }
        PropertyChanges { target: osdGlyph; opacity: 1; scale: 1 }
    }

    transitions: [
        Transition {
            to: "osd"
            ParallelAnimation {
                NumberAnimation { target: timeRow; property: "opacity"; duration: 80; easing.type: Easing.OutCubic }
                NumberAnimation { target: timeRow; property: "scale"; duration: 80; easing.type: Easing.InCubic }
                NumberAnimation { target: osdGlyph; property: "opacity"; duration: 80; easing.type: Easing.OutCubic }
                NumberAnimation { target: osdGlyph; property: "scale"; duration: 180; easing.type: Easing.OutBack }
            }
        },
        Transition {
            from: "osd"
            ParallelAnimation {
                NumberAnimation { target: osdGlyph; property: "opacity"; duration: 80; easing.type: Easing.OutCubic }
                NumberAnimation { target: osdGlyph; property: "scale"; duration: 80; easing.type: Easing.InCubic }
                NumberAnimation { target: timeRow; property: "opacity"; duration: 80; easing.type: Easing.OutCubic }
                NumberAnimation { target: timeRow; property: "scale"; duration: 180; easing.type: Easing.OutBack }
            }
        }
    ]

    SequentialAnimation {
        id: iconPop
        NumberAnimation { target: osdGlyph; property: "scale"; to: 0.6; duration: 50; easing.type: Easing.InCubic }
        NumberAnimation { target: osdGlyph; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
    }

    onOsdActiveChanged: {
        if (!root.osdActive)
            iconPop.stop();
    }

    onOsdIconChanged: {
        // Don't fight the enter transition; only pop once the glyph is on screen.
        if (root.osdActive && osdGlyph.opacity > 0.9)
            iconPop.restart();
    }
}
