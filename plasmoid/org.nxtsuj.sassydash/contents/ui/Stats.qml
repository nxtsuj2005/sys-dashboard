pragma Singleton
import QtQuick
import org.kde.ksysguard.sensors as Sensors

// All live numbers come from ksystemstats (the daemon behind Plasma's own
// system monitor widgets) — no /proc polling or child processes of our own.
// Sensors update on their own phases; everything visible reads the snapshot
// below, taken once per tick, so the scene repaints once a second, not per sensor.
QtObject {
    id: stats
    signal tick()
    property int ticks: 0

    property real cpu
    property real ramPct
    property real diskPct
    property real down
    property real up
    property real temp
    property real load1
    property int cores: 1
    property real ramUsed
    property real ramTotal
    property string ramUsedText: "—"
    property string ramTotalText: "—"
    property string diskFreeText: "—"
    property string downText: "—"
    property string upText: "—"
    property string host: ""

    readonly property Sensors.Sensor sCpu:      Sensors.Sensor { sensorId: "cpu/all/usage" }
    readonly property Sensors.Sensor sCores:    Sensors.Sensor { sensorId: "cpu/all/coreCount" }
    readonly property Sensors.Sensor sTemp:     Sensors.Sensor { sensorId: "cpu/all/averageTemperature"; updateRateLimit: 2000 }
    readonly property Sensors.Sensor sLoad1:    Sensors.Sensor { sensorId: "cpu/loadaverages/loadaverage1"; updateRateLimit: 5000 }
    readonly property Sensors.Sensor sRamPct:   Sensors.Sensor { sensorId: "memory/physical/usedPercent" }
    readonly property Sensors.Sensor sRamUsed:  Sensors.Sensor { sensorId: "memory/physical/used" }
    readonly property Sensors.Sensor sRamTotal: Sensors.Sensor { sensorId: "memory/physical/total" }
    readonly property Sensors.Sensor sDiskPct:  Sensors.Sensor { sensorId: "disk/all/usedPercent"; updateRateLimit: 10000 }
    readonly property Sensors.Sensor sDiskFree: Sensors.Sensor { sensorId: "disk/all/free"; updateRateLimit: 10000 }
    readonly property Sensors.Sensor sDown:     Sensors.Sensor { sensorId: "network/all/download" }
    readonly property Sensors.Sensor sUp:       Sensors.Sensor { sensorId: "network/all/upload" }
    readonly property Sensors.Sensor sHost:     Sensors.Sensor { sensorId: "os/system/hostname" }

    function num(s) { const v = Number(s.value); return Number.isFinite(v) ? v : 0; }
    function fmt(s) { return s.formattedValue || "—"; }

    readonly property Timer timer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stats.cpu = stats.num(stats.sCpu);
            stats.ramPct = stats.num(stats.sRamPct);
            stats.diskPct = stats.num(stats.sDiskPct);
            stats.down = stats.num(stats.sDown);
            stats.up = stats.num(stats.sUp);
            stats.temp = stats.num(stats.sTemp);
            stats.load1 = stats.num(stats.sLoad1);
            stats.cores = Math.max(1, stats.num(stats.sCores));
            stats.ramUsed = stats.num(stats.sRamUsed);
            stats.ramTotal = stats.num(stats.sRamTotal);
            stats.ramUsedText = stats.fmt(stats.sRamUsed);
            stats.ramTotalText = stats.fmt(stats.sRamTotal);
            stats.diskFreeText = stats.fmt(stats.sDiskFree);
            stats.downText = stats.fmt(stats.sDown);
            stats.upText = stats.fmt(stats.sUp);
            stats.host = String(stats.sHost.value || "");
            stats.ticks++;
            stats.tick();
        }
    }
}
