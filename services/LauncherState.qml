pragma Singleton

import Quickshell

/** Global open/close state for the app launcher, shared with the dock for seamless visuals. */
Singleton {
    id: root

    property bool open: false
    property real openProgress: 0.0
}
