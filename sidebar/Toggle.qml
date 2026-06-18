import QtQuick
import qs.theme

/** M3-style switch. */
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    width: 48
    height: 28
    radius: height / 2
    color: checked ? Theme.primary : Theme.surface_container_highest
    border.color: checked ? Theme.primary : Theme.outline
    border.width: 2

    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        width: root.checked ? 20 : 16
        height: width
        radius: width / 2
        color: root.checked ? Theme.on_primary : Theme.outline
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 4 : 4

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
