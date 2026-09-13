import QtQuick
import qs.theme
import qs.components

Row {
    id: root
    spacing: 12

    property int batteryRemaining: 100

    Rectangle {
        width: 32
        height: 32
        radius: 16
        color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
        MaterialIcon {
            anchors.centerIn: parent
            icon: "battery_alert"
            color: Theme.critical
            font.pixelSize: 16
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: "Low Battery"
            color: "#ffffff"
            font.family: "Google Sans Medium"
            font.pixelSize: 14
            font.bold: true
        }
        Text {
            text: root.batteryRemaining + "% battery remaining"
            color: "#bbbbbb"
            font.family: "Google Sans"
            font.pixelSize: 12
        }
    }
}
