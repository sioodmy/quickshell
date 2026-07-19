import QtQuick
import "../theme"
import qs.services

/**
 * One workspace entry in the workspace bar.
 *
 * Occupied: pill-sized column of centered app icons (+ optional overflow badge).
 * Empty + inactive: small centered dot.
 * Empty + active: circular slot (highlight drawn by parent).
 */
Item {
    id: root

    property int wsId: -1
    property bool isFocused: false
    property bool isActive: false
    property var runningApps: []
    property bool isDragTarget: false
    property bool showPill: false

    property int iconSize: 20
    property int iconSpacing: 4
    property int pillPadV: 6
    property int maxApps: 4
    property int overflowHeight: 14
    property int emptyDotSize: 8
    property int emptySlotHeight: 14

    signal becameActive(bool fromFocus)
    signal appHover(string name, real itemY, string winId)
    signal appHoverEnd()
    signal appContextMenu(var itemData, real itemY)
    signal dragStarted(Item item, string winId, real globalX, real globalY)
    signal dragUpdated(real globalX, real globalY)
    signal dragEnded(real globalX, real globalY)

    readonly property var wsApps: {
        if (!runningApps)
            return []
        return runningApps.filter(function(app) {
            return app.minWorkspaceId === root.wsId
        })
    }
    readonly property bool hasApps: wsApps.length > 0
    readonly property int visibleCount: hasApps ? Math.min(wsApps.length, maxApps) : 0
    readonly property int hiddenCount: hasApps ? Math.max(0, wsApps.length - visibleCount) : 0

    // Explicit height — no implicitHeight + margin spaghetti
    height: {
        if (!hasApps)
            return (isFocused || isActive) ? width : emptySlotHeight
        var h = pillPadV * 2 + visibleCount * iconSize + Math.max(0, visibleCount - 1) * iconSpacing
        if (hiddenCount > 0)
            h += iconSpacing + overflowHeight
        return h
    }

    clip: hasApps

    onIsFocusedChanged: {
        if (isFocused)
            becameActive(true)
    }
    onIsActiveChanged: {
        if (isActive)
            becameActive(false)
    }
    Component.onCompleted: {
        if (isFocused)
            becameActive(true)
        else if (isActive)
            becameActive(false)
    }

    // Inactive occupied pill background
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.surface_container_high
        opacity: root.showPill ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // Hover wash
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: wsHover.hovered
            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    HoverHandler { id: wsHover }

    // Empty-workspace indicator
    Rectangle {
        anchors.centerIn: parent
        width: root.isDragTarget ? 14 : root.emptyDotSize
        height: width
        radius: width / 2
        color: Theme.on_surface_variant
        opacity: root.isDragTarget ? 0.8 : 0.35
        visible: !root.hasApps && !root.isFocused && !root.isActive
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // App icons + overflow — column spans pill width so every child can center
    Column {
        id: appColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.pillPadV
        width: parent.width
        spacing: root.iconSpacing
        visible: root.hasApps

        Repeater {
            model: root.visibleCount

            Item {
                id: slot
                width: appColumn.width
                height: root.iconSize

                required property int index

                DockItem {
                    id: appItem
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    itemData: root.wsApps[slot.index] || ({})

                    onHoverChanged: function(hovered) {
                        if (hovered) {
                            var wins = appItem.itemData.windows || []
                            var wsWins = wins.filter(function(w) {
                                return w.workspaceId === root.wsId
                            })
                            var winId = wsWins.length > 0 ? wsWins[0].id : (wins.length > 0 ? wins[0].id : "")
                            var globalY = appItem.mapToItem(null, 0, 0).y
                            root.appHover(appItem.appName, globalY, winId)
                        } else {
                            root.appHoverEnd()
                        }
                    }

                    onContextMenuRequested: {
                        var globalY = appItem.mapToItem(null, 0, 0).y
                        root.appContextMenu(appItem.itemData, globalY)
                    }

                    onDragStarted: {
                        var wins = (appItem.itemData.windows || []).filter(function(w) {
                            return w.workspaceId === root.wsId
                        })
                        var winId = wins.length > 0 ? wins[0].id : ""
                        var g = appItem.mapToItem(null, appItem.width / 2, appItem.height / 2)
                        root.dragStarted(appItem, winId, g.x, g.y)
                    }
                    onDragUpdated: function(gx, gy) {
                        root.dragUpdated(gx, gy)
                    }
                    onDragEnded: function(gx, gy) {
                        root.dragEnded(gx, gy)
                    }
                }
            }
        }

        Item {
            width: appColumn.width
            height: root.hiddenCount > 0 ? root.overflowHeight : 0
            visible: root.hiddenCount > 0

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 8
                height: parent.height
                radius: height / 2
                color: Qt.rgba(
                    Theme.on_surface_variant.r,
                    Theme.on_surface_variant.g,
                    Theme.on_surface_variant.b,
                    0.14
                )

                Text {
                    anchors.centerIn: parent
                    text: "+" + root.hiddenCount
                    color: Theme.on_surface_variant
                    font {
                        family: "Google Sans"
                        pixelSize: 9
                        weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // Click empty/padding area to focus workspace (icons handle their own clicks)
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: NiriService.focusWorkspaceById(root.wsId)
    }
}
