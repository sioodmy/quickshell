import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    readonly property int barRadius: 22
    readonly property int visibleWidth: 44

    // Same left-edge trick as the dock notch: half the radius sits off-screen
    // so only the right side shows rounded corners.
    width: visibleWidth + barRadius
    height: contentCol.implicitHeight + 16
    x: -barRadius
    visible: ScreenRecord.recording

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.barRadius
        color: Theme.critical

        Column {
            id: contentCol
            // Center within the on-screen (right) half of the pill
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.barRadius / 2
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ScreenRecord.elapsedText
                font { family: "Google Sans Medium"; pixelSize: 11 }
                color: Theme.on_critical
            }

            Rectangle {
                width: 26
                height: 26
                radius: 13
                anchors.horizontalCenter: parent.horizontalCenter
                color: stopMouse.containsMouse
                    ? Qt.rgba(Theme.on_critical.r, Theme.on_critical.g, Theme.on_critical.b, 0.28)
                    : Qt.rgba(Theme.on_critical.r, Theme.on_critical.g, Theme.on_critical.b, 0.16)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰓛"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    color: Theme.on_critical
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenRecord.stop()
                }
            }
        }
    }
}
