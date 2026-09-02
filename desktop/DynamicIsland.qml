import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import "../components"
import "../utilities/launcher"
import "../popups"
import qs.services

PanelWindow {
    id: root

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dynamic_island"
    // Only grab keyboard when launcher is open
    WlrLayershell.keyboardFocus: activeState === "launcher"
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // ── State Machine ──
    property string activeState: "default"

    property bool _mouseOnPill: pillMouseArea.containsMouse

    on_MouseOnPillChanged: {
        if (activeState === "default" && _mouseOnPill) {
            activeState = "hover";
        } else if (activeState === "hover" && !_mouseOnPill) {
            activeState = "default";
        }
    }

    // The notch pill — always visible at the top center
    Item {
        anchors.fill: parent

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            height: 32
            width: {
                if (root.activeState === "hover")
                    return Math.max(120, wsBar.implicitWidth + 24);
                if (root.activeState === "osd")
                    return 260;
                return Math.max(120, defaultRow.implicitWidth + 28);
            }
            radius: height / 2
            color: "#0a0a0a"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.InOutCubic } }

            // Default State
            Row {
                id: defaultRow
                anchors.centerIn: parent
                spacing: 10
                opacity: root.activeState === "default" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: "#ef4444"
                    visible: ScreenRecord.recording
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: ScreenRecord.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.primary
                    visible: Pomodoro.isRunning
                    anchors.verticalCenter: parent.verticalCenter
                }

                HorizontalClock { id: hClock }
                HorizontalBattery { id: hBattery }
                HorizontalVolume { id: hVolume }
            }

            // Hover State
            HorizontalWorkspaceBar {
                id: wsBar
                anchors.centerIn: parent
                opacity: root.activeState === "hover" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            // OSD State
            IslandOsd {
                id: osd
                anchors.fill: parent
                anchors.margins: 4
                opacity: root.activeState === "osd" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                onActiveChanged: {
                    if (active && (root.activeState === "default" || root.activeState === "hover")) {
                        root.activeState = "osd";
                    } else if (!active && root.activeState === "osd") {
                        root.activeState = "default";
                    }
                }
            }

            MouseArea {
                id: pillMouseArea
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onClicked: mouse => mouse.accepted = false
                onPressed: mouse => mouse.accepted = false
                onReleased: mouse => mouse.accepted = false
            }
        }

        NotifPopup {
            id: notifOverlay
            anchors.top: pill.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            z: 2
        }
    }

    // ── Launcher overlay ──
    // Full-screen transparent layer, no dimming.
    // Click outside the launcher card dismisses it.
    Item {
        id: launcherOverlay
        anchors.fill: parent
        visible: launcherComponent.menuOpen || launcherComponent.openProgress > 0
        z: 10

        // Transparent click-away area (no dimming)
        MouseArea {
            anchors.fill: parent
            onClicked: launcherComponent.closeMenu()
        }

        Launcher {
            id: launcherComponent
            anchors.fill: parent
        }
    }

    // Only handle Escape at window level when launcher is open
    Keys.onEscapePressed: {
        if (launcherComponent.menuOpen) {
            launcherComponent.closeMenu();
        }
    }

    Connections {
        target: LauncherState
        function onOpenChanged() {
            if (LauncherState.open) {
                root.activeState = "launcher";
            } else {
                root.activeState = "default";
            }
        }
    }
}
