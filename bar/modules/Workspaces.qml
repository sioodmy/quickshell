import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

Rectangle {
    id: root

    property string targetMonitor: ""
    property Item currentActiveDot: null

    readonly property int animDurationShort: 150
    readonly property int dotHeight: 20
    readonly property int spacingAmount: 5

    // Preview properties
    property int hoveredWsId: -1
    property real hoveredWsX: 0
    property real previewTimestamp: 0
    property bool showPreview: false

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/workspaces"

    // Clear cache on startup
    Process {
        Component.onCompleted: running = true
        command: ["bash", "-c", "rm -rf \"$1\" && mkdir -p \"$1\"", "_", root.cacheDir]
    }

    // Screenshot mechanism (rescaled using ImageMagick for performance)
    Process {
        id: screenshotProcess
        property int targetWsId: -1
        command: ["bash", "-c", "out=\"$1/ws_$2.png\"; tmp=\"$out.tmp.png\"; grim -c - | magick - -sample 320x \"$tmp\" && mv \"$tmp\" \"$out\"", "_", root.cacheDir, targetWsId.toString()]
    }

    Timer {
        id: enterCaptureTimer
        interval: 1000
        repeat: false
        property int pendingWsId: -1
        onTriggered: {
            if (pendingWsId !== -1) {
                screenshotProcess.targetWsId = pendingWsId;
                screenshotProcess.running = true;
            }
        }
    }

    Timer {
        id: periodicCaptureTimer
        interval: 15000
        repeat: true
        running: root.currentActiveDot && root.currentActiveDot.hasWindows
        onTriggered: {
            if (root.currentActiveDot) {
                screenshotProcess.targetWsId = root.currentActiveDot.wsId;
                screenshotProcess.running = true;
            }
        }
    }

    Timer {
        id: hidePreviewTimer
        interval: 150
        onTriggered: previewWin.visible = false
    }

    onHoveredWsIdChanged: {
        if (hoveredWsId !== -1) {
            hidePreviewTimer.stop();
            previewWin.visible = true;
            showPreview = true;
        } else {
            showPreview = false;
            hidePreviewTimer.restart();
        }
    }

    // Floating Preview Window
    PanelWindow {
        id: previewWin
        color: "transparent"
        visible: false
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "workspace_preview"
        
        anchors {
            top: true
            left: true
        }
        
        margins {
            top: 15 // Tightly snapped to the bar
            left: Math.max(0, root.hoveredWsX - 140) 
        }

        implicitWidth: 280
        implicitHeight: 180

        Item {
            id: popupContent
            anchors.fill: parent
            
            property real dotLocalX: root.hoveredWsX - previewWin.margins.left
            
            // Pop out animation
            opacity: root.showPreview ? 1 : 0
            scale: root.showPreview ? 1 : 0.6
            transformOrigin: Item.Top
            
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

            // The main card
            Rectangle {
                id: cardBg
                anchors.centerIn: parent
                width: 240
                height: 140
                radius: 18
                color: Theme.surface_container_high
                
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.tint(Theme.surface_container_high, Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)) }
                    GradientStop { position: 1.0; color: Theme.surface_container_high }
                }

                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                border.width: 1
                
                // Add inner glow border
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 17
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                }
            }

            // The arrow pointing up
            Rectangle {
                width: 16
                height: 16
                radius: 3
                color: Qt.tint(Theme.surface_container_high, Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10))
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                border.width: 1
                rotation: 45
                
                x: Math.max(cardBg.x + 20, Math.min(popupContent.dotLocalX - width/2, cardBg.x + cardBg.width - 36))
                y: cardBg.y - 8
                z: -1
            }
            
            // The actual Image
            Item {
                anchors.fill: cardBg
                anchors.margins: 8
                
                Image {
                    id: previewImage
                    anchors.fill: parent
                    source: root.hoveredWsId !== -1 ? "file://" + root.cacheDir + "/ws_" + root.hoveredWsId + ".png?t=" + root.previewTimestamp : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: ShaderEffectSource {
                            hideSource: true
                            sourceItem: Rectangle {
                                width: previewImage.width
                                height: previewImage.height
                                radius: 12
                                color: "black"
                                visible: false
                            }
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: previewImage.status !== Image.Ready
                        
                        Text {
                            anchors.centerIn: parent
                            text: "󰆚"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                            color: Theme.on_surface_variant
                            opacity: 0.5
                        }
                    }
                }
                
                // Inner subtle border to the image
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                }
            }

            // Dynamic App Icons Row
            Row {
                id: iconRow
                anchors.bottom: cardBg.bottom
                anchors.horizontalCenter: cardBg.horizontalCenter
                anchors.bottomMargin: 14
                spacing: 8
                z: 10
                
                Instantiator {
                    model: NiriService.windows
                    delegate: Item {
                        property bool active: model.workspaceId === root.hoveredWsId
                        visible: active || width > 0
                        width: active ? 32 : 0
                        height: 32
                        opacity: active ? 1 : 0
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: 16
                            color: Theme.surface_container_highest
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowBlur: 1.0
                                shadowColor: "#40000000"
                                shadowVerticalOffset: 2
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                fillMode: Image.PreserveAspectFit
                                
                                property var tryIcons: [
                                    model.appId,
                                    model.appId.toLowerCase(),
                                    model.appId.toLowerCase() + "-desktop",
                                    "application-x-executable"
                                ]
                                property int tryIndex: 0
                                
                                source: "image://icon/" + tryIcons[0]
                                
                                onStatusChanged: {
                                    if (status === Image.Error && tryIndex < tryIcons.length - 1) {
                                        tryIndex++;
                                        source = "image://icon/" + tryIcons[tryIndex];
                                    }
                                }
                            }
                        }
                    }
                    onObjectAdded: (index, object) => object.parent = iconRow
                    onObjectRemoved: (index, object) => object.destroy()
                }
            }

            // Drop Shadow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 1.5
                shadowColor: "#50000000"
                shadowVerticalOffset: 8
            }
        }
    }

    implicitWidth: mainLayout.width + 12
    implicitHeight: mainLayout.height + 8
    color: Theme.surface_container
    radius: height / 2

    // The Global Sliding Highlight
    Rectangle {
        id: slidingHighlight

        property real targetX: {
            if (!currentActiveDot)
                return 0;
            let tx = 0;
            for (let i = 0; i < dotRepeater.count; i++) {
                let child = dotRepeater.itemAt(i);
                if (!child)
                    continue;
                if (child === currentActiveDot)
                    break;
                if (child.isVisible) {
                    tx += child.targetWidth + mainLayout.spacing;
                }
            }
            return tx;
        }

        y: mainLayout.y
        x: mainLayout.x + targetX
        width: currentActiveDot ? currentActiveDot.targetWidth : 0
        height: root.dotHeight
        radius: height / 2

        color: currentActiveDot?.isFocused ? (Theme.primary ?? "#6750A4") : (Theme.primary_container ?? "#EADDFF")
        Behavior on color {
            ColorAnimation {
                duration: root.animDurationShort
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
    }

    Row {
        id: mainLayout
        anchors.centerIn: parent
        spacing: root.spacingAmount

        Repeater {
            id: dotRepeater
            model: NiriService.workspaces

            delegate: Item {
                id: workspaceDot

                readonly property bool isVisible: model.output === root.targetMonitor
                readonly property bool isFocused: model.isFocused
                readonly property bool isActive: model.isActive
                readonly property int wsId: model.id
                readonly property bool hasWindows: model.activeWindowId > 0

                visible: isVisible

                onIsFocusedChanged: {
                    if (isFocused) {
                        root.currentActiveDot = workspaceDot;
                        if (hasWindows) {
                            enterCaptureTimer.pendingWsId = wsId;
                            enterCaptureTimer.restart();
                        }
                    }
                }
                
                onIsActiveChanged: {
                    if (isActive && !isFocused)
                        root.currentActiveDot = workspaceDot
                }

                onHasWindowsChanged: {
                    if (isFocused && hasWindows) {
                        enterCaptureTimer.pendingWsId = wsId;
                        enterCaptureTimer.restart();
                    }
                }

                Component.onCompleted: {
                    if (isFocused || (isActive && !root.currentActiveDot)) {
                        root.currentActiveDot = workspaceDot;
                        if (hasWindows) {
                            enterCaptureTimer.pendingWsId = wsId;
                            enterCaptureTimer.restart();
                        }
                    }
                }

                readonly property real targetWidth: {
                    if (!isVisible)
                        return 0;
                    if (isFocused)
                        return 32;
                    if (isActive)
                        return 26;
                    if (hasWindows)
                        return dotHover.hovered ? 26 : 22;
                    return dotHover.hovered ? 24 : 20;
                }

                width: targetWidth
                height: root.dotHeight

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Rectangle {
                    id: inactivePill
                    anchors.fill: parent
                    radius: height / 2

                    opacity: (workspaceDot.isFocused || workspaceDot.isActive) ? 0.0 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    color: dotHover.hovered ? (Theme.secondary_container ?? "#E8DEF8") : (Theme.surface_container_high ?? "#ECE6F0")
                    Behavior on color {
                        ColorAnimation {
                            duration: root.animDurationShort
                        }
                    }
                }

                scale: dotTap.pressed ? 0.92 : (dotHover.hovered ? 1.04 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                Timer {
                    id: hoverPreviewTimer
                    interval: 150
                    running: dotHover.hovered && !workspaceDot.isFocused && workspaceDot.hasWindows
                    onTriggered: {
                        var pos = workspaceDot.mapToItem(null, workspaceDot.width / 2, 0);
                        root.hoveredWsX = pos.x;
                        root.hoveredWsId = workspaceDot.wsId;
                        root.previewTimestamp = Date.now();
                    }
                }

                TapHandler {
                    id: dotTap
                    margin: 8
                    onTapped: NiriService.focusWorkspaceById(workspaceDot.wsId)
                }
                
                HoverHandler {
                    id: dotHover
                    margin: 8
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (!hovered && root.hoveredWsId === workspaceDot.wsId) {
                            root.hoveredWsId = -1;
                        }
                    }
                }
            }
        }
    }
}
