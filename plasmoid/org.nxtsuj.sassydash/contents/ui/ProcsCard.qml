import QtQuick
import QtQuick.Layouts

Card {
    id: card
    title: "Top-Prozesse"
    property var procs: []         // [{ pid, cpu, res, name }]

    // top prints RES in KiB, or with an m/g/t suffix once it gets large.
    function mem(raw) {
        const m = /^([\d.]+)([kmgt]?)$/i.exec(raw || "");
        if (!m) return raw || "";
        const mib = parseFloat(m[1]) * { "": 1 / 1024, k: 1 / 1024, m: 1, g: 1024, t: 1048576 }[m[2].toLowerCase()];
        return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB";
    }

    // Second top iteration = CPU share over the last 0.6 s (the first one is since boot).
    Command {
        every: 3000
        command: "LC_ALL=C top -bn2 -d0.6 -w 512 -o %CPU | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ "
               + "{print $1 \"\\t\" $9 \"\\t\" $6 \"\\t\" $12; if (++c == 5) exit}'"
        onFinished: (out) => {
            card.procs = out.split("\n").filter(l => l).map(l => {
                const [pid, cpu, res, name] = l.split("\t");
                return { pid, cpu: parseFloat(cpu) || 0, res: card.mem(res), name };
            });
        }
    }

    ListView {
        anchors.fill: parent
        clip: true
        spacing: 4
        interactive: false
        model: card.procs
        delegate: Item {
            id: row
            required property var modelData
            width: ListView.view.width
            height: 22
            Rectangle {
                anchors { left: parent.left; bottom: parent.bottom }
                height: 2
                width: parent.width * Math.min(100, row.modelData.cpu) / 100
                color: Theme.accent
                opacity: 0.7
            }
            RowLayout {
                anchors { fill: parent; bottomMargin: 3 }
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font { family: Theme.mono; pixelSize: 11 }
                }
                Text { text: row.modelData.res; color: Theme.muted; font { family: Theme.mono; pixelSize: 10 } }
                Text {
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.cpu.toFixed(0) + "%"
                    color: Theme.level(row.modelData.cpu, 50, 90)
                    font { family: Theme.mono; pixelSize: 11 }
                }
            }
        }
    }
}
