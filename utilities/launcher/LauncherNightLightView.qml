import QtQuick
import QtQuick.Effects
import "../../theme"
import qs.services
import qs.components

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
        color: Theme.glass_panel
        border.color: Theme.glass_border
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ─── Header ───
            Row {
                width: parent.width
                height: 56
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    color: NightLight.enabled
                        ? Qt.rgba(1, 0.65, 0.2, 0.22)
                        : Theme.glass_raised

                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: NightLight.enabled ? "bedtime" : "light_mode"
                        font.pixelSize: 20
                        color: NightLight.enabled ? "#ffb74d" : Theme.on_surface_variant

                        scale: 1.0
                        onIconChanged: iconBounce.restart()
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
                    width: parent.width - 44 - 12 - nightToggle.width - 12
                    spacing: 2

                    Text {
                        text: "Night Light"
                        font { family: "Google Sans Medium"; pixelSize: 15 }
                        color: Theme.on_surface
                    }
                    Text {
                        width: parent.width
                        text: NightLight.enabled
                            ? (NightLight.temperature + "K · " + NightLight.intensity + "%")
                            : "Blue light filter is off"
                        font { family: "Google Sans"; pixelSize: 11 }
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
                    color: NightLight.enabled ? Qt.alpha("#ffb74d", 0.7) : Theme.glass_raised
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
                height: 48
                radius: 12
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
                        color: Theme.glass_raised
                        border.width: 1
                        border.color: Theme.glass_border
                        visible: NightLight.enabled

                        Text {
                            id: tempBadgeText
                            anchors.centerIn: parent
                            text: NightLight.temperature + "K"
                            color: Theme.on_surface
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
                                ? Theme.glass_hover
                                : Theme.glass_raised)
                        border.color: isActive ? "#ffb74d" : Theme.glass_border
                        border.width: isActive ? 1.5 : 1

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
                    color: Theme.glass_raised
                    border.width: 1
                    border.color: Theme.glass_border

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "device_thermostat"
                            font.pixelSize: 16
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
                    color: Theme.glass_raised
                    border.width: 1
                    border.color: Theme.glass_border

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        spacing: 8

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "wb_sunny"
                            font.pixelSize: 16
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
