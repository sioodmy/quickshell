import QtQuick

Item {
    id: root
    anchors.fill: parent

    property real progress: 1.0
    property real unlockProgress: 0.0
    property real eased: progress

    // Ambient floating orbs (pink / lavender / warm)
    Item {
        id: pinkMorph
        anchors.fill: parent

        Rectangle {
            id: pinkBase
            anchors.fill: parent
            radius: 0
            color: "#f5bde6"
            clip: true

            // Soft white orb
            Rectangle {
                width: Math.max(parent.width, parent.height) * 0.55
                height: width
                radius: width / 2
                color: "#ffffff"
                opacity: 0.40
                x: parent.width * -0.05
                y: parent.height * -0.08
                transformOrigin: Item.Center
                visible: true

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.width * 0.35; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * -0.08; duration: 18000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * -0.05; duration: 15000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.height * -0.12; duration: 17000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * 0.18; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * -0.08; duration: 16000; easing.type: Easing.InOutSine }
                }
                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 30000; loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                }
            }

            // Soft lavender orb
            Rectangle {
                width: Math.max(parent.width, parent.height) * 0.5
                height: width
                radius: width / 2
                color: "#c6a0f6"
                opacity: 0.55
                x: parent.width * 0.55
                y: parent.height * -0.05
                transformOrigin: Item.Center
                visible: true

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.width * 0.2; duration: 18000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * 0.7; duration: 19000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * 0.55; duration: 17000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.height * 0.25; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * -0.1; duration: 18000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * -0.05; duration: 16000; easing.type: Easing.InOutSine }
                }
                NumberAnimation on rotation {
                    from: 360; to: 0; duration: 35000; loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                }
            }

            // Tertiary warm orb for depth
            Rectangle {
                width: Math.max(parent.width, parent.height) * 0.35
                height: width
                radius: width / 2
                color: "#ee99a0"
                opacity: 0.35
                x: parent.width * 0.2
                y: parent.height * 0.55
                transformOrigin: Item.Center
                visible: true

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.width * 0.65; duration: 20000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * 0.05; duration: 22000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.width * 0.2; duration: 19000; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.progress > 0.5 && root.unlockProgress < 0.5
                    NumberAnimation { to: root.height * 0.4; duration: 18000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * 0.7; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.height * 0.55; duration: 17000; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // Soft legibility scrim over pink for the auth card / clock
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, (root.eased - 0.35) / 0.65)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.18) }
            GradientStop { position: 0.45; color: Qt.rgba(0.07, 0.07, 0.09, 0.06) }
            GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.28) }
        }
    }
}
