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
        property var source: BackendDaemon.weatherData

        property bool valid: source !== null || cache.temp !== ""
        
        property string emoji: source ? source.emoji : cache.emoji
        property string temp: source ? source.temp : cache.temp
        property string location: source ? source.location : cache.location
        property string condition: source ? source.condition : cache.condition
        property string feelsLike: source ? source.feels_like : cache.feelsLike
        property string humidity: source ? source.humidity : cache.humidity
        property string wind: source ? source.wind : cache.wind
        property string uv: source ? source.uv : cache.uv
        property string weatherCode: source ? source.weather_code : cache.weatherCode
        property string pressure: source ? source.pressure : cache.pressure
        property string visibility: source ? source.visibility : cache.visibility
        property string cloudcover: source ? source.cloudcover : cache.cloudcover
        property string precipMM: source ? source.precip_mm : cache.precipMM
        property string windGust: source ? source.wind_gust : cache.windGust
        property string windDir: source ? source.wind_dir : cache.windDir
        property string windDegree: source ? source.wind_degree : cache.windDegree
        property string sunrise: source ? source.sunrise : cache.sunrise
        property string sunset: source ? source.sunset : cache.sunset
        property bool moonIsWaxing: source ? source.moon_is_waxing : cache.moonIsWaxing
        property string moonIllumination: source ? source.moon_illumination : cache.moonIllumination
        property string maxTemp: source ? source.max_temp : cache.maxTemp
        property string minTemp: source ? source.min_temp : cache.minTemp

        property var hourlyForecast: {
            if (source && source.hourly_forecast) return source.hourly_forecast;
            try { return JSON.parse(cache.hourlyForecastJson); } catch(e) { return []; }
        }

        property var dailyForecast: {
            if (source && source.daily_forecast) return source.daily_forecast;
            try { return JSON.parse(cache.dailyForecastJson); } catch(e) { return []; }
        }

        onSourceChanged: {
            if (source) {
                cache.emoji = source.emoji;
                cache.temp = source.temp;
                cache.location = source.location;
                cache.condition = source.condition;
                cache.feelsLike = source.feels_like;
                cache.humidity = source.humidity;
                cache.wind = source.wind;
                cache.uv = source.uv;
                cache.weatherCode = source.weather_code;
                cache.pressure = source.pressure;
                cache.visibility = source.visibility;
                cache.cloudcover = source.cloudcover;
                cache.precipMM = source.precip_mm;
                cache.windGust = source.wind_gust;
                cache.windDir = source.wind_dir;
                cache.windDegree = source.wind_degree;
                cache.sunrise = source.sunrise;
                cache.sunset = source.sunset;
                cache.moonIsWaxing = source.moon_is_waxing;
                cache.moonIllumination = source.moon_illumination;
                cache.maxTemp = source.max_temp;
                cache.minTemp = source.min_temp;
                cache.hourlyForecastJson = JSON.stringify(source.hourly_forecast);
                cache.dailyForecastJson = JSON.stringify(source.daily_forecast);
                cacheView.writeAdapter();
            }
        }

        function loadFromCache() {}

        function updateWeather() {
            BackendDaemon.send({action: "weather_refresh"});
        }

        function getWeatherTint() {
            var c = weatherCode;
            var isRain = ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(c) >= 0;
            var isThunder = ["200","386","389","392"].indexOf(c) >= 0;
            var isSnow = ["179","227","230","329","332","335","338","371","395","182","185","311","314","317","320","323","326","350","362","365","368","374","377"].indexOf(c) >= 0;
            var isFog = ["143","248","260"].indexOf(c) >= 0;
            var isCloudy = ["119","122"].indexOf(c) >= 0;
            var isSunny = c === "113";
            
            var isHell = parseInt(temp) >= 30;
            
            if (isHell)    return Qt.rgba(0.6, 0.1, 0.1, 0.25); // Deep red for hell
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
            property bool moonIsWaxing: true
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
            temperature: weatherData.temp
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
