import QtQuick
import qs.services
import qs.theme
import qs.bar.widgets.weather

Item {
    id: root

    visible: weatherData.valid

    implicitWidth: visualPill.implicitWidth
    implicitHeight: visualPill.implicitHeight

    QtObject {
        id: weatherData
        property bool valid: false
        property string emoji: ""
        property string temp: ""
        property string location: ""
        property string condition: ""
        property string feelsLike: ""
        property string humidity: ""
        property string wind: ""
        property string uv: ""

        function updateWeather() {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "https://wttr.in/?format=j1");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var response = JSON.parse(xhr.responseText);
                            var current = response.current_condition[0];
                            var area = response.nearest_area[0];

                            emoji = getWeatherEmoji(current.weatherCode);
                            temp = current.temp_C + "°C";
                            location = area.areaName[0].value + ", " + area.country[0].value;
                            condition = current.weatherDesc[0].value;
                            feelsLike = current.FeelsLikeC + "°C";
                            humidity = current.humidity + "%";
                            wind = current.windspeedKmph + " km/h " + current.winddir16Point;
                            uv = current.uvIndex;

                            valid = true;
                        } catch (e) {
                            valid = false;
                            console.log("Weather parse error: " + e);
                        }
                    } else {
                        valid = false;
                    }
                }
            };
            xhr.send();
        }

        function getWeatherEmoji(code) {
            var c = {
                "113": "☀️",
                "116": "⛅",
                "119": "☁️",
                "122": "☁️",
                "143": "🌫️",
                "176": "🌦️",
                "179": "🌨️",
                "182": "🌨️",
                "185": "🌨️",
                "200": "⛈️",
                "227": "🌨️",
                "230": "❄️",
                "248": "🌫️",
                "260": "🌫️",
                "263": "🌧️",
                "266": "🌧️",
                "281": "🌧️",
                "284": "🌧️",
                "293": "🌧️",
                "296": "🌧️",
                "299": "🌧️",
                "302": "🌧️",
                "305": "🌧️",
                "308": "🌧️",
                "311": "🌨️",
                "314": "🌨️",
                "317": "🌨️",
                "320": "🌨️",
                "323": "🌨️",
                "326": "🌨️",
                "329": "❄️",
                "332": "❄️",
                "335": "❄️",
                "338": "❄️",
                "350": "🌨️",
                "353": "🌦️",
                "356": "🌧️",
                "359": "🌧️",
                "362": "🌨️",
                "365": "🌨️",
                "368": "🌨️",
                "371": "❄️",
                "374": "🌨️",
                "377": "🌨️",
                "386": "⛈️",
                "389": "⛈️",
                "392": "⛈️",
                "395": "❄️"
            };
            return c[code] || "❓";
        }
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherData.updateWeather()
    }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: weatherLabel.implicitWidth + 32
        implicitHeight: 28
        radius: height / 2

        color: {
            if (weatherWidget.visible)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12));
            if (pillMouse.containsMouse)
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08));
            return Theme.surface_container;
        }

        scale: pillMouse.pressed ? 0.95 : 1.0

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: weatherWidget.visible = !weatherWidget.visible
        }

        Text {
            id: weatherLabel
            anchors.centerIn: parent
            text: weatherData.emoji + "  " + weatherData.temp
            color: Theme.on_surface
            font {
                family: "Google Sans"
                pixelSize: 14
                weight: Font.Medium
            }
        }
    }

    WeatherWidget {
        id: weatherWidget
        visible: false
        weatherData: weatherData
    }
}
