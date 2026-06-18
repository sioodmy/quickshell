//@ pragma IconTheme Papirus

import Quickshell
import QtQuick
import "bar"
import "lock"
import "sidebar"
import "desktop"
import qs.utilities.clipboard

import qs.utilities.launcher
import qs.popups
import qs.services

/** Main shell entry point; manages surface orchestration. */
ShellRoot {
    id: root

    // Primary desktop bars
    LeftBar {
        id: leftBar
    }
    BottomBar {
        id: bottomBar
    }
    RightBar {
        id: rightBar
    }

    // Screen masking for rounded workspace effect
    BezelsMask {
        id: desktopBezels
    }

    // System status bar
    TopBar {
        id: topBar
    }

    // Session lock screen
    Lock {
        id: lockScreen
    }

    // Right-side control center sidebar
    Sidebar {
        id: controlCenterSidebar
    }

    // Floating notification overlay
    NotifPopup {
        id: notificationOverlay
    }

    // Clipboard
    Clipboard {
        id: clipboardWindow
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

    ScreenshotPopup {
        id: screenshotPopupWindow
    }

    // Live synced lyrics on desktop
    LyricsDesktop {
        id: lyricsDesktop
    }
}
