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
                
                Rectangle {
                    id: iconRect
                width: 32
                height: 32
                radius: 16
                color: Theme.primary_container
                anchors.verticalCenter: parent.verticalCenter
                
                property string appIconSrc: {
                    var n = root.currentNotification;
                    if (!n) return "";
                    if (n.image && n.image.length > 0) return n.image;
                    if (n.appIcon && n.appIcon.length > 0) return Quickshell.iconPath(n.appIcon, true) || "";
                    return "";
                }
                
                Image {
                    anchors.fill: parent
                    source: parent.appIconSrc
                    fillMode: Image.PreserveAspectCrop
                    visible: parent.appIconSrc !== ""
                    sourceSize: Qt.size(64, 64)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: maskRect
                    }
                }
                
                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: parent.radius
                    visible: false
                }
                
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: parent.appIconSrc === ""
                    icon: "notifications"
                    color: Theme.on_primary_container
                    font.pixelSize: 16
                }
            }
            
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
}
