import QtQuick
import QtQuick.Effects
import Quickshell
import qs.theme
import qs.services

Item {
    id: root
    
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 24
        color: Theme.surface_container
        clip: true
        
        border.color: Theme.outline_variant
        border.width: 1

        // Full Background Album Art
        Image {
            id: bgArt
            anchors.fill: parent
            source: Playerctl.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: Playerctl.artUrl !== ""
            
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artMask
            }
        }
        
        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: bgRect.radius
            visible: false
            layer.enabled: true
        }
        
        // Trigger fullscreen overlay
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Lyrics.showFullscreen = true
        }
        
        // Toggle Overlay Button
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: Lyrics.showOverlay ? (overlayMouse.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary) : (overlayMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.1))
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            visible: Playerctl.hasPlayer
            z: 10
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "󰎇" // Single note
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                color: Lyrics.showOverlay ? Theme.on_primary : "#cccccc"
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            
            MouseArea {
                id: overlayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Lyrics.showOverlay = !Lyrics.showOverlay;
                }
            }
        }
        
        // Dark Overlay for readability
        Rectangle {
            anchors.fill: parent
            visible: Playerctl.artUrl !== ""
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.1) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.4) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
            }
        }

        // Placeholder when no media
        Text {
            anchors.centerIn: parent
            visible: !Playerctl.hasPlayer
            text: "󰝚" // Music note
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 48 }
            color: Theme.on_surface_variant
            opacity: 0.4
        }
        
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 36
            visible: !Playerctl.hasPlayer
            text: "No Media"
            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
            color: Theme.on_surface_variant
            opacity: 0.5
        }

        // Content
        Item {
            anchors.fill: parent
            anchors.margins: 16
            visible: Playerctl.hasPlayer
            
            // Controls
            Row {
                id: controlsRow
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                
                // Previous
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮" 
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                        color: Playerctl.artUrl !== "" ? "#ffffff" : Theme.on_surface_variant
                    }
                    
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Playerctl.previous()
                    }
                }

                // Play/Pause
                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: Playerctl.isPlaying ? Theme.primary : (Playerctl.artUrl !== "" ? Qt.rgba(255, 255, 255, 0.25) : Theme.secondary_container)
                    
                    Text {
                        anchors.centerIn: parent
                        text: Playerctl.isPlaying ? "󰏤" : "󰐊" 
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                        color: Playerctl.isPlaying ? Theme.on_primary : (Playerctl.artUrl !== "" ? "#ffffff" : Theme.on_secondary_container)
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Playerctl.playPause()
                    }
                    
                    scale: playMouse.pressed ? 0.9 : (playMouse.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // Next
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭" 
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                        color: Playerctl.artUrl !== "" ? "#ffffff" : Theme.on_surface_variant
                    }
                    
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Playerctl.next()
                    }
                }
            }

            // Info (Title/Artist)
            Column {
                anchors.bottom: controlsRow.top
                anchors.bottomMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 2
                
                Text {
                    width: parent.width
                    text: Playerctl.title !== "" ? Playerctl.title : "Unknown Title"
                    font { family: "Google Sans"; pixelSize: 15; weight: Font.Bold }
                    color: Playerctl.artUrl !== "" ? "#ffffff" : Theme.on_surface
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    width: parent.width
                    text: Playerctl.artist !== "" ? Playerctl.artist : "Unknown Artist"
                    font { family: "Google Sans"; pixelSize: 13 }
                    color: Playerctl.artUrl !== "" ? "#d0d0d0" : Theme.on_surface_variant
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
