import QtQuick
import Quickshell.Bluetooth
import qs.theme

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
            pixelSize: 11
        }
        color: (root.adapter && root.adapter.enabled && root.connectedDevices.length > 0) ? Theme.primary : Theme.on_surface_variant
    }
}
