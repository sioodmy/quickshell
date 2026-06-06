pragma Singleton

import Quickshell
import QtQml

Singleton {
    // Niri does not expose fullscreen state through qml-niri.
    // This stub always returns false so bars remain visible.
    function isFullscreen(monitor) {
        return false;
    }
}
