import QtQuick
import QtQuick.Layouts

Card {
    id: card
    title: "Dienste"
    property int running: -1
    property var failed: []        // [{ name, user }]

    Command {
        every: 10000
        command: "LC_ALL=C sh -c 'systemctl list-units --state=running --no-legend --plain 2>/dev/null | wc -l; "
               + "echo @sys; systemctl --failed --no-legend --plain 2>/dev/null; "
               + "echo @user; systemctl --user --failed --no-legend --plain 2>/dev/null'"
        onFinished: (out) => {
            const lines = out.split("\n");
            card.running = parseInt(lines[0], 10);
            const list = [];
            let user = false;
            for (const l of lines.slice(1)) {
                if (l === "@sys" || l === "@user") { user = l === "@user"; continue; }
                const name = l.trim().split(/\s+/)[0];
                if (name) list.push({ name, user });
            }
            card.failed = list;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            spacing: 14
            Text {
                text: "running " + (card.running >= 0 ? card.running : "—")
                color: Theme.text2
                font { family: Theme.mono; pixelSize: 11 }
            }
            Text {
                text: "failed " + card.failed.length
                color: card.failed.length ? Theme.red : Theme.green
                font { family: Theme.mono; pixelSize: 11 }
            }
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: card.failed
            delegate: Rectangle {
                id: svc
                required property var modelData
                width: ListView.view.width
                height: 20
                color: Theme.panel
                radius: Theme.radius
                Rectangle { width: 2; height: parent.height; color: Theme.red }
                Text {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8 }
                    text: svc.modelData.name + (svc.modelData.user ? "  (user)" : "")
                    elide: Text.ElideRight
                    color: Theme.text2
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: card.running >= 0 && card.failed.length === 0
                text: "Alles grün"
                color: Theme.muted
                font { family: Theme.mono; pixelSize: 11 }
            }
        }
    }
}
