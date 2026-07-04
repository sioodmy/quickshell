import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services


Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: wallpaperWindow
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "wallpaper"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        
        // This makes sure it doesn't block any interactions if something goes wrong
        mask: Region { item: Item {} } 

        AnimatedWallpaper {
            id: wallpaperContent
            anchors.fill: parent
        }
    }
}
