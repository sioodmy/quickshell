pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services // for Playerctl

Singleton {
    id: root
    
    // Array of objects: { time: float, text: string }
    property var parsedLyrics: []
    property int currentIndex: -1
    property bool showFullscreen: false
    property bool showOverlay: false
    
    property string currentLine: ""
    property string nextLine: ""
    
    property string currentLineTranslit: ""
    
    property string currentTrack: Playerctl.artist + " - " + Playerctl.title
    
    property var translitMap: {
        'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'zh',
        'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o',
        'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
        'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu',
        'я': 'ya',
        'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo', 'Ж': 'Zh',
        'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O',
        'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
        'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu',
        'Я': 'Ya',
        'і': 'i', 'І': 'I', 'ї': 'yi', 'Ї': 'Yi', 'є': 'ye', 'Є': 'Ye', 'ґ': 'g', 'Ґ': 'G',
        'ў': 'w', 'Ў': 'W'
    }
    
    function transliterate(text) {
        let hasCyrillic = /[А-Яа-яЁёІіЇїЄєҐґЎў]/.test(text);
        if (!hasCyrillic) return "";
        
        let result = "";
        for (let i = 0; i < text.length; i++) {
            let char = text[i];
            if (root.translitMap[char] !== undefined) {
                result += root.translitMap[char];
            } else {
                result += char;
            }
        }
        return result;
    }
    
    Timer {
        id: debounceTimer
        interval: 1000 // Wait 1 second before fetching to avoid spam
        repeat: false
        onTriggered: {
            if (Playerctl.title !== "") {
                BackendDaemon.send({"action": "lyrics", "artist": Playerctl.artist, "title": Playerctl.title});
            }
        }
    }
    
    Timer {
        id: retryTimer
        interval: 15000 // Retry after 15 seconds
        repeat: false
        onTriggered: {
            if (Playerctl.title !== "") {
                BackendDaemon.send({"action": "lyrics", "artist": Playerctl.artist, "title": Playerctl.title});
            }
        }
    }

    onCurrentTrackChanged: {
        parsedLyrics = [];
        currentLine = "";
        nextLine = "";
        currentLineTranslit = "";
        currentIndex = -1;
        
        BackendDaemon.lyricsStatus = "";
        BackendDaemon.lyricsContent = "";
        
        retryTimer.stop();
        debounceTimer.restart();
    }
    
    Connections {
        target: BackendDaemon
        function onLyricsStatusChanged() {
            if (BackendDaemon.lyricsStatus === "error") {
                console.log("Lyrics API failed. Retrying in 15 seconds...");
                retryTimer.start();
            } else if (BackendDaemon.lyricsStatus === "ok") {
                root.parseLrc(BackendDaemon.lyricsContent);
            }
        }
    }
    
    function parseLrc(lrc) {
        if (!lrc) {
            return;
        }
        
        let lines = lrc.split('\n');
        let arr = [];
        let regex = /\[(\d+):(\d+\.\d+)\](.*)/;
        for (let i = 0; i < lines.length; i++) {
            let match = lines[i].match(regex);
            if (match) {
                let minutes = parseFloat(match[1]);
                let seconds = parseFloat(match[2]);
                let text = match[3].trim();
                if (text !== "") {
                    arr.push({ time: minutes * 60 + seconds, text: text, textTranslit: root.transliterate(text) });
                }
            }
        }
        root.parsedLyrics = arr;
        root.updateLine(Playerctl.position);
    }
    
    Connections {
        target: Playerctl
        function onPositionChanged() {
            root.updateLine(Playerctl.position);
        }
    }
    
    function updateLine(pos) {
        if (parsedLyrics.length === 0) {
            currentLine = "";
            nextLine = "";
            currentLineTranslit = "";
            currentIndex = -1;
            return;
        }
        
        let idx = -1;
        for (let i = 0; i < parsedLyrics.length; i++) {
            if (pos >= parsedLyrics[i].time) {
                idx = i;
            } else {
                break;
            }
        }
        
        if (idx !== currentIndex) {
            currentIndex = idx;
            if (idx >= 0 && idx < parsedLyrics.length) {
                currentLine = parsedLyrics[idx].text;
                currentLineTranslit = parsedLyrics[idx].textTranslit || "";
                if (idx + 1 < parsedLyrics.length) {
                    nextLine = parsedLyrics[idx + 1].text;
                } else {
                    nextLine = "";
                }
            } else {
                currentLine = "";
                currentLineTranslit = "";
                if (parsedLyrics.length > 0) {
                    nextLine = parsedLyrics[0].text;
                } else {
                    nextLine = "";
                }
            }
        }
    }
}
