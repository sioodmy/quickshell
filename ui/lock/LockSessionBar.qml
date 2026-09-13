import QtQuick
import Quickshell
import Quickshell.Services.UPower

import qs.theme
import qs.components

/**
 * Persistent utility row inside the morphing lock shell.
 * It remains readable at dock size, then settles at the bottom of the
 * expanded authentication panel.
 */
Item {
    id: root

    property real presentationProgress: 1

    implicitHeight: 44
    implicitWidth: utilityRow.implicitWidth

    Row {
        id: utilityRow
        anchors.centerIn: parent
        spacing: 9

        Rectangle {
            id: batteryPill

            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool charging: !UPower.onBattery

            visible: UPower.displayDevice?.isPresent ?? false
            width: visible ? 72 : 0
            height: 34
            radius: height / 2
            color: Theme.bubble
            border.width: 1
            border.color: Theme.bubble_border_soft
            clip: true

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            BubbleSheen {}

            Row {
                anchors.centerIn: parent
                spacing: 7
                z: 1

                Item {
                    width: 23
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: batteryBody
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            right: parent.right
                            rightMargin: 3
                        }
                        radius: 3
                        color: "transparent"
                        border.width: 1.3
                        border.color: {
                            if (batteryPill.capacity <= 20 && !batteryPill.charging)
                                return Theme.critical;
                            if (batteryPill.charging)
                                return "#88efad";
                            return Qt.rgba(1, 1, 1, 0.82);
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 5
                        radius: 1
                        anchors.left: batteryBody.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: batteryBody.border.color
                    }

                    Rectangle {
                        anchors {
                            left: batteryBody.left
                            top: batteryBody.top
                            bottom: batteryBody.bottom
                            margins: 2.5
                        }
                        width: Math.max(0, (batteryBody.width - 5) * batteryPill.capacity / 100)
                        radius: 1
                        color: batteryBody.border.color

                        Behavior on width {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(batteryPill.capacity) + "%"
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font {
                        family: "Google Sans"
                        pixelSize: 11
                        weight: Font.Medium
                    }
                }
            }
        }

        Row {
            spacing: 7
            anchors.verticalCenter: parent.verticalCenter

            component SessionButton: Rectangle {
                id: button

                required property string icon
                property string variant: "neutral"
                signal triggered

                width: 34
                height: 34
                radius: width / 2
                color: {
                    if (variant === "critical")
                        return mouse.containsMouse ? Theme.bubble_critical : Theme.bubble_critical_soft;
                    return mouse.containsMouse ? Theme.bubble_hover : Theme.bubble;
                }
                border.width: 1
                border.color: variant === "critical"
                    ? Qt.alpha(Theme.critical, 0.45)
                    : Theme.bubble_border
                scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.05 : 1)
                clip: true

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }

                BubbleSheen {}

                MaterialIcon {
                    anchors.centerIn: parent
                    z: 1
                    icon: button.icon
                    fill: 0
                    grade: -25
                    weight: 300
                    font.pixelSize: 15
                    color: button.variant === "critical"
                        ? Theme.critical
                        : Qt.rgba(1, 1, 1, 0.9)
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: button.triggered()
                }
            }

            SessionButton {
                icon: "bedtime"
                onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
            }

            SessionButton {
                icon: "restart_alt"
                onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
            }

            SessionButton {
                icon: "power_settings_new"
                variant: "critical"
                onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }
}
