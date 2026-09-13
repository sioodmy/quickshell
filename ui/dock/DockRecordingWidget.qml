import QtQuick
import qs.theme
import qs.services
import qs.components

Item {
    id: root

    readonly property real targetWidth: isVisible ? layout.implicitWidth + 16 : 0
    implicitWidth: targetWidth
    implicitHeight: 22
    
    readonly property bool isVisible: ScreenRecord.recording

    Behavior on implicitWidth { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
    
    clip: true
    opacity: isVisible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent
        width: parent.width
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
            
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: Theme.on_surface
            }
            
            FontMetrics {
                id: fontMetrics
                font: recordText.font
            }
            
            Text {
                id: recordText
                anchors.verticalCenter: parent.verticalCenter
                text: ScreenRecord.elapsedText
                color: Theme.on_surface
                font.pixelSize: 12
                font.weight: Font.Medium
                width: fontMetrics.advanceWidth("00:00")
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenRecord.stop()
        }
    }
}
