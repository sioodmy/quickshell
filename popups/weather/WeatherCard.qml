import QtQuick
import QtQuick.Effects
import qs.theme

Rectangle {
    id: card
    property var weatherData: null
    property int selectedDayIndex: -1
    property var selectedDay: selectedDayIndex !== -1 && weatherData && weatherData.dailyForecast ? weatherData.dailyForecast[selectedDayIndex] : null

    // Optional animation properties
    property real animProgress: 1.0
    property bool animActive: true

    width: 380
    height: cardContent.implicitHeight + 48
    radius: 28
    clip: true

    // --- Helpers ---
    readonly property string _code: card.selectedDay && card.selectedDay.weatherCode ? card.selectedDay.weatherCode : (weatherData ? weatherData.weatherCode : "")
    readonly property string _temp: card.selectedDay ? card.selectedDay.maxTemp : (weatherData ? weatherData.temp : "")
    readonly property bool isRain: ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(_code) >= 0
    readonly property bool isThunder: ["200","386","389","392"].indexOf(_code) >= 0
    readonly property bool isSnow: ["179","227","230","329","332","335","338","371","395"].indexOf(_code) >= 0
    readonly property bool isCloudy: ["119","122"].indexOf(_code) >= 0
    readonly property bool isFog: ["143","248","260"].indexOf(_code) >= 0
    readonly property bool isSunny: _code === "113"
    readonly property bool isPartly: _code === "116"
    readonly property bool isHell: {
        var t = parseInt(card._temp);
        return !isNaN(t) && t >= 30;
    }

    function weatherGradient() {
        if (isHell)    return [Qt.rgba(0.4, 0.05, 0.05, 1), Qt.rgba(0.2, 0.02, 0.02, 1)];
        if (isThunder) return [Qt.rgba(0.12,0.10,0.18,1), Qt.rgba(0.22,0.18,0.32,1)];
        if (isRain)    return [Qt.rgba(0.10,0.12,0.20,1), Qt.rgba(0.18,0.22,0.35,1)];
        if (isSnow)    return [Qt.rgba(0.15,0.18,0.25,1), Qt.rgba(0.25,0.28,0.38,1)];
        if (isFog)     return [Qt.rgba(0.14,0.14,0.18,1), Qt.rgba(0.22,0.22,0.28,1)];
        if (isCloudy)  return [Qt.rgba(0.11,0.12,0.17,1), Qt.rgba(0.20,0.22,0.30,1)];
        if (isSunny)   return [Qt.rgba(0.08,0.10,0.18,1), Qt.rgba(0.15,0.18,0.35,1)];
        return [Qt.rgba(0.09,0.10,0.16,1), Qt.rgba(0.17,0.19,0.30,1)];
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: card.weatherGradient()[0] }
        GradientStop { position: 1.0; color: card.weatherGradient()[1] }
    }

    border.color: Qt.rgba(1,1,1,0.06)
    border.width: 1

    opacity: animProgress
    scale: 0.95 + 0.05 * animProgress
    transformOrigin: Item.TopLeft

    // Swallow clicks
    MouseArea { anchors.fill: parent }

    // ====== ANIMATED WEATHER BACKGROUND ======
    WeatherBackground {
        id: animBg
        anchors.fill: parent
        weatherCode: card._code
        temperature: card._temp
        visible: card.animActive

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ShaderEffectSource {
                hideSource: true
                sourceItem: Rectangle {
                    width: animBg.width
                    height: animBg.height
                    radius: card.radius
                    visible: false
                }
            }
        }
    }
        // ====== CONTENT ======
        Column {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 20

            // --- Hero Section ---
            Item {
                width: parent.width
                height: 130

                Column {
                    anchors.left: parent.left
                    anchors.right: heroEmoji.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Location — always visible
                    Text {
                        text: card.weatherData ? card.weatherData.location : ""
                        color: Qt.rgba(1,1,1,0.5)
                        font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                    }

                    // Selected day label
                    Text {
                        visible: card.selectedDay !== null
                        text: card.selectedDay ? (card.selectedDay.dayName + "  ·  " + card.selectedDay.date) : ""
                        color: Qt.rgba(1,1,1,0.7)
                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.3 }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // Temperature
                    Text {
                        text: card.selectedDay
                              ? (card.selectedDay.maxTemp + "°/" + card.selectedDay.minTemp + "°")
                              : (card.weatherData ? card.weatherData.temp : "")
                        color: "#ffffff"
                        font { family: "Google Sans"; pixelSize: 48; weight: Font.Light }
                    }

                    // Condition
                    Text {
                        text: card.selectedDay ? card.selectedDay.condition : (card.weatherData ? card.weatherData.condition : "")
                        color: Qt.rgba(1,1,1,0.75)
                        font { family: "Google Sans"; pixelSize: 14; weight: Font.Normal }
                    }

                    // Sub-stats row
                    Row {
                        spacing: 12
                        topPadding: 2

                        // H/L for current
                        Row {
                            spacing: 6
                            visible: card.selectedDay === null
                            Text {
                                text: "H:" + (card.weatherData ? card.weatherData.maxTemp : "")
                                color: Qt.rgba(1,1,1,0.5)
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                            Text {
                                text: "L:" + (card.weatherData ? card.weatherData.minTemp : "")
                                color: Qt.rgba(1,1,1,0.5)
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }

                        // Rain chance for selected day
                        Row {
                            spacing: 4
                            visible: card.selectedDay !== null && parseInt(card.selectedDay ? card.selectedDay.chanceOfRain : "0") > 0
                            Text {
                                text: "🌧"
                                font.pixelSize: 11
                            }
                            Text {
                                text: (card.selectedDay ? card.selectedDay.chanceOfRain : "") + "%"
                                color: "#7cacf8"
                                font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                            }
                        }

                        // Wind for selected day
                        Row {
                            spacing: 4
                            visible: card.selectedDay !== null
                            Text {
                                text: "💨"
                                font.pixelSize: 11
                            }
                            Text {
                                text: card.selectedDay ? card.selectedDay.wind : ""
                                color: Qt.rgba(1,1,1,0.5)
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }

                        // --- Moon Phase ---
                        Row {
                            spacing: 6
                            visible: card.selectedDay === null

                            Canvas {
                                id: moonViz
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter

                                property real illPercent: {
                                    if (!card.weatherData || !card.weatherData.moonIllumination) return 50;
                                    var s = card.weatherData.moonIllumination.replace("%", "").trim();
                                    var v = parseFloat(s);
                                    return isNaN(v) ? 50 : v;
                                }

                                property bool isWaxing: {
                                    if (!card.weatherData) return true;
                                    return card.weatherData.moonIsWaxing;
                                }
                                
                                onIllPercentChanged: requestPaint()
                                onIsWaxingChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    var cx = width / 2;
                                    var cy = height / 2;
                                    var r = width / 2;

                                    // 1. Dark moon base
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12);
                                    ctx.fill();

                                    // 2. Terminator math
                                    var p = illPercent / 100.0;
                                    var w = Math.abs(p - 0.5) * 2 * r;

                                    // 3. Draw bright primary half
                                    ctx.save();
                                    ctx.beginPath();
                                    if (isWaxing) {
                                        ctx.rect(cx, cy - r, r, r * 2);
                                    } else {
                                        ctx.rect(cx - r, cy - r, r, r * 2);
                                    }
                                    ctx.clip();

                                    if (p < 0.5) {
                                        // Crescent
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
                                        ctx.fill();

                                        ctx.globalCompositeOperation = "destination-out";
                                        ctx.beginPath();
                                        ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
                                        ctx.fillStyle = Qt.rgba(0, 0, 0, 1);
                                        ctx.fill();
                                        
                                        ctx.globalCompositeOperation = "source-over";
                                        ctx.beginPath();
                                        ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
                                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12);
                                        ctx.fill();
                                    } else {
                                        // Gibbous
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
                                        ctx.fill();
                                    }
                                    ctx.restore();

                                    // 4. Draw gibbous overflow
                                    if (p >= 0.5) {
                                        ctx.save();
                                        ctx.beginPath();
                                        if (isWaxing) {
                                            ctx.rect(cx - r, cy - r, r, r * 2);
                                        } else {
                                            ctx.rect(cx, cy - r, r, r * 2);
                                        }
                                        ctx.clip();
                                        
                                        ctx.beginPath();
                                        ctx.ellipse(cx - w, cy - r, w * 2, r * 2);
                                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.95);
                                        ctx.fill();
                                        ctx.restore();
                                    }

                                    // 5. Subtle Craters
                                    ctx.fillStyle = Qt.rgba(0, 0, 0, 0.15);
                                    ctx.beginPath(); ctx.arc(cx - 3, cy - 3, 1.5, 0, Math.PI*2); ctx.fill();
                                    ctx.beginPath(); ctx.arc(cx + 3, cy + 2, 2, 0, Math.PI*2); ctx.fill();
                                    ctx.beginPath(); ctx.arc(cx - 1, cy + 4, 1, 0, Math.PI*2); ctx.fill();
                                }
                            }

                            Text {
                                text: (card.weatherData ? card.weatherData.moonIllumination : "")
                                color: Qt.rgba(1,1,1,0.5)
                                font { family: "Google Sans"; pixelSize: 11 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Text {
                    id: heroEmoji
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    text: card.selectedDay ? card.selectedDay.emoji : (card.weatherData ? card.weatherData.emoji : "")
                    font.pixelSize: 56
                    opacity: 0.85
                }
            }

            // --- Hourly Forecast ---
            Column {
                width: parent.width
                spacing: 8
                visible: card.selectedDayIndex <= 0
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    text: "HOURLY FORECAST"
                    color: Qt.rgba(1,1,1,0.4)
                    font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1,1,1,0.08)
                }

                Flickable {
                    width: parent.width
                    height: 90
                    contentWidth: hourlyRow.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: hourlyRow
                        spacing: 4

                        Repeater {
                            model: card.weatherData ? card.weatherData.hourlyForecast : []

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: 52
                                height: 86
                                radius: 20
                                color: index === 0 ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.04)
                                border.color: index === 0 ? Qt.rgba(1,1,1,0.15) : "transparent"
                                border.width: index === 0 ? 1 : 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: index === 0 ? "Now" : (modelData.hour + ":00")
                                        color: Qt.rgba(1,1,1, index === 0 ? 0.8 : 0.55)
                                        font { family: "Google Sans"; pixelSize: 10; weight: index === 0 ? Font.Bold : Font.Normal }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.emoji
                                        font.pixelSize: 20
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.temp + "°"
                                        color: "#ffffff"
                                        font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                    }
                                    // Rain chance indicator
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: parseInt(modelData.chanceOfRain) > 20 ? modelData.chanceOfRain + "%" : ""
                                        color: "#7cacf8"
                                        font { family: "Google Sans"; pixelSize: 9 }
                                        visible: text !== ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Daily Forecast ---
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "7-DAY FORECAST"
                    color: Qt.rgba(1,1,1,0.4)
                    font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1,1,1,0.08)
                }

                // Scrollable daily list — shows ~3.5 rows, scroll for rest
                Flickable {
                    width: parent.width
                    height: Math.min(dailyCol.height, 36 * 3 + 8 * 2 + 10) // 3 rows + spacing + peek
                    contentHeight: dailyCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: dailyCol.height > height

                    Column {
                        id: dailyCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: card.weatherData ? card.weatherData.dailyForecast : []

                            delegate: Rectangle {
                                id: dayDelegate
                                required property var modelData
                                required property int index
                                width: dailyCol.width
                                height: 38
                                radius: 10
                                color: {
                                    if (card.selectedDayIndex === index) return Qt.rgba(1,1,1,0.1);
                                    if (dayMa.containsMouse) return Qt.rgba(1,1,1,0.05);
                                    return "transparent";
                                }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: dayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        card.selectedDayIndex = (card.selectedDayIndex === index) ? -1 : index;
                                    }
                                }

                                // Selection indicator bar
                                Rectangle {
                                    width: 3
                                    height: 18
                                    radius: 1.5
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#7cacf8"
                                    visible: card.selectedDayIndex === index
                                    opacity: card.selectedDayIndex === index ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.dayName
                                    color: card.selectedDayIndex === index ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.7)
                                    width: 44
                                    font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 60
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.emoji
                                    font.pixelSize: 16
                                }

                                // Rain chance pill
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 82
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: rainText.width + 10
                                    height: 16
                                    radius: 8
                                    color: Qt.rgba(0.48, 0.67, 0.97, 0.15)
                                    visible: parseInt(modelData.chanceOfRain) > 10

                                    Text {
                                        id: rainText
                                        anchors.centerIn: parent
                                        text: modelData.chanceOfRain + "%"
                                        color: "#7cacf8"
                                        font { family: "Google Sans"; pixelSize: 9; weight: Font.Medium }
                                    }
                                }

                                // Temperature bar
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: modelData.minTemp + "°"
                                        color: Qt.rgba(1,1,1,0.4)
                                        font { family: "Google Sans"; pixelSize: 11 }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Mini gradient temp bar
                                    Rectangle {
                                        width: 60
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(1,1,1,0.06)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            height: parent.height
                                            radius: 2
                                            x: {
                                                var minAll = 0, maxAll = 40;
                                                return Math.max(0, (parseInt(modelData.minTemp) - minAll) / (maxAll - minAll)) * parent.width;
                                            }
                                            width: {
                                                var minAll = 0, maxAll = 40;
                                                var start = Math.max(0, (parseInt(modelData.minTemp) - minAll) / (maxAll - minAll));
                                                var end = Math.min(1, (parseInt(modelData.maxTemp) - minAll) / (maxAll - minAll));
                                                return Math.max(4, (end - start) * parent.width);
                                            }
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: "#5b8def" }
                                                GradientStop { position: 1; color: "#f0a050" }
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.maxTemp + "°"
                                        color: Qt.rgba(1,1,1,0.8)
                                        font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Scroll hint
                Rectangle {
                    width: 32
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1,1,1,0.15)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: dailyCol.height > (36 * 3 + 8 * 2 + 10)
                }
            }

            // --- Detail Stats Grid ---
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: card.selectedDay ? "FORECAST DETAILS" : "DETAILS"
                    color: Qt.rgba(1,1,1,0.4)
                    font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1,1,1,0.08)
                }

                Grid {
                    width: parent.width
                    columns: 2
                    rowSpacing: 6
                    columnSpacing: 8

                    Repeater {
                        model: card.weatherData ? (
                            card.selectedDay ? [
                                { icon: "🌧", label: "Rain chance", value: card.selectedDay.chanceOfRain + "%" },
                                { icon: "💨", label: "Wind", value: card.selectedDay.wind },
                                { icon: "☀", label: "UV Index", value: card.selectedDay.uv },
                                { icon: "☁", label: "Condition", value: card.selectedDay.condition },
                                { icon: "🌅", label: "Sunrise", value: card.selectedDay.sunrise },
                                { icon: "🌇", label: "Sunset", value: card.selectedDay.sunset }
                            ] : [
                                { icon: "🌡", label: "Feels like", value: card.weatherData.feelsLike },
                                { icon: "💧", label: "Humidity", value: card.weatherData.humidity },
                                { icon: "💨", label: "Wind", value: card.weatherData.wind },
                                { icon: "☀", label: "UV Index", value: card.weatherData.uv },
                                { icon: "🔽", label: "Pressure", value: card.weatherData.pressure },
                                { icon: "👁", label: "Visibility", value: card.weatherData.visibility },
                                { icon: "🌅", label: "Sunrise", value: card.weatherData.sunrise },
                                { icon: "🌇", label: "Sunset", value: card.weatherData.sunset }
                            ]
                        ) : []

                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 8) / 2
                            height: 48
                            radius: 14
                            color: Qt.rgba(1,1,1,0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: modelData.label
                                        color: Qt.rgba(1,1,1,0.4)
                                        font { family: "Google Sans"; pixelSize: 10 }
                                    }
                                    Text {
                                        text: modelData.value
                                        color: Qt.rgba(1,1,1,0.85)
                                        font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                                    }
                                }
                            }
                        }
                    }
                }
            }


            Item { width: 1; height: 4 }
}
        }
    }
}
