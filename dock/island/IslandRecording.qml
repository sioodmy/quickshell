import QtQuick
import qs.theme
import qs.components

Row {
    spacing: 12

    Rectangle {
        width: 32
        height: 32
        radius: 16
        color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
        MaterialIcon {
            anchors.centerIn: parent
            icon: "videocam"
            color: Theme.critical
            font.pixelSize: 16
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Screen recording saved"
        color: "#ffffff"
        font.family: "Google Sans Medium"
        font.pixelSize: 14
        font.bold: true
    }
}
