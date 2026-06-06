import Quickshell
import Quickshell.Wayland

import QtQuick
import qs.theme
import qs.services

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: sideBarWindow

        // --- Screen Mapping ---
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Overlay

        // --- Geometry & Positioning ---
        anchors {
            top: true
            left: true
            bottom: true
        }

        // --- Visual Styling ---
        implicitWidth: Layout.sideBarWidth
        color: "transparent"
    }
}
