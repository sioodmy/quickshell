import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: indicator

        required property var modelData
        screen: modelData

        implicitWidth: 220
        implicitHeight: 56
        color: "transparent"
        visible: ScreenRecord.recording

        anchors {
            bottom: true
            left: true
        }

        margins {
            bottom: 24
            left: 24
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "recording_indicator"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: contentRow.implicitWidth + 28
            height: 48
            radius: 24
            color: Theme.surface_container_high

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.9
                shadowColor: "#50000000"
                shadowVerticalOffset: 4
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.critical

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: ScreenRecord.recording
                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Recording"
                        font { family: "Google Sans Medium"; pixelSize: 12 }
                        color: Theme.on_surface
                    }
                    Text {
                        text: ScreenRecord.elapsedText + (ScreenRecord.recordAudio ? " · 󰍬" : " · 󰍭")
                        font { family: "Google Sans"; pixelSize: 11 }
                        color: Theme.on_surface_variant
                    }
                }

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: stopMouse.containsMouse ? Theme.critical : Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.18)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰓛"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                        color: stopMouse.containsMouse ? Theme.on_critical : Theme.critical
                    }

                    MouseArea {
                        id: stopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRecord.stop()
                    }
                }
            }
        }
    }
}
