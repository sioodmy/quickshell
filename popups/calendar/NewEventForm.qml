import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.theme
import Quickshell.Io
import qs.services

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
        radius: 28
        visible: false
        layer.enabled: true
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
        radius: 28
        clip: true
        
        layer.enabled: true
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
    
    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        y: slideOffset
        
        Text {
            text: "New Event"
            color: Theme.on_surface
            font { family: "Google Sans"; pointSize: 15; weight: Font.Bold }
        }
        
        Text {
            text: Qt.formatDate(new Date(selectedYear, selectedMonth, selectedDay), "dddd, MMMM d, yyyy")
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pointSize: 11; weight: Font.Medium }
        }
        
        // Title Input
        Rectangle {
            width: parent.width
            height: 40
            radius: 12
            color: Theme.surface_container
            border.color: titleField.activeFocus ? Theme.primary : "transparent"
            border.width: 1
            
            TextField {
                id: titleField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                placeholderText: "Task Title"
                placeholderTextColor: Theme.on_surface_variant
                color: Theme.on_surface
                font { family: "Google Sans"; pointSize: 12 }
                background: Item {}
            }
        }
        
        // Time Picker Header
        Row {
            spacing: 12
            
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: useTime ? Theme.primary : "transparent"
                border.color: useTime ? "transparent" : Theme.outline_variant
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "󰥔"
                    color: useTime ? Theme.on_primary : Theme.on_surface_variant
                    font { family: "JetBrainsMono Nerd Font"; pointSize: 13 }
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
                font { family: "Google Sans"; pointSize: 13; weight: Font.Medium }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        // Sleek Pill-based Time Picker
        Row {
            visible: root.useTime
            spacing: 12
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Hour Pill Stepper
            Rectangle {
                width: 108
                height: 40
                radius: 20
                color: Theme.surface_container
                border.color: Theme.outline_variant
                border.width: 1
                
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    // Minus Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: hrMinus.containsMouse ? Theme.surface_container_highest : "transparent"
                        Text { text: "−"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 12 }
                        MouseArea {
                            id: hrMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedHour = (root.selectedHour + 23) % 24
                        }
                    }
                    
                    // Value
                    Text {
                        width: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: root.selectedHour.toString().padStart(2, '0')
                        font.family: "Google Sans"; font.pointSize: 15; font.weight: Font.Bold
                        color: Theme.on_surface
                    }
                    
                    // Plus Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: hrPlus.containsMouse ? Theme.surface_container_highest : "transparent"
                        Text { text: "+"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 12 }
                        MouseArea {
                            id: hrPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedHour = (root.selectedHour + 1) % 24
                        }
                    }
                }
                
                // Wheel Scroll Support
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
                font.pointSize: 15
                font.weight: Font.Bold
                color: Theme.on_surface_variant
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Minute Pill Stepper
            Rectangle {
                width: 108
                height: 40
                radius: 20
                color: Theme.surface_container
                border.color: Theme.outline_variant
                border.width: 1
                
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    
                    // Minus Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: minMinus.containsMouse ? Theme.surface_container_highest : "transparent"
                        Text { text: "−"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 12 }
                        MouseArea {
                            id: minMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedMinute = (root.selectedMinute + 55) % 60
                        }
                    }
                    
                    // Value
                    Text {
                        width: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: root.selectedMinute.toString().padStart(2, '0')
                        font.family: "Google Sans"; font.pointSize: 15; font.weight: Font.Bold
                        color: Theme.on_surface
                    }
                    
                    // Plus Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: minPlus.containsMouse ? Theme.surface_container_highest : "transparent"
                        Text { text: "+"; anchors.centerIn: parent; font.bold: true; color: Theme.on_surface_variant; font.pointSize: 12 }
                        MouseArea {
                            id: minPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedMinute = (root.selectedMinute + 5) % 60
                        }
                    }
                }
                
                // Wheel Scroll Support
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
            height: 90
            radius: 12
            color: Theme.surface_container
            border.color: descField.activeFocus ? Theme.primary : "transparent"
            border.width: 1
            
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                
                TextArea {
                    id: descField
                    width: parent.width
                    placeholderText: "Description (optional)"
                    placeholderTextColor: Theme.on_surface_variant
                    color: Theme.on_surface
                    font { family: "Google Sans"; pointSize: 12 }
                    background: Item {}
                    wrapMode: Text.Wrap
                }
            }
        }
        
        // Spacer to push buttons to the bottom
        Item { width: 1; height: 4 }
        
        Item {
            width: parent.width
            height: 36
            
            Row {
                anchors.right: parent.right
                spacing: 10
                
                // Cancel Button
                Rectangle {
                    width: 80
                    height: 36
                    radius: 18
                    color: "transparent"
                    border.color: Theme.outline
                    border.width: 1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 11; weight: Font.Medium }
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
                    width: 80
                    height: 36
                    radius: 18
                    color: titleField.text.trim() === "" ? Theme.surface_container_high : Theme.primary
                    opacity: titleField.text.trim() === "" ? 0.5 : 1.0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        color: titleField.text.trim() === "" ? Theme.on_surface_variant : Theme.on_primary
                        font { family: "Google Sans"; pointSize: 11; weight: Font.Medium }
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
