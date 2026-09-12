import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../../theme"
import qs.services
import qs.components

PanelWindow {
    id: launcherWindow

    // Add any apps you want to hide to this list
    property var hiddenKeywords: ["avahi", "uuctl", "bssh", "bvnc"]

    // Track whether a file result is currently selected for preview
    property bool hasFileSelected: false
    property var selectedFileData: null
    property real fileSplitBlend: 0
    property real musicSplitBlend: 0
    readonly property real activeSplitBlend: Math.max(fileSplitBlend, musicSplitBlend)
    property bool shareModeActive: false
    property var shareData: null
    property real shareViewBlend: 0
    property var wolframResultObj: null

    readonly property string trimmedQuery: ctrl.searchText.trim()
    readonly property string normalizedQuery: trimmedQuery.toLowerCase()

    readonly property bool weatherModeActive: normalizedQuery === "weather"
    readonly property bool colorPickerModeActive: ctrl.isColorPickerQuery(trimmedQuery)
    readonly property var connectivityQuery: parseConnectivityQuery(trimmedQuery)
    readonly property var musicQuery: parseMusicQuery(trimmedQuery)
    readonly property bool btModeActive: connectivityQuery && connectivityQuery.mode === "bt"
    readonly property bool wifiModeActive: connectivityQuery && connectivityQuery.mode === "wifi"
    readonly property bool connectivityModeActive: btModeActive || wifiModeActive
    readonly property bool musicModeActive: musicQuery !== null

    readonly property var sliderQuery: parseSliderQuery(trimmedQuery)
    readonly property bool volSliderActive: sliderQuery && sliderQuery.mode === "vol"
    readonly property bool blSliderActive: sliderQuery && sliderQuery.mode === "bl"
    readonly property bool sliderModeActive: volSliderActive || blSliderActive
    readonly property bool sliderHasValue: sliderModeActive && sliderQuery.value >= 0

    readonly property var nightQuery: parseNightQuery(trimmedQuery)
    readonly property bool nightModeActive: nightQuery !== null

    readonly property var dndQuery: parseDndQuery(trimmedQuery)
    readonly property bool dndModeActive: dndQuery !== null

    readonly property var pomQuery: parsePomQuery(trimmedQuery)
    readonly property bool pomModeActive: pomQuery !== null

    readonly property var clipQuery: parseClipQuery(trimmedQuery)
    readonly property bool clipModeActive: clipQuery !== null

    readonly property var ssQuery: parseSsQuery(trimmedQuery)
    readonly property bool ssModeActive: ssQuery !== null

    readonly property var recQuery: parseRecQuery(trimmedQuery)
    readonly property bool recModeActive: recQuery !== null

    readonly property var cocQuery: parseCocQuery(trimmedQuery)
    readonly property bool cocModeActive: cocQuery !== null


    readonly property var bringQuery: parseBringQuery(trimmedQuery)
    readonly property bool bringModeActive: bringQuery !== null

    readonly property bool captureModeActive: ssModeActive || recModeActive

    property int appActionIndex: -1
    // While true, filtering keeps the best match selected at index 0 and does not
    // scroll/cycle. Cleared only by Tab/arrows or mouse hover selection.
    property bool pinSelectionToBest: true

    readonly property bool specialViewActive: weatherModeActive || colorPickerModeActive || connectivityModeActive || musicModeActive || nightModeActive || clipModeActive

    readonly property var pipewireSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: launcherWindow.pipewireSink ? [launcherWindow.pipewireSink] : [] }

    onHasFileSelectedChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onWeatherModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onColorPickerModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
    onNightModeActiveChanged: fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0

    onClipModeActiveChanged: {
        fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0;
        if (clipModeActive && contentLoader.item)
            contentLoader.item.refreshClipboard();
    }
    onMusicModeActiveChanged: {
        fileSplitBlend = (hasFileSelected && !specialViewActive) ? 1 : 0
        syncMusicSplitBlend()
        if (musicModeActive && !BackendDaemon.musicLibrary)
            BackendDaemon.send({ action: "music_library" });
    }

    function syncMusicSplitBlend() {
        musicSplitBlend = (musicModeActive && BackendDaemon.musicState.hasPlayer) ? 1 : 0
    }

    // File preview split is instant for snappiness (no animation)

    Behavior on musicSplitBlend {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    Connections {
        target: BackendDaemon
        function onMusicStateChanged() {
            launcherWindow.syncMusicSplitBlend()
        }
    }

    Connections {
        target: LauncherState
        function onDockWidthChanged() { launcherWindow.syncBlurRegion() }
        function onDockHeightChanged() { launcherWindow.syncBlurRegion() }
        function onCloseRequested() {
            if (launcherWindow.menuOpen || launcherWindow.openProgress > 0)
                launcherWindow.closeMenu();
        }
    }

    onShareModeActiveChanged: shareViewBlend = shareModeActive ? 1 : 0
    Behavior on shareViewBlend {
        NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
    }

    Connections {
        target: BackendDaemon
        function onFileShareReady(data) {
            if (data.error) {
                shareModeActive = false;
                shareData = null;
                return;
            }
            shareData = data;
            shareModeActive = true;
        }
    }

    property real openProgress: 0.0
    property bool menuOpen: false
    // Geometry reveal is separate from mapped state. This lets the lightweight
    // clip shell animate while the expensive launcher layout stays fixed.
    property bool panelExpanded: false
    // When true, we want to open but are waiting for LazyLoader content to load.
    property bool _pendingOpen: false
    // Set once this surface has presented a frame since being mapped.
    property bool _framePresented: false
    // A result rebuild that was queued while closed and held back so it cannot
    // run on the GUI thread during the reveal.
    property bool _rebuildAfterReveal: false
    property string bluetoothConnectedDeviceLabel: ""

    property var _debouncedResults: []

    Timer {
        id: filterDebounce
        interval: 50
        onTriggered: {
            // buildFilteredList() blocks the GUI thread long enough to be seen
            // as a stutter, so it never runs inside the reveal animation.
            if (openAnim.running) {
                launcherWindow._rebuildAfterReveal = true;
                return;
            }
            launcherWindow._debouncedResults = launcherWindow.buildFilteredList();
        }
    }

    onTrimmedQueryChanged: filterDebounce.restart()

    Connections {
        target: ctrl
        function onFileSearchResultsChanged() { filterDebounce.restart() }
        function onBookmarkSearchResultsChanged() { filterDebounce.restart() }
        function onAppFrequenciesChanged() { filterDebounce.restart() }
        function onAppSearchResultsChanged() { filterDebounce.restart() }
    }

    Connections {
        target: ScreenRecord
        function onRecordingChanged() { filterDebounce.restart() }
        function onRecordAudioChanged() { filterDebounce.restart() }
    }

    Connections {
        target: DoNotDisturb
        function onEnabledChanged() { filterDebounce.restart() }
    }

    Connections {
        target: Pomodoro
        function onIsRunningChanged() { filterDebounce.restart() }
        function onModeChanged() { filterDebounce.restart() }
        function onCompletedSessionsChanged() { filterDebounce.restart() }
        function onShouldShowChanged() { filterDebounce.restart() }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { filterDebounce.restart() }
    }

    color: "transparent"
    visible: menuOpen || openAnim.running || closeAnim.running

    // A launcher is transient UI: keep it above panels, never reserve work area,
    // and request focus only while this surface is mapped.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Blur region size is mirrored into plain properties (not a self-referential
    // Region binding) — the previous `property panelWidth → width: panelWidth`
    // form logged a binding loop on every open and is a known Qt instability.
    property real blurPanelWidth: Math.max(1, LauncherState.dockWidth)
    property real blurPanelHeight: Math.max(1, LauncherState.dockHeight)

    function syncBlurRegion() {
        if (contentLoader.item) {
            blurPanelWidth = Math.max(1, contentLoader.item.width);
            blurPanelHeight = Math.max(1, contentLoader.item.height);
        } else {
            blurPanelWidth = Math.max(1, LauncherState.dockWidth);
            blurPanelHeight = Math.max(1, LauncherState.dockHeight);
        }
    }

    // The launcher surface is fullscreen for click-away dismissal, but only
    // this explicit rectangle is submitted to ext-background-effect-v1.
    // Do not also force blur with a niri layer rule: that applies to the whole
    // fullscreen surface and overrides the protocol-defined region.
    BackgroundEffect.blurRegion: Region {
        x: Math.round((launcherWindow.width - launcherWindow.blurPanelWidth) / 2)
        y: 0
        width: launcherWindow.blurPanelWidth
        height: launcherWindow.blurPanelHeight
        // Region only exposes a uniform radius in this Quickshell build.
        // Keep it square so blur does not spill past the flush top edge.
        radius: 0
    }

    // The reveal must start on the frame this surface first reaches the screen.
    // Kicking it off from openMenu() instead lets these wall-clock animations
    // burn through while the surface is still being mapped and its first polish
    // builds the result delegates — exactly the work that gets slow under load.
    // The first visible frame then lands mid-animation and the panel pops in at
    // near-full size. Measured at ~47ms on an idle machine, i.e. three frames
    // of the reveal already gone before anything is on screen.

    // Draws nothing. It exists only to give grabToImage something to grab.
    Item {
        id: frameProbe
        width: 1
        height: 1
    }

    // grabToImage's callback runs after this window has rendered, which is the
    // only "we are on screen" signal available: PanelWindow does not expose the
    // backing QQuickWindow, and backingWindowVisible flips synchronously on
    // map, well before the first frame.
    function _armRevealProbe() {
        var started = frameProbe.grabToImage(function () {
            launcherWindow._onFramePresented();
        }, Qt.size(1, 1));
        if (!started) {
            // No frame signal to wait for; reveal as the old code did.
            _framePresented = true;
            _maybeBeginReveal();
            return;
        }
        revealFallback.restart();
    }

    // Insurance: never leave the launcher stuck invisible if no frame arrives.
    Timer {
        id: revealFallback
        interval: 400
        onTriggered: {
            launcherWindow._framePresented = true;
            launcherWindow._maybeBeginReveal();
        }
    }

    function _onFramePresented() {
        if (_framePresented || !menuOpen)
            return;
        _framePresented = true;
        _maybeBeginReveal();
    }

    // Needs both halves: the content tree built, and the surface on screen.
    function _maybeBeginReveal() {
        if (!menuOpen || _pendingOpen || !_framePresented)
            return;
        if (openAnim.running || openProgress > 0)
            return;
        revealFallback.stop();
        panelExpanded = true;
        if (contentLoader.item)
            contentLoader.item.focusSearch();
        openAnim.start();
    }

    NumberAnimation {
        id: openAnim
        target: launcherWindow
        property: "openProgress"
        from: 0; to: 1
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: {
            LauncherState.openProgress = 1.0;
            if (launcherWindow._rebuildAfterReveal) {
                launcherWindow._rebuildAfterReveal = false;
                filterDebounce.restart();
            }
        }
    }

    NumberAnimation {
        id: closeAnim
        target: launcherWindow
        property: "openProgress"
        // No `from`: closing before the reveal has started must not snap the
        // panel to full size just to animate it back down.
        to: 0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: {
            launcherWindow.menuOpen = false;
            launcherWindow._framePresented = false;
            launcherWindow._rebuildAfterReveal = false;
            LauncherState.open = false;
            LauncherState.openProgress = 0.0;
            LauncherState.screen = null;
            // Prepare the default view while hidden so the next open does not
            // rebuild the result model during its animation.
            ctrl.clearStates();
            if (contentLoader.item)
                contentLoader.item.clearSearch();
            launcherWindow.pinSelectionToBest = true;
            filterDebounce.restart();
        }
    }

    onPanelExpandedChanged: syncBlurRegion()
    onOpenProgressChanged: {
        LauncherState.openProgress = openProgress;
        syncBlurRegion();
    }

    // Ensure the notification appears right after the launcher has closed.
    Timer {
        id: bluetoothConnectedNotifTimer
        interval: 170
        repeat: false
        running: false
        onTriggered: {
            if (!bluetoothConnectedDeviceLabel)
                return;
            Quickshell.execDetached({
                command: [
                    "notify-send",
                    "-a", "Quickshell",
                    "-u", "normal",
                    "-t", "800",
                    "Bluetooth",
                    "Connected to " + bluetoothConnectedDeviceLabel
                ]
            });
            bluetoothConnectedDeviceLabel = "";
        }
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.closeMenu()
    }

    // Keep the visible list small — uncapped matches flood ListView with heavy delegates.
    readonly property int maxEmptyApps: 12
    readonly property int maxAppResults: 8
    readonly property int maxMusicResults: 5
    readonly property int maxFileResults: 8
    readonly property int maxEmojiResults: 6

    // queryLower must already be lowercased; queryLen avoids re-reading the string.
    function scoreMatch(text, queryLower, queryLen) {
        if (!text)
            return -1;
        var textLower = text.toString().toLowerCase();

        // Exact match
        if (textLower === queryLower)
            return 1000;

        // Full string starts with query
        if (textLower.startsWith(queryLower))
            return 800;

        // Any word in the string starts with query
        if (textLower.indexOf(" " + queryLower) !== -1 || textLower.indexOf("-" + queryLower) !== -1 || textLower.indexOf("_" + queryLower) !== -1)
            return 600;

        // single/double letter matches polluting short queries
        if (queryLen >= 3 && textLower.indexOf(queryLower) !== -1)
            return 200;

        return -1;
    }

    function parseConnectivityQuery(query) {
        var q = query.trim().toLowerCase();
        if (q.startsWith("bluetooth"))
            return { mode: "bt", filter: q.substring(9).trim() };
        if (q.startsWith("bt"))
            return { mode: "bt", filter: q.substring(2).trim() };
        if (q.startsWith("wifi"))
            return { mode: "wifi", filter: q.substring(4).trim() };
        if (q.startsWith("net"))
            return { mode: "wifi", filter: q.substring(3).trim() };
        return null;
    }

    function parseBringQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "bring" && !q.startsWith("bring "))
            return null;
        var rest = q === "bring" ? "" : query.trim().substring(6).trim();
        return { filter: rest };
    }

    function parseSliderQuery(query) {
        var q = query.trim().toLowerCase();
        if (q === "vol" || q.startsWith("vol ")) {
            var rest = q === "vol" ? "" : q.substring(4).trim();
            if (rest === "" || rest === "mute")
                return { mode: "vol", value: -1, mute: rest === "mute" };
            var num = parseInt(rest);
            if (!isNaN(num) && num >= 0 && num <= 100)
                return { mode: "vol", value: num, mute: false };
            return { mode: "vol", value: -1, mute: false };
        }
        if (q === "bl" || q.startsWith("bl ")) {
            var rest = q === "bl" ? "" : q.substring(3).trim();
            if (rest === "")
                return { mode: "bl", value: -1, mute: false };
            var num = parseInt(rest);
            if (!isNaN(num) && num >= 0 && num <= 100)
                return { mode: "bl", value: num, mute: false };
            return { mode: "bl", value: -1, mute: false };
        }
        return null;
    }



    function parseMusicQuery(query) {
        var q = query.trim().toLowerCase();
        if (!q.startsWith("music"))
            return null;
        var rest = q.substring(5).trim();
        var commands = ["stop", "pause", "play", "resume", "next", "prev", "previous"];
        if (commands.indexOf(rest) !== -1)
            return { filter: "", command: rest };

        var volMatch = rest.match(/^(?:vol|volume)\s+(\d+)$/);
        if (volMatch) {
            var num = parseInt(volMatch[1]);
            if (!isNaN(num) && num >= 0 && num <= 100)
                return { filter: "", command: "vol", value: num };
        }

        return { filter: rest, command: null };
    }

    function parseNightQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "night" && !q.startsWith("night "))
            return null;
        var rest = q === "night" ? "" : q.substring(6).trim();
        if (rest === "")
            return { command: null, value: -1 };
        if (rest === "on")
            return { command: "on", value: -1 };
        if (rest === "off")
            return { command: "off", value: -1 };
        if (rest === "toggle")
            return { command: "toggle", value: -1 };
        var num = parseInt(rest);
        if (!isNaN(num) && num >= 0 && num <= 100)
            return { command: "set", value: num };
        return { command: null, value: -1 };
    }

    function parseDndQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "dnd" && !q.startsWith("dnd "))
            return null;
        var rest = q === "dnd" ? "" : q.substring(4).trim();
        if (rest === "")
            return { command: null };
        if (rest === "on" || rest === "enable")
            return { command: "on" };
        if (rest === "off" || rest === "disable")
            return { command: "off" };
        if (rest === "toggle")
            return { command: "toggle" };
        return { command: null };
    }

    function parseCocQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "cocaine" && !q.startsWith("cocaine ") && q !== "caffeine" && !q.startsWith("caffeine "))
            return null;
        var rest = "";
        if (q.startsWith("cocaine ")) rest = q.substring(8).trim();
        else if (q.startsWith("caffeine ")) rest = q.substring(9).trim();

        if (rest === "")
            return { command: null };
        if (rest === "on" || rest === "enable")
            return { command: "on" };
        if (rest === "off" || rest === "disable")
            return { command: "off" };
        if (rest === "toggle")
            return { command: "toggle" };
        return { command: null };
    }

    function parsePomQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "pom" && q !== "pomodoro" && !q.startsWith("pom ") && !q.startsWith("pomodoro "))
            return null;

        var rest = "";
        if (q.startsWith("pomodoro "))
            rest = q.substring(9).trim();
        else if (q.startsWith("pom "))
            rest = q.substring(4).trim();
        else if (q === "pomodoro" || q === "pom")
            rest = "";

        if (rest === "")
            return { command: null, minutes: -1 };

        if (rest === "start" || rest === "go")
            return { command: "start", minutes: -1 };
        if (rest === "stop" || rest === "pause")
            return { command: "stop", minutes: -1 };
        if (rest === "toggle")
            return { command: "toggle", minutes: -1 };
        if (rest === "reset")
            return { command: "reset", minutes: -1 };
        if (rest === "work" || rest === "focus")
            return { command: "work", minutes: -1 };
        if (rest === "break" || rest === "short")
            return { command: "break", minutes: -1 };
        if (rest === "long")
            return { command: "long", minutes: -1 };

        if (rest.startsWith("+") || rest.startsWith("-")) {
            var adj = parseInt(rest);
            if (!isNaN(adj) && adj !== 0)
                return { command: "adjust", minutes: adj };
        }

        var num = parseInt(rest);
        if (!isNaN(num) && num >= 1 && num <= 120)
            return { command: "set", minutes: num };

        return { command: null, minutes: -1 };
    }

    function parseClipQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "clip" && !q.startsWith("clip "))
            return null;
        var rest = q === "clip" ? "" : query.trim().substring(5).trim();
        return { filter: rest };
    }

    function parseSsQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "ss" && q !== "screenshot" && !q.startsWith("ss ") && !q.startsWith("screenshot "))
            return null;
        var rest = "";
        if (q.startsWith("screenshot "))
            rest = q.substring(11).trim();
        else if (q.startsWith("ss "))
            rest = q.substring(3).trim();
        else if (q === "screenshot" || q === "ss")
            rest = "";

        if (rest === "" || rest === "menu")
            return { command: rest === "menu" ? "menu" : null };
        if (rest === "area" || rest === "region" || rest === "select")
            return { command: "area" };
        if (rest === "full" || rest === "fullscreen" || rest === "screen")
            return { command: "fullscreen" };
        if (rest === "window" || rest === "win")
            return { command: "window" };
        return { command: null };
    }

    function parseRecQuery(query) {
        var q = query.trim().toLowerCase();
        if (q !== "rec" && q !== "record" && !q.startsWith("rec ") && !q.startsWith("record "))
            return null;
        var rest = "";
        if (q.startsWith("record "))
            rest = q.substring(7).trim();
        else if (q.startsWith("rec "))
            rest = q.substring(4).trim();

        if (rest === "")
            return { command: null };
        if (rest === "area" || rest === "region" || rest === "select")
            return { command: "area" };
        if (rest === "full" || rest === "fullscreen" || rest === "screen")
            return { command: "fullscreen" };
        if (rest === "stop" || rest === "end")
            return { command: "stop" };
        if (rest === "audio" || rest === "mic")
            return { command: "audio" };
        return { command: null };
    }

    function executeMusicCommand(mq) {
        var command = typeof mq === "string" ? mq : mq.command;
        if (command === "stop" || command === "pause") {
            if (Playerctl.isPlaying)
                Playerctl.playPause();
        } else if (command === "play" || command === "resume") {
            if (!Playerctl.isPlaying && Playerctl.hasPlayer)
                Playerctl.playPause();
        } else if (command === "next") {
            Playerctl.next();
        } else if (command === "prev" || command === "previous") {
            Playerctl.previous();
        } else if (command === "vol") {
            var val = typeof mq !== "string" ? mq.value : 50;
            MusicService.setVolume(val / 100.0);
        }
    }

    function executeNightCommand() {
        var nq = launcherWindow.nightQuery;
        if (!nq) return;
        if (nq.command === "on") {
            NightLight.enable();
            launcherWindow.closeMenu();
        } else if (nq.command === "off") {
            NightLight.disable();
            launcherWindow.closeMenu();
        } else if (nq.command === "toggle") {
            NightLight.toggle();
            launcherWindow.closeMenu();
        } else if (nq.command === "set" && nq.value >= 0) {
            NightLight.setIntensity(nq.value);
            if (!NightLight.enabled) NightLight.enable();
            launcherWindow.closeMenu();
        }
    }

    function executeDndCommand() {
        var dq = launcherWindow.dndQuery;
        if (!dq || !dq.command) return;
        if (dq.command === "on") {
            DoNotDisturb.enable();
            launcherWindow.closeMenu();
        } else if (dq.command === "off") {
            DoNotDisturb.disable();
            launcherWindow.closeMenu();
        } else if (dq.command === "toggle") {
            DoNotDisturb.toggle();
            launcherWindow.closeMenu();
        }
    }

    function executeCocCommand() {
        var dq = launcherWindow.cocQuery;
        if (!dq || !dq.command) return;
        ctrl.executeSystemCommand("coc_" + dq.command);
    }

    function executePomCommand() {
        var pq = launcherWindow.pomQuery;
        if (!pq || !pq.command) return;

        if (pq.command === "set" && pq.minutes > 0) {
            Pomodoro.setDuration(pq.minutes);
            if (!Pomodoro.isRunning)
                Pomodoro.isRunning = true;
            launcherWindow.closeMenu();
        } else if (pq.command === "start") {
            if (!Pomodoro.isRunning)
                Pomodoro.isRunning = true;
            launcherWindow.closeMenu();
        } else if (pq.command === "stop") {
            Pomodoro.isRunning = false;
            launcherWindow.closeMenu();
        } else if (pq.command === "toggle") {
            Pomodoro.toggle();
            launcherWindow.closeMenu();
        } else if (pq.command === "reset") {
            Pomodoro.reset();
            launcherWindow.closeMenu();
        } else if (pq.command === "work") {
            Pomodoro.setMode(0);
            launcherWindow.closeMenu();
        } else if (pq.command === "break") {
            Pomodoro.setMode(1);
            launcherWindow.closeMenu();
        } else if (pq.command === "long") {
            Pomodoro.setMode(2);
            launcherWindow.closeMenu();
        } else if (pq.command === "adjust" && pq.minutes !== 0) {
            Pomodoro.adjustTime(pq.minutes);
            launcherWindow.closeMenu();
        }
    }

    function buildFilteredList() {
        var allApps = DesktopEntries.applications.values;
        var query = ctrl.searchText.trim();
        var queryLower = query.toLowerCase();
        var queryLen = queryLower.length;

        var results = [];

        // --- App results ---
        if (query === "") {
            // No query: top apps by frecency only — full catalog floods the list
            var sortedApps = allApps.filter(app => {
                if (!app.name)
                    return false;
                var n = app.name.toLowerCase();
                for (var k = 0; k < hiddenKeywords.length; k++) {
                    if (n.includes(hiddenKeywords[k])) return false;
                }
                return true;
            }).sort((a, b) => {
                var freqA = ctrl.appFrequencies[a.id] || 0;
                var freqB = ctrl.appFrequencies[b.id] || 0;
                if (freqB !== freqA)
                    return freqB - freqA;
                return (a.name || "").localeCompare(b.name || "");
            });

            var emptyCap = Math.min(sortedApps.length, launcherWindow.maxEmptyApps);
            for (var i = 0; i < emptyCap; i++) {
                results.push({ type: "app", entry: sortedApps[i] });
            }
            return results;
        }

        if (launcherWindow.connectivityModeActive)
            return [];

        if (launcherWindow.musicModeActive)
            return [];

        if (launcherWindow.nightModeActive)
            return [];

        if (launcherWindow.clipModeActive)
            return [];

        if (launcherWindow.bringModeActive) {
            var bq = launcherWindow.bringQuery;
            var bringResults = ctrl.getBringWindows(bq.filter);
            for (var i = 0; i < bringResults.length; i++) {
                var w = bringResults[i];
                var entry = ctrl.findDesktopEntry(w.appId);
                results.push({
                    type: "focus",
                    actionId: "bring",
                    entry: entry,
                    windowId: w.id,
                    windowTitle: w.title || ""
                });
            }
            if (results.length === 0) {
                results.push({
                    type: "system_command",
                    actionId: "bring_empty",
                    name: "No windows found",
                    description: "No windows on other workspaces match your query.",
                    icon: "󰀹"
                });
            }
            return results;
        }

        if (launcherWindow.dndModeActive) {
            var dq = launcherWindow.dndQuery;
            var dndResults = [];
            if (!dq.command || dq.command === "on")
                dndResults.push({ type: "system_command", actionId: "dnd_on", name: "Enable Do Not Disturb", description: "Silence notification popups", icon: "󰂛" });
            if (!dq.command || dq.command === "off")
                dndResults.push({ type: "system_command", actionId: "dnd_off", name: "Disable Do Not Disturb", description: "Show notification popups again", icon: "󰂚" });
            if (dq.command === "toggle")
                dndResults.push({
                    type: "system_command",
                    actionId: "dnd_toggle",
                    name: DoNotDisturb.enabled ? "Disable Do Not Disturb" : "Enable Do Not Disturb",
                    description: "Toggle notification popups",
                    icon: DoNotDisturb.enabled ? "󰂛" : "󰂚"
                });
            return dndResults;
        }

        if (launcherWindow.cocModeActive) {
            var dq = launcherWindow.cocQuery;
            var cocResults = [];
            if (!dq.command || dq.command === "on")
                cocResults.push({ type: "system_command", actionId: "coc_on", name: "Snort Cocaine", description: "Keep the computer from sleeping", icon: "󰐂" });
            if (!dq.command || dq.command === "off")
                cocResults.push({ type: "system_command", actionId: "coc_off", name: "Sober Up", description: "Allow the computer to sleep normally", icon: "󰾆" });
            if (dq.command === "toggle")
                cocResults.push({
                    type: "system_command",
                    actionId: "coc_toggle",
                    name: "Toggle Cocaine",
                    description: "Toggle idle inhibitor",
                    icon: "󰐂"
                });
            return cocResults;
        }

        if (launcherWindow.pomModeActive) {
            var pq = launcherWindow.pomQuery;
            var pomResults = [];

            if (pq.command === "set" && pq.minutes > 0) {
                pomResults.push({
                    type: "system_command",
                    actionId: "pom_set",
                    actionValue: pq.minutes,
                    name: "Start " + pq.minutes + " min " + Pomodoro.modeLabel,
                    description: "Set duration and start the timer",
                    icon: "󱎫"
                });
                return pomResults;
            }

            if (pq.command === "adjust") {
                var sign = pq.minutes > 0 ? "+" : "";
                pomResults.push({
                    type: "system_command",
                    actionId: "pom_adjust",
                    actionValue: pq.minutes,
                    name: "Adjust by " + sign + pq.minutes + " min",
                    description: "Change the current session length",
                    icon: "󰔟"
                });
                return pomResults;
            }

            if (pq.command === "work") {
                pomResults.push({ type: "system_command", actionId: "pom_work", name: "Focus Mode", description: "Switch to a focus session", icon: "󱎫" });
                return pomResults;
            }
            if (pq.command === "break") {
                pomResults.push({ type: "system_command", actionId: "pom_break", name: "Short Break", description: "Switch to a short break", icon: "󰅶" });
                return pomResults;
            }
            if (pq.command === "long") {
                pomResults.push({ type: "system_command", actionId: "pom_long", name: "Long Break", description: "Switch to a long break", icon: "󰒲" });
                return pomResults;
            }
            if (pq.command === "reset") {
                pomResults.push({ type: "system_command", actionId: "pom_reset", name: "Reset Timer", description: "Restore full duration for this mode", icon: "󰑐" });
                return pomResults;
            }

            // Bare "pom" / start / stop / toggle — keep the list light; modes live in the widget chips
            pomResults.push({
                type: "system_command",
                actionId: Pomodoro.isRunning ? "pom_stop" : "pom_start",
                name: Pomodoro.isRunning ? "Pause Timer" : "Start Timer",
                description: Pomodoro.modeLabel
                    + (Pomodoro.completedSessions > 0 ? " · " + Pomodoro.completedSessions + " done" : ""),
                icon: Pomodoro.isRunning ? "󰏤" : "󰐊"
            });
            if (Pomodoro.shouldShow)
                pomResults.push({ type: "system_command", actionId: "pom_reset", name: "Reset Timer", description: "Restore full duration for this mode", icon: "󰑐" });
            return pomResults;
        }

        if (launcherWindow.sliderModeActive) {
            var sq = launcherWindow.sliderQuery;
            var sliderResults = [];
            if (sq.mode === "vol") {
                if (sq.mute) {
                    sliderResults.push({ type: "system_command", actionId: "vol_mute", name: "Mute Volume", description: "Mute system audio", icon: "󰖁" });
                } else if (sq.value >= 0) {
                    sliderResults.push({ type: "system_command", actionId: "vol_set", actionValue: sq.value, name: "Set Volume", description: "Set system volume to " + sq.value + "%", icon: "󰕾" });
                }
            } else if (sq.mode === "bl" && sq.value >= 0) {
                sliderResults.push({ type: "system_command", actionId: "bl_set", actionValue: sq.value, name: "Set Backlight", description: "Set screen brightness to " + sq.value + "%", icon: "󰃠" });
            }
            return sliderResults;
        }

        if (launcherWindow.ssModeActive) {
            var ssCmd = launcherWindow.ssQuery ? launcherWindow.ssQuery.command : null;
            var ssResults = [];
            if (!ssCmd || ssCmd === "fullscreen")
                ssResults.push({ type: "system_command", actionId: "ss_fullscreen", name: "Screenshot Fullscreen", description: "Capture the entire screen", icon: "󰊓" });
            if (!ssCmd || ssCmd === "area")
                ssResults.push({ type: "system_command", actionId: "ss_area", name: "Screenshot Area", description: "Select a region to capture", icon: "󰆞" });
            if (!ssCmd || ssCmd === "window")
                ssResults.push({ type: "system_command", actionId: "ss_window", name: "Screenshot Window", description: "Capture the focused window", icon: "󰖯" });
            if (!ssCmd || ssCmd === "menu")
                ssResults.push({ type: "system_command", actionId: "ss_menu", name: "Screenshot Menu", description: "Open the capture overlay", icon: "󰍜" });
            return ssResults;
        }

        if (launcherWindow.recModeActive) {
            var recCmd = launcherWindow.recQuery ? launcherWindow.recQuery.command : null;
            var recResults = [];
            if (ScreenRecord.recording) {
                if (!recCmd || recCmd === "stop")
                    recResults.push({ type: "system_command", actionId: "rec_stop", name: "Stop Recording", description: "Finish and save the recording", icon: "󰓛" });
            } else {
                if (!recCmd || recCmd === "fullscreen")
                    recResults.push({ type: "system_command", actionId: "rec_fullscreen", name: "Record Fullscreen", description: "Record the entire screen", icon: "󰊓" });
                if (!recCmd || recCmd === "area")
                    recResults.push({ type: "system_command", actionId: "rec_area", name: "Record Area", description: "Select a region to record", icon: "󰆞" });
            }
            if (!recCmd || recCmd === "audio")
                recResults.push({ type: "system_command", actionId: "rec_audio_toggle", name: ScreenRecord.recordAudio ? "Disable Audio" : "Enable Audio", description: ScreenRecord.recordAudio ? "Record without microphone/system audio" : "Include audio in the recording", icon: ScreenRecord.recordAudio ? "󰍬" : "󰍭" });
            return recResults;
        }

        // Check if the user's search explicitly contains any of the hidden keywords
        var isSearchingHidden = false;
        for (var k = 0; k < hiddenKeywords.length; k++) {
            if (queryLower.includes(hiddenKeywords[k])) {
                isSearchingHidden = true;
                break;
            }
        }
        var scored = [];

        var rustResults = ctrl.appSearchResults;
        if (rustResults && rustResults.length > 0 && ctrl.appSearchQuery.toLowerCase() === queryLower) {
            for (var ri = 0; ri < rustResults.length; ri++) {
                var item = rustResults[ri];
                var entry = ctrl.findDesktopEntry(item.id);
                if (entry) {
                    var nLower = entry.name ? entry.name.toLowerCase() : "";
                    var isHidden = false;
                    for (var hk = 0; hk < hiddenKeywords.length; hk++) {
                        if (nLower.includes(hiddenKeywords[hk])) {
                            isHidden = true;
                            break;
                        }
                    }
                    if (isHidden && !isSearchingHidden) continue;
                    scored.push({
                        entry: entry,
                        score: item.score
                    });
                }
            }
        } else {
            for (var i = 0; i < allApps.length; i++) {
                var entry = allApps[i];
                var nameLower = entry.name ? entry.name.toLowerCase() : "";
                var isHiddenApp = false;
                for (var hk = 0; hk < hiddenKeywords.length; hk++) {
                    if (nameLower.includes(hiddenKeywords[hk])) {
                        isHiddenApp = true;
                        break;
                    }
                }

                if (isHiddenApp && !isSearchingHidden) {
                    continue;
                }

                var best = scoreMatch(entry.name, queryLower, queryLen);
                if (best >= 0) {
                    scored.push({
                        entry: entry,
                        score: best
                    });
                }
            }
        }

        // ──── Tier 1: Quickkey-boosted results ────
        var quickkeyMatches = ctrl.getQuickkeyMatches(query);
        var quickkeyBoostedIds = {};
        var appSlotsUsed = 0;
        var runningWindows = ctrl.getRunningWindows();
        var runningWindowsById = {};
        for (var w = 0; w < runningWindows.length; w++) {
            var win = runningWindows[w];
            if (win.appId) {
                if (!runningWindowsById[win.appId])
                    runningWindowsById[win.appId] = [];
                runningWindowsById[win.appId].push(win);
            }
        }

        for (var qk = 0; qk < quickkeyMatches.length; qk++) {
            if (appSlotsUsed >= launcherWindow.maxAppResults)
                break;

            var qkId = quickkeyMatches[qk].id;

            if (qkId.startsWith("emoji:")) {
                var emojiChar = qkId.substring(6);
                quickkeyBoostedIds[qkId] = true;
                results.push({
                    type: "emoji",
                    emoji: emojiChar,
                    display: ctrl.getEmojiDisplay(emojiChar)
                });
                continue;
            }

            var qkEntry = ctrl.findDesktopEntry(qkId);
            if (!qkEntry) continue;

            quickkeyBoostedIds[qkId] = true;
            appSlotsUsed++;

            var qkWins = runningWindowsById[qkId];
            if (qkWins) {
                for (var qw = 0; qw < qkWins.length; qw++) {
                    results.push({
                        type: "focus",
                        entry: qkEntry,
                        windowId: qkWins[qw].id,
                        windowTitle: qkWins[qw].title || ""
                    });
                }
            }

            results.push({ type: "app", entry: qkEntry });
        }

        // ──── Tier 2: Standard fuzzy-match results ────
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            var freqA = ctrl.appFrequencies[a.entry.id] || 0;
            var freqB = ctrl.appFrequencies[b.entry.id] || 0;
            if (freqB !== freqA)
                return freqB - freqA;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });

        var maxAppActions = 3;
        var appActionsUsed = 0;

        for (var i = 0; i < scored.length; i++) {
            if (appSlotsUsed >= launcherWindow.maxAppResults)
                break;

            var appEntry = scored[i].entry;
            var entryId = appEntry.id || "";

            if (quickkeyBoostedIds[entryId]) continue;

            appSlotsUsed++;

            var appWins = runningWindowsById[entryId];
            if (appWins) {
                for (var aw = 0; aw < appWins.length; aw++) {
                    results.push({
                        type: "focus",
                        entry: appEntry,
                        windowId: appWins[aw].id,
                        windowTitle: appWins[aw].title || ""
                    });
                }
            }

            results.push({ type: "app", entry: appEntry });
        }

        // --- System Commands ---
        if (queryLower.startsWith("vol ")) {
            var valStr = queryLower.substring(4).trim();
            if (valStr === "mute") {
                results.push({ type: "system_command", actionId: "vol_mute", name: "Mute Volume", description: "Mute system audio", icon: "volume_off" });
            } else if (valStr !== "" && !isNaN(valStr)) {
                var num = Math.max(0, Math.min(100, parseInt(valStr)));
                results.push({ type: "system_command", actionId: "vol_set", actionValue: num, name: "Set Volume", description: "Set system volume to " + num + "%", icon: "volume_up" });
            }
        } else if (queryLower.startsWith("bl ")) {
            var valStr = queryLower.substring(3).trim();
            if (valStr !== "" && !isNaN(valStr)) {
                var num = Math.max(0, Math.min(100, parseInt(valStr)));
                results.push({ type: "system_command", actionId: "bl_set", actionValue: num, name: "Set Backlight", description: "Set screen brightness to " + num + "%", icon: "light_mode" });
            }
        } else if (queryLower === "shutdown" || queryLower === "poweroff") {
            results.push({ type: "system_command", actionId: "shutdown", name: "Shutdown", description: "Turn off the computer", icon: "power_settings_new" });
        } else if (queryLower === "reboot" || queryLower === "restart") {
            results.push({ type: "system_command", actionId: "reboot", name: "Reboot", description: "Restart the computer", icon: "restart_alt" });
        } else if (queryLower === "sleep" || queryLower === "suspend") {
            results.push({ type: "system_command", actionId: "sleep", name: "Sleep", description: "Suspend to RAM", icon: "bedtime" });
        } else if (queryLower === "lock" || queryLower === "lockscreen") {
            results.push({ type: "system_command", actionId: "lock", name: "Lock Screen", description: "Lock the session", icon: "lock" });
        } else if (queryLower === "audio out hdmi") {
            results.push({ type: "system_command", actionId: "audio_out_hdmi", name: "Audio Out HDMI", description: "Set default audio output to HDMI", icon: "tv" });
        }

        // --- Music results (only outside music mode) ---
        if (!launcherWindow.musicModeActive && queryLen >= 2) {
            var library = BackendDaemon.musicLibrary ? BackendDaemon.musicLibrary.albums : [];
            if (library && library.length > 0) {
                var musicScored = [];
                for (var m = 0; m < library.length; m++) {
                    var album = library[m];
                    var albumScore = Math.max(
                        scoreMatch(album.title, queryLower, queryLen),
                        scoreMatch(album.artist, queryLower, queryLen)
                    );
                    if (albumScore >= 0) {
                        musicScored.push({ type: "music_album", album: album, score: albumScore + 10 });
                    }

                    var tracks = album.tracks || [];
                    for (var t = 0; t < tracks.length; t++) {
                        var track = tracks[t];
                        var trackScore = scoreMatch(track.title, queryLower, queryLen);
                        if (trackScore >= 0) {
                            musicScored.push({ type: "music_track", album: album, trackIndex: t, track: track, score: trackScore });
                        }
                    }
                }
                musicScored.sort((a, b) => b.score - a.score);
                var maxMusic = Math.min(musicScored.length, launcherWindow.maxMusicResults);
                for (var ms = 0; ms < maxMusic; ms++) {
                    results.push(musicScored[ms]);
                }
            }
        }

        // --- File search results (from Rust backend) ---
        if (queryLen >= 3) {
            var fileResults = ctrl.fileSearchResults;
            if (fileResults && ctrl.fileSearchQuery.toLowerCase() === queryLower) {
                var maxFiles = Math.min(fileResults.length, launcherWindow.maxFileResults);
                for (var fi = 0; fi < maxFiles; fi++) {
                    results.push({
                        type: "file",
                        file: fileResults[fi]
                    });
                }
            }
        }

        // --- Bookmark search results (from Rust backend) ---
        if (queryLen >= 2) {
            var bookmarkResults = ctrl.bookmarkSearchResults;
            if (bookmarkResults && ctrl.bookmarkSearchQuery.toLowerCase() === queryLower) {
                var maxBookmarks = Math.min(bookmarkResults.length, 5);
                for (var bi = 0; bi < maxBookmarks; bi++) {
                    results.push({
                        type: "bookmark",
                        bookmark: bookmarkResults[bi]
                    });
                }
            }
        }

        // --- Fallback action: Open in WolframAlpha ---
        if (ctrl.looksLikeMath(query)) {
            if (!launcherWindow.wolframResultObj) {
                launcherWindow.wolframResultObj = {
                    type: "action",
                    actionId: "wolfram",
                    name: "Open in WolframAlpha",
                    icon: "calculate",
                    iconFamily: ""
                };
            }
            launcherWindow.wolframResultObj.description = query;
            results.push(launcherWindow.wolframResultObj);
        }

        // --- Fallback action: Dictionary ---
        if (query.indexOf(" ") === -1 && (ctrl.dictStatus === "ok" || ctrl.dictStatus === "loading")) {
            results.push({
                type: "action",
                actionId: "dictionary",
                name: "Dictionary",
                description: "Look up \"" + query + "\" in dictionary",
                icon: "menu_book",
                iconFamily: ""
            });
        }

        // --- Emoji results (skip 1-char queries — they match nearly everything) ---
        var isEmojiQuery = queryLower.indexOf("emoji") !== -1;
        var emojiSearchQuery = isEmojiQuery ? queryLower.replace(/emojis?/g, "").trim() : query;
        if (emojiSearchQuery === "") {
            emojiSearchQuery = query;
        }

        var emojiQueryLen = emojiSearchQuery.length;
        if (emojiQueryLen >= 2 || (isEmojiQuery && emojiQueryLen > 0)) {
            var emojiResults = ctrl.filterEmojis(emojiSearchQuery);

            for (var e = 0; e < emojiResults.length; e++) {
                emojiResults[e]._freq = ctrl.getAppFrecency("emoji:" + emojiResults[e].emoji);
            }

            emojiResults.sort((a, b) => {
                return b._freq - a._freq;
            });

            var maxEmojis = Math.min(emojiResults.length, launcherWindow.maxEmojiResults);
            var emojiItemsToInsert = [];

            for (var ei = 0; ei < maxEmojis; ei++) {
                var eId = "emoji:" + emojiResults[ei].emoji;
                if (!quickkeyBoostedIds[eId]) {
                    var eItem = {
                        type: "emoji",
                        emoji: emojiResults[ei].emoji,
                        display: emojiResults[ei].display
                    };

                    if (isEmojiQuery) {
                        emojiItemsToInsert.push(eItem);
                    } else {
                        results.push(eItem);
                    }
                }
            }

            if (isEmojiQuery && emojiItemsToInsert.length > 0) {
                for (var j = emojiItemsToInsert.length - 1; j >= 0; j--) {
                    results.unshift(emojiItemsToInsert[j]);
                }
            }
        }

        // --- Fallback action: Search the web ---
        results.push({
            type: "action",
            actionId: "websearch",
            name: "Search the web",
            description: "\"" + query + "\" — DuckDuckGo",
            icon: "helium",
            iconFamily: "__icon_theme__"
        });

        return results;
    }

    LauncherBackend {
        id: ctrl

        onOpenMenuRequested: launcherWindow.openMenu()
        onCloseMenuRequested: launcherWindow.closeMenu()
    }

    function openMenu() {
        if (menuOpen) {
            closeMenu();
            return;
        }
        if (KeepassState.open || KeepassState.openProgress > 0.001)
            KeepassState.requestClose();
        pinSelectionToBest = true;
        closeAnim.stop();
        panelExpanded = false;
        // Ensure openProgress starts at 0 so the mask is fully closed
        // before the content appears.
        openProgress = 0;
        // Claim the dock notch now. The dock holds its own chrome until this
        // surface reports progress, so the handoff has no uncovered frame.
        LauncherState.open = true;
        LauncherState.screen = launcherWindow.screen;
        _framePresented = false;
        menuOpen = true;
        // Always start from an empty query. clearStates alone is not enough:
        // the TextField keeps its own text, and a close interrupted mid-animation
        // never reaches closeAnim.onFinished.
        ctrl.clearStates();
        // The result list is kept warm while closed, so there is normally
        // nothing to rebuild. If one was still queued, flush it now: doing the
        // work before the surface is even mapped hides it entirely, whereas
        // letting the debounce fire would land it inside the reveal.
        if (filterDebounce.running) {
            filterDebounce.stop();
            _debouncedResults = buildFilteredList();
        }
        // Focus now, not at reveal time: the compositor hands this surface the
        // keyboard as soon as it maps, so anything typed in between would
        // otherwise miss the search field.
        if (contentLoader.item) {
            contentLoader.item.clearSearch();
            contentLoader.item.focusSearch();
        }

        // Arm the reveal. It fires from _onFramePresented once the surface is
        // actually up; if the content tree is still incubating, wait for that
        // too (see contentLoader.onItemChanged).
        _pendingOpen = !contentLoader.item;
        _armRevealProbe();
    }

    function closeMenu() {
        _pendingOpen = false;
        revealFallback.stop();
        shareModeActive = false;
        shareData = null;
        if (contentLoader.item)
            contentLoader.item.resetSpecialViewState();
        bluetoothConnectedNotifTimer.stop();
        openAnim.stop();
        panelExpanded = false;
        // Keep LauncherState.open true until closeAnim finishes so the dock
        // notch stays expanded while content fades out.
        closeAnim.start();
        ctrl.commitRecents();
    }

    LazyLoader {
        id: contentLoader

        // Warm once at shell startup and retain the component. Unloading this
        // large tree on every close caused first-frame stalls on every opening.
        activeAsync: true

        // When activeAsync finishes loading and a pending open is waiting, arm
        // the reveal now that the mask layer is ready.
        onItemChanged: {
            if (!item)
                return;
            launcherWindow.syncBlurRegion();
            item.widthChanged.connect(launcherWindow.syncBlurRegion);
            item.heightChanged.connect(launcherWindow.syncBlurRegion);
            if (launcherWindow._pendingOpen) {
                launcherWindow._pendingOpen = false;
                // Someone opened the launcher before warm-up finished. Build
                // the list now, while still off screen, rather than letting the
                // debounce drop it into the reveal.
                item.clearSearch();
                launcherWindow._debouncedResults = launcherWindow.buildFilteredList();
                item.focusSearch();
                // The surface may already have presented while this tree was
                // still incubating, in which case no further frame is coming.
                launcherWindow._maybeBeginReveal();
            } else {
                // Populate delegates during warm-up, not while opening.
                filterDebounce.restart();
            }
        }

        component: Component {
            Item {
                id: lazyContentRoot

                parent: launcherWindow.contentItem
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                clip: true

                // Only this clip shell changes geometry. mainUi keeps a fixed
                // layout, avoiding a full anchor/layout pass on every spring frame.
                width: launcherWindow.panelExpanded
                    ? LauncherState.targetWidth : LauncherState.dockWidth
                height: launcherWindow.panelExpanded
                    ? LauncherState.targetHeight : LauncherState.dockHeight

                Behavior on width {
                    SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
                }
                Behavior on height {
                    SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
                }

                // Special views are incubated asynchronously so a 600-line view
                // never builds inside a frame. Every crossfade against them is
                // keyed on this, so nothing ever dissolves into an empty panel.
                readonly property bool specialViewReady: {
                    if (launcherWindow.weatherModeActive) return weatherLoader.status === Loader.Ready;
                    if (launcherWindow.colorPickerModeActive) return colorPickerLoader.status === Loader.Ready;
                    if (launcherWindow.btModeActive) return btLoader.status === Loader.Ready;
                    if (launcherWindow.wifiModeActive) return wifiLoader.status === Loader.Ready;
                    if (launcherWindow.musicModeActive) return musicLoader.status === Loader.Ready;
                    if (launcherWindow.nightModeActive) return nightLightLoader.status === Loader.Ready;
                    if (launcherWindow.clipModeActive) return clipboardLoader.status === Loader.Ready;
                    return false;
                }

                function clearSearch() {
                    searchField.clear();
                }

                function focusSearch() {
                    searchField.forceActiveFocus();
                }

                function syncFilePreviewForCurrentItem() {
                    if (launcherWindow.specialViewActive)
                        return;
                    var item = searchModel.values[listView.currentIndex];
                    if (item && item.type === "file") {
                        launcherWindow.hasFileSelected = true;
                        launcherWindow.selectedFileData = item.file;
                        ctrl.requestFilePreview(item.file.path);
                    } else {
                        launcherWindow.hasFileSelected = false;
                        launcherWindow.selectedFileData = null;
                    }
                }

                // Keep the best match first+selected when the query changes.
                // ScriptModel move ops would otherwise drag currentIndex with the
                // previously selected item as results reorder.
                function resetSelectionToBest() {
                    if (!launcherWindow.pinSelectionToBest)
                        return;
                    launcherWindow.appActionIndex = -1;
                    if (listView.count <= 0) {
                        listView.currentIndex = -1;
                        return;
                    }
                    listView.currentIndex = 0;
                    listView.positionViewAtBeginning();
                }

                function cycleListSelection(forward) {
                    launcherWindow.pinSelectionToBest = false;
                    if (listView.count <= 0)
                        return;
                    if (forward) {
                        if (listView.currentIndex >= listView.count - 1)
                            listView.currentIndex = 0;
                        else
                            listView.incrementCurrentIndex();
                    } else {
                        if (listView.currentIndex <= 0)
                            listView.currentIndex = listView.count - 1;
                        else
                            listView.decrementCurrentIndex();
                    }
                }

                function activeConnectivityView() {
                    if (launcherWindow.btModeActive)
                        return btLoader.item;
                    if (launcherWindow.wifiModeActive)
                        return wifiLoader.item;
                    return null;
                }

                function activeSpecialView() {
                    if (launcherWindow.clipModeActive)
                        return clipboardLoader.item;
                    if (launcherWindow.musicModeActive)
                        return musicLoader.item;
                    return activeConnectivityView();
                }

                function refreshClipboard() {
                    if (clipboardLoader.item)
                        clipboardLoader.item.refresh();
                }

                function cycleSpecialSelection(forward) {
                    var view = activeSpecialView();
                    if (!view)
                        return;
                    if (forward)
                        view.incrementSelection();
                    else
                        view.decrementSelection();
                    scrollSpecialToSelection();
                }

                function scrollSpecialToSelection() {
                    if (launcherWindow.musicModeActive && musicLoader.item) {
                        var maxY = Math.max(0, musicScroll.contentHeight - musicScroll.height);
                        musicScroll.contentY = Math.max(0, Math.min(musicLoader.item.selectedScrollY - musicScroll.height * 0.25, maxY));
                        return;
                    }
                    scrollConnectivityToSelection();
                }

                function activateSpecialSelection() {
                    if (launcherWindow.clipModeActive && clipboardLoader.item)
                        return clipboardLoader.item.activateSelected();
                    if (launcherWindow.musicModeActive)
                        return activateMusicSelection();
                    return activateConnectivitySelection();
                }

                function activateMusicSelection() {
                    var mq = launcherWindow.musicQuery;
                    if (!mq)
                        return false;
                    if (mq.command) {
                        launcherWindow.executeMusicCommand(mq);
                        return true;
                    }
                    if (!musicLoader.item)
                        return false;
                    if (mq.filter !== "")
                        return musicLoader.item.activateTopMatch();
                    return musicLoader.item.activateSelected();
                }

                function cycleConnectivitySelection(forward) {
                    var view = activeConnectivityView();
                    if (!view)
                        return;
                    if (forward)
                        view.incrementSelection();
                    else
                        view.decrementSelection();
                    scrollConnectivityToSelection();
                }

                function scrollConnectivityToSelection() {
                    // Views handle their own scroll position internally
                }

                function activateConnectivitySelection() {
                    var view = activeConnectivityView();
                    if (!view)
                        return false;
                    if (!view.activateSelected())
                        return false;
                    // Bluetooth should close when the device reports `connected`;
                    // Wi-Fi keeps the fixed close timer.
                    if (launcherWindow.wifiModeActive)
                        connectivityCloseTimer.restart();
                    return true;
                }

                function resetSpecialViewState() {
                    connectivityCloseTimer.stop();
                    if (btLoader.item) btLoader.item.resetConnecting();
                    if (wifiLoader.item) wifiLoader.item.resetConnecting();
                }

                function resetConnectivityState() {
                    resetSpecialViewState();
                }

                Timer {
                    id: connectivityCloseTimer
                    interval: 850
                    onTriggered: launcherWindow.closeMenu()
                }

                function handleSpecialNavigationKey(event) {
                    if (launcherWindow.clipModeActive && clipboardLoader.item) {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            var clipForward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                            if (clipForward)
                                clipboardLoader.item.incrementSelection();
                            else
                                clipboardLoader.item.decrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Down) {
                            clipboardLoader.item.incrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Up) {
                            clipboardLoader.item.decrementSelection();
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            clipboardLoader.item.activateSelected();
                            event.accepted = true;
                            return true;
                        }
                        return false;
                    }
                    if (launcherWindow.musicModeActive) {
                        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            var forward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                            cycleSpecialSelection(forward);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Down) {
                            cycleSpecialSelection(true);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Up) {
                            cycleSpecialSelection(false);
                            event.accepted = true;
                            return true;
                        }
                        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            activateMusicSelection();
                            event.accepted = true;
                            return true;
                        }
                        return false;
                    }
                    return handleConnectivityNavigationKey(event);
                }

                function handleConnectivityNavigationKey(event) {
                    if (!launcherWindow.connectivityModeActive)
                        return false;
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        var forward = !((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab);
                        cycleConnectivitySelection(forward);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Down) {
                        cycleConnectivitySelection(true);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Up) {
                        cycleConnectivitySelection(false);
                        event.accepted = true;
                        return true;
                    }
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        activateConnectivitySelection();
                        event.accepted = true;
                        return true;
                    }
                    return false;
                }

                ClippingRectangle {
                    id: mainUi
                    property var launcherWindowRef: launcherWindow
                    property var ctrlRef: ctrl
                    width: LauncherState.targetWidth
                    height: LauncherState.targetHeight
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Square top edge meets the screen like the dock; rounded
                    // bottom corners clip glass fill + children (plain
                    // Rectangle.clip does not honor radius).
                    color: Theme.glass_shell
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: LauncherState.targetRadius
                    bottomRightRadius: LauncherState.targetRadius
                    border.width: 1
                    border.color: Theme.glass_shell_border
                    // Keep layout flush to the card edges; border paints on top.
                    contentUnderBorder: true
                    // Stays visible and is hidden by opacity alone. Gating
                    // `visible` on openProgress deferred the ListView's first
                    // polish until the reveal had already begun, so building
                    // ~10 heavy delegates landed inside the animation.
                    opacity: launcherWindow.openProgress
                    focus: true

                    // Swallow clicks on the card so it doesn't dismiss
                    MouseArea { anchors.fill: parent }

                    LauncherWeatherData {
                        id: launcherWeatherData
                    }

                    Keys.onPressed: event => {
                        if (searchField.activeFocus)
                            return;

                        if (event.key === Qt.Key_Escape) {
                            launcherWindow.closeMenu();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_I) {
                            searchField.forceActiveFocus();
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
                            if (!launcherWindow.specialViewActive && listView.currentItem && listView.currentItem.hasActions) {
                                var count = listView.currentItem.actionCount;
                                if (event.modifiers & Qt.ShiftModifier) {
                                    launcherWindow.appActionIndex = launcherWindow.appActionIndex <= 0 ? count - 1 : launcherWindow.appActionIndex - 1;
                                } else {
                                    launcherWindow.appActionIndex = launcherWindow.appActionIndex >= count - 1 ? 0 : launcherWindow.appActionIndex + 1;
                                }
                                event.accepted = true;
                            }
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            if (lazyContentRoot.handleSpecialNavigationKey(event))
                                return;
                            if (launcherWindow.specialViewActive) {
                                event.accepted = true;
                                return;
                            }
                            lazyContentRoot.cycleListSelection(!((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab));
                            event.accepted = true;
                        } else if (lazyContentRoot.handleSpecialNavigationKey(event)) {
                            return;
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.connectivityModeActive) {
                            lazyContentRoot.activateConnectivitySelection();
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && event.key === Qt.Key_Down) {
                            lazyContentRoot.cycleListSelection(true);
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && event.key === Qt.Key_Up) {
                            lazyContentRoot.cycleListSelection(false);
                            event.accepted = true;
                        } else if (launcherWindow.colorPickerModeActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (colorPickerLoader.item)
                                colorPickerLoader.item.copyColor(colorPickerLoader.item.hexValue, "HEX");
                            event.accepted = true;
                        } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (listView.currentItem) {
                                listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
                            } else if (ctrl.calcResult !== "") {
                                ctrl.copyResult();
                            }
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        id: searchArea
                        z: 3
                        height: 44
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        radius: height / 2
                        color: Theme.glass_raised
                        border.width: 1
                        border.color: Theme.glass_border

                        TextField {
                            id: searchField
                            // Prevent `onAccepted` from firing when we handle Return in `Keys.onReturnPressed`.
                            property bool suppressAcceptedNext: false
                            anchors.fill: parent
                            leftPadding: 44
                            rightPadding: 16

                            font {
                                family: "Google Sans"
                                pixelSize: 16
                                weight: Font.Medium
                            }
                            color: Theme.on_surface
                            selectionColor: Theme.primary_container
                            selectedTextColor: Theme.on_primary_container

                            placeholderText: "Search"
                            placeholderTextColor: Theme.on_surface_variant

                            onAccepted: {
                                if (suppressAcceptedNext) {
                                    suppressAcceptedNext = false;
                                    return;
                                }
                                if (launcherWindow.clipModeActive) {
                                    if (clipboardLoader.item) clipboardLoader.item.activateSelected();
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                } else if (launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                } else if (launcherWindow.cocModeActive && launcherWindow.cocQuery.command) {
                                    launcherWindow.executeCocCommand();
                                } else if (launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                } else if (launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                } else if (launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                } else if (launcherWindow.colorPickerModeActive) {
                                    if (colorPickerLoader.item) colorPickerLoader.item.copyColor(colorPickerLoader.item.hexValue, "HEX");

                                } else if (!launcherWindow.specialViewActive) {
                                    if (listView.currentItem)
                                        listView.currentItem.activate(false);
                                    else if (ctrl.calcResult !== "")
                                        ctrl.copyResult();
                                }
                            }

                            Keys.onReturnPressed: event => {
                                // Ensure we don't also run `onAccepted` for the same keypress.
                                suppressAcceptedNext = true;
                                if (launcherWindow.clipModeActive) {
                                    if (clipboardLoader.item) clipboardLoader.item.activateSelected();
                                    event.accepted = true;
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.cocModeActive && launcherWindow.cocQuery.command) {
                                    launcherWindow.executeCocCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                    event.accepted = true;
                                } else if (launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                    event.accepted = true;
                                } else if (launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                    event.accepted = true;
                                } else if (launcherWindow.colorPickerModeActive) {
                                    if (colorPickerLoader.item) colorPickerLoader.item.copyColor(colorPickerLoader.item.hexValue, "HEX");
                                    event.accepted = true;

                                } else if (!launcherWindow.specialViewActive) {
                                    if (listView.currentItem) {
                                        if (listView.currentItem.hasActions && launcherWindow.appActionIndex >= 0) {
                                            listView.currentItem.activateAction(launcherWindow.appActionIndex);
                                        } else {
                                            listView.currentItem.activate(false);
                                        }
                                    } else if (ctrl.calcResult !== "") {
                                        ctrl.copyResult();
                                    }
                                    event.accepted = true;
                                }
                            }

                            background: Item {
                                MaterialIcon {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "search"
                                    font.pixelSize: 20
                                    color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }

                            onTextChanged: {
                                ctrl.searchText = text;
                                launcherWindow.pinSelectionToBest = true;
                                lazyContentRoot.resetSelectionToBest();
                                if (launcherWindow.weatherModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                    BackendDaemon.send({ action: "weather_refresh" });
                                } else if (launcherWindow.colorPickerModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.connectivityModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.musicModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.sliderModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.bringModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.dndModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.pomModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                    if (launcherWindow.pomQuery.minutes > 0)
                                        pomWidget.pendingMinutes = launcherWindow.pomQuery.minutes;
                                    else
                                        pomWidget.pendingMinutes = -1;
                                } else if (launcherWindow.nightModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else if (launcherWindow.clipModeActive) {
                                    launcherWindow.hasFileSelected = false;
                                    launcherWindow.selectedFileData = null;
                                } else {
                                    Qt.callLater(syncFilePreviewForCurrentItem);
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    mainUi.forceActiveFocus();
                                    event.accepted = true;
                                } else if (launcherWindow.nightModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                    var step = event.key === Qt.Key_Right ? 5 : -5;
                                    NightLight.setIntensity(NightLight.intensity + step);
                                    if (!NightLight.enabled) NightLight.enable();
                                    event.accepted = true;
                                } else if (launcherWindow.sliderModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                    var delta = event.key === Qt.Key_Right ? 0.05 : -0.05;
                                    if (launcherWindow.volSliderActive) volSliderWidget.nudge(delta);
                                    else if (launcherWindow.blSliderActive) blSliderWidget.nudge(delta);
                                    event.accepted = true;
                                } else if (launcherWindow.pomModeActive && (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && !Pomodoro.isRunning) {
                                    var step = event.key === Qt.Key_Right ? 5 : -5;
                                    var base = pomWidget.pendingMinutes > 0
                                        ? pomWidget.pendingMinutes
                                        : Math.round(Pomodoro.currentDuration / 60);
                                    pomWidget.commitMinutes(base + step);
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
                                    if (!launcherWindow.specialViewActive && listView.currentItem && listView.currentItem.hasActions) {
                                        var count = listView.currentItem.actionCount;
                                        if (event.modifiers & Qt.ShiftModifier) {
                                            launcherWindow.appActionIndex = launcherWindow.appActionIndex <= 0 ? count - 1 : launcherWindow.appActionIndex - 1;
                                        } else {
                                            launcherWindow.appActionIndex = launcherWindow.appActionIndex >= count - 1 ? 0 : launcherWindow.appActionIndex + 1;
                                        }
                                        event.accepted = true;
                                    }
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    if (lazyContentRoot.handleSpecialNavigationKey(event))
                                        return;
                                    if (launcherWindow.specialViewActive) {
                                        event.accepted = true;
                                        return;
                                    }
                                    lazyContentRoot.cycleListSelection(!((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab));
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.nightModeActive) {
                                    launcherWindow.executeNightCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.dndModeActive && launcherWindow.dndQuery.command) {
                                    launcherWindow.executeDndCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.pomModeActive && launcherWindow.pomQuery.command) {
                                    launcherWindow.executePomCommand();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.musicModeActive) {
                                    lazyContentRoot.activateMusicSelection();
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && launcherWindow.connectivityModeActive) {
                                    lazyContentRoot.activateConnectivitySelection();
                                    event.accepted = true;
                                } else if (lazyContentRoot.handleSpecialNavigationKey(event)) {
                                    return;
                                } else if (!launcherWindow.specialViewActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                    if (listView.currentItem) {
                                        if (listView.currentItem.hasActions && launcherWindow.appActionIndex >= 0) {
                                            listView.currentItem.activateAction(launcherWindow.appActionIndex);
                                        } else {
                                            listView.currentItem.activate(event.modifiers & Qt.ShiftModifier);
                                        }
                                    } else if (ctrl.calcResult !== "") {
                                        ctrl.copyResult();
                                    }
                                    event.accepted = true;
                                } else if (launcherWindow.colorPickerModeActive && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                    if (colorPickerLoader.item)
                                        colorPickerLoader.item.copyColor(colorPickerLoader.item.hexValue, "HEX");
                                    event.accepted = true;

                                } else if (!launcherWindow.specialViewActive && event.key === Qt.Key_Down) {
                                    lazyContentRoot.cycleListSelection(true);
                                    event.accepted = true;
                                } else if (!launcherWindow.specialViewActive && event.key === Qt.Key_Up) {
                                    lazyContentRoot.cycleListSelection(false);
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // --- Calculator Result Card ---
                    LauncherCalcWidget {
                        id: calcCard
                        calcResult: ctrl.calcResult
                        calcExpression: ctrl.calcExpression
                        onCopyRequested: ctrl.copyResult()
                        visible: ctrl.calcResult !== "" && !launcherWindow.colorPickerModeActive && !launcherWindow.connectivityModeActive && !launcherWindow.musicModeActive && !launcherWindow.sliderModeActive && !launcherWindow.nightModeActive && !launcherWindow.clipModeActive && !launcherWindow.captureModeActive && !launcherWindow.dndModeActive && !launcherWindow.pomModeActive && !launcherWindow.cocModeActive
                        anchors.top: searchArea.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                    }

                    Item {
                        id: belowSearchArea
                        anchors.top: calcCard.visible ? calcCard.bottom : searchArea.bottom
                        anchors.topMargin: launcherWindow.specialViewActive ? 4 : 10
                        Behavior on anchors.topMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        clip: true

                        Item {
                            id: launcherResultsLayer
                            anchors.fill: parent
                            // Hold the results until the incoming special view
                            // is built, otherwise the panel is briefly empty.
                            opacity: (launcherWindow.specialViewActive && lazyContentRoot.specialViewReady) ? 0 : 1
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            LauncherWidgetArea {
                                id: sliderWidgetArea
                                // Named `launcher`/`backend` rather than matching the
                                // outer ids: a property shadows the id of the same name,
                                // so `launcherWindow: launcherWindow` binds to itself.
                                launcher: launcherWindow
                                backend: ctrl
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                            }

                            Item {
                                id: listContainer
                                anchors.top: sliderWidgetArea.visible ? sliderWidgetArea.bottom : parent.top
                                anchors.bottom: footer.top
                                anchors.left: parent.left
                                width: parent.width * (1 - 0.48 * launcherWindow.fileSplitBlend)
                                clip: true

                                ListView {
                                    id: listView
                                    anchors.fill: parent
                                    topMargin: 4
                                    bottomMargin: 8
                                    spacing: 2
                                    clip: true

                                    // Recycle heavy delegates across keystroke model swaps
                                    reuseItems: true
                                    cacheBuffer: 160
                                    highlightMoveDuration: launcherWindow.pinSelectionToBest ? 0 : 80
                                    // Only follow selection when the user cycles (Tab/arrows/hover),
                                    // never when typing reorders results via ScriptModel moves.
                                    highlightFollowsCurrentItem: !launcherWindow.pinSelectionToBest
                                    delegate: LauncherDelegate {}

                                    model: ScriptModel {
                                        id: searchModel
                                        values: launcherWindow._debouncedResults
                                        onValuesChanged: {
                                            if (launcherWindow.pinSelectionToBest)
                                                lazyContentRoot.resetSelectionToBest();
                                        }
                                    }

                                    onCurrentIndexChanged: syncFilePreviewForCurrentItem()

                                    onCountChanged: Qt.callLater(syncFilePreviewForCurrentItem)
                                }

                            }

                            Text {
                                id: emptyMessage
                                anchors.centerIn: listContainer
                                text: "No results found"
                                visible: listView.count === 0
                                color: Theme.on_surface_variant
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 14
                                }
                            }

                            Item {
                                id: footer
                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                }
                                width: listContainer.width
                                height: 16
                            }
                        }

                        Loader {
                            id: weatherLoader
                            z: launcherWindow.weatherModeActive ? 2 : 0
                            enabled: launcherWindow.weatherModeActive
                            active: launcherWindow.weatherModeActive
                            asynchronous: true
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            visible: status === Loader.Ready
                            sourceComponent: LauncherWeatherView {
                                weather: launcherWeatherData
                                revealProgress: launcherWindow.weatherModeActive ? 1 : 0
                            }
                        }

                        Loader {
                            id: colorPickerLoader
                            z: launcherWindow.colorPickerModeActive ? 2 : 0
                            enabled: launcherWindow.colorPickerModeActive
                            active: launcherWindow.colorPickerModeActive
                            asynchronous: true
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 4
                            anchors.bottomMargin: 8
                            visible: status === Loader.Ready
                            sourceComponent: LauncherColorPickerView {
                                searchQuery: ctrl.searchText
                                defaultColor: Theme.primary
                                revealProgress: launcherWindow.colorPickerModeActive ? 1 : 0
                                onCopyRequested: function(text, label) {
                                    ctrl.copyColorText(text);
                                }
                            }
                        }


                        Item {
                            id: musicListContainer
                            z: launcherWindow.musicModeActive ? 2 : 0
                            enabled: launcherWindow.musicModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            // Leave ~50% for the now-compact controls panel.
                            width: parent.width * (1 - 0.50 * launcherWindow.musicSplitBlend)
                            clip: true
                            opacity: (launcherWindow.musicModeActive && musicLoader.status === Loader.Ready) ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on width {
                                NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            Flickable {
                                id: musicScroll
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 4
                                anchors.bottomMargin: 8
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                contentWidth: width
                                contentHeight: musicLoader.item ? musicLoader.item.height : 0

                                Loader {
                                    id: musicLoader
                                    width: musicScroll.width
                                    // The view's lists anchor to its edges and it has no
                                    // implicit height, so it collapses without this.
                                    height: musicScroll.height
                                    active: launcherWindow.musicModeActive
                                    asynchronous: true
                                    visible: status === Loader.Ready
                                    sourceComponent: LauncherMusicView {
                                        width: musicScroll.width
                                        filterQuery: launcherWindow.musicQuery ? launcherWindow.musicQuery.filter : ""
                                        revealProgress: launcherWindow.musicModeActive ? 1 : 0

                                        onSelectedIndexChanged: {
                                            if (launcherWindow.musicModeActive)
                                                lazyContentRoot.scrollSpecialToSelection();
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: connectivityContainer
                            z: launcherWindow.connectivityModeActive ? 2 : 0
                            enabled: launcherWindow.connectivityModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 4
                            anchors.bottomMargin: 8
                            opacity: (launcherWindow.connectivityModeActive && lazyContentRoot.specialViewReady) ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            Loader {
                                id: btLoader
                                anchors.fill: parent
                                active: launcherWindow.btModeActive
                                asynchronous: true
                                visible: status === Loader.Ready && launcherWindow.btModeActive
                                sourceComponent: LauncherBluetoothView {
                                    anchors.fill: parent
                                    filterQuery: launcherWindow.connectivityQuery ? launcherWindow.connectivityQuery.filter : ""
                                    revealProgress: launcherWindow.btModeActive ? 1 : 0
                                    onConnectionSucceeded: function(deviceLabel) {
                                        bluetoothConnectedDeviceLabel = deviceLabel;
                                        launcherWindow.closeMenu();
                                        bluetoothConnectedNotifTimer.restart();
                                    }
                                }
                            }

                            Loader {
                                id: wifiLoader
                                anchors.fill: parent
                                active: launcherWindow.wifiModeActive
                                asynchronous: true
                                visible: status === Loader.Ready && launcherWindow.wifiModeActive
                                sourceComponent: LauncherWifiView {
                                    anchors.fill: parent
                                    filterQuery: launcherWindow.connectivityQuery ? launcherWindow.connectivityQuery.filter : ""
                                    revealProgress: launcherWindow.wifiModeActive ? 1 : 0

                                    onRefocusSearchRequested: searchField.forceActiveFocus()
                                    onConnectionAttemptFailed: lazyContentRoot.resetConnectivityState()
                                }
                            }
                        }

                        Item {
                            id: nightLightContainer
                            z: launcherWindow.nightModeActive ? 2 : 0
                            enabled: launcherWindow.nightModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 4
                            anchors.bottomMargin: 8
                            opacity: (launcherWindow.nightModeActive && nightLightLoader.status === Loader.Ready) ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            Loader {
                                id: nightLightLoader
                                anchors.fill: parent
                                active: launcherWindow.nightModeActive
                                asynchronous: true
                                visible: status === Loader.Ready
                                sourceComponent: LauncherNightLightView {
                                    anchors.fill: parent
                                    revealProgress: launcherWindow.nightModeActive ? 1 : 0
                                }
                            }
                        }

                        Item {
                            id: clipboardContainer
                            z: launcherWindow.clipModeActive ? 2 : 0
                            enabled: launcherWindow.clipModeActive
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 4
                            anchors.bottomMargin: 8
                            opacity: (launcherWindow.clipModeActive && clipboardLoader.status === Loader.Ready) ? 1 : 0
                            visible: opacity > 0.02

                            Behavior on opacity {
                                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                            }

                            Loader {
                                id: clipboardLoader
                                anchors.fill: parent
                                active: launcherWindow.clipModeActive
                                asynchronous: true
                                visible: status === Loader.Ready
                                sourceComponent: LauncherClipboardView {
                                    anchors.fill: parent
                                    filterQuery: launcherWindow.clipQuery ? launcherWindow.clipQuery.filter : ""
                                    revealProgress: launcherWindow.clipModeActive ? 1 : 0

                                    onCloseRequested: launcherWindow.closeMenu()
                                }
                            }
                        }

                        Connections {
                            target: launcherWindow
                            function onConnectivityModeActiveChanged() {
                                if (launcherWindow.connectivityModeActive)
                                    Qt.callLater(lazyContentRoot.scrollConnectivityToSelection);
                            }
                            function onMusicModeActiveChanged() {
                                if (launcherWindow.musicModeActive)
                                    Qt.callLater(lazyContentRoot.scrollSpecialToSelection);
                            }
                        }
                    }
                    // ──── Separator ────
                    Rectangle {
                        x: 8 + (launcherWindow.musicModeActive ? musicListContainer.width : listContainer.width)
                        anchors.top: belowSearchArea.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        width: 1
                        opacity: launcherWindow.activeSplitBlend
                        Behavior on opacity {
                            enabled: launcherWindow.musicModeActive
                            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                        }
                        Behavior on x {
                            enabled: launcherWindow.musicModeActive
                            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                        }

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.15; color: Theme.glass_border }
                            GradientStop { position: 0.85; color: Theme.glass_border }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // ──── Music Controls Panel (Split View) ────
                    // Loaded only while music mode has a player. Keeping
                    // MultiEffect/Image layers mounted at shell warm-up (even
                    // invisible) was crashing updatePixelRatioHelper on Asahi
                    // when album art arrived during startup.
                    Loader {
                        id: musicControlsPanel
                        active: launcherWindow.musicSplitBlend > 0.02
                        asynchronous: true
                        visible: status === Loader.Ready && launcherWindow.musicSplitBlend > 0.02
                        opacity: launcherWindow.musicSplitBlend
                        Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.top: belowSearchArea.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        width: parent.width - 16 - musicListContainer.width
                        clip: true

                        sourceComponent: LauncherMusicControls {}
                    }

                    // ──── File Preview Panel (Split View) ────
                    // Built on the first file selection and kept from then on.
                    // It is the largest subtree in the launcher and plenty of
                    // sessions never select a file, so it stays out of the
                    // warm-up until it is actually wanted.
                    Loader {
                        id: previewLoader
                        property bool needed: false

                        active: needed
                        asynchronous: true
                        visible: status === Loader.Ready && launcherWindow.fileSplitBlend > 0
                        opacity: launcherWindow.fileSplitBlend
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.top: belowSearchArea.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        width: parent.width - 16 - listContainer.width
                        clip: true

                        sourceComponent: LauncherFilePreview {
                            launcherWindow: mainUi.launcherWindowRef
                            ctrl: mainUi.ctrlRef
                        }

                        Connections {
                            target: launcherWindow
                            function onHasFileSelectedChanged() {
                                if (launcherWindow.hasFileSelected)
                                    previewLoader.needed = true;
                            }
                        }
                    }
                } // End of mainUi
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (launcherWindow.visible)
                launcherWindow.closeMenu();
            else
                launcherWindow.openMenu();
        }
        function open(): void {
            launcherWindow.openMenu();
        }
        function close(): void {
            launcherWindow.closeMenu();
        }
    }
}
