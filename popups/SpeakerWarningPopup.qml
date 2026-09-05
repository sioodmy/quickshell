import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick.Effects
import "../theme"
import qs.components

Variants {
    id: root
    model: Quickshell.screens

    property var activeSink: Pipewire.defaultAudioSink
    property string lastSinkDesc: ""
    property bool popupVisible: false
    property int timeoutValue: 0
    property int maxTimeout: 5000 // 5 seconds
    property bool isInitialized: false

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    onActiveSinkChanged: {
        checkSink();
    }

    // Monitor description if it changes after activeSink is bound
    Connections {
        target: root.activeSink
        function onDescriptionChanged() {
            checkSink();
        }
    }

    function checkSink() {
        if (!root.activeSink) return;
        var currentDesc = root.activeSink.description || "";
        
        // Wait for a valid description on initialization
        if (!isInitialized) {
            if (currentDesc !== "") {
                lastSinkDesc = currentDesc;
                isInitialized = true;
            }
            return;
        }

        if (currentDesc === lastSinkDesc || currentDesc === "") return;
        
        lastSinkDesc = currentDesc;
        
        if (currentDesc.toLowerCase().indexOf("speakers") !== -1) {
            // Mute the audio
            Quickshell.execDetached({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"] });
            
            // Show popup
            popupVisible = true;
            countdownAnim.restart();
        }
    }

    NumberAnimation on timeoutValue {
        id: countdownAnim
        from: root.maxTimeout
        to: 0
        duration: root.maxTimeout
        running: false
        onFinished: {
            if (root.timeoutValue <= 0 && root.popupVisible) {
                // Auto unmute
                Quickshell.execDetached({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"] });
                root.popupVisible = false;
            }
        }
    }

    function keepMuted() {
        popupVisible = false;
        countdownAnim.stop();
    }

    function unmute() {
        Quickshell.execDetached({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"] });
        popupVisible = false;
        countdownAnim.stop();
    }

    delegate: PanelWindow {
        id: warningPopup

        required property var modelData
        screen: modelData

        implicitWidth: 380
        implicitHeight: 160

        color: "transparent"
        visible: root.popupVisible

        anchors {
            bottom: true
        }
        margins {
            bottom: 220
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "speaker_warning"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.fill: parent

            Rectangle {
                width: parent.width
                height: parent.height
                anchors.centerIn: parent
                radius: 28
                color: Theme.surface_container_high

                layer.enabled: root.popupVisible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 6
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 16

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "volume_up"
                                font.pixelSize: 24
                                color: Theme.critical
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            spacing: 2

                            Text {
                                text: "Automatically muted"
                                font.family: "Google Sans Medium"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: Theme.on_surface
                            }

                            Text {
                                width: parent.width
                                text: "Audio out has switched to speakers. Do you want to unmute?"
                                font.family: "Google Sans Medium"
                                font.pixelSize: 14
                                color: Theme.on_surface_variant
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.surface_variant
                        
                        Rectangle {
                            height: parent.height
                            width: parent.width * (1.0 - (root.timeoutValue / root.maxTimeout))
                            radius: 2
                            color: Theme.primary
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        layoutDirection: Qt.RightToLeft

                        // Unmute button (Primary action)
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 36
                            radius: 18
                            color: Theme.primary

                            Row {
                                id: unmuteRow
                                anchors.centerIn: parent
                                spacing: 8

                                MaterialIcon {
                                    icon: "volume_up"
                                    font.pixelSize: 16
                                    color: Theme.on_primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Unmute"
                                    font.family: "Google Sans Medium"
                                    font.pixelSize: 14
                                    color: Theme.on_primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.unmute()
                            }
                        }

                        // Keep Muted button (Secondary action)
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 36
                            radius: 18
                            color: Theme.surface_variant

                            Row {
                                id: keepMutedRow
                                anchors.centerIn: parent
                                spacing: 8

                                MaterialIcon {
                                    icon: "volume_off"
                                    font.pixelSize: 16
                                    color: Theme.on_surface_variant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Keep muted"
                                    font.family: "Google Sans Medium"
                                    font.pixelSize: 14
                                    color: Theme.on_surface_variant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.keepMuted()
                            }
                        }
                    }
                }
            }
        }
    }
}
