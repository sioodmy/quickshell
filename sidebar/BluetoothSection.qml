import QtQuick
import Quickshell.Bluetooth
import qs.theme

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 8

    property bool expanded: false
    property bool forceExpanded: false
    property string filterQuery: ""
    property int selectedIndex: 0
    property int connectingIndex: -1

    readonly property bool isExpanded: forceExpanded || expanded

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: {
        if (!adapter)
            return [];
        return [...adapter.devices.values].filter(d => d.connected);
    }
    readonly property var sortedDevices: {
        if (!adapter)
            return [];
        return [...adapter.devices.values].filter(d => d.paired || d.connected).sort((a, b) => {
            if (a.connected !== b.connected)
                return b.connected - a.connected;
            if (a.paired !== b.paired)
                return b.paired - a.paired;
            return (a.name || a.address).localeCompare(b.name || b.address);
        });
    }

    function deviceFilterScore(device, query) {
        var name = (device.name || device.address || "").toLowerCase();
        if (name === query)
            return 1000;
        if (name.startsWith(query))
            return 800;
        var words = name.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(query))
                return 600;
        }
        if (query.length >= 2 && name.indexOf(query) !== -1)
            return 200;
        return -1;
    }

    readonly property var filteredDevices: {
        var q = filterQuery.trim().toLowerCase();
        if (!q)
            return sortedDevices;
        var scored = [];
        for (var i = 0; i < sortedDevices.length; i++) {
            var score = deviceFilterScore(sortedDevices[i], q);
            if (score >= 0)
                scored.push({ device: sortedDevices[i], score: score });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            if (a.device.connected !== b.device.connected)
                return b.device.connected - a.device.connected;
            return (a.device.name || a.device.address).localeCompare(b.device.name || b.device.address);
        });
        return scored.map(function(entry) { return entry.device; });
    }

    readonly property var topMatch: filteredDevices.length > 0 ? filteredDevices[0] : null
    readonly property var selectedDevice: filteredDevices.length > 0 && selectedIndex >= 0 && selectedIndex < filteredDevices.length
        ? filteredDevices[selectedIndex] : null
    readonly property real estimatedSelectedY: 72 + selectedIndex * 48

    function clampSelectedIndex() {
        if (filteredDevices.length === 0)
            selectedIndex = 0;
        else if (selectedIndex >= filteredDevices.length)
            selectedIndex = filteredDevices.length - 1;
        else if (selectedIndex < 0)
            selectedIndex = 0;
    }

    function incrementSelection() {
        if (filteredDevices.length === 0)
            return;
        selectedIndex = (selectedIndex + 1) % filteredDevices.length;
    }

    function decrementSelection() {
        if (filteredDevices.length === 0)
            return;
        selectedIndex = selectedIndex <= 0 ? filteredDevices.length - 1 : selectedIndex - 1;
    }

    function activateSelected() {
        if (!selectedDevice)
            return false;
        if (selectedDevice.connected || selectedDevice.pairing)
            return false;
        connectingIndex = selectedIndex;
        if (!selectedDevice.paired)
            selectedDevice.pair();
        selectedDevice.connect();
        return true;
    }

    function resetConnecting() {
        connectingIndex = -1;
    }

    function activateTopMatch() {
        return activateSelected();
    }

    onFilterQueryChanged: selectedIndex = 0
    onFilteredDevicesChanged: clampSelectedIndex()

    onExpandedChanged: {
        if (adapter && adapter.enabled && !forceExpanded)
            adapter.discovering = expanded;
    }

    onForceExpandedChanged: {
        if (adapter && adapter.enabled && forceExpanded)
            adapter.discovering = true;
    }

    Component.onCompleted: {
        if (adapter && adapter.enabled && forceExpanded)
            adapter.discovering = true;
    }

    // --- Tile header ---
    Rectangle {
        width: parent.width
        height: 64
        radius: 22
        color: (adapter && adapter.enabled)
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
            color: (adapter && adapter.enabled) ? Theme.primary : Theme.surface_container_highest

            Text {
                anchors.centerIn: parent
                text: (root.adapter && root.adapter.enabled) ? "󰂯" : "󰂲"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                color: (root.adapter && root.adapter.enabled) ? Theme.on_primary : Theme.on_surface_variant
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.right: toggleBt.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: "Bluetooth"
                color: Theme.on_surface
                font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: {
                    if (!root.adapter)
                        return "Unavailable";
                    if (!root.adapter.enabled)
                        return "Off";
                    if (root.connectedDevices.length === 1)
                        return root.connectedDevices[0].name || root.connectedDevices[0].address;
                    if (root.connectedDevices.length > 1)
                        return root.connectedDevices.length + " connected";
                    return "Not connected";
                }
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 12 }
                elide: Text.ElideRight
            }
        }

        Toggle {
            id: toggleBt
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            checked: root.adapter ? root.adapter.enabled : false
            onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: toggleBt.left
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!root.forceExpanded) root.expanded = !root.expanded
        }
    }

    // --- Device list ---
    Column {
        width: parent.width
        spacing: 4
        visible: root.isExpanded && root.adapter && root.adapter.enabled

        Text {
            visible: root.filteredDevices.length === 0
            text: root.filterQuery.trim() ? "No matching devices" : "Searching for devices…"
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 13 }
            leftPadding: 8
            topPadding: 6
            bottomPadding: 6
        }

        Repeater {
            model: root.filteredDevices

            Rectangle {
                id: devItem
                required property var modelData
                required property int index
                property bool userOpen: false
                property bool open: root.forceExpanded ? (index === root.selectedIndex) : userOpen
                property bool isKeyboardSelected: root.forceExpanded && index === root.selectedIndex
                property bool isConnecting: root.forceExpanded && index === root.connectingIndex

                width: parent.width
                radius: 16
                color: devItem.isConnecting
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    : (devItem.isKeyboardSelected
                        ? Theme.secondary_container
                        : (modelData.connected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            : (rowMouse.containsMouse || devItem.open
                                ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                                : "transparent")))
                height: col.height

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.primary
                    opacity: connectingPulse.opacity
                    visible: devItem.isConnecting

                    QtObject {
                        id: connectingPulse
                        property real opacity: 0.12
                    }

                    SequentialAnimation {
                        running: devItem.isConnecting
                        loops: Animation.Infinite
                        NumberAnimation { target: connectingPulse; property: "opacity"; from: 0.08; to: 0.24; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { target: connectingPulse; property: "opacity"; from: 0.24; to: 0.08; duration: 450; easing.type: Easing.InOutSine }
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
                            onEntered: if (root.forceExpanded) root.selectedIndex = devItem.index
                            onClicked: {
                                if (root.forceExpanded)
                                    root.selectedIndex = devItem.index;
                                else
                                    devItem.userOpen = !devItem.userOpen;
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰂯"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                            color: devItem.isConnecting || devItem.modelData.connected ? Theme.primary : Theme.on_surface_variant

                            RotationAnimation on rotation {
                                running: devItem.isConnecting
                                from: 0
                                to: 360
                                duration: 1200
                                loops: Animation.Infinite
                            }
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
                                text: devItem.modelData.name || devItem.modelData.address
                                color: devItem.isKeyboardSelected ? Theme.on_secondary_container : Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                elide: Text.ElideRight
                            }
                            Text {
                                text: {
                                    if (devItem.isConnecting)
                                        return "Connecting…";
                                    if (devItem.modelData.connected)
                                        return devItem.modelData.batteryAvailable
                                            ? "Connected · " + Math.round(devItem.modelData.battery * 100) + "%"
                                            : "Connected";
                                    if (devItem.modelData.pairing)
                                        return "Pairing…";
                                    if (devItem.modelData.paired)
                                        return "Paired";
                                    return "Available";
                                }
                                color: devItem.isConnecting
                                    ? Theme.primary
                                    : (devItem.isKeyboardSelected ? Theme.on_secondary_container : Theme.on_surface_variant)
                                opacity: devItem.isKeyboardSelected && !devItem.isConnecting ? 0.8 : 1.0
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }
                    }

                    Row {
                        visible: devItem.open
                        spacing: 8
                        leftPadding: 10
                        bottomPadding: 10

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
                            visible: !devItem.modelData.connected && !devItem.modelData.pairing
                            label: "Connect"
                            onTriggered: {
                                if (!devItem.modelData.paired)
                                    devItem.modelData.pair();
                                devItem.modelData.connect();
                            }
                        }
                        ActBtn {
                            visible: devItem.modelData.connected
                            label: "Disconnect"
                            accent: Theme.on_surface_variant
                            onTriggered: devItem.modelData.disconnect()
                        }
                        ActBtn {
                            visible: devItem.modelData.pairing
                            label: "Cancel"
                            accent: Theme.on_surface_variant
                            onTriggered: devItem.modelData.cancelPair()
                        }
                        ActBtn {
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
