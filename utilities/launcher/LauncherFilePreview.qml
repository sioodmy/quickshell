import QtQuick
import QtQuick.Effects
import "../../theme"
import qs.services
import qs.components

Item {
    id: previewPanel

    property var launcherWindow
    property var ctrl

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.03)
                        }

                    // ── WiFi share QR view (replaces preview when active) ──
                    Item {
                        id: shareView
                        anchors.fill: parent
                        opacity: launcherWindow.shareViewBlend
                        visible: launcherWindow.shareViewBlend > 0.02
                        z: 2
                        property int qrSize: 170

                        Behavior on opacity {
                            NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                        }

                        transform: [
                            Scale {
                                origin.x: parent.width / 2
                                origin.y: parent.height / 2
                                xScale: 0.94 + 0.06 * launcherWindow.shareViewBlend
                                yScale: 0.94 + 0.06 * launcherWindow.shareViewBlend
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
                                    color: shareBackMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container

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

                                layer.enabled: launcherWindow.shareViewBlend > 0.02
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowBlur: 0.6
                                    shadowColor: "#20000000"
                                    shadowVerticalOffset: 4
                                }

                                Image {
                                    id: qrImage
                                    anchors.centerIn: parent
                                    width: shareView.qrSize
                                    height: shareView.qrSize
                                    source: launcherWindow.shareData && launcherWindow.shareData.qr_svg
                                        ? "data:image/svg+xml;utf8," + encodeURIComponent(launcherWindow.shareData.qr_svg)
                                        : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    sourceSize: Qt.size(256, 256)
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
                                color: copyLinkMouse.containsMouse ? Theme.primary : Theme.primary_container

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    MaterialIcon {
                                        icon: "link"
                                        font.pixelSize: 14
                                        color: copyLinkMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                    }
                                    Text {
                                        text: "Copy link"
                                        font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                        color: copyLinkMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                    }
                                }

                                MouseArea {
                                    id: copyLinkMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (launcherWindow.shareData && launcherWindow.shareData.url)
                                            ctrl.copyText(launcherWindow.shareData.url);
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
                        opacity: 1 - launcherWindow.shareViewBlend
                        visible: launcherWindow.shareViewBlend < 0.98

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
                            visible: ctrl.filePreview && (ctrl.filePreview.preview_type === "image" || ((ctrl.filePreview.preview_type === "pdf" || ctrl.filePreview.preview_type === "video") && !!ctrl.filePreview.preview_path))
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
                                border.color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.06)
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
                            visible: ctrl.filePreview && ctrl.filePreview.preview_type === "text"
                            contentWidth: width
                            contentHeight: textPreview.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Text {
                                id: textPreview
                                width: textFlickable.width
                                text: (ctrl.filePreview && ctrl.filePreview.content) || ""
                                // Mocha foreground for code so unstyled tokens match the theme;
                                // markdown keeps the panel's surface contrast color.
                                color: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md")
                                    ? Theme.on_surface
                                    : "#cdd6f4"
                                wrapMode: Text.Wrap
                                font {
                                    family: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? "Inter" : "JetBrains Mono"
                                    pixelSize: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? 13 : 11
                                }
                                lineHeight: 1.4
                                textFormat: (launcherWindow.selectedFileData && launcherWindow.selectedFileData.ext === "md") ? Text.MarkdownText : Text.RichText
                            }
                        }

                        // Truncation indicator for text
                        Rectangle {
                            visible: textFlickable.visible && ctrl.filePreview && ctrl.filePreview.line_count >= 60
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Theme.surface }
                            }
                        }

                        // Archive listing preview (M3 tree + Theme-tinted RichText)
                        Item {
                            id: archivePreview
                            anchors.fill: parent
                            anchors.margins: 12
                            visible: ctrl.filePreview && ctrl.filePreview.preview_type === "archive"

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
                                        color: Theme.primary_container

                                        Text {
                                            id: formatChipText
                                            anchors.centerIn: parent
                                            text: (archivePreview.listing && archivePreview.listing.format) || ""
                                            color: Theme.on_primary_container
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(archivePreview.listing)
                                        height: 24
                                        width: filesChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.secondary_container

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
                                            color: Theme.on_secondary_container
                                            font { family: "Google Sans"; pixelSize: 11; weight: Font.Medium }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(archivePreview.listing && archivePreview.listing.uncompressed_size > 0)
                                        height: 24
                                        width: sizeChipText.implicitWidth + 16
                                        radius: 12
                                        color: Theme.surface_container_highest

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
                                        color: Theme.tertiary_container

                                        Text {
                                            id: truncChipText
                                            anchors.centerIn: parent
                                            text: "truncated"
                                            color: Theme.on_tertiary_container
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
                                visible: archivePreview.visible && archivePreview.listing && archivePreview.listing.truncated
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 36
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Theme.surface }
                                }
                            }
                        }

                        // Fallback icon for non-previewable files
                        Item {
                            id: fallbackIcon
                            anchors.centerIn: parent
                            visible: {
                                if (!ctrl.filePreview) return true;
                                var pt = ctrl.filePreview.preview_type;
                                if ((pt === "pdf" || pt === "video") && ctrl.filePreview.preview_path) return false;
                                return pt !== "image" && pt !== "text" && pt !== "archive";
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    icon: launcherWindow.selectedFileData ? ctrl.mimeIcon(launcherWindow.selectedFileData.mime_cat) : ""
                                    color: Theme.primary
                                    opacity: 0.6
                                    font.pixelSize: 72
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (!ctrl.filePreview) return "Loading...";
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
                            visible: !ctrl.filePreview && launcherWindow.hasFileSelected
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
                        color: Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.04)
                        radius: 28

                        // Only round bottom corners
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            color: parent.color
                        }

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
                                text: launcherWindow.selectedFileData ? launcherWindow.selectedFileData.name : ""
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
                                text: launcherWindow.selectedFileData ? launcherWindow.selectedFileData.dir : ""
                                color: Theme.on_surface_variant
                                elide: Text.ElideMiddle
                                font {
                                    family: "Google Sans"
                                    pixelSize: 12
                                }
                            }

                            Text {
                                text: {
                                    if (!launcherWindow.selectedFileData) return "";
                                    var f = launcherWindow.selectedFileData;
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

                            // Action buttons row
                            Row {
                                spacing: 8

                                Rectangle {
                                    width: copyFileRow.width + 20
                                    height: 32
                                    radius: 16
                                    color: copyFileMouse.containsMouse ? Theme.primary : Theme.primary_container

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        id: copyFileRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "content_copy"
                                            font.pixelSize: 14
                                            color: copyFileMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Copy"
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: copyFileMouse.containsMouse ? Theme.on_primary : Theme.on_primary_container
                                        }
                                    }

                                    MouseArea {
                                        id: copyFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (launcherWindow.selectedFileData)
                                                ctrl.copyFile(launcherWindow.selectedFileData.path);
                                        }
                                    }
                                }

                                Rectangle {
                                    width: copyPathRow.width + 20
                                    height: 32
                                    radius: 16
                                    color: copyPathMouse.containsMouse ? Theme.secondary : Theme.secondary_container

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        id: copyPathRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "content_copy"
                                            font.pixelSize: 14
                                            color: copyPathMouse.containsMouse ? Theme.on_secondary : Theme.on_secondary_container
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Path"
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: copyPathMouse.containsMouse ? Theme.on_secondary : Theme.on_secondary_container
                                        }
                                    }

                                    MouseArea {
                                        id: copyPathMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (launcherWindow.selectedFileData)
                                                ctrl.copyFilePath(launcherWindow.selectedFileData.path);
                                        }
                                    }
                                }

                                Rectangle {
                                    id: stashFileBtn
                                    // FileStash.count keeps this reactive when Drag Queen mutates
                                    readonly property bool alreadyStashed: FileStash.count >= 0
                                        && !!launcherWindow.selectedFileData
                                        && FileStash.indexOfPath(launcherWindow.selectedFileData.path) !== -1
                                    // Soft M3-weight pride tones
                                    readonly property color prideRed: "#E57373"
                                    readonly property color prideOrange: "#FFB74D"
                                    readonly property color prideYellow: "#FFF176"
                                    readonly property color prideGreen: "#81C784"
                                    readonly property color prideBlue: "#64B5F6"
                                    readonly property color prideViolet: "#BA68C8"

                                    width: stashFileRow.width + 20
                                    height: 32
                                    radius: 16
                                    color: Theme.surface_container_high

                                    // Soft pride wash — denser on hover / when already queued
                                    // Same radius as parent so corners stay round (clip ignores radius)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        opacity: stashFileMouse.containsMouse
                                            ? 0.42
                                            : (stashFileBtn.alreadyStashed ? 0.28 : 0.18)
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

                                    Row {
                                        id: stashFileRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "draft"
                                            font.pixelSize: 14
                                            color: Theme.on_surface
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: stashFileBtn.alreadyStashed ? "Dragged" : "Drag Queen"
                                            font { family: "Google Sans"; pixelSize: 12; weight: Font.Medium }
                                            color: Theme.on_surface
                                        }
                                    }

                                    MouseArea {
                                        id: stashFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!launcherWindow.selectedFileData)
                                                return;
                                            const path = launcherWindow.selectedFileData.path;
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
                                    color: shareFileMouse.containsMouse ? Theme.tertiary : Theme.tertiary_container

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        icon: "share"
                                        font.pixelSize: 16
                                        color: shareFileMouse.containsMouse ? Theme.on_tertiary : Theme.on_tertiary_container
                                    }

                                    MouseArea {
                                        id: shareFileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!launcherWindow.selectedFileData)
                                                return;
                                            // Optimistic UI: show the QR/share panel immediately
                                            // so the button never feels dead.
                                            BackendDaemon.fileShareError = "";
                                            launcherWindow.shareModeActive = true;
                                            launcherWindow.shareData = null;
                                            FileShare.startShare(launcherWindow.selectedFileData.path);
                                        }
                                    }
                                }
                            }

                            // If the backend rejects the share request, the QR button
                            // would otherwise look "dead" (no animation/no view).
                            Text {
                                width: parent.width
                                visible: BackendDaemon.fileShareError !== "" && !launcherWindow.shareModeActive
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
