import QtQuick

Item {
    id: root

    required property var weather
    property real revealProgress: 1.0

    readonly property real celestialSize: 14

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
        { icon: "💧", label: "Humidity", value: weather.info.humidity || "—" },
        { icon: "☀️", label: "UV", value: weather.info.uv || "—" },
        { icon: "💨", label: "Wind", value: windParts(weather.info.wind).speed },
        { icon: "🌀", label: "Pressure", value: pressureParts(weather.info.pressure).value }
    ]

    opacity: revealProgress
    scale: 0.97 + 0.03 * revealProgress
    transformOrigin: Item.Top

    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    Rectangle {
        id: weatherSurface
        anchors.fill: parent
        radius: 16
        clip: true

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.alpha(weather.gradBottom, 0.5)
                Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            }
            GradientStop {
                position: 1.0
                color: Qt.alpha(weather.gradTop, 0.45)
                Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.InOutCubic } }
            }
        }

        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Hero — replaces the old pink banner header
            Row {
                width: parent.width
                height: 56
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: weather.info.emoji || "🌤"
                    font.pixelSize: 40
                    opacity: 0.92
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - 52 - 12

                    Row {
                        spacing: 8
                        Text {
                            text: weather.info.valid ? weather.info.temp : "—"
                            color: "#ffffff"
                            font { family: "Google Sans"; pixelSize: 28; weight: Font.Light }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: weather.info.condition || (weather.info.valid ? "" : "Loading…")
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font { family: "Google Sans"; pixelSize: 13 }
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 180)
                        }
                    }

                    Row {
                        spacing: 8
                        Text {
                            text: weather.info.location || "Weather"
                            color: Qt.rgba(1, 1, 1, 0.48)
                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                        }
                        Text {
                            text: weather.info.valid ? ("H " + weather.info.maxTemp + "  L " + weather.info.minTemp) : ""
                            color: Qt.rgba(1, 1, 1, 0.42)
                            font { family: "Google Sans"; pixelSize: 11 }
                            visible: text !== ""
                        }
                    }
                }
            }

            Flickable {
                width: parent.width
                height: 58
                contentWidth: hourlyRow.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: hourlyRow
                    spacing: 5

                    Repeater {
                        model: {
                            var hours = weather.info.hourlyForecast || [];
                            return hours.slice(0, Math.min(12, hours.length));
                        }

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 42
                            height: 56
                            radius: 12
                            color: index === 0
                                   ? Qt.rgba(1, 1, 1, 0.16)
                                   : Qt.rgba(1, 1, 1, 0.07)
                            border.color: index === 0 ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: index === 0 ? "Now" : (modelData.hour + ":00")
                                    color: Qt.rgba(1, 1, 1, index === 0 ? 0.92 : 0.55)
                                    font { family: "Google Sans"; pixelSize: 9; weight: index === 0 ? Font.Bold : Font.Normal }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.emoji || ""
                                    font.pixelSize: 15
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (modelData.temp || "—") + "°"
                                    color: "#ffffff"
                                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: statsRow
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.statTiles

                    delegate: Rectangle {
                        id: statTile
                        required property var modelData
                        required property int index

                        width: (statsRow.width - statsRow.spacing * 3) / 4
                        height: 40
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: statTile.width - 30
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: modelData.label
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font { family: "Google Sans"; pixelSize: 8 }
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.value
                                    color: Qt.rgba(1, 1, 1, 0.88)
                                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
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
                spacing: 8

                Column {
                    id: dailyColumn
                    width: (parent.width - 8) / 2
                    spacing: 6

                    Text {
                        text: "3-DAY"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 1.2 }
                    }

                    Column {
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: {
                                var days = weather.info.dailyForecast || [];
                                return days.slice(0, Math.min(3, days.length));
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: dailyColumn.width
                                height: 32
                                radius: 8
                                color: index === 0 ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03)

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.dayName || ""
                                    color: index === 0 ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.7)
                                    width: 32
                                    font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.emoji || ""
                                    font.pixelSize: 13
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: modelData.minTemp + "°"
                                        color: Qt.rgba(1, 1, 1, 0.4)
                                        font { family: "Google Sans"; pixelSize: 10 }
                                    }
                                    Text {
                                        text: modelData.maxTemp + "°"
                                        color: Qt.rgba(1, 1, 1, 0.85)
                                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: (bottomRow.width - 8) / 2
                    spacing: 6

                    Text {
                        text: "SUN & MOON"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font { family: "Google Sans"; pixelSize: 9; weight: Font.Bold; letterSpacing: 1.2 }
                    }

                    Rectangle {
                        width: parent.width
                        height: 110
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.04)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Item {
                                id: sunArc
                                width: parent.width
                                height: 48
                                clip: true

                                property real progress: {
                                    var _ = weather.nowTick;
                                    return weather.sunProgress();
                                }
                                property bool daytime: {
                                    var _ = weather.nowTick;
                                    return weather.isDaytime;
                                }

                                readonly property real arcBase: height - 2
                                readonly property real arcRadius: Math.min(width / 2 - 6, height - 10)
                                readonly property real cx: width / 2
                                readonly property real clamped: Math.max(0, Math.min(1, progress))
                                readonly property real angle: Math.PI - clamped * Math.PI
                                readonly property bool onArc: progress >= 0 && progress <= 1

                                Rectangle {
                                    x: 6
                                    y: sunArc.arcBase
                                    width: sunArc.width - 12
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, sunArc.daytime ? 0.14 : 0.08)
                                }

                                Item {
                                    x: sunArc.cx - sunArc.arcRadius
                                    y: sunArc.arcBase - sunArc.arcRadius
                                    width: sunArc.arcRadius * 2
                                    height: sunArc.arcRadius
                                    clip: true

                                    Rectangle {
                                        width: sunArc.arcRadius * 2
                                        height: sunArc.arcRadius * 2
                                        radius: sunArc.arcRadius
                                        color: "transparent"
                                        border.width: 2
                                        border.color: sunArc.daytime
                                            ? Qt.rgba(1, 0.75, 0.3, 0.65)
                                            : Qt.rgba(0.6, 0.65, 0.85, 0.4)
                                    }
                                }

                                Rectangle {
                                    visible: sunArc.daytime && sunArc.onArc
                                    width: 9
                                    height: 9
                                    radius: 4.5
                                    color: Qt.rgba(1, 0.92, 0.45, 0.95)
                                    x: sunArc.cx + sunArc.arcRadius * Math.cos(sunArc.angle) - 4.5
                                    y: sunArc.arcBase - sunArc.arcRadius * Math.sin(sunArc.angle) - 4.5
                                }
                            }

                            Item {
                                width: parent.width
                                height: root.celestialSize

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        text: "☀️"
                                        font.pixelSize: root.celestialSize
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
                                    spacing: 4
                                    Text {
                                        text: weather.info.sunset || "—"
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                        font { family: "Google Sans"; pixelSize: 10; weight: Font.Medium }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "🌙"
                                        font.pixelSize: root.celestialSize
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
