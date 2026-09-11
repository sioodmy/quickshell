import QtQuick
import QtQuick.Controls
import "../../theme"
import qs.components
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
        radius: 16
        color: Theme.glass_panel
        border.color: Theme.glass_border
        border.width: 1
        clip: true

        // Soft selected-color wash instead of a full banner
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.alpha(root.selectedColor, 0.22)
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                GradientStop {
                    position: 0.45
                    color: Qt.alpha(root.selectedColor, 0.06)
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Hero row — large swatch + values (replaces banner)
            Row {
                width: parent.width
                height: 52
                spacing: 12

                Rectangle {
                    width: 52
                    height: 52
                    radius: 16
                    color: root.selectedColor
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.28)

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    width: parent.width - 52 - 12 - copyHexBtn.width - 8

                    Text {
                        text: "COLOR"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 1.2 }
                    }

                    Text {
                        text: root.hexValue
                        color: Theme.on_surface
                        font { family: "JetBrains Mono"; pixelSize: 18; weight: Font.Medium }
                    }

                    Text {
                        text: "rgb(" + root.rgbValue + ")"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 11 }
                    }
                }

                Rectangle {
                    id: copyHexBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 32
                    radius: 16
                    color: copyHexMouse.containsMouse ? Theme.bubble_accent : Theme.bubble_accent_soft

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIcon {
                            icon: "content_copy"
                            color: Theme.primary
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Copy"
                            color: Theme.primary
                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: copyHexMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyColor(root.hexValue, "HEX")
                    }
                }
            }

            Row {
                id: pickerTopRow
                width: parent.width
                height: 140
                spacing: 10

                // Shade chips
                Flow {
                    id: shadesList
                    width: (parent.width - parent.spacing) * 0.42
                    height: parent.height
                    spacing: 6
                    clip: true

                    Repeater {
                        model: [
                            Qt.hsva(root.hue / 360, root.saturation, 0.15, 1),
                            Qt.hsva(root.hue / 360, root.saturation, 0.35, 1),
                            Qt.hsva(root.hue / 360, root.saturation, 0.55, 1),
                            Qt.hsva(root.hue / 360, root.saturation, 0.75, 1),
                            Qt.hsva(root.hue / 360, root.saturation, 0.9, 1),
                            Qt.hsva(root.hue / 360, root.saturation * 0.7, 1.0, 1),
                            Qt.hsva(root.hue / 360, root.saturation * 0.4, 1.0, 1),
                            Qt.hsva(root.hue / 360, 0.08, 1.0, 1)
                        ]
                        delegate: Rectangle {
                            property color shadeColor: modelData
                            width: (shadesList.width - 2 * 6) / 3
                            height: (shadesList.height - 2 * 6) / 3
                            radius: 8
                            color: shadeColor
                            border.color: String(root.selectedColor) === String(shadeColor) ? Theme.primary : Qt.alpha(Theme.on_surface, 0.14)
                            border.width: String(root.selectedColor) === String(shadeColor) ? 2 : 1

                            MouseArea {
                                id: shadeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setFromColor(shadeColor)
                            }
                            scale: shadeMouse.pressed ? 0.92 : (shadeMouse.containsMouse ? 1.05 : 1)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        }
                    }
                }

                // SV plane
                Item {
                    id: svPlane
                    width: (pickerTopRow.width - pickerTopRow.spacing) * 0.58
                    height: parent.height
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.hsva(root.hue / 360, 1, 1, 1)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#000000" }
                        }
                    }

                    Rectangle {
                        id: svCursor
                        width: 18
                        height: 18
                        radius: 9
                        x: Math.max(0, Math.min(svPlane.width - width, root.saturation * svPlane.width - width / 2))
                        y: Math.max(0, Math.min(svPlane.height - height, (1 - root.value) * svPlane.height - height / 2))
                        color: "transparent"
                        border.width: 2
                        border.color: root.value > 0.55 ? "#ffffff" : "#1a1c20"
                        Behavior on x { NumberAnimation { duration: 40 } }
                        Behavior on y { NumberAnimation { duration: 40 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: root.selectedColor
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
                height: 18

                Rectangle {
                    anchors.fill: parent
                    radius: 9
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
                    width: 16
                    height: parent.height + 4
                    radius: 8
                    y: -2
                    x: Math.max(-2, Math.min(hueTrack.width - width + 2, root.hue / 360 * hueTrack.width - width / 2))
                    color: Theme.glass_raised
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
                spacing: 6

                Repeater {
                    model: [
                        Theme.primary, Theme.secondary, Theme.tertiary,
                        Theme.critical, "#FFD700", "#FFFFFF", "#000000"
                    ]
                    delegate: Rectangle {
                        property string swatchHex: typeof modelData === "string"
                            ? (ColorLogic.normalizeHex(modelData) || modelData.toUpperCase())
                            : ColorLogic.colorToHex(modelData)

                        width: (parent.width - 6 * 6) / 7
                        height: 22
                        radius: 6
                        color: modelData
                        border.color: root.hexValue === swatchHex
                            ? Theme.primary : Qt.alpha(Theme.on_surface, 0.1)
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
                spacing: 8

                ColorValueRow {
                    width: (parent.width - 8) / 2
                    label: "HEX"
                    value: root.hexValue
                    onCopyClicked: root.copyColor(root.hexValue, "HEX")
                }

                ColorValueRow {
                    width: (parent.width - 8) / 2
                    label: "RGB"
                    value: root.rgbValue
                    onCopyClicked: root.copyColor("rgb(" + root.rgbValue + ")", "RGB")
                }
            }
        }
    }

    component ColorValueRow: Rectangle {
        id: valueRow
        height: 36
        radius: 12
        color: Theme.glass_raised
        border.width: 1
        border.color: Theme.glass_border

        property string label: ""
        property string value: ""
        signal copyClicked()

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 5
            text: valueRow.label
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 8; weight: Font.Bold; letterSpacing: 1.0 }
        }

        Text {
            anchors.left: rowLabel.left
            anchors.right: copyChip.left
            anchors.rightMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            text: valueRow.value
            color: Theme.on_surface
            elide: Text.ElideRight
            font {
                family: valueRow.label === "HEX" ? "JetBrains Mono" : "Google Sans"
                pixelSize: 12
                weight: Font.Medium
            }
        }

        Rectangle {
            id: copyChip
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 26
            radius: 13
            color: copyMouse.containsMouse ? Theme.bubble_accent : Theme.bubble_accent_soft

            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "Copy"
                color: Theme.primary
                font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
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
        anchors.bottomMargin: 6
        width: copyToastText.width + 24
        height: 28
        radius: 14
        color: Theme.glass_raised
        border.width: 1
        border.color: Theme.glass_border
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
            color: Theme.on_surface
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
        }
    }
}
