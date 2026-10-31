import QtQuick

// The clipped-off bands of an FxState (clip-path inset), painted in the colour
// behind the dashboard so the tile looks sliced.
Item {
    id: cut
    property FxState fx
    anchors.fill: parent
    z: 1000
    Rectangle {
        visible: cut.fx.cutTop > 0
        x: -2; y: -2
        width: parent.width + 4
        height: cut.fx.cutTop * parent.height + 2
        color: Theme.backdrop
    }
    Rectangle {
        visible: cut.fx.cutBottom > 0
        x: -2
        height: cut.fx.cutBottom * parent.height + 2
        y: parent.height - height + 2
        width: parent.width + 4
        color: Theme.backdrop
    }
}
