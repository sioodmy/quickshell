import Quickshell
import QtQuick
import "../theme"
import qs.services

/**
 * Vertical workspace track for the dock.
 *
 * Outer pill stretches between clock and stats. Workspace groups (app pills)
 * and empty-workspace dots are stacked and vertically centered inside.
 *
 * Layout is driven by explicit metrics so pill size, icon centering, and the
 * sliding active highlight stay in sync — no magic height offsets.
 */
Item {
    id: root

    // --- Public API ---
    property var runningApps: []
    property Item draggingApp: null
    property int dropHoverWsId: -1
    readonly property bool dropHoverActive: dropHoverWsId >= 0

    signal appHover(string name, real itemY, string winId)
    signal appHoverEnd()
    signal appContextMenu(var itemData, real itemY)
    signal dragStarted(Item item, string winId, real globalX, real globalY)
    signal dragUpdated(real globalX, real globalY)
    signal dragEnded(real globalX, real globalY)

    // --- Metrics (single source of truth) ---
    readonly property int trackWidth: 30
    readonly property int trackInset: 3
    readonly property int pillWidth: trackWidth - trackInset * 2
    readonly property int iconSize: 22
    readonly property int iconSpacing: 3
    readonly property int pillPadV: 8
    readonly property int workspaceGap: 6
    readonly property int maxApps: 4
    readonly property int overflowHeight: 14
    readonly property int emptyDotSize: 8
    readonly property int emptySlotHeight: 14

    width: trackWidth
    // height is set by anchors from Dock

    Rectangle {
        id: track
        anchors.fill: parent
        radius: width / 2
        color: Theme.surface_container
        // Let drop-target wobble spill slightly outside the track
        clip: root.draggingApp === null

        // Inactive backgrounds
        Repeater {
            model: NiriService.workspaces
            Rectangle {
                property var wsItem: wsRepeater.itemAt(index)
                
                width: root.pillWidth
                height: wsItem ? wsItem.height : 0
                x: root.trackInset
                y: wsColumn.y + (wsItem ? wsItem.y : 0)
                radius: width / 2
                color: Theme.surface_container_high
                opacity: (wsItem && wsItem.showPill) ? 1 : 0
                scale: wsItem ? wsItem.scale : 1
                rotation: wsItem ? wsItem.rotation : 0
                
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        // Sliding active highlight — same width as pills, follows active item
        Rectangle {
            id: highlight
            width: root.pillWidth
            height: Math.max(activeTargetHeight, animHeight)
            x: root.trackInset
            y: activeTargetY
            radius: width / 2
            color: Theme.secondary_container
            opacity: root.activeWsItem ? 1 : 0

            property real animHeight: activeTargetHeight

            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on animHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Column {
            id: wsColumn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.pillWidth
            spacing: root.workspaceGap
            z: 1

            Repeater {
                id: wsRepeater
                model: NiriService.workspaces

                WorkspaceItem {
                    id: wsItem

                    required property var model
                    required property int index

                    width: root.pillWidth

                    wsId: model.id
                    wsName: model.name || ""
                    isFocused: model.isFocused
                    isActive: model.isActive
                    runningApps: root.runningApps

                    iconSize: root.iconSize
                    iconSpacing: root.iconSpacing
                    pillPadV: root.pillPadV
                    maxApps: root.maxApps
                    overflowHeight: root.overflowHeight
                    emptyDotSize: root.emptyDotSize
                    emptySlotHeight: root.emptySlotHeight
                    isDragTarget: root.draggingApp !== null
                    isDropHovered: root.dropHoverWsId === wsItem.wsId
                    draggingApp: root.draggingApp

                    // Own background only when occupied & inactive (active uses sliding highlight)
                    showPill: hasApps && !isFocused && !isActive

                    onBecameActive: function(fromFocus) {
                        if (fromFocus || !root.activeWsItem)
                            root.activeWsItem = wsItem
                    }

                    onAppHover: function(name, itemY, winId) {
                        root.appHover(name, itemY, winId)
                    }
                    onAppHoverEnd: root.appHoverEnd()
                    onAppContextMenu: function(itemData, itemY) {
                        root.appContextMenu(itemData, itemY)
                    }
                    onDragStarted: function(item, winId, gx, gy) {
                        root._lastDragGX = gx
                        root._lastDragGY = gy
                        root._updateDropHover(gx, gy)
                        root.dragStarted(item, winId, gx, gy)
                    }
                    onDragUpdated: function(gx, gy) {
                        root._lastDragGX = gx
                        root._lastDragGY = gy
                        root._updateDropHover(gx, gy)
                        root.dragUpdated(gx, gy)
                    }
                    onDragEnded: function(gx, gy) {
                        root._finishDrag(gx, gy, wsItem.wsId)
                    }
                }
            }
        }
    }

    // --- Active workspace tracking ---
    property Item activeWsItem: null

    readonly property real activeTargetY: {
        if (!activeWsItem)
            return root.trackInset
        return wsColumn.y + activeWsItem.y
    }
    readonly property real activeTargetHeight: activeWsItem ? activeWsItem.height : 0

    // Last drag position in scene coords — kept in sync by dragUpdated so drop
    // hit-testing does not depend on DragHandler.translation at release.
    property real _lastDragGX: 0
    property real _lastDragGY: 0

    function _workspaceAt(gx, gy) {
        var local = wsColumn.mapFromItem(null, gx, gy)
        var halfGap = root.workspaceGap / 2
        for (var i = 0; i < wsRepeater.count; i++) {
            var item = wsRepeater.itemAt(i)
            if (!item)
                continue
            var top = item.y - halfGap
            var bottom = item.y + item.height + halfGap
            if (local.y >= top && local.y <= bottom)
                return item
        }
        return null
    }

    function _updateDropHover(gx, gy) {
        var item = root._workspaceAt(gx, gy)
        root.dropHoverWsId = item ? item.wsId : -1
    }

    function _finishDrag(globalX, globalY, fromWsId) {
        var gx = root._lastDragGX
        var gy = root._lastDragGY
        var winId = root.draggingWinId
        var target = root._workspaceAt(gx, gy)

        if (target && target.wsId !== fromWsId && winId !== "") {
            target.playDropAccept()
            // Prefer workspace name for the CLI. Unique ids are not accepted as
            // bare numbers (those are treated as index), so fall back to IPC Id.
            if (target.wsName && target.wsName.length > 0) {
                Quickshell.execDetached({
                    command: [
                        "niri", "msg", "action", "move-window-to-workspace",
                        target.wsName, "--window-id", winId, "--focus", "false"
                    ]
                })
            } else {
                NiriService.sendRawAction({
                    "MoveWindowToWorkspace": {
                        "window_id": Number(winId),
                        "reference": { "Id": Number(target.wsId) },
                        "focus": false
                    }
                })
            }
        }
        root.dropHoverWsId = -1
        root.dragEnded(gx, gy)
    }

    // Set by parent while a drag is in progress (window id being moved)
    property string draggingWinId: ""
}
