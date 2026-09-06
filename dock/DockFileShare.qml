import QtQuick
import qs.theme
import qs.services
import qs.components

Item {
    id: root
    
    readonly property bool isVisible: FileShare.active
    
    // Smooth appearance horizontally
    implicitWidth: isVisible ? layout.implicitWidth + 16 : 0
    implicitHeight: 22
    
    clip: true
    opacity: isVisible ? 1 : 0
    
    Behavior on implicitWidth { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent
        width: layout.implicitWidth + 16
        height: 22
        radius: height / 2
        
        color: {
            if (pillMouse.containsMouse)
                return Qt.rgba(1, 1, 1, 0.1);
            return "transparent";
        }
        
        scale: pillMouse.pressed ? 0.95 : 1.0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        
        Row {
            id: layout
            anchors.centerIn: parent
            spacing: 6
            
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: pillMouse.containsMouse ? "close" : "wifi_tethering"
                font.pixelSize: 13
                color: pillMouse.containsMouse ? Theme.critical : Theme.primary
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sharing"
                color: Theme.on_surface
                font.pixelSize: 13
                font.weight: Font.Medium
            }
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
