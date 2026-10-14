// KWin script (loaded by main.js via org.kde.kwin.Scripting, not by Electron).
// Reports whether the dashboard window is hidden behind a maximized or
// fullscreen window — Chromium on Wayland never learns about occlusion itself.
// Placeholders are filled in by main.js before loading.
const DASH_PID = __DASH_PID__;
const SERVICE = '__DBUS_SERVICE__', PATH = '__DBUS_PATH__', IFACE = '__DBUS_IFACE__';

let last = null;

function report(occluded, force) {
  if (!force && occluded === last) return;
  last = occluded;
  callDBus(SERVICE, PATH, IFACE, 'Report', occluded);
}

function onCurrentDesktop(w) {
  return w.onAllDesktops || w.desktops.some(d => d === workspace.currentDesktop);
}

function onCurrentActivity(w) {
  return !w.activities.length || w.activities.indexOf(workspace.currentActivity) !== -1;
}

function covers(w, dash) {
  if (w.fullScreen || w.maximizeMode === 3) return true;
  const a = w.frameGeometry, b = dash.frameGeometry;
  return a.x <= b.x && a.y <= b.y && a.x + a.width >= b.x + b.width && a.y + a.height >= b.y + b.height;
}

function evaluate() {
  try {
    const stack = workspace.stackingOrder;
    const di = stack.findIndex(w => w.pid === DASH_PID && w.normalWindow);
    if (di < 0) return report(false);
    const dash = stack[di];
    if (dash.minimized || !onCurrentDesktop(dash) || !onCurrentActivity(dash)) return report(true);
    for (let i = di + 1; i < stack.length; i++) {
      const w = stack[i];
      if (!w.normalWindow || w.minimized || w.hidden || w.hiddenByShowDesktop) continue;
      if (w.output !== dash.output || !onCurrentDesktop(w) || !onCurrentActivity(w)) continue;
      if (covers(w, dash)) return report(true);
    }
    report(false);
  } catch (e) {
    // Fail open: a broken check must never freeze the dashboard.
    print('sys-dashboard occlusion: ' + e);
    report(false);
  }
}

const WINDOW_SIGNALS = ['frameGeometryChanged', 'minimizedChanged', 'fullScreenChanged',
  'maximizedChanged', 'outputChanged', 'desktopsChanged', 'activitiesChanged',
  'stackingOrderChanged', 'hiddenChanged', 'hiddenByShowDesktopChanged'];

function watch(w) {
  for (const s of WINDOW_SIGNALS) if (w[s] && w[s].connect) w[s].connect(evaluate);
}

workspace.stackingOrder.forEach(watch);
workspace.windowAdded.connect(w => { watch(w); evaluate(); });
workspace.windowRemoved.connect(evaluate);
workspace.windowActivated.connect(evaluate);
workspace.currentDesktopChanged.connect(evaluate);
workspace.currentActivityChanged.connect(evaluate);

// Safety net for missed signals + heartbeat so main.js can fail open if we die.
const timer = new QTimer();
timer.interval = 2000;
timer.timeout.connect(() => { evaluate(); report(last, true); });
timer.start();
evaluate();
report(last, true);
