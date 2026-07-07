import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../theme"
import qs.services

/**
 * Vertical application dock functioning as a LeftBar.
 * 
 * Layout:
 * - Solid background extending full height.
 * - Top: Launcher icon + Pinned apps (that are NOT running).
 * - Center: Workspaces containing their respective running apps, with sliding highlight.
 * - Bottom: Sidebar toggle button.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: dockWindow

        required property var modelData
        screen: modelData

        // --- Layer Shell ---
        WlrLayershell.layer: WlrLayer.Top // Changed to Top so popups float over windows
        WlrLayershell.namespace: "quickshell-dock"
        // Reserve space for the dock on the left edge
        WlrLayershell.exclusiveZone: 48

        anchors {
            top: true
            left: true
            bottom: true
        }

        // Make the window wide enough to fit tooltips/menus, but transparent
        color: "transparent"
        implicitWidth: 400

        // Allow click-through everywhere except the bar and popups
        mask: Region {
            item: inputMaskContainer
        }

        Item {
            id: dockContent
            anchors.fill: parent

            // --- State for tooltips and context menu ---
            property string hoveredAppName: ""
            property real hoveredItemY: 0
            property bool anyHovered: false

            property bool contextMenuOpen: false
            property string contextDesktopId: ""
            property string contextAppName: ""
            property bool contextIsPinned: false
            property bool contextIsRunning: false
            property real contextItemY: 0
            
            property string hoveredWinId: ""
            property real previewTimestamp: 0

            Connections {
                target: DockBackend
                function onFocusSwitched() {
                    dockContent.anyHovered = false;
                    dockContent.hoveredWinId = "";
                }
            }
            
            property Item draggingApp: null
            property string draggingWinId: ""
            property real dragX: 0
            property real dragY: 0

            property Item currentActiveWs: null

            Timer {
                id: tooltipTimeoutTimer
                interval: 3500
                onTriggered: {
                    dockContent.anyHovered = false;
                    dockContent.hoveredWinId = "";
                }
            }

            // Split model into pinned (not running) and all running apps
            property var pinnedNotRunningApps: {
                var items = DockBackend.dockModel;
                return items ? items.filter(function(item) { return item.pinned && !item.running; }) : [];
            }
            property var runningApps: {
                var items = DockBackend.dockModel;
                return items ? items.filter(function(item) { return item.running; }) : [];
            }

            // The actual visible background of the bar
            Rectangle {
                width: 48
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Theme.surface
            }

            // Defines exactly what areas block clicks
            Item {
                id: inputMaskContainer
                x: 0
                y: 0
                width: {
                    var w = 48;
                    if (tooltip.visible) w = Math.max(w, tooltip.x + tooltip.width + 4);
                    if (contextMenu.visible) w = Math.max(w, contextMenu.x + contextMenu.width + 4);
                    return w;
                }
                height: parent.height
            }

            // Wrap the rest in an Item bounded to 48px
            Item {
                width: 48
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.topMargin: 12
                anchors.bottomMargin: 12

            // --- TOP STATIC SECTION (Launcher + Weather) ---
            Column {
                id: topStaticSection
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                DockItem {
                    isLauncher: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                DockWeather {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // --- PINNED APPS (Scrollable & Expanding) ---
            Flickable {
                id: pinnedFlickable
                anchors.top: topStaticSection.bottom
                anchors.topMargin: 12
                anchors.bottom: centerSection.top
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                
                contentWidth: width
                contentHeight: pinnedColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                HoverHandler { id: pinnedHover }

                Column {
                    id: pinnedColumn
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Repeater {
                        model: dockContent.pinnedNotRunningApps

                        DockItem {
                            id: pinnedItem
                            anchors.horizontalCenter: parent.horizontalCenter
                            required property var modelData
                            itemData: modelData

                            // Dense packing, expands smoothly on hover for the entire section
                            height: pinnedHover.hovered ? 32 : 24
                            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            onContextMenuRequested: {
                                var globalPos = pinnedItem.mapToItem(dockContent, 0, 0);
                                dockContent.contextItemY = globalPos.y;
                                dockContent.contextDesktopId = pinnedItem.desktopId;
                                dockContent.contextAppName = pinnedItem.appName;
                                dockContent.contextIsPinned = pinnedItem.isPinned;
                                dockContent.contextIsRunning = pinnedItem.isRunning;
                                dockContent.contextMenuOpen = true;
                            }
                        }
                    }
                }
            }

            // --- CENTER SECTION (Workspaces + Running Apps) ---
            Rectangle {
                id: centerSection
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: 44
                height: workspaceColumn.implicitHeight + 16
                radius: width / 2
                color: Theme.surface_container

                // Sliding Highlight
                Rectangle {
                    id: slidingHighlight

                    property real targetY: dockContent.currentActiveWs ? dockContent.currentActiveWs.y + 8 : 8
                    property real targetHeight: dockContent.currentActiveWs ? dockContent.currentActiveWs.height : 0

                    y: targetY
                    width: 32
                    height: targetHeight
                    radius: 16
                    anchors.horizontalCenter: parent.horizontalCenter

                    color: Theme.secondary_container
                    opacity: dockContent.currentActiveWs ? 1.0 : 0.0

                    Behavior on y {
                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                Column {
                    id: workspaceColumn
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 8

                    Repeater {
                        id: wsRepeater
                        model: NiriService.workspaces

                        delegate: Item {
                            id: wsItem
                            width: 32
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            // Height depends on apps inside + padding
                            height: (wsApps && wsApps.length > 0) ? (wsAppColumn.implicitHeight + 16) : 32

                            property bool isFocused: model.isFocused
                            property bool isActive: model.isActive
                            property int wsId: model.id
                            property var wsApps: dockContent.runningApps ? dockContent.runningApps.filter(function(app) { return app.minWorkspaceId === wsId; }) : []

                            onIsFocusedChanged: {
                                if (isFocused) {
                                    dockContent.currentActiveWs = wsItem;
                                }
                            }
                            onIsActiveChanged: {
                                if (isActive && !dockContent.currentActiveWs) {
                                    dockContent.currentActiveWs = wsItem;
                                }
                            }
                            Component.onCompleted: {
                                if (isFocused || (isActive && !dockContent.currentActiveWs)) {
                                    dockContent.currentActiveWs = wsItem;
                                }
                            }

                            // Background pill for inactive workspaces (matches TopBar behavior)
                            Rectangle {
                                id: inactivePill
                                anchors.fill: parent
                                radius: 16
                                color: Theme.surface_container_high
                                // Hide if this is the active workspace or if it's completely empty
                                opacity: (isFocused || isActive || !wsApps || wsApps.length === 0) ? 0.0 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            HoverHandler {
                                id: wsHover
                            }

                            // Global hover overlay for the entire workspace bubble
                            Rectangle {
                                id: hoverOverlay
                                anchors.fill: parent
                                radius: 16
                                color: wsHover.hovered ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // Small dot placeholder when workspace is empty
                            Rectangle {
                                anchors.centerIn: parent
                                property bool isDragTarget: dockContent.draggingApp !== null
                                width: isDragTarget ? 14 : 8
                                height: width
                                radius: width / 2
                                color: Theme.on_surface_variant
                                opacity: isDragTarget ? 0.8 : 0.3
                                visible: (!wsApps || wsApps.length === 0) && !isFocused && !isActive
                                
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            // Apps Column
                            Column {
                                id: wsAppColumn
                                anchors.centerIn: parent
                                spacing: 4

                                // Removed add/move transitions to prevent flashing when workspaces switch


                                Repeater {
                                    model: wsItem.wsApps

                                    DockItem {
                                        id: runningItem
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        required property var modelData
                                        itemData: modelData

                                        onHoverChanged: function(hovered) {
                                            if (hovered && dockContent.draggingApp === null) {
                                                dockContent.hoveredAppName = runningItem.appName;
                                                var wsWins = runningItem.itemData.windows.filter(function(w) { return w.workspaceId === wsItem.wsId; });
                                                dockContent.hoveredWinId = wsWins.length > 0 ? wsWins[0].id : "";
                                                var globalPos = runningItem.mapToItem(dockContent, 0, 0);
                                                dockContent.hoveredItemY = globalPos.y;
                                                dockContent.anyHovered = true;
                                                dockContent.previewTimestamp = Date.now();
                                                tooltipTimeoutTimer.restart();
                                            } else {
                                                dockContent.anyHovered = false;
                                                dockContent.hoveredWinId = "";
                                            }
                                        }

                                        Component.onDestruction: {
                                            if (dockContent.anyHovered) {
                                                var wsWins = runningItem.itemData.windows.filter(function(w) { return w.workspaceId === wsItem.wsId; });
                                                var winId = wsWins.length > 0 ? wsWins[0].id : "";
                                                if (winId !== "" && dockContent.hoveredWinId === winId) {
                                                    dockContent.anyHovered = false;
                                                    dockContent.hoveredWinId = "";
                                                }
                                            }
                                        }

                                        onDragStarted: {
                                            dockContent.draggingApp = runningItem;
                                            var wsWins = runningItem.itemData.windows.filter(function(w) { return w.workspaceId === wsItem.wsId; });
                                            dockContent.draggingWinId = wsWins.length > 0 ? wsWins[0].id : "";
                                            var global = runningItem.mapToItem(dockContent, 0, 0);
                                            dockContent.dragX = global.x + runningItem.width / 2;
                                            dockContent.dragY = global.y + runningItem.height / 2;
                                            dockContent.anyHovered = false; // Hide tooltip
                                            tooltipTimeoutTimer.stop();
                                        }

                                        onDragUpdated: function(globalX, globalY) {
                                            dockContent.dragX = globalX;
                                            dockContent.dragY = globalY;
                                        }

                                        onDragEnded: function(globalX, globalY) {
                                            for (var i = 0; i < wsRepeater.count; i++) {
                                                var wItem = wsRepeater.itemAt(i);
                                                if (!wItem) continue;
                                                var wGlobal = wItem.mapToItem(dockContent, 0, 0);
                                                if (dockContent.dragY >= wGlobal.y && dockContent.dragY <= wGlobal.y + wItem.height) {
                                                    if (wItem.wsId !== wsItem.wsId) {
                                                        Quickshell.execDetached({ command: ["niri", "msg", "action", "move-window-to-workspace", wItem.wsId.toString(), "--window-id", dockContent.draggingWinId.toString()] });
                                                    }
                                                    break;
                                                }
                                            }
                                            dockContent.draggingApp = null;
                                        }

                                        onContextMenuRequested: {
                                            var globalPos = runningItem.mapToItem(dockContent, 0, 0);
                                            dockContent.contextItemY = globalPos.y;
                                            dockContent.contextDesktopId = runningItem.desktopId;
                                            dockContent.contextAppName = runningItem.appName;
                                            dockContent.contextIsPinned = runningItem.isPinned;
                                            dockContent.contextIsRunning = runningItem.isRunning;
                                            dockContent.contextMenuOpen = true;
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                // Click the empty area of the workspace bubble to switch to it
                                anchors.fill: parent
                                anchors.margins: 4
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NiriService.focusWorkspaceById(wsItem.wsId)
                            }
                        }
                    }
                }
            }

            // --- BOTTOM SECTION (Sidebar Toggle) ---
            Column {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                DockSystemStats {
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                DockClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                DockItem {
                    isSidebarToggle: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            } // End of 48px bounded container

            // === TOOLTIP ===
            Rectangle {
                id: tooltip
                property bool hasPreview: dockContent.hoveredWinId !== ""
                visible: hasPreview && dockContent.anyHovered && !dockContent.contextMenuOpen
                opacity: visible ? 1.0 : 0.0
                scale: visible ? 1.0 : 0.8
                
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

                x: 56
                y: dockContent.hoveredItemY + 6 - 80

                width: 260
                height: 200
                radius: 16
                color: Theme.surface_container_high

                Rectangle {
                    width: 7
                    height: 7
                    radius: 2
                    rotation: 45
                    color: parent.color
                    anchors.top: parent.top
                    anchors.topMargin: 84
                    anchors.left: parent.left
                    anchors.leftMargin: -3
                }

                Item {
                    anchors.fill: parent
                    
                    Text {
                        id: tooltipText
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: dockContent.hoveredAppName || ""
                        color: Theme.on_surface
                        font {
                            family: "Google Sans"
                            pixelSize: 14
                            weight: Font.DemiBold
                        }
                    }
                    
                    Rectangle {
                        anchors.top: tooltipText.bottom
                        anchors.topMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 24
                        radius: 8
                        color: Theme.surface_container_highest
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                        border.width: 1

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: true
                            fillMode: Image.PreserveAspectCrop
                            source: tooltip.hasPreview ? "file://" + DockBackend.cacheDir + "/win_" + dockContent.hoveredWinId + ".png?t=" + dockContent.previewTimestamp : ""
                            
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    hideSource: true
                                    sourceItem: Rectangle {
                                        width: previewImage.width
                                        height: previewImage.height
                                        radius: 7
                                        color: "black"
                                        visible: false
                                    }
                                }
                            }
                        }
                    }
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

                x: 56
                y: dockContent.contextItemY

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

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (dockContent.contextIsPinned !== undefined ? dockContent.contextIsPinned : false) ? "󰤃" : "󰤂"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
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

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰐕"
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
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
                running: (dockContent.contextMenuOpen !== undefined ? dockContent.contextMenuOpen : false) && !(dockContent.anyHovered !== undefined ? dockContent.anyHovered : false)
                onTriggered: dockContent.contextMenuOpen = false
            }

            // Click-away dismiss via a global area outside the bar
            MouseArea {
                anchors.fill: parent
                visible: dockContent.contextMenuOpen !== undefined ? dockContent.contextMenuOpen : false
                z: -1
                onClicked: dockContent.contextMenuOpen = false
            }

            // Floating Drag Proxy
            DockItem {
                id: dragProxy
                visible: dockContent.draggingApp !== null
                isLauncher: false
                isSidebarToggle: false
                itemData: dockContent.draggingApp ? dockContent.draggingApp.itemData : {}
                width: 32; height: 32
                opacity: 0.8
                x: dockContent.dragX - width / 2
                y: dockContent.dragY - height / 2
                scale: 1.05
            }
        }
    }
}
