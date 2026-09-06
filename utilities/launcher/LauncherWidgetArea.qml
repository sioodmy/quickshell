import QtQuick
import "../../theme"
import qs.services

Column {
    id: root

    property var launcherWindow
    property var ctrl

    height: root.visible ? implicitHeight : 0
    visible: launcherWindow && (launcherWindow.sliderModeActive || launcherWindow.captureModeActive || launcherWindow.dndModeActive || launcherWindow.pomModeActive || launcherWindow.cocModeActive)
    spacing: 8
    topPadding: 8
    bottomPadding: 4

    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    LauncherSliderWidget {
        id: volSliderWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.volSliderActive : false
        label: "Volume"
        accent: Theme.primary
        value: Math.min(1, launcherWindow?.pipewireSink?.audio?.volume ?? 0)
        icon: {
            if (launcherWindow?.pipewireSink?.audio?.muted ?? true)
                return "volume_off";
            if (value >= 0.6)
                return "volume_up";
            if (value >= 0.3)
                return "volume_down";
            return "volume_mute";
        }
        onMoved: v => {
            if (launcherWindow?.pipewireSink?.audio) {
                launcherWindow.pipewireSink.audio.muted = false;
                launcherWindow.pipewireSink.audio.volume = v;
            }
        }
    }

    LauncherSliderWidget {
        id: blSliderWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.blSliderActive : false
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
        active: launcherWindow ? launcherWindow.ssModeActive : false
        onAction: id => {
            if (ctrl) {
                if (id === "fullscreen")
                    ctrl.executeSystemCommand("ss_fullscreen");
                else if (id === "area")
                    ctrl.executeSystemCommand("ss_area");
                else if (id === "window")
                    ctrl.executeSystemCommand("ss_window");
                else if (id === "menu")
                    ctrl.executeSystemCommand("ss_menu");
            }
        }
    }

    LauncherRecordWidget {
        id: recWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.recModeActive : false
        onAction: id => {
            if (ctrl) {
                if (id === "fullscreen")
                    ctrl.executeSystemCommand("rec_fullscreen");
                else if (id === "area")
                    ctrl.executeSystemCommand("rec_area");
                else if (id === "stop")
                    ctrl.executeSystemCommand("rec_stop");
            }
        }
    }

    LauncherDndWidget {
        id: dndWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.dndModeActive : false
    }

    LauncherCocaineWidget {
        id: cocWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.cocModeActive : false
        caffeineEnabled: ctrl ? ctrl.cocaineEnabled : false
        onToggled: enabled => {
            if (ctrl) {
                ctrl.cocaineEnabled = enabled;
                BackendDaemon.send({ action: enabled ? "cocaine_enable" : "cocaine_disable" });
            }
        }
    }

    LauncherPomodoroWidget {
        id: pomWidget
        width: parent.width
        active: launcherWindow ? launcherWindow.pomModeActive : false
    }
}
