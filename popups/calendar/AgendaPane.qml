import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

/**
 * Org Agenda Panel — right side of the calendar popup.
 * Shows today's date, upcoming/overdue tasks with M3 styling.
 */
Item {
    id: root

    property date liveTime
    property int selectedDay
    property int selectedMonth
    property int selectedYear

    property bool isWindowVisible: true
    property bool clockSettled: true

    property alias timeLabel: timeText

    signal closeRequested()

    // Refresh agenda when window becomes visible, reset overlays when hidden
    onIsWindowVisibleChanged: {
        if (isWindowVisible) {
            OrgAgenda.refresh();
        } else {
            newEventForm.isOpen = false;
            eventDetailsView.isOpen = false;
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

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 20
        color: "#000000"
        clip: true

        Item {
            id: agendaMainContent
            anchors.fill: parent
            anchors.margins: 14
            visible: opacity > 0
            opacity: (newEventForm.isOpen || eventDetailsView.isOpen) ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Row {
                id: headerCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    id: timeText
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.liveTime, "HH:mm")
                    color: Theme.primary
                    font { family: "Google Sans"; pointSize: 18; weight: Font.Black }
                    // Keep layout size while invisible so the morph has a stable landing pad
                    opacity: root.clockSettled ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "dddd")
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 10; weight: Font.Bold }
                    }

                    Text {
                        text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "MMM d, yyyy")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pointSize: 8; weight: Font.Medium }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: headerCol.verticalCenter
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: addMouse.containsMouse ? Theme.surface_container_high : "transparent"

                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "add"
                        color: Theme.on_surface_variant
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            eventDetailsView.isOpen = false;
                            newEventForm.isOpen = true;
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Theme.surface_variant : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        font.pixelSize: 18
                        color: Theme.on_surface_variant
                    }
                    
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            Item {
                id: agendaHeader
                anchors.top: headerCol.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: 20

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isToday ? "Today's Agenda" : "Events"
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pointSize: 9; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.0 }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.selectedDateItems.length > 0
                    width: countText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Theme.primary_container

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.selectedDateItems.length.toString()
                        color: Theme.on_primary_container
                        font { family: "Google Sans"; pointSize: 8; weight: Font.Bold }
                    }
                }
            }

            Rectangle {
                id: separator
                anchors.top: agendaHeader.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outline_variant
                opacity: 0.45
            }

            Flickable {
                id: agendaFlick
                anchors.top: separator.bottom
                anchors.topMargin: 6
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
                    spacing: 6

                    Repeater {
                        model: root.selectedDateItems

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData

                            onClicked: (eventData) => {
                                newEventForm.isOpen = false;
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    Item {
                        visible: root.selectedDateItems.length === 0 && !OrgAgenda.loading
                        width: agendaCol.width
                        height: 48

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: "event_busy"
                                color: Theme.on_surface_variant
                                opacity: 0.4
                                font.pixelSize: 20
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No events"
                                color: Theme.on_surface_variant
                                opacity: 0.5
                                font { family: "Google Sans"; pointSize: 10 }
                            }
                        }
                    }

                    Item {
                        visible: upcomingRepeater.count > 0
                        width: agendaCol.width
                        height: 26

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            text: "UPCOMING"
                            color: Theme.on_surface_variant
                            font { family: "Google Sans"; pointSize: 8; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.0 }
                        }
                    }

                    Repeater {
                        id: upcomingRepeater
                        model: {
                            let today = Qt.formatDate(new Date(), "yyyy-MM-dd");
                            return (OrgAgenda.activeItems || []).filter(function(e) {
                                let d = e.deadline || e.scheduled || "";
                                return d >= today && d !== root.selectedDateStr;
                            }).slice(0, 5);
                        }

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData
                            showDate: true

                            onClicked: (eventData) => {
                                newEventForm.isOpen = false;
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    Item {
                        visible: (OrgAgenda.overdueItems || []).length > 0
                        width: agendaCol.width
                        height: 26

                        Row {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            spacing: 5

                            Text {
                                text: "OVERDUE"
                                color: Theme.critical
                                font { family: "Google Sans"; pointSize: 8; weight: Font.DemiBold; capitalization: Font.AllUppercase; letterSpacing: 1.0 }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: overdueCountText.implicitWidth + 8
                                height: 14
                                radius: 7
                                color: Theme.critical
                                opacity: 0.15

                                Text {
                                    id: overdueCountText
                                    anchors.centerIn: parent
                                    text: (OrgAgenda.overdueItems || []).length.toString()
                                    color: Theme.critical
                                    font { family: "Google Sans"; pointSize: 8; weight: Font.Bold }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: (OrgAgenda.overdueItems || []).slice(0, 3)

                        delegate: AgendaCard {
                            required property var modelData
                            width: agendaCol.width
                            entryData: modelData
                            showDate: true
                            isOverdue: true

                            onClicked: (eventData) => {
                                newEventForm.isOpen = false;
                                eventDetailsView.entryData = eventData;
                                eventDetailsView.isOpen = true;
                            }
                        }
                    }

                    Text {
                        visible: OrgAgenda.loading
                        width: agendaCol.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Loading..."
                        color: Theme.on_surface_variant
                        opacity: 0.5
                        font { family: "Google Sans"; pointSize: 10 }
                        topPadding: 12
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
