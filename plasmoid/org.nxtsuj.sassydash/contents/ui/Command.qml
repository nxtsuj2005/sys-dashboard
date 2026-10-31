import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs a shell command via Plasma's executable engine. every > 0 → repeats.
// One-shots also go through connectedSources: an imperative connectSource()
// during plasmashell startup can be dropped by the shared engine.
P5Support.DataSource {
    id: src
    property string command: ""
    property int every: 0
    property bool pending: false
    property bool immediate: false   // deliver right away instead of on the next tick (boot feed)
    signal finished(string stdout, int exitCode)

    engine: "executable"
    interval: every
    connectedSources: (every > 0 || pending) && command !== "" ? [command] : []

    // Results are held until the next Stats tick so every card repaints in the
    // same once-a-second frame instead of whenever its process happens to exit.
    property var queued: null
    onNewData: (source, data) => {
        const code = data["exit code"] ?? -1;
        if (code !== 0 && data["stderr"]) console.warn("sassydash:", source, "→", code, data["stderr"]);
        if (every <= 0) pending = false;
        if (immediate) { finished(data["stdout"] ?? "", code); return; }
        queued = { out: data["stdout"] ?? "", code };
    }
    readonly property Connections flush: Connections {
        target: Stats
        enabled: src.queued !== null
        function onTick() {
            const q = src.queued;
            src.queued = null;
            src.finished(q.out, q.code);
        }
    }
    function run() { if (command !== "") pending = true; }
}
