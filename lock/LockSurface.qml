import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

import qs.theme
import qs.services
import qs.components
import "../history.js" as History

/**
 * Apple-inspired session lock.
 *
 * A single glass object begins at the live dock footprint, travels down the
 * screen, and becomes the authentication card. The same object reverses on
 * successful authentication, so entrance and exit never read as unrelated
 * panels crossfading.
 */
WlSessionLockSurface {
    id: surface

    property var controller

    color: Theme.background

    readonly property bool authenticating: controller ? controller.authenticating : false
    readonly property string statusMessage: controller ? controller.statusMessage : ""
    readonly property bool statusIsError: controller ? controller.statusIsError : false
    readonly property bool unlocking: controller ? controller.unlocking : false
    readonly property bool mediaActive: Playerctl.hasPlayer && Playerctl.title.length > 0

    property bool entranceStarted: false
    property real reveal: 0
    property real unlockProgress: 0
    property real morph: 0
    property real mediaFactor: mediaActive ? 1 : 0

    property string historyTitle: ""
    property string historyBody: ""
    property string historyDateKey: ""

    readonly property real phase: Math.max(0, Math.min(1, reveal - unlockProgress))
    readonly property real contentProgress: Math.max(0, Math.min(1, (phase - 0.2) / 0.8))
    readonly property real morphValue: Math.max(0, Math.min(1, morph))

    function lerp(from, to, amount) {
        return from + (to - from) * amount;
    }

    function beginEntrance() {
        if (entranceStarted)
            return;
        entranceStarted = true;
        frameFallback.stop();
        reveal = 1;
        morph = 1;
        Qt.callLater(function() {
            passwordInput.forceActiveFocus();
        });
    }

    function refreshHistory() {
        const now = new Date();
        const key = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate();
        if (key === historyDateKey)
            return;
        historyDateKey = key;
        const event = History.getTodayEvent();
        historyTitle = event[0];
        historyBody = event[1];
    }

    onUnlockingChanged: {
        if (unlocking) {
            unlockProgress = 1;
            exitMorph.restart();
            passwordInput.clear();
        }
    }

    onMediaActiveChanged: mediaFactor = mediaActive ? 1 : 0

    Behavior on reveal {
        NumberAnimation { duration: 430; easing.type: Easing.OutCubic }
    }

    Behavior on unlockProgress {
        NumberAnimation { duration: 620; easing.type: Easing.InOutCubic }
    }

    Behavior on morph {
        enabled: !surface.unlocking
        SpringAnimation {
            spring: 6
            damping: 0.58
            epsilon: 0.003
        }
    }

    NumberAnimation {
        id: exitMorph
        target: surface
        property: "morph"
        to: 0
        duration: 620
        easing.type: Easing.InOutCubic
    }

    Behavior on mediaFactor {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Never grabToImage on a WlSessionLockSurface — that path hits
    // updatePixelRatioHelper and SIGSEGVs on Asahi. A short timer is enough
    // for the surface to map before the entrance morph starts.
    Timer {
        id: frameFallback
        interval: 48
        onTriggered: surface.beginEntrance()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: surface.refreshHistory()
    }

    Item {
        id: lockStage
        anchors.fill: parent

        LockBackground {
            progress: surface.phase
            alive: surface.phase > 0.05 && !surface.unlocking
            scale: 1.015 - surface.phase * 0.015
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.22 * (1 - surface.phase))
        }

        Item {
            id: clockBlock

            readonly property real show: Math.max(0, Math.min(1, (surface.phase - 0.06) / 0.62))

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.075 - (1 - show) * 22
            width: timeText.width
            height: timeText.height + dateText.height + 8
            opacity: show
            scale: 0.975 + show * 0.025

            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Qt.rgba(1, 1, 1, 0.88)
                font {
                    family: "Google Sans"
                    pixelSize: Math.max(82, Math.min(surface.width * 0.13, surface.height * 0.155))
                    weight: Font.Black
                    letterSpacing: -5
                }
            }

            Text {
                id: dateText
                anchors.top: timeText.bottom
                anchors.topMargin: -3
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: Qt.rgba(1, 1, 1, 0.62)
                font {
                    family: "Google Sans"
                    pixelSize: Math.max(15, Math.min(21, surface.height * 0.021))
                    weight: Font.DemiBold
                    letterSpacing: 0.25
                }
            }
        }

        Column {
            id: historyCard

            readonly property bool wideLayout: surface.width >= 1060
            readonly property real show: Math.max(0, Math.min(1, (surface.phase - 0.42) / 0.5))

            width: Math.min(300, surface.width - 40)
            x: wideLayout ? surface.width - width - 42 : 20
            y: wideLayout
                ? surface.height - height - 42
                : Math.min(surface.height * 0.37, shell.targetY - height - 28)
            spacing: 4
            opacity: show * 0.55
            visible: surface.historyTitle.length > 0
            transform: Translate { y: (1 - historyCard.show) * 12 }

            Text {
                width: parent.width
                text: surface.historyTitle
                color: Qt.rgba(1, 1, 1, 0.85)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font {
                    family: "Google Sans"
                    pixelSize: 13
                    weight: Font.DemiBold
                    letterSpacing: 0.15
                }
            }

            Text {
                width: parent.width
                text: surface.historyBody
                color: Qt.rgba(1, 1, 1, 0.5)
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                font {
                    family: "Google Sans"
                    pixelSize: 12
                    weight: Font.Normal
                }
            }
        }

        Rectangle {
            id: shell

            readonly property real initialWidth: Math.max(238,
                Math.min(LauncherState.dockWidth, surface.width - 24))
            readonly property real initialHeight: Math.max(40,
                Math.min(LauncherState.dockHeight, 52))
            readonly property real initialRadius: Math.max(12, LauncherState.dockRadius)
            readonly property real targetWidth: Math.min(440, surface.width - 32)
            readonly property real targetHeight: Math.min(surface.height - 92,
                228 + 88 * surface.mediaFactor)
            readonly property real bottomGap: Math.max(42, Math.min(96, surface.height * 0.09))
            readonly property real targetY: surface.height - targetHeight - bottomGap

            x: (surface.width - width) / 2
            y: surface.lerp(-14, targetY, surface.morphValue)
            width: surface.lerp(initialWidth, targetWidth, surface.morphValue)
            height: surface.lerp(initialHeight, targetHeight, surface.morphValue)
            radius: surface.lerp(initialRadius, 34, surface.morphValue)
            color: Qt.rgba(0.035, 0.04, 0.065,
                surface.lerp(0.52, 0.64, surface.morphValue))
            border.width: 1
            border.color: Qt.rgba(1, 1, 1,
                surface.lerp(0.22, 0.3, surface.morphValue))
            clip: true

            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on border.color { ColorAnimation { duration: 300 } }

            // Inner luminous wash. Clipping it inside the persistent shell
            // creates the refractive edge without a separate shader surface.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 0.34; color: Qt.rgba(1, 1, 1, 0.055) }
                    GradientStop { position: 0.72; color: Qt.rgba(1, 1, 1, 0.018) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.12) }
                }
            }

            BubbleSheen {}

            Item {
                id: authContent
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 16
                }
                height: mediaCard.y + mediaCard.height
                opacity: surface.contentProgress
                transform: Translate { y: (1 - surface.contentProgress) * 14 }

                Item {
                    id: welcomeHeader
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: 38

                    Rectangle {
                        id: userGlyph
                        width: 34
                        height: 34
                        radius: width / 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(Theme.primary, 0.16)
                        border.width: 1
                        border.color: Qt.alpha(Theme.primary, 0.32)

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "person"
                            fill: 0
                            grade: -25
                            weight: 300
                            font.pixelSize: 18
                            color: Theme.primary
                        }
                    }

                    Column {
                        anchors {
                            left: userGlyph.right
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 0

                        Text {
                            text: "Welcome back"
                            color: Qt.rgba(1, 1, 1, 0.56)
                            font {
                                family: "Google Sans"
                                pixelSize: 10
                                weight: Font.Medium
                                letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: {
                                const user = Quickshell.env("USER") || "user";
                                return user.charAt(0).toUpperCase() + user.slice(1);
                            }
                            color: Qt.rgba(1, 1, 1, 0.96)
                            font {
                                family: "Google Sans"
                                pixelSize: 17
                                weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font {
                            family: "Google Sans"
                            pixelSize: 11
                            weight: Font.Medium
                        }
                    }
                }

                Rectangle {
                    id: passwordField

                    property real shakeX: 0
                    property real errorPulse: 0

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: welcomeHeader.bottom
                        topMargin: 10
                    }
                    height: 42
                    radius: height / 2
                    color: passwordInput.activeFocus
                        ? Qt.rgba(1, 1, 1, 0.14)
                        : Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1
                    border.color: errorPulse > 0
                        ? Qt.alpha(Theme.critical, 0.55 + errorPulse * 0.35)
                        : (passwordInput.activeFocus
                            ? Qt.alpha(Theme.primary, 0.55)
                            : Qt.rgba(1, 1, 1, 0.18))
                    transform: Translate { x: passwordField.shakeX }
                    clip: true

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Rectangle {
                        width: parent.width * passwordField.errorPulse
                        height: parent.height
                        radius: parent.radius
                        color: Qt.alpha(Theme.critical, 0.08)
                    }

                    MaterialIcon {
                        id: lockIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        icon: surface.authenticating ? "lock_clock" : "lock"
                        fill: 0
                        grade: -25
                        weight: 300
                        font.pixelSize: 15
                        color: passwordInput.activeFocus
                            ? Theme.primary
                            : Qt.rgba(1, 1, 1, 0.55)

                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    TextInput {
                        id: passwordInput
                        anchors {
                            left: lockIcon.right
                            leftMargin: 9
                            right: revealButton.left
                            rightMargin: 4
                            top: parent.top
                            bottom: parent.bottom
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Qt.rgba(1, 1, 1, 0.94)
                        selectionColor: Qt.alpha(Theme.primary, 0.42)
                        selectedTextColor: "white"
                        echoMode: revealButton.revealed ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        passwordMaskDelay: 0
                        cursorVisible: activeFocus
                        enabled: !surface.authenticating && !surface.unlocking
                        focus: true
                        clip: true
                        font {
                            family: "Google Sans"
                            pixelSize: 14
                            weight: Font.Medium
                            letterSpacing: echoMode === TextInput.Password ? 2.2 : 0
                        }

                        onAccepted: {
                            if (surface.controller && text.length > 0 && !surface.unlocking)
                                surface.controller.submit(text);
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passwordInput.text.length === 0
                            text: "Enter password"
                            color: Qt.rgba(1, 1, 1, 0.38)
                            font: passwordInput.font
                        }
                    }

                    Item {
                        id: revealButton
                        property bool revealed: false

                        width: 26
                        height: 26
                        anchors {
                            right: submitButton.left
                            rightMargin: 2
                            verticalCenter: parent.verticalCenter
                        }
                        visible: passwordInput.text.length > 0
                        opacity: visible ? 1 : 0

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: revealButton.revealed ? "visibility_off" : "visibility"
                            fill: 0
                            grade: -25
                            weight: 300
                            font.pixelSize: 14
                            color: revealMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.9)
                                : Qt.rgba(1, 1, 1, 0.5)
                        }

                        MouseArea {
                            id: revealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                revealButton.revealed = !revealButton.revealed;
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }

                    Rectangle {
                        id: submitButton

                        readonly property bool ready: passwordInput.text.length > 0
                            && !surface.authenticating && !surface.unlocking

                        width: 30
                        height: 30
                        radius: width / 2
                        anchors {
                            right: parent.right
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        color: ready
                            ? Qt.alpha(Theme.primary, submitMouse.containsMouse ? 0.72 : 0.52)
                            : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        border.color: ready
                            ? Qt.alpha(Theme.primary, 0.72)
                            : Qt.rgba(1, 1, 1, 0.12)
                        scale: submitMouse.pressed ? 0.9 : 1
                        clip: true

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !surface.authenticating
                            icon: "arrow_forward"
                            fill: 0
                            grade: -25
                            weight: 300
                            font.pixelSize: 15
                            color: submitButton.ready
                                ? Qt.rgba(1, 1, 1, 0.96)
                                : Qt.rgba(1, 1, 1, 0.3)
                        }

                        Shape {
                            width: 18
                            height: 18
                            anchors.centerIn: parent
                            visible: surface.authenticating
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 2
                                strokeColor: Theme.primary
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 9
                                    centerY: 9
                                    radiusX: 6
                                    radiusY: 6
                                    startAngle: 0
                                    sweepAngle: 285
                                    moveToStart: true
                                }
                            }

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 760
                                loops: Animation.Infinite
                                running: surface.authenticating
                            }
                        }

                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            enabled: submitButton.ready
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: surface.controller.submit(passwordInput.text)
                        }
                    }
                }

                Item {
                    id: statusArea
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: passwordField.bottom
                        topMargin: 2
                    }
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (surface.unlocking)
                                return "Unlocked";
                            if (surface.authenticating)
                                return "Authenticating…";
                            return surface.statusMessage;
                        }
                        color: surface.statusIsError
                            ? Theme.critical
                            : (surface.unlocking ? Theme.primary : Qt.rgba(1, 1, 1, 0.5))
                        opacity: text.length > 0 ? 1 : 0
                        font {
                            family: "Google Sans"
                            pixelSize: 11
                            weight: Font.Medium
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                }

                LockMediaCard {
                    id: mediaCard
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: statusArea.bottom
                        topMargin: 6
                    }
                    height: implicitHeight
                    mediaActive: surface.mediaActive
                    presentationProgress: Math.max(0,
                        Math.min(1, (surface.contentProgress - 0.3) / 0.7))
                }
            }

            LockSessionBar {
                id: sessionBar
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 12 + surface.morphValue * 4
                    rightMargin: 12 + surface.morphValue * 4
                    bottomMargin: -1 + surface.morphValue * 12
                }
                height: 40
                presentationProgress: surface.contentProgress
                opacity: 0.28 + surface.contentProgress * 0.72
                scale: 0.96 + surface.contentProgress * 0.04
            }
        }
    }

    SequentialAnimation {
        id: passwordShake
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: -18
            duration: 42
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: 16
            duration: 48
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: -12
            duration: 46
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: 8
            duration: 44
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: -4
            duration: 40
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: passwordField
            property: "shakeX"
            to: 0
            duration: 52
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: errorFlash
        NumberAnimation {
            target: passwordField
            property: "errorPulse"
            from: 0
            to: 1
            duration: 90
            easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 170 }
        NumberAnimation {
            target: passwordField
            property: "errorPulse"
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: surface.controller

        function onStatusIsErrorChanged() {
            if (!surface.controller || !surface.controller.statusIsError || surface.unlocking)
                return;
            passwordShake.restart();
            errorFlash.restart();
            passwordInput.clear();
            passwordInput.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        refreshHistory();
        frameFallback.start();
    }
}
