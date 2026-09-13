import QtQuick
import qs.components

MouseArea {
    id: root

    property var notification: null
    signal dismissed()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        if (notification && typeof notification.dismiss === "function") {
            notification.dismiss();
        }
        root.dismissed();
    }

    Row {
        id: row
        spacing: 12

        Column {
            id: textCol
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(300, implicitWidth)

            Text {
                text: root.notification ? (root.notification.summary || root.notification.appName) : ""
                color: "#ffffff"
                font.family: "Google Sans Medium"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 300)
            }
            Text {
                text: root.notification ? root.notification.body : ""
                color: "#bbbbbb"
                font.family: "Google Sans"
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                width: Math.min(implicitWidth, 300)
                visible: text !== ""
            }
        }
    }
}
