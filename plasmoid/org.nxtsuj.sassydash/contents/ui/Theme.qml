pragma Singleton
import QtQuick

// Mirrors what the Electron dashboard finally renders (src/index.html :root + the
// last override block), minus the glows. Colours used by single cards stay local.
QtObject {
    readonly property color bg:      "#0e1116"
    readonly property color card:    "#161b22"
    readonly property color panel:   "#1c2230"
    readonly property color border:  "#2a313c"
    readonly property color accent:  "#4f9cf9"
    readonly property color accentDim: Qt.tint(border, "#8c4f9cf9")
    readonly property color green:   "#3fb950"
    readonly property color orange:  "#d29922"
    readonly property color red:     "#f85149"
    readonly property color text:    "#e6edf3"
    readonly property color text2:   "#9aa7b4"
    readonly property color muted:   "#91a0b1"
    readonly property color termBg:  "#0a1018"
    // panel tiles / buttons inside cards (weather tiles, event rows, shortcut buttons)
    readonly property color tile:       "#1b2533"
    readonly property color tileHover:  "#25384e"
    readonly property color tileBorder: "#334251"
    readonly property color labelBlue:  "#8fa4bd"

    readonly property int gap: 8
    readonly property int radius: 3

    function pick(candidates, fallback) {
        const have = Qt.fontFamilies();
        for (const f of candidates) if (have.indexOf(f) !== -1) return f;
        return fallback;
    }
    readonly property string mono: pick(["DejaVu Sans Mono", "Noto Sans Mono", "Hack"], "monospace")
    readonly property string sans: Qt.application.font.family   // CSS system-ui
    readonly property string display: sans

    function level(pct, warn, crit) { return pct >= crit ? red : pct >= warn ? orange : text; }
}
