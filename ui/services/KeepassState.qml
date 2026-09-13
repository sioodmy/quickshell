pragma Singleton

import Quickshell

/** Open/close state for the KeePass overlay, shared with the dock for island swallow. */
Singleton {
    id: root

    property bool open: false
    property real openProgress: 0.0

    // Compact island footprint — unlock is short; search/list expands.
    readonly property real targetWidth: 520
    readonly property real targetHeightLocked: 148
    readonly property real targetHeightUnlocked: 420
    readonly property real targetRadius: 20

    // Screen the overlay is showing on — other docks stay collapsed.
    property var screen: null

    signal closeRequested()

    function requestClose() {
        closeRequested();
    }
}
