import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

/** Quick-action grid: photo widget (left half) + 2×2 circular button grid (right half). */
Item {
    id: root
    width: parent ? parent.width : 0
    implicitHeight: 180

    // --- Photo widget (random from ~/Pictures/widget/) ---
    property var imageFiles: []
    property string currentImage: ""

    Process {
        id: scanImages
        running: true
        command: ["bash", "-c",
            "find ~/Pictures/widget/ -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \\) 2>/dev/null"
        ]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed.length > 0) {
                    let arr = root.imageFiles.slice();
                    arr.push(trimmed);
                    root.imageFiles = arr;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.pickRandom();
        }
    }

    function pickRandom() {
        if (imageFiles.length === 0) {
            currentImage = "";
            return;
        }
        let idx = Math.floor(Math.random() * imageFiles.length);
        currentImage = "file://" + imageFiles[idx];
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // --- Photo Card ---
        Rectangle {
            id: photoCard
            width: (parent.width - 12) / 2
            height: parent.height
            radius: 24
            color: Theme.surface_container
            clip: true

            Image {
                id: photoImg
                anchors.fill: parent
                source: root.currentImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.currentImage !== ""

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: photoMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Rectangle {
                id: photoMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
                layer.enabled: true
            }

            // Placeholder when no images
            Text {
                anchors.centerIn: parent
                visible: root.currentImage === ""
                text: "󰋩"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 40 }
                color: Theme.on_surface_variant
                opacity: 0.4
            }

            // Refresh overlay
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 8
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.35)
                visible: root.imageFiles.length > 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickRandom()
                }
            }
        }

        // --- Button Grid ---
        Item {
            id: btnGrid
            width: (parent.width - 12) / 2
            height: parent.height

            // --- Action Button Component ---
            component ActionButton: Item {
                id: btn
                property string icon
                property string label
                property color iconColor: Theme.on_surface_variant
                property bool active: false

                signal clicked()

                // Fill cell evenly
                implicitWidth: 52
                implicitHeight: parent.height

                Rectangle {
                    id: circle
                    width: 52
                    height: 52
                    radius: 26
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top

                    color: {
                        if (btn.active)
                            return Theme.primary;
                        if (btnMouse.containsMouse)
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                        return Theme.surface_container_highest;
                    }

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: btn.icon
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 21 }
                        color: btn.active ? Theme.on_primary : btn.iconColor

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    scale: btnMouse.pressed ? 0.88 : (btnMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.clicked()
                    }
                }

                Text {
                    anchors.top: circle.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: btn.label
                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                    color: btn.active ? Theme.primary : Theme.on_surface_variant

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Column {
                anchors.fill: parent
                spacing: 12

                Row {
                    width: parent.width
                    height: (parent.height - 12) / 2
                    spacing: 0

                    ActionButton {
                        width: parent.width / 2
                        height: parent.height
                        icon: "⏻"
                        label: "Power"
                        iconColor: Theme.critical
                        onClicked: Quickshell.execDetached({ command: ["shutdown", "now"] })
                    }

                    ActionButton {
                        width: parent.width / 2
                        height: parent.height
                        icon: "󰹑"
                        label: "Screenshot"
                        iconColor: "#a6da95"
                        onClicked: Screenshot.take()
                    }
                }

                Row {
                    width: parent.width
                    height: (parent.height - 12) / 2
                    spacing: 0

                    ActionButton {
                        width: parent.width / 2
                        height: parent.height
                        icon: "󰌾"
                        label: "Lock"
                        iconColor: Theme.primary
                        onClicked: Quickshell.execDetached({ command: ["quickshell", "ipc", "call", "lock", "lock"] })
                    }

                    ActionButton {
                        width: parent.width / 2
                        height: parent.height
                        icon: DoNotDisturb.enabled ? "󰂛" : "󰂚"
                        label: "DND"
                        active: DoNotDisturb.enabled
                        onClicked: DoNotDisturb.toggle()
                    }
                }
            }
        }
    }
}
