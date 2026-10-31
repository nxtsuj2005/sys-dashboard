pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: card
    title: "Blockgeräte"

    property var treeRows: []
    property var media: []
    property var ioRates: ({})
    property var previousStats: ({})
    property real previousTime: 0
    property string blockSignature: ""
    property string lastLsblk: ""
    property string treeMessage: "Lade…"
    property bool ioReady: false
    readonly property var columnWidths: [0.15, 0.11, 0.09, 0.15, 0.42, 0.08]

    function isWholeDisk(name) {
        // Match Electron: exclude partitions, loop/zram, optical and mapper devices.
        return /^(sd[a-z]+|hd[a-z]+|vd[a-z]+|nvme\d+n\d+|mmcblk\d+|xvd[a-z]+)$/.test(name);
    }

    function mounts(dev) {
        // Preserve Electron's order, including a repeated primary mountpoint.
        return [dev.mountpoint].concat(dev.mountpoints || []).filter(Boolean);
    }

    function formatIo(kib) {
        const value = Number(kib) || 0;
        return value >= 1024 ? (value / 1024).toFixed(1) + " MB/s"
                             : Math.round(value) + " KB/s";
    }

    function parseLsblk(out) {
        const data = JSON.parse(out);
        if (!data || !Array.isArray(data.blockdevices))
            throw new Error("lsblk: blockdevices fehlt");
        const rows = [];
        const disks = [];
        function add(dev, depth) {
            if (!dev || typeof dev.name !== "string")
                throw new Error("lsblk: ungültiges Gerät");
            rows.push({
                topLevel: depth === 0,
                cells: [(depth ? "└─" : "") + dev.name,
                        dev.size == null ? "—" : String(dev.size),
                        dev.type || "—", dev.fstype || "—",
                        mounts(dev).join(", ") || "—", dev["fsuse%"] || "—"]
            });
            (dev.children || []).forEach(child => add(child, depth + 1));
        }
        // The final Electron table renders ALL roots into its visible column;
        // the old USB/external split is no longer used, even for loop/zram.
        data.blockdevices.forEach(dev => {
            add(dev, 0);
            if (isWholeDisk(dev.name)) {
                disks.push({ name: dev.name, transport: String(dev.tran || "").toUpperCase(),
                             label: [dev.name, dev.tran, String(dev.model || "").trim().replace(/\s+/g, " ")]
                                    .filter(Boolean).join(" ") });
            }
        });
        return { rows: rows, disks: disks };
    }

    function refreshTree() {
        if (!lsblk.pending) lsblk.run();
    }

    function parseDiskSample(out) {
        const separator = "\n@diskstats\n";
        const split = out.indexOf(separator);
        if (split < 0) throw new Error("diskstats: Signatur fehlt");
        const header = out.slice(0, split).split("\n");
        const time = Number(header.shift());
        if (!Number.isFinite(time) || time <= 0)
            throw new Error("diskstats: ungültige Laufzeit");
        const counters = {};
        out.slice(split + separator.length).trim().split("\n").forEach(line => {
            const fields = line.trim().split(/\s+/);
            if (!isWholeDisk(fields[2] || "")) return;
            const read = Number(fields[5]);
            const write = Number(fields[9]);
            if (fields.length < 10 || !Number.isFinite(read) || !Number.isFinite(write))
                throw new Error("diskstats: ungültige Zähler für " + fields[2]);
            counters[fields[2]] = { read: read, write: write, identity: fields[0] + ":" + fields[1] };
        });
        return { time: time, signature: header.join("\n"), counters: counters };
    }

    function sampleRates(before, after, elapsed) {
        const rates = {};
        Object.keys(after).forEach(name => {
            const current = after[name];
            const old = before[name];
            // /proc/diskstats sectors are always 512 bytes, including on 4K disks.
            const valid = old && old.identity === current.identity && elapsed > 0;
            rates[name] = {
                read: valid ? Math.max(0, Math.round((current.read - old.read) / (2 * elapsed))) : 0,
                write: valid ? Math.max(0, Math.round((current.write - old.write) / (2 * elapsed))) : 0
            };
        });
        return rates;
    }

    function acceptDiskSample(out) {
        const sample = parseDiskSample(out);
        const changed = blockSignature !== sample.signature;
        ioRates = sampleRates(changed ? {} : previousStats, sample.counters, sample.time - previousTime);
        previousStats = sample.counters;
        previousTime = sample.time;
        blockSignature = sample.signature;
        ioReady = true;
        if (changed) refreshTree();
    }

    Command {
        id: lsblk
        command: "LC_ALL=C lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MOUNTPOINTS,LABEL,FSTYPE,TRAN,MODEL,FSUSE%,FSAVAIL,FSSIZE -J # sassydash-storage-tree"
        onFinished: (out, exitCode) => {
            if (exitCode !== 0) {
                console.warn("sassydash: StorageCard lsblk fehlgeschlagen, Exit " + exitCode);
                card.treeMessage = "Blockgeräte nicht verfügbar";
                return;
            }
            if (out === card.lastLsblk) return;
            try {
                const parsed = card.parseLsblk(out);
                card.treeRows = parsed.rows;
                card.media = parsed.disks;
                card.treeMessage = parsed.rows.length ? "" : "Keine Blockgeräte";
                card.lastLsblk = out;
            } catch (error) {
                console.warn("sassydash: StorageCard " + error);
                card.treeMessage = "Blockgeräte nicht lesbar";
            }
        }
    }

    Command {
        every: 2000
        // Include partitions in the signature to also catch partition hotplug.
        // Read monotonic uptime so delayed polling and suspend do not inflate I/O.
        command: "LC_ALL=C sh -c 'read -r uptime rest < /proc/uptime || exit; "
                 + "printf \"%s\\n\" \"$uptime\" /sys/class/block/*; "
                 + "printf \"@diskstats\\n\"; cat /proc/diskstats' # sassydash-storage-io"
        onFinished: (out, exitCode) => {
            try {
                if (exitCode !== 0) throw new Error("diskstats: Exit " + exitCode);
                card.acceptDiskSample(out);
            } catch (error) {
                console.warn("sassydash: StorageCard " + error);
                card.previousStats = ({});
                card.previousTime = 0;
                card.ioRates = ({});
                card.ioReady = false;
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: card.refreshTree()
    }

    component TableRow: Row {
        id: line
        property var cells: []
        property bool topLevel: false
        property bool heading: false
        height: 17
        Repeater {
            model: line.cells
            delegate: Text {
                required property string modelData
                required property int index
                width: line.width * card.columnWidths[index]
                height: line.height
                rightPadding: 5
                text: modelData
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: line.heading ? "#8fa4be" : line.topLevel ? "#8dc0ff"
                       : index === 0 ? "#87b7ef" : "#bdcce0"
                font { family: Theme.mono; pixelSize: 11 }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Rectangle {
                width: parent.width
                height: Math.min(parent.height, 8 + 18 + Math.max(1, card.treeRows.length) * 17)
                color: Theme.panel
                radius: 6
                ColumnLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                    spacing: 0
                    TableRow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 17
                        heading: true
                        cells: ["NAME", "SIZE", "TYPE", "FS", "MOUNT", "USE%"]
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#344152" }
                    ListView {
                        id: tree
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: card.treeRows
                        ScrollBar.vertical: ScrollBar { }
                        delegate: TableRow {
                            required property var modelData
                            width: tree.width
                            cells: modelData.cells
                            topLevel: modelData.topLevel
                        }
                        Text {
                            visible: card.treeRows.length === 0
                            width: parent.width
                            text: card.treeMessage
                            elide: Text.ElideRight
                            color: Theme.muted
                            font { family: Theme.mono; pixelSize: 11 }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        Row {
            id: ioHeader
            Layout.fillWidth: true
            Layout.topMargin: 1
            Layout.preferredHeight: 12
            spacing: 6
            Repeater {
                model: ["MEDIUM", "READ", "WRITE"]
                delegate: Text {
                    required property string modelData
                    required property int index
                    width: index === 0 ? Math.max(0, ioHeader.width - 192) : 90
                    text: modelData
                    elide: Text.ElideRight
                    color: Theme.muted
                    font { family: Theme.sans; pixelSize: 9; weight: Font.Medium; letterSpacing: 1.2 }
                }
            }
        }
        ListView {
            id: ioList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(42, contentHeight)
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: card.media.length ? card.media : [{ name: "", transport: "", label: "" }]
            ScrollBar.vertical: ScrollBar { }
            delegate: Row {
                id: medium
                required property var modelData
                readonly property var rates: card.ioRates[modelData.name] || { read: 0, write: 0 }
                width: ioList.width
                height: 14
                spacing: 6
                Item {
                    width: Math.max(0, medium.width - 192)
                    height: parent.height
                    Row {
                        anchors.fill: parent
                        Text {
                            width: Math.min(implicitWidth, Math.max(0, parent.width - transport.implicitWidth))
                            text: medium.modelData.name || (card.lastLsblk ? "Keine Medien" : "Lade…")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.text
                            font { family: Theme.mono; pixelSize: 10 }
                        }
                        Text {
                            id: transport
                            text: medium.modelData.transport ? " " + medium.modelData.transport : ""
                            color: Theme.muted
                            font { family: Theme.mono; pixelSize: 9 }
                        }
                    }
                    HoverHandler { id: mediumHover }
                    ToolTip.visible: mediumHover.hovered && medium.modelData.label !== ""
                    ToolTip.text: medium.modelData.label
                }
                Text {
                    width: 90
                    horizontalAlignment: Text.AlignRight
                    text: card.ioReady ? card.formatIo(medium.rates.read) : "—"
                    color: Theme.green
                    font { family: Theme.mono; pixelSize: 10 }
                }
                Text {
                    width: 90
                    horizontalAlignment: Text.AlignRight
                    text: card.ioReady ? card.formatIo(medium.rates.write) : "—"
                    color: Theme.orange
                    font { family: Theme.mono; pixelSize: 10 }
                }
            }
        }
    }
}
