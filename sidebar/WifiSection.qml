import QtQuick
import Quickshell.Networking
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
    property bool selectedPskActive: false
    property string selectedPskText: ""

    signal refocusSearchRequested()
    signal connectionAttemptFailed()

    readonly property bool isExpanded: forceExpanded || expanded

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

    function networkFilterScore(network, query) {
        var name = (network.name || "").toLowerCase();
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

    readonly property var filteredNetworks: {
        var q = filterQuery.trim().toLowerCase();
        if (!q)
            return sortedNetworks;
        var scored = [];
        for (var i = 0; i < sortedNetworks.length; i++) {
            var score = networkFilterScore(sortedNetworks[i], q);
            if (score >= 0)
                scored.push({ network: sortedNetworks[i], score: score });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            if (a.network.connected !== b.network.connected)
                return b.network.connected - a.network.connected;
            return b.network.signalStrength - a.network.signalStrength;
        });
        return scored.map(function(entry) { return entry.network; });
    }

    readonly property var topMatch: filteredNetworks.length > 0 ? filteredNetworks[0] : null
    readonly property var selectedNetwork: filteredNetworks.length > 0 && selectedIndex >= 0 && selectedIndex < filteredNetworks.length
        ? filteredNetworks[selectedIndex] : null
    readonly property real estimatedSelectedY: 72 + selectedIndex * 48

    function clampSelectedIndex() {
        if (filteredNetworks.length === 0)
            selectedIndex = 0;
        else if (selectedIndex >= filteredNetworks.length)
            selectedIndex = filteredNetworks.length - 1;
        else if (selectedIndex < 0)
            selectedIndex = 0;
    }

    function incrementSelection() {
        if (filteredNetworks.length === 0)
            return;
        selectedIndex = (selectedIndex + 1) % filteredNetworks.length;
    }

    function decrementSelection() {
        if (filteredNetworks.length === 0)
            return;
        selectedIndex = selectedIndex <= 0 ? filteredNetworks.length - 1 : selectedIndex - 1;
    }

    function activateSelected() {
        if (!selectedNetwork)
            return false;
        if (selectedNetwork.connected)
            return false;
        connectingIndex = selectedIndex;
        if (selectedPskActive && selectedPskText.length > 0) {
            selectedNetwork.connectWithPsk(selectedPskText);
            selectedPskText = "";
            return true;
        }
        selectedNetwork.connect();
        return true;
    }

    function resetConnecting() {
        connectingIndex = -1;
    }

    function activateTopMatch() {
        return activateSelected();
    }

    onFilterQueryChanged: selectedIndex = 0
    onFilteredNetworksChanged: clampSelectedIndex()
    onSelectedIndexChanged: {
        selectedPskActive = false;
        selectedPskText = "";
    }

    onExpandedChanged: {
        if (wifiDevice && !forceExpanded)
            wifiDevice.scannerEnabled = expanded;
    }

    onForceExpandedChanged: {
        if (wifiDevice && forceExpanded)
            wifiDevice.scannerEnabled = true;
    }

    Component.onCompleted: {
        if (wifiDevice && forceExpanded)
            wifiDevice.scannerEnabled = true;
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
            onClicked: if (!root.forceExpanded) root.expanded = !root.expanded
        }
    }

    // --- Network list ---
    Column {
        width: parent.width
        spacing: 4
        visible: root.isExpanded && Networking.wifiEnabled

        Text {
            visible: root.filteredNetworks.length === 0
            text: root.filterQuery.trim() ? "No matching networks" : "Searching for networks…"
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 13 }
            leftPadding: 8
            topPadding: 6
            bottomPadding: 6
        }

        Repeater {
            model: root.filteredNetworks

            Rectangle {
                id: netItem
                required property var modelData
                required property int index
                property bool userOpen: false
                property bool open: root.forceExpanded ? (index === root.selectedIndex) : userOpen
                property bool showPsk: false
                property string failText: ""
                property bool isKeyboardSelected: root.forceExpanded && index === root.selectedIndex
                property bool isConnecting: root.forceExpanded && index === root.connectingIndex

                onShowPskChanged: {
                    if (root.forceExpanded && index === root.selectedIndex)
                        root.selectedPskActive = showPsk;
                }

                width: parent.width
                radius: 16
                color: netItem.isConnecting
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    : (netItem.isKeyboardSelected
                        ? Theme.secondary_container
                        : (modelData.connected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                            : (rowMouse.containsMouse || netItem.open
                                ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                                : "transparent")))
                height: col.height

                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.primary
                    opacity: connectingPulse.opacity
                    visible: netItem.isConnecting

                    QtObject {
                        id: connectingPulse
                        property real opacity: 0.12
                    }

                    SequentialAnimation {
                        running: netItem.isConnecting
                        loops: Animation.Infinite
                        NumberAnimation { target: connectingPulse; property: "opacity"; from: 0.08; to: 0.24; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { target: connectingPulse; property: "opacity"; from: 0.24; to: 0.08; duration: 450; easing.type: Easing.InOutSine }
                    }
                }

                Connections {
                    target: netItem.modelData
                    function onConnectionFailed(reason) {
                        netItem.failText = "Connection failed";
                        netItem.showPsk = true;
                        if (netItem.index === root.connectingIndex) {
                            root.connectingIndex = -1;
                            root.connectionAttemptFailed();
                        }
                        if (root.forceExpanded && netItem.index === root.selectedIndex) {
                            root.selectedPskActive = true;
                            Qt.callLater(function() { pskInput.forceActiveFocus(); });
                        }
                    }
                    function onStateChanged() {
                        if (netItem.modelData.connected) {
                            netItem.showPsk = false;
                            netItem.failText = "";
                            if (!root.forceExpanded)
                                netItem.userOpen = false;
                            if (netItem.index === root.selectedIndex) {
                                root.selectedPskActive = false;
                                root.selectedPskText = "";
                            }
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
                            onEntered: if (root.forceExpanded) root.selectedIndex = netItem.index
                            onClicked: {
                                if (root.forceExpanded)
                                    root.selectedIndex = netItem.index;
                                else
                                    netItem.userOpen = !netItem.userOpen;
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (netItem.isConnecting)
                                    return "󰤭";
                                const s = netItem.modelData.signalStrength;
                                if (s >= 0.75) return "󰤨";
                                if (s >= 0.5) return "󰤥";
                                if (s >= 0.25) return "󰤢";
                                return "󰤟";
                            }
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                            color: netItem.isConnecting || netItem.modelData.connected ? Theme.primary : Theme.on_surface_variant

                            RotationAnimation on rotation {
                                running: netItem.isConnecting
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
                                text: netItem.modelData.name
                                color: netItem.isKeyboardSelected ? Theme.on_secondary_container : Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: netItem.isConnecting || netItem.modelData.connected || netItem.modelData.known
                                text: netItem.isConnecting
                                    ? "Connecting…"
                                    : (netItem.modelData.connected ? "Connected" : "Saved")
                                color: netItem.isConnecting
                                    ? Theme.primary
                                    : (netItem.isKeyboardSelected ? Theme.on_secondary_container : Theme.on_surface_variant)
                                opacity: netItem.isKeyboardSelected && !netItem.isConnecting ? 0.8 : 1.0
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
                                text: netItem.index === root.selectedIndex ? root.selectedPskText : ""
                                onTextChanged: {
                                    if (netItem.index === root.selectedIndex)
                                        root.selectedPskText = text;
                                }
                                onAccepted: {
                                    netItem.modelData.connectWithPsk(text);
                                    text = "";
                                    if (netItem.index === root.selectedIndex)
                                        root.selectedPskText = "";
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                        if ((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab)
                                            root.decrementSelection();
                                        else
                                            root.incrementSelection();
                                        netItem.showPsk = false;
                                        root.selectedPskActive = false;
                                        root.selectedPskText = "";
                                        root.refocusSearchRequested();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        netItem.showPsk = false;
                                        root.selectedPskActive = false;
                                        root.selectedPskText = "";
                                        pskInput.text = "";
                                        root.refocusSearchRequested();
                                        event.accepted = true;
                                    }
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
