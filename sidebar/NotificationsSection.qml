import QtQuick
import Quickshell
import qs.theme
import qs.services

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 10

    property int pageSize: 5
    property bool showAll: false

    readonly property var allItems: NotificationHistory.items
    readonly property var visibleItems: showAll ? allItems : allItems.slice(0, pageSize)
    readonly property bool hasMore: allItems.length > pageSize

    property double now: Date.now()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    function relTime(t) {
        let diff = Math.max(0, root.now - t);
        let m = Math.floor(diff / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        let h = Math.floor(m / 60);
        if (h < 24) return h + "h";
        return Math.floor(h / 24) + "d";
    }

    // Header
    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications"
            color: Theme.on_surface
            font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.allItems.length > 0
            text: "Clear all"
            color: clearMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationHistory.clear()
            }
        }
    }

    Text {
        visible: root.allItems.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "No notifications"
        color: Theme.on_surface_variant
        font { family: "Google Sans"; pixelSize: 13 }
        topPadding: 8
        bottomPadding: 8
    }

    Repeater {
        model: root.visibleItems

        Rectangle {
            id: card
            required property int index
            required property var modelData

            width: parent.width
            radius: 18
            color: Theme.surface_container_high
            height: cardCol.implicitHeight + 24

            readonly property string iconSource: {
                if (modelData.image && modelData.image.length > 0 && !modelData.image.startsWith("image://qsimage/"))
                    return modelData.image;
                if (modelData.appIcon && modelData.appIcon.length > 0)
                    return Quickshell.iconPath(modelData.appIcon, true);
                return "";
            }

            Column {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 3

                Item {
                    width: parent.width
                    height: 20

                    Rectangle {
                        id: avatar
                        width: 18
                        height: 18
                        radius: 9
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.primary_container
                        visible: card.iconSource === ""

                        Text {
                            anchors.centerIn: parent
                            text: (card.modelData.appName || "?").charAt(0).toUpperCase()
                            color: Theme.on_primary_container
                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Bold }
                        }
                    }

                    Image {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        source: card.iconSource
                        visible: card.iconSource !== ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 28
                        anchors.right: timeLabel.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.appName || "Notification"
                        color: Theme.primary
                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        elide: Text.ElideRight
                    }

                    Text {
                        id: timeLabel
                        anchors.right: removeBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.relTime(card.modelData.time)
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 11 }
                    }

                    Text {
                        id: removeBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2715"
                        color: removeMouse.containsMouse ? Theme.critical : Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 12 }

                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationHistory.removeAt(card.index)
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.modelData.summary || ""
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 14; weight: Font.DemiBold }
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.modelData.body || ""
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13 }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        visible: root.hasMore
        width: parent.width
        height: 34
        radius: 17
        color: showMoreMouse.containsMouse
            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
            : Theme.surface_container_high

        Text {
            anchors.centerIn: parent
            text: root.showAll
                ? "Show less"
                : ("Show " + (root.allItems.length - root.pageSize) + " more")
            color: showMoreMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
        }

        MouseArea {
            id: showMoreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showAll = !root.showAll
        }
    }
}
