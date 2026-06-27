import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

PanelWindow {
    id: root
    width: Screen.width
    height: Screen.height
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "screenshot"
    WlrLayershell.keyboardFocus: KeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    visible: Screenshot.overlayActive

    Rectangle {
        id: pill
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 70
        anchors.horizontalCenter: parent.horizontalCenter
        
        width: contentRow.implicitWidth + 48
        height: 84
        radius: 28
        color: Theme.surface_container_high

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#40000000"
            shadowVerticalOffset: 6
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 16

            component MenuBtn: Rectangle {
                property string icon
                property string label
                signal clicked()

                width: labelText.implicitWidth + iconText.implicitWidth + 48
                height: 56
                radius: 28
                color: m.containsMouse ? Theme.primary_container : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }

                Item {
                    width: iconText.implicitWidth + 12 + labelText.implicitWidth
                    height: Math.max(iconText.implicitHeight, labelText.implicitHeight)
                    anchors.centerIn: parent

                    Text {
                        id: iconText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: m.containsMouse ? Theme.on_primary_container : Theme.on_surface
                    }
                    Text {
                        id: labelText
                        anchors.left: iconText.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.parent.label
                        font.family: "Google Sans Medium"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: m.containsMouse ? Theme.on_primary_container : Theme.on_surface
                    }
                }

                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                }
            }

            MenuBtn {
                icon: "󰊓"
                label: "Fullscreen"
                onClicked: Screenshot.finishFullscreen()
            }
            MenuBtn {
                icon: "󰆞"
                label: "Area"
                onClicked: Screenshot.finishArea()
            }
            MenuBtn {
                icon: "󰖯"
                label: "Window"
                onClicked: Screenshot.finishWindow()
            }
            
            // Separator
            Rectangle {
                width: 2
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surface_variant
                radius: 1
            }

            // Close button
            Rectangle {
                width: 56
                height: 56
                radius: 28
                color: closeM.containsMouse ? Theme.surface_variant : "transparent"
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    color: Theme.on_surface_variant
                }
                MouseArea {
                    id: closeM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Screenshot.overlayActive = false
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Screenshot.overlayActive = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Screenshot.overlayActive = false
        z: -1
    }
}
