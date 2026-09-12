import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.theme
import qs.components

PanelWindow {
    id: editorWindow

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: menuOpen || openAnim.running || closeAnim.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot-editor"
    WlrLayershell.keyboardFocus: menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property bool menuOpen: false
    property bool panelExpanded: false
    property real openProgress: 0.0
    property bool _framePresented: false

    readonly property real toolboxGap: 16
    readonly property real canvasMargin: 28
    readonly property real canvasRadius: 28
    readonly property real canvasPad: 14

    // Mirrored into plain props — self-referential Region bindings loop (see launcher).
    property real blurToolboxW: Math.max(1, LauncherState.dockWidth)
    property real blurToolboxH: Math.max(1, LauncherState.dockHeight)
    property real blurCanvasX: 0
    property real blurCanvasY: 0
    property real blurCanvasW: 0
    property real blurCanvasH: 0

    function syncBlurRegion() {
        blurToolboxW = Math.max(1, panelShell.width);
        blurToolboxH = Math.max(1, panelShell.height);
        if (canvasBubble.opacity > 0.001 && canvasBubble.width > 1 && canvasBubble.height > 1) {
            blurCanvasX = Math.round(canvasBubble.x);
            blurCanvasY = Math.round(canvasBubble.y);
            blurCanvasW = Math.round(canvasBubble.width);
            blurCanvasH = Math.round(canvasBubble.height);
        } else {
            blurCanvasW = 0;
            blurCanvasH = 0;
        }
    }

    // Fullscreen for click-away; only these rects go to ext-background-effect.
    // niri layer-rule sets xray false so windows under the glass are sampled.
    BackgroundEffect.blurRegion: Region {
        Region {
            x: Math.round((editorWindow.width - editorWindow.blurToolboxW) / 2)
            y: 0
            width: editorWindow.blurToolboxW
            height: editorWindow.blurToolboxH
            radius: 0
        }
        Region {
            x: editorWindow.blurCanvasX
            y: editorWindow.blurCanvasY
            width: editorWindow.blurCanvasW
            height: editorWindow.blurCanvasH
            radius: editorWindow.canvasRadius
        }
    }

    function _armRevealProbe() {
        revealFallback.restart();
    }

    Timer {
        id: revealFallback
        interval: 32
        onTriggered: {
            editorWindow._framePresented = true;
            editorWindow._beginReveal();
        }
    }

    function _beginReveal() {
        if (!menuOpen || openAnim.running || openProgress > 0)
            return;
        revealFallback.stop();
        panelExpanded = true;
        openAnim.start();
    }

    NumberAnimation {
        id: openAnim
        target: editorWindow
        property: "openProgress"
        from: 0; to: 1
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: Screenshot.openProgress = 1.0
    }

    NumberAnimation {
        id: closeAnim
        target: editorWindow
        property: "openProgress"
        to: 0
        duration: 200
        easing.type: Easing.InCubic
        onFinished: {
            editorWindow.menuOpen = false;
            editorWindow._framePresented = false;
            Screenshot.open = false;
            Screenshot.openProgress = 0.0;
            Screenshot.screen = null;
            Screenshot.editorActive = false;
            drawCanvas.clearCanvas();
            if (floatingTextInput.visible) {
                floatingTextInput.visible = false;
                floatingTextInput.text = "";
            }
        }
    }

    onOpenProgressChanged: Screenshot.openProgress = openProgress

    function resetEditor() {
        drawCanvas.clearCanvas();
        floatingTextInput.visible = false;
        floatingTextInput.text = "";
        drawCanvas.activeTool = "pencil";
        drawCanvas.drawColor = Theme.critical;
    }

    function openMenu() {
        if (SessionState.locked || menuOpen)
            return;

        // Claim the notch first — Island Draw dismisses in the same stack, and
        // the dock must already see overlayClaiming so it holds the island size.
        Screenshot.open = true;
        Screenshot.editorActive = true;
        Screenshot.screen = editorWindow.screen;

        if (LauncherState.open || LauncherState.openProgress > 0.001)
            LauncherState.requestClose();
        if (KeepassState.open || KeepassState.openProgress > 0.001)
            KeepassState.requestClose();

        closeAnim.stop();
        openProgress = 0;
        panelExpanded = false;
        _framePresented = false;
        menuOpen = true;
        resetEditor();
        syncBlurRegion();
        _armRevealProbe();
    }

    function closeMenu() {
        if (!menuOpen)
            return;
        if (floatingTextInput.visible) {
            floatingTextInput.visible = false;
            floatingTextInput.text = "";
        }
        revealFallback.stop();
        openAnim.stop();
        panelExpanded = false;
        // Keep Screenshot.open true until closeAnim finishes so the dock
        // notch stays expanded while content fades out.
        closeAnim.start();
    }

    Connections {
        target: Screenshot
        function onEditorActiveChanged() {
            if (Screenshot.editorActive && !editorWindow.menuOpen)
                editorWindow.openMenu();
            else if (!Screenshot.editorActive && editorWindow.menuOpen)
                editorWindow.closeMenu();
        }
        function onCloseRequested() {
            if (editorWindow.menuOpen || editorWindow.openProgress > 0)
                editorWindow.closeMenu();
        }
    }

    Connections {
        target: SessionState
        function onLockedChanged() {
            if (SessionState.locked)
                editorWindow.closeMenu();
        }
    }

    // Click-away to dismiss (no opaque scrim — glass shells only)
    MouseArea {
        anchors.fill: parent
        onClicked: editorWindow.closeMenu()
    }

    // Clip shell springs from dock/island footprint → toolbox size.
    Item {
        id: panelShell
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        clip: true
        z: 2
        enabled: editorWindow.menuOpen && !SessionState.locked

        width: editorWindow.panelExpanded
            ? Screenshot.editorTargetWidth
            : Math.max(1, LauncherState.dockWidth)
        height: editorWindow.panelExpanded
            ? Screenshot.editorTargetHeight
            : Math.max(1, LauncherState.dockHeight)

        Behavior on width {
            SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
        }
        Behavior on height {
            SpringAnimation { spring: 6; damping: 0.45; epsilon: 0.25 }
        }

        onWidthChanged: editorWindow.syncBlurRegion()
        onHeightChanged: editorWindow.syncBlurRegion()

        ClippingRectangle {
            id: toolboxUi
            width: Screenshot.editorTargetWidth
            height: Screenshot.editorTargetHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            color: Theme.glass_shell
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Screenshot.editorTargetRadius
            bottomRightRadius: Screenshot.editorTargetRadius
            border.width: 1
            border.color: Theme.glass_shell_border
            contentUnderBorder: true
            opacity: editorWindow.openProgress

            MouseArea { anchors.fill: parent }

            Row {
                id: topRow
                anchors.centerIn: parent
                spacing: 12

                component ActionBtn: Rectangle {
                    property string icon
                    property string label
                    property color baseColor: Theme.bubble
                    property color hoverColor: Theme.bubble_hover
                    property color contentColor: Theme.on_surface
                    signal clicked()

                    width: lbl.implicitWidth > 0 ? lbl.implicitWidth + icn.implicitWidth + 40 : 48
                    height: 48
                    radius: height / 2
                    color: m.containsMouse ? hoverColor : baseColor
                    border.width: 1
                    border.color: Theme.bubble_border
                    clip: true
                    scale: m.pressed ? 0.94 : 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    BubbleSheen {}

                    Item {
                        width: icn.implicitWidth + (lbl.implicitWidth > 0 ? 10 : 0) + lbl.implicitWidth
                        height: Math.max(icn.implicitHeight, lbl.implicitHeight)
                        anchors.centerIn: parent
                        z: 1

                        MaterialIcon {
                            id: icn
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            icon: parent.parent.icon
                            font.pixelSize: 20
                            color: parent.parent.contentColor
                        }
                        Text {
                            id: lbl
                            anchors.left: icn.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text.length > 0
                            text: parent.parent.label
                            font.family: "Google Sans Medium"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: parent.parent.contentColor
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

                ActionBtn {
                    icon: "close"
                    label: "Cancel"
                    onClicked: editorWindow.closeMenu()
                }

                ActionBtn {
                    icon: "undo"
                    label: "Undo"
                    onClicked: {
                        if (floatingTextInput.visible) {
                            floatingTextInput.visible = false;
                            floatingTextInput.text = "";
                        } else {
                            let s = drawCanvas.strokes;
                            if (s.length > 0) {
                                let last = s.pop();
                                if (last.type === "dot")
                                    drawCanvas.dotCounter--;
                                drawCanvas.strokes = s;
                                drawCanvas.requestPaint();
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bubble_border_soft
                    radius: 1
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    component ToolBtn: Rectangle {
                        property string icon
                        property string toolName

                        width: 42
                        height: 42
                        radius: 21
                        color: drawCanvas.activeTool === toolName
                            ? Theme.bubble_accent
                            : (mTool.containsMouse ? Theme.bubble_hover : Theme.bubble)
                        border.width: 1
                        border.color: drawCanvas.activeTool === toolName
                            ? Qt.alpha(Theme.primary, 0.5)
                            : Theme.bubble_border_soft
                        clip: true

                        Behavior on color { ColorAnimation { duration: 150 } }

                        BubbleSheen {}

                        MaterialIcon {
                            anchors.centerIn: parent
                            z: 1
                            icon: parent.icon
                            font.pixelSize: 20
                            color: drawCanvas.activeTool === toolName ? Theme.primary : Theme.on_surface
                        }

                        MouseArea {
                            id: mTool
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (floatingTextInput.visible)
                                    floatingTextInput.commitText();
                                drawCanvas.activeTool = toolName;
                            }
                        }
                    }

                    ToolBtn { icon: "edit"; toolName: "pencil" }
                    ToolBtn { icon: "draw"; toolName: "highlight" }
                    ToolBtn { icon: "circle"; toolName: "dot" }
                    ToolBtn { icon: "title"; toolName: "text" }
                }

                Rectangle {
                    width: 1
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bubble_border_soft
                    radius: 1
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: [Theme.primary, Theme.critical, "#FFD700", "#00FF00", "#FFFFFF", "#000000"]
                        delegate: Rectangle {
                            width: 32; height: 32; radius: 16
                            color: modelData
                            border.color: Theme.on_surface
                            border.width: drawCanvas.drawColor === modelData ? 3 : 0
                            anchors.verticalCenter: parent.verticalCenter

                            scale: colorMouse.pressed ? 0.9 : (colorMouse.containsMouse ? 1.1 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            MouseArea {
                                id: colorMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: drawCanvas.drawColor = modelData
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bubble_border_soft
                    radius: 1
                }

                ActionBtn {
                    icon: "save"
                    label: "Save & Copy"
                    baseColor: Theme.bubble_accent
                    hoverColor: Theme.bubble_hover
                    contentColor: Theme.primary
                    onClicked: {
                        if (floatingTextInput.visible)
                            floatingTextInput.commitText();
                        imageContainer.grabToImage(function(result) {
                            result.saveToFile(Screenshot.imagePath);
                            drawCanvas.clearCanvas();
                            editorWindow.closeMenu();
                            Screenshot.copyToClipboard();
                        });
                    }
                }
            }
        }
    }

    // Keep the shot decoded while the editor is closed so Draw→morph does not
    // pay image load / layout resize mid-animation.
    Image {
        id: targetImg
        width: 0
        height: 0
        visible: false
        source: Screenshot.imagePath ? "file://" + Screenshot.imagePath : ""
        asynchronous: true
        cache: true
    }

    // Big floating canvas bubble below the toolbox morph.
    ClippingRectangle {
        id: canvasBubble
        readonly property bool imageReady: targetImg.status === Image.Ready
            && targetImg.implicitWidth > 1 && targetImg.implicitHeight > 1
        readonly property real maxW: Math.max(200, editorWindow.width - editorWindow.canvasMargin * 2)
        readonly property real maxH: Math.max(200,
            editorWindow.height - panelShell.height - editorWindow.toolboxGap - editorWindow.canvasMargin)
        readonly property real imgW: Math.max(1, targetImg.implicitWidth)
        readonly property real imgH: Math.max(1, targetImg.implicitHeight)
        readonly property real fitScale: imageReady
            ? Math.min(1.0,
                (maxW - editorWindow.canvasPad * 2) / imgW,
                (maxH - editorWindow.canvasPad * 2) / imgH)
            : 0

        width: imageReady ? Math.round(imgW * fitScale) + editorWindow.canvasPad * 2 : 1
        height: imageReady ? Math.round(imgH * fitScale) + editorWindow.canvasPad * 2 : 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: panelShell.height + editorWindow.toolboxGap

        color: Theme.glass_shell
        radius: editorWindow.canvasRadius
        border.width: 1
        border.color: Theme.glass_shell_border
        contentUnderBorder: true
        // Fade with the morph, but only once size is stable.
        opacity: (imageReady && editorWindow.openProgress > 0.001) ? editorWindow.openProgress : 0
        scale: 0.96 + 0.04 * editorWindow.openProgress
        transformOrigin: Item.Top
        visible: opacity > 0.001
        z: 1

        onXChanged: editorWindow.syncBlurRegion()
        onYChanged: editorWindow.syncBlurRegion()
        onWidthChanged: editorWindow.syncBlurRegion()
        onHeightChanged: editorWindow.syncBlurRegion()
        onOpacityChanged: editorWindow.syncBlurRegion()

        MouseArea { anchors.fill: parent }

        Item {
            id: imageContainer
            anchors.centerIn: parent
            width: canvasBubble.imageReady ? Math.round(canvasBubble.imgW * canvasBubble.fitScale) : 0
            height: canvasBubble.imageReady ? Math.round(canvasBubble.imgH * canvasBubble.fitScale) : 0

            Image {
                anchors.fill: parent
                source: targetImg.source
                cache: true
                asynchronous: false
            }

            Canvas {
                id: drawCanvas
                anchors.fill: parent
                property var strokes: []
                property var currentStroke: []
                property string drawColor: Theme.critical
                property string activeTool: "pencil"
                property int dotCounter: 1

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    for (let i = 0; i < strokes.length; i++) {
                        let stroke = strokes[i];
                        ctx.strokeStyle = stroke.color;
                        ctx.fillStyle = stroke.color;

                        if (stroke.type === "pencil" || stroke.type === "highlight") {
                            if (stroke.points.length < 2) continue;
                            ctx.globalAlpha = stroke.type === "highlight" ? 0.4 : 1.0;
                            ctx.lineWidth = stroke.type === "highlight" ? 24 : 6;
                            ctx.beginPath();
                            ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
                            for (let j = 1; j < stroke.points.length; j++) {
                                ctx.lineTo(stroke.points[j].x, stroke.points[j].y);
                            }
                            ctx.stroke();
                        } else if (stroke.type === "dot") {
                            if (stroke.points.length < 1) continue;
                            ctx.globalAlpha = 0.85;
                            ctx.beginPath();
                            ctx.arc(stroke.points[0].x, stroke.points[0].y, 24, 0, 2 * Math.PI);
                            ctx.fill();

                            ctx.globalAlpha = 1.0;
                            ctx.fillStyle = (stroke.color === "#FFFFFF" || stroke.color === "#FFD700" || stroke.color === "#00FF00") ? "#000000" : "#FFFFFF";
                            ctx.font = "bold 22px sans-serif";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(stroke.number.toString(), stroke.points[0].x, stroke.points[0].y + 2);
                        } else if (stroke.type === "text") {
                            if (stroke.points.length < 1) continue;
                            ctx.globalAlpha = 1.0;
                            ctx.fillStyle = stroke.color;
                            ctx.font = "bold 24px 'Google Sans Medium'";
                            ctx.textAlign = "left";
                            ctx.textBaseline = "top";
                            ctx.fillText(stroke.text, stroke.points[0].x, stroke.points[0].y);
                        }
                    }

                    if (currentStroke.length > 0) {
                        ctx.strokeStyle = drawColor;
                        ctx.fillStyle = drawColor;

                        if (activeTool === "pencil" || activeTool === "highlight") {
                            if (currentStroke.length > 1) {
                                ctx.globalAlpha = activeTool === "highlight" ? 0.4 : 1.0;
                                ctx.lineWidth = activeTool === "highlight" ? 24 : 6;
                                ctx.beginPath();
                                ctx.moveTo(currentStroke[0].x, currentStroke[0].y);
                                for (let j = 1; j < currentStroke.length; j++) {
                                    ctx.lineTo(currentStroke[j].x, currentStroke[j].y);
                                }
                                ctx.stroke();
                            }
                        } else if (activeTool === "dot") {
                            ctx.globalAlpha = 0.85;
                            ctx.beginPath();
                            ctx.arc(currentStroke[0].x, currentStroke[0].y, 24, 0, 2 * Math.PI);
                            ctx.fill();

                            ctx.globalAlpha = 1.0;
                            ctx.fillStyle = (drawColor === "#FFFFFF" || drawColor === "#FFD700" || drawColor === "#00FF00") ? "#000000" : "#FFFFFF";
                            ctx.font = "bold 22px sans-serif";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(dotCounter.toString(), currentStroke[0].x, currentStroke[0].y + 2);
                        }
                    }
                }

                function clearCanvas() {
                    strokes = [];
                    currentStroke = [];
                    dotCounter = 1;
                    requestPaint();
                }
            }

            TextInput {
                id: floatingTextInput
                visible: false
                font.family: "Google Sans Medium"
                font.pixelSize: 24
                font.weight: Font.Bold
                color: drawCanvas.drawColor
                activeFocusOnPress: true

                onEditingFinished: commitText()

                function commitText() {
                    if (visible) {
                        if (text.trim().length > 0) {
                            let s = drawCanvas.strokes;
                            s.push({ type: "text", color: color, points: [{x: x, y: y}], text: text });
                            drawCanvas.strokes = s;
                            drawCanvas.requestPaint();
                        }
                        visible = false;
                        text = "";
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                property bool isDrawing: false
                onPressed: e => {
                    if (drawCanvas.activeTool === "text") {
                        if (floatingTextInput.visible) {
                            floatingTextInput.commitText();
                        } else {
                            floatingTextInput.x = e.x;
                            floatingTextInput.y = e.y;
                            floatingTextInput.text = "";
                            floatingTextInput.color = drawCanvas.drawColor;
                            floatingTextInput.visible = true;
                            floatingTextInput.forceActiveFocus();
                        }
                    } else if (drawCanvas.activeTool === "dot") {
                        let s = drawCanvas.strokes;
                        s.push({ type: "dot", color: drawCanvas.drawColor, points: [{x: e.x, y: e.y}], number: drawCanvas.dotCounter });
                        drawCanvas.strokes = s;
                        drawCanvas.dotCounter++;
                        drawCanvas.requestPaint();
                    } else {
                        isDrawing = true;
                        drawCanvas.currentStroke = [{x: e.x, y: e.y}];
                        drawCanvas.requestPaint();
                    }
                }
                onPositionChanged: e => {
                    if (isDrawing && drawCanvas.activeTool !== "dot" && drawCanvas.activeTool !== "text") {
                        let arr = drawCanvas.currentStroke;
                        arr.push({x: e.x, y: e.y});
                        drawCanvas.currentStroke = arr;
                        drawCanvas.requestPaint();
                    }
                }
                onReleased: e => {
                    if (isDrawing && drawCanvas.activeTool !== "dot" && drawCanvas.activeTool !== "text") {
                        isDrawing = false;
                        let s = drawCanvas.strokes;
                        s.push({ type: drawCanvas.activeTool, color: drawCanvas.drawColor, points: drawCanvas.currentStroke });
                        drawCanvas.strokes = s;
                        drawCanvas.currentStroke = [];
                        drawCanvas.requestPaint();
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: editorWindow.menuOpen
        onActivated: {
            if (floatingTextInput.visible) {
                floatingTextInput.visible = false;
                floatingTextInput.text = "";
            } else {
                editorWindow.closeMenu();
            }
        }
    }
}
