import QtQuick

Item {
    id: root

    required property var weather
    property real headerReveal: 1.0

    opacity: headerReveal
    scale: 0.96 + 0.04 * headerReveal
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

    Column {
        anchors.left: parent.left
        anchors.right: heroEmoji.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        spacing: 3

        Text {
            text: weather.info.location || "Weather"
            color: Qt.rgba(1, 1, 1, 0.55)
            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.4 }
        }

        Text {
            text: weather.info.valid ? weather.info.temp : "—"
            color: "#ffffff"
            font { family: "Google Sans"; pixelSize: 44; weight: Font.Light }
        }

        Text {
            text: weather.info.condition || (weather.info.valid ? "" : "Loading forecast…")
            color: Qt.rgba(1, 1, 1, 0.78)
            font { family: "Google Sans"; pixelSize: 14 }
        }

        Row {
            spacing: 10
            visible: weather.info.valid
            topPadding: 2

            Text {
                text: "H:" + weather.info.maxTemp
                color: Qt.rgba(1, 1, 1, 0.5)
                font { family: "Google Sans"; pixelSize: 11 }
            }
            Text {
                text: "L:" + weather.info.minTemp
                color: Qt.rgba(1, 1, 1, 0.5)
                font { family: "Google Sans"; pixelSize: 11 }
            }
        }
    }

    Text {
        id: heroEmoji
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        text: weather.info.emoji || "🌤"
        font.pixelSize: 52
        opacity: 0.88

        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: root.visible && root.opacity > 0.5
            NumberAnimation { from: 1.0; to: 1.06; duration: 3200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.06; to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
        }
    }
}
