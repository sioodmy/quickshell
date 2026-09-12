import QtQuick
import QtQuick.Shapes

/**
 * Album-tinted aurora. Cover art is decoded tiny and stretched fullscreen
 * so it reads as blur without ShaderEffectSource / MultiEffect (those crash
 * updatePixelRatioHelper on Asahi).
 */
Item {
    id: root
    anchors.fill: parent
    clip: true

    property url artUrl: ""
    property color primary: "#ff7ec0"
    property color secondary: "#8b74ff"
    property color accent: "#e08cff"
    property color bg: "#24143a"
    property bool alive: true

    Behavior on primary { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on secondary { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on bg { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }

    property int front: 0
    property string loadedA: ""
    property string loadedB: ""

    function enqueueArt(url) {
        const s = "" + url;
        if (s === "")
            return;
        if (s === loadedA) {
            front = 0;
            return;
        }
        if (s === loadedB) {
            front = 1;
            return;
        }
        if (front === 0)
            imgB.source = s;
        else
            imgA.source = s;
    }

    onArtUrlChanged: enqueueArt(artUrl)
    Component.onCompleted: enqueueArt(artUrl)

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
                GradientStop { position: 0.4; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.45) }
                GradientStop { position: 0.75; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.12) }
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
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        sourceSize: Qt.size(28, 16)
        opacity: (root.front === 0 && status === Image.Ready) ? 0.82 : 0
        Behavior on opacity { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        onStatusChanged: {
            if (status === Image.Ready) {
                root.loadedA = "" + source;
                root.front = 0;
            }
        }
    }

    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        sourceSize: Qt.size(28, 16)
        opacity: (root.front === 1 && status === Image.Ready) ? 0.82 : 0
        Behavior on opacity { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        onStatusChanged: {
            if (status === Image.Ready) {
                root.loadedB = "" + source;
                root.front = 1;
            }
        }
    }

    LightPool {
        tint: root.primary
        centerX: root.width * 0.22
        centerY: root.height * 0.3
        spread: Math.max(root.width, root.height) * 0.48
        intensity: 0.58

        SequentialAnimation on centerX {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.width * 0.42; duration: 20000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.16; duration: 18000; easing.type: Easing.InOutSine }
        }
    }

    LightPool {
        tint: root.secondary
        centerX: root.width * 0.76
        centerY: root.height * 0.22
        spread: Math.max(root.width, root.height) * 0.52
        intensity: 0.5

        SequentialAnimation on centerY {
            loops: Animation.Infinite
            paused: !root.alive
            NumberAnimation { to: root.height * 0.48; duration: 22000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.1; duration: 19000; easing.type: Easing.InOutSine }
        }
    }

    LightPool {
        tint: root.accent
        centerX: root.width * 0.5
        centerY: root.height * 0.72
        spread: Math.max(root.width, root.height) * 0.4
        intensity: 0.34
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.08) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.02) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.16) }
        }
    }
}
