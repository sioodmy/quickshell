pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var agendaItems: []
    property var weatherData: null
    property string dictStatus: ""
    property string dictWord: ""
    property string dictPhonetic: ""
    property string dictDefinition: ""
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
    property var fileSearchResults: []
    property string fileSearchQuery: ""
    property var bookmarkSearchResults: []
    property string bookmarkSearchQuery: ""
    property var filePreview: null
    property string filePreviewPath: ""
    property var bluetoothDevices: []
    property var wifiNetworks: []
    property var cliphistItems: []

    // Emitted once a clipboard copy has been written to the Wayland selection.
    signal cliphistCopied()
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
        "hasPlayer": false
    }

    Process {
        id: daemon
        command: ["/home/sioodmy/.config/quickshell/backendqs/target/release/backendqs", "daemon"]
        running: true
        stdinEnabled: true
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
                            root.backendqsSvg = "";
                            root.backendqsError = parsed.error || "Unknown error";
                        }
                        root.backendqsStatus = parsed.status;
                    } else if (type === "calc_result") {
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
                        let rawUrl = parsed.state.art_url;
                        let finalUrl = (rawUrl.startsWith("file://") || rawUrl.startsWith("http")) ? rawUrl : (rawUrl !== "" ? "file://" + rawUrl : "");
                        root.musicState = {
                            "playing": parsed.state.playing,
                            "title": parsed.state.title,
                            "artist": parsed.state.artist,
                            "album": parsed.state.album,
                            "artUrl": finalUrl,
                            "duration": parsed.state.duration_us / 1000000.0,
                            "position": parsed.state.position_us / 1000000.0,
                            "volume": parsed.state.volume,
                            "loopAlbum": parsed.state.loop_album,
                            "hasPlayer": parsed.state.has_player
                        };
                    } else if (type === "frecency_update") {
                        root.frecencyScores = parsed.scores || { apps: {}, quickkeys: {} };
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
                        root.cliphistItems = parsed.items || [];
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
                    }
                } catch(e) {
                    console.error("BackendDaemon JSON error:", e, trimmed);
                }
            }
        }
    }

    function send(obj) {
        daemon.write(JSON.stringify(obj) + "\n");
    }

    Timer {
        id: initTimer
        running: true
        interval: 100
        repeat: false
        onTriggered: {
            root.send({action: "music_library"});
            root.send({action: "frecency_load"});
        }
    }
}
