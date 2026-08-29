const { app, BrowserWindow, ipcMain, screen } = require('electron');
const { exec, execFile, execSync, spawn } = require('child_process');
const os   = require('os');
const fs   = require('fs');
const path = require('path');

let mainWindow;
let storageMonitor = null;
let storageNotifyTimer = null;

app.setName('SysDashboard');

// "Immer im Hintergrund" (keep below) wird über KWin-Fensterregeln erzwungen,
// nicht im Code — siehe ~/.config/kwinrulesrc (Titel "Dashboard" / Klasse
// "SysDashboardXterm", below=Force). Ozone-Plattform NICHT auf x11 zwingen:
// bricht das Rendering unter diesem KWin (GPU-Segfault, kein Fenster).

// ── Logging ────────────────────────────────────────────────────
const DASH_DIR   = path.join(os.homedir(), '.local', 'share', 'sys-dashboard');
const LOG_FILE   = path.join(DASH_DIR, 'dashboard.log');
const XTERM_PID  = path.join(DASH_DIR, 'xterm.pid');

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}\n`;
  process.stdout.write(line);
  try { fs.appendFileSync(LOG_FILE, line); } catch {}
}

function rotateLogIfLarge() {
  try {
    if (!fs.existsSync(LOG_FILE)) return;
    if (fs.statSync(LOG_FILE).size <= 1_000_000) return;
    const kept = fs.readFileSync(LOG_FILE, 'utf8').split('\n').slice(-500);
    fs.writeFileSync(LOG_FILE, kept.join('\n'));
    log('Log rotiert (letzte 500 Zeilen behalten)');
  } catch {}
}

function detectBattery() {
  const root = '/sys/class/power_supply';
  const rd = (p) => { try { return fs.readFileSync(p, 'utf8').trim(); } catch { return null; } };

  try {
    const devices = fs.readdirSync(root);
    return devices.some(d => /^BAT/i.test(d)) ||
      devices.some(d => rd(path.join(root, d, 'type')) === 'Battery');
  } catch {
    return false;
  }
}

function readX11WorkArea() {
  try {
    const out = execSync('xprop -root _NET_WORKAREA 2>/dev/null', {
      encoding: 'utf8',
      env: { ...process.env, DISPLAY: process.env.DISPLAY || ':0' },
    });
    const nums = out.match(/-?\d+/g)?.map(Number) || [];
    if (nums.length >= 4 && nums[2] > 0 && nums[3] > 0) {
      return { x: nums[0], y: nums[1], width: nums[2], height: nums[3] };
    }
  } catch {}
  return null;
}

function readEnvInt(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  return Number.isFinite(value) ? value : fallback;
}

function getDashboardBounds() {
  const display = screen.getPrimaryDisplay();
  const x11WorkArea = readX11WorkArea();
  const workArea = x11WorkArea || display.workArea;
  const fallback = display.workArea || display.bounds;
  const hasFullWorkArea =
    !x11WorkArea &&
    workArea.x === display.bounds.x &&
    workArea.y === display.bounds.y &&
    workArea.width === display.bounds.width &&
    workArea.height === display.bounds.height;
  const defaultPanelInset = readEnvInt('SYS_DASHBOARD_PANEL_INSET', 0);
  const inset = {
    top: readEnvInt('SYS_DASHBOARD_INSET_TOP', defaultPanelInset),
    right: readEnvInt('SYS_DASHBOARD_INSET_RIGHT', 0),
    bottom: readEnvInt('SYS_DASHBOARD_INSET_BOTTOM', defaultPanelInset),
    left: readEnvInt('SYS_DASHBOARD_INSET_LEFT', 0),
  };
  const base = {
    x: Number.isFinite(workArea.x) ? workArea.x : fallback.x,
    y: Number.isFinite(workArea.y) ? workArea.y : fallback.y,
    width: workArea.width || fallback.width,
    height: workArea.height || fallback.height,
  };
  const bounds = {
    x: base.x + inset.left,
    y: base.y + inset.top,
    width: Math.max(640, base.width - inset.left - inset.right),
    height: Math.max(360, base.height - inset.top - inset.bottom),
  };

  log(`Display bounds=${JSON.stringify(display.bounds)} workArea=${JSON.stringify(display.workArea)} x11WorkArea=${JSON.stringify(x11WorkArea)} hasFullWorkArea=${hasFullWorkArea} inset=${JSON.stringify(inset)} dashboard=${JSON.stringify(bounds)}`);
  return bounds;
}

// ── Window ─────────────────────────────────────────────────────
function createWindow() {
  const dashboardBounds = getDashboardBounds();
  mainWindow = new BrowserWindow({
    ...dashboardBounds,
    frame: false, transparent: false,
    alwaysOnTop: false, skipTaskbar: true,
    resizable: true, fullscreen: false,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      additionalArguments: [`--sys-dashboard-has-battery=${detectBattery() ? '1' : '0'}`],
      preload: path.join(__dirname, 'preload.js'),
    },
    backgroundColor: '#0d0f14',
  });
  mainWindow.loadFile(path.join(__dirname, 'index.html'));
  mainWindow.once('ready-to-show', () => {
    mainWindow.setBounds(dashboardBounds);
    mainWindow.setSkipTaskbar(true);
    mainWindow.show();
    mainWindow.focus();
  });
  log('Dashboard gestartet');
}

// Nur eine Instanz — zweiter Start fokussiert das vorhandene Fenster
const gotSingleInstanceLock = app.requestSingleInstanceLock();
if (!gotSingleInstanceLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.show();
      mainWindow.focus();
    }
  });

  app.whenReady().then(() => {
    rotateLogIfLarge();
    killOldXterm();
    createWindow();
    startStorageMonitor();
  });
}

app.on('window-all-closed', () => {
  stopStorageMonitor();
  killExternalTerminal();
  log('Dashboard beendet');
  app.quit();
});

// ── Storage hotplug monitor ────────────────────────────────────
function notifyStorageChanged() {
  clearTimeout(storageNotifyTimer);
  storageNotifyTimer = setTimeout(() => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('storage-changed');
    }
  }, 350);
}

function startStorageMonitor() {
  if (storageMonitor) return;

  storageMonitor = spawn('udevadm', ['monitor', '--udev', '--subsystem-match=block'], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  storageMonitor.stdout.on('data', (buf) => {
    const out = buf.toString();
    if (/(add|remove|change)\s+/.test(out)) notifyStorageChanged();
  });

  storageMonitor.stderr.on('data', (buf) => {
    const msg = buf.toString().trim();
    if (msg) log('udevadm monitor: ' + msg);
  });

  storageMonitor.on('error', (err) => {
    log('Storage-Monitor nicht verfügbar: ' + err.message);
    storageMonitor = null;
  });

  storageMonitor.on('exit', (code) => {
    storageMonitor = null;
    log(`Storage-Monitor beendet (exit ${code})`);
  });

  log('Storage-Monitor gestartet');
}

function stopStorageMonitor() {
  clearTimeout(storageNotifyTimer);
  storageNotifyTimer = null;
  if (storageMonitor) {
    try { storageMonitor.kill('SIGTERM'); } catch {}
    storageMonitor = null;
  }
}

// ── IPC: CPU ───────────────────────────────────────────────────
ipcMain.handle('get-cpu', async () => {
  return new Promise((resolve) => {
    const s = os.cpus().map(c => ({ idle: c.times.idle, total: Object.values(c.times).reduce((a,b)=>a+b,0) }));
    setTimeout(() => {
      const e = os.cpus().map(c => ({ idle: c.times.idle, total: Object.values(c.times).reduce((a,b)=>a+b,0) }));
      const usages = s.map((x,i) => Math.round(100*(1-(e[i].idle-x.idle)/(e[i].total-x.total))));
      resolve({ avg: Math.round(usages.reduce((a,b)=>a+b,0)/usages.length), cores: usages });
    }, 500);
  });
});

// ── IPC: RAM ───────────────────────────────────────────────────
function readRam() {
  const total = os.totalmem(), free = os.freemem(), used = total - free;
  return {
    total: Math.round(total/1024/1024), used: Math.round(used/1024/1024),
    free:  Math.round(free/1024/1024),  percent: Math.round(used/total*100),
  };
}
ipcMain.handle('get-ram', () => readRam());

// ── IPC: consolidated System-Stats (ein Aufruf pro Tick) ──────
// Löst nach ~500ms auf (CPU-Delta-Sampling wie get-cpu).
function readHottestTempC() {
  try {
    const root = '/sys/class/thermal';
    const zones = fs.readdirSync(root).filter(d => /^thermal_zone\d+$/.test(d));
    const rd = (p) => { try { return fs.readFileSync(p, 'utf8').trim(); } catch { return null; } };
    let pkg = null, max = null;
    for (const z of zones) {
      const type = rd(`${root}/${z}/type`);
      const raw  = rd(`${root}/${z}/temp`);
      if (raw === null) continue;
      const c = parseInt(raw, 10);
      if (!Number.isFinite(c)) continue;
      if (type === 'x86_pkg_temp' && pkg === null) pkg = c;
      if (max === null || c > max) max = c;
    }
    const milli = pkg !== null ? pkg : max;
    return milli === null ? null : Math.round(milli / 1000);
  } catch { return null; }
}
ipcMain.handle('get-system-stats', async () => {
  return new Promise((resolve) => {
    const s = os.cpus().map(c => ({ idle: c.times.idle, total: Object.values(c.times).reduce((a,b)=>a+b,0) }));
    setTimeout(() => {
      const e = os.cpus().map(c => ({ idle: c.times.idle, total: Object.values(c.times).reduce((a,b)=>a+b,0) }));
      const cores = s.map((x,i) => Math.round(100*(1-(e[i].idle-x.idle)/(e[i].total-x.total))));
      resolve({
        cpu:    { avg: Math.round(cores.reduce((a,b)=>a+b,0)/cores.length), cores },
        ram:    readRam(),
        load:   os.loadavg(),
        uptime: Math.round(os.uptime()),
        kernel: os.release(),
        tempC:  readHottestTempC(),
      });
    }, 500);
  });
});

// ── IPC: Hostname ──────────────────────────────────────────────
ipcMain.handle('get-hostname', () => { try { return os.hostname(); } catch { return ''; } });

// ── IPC: systemd-Dienste ───────────────────────────────────────
ipcMain.handle('get-services', async () => new Promise((resolve) => {
  const done = (r) => resolve(r);
  const run = (cmd) => new Promise((res) => {
    exec(cmd, { timeout: 4000 }, (err, out) => res(err ? '' : (out || '')));
  });
  const parseFailed = (text) => {
    const list = [];
    for (const line of text.split('\n')) {
      const t = line.trim();
      if (!t) continue;
      const p = t.split(/\s+/);
      if (p.length < 4) continue;
      const name = p[0];
      const desc = p.slice(4).join(' ');
      list.push({ name, desc });
    }
    return list;
  };
  Promise.all([
    run('systemctl --user list-units --state=failed --no-legend --no-pager --plain'),
    run('systemctl list-units --state=failed --no-legend --no-pager --plain'),
    run('systemctl list-units --state=running --no-legend --no-pager --plain'),
  ]).then(([userFailed, sysFailed, running]) => {
    const byName = new Map();
    for (const u of [...parseFailed(userFailed), ...parseFailed(sysFailed)]) {
      if (!byName.has(u.name)) byName.set(u.name, u);
    }
    const failed = [...byName.values()];
    const runningCount = running.split('\n').filter(l => l.trim()).length;
    done({ failed, failedCount: failed.length, runningCount });
  }).catch(() => done({ failed: [], failedCount: 0, runningCount: 0 }));
}));

// ── IPC: Network ───────────────────────────────────────────────
ipcMain.handle('get-net', async () => {
  return new Promise((resolve) => {
    const read = () => {
      const lines = fs.readFileSync('/proc/net/dev','utf8').split('\n').slice(2);
      let rx=0,tx=0;
      // Virtuelle Interfaces (Container/VPN/Bridges) ausklammern — sonst
      // werden Durchsatzzahlen durch docker/veth/tun-Traffic verfälscht.
      const SKIP = /^(lo|docker|veth|br-|virbr|tun|tap|wg|vnet|vmnet|kube|cni|flannel|cali)/;
      for (const l of lines) {
        const p=l.trim().split(/\s+/);
        if (p.length<10) continue;
        const name=p[0].replace(':','');
        if (!name||SKIP.test(name)) continue;
        rx+=parseInt(p[1])||0; tx+=parseInt(p[9])||0;
      }
      return {rx,tx};
    };
    const s=read();
    setTimeout(()=>{ const e=read(); resolve({rx:Math.round((e.rx-s.rx)/1024),tx:Math.round((e.tx-s.tx)/1024)}); },1000);
  });
});

// ── IPC: lsblk ─────────────────────────────────────────────────
ipcMain.handle('get-lsblk', async () => new Promise((resolve) => {
  exec('lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MOUNTPOINTS,LABEL,FSTYPE,TRAN,MODEL,FSUSE%,FSAVAIL,FSSIZE -J 2>/dev/null || lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,FSTYPE,TRAN,MODEL -J 2>/dev/null || lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL',
    (err,out) => resolve(out||'lsblk nicht verfügbar'));
}));

// ── IPC: Disk I/O (KB/s per Gerät) ────────────────────────────
const DISK_RE = /^(sd[a-z]+|hd[a-z]+|vd[a-z]+|nvme\d+n\d+|mmcblk\d+|xvd[a-z]+)$/;
ipcMain.handle('get-disk-io', async () => new Promise((resolve) => {
  const readStats = () => {
    try {
      const map = {};
      fs.readFileSync('/proc/diskstats','utf8').split('\n').forEach(line => {
        const p = line.trim().split(/\s+/);
        if (p.length < 10) return;
        const name = p[2];
        if (!DISK_RE.test(name)) return;
        // sectors_read=p[5], sectors_written=p[9]; 1 sector = 512 B
        map[name] = { r: parseInt(p[5])||0, w: parseInt(p[9])||0 };
      });
      return map;
    } catch { return {}; }
  };
  const s = readStats();
  setTimeout(() => {
    const e = readStats();
    const out = {};
    for (const name of Object.keys(s)) {
      if (!e[name]) continue;
      // diff sectors / 2 = KB  (512 B * diff / 1024)
      out[name] = {
        read:  Math.max(0, Math.round((e[name].r - s[name].r) / 2)),
        write: Math.max(0, Math.round((e[name].w - s[name].w) / 2)),
      };
    }
    resolve(out);
  }, 1000);
}));

// ── IPC: Weather ───────────────────────────────────────────────
ipcMain.handle('get-weather', async (_,city) => new Promise((resolve) => {
  const u = `https://wttr.in/${encodeURIComponent(city)}?format=j1`;
  execFile('curl', ['-s', '--max-time', '5', '--', u], { maxBuffer: 1<<20 },
    (err,out) => { try { resolve(JSON.parse(out)); } catch { resolve(null); } });
}));

