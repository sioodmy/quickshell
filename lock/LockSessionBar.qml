import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../theme"
import qs.components

Rectangle {
    id: root

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28
    width: bottomChrome.implicitWidth + 28
    height: 52
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.26)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.4)

    BubbleSheen {}

    Row {
        id: bottomChrome
        anchors.centerIn: parent
        spacing: 10
        z: 1

        Rectangle {
            id: battPill
            height: 36
            width: battRow.implicitWidth + 20
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.32)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.4)
            visible: UPower.displayDevice?.isPresent ?? false
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            BubbleSheen {}

            Row {
                id: battRow
                anchors.centerIn: parent
                spacing: 8
                z: 1

                readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
                readonly property bool charging: !UPower.onBattery

                Item {
                    width: 26
                    height: 13
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
                            return Qt.rgba(1, 1, 1, 0.75);
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
                    color: Qt.rgba(1, 1, 1, 0.92)
                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                }
            }
        }

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            component SessionBtn: Rectangle {
                property string icon
                property color accent: Qt.rgba(1, 1, 1, 0.88)
                signal triggered

                width: 36
                height: 36
                radius: width / 2
                scale: btnArea.pressed ? 0.92 : (btnArea.containsMouse ? 1.06 : 1.0)
                color: {
                    if (btnArea.pressed)
                        return Qt.rgba(1, 1, 1, 0.48);
                    if (btnArea.containsMouse)
                        return Qt.rgba(1, 1, 1, 0.38);
                    return Qt.rgba(1, 1, 1, 0.28);
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.4)
                clip: true

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 120 } }

                BubbleSheen {}

                MaterialIcon {
                    anchors.centerIn: parent
                    z: 1
                    icon: parent.icon
                    font.pixelSize: 15
                    color: parent.accent
                    opacity: btnArea.containsMouse ? 1 : 0.92
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
