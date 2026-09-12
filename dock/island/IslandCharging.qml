import QtQuick
import qs.theme
import qs.components

Item {
    id: root

    property real osdDockWidth: 300
    property real osdDockHeight: 42

    implicitWidth: osdDockWidth
    implicitHeight: osdDockHeight

    Item {
        anchors.top: parent.top
        anchors.topMargin: 14
        height: 28
        anchors.left: parent.left
        anchors.right: parent.right

        Row {
            anchors.centerIn: parent
            spacing: 8

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "bolt"
                font.pixelSize: 18
                color: "#259b50"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Charging"
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pointSize: 11
                font.weight: Font.Bold
            }
        }
    }
}
