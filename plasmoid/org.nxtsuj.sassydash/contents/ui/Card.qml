import QtQuick
import QtQuick.Layouts

// Flat card with an uppercase mono title; children go into the body below it.
Rectangle {
    id: card
    property string title: ""
    property alias headerExtras: extras.data
    default property alias body: content.data
    property int padding: 10
    property int titleGap: 10

    color: Theme.card
    border.color: hover.hovered ? Theme.accentDim : Theme.border
    border.width: 1
    radius: Theme.radius
    clip: true

    HoverHandler { id: hover }
    readonly property FxState fx: FxState { h: card.height }
    transform: [fx.shear, fx.shift]
    opacity: fx.opacity
    enabled: !fx.hidden            // a hidden tile takes no clicks or keys
    FxCut { fx: card.fx }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: card.padding
        spacing: card.titleGap

        RowLayout {
            visible: card.title !== ""
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: card.title
                color: Theme.text2
                font { family: Theme.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1; capitalization: Font.AllUppercase }
            }
            Item { Layout.fillWidth: true }
            Row { id: extras; spacing: 10 }
        }

        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
