import Quickshell
import Quickshell.Wayland

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    property int hoveredNotificationId: -1

    delegate: PanelWindow {
        id: notificationPopup

        required property var modelData
        screen: modelData

        property var notificationEntries: ({})

        ListModel {
            id: notifModel
        }

        function addOrUpdateNotification(notification) {
            let idStr = notification.id.toString();
            let temp = {};
            for (let k in notificationEntries) {
                temp[k] = notificationEntries[k];
            }
            temp[idStr] = notification;
            notificationEntries = temp;

            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).notifId === idStr) {
                    return;
                }
            }
            notifModel.insert(0, {
                notifId: idStr,
                notifType: "notification"
            });
        }

        Connections {
            target: Screenshot
            function onActiveChanged() {
                if (Screenshot.active) {
                    let found = false;
                    for (let i = 0; i < notifModel.count; i++) {
                        if (notifModel.get(i).notifType === "screenshot") {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        notifModel.insert(0, {
                            notifId: "screenshot_id",
                            notifType: "screenshot"
                        });
                    }
                }
            }
        }

        Connections {
            target: ScreenRecord
            function onActiveChanged() {
                if (ScreenRecord.active) {
                    let found = false;
                    for (let i = 0; i < notifModel.count; i++) {
                        if (notifModel.get(i).notifType === "recording") {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        notifModel.insert(0, {
                            notifId: "recording_id",
                            notifType: "recording"
                        });
                    }
                }
            }
        }

        function disposeNotification(notificationId) {
            let idStr = notificationId.toString();
            let temp = {};
            for (let k in notificationEntries) {
                if (k !== idStr) {
                    temp[k] = notificationEntries[k];
                }
            }
            notificationEntries = temp;

            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).notifId === idStr) {
                    if (notifModel.get(i).notifType === "screenshot") {
                        Screenshot.active = false;
                    } else if (notifModel.get(i).notifType === "recording") {
                        ScreenRecord.active = false;
                    }
                    notifModel.remove(i, 1);
                    return;
                }
            }
        }

        visible: true
        property bool hasNotifications: notifModel.count > 0

        Timer {
            id: exitTimer
            interval: 350
            running: !hasNotifications
        }

        readonly property bool surfaceMapped: hasNotifications || exitTimer.running

        implicitWidth: surfaceMapped ? 390 : 0
        implicitHeight: surfaceMapped ? modelData.height : 0

        mask: Region {
            item: clickHitbox
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification_overlay"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        color: "transparent"

        anchors {
            top: true
            right: true
        }

        margins {
            top: 40
            right: 5
        }

        Connections {
            target: NotifServer
            function onNotification(notification) {
                if (DoNotDisturb.enabled)
                    return;

                notificationPopup.addOrUpdateNotification(notification);
            }
        }

        Item {
            id: clickHitbox
            width: notificationStack.width
            height: notificationStack.activeStackHeight
            anchors {
                top: notificationStack.top
                right: notificationStack.right
            }
        }

        Item {
            id: notificationStack

            visible: {
                return surfaceMapped;
            }

            width: 350
            height: parent.height

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 20
            }

            property var cardHeights: []

            property real activeStackHeight: 0
            onCardHeightsChanged: {
                activeStackHeight = yForIndex(notifModel.count);
            }

            function getCardHeight(id) {
                for (let i = 0; i < cardHeights.length; i++) {
                    if (cardHeights[i].notifId === id)
                        return cardHeights[i].h;
                }
                return 0;
            }

            function setCardHeight(id, h) {
                for (let i = 0; i < cardHeights.length; i++) {
                    if (cardHeights[i].notifId === id) {
                        if (cardHeights[i].h === h)
                            return;
                        cardHeights[i].h = h;
                        cardHeightsChanged();
                        return;
                    }
                }
                cardHeights.push({
                    notifId: id,
                    h: h
                });
                cardHeightsChanged();
            }

            function removeCardHeight(id) {
                const idx = cardHeights.findIndex(e => e.notifId === id);
                if (idx !== -1) {
                    cardHeights.splice(idx, 1);
                    cardHeightsChanged();
                }
            }

            function yForIndex(idx) {
                const spacing = 14;
                let y = 0;
                for (let i = 0; i < idx; i++) {
                    const id = notifModel.get(i).notifId;
                    y += getCardHeight(id) + spacing;
                }
                return y;
            }

            Repeater {
                model: notifModel

                delegate: Item {
                    id: cardDelegate

                    required property int index
                    required property var notifId
                    required property string notifType
                    readonly property var notificationEntry: notificationPopup.notificationEntries[notifId.toString()]

                    width: 350
                    height: notificationCard.height + 20

                    x: 0
                    y: notificationStack.yForIndex(index)

                    Behavior on y {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }

                    property bool slidingOut: false

                    function slideOut() {
                        if (slidingOut)
                            return;
                        slidingOut = true;
                        expiryAnim.stop();
                        slideOutAnim.start();
                    }

                    Component.onCompleted: {
                        notificationStack.setCardHeight(notifId, notificationCard.height);
                        x = 390;
                        opacity = 0;
                        slideIn.start();
                        // Universal timer initialization
                        lifeSpanProgress = 1.0;
                        expiryAnim.duration = 7000;
                        expiryAnim.restart();
                        updateExpiryPaused();
                    }

                    Component.onDestruction: {
                        notificationStack.removeCardHeight(notifId);

                        if (root.hoveredNotificationId === notifId) {
                            root.hoveredNotificationId = -1;
                        }
                    }

                    onHeightChanged: {
                        notificationStack.setCardHeight(notifId, notificationCard.height);
                    }

                    ParallelAnimation {
                        id: slideIn
                        NumberAnimation {
                            target: cardDelegate
                            property: "x"
                            to: 0
                            duration: 350
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.05
                        }
                        NumberAnimation {
                            target: cardDelegate
                            property: "opacity"
                            to: 1
                            duration: 250
                        }
                    }

                    ParallelAnimation {
                        id: slideOutAnim
                        NumberAnimation {
                            target: cardDelegate
                            property: "x"
                            to: 390
                            duration: 320
                            easing.type: Easing.InBack
                            easing.overshoot: 1.1
                        }
                        NumberAnimation {
                            target: cardDelegate
                            property: "opacity"
                            to: 0
                            duration: 220
                        }
                        onFinished: notificationPopup.disposeNotification(notifId)
                    }

                    readonly property string applicationName: {
                        if (notifType === "screenshot") return "Screenshot";
                        if (notifType === "recording") return "Recording";
                        if (!notificationEntry) return "Notification";
                        return notificationEntry.appName || "Notification";
                    }
                    readonly property var applicationIcon: {
                        if (notifType === "screenshot" || notifType === "recording") return "";
                        if (!notificationEntry) return "";
                        if (notificationEntry.image && notificationEntry.image.length > 0) return notificationEntry.image;
                        if (notificationEntry.appIcon && notificationEntry.appIcon.length > 0) return Quickshell.iconPath(notificationEntry.appIcon, true) || "";
                        return "";
                    }

                    property real lifeSpanProgress: 1.0

                    onNotificationEntryChanged: {
                        if (slidingOut)
                            return;
                        lifeSpanProgress = 1.0;
                        expiryAnim.duration = 7000;
                        expiryAnim.restart();
                        updateExpiryPaused();
                    }

                    Connections {
                        target: (notifType === "notification" && notificationEntry) ? notificationEntry : null
                        function onClosed(reason) {
                            cardDelegate.slideOut();
                        }
                    }

                    readonly property bool isOnFocusedScreen: true

                    property bool expireCalled: false

                    function updateExpiryPaused() {
                        if (!expiryAnim.running)
                            return;
                        const shouldPause = !isOnFocusedScreen || root.hoveredNotificationId === notifId;
                        if (shouldPause && !expiryAnim.paused) {
                            expiryAnim.pause();
                        }
                        if (!shouldPause && expiryAnim.paused) {
                            expiryAnim.duration = 7000 * cardDelegate.lifeSpanProgress;
                            expiryAnim.resume();
                        }
                    }

                    Connections {
                        target: root
                        function onHoveredNotificationIdChanged() {
                            cardDelegate.updateExpiryPaused();
                        }
                    }

                    Connections {
                        target: Screenshot
                        function onActiveChanged() {
                            if (notifType === "screenshot" && !Screenshot.active) {
                                cardDelegate.slideOut();
                            }
                        }
                    }

                    Connections {
                        target: ScreenRecord
                        function onActiveChanged() {
                            if (notifType === "recording" && !ScreenRecord.active) {
                                cardDelegate.slideOut();
                            }
                        }
                    }

                    NumberAnimation {
                        id: expiryAnim
                        target: cardDelegate
                        property: "lifeSpanProgress"
                        from: 1.0
                        to: 0.0
                        duration: 7000
                        running: true // Both standard notifications and screenshots have auto-close

                        onRunningChanged: {
                            if (running) {
                                cardDelegate.updateExpiryPaused();
                            }
                        }

                        onFinished: {
                            if (cardDelegate.lifeSpanProgress > 0.01)
                                return;
                            if (cardDelegate.slidingOut)
                                return;
                            if (cardDelegate.expireCalled)
                                return;
                            cardDelegate.expireCalled = true;

                            if (notifType === "screenshot") {
                                Screenshot.dismiss();
                            } else if (notifType === "recording") {
                                ScreenRecord.dismiss();
                            } else if (notificationEntry && typeof notificationEntry.expire === "function") {
                                notificationEntry.expire();
                            }
                        }
                    }

                    Rectangle {
                        id: notificationCard

                        width: parent.width
                        height: layoutContent.implicitHeight + 36
                        y: 4

                        radius: 28
                        color: Theme.surface_container

                        border.color: Theme.outline_variant !== undefined ? Theme.outline_variant : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.15)
                        border.width: 1

                        scale: interactionArea.pressed ? 0.975 : 1.0
                        layer.enabled: true

                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#40000000"
                            blurMax: 32
                            shadowBlur: interactionArea.containsMouse ? 1.0 : 0.85
                            shadowVerticalOffset: interactionArea.containsMouse ? 6 : 4

                            Behavior on shadowBlur {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on shadowVerticalOffset {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: {
                                if (interactionArea.pressed)
                                    return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.10);
                                if (interactionArea.containsMouse)
                                    return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                return "transparent";
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: interactionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                if (!cardDelegate.slidingOut) {
                                    root.hoveredNotificationId = notifId;
                                }
                            }
                            onExited: {
                                if (root.hoveredNotificationId === notifId) {
                                    root.hoveredNotificationId = -1;
                                }
                            }

                            onClicked: {
                                if (cardDelegate.slidingOut)
                                    return;

                                if (notifType === "screenshot" || notifType === "recording")
                                    return;

                                let invoked = false;
                                if (notificationEntry && notificationEntry.actions) {
                                    for (let i = 0; i < notificationEntry.actions.length; i++) {
                                        if (notificationEntry.actions[i].identifier === "default") {
                                            if (typeof notificationEntry.actions[i].invoke === "function") {
                                                notificationEntry.actions[i].invoke();
                                            }
                                            invoked = true;
                                            break;
                                        }
                                    }
                                }

                                if (!invoked && notificationEntry && typeof notificationEntry.dismiss === "function") {
                                    notificationEntry.dismiss();
                                }
                            }
                        }

                        Column {
                            id: layoutContent
                            width: parent.width - 40
                            anchors.centerIn: parent
                            spacing: 4

                            Item {
                                width: parent.width
                                height: 32

                                Item {
                                    id: headerIconWrapper
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: notifType === "recording" ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22) : Theme.primary_container
                                        visible: notifType === "screenshot" || notifType === "recording" || !cardDelegate.applicationIcon

                                        Text {
                                            anchors.centerIn: parent
                                            text: notifType === "screenshot" ? "󰹑" : (notifType === "recording" ? "󰕧" : "!")
                                            color: notifType === "recording" ? Theme.critical : Theme.on_primary_container
                                            font {
                                                family: (notifType === "screenshot" || notifType === "recording") ? "JetBrainsMono Nerd Font" : "Google Sans Medium"
                                                pixelSize: 13
                                                bold: notifType !== "screenshot" && notifType !== "recording"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: headerMask
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "black"
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: cardDelegate.applicationIcon
                                        fillMode: Image.PreserveAspectCrop
                                        visible: !!cardDelegate.applicationIcon && notifType !== "screenshot" && notifType !== "recording"
                                        layer.enabled: true
                                        layer.smooth: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: headerMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }
                                    }
                                }

                                Text {
                                    text: cardDelegate.applicationName
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: headerIconWrapper.right
                                    anchors.leftMargin: 12
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 14
                                    }
                                }

                                Rectangle {
                                    id: closeAction
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: "transparent"
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    Shape {
                                        anchors.fill: parent
                                        antialiasing: true
                                        preferredRendererType: Shape.CurveRenderer

                                        ShapePath {
                                            fillColor: "transparent"
                                            strokeColor: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.2)
                                            strokeWidth: 4
                                            capStyle: ShapePath.RoundCap
                                            PathAngleArc {
                                                centerX: closeAction.width / 2
                                                centerY: closeAction.height / 2
                                                radiusX: (closeAction.width / 2) - 2.5
                                                radiusY: (closeAction.height / 2) - 2.5
                                                startAngle: 0
                                                sweepAngle: 360
                                            }
                                        }

                                        ShapePath {
                                            fillColor: "transparent"
                                            strokeColor: Theme.critical
                                            strokeWidth: 4
                                            capStyle: ShapePath.RoundCap
                                            PathAngleArc {
                                                centerX: closeAction.width / 2
                                                centerY: closeAction.height / 2
                                                radiusX: (closeAction.width / 2) - 2.5
                                                radiusY: (closeAction.height / 2) - 2.5
                                                startAngle: -90
                                                sweepAngle: cardDelegate.lifeSpanProgress * 360
                                            }
                                        }
                                    }

                                    Item {
                                        anchors.centerIn: parent
                                        width: 12
                                        height: 12
                                        rotation: 45

                                        Rectangle {
                                            width: 2
                                            height: parent.height
                                            anchors.centerIn: parent
                                            radius: 1
                                            color: closeMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                            antialiasing: true
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }
                                        Rectangle {
                                            width: parent.width
                                            height: 2
                                            anchors.centerIn: parent
                                            radius: 1
                                            color: closeMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                            antialiasing: true
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: closeMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onEntered: {
                                            if (!cardDelegate.slidingOut) {
                                                closeAction.color = Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                            }
                                        }
                                        onExited: closeAction.color = "transparent"

                                        onClicked: event => {
                                            event.accepted = true;
                                            if (cardDelegate.slidingOut)
                                                return;

                                            if (notifType === "screenshot") {
                                                Screenshot.dismiss();
                                                return;
                                            }

                                            if (notifType === "recording") {
                                                ScreenRecord.dismiss();
                                                return;
                                            }

                                            if (notificationEntry && typeof notificationEntry.dismiss === "function") {
                                                notificationEntry.dismiss();
                                            }
                                        }
                                    }
                                }
                            }

                            Loader {
                                width: parent.width
                                sourceComponent: {
                                    if (notifType === "screenshot")
                                        return screenshotContent;
                                    if (notifType === "recording")
                                        return recordingContent;
                                    return notificationContent;
                                }
                            }
                        }
                    }

                    Component {
                        id: notificationContent
                        Column {
                            width: layoutContent.width
                            spacing: 4

                            Text {
                                text: notificationEntry ? notificationEntry.summary : ""
                                color: Theme.on_surface
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                    bold: true
                                }
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            Text {
                                text: notificationEntry ? notificationEntry.body : ""
                                color: Theme.on_surface_variant
                                font {
                                    family: "Google Sans"
                                    pixelSize: 14
                                }
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Component {
                        id: screenshotContent
                        Column {
                            width: layoutContent.width
                            spacing: 10

                            // --- Screenshot Preview ---
                            Rectangle {
                                id: previewContainer
                                width: parent.width
                                height: Math.min(width * 0.5625, 160)
                                radius: 16
                                color: Theme.surface_container_high
                                clip: true

                                Image {
                                    id: previewImg
                                    anchors.fill: parent
                                    source: Screenshot.imagePath ? ("file://" + Screenshot.imagePath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: previewMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }

                                Rectangle {
                                    id: previewMask
                                    anchors.fill: parent
                                    radius: parent.radius
                                    visible: false
                                    layer.enabled: true
                                }
                            }

                            // --- Action Buttons ---
                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 8

                                component ActionPill: Rectangle {
                                    id: pill
                                    property string icon
                                    property string label
                                    property bool done: false
                                    property bool busy: false

                                    width: (parent.width - 8) / 2
                                    height: 36
                                    radius: 18
                                    color: {
                                        if (done) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                                        if (pillMouse.containsMouse) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14);
                                        return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                    }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    signal triggered()

                                    scale: pillMouse.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: pill.done ? "󰄬" : (pill.busy ? "󰦖" : pill.icon)
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                            color: pill.done ? Theme.primary : Theme.on_surface_variant

                                            RotationAnimation on rotation {
                                                running: pill.busy
                                                from: 0; to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: pill.label
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: pill.done ? Theme.primary : Theme.on_surface
                                            Behavior on color { ColorAnimation { duration: 150 } }
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

                                Timer {
                                    id: closeDelayTimer
                                    interval: 400
                                    onTriggered: Screenshot.dismiss()
                                }

                                ActionPill {
                                    icon: "󰆏"
                                    label: "Copy"
                                    done: Screenshot.wasCopied
                                    onTriggered: {
                                        Screenshot.copyToClipboard();
                                        closeDelayTimer.start();
                                    }
                                }

                                ActionPill {
                                    icon: "󰈝"
                                    label: "Save"
                                    done: Screenshot.wasSaved
                                    onTriggered: {
                                        Screenshot.save();
                                        closeDelayTimer.start();
                                    }
                                }

                                ActionPill {
                                    icon: "󰏫"
                                    label: "Draw"
                                    onTriggered: Screenshot.editorActive = true
                                }

                                ActionPill {
                                    icon: "󰊄"
                                    label: "OCR Text"
                                    done: Screenshot.wasOcred
                                    busy: Screenshot.ocring
                                    onTriggered: Screenshot.ocr()
                                }
                            }
                        }
                    }

                    Component {
                        id: recordingContent
                        Column {
                            width: layoutContent.width
                            spacing: 10

                            Rectangle {
                                width: parent.width
                                height: Math.min(width * 0.5625, 160)
                                radius: 16
                                color: Theme.surface_container_high
                                clip: true

                                Image {
                                    id: recPreviewImg
                                    anchors.fill: parent
                                    source: ScreenRecord.thumbPath ? ("file://" + ScreenRecord.thumbPath + "?t=" + ScreenRecord.fileName) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    visible: status === Image.Ready

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: recPreviewMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }

                                Rectangle {
                                    id: recPreviewMask
                                    anchors.fill: parent
                                    radius: parent.radius
                                    visible: false
                                    layer.enabled: true
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: recPreviewImg.status !== Image.Ready

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "󰕧"
                                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
                                        color: Theme.on_surface_variant
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.parent.width - 24
                                        horizontalAlignment: Text.AlignHCenter
                                        text: ScreenRecord.fileName
                                        elide: Text.ElideMiddle
                                        font { family: "Google Sans"; pixelSize: 12 }
                                        color: Theme.on_surface_variant
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                    width: Math.min(fileChipText.implicitWidth + 16, parent.width - 20)
                                    height: 24
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    visible: recPreviewImg.status === Image.Ready

                                    Text {
                                        id: fileChipText
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        text: ScreenRecord.fileName
                                        elide: Text.ElideMiddle
                                        color: "#ffffff"
                                        font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                    }
                                }
                            }

                            Grid {
                                width: parent.width
                                columns: 2
                                spacing: 8

                                component RecActionPill: Rectangle {
                                    id: recPill
                                    property string icon
                                    property string label
                                    property bool done: false
                                    property bool danger: false

                                    width: (parent.width - 8) / 2
                                    height: 36
                                    radius: 18
                                    color: {
                                        if (done) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18);
                                        if (danger && recPillMouse.containsMouse)
                                            return Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22);
                                        if (recPillMouse.containsMouse)
                                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14);
                                        return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                    }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    signal triggered()

                                    scale: recPillMouse.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: recPill.done ? "󰄬" : recPill.icon
                                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                                            color: {
                                                if (recPill.done) return Theme.primary;
                                                if (recPill.danger) return Theme.critical;
                                                return Theme.on_surface_variant;
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: recPill.label
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: {
                                                if (recPill.done) return Theme.primary;
                                                if (recPill.danger) return Theme.critical;
                                                return Theme.on_surface;
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: recPillMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: recPill.triggered()
                                    }
                                }

                                Timer {
                                    id: recCloseDelay
                                    interval: 400
                                    onTriggered: ScreenRecord.dismiss()
                                }

                                RecActionPill {
                                    icon: "󰈈"
                                    label: "Open"
                                    done: ScreenRecord.wasOpened
                                    onTriggered: {
                                        ScreenRecord.openFile();
                                        recCloseDelay.start();
                                    }
                                }

                                RecActionPill {
                                    icon: "󰆴"
                                    label: "Remove"
                                    danger: true
                                    done: ScreenRecord.wasRemoved
                                    onTriggered: {
                                        ScreenRecord.removeFile();
                                        recCloseDelay.start();
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
