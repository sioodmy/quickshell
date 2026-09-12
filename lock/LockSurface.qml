import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

import qs.theme
import qs.services
import qs.components
import "../history.js" as History

/**
 * Lock surface — liquid aurora backdrop with frosted glass auth chrome.
 * Entrance morphs from the dock pill; wrong password shakes the field
 * like macOS.
 */
WlSessionLockSurface {
    id: surface

    property var controller

    color: "#24183e"

    readonly property bool authenticating: controller ? controller.authenticating : false
    readonly property string statusMessage: controller ? controller.statusMessage : ""
    readonly property bool statusIsError: controller ? controller.statusIsError : false
    readonly property bool unlocking: controller ? controller.unlocking : false

    property real reveal: 0
    property real unlockProgress: 0

    readonly property real progress: {
        if (unlockProgress > 0)
            return Math.max(0, 1 - unlockProgress);
        return reveal;
    }
    readonly property real eased: {
        const t = progress;
        return 1 - Math.pow(1 - t, 3);
    }

    function lerp(a, b, t) {
        return a + (b - a) * t;
    }

    onUnlockingChanged: {
        if (unlocking) {
            unlockProgress = 1;
            passwordInput.clear();
        } else {
            unlockProgress = 0;
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0

    Item {
        id: lockMask
        anchors.fill: parent
        visible: false
        layer.enabled: surface.progress < 0.999
        layer.smooth: true

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            width: Math.max(0, parent.width * surface.eased)
            radius: 28
            color: "black"
        }
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            width: Math.min(48, Math.max(0, parent.width * surface.eased))
            color: "black"
        }
    }

    Item {
        id: lockContent
        anchors.fill: parent

        layer.enabled: surface.progress < 0.999
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: lockMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        LockBackground {
            progress: surface.eased
            unlockProgress: surface.unlockProgress
        }

        // ====================================================================
        //  Clock — macOS lock: ultra-bold, slightly transparent, frosted
        // ====================================================================
        Item {
            id: lockClock
            z: 50
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: surface.height * 0.1
            width: clockFace.width
            height: clockFace.height
            opacity: Math.min(1, surface.eased * 1.4)

            readonly property string hours: Qt.formatDateTime(clock.date, "HH")
            readonly property string mins: Qt.formatDateTime(clock.date, "mm")
            readonly property real fontPx: Math.round(surface.height * 0.15)
            readonly property color textColor: Qt.rgba(1, 1, 1, 0.78)

            // Soft halo without MultiEffect (Asahi crashes updatePixelRatioHelper).
            Column {
                id: clockBloom
                anchors.centerIn: clockFace
                spacing: 2
                opacity: 0.28
                scale: 1.08
                transformOrigin: Item.Center

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        text: lockClock.hours
                        color: Qt.rgba(1, 1, 1, 1)
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }
                    Text {
                        text: ":"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }
                    Text {
                        text: lockClock.mins
                        color: Qt.rgba(1, 1, 1, 1)
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }
                }
            }

            Column {
                id: clockFace
                spacing: 2

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        text: lockClock.hours
                        color: lockClock.textColor
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }

                    Text {
                        text: ":"
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }

                    Text {
                        text: lockClock.mins
                        color: lockClock.textColor
                        font {
                            family: "Google Sans"
                            pixelSize: lockClock.fontPx
                            weight: Font.Black
                            letterSpacing: -4
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                    color: Qt.rgba(1, 1, 1, 0.48)
                    font {
                        family: "Google Sans"
                        pixelSize: Math.round(surface.height * 0.02)
                        weight: Font.DemiBold
                        letterSpacing: 0.4
                    }
                }
            }
        }

        // ====================================================================
        //  Auth card — liquid glass shell over aurora
        // ====================================================================
        Rectangle {
            id: authCard
            width: 400
            height: authColumn.implicitHeight + 44
            radius: 28
            // Luminous frosted glass — white wash, not dark shell
            color: Qt.rgba(1, 1, 1, 0.26)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.42)

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: surface.height * 0.07

            transformOrigin: Item.Center
            opacity: Math.min(1, Math.max(0, (surface.eased - 0.35) / 0.5))
            scale: 0.94 + 0.06 * Math.min(1, Math.max(0, (surface.eased - 0.3) / 0.55))

            BubbleSheen {}

            Column {
                id: authColumn
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 14
                z: 1

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Welcome back"
                        color: Qt.rgba(0.12, 0.1, 0.18, 0.55)
                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.3 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const u = Quickshell.env("USER") || "user";
                            return u.charAt(0).toUpperCase() + u.slice(1);
                        }
                        color: Qt.rgba(0.1, 0.08, 0.16, 0.92)
                        font { family: "Google Sans"; pixelSize: 21; weight: Font.DemiBold }
                    }
                }

                // Password field — glass capsule; shakes on wrong password
                Rectangle {
                    id: pwField
                    width: parent.width
                    height: 52
                    radius: height / 2
                    color: passwordInput.activeFocus
                        ? Qt.rgba(1, 1, 1, 0.42)
                        : Qt.rgba(1, 1, 1, 0.3)
                    border.width: 1
                    border.color: {
                        if (showingError)
                            return Qt.alpha(Theme.critical, 0.9);
                        if (passwordInput.activeFocus)
                            return Qt.rgba(1, 1, 1, 0.55);
                        return Qt.rgba(1, 1, 1, 0.35);
                    }

                    transform: Translate { x: pwField.shakeX }
                    property real shakeX: 0
                    property bool showingError: false

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    BubbleSheen {}

                    // macOS-style decaying horizontal shake
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: pwField; property: "shakeX"; to: -18; duration: 40; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pwField; property: "shakeX"; to: 16; duration: 50; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pwField; property: "shakeX"; to: -12; duration: 45; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pwField; property: "shakeX"; to: 8; duration: 45; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pwField; property: "shakeX"; to: -4; duration: 40; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pwField; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.OutCubic }
                    }

                    SequentialAnimation {
                        id: errorFlash
                        ScriptAction { script: pwField.showingError = true }
                        PauseAnimation { duration: 420 }
                        ScriptAction { script: pwField.showingError = false }
                    }

                    MaterialIcon {
                        id: lockGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        z: 1
                        icon: "lock"
                        font.pixelSize: 15
                        color: passwordInput.activeFocus ? Theme.primary : Qt.rgba(0.15, 0.12, 0.22, 0.55)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    Item {
                        id: pwInputArea
                        anchors.left: lockGlyph.right
                        anchors.leftMargin: 10
                        anchors.right: revealBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        clip: true
                        z: 1

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: revealBtn.revealed ? Qt.rgba(0.1, 0.08, 0.16, 0.95) : "transparent"
                            font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                            echoMode: TextInput.Normal
                            cursorVisible: activeFocus
                            clip: true
                            enabled: !surface.authenticating && !surface.unlocking
                            focus: true
                            selectByMouse: revealBtn.revealed
                            selectionColor: Theme.primary

                            cursorDelegate: Rectangle {
                                width: revealBtn.revealed ? 2 : 0
                                height: 15
                                radius: 1
                                color: Theme.primary
                                visible: revealBtn.revealed
                            }

                            onAccepted: {
                                if (!surface.unlocking)
                                    surface.controller.submit(text);
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                visible: passwordInput.text.length === 0
                                text: "Enter password"
                                color: Qt.rgba(0.15, 0.12, 0.22, 0.4)
                                font: passwordInput.font
                            }
                        }

                        Row {
                            id: pwShapes
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            visible: !revealBtn.revealed

                            Repeater {
                                model: passwordInput.text.length

                                Item {
                                    id: shapeSlot
                                    width: 10
                                    height: 10
                                    readonly property int kind: index % 3

                                    Rectangle {
                                        visible: shapeSlot.kind === 0
                                        anchors.centerIn: parent
                                        width: 9
                                        height: 9
                                        radius: width / 2
                                        color: Qt.rgba(0.12, 0.1, 0.18, 0.9)
                                    }

                                    Rectangle {
                                        visible: shapeSlot.kind === 1
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        radius: 1.5
                                        color: Qt.rgba(0.12, 0.1, 0.18, 0.9)
                                    }

                                    Shape {
                                        visible: shapeSlot.kind === 2
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 9
                                        layer.enabled: shapeSlot.kind === 2
                                        layer.samples: 4

                                        ShapePath {
                                            fillColor: Qt.rgba(0.12, 0.1, 0.18, 0.9)
                                            strokeWidth: 0
                                            startX: 5; startY: 0.5
                                            PathLine { x: 9.5; y: 8.5 }
                                            PathLine { x: 0.5; y: 8.5 }
                                            PathLine { x: 5; y: 0.5 }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: pwCaret
                                width: 2
                                height: 15
                                radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primary
                                visible: passwordInput.activeFocus
                                opacity: 1

                                SequentialAnimation on opacity {
                                    running: pwCaret.visible
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 0 }
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 1 }
                                }
                            }
                        }
                    }

                    Item {
                        id: revealBtn
                        property bool revealed: false
                        width: 28
                        height: 28
                        anchors.right: submitBtn.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length > 0
                        opacity: visible ? 1 : 0
                        z: 1
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: revealBtn.revealed ? "visibility_off" : "visibility"
                            font.pixelSize: 14
                            color: revealMouse.containsMouse
                                ? Qt.rgba(0.12, 0.1, 0.18, 0.85)
                                : Qt.rgba(0.15, 0.12, 0.22, 0.5)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: revealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: revealBtn.revealed = !revealBtn.revealed
                        }
                    }

                    Rectangle {
                        id: submitBtn
                        width: 36
                        height: 36
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        z: 1
                        color: Qt.alpha(Theme.primary, 0.55)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.45)
                        opacity: (passwordInput.text.length > 0 && !surface.authenticating) ? 1 : 0
                        scale: submitMouse.pressed ? 0.9 : ((passwordInput.text.length > 0) ? 1 : 0.7)
                        visible: opacity > 0.01
                        clip: true

                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                        BubbleSheen {}

                        MaterialIcon {
                            anchors.centerIn: parent
                            z: 1
                            icon: "arrow_forward"
                            font.pixelSize: 14
                            color: Theme.primary
                        }
                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: surface.controller.submit(passwordInput.text)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: statusRow.visible ? 18 : 0
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 8
                        visible: surface.authenticating || surface.unlocking || surface.statusMessage.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        Shape {
                            width: 13
                            height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            visible: surface.authenticating
                            layer.enabled: surface.authenticating
                            layer.samples: 4

                            ShapePath {
                                strokeWidth: 2
                                strokeColor: Theme.primary
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 6.5; centerY: 6.5
                                    radiusX: 4.5; radiusY: 4.5
                                    startAngle: 0; sweepAngle: 270
                                    moveToStart: true
                                }
                            }

                            RotationAnimation on rotation {
                                from: 0; to: 360
                                duration: 800
                                loops: Animation.Infinite
                                running: surface.authenticating
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: surface.unlocking
                                ? "Unlocked"
                                : (surface.authenticating
                                    ? "Authenticating…"
                                    : surface.statusMessage)
                            visible: text.length > 0
                            color: surface.unlocking
                                ? Theme.primary
                                : (surface.statusIsError ? Theme.critical : Qt.rgba(1, 1, 1, 0.55))
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                        }
                    }
                }

                LockMediaCard {
                    mediaActive: surface.mediaActive
                }
            }
        }

        LockSessionBar {}

        Column {
            id: historyBox
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 48
            spacing: 4
            visible: text1.text !== ""
            opacity: 0.45

            Text {
                id: text1
                font { family: "Google Sans"; pixelSize: 16; weight: Font.Bold }
                color: Qt.rgba(1, 1, 1, 0.85)
                text: ""
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
            Text {
                id: text2
                font { family: "Google Sans"; pixelSize: 14 }
                color: Qt.rgba(1, 1, 1, 0.55)
                text: ""
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
                width: Math.min(implicitWidth, 560)
                wrapMode: Text.WordWrap
            }

            Component.onCompleted: {
                const ev = History.getTodayEvent();
                text1.text = ev[0];
                text2.text = ev[1];
            }
        }

    } // end lockContent

    Connections {
        target: surface.controller
        function onStatusIsErrorChanged() {
            if (surface.controller.statusIsError && !surface.unlocking) {
                shakeAnim.restart();
                errorFlash.restart();
                passwordInput.clear();
                passwordInput.forceActiveFocus();
            }
        }
    }

    Behavior on reveal {
        NumberAnimation { duration: 520; easing.type: Easing.OutCubic }
    }

    Behavior on unlockProgress {
        NumberAnimation { duration: 480; easing.type: Easing.InCubic }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
        reveal = 1;
    }
}
