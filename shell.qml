//@ pragma IconTheme Papirus

import Quickshell
import Quickshell.Io
import QtQuick
import "dock"
import "lock"
import "desktop"

import qs.utilities.launcher
import qs.popups
import qs.services

/** Main shell entry point; manages surface orchestration. */
ShellRoot {
    id: root

    // Application dock & top notch (Dynamic Island)
    Dock {
        id: applicationDock
    }

    // Session lock screen
    Lock {
        id: lockScreen
    }

    // Application Launcher
    Launcher {
        id: launcherWindow
    }

    SpeakerWarningPopup {
        id: speakerWarningPopupWindow
    }

    Loader {
        active: Screenshot.editorActive
        asynchronous: true
        sourceComponent: ScreenshotEditor { id: screenshotEditor }
    }

    // Live synced lyrics on desktop (wallpaper)
    Loader {
        active: Lyrics.parsedLyrics.length > 0
        asynchronous: true
        sourceComponent: LyricsDesktop { id: lyricsDesktop }
    }

    // Fullscreen media overlay
    Loader {
        active: Lyrics.showFullscreen
        asynchronous: true
        sourceComponent: FullscreenMedia { id: fullscreenMedia }
    }

    // RSVP speed reader overlay
    Loader {
        active: RsvpReader.active
        asynchronous: true
        sourceComponent: RsvpOverlay { id: rsvpOverlay }
    }

    IpcHandler {
        target: "cocaine"
        function enable() {
            BackendDaemon.send({ action: "cocaine_enable" });
        }
        function disable() {
            BackendDaemon.send({ action: "cocaine_disable" });
        }
        function toggle() {
            BackendDaemon.send({ action: "cocaine_enable" });
        }
    }
}
