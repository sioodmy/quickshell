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
 * Lock surface — pink launcher-style ambient background with a Material 3
 * auth card that matches the dock bar. Entrance morphs the dock launcher
 * pill into the fullscreen pink field and the dock clock into the lock clock.
 */
WlSessionLockSurface {
    id: surface

    property var controller

    // Dark base so the pink field can morph outward from the dock launcher pill.
    color: Theme.surface

    readonly property bool authenticating: controller ? controller.authenticating : false
    readonly property string statusMessage: controller ? controller.statusMessage : ""
    readonly property bool statusIsError: controller ? controller.statusIsError : false
    readonly property bool unlocking: controller ? controller.unlocking : false

    // 0 → 1 lock entrance; 0 → 1 unlock exit (reverse morph).
    property real reveal: 0
    property real unlockProgress: 0

    // Combined progress: settled lock = 1, unlocking reverses toward 0.
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

        // Rounded reveal area that grows from left
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: 0
            width: Math.max(0, parent.width * surface.eased)
            radius: 28
            color: "black"
        }
        // Flat left edge filler (covers the left rounded corners)
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

    // ========================================================================
    //  Lock Background (Ambient pink/lavender orbs + legibility scrim)
    // ========================================================================
    LockBackground {
        progress: surface.eased
        unlockProgress: surface.unlockProgress
    }

    // ========================================================================
    //  Clock (Lockscreen HH:mm + Date)
    // ========================================================================
    Column {
        id: lockClock
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: surface.height * 0.12
        spacing: 6

        readonly property string hours: Qt.formatDateTime(clock.date, "HH")
        readonly property string mins: Qt.formatDateTime(clock.date, "mm")
        readonly property real fontPx: Math.round(surface.height * 0.14)
        readonly property color textColor: Qt.rgba(0.19, 0.1, 0.25, 1)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                text: lockClock.hours
                color: lockClock.textColor
                font {
                    family: "Google Sans"
                    pixelSize: lockClock.fontPx
                    weight: Font.Bold
                    letterSpacing: -2
                }
            }

            Text {
                text: ":"
                color: lockClock.textColor
                font {
                    family: "Google Sans"
                    pixelSize: lockClock.fontPx
                    weight: Font.Bold
                    letterSpacing: -2
                }
            }

            Text {
                text: lockClock.mins
                color: lockClock.textColor
                font {
                    family: "Google Sans"
                    pixelSize: lockClock.fontPx
                    weight: Font.Bold
                    letterSpacing: -2
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Qt.rgba(0.19, 0.1, 0.25, 0.72)
            font {
                family: "Google Sans"
                pixelSize: Math.round(surface.height * 0.022)
                weight: Font.Medium
                letterSpacing: 0.8
            }
        }
    }

    // ========================================================================
    //  Auth card — Material 3 surface matching the dock bar
    // ========================================================================
    Rectangle {
        id: authCard
        width: 420
        height: authColumn.implicitHeight + 48
        radius: 28
        color: Theme.surface
        border.width: 1
        border.color: Theme.surface_container_high

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: surface.height * 0.06

        // Panel reveal like calendar/launcher — fades in after pink has expanded.
        transformOrigin: Item.Center
        transform: Translate {
            x: authCard.shakeX
        }

        property real shakeX: 0

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: authCard; property: "shakeX"; to: -12; duration: 50 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 10; duration: 50 }
            NumberAnimation { target: authCard; property: "shakeX"; to: -7; duration: 50 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 5; duration: 50 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 0; duration: 50 }
        }

        // Soft shadow matching launcher/calendar
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.9
            shadowColor: "#50000000"
            shadowVerticalOffset: 10
            shadowHorizontalOffset: 0
        }

        Column {
            id: authColumn
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 16

            // Greeting and Username
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome back"
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium; letterSpacing: 0.2 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const u = Quickshell.env("USER") || "user";
                        return u.charAt(0).toUpperCase() + u.slice(1);
                    }
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 22; weight: Font.Bold }
                }
            }

            // Password field — M3 filled tonal, bar-matching grays
            Rectangle {
                id: pwField
                width: parent.width
                height: 56
                radius: 16
                color: passwordInput.activeFocus
                    ? Theme.surface_container_high
                    : Theme.surface_container
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? Theme.primary : Theme.outline_variant

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                MaterialIcon {
                    id: lockGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "lock"
                    font.pixelSize: 16
                    color: passwordInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Item {
                    id: pwInputArea
                    anchors.left: lockGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: revealBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    clip: true

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: revealBtn.revealed ? Theme.on_surface : "transparent"
                        font { family: "Google Sans"; pixelSize: 17; weight: Font.Medium }
                        echoMode: TextInput.Normal
                        cursorVisible: activeFocus
                        clip: true
                        enabled: !surface.authenticating && !surface.unlocking
                        focus: true
                        selectByMouse: revealBtn.revealed
                        selectionColor: Theme.primary

                        // Hide the native caret while masked — shapes row draws its own.
                        // When revealed, this delegate is the only caret.
                        cursorDelegate: Rectangle {
                            width: revealBtn.revealed ? 2 : 0
                            height: 16
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
                            color: Theme.on_surface_variant
                            opacity: 0.7
                            font: passwordInput.font
                        }
                    }

                    // Shape glyphs instead of password dots (hidden when revealed)
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
                                width: 11
                                height: 11
                                // 0 = circle, 1 = square, 2 = triangle
                                readonly property int kind: index % 3

                                // Circle
                                Rectangle {
                                    visible: shapeSlot.kind === 0
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: width / 2
                                    color: Theme.on_surface
                                }

                                // Square
                                Rectangle {
                                    visible: shapeSlot.kind === 1
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: 1.5
                                    color: Theme.on_surface
                                }

                                // Triangle
                                Shape {
                                    visible: shapeSlot.kind === 2
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 10
                                    layer.enabled: shapeSlot.kind === 2
                                    layer.samples: 4

                                    ShapePath {
                                        fillColor: Theme.on_surface
                                        strokeWidth: 0
                                        startX: 5.5; startY: 0.5
                                        PathLine { x: 10.5; y: 9.5 }
                                        PathLine { x: 0.5; y: 9.5 }
                                        PathLine { x: 5.5; y: 0.5 }
                                    }
                                }
                            }
                        }

                        // Caret after the last shape
                        Rectangle {
                            id: pwCaret
                            width: 2
                            height: 16
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
                    width: 30
                    height: 30
                    anchors.right: submitBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text.length > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: revealBtn.revealed ? "visibility_off" : "visibility"
                        font.pixelSize: 15
                        color: revealMouse.containsMouse ? Theme.on_surface : Theme.on_surface_variant
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
                    width: 40
                    height: 40
                    radius: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.primary
                    opacity: (passwordInput.text.length > 0 && !surface.authenticating) ? 1 : 0
                    scale: submitMouse.pressed ? 0.9 : ((passwordInput.text.length > 0) ? 1 : 0.7)
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "arrow_forward"
                        font.pixelSize: 15
                        color: Theme.on_primary
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

            // Status
            Item {
                width: parent.width
                height: statusRow.visible ? 20 : 0
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 8
                    visible: surface.authenticating || surface.unlocking || surface.statusMessage.length > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Shape {
                        width: 14
                        height: 14
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
                                centerX: 7; centerY: 7
                                radiusX: 5; radiusY: 5
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
                            : (surface.statusIsError ? Theme.critical : Theme.on_surface_variant)
                        font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                    }
                }
            }

            // ----------------------------------------------------------------
            //  Now playing — expands seamlessly inside the auth card
            // ----------------------------------------------------------------
            LockMediaCard {
                mediaActive: surface.mediaActive
            }
        }
    }

    // ========================================================================
    //  Bottom session chrome — bar-matching pills
    // ========================================================================
    LockSessionBar {}

    // Historical event text
    Column {
        id: historyBox
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 48
        spacing: 4
        visible: text1.text !== ""
        opacity: 0.55
        
        Text {
            id: text1
            font { family: "Google Sans"; pixelSize: 18; weight: Font.Bold }
            color: Theme.on_surface
            text: ""
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
        }
        Text {
            id: text2
            font { family: "Google Sans"; pixelSize: 16 }
            color: Theme.on_surface_variant
            text: ""
            horizontalAlignment: Text.AlignRight
            anchors.right: parent.right
            width: Math.min(implicitWidth, 600)
            wrapMode: Text.WordWrap
        }

        Component.onCompleted: {
            const ev = History.getTodayEvent();
            text1.text = ev[0];
            text2.text = ev[1];
        }
    }

    } // end lockContent


    // ========================================================================
    //  Behaviour glue
    // ========================================================================
    Connections {
        target: surface.controller
        function onStatusIsErrorChanged() {
            if (surface.controller.statusIsError && !surface.unlocking) {
                shakeAnim.restart();
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
