import QtQuick
import QtQuick.Effects
import "../../theme"
import qs.services
import qs.components

Item {
    id: root

    property bool active: false
    // NOTE: In a real implementation this would tie into the Rust backend's idle inhibition logic.
    // For now, we simulate the state.
    property bool caffeineEnabled: false

    implicitHeight: active ? 84 : 0
    signal toggled(bool enabled)
    opacity: active ? 1 : 0
    visible: opacity > 0.02
    clip: true

    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        radius: 20
        color: Theme.surface_container_high
        border.color: caffeineEnabled
            ? Qt.rgba(1, 0, 1, 0.5) // Flashy neon pink edge
            : Theme.outline_variant
        border.width: caffeineEnabled ? 2 : 1
        clip: true

        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: tripMask
            anchors.fill: parent
            radius: 20
            visible: false
            layer.enabled: true
        }

        // The "trip" gradient background that animates when active
        Item {
            anchors.fill: parent
            opacity: caffeineEnabled ? 0.3 : 0

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: tripMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

            Rectangle {
                id: tripBackground
                anchors.centerIn: parent
                width: parent.width
                height: parent.height

                gradient: Gradient {
                    id: tripGrad
                    GradientStop { position: 0.0; color: "#ff0080" }
                    GradientStop { position: 0.33; color: "#ff8c00" }
                    GradientStop { position: 0.66; color: "#40e0d0" }
                    GradientStop { position: 1.0; color: "#8a2be2" }
                }

                // Spin the gradient to simulate a trip
                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 2500
                    running: caffeineEnabled
                }
                // Scale it up so rotation doesn't show corners
                scale: 2.0
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            z: 2 // Make sure it sits above the background

            Rectangle {
                width: 44
                height: 44
                radius: 22
                anchors.verticalCenter: parent.verticalCenter
                color: caffeineEnabled
                    ? Qt.rgba(1, 1, 1, 0.2)
                    : Theme.surface_variant

                Behavior on color { ColorAnimation { duration: 220 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: caffeineEnabled ? "coffee" : "coffee_maker"
                    font.pixelSize: 24
                    color: caffeineEnabled ? "#ffffff" : Theme.on_surface_variant

                    scale: 1.0
                    onIconChanged: iconPulse.restart()
                    SequentialAnimation {
                        id: iconPulse
                        NumberAnimation { target: parent; property: "scale"; to: 1.3; duration: 80; easing.type: Easing.OutElastic }
                        NumberAnimation { target: parent; property: "scale"; to: 1.0; duration: 150; easing.type: Easing.OutBounce }
                    }

                    // Jitter animation when enabled
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: caffeineEnabled
                        NumberAnimation { to: 13; duration: 50 }
                        NumberAnimation { to: 11; duration: 50 }
                        NumberAnimation { to: 12; duration: 50 }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: caffeineEnabled
                        NumberAnimation { to: 11; duration: 40 }
                        NumberAnimation { to: 13; duration: 60 }
                        NumberAnimation { to: 12; duration: 50 }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - 12 - cocSwitch.width - 12
                spacing: 2

                Text {
                    text: "Cocaine"
                    font { family: "Google Sans Medium"; pixelSize: 15 }
                    color: Theme.on_surface

                    // Slight color shifting on the text
                    SequentialAnimation on color {
                        loops: Animation.Infinite
                        running: caffeineEnabled
                        ColorAnimation { to: "#ff0080"; duration: 300 }
                        ColorAnimation { to: "#00ffff"; duration: 300 }
                        ColorAnimation { to: Theme.on_surface; duration: 300 }
                    }
                }
                Text {
                    width: parent.width
                    text: caffeineEnabled
                        ? "I AM AWAKE I AM AWAKE I AM AWAKE"
                        : "Keep the computer from falling asleep"
                    font { family: "Google Sans"; pixelSize: 11 }
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: cocSwitch
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 32
                radius: 16
                color: caffeineEnabled ? "#ff0055" : Theme.surface_container_highest
                border.color: caffeineEnabled ? "#ff0055" : Theme.outline
                border.width: 2

                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: caffeineEnabled ? 22 : 18
                    height: width
                    radius: width / 2
                    color: caffeineEnabled ? "#ffffff" : Theme.outline
                    anchors.verticalCenter: parent.verticalCenter
                    x: caffeineEnabled ? parent.width - width - 5 : 5

                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutElastic } }
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.toggled(!caffeineEnabled)
                    }
                }
            }
    }
}
}
