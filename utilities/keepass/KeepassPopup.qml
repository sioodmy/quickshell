import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import "../../theme"
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
    WlrLayershell.namespace: "keepass_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    readonly property bool isUnlocked: KeepassBackend.isUnlocked
    property var searchResults: []
    property string searchText: ""
    readonly property bool authenticating: KeepassBackend.unlockPending
    property string authError: ""
    property bool menuOpen: false
    property real openProgress: 0.0
    property int selectedIndex: 0

    onMenuOpenChanged: {
        if (!menuOpen) {
            passwordInput.clear();
            if (authenticating) KeepassBackend.lock();
        }
    }

    NumberAnimation {
        id: openAnim
        target: keepassWindow
        property: "openProgress"
        from: 0; to: 1
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: keepassWindow
        property: "openProgress"
        from: 1; to: 0
        duration: 150
        easing.type: Easing.InCubic
        onFinished: keepassWindow.menuOpen = false
    }

    function openMenu() {
        if (SessionState.locked || menuOpen) return;
        closeAnim.stop();
        menuOpen = true;
        authError = "";
        if (isUnlocked) {
            searchInput.text = "";
            KeepassBackend.search("");
            searchInput.forceActiveFocus();
        } else {
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
        openAnim.start();
    }

    function closeMenu() {
        passwordInput.clear();
        authError = "";
        if (authenticating) KeepassBackend.lock();
        if (!menuOpen) return;
        menuOpen = false;
        openAnim.stop();
        closeAnim.start();
    }

    function toggle() {
        if (menuOpen) closeMenu();
        else openMenu();
    }

    onVisibleChanged: {
        if (visible && menuOpen) {
            if (isUnlocked) {
                searchInput.forceActiveFocus();
            } else {
                passwordInput.forceActiveFocus();
            }
        }
    }

    Connections {
        target: KeepassBackend
        function onUnlocked(success, error) {
            passwordInput.clear();
            if (!menuOpen) return;
            if (success) {
                authError = "";
                KeepassBackend.search("");
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

    // Scrim
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: keepassWindow.openProgress * 0.3
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: keepassWindow.closeMenu()
    }

    Item {
        id: mainUi
        enabled: keepassWindow.menuOpen && !SessionState.locked
        width: 600
        height: isUnlocked ? Math.min(520, 88 + Math.max((entriesList.contentHeight || 0) + 32, 120)) : 160
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18

        visible: keepassWindow.openProgress > 0
        opacity: keepassWindow.openProgress
        scale: 0.95 + (0.05 * keepassWindow.openProgress)
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // Shadow
        Rectangle {
            id: shadowCaster
            anchors.fill: parent
            anchors.margins: 4
            radius: bg.radius
            color: Theme.surface
            visible: false
        }

        MultiEffect {
            anchors.fill: shadowCaster
            source: shadowCaster
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#40000000"
            shadowVerticalOffset: 8
            shadowHorizontalOffset: 4
            opacity: keepassWindow.openProgress
            visible: keepassWindow.openProgress > 0
        }

        // Rounded mask
        Item {
            id: mainUiMask
            anchors.fill: parent
            visible: false
            layer.enabled: keepassWindow.openProgress > 0
            layer.smooth: true
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "black"
            }
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 28
            color: Theme.surface
            border.width: 1
            border.color: Theme.surface_container_high

            layer.enabled: keepassWindow.openProgress > 0
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mainUiMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            // Swallow clicks on the card so it doesn't dismiss
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
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (searchResults.length > 0 && selectedIndex >= 0 && selectedIndex < searchResults.length) {
                            keepassWindow.closeMenu();
                            KeepassBackend.entrySelected(searchResults[selectedIndex]);
                        }
                        event.accepted = true;
                    }
                }
            }

            // ─── Locked state ─────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: !isUnlocked
                opacity: !isUnlocked ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 20
                    width: parent.width - 64

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter

                        MaterialIcon {
                            icon: "lock"
                            font.pixelSize: 28
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "Unlock KeePass"
                                font.family: "Google Sans"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }
                            Text {
                                text: keepassWindow.authError !== "" ? keepassWindow.authError : "Enter master password"
                                textFormat: Text.PlainText
                                font.family: "Google Sans"
                                font.pixelSize: 13
                                color: keepassWindow.authError !== "" ? Theme.error : Theme.on_surface_variant
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: height / 2
                        color: Theme.surface_container_highest
                        border.width: 1
                        border.color: passwordInput.activeFocus ? Theme.primary : "transparent"

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Google Sans"
                            font.pixelSize: 20
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

                        // Shape glyphs overlay
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
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

                            // Caret
                            Rectangle {
                                width: 2; height: 16; radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.primary
                                visible: passwordInput.activeFocus && !keepassWindow.authenticating
                                opacity: 1
                                SequentialAnimation on opacity {
                                    running: passwordInput.activeFocus && !keepassWindow.authenticating
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 0 }
                                    PauseAnimation { duration: 530 }
                                    PropertyAction { value: 1 }
                                }
                            }

                            // Loading spinner
                            Shape {
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: keepassWindow.authenticating
                                layer.enabled: keepassWindow.authenticating
                                layer.samples: 4
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

                // Search bar
                Rectangle {
                    id: searchBar
                    z: 3
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    height: 56
                    radius: height / 2
                    color: Theme.surface_container_highest

                    layer.enabled: keepassWindow.openProgress > 0
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowBlur: 0.6
                        shadowColor: "#20000000"
                        shadowVerticalOffset: 3
                    }

                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "search"
                        font.pixelSize: 24
                        color: searchInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.right: lockBtn.left
                        anchors.leftMargin: 52
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: "Google Sans"
                        font.pixelSize: 18
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

                        onTextChanged: {
                            keepassWindow.searchText = text;
                            keepassWindow.selectedIndex = 0;
                            KeepassBackend.search(text);
                        }
                    }

                    // Lock button inside search bar
                    Rectangle {
                        id: lockBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; radius: 18
                        color: lockMouse.containsMouse ? Theme.surface_variant : "transparent"

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "lock"
                            font.pixelSize: 18
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

                // Entry count badge
                Text {
                    anchors.top: searchBar.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 36
                    text: searchResults.length + (searchResults.length === 1 ? " entry" : " entries")
                    font.family: "Google Sans"
                    font.pixelSize: 12
                    color: Theme.on_surface_variant
                    visible: searchResults.length > 0
                }

                // Entry list
                ListView {
                    id: entriesList
                    anchors.top: searchBar.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 28
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.bottomMargin: 8
                    clip: true
                    spacing: 2
                    currentIndex: keepassWindow.selectedIndex

                    model: keepassWindow.searchResults

                    delegate: Item {
                        id: delegateRoot
                        width: ListView.view.width
                        height: 64

                        property bool isSelected: index === keepassWindow.selectedIndex
                        property bool isHovered: delegateMouse.containsMouse

                        Rectangle {
                            id: delegateBg
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: 16

                            scale: delegateMouse.pressed ? 0.98 : (delegateRoot.isSelected || delegateRoot.isHovered ? 1.01 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            color: delegateRoot.isSelected ? Theme.secondary_container : (delegateRoot.isHovered ? Qt.lighter(Theme.surface_container_low, 1.08) : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }

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

                            // Active indicator bar
                            Rectangle {
                                width: 4
                                height: delegateRoot.isSelected ? parent.height * 0.5 : 0
                                opacity: delegateRoot.isSelected ? 1.0 : 0.0
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 2
                                color: Theme.primary
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 16
                                spacing: 14

                                // Icon
                                Rectangle {
                                    width: 42; height: 42
                                    radius: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: delegateRoot.isSelected ? Theme.surface : Theme.surface_container_low

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "key"
                                        font.pixelSize: 22
                                        color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                                    }
                                }

                                // Text
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 42 - 14 - 18 - 16 - badgeRow.width - 8

                                    Text {
                                        text: modelData.title || ""
                                        textFormat: Text.PlainText
                                        width: parent.width
                                        font.family: "Google Sans"
                                        font.pixelSize: 15
                                        font.weight: delegateRoot.isSelected ? Font.DemiBold : Font.Medium
                                        color: Theme.on_surface
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.username || ""
                                        textFormat: Text.PlainText
                                        width: parent.width
                                        font.family: "Google Sans"
                                        font.pixelSize: 12
                                        color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }
                            }

                            // Badges
                            Row {
                                id: badgeRow
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    visible: modelData.has_otp
                                    width: otpLabel.implicitWidth + 12
                                    height: 20; radius: 10
                                    color: Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.15)
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

                // Empty state
                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 40
                    spacing: 8
                    visible: isUnlocked && searchResults.length === 0

                    MaterialIcon {
                        icon: keepassWindow.searchText !== "" ? "search_off" : "vpn_key"
                        font.pixelSize: 48
                        color: Theme.on_surface_variant
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.5
                    }
                    Text {
                        text: keepassWindow.searchText !== "" ? "No matching entries" : "No entries found"
                        font.family: "Google Sans"
                        font.pixelSize: 15
                        color: Theme.on_surface_variant
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
