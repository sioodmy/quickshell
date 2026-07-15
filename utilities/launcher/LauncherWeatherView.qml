import QtQuick

Item {
    id: root

    required property var weather
    property real revealProgress: 1.0

    readonly property real celestialSize: 16

    function windParts(raw) {
        var parts = (raw || "").trim().split(/\s+/);
        if (parts.length >= 3)
            return { speed: parts[0] + " " + parts[1], dir: parts[2] };
        if (parts.length === 2)
            return { speed: parts[0] + " " + parts[1], dir: "" };
        return { speed: raw || "—", dir: "" };
    }

    function pressureParts(raw) {
        if (!raw) return { value: "—", unit: "" };
        var s = raw.toString().trim();
        if (s.indexOf("hPa") >= 0)
            return { value: s.replace("hPa", "").trim(), unit: "hPa" };
        return { value: s, unit: "" };
    }

    readonly property var statTiles: [
        { icon: "💧", label: "Humidity", value: weather.info.humidity || "—", detail: "" },
        { icon: "☀️", label: "UV Index", value: weather.info.uv || "—", detail: "" },
        { icon: "💨", label: "Wind", value: windParts(weather.info.wind).speed, detail: windParts(weather.info.wind).dir },
        { icon: "🌀", label: "Pressure", value: pressureParts(weather.info.pressure).value, detail: pressureParts(weather.info.pressure).unit }
    ]

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    Rectangle {
        id: weatherSurface
        anchors.fill: parent
        radius: 20
        clip: true

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: weather.gradBottom
                Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            }
            GradientStop {
                position: 1.0
                color: weather.gradTop
                Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            }
        }

        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "HOURLY"
                    color: Qt.rgba(1, 1, 1, 0.38)
                    font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.4 }
                }

                Flickable {
                    width: parent.width
                    height: 68
                    contentWidth: hourlyRow.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: hourlyRow
                        spacing: 6

                        Repeater {
                            model: {
                                var hours = weather.info.hourlyForecast || [];
                                return hours.slice(0, Math.min(12, hours.length));
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                opacity: root.revealProgress
                                scale: 0.94 + 0.06 * root.revealProgress

                                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }

                                width: 48
                                height: 66
                                radius: 14
                                color: index === 0
                                       ? Qt.rgba(1, 1, 1, 0.16)
                                       : Qt.rgba(1, 1, 1, 0.07)
                                border.color: index === 0 ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: index === 0 ? "Now" : (modelData.hour + ":00")
                                        color: Qt.rgba(1, 1, 1, index === 0 ? 0.92 : 0.58)
                                        font { family: "Google Sans"; pixelSize: 9; weight: index === 0 ? Font.Bold : Font.Normal }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.emoji || ""
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: (modelData.temp || "—") + "°"
                                        color: "#ffffff"
                                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: parseInt(modelData.chanceOfRain || "0") > 20 ? modelData.chanceOfRain + "%" : ""
                                        color: "#9ec5ff"
                                        font { family: "Google Sans"; pixelSize: 8 }
                                        visible: text !== ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // M3-style detail tiles
            Row {
                id: statsRow
                width: parent.width
                spacing: 8

                Repeater {
                    model: root.statTiles

                    delegate: Rectangle {
                        id: statTile
                        required property var modelData
                        required property int index

                        width: (statsRow.width - statsRow.spacing * 3) / 4
                        height: 52
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: modelData.icon
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: statTile.width - 34
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: modelData.label
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font { family: "Google Sans"; pixelSize: 9 }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.value
                                    color: Qt.rgba(1, 1, 1, 0.88)
                                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.detail || ""
                                    visible: text !== ""
                                    color: Qt.rgba(1, 1, 1, 0.45)
                                    font { family: "Google Sans"; pixelSize: 9 }
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: bottomRow
                width: parent.width
                spacing: 10

                Column {
                    id: dailyColumn
                    width: (parent.width - 10) / 2
                    spacing: 8

                    Text {
                        text: "3-DAY FORECAST"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.4 }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Column {
                        id: dailyList
                        width: parent.width
                        spacing: 3

                        Repeater {
                            model: {
                                var days = weather.info.dailyForecast || [];
                                return days.slice(0, Math.min(3, days.length));
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: dailyColumn.width
                                height: 38
                                radius: 10
                                color: index === 0 ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.dayName || ""
                                    color: index === 0 ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.72)
                                    width: 36
                                    font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 46
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.emoji || ""
                                    font.pixelSize: 15
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 66
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: rainPillText.width + 8
                                    height: 14
                                    radius: 7
                                    color: Qt.rgba(0.48, 0.67, 0.97, 0.15)
                                    visible: parseInt(modelData.chanceOfRain || "0") > 10

                                    Text {
                                        id: rainPillText
                                        anchors.centerIn: parent
                                        text: modelData.chanceOfRain + "%"
                                        color: "#7cacf8"
                                        font { family: "Google Sans"; pixelSize: 8; weight: Font.Medium }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Text {
                                        text: modelData.minTemp + "°"
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                        font { family: "Google Sans"; pixelSize: 10 }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        width: 44
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(1, 1, 1, 0.06)
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
                                                return Math.max(3, (end - start) * parent.width);
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
                                        color: Qt.rgba(1, 1, 1, 0.85)
                                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: sunColumn
                    width: (bottomRow.width - 10) / 2
                    height: dailyColumn.height
                    spacing: 8

                    Text {
                        text: "SUN & MOON"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.4 }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - 26
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Canvas {
                                id: sunArc
                                width: parent.width
                                height: parent.height - 44

                                property real progress: {
                                    var _ = weather.nowTick;
                                    return weather.sunProgress();
                                }
                                property bool daytime: {
                                    var _ = weather.nowTick;
                                    return weather.isDaytime;
                                }

                                onProgressChanged: requestPaint()
                                onDaytimeChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                Connections {
                                    target: weather.info
                                    function onSunriseChanged() { sunArc.requestPaint() }
                                    function onSunsetChanged() { sunArc.requestPaint() }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    var cx = width / 2;
                                    var baseline = height - 4;
                                    var radius = Math.min(width / 2 - 8, height - 12);
                                    var p = progress;
                                    var onArc = p >= 0 && p <= 1;
                                    var clamped = Math.max(0, Math.min(1, p));
                                    var angle = Math.PI - clamped * Math.PI;

                                    ctx.beginPath();
                                    ctx.moveTo(8, baseline);
                                    ctx.lineTo(width - 8, baseline);
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, daytime ? 0.14 : 0.08);
                                    ctx.lineWidth = 1;
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.arc(cx, baseline, radius, Math.PI, 0, false);
                                    var arcGrad = ctx.createLinearGradient(0, baseline - radius, width, baseline);
                                    if (daytime) {
                                        arcGrad.addColorStop(0, Qt.rgba(1, 0.55, 0.2, 0.55));
                                        arcGrad.addColorStop(0.5, Qt.rgba(1, 0.85, 0.35, 0.85));
                                        arcGrad.addColorStop(1, Qt.rgba(1, 0.45, 0.25, 0.55));
                                    } else {
                                        arcGrad.addColorStop(0, Qt.rgba(0.5, 0.55, 0.75, 0.35));
                                        arcGrad.addColorStop(0.5, Qt.rgba(0.7, 0.75, 0.95, 0.5));
                                        arcGrad.addColorStop(1, Qt.rgba(0.5, 0.55, 0.75, 0.35));
                                    }
                                    ctx.strokeStyle = arcGrad;
                                    ctx.lineWidth = 2.5;
                                    ctx.stroke();

                                    ctx.beginPath();
                                    ctx.arc(cx, baseline, radius, Math.PI, 0, false);
                                    ctx.lineTo(cx + radius, baseline);
                                    ctx.lineTo(cx - radius, baseline);
                                    ctx.closePath();
                                    var fillGrad = ctx.createLinearGradient(0, baseline - radius, 0, baseline);
                                    fillGrad.addColorStop(0, daytime ? Qt.rgba(1, 0.7, 0.2, 0.14) : Qt.rgba(0.5, 0.6, 0.9, 0.1));
                                    fillGrad.addColorStop(1, "transparent");
                                    ctx.fillStyle = fillGrad;
                                    ctx.fill();

                                    if (daytime && onArc) {
                                        var sx = cx + radius * Math.cos(angle);
                                        var sy = baseline - radius * Math.sin(angle);

                                        var glow = ctx.createRadialGradient(sx, sy, 0, sx, sy, 14);
                                        glow.addColorStop(0, Qt.rgba(1, 0.9, 0.4, 0.6));
                                        glow.addColorStop(1, "transparent");
                                        ctx.beginPath();
                                        ctx.arc(sx, sy, 14, 0, Math.PI * 2);
                                        ctx.fillStyle = glow;
                                        ctx.fill();

                                        ctx.beginPath();
                                        ctx.arc(sx, sy, 5.5, 0, Math.PI * 2);
                                        ctx.fillStyle = Qt.rgba(1, 0.92, 0.45, 0.95);
                                        ctx.fill();
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: root.celestialSize

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Text {
                                        text: "☀️"
                                        font.pixelSize: root.celestialSize
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: weather.info.sunrise || "—"
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Text {
                                        text: weather.info.sunset || "—"
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Canvas {
                                        id: moonViz
                                        width: root.celestialSize
                                        height: root.celestialSize
                                        antialiasing: true

                                        property real illPercent: {
                                            if (!weather.info.moonIllumination) return 50;
                                            var s = weather.info.moonIllumination.replace("%", "").trim();
                                            var v = parseFloat(s);
                                            return isNaN(v) ? 50 : v;
                                        }
                                        property bool isWaxing: weather.info.moonIsWaxing

                                        onIllPercentChanged: requestPaint()
                                        onIsWaxingChanged: requestPaint()

                                        Connections {
                                            target: weather.info
                                            function onMoonIlluminationChanged() { moonViz.requestPaint() }
                                            function onMoonIsWaxingChanged() { moonViz.requestPaint() }
                                        }

                                        Component.onCompleted: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            var cx = width / 2;
                                            var cy = height / 2;
                                            var r = Math.max(1, width / 2 - 0.5);

                                            ctx.beginPath();
                                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.14);
                                            ctx.fill();

                                            var p = illPercent / 100.0;
                                            if (p <= 0.02 || p >= 0.98) {
                                                ctx.beginPath();
                                                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                                ctx.fillStyle = Qt.rgba(1, 1, 1, p <= 0.02 ? 0.2 : 0.95);
                                                ctx.fill();
                                                return;
                                            }

                                            var w = Math.abs(p - 0.5) * 2 * r;
                                            var shade = Qt.rgba(1, 1, 1, 0.95);
                                            var shadow = Qt.rgba(1, 1, 1, 0.14);

                                            ctx.save();
                                            ctx.beginPath();
                                            if (isWaxing) {
                                                ctx.rect(cx, cy - r, r, r * 2);
                                            } else {
                                                ctx.rect(cx - r, cy - r, r, r * 2);
                                            }
                                            ctx.clip();

                                            ctx.beginPath();
                                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                                            ctx.fillStyle = shade;
                                            ctx.fill();

                                            if (p < 0.5) {
                                                ctx.beginPath();
                                                ctx.ellipse(cx - w, cy - r, Math.max(0.5, w * 2), r * 2);
                                                ctx.fillStyle = shadow;
                                                ctx.fill();
                                            }
                                            ctx.restore();

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
                                                ctx.ellipse(cx - w, cy - r, Math.max(0.5, w * 2), r * 2);
                                                ctx.fillStyle = shade;
                                                ctx.fill();
                                                ctx.restore();
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weather.info.moonIllumination ? ("Moon " + weather.info.moonIllumination) : ""
                                color: Qt.rgba(1, 1, 1, 0.45)
                                font { family: "Google Sans"; pixelSize: 9 }
                            }
                        }
                    }
                }
            }
        }
    }
}
