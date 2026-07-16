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
        WlrLayershell.layer: WlrLayer.Overlay // Changed to Overlay so it floats above fake bezels
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

            // The visible background of the bar (floating notch)
            Rectangle {
                id: notchBg
                width: 44 + 22
                height: 680
                anchors.verticalCenter: parent.verticalCenter
                x: -22
                radius: 22
                color: Theme.surface
                z: -10
            }

            // Defines exactly what areas block clicks
            Item {
                id: inputMaskContainer
                x: 0
                y: Math.min(notchBg.y, tooltip.visible ? tooltip.y : notchBg.y, contextMenu.visible ? contextMenu.y : notchBg.y)
                width: {
                    var w = 44;
                    if (tooltip.visible) w = Math.max(w, tooltip.x + tooltip.width + 4);
                    if (contextMenu.visible) w = Math.max(w, contextMenu.x + contextMenu.width + 4);
                    return w;
                }
                height: {
                    var bottom = notchBg.y + notchBg.height;
                    if (tooltip.visible) bottom = Math.max(bottom, tooltip.y + tooltip.height + 4);
                    if (contextMenu.visible) bottom = Math.max(bottom, contextMenu.y + contextMenu.height + 4);
                    return bottom - y;
                }
            }

            // The single container that holds the modules, centered vertically
            Item {
                id: contentColumn
                width: 44
                height: 680
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left

                // 0. Launcher Button — pink animated rounded square matching launcher header
                Item {
                    id: launcherButton
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34

                    Item {
                        id: launcherMerge
                        anchors.fill: parent
                        opacity: Math.max(0, 1.0 - LauncherState.openProgress * 1.4)

                        transform: Translate {
                            x: LauncherState.openProgress * 4
                            y: LauncherState.openProgress * 24
                        }

                        Rectangle {
                            id: launcherPill
                            anchors.fill: parent
                            radius: 10
                            color: "#f5bde6"

                            scale: {
                                if (LauncherState.openProgress > 0.05) return 1.0;
                                return launcherTap.pressed ? 0.88 : (launcherHover.hovered ? 1.06 : 1.0);
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: "#ffffff"; opacity: 0.38
                                x: -6; y: -4

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 12; duration: 4200; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -8; duration: 4600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -6; duration: 3800; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: -8; duration: 3600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 16; duration: 4400; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -4; duration: 3800; easing.type: Easing.InOutSine }
                                }
                            }

                            Rectangle {
                                width: 26; height: 26; radius: 13
                                color: "#c6a0f6"; opacity: 0.50
                                x: 8; y: 14

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: -4; duration: 5000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 16; duration: 4800; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 8; duration: 4200; easing.type: Easing.InOutSine }
                                }
                                SequentialAnimation on y {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 22; duration: 4400; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: -4; duration: 5000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 14; duration: 4600; easing.type: Easing.InOutSine }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font {
                                    family: "JetBrainsMono Nerd Font"
                                    pixelSize: 14
                                }
                                color: "#301a40"
                                opacity: Math.max(0, 1.0 - LauncherState.openProgress * 2.5)
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "white"
                                opacity: launcherHover.hovered && LauncherState.openProgress < 0.1 ? 0.12 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    hideSource: true
                                    sourceItem: Rectangle {
                                        width: launcherPill.width
                                        height: launcherPill.height
                                        radius: 10
                                        color: "black"
                                        visible: false
                                    }
                                }
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                        }
                    }

                    HoverHandler {
                        id: launcherHover
                        enabled: LauncherState.openProgress < 0.3
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: launcherTap
                        onTapped: Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "appLauncher", "toggle"] })
                    }
                }

                // 1. Time (DockClock)
                DockClock {
                    id: clockModule
                    anchors.top: launcherButton.bottom
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 2. Workspaces (centerSection)
                Rectangle {
                    id: centerSection
                    anchors.top: clockModule.bottom
                    anchors.topMargin: 12
                    anchors.bottom: statsModule.top
                    anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 30
                    radius: width / 2
                    color: Theme.surface_container
                    clip: true

                    property int innerPadding: 6
                    property int workspaceGap: 6
                    property int maxVisibleAppsPerWorkspace: 4

                    // Sliding Highlight
                    Rectangle {
                        id: slidingHighlight

                        property real targetY: dockContent.currentActiveWs ? dockContent.currentActiveWs.mapToItem(centerSection, 0, 0).y : centerSection.innerPadding
                        property real targetHeight: dockContent.currentActiveWs ? dockContent.currentActiveWs.height : 0

                        y: targetY
                        width: parent.width
                        height: targetHeight
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter

                        color: Theme.secondary_container
                        opacity: dockContent.currentActiveWs ? 1.0 : 0.0

                        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Column {
                        id: workspaceColumn
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: centerSection.innerPadding / 2
                        anchors.rightMargin: centerSection.innerPadding / 2
                        width: parent.width
                        spacing: centerSection.workspaceGap

                        Repeater {
                            id: wsRepeater
                            model: NiriService.workspaces

                            delegate: Item {
                                id: wsItem
                                width: parent ? parent.width : 28
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                height: hasApps ? (wsAppColumn.implicitHeight + overflowBadge.height + 14) : width

                                property bool isFocused: model.isFocused
                                property bool isActive: model.isActive
                                property int wsId: model.id
                                property var wsApps: dockContent.runningApps ? dockContent.runningApps.filter(function(app) { return app.minWorkspaceId === wsId; }) : []
                                readonly property bool hasApps: wsApps && wsApps.length > 0
                                readonly property int visibleAppCount: hasApps ? Math.min(wsApps.length, centerSection.maxVisibleAppsPerWorkspace) : 0
                                readonly property int hiddenAppCount: hasApps ? Math.max(0, wsApps.length - visibleAppCount) : 0

                                onIsFocusedChanged: { if (isFocused) dockContent.currentActiveWs = wsItem; }
                                onIsActiveChanged: { if (isActive && !dockContent.currentActiveWs) dockContent.currentActiveWs = wsItem; }
                                Component.onCompleted: { if (isFocused || (isActive && !dockContent.currentActiveWs)) dockContent.currentActiveWs = wsItem; }

                                Rectangle {
                                    id: inactivePill
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Theme.surface_container_high
                                    opacity: (isFocused || isActive || !wsApps || wsApps.length === 0) ? 0.0 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                HoverHandler { id: wsHover }

                                Rectangle {
                                    id: hoverOverlay
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: wsHover.hovered ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

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

                                Column {
                                    id: wsAppColumn
                                    anchors.top: parent.top
                                    anchors.topMargin: 7
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: wsItem.wsApps.length > 3 ? 2 : 4

                                    Repeater {
                                        model: wsItem.visibleAppCount
                                        DockItem {
                                            id: runningItem
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: wsItem.width
                                            height: wsItem.width
                                            itemData: wsItem.wsApps[index]
                                            onDragStarted: {
                                                dockContent.draggingApp = runningItem;
                                                var wsWins = runningItem.itemData.windows.filter(function(w) { return w.workspaceId === wsItem.wsId; });
                                                dockContent.draggingWinId = wsWins.length > 0 ? wsWins[0].id : "";
                                                var global = runningItem.mapToItem(dockContent, 0, 0);
                                                dockContent.dragX = global.x + runningItem.width / 2;
                                                dockContent.dragY = global.y + runningItem.height / 2;
                                                dockContent.anyHovered = false;
                                                tooltipTimeoutTimer.stop();
                                            }
                                            onDragUpdated: function(globalX, globalY) { dockContent.dragX = globalX; dockContent.dragY = globalY; }
                                            onDragEnded: function(globalX, globalY) {
                                                for (var i = 0; i < wsRepeater.count; i++) {
                                                    var wItem = wsRepeater.itemAt(i);
                                                    if (!wItem) continue;
                                                    var wGlobal = wItem.mapToItem(dockContent, 0, 0);
                                                    if (dockContent.dragY >= wGlobal.y && dockContent.dragY <= wGlobal.y + wItem.height) {
                                                        if (wItem.wsId !== wsItem.wsId) Quickshell.execDetached({ command: ["niri", "msg", "action", "move-window-to-workspace", wItem.wsId.toString(), "--window-id", dockContent.draggingWinId.toString()] });
                                                        break;
                                                    }
                                                }
                                                dockContent.draggingApp = null;
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: overflowBadge
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 8
                                    height: wsItem.hiddenAppCount > 0 ? 14 : 0
                                    radius: height / 2
                                    visible: wsItem.hiddenAppCount > 0
                                    color: Qt.rgba(Theme.on_surface_variant.r, Theme.on_surface_variant.g, Theme.on_surface_variant.b, 0.14)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+" + wsItem.hiddenAppCount
                                        color: Theme.on_surface_variant
                                        font {
                                            family: "Google Sans"
                                            pixelSize: 9
                                            weight: Font.DemiBold
                                        }
                                    }
                                }

                                MouseArea {
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

                // 3. Sys/Net Stats
                DockSystemStats {
                    id: statsModule
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // === TOOLTIP ===
            Rectangle {
                id: tooltip
                property bool hasPreview: dockContent.hoveredWinId !== ""
                visible: false
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
                visible: false
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
