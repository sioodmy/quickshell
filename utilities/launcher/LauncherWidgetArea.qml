import QtQuick
import "../../theme"
import qs.services

Column {
    id: root

    property var launcher
    property var backend

    height: root.visible ? implicitHeight : 0
    visible: launcher ? (launcher.sliderModeActive || launcher.captureModeActive || launcher.dndModeActive || launcher.pomModeActive || launcher.cocModeActive) : false
    spacing: 8
    topPadding: 8
    bottomPadding: 4

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    LauncherSliderWidget {
        id: volSliderWidget
        width: parent.width
        active: launcher ? launcher.volSliderActive : false
        label: "Volume"
        accent: Theme.primary
        value: Math.min(1, launcher?.pipewireSink?.audio?.volume ?? 0)
        icon: {
            if (launcher?.pipewireSink?.audio?.muted ?? true)
                return "volume_off";
            if (value >= 0.6)
                return "volume_up";
            if (value >= 0.3)
                return "volume_down";
            return "volume_mute";
        }
        onMoved: v => {
            if (launcher?.pipewireSink?.audio) {
                launcher.pipewireSink.audio.muted = false;
                launcher.pipewireSink.audio.volume = v;
            }
        }
    }

    LauncherSliderWidget {
        id: blSliderWidget
        width: parent.width
        active: launcher ? launcher.blSliderActive : false
        label: "Brightness"
        accent: Theme.tertiary
        value: Brightness.value
        icon: {
            if (value >= 0.7) return "light_mode";
            if (value >= 0.3) return "brightness_5";
            return "brightness_6";
        }
        onMoved: v => Brightness.setPercent(v * 100)
    }

    LauncherScreenshotWidget {
        id: ssWidget
        width: parent.width
        active: launcher ? launcher.ssModeActive : false
        onAction: id => {
            if (backend) {
                if (id === "fullscreen")
                    backend.executeSystemCommand("ss_fullscreen");
                else if (id === "area")
                    backend.executeSystemCommand("ss_area");
                else if (id === "window")
                    backend.executeSystemCommand("ss_window");
                else if (id === "menu")
                    backend.executeSystemCommand("ss_menu");
            }
        }
    }

    LauncherRecordWidget {
        id: recWidget
        width: parent.width
        active: launcher ? launcher.recModeActive : false
        onAction: id => {
            if (backend) {
                if (id === "fullscreen")
                    backend.executeSystemCommand("rec_fullscreen");
                else if (id === "area")
                    backend.executeSystemCommand("rec_area");
                else if (id === "stop")
                    backend.executeSystemCommand("rec_stop");
            }
        }
    }

    LauncherDndWidget {
        id: dndWidget
        width: parent.width
        active: launcher ? launcher.dndModeActive : false
    }

    LauncherCocaineWidget {
        id: cocWidget
        width: parent.width
        active: launcher ? launcher.cocModeActive : false
        caffeineEnabled: backend ? backend.cocaineEnabled : false
        onToggled: enabled => {
            if (backend) {
                backend.cocaineEnabled = enabled;
                BackendDaemon.send({ action: enabled ? "cocaine_enable" : "cocaine_disable" });
            }
        }
    }

    LauncherPomodoroWidget {
        id: pomWidget
        width: parent.width
        active: launcher ? launcher.pomModeActive : false
    }
}
