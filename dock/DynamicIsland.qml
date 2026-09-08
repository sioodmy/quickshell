import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.theme
import qs.services
import qs.components
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "calendar"
import "island"

Item {
    Connections {
        target: KeepassBackend
        function onEntrySelected(entry) {
            root.keepassEntry = entry;
            root.activeMode = "keepass";
        }
    }

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
    property var keepassEntry: null

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

    property string lastSinkDesc: ""
    property bool speakerWarningInitialized: false

    onActiveSinkChanged: checkSpeakerWarning()

    readonly property string currentSinkDesc: activeSink?.description ?? ""
    onCurrentSinkDescChanged: checkSpeakerWarning()

    function checkSpeakerWarning() {
        if (!root.activeSink) return;
        var currentDesc = root.activeSink.description || "";
        
        if (!speakerWarningInitialized) {
            if (currentDesc !== "") {
                lastSinkDesc = currentDesc;
                speakerWarningInitialized = true;
            }
            return;
        }

        if (currentDesc === lastSinkDesc || currentDesc === "") return;
        
        lastSinkDesc = currentDesc;
        
        if (currentDesc.toLowerCase().indexOf("speakers") !== -1) {
            Quickshell.execDetached({ command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"] });
            root.activeMode = "speaker_warning";
        }
    }


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
                if (root.activeMode === "keepass") return keepassComp;
                if (root.activeMode === "speaker_warning") return speakerWarningComp;
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
        id: keepassComp
        IslandKeepass {
            entry: root.keepassEntry
            onCloseRequested: {
                root.activeMode = "dock";
                root.keepassEntry = null;
            }
        }
    }


    Component {
        id: chargingComp
        IslandCharging {
            osdDockWidth: root.osdDockWidth
            osdDockHeight: root.osdDockHeight
        }
    }

    Component {
        id: osdComp
        IslandOsd {
            osdDockWidth: root.osdDockWidth
            osdDockHeight: root.osdDockHeight
            osdProgress: root.osdProgress
            osdIcon: root.osdIcon
            osdTitle: root.osdTitle
            osdText: root.osdText
            osdColor: root.osdColor
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
        id: speakerWarningComp
        IslandSpeakerWarning {
            onDismissed: root.activeMode = "dock"
        }
    }

    Component {
        id: polkitComp
        IslandPolkit {
            message: root.polkitMessage
            iconName: root.polkitIcon
            cookie: root.polkitCookie
            userName: root.polkitUserName
            prompt: root.polkitPrompt
            hasError: root.polkitError
            isYubikey: root.polkitYubikey
            onCancelRequested: {
                BackendDaemon.polkitCancel(root.polkitCookie);
                root.activeMode = "dock";
            }
            onSubmitRequested: function(password) {
                BackendDaemon.polkitSubmit(root.polkitCookie, password);
            }
        }
    }

    Component {
        id: emptyComp
        Item {
            implicitWidth: 0
            implicitHeight: 0
        }
    }

    Component {
        id: notifComp
        IslandNotification {
            notification: root.currentNotification
            onDismissed: root.activeMode = "dock"
        }
    }

    Component {
        id: screenshotComp
        IslandScreenshot {
            onFinished: {
                if (root.activeMode === "screenshot") root.activeMode = "dock";
            }
        }
    }

    Component {
        id: screenshotResultComp
        IslandScreenshotResult {
            onDismissed: root.activeMode = "dock"
        }
    }

    Component {
        id: recordingComp
        IslandRecording {}
    }

    Component {
        id: batteryComp
        IslandBattery {
            batteryRemaining: root.batteryRemaining
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
        IslandDragQueen {
            dragHover: root._dragQueenDragHover
            onRequestClose: {
                if (root.activeMode === "drag_queen") root.activeMode = "dock";
            }
        }
    }

}
