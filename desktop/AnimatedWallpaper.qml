import Quickshell
import QtQuick
import qs.services

Item {
    id: root

    // --- Niri Workspace Parallax ---
    property int activeWsIndex: 0
    property real scrollOffset: -activeWsIndex * 60 // 60px base shift per workspace
    
    Behavior on scrollOffset {
        SpringAnimation {
            spring: 3.5       // ~1500 stiffness
            damping: 0.8      // 0.80 damping-ratio
            epsilon: 0.001
        }
    }

    Repeater {
        model: NiriService.workspaces
        Item {
            property bool isFocused: model.isFocused
            property int wsIndex: index
            onIsFocusedChanged: {
                if (isFocused) root.activeWsIndex = wsIndex;
            }
            Component.onCompleted: {
                if (isFocused) root.activeWsIndex = wsIndex;
            }
        }
    }

    // --- Sky Background ---
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#05060D" } // Deep space blue/black
            GradientStop { position: 0.4; color: "#111026" } // Dark blueish purple
            GradientStop { position: 0.8; color: "#32164A" } // Vibrant purple
            GradientStop { position: 1.0; color: "#54205B" } // Pinkish purple horizon
        }
    }

    // --- Animated Stars ---
    Item {
        anchors.fill: parent
        
        Repeater {
            model: 200
            Item {
                id: starWrapper
                property real startX: Math.random()
                property real startY: Math.random()
                property real animOffset: Math.random() * 5000
                property real durationMod: 3000 + Math.random() * 4000
                
                property real baseY: startY * root.height
                
                x: startX * root.width
                y: {
                    var h = root.height;
                    if (h === 0) h = 1080;
                    // Move stars vertically using parallax offset. Wrap around using modulo.
                    var rawY = baseY + root.scrollOffset * 1.5;
                    return ((rawY % h) + h) % h;
                }
                
                Rectangle {
                    width: Math.random() > 0.85 ? 2 : 1
                    height: width
                    radius: width / 2
                    color: {
                        var r = Math.random();
                        if (r > 0.8) return "#FFD1EC"; // Light pink
                        if (r > 0.6) return "#D1E2FF"; // Light blue
                        return "#FFFFFF"; // White
                    }
                    
                    opacity: 0.1
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true
                        
                        PauseAnimation { duration: starWrapper.animOffset }
                        NumberAnimation { to: 0.8; duration: starWrapper.durationMod; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.1; duration: starWrapper.durationMod; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // --- Subtle Dune Animation State ---
    property real duneShift: 0
    SequentialAnimation on duneShift {
        loops: Animation.Infinite
        running: true
        NumberAnimation { from: 0; to: 1; duration: 45000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 45000; easing.type: Easing.InOutSine }
    }

    // --- Dunes (Using Hardware-Accelerated Overlapping Rectangles) ---
    
    // Base properties for dune sizing to keep them proportionate
    property real w1: root.width * 2.2
    property real w2: root.width * 1.8
    property real w3: root.width * 2.5
    property real w4: root.width * 2.0
    property real w5: root.width * 2.8

    // Dune 1 (Back Left)
    Rectangle {
        width: root.w1
        height: root.w1
        radius: root.w1 / 2
        x: -root.width * 0.5
        y: root.height * 0.60 + root.duneShift * 15 + root.scrollOffset * 0.3
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#7B2A6B" } // Highlights
            GradientStop { position: 0.15; color: "#3B0E45" } // Shadows
            GradientStop { position: 1.0; color: "#3B0E45" }
        }
    }

    // Dune 2 (Back Right)
    Rectangle {
        width: root.w2
        height: root.w2
        radius: root.w2 / 2
        x: root.width * 0.2
        y: root.height * 0.65 - root.duneShift * 20 + root.scrollOffset * 0.45
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#993375" }
            GradientStop { position: 0.2; color: "#4A1254" }
            GradientStop { position: 1.0; color: "#4A1254" }
        }
    }

    // Dune 3 (Mid Right)
    Rectangle {
        width: root.w3
        height: root.w3
        radius: root.w3 / 2
        x: -root.width * 0.2
        y: root.height * 0.72 + root.duneShift * 10 + root.scrollOffset * 0.6
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#5E1854" }
            GradientStop { position: 0.15; color: "#22052C" }
            GradientStop { position: 1.0; color: "#22052C" }
        }
    }

    // Dune 4 (Foreground Left)
    Rectangle {
        width: root.w4
        height: root.w4
        radius: root.w4 / 2
        x: -root.width * 0.8
        y: root.height * 0.80 - root.duneShift * 12 + root.scrollOffset * 0.8
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#3B0B3B" }
            GradientStop { position: 0.15; color: "#0F0212" }
            GradientStop { position: 1.0; color: "#0F0212" }
        }
    }

    // Dune 5 (Foreground Right)
    Rectangle {
        width: root.w5
        height: root.w5
        radius: root.w5 / 2
        x: root.width * 0.1
        y: root.height * 0.85 + root.duneShift * 8 + root.scrollOffset * 1.0
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#250628" }
            GradientStop { position: 0.1; color: "#050008" }
            GradientStop { position: 1.0; color: "#050008" }
        }
    }


    // --- Glowing Planet / Moon ---
    Rectangle {
        width: 120
        height: 120
        radius: 60
        
        x: root.width * 0.75
        y: root.height * 0.25 - root.duneShift * 15 + root.scrollOffset * 0.1
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FFF0F5" } // Lavender blush
            GradientStop { position: 1.0; color: "#E0B0FF" } // Mauve
        }
    }
    
    // Fix radial glow using a Canvas or just an Image/Shader
    Canvas {
        id: planetGlow
        anchors.centerIn: parent // Center in the item, but we'll manually position it
        width: 300
        height: 300
        x: root.width * 0.75 - width/2 + 60
        y: root.height * 0.25 - root.duneShift * 15 + root.scrollOffset * 0.1 - height/2 + 60
        z: -1 // Behind the planet

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            var gradient = ctx.createRadialGradient(width/2, height/2, 60, width/2, height/2, 150);
            gradient.addColorStop(0, "rgba(224, 176, 255, 0.4)"); // #E0B0FF with 0.4 alpha
            gradient.addColorStop(1, "rgba(224, 176, 255, 0.0)");
            
            ctx.fillStyle = gradient;
            ctx.beginPath();
            ctx.arc(width/2, height/2, 150, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
