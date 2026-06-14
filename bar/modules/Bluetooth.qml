import QtQuick
import Quickshell.Bluetooth
import qs.theme
import qs.bar.widgets.bluetooth

Item {
    id: root

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: {
        if (!adapter)
            return []
        return [...adapter.devices.values].filter(device => device.connected)
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: (root.adapter && root.adapter.enabled) ? "󰂯" : "󰂲"
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 14
        }
        color: (root.adapter && root.adapter.enabled && root.connectedDevices.length > 0) ? Theme.primary : Theme.on_surface_variant
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bluetoothWidget.visible = !bluetoothWidget.visible
    }

    BluetoothWidget {
        id: bluetoothWidget
        visible: false
        adapter: root.adapter
    }
}
