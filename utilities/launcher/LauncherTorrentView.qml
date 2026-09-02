import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"
import qs.services
import qs.components

Item {
    id: root

    property string magnetUrl: ""
    property bool isAddMode: false
    property var activeTorrents: BackendDaemon.activeTorrents || []
    
    property bool successAnim: false
    signal addedAnimationFinished()

    function triggerSuccess() {
        successAnim = true;
        successTimer.start();
    }

    Timer {
        id: successTimer
        interval: 600
        repeat: false
        onTriggered: {
            successAnim = false;
            root.addedAnimationFinished();
        }
    }
    
    // Scale animation similar to wifi/music views
    property real revealProgress: 1.0
    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    clip: true

    Column {
        anchors.fill: parent
        spacing: 10

        // ─── Status Header ───
        Rectangle {
            id: statusHeader
            width: parent.width
            height: 72
            radius: 16
            color: statusMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high
            
            Behavior on color { ColorAnimation { duration: 120 } }
            
            MouseArea {
                id: statusMouse
                anchors.fill: parent
                hoverEnabled: true
            }

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "download"
                        font.pixelSize: 20
                        color: Theme.primary
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 48 - 14
                    spacing: 2

                    Text {
                        text: root.isAddMode ? "Add Torrent" : "Torrents"
                        font { family: "Google Sans Medium"; pixelSize: 15 }
                        color: Theme.on_surface
                    }
                    Text {
                        width: parent.width
                        text: root.isAddMode ? "Paste a magnet link to start downloading" : (root.activeTorrents.length + " active downloads")
                        font { family: "Google Sans"; pixelSize: 12 }
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ─── Add Mode View ───
        Rectangle {
            width: parent.width
            height: 64
            radius: 14
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
            visible: root.isAddMode

            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: root.successAnim ? "Downloading..." : "Start downloading the torrent"
                    font { family: "Google Sans Medium"; pixelSize: 14 }
                    color: root.successAnim ? Theme.primary : Theme.on_surface
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                
                Rectangle {
                    width: root.successAnim ? parent.width : (enterLabel.width + 16)
                    height: root.successAnim ? parent.height : 24
                    radius: root.successAnim ? 12 : 6
                    color: root.successAnim ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Theme.surface_container_high
                    border.color: root.successAnim ? "transparent" : Theme.outline_variant
                    border.width: 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on radius { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        MaterialIcon {
                            visible: root.successAnim
                            icon: "check"
                            font.pixelSize: 18
                            color: Theme.primary
                        }

                        Text {
                            id: enterLabel
                            visible: !root.successAnim
                            text: "Enter"
                            font { family: "Google Sans"; pixelSize: 11 }
                            color: Theme.on_surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MaterialIcon {
                            visible: !root.successAnim
                            icon: "keyboard_return"
                            font.pixelSize: 14
                            color: Theme.on_surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ─── List Mode View ───
        ListView {
            width: parent.width
            height: parent.height - statusHeader.height - 10
            visible: !root.isAddMode
            model: root.activeTorrents
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 32
                visible: root.activeTorrents.length === 0
                text: "No active torrents"
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 14 }
                opacity: 0.8
            }
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 72
                radius: 14
                color: netMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06) : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }
                
                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                Rectangle {
                    width: 3
                    height: 28
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 1.5
                    color: Theme.primary
                    visible: true
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16
                    
                    Item {
                        anchors.fill: parent
                        
                        Column {
                            anchors.left: parent.left
                            anchors.right: cancelButton.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            
                            Text {
                                text: modelData.name ? modelData.name : "Downloading..."
                                font { family: "Google Sans Medium"; pixelSize: 14 }
                                color: Theme.on_surface
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            
                            Row {
                                spacing: 8
                                Text {
                                    text: modelData.status_text || ""
                                    font { family: "Google Sans"; pixelSize: 12 }
                                    color: Theme.on_surface_variant
                                }
                            }
                            
                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Theme.surface_container_highest
                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    color: Theme.primary
                                    width: {
                                        if (modelData.progress === undefined) return 0;
                                        return parent.width * (modelData.progress / 100.0);
                                    }
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                        
                        // Cancel button
                        Rectangle {
                            id: cancelButton
                            width: 32
                            height: 32
                            radius: 16
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: cancelArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "close"
                                color: cancelArea.containsMouse ? Theme.error : Theme.on_surface_variant
                                font.pixelSize: 18
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: cancelArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (modelData && modelData.id !== undefined) {
                                        BackendDaemon.send({
                                            "action": "torrent_cancel",
                                            "id": modelData.id
                                        });
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
