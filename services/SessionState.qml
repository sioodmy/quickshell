pragma Singleton

import Quickshell

/** Global session state (lock state, idle status) for power & resource management. */
Singleton {
    id: root

    property bool locked: false
}
