import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services

/**
 * Org Agenda Panel — right side of the calendar popup.
 * Shows today's date, upcoming/overdue tasks with M3 styling.
 * Replaces the old ClockPane.
 */
Item {
    id: root

    property date liveTime
    property int selectedDay
    property int selectedMonth
    property int selectedYear

    property bool isWindowVisible: true

    // Refresh agenda when window becomes visible
    onIsWindowVisibleChanged: {
        if (isWindowVisible) {
            OrgAgenda.refresh();
        }
    }

    // Selected date string for filtering
    readonly property string selectedDateStr: {
        let m = (selectedMonth + 1).toString().padStart(2, '0');
        let d = selectedDay.toString().padStart(2, '0');
        return selectedYear + "-" + m + "-" + d;
    }

    readonly property var selectedDateItems: OrgAgenda.itemsForDate(selectedDateStr)

    readonly property bool isToday: {
        let now = new Date();
        return selectedDay === now.getDate() &&
               selectedMonth === now.getMonth() &&
               selectedYear === now.getFullYear();
    }

    // Rounded-corner mask
    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: 28
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 28
        color: Theme.surface_container_highest
        clip: true

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        // ── Animated Background Blobs ──
        Rectangle {
            width: 180
            height: 160
            radius: 80
            color: Theme.primary
            opacity: 0.08
            x: -40
            y: -30
            transformOrigin: Item.Center

            SequentialAnimation on x {
                loops: Animation.Infinite
                paused: !root.isWindowVisible
                NumberAnimation { to: 20; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -80; duration: 8000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -20; duration: 10000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -40; duration: 7500; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                paused: !root.isWindowVisible
                NumberAnimation { to: -70; duration: 8500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 20; duration: 9500; easing.type: Easing.InOutSine }
                NumberAnimation { to: -50; duration: 8000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -30; duration: 9000; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation {
                from: 0; to: 360; duration: 28000
                loops: Animation.Infinite
                paused: !root.isWindowVisible
            }
        }

        Rectangle {
            width: 140
            height: 180
            radius: 70
            color: Theme.tertiary
            opacity: 0.06
            x: bgRect.width - 100
            y: bgRect.height - 140
            transformOrigin: Item.Center

            SequentialAnimation on x {
                loops: Animation.Infinite
                paused: !root.isWindowVisible
                NumberAnimation { to: bgRect.width - 140; duration: 10000; easing.type: Easing.InOutSine }
                NumberAnimation { to: bgRect.width - 60; duration: 8000; easing.type: Easing.InOutSine }
                NumberAnimation { to: bgRect.width - 110; duration: 9500; easing.type: Easing.InOutSine }
                NumberAnimation { to: bgRect.width - 100; duration: 8500; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation {
                from: 360; to: 0; duration: 32000
                loops: Animation.Infinite
                paused: !root.isWindowVisible
            }
        }

        // ── Content ──
        Item {
            anchors.fill: parent
            anchors.margins: 20

            // ── Header: Time + Date (side-by-side) ──
            Row {
                id: headerCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                // Time display
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.liveTime, "HH:mm")
                    color: Theme.primary
                    font { family: "Google Sans"; pointSize: 32; weight: Font.Black }
                }

                // Day name + full date stacked
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "dddd")
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 13; weight: Font.Bold }
                    }

                    Text {
                        text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "MMMM d, yyyy")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pointSize: 10; weight: Font.Medium }
                    }
                }
            }
                
            // Subtle Add Event Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                anchors.right: parent.right
                anchors.verticalCenter: headerCol.verticalCenter
                color: addMouse.containsMouse ? Theme.surface_container_high : "transparent"
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    color: Theme.on_surface_variant
                    font { family: "JetBrainsMono Nerd Font"; pointSize: 16 }
                }
                
                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: newEventForm.isOpen = true
                }
            }
            
            // ── Agenda Section Header ──
            Item {
                id: agendaHeader
                anchors.top: headerCol.bottom
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isToday ? "Today's Agenda" : "Events"
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pointSize: 10; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.2 }
                }

                // Event count badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.selectedDateItems.length > 0
                    width: countText.implicitWidth + 14
                    height: 20
                    radius: 10
                    color: Theme.primary_container

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.selectedDateItems.length.toString()
                        color: Theme.on_primary_container
                        font { family: "Google Sans"; pointSize: 10; weight: Font.Bold }
                    }
                }
            }

            // ── Separator line ──
            Rectangle {
                id: separator
                anchors.top: agendaHeader.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outline_variant
                opacity: 0.5
            }

            // ── Scrollable Agenda List ──
            Flickable {
                id: agendaFlick
                anchors.top: separator.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                contentHeight: agendaCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1500
                maximumFlickVelocity: 4000

                Column {
                    id: agendaCol
                    width: agendaFlick.width
                    spacing: 8

                    // ── Selected date items ──
                    Repeater {
                        model: root.selectedDateItems

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData
                            
                            onClicked: (eventData) => {
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    // ── Empty state for selected date ──
                    Item {
                        visible: root.selectedDateItems.length === 0 && !OrgAgenda.loading
                        width: agendaCol.width
                        height: 60

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰃭"
                                color: Theme.on_surface_variant
                                opacity: 0.4
                                font { family: "JetBrainsMono Nerd Font"; pointSize: 20 }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No events"
                                color: Theme.on_surface_variant
                                opacity: 0.5
                                font { family: "Google Sans"; pointSize: 11 }
                            }
                        }
                    }

                    // ── Divider: Upcoming ──
                    Item {
                        visible: upcomingRepeater.count > 0
                        width: agendaCol.width
                        height: 32

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: "UPCOMING"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pointSize: 9; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.2 }
                        }
                    }

                    Repeater {
                        id: upcomingRepeater
                        model: {
                            let today = Qt.formatDate(new Date(), "yyyy-MM-dd");
                            return OrgAgenda.activeItems.filter(function(e) {
                                let d = e.deadline || e.scheduled || "";
                                // Show upcoming items not on selected date, and that are today or future
                                return d >= today && d !== root.selectedDateStr;
                            }).slice(0, 5);
                        }

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData
                            showDate: true
                            
                            onClicked: (eventData) => {
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    // ── Divider: Overdue ──
                    Item {
                        visible: OrgAgenda.overdueItems.length > 0
                        width: agendaCol.width
                        height: 32

                        Row {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            spacing: 6

                            Text {
                                text: "OVERDUE"
                                color: Theme.critical
                                font { family: "Google Sans"; pointSize: 9; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.2 }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: overdueCountText.implicitWidth + 10
                                height: 16
                                radius: 8
                                color: Theme.critical
                                opacity: 0.15

                                Text {
                                    id: overdueCountText
                                    anchors.centerIn: parent
                                    text: OrgAgenda.overdueItems.length.toString()
                                    color: Theme.critical
                                    font { family: "Google Sans"; pointSize: 9; weight: Font.Bold }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: OrgAgenda.overdueItems.slice(0, 3)

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData
                            showDate: true
                            isOverdue: true
                            
                            onClicked: (eventData) => {
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    // Loading state
                    Text {
                        visible: OrgAgenda.loading
                        width: agendaCol.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Loading..."
                        color: Theme.on_surface_variant
                        opacity: 0.5
                        font { family: "Google Sans"; pointSize: 11 }
                        topPadding: 16
                    }
                }
            }
        }
        
        // ── New Event Form Overlay ──
        NewEventForm {
            id: newEventForm
            anchors.fill: parent
            selectedDay: root.selectedDay
            selectedMonth: root.selectedMonth
            selectedYear: root.selectedYear
            
            onRequestClose: isOpen = false
        }
        
        // ── Event Details View Overlay ──
        EventDetailsView {
            id: eventDetailsView
            anchors.fill: parent
            
            onRequestClose: isOpen = false
        }
    }
}
