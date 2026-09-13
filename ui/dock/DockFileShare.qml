import QtQuick
import qs.theme
import qs.services
import qs.components

Item {
    id: root
    
    readonly property bool isVisible: FileShare.active
    
    readonly property real targetWidth: isVisible ? 22 : 0
    implicitWidth: targetWidth
    implicitHeight: 22
    
    clip: true
    opacity: isVisible ? 1 : 0
    
    Behavior on implicitWidth { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 11
        
        color: {
            if (pillMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.1);
            return "transparent";
        }
        
        scale: pillMouse.pressed ? 0.95 : 1.0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        
        MaterialIcon {
            id: layout
            anchors.centerIn: parent
            icon: pillMouse.containsMouse ? "close" : "wifi_tethering"
            font.pixelSize: 13
            color: pillMouse.containsMouse ? Theme.critical : Theme.primary
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: FileShare.cancelAll()
        }
    }
}
