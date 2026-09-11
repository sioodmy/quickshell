import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme
import qs.components

Rectangle {
    id: root

    property bool osdActive: false
    property int osdSeq: 0

    implicitWidth: layout.implicitWidth + 8
    implicitHeight: 22
    radius: height / 2
    color: "transparent"

    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property bool isMuted: activeSink?.audio?.muted ?? true
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0
    readonly property string volumeIcon: {
        if (root.isMuted)
            return "volume_off";
        if (root.volumeLevel > 0.5)
            return "volume_up";
        if (root.volumeLevel > 0)
            return "volume_down";
        return "volume_mute";
    }

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // Fixed slot so scale pops never shift battery / dock width.
        Item {
            id: audioSlot
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            MaterialIcon {
                id: audioIcon
                anchors.centerIn: parent
                icon: root.volumeIcon
                fill: 0
                font.pixelSize: 16
                opticalSize: 20
                color: "#ffffff"
                transformOrigin: Item.Center
            }
        }

        Item {
            id: batteryIconItem
            width: 22
            height: 12
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            Rectangle {
                id: batteryNub
                width: 2
                height: 5
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                radius: 1
                color: batteryBody.border.color
            }

            Rectangle {
                id: batteryBody
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    right: batteryNub.left
                    rightMargin: 1
                }
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: {
                    if (batteryIconItem.capacity <= 10 && !batteryIconItem.isCharging)
                        return Theme.critical;
                    if (batteryIconItem.capacity <= 20 && !batteryIconItem.isCharging)
                        return "#ea999c";
                    if (batteryIconItem.isCharging)
                        return "#259b50";
                    return "#ffffff";
                }
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }

            Rectangle {
                id: batteryFill
                anchors {
                    left: batteryBody.left
                    top: batteryBody.top
                    bottom: batteryBody.bottom
                    margins: 2
                }
                radius: 1.5
                width: Math.max(0, (batteryBody.width - 4) * (batteryIconItem.capacity / 100))
                color: batteryBody.border.color
                opacity: 0.4

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }

            Text {
                visible: !batteryIconItem.isCharging
                anchors.centerIn: batteryBody
                text: Math.round(batteryIconItem.capacity)
                font.family: "Google Sans"
                font.pixelSize: 7
                font.bold: true
                color: "#ffffff"
            }

            MaterialIcon {
                visible: batteryIconItem.isCharging
                anchors.centerIn: batteryBody
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                icon: "bolt"
                font.pixelSize: 8
                color: "#ffffff"
            }
        }
    }

    SequentialAnimation {
        id: iconPop
        NumberAnimation { target: audioIcon; property: "scale"; to: 0.6; duration: 50; easing.type: Easing.InCubic }
        NumberAnimation { target: audioIcon; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
    }

    onOsdActiveChanged: {
        if (root.osdActive)
            iconPop.restart();
        else {
            iconPop.stop();
            audioIcon.scale = 1;
        }
    }

    onOsdSeqChanged: {
        if (root.osdActive)
            iconPop.restart();
    }
}
