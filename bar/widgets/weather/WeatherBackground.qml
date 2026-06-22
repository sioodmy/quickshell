import QtQuick
import QtQuick.Effects

// Animated weather background with particles and effects
// modeled after Breezy Weather / Modern Google M3
Item {
    id: bg
    property string weatherCode: ""
    clip: true

    readonly property bool isRain: ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(weatherCode) >= 0
    readonly property bool isHeavyRain: ["302","305","308","356","359"].indexOf(weatherCode) >= 0
    readonly property bool isThunder: ["200","386","389","392"].indexOf(weatherCode) >= 0
    readonly property bool isSnow: ["179","227","230","329","332","335","338","371","395","182","185","311","314","317","320","323","326","350","362","365","368","374","377"].indexOf(weatherCode) >= 0
    readonly property bool isCloudy: ["119","122"].indexOf(weatherCode) >= 0
    readonly property bool isFog: ["143","248","260"].indexOf(weatherCode) >= 0
    readonly property bool isSunny: weatherCode === "113"
    readonly property bool isPartly: weatherCode === "116"

    // ===== SUN GLOW =====
    Item {
        visible: isSunny || isPartly
        width: 240
        height: 240
        x: bg.width - 150
        y: -60

        // Soft, wide outer glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.8, 0.2, 0.15) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.6, 0.1, 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 0.95; to: 1.1; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.1; to: 0.95; duration: 4000; easing.type: Easing.InOutSine }
            }
        }

        // Warmer inner core
        Rectangle {
            anchors.centerIn: parent
            width: 140
            height: 140
            radius: 70
            color: "transparent"

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.85, 0.4, 0.2) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.05; duration: 3000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 0.9; duration: 3000; easing.type: Easing.InOutSine }
            }
        }
    }

    // ===== RAIN DROPS =====
    Repeater {
        model: (isRain || isThunder) ? (isHeavyRain || isThunder ? 60 : 30) : 0
        delegate: Rectangle {
            id: raindrop
            width: 1.5
            height: 18 + Math.random() * 15
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.35)
            x: Math.random() * bg.width
            rotation: 12

            property real startY: -(Math.random() * bg.height)
            property real speed: 800 + Math.random() * 500
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
            PauseAnimation { duration: 2500 + Math.random() * 5000 }
            NumberAnimation { to: 0.4; duration: 40 }
            NumberAnimation { to: 0; duration: 80 }
            PauseAnimation { duration: 100 }
            NumberAnimation { to: 0.2; duration: 30 }
            NumberAnimation { to: 0; duration: 150 }
        }
    }

    // ===== SNOW FLAKES =====
    Repeater {
        model: isSnow ? 45 : 0
        delegate: Rectangle {
            id: snowflake
            width: 4 + Math.random() * 5
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.6)

            property real startX: Math.random() * bg.width
            property real startY: -(Math.random() * bg.height)
            property real speed: 4000 + Math.random() * 4000
            property real drift: 25 + Math.random() * 30

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
            width: 120
            height: 60
            property real baseOpacity: 0.15

            // Puffy shapes making up the cloud
            Rectangle { x: 10; y: 30; width: 90; height: 30; radius: 15; color: "white"; opacity: parent.baseOpacity }
            Rectangle { x: 25; y: 15; width: 40; height: 40; radius: 20; color: "white"; opacity: parent.baseOpacity }
            Rectangle { x: 50; y: 5; width: 50; height: 50; radius: 25; color: "white"; opacity: parent.baseOpacity }
        }
    }

    Repeater {
        model: (isCloudy || isPartly || isFog) ? (isFog ? 6 : 4) : 0
        delegate: Loader {
            sourceComponent: cloudComponent
            y: 10 + index * 45 + Math.random() * 20
            
            onLoaded: {
                item.baseOpacity = isFog ? 0.08 : (isCloudy ? 0.15 : 0.1)
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
                    duration: 25000 + Math.random() * 15000
                    easing.type: Easing.Linear
                }
            }
        }
    }

    // ===== FOG LAYERS =====
    Repeater {
        model: isFog ? 3 : 0
        delegate: Rectangle {
            id: fogLayer
            width: bg.width * 1.5
            height: 60 + Math.random() * 40
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.04)
            y: bg.height * 0.4 + index * 40

            property real baseX: -80
            x: baseX

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: fogLayer.baseX - 40
                    to: fogLayer.baseX + 40
                    duration: 8000 + Math.random() * 5000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: fogLayer.baseX + 40
                    to: fogLayer.baseX - 40
                    duration: 8000 + Math.random() * 5000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
