import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    property bool warned20: false
    property bool warned10: false
    property bool popupVisible: false
    property int batteryRemaining: 0

    // Monitor battery level
    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            checkBattery();
        }
    }
    
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            checkBattery();
        }
    }

    function checkBattery() {
        if (!UPower.displayDevice) return;

        // Reset warnings if charging
        if (!UPower.onBattery) {
            warned20 = false;
            warned10 = false;
            popupVisible = false;
            return;
        }

        var percentage = UPower.displayDevice.percentage;
        // In Quickshell, percentage is likely 0.0 - 1.0 or 0 - 100.
        // Assuming 0.0 - 1.0 based on DockSystemStats.qml `percentage * 100`.
        // We'll normalize to 0-100 just in case.
        var batPercent = percentage <= 1.0 ? Math.round(percentage * 100) : Math.round(percentage);

        if (batPercent <= 10 && !warned10) {
            warned10 = true;
            warned20 = true; // Implicitly warned for 20 if we hit 10
            batteryRemaining = batPercent;
            popupVisible = true;
        } else if (batPercent <= 20 && batPercent > 10 && !warned20) {
            warned20 = true;
            batteryRemaining = batPercent;
            popupVisible = true;
        }
    }

    delegate: PanelWindow {
        id: lowBatteryPopup

        required property var modelData
        screen: modelData

        implicitWidth: 340
        implicitHeight: 140

        color: "transparent"
        visible: root.popupVisible

        anchors {
            top: true
            right: true
        }
        margins {
            top: 60
            right: 20
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "low_battery_warning"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.fill: parent

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: 20
                color: Theme.surface_container_high

                // Subtle shadow
                layer.enabled: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 14

                        // App icon area (like macOS notification icon)
                        Rectangle {
                            width: 44
                            height: 44
                            radius: 12
                            color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: "󰂃" // Empty/Low battery icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 26
                                color: Theme.critical
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 58
                            spacing: 4

                            Text {
                                text: "Low Battery"
                                font.family: "Google Sans Medium"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }

                            Text {
                                width: parent.width
                                text: root.batteryRemaining + "% battery remaining."
                                font.family: "Google Sans"
                                font.pixelSize: 13
                                color: Theme.on_surface_variant
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Action buttons
                    Row {
                        width: parent.width
                        layoutDirection: Qt.RightToLeft

                        Rectangle {
                            width: 80
                            height: 32
                            radius: 8
                            color: Theme.surface_variant

                            Text {
                                anchors.centerIn: parent
                                text: "Close"
                                font.family: "Google Sans Medium"
                                font.pixelSize: 13
                                color: Theme.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.popupVisible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
