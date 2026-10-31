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
        return mib >= 1024 ? (mib / 1024).toFixed(1) + "G" : Math.round(mib) + "M";
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

    headerExtras: Row {
        spacing: 5
        Rectangle { width: 7; height: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "CPU"; color: Theme.muted; font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 } }
    }

    // Electron .tp-row: name + "cpu% memM" on one line, a 3 px bar under it scaled
    // to the busiest process (min 2 %). Rows are fixed slots so bars can ease
    // between refreshes instead of being rebuilt.
    Column {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 6
        readonly property real maxCpu: Math.max(1, card.procs.length ? card.procs[0].cpu : 1)
        Repeater {
            model: 5
            delegate: Column {
                id: row
                required property int index
                readonly property var p: card.procs[index] ?? null
                readonly property Glide bar: Glide {
                    to: row.p ? Math.max(0.02, Math.min(1, row.p.cpu / list.maxCpu)) : 0
                }
                visible: p !== null
                width: list.width
                spacing: 3
                RowLayout {
                    width: parent.width
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: row.p ? row.p.name : ""
                        elide: Text.ElideRight
                        color: Theme.text
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                    Text {
                        textFormat: Text.StyledText
                        text: row.p ? row.p.cpu.toFixed(0) + "%&nbsp;<font size=\"1\" color=\"" + Theme.muted + "\">" + row.p.res + "</font>" : ""
                        color: Theme.accent
                        font { family: Theme.mono; pixelSize: 10 }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 3
                    color: Theme.panel
                    Rectangle {
                        height: parent.height
                        width: parent.width * row.bar.value
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.tint(Theme.bg, Qt.alpha(Theme.accent, 0.55)) }
                            GradientStop { position: 1; color: Theme.accent }
                        }
                    }
                }
            }
        }
    }
}
