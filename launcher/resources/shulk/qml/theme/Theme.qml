// SPDX-License-Identifier: GPL-3.0-only
pragma Singleton
import QtQuick

QtObject {
    id: root

    // Handheld scale multiplier
    readonly property real scale: typeof shulkTheme !== "undefined" ? shulkTheme.scaleFactor : 1.0

    // Launcher palette: clean graphite surfaces with a single Minecraft-green accent.
    readonly property color bgDeep: "#0C0D0E"
    readonly property color bgSurface: "#171819"
    readonly property color bgSurfaceRaised: "#202122"
    readonly property color bgSurfaceHover: "#292B2C"
    readonly property color bgSurfaceFocused: "#303332"
    readonly property color bgOverlay: "#E80C0D0E"
    readonly property color bgPanel: "#F2171819"

    // Minecraft Material Palette
    readonly property color mcDirt: "#3C2B1D"
    readonly property color mcDeepslate: "#1B1C1D"
    readonly property color mcBedrock: "#121214"
    readonly property color mcStone: "#4F5052"
    readonly property color mcStoneLight: "#8F9094"
    readonly property color mcStoneDark: "#2A2A2C"
    readonly property color mcGold: "#FFAA00"
    readonly property color mcEmerald: "#3C8527"
    readonly property color mcEmeraldDark: "#2A641C"
    readonly property color mcDiamond: "#55FFFF"
    readonly property color mcRedstone: "#FF5555"
    readonly property color mcNetherite: "#2C2628"
    readonly property color mcTextShadow: "#2F2F2F"
    readonly property color fontShadowColor: "#3F3F3F"
    readonly property color fontShadowDark: "#3F3F3F"
    readonly property int fontShadowStyle: Text.Outline
    readonly property real fontShadowOffset: Math.max(1, Math.round(sizeBody / 8))

    // Authentic Minecraft quarter-brightness shadow calculation:
    // In Minecraft Java Edition: shadowColor = (color >> 2) & 0x3F3F3F (each RGB channel / 4)
    function getShadowColor(fgColor) {
        if (!fgColor) return "#3F3F3F"
        var c = Qt.color(fgColor)
        var lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        // Too dark check (matches "Too dark." behavior in Minecraft): text that is nearly black shouldn't have a muddy shadow
        if (lum < 0.10) {
            return "transparent"
        }
        var r = Math.floor(c.r * 255 / 4) / 255
        var g = Math.floor(c.g * 255 / 4) / 255
        var b = Math.floor(c.b * 255 / 4) / 255
        return Qt.rgba(r, g, b, c.a)
    }

    // Authentic Minecraft font shadow offset:
    // In Minecraft: at standard 8px glyph height, shadow is 1px.
    // Scales proportionally with font size (1:8 ratio).
    function getShadowOffset(pixelSize) {
        var size = (pixelSize && pixelSize > 0) ? pixelSize : sizeBody
        return Math.max(1, Math.round(size / 8))
    }

    // Accents
    readonly property color accentShulk: "#3C8527"
    readonly property color accentShulkLight: "#52A535"
    readonly property color accentPlay: mcEmerald
    readonly property color accentPlayHover: "#52A535"
    readonly property color accentWarning: mcGold
    readonly property color accentDanger: mcRedstone

    // Controller Focus Visuals
    readonly property color focusRing: "#FFFFFF"
    readonly property color focusRingGlow: "#70FFFFFF"
    readonly property color borderSubtle: "#3B3C3D"
    readonly property color borderStrong: "#5A5C5D"
    readonly property color borderFocused: "#FFFFFF"

    // Text Palette
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#C4C5C6"
    readonly property color textMuted: "#8B8D8E"
    readonly property color textOnAccent: "#FFFFFF"
    readonly property color textGold: mcGold
    readonly property color textGreen: mcEmerald

    // A legible launcher face for dense UI; Minecraft lettering remains available for display moments.
    readonly property string fontFamily: "Mojangles"
    readonly property string fontPixel: "Mojangles"
    readonly property string fontDisplay: "Mojangles"
    readonly property string fontBody: "Inter, Noto Sans, system-ui, sans-serif"
    readonly property int sizeHero: Math.round(38 * scale)
    readonly property int sizeTitle: Math.round(26 * scale)
    readonly property int sizeHeader: Math.round(18 * scale)
    readonly property int sizeBody: Math.round(14 * scale)
    readonly property int sizeCaption: Math.round(12 * scale)
    readonly property int sizeSmall: Math.round(10 * scale)

    // Spacing
    readonly property int space4: Math.round(4 * scale)
    readonly property int space6: Math.round(6 * scale)
    readonly property int space8: Math.round(8 * scale)
    readonly property int space10: Math.round(10 * scale)
    readonly property int space12: Math.round(12 * scale)
    readonly property int space14: Math.round(14 * scale)
    readonly property int space16: Math.round(16 * scale)
    readonly property int space20: Math.round(20 * scale)
    readonly property int space24: Math.round(24 * scale)
    readonly property int space28: Math.round(28 * scale)
    readonly property int space32: Math.round(32 * scale)
    readonly property int space48: Math.round(48 * scale)

    // Square, compact geometry shared by the current official launcher family.
    readonly property int radiusSm: Math.round(2 * scale)
    readonly property int radiusMd: Math.round(3 * scale)
    readonly property int radiusLg: Math.round(4 * scale)
    readonly property int radiusPill: 999
    readonly property int radiusSmall: radiusSm
    readonly property int radiusMedium: radiusMd
    readonly property int radiusLarge: radiusLg

    // Semantic Aliases
    readonly property color accentPrimary: accentShulk
    readonly property color bgCard: bgSurfaceRaised
    readonly property color bgCardHover: bgSurfaceHover
    readonly property color borderFocus: borderFocused
    readonly property int sizeSubheading: sizeHeader

    // Semantic Status Colors
    readonly property color bgDanger: "#241513"
    readonly property color bgDangerBorder: "#703630"
    readonly property color textDanger: "#FF8888"
    readonly property color bgSuccess: "#203D22"
    readonly property color bgSuccessBorder: "#38703C"
    readonly property color textSuccess: "#9BD38B"
    readonly property color bgInfo: "#1B2433"
    readonly property color bgInfoBorder: "#2E415E"
    readonly property color textInfo: "#38BDF8"

    // Controller Action Constants (matches LogicalAction in ShulkInputManager.h)
    readonly property int actionUp: 1
    readonly property int actionDown: 2
    readonly property int actionLeft: 3
    readonly property int actionRight: 4
    readonly property int actionAccept: 5
    readonly property int actionBack: 6
    readonly property int actionPrimary: 7
    readonly property int actionSecondary: 8
    readonly property int actionMenu: 9
    readonly property int actionSearch: 10
    readonly property int actionPrevTab: 11
    readonly property int actionNextTab: 12
    readonly property int actionFilter: 13
    readonly property int actionRefresh: 14
    readonly property int actionTriggerLeft: 15
    readonly property int actionTriggerRight: 16

    // Animation durations
    readonly property int animFast: 80
    readonly property int animNormal: 180
    readonly property int animSlow: 300
}
