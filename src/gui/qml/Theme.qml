pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property color backgroundColor: "#3c3d3f"
    readonly property color surfaceColor: "#252525"
    readonly property color surfaceDark: "#131416"
    readonly property color cardBackground: "#666666"

    readonly property color primaryAccent: "#d8fa00"
    readonly property color secondaryAccent: "#92fa00"
    readonly property color dangerAccent: "#e91a1a"
    readonly property color disabledAccent: "#808080"

    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#666666"
    readonly property color textTertiary: "#1f1e1e"
    readonly property color textOnAccent: "#000000"

    readonly property string fontFamily: "Alatsi"
    readonly property string fontFamilyTitle: "Audiowide"

    readonly property int fontSizeHuge: 40
    readonly property int fontSizeLarge: 32
    readonly property int fontSizeMedium: 20
    readonly property int fontSizeNormal: 16
    readonly property int fontSizeSmall: 14

    readonly property int spacingTiny: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 24
    readonly property int spacingHuge: 36

    readonly property int radiusSmall: 18
    readonly property int radiusMedium: 20
    readonly property int radiusLarge: 36

    readonly property int buttonHeight: 31
    readonly property int buttonHeightLarge: 47
    readonly property int buttonHeightHuge: 69

    readonly property int navbarIconSize: 35
    readonly property int navbarButtonSize: 68

    readonly property int modCardHeight: 108
    readonly property int modThumbnailSize: 92

    readonly property int animationDuration: 200
    readonly property int animationDurationSlow: 400

    property var easingStandard: Easing.OutCubic
    property var easingEnter: Easing.OutBack
    property var easingExit: Easing.InCubic
}
