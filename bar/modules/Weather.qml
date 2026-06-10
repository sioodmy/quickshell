import QtQuick
import qs.services
import qs.theme
import "qrc:/qs/bar/widgets/weather" // Wait, I can't use qrc here if it's not a qt resource. I'll just use relative import or "qs.bar.widgets.weather"
// Let's check how calendar does it: Calendar.qml uses `import qs.bar.widgets.calendar`.

import qs.bar.widgets.weather

Item {
    id: root

    // Visible only when weather data is successfully fetched
    visible: weatherData.valid

    implicitWidth: visualPill.implicitWidth
    implicitHeight: visualPill.implicitHeight

    QtObject {
        id: weatherData
        property bool valid: false
        property string emoji: "..."
        property string temp: "..."
        // Properties for widget
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
                            wind = current.windspeedKmph + " km/h";
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
            var codeMap = {
                "113": "☀️", // Clear/Sunny
                "116": "⛅", // Partly cloudy
                "119": "☁️", // Cloudy
                "122": "☁️", // Overcast
                "143": "🌫️", // Mist
                "176": "🌦️", // Patchy rain possible
                "179": "🌨️", // Patchy snow possible
                "182": "🌨️", // Patchy sleet possible
                "185": "🌨️", // Patchy freezing drizzle possible
                "200": "⛈️", // Thundery outbreaks possible
                "227": "🌨️", // Blowing snow
                "230": "❄️", // Blizzard
                "248": "🌫️", // Fog
                "260": "🌫️", // Freezing fog
                "263": "🌧️", // Patchy light drizzle
                "266": "🌧️", // Light drizzle
                "281": "🌧️", // Freezing drizzle
                "284": "🌧️", // Heavy freezing drizzle
                "293": "🌧️", // Patchy light rain
                "296": "🌧️", // Light rain
                "299": "🌧️", // Moderate rain at times
                "302": "🌧️", // Moderate rain
                "305": "🌧️", // Heavy rain at times
                "308": "🌧️", // Heavy rain
                "311": "🌨️", // Light freezing rain
                "314": "🌨️", // Moderate or heavy freezing rain
                "317": "🌨️", // Light sleet
                "320": "🌨️", // Moderate or heavy sleet
                "323": "🌨️", // Patchy light snow
                "326": "🌨️", // Light snow
                "329": "❄️", // Patchy moderate snow
                "332": "❄️", // Moderate snow
                "335": "❄️", // Patchy heavy snow
                "338": "❄️", // Heavy snow
                "350": "🌨️", // Ice pellets
                "353": "🌦️", // Light rain shower
                "356": "🌧️", // Moderate or heavy rain shower
                "359": "🌧️", // Torrential rain shower
                "362": "🌨️", // Light sleet showers
                "365": "🌨️", // Moderate or heavy sleet showers
                "368": "🌨️", // Light snow showers
                "371": "❄️", // Moderate or heavy snow showers
                "374": "🌨️", // Light showers of ice pellets
                "377": "🌨️", // Moderate or heavy showers of ice pellets
                "386": "⛈️", // Patchy light rain with thunder
                "389": "⛈️", // Moderate or heavy rain with thunder
                "392": "⛈️", // Patchy light snow with thunder
                "395": "❄️"  // Moderate or heavy snow with thunder
            };
            return codeMap[code] || "❓";
        }
    }

    Timer {
        interval: 600000 // 10 minutes
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
