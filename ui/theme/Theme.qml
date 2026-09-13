pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

FileView {
    id: root
    path: Quickshell.shellPath("theme/colors.json")
    watchChanges: true
    onFileChanged: reload()

    // --- ALIASES ---
    property alias primary: colors.primary
    property alias on_primary: colors.on_primary
    property alias primary_container: colors.primary_container
    property alias on_primary_container: colors.on_primary_container

    property alias secondary: colors.secondary
    property alias on_secondary: colors.on_secondary
    property alias secondary_container: colors.secondary_container
    property alias on_secondary_container: colors.on_secondary_container

    property alias tertiary: colors.tertiary
    property alias on_tertiary: colors.on_tertiary
    property alias tertiary_container: colors.tertiary_container
    property alias on_tertiary_container: colors.on_tertiary_container

    property alias background: colors.background
    property alias surface: colors.surface
    property alias on_surface: colors.on_surface

    property alias surface_variant: colors.surface_variant
    property alias on_surface_variant: colors.on_surface_variant
    property alias inverse_surface: colors.inverse_surface
    property alias inverse_on_surface: colors.inverse_on_surface

    property alias surface_container_lowest: colors.surface_container_lowest
    property alias surface_container_low: colors.surface_container_low
    property alias surface_container: colors.surface_container
    property alias surface_container_high: colors.surface_container_high
    property alias surface_container_highest: colors.surface_container_highest

    property alias outline: colors.outline
    property alias outline_variant: colors.outline_variant

    property alias critical: colors.critical
    property alias on_critical: colors.on_critical
    property alias wallpaper_path: colors.wallpaper_path

    // --- LIQUID GLASS SURFACES ---
    // Translucent fills for UI drawn over a compositor-blurred backdrop.
    // Note: the tokens above are strings, so `Theme.x.r` is undefined and
    // `Qt.rgba(Theme.x.r, ...)` silently yields black. Use Qt.alpha instead.
    readonly property color glass_card: Qt.alpha(colors.surface_container, 0.58)
    readonly property color glass_panel: Qt.alpha(colors.surface_container_high, 0.42)
    readonly property color glass_raised: Qt.alpha(colors.surface_container_highest, 0.58)
    readonly property color glass_fade: Qt.alpha(colors.surface, 0.6)

    // Outer shell for dock / launcher / keepass. Dense enough that white
    // text stays readable on bright wallpapers, while blur still shows through.
    readonly property color glass_shell: Qt.rgba(0, 0, 0, 0.52)
    readonly property color glass_shell_border: Qt.rgba(1, 1, 1, 0.22)

    readonly property color glass_hover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color glass_selected: Qt.alpha(colors.primary, 0.22)

    // --- LIQUID BUBBLES (controls) ---
    // Capsules that float ON glass — luminous white / soft tint, not another
    // frosted panel layer. Prefer these for buttons, chips, and pills.
    readonly property color bubble: Qt.rgba(1, 1, 1, 0.14)
    readonly property color bubble_hover: Qt.rgba(1, 1, 1, 0.26)
    readonly property color bubble_active: Qt.rgba(1, 1, 1, 0.34)
    readonly property color bubble_border: Qt.rgba(1, 1, 1, 0.34)
    readonly property color bubble_border_soft: Qt.rgba(1, 1, 1, 0.18)
    readonly property color bubble_sheen: Qt.rgba(1, 1, 1, 0.14)

    readonly property color bubble_accent: Qt.alpha(colors.primary, 0.4)
    readonly property color bubble_accent_soft: Qt.alpha(colors.primary, 0.22)
    readonly property color bubble_secondary: Qt.alpha(colors.secondary, 0.4)
    readonly property color bubble_secondary_soft: Qt.alpha(colors.secondary, 0.22)
    readonly property color bubble_tertiary: Qt.alpha(colors.tertiary, 0.4)
    readonly property color bubble_tertiary_soft: Qt.alpha(colors.tertiary, 0.22)
    readonly property color bubble_critical: Qt.alpha(colors.critical, 0.45)
    readonly property color bubble_critical_soft: Qt.alpha(colors.critical, 0.22)

    // Legacy aliases — point former frosted-button fills at liquid bubbles
    // so existing call sites pick up the new language.
    readonly property color glass_accent: bubble_accent
    readonly property color glass_accent_soft: bubble_accent_soft
    readonly property color glass_secondary: bubble_secondary
    readonly property color glass_secondary_soft: bubble_secondary_soft
    readonly property color glass_tertiary: bubble_tertiary
    readonly property color glass_tertiary_soft: bubble_tertiary_soft

    readonly property color glass_border: bubble_border_soft
    readonly property color glass_border_strong: bubble_border

    // --- DATA MAPPER ---
    JsonAdapter {
        id: colors

        property string wallpaper_path: ""
        property string primary: "#6750a4"
        property string on_primary: "#ffffff"
        property string primary_container: "#eaddff"
        property string on_primary_container: "#21005d"

        property string secondary: "#625b71"
        property string on_secondary: "#ffffff"
        property string secondary_container: "#e8def8"
        property string on_secondary_container: "#1d192b"

        property string tertiary: "#7d5260"
        property string on_tertiary: "#ffffff"
        property string tertiary_container: "#ffd8e4"
        property string on_tertiary_container: "#31111d"

        property string background: "#1c1b1f"
        property string on_background: "#e6e1e5"
        property string surface: "#1c1b1f"
        property string on_surface: "#e6e1e5"

        property string surface_variant: "#49454f"
        property string on_surface_variant: "#cac4d0"
        property string inverse_surface: "#e6e1e5"
        property string inverse_on_surface: "#313033"

        property string surface_container_lowest: "#0f0d13"
        property string surface_container_low: "#1d1b20"
        property string surface_container: "#211f26"
        property string surface_container_high: "#2b2930"
        property string surface_container_highest: "#36343b"

        property string outline: "#938f99"
        property string outline_variant: "#49454f"
        property string shadow: "#000000"
        property string scrim: "#000000"

        property string critical: "#b3261e"
        property string on_critical: "#ffffff"
    }
}
