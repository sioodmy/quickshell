import QtQuick
import QtQuick.Effects
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
        property string weatherCode: ""

        // Extended data
        property string pressure: ""
        property string visibility: ""
        property string cloudcover: ""
        property string precipMM: ""
        property string windGust: ""
        property string windDir: ""
        property string windDegree: ""

        // Astronomy
        property string sunrise: ""
        property string sunset: ""
        property string moonPhase: ""
        property string moonIllumination: ""

        // Daily summary for today
        property string maxTemp: ""
        property string minTemp: ""

        // Hourly forecast (list of objects)
        property var hourlyForecast: []

        // Daily forecast (list of objects for 3 days)
        property var dailyForecast: []

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
            weatherCode = cache.weatherCode;
            pressure = cache.pressure;
            visibility = cache.visibility;
            cloudcover = cache.cloudcover;
            precipMM = cache.precipMM;
            windGust = cache.windGust;
            windDir = cache.windDir;
            windDegree = cache.windDegree;
            sunrise = cache.sunrise;
            sunset = cache.sunset;
            moonPhase = cache.moonPhase;
            moonIllumination = cache.moonIllumination;
            maxTemp = cache.maxTemp;
            minTemp = cache.minTemp;

            try {
                hourlyForecast = JSON.parse(cache.hourlyForecastJson);
            } catch(e) { hourlyForecast = []; }
            try {
                dailyForecast = JSON.parse(cache.dailyForecastJson);
            } catch(e) { dailyForecast = []; }

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
                            var today = response.weather[0];
                            var astro = today.astronomy[0];

                            emoji = getWeatherEmoji(current.weatherCode);
                            temp = current.temp_C + "°C";
                            location = area.areaName[0].value + ", " + area.country[0].value;
                            condition = current.weatherDesc[0].value;
                            feelsLike = current.FeelsLikeC + "°C";
                            humidity = current.humidity + "%";
                            wind = current.windspeedKmph + " km/h " + current.winddir16Point;
                            uv = current.uvIndex;
                            weatherCode = current.weatherCode;

                            // Extended
                            pressure = current.pressure + " hPa";
                            visibility = current.visibility + " km";
                            cloudcover = current.cloudcover + "%";
                            precipMM = current.precipMM + " mm";
                            var gust = current.WindGustKmph || "";
                            windGust = gust ? gust + " km/h" : "";
                            windDir = current.winddir16Point;
                            windDegree = current.winddirDegree;

                            // Astronomy
                            sunrise = astro.sunrise;
                            sunset = astro.sunset;
                            moonPhase = astro.moon_phase;
                            moonIllumination = astro.moon_illumination + "%";

                            // Daily
                            maxTemp = today.maxtempC + "°";
                            minTemp = today.mintempC + "°";

                            // Parse hourly forecast (today's remaining + tomorrow's)
                            var hourly = [];
                            for (var d = 0; d < response.weather.length && d < 2; d++) {
                                var dayData = response.weather[d];
                                for (var h = 0; h < dayData.hourly.length; h++) {
                                    var hr = dayData.hourly[h];
                                    var hourNum = parseInt(hr.time) / 100;
                                    hourly.push({
                                        hour: hourNum,
                                        temp: hr.tempC,
                                        emoji: getWeatherEmoji(hr.weatherCode),
                                        condition: hr.weatherDesc[0].value.trim(),
                                        chanceOfRain: hr.chanceofrain,
                                        day: d,
                                        humidity: hr.humidity,
                                        wind: hr.windspeedKmph
                                    });
                                }
                            }
                            hourlyForecast = hourly;

                            // Parse daily forecast (3 days)
                            var daily = [];
                            var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                            for (var i = 0; i < response.weather.length; i++) {
                                var wd = response.weather[i];
                                var dateObj = new Date(wd.date);
                                // Pick mid-day weather code for representative emoji
                                var midHourly = wd.hourly[Math.floor(wd.hourly.length / 2)];
                                daily.push({
                                    dayName: i === 0 ? "Today" : dayNames[dateObj.getDay()],
                                    date: wd.date,
                                    maxTemp: wd.maxtempC,
                                    minTemp: wd.mintempC,
                                    emoji: getWeatherEmoji(midHourly.weatherCode),
                                    condition: midHourly.weatherDesc[0].value.trim(),
                                    sunrise: wd.astronomy[0].sunrise,
                                    sunset: wd.astronomy[0].sunset
                                });
                            }
                            dailyForecast = daily;

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
                            cache.weatherCode = weatherCode;
                            cache.pressure = pressure;
                            cache.visibility = visibility;
                            cache.cloudcover = cloudcover;
                            cache.precipMM = precipMM;
                            cache.windGust = windGust;
                            cache.windDir = windDir;
                            cache.windDegree = windDegree;
                            cache.sunrise = sunrise;
                            cache.sunset = sunset;
                            cache.moonPhase = moonPhase;
                            cache.moonIllumination = moonIllumination;
                            cache.maxTemp = maxTemp;
                            cache.minTemp = minTemp;
                            cache.hourlyForecastJson = JSON.stringify(hourlyForecast);
                            cache.dailyForecastJson = JSON.stringify(dailyForecast);
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

        function getWeatherTint() {
            var c = weatherCode;
            var isRain = ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(c) >= 0;
            var isThunder = ["200","386","389","392"].indexOf(c) >= 0;
            var isSnow = ["179","227","230","329","332","335","338","371","395","182","185","311","314","317","320","323","326","350","362","365","368","374","377"].indexOf(c) >= 0;
            var isFog = ["143","248","260"].indexOf(c) >= 0;
            var isCloudy = ["119","122"].indexOf(c) >= 0;
            var isSunny = c === "113";
            
            if (isThunder) return Qt.rgba(0.15, 0.10, 0.35, 0.18); // deep purple-blue
            if (isRain)    return Qt.rgba(0.10, 0.20, 0.50, 0.18); // dark indigo-blue
            if (isSnow)    return Qt.rgba(0.15, 0.35, 0.60, 0.18); // dark azure blue
            if (isFog)     return Qt.rgba(0.15, 0.20, 0.30, 0.18); // dark slate blue
            if (isCloudy)  return Qt.rgba(0.12, 0.15, 0.35, 0.18); // deep navy blue
            if (isSunny)   return Qt.rgba(0.25, 0.30, 0.50, 0.15); // rich dark blue with hint of warmth
            return Qt.rgba(0.15, 0.20, 0.40, 0.15); // partly cloudy (dark blue)
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
            property string weatherCode: ""
            property string pressure: ""
            property string visibility: ""
            property string cloudcover: ""
            property string precipMM: ""
            property string windGust: ""
            property string windDir: ""
            property string windDegree: ""
            property string sunrise: ""
            property string sunset: ""
            property string moonPhase: ""
            property string moonIllumination: ""
            property string maxTemp: ""
            property string minTemp: ""
            property string hourlyForecastJson: "[]"
            property string dailyForecastJson: "[]"
        }
    }

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: weatherLabel.implicitWidth + 32
        implicitHeight: 28
        radius: height / 2

        color: {
            var baseColor = Qt.tint(Theme.surface_container, weatherData.getWeatherTint());
            if (weatherWidget.visible)
                return Qt.tint(baseColor, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12));
            if (pillMouse.containsMouse)
                return Qt.tint(baseColor, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08));
            return baseColor;
        }

        scale: pillMouse.pressed ? 0.95 : 1.0

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        WeatherBackground {
            anchors.fill: parent
            weatherCode: weatherData.weatherCode
            miniMode: true
            opacity: 0.9

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    hideSource: true
                    sourceItem: Rectangle {
                        width: visualPill.width
                        height: visualPill.height
                        radius: visualPill.radius
                        visible: false
                    }
                }
            }
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
