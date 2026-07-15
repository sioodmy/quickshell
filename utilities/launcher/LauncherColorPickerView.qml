import QtQuick
import QtQuick.Controls
import "../../theme"
import "LauncherColorLogic.js" as ColorLogic

Item {
    id: root

    property real revealProgress: 1.0
    property color defaultColor: Theme.primary
    property string searchQuery: ""

    property real hue: 220
    property real saturation: 0.45
    property real value: 0.85
    property bool syncingFromSearch: false

    readonly property color selectedColor: Qt.hsva(hue / 360, saturation, value, 1)
    readonly property string hexValue: ColorLogic.rgbToHex(
        Math.round(selectedColor.r * 255),
        Math.round(selectedColor.g * 255),
        Math.round(selectedColor.b * 255))
    readonly property string rgbValue: Math.round(selectedColor.r * 255) + ", "
        + Math.round(selectedColor.g * 255) + ", "
        + Math.round(selectedColor.b * 255)

    signal copyRequested(string text, string label)

    property string copyFeedback: ""

    Timer {
        id: copyFeedbackTimer
        interval: 1400
        onTriggered: root.copyFeedback = ""
    }

    function copyColor(text, label) {
        copyFeedback = label + " copied";
        copyFeedbackTimer.restart();
        copyRequested(text, label);
    }

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    function setFromColor(color) {
        if (typeof color === "string") {
            setFromHex(color);
            return;
        }
        var hsv = ColorLogic.rgbToHsv(
            Math.round(color.r * 255),
            Math.round(color.g * 255),
            Math.round(color.b * 255));
        syncingFromSearch = true;
        hue = hsv.h;
        saturation = hsv.s;
        value = hsv.v;
        syncingFromSearch = false;
    }

    function setFromHex(hex) {
        var rgb = ColorLogic.hexToRgb(hex);
        if (!rgb)
            return;
        setFromColor(Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, 1));
    }

    function applySearchQuery(query) {
        var trimmed = (query || "").trim();
        if (ColorLogic.isHexColor(trimmed) || ColorLogic.isRgbColor(trimmed)) {
            var rgb = ColorLogic.parseColorQuery(trimmed);
            if (rgb)
                setFromColor(Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, 1));
        } else if (ColorLogic.isColorPickerQuery(trimmed)) {
            setFromColor(defaultColor);
        }
    }

    onSearchQueryChanged: applySearchQuery(searchQuery)

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.surface_container_high
        border.color: Theme.outline_variant
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Row {
                id: pickerTopRow
                width: parent.width
                height: 168
                spacing: 12

                // Left: header + large preview
                Item {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    Column {
                        id: headerCol
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "COLOR PICKER"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.4 }
                        }

                        Text {
                            text: hexValue
                            color: Theme.on_surface
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 20; weight: Font.Medium }
                        }

                        Text {
                            text: "rgb(" + rgbValue + ")"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pixelSize: 12 }
                        }
                    }

                    Rectangle {
                        id: previewSwatch
                        anchors.top: headerCol.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        radius: 16
                        color: root.selectedColor
                        border.color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.14)
                        border.width: 1
                    }
                }

                // Right: saturation / value spectrum
                Item {
                    id: svPlane
                    width: (pickerTopRow.width - pickerTopRow.spacing) / 2
                    height: parent.height
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.hsva(root.hue / 360, 1, 1, 1)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#000000" }
                        }
                    }

                    Rectangle {
                        id: svCursor
                        width: 22
                        height: 22
                        radius: 11
                        x: Math.max(0, Math.min(svPlane.width - width, root.saturation * svPlane.width - width / 2))
                        y: Math.max(0, Math.min(svPlane.height - height, (1 - root.value) * svPlane.height - height / 2))
                        color: "transparent"
                        border.width: 3
                        border.color: root.value > 0.55 ? "#ffffff" : "#1a1c20"
                        Behavior on x { NumberAnimation { duration: 40 } }
                        Behavior on y { NumberAnimation { duration: 40 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.selectedColor
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.CrossCursor

                        function pick(pos) {
                            root.saturation = Math.max(0, Math.min(1, pos.x / svPlane.width));
                            root.value = Math.max(0, Math.min(1, 1 - pos.y / svPlane.height));
                        }

                        onPressed: function(mouse) { pick(Qt.point(mouse.x, mouse.y)); }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                pick(Qt.point(mouse.x, mouse.y));
                        }
                    }
                }
            }

            // Hue slider
            Item {
                id: hueTrack
                width: parent.width
                height: 22

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    clip: true

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#FF0000" }
                        GradientStop { position: 0.17; color: "#FFFF00" }
                        GradientStop { position: 0.33; color: "#00FF00" }
                        GradientStop { position: 0.50; color: "#00FFFF" }
                        GradientStop { position: 0.67; color: "#0000FF" }
                        GradientStop { position: 0.83; color: "#FF00FF" }
                        GradientStop { position: 1.00; color: "#FF0000" }
                    }
                }

                Rectangle {
                    width: 18
                    height: parent.height + 6
                    radius: 9
                    y: -3
                    x: Math.max(-2, Math.min(hueTrack.width - width + 2, root.hue / 360 * hueTrack.width - width / 2))
                    color: Theme.surface_container_highest
                    border.width: 2
                    border.color: Qt.hsva(root.hue / 360, 1, 1, 1)
                    Behavior on x { NumberAnimation { duration: 40 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor

                    function pick(pos) {
                        root.hue = Math.max(0, Math.min(360, pos.x / hueTrack.width * 360));
                    }

                    onPressed: function(mouse) { pick(Qt.point(mouse.x, mouse.y)); }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            pick(Qt.point(mouse.x, mouse.y));
                    }
                }
            }

            // Preset swatches
            Row {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        Theme.primary, Theme.secondary, Theme.tertiary,
                        Theme.critical, "#FFD700", "#FFFFFF", "#000000"
                    ]
                    delegate: Rectangle {
                        property string swatchHex: typeof modelData === "string"
                            ? (ColorLogic.normalizeHex(modelData) || modelData.toUpperCase())
                            : ColorLogic.colorToHex(modelData)

                        width: (parent.width - 6 * 8) / 7
                        height: 28
                        radius: 8
                        color: modelData
                        border.color: root.hexValue === swatchHex
                            ? Theme.primary : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.1)
                        border.width: root.hexValue === swatchHex ? 2 : 1
                        scale: presetMouse.pressed ? 0.92 : (presetMouse.containsMouse ? 1.06 : 1)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setFromColor(modelData)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10

                ColorValueRow {
                    width: (parent.width - 10) / 2
                    label: "HEX"
                    value: root.hexValue
                    onCopyClicked: root.copyColor(root.hexValue, "HEX")
                }

                ColorValueRow {
                    width: (parent.width - 10) / 2
                    label: "RGB"
                    value: root.rgbValue
                    onCopyClicked: root.copyColor("rgb(" + root.rgbValue + ")", "RGB")
                }
            }
        }
    }

    component ColorValueRow: Rectangle {
        id: valueRow
        height: 44
        radius: 14
        color: Theme.surface_container_highest

        property string label: ""
        property string value: ""
        signal copyClicked()

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 8
            text: valueRow.label
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 1.1 }
        }

        Text {
            anchors.left: rowLabel.left
            anchors.right: copyChip.left
            anchors.rightMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: valueRow.value
            color: Theme.on_surface
            elide: Text.ElideRight
            font {
                family: valueRow.label === "HEX" ? "JetBrainsMono Nerd Font" : "Google Sans"
                pixelSize: 14
                weight: Font.Medium
            }
        }

        Rectangle {
            id: copyChip
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 30
            radius: 15
            color: copyMouse.containsMouse ? Theme.primary : Theme.primary_container

            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    text: "󰆏"
                    color: copyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                }

                Text {
                    text: "Copy"
                    color: copyMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                }
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: valueRow.copyClicked()
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: copyToastText.width + 28
        height: 34
        radius: 17
        color: Theme.inverse_surface
        opacity: root.copyFeedback !== "" ? 1 : 0
        scale: root.copyFeedback !== "" ? 1 : 0.92
        visible: opacity > 0.01
        z: 10

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Text {
            id: copyToastText
            anchors.centerIn: parent
            text: root.copyFeedback
            color: Theme.inverse_on_surface
            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
        }
    }
}
