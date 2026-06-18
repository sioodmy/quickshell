import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

Variants {
    id: root
    model: Quickshell.screens
    
    delegate: PanelWindow {
        required property var modelData
        screen: modelData
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fullscreen_media"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive // Allow catching Escape
        WlrLayershell.exclusionMode: ExclusionMode.Ignore // Ignore bar margins to be TRULY fullscreen
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        color: "transparent"
        visible: Lyrics.showFullscreen || opacityAnim.running
        
        // --- Animated Root Container ---
        Item {
            anchors.fill: parent
            
            opacity: Lyrics.showFullscreen ? 1.0 : 0.0
            scale: Lyrics.showFullscreen ? 1.0 : 1.1
            
            Behavior on opacity {
                NumberAnimation { id: opacityAnim; duration: 400; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
            
            // Background
            Rectangle {
                anchors.fill: parent
                color: Theme.background
            }
            
            // --- Escape Key to Close ---
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Lyrics.showFullscreen = false
                
                // Allow clicking empty areas to close
                MouseArea {
                    anchors.fill: parent
                    onClicked: Lyrics.showFullscreen = false
                }
            }
            
            // --- Floating Pastel Circles (Background) ---
            Item {
                id: bgContainer
                anchors.fill: parent
                clip: true
            
            Rectangle {
                width: 900
                height: 900
                radius: 450
                color: Theme.primary
                opacity: 0.10
                x: 100
                y: -200
                transformOrigin: Item.Center

                SequentialAnimation on x {
                    loops: Animation.Infinite; paused: !Lyrics.showFullscreen
                    NumberAnimation { to: 300; duration: 25000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -300; duration: 22000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 100; duration: 20000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite; paused: !Lyrics.showFullscreen
                    NumberAnimation { to: 300; duration: 21000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -400; duration: 24000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -200; duration: 19000; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                width: 700
                height: 700
                radius: 350
                color: Theme.tertiary
                opacity: 0.12
                x: -100
                y: bgContainer.height - 400
                transformOrigin: Item.Center

                SequentialAnimation on x {
                    loops: Animation.Infinite; paused: !Lyrics.showFullscreen
                    NumberAnimation { to: bgContainer.width / 2 + 300; duration: 26000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bgContainer.width / 2 - 400; duration: 24000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bgContainer.width / 2 - 250; duration: 22000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite; paused: !Lyrics.showFullscreen
                    NumberAnimation { to: bgContainer.height / 2 - 400; duration: 22000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bgContainer.height / 2 + 300; duration: 27000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: bgContainer.height / 2 + 100; duration: 24000; easing.type: Easing.InOutSine }
                }
            }

        }
        
        // --- Main 50/50 Layout ---
        Row {
            id: mainRow
            property bool hasLyrics: Lyrics.parsedLyrics.length > 0
            
            anchors.fill: parent
            anchors.margins: 40 // some padding from screen edges
            spacing: hasLyrics ? 40 : 0
            
            Behavior on spacing { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
            
            // LEFT SIDE: Media Controls
            Item {
                width: mainRow.hasLyrics ? (parent.width - 40) / 2 : parent.width
                height: parent.height
                
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
                
                MouseArea {
                    anchors.fill: controlsCol
                    // Prevent closing when clicking anywhere inside the album art / controls area
                }
                
                Column {
                    id: controlsCol
                    anchors.centerIn: parent
                    spacing: 32 // reduced spacing
                    
                    // Album Art
                    Rectangle {
                        width: Math.min(parent.parent.width * 0.5, parent.parent.height * 0.45) // smaller album art
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 24
                        color: Theme.surface_container_highest
                        
                        Image {
                            id: mainArt
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
                            radius: parent.radius
                            visible: false
                            layer.enabled: true
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            visible: Playerctl.artUrl === ""
                            text: "󰝚"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 80 }
                            color: Theme.on_surface_variant
                        }
                    }
                    
                    // Title & Artist
                    Column {
                        width: Math.min(parent.parent.width * 0.9, 500)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        
                        Text {
                            width: parent.width
                            text: Playerctl.title !== "" ? Playerctl.title : "No Media"
                            font { family: "Google Sans"; pixelSize: 32; weight: Font.Bold } // smaller title
                            color: Theme.on_surface
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            width: parent.width
                            text: Playerctl.artist !== "" ? Playerctl.artist : "Unknown Artist"
                            font { family: "Google Sans"; pixelSize: 20; weight: Font.Medium } // smaller artist
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    // Controls
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 24 // reduced spacing
                        
                        // Previous
                        Rectangle {
                            width: 48 // smaller
                            height: 48
                            radius: 24
                            anchors.verticalCenter: parent.verticalCenter
                            color: prevMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮" 
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 } // smaller
                                color: Theme.on_surface_variant
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
                            width: 72 // smaller
                            height: 72
                            radius: 36
                            anchors.verticalCenter: parent.verticalCenter
                            color: Playerctl.isPlaying ? Theme.primary : Theme.secondary_container
                            
                            Text {
                                anchors.centerIn: parent
                                text: Playerctl.isPlaying ? "󰏤" : "󰐊" 
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 36 } // smaller
                                color: Playerctl.isPlaying ? Theme.on_primary : Theme.on_secondary_container
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
                            width: 48 // smaller
                            height: 48
                            radius: 24
                            anchors.verticalCenter: parent.verticalCenter
                            color: nextMouse.containsMouse ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭" 
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 } // smaller
                                color: Theme.on_surface_variant
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
                }
            }
            
            // RIGHT SIDE: Lyrics (Big Rounded Box)
            Rectangle {
                width: mainRow.hasLyrics ? (parent.width - 40) / 2 : 0
                height: parent.height
                radius: 32
                color: Theme.surface_container
                opacity: mainRow.hasLyrics ? 1.0 : 0.0
                scale: mainRow.hasLyrics ? 1.0 : 0.95
                visible: opacity > 0 || width > 0
                clip: true
                
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.InOutQuint } }
                
                // Prevent closing when clicking on lyrics
                MouseArea { anchors.fill: parent }
                
                ListView {
                    id: lyricsView
                    anchors.fill: parent
                    anchors.margins: 80 // MORE PADDING
                    clip: true
                    
                    model: Lyrics.parsedLyrics
                    interactive: true // Allow scrolling manually if they want
                    
                    // Keep the current item perfectly centered in the view
                    preferredHighlightBegin: height / 2 - 40
                    preferredHighlightEnd: height / 2 + 40
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 500 // Smooth sliding animation
                    
                    // Sync with our Lyrics service
                    currentIndex: Math.max(0, Lyrics.currentIndex)
                    
                    delegate: Item {
                        width: ListView.view.width
                        height: textItem.implicitHeight + 40
                        
                        property bool isCurrent: index === lyricsView.currentIndex
                        
                        MouseArea {
                            id: lyricMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Playerctl.setPosition(modelData.time);
                            }
                        }
                        
                        Text {
                            id: textItem
                            anchors.centerIn: parent
                            width: parent.width
                            text: modelData.text
                            color: Theme.on_surface
                            wrapMode: Text.WordWrap
                            
                            // Fixed font size to completely eliminate listview layout glitching!
                            font { 
                                family: "Google Sans"
                                pixelSize: 32 
                                weight: isCurrent ? Font.Bold : Font.Medium
                            }
                            
                            // Show full lyrics window, highlight current. Boost slightly on hover.
                            opacity: Math.min(1.0, (isCurrent ? 1.0 : 0.35) + (lyricMouse.containsMouse ? 0.25 : 0.0))
                            
                            // Smooth transitions for opacity ONLY. No layout shifting!
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                
                // Overlay text if no lyrics
                Text {
                    anchors.centerIn: parent
                    visible: Lyrics.parsedLyrics.length === 0
                    text: Playerctl.isPlaying ? "Fetching lyrics..." : "No Media"
                    font { family: "Google Sans"; pixelSize: 24; weight: Font.Medium } // smaller
                    color: Theme.on_surface_variant
                    opacity: 0.5
                }
            }
        }
        } // Close animated container
    }
}
