import QtQuick
import "../theme"
import qs.services
import "../dock"

/**
 * Horizontal workspace item for the notch.
 * Adapted from dock/WorkspaceItem.qml for horizontal layout.
 */
Item {
    id: root

    property int wsId: -1
    property string wsName: ""
    property bool isFocused: false
    property bool isActive: false
    property var runningApps: []
    property bool isDragTarget: false
    property bool isDropHovered: false
    property Item draggingApp: null
    property bool showPill: false

    property int iconSize: 18
    property int iconSpacing: 3
    property int pillPadH: 7
    property int maxApps: 3
    property int overflowWidth: 14
    property int emptyDotSize: 6
    property int emptySlotWidth: 14

    signal becameActive(bool fromFocus)

    readonly property var wsApps: {
        if (!runningApps) return []
        return runningApps.filter(function(app) {
            return app.minWorkspaceId === root.wsId
        })
    }
    readonly property bool hasApps: wsApps.length > 0
    readonly property int visibleCount: hasApps ? Math.min(wsApps.length, maxApps) : 0
    readonly property int hiddenCount: hasApps ? Math.max(0, wsApps.length - visibleCount) : 0

    width: {
        if (!hasApps)
            return (isFocused || isActive) ? height : emptySlotWidth
        var w = pillPadH * 2 + visibleCount * iconSize + Math.max(0, visibleCount - 1) * iconSpacing
        if (hiddenCount > 0)
            w += iconSpacing + overflowWidth
        return w
    }

    clip: hasApps
    transformOrigin: Item.Center

    onIsFocusedChanged: { if (isFocused) becameActive(true) }
    onIsActiveChanged: { if (isActive) becameActive(false) }
    Component.onCompleted: {
        if (isFocused) becameActive(true)
        else if (isActive) becameActive(false)
    }

    // Inactive pill background
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (wsHover.hovered)
                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
            if (root.showPill)
                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    HoverHandler { id: wsHover }

    // Empty-workspace indicator dot
    Rectangle {
        anchors.centerIn: parent
        height: root.emptyDotSize
        width: height
        radius: height / 2
        color: Theme.on_surface_variant
        opacity: 0.35
        visible: !root.hasApps && !root.isFocused && !root.isActive
    }

    // App icons row
    Row {
        id: appRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.pillPadH
        height: parent.height
        spacing: root.iconSpacing
        visible: root.hasApps

        Repeater {
            model: root.visibleCount
            Item {
                id: slot
                height: appRow.height
                width: root.iconSize
                required property int index

                DockItem {
                    id: appItem
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    itemData: root.wsApps[slot.index] || ({})
                }
            }
        }

        // Overflow badge
        Item {
            height: appRow.height
            width: root.hiddenCount > 0 ? root.overflowWidth : 0
            visible: root.hiddenCount > 0
            Rectangle {
                anchors.centerIn: parent
                height: parent.height - 6
                width: parent.width
                radius: width / 2
                color: Qt.alpha(Theme.on_surface_variant, 0.14)
                Text {
                    anchors.centerIn: parent
                    text: "+" + root.hiddenCount
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 8; weight: Font.DemiBold }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: NiriService.focusWorkspaceById(root.wsId)
    }
}
