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
    property var cliphistItems: []

    Process {
        id: daemon
        command: ["backendqs", "daemon"]
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
                    } else if (type === "cliphist_result") {
                        root.cliphistItems = parsed.data || [];
                    }
                } catch(e) {
                    console.error("BackendDaemon JSON error:", e, trimmed);
                }
            }
        }
    }

    function send(msg) {
        if (daemon.running) {
            daemon.write(JSON.stringify(msg) + "\n");
        }
    }
}
