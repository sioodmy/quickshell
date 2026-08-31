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

    // Screen masking for rounded workspace effect
    BezelsMask {
        id: desktopBezels
    }



    // Session lock screen
    Lock {
        id: lockScreen
    }

    // Floating notification overlay
    NotifPopup {
        id: notificationOverlay
    }

    // Polkit authentication popup
    PolkitPopup {
        id: polkitPopup
    }

    // Top-right Drag Queen dropzone
    FileStashPopup {
        id: fileStashOverlay
    }



    // Application Launcher
    Launcher {
        id: launcherWindow
    }

    VolumePopup {
        id: volumePopupWindow
    }

    BrightnessPopup {
        id: brightnessPopupWindow
    }

    SpeakerWarningPopup {
        id: speakerWarningPopupWindow
    }

    ChargePopup {
        id: chargePopupWindow
    }

    Loader {
        active: Screenshot.editorActive
        asynchronous: true
        sourceComponent: ScreenshotEditor { id: screenshotEditor }
    }

    Loader {
        active: Screenshot.overlayActive
        asynchronous: true
        sourceComponent: ScreenshotOverlay { id: screenshotOverlay }
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
