import QtQuick

// A number that eases toward `to` (cubic ease-out, Electron gauges/bars) on the
// shared Stats glide frames instead of a display-rate animation.
QtObject {
    id: g
    property real to: 0
    property real value: 0
    property real from: 0

    Component.onCompleted: value = to
    onToChanged: {
        if (Stats.frac >= 1) { value = to; return; }   // off-tick change or glide off: no frames coming
        from = value;
    }
    readonly property Connections step: Connections {
        target: Stats
        enabled: g.value !== g.to
        function onFrame() { g.value = Stats.frac >= 1 ? g.to : g.from + (g.to - g.from) * Stats.eased; }
    }
}
