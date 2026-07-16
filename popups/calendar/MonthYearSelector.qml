import QtQuick
import qs.theme

Item {
    id: root

    readonly property int monthW: 64
    readonly property int monthH: 36
    readonly property int monthSpacing: 8
    readonly property int monthStrideX: monthW + monthSpacing
    readonly property int monthStrideY: monthH + monthSpacing

    property int displayYear
    property int displayMonth

    signal previousYear
    signal nextYear
    signal monthSelected(int monthIndex)

    Column {
        anchors.centerIn: parent
        spacing: 20

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: yearPrevMouse.containsMouse ? Theme.surface_variant : "transparent"
                scale: yearPrevMouse.pressed ? 0.9 : (yearPrevMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "❮"
                    color: Theme.on_surface
                    font.pointSize: 11
                }
                MouseArea {
                    id: yearPrevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previousYear()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayYear.toString()
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pointSize: 18
                font.weight: Font.Bold
            }

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: yearNextMouse.containsMouse ? Theme.surface_variant : "transparent"
                scale: yearNextMouse.pressed ? 0.9 : (yearNextMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "❯"
                    color: Theme.on_surface
                    font.pointSize: 11
                }
                MouseArea {
                    id: yearNextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextYear()
                }
            }
        }

        Item {
            width: monthGrid.implicitWidth
            height: monthGrid.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: root.monthW
                height: root.monthH
                radius: root.monthH / 2
                color: Theme.primary
                x: (root.displayMonth % 4) * root.monthStrideX
                y: Math.floor(root.displayMonth / 4) * root.monthStrideY

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
            }

            Grid {
                id: monthGrid
                columns: 4
                spacing: root.monthSpacing

                Repeater {
                    model: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                    Rectangle {
                        width: root.monthW
                        height: root.monthH
                        radius: root.monthH / 2
                        readonly property bool isSelectedMonth: index === root.displayMonth
                        color: monthMouse.containsMouse && !isSelectedMonth ? Theme.surface_variant : "transparent"
                        scale: monthMouse.pressed ? 0.9 : (monthMouse.containsMouse && !isSelectedMonth ? 1.04 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.05
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: isSelectedMonth ? Theme.on_primary : Theme.on_surface
                            font.family: "Google Sans"
                            font.pointSize: 11
                            font.weight: isSelectedMonth ? Font.Bold : Font.Medium
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: monthMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthSelected(index)
                        }
                    }
                }
            }
        }
    }
}
