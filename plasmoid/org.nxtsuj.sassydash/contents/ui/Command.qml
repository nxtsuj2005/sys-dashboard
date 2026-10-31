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
    signal finished(string stdout, int exitCode)

    engine: "executable"
    interval: every
    connectedSources: (every > 0 || pending) && command !== "" ? [command] : []

    onNewData: (source, data) => {
        const code = data["exit code"] ?? -1;
        if (code !== 0 && data["stderr"]) console.warn("sassydash:", source, "→", code, data["stderr"]);
        if (every <= 0) pending = false;
        finished(data["stdout"] ?? "", code);
    }
    function run() { if (command !== "") pending = true; }
}
