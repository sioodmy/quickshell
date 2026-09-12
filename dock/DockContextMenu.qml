import QtQuick
import "../theme"
import qs.components

Rectangle {
    id: root

    property bool isOpen: false
    property real itemX: 0
    property string appName: ""
    property string desktopId: ""
    property bool isPinned: false
    property bool isRunning: false
    signal closeRequested()

    visible: isOpen
    opacity: visible ? 1.0 : 0.0
    scale: visible ? 1.0 : 0.85

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

    x: itemX
    y: 56

    width: 170
    height: contextMenuCol.implicitHeight + 16
    radius: 16
    color: Theme.surface_container

    Timer {
        interval: 3000
        running: root.isOpen
        onTriggered: root.closeRequested()
    }

    Column {
        id: contextMenuCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 2

        Text {
            leftPadding: 12
            topPadding: 4
            bottomPadding: 6
            text: root.appName || ""
            font { family: "Google Sans"; pixelSize: 12; weight: Font.DemiBold }
            color: Theme.on_surface_variant
            opacity: 0.7
        }

        Rectangle {
            width: parent.width - 8
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        Item { width: 1; height: 4 }

        Rectangle {
            width: parent.width
            height: 36
            radius: 10
            color: pinHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.isPinned ? "keep" : "push_pin"
                    font.pixelSize: 16
                    color: Theme.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isPinned ? "Unpin from Dock" : "Pin to Dock"
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                    color: Theme.on_surface
                }
            }

            MouseArea {
                id: pinHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isPinned) {
                        DockBackend.unpinApp(root.desktopId);
                    } else {
                        DockBackend.pinApp(root.desktopId);
                    }
                    root.closeRequested();
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 10
            visible: root.isRunning
            color: newHover.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 10

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "add"
                    font.pixelSize: 16
                    color: Theme.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "New Window"
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                    color: Theme.on_surface
                }
            }

            MouseArea {
                id: newHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DockBackend.launchApp(root.desktopId);
                    root.closeRequested();
                }
            }
        }
    }
}
