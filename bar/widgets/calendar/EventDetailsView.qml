import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.theme

Item {
    id: root

    property var entryData: ({})
    property bool isOpen: false

    signal requestClose()
    
    visible: opacity > 0
    opacity: isOpen ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
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
            width: 200
            height: 200
            radius: 100
            color: {
                if (root.entryData.state === "TODO" || root.entryData.state === "NEXT") return Theme.primary;
                if (root.entryData.state === "WAITING") return Theme.tertiary;
                if (root.entryData.state === "DONE") return Theme.primary;
                return Theme.secondary;
            }
            opacity: 0.08
            x: -50
            y: parent.height - 150
            transformOrigin: Item.Center
            
            SequentialAnimation on x {
                loops: Animation.Infinite; paused: !root.isOpen
                NumberAnimation { to: 10; duration: 8000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -50; duration: 9000; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 20000; loops: Animation.Infinite; paused: !root.isOpen }
        }

        Rectangle {
            width: 150
            height: 150
            radius: 75
            color: Theme.primary
            opacity: 0.06
            x: parent.width - 80
            y: -30
            transformOrigin: Item.Center
            
            SequentialAnimation on y {
                loops: Animation.Infinite; paused: !root.isOpen
                NumberAnimation { to: 20; duration: 10000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -30; duration: 8500; easing.type: Easing.InOutSine }
            }
            NumberAnimation on rotation { from: 360; to: 0; duration: 25000; loops: Animation.Infinite; paused: !root.isOpen }
        }
        
        // Dynamic State Stripe removed per user request
    
        Column {
            anchors.fill: parent
            anchors.margins: 20
            anchors.leftMargin: 24
            spacing: 16
            
            // ── Header with Back Button ──
            Row {
                width: parent.width
                spacing: 12
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: backMouse.containsMouse ? Theme.surface_container_high : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰁍" // mdi-arrow-left
                        color: Theme.on_surface
                        font { family: "JetBrainsMono Nerd Font"; pointSize: 16 }
                    }
                    
                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
                
                Text {
                    text: "Event Details"
                    color: Theme.on_surface
                    font { family: "Google Sans"; pointSize: 15; weight: Font.Bold }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // ── Separator line ──
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline_variant
                opacity: 0.5
            }
            
            // ── Scrollable Content ──
            ScrollView {
                id: detailsScroll
                width: parent.width
                height: parent.height - 76
                clip: true
                
                Column {
                    width: detailsScroll.width - 12
                    spacing: 16
                    y: root.slideOffset
                    
                    // Title
                    Text {
                        width: parent.width
                        text: root.entryData.title || ""
                        color: Theme.on_surface
                        font { family: "Google Sans"; pointSize: 22; weight: Font.Black }
                        wrapMode: Text.Wrap
                        lineHeight: 1.1
                    }
                    
                    // Tags
                    Flow {
                        width: parent.width
                        spacing: 8
                        visible: root.entryData.tags && root.entryData.tags.length > 0
                        
                        Repeater {
                            model: root.entryData.tags || []
                            Rectangle {
                                required property var modelData
                                width: tagTextD.implicitWidth + 16
                                height: 24
                                radius: 12
                                color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.3)
                                border.width: 1
                                
                                Text {
                                    id: tagTextD
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Theme.secondary
                                    font { family: "Google Sans"; pointSize: 11; weight: Font.Bold }
                                }
                            }
                        }
                    }
                    
                    // Metadata Info Card
                    Rectangle {
                        width: parent.width
                        height: infoCol.implicitHeight + 24
                        radius: 16
                        color: Theme.surface_container
                        border.color: Theme.outline_variant
                        border.width: 1
                        
                        Column {
                            id: infoCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            
                            // State
                            Row {
                                spacing: 10
                                visible: root.entryData.state ? true : false
                                Text { text: "󰡖"; color: Theme.on_surface_variant; font { family: "JetBrainsMono Nerd Font"; pointSize: 16 } anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: stateText.implicitWidth + 16
                                    height: 24
                                    radius: 12
                                    color: {
                                        if (root.entryData.state === "DONE") return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                                        if (root.entryData.state === "TODO" || root.entryData.state === "NEXT") return Theme.primary_container;
                                        if (root.entryData.state === "WAITING") return Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.15);
                                        return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                    }
                                    
                                    Text {
                                        id: stateText
                                        anchors.centerIn: parent
                                        text: root.entryData.state || ""
                                        color: {
                                            if (root.entryData.state === "DONE") return Theme.primary;
                                            if (root.entryData.state === "TODO" || root.entryData.state === "NEXT") return Theme.on_primary_container;
                                            if (root.entryData.state === "WAITING") return Theme.tertiary;
                                            return Theme.on_surface_variant;
                                        }
                                        font { family: "Google Sans"; pointSize: 11; weight: Font.Black }
                                    }
                                }
                            }
                            
                            // Scheduled
                            Row {
                                visible: root.entryData.scheduled ? true : false
                                spacing: 10
                                Text { text: "󰸗"; color: Theme.on_surface_variant; font { family: "JetBrainsMono Nerd Font"; pointSize: 16 } anchors.verticalCenter: parent.verticalCenter }
                                Text { 
                                    text: (root.entryData.scheduled || "") + (root.entryData.scheduled_time ? " at " + root.entryData.scheduled_time : "")
                                    color: Theme.on_surface_variant
                                    font { family: "Google Sans"; pointSize: 13; weight: Font.Medium }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            // Deadline
                            Row {
                                visible: root.entryData.deadline ? true : false
                                spacing: 10
                                Text { text: "󰃰"; color: Theme.critical; font { family: "JetBrainsMono Nerd Font"; pointSize: 16 } anchors.verticalCenter: parent.verticalCenter }
                                Text { 
                                    text: (root.entryData.deadline || "") + (root.entryData.deadline_time ? " at " + root.entryData.deadline_time : "")
                                    color: Theme.critical
                                    font { family: "Google Sans"; pointSize: 13; weight: Font.Bold }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            // Source File
                            Row {
                                visible: root.entryData.file ? true : false
                                spacing: 10
                                Text { text: "󰈔"; color: Theme.on_surface_variant; font { family: "JetBrainsMono Nerd Font"; pointSize: 16 } anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: root.entryData.file || ""
                                    color: Theme.on_surface_variant
                                    font { family: "Google Sans"; pointSize: 13; weight: Font.Medium; italic: true }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                    
                    // Body / Description Container
                    Rectangle {
                        visible: root.entryData.body ? true : false
                        width: parent.width
                        height: bodyText.implicitHeight + 24
                        radius: 16
                        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.03)
                        
                        Text {
                            id: bodyText
                            anchors.fill: parent
                            anchors.margins: 12
                            text: root.entryData.body ? root.entryData.body.replace(/\\n/g, "\n") : ""
                            color: Theme.on_surface
                            font { family: "Google Sans"; pointSize: 13; weight: Font.Medium }
                            wrapMode: Text.Wrap
                            lineHeight: 1.3
                        }
                    }
                    
                    Item { width: 1; height: 30 } // Bottom padding
                }
            }
        }
    }
}
