import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

import qs.theme
import qs.services

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

    // Approximate dock launcher / clock origins (dock contentColumn is 680px,
    // vertically centered; launcher is 34² at top + 12).
    readonly property real dockNotchTop: (height - 680) / 2
    readonly property real launcherFromX: 5
    readonly property real launcherFromY: dockNotchTop + 12
    readonly property real launcherFromSize: 34
    readonly property real clockFromX: (44 - 28) / 2
    readonly property real clockFromY: launcherFromY + 34 + 10
    readonly property real clockFromW: 28
    readonly property real clockFromH: 58

    readonly property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0

    Item {
        id: lockMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
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

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: lockMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

    // ========================================================================
    //  Pink ambient background (launcher pinkLayer, fullscreen)
    // ========================================================================
    Item {
        id: pinkBg
        anchors.fill: parent

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
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.width * 0.35; duration: 16000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * -0.08; duration: 18000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * -0.05; duration: 15000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.height * -0.12; duration: 17000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * 0.18; duration: 16000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * -0.08; duration: 16000; easing.type: Easing.InOutSine }
                    }
                    NumberAnimation on rotation {
                        from: 0; to: 360; duration: 30000; loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
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
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.width * 0.2; duration: 18000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * 0.7; duration: 19000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * 0.55; duration: 17000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.height * 0.25; duration: 16000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * -0.1; duration: 18000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * -0.05; duration: 16000; easing.type: Easing.InOutSine }
                    }
                    NumberAnimation on rotation {
                        from: 360; to: 0; duration: 35000; loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                    }
                }

                // Tertiary warm orb for depth
                Rectangle {
                    width: Math.max(parent.width, parent.height) * 0.35
                    height: width
                    radius: width / 2
                    color: "#f5c2e7"
                    opacity: 0.35
                    x: parent.width * 0.15
                    y: parent.height * 0.55
                    visible: true

                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.width * 0.4; duration: 20000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * 0.05; duration: 17000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.width * 0.15; duration: 18000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: surface.progress > 0.5 && surface.unlockProgress < 0.5
                        NumberAnimation { to: surface.height * 0.35; duration: 19000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * 0.7; duration: 16000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: surface.height * 0.55; duration: 17000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // Soft legibility scrim over pink for the auth card / clock
    Rectangle {
        anchors.fill: parent
        opacity: Math.max(0, (surface.eased - 0.35) / 0.65)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.18) }
            GradientStop { position: 0.45; color: Qt.rgba(0.07, 0.07, 0.09, 0.06) }
            GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.28) }
        }
    }

    // ========================================================================
    //  Morphing clock (dock stacked HH/mm → lockscreen HH:mm)
    // ========================================================================
    Item {
        id: morphClock
        z: 50

        readonly property real p: 1.0
        readonly property string hours: Qt.formatDateTime(clock.date, "HH")
        readonly property string mins: Qt.formatDateTime(clock.date, "mm")
        readonly property real fontPx: Math.round(surface.height * 0.14)
        readonly property real colonGap: 2
        readonly property real colonOpacity: 1
        readonly property real rowW: hoursMetrics.width + colonMetrics.width * colonOpacity + minsMetrics.width + colonGap * 4
        readonly property real rowH: fontPx * 1.15

        // Settled clock target: top-center
        readonly property real toX: (surface.width - rowW) / 2
        readonly property real toY: surface.height * 0.12

        width: Math.max(rowW, dateMetrics.width)
        height: rowH + dateBlock.height + 8

        x: toX
        y: toY

        TextMetrics {
            id: hoursMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.DemiBold
            text: morphClock.hours
        }
        TextMetrics {
            id: minsMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.DemiBold
            text: morphClock.mins
        }
        TextMetrics {
            id: colonMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.DemiBold
            text: ":"
        }
        TextMetrics {
            id: dateMetrics
            font.family: "Google Sans"
            font.pixelSize: Math.round(surface.height * 0.022)
            font.weight: Font.Medium
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
        }

        readonly property color fromColor: Theme.on_surface
        readonly property color toColor: Qt.rgba(0.19, 0.1, 0.25, 1)
        readonly property color textColor: Qt.rgba(
            surface.lerp(fromColor.r, toColor.r, p),
            surface.lerp(fromColor.g, toColor.g, p),
            surface.lerp(fromColor.b, toColor.b, p),
            1
        )

        Text {
            id: hoursText
            text: morphClock.hours
            color: morphClock.textColor
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: morphClock.p > 0.45 ? Font.DemiBold : Font.Bold
                letterSpacing: morphClock.p > 0.5 ? -2 : 0
            }
            x: surface.lerp((morphClock.width - hoursText.width) / 2, (morphClock.width - morphClock.rowW) / 2, morphClock.p)
            y: surface.lerp(0, 0, morphClock.p)
        }

        Text {
            id: colonText
            text: ":"
            color: morphClock.textColor
            opacity: morphClock.colonOpacity
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: Font.DemiBold
                letterSpacing: -2
            }
            x: hoursText.x + hoursText.width + morphClock.colonGap
            y: hoursText.y
        }

        Text {
            id: minsText
            text: morphClock.mins
            color: morphClock.textColor
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: morphClock.p > 0.45 ? Font.DemiBold : Font.Bold
                letterSpacing: morphClock.p > 0.5 ? -2 : 0
            }
            x: surface.lerp(
                (morphClock.width - minsText.width) / 2,
                hoursText.x + hoursText.width + morphClock.colonGap + colonText.width * morphClock.colonOpacity + morphClock.colonGap,
                morphClock.p
            )
            y: surface.lerp(hoursText.height, hoursText.y, morphClock.p)
        }

        Column {
            id: dateBlock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: morphClock.rowH + 4
            spacing: 0
            opacity: Math.max(0, Math.min(1, (morphClock.p - 0.55) / 0.3))

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

            // Greeting — no avatar
            Column {
                width: parent.width
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome back"
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium; letterSpacing: 0.4 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const u = Quickshell.env("USER") || "user";
                        return u.charAt(0).toUpperCase() + u.slice(1);
                    }
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 22; weight: Font.DemiBold }
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

                Text {
                    id: lockGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: passwordInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                TextInput {
                    id: passwordInput
                    anchors.left: lockGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: revealBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 17; weight: Font.Medium }
                    echoMode: revealBtn.revealed ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    clip: true
                    enabled: !surface.authenticating && !surface.unlocking
                    focus: true
                    selectByMouse: true
                    selectionColor: Theme.primary

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

                    Text {
                        anchors.centerIn: parent
                        text: revealBtn.revealed ? "󰈉" : "󰈈"
                        font.family: "JetBrainsMono Nerd Font"
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

                    Text {
                        anchors.centerIn: parent
                        text: "󰁔"
                        font.family: "JetBrainsMono Nerd Font"
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
                        layer.enabled: true
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
            Rectangle {
                id: mediaRow
                width: parent.width
                height: surface.mediaActive ? 72 : 0
                radius: 16
                color: Theme.surface_container
                clip: true
                visible: height > 0.5
                opacity: surface.mediaActive ? 1 : 0

                Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12
                    opacity: surface.mediaActive ? 1 : 0

                    Rectangle {
                        width: 52
                        height: 52
                        radius: 12
                        color: Theme.surface_container_highest
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: Playerctl.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    hideSource: true
                                    sourceItem: Rectangle {
                                        width: artImg.width
                                        height: artImg.height
                                        radius: 12
                                        color: "black"
                                        visible: false
                                    }
                                }
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: artImg.status !== Image.Ready
                            text: "󰝚"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                            color: Theme.on_surface_variant
                        }
                    }

                    Column {
                        width: parent.width - 52 - 12 - transport.width - 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: Playerctl.title
                            elide: Text.ElideRight
                            color: Theme.on_surface
                            font { family: "Google Sans"; pixelSize: 14; weight: Font.DemiBold }
                        }
                        Text {
                            width: parent.width
                            text: Playerctl.artist
                            elide: Text.ElideRight
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 12 }
                            visible: text.length > 0
                        }

                        Item {
                            width: parent.width
                            height: 7
                            visible: Playerctl.length > 0

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 3
                                radius: 1.5
                                color: Theme.surface_container_highest

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * (Playerctl.length > 0
                                        ? Math.min(1, Playerctl.position / Playerctl.length) : 0)
                                    color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    Row {
                        id: transport
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        component MediaBtn: Rectangle {
                            property string icon
                            property bool accent: false
                            signal triggered

                            width: 36
                            height: 36
                            radius: 10
                            color: {
                                if (accent)
                                    return Theme.primary;
                                return btnMouse.containsMouse
                                    ? Theme.surface_container_highest
                                    : "transparent";
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: parent.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                                color: parent.accent ? Theme.on_primary : Theme.on_surface
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.triggered()
                            }
                        }

                        MediaBtn {
                            icon: "󰒮"
                            onTriggered: Playerctl.previous()
                        }
                        MediaBtn {
                            icon: Playerctl.isPlaying ? "󰏤" : "󰐊"
                            accent: true
                            onTriggered: Playerctl.playPause()
                        }
                        MediaBtn {
                            icon: "󰒭"
                            onTriggered: Playerctl.next()
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    //  Bottom session chrome — bar-matching pills
    // ========================================================================
    Row {
        id: bottomChrome
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: surface.height * 0.05
        spacing: 12

        // Battery
        Rectangle {
            id: battPill
            height: 40
            width: battRow.implicitWidth + 28
            radius: 14
            color: Theme.surface
            border.width: 1
            border.color: Theme.surface_container_high
            visible: UPower.displayDevice?.isPresent ?? false
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: battRow
                anchors.centerIn: parent
                spacing: 8

                readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
                readonly property bool charging: !UPower.onBattery

                Item {
                    width: 28
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: battBody
                        anchors {
                            left: parent.left; top: parent.top; bottom: parent.bottom
                            right: parent.right; rightMargin: 3
                        }
                        radius: 3
                        color: "transparent"
                        border.width: 1.5
                        border.color: {
                            if (battRow.capacity <= 20 && !battRow.charging)
                                return Theme.critical;
                            if (battRow.charging)
                                return "#7ee787";
                            return Theme.on_surface;
                        }
                    }
                    Rectangle {
                        width: 2.5; height: 5
                        anchors { left: battBody.right; verticalCenter: parent.verticalCenter }
                        radius: 1
                        color: battBody.border.color
                    }
                    Rectangle {
                        anchors {
                            left: battBody.left; top: battBody.top; bottom: battBody.bottom
                            margins: 2.5
                        }
                        radius: 1
                        width: Math.max(0, (battBody.width - 5) * (battRow.capacity / 100))
                        color: battBody.border.color
                        opacity: 0.85
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(battRow.capacity) + "%"
                    color: Theme.on_surface
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                }
            }
        }

        // Session controls
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            component SessionBtn: Rectangle {
                property string icon
                property color accent: Theme.on_surface
                signal triggered

                width: 40
                height: 40
                radius: 14
                border.width: 1
                border.color: Theme.surface_container_high
                scale: btnArea.pressed ? 0.92 : (btnArea.containsMouse ? 1.04 : 1.0)
                color: {
                    if (btnArea.pressed)
                        return Theme.surface_container_high;
                    if (btnArea.containsMouse)
                        return Theme.surface_container;
                    return Theme.surface;
                }

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: parent.icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: parent.accent
                    opacity: btnArea.containsMouse ? 1 : 0.85
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.triggered()
                }
            }

            SessionBtn {
                icon: "󰒲"
                onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
            }
            SessionBtn {
                icon: "󰜉"
                onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
            }
            SessionBtn {
                icon: "󰐥"
                accent: Theme.critical
                onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
            }
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
