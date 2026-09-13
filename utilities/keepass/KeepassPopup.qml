import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import qs.theme
import qs.services
import qs.components

PanelWindow {
    id: keepassWindow

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: menuOpen || openAnim.running || closeAnim.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-keepass"
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    readonly property bool isUnlocked: KeepassBackend.isUnlocked
    property var searchResults: []
    property string searchText: ""
    readonly property bool authenticating: KeepassBackend.unlockPending
    property string authError: ""
    property bool menuOpen: false
    property bool panelExpanded: false
    property real openProgress: 0.0
    property int selectedIndex: 0
    property string activeWindowTitle: ""

    readonly property real panelTargetHeight: isUnlocked
        ? KeepassState.targetHeightUnlocked
        : KeepassState.targetHeightLocked

    Instantiator {
        model: NiriService.windows
        delegate: QtObject {
            property bool winIsFocused: model.isFocused !== undefined ? model.isFocused : false
            property string winTitle: model.title || ""
            onWinIsFocusedChanged: if (winIsFocused && winTitle !== "") keepassWindow.activeWindowTitle = winTitle;
            Component.onCompleted: if (winIsFocused && winTitle !== "") keepassWindow.activeWindowTitle = winTitle;
        }
    }

    onMenuOpenChanged: {
        if (!menuOpen) {
            passwordInput.clear();
            if (authenticating) KeepassBackend.lock();
        }
    }

    // Fullscreen surface for click-away; only this region is blurred.
    BackgroundEffect.blurRegion: Region {
        readonly property real panelWidth: Math.max(1, panelShell.width)
        readonly property real panelHeight: Math.max(1, panelShell.height)

        x: Math.round((keepassWindow.width - panelWidth) / 2)
        y: 0
        width: panelWidth
        height: panelHeight
        radius: 0
    }

    // Set once this surface has presented a frame since being mapped.
    property bool _framePresented: false

    // Avoid grabToImage here: on Asahi it crashes updatePixelRatioHelper when
    // the PanelWindow is still mapping. A short timer approximates first paint.
    function _armRevealProbe() {
        revealFallback.restart();
    }

    Timer {
        id: revealFallback
        interval: 32
        onTriggered: {
            keepassWindow._framePresented = true;
            keepassWindow._beginReveal();
        }
    }

    function _onFramePresented() {
        if (_framePresented || !menuOpen)
            return;
        _framePresented = true;
        _beginReveal();
    }

    function _beginReveal() {
        if (!menuOpen || openAnim.running || openProgress > 0)
            return;
        revealFallback.stop();
        panelExpanded = true;
        if (isUnlocked)
            searchInput.forceActiveFocus();
        else
            passwordInput.forceActiveFocus();
        openAnim.start();
    }

    NumberAnimation {
        id: openAnim
        target: keepassWindow
        property: "openProgress"
        from: 0; to: 1
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: KeepassState.openProgress = 1.0
    }

    NumberAnimation {
        id: closeAnim
        target: keepassWindow
        property: "openProgress"
        // No `from`: closing before the reveal has started must not snap the
        // panel to full size just to animate it back down.
        to: 0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: {
            keepassWindow.menuOpen = false;
            keepassWindow._framePresented = false;
            KeepassState.open = false;
            KeepassState.openProgress = 0.0;
            KeepassState.screen = null;
        }
    }

    onOpenProgressChanged: KeepassState.openProgress = openProgress

    function openMenu() {
        if (SessionState.locked || menuOpen) return;
        // One expanded notch at a time.
        if (LauncherState.open || LauncherState.openProgress > 0.001)
            LauncherState.requestClose();
        if (Screenshot.open || Screenshot.openProgress > 0.001)
            Screenshot.requestClose();

        closeAnim.stop();
        openProgress = 0;
        panelExpanded = false;
        _framePresented = false;
        menuOpen = true;
        authError = "";
        // Claim the dock notch now. The dock holds its own chrome until this
        // surface reports progress, so the handoff has no uncovered frame.
        KeepassState.open = true;
        KeepassState.screen = keepassWindow.screen;

        // Populate before the reveal, never during it.
        if (isUnlocked) {
            searchInput.text = "";
            KeepassBackend.search("", keepassWindow.activeWindowTitle);
        } else {
            passwordInput.text = "";
        }
        _armRevealProbe();
    }

    function closeMenu() {
        passwordInput.clear();
        authError = "";
        if (authenticating) KeepassBackend.lock();
        if (!menuOpen) return;
        revealFallback.stop();
        openAnim.stop();
        panelExpanded = false;
        // Keep KeepassState.open true until closeAnim finishes so the dock
        // notch stays expanded while content fades out.
        closeAnim.start();
    }

    function toggle() {
        if (menuOpen) closeMenu();
        else openMenu();
    }

    onVisibleChanged: {
        if (visible && menuOpen) {
            if (isUnlocked) searchInput.forceActiveFocus();
            else passwordInput.forceActiveFocus();
        }
    }

    Connections {
        target: KeepassBackend
        function onUnlocked(success, error) {
            passwordInput.clear();
            if (!menuOpen) return;
            if (success) {
                authError = "";
                KeepassBackend.search("", keepassWindow.activeWindowTitle);
                searchInput.forceActiveFocus();
            } else {
                authError = error || "Unable to unlock database";
                passwordInput.forceActiveFocus();
            }
        }
        function onLocked() {
            passwordInput.clear();
            searchInput.clear();
            searchText = "";
            searchResults = [];
            selectedIndex = 0;
            keepassWindow.closeMenu();
        }
        function onSearchResult(results) {
            if (!menuOpen || !isUnlocked) return;
            searchResults = results;
            selectedIndex = 0;
        }
    }

    Connections {
        target: SessionState
        function onLockedChanged() {
            if (SessionState.locked) keepassWindow.closeMenu();
        }
    }

    Connections {
        target: KeepassState
        function onCloseRequested() {
            if (keepassWindow.menuOpen || keepassWindow.openProgress > 0)
                keepassWindow.closeMenu();
        }
    }

    // Click-away to dismiss (no opaque scrim — glass island only)
    MouseArea {
        anchors.fill: parent
        onClicked: keepassWindow.closeMenu()
    }

    // Clip shell springs from dock footprint → island size.
    Item {
        id: panelShell
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        clip: true
        enabled: keepassWindow.menuOpen && !SessionState.locked

        width: keepassWindow.panelExpanded
            ? KeepassState.targetWidth : Math.max(1, LauncherState.dockWidth)
        height: keepassWindow.panelExpanded
            ? keepassWindow.panelTargetHeight : Math.max(1, LauncherState.dockHeight)

        Behavior on width {
            SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
        }
        Behavior on height {
            SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
        }

        ClippingRectangle {
            id: mainUi
            width: KeepassState.targetWidth
            height: keepassWindow.panelTargetHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            // Same language as the dock / launcher island.
            color: Theme.glass_shell
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: KeepassState.targetRadius
            bottomRightRadius: KeepassState.targetRadius
            border.width: 1
            border.color: Theme.glass_shell_border
            contentUnderBorder: true
            // Hidden by opacity alone. Gating `visible` on openProgress pushed
            // the entry list's first polish into the reveal animation.
            opacity: keepassWindow.openProgress
            focus: true

            Behavior on height {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            MouseArea { anchors.fill: parent }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    keepassWindow.closeMenu();
                    event.accepted = true;
                } else if (isUnlocked) {
                    if (event.key === Qt.Key_Down) {
                        selectedIndex = Math.min(selectedIndex + 1, searchResults.length - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        selectedIndex = Math.max(selectedIndex - 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        if (searchResults.length > 0)
                            selectedIndex = (selectedIndex >= searchResults.length - 1) ? 0 : selectedIndex + 1;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backtab) {
                        if (searchResults.length > 0)
                            selectedIndex = (selectedIndex <= 0) ? searchResults.length - 1 : selectedIndex - 1;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (searchResults.length > 0 && selectedIndex >= 0 && selectedIndex < searchResults.length) {
                            keepassWindow.closeMenu();
                            KeepassBackend.entrySelected(searchResults[selectedIndex]);
                        }
                        event.accepted = true;
                    }
                }
            }

            Keys.onTabPressed: event => {
                if (isUnlocked && searchResults.length > 0) {
                    selectedIndex = (selectedIndex >= searchResults.length - 1) ? 0 : selectedIndex + 1;
                }
                event.accepted = true;
            }

            Keys.onBacktabPressed: event => {
                if (isUnlocked && searchResults.length > 0) {
                    selectedIndex = (selectedIndex <= 0) ? searchResults.length - 1 : selectedIndex - 1;
                }
                event.accepted = true;
            }

            // ─── Locked state ─────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: !isUnlocked
                opacity: !isUnlocked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    width: parent.width - 48

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.glass_accent
                            border.width: 1
                            border.color: Theme.glass_border

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "lock"
                                font.pixelSize: 18
                                color: Theme.primary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "Unlock KeePass"
                                font.family: "Google Sans"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: Theme.on_surface
                            }
                            Text {
                                text: keepassWindow.authError !== "" ? keepassWindow.authError : "Enter master password"
                                textFormat: Text.PlainText
                                font.family: "Google Sans"
                                font.pixelSize: 12
                                color: keepassWindow.authError !== "" ? Theme.critical : Theme.on_surface_variant
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: height / 2
                        color: Theme.glass_raised
                        border.width: 1
                        border.color: passwordInput.activeFocus ? Theme.primary : Theme.glass_border

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Google Sans"
                            font.pixelSize: 18
                            color: "transparent"
                            selectionColor: Theme.primary
                            selectedTextColor: "transparent"
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                            readOnly: keepassWindow.authenticating || KeepassBackend.lockPending
                            cursorDelegate: Component { Item {} }

                            Keys.onEscapePressed: keepassWindow.closeMenu()

                            onAccepted: {
                                if (text.length > 0 && keepassWindow.menuOpen && !keepassWindow.authenticating && !KeepassBackend.lockPending && !SessionState.locked) {
                                    keepassWindow.authError = "";
                                    KeepassBackend.unlock(text);
                                    clear();
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            Repeater {
                                model: passwordInput.text.length
                                Item {
                                    id: shapeSlot
                                    width: 11
                                    height: 11
                                    readonly property int kind: index % 3

                                    Rectangle {
                                        visible: shapeSlot.kind === 0
                                        anchors.centerIn: parent
                                        width: 10; height: 10
                                        radius: width / 2
                                        color: Theme.on_surface
                                    }
                                    Rectangle {
                                        visible: shapeSlot.kind === 1
                                        anchors.centerIn: parent
                                        width: 9; height: 9
                                        radius: 1.5
                                        color: Theme.on_surface
                                    }
                                    Shape {
                                        visible: shapeSlot.kind === 2
                                        anchors.centerIn: parent
                                        width: 11; height: 10
                                        antialiasing: true
                                        ShapePath {
                                            fillColor: Theme.on_surface
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
                                width: 2; height: 14; radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primary
                                visible: passwordInput.activeFocus && !keepassWindow.authenticating
                                SequentialAnimation on opacity {
                                    running: passwordInput.activeFocus && !keepassWindow.authenticating
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 0 }
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 1 }
                                }
                            }

                            Shape {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: keepassWindow.authenticating
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeWidth: 2
                                    strokeColor: Theme.primary
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    PathAngleArc {
                                        centerX: 7; centerY: 7
                                        radiusX: 5; radiusY: 5
                                        startAngle: 0; sweepAngle: 270
                                        moveToStart: true
                                    }
                                }
                                RotationAnimation on rotation {
                                    from: 0; to: 360
                                    duration: 800
                                    loops: Animation.Infinite
                                    running: keepassWindow.authenticating
                                }
                            }
                        }
                    }
                }
            }

            // ─── Unlocked state ───────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: isUnlocked
                opacity: isUnlocked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Rectangle {
                    id: searchBar
                    z: 3
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    height: 44
                    radius: height / 2
                    color: Theme.glass_raised
                    border.width: 1
                    border.color: searchInput.activeFocus ? Theme.primary : Theme.glass_border

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "search"
                        font.pixelSize: 20
                        color: searchInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.right: lockBtn.left
                        anchors.leftMargin: 44
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "Google Sans"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        color: Theme.on_surface
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        clip: true

                        Text {
                            anchors.fill: parent
                            anchors.verticalCenter: parent.verticalCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "Search passwords…"
                            font: searchInput.font
                            color: Theme.on_surface_variant
                        }

                        Keys.onEscapePressed: keepassWindow.closeMenu()
                        Keys.onTabPressed: event => {
                            if (keepassWindow.searchResults.length > 0) {
                                keepassWindow.selectedIndex = (keepassWindow.selectedIndex >= keepassWindow.searchResults.length - 1)
                                    ? 0 : keepassWindow.selectedIndex + 1;
                            }
                            event.accepted = true;
                        }
                        Keys.onBacktabPressed: event => {
                            if (keepassWindow.searchResults.length > 0) {
                                keepassWindow.selectedIndex = (keepassWindow.selectedIndex <= 0)
                                    ? keepassWindow.searchResults.length - 1 : keepassWindow.selectedIndex - 1;
                            }
                            event.accepted = true;
                        }

                        onTextChanged: {
                            keepassWindow.searchText = text;
                            keepassWindow.selectedIndex = 0;
                            KeepassBackend.search(text, keepassWindow.activeWindowTitle);
                        }
                    }

                    Rectangle {
                        id: lockBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        color: lockMouse.containsMouse ? Theme.bubble_hover : Theme.bubble
                        border.width: 1
                        border.color: Theme.bubble_border_soft
                        clip: true

                        BubbleSheen {}

                        MaterialIcon {
                            anchors.centerIn: parent
                            z: 1
                            icon: "lock"
                            font.pixelSize: 16
                            color: Theme.on_surface_variant
                        }

                        MouseArea {
                            id: lockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                KeepassBackend.lock();
                                keepassWindow.closeMenu();
                            }
                        }
                    }
                }

                Text {
                    anchors.top: searchBar.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    text: searchResults.length + (searchResults.length === 1 ? " entry" : " entries")
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    color: Theme.on_surface_variant
                    visible: searchResults.length > 0
                }

                ListView {
                    id: entriesList
                    anchors.top: searchBar.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 24
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.bottomMargin: 10
                    clip: true
                    spacing: 2
                    currentIndex: keepassWindow.selectedIndex
                    model: keepassWindow.searchResults

                    delegate: Item {
                        id: delegateRoot
                        width: ListView.view.width
                        height: 56

                        property bool isSelected: index === keepassWindow.selectedIndex
                        property bool isHovered: delegateMouse.containsMouse

                        Rectangle {
                            id: delegateBg
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: 14
                            color: delegateRoot.isSelected
                                ? Theme.glass_selected
                                : (delegateRoot.isHovered ? Theme.glass_hover : "transparent")
                            border.width: delegateRoot.isSelected ? 1 : 0
                            border.color: Theme.glass_border
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: delegateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: keepassWindow.selectedIndex = index
                                onClicked: {
                                    keepassWindow.closeMenu();
                                    KeepassBackend.entrySelected(modelData);
                                }
                            }

                            Rectangle {
                                width: 3
                                height: delegateRoot.isSelected ? parent.height * 0.45 : 0
                                opacity: delegateRoot.isSelected ? 1.0 : 0.0
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 2
                                color: Theme.primary
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 14
                                spacing: 12

                                Rectangle {
                                    width: 36; height: 36
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.glass_raised
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "key"
                                        font.pixelSize: 18
                                        color: delegateRoot.isSelected ? Theme.primary : Theme.on_surface_variant
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 36 - 12 - badgeRow.width - 8

                                    Text {
                                        text: modelData.title || ""
                                        textFormat: Text.PlainText
                                        width: parent.width
                                        font.family: "Google Sans"
                                        font.pixelSize: 14
                                        font.weight: delegateRoot.isSelected ? Font.DemiBold : Font.Medium
                                        color: Theme.on_surface
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.username || ""
                                        textFormat: Text.PlainText
                                        width: parent.width
                                        font.family: "Google Sans"
                                        font.pixelSize: 11
                                        color: Theme.on_surface_variant
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }
                            }

                            Row {
                                id: badgeRow
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    visible: modelData.has_otp
                                    width: otpLabel.implicitWidth + 12
                                    height: 20; radius: 10
                                    color: Theme.glass_tertiary_soft
                                    border.width: 1
                                    border.color: Theme.glass_border
                                    Text {
                                        id: otpLabel
                                        anchors.centerIn: parent
                                        text: "OTP"
                                        font.family: "Google Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.tertiary
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 28
                    spacing: 8
                    visible: isUnlocked && searchResults.length === 0

                    MaterialIcon {
                        icon: keepassWindow.searchText !== "" ? "search_off" : "vpn_key"
                        font.pixelSize: 40
                        color: Theme.on_surface_variant
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.45
                    }
                    Text {
                        text: keepassWindow.searchText !== "" ? "No matching entries" : "No entries found"
                        font.family: "Google Sans"
                        font.pixelSize: 14
                        color: Theme.on_surface_variant
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
