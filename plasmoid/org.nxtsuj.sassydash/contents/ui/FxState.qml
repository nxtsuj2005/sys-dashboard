import QtQuick

// Per-item glitch state, set in hard steps by Fx.qml (Electron's steps(1) keyframes):
// tear offset + skew, a clipped band (clip-path inset), opacity, and a slot
// displacement used when tiles "lose their place". Identity when idle.
QtObject {
    id: s
    property real h: 0            // item height, for skewing around the centre like CSS
    property real tx: 0           // tear offset (keyframe translateX)
    property real dx: 0           // slot displacement
    property real dy: 0
    property real skew: 0         // degrees (skewX)
    property real cutTop: 0       // fraction hidden from the top
    property real cutBottom: 0    // fraction hidden from the bottom
    property real alpha: 1
    property bool hidden: false
    readonly property real opacity: hidden ? 0 : alpha

    readonly property Matrix4x4 shear: Matrix4x4 {
        readonly property real t: Math.tan(s.skew * Math.PI / 180)
        matrix: Qt.matrix4x4(1, t, 0, -t * s.h / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    }
    readonly property Translate shift: Translate { x: s.tx + s.dx; y: s.dy }

    function frame(k) {           // one keyframe; missing keys fall back to identity
        tx = k.tx ?? 0;
        skew = k.skew ?? 0;
        cutTop = k.cutTop ?? 0;
        cutBottom = k.cutBottom ?? 0;
        alpha = k.alpha ?? 1;
    }
    function reset() { frame({}); dx = 0; dy = 0; hidden = false; }
}
