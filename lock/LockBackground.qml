import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

/**
 * Fullscreen liquid aurora for the lock surface.
 *
 * Heavy MultiEffect blur is armed only after the lock surface has settled —
 * enabling ShaderEffectSource / layered blur on first map crashes
 * updatePixelRatioHelper on Asahi.
 */
Item {
    id: root
    anchors.fill: parent

    property real progress: 1.0
    property real unlockProgress: 0.0

    readonly property bool alive: progress > 0.45 && unlockProgress < 0.55
    property bool blurArmed: false

    component LightPool: Shape {
        id: pool

        property color tint: "#ffffff"
        property real centerX: 0
        property real centerY: 0
        property real spread: 420
        property real intensity: 0.55

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
                GradientStop { position: 0.28; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.72) }
                GradientStop { position: 0.52; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.35) }
                GradientStop { position: 0.78; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.1) }
                GradientStop { position: 1.0; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, 0.0) }
            }

            startX: 0
            startY: 0
            PathLine { x: pool.width; y: 0 }
            PathLine { x: pool.width; y: pool.height }
            PathLine { x: 0; y: pool.height }
        }
    }

    // Brighter base under the bloom
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#3a2460" }
            GradientStop { position: 0.45; color: "#2e2250" }
            GradientStop { position: 1.0; color: "#1e2a44" }
        }
    }

    Item {
        id: aurora
        anchors.fill: parent
        opacity: Math.max(0, (root.progress - 0.12) / 0.88)

        // Arm blur after first frames so WlSessionLockSurface mapping is done.
        layer.enabled: root.blurArmed
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            blurMultiplier: 2.0
            brightness: 0.12
            saturation: 0.18
        }

        LightPool {
            tint: "#ff8ad0"
            centerX: root.width * 0.18
            centerY: root.height * 0.22
            spread: Math.max(root.width, root.height) * 0.58
            intensity: 0.78

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.width * 0.42; duration: 18000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.width * 0.12; duration: 21000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on centerY {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.height * 0.08; duration: 15000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.height * 0.38; duration: 19000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#9b86ff"
            centerX: root.width * 0.74
            centerY: root.height * 0.18
            spread: Math.max(root.width, root.height) * 0.64
            intensity: 0.7

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.width * 0.52; duration: 20000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.width * 0.86; duration: 17000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on centerY {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.height * 0.45; duration: 22000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.height * 0.06; duration: 18000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#eda0ff"
            centerX: root.width * 0.48
            centerY: root.height * 0.55
            spread: Math.max(root.width, root.height) * 0.52
            intensity: 0.6

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.width * 0.28; duration: 24000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.width * 0.68; duration: 20000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#7af0e6"
            centerX: root.width * 0.3
            centerY: root.height * 0.78
            spread: Math.max(root.width, root.height) * 0.44
            intensity: 0.48

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.width * 0.55; duration: 26000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.width * 0.16; duration: 22000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#ffe8f6"
            centerX: root.width * 0.62
            centerY: root.height * 0.08
            spread: Math.max(root.width, root.height) * 0.38
            intensity: 0.5
        }

        Rectangle {
            width: Math.max(root.width, root.height) * 0.52
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.68, 0.86, 0.22)
            x: root.width * -0.1
            y: root.height * 0.1

            SequentialAnimation on x {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.width * 0.22; duration: 22000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.width * -0.12; duration: 24000; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            width: Math.max(root.width, root.height) * 0.44
            height: width
            radius: width / 2
            color: Qt.rgba(0.62, 0.5, 1, 0.2)
            x: root.width * 0.58
            y: root.height * -0.08

            SequentialAnimation on y {
                loops: Animation.Infinite
                running: root.alive
                NumberAnimation { to: root.height * 0.28; duration: 19000; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.height * -0.1; duration: 22000; easing.type: Easing.InOutSine }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, (root.progress - 0.25) / 0.75)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
            GradientStop { position: 0.22; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.08) }
        }
    }

    Timer {
        id: blurArm
        interval: 420
        onTriggered: root.blurArmed = true
    }

    Component.onCompleted: blurArm.start()
    onAliveChanged: {
        if (!alive)
            root.blurArmed = false;
        else if (!blurArm.running && !root.blurArmed)
            blurArm.start();
    }
}
