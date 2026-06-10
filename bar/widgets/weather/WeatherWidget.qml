import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts

import qs.theme

PanelWindow {
    id: root

    property var weatherData: null

    implicitWidth: 320
    implicitHeight: 220
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    
    margins {
        top: 70
        right: 16
    }

    WlrLayershell.namespace: "weather_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        anchors.fill: parent
        color: Theme.surface_container_low
        radius: 32

        border.color: Theme.outline_variant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                text: root.weatherData ? root.weatherData.location : "Loading..."
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pixelSize: 18
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                Text {
                    text: root.weatherData ? root.weatherData.emoji : ""
                    font.pixelSize: 48
                }

                ColumnLayout {
                    spacing: 4
                    Text {
                        text: root.weatherData ? root.weatherData.temp : ""
                        color: Theme.on_surface
                        font.family: "Google Sans"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.weatherData ? root.weatherData.condition : ""
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        Layout.maximumWidth: 150
                        elide: Text.ElideRight
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                columns: 2
                rowSpacing: 12
                columnSpacing: 24

                // Feels like
                RowLayout {
                    spacing: 8
                    Text {
                        text: "🌡️"
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Feels like: " + (root.weatherData ? root.weatherData.feelsLike : "")
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 14
                    }
                }

                // Humidity
                RowLayout {
                    spacing: 8
                    Text {
                        text: "💧"
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Humidity: " + (root.weatherData ? root.weatherData.humidity : "")
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 14
                    }
                }

                // Wind
                RowLayout {
                    spacing: 8
                    Text {
                        text: "💨"
                        font.pixelSize: 14
                    }
                    Text {
                        text: "Wind: " + (root.weatherData ? root.weatherData.wind : "")
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 14
                    }
                }

                // UV
                RowLayout {
                    spacing: 8
                    Text {
                        text: "☀️"
                        font.pixelSize: 14
                    }
                    Text {
                        text: "UV Index: " + (root.weatherData ? root.weatherData.uv : "")
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
