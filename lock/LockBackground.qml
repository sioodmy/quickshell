import QtQuick
import QtQuick.Shapes

import qs.theme
import qs.services

/**
 * Shader-light lock backdrop.
 *
 * Wallpaper and album art are decoded at deliberately small resolutions so
 * scaling them fullscreen creates a soft diffusion without ShaderEffectSource
 * or MultiEffect. This keeps the WlSessionLockSurface mapping path safe on
 * Asahi while still producing an album-aware, liquid atmosphere.
 */
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real progress: 1
    property bool alive: true

    readonly property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0
    readonly property color baseColor: mediaActive ? Playerctl.artBg : Theme.background
    readonly property color primaryGlow: mediaActive ? Playerctl.artPrimary : Theme.primary
    readonly property color secondaryGlow: mediaActive ? Playerctl.artSecondary : Theme.secondary
    readonly property color accentGlow: mediaActive ? Playerctl.artAccent : Theme.tertiary
    readonly property url wallpaperUrl: {
        const path = Theme.wallpaper_path || "";
        if (path.length === 0)
            return "";
        return path.indexOf("file:") === 0 ? path : "file://" + path;
    }

    opacity: Math.max(0, Math.min(1, progress))

    component LightPool: Shape {
        id: pool

        property color tint: "white"
        property real centerX: 0
        property real centerY: 0
        property real spread: 500
        property real intensity: 0.3

        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: pool.centerX
                centerY: pool.centerY
                centerRadius: pool.spread
                focalX: pool.centerX
                focalY: pool.centerY

                GradientStop {
                    position: 0
                    color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity)
                }
                GradientStop {
                    position: 0.38
                    color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.48)
                }
                GradientStop {
                    position: 0.76
                    color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.1)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, 0)
                }
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
        color: root.baseColor

        Behavior on color {
            ColorAnimation { duration: 520; easing.type: Easing.OutCubic }
        }
    }

    // A real wallpaper when configured, softly decoded to avoid a large
    // texture upload during the first lock frame.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperUrl
        sourceSize: Qt.size(720, 450)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        opacity: status === Image.Ready ? 0.72 : 0
        scale: 1.04 + root.progress * 0.015

        Behavior on opacity { NumberAnimation { duration: 360 } }
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    // Album art is used as a faint color wash, never as readable content.
    Image {
        id: albumWash
        anchors.fill: parent
        source: root.mediaActive ? Playerctl.artUrl : ""
        sourceSize: Qt.size(40, 24)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        opacity: status === Image.Ready && root.mediaActive ? 0.22 : 0

        Behavior on opacity { NumberAnimation { duration: 440; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent
        opacity: 0.92

        LightPool {
            tint: root.primaryGlow
            centerX: root.width * 0.18
            centerY: root.height * 0.28
            spread: Math.max(root.width, root.height) * 0.58
            intensity: root.mediaActive ? 0.48 : 0.34

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                paused: !root.alive
                NumberAnimation {
                    to: root.width * 0.36
                    duration: 19000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.width * 0.14
                    duration: 22000
                    easing.type: Easing.InOutSine
                }
            }
        }

        LightPool {
            tint: root.secondaryGlow
            centerX: root.width * 0.82
            centerY: root.height * 0.22
            spread: Math.max(root.width, root.height) * 0.62
            intensity: root.mediaActive ? 0.44 : 0.3

            SequentialAnimation on centerY {
                loops: Animation.Infinite
                paused: !root.alive
                NumberAnimation {
                    to: root.height * 0.46
                    duration: 23000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.height * 0.12
                    duration: 20000
                    easing.type: Easing.InOutSine
                }
            }
        }

        LightPool {
            tint: root.accentGlow
            centerX: root.width * 0.52
            centerY: root.height * 0.78
            spread: Math.max(root.width, root.height) * 0.46
            intensity: root.mediaActive ? 0.34 : 0.22

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                paused: !root.alive
                NumberAnimation {
                    to: root.width * 0.7
                    duration: 26000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: root.width * 0.38
                    duration: 24000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // Readability wash and edge vignette.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.1) }
            GradientStop { position: 0.34; color: Qt.rgba(0, 0, 0, 0.03) }
            GradientStop { position: 0.72; color: Qt.rgba(0, 0, 0, 0.13) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.34) }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.025, 0.03, 0.055, 0.18)
    }
}
