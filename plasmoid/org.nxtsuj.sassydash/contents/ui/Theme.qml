pragma Singleton
import QtQuick

// Palette mirrors the Electron dashboard (src/index.html :root), minus the glows.
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
    readonly property color muted:   "#6b7480"
    readonly property color termBg:  "#0a1018"

    readonly property int gap: 9
    readonly property int radius: 2

    function pick(candidates, fallback) {
        const have = Qt.fontFamilies();
        for (const f of candidates) if (have.indexOf(f) !== -1) return f;
        return fallback;
    }
    readonly property string mono: pick(["JetBrains Mono", "Cascadia Code", "DejaVu Sans Mono", "Hack", "Noto Sans Mono"], "monospace")
    readonly property string sans: pick(["Space Grotesk", "Inter", "Noto Sans"], "sans-serif")
    readonly property string display: pick(["Chakra Petch", "Space Grotesk", "Noto Sans"], "sans-serif")

    function level(pct, warn, crit) { return pct >= crit ? red : pct >= warn ? orange : text; }
}
