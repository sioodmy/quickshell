import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

PanelWindow {
    id: root
    width: Screen.width
    height: Screen.height
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "screenshot_editor"
    WlrLayershell.keyboardFocus: KeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    visible: Screenshot.editorActive

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.85)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                drawCanvas.clearCanvas();
                Screenshot.editorActive = false;
            }
        }
    }

    Item {
        id: container
        anchors.centerIn: parent
        width: targetImg.implicitWidth
        height: targetImg.implicitHeight
        
        scale: Math.min(1.0, (root.width - 100) / width, (root.height - 200) / height)

        Image {
            id: targetImg
            anchors.fill: parent
            source: Screenshot.imagePath ? "file://" + Screenshot.imagePath : ""
            cache: false
            asynchronous: true
        }

        Canvas {
            id: drawCanvas
            anchors.fill: parent
            property var strokes: []
            property var currentStroke: []
            property string drawColor: Theme.critical
            property string activeTool: "pencil" // pencil, highlight, dot
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
                        ctx.globalAlpha = 1.0;
                        ctx.beginPath();
                        ctx.arc(stroke.points[0].x, stroke.points[0].y, 16, 0, 2 * Math.PI);
                        ctx.fill();
                        
                        ctx.fillStyle = (stroke.color === "#FFFFFF" || stroke.color === "#FFD700" || stroke.color === "#00FF00") ? "#000000" : "#FFFFFF";
                        ctx.font = "bold 16px 'Google Sans Medium'";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(stroke.number.toString(), stroke.points[0].x, stroke.points[0].y + 1);
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

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            property bool isDrawing: false
            onPressed: e => {
                if (drawCanvas.activeTool === "dot") {
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
                if (isDrawing && drawCanvas.activeTool !== "dot") {
                    let arr = drawCanvas.currentStroke;
                    arr.push({x: e.x, y: e.y});
                    drawCanvas.currentStroke = arr;
                    drawCanvas.requestPaint();
                }
            }
            onReleased: e => {
                if (isDrawing && drawCanvas.activeTool !== "dot") {
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

    // Top bar for actions
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 32
        anchors.horizontalCenter: parent.horizontalCenter
        width: topRow.implicitWidth + 32
        height: 72
        radius: 36
        color: Theme.surface_container_high
        border.color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#40000000"
            shadowVerticalOffset: 6
        }

        Row {
            id: topRow
            anchors.centerIn: parent
            spacing: 12

            component ActionBtn: Rectangle {
                property string icon
                property string label
                property color baseColor: "transparent"
                property color hoverColor: Theme.surface_variant
                property color contentColor: Theme.on_surface
                signal clicked()

                width: lbl.implicitWidth + icn.implicitWidth + 36
                height: 56
                radius: 28
                color: m.containsMouse ? hoverColor : baseColor

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        id: icn
                        text: parent.parent.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: parent.parent.contentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: lbl
                        visible: text.length > 0
                        text: parent.parent.label
                        font.family: "Google Sans Medium"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: parent.parent.contentColor
                        anchors.verticalCenter: parent.verticalCenter
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
                icon: "󰅖"
                label: "Cancel"
                onClicked: {
                    drawCanvas.clearCanvas();
                    Screenshot.editorActive = false;
                }
            }

            ActionBtn {
                icon: "󰕌"
                label: "Undo"
                onClicked: {
                    let s = drawCanvas.strokes;
                    if (s.length > 0) {
                        let last = s.pop();
                        if (last.type === "dot") {
                            drawCanvas.dotCounter--;
                        }
                        drawCanvas.strokes = s;
                        drawCanvas.requestPaint();
                    }
                }
            }

            // Separator
            Rectangle {
                width: 2
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surface_variant
                radius: 1
            }

            // Tools
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                
                component ToolBtn: Rectangle {
                    property string icon
                    property string toolName
                    
                    width: 48
                    height: 48
                    radius: 24
                    color: drawCanvas.activeTool === toolName ? Theme.primary_container : (mTool.containsMouse ? Theme.surface_variant : "transparent")

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: drawCanvas.activeTool === toolName ? Theme.on_primary_container : Theme.on_surface
                    }
                    
                    MouseArea {
                        id: mTool
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawCanvas.activeTool = toolName
                    }
                }

                ToolBtn { icon: "󰏫"; toolName: "pencil" }
                ToolBtn { icon: "󰸱"; toolName: "highlight" }
                ToolBtn { icon: "󰎍"; toolName: "dot" }
            }

            // Separator
            Rectangle {
                width: 2
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surface_variant
                radius: 1
            }

            // Color picker row
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: [Theme.primary, Theme.critical, "#FFD700", "#00FF00", "#FFFFFF", "#000000"]
                    delegate: Rectangle {
                        width: 40; height: 40; radius: 20
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

            // Separator
            Rectangle {
                width: 2
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.surface_variant
                radius: 1
            }

            ActionBtn {
                icon: "󰆧"
                label: "Save & Copy"
                baseColor: Theme.primary_container
                hoverColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                contentColor: Theme.on_primary_container
                onClicked: {
                    container.grabToImage(function(result) {
                        result.saveToFile(Screenshot.imagePath);
                        drawCanvas.clearCanvas();
                        Screenshot.editorActive = false;
                        Screenshot.copyToClipboard();
                    });
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            drawCanvas.clearCanvas();
            Screenshot.editorActive = false;
        }
    }
}
