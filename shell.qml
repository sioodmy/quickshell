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

    // Application dock (vertical, left side)
    Dock {
        id: applicationDock
    }



    // Session lock screen
    Lock {
        id: lockScreen
    }

    // Floating notification overlay (Disabled, now inside dock)
    // NotifPopup {
    //     id: notificationOverlay
    // }

    // Polkit authentication popup (Disabled, now inside dock)
    // PolkitPopup {
    //     id: polkitPopup
    // }



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

    // Loader {
    //     active: Screenshot.overlayActive
    //     asynchronous: true
    //     sourceComponent: ScreenshotOverlay { id: screenshotOverlay }
    // }

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
