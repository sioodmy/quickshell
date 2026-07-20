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
 * - Top: Launcher icon + clock.
 * - Center: WorkspaceBar — workspaces with running apps and sliding highlight.
 * - Bottom: System stats.
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
                    tooltip.visible = false;
                }
            }
            
            property Item draggingApp: null
            property string draggingWinId: ""
            property real dragX: 0
            property real dragY: 0
            property real dragVY: 0
            property real _prevDragY: 0
            property bool dropHoverActive: workspaceBar.dropHoverActive

            onDragYChanged: {
                dragVY = dragY - _prevDragY
                _prevDragY = dragY
            }

            Timer {
                id: tooltipTimeoutTimer
                interval: 3500
                onTriggered: {
                    dockContent.anyHovered = false;
                    dockContent.hoveredWinId = "";
                    tooltip.visible = false;
                }
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

            // Recording indicator — same layer / exclusive zone as the bar,
            // glued to the left edge below the notch, right-side radius only.
            DockRecordingIndicator {
                id: recordingIndicator
                anchors.top: notchBg.bottom
                anchors.topMargin: 8
                z: -10
            }

            // Pomodoro focus orb — above the notch, same left-edge pill treatment.
            DockPomodoroIndicator {
                id: pomodoroIndicator
                anchors.bottom: notchBg.top
                anchors.bottomMargin: 8
                z: -10
            }

            // Defines exactly what areas block clicks
            Item {
                id: inputMaskContainer
                x: 0
                y: {
                    var top = notchBg.y;
                    if (pomodoroIndicator.visible)
                        top = Math.min(top, pomodoroIndicator.y);
                    if (tooltip.visible) top = Math.min(top, tooltip.y);
                    if (contextMenu.visible) top = Math.min(top, contextMenu.y);
                    return top;
                }
                width: {
                    var w = 44;
                    if (tooltip.visible) w = Math.max(w, tooltip.x + tooltip.width + 4);
                    if (contextMenu.visible) w = Math.max(w, contextMenu.x + contextMenu.width + 4);
                    // Keep a bit of horizontal slack while dragging so the
                    // pointer doesn't leave the layer-shell input region.
                    if (dockContent.draggingApp !== null) w = Math.max(w, 72);
                    return w;
                }
                height: {
                    var bottom = notchBg.y + notchBg.height;
                    if (recordingIndicator.visible)
                        bottom = Math.max(bottom, recordingIndicator.y + recordingIndicator.height);
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

                // 2. Workspaces
                WorkspaceBar {
                    id: workspaceBar
                    anchors.top: clockModule.bottom
                    anchors.topMargin: 12
                    anchors.bottom: statsModule.top
                    anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    runningApps: dockContent.runningApps
                    draggingApp: dockContent.draggingApp
                    draggingWinId: dockContent.draggingWinId

                    onAppHover: function(name, itemY, winId) {
                        dockContent.hoveredAppName = name
                        dockContent.hoveredItemY = itemY
                        dockContent.hoveredWinId = winId
                        dockContent.anyHovered = true
                        dockContent.previewTimestamp = Date.now()
                        tooltip.visible = true
                        tooltipTimeoutTimer.restart()
                    }
                    onAppHoverEnd: {
                        // keep tooltip until timeout / focus switch
                    }
                    onAppContextMenu: function(itemData, itemY) {
                        dockContent.contextDesktopId = itemData.desktopId || ""
                        dockContent.contextAppName = itemData.name || ""
                        dockContent.contextIsPinned = !!itemData.pinned
                        dockContent.contextIsRunning = !!itemData.running
                        dockContent.contextItemY = itemY - dockContent.mapToItem(null, 0, 0).y
                        dockContent.contextMenuOpen = true
                        tooltip.visible = false
                    }
                    onDragStarted: function(item, winId, gx, gy) {
                        var local = dockContent.mapFromItem(null, gx, gy)
                        dockContent.draggingApp = item
                        dockContent.draggingWinId = winId
                        dockContent.dragX = local.x
                        dockContent.dragY = local.y
                        dockContent._prevDragY = local.y
                        dockContent.dragVY = 0
                        dockContent.anyHovered = false
                        tooltipTimeoutTimer.stop()
                        tooltip.visible = false
                    }
                    onDragUpdated: function(gx, gy) {
                        var local = dockContent.mapFromItem(null, gx, gy)
                        dockContent.dragX = local.x
                        dockContent.dragY = local.y
                    }
                    onDragEnded: function(gx, gy) {
                        dockContent.draggingApp = null
                        dockContent.draggingWinId = ""
                        dockContent.dragVY = 0
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
                y: dockContent.hoveredItemY + 6 - 80 - dockContent.mapToItem(null, 0, 0).y

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
            }
        }
    }
}
