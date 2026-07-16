import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

PanelWindow {
    id: root
    implicitWidth: Screen.width
    implicitHeight: Screen.height
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    visible: Screenshot.overlayActive

    Rectangle {
        id: pill
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 70
        anchors.horizontalCenter: parent.horizontalCenter

        width: contentCol.implicitWidth + 48
        height: contentCol.implicitHeight + 36
        radius: 28
        color: Theme.surface_container_high

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#40000000"
            shadowVerticalOffset: 6
        }

        Column {
            id: contentCol
            anchors.centerIn: parent
            spacing: 14

            Row {
                id: contentRow
                anchors.horizontalCenter: parent.horizontalCenter
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

                Rectangle {
                    width: 2
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.surface_variant
                    radius: 1
                }

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

            Rectangle {
                width: contentRow.width
                height: 1
                color: Theme.surface_variant
                opacity: 0.6
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                component RecBtn: Rectangle {
                    property string icon
                    property string label
                    property bool danger: false
                    signal clicked()

                    width: recLabel.implicitWidth + recIcon.implicitWidth + 40
                    height: 48
                    radius: 24
                    color: {
                        if (danger)
                            return recM.containsMouse ? Theme.critical
                                : Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.16);
                        return recM.containsMouse ? Theme.secondary_container : "transparent";
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            id: recIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.icon
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            color: {
                                if (parent.parent.danger)
                                    return recM.containsMouse ? Theme.on_critical : Theme.critical;
                                return recM.containsMouse ? Theme.on_secondary_container : Theme.on_surface;
                            }
                        }
                        Text {
                            id: recLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.label
                            font.family: "Google Sans Medium"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: {
                                if (parent.parent.danger)
                                    return recM.containsMouse ? Theme.on_critical : Theme.critical;
                                return recM.containsMouse ? Theme.on_secondary_container : Theme.on_surface;
                            }
                        }
                    }

                    MouseArea {
                        id: recM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.clicked()
                    }
                }

                RecBtn {
                    visible: !ScreenRecord.recording
                    icon: "󰕧"
                    label: "Record Full"
                    onClicked: ScreenRecord.startFullscreen()
                }
                RecBtn {
                    visible: !ScreenRecord.recording
                    icon: "󰆞"
                    label: "Record Area"
                    onClicked: ScreenRecord.startArea()
                }
                RecBtn {
                    visible: ScreenRecord.recording
                    icon: "󰓛"
                    label: "Stop · " + ScreenRecord.elapsedText
                    danger: true
                    onClicked: ScreenRecord.stop()
                }

                Rectangle {
                    width: audioRow.implicitWidth + 24
                    height: 48
                    radius: 24
                    visible: !ScreenRecord.recording
                    color: ScreenRecord.recordAudio
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                        : (audioM.containsMouse ? Theme.surface_variant : "transparent")
                    border.color: ScreenRecord.recordAudio ? Theme.primary : "transparent"
                    border.width: ScreenRecord.recordAudio ? 1.5 : 0

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: audioRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ScreenRecord.recordAudio ? "󰄲" : "󰄱"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: ScreenRecord.recordAudio ? Theme.primary : Theme.on_surface_variant
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Audio"
                            font.family: "Google Sans Medium"
                            font.pixelSize: 13
                            color: ScreenRecord.recordAudio ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    MouseArea {
                        id: audioM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRecord.toggleAudio()
                    }
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
