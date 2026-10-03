const { contextBridge, ipcRenderer } = require('electron');

// Hardware-Profil aus dem Main-Prozess (base64-JSON), bei Fehler null
let profile = null;
try {
  const arg = process.argv.find(a => a.startsWith('--sys-dashboard-profile='));
  if (arg) profile = JSON.parse(Buffer.from(arg.slice('--sys-dashboard-profile='.length), 'base64').toString('utf8'));
} catch {}

const hasBattery = profile
  ? !!profile.battery
  : process.argv.includes('--sys-dashboard-has-battery=1');

contextBridge.exposeInMainWorld('api', {
  hasBattery,
  profile,
  // System-Stats
  getSystemStats: ()  => ipcRenderer.invoke('get-system-stats'),
  getHostname: ()     => ipcRenderer.invoke('get-hostname'),
  getServices: ()     => ipcRenderer.invoke('get-services'),
  getNet:     ()      => ipcRenderer.invoke('get-net'),
  getLsblk:   ()      => ipcRenderer.invoke('get-lsblk'),
  getWeather: (city)  => ipcRenderer.invoke('get-weather', city),
  getRss:     (url)   => ipcRenderer.invoke('get-rss', url),
  saveNotes:  (txt)   => ipcRenderer.invoke('save-notes', txt),
  loadNotes:  ()      => ipcRenderer.invoke('load-notes'),
  getBattery: ()      => ipcRenderer.invoke('get-battery'),
  getLogs:    ()      => ipcRenderer.invoke('get-logs'),
  getDiskIo:  ()      => ipcRenderer.invoke('get-disk-io'),
  getTopProcs: ()     => ipcRenderer.invoke('get-top-procs'),
  onStorageChanged: (cb) => {
    const listener = () => cb();
    ipcRenderer.on('storage-changed', listener);
    return () => ipcRenderer.removeListener('storage-changed', listener);
  },
  onBatteryChanged: (cb) => {
    const listener = () => cb();
    ipcRenderer.on('battery-changed', listener);
    return () => ipcRenderer.removeListener('battery-changed', listener);
  },

  // Externes Terminal
  spawnTerminal:   (geom) => ipcRenderer.send('terminal-spawn', geom),
  updateTerminalGeometry: (geom) => ipcRenderer.send('terminal-geometry', geom),
  raiseTerminal:   ()     => ipcRenderer.send('terminal-raise'),
  termRestart:     ()     => ipcRenderer.send('terminal-restart'),
  termClear:       ()     => ipcRenderer.send('terminal-clear'),
  setTerminalVisible: (v) => ipcRenderer.send('terminal-visible', !!v),

  // App-Shortcuts (Key wird im Main-Prozess gegen eine Whitelist geprüft)
  launchApp:       (key)  => ipcRenderer.send('launch-app', key),

  // App-Suche (Ctrl+K): Liste holen, Start nur über id aus dieser Liste
  listApps:        ()     => ipcRenderer.invoke('list-apps'),
  launchDesktop:   (id)   => ipcRenderer.send('launch-desktop', id),
});
