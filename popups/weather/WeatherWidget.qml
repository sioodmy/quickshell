import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.theme

PanelWindow {
    id: root
    property var weatherData: null
    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    WlrLayershell.namespace: "weather_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // --- Helpers ---
    readonly property string _code: weatherData ? weatherData.weatherCode : ""
    readonly property bool isRain: ["176","263","266","293","296","299","302","305","308","353","356","359"].indexOf(_code) >= 0
    readonly property bool isThunder: ["200","386","389","392"].indexOf(_code) >= 0
    readonly property bool isSnow: ["179","227","230","329","332","335","338","371","395"].indexOf(_code) >= 0
    readonly property bool isCloudy: ["119","122"].indexOf(_code) >= 0
    readonly property bool isFog: ["143","248","260"].indexOf(_code) >= 0
    readonly property bool isSunny: _code === "113"
    readonly property bool isPartly: _code === "116"
    readonly property bool isHell: {
        var t = parseInt(root.weatherData ? root.weatherData.temp : "0");
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
        // default / partly cloudy
        return [Qt.rgba(0.09,0.10,0.16,1), Qt.rgba(0.17,0.19,0.30,1)];
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // --- Main Card ---
    Rectangle {
        id: card
        width: 380
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 70
        anchors.leftMargin: 64
        height: cardContent.implicitHeight + 48
        radius: 28
        clip: true

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.weatherGradient()[0] }
            GradientStop { position: 1.0; color: root.weatherGradient()[1] }
        }

        border.color: Qt.rgba(1,1,1,0.06)
        border.width: 1

        // Slide-in animation
        property real animProgress: root.visible ? 1 : 0
        Behavior on animProgress { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        opacity: animProgress
        scale: 0.95 + 0.05 * animProgress
        transformOrigin: Item.TopLeft

        // Swallow clicks
        MouseArea { anchors.fill: parent }

        // ====== ANIMATED WEATHER BACKGROUND ======
        WeatherBackground {
            id: animBg
            anchors.fill: parent
            weatherCode: root._code
            temperature: root.weatherData ? root.weatherData.temp : ""
            visible: root.visible

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
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: root.weatherData ? root.weatherData.location : ""
                        color: Qt.rgba(1,1,1,0.6)
                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                    }

                    Text {
                        text: root.weatherData ? root.weatherData.temp : ""
                        color: "#ffffff"
                        font { family: "Google Sans"; pixelSize: 52; weight: Font.Light }
                    }

                    Text {
                        text: root.weatherData ? root.weatherData.condition : ""
                        color: Qt.rgba(1,1,1,0.75)
                        font { family: "Google Sans"; pixelSize: 14; weight: Font.Normal }
                    }

                    Row {
                        spacing: 16
                        
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "H:" + (root.weatherData ? root.weatherData.maxTemp : "")
                                color: Qt.rgba(1,1,1,0.55)
                                font { family: "Google Sans"; pixelSize: 12 }
                            }
                            Text {
                                text: "L:" + (root.weatherData ? root.weatherData.minTemp : "")
                                color: Qt.rgba(1,1,1,0.55)
                                font { family: "Google Sans"; pixelSize: 12 }
                            }
                        }

                        // --- Moon Phase ---
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter

                            Canvas {
                                id: moonViz
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                property real illPercent: {
                                    if (!root.weatherData || !root.weatherData.moonIllumination) return 50;
                                    var s = root.weatherData.moonIllumination.replace("%", "").trim();
                                    var v = parseFloat(s);
                                    return isNaN(v) ? 50 : v;
                                }

                                property bool isWaxing: {
                                    if (!root.weatherData) return true;
                                    return root.weatherData.moonIsWaxing;
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
                                text: (root.weatherData ? root.weatherData.moonIllumination : "")
                                color: Qt.rgba(1,1,1,0.55)
                                font { family: "Google Sans"; pixelSize: 12 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    text: root.weatherData ? root.weatherData.emoji : ""
                    font.pixelSize: 60
                    opacity: 0.9
                }
            }

            // --- Hourly Forecast ---
            Column {
                width: parent.width
                spacing: 8

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
                            model: root.weatherData ? root.weatherData.hourlyForecast : []

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
                                        text: modelData.day === 0 ? (modelData.hour + ":00") : (modelData.hour + ":00")
                                        color: Qt.rgba(1,1,1,0.55)
                                        font { family: "Google Sans"; pixelSize: 10 }
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
                    text: "3-DAY FORECAST"
                    color: Qt.rgba(1,1,1,0.4)
                    font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1,1,1,0.08)
                }

                Repeater {
                    model: root.weatherData ? root.weatherData.dailyForecast : []

                    delegate: Item {
                        required property var modelData
                        width: parent.width
                        height: 36

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.dayName
                            color: Qt.rgba(1,1,1,0.7)
                            width: 50
                            font { family: "Google Sans"; pixelSize: 13; weight: Font.Medium }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 55
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.emoji
                            font.pixelSize: 18
                        }

                        // Temperature bar
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: modelData.minTemp + "°"
                                color: Qt.rgba(1,1,1,0.4)
                                font { family: "Google Sans"; pixelSize: 12 }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Mini gradient temp bar
                            Rectangle {
                                width: 80
                                height: 4
                                radius: 2
                                color: Qt.rgba(1,1,1,0.08)
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
                                font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // --- Detail Stats Grid ---
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "DETAILS"
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
                        model: root.weatherData ? [
                            { icon: "🌡", label: "Feels like", value: root.weatherData.feelsLike },
                            { icon: "💧", label: "Humidity", value: root.weatherData.humidity },
                            { icon: "💨", label: "Wind", value: root.weatherData.wind },
                            { icon: "☀", label: "UV Index", value: root.weatherData.uv },
                            { icon: "🔽", label: "Pressure", value: root.weatherData.pressure },
                            { icon: "👁", label: "Visibility", value: root.weatherData.visibility },
                            { icon: "🌅", label: "Sunrise", value: root.weatherData.sunrise },
                            { icon: "🌇", label: "Sunset", value: root.weatherData.sunset }
                        ] : []

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
