import QtQuick
import QtQuick.Effects
import "../../theme"
import qs.services

Item {
    id: root

    property real revealProgress: 1.0

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 20
        color: Theme.surface_container_high
        border.color: Theme.outline_variant
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // ─── Header ───
            Row {
                width: parent.width
                height: 72
                spacing: 14

                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: NightLight.enabled
                        ? Qt.rgba(1, 0.65, 0.2, 0.22)
                        : Theme.surface_variant

                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: NightLight.enabled ? "󰖔" : "󰖕"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                        color: NightLight.enabled ? "#ffb74d" : Theme.on_surface_variant

                        scale: 1.0
                        onTextChanged: iconBounce.restart()
                        SequentialAnimation {
                            id: iconBounce
                            NumberAnimation { target: parent; property: "scale"; to: 1.05; duration: 100; easing.type: Easing.OutCubic }
                            NumberAnimation { target: parent; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                        }

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - 14 - nightToggle.width - 14
                    spacing: 2

                    Text {
                        text: "Night Light"
                        font { family: "Google Sans Medium"; pixelSize: 16 }
                        color: Theme.on_surface
                    }
                    Text {
                        width: parent.width
                        text: NightLight.enabled
                            ? (NightLight.temperature + "K · " + NightLight.intensity + "% intensity")
                            : "Blue light filter is off"
                        font { family: "Google Sans"; pixelSize: 12 }
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: nightToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 28
                    radius: 14
                    color: NightLight.enabled ? "#ffb74d" : Theme.surface_container_highest
                    border.color: NightLight.enabled ? "#ffb74d" : Theme.outline
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Rectangle {
                        width: NightLight.enabled ? 20 : 16
                        height: width
                        radius: width / 2
                        color: NightLight.enabled ? "#3e2723" : Theme.outline
                        anchors.verticalCenter: parent.verticalCenter
                        x: NightLight.enabled ? parent.width - width - 4 : 4

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NightLight.toggle()
                    }
                }
            }

            // ─── Warmth Gradient Preview ───
            Rectangle {
                width: parent.width
                height: 64
                radius: 16
                clip: true

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#1a237e" }
                    GradientStop { position: 0.2; color: "#283593" }
                    GradientStop { position: 0.4; color: "#e65100" }
                    GradientStop { position: 0.6; color: "#ff6d00" }
                    GradientStop { position: 0.8; color: "#ff8f00" }
                    GradientStop { position: 1.0; color: "#ffab00" }
                }

                Rectangle {
                    id: positionIndicator
                    width: 4
                    height: parent.height
                    color: Qt.rgba(1, 1, 1, 0.9)
                    radius: 2
                    x: Math.max(2, Math.min(parent.width - 6, (NightLight.intensity / 100) * parent.width - 2))

                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: -4
                        width: tempBadgeText.width + 16
                        height: 22
                        radius: 11
                        color: Theme.inverse_surface
                        visible: NightLight.enabled

                        Text {
                            id: tempBadgeText
                            anchors.centerIn: parent
                            text: NightLight.temperature + "K"
                            color: Theme.inverse_on_surface
                            font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold }
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Cool"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                    }

                    Item { width: parent.width - 70; height: 1 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Warm"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function apply(mx) {
                        var v = Math.max(0, Math.min(100, Math.round(mx / width * 100)));
                        NightLight.setIntensity(v);
                        if (!NightLight.enabled)
                            NightLight.enable();
                    }

                    onPressed: mouse => apply(mouse.x)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                }
            }

            // ─── Intensity Slider ───
            Item {
                width: parent.width
                height: 56

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Theme.surface_container_highest
                    clip: true

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: Math.max(height, parent.width * Math.min(1, Math.max(0, NightLight.intensity / 100.0)))
                        color: NightLight.enabled ? "#ffb74d" : Theme.surface_variant

                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 14

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰃝"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                            color: NightLight.intensity > 12 && NightLight.enabled
                                ? "#3e2723" : Theme.on_surface

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 56 - percentText.width - parent.spacing * 2
                            height: labelTextNl.implicitHeight

                            Text {
                                id: labelTextNl
                                text: "Intensity"
                                color: NightLight.intensity > 25 && NightLight.enabled
                                    ? "#3e2723" : Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 15; weight: Font.DemiBold }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        Text {
                            id: percentText
                            anchors.verticalCenter: parent.verticalCenter
                            text: NightLight.intensity + "%"
                            font { family: "Google Sans"; pixelSize: 14; weight: Font.Medium }
                            color: NightLight.intensity > 85 && NightLight.enabled
                                ? "#3e2723" : Theme.on_surface
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        function apply(mx) {
                            var v = Math.max(0, Math.min(100, Math.round(mx / width * 100)));
                            NightLight.setIntensity(v);
                            if (!NightLight.enabled)
                                NightLight.enable();
                        }

                        onPressed: mouse => apply(mouse.x)
                        onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                    }
                }
            }

            // ─── Preset Buttons ───
            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        { label: "Subtle", value: 20, icon: "☀️" },
                        { label: "Comfort", value: 45, icon: "🌤️" },
                        { label: "Warm", value: 70, icon: "🌅" },
                        { label: "Deep", value: 95, icon: "🌙" }
                    ]

                    delegate: Rectangle {
                        property bool isActive: NightLight.enabled && Math.abs(NightLight.intensity - modelData.value) <= 5
                        width: (parent.width - 3 * 8) / 4
                        height: 56
                        radius: 14
                        color: isActive
                            ? Qt.rgba(1, 0.72, 0.3, 0.22)
                            : (presetMouse.containsMouse
                                ? Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
                                : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04))
                        border.color: isActive ? "#ffb74d" : "transparent"
                        border.width: isActive ? 1.5 : 0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        scale: presetMouse.pressed ? 0.94 : (presetMouse.containsMouse ? 1.03 : 1)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: 16
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: isActive ? "#ffb74d" : Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                            }
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NightLight.setIntensity(modelData.value);
                                if (!NightLight.enabled)
                                    NightLight.enable();
                            }
                        }
                    }
                }
            }

            // ─── Info Row ───
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 44
                    radius: 14
                    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰔏"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                            color: NightLight.enabled ? "#ffb74d" : Theme.on_surface_variant
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Temperature"
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 0.8 }
                            }
                            Text {
                                text: NightLight.enabled ? (NightLight.temperature + "K") : "6500K"
                                color: Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                            }
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 44
                    radius: 14
                    color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󱩑"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                            color: NightLight.enabled ? "#ffb74d" : Theme.on_surface_variant
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Status"
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 0.8 }
                            }
                            Text {
                                text: NightLight.enabled ? "Active" : "Inactive"
                                color: NightLight.enabled ? "#ffb74d" : Theme.on_surface
                                font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                            }
                        }
                    }
                }
            }
        }
    }
}
