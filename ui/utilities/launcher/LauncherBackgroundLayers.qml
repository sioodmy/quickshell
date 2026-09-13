import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import "../../theme"
import qs.components

Item {
    id: bgLayersRoot
    
    property bool weatherModeActive: false
    property bool colorPickerModeActive: false
    property bool nightModeActive: false
    property bool menuOpen: false
    
    // Weather properties
    property string weatherCode: ""
    property real temperature: 0
    property color gradTop: "transparent"
    property color gradBottom: "transparent"
    
    // Color picker property
    property color selectedColor: "transparent"
    
    clip: true

    property real bannerBlend: (weatherModeActive || colorPickerModeActive || nightModeActive) ? 1 : 0
    property real weatherBlend: weatherModeActive ? 1 : 0
    property real colorBlend: colorPickerModeActive ? 1 : 0
    property real nightBlend: nightModeActive ? 1 : 0

    Behavior on bannerBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
    Behavior on weatherBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
    Behavior on colorBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
    Behavior on nightBlend { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

    onWeatherModeActiveChanged: {
        bannerShimmer.restart();
    }
    onNightModeActiveChanged: {
        bannerShimmer.restart();
    }

    // A pool of coloured light with a smooth radial falloff. Nothing reaches
    // full opacity, so the compositor blur stays visible through the header,
    // and nothing has an edge, so no shape reads as a drawn object.
    component LightPool: Shape {
        id: pool

        property color tint: "#ffffff"
        property real centerX: 0
        property real centerY: 0
        property real spread: 320
        property real intensity: 0.7

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

                // A steep tail lets the pool reach zero well inside the header,
                // so the colour melts into the glass with no cut-off edge.
                GradientStop { position: 0.0; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity) }
                GradientStop { position: 0.35; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.62) }
                GradientStop { position: 0.62; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.26) }
                GradientStop { position: 0.82; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, pool.intensity * 0.06) }
                GradientStop { position: 1.0; color: Qt.rgba(pool.tint.r, pool.tint.g, pool.tint.b, 0.0) }
            }

            startX: 0
            startY: 0
            PathLine { x: pool.width; y: 0 }
            PathLine { x: pool.width; y: pool.height }
            PathLine { x: 0; y: pool.height }
        }
    }

    // --- Liquid aurora launcher background ---
    Item {
        id: pinkLayer
        anchors.fill: parent
        opacity: 1 - bgLayersRoot.bannerBlend
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

        LightPool {
            tint: "#ff5aa8"
            centerY: 10
            spread: 220
            intensity: 0.68
            centerX: 150

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen
                NumberAnimation { to: 300; duration: 13000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 150; duration: 15000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#c76ad9"
            centerX: 405
            centerY: 10
            spread: 230
            intensity: 0.56

            SequentialAnimation on centerY {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen
                NumberAnimation { to: -18; duration: 10500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 10; duration: 12500; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#7a5cf0"
            centerY: 0
            spread: 230
            intensity: 0.7
            centerX: 660

            SequentialAnimation on centerX {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen
                NumberAnimation { to: 510; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 660; duration: 12000; easing.type: Easing.InOutSine }
            }
        }

        LightPool {
            tint: "#ffd4ec"
            centerX: 330
            spread: 190
            intensity: 0.4
            centerY: -40

            SequentialAnimation on centerY {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen
                NumberAnimation { to: 4; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -40; duration: 11000; easing.type: Easing.InOutSine }
            }
        }

        // Specular sheen along the top edge, the way light catches the lip of
        // a thick glass panel.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.24) }
                GradientStop { position: 0.16; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            width: parent.width * 0.6
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 1
            color: Qt.rgba(1, 1, 1, 0.45)
        }
    }

    // --- Weather reactive background ---
    Item {
        id: weatherBannerLayer
        anchors.fill: parent
        opacity: bgLayersRoot.weatherBlend
        scale: 1.04 - 0.04 * bgLayersRoot.weatherBlend
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: bgLayersRoot.gradTop
                    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                }
                GradientStop {
                    position: 1.0
                    color: bgLayersRoot.gradBottom
                    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                }
            }
        }

        WeatherBackground {
            id: bannerWeatherAnim
            anchors.fill: parent
            weatherCode: bgLayersRoot.weatherCode
            temperature: bgLayersRoot.temperature
            visible: bgLayersRoot.weatherBlend > 0.02
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
            }
        }
    }

    // --- Color Picker background ---
    Item {
        id: colorPickerBannerLayer
        anchors.fill: parent
        opacity: bgLayersRoot.colorBlend
        scale: 1.04 - 0.04 * bgLayersRoot.colorBlend
        transformOrigin: Item.Center
        visible: opacity > 0.02

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: bgLayersRoot.selectedColor
        }
    }

    // --- Night Light background ---
    Item {
        id: nightBannerLayer
        anchors.fill: parent
        opacity: bgLayersRoot.nightBlend
        scale: 1.04 - 0.04 * bgLayersRoot.nightBlend
        transformOrigin: Item.Center
        visible: opacity > 0.02

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1a1040" }
                GradientStop { position: 0.4; color: "#2d1b69" }
                GradientStop { position: 0.7; color: "#4a1942" }
                GradientStop { position: 1.0; color: "#e65100" }
            }
        }

        Rectangle {
            width: 180
            height: 180
            radius: 90
            color: "#ffb74d"
            opacity: 0.12
            x: parent.width - 140
            y: -30

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen || !bgLayersRoot.nightModeActive
                NumberAnimation { to: 0.20; duration: 3000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.08; duration: 3000; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            width: 120
            height: 120
            radius: 60
            color: "#ff8f00"
            opacity: 0.10
            x: 60
            y: 40

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                paused: !bgLayersRoot.menuOpen || !bgLayersRoot.nightModeActive
                NumberAnimation { to: 0.18; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.06; duration: 3500; easing.type: Easing.InOutSine }
            }
        }

        MaterialIcon {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10
            icon: "bedtime"
            font.pixelSize: 64
            color: Qt.rgba(1, 0.72, 0.3, 0.35)
        }
    }

    // --- Transition shimmer ---
    Rectangle {
        id: shimmerBar
        z: 3
        width: parent.width * 0.45
        height: parent.height
        y: 0
        x: -width
        opacity: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.22) }
            GradientStop { position: 0.65; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation {
            id: bannerShimmer
            running: false

            PropertyAnimation {
                target: shimmerBar
                property: "opacity"
                from: 0; to: 0.85; duration: 80
            }
            NumberAnimation {
                target: shimmerBar
                property: "x"
                from: -shimmerBar.width
                to: bgLayersRoot.width + shimmerBar.width
                duration: 420
                easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: shimmerBar
                property: "opacity"
                from: 0.85; to: 0; duration: 120
            }
        }
    }
}
