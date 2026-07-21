import QtQuick
import "../theme"
import qs.services

/**
 * One workspace entry in the workspace bar.
 *
 * Occupied: pill-shaped column of app icons (+ optional overflow badge).
 * Empty + inactive: centered dot.
 * Empty + active: circular slot (highlight drawn by parent).
 *
 * During window drag: scales up, shakes, and shows a glow ring when hovered.
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

    height: {
        if (!hasApps)
            return (isFocused || isActive) ? width : emptySlotHeight
        var h = pillPadV * 2 + visibleCount * iconSize + Math.max(0, visibleCount - 1) * iconSpacing
        if (hiddenCount > 0)
            h += iconSpacing + overflowHeight
        return h
    }

    // Don't clip while dragging so scale/glow can spill out of the pill
    clip: hasApps && !isDragTarget

    transformOrigin: Item.Center

    // Base scale stays declarative; animations write to boost/spin only
    // so they never break the binding.
    property real animBoost: 1.0
    property real animSpin: 0

    scale: {
        var base = 1.0
        if (isDropHovered)
            base = hasApps ? 1.28 : 1.55
        else if (isDragTarget)
            base = 1.06
        return base * animBoost
    }
    rotation: animSpin

    Behavior on scale {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 2.6
        }
    }

    onIsDropHoveredChanged: {
        if (isDropHovered) {
            shakeLoop.restart()
        } else {
            shakeLoop.stop()
            animSpin = 0
        }
    }

    onIsDragTargetChanged: {
        if (!isDragTarget) {
            shakeLoop.stop()
            animSpin = 0
            animBoost = 1.0
        }
    }

    function playDropAccept() {
        shakeLoop.stop()
        animSpin = 0
        acceptPop.restart()
    }

    // Continuous shake while this slot is the drop target
    SequentialAnimation {
        id: shakeLoop
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "animSpin"
            to: 14
            duration: 70
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "animSpin"
            to: -14
            duration: 140
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "animSpin"
            to: 10
            duration: 110
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "animSpin"
            to: -6
            duration: 90
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "animSpin"
            to: 0
            duration: 80
            easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 60 }
    }

    // Big bounce when a window lands here
    SequentialAnimation {
        id: acceptPop
        NumberAnimation {
            target: root
            property: "animBoost"
            to: 1.35
            duration: 100
            easing.type: Easing.OutCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "animBoost"
                to: 1.0
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 3.2
            }
            SequentialAnimation {
                NumberAnimation {
                    target: root
                    property: "animSpin"
                    to: -18
                    duration: 80
                }
                NumberAnimation {
                    target: root
                    property: "animSpin"
                    to: 14
                    duration: 100
                }
                NumberAnimation {
                    target: root
                    property: "animSpin"
                    to: 0
                    duration: 180
                    easing.type: Easing.OutBack
                }
            }
        }
    }

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

    // Hover / drop wash
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: {
            if (root.isDropHovered)
                return Qt.alpha(Theme.primary, 0.35)
            if (wsHover.hovered)
                return Qt.alpha(Theme.on_surface, 0.08)
            return "transparent"
        }
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    // Glow ring — the obvious "you can drop here" signal
    Rectangle {
        id: dropRing
        anchors.centerIn: parent
        width: parent.width + (root.isDropHovered ? 18 : (root.isDragTarget ? 10 : 0))
        height: parent.height + (root.isDropHovered ? 18 : (root.isDragTarget ? 10 : 0))
        radius: width / 2
        color: "transparent"
        border.width: root.isDropHovered ? 3 : (root.isDragTarget ? 2 : 0)
        border.color: Theme.primary
        property real pulse: 1.0
        opacity: {
            if (!root.isDragTarget && !root.isDropHovered)
                return 0
            if (root.isDropHovered)
                return pulse
            return 0.45
        }
        visible: root.isDragTarget || root.isDropHovered
        z: -1

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }
        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation { duration: 120 } }

        SequentialAnimation on pulse {
            running: root.isDropHovered
            loops: Animation.Infinite
            NumberAnimation { to: 1.0; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.4; duration: 280; easing.type: Easing.InOutSine }
        }
    }

    HoverHandler { id: wsHover }

    // Empty-workspace indicator
    Rectangle {
        anchors.centerIn: parent
        width: {
            if (root.isDropHovered)
                return 18
            if (root.isDragTarget)
                return 13
            return root.emptyDotSize
        }
        height: width
        radius: width / 2
        color: root.isDropHovered ? Theme.primary : Theme.on_surface_variant
        opacity: root.isDropHovered ? 1.0 : (root.isDragTarget ? 0.85 : 0.35)
        visible: !root.hasApps && !root.isFocused && !root.isActive

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.8 }
        }
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

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
                    opacity: root.draggingApp === appItem ? 0.15 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 100 } }

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
                            return Number(w.workspaceId) === Number(root.wsId)
                        })
                        var winId = wins.length > 0
                            ? String(wins[0].id)
                            : (appItem.itemData.windows && appItem.itemData.windows.length > 0
                                ? String(appItem.itemData.windows[0].id) : "")
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
                color: Qt.alpha(Theme.on_surface_variant, 0.14)

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

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: NiriService.focusWorkspaceById(root.wsId)
    }
}
