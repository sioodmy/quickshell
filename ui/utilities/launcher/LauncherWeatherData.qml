import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Item {
    id: root
    width: 0
    height: 0
    visible: false

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell"

    QtObject {
        id: weatherData
        property var source: BackendDaemon.weatherData

        property bool valid: source !== null || cache.temp !== ""
        property string emoji: source ? source.emoji : cache.emoji
        property string temp: source ? source.temp : cache.temp
        property string location: source ? source.location : cache.location
        property string condition: source ? source.condition : cache.condition
        property string weatherCode: source ? source.weather_code : cache.weatherCode
        property string maxTemp: source ? source.max_temp : cache.maxTemp
        property string minTemp: source ? source.min_temp : cache.minTemp
        property string sunrise: source ? source.sunrise : cache.sunrise
        property string sunset: source ? source.sunset : cache.sunset
        property bool moonIsWaxing: source ? source.moon_is_waxing : cache.moonIsWaxing
        property string moonIllumination: source ? source.moon_illumination : cache.moonIllumination
        property string humidity: source ? source.humidity : cache.humidity
        property string wind: source ? source.wind : cache.wind
        property string uv: source ? source.uv : cache.uv
        property string pressure: source ? source.pressure : cache.pressure

        property var dailyForecast: {
            if (source && source.daily_forecast) return source.daily_forecast;
            try { return JSON.parse(cache.dailyForecastJson); } catch (e) { return []; }
        }

        property var hourlyForecast: {
            if (source && source.hourly_forecast) return source.hourly_forecast;
            try { return JSON.parse(cache.hourlyForecastJson); } catch (e) { return []; }
        }

        onSourceChanged: {
            if (!source) return;
            cache.emoji = source.emoji;
            cache.temp = source.temp;
            cache.location = source.location;
            cache.condition = source.condition;
            cache.weatherCode = source.weather_code;
            cache.maxTemp = source.max_temp;
            cache.minTemp = source.min_temp;
            cache.sunrise = source.sunrise;
            cache.sunset = source.sunset;
            cache.moonIsWaxing = source.moon_is_waxing;
            cache.moonIllumination = source.moon_illumination;
            cache.humidity = source.humidity;
            cache.wind = source.wind;
            cache.uv = source.uv;
            cache.pressure = source.pressure;
            cache.dailyForecastJson = JSON.stringify(source.daily_forecast);
            cache.hourlyForecastJson = JSON.stringify(source.hourly_forecast);
            cacheView.writeAdapter();
        }
    }

    FileView {
        id: cacheView
        path: root.cacheDir + "/weather_cache.json"
        printErrors: false

        JsonAdapter {
            id: cache
            property string emoji: ""
            property string temp: ""
            property string location: ""
            property string condition: ""
            property string weatherCode: ""
            property string maxTemp: ""
            property string minTemp: ""
            property string sunrise: ""
            property string sunset: ""
            property bool moonIsWaxing: true
            property string moonIllumination: ""
            property string humidity: ""
            property string wind: ""
            property string uv: ""
            property string pressure: ""
            property string dailyForecastJson: "[]"
            property string hourlyForecastJson: "[]"
        }
    }

    readonly property alias info: weatherData

    readonly property string _code: weatherData.weatherCode
    readonly property string _temp: weatherData.temp
    readonly property bool isRain: ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(_code) >= 0
    readonly property bool isThunder: ["200","386","389","392"].indexOf(_code) >= 0
    readonly property bool isSnow: ["179","227","230","329","332","335","338","371","395"].indexOf(_code) >= 0
    readonly property bool isCloudy: ["119","122"].indexOf(_code) >= 0
    readonly property bool isFog: ["143","248","260"].indexOf(_code) >= 0
    readonly property bool isSunny: _code === "113"
    readonly property bool isPartly: _code === "116"
    readonly property bool isHell: {
        var t = parseInt(_temp);
        return !isNaN(t) && t >= 30;
    }

    readonly property color gradTop: weatherGradient()[0]
    readonly property color gradBottom: weatherGradient()[1]

    property int nowTick: 0

    function parseMinutes(timeStr) {
        if (!timeStr) return 0;
        var parts = timeStr.toString().split(":");
        if (parts.length < 2) return 0;
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    function sunProgress() {
        var now = new Date();
        var currentMins = now.getHours() * 60 + now.getMinutes();
        var rise = parseMinutes(weatherData.sunrise);
        var set = parseMinutes(weatherData.sunset);
        if (!rise && !set) return 0.5;
        if (currentMins < rise) return -0.08;
        if (currentMins > set) return 1.08;
        return (currentMins - rise) / Math.max(1, set - rise);
    }

    readonly property bool isDaytime: {
        var _ = nowTick;
        var p = sunProgress();
        return p >= 0 && p <= 1;
    }

    function weatherGradient() {
        if (isHell)    return [Qt.rgba(0.4, 0.05, 0.05, 1), Qt.rgba(0.2, 0.02, 0.02, 1)];
        if (isThunder) return [Qt.rgba(0.12, 0.10, 0.18, 1), Qt.rgba(0.22, 0.18, 0.32, 1)];
        if (isRain)    return [Qt.rgba(0.10, 0.12, 0.20, 1), Qt.rgba(0.18, 0.22, 0.35, 1)];
        if (isSnow)    return [Qt.rgba(0.15, 0.18, 0.25, 1), Qt.rgba(0.25, 0.28, 0.38, 1)];
        if (isFog)     return [Qt.rgba(0.14, 0.14, 0.18, 1), Qt.rgba(0.22, 0.22, 0.28, 1)];
        if (isCloudy)  return [Qt.rgba(0.11, 0.12, 0.17, 1), Qt.rgba(0.20, 0.22, 0.30, 1)];
        if (isSunny)   return [Qt.rgba(0.08, 0.10, 0.18, 1), Qt.rgba(0.15, 0.18, 0.35, 1)];
        return [Qt.rgba(0.09, 0.10, 0.16, 1), Qt.rgba(0.17, 0.19, 0.30, 1)];
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.nowTick++
    }
}
