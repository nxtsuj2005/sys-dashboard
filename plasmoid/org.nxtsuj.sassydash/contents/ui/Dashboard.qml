import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

// Picks the view for this screen and wraps it in the shared boot/glitch/crash effects.
Rectangle {
    id: dash
    color: Theme.bg

    // "auto": the primary screen gets the full dashboard, every further screen the graph wall.
    readonly property string view: {
        const v = Plasmoid.configuration.view;
        if (v === "main" || v === "monitor") return v;
        return Plasmoid.containment.screen > 0 ? "monitor" : "main";
    }

    // Stats is shared by all screens: keep glideFps the same on each of them.
    // On battery glideFpsBattery takes over (-1 = no change); desktops have no AC source → plugged in.
    P5Support.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: ["AC Adapter"]
        readonly property bool onBattery: data["AC Adapter"]?.["Plugged in"] === false
    }
    Binding {
        target: Stats
        property: "glideFps"
        value: {
            const battery = Plasmoid.configuration.glideFpsBattery;
            const fps = power.onBattery && battery >= 0 ? battery : Plasmoid.configuration.glideFps;
            return Math.max(0, Math.min(60, fps));
        }
    }

    Item {   // the whole dashboard, so it can tear as one (boot reveal, crash)
        id: app
        anchors.fill: parent
        readonly property FxState fx: FxState { h: app.height }
        transform: [app.fx.shear, app.fx.shift]
        opacity: app.fx.opacity
        FxCut { fx: app.fx }

        Loader {
            id: content
            anchors.fill: parent
            source: dash.view === "monitor" ? "MonitorView.qml" : "MainView.qml"
        }
    }

    Rectangle { id: crashBlack; anchors.fill: parent; z: 5; visible: false; color: "#04070b" }
    BootScreen { id: bootScreen; anchors.fill: parent; z: 10 }
    Fx {
        id: effects
        app: app
        appFx: app.fx
        boot: bootScreen
        black: crashBlack
        topBar: content.item?.bar ?? null
        terminal: content.item?.term ?? null
        groups: content.item?.groups ?? []
        reduced: Plasmoid.configuration.reducedMotion
        debug: Plasmoid.configuration.fxDebug
    }
    Component.onCompleted: effects.startBoot(false)

    // Ctrl+K only while the desktop has focus (no global accelerator, by design).
    AppSearch { id: appSearch }
    Shortcut {
        sequences: ["Ctrl+K"]
        context: Qt.WindowShortcut
        onActivated: appSearch.toggle()
    }
}
