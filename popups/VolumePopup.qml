import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../theme"
import qs.services

Variants {
    id: root
    model: Quickshell.screens

    signal osdTriggered()

    delegate: PanelWindow {
        id: volumeOsdPopup

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
        WlrLayershell.namespace: "volume_osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property var activeSink: Pipewire.defaultAudioSink
        readonly property bool isMuted: activeSink?.audio?.muted ?? true
        readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

        PwObjectTracker {
            objects: volumeOsdPopup.activeSink ? [volumeOsdPopup.activeSink] : []
        }

        onVolumeLevelChanged: {
            triggerOsd();
        }

        Connections {
            target: root
            function onOsdTriggered() {
                triggerOsd();
            }
        }

        onIsMutedChanged: {
            triggerOsd();
        }

        property bool isInitialized: false
        property bool showOsd: false

        Timer {
            id: initTimer
            interval: 1000
            running: true

            onTriggered: {
                volumeOsdPopup.isInitialized = true;
            }
        }

        Timer {
            id: hideTimer
            interval: 2000

            onTriggered: {
                volumeOsdPopup.showOsd = false;
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
                height: musicRow.visible ? 120 : 84
                anchors.centerIn: parent

                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                radius: 28

                color: Theme.surface_container_high

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 6
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Item {
                        id: musicRow
                        width: parent.width
                        height: 24
                        visible: BackendDaemon.musicState.playing
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        Row {
                            anchors.centerIn: parent
                            height: 24
                            spacing: 8

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: Theme.surface_container_highest

                                Image {
                                    id: volAlbumImg
                                    anchors.fill: parent
                                    source: BackendDaemon.musicState.artUrl !== "" ? BackendDaemon.musicState.artUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: ShaderEffectSource {
                                            sourceItem: Rectangle {
                                                width: volAlbumImg.width
                                                height: volAlbumImg.height
                                                radius: 12
                                            }
                                        }
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝚"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: Theme.on_surface_variant
                                    visible: volAlbumImg.status !== Image.Ready
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, musicRow.width - 32)
                                text: BackendDaemon.musicState.title
                                font.family: "Google Sans Medium"
                                font.pixelSize: 14
                                color: Theme.on_surface
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 48
                        spacing: 16

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: volumeOsdPopup.isMuted ? Theme.surface_variant : Theme.primary_container

                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            id: volumeIcon
                            anchors.centerIn: parent

                            color: volumeOsdPopup.isMuted ? Theme.on_surface_variant : Theme.on_primary_container
                            Behavior on color { ColorAnimation { duration: 200 } }

                            font {
                                family: "JetBrainsMono Nerd Font"
                                pixelSize: 22
                            }

                            // Dynamic bounce on icon change
                            scale: 1.0
                            onTextChanged: bounceAnim.restart()
                            SequentialAnimation {
                                id: bounceAnim
                                NumberAnimation { target: volumeIcon; property: "scale"; to: 1.3; duration: 100; easing.type: Easing.OutQuad }
                                NumberAnimation { target: volumeIcon; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutBounce }
                            }

                            text: {
                                if (!volumeOsdPopup.activeSink?.audio)
                                    return "";
                                if (volumeOsdPopup.isMuted)
                                    return "";
                                if (volumeOsdPopup.volumeLevel >= 0.6)
                                    return "";
                                if (volumeOsdPopup.volumeLevel >= 0.3)
                                    return "";

                                return "";
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48 - parent.spacing
                        spacing: 10

                        Item {
                            width: parent.width
                            height: volumeLabel.implicitHeight

                            Text {
                                text: "Volume"
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
                                id: volumeLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface_variant

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 15
                                }

                                text: volumeOsdPopup.activeSink?.audio ? Math.round(volumeOsdPopup.volumeLevel * 100) + "%" : "--%"
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
                                    color: volumeOsdPopup.isMuted ? Theme.outline : Theme.primary
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    readonly property real visualVolume: Math.min(volumeOsdPopup.volumeLevel, 1.0)
                                    width: Math.max(height, parent.width * visualVolume)

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
                } // End of Volume Row
                } // End of Column
            } // End of pill Rectangle
        } // End of Item
    } // End of PanelWindow
} // End of Variants
