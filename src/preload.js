const { contextBridge, ipcRenderer } = require('electron');

const hasBattery = process.argv.includes('--sys-dashboard-has-battery=1');

contextBridge.exposeInMainWorld('api', {
  hasBattery,
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
  onStorageChanged: (cb) => {
    const listener = () => cb();
    ipcRenderer.on('storage-changed', listener);
    return () => ipcRenderer.removeListener('storage-changed', listener);
  },

  // Externes Terminal
  spawnTerminal:   (geom) => ipcRenderer.send('terminal-spawn', geom),
  updateTerminalGeometry: (geom) => ipcRenderer.send('terminal-geometry', geom),
  termRestart:     ()     => ipcRenderer.send('terminal-restart'),
  termClear:       ()     => ipcRenderer.send('terminal-clear'),
  closeDashboard:  ()     => ipcRenderer.send('dashboard-close'),
});
