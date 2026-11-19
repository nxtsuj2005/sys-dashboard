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
    property int timeout: 30         // seconds; a hung process is killed and reports exit 124
    signal finished(string stdout, int exitCode)

    // The engine cannot kill what it started, so coreutils timeout does it. The
    // command is single-quoted for sh -c; it is always our own fixed string.
    readonly property string source: command === "" ? ""
        : "timeout -k 2 " + Math.max(1, timeout) + " sh -c '" + command.replace(/'/g, "'\\''") + "'"

    engine: "executable"
    interval: every
    connectedSources: (every > 0 || pending) && source !== "" ? [source] : []

    // Results are held until the next Stats tick so every card repaints in the
    // same once-a-second frame instead of whenever its process happens to exit.
    property var queued: null
    onNewData: (source, data) => {
        const code = data["exit code"] ?? -1;
        if (code === 124) console.warn("sassydash: timed out after", timeout, "s:", command);
        else if (code !== 0 && data["stderr"]) console.warn("sassydash:", command, "→", code, data["stderr"]);
        if (every <= 0) { pending = false; watchdog.stop(); }
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
    // Last resort if the engine never answers a one-shot: free `pending` so callers can retry.
    readonly property Timer watchdog: Timer {
        interval: (src.timeout + 5) * 1000
        onTriggered: {
            if (!src.pending) return;
            console.warn("sassydash: no result from executable engine, giving up:", src.command);
            src.pending = false;
            src.finished("", -1);
        }
    }
    function run() {
        if (command === "") return;
        pending = true;
        watchdog.restart();
    }
}
