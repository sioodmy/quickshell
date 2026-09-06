import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.theme
import Quickshell.Io
import qs.services
import qs.components

Item {
    id: root

    property int selectedDay
    property int selectedMonth
    property int selectedYear
    
    property bool isOpen: false
    
    property bool useTime: false
    property int selectedHour: 12
    property int selectedMinute: 0

    signal requestClose()
    
    visible: opacity > 0
    opacity: isOpen ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    
    // Entrance slide animation for content
    property real slideOffset: isOpen ? 0 : 40
    Behavior on slideOffset { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: 20
        visible: false
        layer.enabled: isOpen
    }
    
    // Block clicks and wheel events from bleeding through
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
    }
    
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Theme.surface_container_highest
        radius: 20
        clip: true
        
        layer.enabled: isOpen
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
        }
        
        // ── Animated Background Blobs ──
        Rectangle {
            width: 180
            height: 160
            radius: 80
            color: Theme.primary
            opacity: 0.08
            x: -40
            y: parent.height - 130
            transformOrigin: Item.Center
            
            SequentialAnimation on x {
                loops: Animation.Infinite; paused: !root.isOpen
                NumberAnimation { to: 20; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -40; duration: 8000; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 25000; loops: Animation.Infinite; paused: !root.isOpen }
        }

        Rectangle {
            width: 150
            height: 150
            radius: 75
            color: Theme.tertiary
            opacity: 0.06
            x: parent.width - 90
            y: -30
            transformOrigin: Item.Center
            
            SequentialAnimation on y {
                loops: Animation.Infinite; paused: !root.isOpen
                NumberAnimation { to: 30; duration: 10000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -30; duration: 8500; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation { from: 360; to: 0; duration: 28000; loops: Animation.Infinite; paused: !root.isOpen }
        }
    }
    
    Flickable {
        id: formFlick
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: formCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: formCol
            width: formFlick.width
            spacing: 8
            y: root.slideOffset
            
            // ── Header with Back Button ──
            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: backMouse.containsMouse ? Theme.surface_container_high : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "arrow_back"
                        color: Theme.on_surface
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.requestClose();
                            clearFields();
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: "New Event"
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 13; weight: Font.Bold }
                    }

                    Text {
                        text: Qt.formatDate(new Date(selectedYear, selectedMonth, selectedDay), "dddd, MMM d, yyyy")
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pointSize: 8; weight: Font.Medium }
                    }
                }
            }
            
            // Title Input
            Rectangle {
                width: parent.width
                height: 36
                radius: 10
                color: Theme.surface_container
                border.color: titleField.activeFocus ? Theme.primary : "transparent"
                border.width: 1
                
                TextField {
                    id: titleField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    placeholderText: "Task Title"
                    placeholderTextColor: Theme.on_surface_variant
                    color: Theme.on_surface
                    font { family: "Google Sans"; pointSize: 11 }
                    background: Item {}
                }
            }
            
            // Time Picker Header
            Row {
                spacing: 10
                
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: useTime ? Theme.primary : "transparent"
                    border.color: useTime ? "transparent" : Theme.outline_variant
                    border.width: 1
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "schedule"
                        color: useTime ? Theme.on_primary : Theme.on_surface_variant
                        font.pixelSize: 15
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.useTime = !root.useTime
                    }
                }
                
                Text {
                    text: "Schedule Time"
                    color: useTime ? Theme.on_surface : Theme.on_surface_variant
                    font { family: "Google Sans"; pointSize: 11; weight: Font.Medium }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // Sleek Pill-based Time Picker
            Row {
                visible: root.useTime
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Hour Pill Stepper
                Rectangle {
                    width: 96
                    height: 34
                    radius: 17
                    color: Theme.surface_container
                    border.color: Theme.outline_variant
                    border.width: 1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: hrMinus.containsMouse ? Theme.surface_container_highest : "transparent"
                            Text { text: "−"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 11 }
                            MouseArea {
                                id: hrMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedHour = (root.selectedHour + 23) % 24
                            }
                        }
                        
                        Text {
                            width: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: root.selectedHour.toString().padStart(2, '0')
                            font.family: "Google Sans"; font.pointSize: 13; font.weight: Font.Bold
                            color: Theme.on_surface
                        }
                        
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: hrPlus.containsMouse ? Theme.surface_container_highest : "transparent"
                            Text { text: "+"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 11 }
                            MouseArea {
                                id: hrPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedHour = (root.selectedHour + 1) % 24
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) root.selectedHour = (root.selectedHour + 1) % 24;
                            else root.selectedHour = (root.selectedHour + 23) % 24;
                            wheel.accepted = true;
                        }
                    }
                }
                
                Text {
                    text: ":"
                    font.family: "Google Sans"
                    font.pointSize: 13
                    font.weight: Font.Bold
                    color: Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // Minute Pill Stepper
                Rectangle {
                    width: 96
                    height: 34
                    radius: 17
                    color: Theme.surface_container
                    border.color: Theme.outline_variant
                    border.width: 1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: minMinus.containsMouse ? Theme.surface_container_highest : "transparent"
                            Text { text: "−"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 11 }
                            MouseArea {
                                id: minMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedMinute = (root.selectedMinute + 55) % 60
                            }
                        }
                        
                        Text {
                            width: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: root.selectedMinute.toString().padStart(2, '0')
                            font.family: "Google Sans"; font.pointSize: 13; font.weight: Font.Bold
                            color: Theme.on_surface
                        }
                        
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: minPlus.containsMouse ? Theme.surface_container_highest : "transparent"
                            Text { text: "+"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 11 }
                            MouseArea {
                                id: minPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedMinute = (root.selectedMinute + 5) % 60
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) root.selectedMinute = (root.selectedMinute + 5) % 60;
                            else root.selectedMinute = (root.selectedMinute + 55) % 60;
                            wheel.accepted = true;
                        }
                    }
                }
            }
            
            // Description Input
            Rectangle {
                width: parent.width
                height: 52
                radius: 10
                color: Theme.surface_container
                border.color: descField.activeFocus ? Theme.primary : "transparent"
                border.width: 1
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    
                    TextArea {
                        id: descField
                        width: parent.width
                        placeholderText: "Description (optional)"
                        placeholderTextColor: Theme.on_surface_variant
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 11 }
                        background: Item {}
                        wrapMode: Text.Wrap
                    }
                }
            }
            
            // Buttons Row
            Row {
                anchors.right: parent.right
                spacing: 8
                
                // Cancel Button
                Rectangle {
                    width: 68
                    height: 30
                    radius: 15
                    color: "transparent"
                    border.color: Theme.outline
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 10; weight: Font.Medium }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.requestClose();
                            clearFields();
                        }
                    }
                }
                
                // Save Button
                Rectangle {
                    width: 68
                    height: 30
                    radius: 15
                    color: titleField.text.trim() === "" ? Theme.surface_container_high : Theme.primary
                    opacity: titleField.text.trim() === "" ? 0.5 : 1.0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: titleField.text.trim() === "" ? Theme.on_surface_variant : Theme.on_primary
                        font { family: "Google Sans"; pointSize: 10; weight: Font.Medium }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: titleField.text.trim() !== ""
                        onClicked: {
                            saveEntry();
                            root.requestClose();
                            clearFields();
                        }
                    }
                }
            }
        }
    }
    
    function clearFields() {
        titleField.text = "";
        descField.text = "";
        useTime = false;
        selectedHour = 12;
        selectedMinute = 0;
    }
    
    function saveEntry() {
        let title = titleField.text.trim();
        let desc = descField.text.trim();
        
        let targetDate = new Date(selectedYear, selectedMonth, selectedDay);
        let dateStr = Qt.formatDate(targetDate, "yyyy-MM-dd ddd");
        
        let timeStr = "";
        if (useTime) {
            timeStr = " " + selectedHour.toString().padStart(2, '0') + ":" + selectedMinute.toString().padStart(2, '0');
        }
        
        let scheduled = "SCHEDULED: <" + dateStr + timeStr + ">";
        
        let entry = "* TODO " + title + "\n" + scheduled;
        if (desc !== "") {
            entry += "\n" + desc;
        }
        entry += "\n";
        
        appendProc.command = ["bash", "-c", "printf '%s\n' \"$1\" >> ~/Notes/refile.org", "--", entry];
        appendProc.running = true;
    }
    
    Process {
        id: appendProc
        onExited: {
            OrgAgenda.refresh();
        }
    }
    
    onIsOpenChanged: {
        if (isOpen) {
            titleField.forceActiveFocus();
        }
    }
}
