import QtQuick
import Quickshell.Networking
import qs.theme
import qs.components

Item {
    id: root

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device
        }
        return null
    }

    readonly property var activeNetwork: {
        if (!wifiDevice)
            return null
        for (const network of wifiDevice.networks.values) {
            if (network.connected)
                return network
        }
        return null
    }

    MaterialIcon {
        id: icon
        anchors.centerIn: parent
        icon: {
            if (!Networking.wifiEnabled)
                return "signal_wifi_off"
            if (root.activeNetwork)
                return "signal_wifi_4_bar"
            return "signal_wifi_0_bar"
        }
        font.pixelSize: 11
        color: Networking.wifiEnabled ? Theme.primary : Theme.on_surface_variant
    }
}
