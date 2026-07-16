import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    readonly property int cellSize: 38
    readonly property int cellSpacing: 6
    readonly property int cellStride: cellSize + cellSpacing

    property alias model: daysRepeater.model
    property int activeCellIndex
    property int lastValidIndex
    property int selectedDay
    property int selectedMonth
    property int selectedYear
    property int displayMonth
    property int displayYear

    signal daySelected(int day)

    Column {
        id: gridContainer
        spacing: 10
        anchors.centerIn: parent

        Grid {
            columns: 7
            spacing: root.cellSpacing
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                Item {
                    width: root.cellSize
                    height: 20
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pointSize: 10
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item {
            width: daysGrid.implicitWidth
            height: daysGrid.implicitHeight

            Rectangle {
                width: root.cellSize
                height: root.cellSize
                radius: root.cellSize / 2
                color: Theme.primary
                opacity: root.activeCellIndex !== -1 ? 1 : 0
                x: (root.lastValidIndex % 7) * root.cellStride
                y: Math.floor(root.lastValidIndex / 7) * root.cellStride

                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            Grid {
                id: daysGrid
                columns: 7
                spacing: root.cellSpacing

                Repeater {
                    id: daysRepeater
                    Rectangle {
                        id: dayCell
                        width: root.cellSize
                        height: root.cellSize
                        radius: root.cellSize / 2
                        readonly property bool isSelectedDay: (model.isCurrentMonth && parseInt(model.dayText) === root.selectedDay && root.displayMonth === root.selectedMonth && root.displayYear === root.selectedYear)

                        readonly property bool hasEvents: {
                            if (!model.isCurrentMonth)
                                return false;
                            return OrgAgenda.hasEventsOnDate(root.displayYear, root.displayMonth, parseInt(model.dayText));
                        }

                        color: (dayMouse.containsMouse && model.isCurrentMonth && !isSelectedDay) ? Theme.surface_variant : "transparent"
                        border.color: model.isToday && !isSelectedDay ? Theme.primary : "transparent"
                        border.width: model.isToday && !isSelectedDay ? 1.5 : 0
                        scale: dayMouse.pressed && model.isCurrentMonth ? 0.90 : (dayMouse.containsMouse && model.isCurrentMonth ? 1.08 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.1
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: dayCell.hasEvents ? -2 : 0
                            text: model.dayText
                            font.family: "Google Sans"
                            font.pointSize: 11
                            font.weight: dayCell.isSelectedDay || model.isToday ? Font.Bold : Font.Medium
                            color: dayCell.isSelectedDay ? Theme.on_primary : (model.isToday ? Theme.primary : (!model.isCurrentMonth ? Theme.outline : Theme.on_surface))
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on anchors.verticalCenterOffset {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            width: 4
                            height: 4
                            radius: 2
                            visible: dayCell.hasEvents
                            color: dayCell.isSelectedDay ? Theme.on_primary : Theme.primary
                            opacity: dayCell.hasEvents ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: model.isCurrentMonth
                            cursorShape: model.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (model.isCurrentMonth) {
                                    root.daySelected(parseInt(model.dayText));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
