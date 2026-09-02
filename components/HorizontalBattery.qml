import QtQuick
import Quickshell.Services.UPower
import qs.theme

Item {
    id: root

    implicitWidth: layout.implicitWidth + 16
    implicitHeight: 32

    // Internal logic
    readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
    readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
    readonly property bool isCharging: !UPower.onBattery

    visible: isVisible

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Item {
            id: batteryIconItem
            width: 20
            height: 10
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: batteryBody
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                    rightMargin: 2
                }
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: {
                    if (root.capacity <= 10 && !root.isCharging)
                        return Theme.critical;
                    if (root.capacity <= 20 && !root.isCharging)
                        return "#ea999c";
                    if (root.isCharging)
                        return "#259b50";
                    return Theme.on_surface_variant;
                }
                Behavior on border.color { ColorAnimation { duration: 250 } }

                Rectangle {
                    id: batteryFill
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                        margins: 2
                    }
                    radius: 1
                    width: Math.max(0, (parent.width - 4) * (root.capacity / 100))
                    color: parent.border.color
                    opacity: 1.0

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                MaterialIcon {
                    visible: root.isCharging
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    icon: "bolt"
                    font.pixelSize: 8
                    color: Theme.on_surface
                }
            }

            // Battery nub (terminal)
            Rectangle {
                id: batteryNub
                width: 2
                height: 4
                anchors {
                    left: batteryBody.right
                    verticalCenter: parent.verticalCenter
                }
                radius: 1
                color: batteryBody.border.color
            }
        }
        
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.capacity) + "%"
            color: Theme.on_surface_variant
            font {
                family: "Google Sans"
                pixelSize: 13
                weight: Font.Medium
            }
        }
    }
}
