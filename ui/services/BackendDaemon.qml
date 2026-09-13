pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property var agendaItems: null
    property var weatherData: null
    property string dictStatus: ""
    property string dictWord: ""
    property string dictPhonetic: ""
    property string dictDefinition: ""
    property string calcResultQuery: ""
    property string calcResult: ""
    property string calcStatus: ""
    property string backendqsStatus: ""
    property string backendqsSvg: ""
    property string backendqsError: ""
    property string lyricsStatus: ""
    property string lyricsContent: ""
    property var musicLibrary: null
    property string musicLibraryStatus: ""
    property var frecencyScores: ({ apps: {}, quickkeys: {} })
    property var appSearchResults: []
    property string appSearchQuery: ""
    property var fileSearchResults: []
    property string fileSearchQuery: ""
    property var bookmarkSearchResults: []
    property string bookmarkSearchQuery: ""
    property var filePreview: null
    property string filePreviewPath: ""
    property var bluetoothDevices: []
    property var wifiNetworks: []
    property var cliphistItems: []
    property var fileShareItems: []
    property string fileShareError: ""
    property string musicRemoteUrl: ""
    property string musicRemoteQrSvg: ""
    property bool musicRemoteConnected: false


    // Emitted when a new share is ready with QR data for the launcher.
    signal fileShareReady(var data)

    // Emitted once a clipboard copy has been written to the Wayland selection.
    signal cliphistCopied()
    signal cliphistUpdated()

    signal polkitShowAuth(string action_id, string message, string icon_name, string cookie, string user_name, string prompt)
    signal polkitResult(string cookie, bool success)
    signal polkitDismiss(string cookie)
    signal eventReceived(var event)
    signal backendStarted()
    signal backendStopped()

    property var musicState: {
        "playing": false,
        "title": "",
        "artist": "",
        "album": "",
        "artUrl": "",
        "duration": 0,
        "position": 0,
        "volume": 1.0,
        "loopAlbum": false,
        "hasPlayer": false,
        "palette": {
            "primary": "#ff7ec0",
            "secondary": "#8b74ff",
            "accent": "#e08cff",
            "bg": "#24143a",
            "fg": "#ffffff"
        }
    }

    Process {
        id: daemon
        command: ["backendqs", "daemon"]
        running: true
        stdinEnabled: true
        onStarted: {
            root.available = true;
            root.backendStarted();
        }
        // Survive crashes / binary rebuilds without requiring a full shell restart.
        onExited: {
            root.available = false;
            root.backendStopped();
            restartDaemon.restart();
        }
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim();
                if (trimmed === "") return;
                try {
                    var parsed = JSON.parse(trimmed);
                    var type = parsed.type;
                    if (type === "agenda_update") {
                        root.agendaItems = parsed.data || [];
                    } else if (type === "weather_result") {
                        if (parsed.status === "ok") {
                            root.weatherData = parsed.data;
                        }
                    } else if (type === "dictionary_result") {
                        if (parsed.status === "ok") {
                            root.dictWord = parsed.word || "";
                            root.dictPhonetic = parsed.phonetic || "";
                            root.dictDefinition = parsed.definition || "";
                        } else {
                            root.dictWord = "";
                            root.dictPhonetic = "";
                            root.dictDefinition = parsed.error || "Not found";
                        }
                        root.dictStatus = parsed.status;
                    } else if (type === "math_result") {
                        if (parsed.status === "ok") {
                            if (parsed.svg_content) {
                                root.backendqsSvg = "data:image/svg+xml;utf8," + encodeURIComponent(parsed.svg_content);
                            } else if (parsed.svg_file) {
                                root.backendqsSvg = "file://" + parsed.svg_file + "?t=" + Date.now();
                            }
                            root.backendqsError = "";
                        } else {
                            root.backendqsError = parsed.error || "Unknown error";
                        }
                        root.backendqsStatus = parsed.status;
                    } else if (type === "calc_result") {
                        root.calcResultQuery = parsed.query || "";
                        if (parsed.status === "ok") {
                            root.calcResult = parsed.result || "";
                        } else {
                            root.calcResult = "";
                        }
                        root.calcStatus = parsed.status;
                    } else if (type === "lyrics_result") {
                        if (parsed.status === "ok") {
                            root.lyricsContent = parsed.lyrics || "";
                        } else {
                            root.lyricsContent = "";
                        }
                        root.lyricsStatus = parsed.status;
                    } else if (type === "music_library_result") {
                        if (parsed.status === "ok") {
                            root.musicLibrary = parsed.library || null;
                        } else {
                            root.musicLibrary = null;
                        }
                        root.musicLibraryStatus = parsed.status;
                    } else if (type === "music_state_update") {
                        // art_url can be missing/null if the backend DTO is
                        // partial; never call startsWith on a non-string.
                        let rawUrl = parsed.state && parsed.state.art_url != null
                            ? ("" + parsed.state.art_url) : "";
                        let finalUrl = (rawUrl.startsWith("file://") || rawUrl.startsWith("http"))
                            ? rawUrl
                            : (rawUrl !== "" ? "file://" + rawUrl : "");
                        let next = {
                            "playing": !!(parsed.state && parsed.state.playing),
                            "title": (parsed.state && parsed.state.title) ? ("" + parsed.state.title) : "",
                            "artist": (parsed.state && parsed.state.artist) ? ("" + parsed.state.artist) : "",
                            "album": (parsed.state && parsed.state.album) ? ("" + parsed.state.album) : "",
                            "artUrl": finalUrl,
                            "duration": parsed.state ? (parsed.state.duration_us / 1000000.0) : 0,
                            "position": parsed.state ? (parsed.state.position_us / 1000000.0) : 0,
                            "volume": parsed.state && parsed.state.volume != null ? parsed.state.volume : 1.0,
                            "loopAlbum": !!(parsed.state && parsed.state.loop_album),
                            "hasPlayer": !!(parsed.state && parsed.state.has_player),
                            "palette": (parsed.state && parsed.state.palette) ? parsed.state.palette : {
                                "primary": "#ff7ec0",
                                "secondary": "#8b74ff",
                                "accent": "#e08cff",
                                "bg": "#24143a",
                                "fg": "#ffffff"
                            }
                        };
                        // Skip no-op updates so bindings (and any layered
                        // Image/MultiEffect consumers) are not churned at 2Hz.
                        let prev = root.musicState;
                        if (!prev
                            || prev.playing !== next.playing
                            || prev.title !== next.title
                            || prev.artist !== next.artist
                            || prev.album !== next.album
                            || prev.artUrl !== next.artUrl
                            || (prev.palette && next.palette && prev.palette.primary !== next.palette.primary)
                            || prev.loopAlbum !== next.loopAlbum
                            || prev.hasPlayer !== next.hasPlayer
                            || prev.volume !== next.volume
                            || Math.abs((prev.duration || 0) - next.duration) > 0.05
                            || Math.abs((prev.position || 0) - next.position) > 0.2) {
                            root.musicState = next;
                        }
                    } else if (type === "frecency_update") {
                        root.frecencyScores = parsed.scores || { apps: {}, quickkeys: {} };
                    } else if (type === "app_search_result") {
                        if (parsed.query === root.appSearchQuery) {
                            root.appSearchResults = parsed.results || [];
                        }
                    } else if (type === "file_search_result") {
                        root.fileSearchQuery = parsed.query || "";
                        root.fileSearchResults = parsed.results || [];
                    } else if (type === "bookmark_search_result") {
                        root.bookmarkSearchQuery = parsed.query || "";
                        root.bookmarkSearchResults = parsed.results || [];
                    } else if (type === "file_preview_result") {
                        if (parsed.path === root.filePreviewPath) {
                            root.filePreview = parsed;
                        }
                    } else if (type === "sysctl_list_result") {
                        if (parsed.kind === "bluetooth") {
                            root.bluetoothDevices = parsed.devices || [];
                        } else if (parsed.kind === "wifi" || parsed.kind === "net") {
                            root.wifiNetworks = parsed.devices || [];
                        }
                    } else if (type === "cliphist_list_result") {
                        console.log("Received cliphist_list_result with items: ", parsed.items ? parsed.items.length : 0);
                        root.cliphistItems = parsed.items || [];
                        root.cliphistUpdated();
                    } else if (type === "cliphist_ocr_update") {
                        // Patch the matching entry with freshly recognised OCR
                        // text so the launcher can fuzzy-match it immediately.
                        var items = root.cliphistItems;
                        var changed = false;
                        for (var i = 0; i < items.length; i++) {
                            if (items[i].id === parsed.id) {
                                items[i].ocr_text = parsed.ocr_text || "";
                                items[i].search_text = parsed.search_text || "";
                                items[i].ocr_done = true;
                                changed = true;
                                break;
                            }
                        }
                        if (changed)
                            root.cliphistItems = items.slice();
                    } else if (type === "cliphist_action_done") {
                        if (parsed.action === "copy")
                            root.cliphistCopied();
                    } else if (type === "file_share_started") {
                        if (parsed.status === "ok") {
                            root.fileShareError = "";
                            var shareData = {
                                id: parsed.id,
                                url: parsed.url,
                                qr_svg: parsed.qr_svg,
                                name: parsed.name,
                                size: parsed.size
                            };
                            FileShare.addShare({
                                id: parsed.id,
                                name: parsed.name,
                                size: parsed.size,
                                url: parsed.url
                            });
                            root.fileShareReady(shareData);
                        } else {
                            root.fileShareError = parsed.error || "Share failed";
                            root.fileShareReady({ error: root.fileShareError });
                        }
                    } else if (type === "file_share_progress") {
                        root.fileShareItems = parsed.shares || [];
                        FileShare.updateFromBackend(parsed.shares || []);
                    } else if (type === "music_remote_started") {
                        if (parsed.status === "ok") {
                            root.musicRemoteUrl = parsed.url || "";
                            root.musicRemoteQrSvg = parsed.qr_svg || "";
                            root.musicRemoteConnected = false;
                        } else {
                            root.musicRemoteUrl = "";
                            root.musicRemoteQrSvg = "";
                            root.musicRemoteConnected = false;
                        }
                    } else if (type === "music_remote_stopped") {
                        root.musicRemoteUrl = "";
                        root.musicRemoteQrSvg = "";
                        root.musicRemoteConnected = false;

                    } else if (type === "music_remote_connected") {
                        root.musicRemoteConnected = true;
                    } else if (type === "polkit_show_auth") {
                        root.polkitShowAuth(parsed.action_id, parsed.message, parsed.icon_name, parsed.cookie, parsed.user_name, parsed.prompt);
                    } else if (type === "polkit_result") {
                        root.polkitResult(parsed.cookie, parsed.success);
                                        } else if (type === "polkit_dismiss") {
                        root.polkitDismiss(parsed.cookie);
                    } else {
                        root.eventReceived(parsed);
                    }

                } catch(e) {
                    console.error("BackendDaemon: failed to process event:", e);
                }
            }
        }
    }

    function send(obj) {
        daemon.write(JSON.stringify(obj) + "\n");
    }

    function polkitSubmit(cookie, response) {
        send({ action: "polkit_submit", cookie: cookie, response: response })
    }

    function polkitCancel(cookie) {
        send({ action: "polkit_cancel", cookie: cookie })
    }

    Timer {
        id: restartDaemon
        interval: 250
        repeat: false
        onTriggered: daemon.running = true
    }

    Timer {
        id: initTimer
        running: true
        interval: 100
        repeat: false
        onTriggered: {
            // Defer library scan so launcher LazyLoader warm-up is not
            // competing with a large JSON parse on the GUI thread at boot.
            root.send({action: "frecency_load"});
            libraryDefer.restart();
        }
    }

    Timer {
        id: libraryDefer
        interval: 800
        repeat: false
        onTriggered: root.send({action: "music_library"})
    }
}
