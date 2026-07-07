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
        
        WlrLayershell.layer: WlrLayer.Overlay // On top of everything, including windows
        WlrLayershell.namespace: "lyrics_overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        
        anchors {
            bottom: true
            right: true
        }
        
        margins {
            bottom: 60 // Slightly more padding to look nice without a box
            right: 60
        }
        
        implicitWidth: 400
        implicitHeight: 80 // Reduced height
        color: "transparent"
        visible: Lyrics.showOverlay && Lyrics.parsedLyrics.length > 0
        
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
        }
        
        // Inner Content (No Background Rectangle anymore!)
        Item {
            anchors.fill: parent
            clip: true // Ensure text doesn't overflow
            
            // Disappear when hovered
            opacity: hoverArea.containsMouse ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            ListView {
                id: listView
                anchors.fill: parent
                
                model: Lyrics.parsedLyrics
                interactive: false
                
                // Pin the current line to the top of the view
                preferredHighlightBegin: 0
                preferredHighlightEnd: 0
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 500
                
                currentIndex: Math.max(0, Lyrics.currentIndex)
                
                delegate: Item {
                    width: ListView.view.width
                    height: 24 // Fixed, smaller height
                    
                    property bool isCurrent: index === listView.currentIndex
                    property bool isNext: index === listView.currentIndex + 1
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: modelData.text
                        color: "#ffffff" // Pure white for better contrast without background
                        elide: Text.ElideLeft // Since it's right aligned, elide left if it overflows
                        horizontalAlignment: Text.AlignRight // ALIGN RIGHT
                        
                        // Text outline to keep it readable against ANY window background
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.4)
                        
                        font { 
                            family: "Google Sans"
                            pixelSize: isCurrent ? 16 : 14 // EVEN SMALLER (Chrome search bar size)
                            weight: isCurrent ? Font.Bold : Font.Medium
                        }
                        
                        // Show ONLY current and next line, even more transparent
                        opacity: isCurrent ? 0.7 : (isNext ? 0.2 : 0.0)
                        
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
