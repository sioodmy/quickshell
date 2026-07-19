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
        
        WlrLayershell.layer: WlrLayer.Bottom // Sits on the wallpaper
        WlrLayershell.namespace: "lyrics_desktop"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore // Do not reserve space!
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        margins {
            top: 80
        }
        
        implicitHeight: 200
        color: "transparent"
        visible: Lyrics.parsedLyrics.length > 0
        
        // Inner Content
        Item {
            anchors.fill: parent
            clip: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Lyrics.showFullscreen = true
            }
            
            ListView {
                id: listView
                anchors.fill: parent
                
                model: Lyrics.parsedLyrics
                interactive: false
                
                // Center the current line
                preferredHighlightBegin: height / 2 - 25
                preferredHighlightEnd: height / 2 + 25
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 500
                
                currentIndex: Math.max(0, Lyrics.currentIndex)
                
                delegate: Item {
                    width: ListView.view.width
                    height: 50 // Fixed height
                    
                    property bool isPrevious: index === listView.currentIndex - 1
                    property bool isCurrent: index === listView.currentIndex
                    property bool isNext: index === listView.currentIndex + 1
                    
                    Text {
                        anchors.centerIn: parent
                        width: parent.width * 0.8
                        text: modelData.text
                        color: "#ffffff"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter // Centered
                        
                        font { 
                            family: "Google Sans"
                            pixelSize: isCurrent ? 42 : 28 // Big fonts for desktop
                            weight: isCurrent ? Font.Bold : Font.Medium
                        }
                        
                        // Show previous, current, next
                        opacity: isCurrent ? 1.0 : ((isPrevious || isNext) ? 0.35 : 0.0)
                        
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
