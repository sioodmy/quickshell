import QtQuick
import Quickshell.Networking
import qs.theme

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 8

    property bool expanded: false

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }

    readonly property var activeNetwork: {
        if (!wifiDevice)
            return null;
        for (const n of wifiDevice.networks.values) {
            if (n.connected)
                return n;
        }
        return null;
    }

    readonly property var sortedNetworks: {
        if (!wifiDevice)
            return [];
        return [...wifiDevice.networks.values].sort((a, b) => {
            if (a.connected !== b.connected)
                return b.connected - a.connected;
            if (a.known !== b.known)
                return b.known - a.known;
            return b.signalStrength - a.signalStrength;
        });
    }

    onExpandedChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = expanded;
    }

    // --- Tile header ---
    Rectangle {
        width: parent.width
        height: 64
        radius: 22
        color: Networking.wifiEnabled
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            : Theme.surface_container_high

        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            width: 40
            height: 40
            radius: 20
            color: Networking.wifiEnabled ? Theme.primary : Theme.surface_container_highest

            Text {
                anchors.centerIn: parent
                text: !Networking.wifiEnabled ? "󰤭" : (root.activeNetwork ? "󰤨" : "󰤯")
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                color: Networking.wifiEnabled ? Theme.on_primary : Theme.on_surface_variant
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.right: toggleWifi.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "Wi-Fi"
                color: Theme.on_surface
                font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: !Networking.wifiEnabled ? "Off" : (root.activeNetwork ? root.activeNetwork.name : "Not connected")
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 12 }
                elide: Text.ElideRight
            }
        }

        Toggle {
            id: toggleWifi
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            checked: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: toggleWifi.left
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // --- Network list ---
    Column {
        width: parent.width
        spacing: 4
        visible: root.expanded && Networking.wifiEnabled

        Text {
            visible: root.sortedNetworks.length === 0
            text: "Searching for networks…"
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 13 }
            leftPadding: 8
            topPadding: 6
            bottomPadding: 6
        }

        Repeater {
            model: root.sortedNetworks

            Rectangle {
                id: netItem
                required property var modelData
                property bool open: false
                property bool showPsk: false
                property string failText: ""

                width: parent.width
                radius: 16
                color: modelData.connected
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                    : (rowMouse.containsMouse || netItem.open
                        ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                        : "transparent")
                height: col.height

                Behavior on color { ColorAnimation { duration: 150 } }

                Connections {
                    target: netItem.modelData
                    function onConnectionFailed(reason) {
                        netItem.failText = "Connection failed";
                        netItem.showPsk = true;
                        netItem.open = true;
                    }
                    function onStateChanged() {
                        if (netItem.modelData.connected) {
                            netItem.showPsk = false;
                            netItem.failText = "";
                            netItem.open = false;
                        }
                    }
                }

                Column {
                    id: col
                    width: parent.width
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 44

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netItem.open = !netItem.open
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const s = netItem.modelData.signalStrength;
                                if (s >= 0.75) return "󰤨";
                                if (s >= 0.5) return "󰤥";
                                if (s >= 0.25) return "󰤢";
                                return "󰤟";
                            }
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                            color: netItem.modelData.connected ? Theme.primary : Theme.on_surface_variant
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 38
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                width: parent.width
                                text: netItem.modelData.name
                                color: Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: netItem.modelData.connected || netItem.modelData.known
                                text: netItem.modelData.connected ? "Connected" : "Saved"
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: netItem.open
                        spacing: 8
                        bottomPadding: 10
                        leftPadding: 10
                        rightPadding: 10

                        Text {
                            visible: netItem.failText.length > 0
                            text: netItem.failText
                            color: Theme.critical
                            font { family: "Google Sans"; pixelSize: 12 }
                        }

                        Rectangle {
                            visible: netItem.showPsk
                            width: parent.width - 20
                            height: 38
                            radius: 10
                            color: Theme.surface_container_high
                            border.color: pskInput.activeFocus ? Theme.primary : Theme.outline_variant
                            border.width: 1

                            TextInput {
                                id: pskInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13 }
                                echoMode: TextInput.Password
                                clip: true
                                onAccepted: {
                                    netItem.modelData.connectWithPsk(text);
                                    text = "";
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: pskInput.text.length === 0
                                    text: "Password"
                                    color: Theme.on_surface_variant
                                    font: pskInput.font
                                }
                            }
                        }

                        Row {
                            spacing: 8

                            component ActBtn: Rectangle {
                                id: ab
                                property string label
                                property color accent: Theme.primary
                                signal triggered()
                                width: abt.implicitWidth + 24
                                height: 30
                                radius: 15
                                color: abm.containsMouse
                                    ? Qt.rgba(accent.r, accent.g, accent.b, 0.24)
                                    : Qt.rgba(accent.r, accent.g, accent.b, 0.12)
                                Text {
                                    id: abt
                                    anchors.centerIn: parent
                                    text: ab.label
                                    color: ab.accent
                                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                }
                                MouseArea {
                                    id: abm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ab.triggered()
                                }
                            }

                            ActBtn {
                                visible: !netItem.modelData.connected && !netItem.modelData.stateChanging
                                label: "Connect"
                                onTriggered: {
                                    netItem.failText = "";
                                    if (netItem.showPsk && pskInput.text.length > 0) {
                                        netItem.modelData.connectWithPsk(pskInput.text);
                                        pskInput.text = "";
                                    } else {
                                        netItem.modelData.connect();
                                    }
                                }
                            }
                            ActBtn {
                                visible: netItem.modelData.connected
                                label: "Disconnect"
                                accent: Theme.on_surface_variant
                                onTriggered: netItem.modelData.disconnect()
                            }
                            ActBtn {
                                visible: netItem.modelData.known
                                label: "Forget"
                                accent: Theme.critical
                                onTriggered: netItem.modelData.forget()
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: netItem.modelData.stateChanging
                                text: "Connecting…"
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }
}
