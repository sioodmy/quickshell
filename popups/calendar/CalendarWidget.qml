import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.theme

PanelWindow {
    id: root

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "calendar_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        width: 780
        height: 520
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 16
        anchors.leftMargin: 64
        color: Theme.surface_container_low
        radius: 32

        border.color: Theme.outline_variant
        border.width: 1

        // Swallow clicks on the card so it doesn't dismiss
        MouseArea { anchors.fill: parent }

        CalendarGrid {
            anchors.fill: parent

            isWindowVisible: root.visible

            onRequestClose: root.visible = false
        }
    }
}
