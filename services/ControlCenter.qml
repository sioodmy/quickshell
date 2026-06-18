pragma Singleton

import Quickshell

/** Global open/close state for the right-side control center sidebar. */
Singleton {
    id: root

    property bool open: false

    function toggle() {
        open = !open;
    }

    function show() {
        open = true;
    }

    function hide() {
        open = false;
    }
}
