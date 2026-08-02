import QtQuick
import Quickshell.Bluetooth
import qs.theme
import qs.components

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

    MaterialIcon {
        id: icon
        anchors.centerIn: parent
        icon: (root.adapter && root.adapter.enabled) ? "bluetooth" : "bluetooth_disabled"
        font.pixelSize: 11
        color: (root.adapter && root.adapter.enabled && root.connectedDevices.length > 0) ? Theme.primary : Theme.on_surface_variant
    }
}
