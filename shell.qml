//@ pragma IconTheme Papirus

import Quickshell
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

    ChargePopup {
        id: chargePopupWindow
    }

    ScreenshotEditor {
        id: screenshotEditor
    }

    ScreenshotOverlay {
        id: screenshotOverlay
    }

    // Live synced lyrics on desktop (wallpaper)
    LyricsDesktop {
        id: lyricsDesktop
    }

    // Fullscreen media overlay
    FullscreenMedia {
        id: fullscreenMedia
    }
}
