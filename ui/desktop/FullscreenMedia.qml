import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services
import qs.components

/**
 * Fullscreen now-playing + lyrics — album-tinted frosted glass.
 * Palette comes from the rust daemon; QML only crossfades it.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: mediaWindow

        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "fullscreen_media"
        WlrLayershell.keyboardFocus: Lyrics.showFullscreen
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        visible: Lyrics.showFullscreen || Lyrics.fullscreenTransitioning
            || openSequence.running || closeSequence.running || morphProgress > 0.001

        property real morphProgress: 0.0
        property real lyricsProgress: 0.0
        property real backdropProgress: 0.0
        property real shellOpacity: 1.0

        function openFullscreen() {
            closeSequence.stop();
            openSequence.stop();
            Lyrics.fullscreenTransitioning = true;
            openSequence.start();
        }

        function closeFullscreen() {
            openSequence.stop();
            closeSequence.stop();
            Lyrics.fullscreenTransitioning = true;
            closeSequence.start();
        }

        onMorphProgressChanged: Lyrics.fullscreenProgress = morphProgress

        Connections {
            target: Lyrics
            function onShowFullscreenChanged() {
                if (Lyrics.showFullscreen)
                    mediaWindow.openFullscreen();
                else
                    mediaWindow.closeFullscreen();
            }
        }

        Component.onCompleted: {
            if (Lyrics.showFullscreen)
                Qt.callLater(openFullscreen);
        }

        SequentialAnimation {
            id: openSequence

            ParallelAnimation {
                NumberAnimation {
                    target: mediaWindow
                    property: "morphProgress"
                    to: 1
                    duration: 620
                    easing.type: Easing.OutExpo
                }
                NumberAnimation {
                    target: mediaWindow
                    property: "backdropProgress"
                    to: 1
                    duration: 480
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: mediaWindow
                    property: "shellOpacity"
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            PauseAnimation { duration: 45 }
            NumberAnimation {
                target: mediaWindow
                property: "lyricsProgress"
                to: mainRow.hasLyrics ? 1 : 0
                duration: 560
                easing.type: Easing.OutQuint
            }
            ScriptAction { script: Lyrics.fullscreenTransitioning = false }
        }

        SequentialAnimation {
            id: closeSequence

            ParallelAnimation {
                NumberAnimation {
                    target: mediaWindow
                    property: "lyricsProgress"
                    to: 0
                    duration: 360
                    easing.type: Easing.InOutCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: 100 }
                    NumberAnimation {
                        target: mediaWindow
                        property: "morphProgress"
                        to: 0
                        duration: 430
                        easing.type: Easing.InOutCubic
                    }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 120 }
                    NumberAnimation {
                        target: mediaWindow
                        property: "backdropProgress"
                        to: 0
                        duration: 370
                        easing.type: Easing.InOutCubic
                    }
                }
            }
            // At this point the overlay shell exactly covers the real dock.
            // Crossfade the identical shapes instead of dropping one surface.
            ScriptAction { script: Lyrics.fullscreenProgress = 0 }
            NumberAnimation {
                target: mediaWindow
                property: "shellOpacity"
                to: 0
                duration: 110
                easing.type: Easing.OutCubic
            }
            ScriptAction {
                script: {
                    Lyrics.fullscreenProgress = 0;
                    Lyrics.fullscreenTransitioning = false;
                }
            }
        }

        NumberAnimation {
            id: lyricsOnlyAnimation
            target: mediaWindow
            property: "lyricsProgress"
            duration: 460
            easing.type: Easing.InOutQuint
        }

        readonly property color artPrimary: Playerctl.artPrimary
        readonly property color artSecondary: Playerctl.artSecondary
        readonly property color artAccent: Playerctl.artAccent
        readonly property color artBg: Playerctl.artBg
        readonly property color artFg: Playerctl.artFg

        Item {
            anchors.fill: parent

            AlbumBackdrop {
                primary: artPrimary
                secondary: artSecondary
                accent: artAccent
                bg: artBg
                alive: Lyrics.showFullscreen
                opacity: mediaWindow.backdropProgress
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Lyrics.showFullscreen = false

                MouseArea {
                    anchors.fill: parent
                    onClicked: Lyrics.showFullscreen = false
                }
            }

            Row {
                id: mainRow
                property bool hasLyrics: Lyrics.parsedLyrics.length > 0
                onHasLyricsChanged: {
                    if (!Lyrics.showFullscreen || mediaWindow.morphProgress < 0.99)
                        return;
                    lyricsOnlyAnimation.stop();
                    lyricsOnlyAnimation.to = hasLyrics ? 1 : 0;
                    lyricsOnlyAnimation.start();
                }

                anchors.fill: parent
                anchors.margins: 48
                spacing: hasLyrics ? 36 : 0
                z: 2

                Behavior on spacing { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                // LEFT: media card
                Item {
                    id: leftPane
                    width: mainRow.hasLyrics ? (parent.width - 36) / 2 : parent.width
                    height: parent.height

                    Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                    MouseArea {
                        anchors.fill: mediaCard
                    }

                    Rectangle {
                        id: mediaCard
                        readonly property real targetWidth: Math.min(leftPane.width * 0.92, 460)
                        readonly property real targetHeight: mediaCol.implicitHeight + 48

                        anchors.centerIn: parent
                        width: LauncherState.dockWidth
                            + (targetWidth - LauncherState.dockWidth) * mediaWindow.morphProgress
                        height: LauncherState.dockHeight
                            + (targetHeight - LauncherState.dockHeight) * mediaWindow.morphProgress
                        radius: LauncherState.dockRadius
                            + (32 - LauncherState.dockRadius) * mediaWindow.morphProgress
                        color: Qt.rgba(
                            Theme.glass_shell.r * (1 - mediaWindow.morphProgress) + mediaWindow.morphProgress,
                            Theme.glass_shell.g * (1 - mediaWindow.morphProgress) + mediaWindow.morphProgress,
                            Theme.glass_shell.b * (1 - mediaWindow.morphProgress) + mediaWindow.morphProgress,
                            Theme.glass_shell.a * (1 - mediaWindow.morphProgress) + 0.24 * mediaWindow.morphProgress)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1,
                            0.22 + 0.18 * mediaWindow.morphProgress)
                        clip: true
                        opacity: mediaWindow.shellOpacity

                        transform: Translate {
                            x: (mediaWindow.width / 2
                                - (mainRow.x + leftPane.x + leftPane.width / 2))
                                * (1 - mediaWindow.morphProgress)
                            y: (-14 + LauncherState.dockHeight / 2
                                - (mainRow.y + leftPane.y + leftPane.height / 2))
                                * (1 - mediaWindow.morphProgress)
                        }

                        BubbleSheen { opacity: mediaWindow.morphProgress }

                        // Keep title/artist readable over bright frosted glass
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            z: 0
                            opacity: mediaWindow.morphProgress
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.12) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                            }
                        }

                        Column {
                            id: mediaCol
                            anchors.centerIn: parent
                            width: mediaCard.targetWidth - 48
                            spacing: 22
                            z: 1
                            opacity: Math.max(0, Math.min(1,
                                (mediaWindow.morphProgress - 0.42) / 0.58))
                            scale: 0.94 + 0.06 * opacity

                            Item {
                                width: Math.min(parent.width, 320)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: mediaCard.radius
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    opacity: (BackendDaemon.musicRemoteUrl === "" || BackendDaemon.musicRemoteConnected) ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    contentUnderBorder: true

                                    Image {
                                        id: mainArt
                                        anchors.fill: parent
                                        source: Playerctl.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                        sourceSize: Qt.size(768, 768)
                                        visible: Playerctl.artUrl !== ""
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: Playerctl.artUrl === ""
                                        icon: "music_note"
                                        font.pixelSize: 72
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 22
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                    opacity: (BackendDaemon.musicRemoteUrl !== "" && !BackendDaemon.musicRemoteConnected) ? 1.0 : 0.0
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 14

                                        Rectangle {
                                            width: 168
                                            height: 168
                                            radius: 20
                                            color: "white"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            clip: true

                                            Image {
                                                anchors.centerIn: parent
                                                width: 140
                                                height: 140
                                                source: BackendDaemon.musicRemoteQrSvg !== ""
                                                    ? "data:image/svg+xml;utf8," + encodeURIComponent(BackendDaemon.musicRemoteQrSvg)
                                                    : ""
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(200, 200)
                                            }
                                        }

                                        Text {
                                            text: "Scan to Control Music"
                                            font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                                            color: Qt.rgba(1, 1, 1, 0.85)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: Playerctl.title !== "" ? Playerctl.title : "No Media"
                                    font { family: "Google Sans"; pixelSize: 26; weight: Font.Bold }
                                    color: Qt.rgba(1, 1, 1, 0.95)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    width: parent.width
                                    text: Playerctl.artist !== "" ? Playerctl.artist : "Unknown Artist"
                                    font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // Seekbar — drag scrub with live preview
                            Column {
                                id: seekCol
                                width: parent.width
                                spacing: 8
                                visible: Playerctl.length > 0

                                readonly property real progress: Playerctl.length > 0
                                    ? Math.min(1, Playerctl.position / Playerctl.length) : 0
                                property real scrubRatio: -1
                                readonly property real shownRatio: scrubRatio >= 0
                                    ? scrubRatio : progress
                                readonly property real shownSeconds: shownRatio * Playerctl.length

                                function formatTime(secs) {
                                    secs = Math.max(0, Math.floor(Number(secs) || 0));
                                    const m = Math.floor(secs / 60);
                                    const s = secs % 60;
                                    return m + ":" + (s < 10 ? "0" : "") + s;
                                }

                                function seekAt(x, trackWidth) {
                                    if (trackWidth <= 0 || Playerctl.length <= 0)
                                        return;
                                    scrubRatio = Math.max(0, Math.min(1, x / trackWidth));
                                }

                                function commitSeek() {
                                    if (scrubRatio < 0 || Playerctl.length <= 0)
                                        return;
                                    Playerctl.setPosition(scrubRatio * Playerctl.length);
                                    scrubRatio = -1;
                                }

                                Item {
                                    id: seekTrack
                                    width: parent.width
                                    height: 28

                                    // Soft hit area — fixed height so the thumb
                                    // never reflows while hover thickens the fill.
                                    Rectangle {
                                        id: seekRail
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(1, 1, 1, 0.22)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.18)

                                        Rectangle {
                                            id: seekFill
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: seekArea.pressed || seekArea.containsMouse ? 8 : 6
                                            radius: height / 2
                                            color: artAccent
                                            width: Math.max(0, parent.width * seekCol.shownRatio)
                                            Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
                                        }

                                        // Thumb sits on a 1px anchor so size/scale
                                        // never feeds back into its X position.
                                        Item {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.round(parent.width * seekCol.shownRatio)
                                            width: 1
                                            height: 1
                                            z: 2

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: Qt.rgba(1, 1, 1, 0.96)
                                                scale: seekArea.pressed ? 1.28
                                                    : (seekArea.containsMouse ? 1.14 : 1.0)
                                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: seekArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        preventStealing: true
                                        onPressed: (mouse) => seekCol.seekAt(mouse.x, width)
                                        onPositionChanged: (mouse) => {
                                            if (pressed)
                                                seekCol.seekAt(mouse.x, width);
                                        }
                                        onReleased: seekCol.commitSeek()
                                        onCanceled: seekCol.scrubRatio = -1
                                    }
                                }

                                Row {
                                    width: parent.width

                                    Text {
                                        id: seekPosLabel
                                        text: seekCol.formatTime(seekCol.shownSeconds)
                                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                        color: Qt.rgba(1, 1, 1, seekCol.scrubRatio >= 0 ? 0.9 : 0.55)
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - seekPosLabel.width - seekDurLabel.width)
                                        height: 1
                                    }

                                    Text {
                                        id: seekDurLabel
                                        text: seekCol.formatTime(Playerctl.length)
                                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                    }
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 16
                                height: 64

                                component TransportBtn: Rectangle {
                                    property string iconName
                                    property real size: 48
                                    property bool accent: false
                                    signal triggered

                                    width: size
                                    height: size
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: size / 2
                                    color: {
                                        if (accent)
                                            return Qt.alpha(Playerctl.artAccent, Playerctl.isPlaying ? 0.62 : 0.4);
                                        return hover.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.4)
                                            : Qt.rgba(1, 1, 1, 0.28);
                                    }
                                    border.width: 1
                                    border.color: accent
                                        ? Qt.rgba(1, 1, 1, 0.45)
                                        : Qt.rgba(1, 1, 1, 0.38)
                                    clip: true
                                    scale: hover.pressed ? 0.92 : (hover.containsMouse ? 1.05 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    BubbleSheen { visible: accent }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        z: 1
                                        icon: parent.iconName
                                        font.pixelSize: Math.round(parent.size * 0.42)
                                        color: parent.accent ? Playerctl.artFg : Qt.rgba(1, 1, 1, 0.85)
                                    }

                                    MouseArea {
                                        id: hover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.triggered()
                                    }
                                }

                                TransportBtn {
                                    iconName: "skip_previous"
                                    onTriggered: Playerctl.previous()
                                }
                                TransportBtn {
                                    iconName: Playerctl.isPlaying ? "pause" : "play_arrow"
                                    size: 64
                                    accent: true
                                    onTriggered: Playerctl.playPause()
                                }
                                TransportBtn {
                                    iconName: "skip_next"
                                    onTriggered: Playerctl.next()
                                }
                            }
                        }
                    }
                }

                // RIGHT: lyrics glass pane
                Rectangle {
                    id: lyricsPane
                    readonly property real contentReveal: Math.max(0, Math.min(1,
                        (mediaWindow.lyricsProgress - 0.26) / 0.74))

                    width: mainRow.hasLyrics ? (parent.width - 36) / 2 : 0
                    height: parent.height
                    radius: 32
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.38)
                    opacity: mainRow.hasLyrics
                        ? Math.min(1, mediaWindow.lyricsProgress * 3.5) : 0
                    Behavior on color { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
                    visible: opacity > 0 || width > 0
                    clip: true

                    Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.InOutQuint } }

                    transform: [
                        Scale {
                            origin.x: lyricsPane.width / 2
                            origin.y: lyricsPane.height / 2
                            xScale: (mediaCard.targetWidth / Math.max(1, lyricsPane.width))
                                + (1 - mediaCard.targetWidth / Math.max(1, lyricsPane.width))
                                * mediaWindow.lyricsProgress
                            yScale: (mediaCard.targetHeight / Math.max(1, lyricsPane.height))
                                + (1 - mediaCard.targetHeight / Math.max(1, lyricsPane.height))
                                * mediaWindow.lyricsProgress
                        },
                        Translate {
                            x: (mainRow.x + leftPane.x + leftPane.width / 2
                                - (mainRow.x + lyricsPane.x + lyricsPane.width / 2))
                                * (1 - mediaWindow.lyricsProgress)
                        }
                    ]

                    BubbleSheen {}
                    MouseArea {
                        anchors.fill: parent
                        enabled: lyricsPane.contentReveal > 0.8
                    }

                    // Soft dark wash so white lyrics stay readable on bright glass
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        z: 0
                        opacity: lyricsPane.contentReveal
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
                            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.1) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
                        }
                    }

                    ListView {
                        id: lyricsView
                        anchors.fill: parent
                        anchors.margins: 56
                        anchors.topMargin: 40
                        anchors.bottomMargin: 64
                        clip: true
                        z: 1
                        opacity: lyricsPane.contentReveal
                        transform: Translate {
                            x: -30 * (1 - lyricsPane.contentReveal)
                        }

                        model: Lyrics.parsedLyrics
                        interactive: true

                        // Snap instantly until the pane has finished opening so
                        // the morph never reveals a scroll catching up.
                        property bool snapHighlight: true

                        preferredHighlightBegin: 0
                        preferredHighlightEnd: height * 0.58
                        highlightRangeMode: ListView.ApplyRange
                        highlightMoveDuration: snapHighlight ? 0 : 420

                        currentIndex: Math.max(0, Lyrics.currentIndex)

                        function snapToCurrent() {
                            snapHighlight = true;
                            const idx = Math.max(0, Lyrics.currentIndex);
                            if (count > 0)
                                positionViewAtIndex(idx, ListView.Beginning);
                        }

                        Component.onCompleted: snapToCurrent()
                        onCountChanged: if (mediaWindow.lyricsProgress < 0.99) snapToCurrent()
                        onCurrentIndexChanged: {
                            if (snapHighlight && count > 0)
                                positionViewAtIndex(currentIndex, ListView.Beginning);
                        }

                        Connections {
                            target: Lyrics
                            function onCurrentIndexChanged() {
                                if (lyricsView.snapHighlight)
                                    lyricsView.snapToCurrent();
                            }
                            function onShowFullscreenChanged() {
                                if (Lyrics.showFullscreen)
                                    lyricsView.snapToCurrent();
                            }
                        }

                        Connections {
                            target: mediaWindow
                            function onLyricsProgressChanged() {
                                if (mediaWindow.lyricsProgress >= 0.99 && lyricsView.snapHighlight)
                                    lyricsView.snapHighlight = false;
                                else if (mediaWindow.lyricsProgress < 0.2)
                                    lyricsView.snapToCurrent();
                            }
                        }

                        delegate: Item {
                            width: ListView.view.width
                            // Reserve room for the scaled-up current line so
                            // neighbors don't shift when emphasis changes.
                            height: contentCol.implicitHeight + 28

                            property bool isCurrent: index === lyricsView.currentIndex

                            MouseArea {
                                id: lyricMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Playerctl.setPosition(modelData.time)
                            }

                            Column {
                                id: contentCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                // Fixed pixelSize keeps wrap breaks stable;
                                // scale/opacity carry the current-line emphasis.
                                Text {
                                    width: parent.width
                                    text: modelData.text
                                    color: Qt.rgba(1, 1, 1, 1)
                                    wrapMode: Text.WordWrap

                                    font {
                                        family: "Google Sans"
                                        pixelSize: 28
                                        // Keep weight fixed — Bold vs Medium
                                        // reflows wraps the same way size did.
                                        weight: Font.DemiBold
                                    }

                                    opacity: Math.min(1.0, (isCurrent ? 1.0 : 0.28)
                                        + (lyricMouse.containsMouse ? 0.3 : 0.0))
                                    scale: isCurrent ? 1.12 : 0.86
                                    transformOrigin: Item.Left

                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.textTranslit !== undefined ? modelData.textTranslit : ""
                                    visible: text !== ""
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                    wrapMode: Text.WordWrap

                                    font {
                                        family: "Google Sans"
                                        pixelSize: 15
                                        weight: Font.Medium
                                    }

                                    opacity: Math.min(1.0, (isCurrent ? 0.75 : 0.2)
                                        + (lyricMouse.containsMouse ? 0.25 : 0.0))
                                    scale: isCurrent ? 1.08 : 0.92
                                    transformOrigin: Item.Left
                                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        z: 1
                        visible: Lyrics.parsedLyrics.length === 0
                        opacity: lyricsPane.contentReveal
                        text: Playerctl.isPlaying ? "Fetching lyrics…" : "No Media"
                        font { family: "Google Sans"; pixelSize: 20; weight: Font.Medium }
                        color: Qt.rgba(1, 1, 1, 0.4)
                    }
                }
            }

            // A short-lived elastic neck makes the second pane feel pulled out
            // of the media card instead of appearing as an unrelated panel.
            Rectangle {
                id: liquidBridge
                readonly property real p: mediaWindow.lyricsProgress
                readonly property real wave: Math.sin(Math.PI * p)
                readonly property real cardCenter: mainRow.x + leftPane.x + leftPane.width / 2
                readonly property real cardRight: cardCenter + mediaCard.targetWidth / 2
                readonly property real lyricsTargetCenter:
                    mainRow.x + lyricsPane.x + lyricsPane.width / 2
                readonly property real movingCenter:
                    cardCenter + (lyricsTargetCenter - cardCenter) * p
                readonly property real movingWidth:
                    mediaCard.targetWidth + (lyricsPane.width - mediaCard.targetWidth) * p
                readonly property real movingLeft: movingCenter - movingWidth / 2

                x: cardRight - 28
                width: Math.max(56, movingLeft - x + 28)
                height: 72 + 76 * wave
                y: mediaWindow.height / 2 - height / 2
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.2)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
                opacity: mainRow.hasLyrics ? wave * 0.72 : 0
                visible: opacity > 0.001
                z: 1

                BubbleSheen {}
            }

            // Cast / sync — floating bubble
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 40
                anchors.bottomMargin: 40
                width: 52
                height: 52
                radius: 26
                color: remoteMouse.containsMouse
                    ? Qt.rgba(1, 1, 1, 0.4)
                    : Qt.rgba(1, 1, 1, 0.28)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.4)
                opacity: Playerctl.hasPlayer
                    ? Math.max(0, Math.min(1,
                        (mediaWindow.morphProgress - 0.65) / 0.35))
                    : 0
                visible: opacity > 0
                clip: true

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                BubbleSheen {}

                MaterialIcon {
                    anchors.centerIn: parent
                    z: 1
                    icon: BackendDaemon.musicRemoteUrl !== "" ? "cast" : "sync"
                    font.pixelSize: 22
                    color: Qt.rgba(1, 1, 1, 0.75)
                }

                MouseArea {
                    id: remoteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (BackendDaemon.musicRemoteUrl !== "")
                            BackendDaemon.send({action: "music_remote_stop"});
                        else
                            BackendDaemon.send({action: "music_remote_start"});
                    }
                }
            }
        }
    }
}
