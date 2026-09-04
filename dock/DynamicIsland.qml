import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.theme
import qs.services
import qs.components
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../popups/calendar"

Item {
    id: root
    
    // Explicit sizing for Dock.qml to animate notchBg
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // State
    property string activeMode: "dock" // "dock", "notification", "screenshot", "battery", "polkit"
    property var currentNotification: null
    property int batteryRemaining: 100
    
    // Polkit state
    property string polkitActionId: ""
    property string polkitMessage: ""
    property string polkitIcon: ""
    property string polkitCookie: ""
    property string polkitUserName: ""
    property string polkitPrompt: ""
    property bool polkitError: false
    property bool polkitYubikey: false

    // OSD state
    property real osdDockWidth: 300
    property real osdDockHeight: 42
    property string osdType: "volume" // "volume" or "brightness"
    property real osdProgress: 0.0
    property string osdIcon: "volume_up"
    property string osdTitle: "Volume"
    property string osdText: "100%"
    property color osdColor: "#ffffff"
    property bool audioInitialized: false
    property bool brightnessInitialized: false

    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0
    readonly property bool isMuted: activeSink?.audio?.muted ?? true

    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    Timer {
        id: osdTimer
        interval: 2000
        onTriggered: {
            if (root.activeMode === "osd") {
                root.activeMode = "dock";
            }
        }
    }

    function triggerVolumeOsd() {
        if (!audioInitialized) {
            audioInitialized = true;
            return;
        }
        root.osdType = "volume";
        root.osdProgress = isMuted ? 0 : Math.min(1.0, Math.max(0.0, volumeLevel));
        root.osdIcon = isMuted ? "volume_off" : (volumeLevel > 0.5 ? "volume_up" : (volumeLevel > 0 ? "volume_down" : "volume_mute"));
        root.osdTitle = "Volume";
        root.osdText = isMuted ? "Muted" : Math.round(volumeLevel * 100) + "%";
        root.osdColor = "#ffffff";
        root.activeMode = "osd";
        osdTimer.restart();
    }

    function triggerBrightnessOsd() {
        if (!brightnessInitialized) {
            brightnessInitialized = true;
            return;
        }
        var val = Brightness.value;
        root.osdType = "brightness";
        root.osdProgress = Math.min(1.0, Math.max(0.0, val));
        root.osdIcon = val >= 0.7 ? "brightness_7" : (val >= 0.3 ? "brightness_5" : "brightness_6");
        root.osdTitle = "Brightness";
        root.osdText = Math.round(val * 100) + "%";
        root.osdColor = "#ffffff";
        root.activeMode = "osd";
        osdTimer.restart();
    }

    onVolumeLevelChanged: triggerVolumeOsd()
    onIsMutedChanged: triggerVolumeOsd()

    Connections {
        target: Brightness
        function onValueChanged() {
            triggerBrightnessOsd();
        }
    }
    
    // API for Dock.qml to check if it should hide normal content
    readonly property bool isDockHidden: activeMode !== "dock"
    readonly property bool requiresKeyboard: activeMode === "polkit" && !polkitYubikey
    
    // --- Connections ---
    
    Connections {
        target: NotifServer
        function onNotification(notification) {
            if (DoNotDisturb.enabled) return;
            root.currentNotification = notification;
            root.activeMode = "notification";
            notificationTimer.restart();
        }
    }
    
    Connections {
        target: Screenshot
        function onOverlayActiveChanged() {
            if (Screenshot.overlayActive) {
                root.activeMode = "screenshot";
            } else {
                if (root.activeMode === "screenshot") {
                    root.activeMode = "dock";
                }
            }
        }
        
        function onActiveChanged() {
            if (Screenshot.active) {
                root.activeMode = "screenshot_result";
                notificationTimer.restart();
            } else if (root.activeMode === "screenshot_result") {
                root.activeMode = "dock";
            }
        }
    }
    
    Connections {
        target: ScreenRecord
        function onActiveChanged() {
            if (ScreenRecord.active) {
                root.activeMode = "recording";
                notificationTimer.restart();
            } else if (root.activeMode === "recording") {
                root.activeMode = "dock";
            }
        }
    }

    Connections {
        target: BackendDaemon
        function onPolkitShowAuth(action_id, message, icon_name, cookie, user_name, prompt) {
            root.polkitActionId = action_id;
            root.polkitMessage = message;
            root.polkitIcon = icon_name;
            root.polkitCookie = cookie;
            root.polkitUserName = user_name;
            root.polkitPrompt = prompt;
            root.polkitError = false;
            
            root.polkitYubikey = prompt.toLowerCase().indexOf("touch") !== -1 || prompt.toLowerCase().indexOf("fido") !== -1 || prompt.toLowerCase().indexOf("yubikey") !== -1;
            
            root.activeMode = "polkit";
        }
        function onPolkitResult(cookie, success) {
            if (cookie === root.polkitCookie) {
                if (success) {
                    if (root.activeMode === "polkit") root.activeMode = "dock";
                } else {
                    root.polkitError = true;
                }
            }
        }
        function onPolkitDismiss(cookie) {
            if (cookie === root.polkitCookie) {
                if (root.activeMode === "polkit") root.activeMode = "dock";
            }
        }
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() {
            checkBattery();
        }
    }
    
    property bool wasOnBattery: true

    Connections {
        target: UPower
        function onOnBatteryChanged() {
            if (root.wasOnBattery && !UPower.onBattery) {
                root.activeMode = "charging";
                chargingTimer.restart();
            }
            root.wasOnBattery = UPower.onBattery;
            checkBattery();
        }
    }

    Timer {
        id: chargingTimer
        interval: 1500
        onTriggered: {
            if (root.activeMode === "charging") {
                root.activeMode = "dock";
            }
        }
    }
    
    property bool warned20: false
    property bool warned10: false
    
    function checkBattery() {
        if (!UPower.displayDevice) return;
        var percentage = UPower.displayDevice.percentage;
        var batPercent = percentage <= 1.0 ? Math.round(percentage * 100) : Math.round(percentage);
        
        if (!UPower.onBattery || batPercent > 20) {
            warned20 = false;
            warned10 = false;
            if (root.activeMode === "battery") root.activeMode = "dock";
            return;
        }
        if (batPercent === 0) return; 
        if (batPercent <= 10 && !warned10) {
            warned10 = true;
            warned20 = true;
            batteryRemaining = batPercent;
            root.activeMode = "battery";
            notificationTimer.restart();
        } else if (batPercent <= 20 && batPercent > 10 && !warned20) {
            warned20 = true;
            batteryRemaining = batPercent;
            root.activeMode = "battery";
            notificationTimer.restart();
        }
    }

    Timer {
        id: notificationTimer
        interval: 6000
        onTriggered: {
            if (root.activeMode === "notification" || root.activeMode === "battery" || root.activeMode === "screenshot_result" || root.activeMode === "recording") {
                root.activeMode = "dock";
            }
        }
    }

    // Layout
    Item {
        id: layout
        anchors.centerIn: parent
        implicitWidth: Math.max(0, loader.implicitWidth)
        implicitHeight: Math.max(0, loader.implicitHeight)
        
        Loader {
            id: loader
            anchors.centerIn: parent
            sourceComponent: {
                if (root.activeMode === "notification") return notifComp;
                if (root.activeMode === "screenshot") return screenshotComp;
                if (root.activeMode === "battery") return batteryComp;
                if (root.activeMode === "screenshot_result") return screenshotResultComp;
                if (root.activeMode === "recording") return recordingComp;
                if (root.activeMode === "polkit") return polkitComp;
                if (root.activeMode === "calendar") return calendarComp;
                if (root.activeMode === "osd") return osdComp;
                if (root.activeMode === "charging") return chargingComp;
                if (root.activeMode === "drag_queen") return dragQueenComp;
                return emptyComp;
            }
        }
    }

    // --- Components ---
    
    Component {
        id: chargingComp
        Item {
            implicitWidth: root.osdDockWidth
            implicitHeight: root.osdDockHeight

            Item {
                anchors.top: parent.top
                anchors.topMargin: 14
                height: 28
                anchors.left: parent.left
                anchors.right: parent.right

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "bolt"
                        font.pixelSize: 18
                        color: "#259b50"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Charging"
                        color: Theme.on_surface
                        font.family: "Google Sans"
                        font.pointSize: 11
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }



    Component {
        id: osdComp
        Item {
            implicitWidth: root.osdDockWidth
            implicitHeight: root.osdDockHeight

            // Base Unclipped Labels Overlay (white/light text over dark dock background)
            Item {
                anchors.top: parent.top
                anchors.topMargin: 14
                height: 28
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: root.osdIcon
                        font.pixelSize: 16
                        color: "#ffffff"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.osdTitle
                        color: "#ffffff"
                        font.family: "Google Sans"
                        font.pointSize: 10
                        font.weight: Font.Medium
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.osdText
                    color: "#ffffff"
                    font.family: "Google Sans"
                    font.pointSize: 10
                    font.weight: Font.Bold
                }
            }

            // Full-bleed Progress Fill Bar (rounded left dock edge, sharp plain vertical right edge)
            Item {
                id: progressClipper
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.min(1.0, Math.max(0.0, root.osdProgress))
                clip: true

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.osdDockWidth
                    color: root.osdColor
                    radius: 14
                }

                // Clipped Dark Labels Overlay (dark gray text over white fill bar)
                Item {
                    width: root.osdDockWidth
                    height: root.osdDockHeight
                    anchors.left: parent.left
                    anchors.top: parent.top

                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        height: 28
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: root.osdIcon
                                font.pixelSize: 16
                                color: "#1e1e1e"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.osdTitle
                                color: "#1e1e1e"
                                font.family: "Google Sans"
                                font.pointSize: 10
                                font.weight: Font.Medium
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.osdText
                            color: "#1e1e1e"
                            font.family: "Google Sans"
                            font.pointSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }

    Component {
        id: calendarComp
        CalendarGrid {
            isWindowVisible: root.activeMode === "calendar"
            clockSettled: true
            onRequestClose: root.activeMode = "dock"
        }
    }
    
    Component {
        id: polkitComp
        Row {
            spacing: 12

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.polkitYubikey ? "fingerprint" : "lock"
                font.pixelSize: 24
                color: Theme.primary
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: 350

                Text {
                    text: root.polkitMessage
                    color: "#ffffff"
                    font.family: "Google Sans Medium"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    width: parent.width
                }
                Text {
                    text: root.polkitError ? "Authentication failed" : (root.polkitYubikey ? root.polkitPrompt : ("Password for " + root.polkitUserName))
                    color: root.polkitError ? Theme.error : "#bbbbbb"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Rectangle {
                width: 250
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                radius: 16
                color: Theme.surface_container_highest
                visible: !root.polkitYubikey
                border.width: 1
                border.color: polkitInput.activeFocus ? Theme.primary : "transparent"
                clip: true

                TextInput {
                    id: polkitInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: "transparent"
                    font.pixelSize: 14
                    echoMode: TextInput.Normal
                    selectByMouse: false
                    cursorDelegate: Item {}

                    Keys.onEscapePressed: {
                        BackendDaemon.polkitCancel(root.polkitCookie);
                        root.activeMode = "dock";
                    }

                    onAccepted: {
                        if (text.length > 0) {
                            BackendDaemon.polkitSubmit(root.polkitCookie, text);
                        }
                    }
                }
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Repeater {
                        model: polkitInput.text.length

                        Item {
                            id: shapeSlot
                            width: 11
                            height: 11
                            readonly property int kind: index % 3

                            Rectangle {
                                visible: shapeSlot.kind === 0
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                radius: width / 2
                                color: "#ffffff"
                            }

                            Rectangle {
                                visible: shapeSlot.kind === 1
                                anchors.centerIn: parent
                                width: 9
                                height: 9
                                radius: 1.5
                                color: "#ffffff"
                            }

                            Shape {
                                visible: shapeSlot.kind === 2
                                anchors.centerIn: parent
                                width: 11
                                height: 10
                                antialiasing: true

                                ShapePath {
                                    fillColor: "#ffffff"
                                    strokeWidth: 0
                                    startX: 5.5; startY: 0.5
                                    PathLine { x: 10.5; y: 9.5 }
                                    PathLine { x: 0.5; y: 9.5 }
                                    PathLine { x: 5.5; y: 0.5 }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: pwCaret
                        width: 2
                        height: 16
                        radius: 1
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.primary
                        visible: polkitInput.activeFocus
                        opacity: 1

                        SequentialAnimation on opacity {
                            running: pwCaret.visible
                            loops: Animation.Infinite
                            PauseAnimation { duration: 530 }
                            PropertyAction { value: 0 }
                            PauseAnimation { duration: 530 }
                            PropertyAction { value: 1 }
                        }
                    }
                }

                
                Component.onCompleted: {
                    if (!root.polkitYubikey) {
                        polkitInput.forceActiveFocus();
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: cancelMouse.containsMouse ? Theme.surface_variant : "transparent"
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        font.pixelSize: 18
                        color: Theme.on_surface
                    }
                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BackendDaemon.polkitCancel(root.polkitCookie);
                            root.activeMode = "dock";
                        }
                    }
                }
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.primary
                    visible: !root.polkitYubikey
                    opacity: authMouse.containsMouse ? 0.8 : 1.0
                    
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "check"
                        font.pixelSize: 18
                        color: Theme.on_primary
                    }
                    MouseArea {
                        id: authMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (polkitInput.text.length > 0) {
                                BackendDaemon.polkitSubmit(root.polkitCookie, polkitInput.text);
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component {
        id: emptyComp
        Item { implicitWidth: 0; implicitHeight: 0 }
    }
    
    Component {
        id: notifComp
        
        MouseArea {
            implicitWidth: row.implicitWidth
            implicitHeight: row.implicitHeight
            cursorShape: Qt.PointingHandCursor
            
            onClicked: {
                if (root.currentNotification && typeof root.currentNotification.dismiss === "function") {
                    root.currentNotification.dismiss();
                }
                root.activeMode = "dock";
            }
            
            Row {
                id: row
                spacing: 12
                

            
            Column {
                id: textCol
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(300, implicitWidth) // max width constraint
                
                Text {
                    text: root.currentNotification ? (root.currentNotification.summary || root.currentNotification.appName) : ""
                    color: "#ffffff"
                    font.family: "Google Sans Medium"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 300)
                }
                Text {
                    text: root.currentNotification ? root.currentNotification.body : ""
                    color: "#bbbbbb"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    width: Math.min(implicitWidth, 300)
                    visible: text !== ""
                }
            }
        }
    }
    }
    
    Component {
        id: screenshotComp
        Row {
            spacing: 8
            
            Timer {
                running: true
                interval: 3000
                onTriggered: {
                    if (root.activeMode === "screenshot") {
                        root.activeMode = "dock";
                    }
                    Screenshot.overlayActive = false;
                }
            }
            
            component Btn: Rectangle {
                property string icon
                property string label
                signal clicked()
                width: 80
                height: 32
                radius: 16
                color: m.containsMouse ? Theme.primary_container : "transparent"
                border.color: Theme.surface_variant
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialIcon {
                        icon: parent.parent.icon
                        font.pixelSize: 14
                        color: m.containsMouse ? Theme.on_primary_container : "#ffffff"
                    }
                    Text {
                        text: parent.parent.label
                        font.family: "Google Sans Medium"
                        font.pixelSize: 12
                        color: m.containsMouse ? Theme.on_primary_container : "#ffffff"
                    }
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                }
            }
            
            Btn {
                icon: "fullscreen"
                label: "Full"
                onClicked: Screenshot.finishFullscreen()
            }
            Btn {
                icon: "crop"
                label: "Area"
                onClicked: Screenshot.finishArea()
            }
            Btn {
                icon: "window"
                label: "Window"
                onClicked: Screenshot.finishWindow()
            }
            Btn {
                icon: "close"
                label: "Close"
                onClicked: {
                    if (root.activeMode === "screenshot") {
                        root.activeMode = "dock";
                    }
                    Screenshot.overlayActive = false;
                }
            }
        }
    }

    Component {
        id: screenshotResultComp
        Row {
            spacing: 12
            
            Rectangle {
                id: previewContainer
                width: 142
                height: 80
                radius: 12
                color: Theme.surface_container_high
                clip: true
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        FileStash.addPath(Screenshot.imagePath);
                        Screenshot.dismiss();
                        root.activeMode = "dock";
                    }
                }
                
                Image {
                    id: previewImg
                    anchors.fill: parent
                    source: Screenshot.imagePath ? ("file://" + Screenshot.imagePath) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 400
                    layer.enabled: true
                    layer.effect: MultiEffect { 
                        maskEnabled: true
                        maskSource: previewMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0 
                    }
                }
                Rectangle { id: previewMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
            }
            
            Grid {
                anchors.verticalCenter: parent.verticalCenter
                columns: 2
                spacing: 8
                
                component ActionPill: Rectangle {
                    id: pill
                    property string icon
                    property string label
                    property bool done: false
                    property bool busy: false
                    signal triggered()
                    
                    width: 96
                    height: 36
                    radius: 18
                    color: {
                        if (done) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                        if (pillMouse.containsMouse) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14);
                        return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: pillMouse.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: pill.done ? "check" : (pill.busy ? "sync" : pill.icon)
                            font.pixelSize: 13
                            color: pill.done ? Theme.primary : Theme.on_surface_variant
                            RotationAnimation on rotation {
                                running: pill.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.label
                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                            color: pill.done ? Theme.primary : Theme.on_surface
                        }
                    }
                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.triggered()
                    }
                }
                
                Timer { id: closeDelayTimer; interval: 400; onTriggered: { Screenshot.dismiss(); root.activeMode = "dock"; } }
                
                ActionPill {
                    icon: "content_copy"
                    label: "Copy"
                    done: Screenshot.wasCopied
                    onTriggered: { Screenshot.copyToClipboard(); closeDelayTimer.start(); }
                }
                ActionPill {
                    icon: "save"
                    label: "Save"
                    done: Screenshot.wasSaved
                    onTriggered: { Screenshot.save(); closeDelayTimer.start(); }
                }
                ActionPill {
                    icon: "edit"
                    label: "Draw"
                    onTriggered: { Screenshot.editorActive = true; root.activeMode = "dock"; }
                }
                ActionPill {
                    icon: "text_fields"
                    label: "OCR Text"
                    done: Screenshot.wasOcred
                    busy: Screenshot.ocring
                    onTriggered: Screenshot.ocr()
                }
            }
        }
    }
    
    Component {
        id: recordingComp
        Row {
            spacing: 12
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "videocam"
                    color: Theme.critical
                    font.pixelSize: 16
                }
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Screen recording saved"
                color: "#ffffff"
                font.family: "Google Sans Medium"
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
    
    Component {
        id: batteryComp
        Row {
            spacing: 12
            
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "battery_alert"
                    color: Theme.critical
                    font.pixelSize: 16
                }
            }
            
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "Low Battery"
                    color: "#ffffff"
                    font.family: "Google Sans Medium"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: root.batteryRemaining + "% battery remaining"
                    color: "#bbbbbb"
                    font.family: "Google Sans"
                    font.pixelSize: 12
                }
            }
        }
    }

    // --- Drag Queen (file stash) ---

    property bool _dragQueenDragHover: false
    property bool _dragQueenHasItems: FileStash.count > 0

    Timer {
        id: dragQueenAutoHide
        interval: 400
        onTriggered: {
            if (!root._dragQueenHasItems && !root._dragQueenDragHover && root.activeMode === "drag_queen")
                root.activeMode = "dock";
        }
    }

    on_DragQueenDragHoverChanged: {
        if (!_dragQueenDragHover && !_dragQueenHasItems && root.activeMode === "drag_queen")
            dragQueenAutoHide.restart();
    }

    on_DragQueenHasItemsChanged: {
        if (_dragQueenHasItems && root.activeMode === "dock")
            root.activeMode = "drag_queen";
        else if (!_dragQueenHasItems && root.activeMode === "drag_queen" && !_dragQueenDragHover)
            dragQueenAutoHide.restart();
    }

    Component {
        id: dragQueenComp
        Item {
            id: dqRoot

            readonly property real cardWidth: 104
            readonly property real cardHeight: 116
            readonly property real cardSpacing: 10
            readonly property real maxTrayWidth: 540
            readonly property real contentWidth: FileStash.count > 0 
                ? Math.min(maxTrayWidth, FileStash.count * (cardWidth + cardSpacing) - cardSpacing)
                : 280

            implicitWidth: Math.max(320, contentWidth + 28)
            implicitHeight: FileStash.count > 0 ? 170 : 128

            Column {
                id: mainColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // --- HEADER BAR ---
                Item {
                    id: headerBar
                    width: parent.width
                    height: 26

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: Qt.rgba(0.96, 0.35, 0.65, 0.18)
                            border.color: Qt.rgba(0.96, 0.35, 0.65, 0.35)
                            border.width: 1

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "move_to_inbox"
                                font.pixelSize: 14
                                color: "#F472B6"
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Drag Queen"
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: countText.implicitWidth + 10
                            height: 18
                            radius: 9
                            color: Theme.surface_container_highest
                            border.color: Theme.outline_variant
                            border.width: 1

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: FileStash.count + (FileStash.count === 1 ? " item" : " items")
                                font.family: "Google Sans"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Theme.on_surface_variant
                            }
                        }
                    }

                    // Header Quick Actions (Copy All, Clear)
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        visible: FileStash.count > 0

                        property bool copiedFeedback: false

                        Timer {
                            id: copyTimer
                            interval: 1500
                            onTriggered: parent.copiedFeedback = false
                        }

                        // Copy All Pill Button
                        Rectangle {
                            width: copyRow.implicitWidth + 14
                            height: 24
                            radius: 12
                            color: copyMouse.containsMouse 
                                ? Theme.surface_container_highest 
                                : Theme.surface_container_high
                            border.color: parent.copiedFeedback ? "#10B981" : Theme.outline_variant
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Row {
                                id: copyRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: parent.parent.parent.copiedFeedback ? "check" : "content_copy"
                                    font.pixelSize: 12
                                    color: parent.parent.parent.copiedFeedback ? "#10B981" : Theme.on_surface_variant
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.parent.copiedFeedback ? "Copied" : "Copy All"
                                    font.family: "Google Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: parent.parent.parent.copiedFeedback ? "#10B981" : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: copyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (FileStash.copyAllPaths()) {
                                        parent.parent.copiedFeedback = true;
                                        copyTimer.restart();
                                    }
                                }
                            }
                        }

                        // Clear Stash Button
                        Rectangle {
                            width: clearRow.implicitWidth + 12
                            height: 24
                            radius: 12
                            color: clearMouse.containsMouse 
                                ? Qt.rgba(0.9, 0.2, 0.2, 0.18) 
                                : Theme.surface_container_high
                            border.color: clearMouse.containsMouse 
                                ? Qt.rgba(0.9, 0.2, 0.2, 0.4) 
                                : Theme.outline_variant
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Row {
                                id: clearRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "delete_sweep"
                                    font.pixelSize: 13
                                    color: clearMouse.containsMouse ? "#EF4444" : Theme.on_surface_variant
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Clear"
                                    font.family: "Google Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: clearMouse.containsMouse ? "#EF4444" : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    FileStash.clear();
                                    if (root.activeMode === "drag_queen") {
                                        root.activeMode = "dock";
                                    }
                                }
                            }
                        }
                    }
                }

                // --- EMPTY STATE / DROP TARGET BANNER ---
                Rectangle {
                    width: parent.width
                    height: 74
                    radius: 14
                    visible: FileStash.count === 0
                    color: root._dragQueenDragHover 
                        ? Qt.rgba(0.96, 0.35, 0.65, 0.15) 
                        : Theme.surface_container_low
                    border.color: root._dragQueenDragHover 
                        ? "#F472B6" 
                        : Theme.outline_variant
                    border.width: root._dragQueenDragHover ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38
                            radius: 19
                            color: Theme.surface_container_highest

                            MaterialIcon {
                                id: dropIcon
                                anchors.centerIn: parent
                                icon: "file_download"
                                font.pixelSize: 20
                                color: "#F472B6"

                                SequentialAnimation on anchors.verticalCenterOffset {
                                    running: root._dragQueenDragHover
                                    loops: Animation.Infinite
                                    NumberAnimation { to: -3; duration: 400; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 3; duration: 400; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: root._dragQueenDragHover ? "Release to Stash Files" : "Drop Files Here to Stash"
                                font.family: "Google Sans"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }

                            Text {
                                text: "Keep files handy for quick drag & drop"
                                font.family: "Google Sans"
                                font.pixelSize: 10
                                color: Theme.on_surface_variant
                            }
                        }
                    }
                }

                // --- STASHED ITEMS LISTVIEW TRAY ---
                Item {
                    width: parent.width
                    height: dqRoot.cardHeight
                    visible: FileStash.count > 0

                    ListView {
                        id: stashListView
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: dqRoot.cardSpacing
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: FileStash.items

                        delegate: Item {
                            id: chipRoot

                            required property int index
                            required property string path
                            required property string url
                            required property string name
                            required property string glyph
                            required property bool isImage
                            property string category: model.category || FileStash.typeCategory(name)
                            property string accentColor: model.accentColor || FileStash.accentColor(name)
                            property string tag: model.tag || FileStash.categoryTag(name)

                            width: dqRoot.cardWidth
                            height: dqRoot.cardHeight

                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.proposedAction: Qt.CopyAction
                            Drag.mimeData: {
                                "text/uri-list": chipRoot.url,
                                "text/plain": chipRoot.path
                            }
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            // Card Outer Background
                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                radius: 14
                                color: cardMouse.containsMouse || chipRoot.Drag.active
                                    ? Theme.surface_container_highest
                                    : Theme.surface_container_high
                                border.color: cardMouse.containsMouse 
                                    ? chipRoot.accentColor 
                                    : Qt.rgba(1, 1, 1, 0.08)
                                border.width: cardMouse.containsMouse ? 1.5 : 1

                                opacity: chipRoot.Drag.active ? 0.6 : 1.0
                                scale: chipRoot.Drag.active ? 0.95 : 1.0

                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                                Column {
                                    z: 1
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 5

                                    // Preview Frame
                                    Item {
                                        width: parent.width
                                        height: 70

                                        // Image or Gradient Icon Box
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            color: Theme.surface_container_lowest 
                                            border.color: Theme.surface_container_high
                                            border.width: 1

                                            // Image Thumbnail
                                            Image {
                                                id: thumb
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                visible: chipRoot.isImage
                                                source: chipRoot.isImage ? ("file://" + chipRoot.path) : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                sourceSize: Qt.size(200, 200)
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: ShaderEffectSource {
                                                        sourceItem: Rectangle {
                                                            width: thumb.width
                                                            height: thumb.height
                                                            radius: 9
                                                        }
                                                    }
                                                }
                                            }

                                            // Material Icon for Non-Images or Image Loading
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                visible: !chipRoot.isImage || thumb.status !== Image.Ready
                                                icon: chipRoot.glyph
                                                font.pixelSize: 26
                                                color: chipRoot.accentColor
                                            }

                                            // Top Right File Category Tag Badge
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 4
                                                width: tagText.implicitWidth + 6
                                                height: 14
                                                radius: 4
                                                color: Qt.rgba(0, 0, 0, 0.7)
                                                border.color: chipRoot.accentColor
                                                border.width: 1

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: chipRoot.tag
                                                    font.family: "Google Sans"
                                                    font.pixelSize: 7
                                                    font.weight: Font.Bold
                                                    color: chipRoot.accentColor
                                                }
                                            }
                                        }

                                        // Hover Glass Action Overlay (Open, Copy, Remove)
                                        Rectangle {
                                            id: actionOverlay
                                            anchors.fill: parent
                                            radius: 10
                                            color: Qt.rgba(0.05, 0.05, 0.08, 0.85)
                                            opacity: (cardMouse.containsMouse || openBtnMouse.containsMouse || copyBtnMouse.containsMouse || removeBtnMouse.containsMouse) && !chipRoot.Drag.active ? 1.0 : 0.0

                                            Behavior on opacity { NumberAnimation { duration: 120 } }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 5

                                                // Open File Button
                                                Rectangle {
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: openBtnMouse.containsMouse ? Theme.primary : Theme.surface_container_highest

                                                    MaterialIcon {
                                                        anchors.centerIn: parent
                                                        icon: "open_in_new"
                                                        font.pixelSize: 11
                                                        color: openBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: openBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: FileStash.openFile(chipRoot.path)
                                                    }
                                                }

                                                // Copy Path Button
                                                Rectangle {
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: copyBtnMouse.containsMouse ? Theme.primary : Theme.surface_container_highest

                                                    MaterialIcon {
                                                        anchors.centerIn: parent
                                                        icon: "content_copy"
                                                        font.pixelSize: 11
                                                        color: copyBtnMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: copyBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: FileStash.copyPath(chipRoot.path)
                                                    }
                                                }

                                                // Remove Button
                                                Rectangle {
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: removeBtnMouse.containsMouse ? "#EF4444" : Theme.surface_container_highest

                                                    MaterialIcon {
                                                        anchors.centerIn: parent
                                                        icon: "close"
                                                        font.pixelSize: 12
                                                        color: removeBtnMouse.containsMouse ? "#FFFFFF" : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: removeBtnMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: FileStash.removePath(chipRoot.path)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Filename Label
                                    Text {
                                        width: parent.width
                                        text: chipRoot.name
                                        font.family: "Google Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        color: Theme.on_surface
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 1
                                    }
                                }

                                // Interactive Drag & Click Area
                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: chipRoot.Drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    acceptedButtons: Qt.LeftButton

                                    property real pressX: 0
                                    property real pressY: 0

                                    onPressed: function (mouse) {
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                    }

                                    onPositionChanged: function (mouse) {
                                        if (!chipRoot.Drag.active && pressed) {
                                            if (Math.abs(mouse.x - pressX) > 6 || Math.abs(mouse.y - pressY) > 6) {
                                                chipRoot.Drag.active = true;
                                            }
                                        }
                                    }

                                    onReleased: function (mouse) {
                                        if (chipRoot.Drag.active) {
                                            chipRoot.Drag.active = false;
                                        }
                                    }

                                    onDoubleClicked: {
                                        FileStash.openFile(chipRoot.path);
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
