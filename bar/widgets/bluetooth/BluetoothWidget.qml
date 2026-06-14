import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth

import qs.theme

PanelWindow {
    id: root

    property var adapter: null

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "bluetooth_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Discover new devices only while the popup is open.
    onVisibleChanged: {
        if (adapter && adapter.enabled)
            adapter.discovering = visible
    }

    readonly property var sortedDevices: {
        if (!adapter)
            return []
        return [...adapter.devices.values].sort((a, b) => {
            if (a.connected !== b.connected)
                return b.connected - a.connected
            if (a.paired !== b.paired)
                return b.paired - a.paired
            return (a.name || a.address).localeCompare(b.name || b.address)
        })
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        width: 340
        height: 440
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 60
        anchors.rightMargin: 15
        color: Theme.surface_container_low
        radius: 24
        border.color: Theme.outline_variant
        border.width: 1

        // Swallow clicks on the card so it doesn't dismiss
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // --- Header with Bluetooth toggle ---
            Row {
                width: parent.width
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 18; weight: Font.Bold }
                }

                Item {
                    width: parent.width - btText.width - parent.spacing * 2 - btToggle.width
                    height: 1
                    Text { id: btText; visible: false; text: "Bluetooth"; font { family: "Google Sans"; pixelSize: 18; weight: Font.Bold } }
                }

                Rectangle {
                    id: btToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 28
                    radius: height / 2
                    enabled: root.adapter !== null
                    opacity: enabled ? 1 : 0.4
                    color: root.adapter?.enabled ? Theme.primary : Theme.surface_container_high
                    border.color: root.adapter?.enabled ? Theme.primary : Theme.outline
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Rectangle {
                        width: root.adapter?.enabled ? 20 : 16
                        height: width
                        radius: width / 2
                        color: root.adapter?.enabled ? Theme.on_primary : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.adapter?.enabled ? parent.width - width - 4 : 4

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.adapter !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.adapter.enabled = !root.adapter.enabled
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.outline_variant }

            // --- Empty / disabled states ---
            Text {
                visible: !root.adapter
                width: parent.width
                text: "No Bluetooth adapter found"
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                font { family: "Google Sans"; pixelSize: 14 }
                topPadding: 24
            }

            Text {
                visible: root.adapter && !root.adapter.enabled
                width: parent.width
                text: "Bluetooth is turned off"
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                font { family: "Google Sans"; pixelSize: 14 }
                topPadding: 24
            }

            Text {
                visible: root.adapter && root.adapter.enabled && root.sortedDevices.length === 0
                width: parent.width
                text: "Searching for devices…"
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                font { family: "Google Sans"; pixelSize: 14 }
                topPadding: 24
            }

            // --- Device list ---
            Flickable {
                visible: root.adapter && root.adapter.enabled
                width: parent.width
                height: parent.height - y
                contentHeight: deviceColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: deviceColumn
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.sortedDevices

                        Rectangle {
                            id: devItem
                            required property var modelData
                            property bool expanded: false

                            width: deviceColumn.width
                            radius: 14
                            color: modelData.connected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                : (rowMouse.containsMouse || devItem.expanded
                                    ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                                    : "transparent")
                            height: itemColumn.height

                            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Column {
                                id: itemColumn
                                width: parent.width
                                spacing: 0

                                Item {
                                    width: parent.width
                                    height: 48

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: devItem.expanded = !devItem.expanded
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                const i = devItem.modelData.icon || ""
                                                if (i.includes("audio") || i.includes("headset") || i.includes("headphone")) return "󰋋"
                                                if (i.includes("mouse")) return "󰍽"
                                                if (i.includes("keyboard")) return "󰌌"
                                                if (i.includes("phone")) return "󰏳"
                                                return "󰂯"
                                            }
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                                            color: devItem.modelData.connected ? Theme.primary : Theme.on_surface_variant
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: devItem.modelData.name || devItem.modelData.address
                                                color: Theme.on_surface
                                                font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                                                width: devItem.width - 90
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: {
                                                    if (devItem.modelData.connected)
                                                        return devItem.modelData.batteryAvailable
                                                            ? "Connected · " + Math.round(devItem.modelData.battery * 100) + "%"
                                                            : "Connected"
                                                    if (devItem.modelData.pairing) return "Pairing…"
                                                    if (devItem.modelData.paired) return "Paired"
                                                    return "Available"
                                                }
                                                color: Theme.on_surface_variant
                                                font { family: "Google Sans"; pixelSize: 11 }
                                            }
                                        }
                                    }
                                }

                                // Expanded controls
                                Row {
                                    visible: devItem.expanded
                                    spacing: 8
                                    leftPadding: 12
                                    bottomPadding: 12

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
                                        visible: !devItem.modelData.connected && !devItem.modelData.pairing
                                        label: "Connect"
                                        onTriggered: {
                                            if (!devItem.modelData.paired)
                                                devItem.modelData.pair()
                                            devItem.modelData.connect()
                                        }
                                    }

                                    ActionButton {
                                        visible: devItem.modelData.connected
                                        label: "Disconnect"
                                        accent: Theme.on_surface_variant
                                        onTriggered: devItem.modelData.disconnect()
                                    }

                                    ActionButton {
                                        visible: devItem.modelData.pairing
                                        label: "Cancel"
                                        accent: Theme.on_surface_variant
                                        onTriggered: devItem.modelData.cancelPair()
                                    }

                                    ActionButton {
                                        visible: devItem.modelData.paired || devItem.modelData.bonded
                                        label: "Forget"
                                        accent: Theme.critical
                                        onTriggered: devItem.modelData.forget()
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
