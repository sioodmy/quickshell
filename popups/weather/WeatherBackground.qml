import QtQuick
import QtQuick.Effects

// Animated weather background with particles and effects
// modeled after Breezy Weather / Modern Google M3
Item {
    id: bg
    property string weatherCode: ""
    property string temperature: ""
    property bool miniMode: false
    clip: true

    readonly property bool isRain: ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(weatherCode) >= 0
    readonly property bool isHeavyRain: ["302","305","308","356","359"].indexOf(weatherCode) >= 0
    readonly property bool isThunder: ["200","386","389","392"].indexOf(weatherCode) >= 0
    readonly property bool isSnow: ["179","227","230","329","332","335","338","371","395","182","185","311","314","317","320","323","326","350","362","365","368","374","377"].indexOf(weatherCode) >= 0
    readonly property bool isCloudy: ["119","122"].indexOf(weatherCode) >= 0
    readonly property bool isFog: ["143","248","260"].indexOf(weatherCode) >= 0
    readonly property bool isSunny: weatherCode === "113"
    readonly property bool isPartly: weatherCode === "116"
    readonly property bool isHell: {
        var t = parseInt(temperature);
        return !isNaN(t) && t >= 30;
    }

    // ===== SUN GLOW =====
    Item {
        visible: isSunny || isPartly
        width: miniMode ? 100 : 240
        height: miniMode ? 100 : 240
        x: bg.width - (miniMode ? 50 : 150)
        y: miniMode ? -20 : -60

        // Soft, wide outer glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.8, 0.2, miniMode ? 0.08 : 0.15) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.6, 0.1, miniMode ? 0.02 : 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 0.95; to: 1.1; duration: miniMode ? 12000 : 4000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.1; to: 0.95; duration: miniMode ? 12000 : 4000; easing.type: Easing.InOutSine }
            }
        }

        // Warmer inner core
        Rectangle {
            anchors.centerIn: parent
            width: miniMode ? 60 : 140
            height: miniMode ? 60 : 140
            radius: width / 2
            color: "transparent"

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.85, 0.4, miniMode ? 0.12 : 0.2) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.05; duration: miniMode ? 10000 : 3000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 0.9; duration: miniMode ? 10000 : 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    // ===== RAIN DROPS =====
    Repeater {
        model: (isRain || isThunder) ? (miniMode ? (isHeavyRain ? 6 : 3) : (isHeavyRain || isThunder ? 60 : 30)) : 0
        delegate: Rectangle {
            id: raindrop
            width: miniMode ? 1 : 1.5
            height: (miniMode ? 6 : 18) + Math.random() * (miniMode ? 6 : 15)
            radius: 1
            color: Qt.rgba(1, 1, 1, miniMode ? 0.15 : 0.35)
            x: Math.random() * bg.width
            rotation: 12

            property real startY: -(Math.random() * bg.height)
            property real speed: (800 + Math.random() * 500) * (miniMode ? 8 : 1)
            y: startY

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    from: raindrop.startY
                    to: bg.height + 40
                    duration: raindrop.speed
                    easing.type: Easing.Linear
                }
                NumberAnimation {
                    from: raindrop.startY
                    to: raindrop.startY
                    duration: 0
                }
            }
        }
    }

    // ===== THUNDER FLASH =====
    Rectangle {
        visible: isThunder
        anchors.fill: parent
        color: "white"
        opacity: 0

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: isThunder
            PauseAnimation { duration: (2500 + Math.random() * 5000) * (miniMode ? 3 : 1) }
            NumberAnimation { to: miniMode ? 0.15 : 0.4; duration: miniMode ? 120 : 40 }
            NumberAnimation { to: 0; duration: miniMode ? 240 : 80 }
            PauseAnimation { duration: miniMode ? 300 : 100 }
            NumberAnimation { to: miniMode ? 0.08 : 0.2; duration: miniMode ? 90 : 30 }
            NumberAnimation { to: 0; duration: miniMode ? 450 : 150 }
        }
    }

    // ===== SNOW FLAKES =====
    Repeater {
        model: isSnow ? (miniMode ? 6 : 45) : 0
        delegate: Rectangle {
            id: snowflake
            width: (miniMode ? 2 : 4) + Math.random() * (miniMode ? 2 : 5)
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, miniMode ? 0.3 : 0.6)

            property real startX: Math.random() * bg.width
            property real startY: -(Math.random() * bg.height)
            property real speed: (4000 + Math.random() * 4000) * (miniMode ? 6 : 1)
            property real drift: (25 + Math.random() * 30) * (miniMode ? 0.3 : 1)

            x: startX
            y: startY

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    from: snowflake.startY
                    to: bg.height + 20
                    duration: snowflake.speed
                    easing.type: Easing.Linear
                }
                NumberAnimation { from: snowflake.startY; to: snowflake.startY; duration: 0 }
            }

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: snowflake.startX - snowflake.drift
                    to: snowflake.startX + snowflake.drift
                    duration: snowflake.speed * 0.7
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: snowflake.startX + snowflake.drift
                    to: snowflake.startX - snowflake.drift
                    duration: snowflake.speed * 0.7
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ===== REALISTIC PUFFY CLOUDS =====
    Component {
        id: cloudComponent
        Item {
            width: miniMode ? 60 : 120
            height: miniMode ? 30 : 60
            property real baseOpacity: 0.15

            // Puffy shapes making up the cloud
            Rectangle { x: parent.width*0.08; y: parent.height*0.5; width: parent.width*0.75; height: parent.height*0.5; radius: height/2; color: "white"; opacity: parent.baseOpacity }
            Rectangle { x: parent.width*0.2; y: parent.height*0.25; width: parent.width*0.33; height: parent.width*0.33; radius: height/2; color: "white"; opacity: parent.baseOpacity }
            Rectangle { x: parent.width*0.41; y: parent.height*0.08; width: parent.width*0.41; height: parent.width*0.41; radius: height/2; color: "white"; opacity: parent.baseOpacity }
        }
    }

    Repeater {
        model: (isCloudy || isPartly || isFog) ? (miniMode ? (isFog ? 2 : 1) : (isFog ? 6 : 4)) : 0
        delegate: Loader {
            sourceComponent: cloudComponent
            y: (miniMode ? 2 : 10) + index * (miniMode ? 10 : 45) + Math.random() * (miniMode ? 5 : 20)
            
            onLoaded: {
                item.baseOpacity = (isFog ? 0.08 : (isCloudy ? 0.15 : 0.1)) * (miniMode ? 0.5 : 1.0)
                // Random scale
                item.scale = 0.8 + Math.random() * 0.5
            }

            property real startX: -150 - Math.random() * 200
            x: startX

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: startX
                    to: bg.width + 50
                    duration: (25000 + Math.random() * 15000) * (miniMode ? 4 : 1)
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // ===== FOG LAYERS =====
    Repeater {
        model: isFog ? (miniMode ? 1 : 3) : 0
        delegate: Rectangle {
            id: fogLayer
            width: bg.width * 1.5
            height: (60 + Math.random() * 40) * (miniMode ? 0.5 : 1)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, miniMode ? 0.02 : 0.04)
            y: bg.height * (miniMode ? 0.1 : 0.4) + index * 40

            property real baseX: -80
            x: baseX

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: fogLayer.baseX - 40
                    to: fogLayer.baseX + 40
                    duration: (8000 + Math.random() * 5000) * (miniMode ? 4 : 1)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: fogLayer.baseX + 40
                    to: fogLayer.baseX - 40
                    duration: (8000 + Math.random() * 5000) * (miniMode ? 4 : 1)
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ===== HELL / FIRE =====
    Repeater {
        model: isHell && !miniMode ? 40 : 0
        delegate: Rectangle {
            id: ember
            width: (miniMode ? 2 : 4) + Math.random() * (miniMode ? 2 : 4)
            height: width
            radius: width / 2
            
            // Fire colors: Red, Orange, Yellow
            property var colors: [Qt.rgba(1, 0.2, 0, 0.8), Qt.rgba(1, 0.5, 0, 0.8), Qt.rgba(1, 0.8, 0, 0.8)]
            color: colors[Math.floor(Math.random() * colors.length)]

            property real startX: Math.random() * bg.width
            property real startY: bg.height + Math.random() * 20
            property real speed: (2000 + Math.random() * 3000) * (miniMode ? 3 : 1)
            property real drift: (15 + Math.random() * 20) * (miniMode ? 0.3 : 1)

            x: startX
            y: startY

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    from: ember.startY
                    to: -20
                    duration: ember.speed
                    easing.type: Easing.OutSine
                }
                NumberAnimation { from: ember.startY; to: ember.startY; duration: 0 }
            }

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: ember.startX - ember.drift
                    to: ember.startX + ember.drift
                    duration: ember.speed * 0.6
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: ember.startX + ember.drift
                    to: ember.startX - ember.drift
                    duration: ember.speed * 0.6
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0; duration: ember.speed; easing.type: Easing.InQuad }
                NumberAnimation { from: 1; to: 1; duration: 0 }
            }
        }
    }
}
