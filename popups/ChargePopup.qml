import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: chargeOsdPopup

        required property var modelData
        screen: modelData

        anchors {
            top: true; bottom: true; left: true; right: true
        }

        color: "transparent"
        visible: showOsd

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "charge_osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property bool showOsd: false
        property bool wasOnBattery: true

        Connections {
            target: UPower
            function onOnBatteryChanged() {
                if (chargeOsdPopup.wasOnBattery && !UPower.onBattery) {
                    triggerAnimation();
                }
                chargeOsdPopup.wasOnBattery = UPower.onBattery;
            }
        }

        Component.onCompleted: {
            wasOnBattery = UPower.onBattery;
        }

        function triggerAnimation() {
            showOsd = true;
            flashAnim.restart();
        }

        Item {
            anchors.fill: parent

            Rectangle {
                id: ripple
                width: size
                height: size
                radius: size / 2
                anchors.centerIn: parent
                color: Theme.primary
                opacity: 0.0

                property real size: 0

                SequentialAnimation {
                    id: flashAnim
                    ParallelAnimation {
                        NumberAnimation { target: ripple; property: "size"; from: 0; to: Math.max(chargeOsdPopup.width, chargeOsdPopup.height) * 2.5; duration: 800; easing.type: Easing.OutQuint }
                        SequentialAnimation {
                            NumberAnimation { target: ripple; property: "opacity"; from: 0.0; to: 0.3; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ripple; property: "opacity"; from: 0.3; to: 0.0; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }
                    onStopped: chargeOsdPopup.showOsd = false
                }
            }

            Text {
                id: chargeIcon
                anchors.centerIn: parent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 160
                color: Theme.on_surface
                text: ""
                opacity: 0.0
                scale: 0.5
                
                SequentialAnimation {
                    running: flashAnim.running
                    ParallelAnimation {
                        NumberAnimation { target: chargeIcon; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: chargeIcon; property: "scale"; from: 0.5; to: 1.0; duration: 500; easing.type: Easing.OutBack }
                    }
                    PauseAnimation { duration: 100 }
                    NumberAnimation { target: chargeIcon; property: "opacity"; from: 1.0; to: 0.0; duration: 200; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
}
