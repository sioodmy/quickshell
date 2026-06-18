import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

Variants {
    id: root
    model: Quickshell.screens
    
    delegate: PanelWindow {
        screen: modelData
        
        WlrLayershell.layer: WlrLayer.Bottom // Below windows, above wallpaper
        WlrLayershell.namespace: "lyrics_desktop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore // DO NOT reserve window space for Niri!
        
        anchors {
            bottom: true
            left: true
            right: true
        }
        
        margins {
            bottom: 120 // Above dock/panels
        }
        height: 160
        color: "transparent"
        
        // Don't focus or accept input
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        
        ListView {
            id: listView
            anchors.centerIn: parent
            width: parent.width * 0.8
            height: parent.height
            
            model: Lyrics.parsedLyrics
            interactive: false // No manual scrolling
            
            // Keep the current item perfectly centered in the view
            preferredHighlightBegin: height / 2 - 24
            preferredHighlightEnd: height / 2 + 24
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 500 // Smooth sliding animation
            
            // Sync with our Lyrics service
            currentIndex: Math.max(0, Lyrics.currentIndex)
            
            delegate: Item {
                width: ListView.view.width
                height: 48
                
                property bool isCurrent: index === listView.currentIndex
                property bool isPrevious: index === listView.currentIndex - 1
                property bool isNext: index === listView.currentIndex + 1
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.text
                    color: "#ffffff"
                    
                    font { 
                        family: "Google Sans"
                        pixelSize: isCurrent ? 36 : 24
                        weight: isCurrent ? Font.Bold : Font.Medium
                    }
                    
                    // Show 3 lines: previous, current, next
                    opacity: isCurrent ? 1.0 : (isPrevious || isNext ? 0.35 : 0.0)
                    
                    // Smooth transitions for font size and opacity
                    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    Behavior on font.pixelSize { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
