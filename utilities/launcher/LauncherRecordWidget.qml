import QtQuick
import "../../theme"
import qs.services

Item {
    id: root

    property bool active: false
    signal action(string id)

    implicitHeight: active ? 168 : 0
    opacity: active ? 1 : 0
    visible: opacity > 0.02
    clip: true

    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        radius: 20
        color: Theme.surface_container_high
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: ScreenRecord.recording
                        ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
                        : Theme.surface_variant

                    Text {
                        anchors.centerIn: parent
                        text: ScreenRecord.recording ? "󰻃" : "󰕧"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: ScreenRecord.recording ? Theme.critical : Theme.on_surface_variant
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - 10 - audioChip.width - 10
                    spacing: 1

                    Text {
                        text: ScreenRecord.recording ? "Recording…" : "Screen Record"
                        font { family: "Google Sans Medium"; pixelSize: 14 }
                        color: Theme.on_surface
                    }
                    Text {
                        width: parent.width
                        text: ScreenRecord.recording
                            ? (ScreenRecord.elapsedText + " · " + ScreenRecord.fileName)
                            : "Record full screen or a region"
                        font { family: "Google Sans"; pixelSize: 11 }
                        color: Theme.on_surface_variant
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    id: audioChip
                    anchors.verticalCenter: parent.verticalCenter
                    width: audioRow.implicitWidth + 20
                    height: 32
                    radius: 16
                    color: ScreenRecord.recordAudio
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                        : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                    border.color: ScreenRecord.recordAudio ? Theme.primary : "transparent"
                    border.width: ScreenRecord.recordAudio ? 1 : 0

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: audioRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ScreenRecord.recordAudio ? "󰄲" : "󰄱"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                            color: ScreenRecord.recordAudio ? Theme.primary : Theme.on_surface_variant
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Audio"
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                            color: ScreenRecord.recordAudio ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRecord.toggleAudio()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: ScreenRecord.recording
                        ? [{ id: "stop", icon: "󰓛", label: "Stop" }]
                        : [
                            { id: "fullscreen", icon: "󰊓", label: "Full screen" },
                            { id: "area", icon: "󰆞", label: "Area" }
                        ]

                    delegate: Rectangle {
                        width: ScreenRecord.recording
                            ? parent.width
                            : (parent.width - 8) / 2
                        height: 56
                        radius: 14
                        color: {
                            if (modelData.id === "stop")
                                return stopMouse.containsMouse ? Theme.critical
                                    : Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.18);
                            return btnMouse.containsMouse
                                ? Theme.primary_container
                                : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06);
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                        scale: (modelData.id === "stop" ? stopMouse.pressed : btnMouse.pressed) ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                                color: {
                                    if (modelData.id === "stop")
                                        return stopMouse.containsMouse ? Theme.on_critical : Theme.critical;
                                    return btnMouse.containsMouse ? Theme.on_primary_container : Theme.on_surface;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.DemiBold }
                                color: {
                                    if (modelData.id === "stop")
                                        return stopMouse.containsMouse ? Theme.on_critical : Theme.critical;
                                    return btnMouse.containsMouse ? Theme.on_primary_container : Theme.on_surface;
                                }
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            visible: modelData.id !== "stop"
                            onClicked: root.action(modelData.id)
                        }

                        MouseArea {
                            id: stopMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            visible: modelData.id === "stop"
                            onClicked: root.action("stop")
                        }
                    }
                }
            }
        }
    }
}
