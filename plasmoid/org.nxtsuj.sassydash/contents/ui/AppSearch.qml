import QtQuick
import QtQuick.Controls as QQC2

// Ctrl+K app search (Electron initCmdK + scanApps/launch-desktop): .desktop
// entries scanned once, fuzzy-ish ranking, launched via gio (kioclient fallback).
Rectangle {
    id: search
    anchors.fill: parent
    visible: false
    color: Qt.rgba(6 / 255, 8 / 255, 12 / 255, 0.55)
    z: 50

    property var apps: null          // [{ id, name, terminal, file }]
    property var filtered: []
    property int sel: 0
    property bool loading: false

    function toggle() { visible ? close() : open(); }
    function open() {
        if (visible) return;
        input.text = "";
        visible = true;
        if (!apps && !loading) { loading = true; scan.run(); }
        filter();
        input.forceActiveFocus();
    }
    function close() { visible = false; }

    // 0 = prefix, 1+ = substring (later is worse), 5 = subsequence, Infinity = no match
    function score(q, name) {
        name = name.toLowerCase();
        if (name.startsWith(q)) return 0;
        const i = name.indexOf(q);
        if (i > 0) return 1 + i / 200;
        let k = 0;
        for (let c = 0; c < name.length && k < q.length; c++) if (name[c] === q[k]) k++;
        return k === q.length ? 5 : Infinity;
    }
    function filter() {
        const q = input.text.trim().toLowerCase();
        const src = apps || [];
        filtered = !q ? src.slice(0, 60)
            : src.map(a => [score(q, a.name), a])
                 .filter(x => x[0] !== Infinity)
                 .sort((x, y) => x[0] - y[0] || x[1].name.length - y[1].name.length)
                 .slice(0, 60)
                 .map(x => x[1]);
        sel = 0;
    }
    function launch() {
        const a = filtered[sel];
        if (!a) return;
        // The path ends up inside a shell command: allow only plain path characters.
        if (!/^\/[A-Za-z0-9._\/+@-]+\.desktop$/.test(a.file)) {
            console.warn("sassydash: refusing to launch unusual desktop file path:", a.file);
            return;
        }
        launcher.command = "sh -c 'setsid -f gio launch \"$1\" >/dev/null 2>&1 || setsid -f kioclient exec \"$1\"' _ " + a.file;
        launcher.run();
        close();
    }

    // First entry per desktop id wins, in XDG priority order (user dirs first like XDG says,
    // then system); NoDisplay/Hidden/non-Application entries are skipped.
    Command {
        id: scan
        command: "sh -c 'for d in \"$HOME/.local/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" "
               + "/var/lib/flatpak/exports/share/applications /usr/local/share/applications /usr/share/applications /var/lib/snapd/desktop/applications; do "
               + "[ -d \"$d\" ] && for f in \"$d\"/*.desktop; do [ -f \"$f\" ] && printf \"%s\\n\" \"$f\"; done; done' | "
               + "awk 'BEGIN{FS=\"=\"} function flush(){ if (file != \"\" && name != \"\" && ex && !hide && (type == \"\" || type == \"Application\") && !(id in seen)) "
               + "{ seen[id]=1; print id \"\\t\" name \"\\t\" term \"\\t\" file } } "
               + "{ flush(); file=$0; id=file; sub(/.*\\//, \"\", id); sub(/\\.desktop$/, \"\", id); name=\"\"; ex=0; hide=0; type=\"\"; term=0; sec=0; "
               + "while ((getline l < file) > 0) { if (l ~ /^\\[/) { sec = (l == \"[Desktop Entry]\"); continue } if (!sec) continue; "
               + "k=l; sub(/=.*/, \"\", k); v=substr(l, length(k) + 2); gsub(/^[ \\t]+|[ \\t]+$/, \"\", k); "
               + "if (k == \"Name\" && name == \"\") name=v; else if (k == \"Exec\") ex=1; else if (k == \"Type\") type=v; "
               + "else if ((k == \"NoDisplay\" || k == \"Hidden\") && tolower(v) == \"true\") hide=1; else if (k == \"Terminal\" && tolower(v) == \"true\") term=1 } "
               + "close(file) } END{ flush() }'"
        onFinished: (out) => {
            search.apps = out.split("\n").filter(l => l).map(l => {
                const [id, name, term, file] = l.split("\t");
                return { id, name, terminal: term === "1", file };
            }).sort((a, b) => a.name.localeCompare(b.name, "de"));
            console.log("sassydash: app search scanned", search.apps.length, "entries");
            search.loading = false;
            if (search.visible) search.filter();
        }
    }
    Command { id: launcher }

    MouseArea { anchors.fill: parent; onPressed: search.close() }

    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.07
        width: Math.min(560, parent.width * 0.86)
        height: field.height + list.height
        color: Theme.card
        border.color: Theme.accentDim
        radius: Theme.radius
        clip: true
        MouseArea { anchors.fill: parent }   // swallow clicks so the backdrop doesn't close

        Rectangle {
            id: field
            width: parent.width
            height: 44
            color: Theme.panel
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            QQC2.TextField {
                id: input
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                background: null
                color: Theme.text
                placeholderText: "App suchen …"
                placeholderTextColor: Theme.muted
                font { family: Theme.mono; pixelSize: 14 }
                onTextEdited: search.filter()
                Keys.onDownPressed: { search.sel = Math.min(search.sel + 1, search.filtered.length - 1); list.positionViewAtIndex(search.sel, ListView.Contain); }
                Keys.onUpPressed: { search.sel = Math.max(search.sel - 1, 0); list.positionViewAtIndex(search.sel, ListView.Contain); }
                Keys.onReturnPressed: search.launch()
                Keys.onEnterPressed: search.launch()
                Keys.onEscapePressed: search.close()
            }
        }

        ListView {
            id: list
            anchors.top: field.bottom
            width: parent.width
            height: Math.min(contentHeight, search.height * 0.44) || 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: search.filtered
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property bool current: index === search.sel
                width: ListView.view.width
                height: 34
                color: current ? Theme.panel : "transparent"
                Rectangle { visible: item.current; width: 2; height: parent.height; color: Theme.accent }
                Text {
                    anchors { left: parent.left; leftMargin: 16; right: badge.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: item.modelData.name
                    elide: Text.ElideRight
                    color: item.current ? Theme.text : Theme.text2
                    font { family: Theme.mono; pixelSize: 12 }
                }
                Text {
                    id: badge
                    anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    visible: item.modelData.terminal
                    text: "TERMINAL"
                    color: Theme.muted
                    font { family: Theme.mono; pixelSize: 9; letterSpacing: 1 }
                }
                HoverHandler { onHoveredChanged: if (hovered) search.sel = item.index }
                TapHandler { onTapped: { search.sel = item.index; search.launch(); } }
            }
            Text {
                visible: search.filtered.length === 0
                x: 16; y: 13
                text: search.loading ? "Lade Apps …" : "Nichts gefunden"
                color: Theme.muted
                font { family: Theme.mono; pixelSize: 12 }
            }
        }
    }
}
