import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

import qs.theme
import qs.services

PanelWindow {
    id: win

    readonly property bool shown: ControlCenter.open

    visible: shown || slideAnim.running
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "control_center"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onShownChanged: {
        if (shown) {
            clipSection.refresh();
            panel.forceActiveFocus();
        } else {
            notifSection.showAll = false;
            clipSection.showAll = false;
        }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { ControlCenter.toggle(); }
        function open(): void { ControlCenter.show(); }
        function close(): void { ControlCenter.hide(); }
    }

    // Audio
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: win.sink ? [win.sink] : []
    }

    // Dim scrim
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.shown ? 0.35 : 0.0
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // Click-away
    MouseArea {
        anchors.fill: parent
        onClicked: ControlCenter.hide()
    }

    // --- Sliding panel ---
    Rectangle {
        id: panel
        width: 430
        focus: win.shown
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: Layout.topBarHeight + 8
        anchors.bottomMargin: 8
        anchors.rightMargin: win.shown ? 8 : -(width + 24)

        radius: 28
        color: Theme.surface_container_low
        border.color: Theme.outline_variant
        border.width: 1

        Behavior on anchors.rightMargin {
            NumberAnimation {
                id: slideAnim
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#50000000"
            shadowHorizontalOffset: -6
            shadowVerticalOffset: 6
        }

        // Swallow clicks so they don't dismiss
        MouseArea { anchors.fill: parent }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                ControlCenter.hide();
                event.accepted = true;
            }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 18
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1500
            maximumFlickVelocity: 5000

            Column {
                id: contentCol
                width: flick.width
                spacing: 18

                // --- Header ---
                Item {
                    width: parent.width
                    height: 44

                    Row {
                        id: tabBar
                        anchors.left: parent.left
                        anchors.right: closeBtnRect.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 40
                        spacing: 8
                        
                        property int currentTab: 0

                        Repeater {
                            model: ["󰒲", "󰂚", "󰅌", "󰝚"]
                            delegate: Rectangle {
                                width: (tabBar.width - (tabBar.spacing * 3)) / 4
                                height: 40
                                radius: 20
                                color: tabBar.currentTab === index ? Theme.primary : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18; weight: Font.Medium }
                                    color: tabBar.currentTab === index ? Theme.on_primary : Theme.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tabBar.currentTab = index
                                }
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        id: closeBtnRect
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 18
                        color: closeMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 15 }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ControlCenter.hide()
                        }
                    }
                }

                // --- Controls Tab ---
                Column {
                    width: parent.width
                    spacing: 18
                    visible: tabBar.currentTab === 0

                    // --- Sliders card ---
                    Rectangle {
                        width: parent.width
                        radius: 24
                        color: Theme.surface_container
                        height: slidersCol.implicitHeight + 32
                        clip: true

                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Column {
                            id: slidersCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Row {
                                width: parent.width
                                spacing: 14

                                Rectangle {
                                    id: mixerButton
                                    width: 48
                                    height: 48
                                    radius: 24
                                    color: mixerMouse.containsMouse ? Theme.surface_variant : Theme.surface_container_high
                                    border.color: Theme.outline_variant
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 18
                                        color: Theme.on_surface
                                    }

                                    MouseArea {
                                        id: mixerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mixerCard.visible = !mixerCard.visible
                                    }
                                }

                                Slider {
                                    width: parent.width - mixerButton.width - 14
                                    icon: {
                                        if (!win.sink?.audio)
                                            return "";
                                        if (win.sink?.audio?.muted ?? true)
                                            return "";
                                        if (value >= 0.6)
                                            return "";
                                        if (value >= 0.3)
                                            return "";
                                        return "";
                                    }
                                    value: Math.min(1, win.sink?.audio?.volume ?? 0)
                                    onMoved: v => {
                                        if (win.sink?.audio) {
                                            win.sink.audio.muted = false;
                                            win.sink.audio.volume = v;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: mixerCard
                                width: parent.width
                                height: mixerColumn.implicitHeight + 24
                                visible: false
                                radius: 20
                                color: Theme.surface_variant
                                border.color: Theme.outline_variant
                                border.width: 1
                                clip: true

                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                Column {
                                    id: mixerColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Text {
                                        text: "Volume Mixer"
                                        color: Theme.on_surface_variant
                                        font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                        leftPadding: 4
                                    }

                                    Repeater {
                                        model: Pipewire.nodes

                                        delegate: Column {
                                            width: mixerColumn.width
                                            visible: showNode
                                            height: showNode ? implicitHeight : 0
                                            spacing: 8
                                            clip: true

                                            PwObjectTracker {
                                                objects: [modelData]
                                            }

                                            // Don't show the default sink again since it's above, only output streams and other sinks
                                            readonly property bool isDefaultSink: modelData.id === win.sink?.id
                                            readonly property bool isOutputStream: modelData.isStream && modelData.properties["media.class"] === "Stream/Output/Audio"
                                            readonly property bool showNode: modelData.audio !== undefined && (isOutputStream || (modelData.isSink && !isDefaultSink))

                                            Text {
                                                text: modelData.properties["application.name"] || modelData.description || modelData.name || "Unknown"
                                                color: Theme.on_surface
                                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                                elide: Text.ElideRight
                                                width: parent.width
                                                leftPadding: 4
                                            }

                                            Slider {
                                                width: parent.width
                                                icon: modelData.isStream ? "󰎆" : "󰓃"
                                                accent: Theme.secondary
                                                value: modelData.audio ? modelData.audio.volume : 0
                                                onMoved: v => {
                                                    if (modelData.audio) {
                                                        modelData.audio.muted = false;
                                                        modelData.audio.volume = v;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Slider {
                                width: parent.width
                                icon: "󰃠"
                                value: Brightness.value
                                enabledControl: Brightness.available
                                onMoved: v => Brightness.setPercent(v * 100)
                            }
                        }
                    }

                    // --- Quick Actions: Photo + Buttons ---
                    QuickActions { width: parent.width }

                    // --- Connectivity ---
                    WifiSection { width: parent.width }
                    BluetoothSection { width: parent.width }

                    Row {
                        width: parent.width
                        height: (width - 12) / 2
                        spacing: 12

                        PomodoroWidget {
                            width: (parent.width - 12) / 2
                            height: parent.height
                        }

                        MediaWidget {
                            width: (parent.width - 12) / 2
                            height: parent.height
                        }
                    }
                }

                // --- Notifications Tab ---
                NotificationsSection {
                    id: notifSection
                    width: parent.width
                    visible: tabBar.currentTab === 1
                }

                // --- Clipboard Tab ---
                ClipboardSection {
                    id: clipSection
                    width: parent.width
                    visible: tabBar.currentTab === 2
                }

                // --- Music Tab ---
                MusicSection {
                    id: musicSection
                    width: parent.width
                    visible: tabBar.currentTab === 3
                    height: visible ? (flick.height - 44 - 18) : 0
                }

            }
        }
    }
}
