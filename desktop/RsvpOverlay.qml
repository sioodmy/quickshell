import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rsvp_reader"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true; bottom: true; left: true; right: true
        }

        color: "transparent"
        visible: RsvpReader.active || opacityAnim.running

        // --- Animated Root Container ---
        Item {
            id: animRoot
            anchors.fill: parent

            opacity: RsvpReader.active ? 1.0 : 0.0
            scale: RsvpReader.active ? 1.0 : 1.05

            Behavior on opacity {
                NumberAnimation { id: opacityAnim; duration: 350; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
            }

            // --- Solid Background ---
            Rectangle {
                anchors.fill: parent
                color: Theme.background
            }

            // --- Floating Pastel Circles ---
            Item {
                id: bgCircles
                anchors.fill: parent
                clip: true

                // Large primary circle — top-left region
                Rectangle {
                    width: 900; height: 900; radius: 450
                    color: Theme.primary; opacity: 0.08
                    x: -200; y: -250
                    transformOrigin: Item.Center

                    SequentialAnimation on x {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: 250;  duration: 24000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -350; duration: 22000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -200; duration: 20000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: 200;  duration: 21000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -400; duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -250; duration: 19000; easing.type: Easing.InOutSine }
                    }
                }

                // Medium tertiary circle — bottom-right region
                Rectangle {
                    width: 700; height: 700; radius: 350
                    color: Theme.tertiary; opacity: 0.10
                    x: bgCircles.width - 500; y: bgCircles.height - 350
                    transformOrigin: Item.Center

                    SequentialAnimation on x {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: bgCircles.width / 2 + 200; duration: 26000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.width / 2 - 300; duration: 23000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.width - 500;     duration: 21000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: bgCircles.height / 2 - 200; duration: 23000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.height / 2 + 250; duration: 27000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.height - 350;     duration: 24000; easing.type: Easing.InOutSine }
                    }
                }

                // Small secondary circle — center drift
                Rectangle {
                    width: 500; height: 500; radius: 250
                    color: Theme.secondary; opacity: 0.06
                    x: bgCircles.width / 2 - 250; y: bgCircles.height / 2 - 250
                    transformOrigin: Item.Center

                    SequentialAnimation on x {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: bgCircles.width / 2 + 100; duration: 18000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.width / 2 - 350; duration: 22000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.width / 2 - 250; duration: 20000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite; paused: !RsvpReader.active
                        NumberAnimation { to: bgCircles.height / 2 + 200; duration: 20000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.height / 2 - 300; duration: 24000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: bgCircles.height / 2 - 250; duration: 18000; easing.type: Easing.InOutSine }
                    }
                }
            }

            // --- Key Input Handler ---
            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                        RsvpReader.quit();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Space) {
                        RsvpReader.playPause();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        RsvpReader.goBack();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K
                               || event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                        RsvpReader.speedUp();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J
                               || event.key === Qt.Key_Minus) {
                        RsvpReader.speedDown();
                        event.accepted = true;
                    }
                }
            }

            // --- Central Content Column ---
            Column {
                anchors.centerIn: parent
                spacing: 28
                width: parent.width * 0.7

                // Status row: word count | play/pause | WPM
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 32

                    // Word count
                    Text {
                        text: (RsvpReader.currentIndex + 1) + " / " + RsvpReader.wordCount
                        font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                        color: Theme.on_surface_variant
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Play/Pause indicator
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: RsvpReader.playing
                               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                               : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: RsvpReader.playing ? "pause" : "play_arrow"
                            font.pixelSize: 20
                            color: RsvpReader.playing ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    // WPM
                    Text {
                        text: RsvpReader.wpm + " WPM"
                        font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
                        color: Theme.on_surface_variant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // --- Central Word Display ---
                Item {
                    width: parent.width
                    height: 160
                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isDone: !RsvpReader.playing && RsvpReader.progress >= 1.0

                    // ORP marker — thin red vertical line above the word
                    Rectangle {
                        width: 2; height: 24; radius: 1
                        color: Theme.critical
                        opacity: isDone ? 0.0 : 0.7
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2 - wordA.paintedHeight / 2 - 8 - height
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    // Crossfade word display — two texts that alternate
                    property int displayIndex: RsvpReader.currentIndex
                    property bool _showA: true

                    onDisplayIndexChanged: {
                        if (_showA) {
                            wordB.text = RsvpReader.currentWord;
                            _showA = false;
                        } else {
                            wordA.text = RsvpReader.currentWord;
                            _showA = true;
                        }
                    }

                    Text {
                        id: wordA
                        anchors.centerIn: parent
                        text: RsvpReader.currentWord
                        font {
                            family: "Google Sans"
                            pixelSize: 96
                            weight: Font.Bold
                            letterSpacing: 2
                        }
                        color: Theme.on_surface
                        opacity: parent._showA && !parent.isDone ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.InOutQuad } }
                    }

                    Text {
                        id: wordB
                        anchors.centerIn: parent
                        text: ""
                        font {
                            family: "Google Sans"
                            pixelSize: 96
                            weight: Font.Bold
                            letterSpacing: 2
                        }
                        color: Theme.on_surface
                        opacity: !parent._showA && !parent.isDone ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.InOutQuad } }
                    }

                    // "Done" label — replaces the word, never overlaps
                    Text {
                        anchors.centerIn: parent
                        text: "✓  Done — press Space to restart"
                        font { family: "Google Sans"; pixelSize: 36; weight: Font.Medium }
                        color: Theme.primary
                        opacity: parent.isDone ? 0.9 : 0.0
                        scale: parent.isDone ? 1.0 : 0.95
                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                // --- Progress Bar ---
                Item {
                    width: parent.width
                    height: 4
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Track background
                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Theme.surface_variant
                    }

                    // Fill
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, RsvpReader.progress))
                        radius: 2
                        color: Theme.primary

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            // --- Keybind Cheatsheet ---
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: [
                        { key: "Space",     action: "Play / Pause" },
                        { key: "← / H",     action: "Back 5 words" },
                        { key: "↑ / K",     action: "Speed up" },
                        { key: "↓ / J",     action: "Speed down" },
                        { key: "Esc / Q",   action: "Quit" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: badgeRow.implicitWidth + 20
                        height: 32
                        radius: 16
                        color: Theme.surface_container_high
                        opacity: 0.85

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.key
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Bold }
                                color: Theme.on_surface
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.action
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Normal }
                                color: Theme.on_surface_variant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

        } // Close animRoot
    }
}
