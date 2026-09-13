import QtQuick
import QtQuick.Shapes

/**
 * Album-palette fluid aurora. The Rust backend extracts a dark base and three
 * separated hues from the cover; large overlapping radial fields turn those
 * colors into a smooth, slowly moving liquid backdrop with no image upscale
 * or render-to-texture blur.
 */
Item {
    id: root
    anchors.fill: parent
    clip: true

    property color primary: "#ff7ec0"
    property color secondary: "#8b74ff"
    property color accent: "#e08cff"
    property color bg: "#24143a"
    property bool alive: true

    Behavior on primary { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on secondary { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on bg { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }

    component LightPool: Shape {
        id: pool
        property color tint: "#ffffff"
        property real centerX: 0
        property real centerY: 0
        property real spread: 420
        property real intensity: 0.5

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: pool.centerX
                centerY: pool.centerY
                centerRadius: pool.spread
                focalX: pool.centerX
                focalY: pool.centerY

                GradientStop { position: 0.0; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity) }
                GradientStop { position: 0.22; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.8) }
                GradientStop { position: 0.48; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.42) }
                GradientStop { position: 0.72; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.14) }
                GradientStop { position: 1.0; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, 0.0) }
            }

            startX: 0
            startY: 0
            PathLine { x: pool.width; y: 0 }
            PathLine { x: pool.width; y: pool.height }
            PathLine { x: 0; y: pool.height }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.bg, 1.16) }
            GradientStop { position: 0.48; color: root.bg }
            GradientStop { position: 1; color: Qt.darker(root.bg, 1.22) }
        }
    }

    LightPool {
        tint: root.primary
        centerX: root.width * 0.14
        centerY: root.height * 0.22
        spread: Math.max(root.width, root.height) * 0.58
        intensity: 0.54

        SequentialAnimation on centerX {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.width * 0.46; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.1; duration: 27000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on centerY {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.height * 0.5; duration: 29000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.16; duration: 26000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on spread {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: Math.max(root.width, root.height) * 0.7; duration: 18000; easing.type: Easing.InOutSine }
            NumberAnimation { to: Math.max(root.width, root.height) * 0.54; duration: 22000; easing.type: Easing.InOutSine }
        }
    }

    LightPool {
        tint: root.secondary
        centerX: root.width * 0.88
        centerY: root.height * 0.14
        spread: Math.max(root.width, root.height) * 0.64
        intensity: 0.48

        SequentialAnimation on centerX {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.width * 0.54; duration: 31000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.92; duration: 28000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on centerY {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.height * 0.62; duration: 26000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.08; duration: 30000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on spread {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: Math.max(root.width, root.height) * 0.52; duration: 21000; easing.type: Easing.InOutSine }
            NumberAnimation { to: Math.max(root.width, root.height) * 0.68; duration: 24000; easing.type: Easing.InOutSine }
        }
    }

    LightPool {
        tint: root.accent
        centerX: root.width * 0.34
        centerY: root.height * 0.88
        spread: Math.max(root.width, root.height) * 0.5
        intensity: 0.4

        SequentialAnimation on centerX {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.width * 0.76; duration: 27000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.28; duration: 32000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on centerY {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.height * 0.58; duration: 23000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.92; duration: 28000; easing.type: Easing.InOutSine }
        }
    }

    // A dim counter-flowing lobe adds depth where the larger fields overlap.
    LightPool {
        tint: root.primary
        centerX: root.width * 0.72
        centerY: root.height * 0.74
        spread: Math.max(root.width, root.height) * 0.34
        intensity: 0.2

        SequentialAnimation on centerX {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.width * 0.42; duration: 34000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.8; duration: 30000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on centerY {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.height * 0.36; duration: 30000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.8; duration: 35000; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.035) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.015) }
            GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0.08) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.24) }
        }
    }

    // Thin milk-glass veil keeps intersections creamy instead of neon.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.8, 0.86, 1, 0.025)
    }
}
