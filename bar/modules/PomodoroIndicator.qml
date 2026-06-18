import QtQuick
import Quickshell
import qs.theme
import qs.services

Item {
    id: container
    
    // Show if running, or if time remaining is less than the max for current mode
    property bool shouldShow: Pomodoro.isRunning || 
        (Pomodoro.mode === 0 && Pomodoro.timeRemaining !== Pomodoro.workDuration) ||
        (Pomodoro.mode === 1 && Pomodoro.timeRemaining !== Pomodoro.shortBreakDuration) ||
        (Pomodoro.mode === 2 && Pomodoro.timeRemaining !== Pomodoro.longBreakDuration)
    
    width: shouldShow ? pill.width : 0
    height: 28
    visible: width > 0
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    clip: true

    Connections {
        target: Pomodoro
        function onTimeUp() {
            popAnim.start()
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: container; property: "scale"; to: 1.15; duration: 150; easing.type: Easing.OutBack }
        NumberAnimation { target: container; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutBounce }
    }

    Rectangle {
        id: pill
        width: row.width + 20
        height: 28
        radius: height / 2
        color: Pomodoro.isRunning ? Theme.primary : Theme.surface_container
        border.color: Theme.outline_variant
        border.width: Pomodoro.isRunning ? 0 : 1
        
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            
            Text {
                text: Pomodoro.mode === 0 ? "󰒲" : "󱎫"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                color: Pomodoro.isRunning ? Theme.on_primary : Theme.on_surface_variant
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Text {
                text: Pomodoro.formattedTime
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; weight: Font.Bold }
                color: Pomodoro.isRunning ? Theme.on_primary : Theme.on_surface_variant
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "sidebar", "toggle"] })
        }
    }
}
