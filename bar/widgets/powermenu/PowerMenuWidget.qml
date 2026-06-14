import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.theme

PanelWindow {
    id: root

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "powermenu_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        width: 240
        height: contentColumn.implicitHeight + 24
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 60
        anchors.rightMargin: 15
        color: Theme.surface_container_low
        radius: 16

        border.color: Theme.outline_variant
        border.width: 1

        // Swallow clicks on the card so it doesn't dismiss
        MouseArea { anchors.fill: parent }

        Column {
            id: contentColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            // Custom component for the buttons
            component PowerButton: Rectangle {
                id: btn
                property string icon
                property string label
                property string command
                property color iconColor: Theme.primary
                
                width: parent.width
                height: 52
                radius: 26 // Full pill shape for M3
                color: btnMouse.containsMouse ? Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.15) : "transparent"
                
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    spacing: 16

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.icon
                        font {
                            family: "JetBrainsMono Nerd Font"
                            pixelSize: 20
                        }
                        color: btn.iconColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btn.label
                        font {
                            family: "Google Sans"
                            pixelSize: 16
                            weight: Font.Medium
                        }
                        color: "#ffffff" // explicitly keep text white
                    }
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached({ command: btn.command.split(" ") })
                        root.visible = false
                    }
                }
            }

            PowerButton {
                icon: ""
                label: "Lock"
                command: "quickshell ipc call lock lock"
                iconColor: Theme.secondary
            }
            PowerButton {
                icon: ""
                label: "Sleep"
                command: "systemctl suspend"
                iconColor: Theme.tertiary
            }
            PowerButton {
                icon: ""
                label: "Reboot"
                command: "reboot"
                iconColor: Theme.primary
            }
            PowerButton {
                icon: ""
                label: "Shutdown"
                command: "shutdown now"
                iconColor: Theme.critical
            }
        }
    }
}
