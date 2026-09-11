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
            if (!KeepassBackend.isUnlocked || SessionState.locked) return;
            keepassEntryRelease.stop();
            root.keepassEntry = entry;
            root.activeMode = "keepass";
        }
        function onLocked() {
            root.keepassEntry = null;
            if (root.activeMode === "keepass") root.activeMode = "dock";
        }
    }

    id: root
    
    // Explicit sizing for Dock.qml to animate notchBg
    implicitWidth: morph.implicitWidth
    implicitHeight: morph.implicitHeight

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

    // OSD state — inlined into the dock (progress fill + icon pop).
    // Never takes over activeMode so dock widgets stay visible.
    property bool osdVisible: false
    property real osdDockWidth: 300
    property real osdDockHeight: 42
    property string osdType: "volume" // "volume" or "brightness"
    property real osdProgress: 0.0
    property string osdIcon: "volume_up"
    property int osdSeq: 0
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
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    onActiveModeChanged: {
        if (root.activeMode !== "dock")
            root.osdVisible = false;
    }

    Connections {
        target: LauncherState
        function onOpenChanged() {
            if (LauncherState.open)
                root.osdVisible = false;
        }
    }

    Connections {
        target: KeepassState
        function onOpenChanged() {
            if (KeepassState.open)
                root.osdVisible = false;
        }
    }

    function osdAllowed() {
        if (root.activeMode !== "dock")
            return false;
        if (LauncherState.open)
            return false;
        if (KeepassState.open)
            return false;
        return true;
    }

    function triggerVolumeOsd() {
        if (!audioInitialized) {
            audioInitialized = true;
            return;
        }
        if (!osdAllowed())
            return;
        root.osdType = "volume";
        root.osdProgress = isMuted ? 0 : Math.min(1.0, Math.max(0.0, volumeLevel));
        root.osdIcon = isMuted ? "volume_off" : (volumeLevel > 0.5 ? "volume_up" : (volumeLevel > 0 ? "volume_down" : "volume_mute"));
        root.osdVisible = true;
        root.osdSeq++;
        osdTimer.restart();
    }

    function triggerBrightnessOsd() {
        if (!brightnessInitialized) {
            brightnessInitialized = true;
            return;
        }
        if (!osdAllowed())
            return;
        var val = Brightness.value;
        root.osdType = "brightness";
        root.osdProgress = Math.min(1.0, Math.max(0.0, val));
        root.osdIcon = val >= 0.7 ? "brightness_7" : (val >= 0.3 ? "brightness_5" : "brightness_6");
        root.osdVisible = true;
        root.osdSeq++;
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
    
    // Mode whose content is actually built and on screen. `activeMode` is the
    // request; this lags it while a heavy island incubates. Dock geometry keys
    // off this so the notch never expands around content that isn't there yet.
    readonly property string displayMode: morph.displayedKey

    // API for Dock.qml to check if it should hide normal content
    readonly property bool isDockHidden: displayMode !== "dock"
    // Claim the keyboard on request and hold it through the closing fade, so
    // focus is never dropped while the prompt is still visible.
    readonly property bool requiresKeyboard: (activeMode === "polkit" || displayMode === "polkit") && !polkitYubikey
    
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
            } else if (root.activeMode === "screenshot") {
                // Capture is in flight (or already ready) — morph straight into
                // the result island instead of flashing dock chrome.
                if (Screenshot.awaitingCapture || Screenshot.active)
                    root.activeMode = "screenshot_result";
                else
                    root.activeMode = "dock";
            }
        }
        
        function onActiveChanged() {
            if (Screenshot.active) {
                root.activeMode = "screenshot_result";
                notificationTimer.restart();
            } else if (root.activeMode === "screenshot_result" && !Screenshot.awaitingCapture) {
                root.activeMode = "dock";
            }
        }

        function onAwaitingCaptureChanged() {
            if (!Screenshot.awaitingCapture && !Screenshot.active && root.activeMode === "screenshot_result")
                root.activeMode = "dock";
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
    IslandMorph {
        id: morph
        anchors.centerIn: parent
        requestedKey: root.activeMode
        resolve: root.componentForMode
    }

    // Returning null for "dock" lets the morph collapse without incubating an
    // empty placeholder tree.
    function componentForMode(mode) {
        switch (mode) {
        case "notification": return notifComp;
        case "screenshot": return screenshotComp;
        case "battery": return batteryComp;
        case "screenshot_result": return screenshotResultComp;
        case "recording": return recordingComp;
        case "polkit": return polkitComp;
        case "keepass": return keepassComp;
        case "speaker_warning": return speakerWarningComp;
        case "calendar": return calendarComp;
        case "charging": return chargingComp;
        case "drag_queen": return dragQueenComp;
        default: return null;
        }
    }

    // --- Components ---
    // The entry outlives the mode change: clearing it on the spot would blank
    // the island while it is still fading out. Lock clears immediately.
    Timer {
        id: keepassEntryRelease
        interval: 260
        onTriggered: if (root.activeMode !== "keepass") root.keepassEntry = null
    }

    Component {
        id: keepassComp
        IslandKeepass {
            entry: root.keepassEntry
            onCloseRequested: {
                root.activeMode = "dock";
                keepassEntryRelease.restart();
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
            dockDragHover: root._dragQueenDragHover
            onLocalDragHoverChanged: {
                if (localDragHover)
                    root._dragQueenDragHover = true;
            }
            onRequestClose: {
                if (root.activeMode === "drag_queen") root.activeMode = "dock";
            }
        }
    }

}