// ── IPC: RSS ───────────────────────────────────────────────────
ipcMain.handle('get-rss', async (_,url) => new Promise((resolve) => {
  if (!/^https?:\/\//i.test(url)) return resolve('');           // nur http(s), kein Shell-Kram
  execFile('curl', ['-s', '--max-time', '8', '--', url], { maxBuffer: 1<<20 },
    (err,out) => resolve(out||''));
}));

// ── IPC: Notes ─────────────────────────────────────────────────
const NOTES = path.join(os.homedir(), '.dashboard-notes.txt');
ipcMain.handle('save-notes', (_,txt) => { fs.writeFileSync(NOTES, txt, 'utf8'); return true; });
ipcMain.handle('load-notes', () => { try { return fs.readFileSync(NOTES,'utf8'); } catch { return ''; } });

// ── IPC: Battery (sysfs) ───────────────────────────────────────
ipcMain.handle('get-battery', () => {
  const root = '/sys/class/power_supply';
  const rd   = (p) => { try { return fs.readFileSync(p,'utf8').trim(); } catch { return null; } };

  let devices;
  try { devices = fs.readdirSync(root); } catch { return null; }

  let bat = devices.find(d => /^BAT/i.test(d));
  if (!bat) bat = devices.find(d => rd(`${root}/${d}/type`) === 'Battery' && rd(`${root}/${d}/capacity`) !== null);
  if (!bat) bat = devices.find(d => rd(`${root}/${d}/capacity`) !== null);
  if (!bat) return null;

  const base     = `${root}/${bat}`;
  const capacity = parseInt(rd(`${base}/capacity`)) || 0;
  const status   = rd(`${base}/status`) || 'Unknown';

  const energyNow  = parseInt(rd(`${base}/energy_now`))  || 0;
  const energyFull = parseInt(rd(`${base}/energy_full`)) || 0;
  const powerNow   = parseInt(rd(`${base}/power_now`))   || 0;
  const chargeNow  = parseInt(rd(`${base}/charge_now`))  || 0;
  const chargeFull = parseInt(rd(`${base}/charge_full`)) || 0;
  const currentNow = parseInt(rd(`${base}/current_now`)) || 0;
  const voltageNow = parseInt(rd(`${base}/voltage_now`)) || 0;

  const eN = energyNow  || chargeNow;
  const eF = energyFull || chargeFull;
  const pN = powerNow   || currentNow;

  let timeLeft = null;
  if (pN > 0) {
    if (status === 'Discharging') timeLeft = Math.round((eN / pN) * 3600);
    if (status === 'Charging')    timeLeft = Math.round(((eF - eN) / pN) * 3600);
  }

  let watts = null;
  if (powerNow > 0) watts = powerNow / 1000000;
  else if (currentNow > 0 && voltageNow > 0) watts = (currentNow * voltageNow) / 1000000000000;

  return { capacity, status, timeLeft, watts };
});

// ── IPC: Logs ──────────────────────────────────────────────────
ipcMain.handle('get-logs', () => {
  try {
    const lines = fs.readFileSync(LOG_FILE,'utf8').split('\n').filter(Boolean);
    return lines.slice(-150).join('\n');
  } catch { return '(Noch keine Logs)'; }
});

// ── Externes Terminal (xterm als rahmenlose Overlay-Fenster) ──
// -into funktioniert auf XWayland nicht (exit 83 / Reparenting nicht unterstützt)
// Stattdessen: xterm als eigenes X11-Fenster, positioniert über dem Terminal-Bereich
// SKIP_TASKBAR versteckt es aus der Taskbar. "Immer unten" macht die KWin-Regel (kwinrulesrc).
let termProc     = null;
let termWid      = null;   // X11-WID des xterm-Fensters
let termGeom     = null;   // { x, y, w, h } — Bildschirmkoordinaten des terminal-wrappers
let termGen      = 0;

function toScreenGeom(geom) {
  const bounds = mainWindow && !mainWindow.isDestroyed()
    ? mainWindow.getBounds()
    : { x: 0, y: 0 };

  return {
    x: Math.round(bounds.x + geom.x),
    y: Math.round(bounds.y + geom.y),
    w: Math.max(80, Math.round(geom.w)),
    h: Math.max(60, Math.round(geom.h)),
  };
}

function killOldXterm() {
  try {
    const pid = parseInt(fs.readFileSync(XTERM_PID,'utf8').trim());
    if (pid) try { process.kill(pid, 'SIGTERM'); log(`Alter xterm (PID ${pid}) beendet`); } catch {}
  } catch {}
  try { fs.unlinkSync(XTERM_PID); } catch {}
}

function killExternalTerminal() {
  termGen++;                 // invalidiert einen evtl. anstehenden Auto-Neustart (exit-Handler)
  termWid = null;
  if (termProc) { try { termProc.kill('SIGTERM'); } catch {} termProc = null; }
  try { fs.unlinkSync(XTERM_PID); } catch {}
}

function applyWindowProps(wid, x, y, w, h) {
  // Fenster sofort verstecken → konfigurieren → an richtiger Position einblenden
  // So sieht der Nutzer nie einen dekorierten oder falsch positionierten Flash
  exec(`xdotool windowunmap ${wid}`, () => {
    // Keine WM-Dekorationen (Motif WM Hints: flags=2 → nur Dekorationen, decorations=0)
    exec(`xprop -id ${wid} -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "2, 0, 0, 0, 0"`, () => {});
    // Fenstertyp Utility: kein Taskbar-Eintrag, kein normales Fenster-Management
    exec(`xprop -id ${wid} -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_UTILITY`, () => {});
    // Keep Below + Taskleisten/Pager/Switcher überspringen — xterm bleibt hinter normalen Fenstern.
    exec(`xprop -id ${wid} -f _NET_WM_STATE 32a -set _NET_WM_STATE "_NET_WM_STATE_SKIP_TASKBAR,_NET_WM_STATE_SKIP_PAGER,_KDE_NET_WM_STATE_SKIP_SWITCHER"`, () => {});
    // Position + Größe setzen, dann erst einblenden
    exec(`xdotool windowmove ${wid} ${x} ${y} windowsize ${wid} ${w} ${h}`, () => {
      exec(`xdotool windowmap ${wid}`, () => {
        log(`xterm konfiguriert: WID ${wid} @ (${x},${y}) ${w}×${h}`);
      });
    });
  });
}

function spawnTerminal() {
  killExternalTerminal();
  const gen = ++termGen;

  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (!termGeom) { log('xterm: termGeom noch nicht gesetzt'); return; }

  const { x, y, w, h } = termGeom;
  const env = { ...process.env, DISPLAY: process.env.DISPLAY || ':0' };

  // Kein -into: xterm als normales X11-Fenster, startet direkt an richtiger Position
  termProc = spawn('xterm', [
    '-class',    'SysDashboardXterm',
    '-name',     'sys-dashboard-xterm',
    '-geometry', `+${x}+${y}`,   // Startposition = Terminal-Bereich auf dem Bildschirm
    '-bg',      '#0a0c10',
    '-fg',      '#e8eaed',
    '-cr',      '#4fc3f7',
    '-selbg',   '#4fc3f7',
    '-selfg',   '#0a0c10',
    '+sb',                        // kein Scrollbar
    '-bc',                        // Block-Cursor
    '-bw',      '0',
    '-e',       '/usr/bin/fish',
  ], { detached: false, env });

  fs.writeFileSync(XTERM_PID, String(termProc.pid), 'utf8');
  log(`xterm gestartet (PID ${termProc.pid})`);

  termProc.on('error', (err) => log('xterm Fehler: ' + err.message));
  termProc.on('exit', (code) => {
    if (gen !== termGen) return;
    termProc = null; termWid = null;
    try { fs.unlinkSync(XTERM_PID); } catch {}
    log(`xterm beendet (exit ${code}), Neustart in 800ms`);
    setTimeout(() => { if (gen === termGen) spawnTerminal(); }, 800);
  });

  // --sync: blockiert bis das xterm-Fenster erscheint → sofort unmap bevor User es sieht.
  // timeout, damit ein nie erscheinendes Fenster den Handler nicht ewig hängen lässt.
  exec(`xdotool search --sync --pid ${termProc.pid} 2>/dev/null | tail -1`,
    { timeout: 6000, killSignal: 'SIGKILL' }, (err, out) => {
    if (gen !== termGen || !termProc) return;
    const wid = (out || '').trim();
    if (wid) {
      termWid = wid;
      applyWindowProps(wid, x, y, w, h);
    } else {
      log('xterm WID nicht gefunden (--sync' + (err ? ', ' + err.message : '') + ')');
    }
  });
}

ipcMain.on('terminal-spawn', (event, geom) => {
  termGeom = toScreenGeom(geom);
  spawnTerminal();
});

ipcMain.on('terminal-geometry', (event, geom) => {
  termGeom = toScreenGeom(geom);
  if (termWid) applyWindowProps(termWid, termGeom.x, termGeom.y, termGeom.w, termGeom.h);
});

ipcMain.on('terminal-restart', () => {
  log('Terminal: manueller Neustart');
  spawnTerminal();
});

ipcMain.on('terminal-clear', () => {
  if (!termWid) return;
  // --window muss VOR der Tastenfolge stehen, sonst deutet xdotool "--window"
  // als Key und schlägt fehl. Ctrl+L an das xterm senden.
  exec(`xdotool key --window ${termWid} --clearmodifiers ctrl+l`,
    (e) => { if (e) log('terminal-clear: ' + e.message); });
});

ipcMain.on('dashboard-close', () => {
  log('Dashboard: Schließen über Terminal-Button');
  stopStorageMonitor();
  killExternalTerminal();
  app.quit();
});
