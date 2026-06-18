import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.services
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: popup
        required property var modelData
        screen: modelData

        visible: surfaceMapped
        property bool hasScreenshot: Screenshot.active

        Timer {
            id: exitTimer
            interval: 400
            running: !hasScreenshot
        }

        readonly property bool surfaceMapped: hasScreenshot || exitTimer.running

        implicitWidth: surfaceMapped ? 390 : 0
        implicitHeight: surfaceMapped ? modelData.height : 0

        mask: Region { item: hitbox }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screenshot_popup"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        color: "transparent"

        anchors { top: true; right: true }
        margins { top: 40; right: 5 }

        Item {
            id: hitbox
            width: card.width
            height: card.height + 40
            anchors { top: card.top; right: card.right }
            visible: popup.hasScreenshot
        }

        Rectangle {
            id: card
            width: 350
            height: cardContent.implicitHeight + 36

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 20
            }

            radius: 28
            color: Theme.surface_container
            border.color: Theme.outline_variant
            border.width: 1

            property real slideX: popup.hasScreenshot ? 0 : 390

            transform: Translate { x: card.slideX }
            opacity: popup.hasScreenshot ? 1 : 0

            Behavior on slideX {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: 250 }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#40000000"
                blurMax: 32
                shadowBlur: cardMouse.containsMouse ? 1.0 : 0.85
                shadowVerticalOffset: cardMouse.containsMouse ? 6 : 4

                Behavior on shadowBlur {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on shadowVerticalOffset {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
            }

            // Hover overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: cardMouse.containsMouse
                    ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            Column {
                id: cardContent
                width: parent.width - 40
                anchors.centerIn: parent
                spacing: 10

                // --- Header ---
                Item {
                    width: parent.width
                    height: 32

                    Rectangle {
                        id: headerIcon
                        width: 24; height: 24; radius: 12
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.primary_container

                        Text {
                            anchors.centerIn: parent
                            text: "󰹑"
                            color: Theme.on_primary_container
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                        }
                    }

                    Text {
                        text: "Screenshot"
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: headerIcon.right
                        anchors.leftMargin: 12
                        font { family: "Google Sans Medium"; pixelSize: 14 }
                    }

                    // Close button
                    Rectangle {
                        id: closeBtn
                        width: 32; height: 32; radius: 16
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: closeMouse.containsMouse
                            ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Item {
                            anchors.centerIn: parent
                            width: 12; height: 12; rotation: 45

                            Rectangle {
                                width: 2; height: parent.height
                                anchors.centerIn: parent; radius: 1
                                color: closeMouse.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Rectangle {
                                width: parent.width; height: 2
                                anchors.centerIn: parent; radius: 1
                                color: closeMouse.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Screenshot.dismiss()
                        }
                    }
                }

                // --- Screenshot Preview ---
                Rectangle {
                    id: previewContainer
                    width: parent.width
                    height: Math.min(width * 0.5625, 160)
                    radius: 16
                    color: Theme.surface_container_high
                    clip: true

                    Image {
                        id: previewImg
                        anchors.fill: parent
                        source: Screenshot.imagePath ? ("file://" + Screenshot.imagePath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: previewMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }

                    Rectangle {
                        id: previewMask
                        anchors.fill: parent
                        radius: parent.radius
                        visible: false
                        layer.enabled: true
                    }
                }

                // --- Action Buttons ---
                Row {
                    width: parent.width
                    spacing: 8

                    component ActionPill: Rectangle {
                        id: pill
                        property string icon
                        property string label
                        property bool done: false
                        property bool busy: false

                        width: (parent.width - 16) / 3
                        height: 36
                        radius: 18
                        color: {
                            if (done) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                            if (pillMouse.containsMouse) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14);
                            return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        signal triggered()

                        scale: pillMouse.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pill.done ? "󰄬" : (pill.busy ? "󰦖" : pill.icon)
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                color: pill.done ? Theme.primary : Theme.on_surface_variant

                                RotationAnimation on rotation {
                                    running: pill.busy
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pill.label
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                color: pill.done ? Theme.primary : Theme.on_surface
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pill.triggered()
                        }
                    }

                    ActionPill {
                        icon: "󰆏"
                        label: "Copy"
                        done: Screenshot.wasCopied
                        onTriggered: Screenshot.copyToClipboard()
                    }

                    ActionPill {
                        icon: "󰈝"
                        label: "Save"
                        done: Screenshot.wasSaved
                        onTriggered: Screenshot.save()
                    }

                    ActionPill {
                        icon: "󰊄"
                        label: "OCR Text"
                        done: Screenshot.wasOcred
                        busy: Screenshot.ocring
                        onTriggered: Screenshot.ocr()
                    }
                }
            }
        }
    }
}
