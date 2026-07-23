import QtQuick
import Quickshell.Widgets
import "../../theme"
import "../../popups/weather"

Item {
    id: edgeBanner
    
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

    // --- Pink launcher background ---
    Item {
        id: pinkLayer
        anchors.fill: parent
        opacity: 1 - edgeBanner.bannerBlend
        scale: 1 - 0.05 * edgeBanner.bannerBlend
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#f5bde6"
        }

        Rectangle {
            width: 320
            height: 320
            radius: 160
            color: "#ffffff"
            opacity: 0.40
            x: -20
            y: -50
            transformOrigin: Item.Center

            SequentialAnimation on x {
                loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
                NumberAnimation { to: 180; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -60; duration: 18000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -20; duration: 15000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
                NumberAnimation { to: -100; duration: 17000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 40; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -50; duration: 16000; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation {
                from: 0; to: 360; duration: 30000; loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
            }
        }

        Rectangle {
            width: 300
            height: 300
            radius: 150
            color: "#c6a0f6"
            opacity: 0.60
            x: 350
            y: -40
            transformOrigin: Item.Center

            SequentialAnimation on x {
                loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
                NumberAnimation { to: 150; duration: 18000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 480; duration: 19000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 350; duration: 17000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
                NumberAnimation { to: 60; duration: 16000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -120; duration: 18000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -40; duration: 16000; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation {
                from: 360; to: 0; duration: 35000; loops: Animation.Infinite
                paused: !edgeBanner.menuOpen || edgeBanner.weatherModeActive
            }
        }
    }

    // --- Weather reactive background ---
    Item {
        id: weatherBannerLayer
        anchors.fill: parent
        opacity: edgeBanner.weatherBlend
        scale: 1.04 - 0.04 * edgeBanner.weatherBlend
        transformOrigin: Item.Center

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: edgeBanner.gradTop
                    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                }
                GradientStop {
                    position: 1.0
                    color: edgeBanner.gradBottom
                    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
                }
            }
        }

        WeatherBackground {
            id: bannerWeatherAnim
            anchors.fill: parent
            weatherCode: edgeBanner.weatherCode
            temperature: edgeBanner.temperature
            visible: edgeBanner.weatherBlend > 0.02
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
        opacity: edgeBanner.colorBlend
        scale: 1.04 - 0.04 * edgeBanner.colorBlend
        transformOrigin: Item.Center
        visible: opacity > 0.02

        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: edgeBanner.selectedColor
        }
    }

    // --- Night Light background ---
    Item {
        id: nightBannerLayer
        anchors.fill: parent
        opacity: edgeBanner.nightBlend
        scale: 1.04 - 0.04 * edgeBanner.nightBlend
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
                paused: !edgeBanner.menuOpen || !edgeBanner.nightModeActive
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
                paused: !edgeBanner.menuOpen || !edgeBanner.nightModeActive
                NumberAnimation { to: 0.18; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.06; duration: 3500; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10
            text: "󰖔"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 64 }
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
                to: edgeBanner.width + shimmerBar.width
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
