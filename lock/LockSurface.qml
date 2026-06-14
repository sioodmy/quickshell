import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower

import qs.theme

WlSessionLockSurface {
    id: surface

    property var controller

    color: Theme.background

    readonly property string lockWall: Quickshell.env("LOCKSCREEN_WALL") || ""
    readonly property string wallSource: lockWall !== ""
        ? "file://" + lockWall
        : Theme.wallpaper

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // --- Wallpaper background (sharp) ---
    Image {
        anchors.fill: parent
        source: surface.wallSource
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
    }

    // --- Split clock (left side) ---
    Column {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.07
        anchors.verticalCenter: parent.verticalCenter
        spacing: -surface.height * 0.05

        Text {
            id: hoursText
            text: Qt.formatDateTime(clock.date, "HH")
            color: Qt.rgba(1, 1, 1, 0.9)
            font {
                family: "Work Sans"
                pixelSize: Math.round(surface.height * 0.28)
                weight: Font.ExtraBold
            }
        }

        Text {
            text: Qt.formatDateTime(clock.date, "mm")
            color: Qt.rgba(1, 1, 1, 0.9)
            font {
                family: "Work Sans"
                pixelSize: Math.round(surface.height * 0.26)
                weight: Font.Bold
            }
        }

        TextMetrics {
            id: dateMetrics
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            font.family: "Work Sans"
            font.pixelSize: Math.round(surface.height * 0.028)
            font.weight: Font.Medium
        }

        Text {
            topPadding: surface.height * 0.04
            width: hoursText.contentWidth
            text: dateMetrics.text
            color: Qt.rgba(1, 1, 1, 0.9)
            horizontalAlignment: Text.AlignJustify
            font {
                family: "Work Sans"
                pixelSize: Math.round(surface.height * 0.028)
                weight: Font.Medium
                // Stretch the date so its edges line up with the clock digits.
                letterSpacing: Math.max(0, (hoursText.contentWidth - dateMetrics.advanceWidth) / Math.max(1, dateMetrics.text.length - 1))
            }
        }
    }

    // --- Password input (top right, no box) ---
    Item {
        id: passwordArea
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: parent.height * 0.12
        anchors.rightMargin: parent.width * 0.07
        width: 300
        height: 70

        TextInput {
            id: passwordInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 40
            horizontalAlignment: TextInput.AlignRight
            verticalAlignment: TextInput.AlignVCenter
            color: "white"
            font { family: "Google Sans"; pixelSize: 22; weight: Font.Medium }
            echoMode: TextInput.Password
            passwordCharacter: "●"
            clip: true
            enabled: !surface.controller.authenticating
            focus: true

            onAccepted: surface.controller.submit(text)

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                visible: passwordInput.text.length === 0
                text: "Password"
                color: Qt.rgba(1, 1, 1, 0.55)
                font: passwordInput.font
            }
        }

        // Subtle underline to keep the field visible
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: passwordInput.bottom
            anchors.topMargin: 6
            height: 2
            radius: 1
            color: passwordInput.activeFocus ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.35)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Status / error message
        Text {
            anchors.right: parent.right
            anchors.top: passwordInput.bottom
            anchors.topMargin: 14
            horizontalAlignment: Text.AlignRight
            text: surface.controller.authenticating
                ? "Authenticating…"
                : surface.controller.statusMessage
            visible: text.length > 0
            color: surface.controller.statusIsError ? Theme.critical : Qt.rgba(1, 1, 1, 0.7)
            font { family: "Google Sans"; pixelSize: 13 }
        }
    }

    // --- Session buttons (bottom right, white, no background) ---
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: parent.width * 0.07
        anchors.bottomMargin: parent.height * 0.08
        spacing: 28

        // Battery indicator
        Row {
            id: battRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: UPower.displayDevice?.isPresent ?? false

            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool charging: !UPower.onBattery

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                color: "white"
                opacity: 0.9
                text: {
                    if (battRow.charging && battRow.capacity < 100)
                        return "";
                    if (battRow.capacity >= 90)
                        return "󰂂";
                    if (battRow.capacity >= 70)
                        return "󰂀";
                    if (battRow.capacity >= 50)
                        return "󰁾";
                    if (battRow.capacity >= 30)
                        return "󰁼";
                    if (battRow.capacity >= 10)
                        return "󰁺";
                    return "󰂃";
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(battRow.capacity) + "%"
                color: "white"
                opacity: 0.9
                font { family: "Google Sans"; pixelSize: 16; weight: Font.Medium }
            }
        }

        component SessionButton: Item {
            id: sb
            property string icon
            signal triggered()

            width: 40
            height: 40

            Text {
                anchors.centerIn: parent
                text: sb.icon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 26 }
                color: "white"
                opacity: sbMouse.containsMouse ? 1.0 : 0.7
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                id: sbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sb.triggered()
            }
        }

        SessionButton {
            icon: ""
            onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
        }

        SessionButton {
            icon: ""
            onTriggered: Quickshell.execDetached(["shutdown", "now"])
        }
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
