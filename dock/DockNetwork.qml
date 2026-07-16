import QtQuick
import Quickshell.Networking
import qs.theme

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

    Text {
        id: icon
        anchors.centerIn: parent
        text: {
            if (!Networking.wifiEnabled)
                return "󰤭"
            if (root.activeNetwork)
                return "󰤨"
            return "󰤯"
        }
        font {
            family: "JetBrainsMono Nerd Font"
            pixelSize: 11
        }
        color: Networking.wifiEnabled ? Theme.primary : Theme.on_surface_variant
    }
}
