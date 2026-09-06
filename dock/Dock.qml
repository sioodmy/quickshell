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

            // Click-away dismiss via a global area outside the bar
            MouseArea {
                anchors.fill: parent
                visible: dockContent.contextMenuOpen
                z: -1
                onClicked: dockContent.contextMenuOpen = false
            }

            // === CONTEXT MENU ===
            DockContextMenu {
                id: contextMenu
                isOpen: dockContent.contextMenuOpen
                itemX: dockContent.contextItemX
                appName: dockContent.contextAppName
                desktopId: dockContent.contextDesktopId
                isPinned: dockContent.contextIsPinned
                isRunning: dockContent.contextIsRunning
                onCloseRequested: dockContent.contextMenuOpen = false
            }

            // === FLOATING DRAG PROXY ===
            DockDragProxy {
                id: dragProxy
                dragX: dockContent.dragX
                dragY: dockContent.dragY
                draggingApp: dockContent.draggingApp
                dropHoverActive: dockContent.dropHoverActive
            }

            DropArea {
                id: dragQueenDropArea
                anchors.fill: notchBg

                onEntered: function (drag) {
                    if (drag.hasUrls) {
                        drag.accept(Qt.CopyAction);
                        if (typeof dynamicIsland !== "undefined") {
                            dynamicIsland._dragQueenDragHover = true;
                            if (dynamicIsland.activeMode === "dock")
                                dynamicIsland.activeMode = "drag_queen";
                        }
                        return;
                    }
                    if (drag.hasText && String(drag.text).indexOf("file:") !== -1) {
                        drag.accept(Qt.CopyAction);
                        if (typeof dynamicIsland !== "undefined") {
                            dynamicIsland._dragQueenDragHover = true;
                            if (dynamicIsland.activeMode === "dock")
                                dynamicIsland.activeMode = "drag_queen";
                        }
                    }
                }

                onExited: {
                    if (typeof dynamicIsland !== "undefined")
                        dynamicIsland._dragQueenDragHover = false;
                }

                onDropped: function (drop) {
                    if (typeof dynamicIsland !== "undefined")
                        dynamicIsland._dragQueenDragHover = false;
                    if (drop.hasUrls) {
                        FileStash.addUrls(drop.urls);
                        drop.acceptProposedAction();
                        return;
                    }
                    if (drop.hasText && drop.text) {
                        const parts = String(drop.text).split(/\s+/).filter(function (p) {
                            return p.indexOf("file:") === 0;
                        });
                        if (parts.length > 0) {
                            FileStash.addUrls(parts);
                            drop.acceptProposedAction();
                        }
                    }
                }
            }

            property real dockTargetWidth: (clockModule ? clockModule.implicitWidth : 0) + (statsModule ? statsModule.implicitWidth : 0) + (dockShareIcon ? dockShareIcon.implicitWidth : 0) + (pomodoroWidget ? pomodoroWidget.implicitWidth : 0) + (workspaceBar ? workspaceBar.implicitWidth : 0) + (pomodoroWidget && pomodoroWidget.isVisible ? 24 : 18) + 16
            property real dockTargetHeight: 28 + 14
            property real dockTargetRadius: 14

            property real islandTargetWidth: dynamicIsland ? ((dynamicIsland.activeMode === "osd" || dynamicIsland.activeMode === "charging") ? dockTargetWidth : (dynamicIsland.activeMode === "drag_queen" ? Math.max(dockTargetWidth, dynamicIsland.implicitWidth + 32) : dynamicIsland.implicitWidth + 32)) : 0
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
