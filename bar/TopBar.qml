import Quickshell
import Quickshell.Wayland

import QtQuick
import "modules"
import qs.theme
import qs.services

Variants {
    id: root
    model: Quickshell.screens
    delegate: PanelWindow {
        id: mainBar
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-topbar"

        // --- Geometry & Positioning ---
        anchors {
            top: true
            left: true
            right: true
        }
        color: "transparent"
        implicitHeight: Layout.topBarHeight

        // --- Core Modules ---
        Row {
            anchors {
                left: parent.left
                leftMargin: 15
                verticalCenter: parent.verticalCenter
            }
            spacing: 12

            Rectangle {
                width: 28
                height: 28
                color: Theme.surface_container
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: " "
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pixelSize: 14
                    }
                    color: Theme.on_surface
                }

                TapHandler {
                    onTapped: Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "appLauncher", "toggle"] })
                    cursorShape: Qt.PointingHandCursor
                }

                HoverHandler {
                    id: searchHover
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.on_surface
                    opacity: searchHover.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            Workspaces {
                id: workspaceModule
                targetMonitor: modelData.name
            }
        }
        Calendar {
            id: calendarModule
            anchors.centerIn: parent
        }
        Weather {
            id: weatherModule
            anchors {
                right: statusModule.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
        }
        SystemStats {
            id: statusModule
            anchors {
                right: parent.right
                rightMargin: 15
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
