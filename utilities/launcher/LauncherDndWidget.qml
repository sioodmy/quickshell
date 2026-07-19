import QtQuick
import "../../theme"
import qs.services

Item {
    id: root

    property bool active: false

    readonly property color accent: Theme.tertiary
    readonly property color accentOn: Theme.on_tertiary

    implicitHeight: active ? 84 : 0
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
        border.color: DoNotDisturb.enabled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.35)
            : Theme.outline_variant
        border.width: 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Rectangle {
                width: 44
                height: 44
                radius: 22
                anchors.verticalCenter: parent.verticalCenter
                color: DoNotDisturb.enabled
                    ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
                    : Theme.surface_variant

                Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: DoNotDisturb.enabled ? "󰂛" : "󰂚"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                    color: DoNotDisturb.enabled ? accent : Theme.on_surface_variant

                    scale: 1.0
                    onTextChanged: iconPulse.restart()
                    SequentialAnimation {
                        id: iconPulse
                        NumberAnimation { target: parent; property: "scale"; to: 1.05; duration: 100; easing.type: Easing.OutCubic }
                        NumberAnimation { target: parent; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    }

                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 12 - dndSwitch.width - 12
                spacing: 2

                Text {
                    text: "Do Not Disturb"
                    font { family: "Google Sans Medium"; pixelSize: 15 }
                    color: Theme.on_surface
                }
                Text {
                    width: parent.width
                    text: DoNotDisturb.enabled
                        ? "Notification popups are silenced"
                        : "Notifications will appear as usual"
                    font { family: "Google Sans"; pixelSize: 11 }
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: dndSwitch
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 32
                radius: 16
                color: DoNotDisturb.enabled ? accent : Theme.surface_container_highest
                border.color: DoNotDisturb.enabled ? accent : Theme.outline
                border.width: 2

                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: DoNotDisturb.enabled ? 22 : 18
                    height: width
                    radius: width / 2
                    color: DoNotDisturb.enabled ? accentOn : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    x: DoNotDisturb.enabled ? parent.width - width - 5 : 5

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DoNotDisturb.toggle()
                }
            }
        }
    }
}
