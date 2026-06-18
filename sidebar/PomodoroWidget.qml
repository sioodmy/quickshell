import QtQuick
import QtQuick.Effects
import Quickshell
import qs.theme
import qs.services

Rectangle {
    id: root
    radius: 24
    color: Theme.surface_container
    
    border.color: Theme.outline_variant
    border.width: 1

    Item {
        anchors.fill: parent
        anchors.margins: 16

        // Top Header
        Text {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: Pomodoro.mode === 0 ? "Focus Session" : (Pomodoro.mode === 1 ? "Short Break" : "Long Break")
            color: Pomodoro.isRunning ? Theme.primary : Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 14; weight: Font.Bold }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Center Time & Plus/Minus
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Pomodoro.formattedTime
                color: Theme.on_surface
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 42; weight: Font.Bold }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: minusMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "-"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                        color: Theme.on_surface_variant
                    }
                    MouseArea {
                        id: minusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pomodoro.adjustTime(-1)
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: plusMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                        color: Theme.on_surface_variant
                    }
                    MouseArea {
                        id: plusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pomodoro.adjustTime(1)
                    }
                }
            }
        }

        // Bottom Controls
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // Mode Selector
            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: modeMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                border.width: 1
                border.color: Theme.outline_variant
                
                Text {
                    anchors.centerIn: parent
                    text: Pomodoro.mode === 0 ? "󰒲" : "󱎫" // Toggle icon
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                    color: Theme.on_surface_variant
                }
                
                MouseArea {
                    id: modeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.setMode((Pomodoro.mode + 1) % 3)
                }
            }

            // Play/Pause
            Rectangle {
                width: 48
                height: 48
                radius: 24
                anchors.verticalCenter: parent.verticalCenter
                color: Pomodoro.isRunning ? Theme.secondary_container : Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: Pomodoro.isRunning ? "󰏤" : "󰐊"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                    color: Pomodoro.isRunning ? Theme.on_secondary_container : Theme.on_primary
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.toggle()
                }

                scale: playMouse.pressed ? 0.9 : (playMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Reset
            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: resetMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                border.width: 1
                border.color: Theme.outline_variant

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                    color: Theme.on_surface_variant
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pomodoro.reset()
                }
            }
        }
    }
}
