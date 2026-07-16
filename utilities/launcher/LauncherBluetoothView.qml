import QtQuick
import Quickshell.Bluetooth
import "../../theme"

Item {
    id: root

    property string filterQuery: ""
    property real revealProgress: 1.0
    property int selectedIndex: 0
    property int connectingIndex: -1
    property var connectingDevice: null
    property string connectingDeviceAddress: ""
    property int connectionWatchStartMs: 0

    signal refocusSearchRequested()
    signal connectionSucceeded(string deviceLabel)

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: {
        if (!adapter) return [];
        return [...adapter.devices.values].filter(d => d.connected);
    }
    readonly property var sortedDevices: {
        if (!adapter) return [];
        return [...adapter.devices.values].filter(d => d.paired || d.connected).sort((a, b) => {
            if (a.connected !== b.connected) return b.connected - a.connected;
            if (a.paired !== b.paired) return b.paired - a.paired;
            return (a.name || a.address).localeCompare(b.name || b.address);
        });
    }

    function deviceFilterScore(device, query) {
        var name = (device.name || device.address || "").toLowerCase();
        if (name === query) return 1000;
        if (name.startsWith(query)) return 800;
        var words = name.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(query)) return 600;
        }
        if (query.length >= 2 && name.indexOf(query) !== -1) return 200;
        return -1;
    }

    readonly property var filteredDevices: {
        var q = filterQuery.trim().toLowerCase();
        if (!q) return sortedDevices;
        var scored = [];
        for (var i = 0; i < sortedDevices.length; i++) {
            var score = deviceFilterScore(sortedDevices[i], q);
            if (score >= 0)
                scored.push({ device: sortedDevices[i], score: score });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (a.device.connected !== b.device.connected)
                return b.device.connected - a.device.connected;
            return (a.device.name || a.device.address).localeCompare(b.device.name || b.device.address);
        });
        return scored.map(function(entry) { return entry.device; });
    }

    readonly property var topMatch: filteredDevices.length > 0 ? filteredDevices[0] : null
    readonly property var selectedDevice: filteredDevices.length > 0 && selectedIndex >= 0 && selectedIndex < filteredDevices.length
        ? filteredDevices[selectedIndex] : null
    readonly property real estimatedSelectedY: 88 + selectedIndex * 56
    readonly property real selectedScrollY: estimatedSelectedY

    function clampSelectedIndex() {
        if (filteredDevices.length === 0) selectedIndex = 0;
        else if (selectedIndex >= filteredDevices.length) selectedIndex = filteredDevices.length - 1;
        else if (selectedIndex < 0) selectedIndex = 0;
    }

    function incrementSelection() {
        if (filteredDevices.length === 0) return;
        selectedIndex = (selectedIndex + 1) % filteredDevices.length;
    }

    function decrementSelection() {
        if (filteredDevices.length === 0) return;
        selectedIndex = selectedIndex <= 0 ? filteredDevices.length - 1 : selectedIndex - 1;
    }

    function activateSelected() {
        if (!selectedDevice) return false;
        if (selectedDevice.connected || selectedDevice.pairing) return false;
        connectingIndex = selectedIndex;
        connectingDevice = selectedDevice;
        connectingDeviceAddress = selectedDevice.address || "";
        connectionWatchStartMs = Date.now();
        connectionWatchTimer.restart();
        if (!selectedDevice.paired)
            selectedDevice.pair();
        selectedDevice.connect();
        return true;
    }

    function resetConnecting() {
        connectingIndex = -1;
        connectingDevice = null;
        connectingDeviceAddress = "";
        connectionWatchStartMs = 0;
        connectionWatchTimer.stop();
    }

    function activateTopMatch() { return activateSelected(); }

    onFilterQueryChanged: selectedIndex = 0
    onFilteredDevicesChanged: clampSelectedIndex()

    Component.onCompleted: {
        if (adapter && adapter.enabled)
            adapter.discovering = true;
    }

    onVisibleChanged: {
        if (!visible) {
            resetConnecting();
            return;
        }
        if (adapter && adapter.enabled)
            adapter.discovering = true;
    }

    Timer {
        id: connectionWatchTimer
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            if (!connectingDevice) {
                stop();
                return;
            }

            var currentDevice = connectingDevice;
            if (connectingDeviceAddress && adapter) {
                // Adapter may replace device objects; poll the current one by address.
                currentDevice = [...adapter.devices.values].find(d => d.address === connectingDeviceAddress) || currentDevice;
            }

            if (currentDevice && currentDevice.connected) {
                var label = currentDevice.name || currentDevice.address || "Bluetooth device";
                // Stop UI spinner; launcher will reset state as part of closeMenu().
                connectingIndex = -1;
                connectingDevice = null;
                connectingDeviceAddress = "";
                connectionWatchStartMs = 0;
                stop();
                connectionSucceeded(label);
                return;
            }

            // Avoid leaving the launcher stuck in "Connecting…" forever.
            if (connectionWatchStartMs > 0 && (Date.now() - connectionWatchStartMs) > 12000) {
                connectingIndex = -1;
                connectingDevice = null;
                connectionWatchStartMs = 0;
                stop();
            }
        }
    }

    function btDeviceIcon(device) {
        if (!device) return "󰂯";
        var name = (device.name || "").toLowerCase();
        if (name.indexOf("headphone") !== -1 || name.indexOf("airpod") !== -1 || name.indexOf("buds") !== -1)
            return "󰋋";
        if (name.indexOf("keyboard") !== -1 || name.indexOf("keeb") !== -1)
            return "󰌌";
        if (name.indexOf("mouse") !== -1 || name.indexOf("trackpad") !== -1)
            return "󰍽";
        if (name.indexOf("controller") !== -1 || name.indexOf("gamepad") !== -1 || name.indexOf("joystick") !== -1)
            return "󰊗";
        if (name.indexOf("phone") !== -1 || name.indexOf("pixel") !== -1 || name.indexOf("iphone") !== -1)
            return "󰏲";
        return "󰂯";
    }

    // ─── Status Header ───
    Rectangle {
        id: statusHeader
        anchors.top: parent.top
        anchors.topMargin: 8
        width: parent.width
        height: 72
        radius: 16
        color: statusMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: statusMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Rectangle {
                width: 48
                height: 48
                radius: 24
                anchors.verticalCenter: parent.verticalCenter
                color: (root.adapter && root.adapter.enabled)
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                    : Theme.surface_variant

                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: (root.adapter && root.adapter.enabled) ? "󰂯" : "󰂲"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                    color: (root.adapter && root.adapter.enabled) ? Theme.primary : Theme.on_surface_variant
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - 14 - btToggle.width - 14
                spacing: 2

                Text {
                    text: "Bluetooth"
                    font { family: "Google Sans Medium"; pixelSize: 15 }
                    color: Theme.on_surface
                }
                Text {
                    width: parent.width
                    text: {
                        if (!root.adapter) return "Unavailable";
                        if (!root.adapter.enabled) return "Disabled";
                        if (root.connectedDevices.length === 1)
                            return root.connectedDevices[0].name || root.connectedDevices[0].address;
                        if (root.connectedDevices.length > 1)
                            return root.connectedDevices.length + " devices connected";
                        return "Not connected";
                    }
                    font { family: "Google Sans"; pixelSize: 12 }
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: btToggle
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 28
                radius: 14
                color: (root.adapter && root.adapter.enabled) ? Theme.primary : Theme.surface_container_highest
                border.color: (root.adapter && root.adapter.enabled) ? Theme.primary : Theme.outline
                border.width: 2

                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: (root.adapter && root.adapter.enabled) ? 20 : 16
                    height: width
                    radius: width / 2
                    color: (root.adapter && root.adapter.enabled) ? Theme.on_primary : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    x: (root.adapter && root.adapter.enabled) ? parent.width - width - 4 : 4

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                }
            }
        }
    }

    // ─── Device List ───
    ListView {
        id: deviceList
        anchors.top: statusHeader.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        visible: root.adapter && root.adapter.enabled
        model: root.filteredDevices

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 32
            visible: root.filteredDevices.length === 0
            text: root.filterQuery.trim() ? "No matching devices" : "Searching for devices…"
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 14 }
            opacity: 0.8
        }

        delegate: Rectangle {
            id: devDelegate
            required property var modelData
            required property int index

            property bool isSelected: index === root.selectedIndex
            property bool isConnecting: index === root.connectingIndex

            width: ListView.view.width
            height: 56
            radius: 14
            color: isConnecting
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                : (isSelected
                    ? Theme.secondary_container
                    : (modelData.connected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        : (devMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                            : "transparent")))

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: devPulse.pulseOpacity
                visible: devDelegate.isConnecting

                QtObject {
                    id: devPulse
                    property real pulseOpacity: 0.10
                }

                SequentialAnimation {
                    running: devDelegate.isConnecting
                    loops: Animation.Infinite
                    NumberAnimation { target: devPulse; property: "pulseOpacity"; from: 0.06; to: 0.20; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { target: devPulse; property: "pulseOpacity"; from: 0.20; to: 0.06; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                width: 3
                height: devDelegate.isSelected ? 28 : 0
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                radius: 1.5
                color: Theme.primary
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: devMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = devDelegate.index
                onClicked: root.selectedIndex = devDelegate.index
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 14

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: devDelegate.modelData.connected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                        : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.btDeviceIcon(devDelegate.modelData)
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: devDelegate.isConnecting || devDelegate.modelData.connected
                            ? Theme.primary : Theme.on_surface_variant

                        RotationAnimation on rotation {
                            running: devDelegate.isConnecting
                            from: 0; to: 360; duration: 1200
                            loops: Animation.Infinite
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - 14 - devActionArea.width - 14
                    spacing: 1

                    Text {
                        width: parent.width
                        text: devDelegate.modelData.name || devDelegate.modelData.address
                        color: devDelegate.isSelected ? Theme.on_secondary_container : Theme.on_surface
                        font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                        elide: Text.ElideRight
                    }
                    Text {
                        text: {
                            if (devDelegate.isConnecting) return "Connecting…";
                            if (devDelegate.modelData.connected)
                                return devDelegate.modelData.batteryAvailable
                                    ? "Connected · " + Math.round(devDelegate.modelData.battery * 100) + "%"
                                    : "Connected";
                            if (devDelegate.modelData.pairing) return "Pairing…";
                            if (devDelegate.modelData.paired) return "Paired";
                            return "Available";
                        }
                        color: devDelegate.isConnecting ? Theme.primary
                            : (devDelegate.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant)
                        opacity: devDelegate.isSelected && !devDelegate.isConnecting ? 0.8 : 1.0
                        font { family: "Google Sans"; pixelSize: 11 }
                    }
                }

                Row {
                    id: devActionArea
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: devDelegate.isSelected
                    opacity: devDelegate.isSelected ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        visible: !devDelegate.modelData.connected && !devDelegate.modelData.pairing
                        width: devConnLabel.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: devConnMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: devConnLabel
                            anchors.centerIn: parent
                            text: "Connect"
                            color: devConnMouse.containsMouse ? Theme.on_primary : Theme.primary
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }

                        MouseArea {
                            id: devConnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.connectingIndex = devDelegate.index;
                                if (!devDelegate.modelData.paired)
                                    devDelegate.modelData.pair();
                                devDelegate.modelData.connect();
                            }
                        }
                    }

                    Rectangle {
                        visible: devDelegate.modelData.connected
                        width: devDisconnLabel.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: devDisconnMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.2)
                            : Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.1)

                        Text {
                            id: devDisconnLabel
                            anchors.centerIn: parent
                            text: "Disconnect"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }

                        MouseArea {
                            id: devDisconnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devDelegate.modelData.disconnect()
                        }
                    }

                    Rectangle {
                        visible: devDelegate.modelData.pairing
                        width: devCancelLabel.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: devCancelMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.2)
                            : Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.1)

                        Text {
                            id: devCancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }

                        MouseArea {
                            id: devCancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devDelegate.modelData.cancelPair()
                        }
                    }

                    Rectangle {
                        visible: (devDelegate.modelData.paired || devDelegate.modelData.bonded) && !devDelegate.modelData.connected
                        width: devForgetLabel.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: devForgetMouse.containsMouse
                            ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.2)
                            : Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.1)

                        Text {
                            id: devForgetLabel
                            anchors.centerIn: parent
                            text: "Forget"
                            color: Theme.critical
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }

                        MouseArea {
                            id: devForgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devDelegate.modelData.forget()
                        }
                    }
                }
            }
        }
    }

    // Disabled state overlay
    Rectangle {
        anchors.top: statusHeader.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        visible: !root.adapter || !root.adapter.enabled
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰂲"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 48 }
                color: Theme.on_surface_variant
                opacity: 0.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.adapter ? "No Bluetooth adapter" : "Bluetooth is turned off"
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 14 }
                opacity: 0.7
            }
        }
    }
}
