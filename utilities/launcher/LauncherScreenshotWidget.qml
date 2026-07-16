import QtQuick
import "../../theme"
import qs.services

Item {
    id: root

    property bool active: false
    signal action(string id)

    implicitHeight: active ? 148 : 0
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

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰹑"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                    color: Theme.primary
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "Screenshot"
                        font { family: "Google Sans Medium"; pixelSize: 14 }
                        color: Theme.on_surface
                    }
                    Text {
                        text: "Capture screen, area, or window"
                        font { family: "Google Sans"; pixelSize: 11 }
                        color: Theme.on_surface_variant
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        { id: "fullscreen", icon: "󰊓", label: "Full" },
                        { id: "area", icon: "󰆞", label: "Area" },
                        { id: "window", icon: "󰖯", label: "Window" },
                        { id: "menu", icon: "󰍜", label: "Menu" }
                    ]

                    delegate: Rectangle {
                        width: (parent.width - 24) / 4
                        height: 64
                        radius: 14
                        color: btnMouse.containsMouse
                            ? Theme.primary_container
                            : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        scale: btnMouse.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                                color: btnMouse.containsMouse ? Theme.on_primary_container : Theme.on_surface
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                color: btnMouse.containsMouse ? Theme.on_primary_container : Theme.on_surface_variant
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
