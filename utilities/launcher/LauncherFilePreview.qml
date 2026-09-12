import QtQuick
import "../../theme"
import qs.services
import qs.components

Item {
    id: previewPanel

    property var launcherWindow
    property var ctrl

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(Theme.on_surface, 0.03)
                        }

                    // ── WiFi share QR view (replaces preview when active) ──
                    Item {
                        id: shareView
                        anchors.fill: parent
                        opacity: launcherWindow ? launcherWindow.shareViewBlend : 0
                        visible: launcherWindow ? launcherWindow.shareViewBlend > 0.02 : false
                        z: 2
                        property int qrSize: 170

                        Behavior on opacity {
                            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                        }

                        transform: [
                            Scale {
                                origin.x: shareView.width / 2
                                origin.y: shareView.height / 2
                                xScale: 0.94 + 0.06 * (launcherWindow ? launcherWindow.shareViewBlend : 0)
                                yScale: 0.94 + 0.06 * (launcherWindow ? launcherWindow.shareViewBlend : 0)
                                Behavior on xScale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                                Behavior on yScale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                            }
                        ]

                        Column {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 8
                            width: Math.min(parent.width - 48, 280)
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    id: shareBackBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: shareBackMouse.containsMouse ? Theme.bubble_hover : Theme.bubble
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "arrow_back"
                                        font.pixelSize: 17
                                        color: Theme.on_surface
                                    }

                                    MouseArea {
                                        id: shareBackMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            launcherWindow.shareModeActive = false;
                                            launcherWindow.shareData = null;
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - shareBackBtn.width - parent.spacing
                                    text: "Share over WiFi"
                                    color: Theme.on_surface
                                    font { family: "Google Sans"; pixelSize: 16; weight: Font.DemiBold }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: shareView.qrSize + 20
                                height: shareView.qrSize + 20
                                radius: 18
                                color: "#ffffff"

                                Image {
                                    id: qrImage
                                    anchors.centerIn: parent
                                    width: shareView.qrSize
                                    height: shareView.qrSize
                                    source: {
                                        if (!launcherWindow || !launcherWindow.shareData || !launcherWindow.shareData.qr_svg)
                                            return "";
                                        return "data:image/svg+xml;utf8," + encodeURIComponent(launcherWindow.shareData.qr_svg);
                                    }
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: false
                                    cache: false
                                    sourceSize: Qt.size(256, 256)
                                }

                                // Loading / error placeholder while the backend prepares the QR
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: !qrImage.source || qrImage.status !== Image.Ready

                                    MaterialIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        icon: BackendDaemon.fileShareError !== "" ? "error" : "hourglass_empty"
                                        font.pixelSize: 28
                                        color: BackendDaemon.fileShareError !== "" ? "#B3261E" : "#5C5C5C"
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: BackendDaemon.fileShareError !== ""
                                            ? "Share failed"
                                            : "Generating QR…"
                                        color: "#5C5C5C"
                                        font { family: "Google Sans"; pixelSize: 11 }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: launcherWindow.shareData ? launcherWindow.shareData.name : "Starting..."
                                color: Theme.on_surface_variant
                                elide: Text.ElideMiddle
                                font { family: "Google Sans"; pixelSize: 12 }
                            }

                            // Copy-to-clipboard instead of showing the full URL.
                            Rectangle {
                                id: copyLinkBtn
                                width: parent.width
                                height: 40
                                radius: 16
                                color: copyLinkMouse.containsMouse ? Theme.bubble_accent : Theme.bubble_accent_soft
                                border.width: 1
                                border.color: Theme.glass_border

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    MaterialIcon {
                                        icon: "link"
                                        font.pixelSize: 14
                                        color: Theme.primary
                                    }
                                    Text {
                                        text: "Copy link"
                                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: copyLinkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (launcherWindow && launcherWindow.shareData && launcherWindow.shareData.url) {
                                            ctrl.copyText(launcherWindow.shareData.url);
                                            launcherWindow.closeMenu();
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: "Scan QR or open link on the same network"
                                color: Theme.on_surface_variant
                                opacity: 0.7
                                font { family: "Google Sans"; pixelSize: 11 }
                            }
                        }
                    }

                    // Normal preview (fades out when share view is active)
                    Item {
                        anchors.fill: parent
                        opacity: launcherWindow ? 1 - launcherWindow.shareViewBlend : 1
                        visible: !launcherWindow || launcherWindow.shareViewBlend < 0.98

                        Behavior on opacity {
                            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                        }

                    // Preview content area
                    Item {
                        id: previewContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: previewMeta.top
                        clip: true

                        // Image preview
                        Image {
                            id: imagePreview
                            anchors.fill: parent
                            anchors.margins: 16
                            visible: !!(ctrl && ctrl.filePreview && (ctrl.filePreview.preview_type === "image" || ((ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video") && !!ctrl.filePreview.preview_path)))
                            source: {
                                if (!ctrl.filePreview) return "";
                                if (ctrl.filePreview.preview_type === "image")
                                    return "file://" + ctrl.filePreview.path;
                                if ((ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video") && ctrl.filePreview.preview_path)
                                    return "file://" + ctrl.filePreview.preview_path;
                                return "";
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: ctrl.filePreview && (ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video")
                            smooth: true
                            mipmap: true
                            sourceSize: Qt.size(400, 400)

                            // Handle broken images
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    imagePreview.visible = false;
                                    fallbackIcon.visible = true;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Qt.alpha(Theme.on_surface, 0.06)
                                border.width: 1
                                radius: 12
                                visible: imagePreview.status === Image.Ready
                            }
                        }

                        // Text preview
                        Flickable {
                            id: textFlickable
                            anchors.fill: parent
                            anchors.margins: 16
                            visible: !!(ctrl && ctrl.filePreview && ctrl.filePreview.preview_type === "text")
                            contentWidth: width
                            contentHeight: textPreview.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: textPreview
                                width: textFlickable.width
                                text: (ctrl && ctrl.filePreview && ctrl.filePreview.content) || ""
                                // Mocha foreground for code so unstyled tokens match the theme;
                                // markdown keeps the panel's surface contrast color.
                                color: (launcherWindow && (launcherWindow && launcherWindow.selectedFileData) && (launcherWindow && launcherWindow.selectedFileData).ext === "md")
                                    ? Theme.on_surface
                                    : "#cdd6f4"
                                wrapMode: Text.Wrap
                                font {
                                    family: (launcherWindow && (launcherWindow && launcherWindow.selectedFileData) && (launcherWindow && launcherWindow.selectedFileData).ext === "md") ? "Inter" : "JetBrains Mono"
                                    pixelSize: (launcherWindow && (launcherWindow && launcherWindow.selectedFileData) && (launcherWindow && launcherWindow.selectedFileData).ext === "md") ? 13 : 11
                                }
                                lineHeight: 1.4
                                textFormat: (launcherWindow && (launcherWindow && launcherWindow.selectedFileData) && (launcherWindow && launcherWindow.selectedFileData).ext === "md") ? Text.MarkdownText : Text.RichText
                            }
                        }

                        // Truncation indicator for text
                        Rectangle {
                            visible: !!(textFlickable.visible && ctrl && ctrl.filePreview && ctrl.filePreview.line_count >= 60)
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Theme.glass_fade }
                            }
                        }

                        // Archive listing preview (M3 tree + Theme-tinted RichText)
                        Item {
                            id: archivePreview
                            anchors.fill: parent
                            anchors.margins: 12
                            visible: !!(ctrl && ctrl.filePreview && ctrl.filePreview.preview_type === "archive")

                            property var listing: {
                                if (!ctrl.filePreview || ctrl.filePreview.preview_type !== "archive" || !ctrl.filePreview.content)
                                    return null;
                                try {
                                    return JSON.parse(ctrl.filePreview.content);
                                } catch (e) {
                                    return null;
                                }
                            }

                            // Build Qt RichText from Theme tokens (same pipeline as syntect HTML)
                            property string treeHtml: {
                                var L = archivePreview.listing;
                                if (!L || !L.entries) return "";
                                function esc(s) {
                                    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                                }
                                function sz(n) {
                                    n = Number(n) || 0;
                                    if (n < 1024) return n + " B";
                                    var kb = n / 1024;
                                    if (kb < 1024) return kb.toFixed(1) + " KB";
                                    var mb = kb / 1024;
                                    if (mb < 1024) return mb.toFixed(1) + " MB";
                                    return (mb / 1024).toFixed(2) + " GB";
                                }
                                function hex(c) {
                                    // Theme tokens are hex strings; color objects need packing.
                                    if (typeof c === "string") return c;
                                    var r = Math.round(c.r * 255);
                                    var g = Math.round(c.g * 255);
                                    var b = Math.round(c.b * 255);
                                    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
                                }
                                function icon(cat, isDir) {
                                    if (isDir) return "󰉋";
                                    if (cat === "image") return "󰋩";
                                    if (cat === "video") return "󰕧";
                                    if (cat === "audio") return "󰝚";
                                    if (cat === "pdf") return "󰈦";
                                    if (cat === "archive") return "󰀼";
                                    if (cat === "document") return "󱎒";
                                    if (cat === "text") return "󰈙";
                                    return "󰈔";
                                }
                                function iconColor(cat, isDir) {
                                    if (isDir) return hex(Theme.primary);
                                    if (cat === "image" || cat === "video" || cat === "audio") return hex(Theme.tertiary);
                                    if (cat === "pdf") return hex(Theme.critical);
                                    return hex(Theme.secondary);
                                }
                                var guide = hex(Theme.surface_container_highest);
                                var onSurf = hex(Theme.on_surface);
                                var onVar = hex(Theme.on_surface_variant);
                                var outline = hex(Theme.outline);
                                var tertiary = hex(Theme.tertiary);
                                var html = "<pre style=\"margin:0;white-space:pre;line-height:1.55;\">";
                                for (var i = 0; i < L.entries.length; i++) {
                                    var e = L.entries[i];
                                    for (var d = 0; d < (e.depth || 0); d++)
                                        html += "<span style=\"color:" + guide + ";\">│  </span>";
                                    html += "<span style=\"color:" + iconColor(e.mime_cat, e.is_dir) + ";\">" + icon(e.mime_cat, e.is_dir) + "</span> ";
                                    if (e.is_dir) {
                                        html += "<span style=\"color:" + onSurf + ";\">" + esc(e.name) + "</span>";
                                        html += "<span style=\"color:" + outline + ";\">/</span>";
                                    } else {
                                        html += "<span style=\"color:" + onVar + ";\">" + esc(e.name) + "</span>";
                                        if (e.size > 0)
                                            html += "  <span style=\"color:" + outline + ";\">" + esc(sz(e.size)) + "</span>";
                                    }
                                    html += "\n";
                                }
                                if (L.truncated) {
                                    var rem = Math.max(1, (L.total_entries || 0) - (L.entries.length || 0));
                                    html += "<span style=\"color:" + tertiary + ";\">󰇘  " + rem + " more entries</span>\n";
                                }
                                html += "</pre>";
                                return html;
                            }

                            Column {
                                anchors.fill: parent
                                spacing: 10

                                // Summary chips
                                Flow {
                                    id: archiveChips
                                    width: parent.width
                                    spacing: 6

                                    Rectangle {
                                        visible: !!(archivePreview.listing && archivePreview.listing.format)
                                        height: 24
                                        width: formatChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.bubble_accent_soft
                                        border.width: 1
                                        border.color: Theme.bubble_border_soft

                                        Text {
                                            id: formatChipText
                                            anchors.centerIn: parent
                                            text: (archivePreview.listing && archivePreview.listing.format) || ""
                                            color: Theme.primary
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(archivePreview.listing)
                                        height: 24
                                        width: filesChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.bubble_secondary_soft
                                        border.width: 1
                                        border.color: Theme.bubble_border_soft

                                        Text {
                                            id: filesChipText
                                            anchors.centerIn: parent
                                            text: {
                                                var L = archivePreview.listing;
                                                if (!L) return "";
                                                var t = L.file_count + (L.file_count === 1 ? " file" : " files");
                                                if (L.dir_count > 0)
                                                    t += " · " + L.dir_count + (L.dir_count === 1 ? " folder" : " folders");
                                                return t;
                                            }
                                            color: Theme.secondary
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(archivePreview.listing && archivePreview.listing.uncompressed_size > 0)
                                        height: 24
                                        width: sizeChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.bubble
                                        border.width: 1
                                        border.color: Theme.bubble_border_soft

                                        Text {
                                            id: sizeChipText
                                            anchors.centerIn: parent
                                            text: {
                                                var L = archivePreview.listing;
                                                if (!L) return "";
                                                return ctrl.formatFileSize(L.uncompressed_size) + " unpacked";
                                            }
                                            color: Theme.on_surface_variant
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(archivePreview.listing && archivePreview.listing.truncated)
                                        height: 24
                                        width: truncChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.bubble_tertiary_soft
                                        border.width: 1
                                        border.color: Theme.bubble_border_soft

                                        Text {
                                            id: truncChipText
                                            anchors.centerIn: parent
                                            text: "truncated"
                                            color: Theme.tertiary
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }
                                }

                                Flickable {
                                    id: archiveFlickable
                                    width: parent.width
                                    height: parent.height - archiveChips.height - 10
                                    contentWidth: width
                                    contentHeight: archiveTree.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    opacity: archivePreview.listing ? 1 : 0

                                    Text {
                                        id: archiveTree
                                        width: archiveFlickable.width
                                        text: archivePreview.treeHtml
                                        textFormat: Text.RichText
                                        color: Theme.on_surface
                                        wrapMode: Text.NoWrap
                                        font {
                                            family: "Monospace"
                                            pixelSize: 11
                                        }
                                    }
                                }
                            }

                            // Fade when truncated / scrollable
                            Rectangle {
                                visible: !!(archivePreview.visible && archivePreview.listing && archivePreview.listing.truncated)
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 36
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Theme.glass_fade }
                                }
                            }
                        }

                        // Fallback icon for non-previewable files
                        Item {
                            id: fallbackIcon
                            anchors.centerIn: parent
                            visible: {
                                if (!ctrl || !ctrl.filePreview) return true;
                                var pt = ctrl.filePreview.preview_type;
                                if ((pt === "pdf" || pt === "video") && ctrl.filePreview.preview_path) return false;
                                return pt !== "image" && pt !== "text" && pt !== "archive";
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    icon: (launcherWindow && (launcherWindow && launcherWindow.selectedFileData)) ? ctrl.mimeIcon((launcherWindow && launcherWindow.selectedFileData).mime_cat) : ""
                                    color: Theme.primary
                                    opacity: 0.6
                                    font.pixelSize: 72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (!ctrl || !ctrl.filePreview) return "Loading...";
                                        if (ctrl.filePreview.preview_type === "text_too_large") return "File too large to preview";
                                        if (ctrl.filePreview.preview_type === "binary") return "Binary file";
                                        if (ctrl.filePreview.preview_type === "pdf") return "PDF preview unavailable";
                                        if (ctrl.filePreview.preview_type === "video") return "Video preview unavailable";
                                        if (ctrl.filePreview.preview_type === "archive_unavailable") return "Couldn't list archive";
                                        return "No preview available";
                                    }
                                    color: Theme.on_surface_variant
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 13
                                    }
                                }
                            }
                        }

                        // Loading spinner
                        Text {
                            anchors.centerIn: parent
                            visible: !!(ctrl && !ctrl.filePreview && launcherWindow && launcherWindow.hasFileSelected)
                            text: "Loading..."
                            color: Theme.on_surface_variant
                            opacity: 0.6
                            font {
                                family: "Google Sans"
                                pixelSize: 14
                            }
                        }
                    }

                    // ── File metadata + action buttons ──
                    Rectangle {
                        id: previewMeta
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: metaColumn.implicitHeight + 32
                        color: Qt.alpha(Theme.on_surface, 0.04)
                        // Per-corner radii instead of an overlaid square-off
                        // rectangle, which would double the translucent wash.
                        bottomLeftRadius: 28
                        bottomRightRadius: 28

                        Column {
                            id: metaColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 20
                            anchors.bottomMargin: 16
                            spacing: 6

                            Text {
                                width: parent.width
                                text: (launcherWindow && launcherWindow.selectedFileData) ? (launcherWindow && launcherWindow.selectedFileData).name : ""
                                color: Theme.on_surface
                                elide: Text.ElideMiddle
                                font {
                                    family: "Google Sans"
                                    pixelSize: 15
                                    weight: Font.DemiBold
                                }
                            }

                            Text {
                                width: parent.width
                                text: (launcherWindow && launcherWindow.selectedFileData) ? (launcherWindow && launcherWindow.selectedFileData).dir : ""
                                color: Theme.on_surface_variant
                                elide: Text.ElideMiddle
                                font {
                                    family: "Google Sans"
                                    pixelSize: 12
                                }
                            }

                            Text {
                                text: {
                                    if (!(launcherWindow && launcherWindow.selectedFileData)) return "";
                                    var f = (launcherWindow && launcherWindow.selectedFileData);
                                    var parts = [ctrl.formatFileSize(f.size)];
                                    if (f.ext) parts.push(f.ext.toUpperCase());
                                    return parts.join("  •  ");
                                }
                                color: Theme.on_surface_variant
                                opacity: 0.7
                                font {
                                    family: "Google Sans"
                                    pixelSize: 11
                                }
                            }

                            Item { width: 1; height: 6 }

                            // Action buttons row — icon-only so share stays visible
                            Row {
                                spacing: 8

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: copyFileMouse.containsMouse ? Theme.bubble_accent : Theme.bubble_accent_soft
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "content_copy"
                                        font.pixelSize: 16
                                        color: Theme.primary
                                    }

                                    MouseArea {
                                        id: copyFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if ((launcherWindow && launcherWindow.selectedFileData))
                                                ctrl.copyFile((launcherWindow && launcherWindow.selectedFileData).path);
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: copyPathMouse.containsMouse ? Theme.bubble_secondary : Theme.bubble_secondary_soft
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "link"
                                        font.pixelSize: 16
                                        color: Theme.secondary
                                    }

                                    MouseArea {
                                        id: copyPathMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if ((launcherWindow && launcherWindow.selectedFileData))
                                                ctrl.copyFilePath((launcherWindow && launcherWindow.selectedFileData).path);
                                        }
                                    }
                                }

                                Rectangle {
                                    id: stashFileBtn
                                    // FileStash.count keeps this reactive when Drag Queen mutates
                                    readonly property bool alreadyStashed: FileStash.count >= 0
                                        && !!(launcherWindow && launcherWindow.selectedFileData)
                                        && FileStash.indexOfPath((launcherWindow && launcherWindow.selectedFileData).path) !== -1
                                    readonly property color prideRed: "#E57373"
                                    readonly property color prideOrange: "#FFB74D"
                                    readonly property color prideYellow: "#FFF176"
                                    readonly property color prideGreen: "#81C784"
                                    readonly property color prideBlue: "#64B5F6"
                                    readonly property color prideViolet: "#BA68C8"

                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.glass_panel
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        opacity: stashFileMouse.containsMouse
                                            ? 0.28
                                            : (stashFileBtn.alreadyStashed ? 0.18 : 0.10)
                                        Behavior on opacity { NumberAnimation { duration: 100 } }
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.00; color: stashFileBtn.prideRed }
                                            GradientStop { position: 0.20; color: stashFileBtn.prideOrange }
                                            GradientStop { position: 0.40; color: stashFileBtn.prideYellow }
                                            GradientStop { position: 0.60; color: stashFileBtn.prideGreen }
                                            GradientStop { position: 0.80; color: stashFileBtn.prideBlue }
                                            GradientStop { position: 1.00; color: stashFileBtn.prideViolet }
                                        }
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: stashFileBtn.alreadyStashed ? "check" : "move_to_inbox"
                                        font.pixelSize: 16
                                        color: Theme.on_surface
                                    }

                                    MouseArea {
                                        id: stashFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!(launcherWindow && launcherWindow.selectedFileData))
                                                return;
                                            const path = (launcherWindow && launcherWindow.selectedFileData).path;
                                            if (FileStash.indexOfPath(path) !== -1)
                                                FileStash.removePath(path);
                                            else
                                                FileStash.addPath(path);
                                            launcherWindow.closeMenu();
                                        }
                                    }
                                }

                                Rectangle {
                                    id: shareFileBtn
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: shareFileMouse.containsMouse ? Theme.bubble_tertiary : Theme.bubble_tertiary_soft
                                    border.width: 1
                                    border.color: Theme.glass_border

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "qr_code"
                                        font.pixelSize: 16
                                        color: Theme.tertiary
                                    }

                                    MouseArea {
                                        id: shareFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!(launcherWindow && launcherWindow.selectedFileData))
                                                return;
                                            BackendDaemon.fileShareError = "";
                                            launcherWindow.shareModeActive = true;
                                            launcherWindow.shareData = null;
                                            FileShare.startShare((launcherWindow && launcherWindow.selectedFileData).path);
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                visible: BackendDaemon.fileShareError !== ""
                                text: BackendDaemon.fileShareError
                                color: Theme.critical
                                elide: Text.ElideRight
                                font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                opacity: 0.95
                            }
                        }
                    }
                    } // End normal preview wrapper
}
