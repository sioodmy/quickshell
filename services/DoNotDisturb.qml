pragma Singleton

import Quickshell

/** Global Do Not Disturb state – suppresses notification popups while still
    saving them to history. */
Singleton {
    id: root

    property bool enabled: false

    function enable() {
        enabled = true;
    }

    function disable() {
        enabled = false;
    }

    function toggle() {
        enabled = !enabled;
    }
}
