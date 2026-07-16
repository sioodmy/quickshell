import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import "../../theme"

Item {
    id: root

    property string filterQuery: ""
    property real revealProgress: 1.0
    property int selectedIndex: 0
    property int connectingIndex: -1
    property bool selectedPskActive: false
    property string selectedPskText: ""

    signal refocusSearchRequested()
    signal connectionAttemptFailed()

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

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
        if (name === query) return 1000;
        if (name.startsWith(query)) return 800;
        var words = name.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(query)) return 600;
        }
        if (query.length >= 2 && name.indexOf(query) !== -1) return 200;
        return -1;
    }

    readonly property var filteredNetworks: {
        var q = filterQuery.trim().toLowerCase();
        if (!q) return sortedNetworks;
        var scored = [];
        for (var i = 0; i < sortedNetworks.length; i++) {
            var score = networkFilterScore(sortedNetworks[i], q);
            if (score >= 0)
                scored.push({ network: sortedNetworks[i], score: score });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (a.network.connected !== b.network.connected)
                return b.network.connected - a.network.connected;
            return b.network.signalStrength - a.network.signalStrength;
        });
        return scored.map(function(entry) { return entry.network; });
    }

    readonly property var topMatch: filteredNetworks.length > 0 ? filteredNetworks[0] : null
    readonly property var selectedNetwork: filteredNetworks.length > 0 && selectedIndex >= 0 && selectedIndex < filteredNetworks.length
        ? filteredNetworks[selectedIndex] : null
    readonly property real estimatedSelectedY: 88 + selectedIndex * 56
    readonly property real selectedScrollY: estimatedSelectedY

    function clampSelectedIndex() {
        if (filteredNetworks.length === 0) selectedIndex = 0;
        else if (selectedIndex >= filteredNetworks.length) selectedIndex = filteredNetworks.length - 1;
        else if (selectedIndex < 0) selectedIndex = 0;
    }

    function incrementSelection() {
        if (filteredNetworks.length === 0) return;
        selectedIndex = (selectedIndex + 1) % filteredNetworks.length;
    }

    function decrementSelection() {
        if (filteredNetworks.length === 0) return;
        selectedIndex = selectedIndex <= 0 ? filteredNetworks.length - 1 : selectedIndex - 1;
    }

    function activateSelected() {
        if (!selectedNetwork) return false;
        if (selectedNetwork.connected) return false;
        connectingIndex = selectedIndex;
        if (selectedPskActive && selectedPskText.length > 0) {
            selectedNetwork.connectWithPsk(selectedPskText);
            selectedPskText = "";
            return true;
        }
        selectedNetwork.connect();
        return true;
    }

    function resetConnecting() { connectingIndex = -1; }

    function activateTopMatch() { return activateSelected(); }

    onFilterQueryChanged: selectedIndex = 0
    onFilteredNetworksChanged: clampSelectedIndex()
    onSelectedIndexChanged: {
        selectedPskActive = false;
        selectedPskText = "";
    }

    Component.onCompleted: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = true;
    }

    onVisibleChanged: {
        if (visible && wifiDevice)
            wifiDevice.scannerEnabled = true;
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
                color: Networking.wifiEnabled
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                    : Theme.surface_variant

                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: !Networking.wifiEnabled ? "󰤭" : (root.activeNetwork ? "󰤨" : "󰤯")
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                    color: Networking.wifiEnabled ? Theme.primary : Theme.on_surface_variant
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - 14 - wifiToggle.width - 14
                spacing: 2

                Text {
                    text: "Wi-Fi"
                    font { family: "Google Sans Medium"; pixelSize: 15 }
                    color: Theme.on_surface
                }
                Text {
                    width: parent.width
                    text: !Networking.wifiEnabled ? "Disabled"
                        : (root.activeNetwork ? root.activeNetwork.name : "Not connected")
                    font { family: "Google Sans"; pixelSize: 12 }
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: wifiToggle
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 28
                radius: 14
                color: Networking.wifiEnabled ? Theme.primary : Theme.surface_container_highest
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
    }

    // ─── Network List ───
    ListView {
        id: networkList
        anchors.top: statusHeader.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        visible: Networking.wifiEnabled
        model: root.filteredNetworks

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 32
            visible: root.filteredNetworks.length === 0
            text: root.filterQuery.trim() ? "No matching networks" : "Scanning for networks…"
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 14 }
            opacity: 0.8
        }

        delegate: Rectangle {
            id: netDelegate
            required property var modelData
            required property int index

            property bool isSelected: index === root.selectedIndex
            property bool isConnecting: index === root.connectingIndex
            property bool showPsk: false
            property string failText: ""

            width: ListView.view.width
            height: netCol.height
            radius: 14
            color: isConnecting
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                : (isSelected
                    ? Theme.secondary_container
                    : (modelData.connected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        : (netMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
                            : "transparent")))

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: pulseObj.pulseOpacity
                visible: netDelegate.isConnecting

                QtObject {
                    id: pulseObj
                    property real pulseOpacity: 0.10
                }

                SequentialAnimation {
                    running: netDelegate.isConnecting
                    loops: Animation.Infinite
                    NumberAnimation { target: pulseObj; property: "pulseOpacity"; from: 0.06; to: 0.20; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { target: pulseObj; property: "pulseOpacity"; from: 0.20; to: 0.06; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                width: 3
                height: netDelegate.isSelected ? 28 : 0
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                radius: 1.5
                color: Theme.primary
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Connections {
                target: netDelegate.modelData
                function onConnectionFailed(reason) {
                    netDelegate.failText = "Connection failed";
                    netDelegate.showPsk = true;
                    if (netDelegate.index === root.connectingIndex) {
                        root.connectingIndex = -1;
                        root.connectionAttemptFailed();
                    }
                    if (netDelegate.index === root.selectedIndex) {
                        root.selectedPskActive = true;
                        Qt.callLater(function() { pskField.forceActiveFocus(); });
                    }
                }
                function onStateChanged() {
                    if (netDelegate.modelData.connected) {
                        netDelegate.showPsk = false;
                        netDelegate.failText = "";
                        if (netDelegate.index === root.selectedIndex) {
                            root.selectedPskActive = false;
                            root.selectedPskText = "";
                        }
                    }
                }
            }

            Column {
                id: netCol
                width: parent.width
                spacing: 0

                Item {
                    width: parent.width
                    height: 52

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = netDelegate.index
                        onClicked: root.selectedIndex = netDelegate.index
                    }

                    Text {
                        id: signalIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (netDelegate.isConnecting) return "󰤭";
                            const s = netDelegate.modelData.signalStrength;
                            if (s >= 0.75) return "󰤨";
                            if (s >= 0.5) return "󰤥";
                            if (s >= 0.25) return "󰤢";
                            return "󰤟";
                        }
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: netDelegate.isConnecting || netDelegate.modelData.connected
                            ? Theme.primary : Theme.on_surface_variant

                        RotationAnimation on rotation {
                            running: netDelegate.isConnecting
                            from: 0; to: 360; duration: 1200
                            loops: Animation.Infinite
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 44
                        anchors.right: actionArea.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: netDelegate.modelData.name
                            color: netDelegate.isSelected ? Theme.on_secondary_container : Theme.on_surface
                            font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: netDelegate.isConnecting || netDelegate.modelData.connected || netDelegate.modelData.known
                            text: netDelegate.isConnecting ? "Connecting…"
                                : (netDelegate.modelData.connected ? "Connected" : "Saved")
                            color: netDelegate.isConnecting ? Theme.primary
                                : (netDelegate.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant)
                            opacity: netDelegate.isSelected && !netDelegate.isConnecting ? 0.8 : 1.0
                            font { family: "Google Sans"; pixelSize: 11 }
                        }
                    }

                    Row {
                        id: actionArea
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: netDelegate.isSelected
                        opacity: netDelegate.isSelected ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            visible: !netDelegate.modelData.connected && !netDelegate.modelData.stateChanging
                            width: connectLabel.implicitWidth + 20
                            height: 28
                            radius: 14
                            color: connectBtnMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                id: connectLabel
                                anchors.centerIn: parent
                                text: "Connect"
                                color: connectBtnMouse.containsMouse ? Theme.on_primary : Theme.primary
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                            }

                            MouseArea {
                                id: connectBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    netDelegate.failText = "";
                                    root.connectingIndex = netDelegate.index;
                                    if (netDelegate.showPsk && pskField.text.length > 0)
                                        netDelegate.modelData.connectWithPsk(pskField.text);
                                    else
                                        netDelegate.modelData.connect();
                                }
                            }
                        }

                        Rectangle {
                            visible: netDelegate.modelData.connected
                            width: disconnectLabel.implicitWidth + 20
                            height: 28
                            radius: 14
                            color: disconnectMouse.containsMouse
                                ? Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.2)
                                : Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.1)

                            Text {
                                id: disconnectLabel
                                anchors.centerIn: parent
                                text: "Disconnect"
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                            }

                            MouseArea {
                                id: disconnectMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netDelegate.modelData.disconnect()
                            }
                        }

                        Rectangle {
                            visible: netDelegate.modelData.known && !netDelegate.modelData.connected
                            width: forgetLabel.implicitWidth + 20
                            height: 28
                            radius: 14
                            color: forgetMouse.containsMouse
                                ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.2)
                                : Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.1)

                            Text {
                                id: forgetLabel
                                anchors.centerIn: parent
                                text: "Forget"
                                color: Theme.critical
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                            }

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netDelegate.modelData.forget()
                            }
                        }
                    }
                }

                // Password field (shown on connection failure or secured networks)
                Item {
                    width: parent.width
                    height: netDelegate.showPsk ? pskCol.height + 8 : 0
                    visible: height > 0
                    clip: true

                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Column {
                        id: pskCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 6

                        Text {
                            visible: netDelegate.failText.length > 0
                            text: netDelegate.failText
                            color: Theme.critical
                            font { family: "Google Sans"; pixelSize: 12 }
                        }

                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 12
                            color: Theme.surface_container_highest
                            border.color: pskField.activeFocus ? Theme.primary : Theme.outline_variant
                            border.width: 1

                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            TextField {
                                id: pskField
                                anchors.fill: parent
                                leftPadding: 14
                                rightPadding: 14
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13 }
                                echoMode: TextInput.Password
                                placeholderText: "Password"
                                placeholderTextColor: Theme.on_surface_variant
                                background: Item {}
                                text: netDelegate.index === root.selectedIndex ? root.selectedPskText : ""

                                onTextChanged: {
                                    if (netDelegate.index === root.selectedIndex)
                                        root.selectedPskText = text;
                                }

                                onAccepted: {
                                    netDelegate.modelData.connectWithPsk(text);
                                    root.connectingIndex = netDelegate.index;
                                    text = "";
                                    if (netDelegate.index === root.selectedIndex)
                                        root.selectedPskText = "";
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                        if ((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab)
                                            root.decrementSelection();
                                        else
                                            root.incrementSelection();
                                        netDelegate.showPsk = false;
                                        root.selectedPskActive = false;
                                        root.selectedPskText = "";
                                        root.refocusSearchRequested();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        netDelegate.showPsk = false;
                                        root.selectedPskActive = false;
                                        root.selectedPskText = "";
                                        root.refocusSearchRequested();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        Item { width: 1; height: 2 }
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
        visible: !Networking.wifiEnabled
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰤭"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 48 }
                color: Theme.on_surface_variant
                opacity: 0.4
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wi-Fi is turned off"
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 14 }
                opacity: 0.7
            }
        }
    }
}
