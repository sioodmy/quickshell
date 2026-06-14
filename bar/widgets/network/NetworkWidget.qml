import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking

import qs.theme

PanelWindow {
    id: root

    property var wifiDevice: null

    implicitWidth: 340
    implicitHeight: 440
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins {
        top: 60
        right: 15
    }

    WlrLayershell.namespace: "network_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Keep the radio scanning only while the popup is open so the list stays fresh.
    onVisibleChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = visible
    }

    readonly property var sortedNetworks: {
        if (!wifiDevice)
            return []
        return [...wifiDevice.networks.values].sort((a, b) => {
            if (a.connected !== b.connected)
                return b.connected - a.connected
            if (a.known !== b.known)
                return b.known - a.known
            return b.signalStrength - a.signalStrength
        })
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface_container_low
        radius: 24
        border.color: Theme.outline_variant
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // --- Header with WiFi toggle ---
            Row {
                width: parent.width
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 18; weight: Font.Bold }
                }

                Item {
                    width: parent.width - 60 - parent.spacing * 2 - wifiToggle.width
                    height: 1
                }

                // M3 toggle switch
                Rectangle {
                    id: wifiToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 28
                    radius: height / 2
                    color: Networking.wifiEnabled ? Theme.primary : Theme.surface_container_high
                    border.color: Networking.wifiEnabled ? Theme.primary : Theme.outline
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Rectangle {
                        width: Networking.wifiEnabled ? 20 : 16
                        height: width
                        radius: width / 2
                        color: Networking.wifiEnabled ? Theme.on_primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                        x: Networking.wifiEnabled ? parent.width - width - 4 : 4

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.outline_variant }

            // --- Disabled / empty states ---
            Text {
                visible: !Networking.wifiEnabled
                width: parent.width
                text: "Wi-Fi is turned off"
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                font { family: "Google Sans"; pixelSize: 14 }
                topPadding: 24
            }

            Text {
                visible: Networking.wifiEnabled && root.sortedNetworks.length === 0
                width: parent.width
                text: "Searching for networks…"
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                font { family: "Google Sans"; pixelSize: 14 }
                topPadding: 24
            }

            // --- Network list ---
            Flickable {
                visible: Networking.wifiEnabled
                width: parent.width
                height: parent.height - y
                contentHeight: networkColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: networkColumn
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.sortedNetworks

                        Rectangle {
                            id: netItem
                            required property var modelData
                            property bool expanded: false
                            property bool showPsk: false
                            property string failText: ""

                            width: networkColumn.width
                            radius: 14
                            color: modelData.connected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                : (rowMouse.containsMouse || netItem.expanded
                                    ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                                    : "transparent")
                            height: itemColumn.height

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Connections {
                                target: netItem.modelData
                                function onConnectionFailed(reason) {
                                    netItem.failText = "Connection failed: " + ConnectionFailReason.toString(reason)
                                    netItem.showPsk = true
                                    netItem.expanded = true
                                }
                                function onStateChanged() {
                                    if (netItem.modelData.connected) {
                                        netItem.showPsk = false
                                        netItem.failText = ""
                                        netItem.expanded = false
                                    }
                                }
                            }

                            Column {
                                id: itemColumn
                                width: parent.width
                                spacing: 0

                                // Main row
                                Item {
                                    width: parent.width
                                    height: 48

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: netItem.expanded = !netItem.expanded
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                const s = netItem.modelData.signalStrength
                                                if (s >= 0.75) return "󰤨"
                                                if (s >= 0.5) return "󰤥"
                                                if (s >= 0.25) return "󰤢"
                                                return "󰤟"
                                            }
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                                            color: netItem.modelData.connected ? Theme.primary : Theme.on_surface_variant
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: netItem.modelData.name
                                                color: Theme.on_surface
                                                font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                                                width: netItem.width - 90
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

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: netItem.modelData.security !== WifiSecurityType.None
                                        text: "󰍁"
                                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                        color: Theme.on_surface_variant
                                    }
                                }

                                // Expanded controls
                                Column {
                                    width: parent.width
                                    visible: netItem.expanded
                                    spacing: 8
                                    bottomPadding: 12
                                    leftPadding: 12
                                    rightPadding: 12

                                    Text {
                                        visible: netItem.failText.length > 0
                                        text: netItem.failText
                                        color: Theme.critical
                                        font { family: "Google Sans"; pixelSize: 12 }
                                        width: parent.width - 24
                                        wrapMode: Text.WordWrap
                                    }

                                    // PSK entry field
                                    Rectangle {
                                        visible: netItem.showPsk
                                        width: parent.width - 24
                                        height: 40
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
                                                netItem.modelData.connectWithPsk(text)
                                                text = ""
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

                                    // Action buttons
                                    Row {
                                        spacing: 8

                                        component ActionButton: Rectangle {
                                            id: ab
                                            property string label
                                            property color accent: Theme.primary
                                            signal triggered()
                                            width: abText.implicitWidth + 28
                                            height: 34
                                            radius: 17
                                            color: abMouse.containsMouse
                                                ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
                                                : Qt.rgba(accent.r, accent.g, accent.b, 0.12)
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Text {
                                                id: abText
                                                anchors.centerIn: parent
                                                text: ab.label
                                                color: ab.accent
                                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                            }
                                            MouseArea {
                                                id: abMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ab.triggered()
                                            }
                                        }

                                        ActionButton {
                                            visible: !netItem.modelData.connected && !netItem.modelData.stateChanging
                                            label: netItem.modelData.known ? "Connect" : "Connect"
                                            onTriggered: {
                                                netItem.failText = ""
                                                if (netItem.showPsk && pskInput.text.length > 0) {
                                                    netItem.modelData.connectWithPsk(pskInput.text)
                                                    pskInput.text = ""
                                                } else {
                                                    netItem.modelData.connect()
                                                }
                                            }
                                        }

                                        ActionButton {
                                            visible: netItem.modelData.connected
                                            label: "Disconnect"
                                            accent: Theme.on_surface_variant
                                            onTriggered: netItem.modelData.disconnect()
                                        }

                                        ActionButton {
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
                                            font { family: "Google Sans"; pixelSize: 13 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
