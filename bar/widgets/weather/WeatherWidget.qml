import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.theme

PanelWindow {
    id: root

    property var weatherData: null

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "weather_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        width: 320
        height: 260
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 70
        anchors.leftMargin: 16
        color: Theme.surface_container_low
        radius: 32

        border.color: Theme.outline_variant
        border.width: 1

        // Swallow clicks on the card so it doesn't dismiss
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // --- Location ---
            Text {
                text: root.weatherData ? root.weatherData.location : "Loading..."
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pixelSize: 16
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // --- Main weather display ---
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Text {
                    text: root.weatherData ? root.weatherData.emoji : ""
                    font.pixelSize: 44
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.weatherData ? root.weatherData.temp : ""
                        color: Theme.on_surface
                        font.family: "Google Sans"
                        font.pixelSize: 28
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.weatherData ? root.weatherData.condition : ""
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        width: 150
                        elide: Text.ElideRight
                    }
                }
            }

            // --- Separator ---
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline_variant
            }

            // --- Detail rows ---
            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 10
                columnSpacing: 16

                Row {
                    spacing: 6
                    Text { text: "🌡️"; font.pixelSize: 13 }
                    Text {
                        text: "Feels " + (root.weatherData ? root.weatherData.feelsLike : "")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 13 }
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "💧"; font.pixelSize: 13 }
                    Text {
                        text: "Humidity " + (root.weatherData ? root.weatherData.humidity : "")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 13 }
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "💨"; font.pixelSize: 13 }
                    Text {
                        text: "Wind " + (root.weatherData ? root.weatherData.wind : "")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 13 }
                    }
                }

                Row {
                    spacing: 6
                    Text { text: "☀️"; font.pixelSize: 13 }
                    Text {
                        text: "UV " + (root.weatherData ? root.weatherData.uv : "")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 13 }
                    }
                }
            }
        }
    }
}
