import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.theme
import qs.bar.widgets.weather

Item {
    id: root

    visible: weatherData.valid

    implicitWidth: visualPill.implicitWidth
    implicitHeight: visualPill.implicitHeight

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell"

    // Ensure the cache directory exists before the FileView tries to write to it.
    Process {
        running: true
        command: ["mkdir", "-p", root.cacheDir]
    }

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

        // Populate from the on-disk cache so the widget shows data instantly
        // on startup and remains useful while offline.
        function loadFromCache() {
            if (cache.temp === "")
                return;
            emoji = cache.emoji;
            temp = cache.temp;
            location = cache.location;
            condition = cache.condition;
            feelsLike = cache.feelsLike;
            humidity = cache.humidity;
            wind = cache.wind;
            uv = cache.uv;
            valid = true;
        }

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

                            // Persist the fresh data to disk.
                            cache.emoji = emoji;
                            cache.temp = temp;
                            cache.location = location;
                            cache.condition = condition;
                            cache.feelsLike = feelsLike;
                            cache.humidity = humidity;
                            cache.wind = wind;
                            cache.uv = uv;
                            cacheView.writeAdapter();
                        } catch (e) {
                            // Keep any previously cached data on parse errors.
                            console.log("Weather parse error: " + e);
                        }
                    } else {
                        // Network/server error: keep showing cached data.
                        console.log("Weather fetch failed, status: " + xhr.status);
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

    // Periodic refresh (every 10 minutes), and an immediate fetch on startup.
    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherData.updateWeather()
    }

    // On-disk cache for fast loads and offline availability.
    FileView {
        id: cacheView
        path: root.cacheDir + "/weather_cache.json"
        printErrors: false
        onLoaded: weatherData.loadFromCache()

        JsonAdapter {
            id: cache
            property string emoji: ""
            property string temp: ""
            property string location: ""
            property string condition: ""
            property string feelsLike: ""
            property string humidity: ""
            property string wind: ""
            property string uv: ""
        }
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
