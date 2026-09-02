import Quickshell
import QtQuick
import "../theme"
import qs.services
import "../dock"

/**
 * Horizontal workspace bar for the dynamic notch.
 *
 * A horizontal adaptation of dock/WorkspaceBar.qml.  Workspace groups
 * (app-icon pills) are laid out in a Row and centered inside the notch.
 * The sliding active highlight follows the focused workspace.
 */
Item {
    id: root

    property var runningApps: DockBackend.dockModel

    readonly property int trackHeight: 28
    readonly property int trackInset: 3
    readonly property int pillHeight: trackHeight - trackInset * 2
    readonly property int iconSize: 18
    readonly property int iconSpacing: 3
    readonly property int pillPadH: 7
    readonly property int workspaceGap: 5
    readonly property int maxApps: 3
    readonly property int overflowWidth: 14
    readonly property int emptyDotSize: 6
    readonly property int emptySlotWidth: 14

    height: trackHeight
    implicitWidth: wsRow.implicitWidth + trackInset * 2

    // Sliding active highlight
    Rectangle {
        id: highlight
        height: root.pillHeight
        width: activeTargetWidth
        y: root.trackInset
        x: activeTargetX
        radius: height / 2
        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.15)
        opacity: root.activeWsItem ? 1 : 0
        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        height: root.pillHeight
        spacing: root.workspaceGap

        Repeater {
            id: wsRepeater
            model: NiriService.workspaces

            HorizontalWorkspaceItem {
                id: wsItem

                required property var model
                required property int index

                height: root.pillHeight

                wsId: model.id
                wsName: model.name || ""
                isFocused: model.isFocused
                isActive: model.isActive
                runningApps: root.runningApps

                iconSize: root.iconSize
                iconSpacing: root.iconSpacing
                pillPadH: root.pillPadH
                maxApps: root.maxApps
                overflowWidth: root.overflowWidth
                emptyDotSize: root.emptyDotSize
                emptySlotWidth: root.emptySlotWidth
                isDragTarget: false
                isDropHovered: false
                draggingApp: null

                showPill: hasApps && !isFocused && !isActive

                onBecameActive: function(fromFocus) {
                    if (fromFocus || !root.activeWsItem)
                        root.activeWsItem = wsItem
                }
            }
        }
    }

    property Item activeWsItem: null
    readonly property real activeTargetX: {
        if (!activeWsItem) return root.trackInset
        return wsRow.x + activeWsItem.x
    }
    readonly property real activeTargetWidth: activeWsItem ? activeWsItem.width : 0
}
