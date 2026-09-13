pragma Singleton

import Quickshell

/** Global open/close state for the app launcher, shared with the dock for seamless visuals. */
Singleton {
    id: root

    property bool open: false
    property real openProgress: 0.0

    // Compact island footprint — slightly taller than calendar (540×310) for search + results.
    readonly property real targetWidth: 560
    readonly property real targetHeight: 400
    readonly property real targetRadius: 20

    // Live dock notch size, written by Dock so the launcher can morph from it.
    property real dockWidth: 280
    property real dockHeight: 42
    property real dockRadius: 14

    // Screen the launcher is showing on — other docks stay collapsed.
    property var screen: null

    // Applied once on the next open (or immediately if already open).
    property string pendingQuery: ""

    signal closeRequested()
    signal openRequested()

    function requestClose() {
        closeRequested();
    }

    function openWithQuery(query) {
        pendingQuery = query || "";
        openRequested();
    }
}
