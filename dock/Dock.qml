import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../theme"
import qs.services
import qs.components

/**
 * Horizontal application dock functioning as a TopBar.
 *
 * Layout:
 * - Solid background extending full width.
 * - Left: Launcher icon + clock.
 * - Center: WorkspaceBar — workspaces with running apps and sliding highlight.
 * - Right: System stats.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: dockWindow

        required property var modelData
        screen: modelData

        // --- Layer Shell ---
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-dock"
        WlrLayershell.exclusiveZone: 28
        WlrLayershell.keyboardFocus: (typeof dynamicIsland !== "undefined" && dynamicIsland.requiresKeyboard) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
        }

        // Make the window tall enough to fit menus, but transparent
        color: "transparent"
        implicitHeight: 400

        // Allow click-through everywhere except the bar and popups
        mask: Region {
            item: inputMaskContainer
        }

        Item {
            id: dockContent
            anchors.fill: parent

            // --- State for context menu ---
            property bool contextMenuOpen: false
            property string contextDesktopId: ""
            property string contextAppName: ""
            property bool contextIsPinned: false
            property bool contextIsRunning: false
            property real contextItemX: 0

            property Item draggingApp: null
            property string draggingWinId: ""
            property real dragX: 0
            property real dragY: 0
            property real dragVX: 0
            property real _prevDragX: 0
            property bool dropHoverActive: workspaceBar.dropHoverActive

            onDragXChanged: {
                dragVX = dragX - _prevDragX
                _prevDragX = dragX
            }

            property var runningApps: {
                var items = DockBackend.dockModel;
                return items ? items.filter(function(item) { return item.running; }) : [];
            }

            // The visible background of the bar (floating notch)
            Rectangle {
                id: notchBg
                height: dockContent.animHeight
                width: dockContent.animWidth
                anchors.horizontalCenter: parent.horizontalCenter
                y: -14
                radius: dockContent.animRadius
                color: "#000000"
                border.width: 1
                border.color: "#1e1e1e"
                z: -10
            }

            // Recording indicator — same layer / exclusive zone as the bar,
            // glued to the top edge to the right of the notch.
            DockRecordingIndicator {
                id: recordingIndicator
                anchors.left: notchBg.right
                anchors.leftMargin: 8
                z: -10
            }

            // Defines exactly what areas block clicks
            Item {
                id: inputMaskContainer
                y: 0
                x: {
                    var left = notchBg.x;
                    if (contextMenu.visible) left = Math.min(left, contextMenu.x);
                    return left;
                }
                height: {
                    var h = dynamicIsland.isDockHidden ? dynamicIsland.implicitHeight + 16 : 28;
                    if (contextMenu.visible) h = Math.max(h, contextMenu.y + contextMenu.height + 4);
                    // Keep a bit of vertical slack while dragging so the
                    // pointer doesn't leave the layer-shell input region.
                    if (dockContent.draggingApp !== null) h = Math.max(h, 56);
                    return h;
                }
                width: {
                    var right = notchBg.x + notchBg.width;
                    if (recordingIndicator.visible)
                        right = Math.max(right, recordingIndicator.x + recordingIndicator.width);
                    if (contextMenu.visible) right = Math.max(right, contextMenu.x + contextMenu.width + 4);
                    return right - x;
                }


            }

            Row {
                id: contentRow
                height: 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 6
                opacity: dynamicIsland.isDockHidden ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                // 1. Time (DockClock)
                DockClock {
                    id: clockModule
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 2. Workspaces
                Item {
                    id: workspaceContainer
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    
                    width: dynamicIsland.isDockHidden ? 0 : workspaceBar.implicitWidth
                    
                    clip: true
                    
                    WorkspaceBar {
                        id: workspaceBar
                        anchors.centerIn: parent

                    runningApps: dockContent.runningApps
                    draggingApp: dockContent.draggingApp
                    draggingWinId: dockContent.draggingWinId

                    onAppContextMenu: function(itemData, itemX) {
                        dockContent.contextDesktopId = itemData.desktopId || ""
                        dockContent.contextAppName = itemData.name || ""
                        dockContent.contextIsPinned = !!itemData.pinned
                        dockContent.contextIsRunning = !!itemData.running
                        dockContent.contextItemX = itemX - dockContent.mapToItem(null, 0, 0).x
                        dockContent.contextMenuOpen = true
                    }
                    onDragStarted: function(item, winId, gx, gy) {
                        var local = dockContent.mapFromItem(null, gx, gy)
                        dockContent.draggingApp = item
                        dockContent.draggingWinId = winId
                        dockContent.dragX = local.x
                        dockContent.dragY = local.y
                        dockContent._prevDragX = local.x
                        dockContent.dragVX = 0
                    }
                    onDragUpdated: function(gx, gy) {
                        var local = dockContent.mapFromItem(null, gx, gy)
                        dockContent.dragX = local.x
                        dockContent.dragY = local.y
                    }
                    onDragEnded: function(gx, gy) {
                        dockContent.draggingApp = null
                        dockContent.draggingWinId = ""
                        dockContent.dragVX = 0
                    }
                }
                }

                DockFileShare {
                    id: dockShareIcon
                    anchors.verticalCenter: parent.verticalCenter
                }

                DockPomodoroWidget {
                    id: pomodoroWidget
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 3. Sys Stats
                DockSystemStats {
                    id: statsModule
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: islandClipper
                anchors.horizontalCenter: parent.horizontalCenter
                y: -14
                width: dockContent.animWidth
                height: dockContent.animHeight
                radius: dockContent.animRadius
                color: "transparent"
                clip: true
                z: 10

                DynamicIsland {
                    id: dynamicIsland
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: (activeMode === "osd" || activeMode === "charging") ? 0 : 22
                    osdDockWidth: (activeMode === "osd" || activeMode === "charging") ? dockContent.dockTargetWidth : dockContent.dockTargetWidth - 32
                    osdDockHeight: dockContent.dockTargetHeight
                    opacity: isDockHidden ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }

            // === CONTEXT MENU ===
            Rectangle {
                id: contextMenu
                visible: dockContent.contextMenuOpen
                opacity: visible ? 1.0 : 0.0
                scale: visible ? 1.0 : 0.85

                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

                x: dockContent.contextItemX
                y: 56

                width: 170
                height: contextMenuCol.implicitHeight + 16
                radius: 16
                color: Theme.surface_container

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#30000000"
                    shadowVerticalOffset: 4
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
                        text: dockContent.contextAppName || ""
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
                                icon: (dockContent.contextIsPinned !== undefined ? dockContent.contextIsPinned : false) ? "keep" : "push_pin"
                                font.pixelSize: 16
                                color: Theme.on_surface_variant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (dockContent.contextIsPinned !== undefined ? dockContent.contextIsPinned : false) ? "Unpin from Dock" : "Pin to Dock"
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
                                if (dockContent.contextIsPinned) {
                                    DockBackend.unpinApp(dockContent.contextDesktopId);
                                } else {
                                    DockBackend.pinApp(dockContent.contextDesktopId);
                                }
                                dockContent.contextMenuOpen = false;
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 10
                        visible: dockContent.contextIsRunning !== undefined ? dockContent.contextIsRunning : false
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
                                DockBackend.launchApp(dockContent.contextDesktopId);
                                dockContent.contextMenuOpen = false;
                            }
                        }
                    }
                }
            }

            Timer {
                interval: 3000
                running: dockContent.contextMenuOpen
                onTriggered: dockContent.contextMenuOpen = false
            }

            // Click-away dismiss via a global area outside the bar
            MouseArea {
                anchors.fill: parent
                visible: dockContent.contextMenuOpen !== undefined ? dockContent.contextMenuOpen : false
                z: -1
                onClicked: dockContent.contextMenuOpen = false
            }

            // Floating drag proxy — lagged jelly follow + continuous wobble
            Item {
                id: dragProxy

                property real followX: dockContent.dragX
                property real followY: dockContent.dragY
                property bool active: dockContent.draggingApp !== null
                // Animations write here so they don't break the scale binding
                property real popBoost: 1.0
                property real wobbleSpin: 0

                width: 40
                height: 40
                x: followX - width / 2
                y: followY - height / 2
                z: 100
                visible: active
                opacity: active ? 1 : 0
                transformOrigin: Item.Center
                rotation: wobbleSpin

                scale: {
                    var base = 0.4
                    if (active)
                        base = dockContent.dropHoverActive ? 1.35 : 1.15
                    return base * popBoost
                }

                onActiveChanged: {
                    if (active) {
                        followBehaviorX.enabled = false
                        followBehaviorY.enabled = false
                        followX = dockContent.dragX
                        followY = dockContent.dragY
                        followBehaviorX.enabled = true
                        followBehaviorY.enabled = true
                        popBoost = 1.0
                        grabPop.restart()
                        wobbleLoop.restart()
                    } else {
                        wobbleLoop.stop()
                        wobbleSpin = 0
                        popBoost = 1.0
                    }
                }

                Connections {
                    target: dockContent
                    function onDragXChanged() {
                        if (dragProxy.active)
                            dragProxy.followX = dockContent.dragX
                    }
                    function onDragYChanged() {
                        if (dragProxy.active)
                            dragProxy.followY = dockContent.dragY
                    }
                }

                Behavior on followX {
                    id: followBehaviorX
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on followY {
                    id: followBehaviorY
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.8
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 90 } }

                SequentialAnimation {
                    id: grabPop
                    NumberAnimation {
                        target: dragProxy
                        property: "popBoost"
                        to: 1.25
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: dragProxy
                        property: "popBoost"
                        to: 1.0
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.4
                    }
                }

                SequentialAnimation {
                    id: wobbleLoop
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: dragProxy
                        property: "wobbleSpin"
                        to: 16
                        duration: 90
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: dragProxy
                        property: "wobbleSpin"
                        to: -14
                        duration: 160
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: dragProxy
                        property: "wobbleSpin"
                        to: 10
                        duration: 130
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: dragProxy
                        property: "wobbleSpin"
                        to: -6
                        duration: 110
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: dragProxy
                        property: "wobbleSpin"
                        to: 0
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 14
                    height: parent.height + 14
                    radius: width / 2
                    color: Qt.alpha(Theme.primary, dockContent.dropHoverActive ? 0.45 : 0.22)
                    scale: dockContent.dropHoverActive ? 1.2 : 1.0
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.88
                    height: parent.height * 0.88
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    source: {
                        if (!dockContent.draggingApp)
                            return ""
                        var icon = dockContent.draggingApp.itemData
                            ? (dockContent.draggingApp.itemData.icon || "")
                            : ""
                        if (!icon || icon === "")
                            return "image://icon/application-x-executable"
                        if (icon.startsWith("/"))
                            return "file://" + icon
                        return "image://icon/" + icon
                    }
                }
            } // end draggingOverlay

            property real dockTargetWidth: (clockModule ? clockModule.implicitWidth : 0) + (statsModule ? statsModule.implicitWidth : 0) + (dockShareIcon ? dockShareIcon.implicitWidth : 0) + (pomodoroWidget ? pomodoroWidget.implicitWidth : 0) + (workspaceBar ? workspaceBar.implicitWidth : 0) + (pomodoroWidget && pomodoroWidget.isVisible ? 24 : 18) + 16
            property real dockTargetHeight: 28 + 14
            property real dockTargetRadius: 14

            property real islandTargetWidth: dynamicIsland ? ((dynamicIsland.activeMode === "osd" || dynamicIsland.activeMode === "charging") ? dockTargetWidth : dynamicIsland.implicitWidth + 32) : 0
            property real islandTargetHeight: dynamicIsland ? ((dynamicIsland.activeMode === "osd" || dynamicIsland.activeMode === "charging") ? dockTargetHeight : dynamicIsland.implicitHeight + 16 + 14) : 0
            property real islandTargetRadius: dynamicIsland ? ((dynamicIsland.activeMode === "osd" || dynamicIsland.activeMode === "charging") ? dockTargetRadius : 20) : 20

            property real animWidth: dynamicIsland && dynamicIsland.isDockHidden ? islandTargetWidth : dockTargetWidth
            property real animHeight: dynamicIsland && dynamicIsland.isDockHidden ? islandTargetHeight : dockTargetHeight
            property real animRadius: dynamicIsland && dynamicIsland.isDockHidden ? islandTargetRadius : dockTargetRadius

            Behavior on animWidth { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
            Behavior on animHeight { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }
            Behavior on animRadius { SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 } }

        }
    }
}
