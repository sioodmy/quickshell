import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: brightnessOsdPopup

        required property var modelData
        screen: modelData

        implicitWidth: 380
        implicitHeight: 136

        color: "transparent"
        visible: showOsd

        anchors {
            bottom: true
        }

        margins {
            bottom: 70
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "brightness_osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property real brightnessLevel: 0.0

        Process {
            command: ["sh", "-c", "udevadm monitor --subsystem-match=backlight --udev"]
            running: true
            stdout: SplitParser {
                onRead: updateBrightness.running = true
            }
        }

        Process {
            id: updateBrightness
            command: ["sh", "-c", "brightnessctl -m"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    let text = this.text.trim();
                    if (!text) return;
                    let parts = text.split(",");
                    if (parts.length > 3) {
                        let val = parseInt(parts[3].replace("%", ""));
                        if (!isNaN(val)) {
                            brightnessOsdPopup.brightnessLevel = val / 100.0;
                        }
                    }
                }
            }
        }

        onBrightnessLevelChanged: {
            triggerOsd();
        }

        property bool isInitialized: false
        property bool showOsd: false

        Timer {
            id: initTimer
            interval: 1000
            running: true

            onTriggered: {
                brightnessOsdPopup.isInitialized = true;
            }
        }

        Timer {
            id: hideTimer
            interval: 2000

            onTriggered: {
                brightnessOsdPopup.showOsd = false;
            }
        }

        function triggerOsd() {
            if (!isInitialized)
                return;

            showOsd = true;
            hideTimer.restart();
        }

        Item {
            anchors.fill: parent

            Rectangle {
                id: pill

                width: 320
                height: 84
                anchors.centerIn: parent

                radius: 28

                color: Theme.surface_container_high

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 6
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: Theme.primary_container

                        Text {
                            id: brightnessIcon
                            anchors.centerIn: parent

                            color: Theme.on_primary_container

                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 22
                            }

                            // Dynamic bounce on icon change
                            scale: 1.0
                            onTextChanged: bounceAnim.restart()
                            SequentialAnimation {
                                id: bounceAnim
                                NumberAnimation { target: brightnessIcon; property: "scale"; to: 1.3; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: brightnessIcon; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutBounce }
                            }

                            text: {
                                if (brightnessOsdPopup.brightnessLevel >= 0.7)
                                    return "󰃠";
                                if (brightnessOsdPopup.brightnessLevel >= 0.3)
                                    return "󰃝";

                                return "󰃞";
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48 - parent.spacing
                        spacing: 10

                        Item {
                            width: parent.width
                            height: brightnessLabel.implicitHeight

                            Text {
                                text: "Brightness"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 15
                                    bold: true
                                }
                            }

                            Text {
                                id: brightnessLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface_variant

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 15
                                }

                                text: Math.round(brightnessOsdPopup.brightnessLevel * 100) + "%"
                            }
                        }

                        Item {
                            width: parent.width
                            height: 12

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Theme.surface_variant

                                Rectangle {
                                    id: activeTrack
                                    height: parent.height
                                    radius: height / 2
                                    color: Theme.primary

                                    readonly property real visualBrightness: Math.min(Math.max(brightnessOsdPopup.brightnessLevel, 0.0), 1.0)
                                    width: Math.max(height, parent.width * visualBrightness)

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
