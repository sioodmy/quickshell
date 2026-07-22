import Quickshell
import Quickshell.Wayland
import QtQuick
import "../theme"
import qs.services

/**
 * Minimal single-file share notch:
 * thick progressbar background, compact bubble controls centered on the pill.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: shareWindow

        required property var modelData
        screen: modelData

        readonly property int barRadius: 20
        readonly property bool hasShare: FileShare.active

        property bool panelVisible: false

        function updateVisibility() {
            if (hasShare) {
                hideTimer.stop();
                panelVisible = true;
            } else {
                hideTimer.restart();
            }
        }

        onHasShareChanged: updateVisibility()

        Timer {
            id: hideTimer
            interval: 280
            onTriggered: {
                if (!shareWindow.hasShare)
                    shareWindow.panelVisible = false;
            }
        }

        color: "transparent"
        visible: true
        implicitWidth: modelData.width
        implicitHeight: notchRoot.height + barRadius + 4

        mask: Region { item: inputHitbox }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "file_share_notch"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
        }

        Item {
            id: inputHitbox
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: notchRoot.width + 16
            height: notchRoot.height + barRadius + 4
        }

        Item {
            id: notchRoot
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: -barRadius

            width: controlsRow.width + 20
            height: barRadius + 40

            opacity: panelVisible ? 1 : 0
            scale: panelVisible ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Thick progress bar background (empty = bar bg, fill = pink).
            Rectangle {
                anchors.fill: parent
                radius: barRadius
                color: Theme.surface_container_high
            }
            Rectangle {
                width: parent.width * FileShare.totalProgress
                height: parent.height
                radius: barRadius
                color: Theme.tertiary
                opacity: 0.92
                Behavior on width {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            Row {
                id: controlsRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: barRadius + 5
                spacing: 6

                // Label bubble
                Rectangle {
                    height: 28
                    width: labelRow.width + 16
                    radius: 14
                    color: Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)

                    Row {
                        id: labelRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰖩"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                            color: Theme.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sharing"
                            color: Theme.on_surface
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }
                    }
                }

                // Cancel bubble — sits right beside the label
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: cancelMouse.containsMouse ? Theme.critical : Theme.surface
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: cancelMouse.containsMouse ? Theme.on_critical : Theme.on_surface_variant
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: FileShare.cancelAll()
                    }
                }
            }
        }

        Component.onCompleted: updateVisibility()
    }
}
