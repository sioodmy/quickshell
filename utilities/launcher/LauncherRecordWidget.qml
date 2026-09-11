import QtQuick
import "../../theme"
import qs.services
import qs.components

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
        color: Theme.glass_panel
        border.width: 1
        border.color: Theme.glass_border
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
                        ? Qt.alpha(Theme.critical, 0.22)
                        : Theme.glass_raised

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: ScreenRecord.recording ? "videocam" : "videocam_off"
                        font.pixelSize: 16
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
                        ? Qt.alpha(Theme.primary, 0.22)
                        : Theme.glass_hover
                    border.color: ScreenRecord.recordAudio ? Theme.primary : Theme.glass_border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: audioRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: ScreenRecord.recordAudio ? "check_box" : "check_box_outline_blank"
                            font.pixelSize: 14
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
                        ? [{ id: "stop", icon: "stop", label: "Stop" }]
                        : [
                            { id: "fullscreen", icon: "fullscreen", label: "Full screen" },
                            { id: "area", icon: "crop", label: "Area" }
                        ]

                    delegate: Rectangle {
                        width: ScreenRecord.recording
                            ? parent.width
                            : (parent.width - 8) / 2
                        height: 56
                        radius: 14
                        color: {
                            if (modelData.id === "stop")
                                return stopMouse.containsMouse ? Qt.alpha(Theme.critical, 0.8)
                                    : Qt.alpha(Theme.critical, 0.18);
                            return btnMouse.containsMouse
                                ? Theme.glass_accent_soft
                                : Theme.glass_hover;
                        }
                        border.width: 1
                        border.color: Theme.glass_border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        scale: (modelData.id === "stop" ? stopMouse.pressed : btnMouse.pressed) ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: modelData.icon
                                font.pixelSize: 18
                                color: {
                                    if (modelData.id === "stop")
                                        return stopMouse.containsMouse ? Theme.on_critical : Theme.critical;
                                    return btnMouse.containsMouse ? Theme.primary : Theme.on_surface;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.DemiBold }
                                color: {
                                    if (modelData.id === "stop")
                                        return stopMouse.containsMouse ? Theme.on_critical : Theme.critical;
                                    return btnMouse.containsMouse ? Theme.primary : Theme.on_surface;
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
