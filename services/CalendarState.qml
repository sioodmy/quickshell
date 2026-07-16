pragma Singleton

import Quickshell

/** Global open/close state for the calendar, shared with the dock for clock morph. */
Singleton {
    id: root

    property bool open: false
    property real openProgress: 0.0

    // Dock clock source rect in global/screen coordinates
    property real sourceX: 0
    property real sourceY: 0
    property real sourceW: 28
    property real sourceH: 40

    property string hoursText: "00"
    property string minutesText: "00"
}
