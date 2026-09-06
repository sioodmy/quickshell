import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../theme"
import qs.components

Rectangle {
    id: root

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -22
    width: bottomChrome.implicitWidth + 32
    height: bottomChrome.implicitHeight + 24 + 22
    radius: 22
    color: Theme.surface

    Row {
        id: bottomChrome
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -11
        spacing: 12

        // Battery
        Rectangle {
            id: battPill
            height: 40
            width: battRow.implicitWidth + 28
            radius: 14
            color: "transparent"
            visible: UPower.displayDevice?.isPresent ?? false
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: battRow
                anchors.centerIn: parent
                spacing: 8

                readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
                readonly property bool charging: !UPower.onBattery

                Item {
                    width: 28
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: battBody
                        anchors {
                            left: parent.left; top: parent.top; bottom: parent.bottom
                            right: parent.right; rightMargin: 3
                        }
                        radius: 3
                        color: "transparent"
                        border.width: 1.5
                        border.color: {
                            if (battRow.capacity <= 20 && !battRow.charging)
                                return Theme.critical;
                            if (battRow.charging)
                                return "#7ee787";
                            return Theme.on_surface;
                        }
                    }
                    Rectangle {
                        width: 2.5; height: 5
                        anchors { left: battBody.right; verticalCenter: parent.verticalCenter }
                        radius: 1
                        color: battBody.border.color
                    }
                    Rectangle {
                        anchors {
                            left: battBody.left; top: battBody.top; bottom: battBody.bottom
                            margins: 2.5
                        }
                        radius: 1
                        width: Math.max(0, (battBody.width - 5) * (battRow.capacity / 100))
                        color: battBody.border.color
                        opacity: 0.85
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(battRow.capacity) + "%"
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                }
            }
        }

        // Session controls
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            component SessionBtn: Rectangle {
                property string icon
                property color accent: Theme.on_surface
                signal triggered

                width: 40
                height: 40
                radius: 14
                scale: btnArea.pressed ? 0.92 : (btnArea.containsMouse ? 1.04 : 1.0)
                color: {
                    if (btnArea.pressed)
                        return Theme.surface_container_high;
                    if (btnArea.containsMouse)
                        return Theme.surface_container;
                    return "transparent";
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: parent.icon
                    font.pixelSize: 16
                    color: parent.accent
                    opacity: btnArea.containsMouse ? 1 : 0.85
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.triggered()
                }
            }

            SessionBtn {
                icon: "bedtime"
                onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
            }
            SessionBtn {
                icon: "restart_alt"
                onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
            }
            SessionBtn {
                icon: "power_settings_new"
                accent: Theme.critical
                onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }
}
