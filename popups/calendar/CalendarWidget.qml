import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import qs.theme
import qs.services

PanelWindow {
    id: root

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "calendar_widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property real openProgress: 0
    property bool animating: openAnim.running || closeAnim.running
    property bool closing: false

    // Morph endpoints in this window's coordinates
    property real morphFromX: 0
    property real morphFromY: 0
    property real morphFromW: 28
    property real morphFromH: 40
    property real morphToX: 0
    property real morphToY: 0
    property real morphToW: 100
    property real morphToH: 36

    readonly property real morphEased: {
        // Smooth ease-out cubic with a slight settle
        const t = openProgress;
        return 1 - Math.pow(1 - t, 3);
    }

    onOpenProgressChanged: {
        CalendarState.openProgress = openProgress;
        // Refine landing pad once the panel has laid out
        if (!closing && openProgress > 0.15 && openProgress < 0.45)
            captureTargets();
    }

    function lerp(a, b, t) {
        return a + (b - a) * t;
    }

    function captureTargets() {
        const src = root.contentItem.mapFromGlobal(CalendarState.sourceX, CalendarState.sourceY);
        morphFromX = src.x;
        morphFromY = src.y;
        morphFromW = CalendarState.sourceW;
        morphFromH = CalendarState.sourceH;

        if (calendarGrid.agendaTimeLabel) {
            const label = calendarGrid.agendaTimeLabel;
            const dest = label.mapToItem(root.contentItem, 0, 0);
            morphToX = dest.x;
            morphToY = dest.y;
            morphToW = Math.max(label.width, label.implicitWidth);
            morphToH = Math.max(label.height, label.implicitHeight);
        }
    }

    function openAnimated() {
        closing = false;
        openProgress = 0;
        CalendarState.open = true;
        visible = true;
        // Wait a frame so AgendaPane has laid out the target time label
        layoutTimer.restart();
    }

    function closeAnimated() {
        if (!visible && openProgress <= 0)
            return;
        closing = true;
        CalendarState.open = false;
        captureTargets();
        closeAnim.start();
    }

    Timer {
        id: layoutTimer
        interval: 16
        repeat: false
        onTriggered: {
            captureTargets();
            // Re-capture once more after fonts settle for accurate landing
            Qt.callLater(captureTargets);
            openAnim.start();
            calendarGrid.forceActiveFocus();
        }
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "openProgress"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: {
            CalendarState.openProgress = 1;
        }
    }

    NumberAnimation {
        id: closeAnim
        target: root
        property: "openProgress"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: {
            closing = false;
            visible = false;
            CalendarState.open = false;
            CalendarState.openProgress = 0;
        }
    }

    // Click-away to dismiss
    MouseArea {
        anchors.fill: parent
        enabled: root.openProgress > 0.85 && !root.closing
        onClicked: root.closeAnimated()
    }

    // Panel shell — fades/scales in while the clock flies
    Item {
        id: panelHost
        width: 640
        height: 560
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        // Reveal with the morph — panel should feel immediate
        opacity: Math.max(0, Math.min(1, root.openProgress / 0.35))
        scale: 0.97 + 0.03 * Math.min(1, root.openProgress / 0.4)
        transformOrigin: Item.Left

        Rectangle {
            id: shadowCaster
            x: 44
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: parent.width - 44
            radius: 26
            color: "black"
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
            opacity: panelHost.opacity
        }

        Item {
            id: mainUiMask
            anchors.fill: mainUi
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "black"
            }
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 48
                color: "black"
            }
        }

        Rectangle {
            id: mainUi
            anchors.fill: parent
            color: Theme.surface
            radius: 28
            border.width: 1
            border.color: Theme.surface_container_high

            MouseArea {
                anchors.fill: parent
            }

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mainUiMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            CalendarGrid {
                id: calendarGrid
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 48

                isWindowVisible: root.visible
                clockSettled: root.openProgress >= 0.85

                onRequestClose: root.closeAnimated()
            }
        }
    }

    // Flying morph clock — travels from dock digits into the agenda time
    Item {
        id: morphClock
        visible: root.openProgress > 0.001 && root.openProgress < 0.999
        z: 100
        opacity: {
            if (root.openProgress < 0.75)
                return 1;
            // Crossfade into the settled agenda time
            return Math.max(0, (1.0 - root.openProgress) / 0.25);
        }

        readonly property real p: root.morphEased
        readonly property real fontPx: root.lerp(17, 32, p)
        readonly property real colonGap: root.lerp(0, 1, Math.min(1, p * 1.4))
        readonly property real hoursW: hoursMetrics.width
        readonly property real minsW: minsMetrics.width
        readonly property real colonW: colonMetrics.width * colonOpacity
        readonly property real colonOpacity: Math.max(0, Math.min(1, (p - 0.12) / 0.4))
        readonly property real rowW: hoursW + colonW + minsW + colonGap * 4
        readonly property real rowH: fontPx * 1.15

        width: root.lerp(root.morphFromW, rowW, p)
        height: root.lerp(root.morphFromH, rowH, p)

        // Center-to-center flight path with a slight arc
        x: {
            const fromCx = root.morphFromX + root.morphFromW / 2;
            const toCx = root.morphToX + root.morphToW / 2;
            return root.lerp(fromCx, toCx, p) - width / 2;
        }
        y: {
            const fromCy = root.morphFromY + root.morphFromH / 2;
            const toCy = root.morphToY + root.morphToH / 2;
            const base = root.lerp(fromCy, toCy, p) - height / 2;
            const arc = -10 * Math.sin(Math.PI * p);
            return base + arc;
        }

        scale: 1.0 + 0.03 * Math.sin(Math.PI * p)

        TextMetrics {
            id: hoursMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.Black
            text: CalendarState.hoursText
        }
        TextMetrics {
            id: minsMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.Black
            text: CalendarState.minutesText
        }
        TextMetrics {
            id: colonMetrics
            font.family: "Google Sans"
            font.pixelSize: morphClock.fontPx
            font.weight: Font.Black
            text: ":"
        }

        readonly property color fromColor: Theme.on_surface
        readonly property color toColor: Theme.primary
        readonly property color textColor: Qt.rgba(
            root.lerp(fromColor.r, toColor.r, p),
            root.lerp(fromColor.g, toColor.g, p),
            root.lerp(fromColor.b, toColor.b, p),
            1
        )

        Text {
            id: hoursText
            text: CalendarState.hoursText
            color: morphClock.textColor
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: morphClock.p > 0.5 ? Font.Black : Font.Bold
            }
            x: root.lerp((morphClock.width - hoursText.width) / 2, 0, morphClock.p)
            y: root.lerp(0, (morphClock.height - hoursText.height) / 2, morphClock.p)
        }

        Text {
            id: colonText
            text: ":"
            color: morphClock.textColor
            opacity: morphClock.colonOpacity
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: Font.Black
            }
            x: hoursText.x + hoursText.width + morphClock.colonGap
            y: (morphClock.height - height) / 2
        }

        Text {
            id: minsText
            text: CalendarState.minutesText
            color: morphClock.textColor
            font {
                family: "Google Sans"
                pixelSize: morphClock.fontPx
                weight: morphClock.p > 0.5 ? Font.Black : Font.Bold
            }
            x: root.lerp(
                (morphClock.width - minsText.width) / 2,
                hoursText.x + hoursText.width + morphClock.colonGap + colonText.width * morphClock.colonOpacity + morphClock.colonGap,
                morphClock.p
            )
            y: root.lerp(hoursText.height, (morphClock.height - minsText.height) / 2, morphClock.p)
        }
    }

    // Escape to close
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeAnimated();
            event.accepted = true;
        }
    }
}
