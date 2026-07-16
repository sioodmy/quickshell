import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

import qs.theme
import qs.services
import "../desktop"

WlSessionLockSurface {
    id: surface

    property var controller

    color: Theme.background

    // Convenience aliases into the auth controller.
    readonly property bool authenticating: controller ? controller.authenticating : false
    readonly property string statusMessage: controller ? controller.statusMessage : ""
    readonly property bool statusIsError: controller ? controller.statusIsError : false
    readonly property bool unlocking: controller ? controller.unlocking : false

    readonly property string userName: (Quickshell.env("USER") || "user")
    readonly property string prettyUser: userName.charAt(0).toUpperCase() + userName.slice(1)

    // Drives the staged entrance animation.
    property real reveal: 0
    // 0 → 1 unlock exit animation (orb bloom, UI dissolve).
    property real unlockProgress: 0

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

    // --- Animated night-sky wallpaper ---------------------------------------
    AnimatedWallpaper {
        id: wallpaper
        anchors.fill: parent
    }

    // --- Legibility scrim + vignette ----------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.32) }
            GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.12) }
            GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
        }
    }
    // Side vignette for focus (edges darker than center).
    Row {
        anchors.fill: parent
        Rectangle {
            width: parent.width * 0.22
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Item { width: parent.width * 0.56; height: parent.height }
        Rectangle {
            width: parent.width * 0.22
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
            }
        }
    }

    // ========================================================================
    //  Reusable pieces
    // ========================================================================

    // Frosted-glass surface (translucent tint + sheen + hairline border).
    component GlassCard: Rectangle {
        radius: 28
        color: Qt.rgba(0.09, 0.09, 0.12, 0.55)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)

        // Top-down light sheen.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // M3 tonal circular icon button.
    component CircleButton: Item {
        id: cb
        property string icon
        property real diameter: 52
        property real glyphSize: 22
        property color accent: Qt.rgba(1, 1, 1, 0.92)
        signal triggered

        implicitWidth: diameter
        implicitHeight: diameter

        Rectangle {
            id: cbBg
            anchors.fill: parent
            radius: width / 2
            color: cbMouse.pressed
                ? Qt.rgba(1, 1, 1, 0.2)
                : (cbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
            border.width: 1
            border.color: cbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
            scale: cbMouse.pressed ? 0.92 : (cbMouse.containsMouse ? 1.06 : 1.0)

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        }

        Text {
            anchors.centerIn: parent
            text: cb.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: cb.glyphSize
            color: cb.accent
            opacity: cbMouse.containsMouse ? 1.0 : 0.82
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        MouseArea {
            id: cbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.triggered()
        }
    }

    // ========================================================================
    //  Clock (top center)
    // ========================================================================
    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: surface.height * 0.11
        spacing: surface.height * 0.005

        opacity: surface.reveal * (1 - surface.unlockProgress)
        transform: Translate { y: (1 - surface.reveal) * -30 - surface.unlockProgress * 40 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "white"
            font {
                family: "Work Sans"
                pixelSize: Math.round(surface.height * 0.19)
                weight: Font.DemiBold
                letterSpacing: -2
            }
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.82)
            font {
                family: "Google Sans"
                pixelSize: Math.round(surface.height * 0.026)
                weight: Font.Medium
                letterSpacing: 1.5
            }
        }
    }

    // ========================================================================
    //  Now-playing glass card (top right) — only when a player is active
    // ========================================================================
    GlassCard {
        id: mediaCard
        visible: opacity > 0.01
        readonly property bool active: Playerctl.hasPlayer && (Playerctl.title.length > 0)

        width: 320
        height: 92
        radius: 24
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: surface.height * 0.07
        anchors.rightMargin: surface.width * 0.05

        opacity: active ? surface.reveal * (1 - surface.unlockProgress) : 0
        transform: Translate { y: (1 - surface.reveal) * -20 - surface.unlockProgress * 30 }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Album art
            Rectangle {
                id: artHolder
                width: 68
                height: 68
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Qt.rgba(1, 1, 1, 0.08)

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: Playerctl.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: artImg.status !== Image.Ready
                    text: "󰝚"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
            }

            Column {
                width: parent.width - 68 - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: Playerctl.title
                    elide: Text.ElideRight
                    color: "white"
                    font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    text: Playerctl.artist
                    elide: Text.ElideRight
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font { family: "Google Sans"; pixelSize: 12 }
                }

                Row {
                    spacing: 14
                    topPadding: 4

                    Text {
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Qt.rgba(1, 1, 1, 0.85)
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Playerctl.previous()
                        }
                    }
                    Text {
                        text: Playerctl.isPlaying ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: "white"
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Playerctl.playPause()
                        }
                    }
                    Text {
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: Qt.rgba(1, 1, 1, 0.85)
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Playerctl.next()
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    //  Auth card (center)
    // ========================================================================
    GlassCard {
        id: authCard
        width: 400
        height: authColumn.implicitHeight + 56
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: surface.height * 0.08

        opacity: surface.reveal * (1 - Math.min(1, surface.unlockProgress * 1.2))
        scale: (0.94 + surface.reveal * 0.06) * (1 + surface.unlockProgress * 0.08)
        transformOrigin: Item.Center
        transform: [
            Translate { y: (1 - surface.reveal) * 40 - surface.unlockProgress * 24 },
            Translate { x: authCard.shakeX }
        ]

        // Error shake.
        property real shakeX: 0

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: authCard; property: "shakeX"; to: -14; duration: 55 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 12; duration: 55 }
            NumberAnimation { target: authCard; property: "shakeX"; to: -8; duration: 55 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 6; duration: 55 }
            NumberAnimation { target: authCard; property: "shakeX"; to: 0; duration: 55 }
        }

        Column {
            id: authColumn
            anchors.centerIn: parent
            width: parent.width - 56
            spacing: 18

            // Orbital lock animation — fixed layout box; breath via scale only
            // to avoid subpixel width jitter.
            Item {
                id: orbRoot
                width: 110
                height: 110
                anchors.horizontalCenter: parent.horizontalCenter

                property real breath: 0
                property real spin: 0
                // Extra bloom during unlock exit.
                readonly property real bloom: 1 + surface.unlockProgress * 1.8

                SequentialAnimation on breath {
                    loops: Animation.Infinite
                    running: surface.reveal > 0.5 && !surface.unlocking
                    NumberAnimation { from: 0; to: 1; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: 0; duration: 2200; easing.type: Easing.InOutSine }
                }
                NumberAnimation on spin {
                    from: 0; to: 360
                    duration: 10000
                    loops: Animation.Infinite
                    running: surface.reveal > 0.5 && surface.unlockProgress < 0.85
                }

                // Soft outer glow (fixed size, breath = opacity + scale)
                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 100
                    radius: 50
                    color: Theme.primary
                    opacity: (0.08 + orbRoot.breath * 0.06) * (1 - surface.unlockProgress * 0.3)
                    scale: (1 + orbRoot.breath * 0.08) * orbRoot.bloom
                    transformOrigin: Item.Center
                }

                // Mid halo
                Rectangle {
                    anchors.centerIn: parent
                    width: 78
                    height: 78
                    radius: 39
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.primary
                    opacity: (0.35 + orbRoot.breath * 0.25) * (1 - surface.unlockProgress)
                    scale: (1 + orbRoot.breath * 0.04) * (1 + surface.unlockProgress * 0.6)
                    transformOrigin: Item.Center
                }

                // Orbiting dots — layered for clean rotation (avoids subpixel crawl)
                Item {
                    anchors.centerIn: parent
                    width: 88
                    height: 88
                    rotation: orbRoot.spin
                    opacity: 1 - surface.unlockProgress
                    scale: 1 + surface.unlockProgress * 1.4
                    transformOrigin: Item.Center
                    layer.enabled: true
                    layer.smooth: true

                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 6
                            height: 6
                            radius: 3
                            color: index === 0 ? Theme.primary
                                 : (index === 1 ? Theme.tertiary : Qt.rgba(1, 1, 1, 0.85))
                            opacity: 0.9 - index * 0.15
                            property real ang: index * 120 * Math.PI / 180
                            // Integer-aligned resting positions (rotation does the motion).
                            x: Math.round(44 + Math.cos(ang) * 40 - 3)
                            y: Math.round(44 + Math.sin(ang) * 40 - 3)
                        }
                    }
                }

                // Counter-orbiting sparks
                Item {
                    anchors.centerIn: parent
                    width: 62
                    height: 62
                    // Keep in sync with spin (same period) so loop resets don't jump.
                    rotation: -orbRoot.spin
                    opacity: 1 - surface.unlockProgress
                    scale: 1 + surface.unlockProgress * 1.1
                    transformOrigin: Item.Center
                    layer.enabled: true
                    layer.smooth: true

                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: 3
                            height: 3
                            radius: 1.5
                            color: "white"
                            opacity: 0.35 + (index % 2) * 0.25
                            property real ang: index * 72 * Math.PI / 180
                            x: Math.round(31 + Math.cos(ang) * 28 - 1.5)
                            y: Math.round(31 + Math.sin(ang) * 28 - 1.5)
                        }
                    }
                }

                // Unlock bloom flash (expands from core on success)
                Rectangle {
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    radius: 21
                    color: Theme.primary
                    opacity: surface.unlockProgress > 0
                        ? Math.max(0, 0.55 - surface.unlockProgress * 0.55)
                        : 0
                    scale: 1 + surface.unlockProgress * 6
                    transformOrigin: Item.Center
                }

                // Core orb — fixed geometry, breath via scale
                Rectangle {
                    id: coreOrb
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Theme.primary, 1.35) }
                        GradientStop { position: 1.0; color: Theme.primary_container }
                    }
                    scale: (1 + orbRoot.breath * 0.06) * (1 + surface.unlockProgress * 0.35)
                    opacity: 1 - surface.unlockProgress * 0.85
                    transformOrigin: Item.Center

                    Rectangle {
                        width: 19
                        height: 13
                        radius: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        color: Qt.rgba(1, 1, 1, 0.35)
                        rotation: -18
                    }
                }

                // Lock → unlock glyph
                Text {
                    anchors.centerIn: parent
                    text: surface.unlockProgress > 0.15 ? "󰌿" : "󰌾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: Theme.on_primary
                    opacity: 0.95 * (1 - Math.min(1, surface.unlockProgress * 1.4))
                    scale: (1 + orbRoot.breath * 0.03) * (1 + surface.unlockProgress * 0.5)
                    transformOrigin: Item.Center
                }
            }

            // Greeting
            Column {
                width: parent.width
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Welcome back"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium; letterSpacing: 0.5 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: surface.prettyUser
                    color: "white"
                    font { family: "Google Sans"; pixelSize: 22; weight: Font.DemiBold }
                }
            }

            // Password field (M3 pill)
            Rectangle {
                id: pwField
                width: parent.width
                height: 56
                radius: height / 2
                color: Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.12 : 0.07)
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: passwordInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.14)

                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Focus glow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: height / 2
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.primary
                    opacity: passwordInput.activeFocus ? 0.25 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Text {
                    id: lockGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                    color: passwordInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.55)
                    Behavior on color { ColorAnimation { duration: 160 } }
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
                    color: "white"
                    font { family: "Google Sans"; pixelSize: 18; weight: Font.Medium }
                    echoMode: revealBtn.revealed ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    clip: true
                    enabled: !surface.authenticating && !surface.unlocking
                    focus: true
                    selectByMouse: true
                    selectionColor: Theme.primary

                    onAccepted: {
                        if (!surface.unlocking)
                            surface.controller.submit(text)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: passwordInput.text.length === 0
                        text: "Enter password"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font: passwordInput.font
                    }
                }

                // Reveal toggle
                Item {
                    id: revealBtn
                    property bool revealed: false
                    width: 30
                    height: 30
                    anchors.right: submitBtn.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: revealBtn.revealed ? "󰈉" : "󰈈"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: revealMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.55)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: revealMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: revealBtn.revealed = !revealBtn.revealed
                    }
                }

                // Submit
                Rectangle {
                    id: submitBtn
                    width: 44
                    height: 44
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.primary
                    opacity: (passwordInput.text.length > 0 && !surface.authenticating) ? 1 : 0
                    scale: submitMouse.pressed ? 0.9 : ((passwordInput.text.length > 0) ? 1 : 0.6)
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁔"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
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

            // Status row (spinner + message)
            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Shape {
                        id: spinner
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: surface.authenticating
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeWidth: 2.5
                            strokeColor: Theme.primary
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 8; centerY: 8
                                radiusX: 6; radiusY: 6
                                startAngle: 0; sweepAngle: 280
                                moveToStart: true
                            }
                        }

                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: 850
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
                                : (surface.statusMessage.length > 0 ? surface.statusMessage : ""))
                        visible: text.length > 0
                        color: surface.unlocking
                            ? Theme.primary
                            : (surface.statusIsError ? Theme.critical : Qt.rgba(1, 1, 1, 0.7))
                        font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                    }
                }
            }
        }
    }

    // ========================================================================
    //  Bottom bar: battery (left) + session controls (right)
    // ========================================================================

    // Battery pill
    Rectangle {
        id: battPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: surface.width * 0.05
        anchors.bottomMargin: surface.height * 0.06
        height: 44
        width: battRow.implicitWidth + 32
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        visible: (UPower.displayDevice?.isPresent ?? false) && opacity > 0.01
        opacity: surface.reveal * (1 - surface.unlockProgress)

        Row {
            id: battRow
            anchors.centerIn: parent
            spacing: 10

            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool charging: !UPower.onBattery

            Item {
                id: battIconItem
                width: 34
                height: 15
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: battBody
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: 3 }
                    radius: 4
                    color: "transparent"
                    border.width: 1.5
                    border.color: {
                        if (battRow.capacity <= 20 && !battRow.charging) return Theme.critical;
                        if (battRow.charging) return "#7ee787";
                        return "white";
                    }
                }
                Rectangle {
                    width: 3; height: 6
                    anchors { left: battBody.right; verticalCenter: parent.verticalCenter }
                    radius: 1.5
                    color: battBody.border.color
                }
                Rectangle {
                    id: battFill
                    anchors { left: battBody.left; top: battBody.top; bottom: battBody.bottom; margins: 3 }
                    radius: 1.5
                    width: Math.max(0, (battBody.width - 6) * (battRow.capacity / 100))
                    color: battBody.border.color
                    opacity: 0.9
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Text {
                    visible: battRow.charging
                    anchors.centerIn: battBody
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "white"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(battRow.capacity) + "%"
                color: "white"
                opacity: 0.9
                font { family: "Google Sans"; pixelSize: 15; weight: Font.Medium }
            }
        }
    }

    // Session controls
    Row {
        id: sessionRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: surface.width * 0.05
        anchors.bottomMargin: surface.height * 0.06
        spacing: 16
        opacity: surface.reveal * (1 - surface.unlockProgress)
        transform: Translate { y: (1 - surface.reveal) * 20 + surface.unlockProgress * 30 }

        CircleButton {
            icon: "󰤓"
            onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
        }
        CircleButton {
            icon: "󰜉"
            onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
        }
        CircleButton {
            icon: "󰐥"
            accent: "#ff8a80"
            onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }

    // ========================================================================
    //  Behaviour glue
    // ========================================================================

    // Fullscreen dissolve flash on unlock.
    Rectangle {
        anchors.fill: parent
        color: Theme.primary
        opacity: {
            // Peak mid-animation, fade out toward the end.
            var p = surface.unlockProgress;
            if (p <= 0) return 0;
            if (p < 0.35) return p / 0.35 * 0.18;
            return (1 - (p - 0.35) / 0.65) * 0.18;
        }
        z: 100
    }

    // Soft black fade so the unlock handoff feels clean.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Math.max(0, (surface.unlockProgress - 0.45) / 0.55) * 0.55
        z: 101
    }

    // Reset password + shake on failed attempt.
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
        NumberAnimation { duration: 620; easing.type: Easing.OutCubic }
    }

    Behavior on unlockProgress {
        NumberAnimation { duration: 900; easing.type: Easing.InOutCubic }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
        reveal = 1;
    }
}
