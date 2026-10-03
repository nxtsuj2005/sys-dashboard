'use strict';
// Hardware/host probe so the dashboard can adapt to any Linux machine.
const fs = require('fs');
const os = require('os');
const path = require('path');

function safe(fn, fallback) { try { return fn(); } catch (_) { return fallback; } }
function ls(dir) { return safe(() => fs.readdirSync(dir), []); }
function readTrim(p) { return safe(() => fs.readFileSync(p, 'utf8').trim(), ''); }

function hasExec(name) {
  const dirs = (process.env.PATH || '').split(path.delimiter).filter(Boolean);
  return dirs.some((d) => safe(() => {
    const p = path.join(d, name);
    if (!fs.statSync(p).isFile()) return false;
    fs.accessSync(p, fs.constants.X_OK);
    return true;
  }, false));
}

function probe() {
  const cores = safe(() => os.cpus().length, 0) || 1;
  const ramMB = safe(() => Math.round(os.totalmem() / 1048576), 0);
  const battery = safe(() => ls('/sys/class/power_supply').some((e) =>
    /^BAT/i.test(e) || readTrim(`/sys/class/power_supply/${e}/type`) === 'Battery'), false);
  const thermal = safe(() => ls('/sys/class/thermal').some((e) => {
    if (!/^thermal_zone/.test(e)) return false;
    const v = readTrim(`/sys/class/thermal/${e}/temp`);
    return v !== '' && Number.isFinite(Number(v));
  }), false);
  const systemd = safe(() => fs.existsSync('/run/systemd/system'), false);
  const netIfaces = safe(() => ls('/sys/class/net').filter((n) =>
    !/^(lo|docker|veth|br-|virbr|tun|tap|wg|vnet|vmnet|kube|cni|flannel|cali)/.test(n)).length, 0);
  const disks = safe(() => ls('/sys/block').filter((n) =>
    /^(sd[a-z]+|hd[a-z]+|vd[a-z]+|nvme\d+n\d+|mmcblk\d+|xvd[a-z]+)$/.test(n)).length, 0);
  const session = process.env.XDG_SESSION_TYPE || 'unknown';
  const kde = /KDE/i.test(process.env.XDG_CURRENT_DESKTOP || '');
  const tools = {};
  for (const t of ['xterm', 'xdotool', 'gio', 'udevadm', 'curl', 'konsole']) tools[t] = safe(() => hasExec(t), false);
  const shell = ['/usr/bin/fish', '/bin/fish', process.env.SHELL, '/bin/bash', '/bin/sh']
    .find((p) => p && safe(() => fs.existsSync(p), false)) || '/bin/sh';
  const tier = (cores <= 2 || ramMB < 3500) ? 'low' : (cores <= 4 || ramMB < 7000) ? 'mid' : 'high';
  const glideFps = { low: 6, mid: 10, high: 14 }[tier];

  const warnings = [];
  if (!tools.xterm) warnings.push('xterm fehlt (eingebettetes Terminal nicht verfügbar)');
  if (!tools.xdotool) warnings.push('xdotool fehlt (Fenstersteuerung eingeschränkt)');
  if (netIfaces === 0) warnings.push('Keine Netzwerkschnittstelle gefunden');
  if (disks === 0) warnings.push('Keine Datenträger gefunden');
  if (!tools.curl) warnings.push('curl fehlt (Wetter/RSS nicht verfügbar)');
  if (!systemd) warnings.push('Kein systemd-Host (Service-Widget deaktiviert)');
  if (session !== 'wayland' && session !== 'x11') warnings.push(`Sitzungstyp "${session}" ist weder Wayland noch X11`);
  if (!kde) warnings.push('Kein KDE (Fenster bleibt im normalen Stacking, kein "immer im Hintergrund")');

  return { cores, ramMB, battery, thermal, systemd, netIfaces, disks, session, kde, tools, shell, tier, glideFps, warnings };
}

function writeProfile(dir) {
  const p = probe();
  fs.writeFileSync(path.join(dir, 'profile.json'), JSON.stringify(p, null, 2) + '\n');
  return p;
}

function report(p) {
  const m = (b) => (b ? '✓' : '✗');
  const row = (k, v) => `  ${k.padEnd(12)} ${v}`;
  const lines = ['Selfcheck – Systemprofil', ''];
  lines.push(row('CPU-Kerne', p.cores));
  lines.push(row('RAM', `${p.ramMB} MB`));
  lines.push(row('Leistung', `${p.tier} (Glide ${p.glideFps} fps)`));
  lines.push(row('Akku', m(p.battery)));
  lines.push(row('Thermik', m(p.thermal)));
  lines.push(row('systemd', m(p.systemd)));
  lines.push(row('Netzwerk', p.netIfaces));
  lines.push(row('Datenträger', p.disks));
  lines.push(row('Sitzung', p.session));
  lines.push(row('KDE', m(p.kde)));
  lines.push(row('Shell', p.shell));
  lines.push(row('Werkzeuge', Object.entries(p.tools).map(([k, v]) => `${m(v)} ${k}`).join('  ')));
  lines.push('');
  if (p.warnings.length) { lines.push('Warnungen:'); p.warnings.forEach((w) => lines.push(`  ! ${w}`)); }
  else lines.push('Keine Warnungen.');
  return lines.join('\n');
}

module.exports = { probe, writeProfile };

if (require.main === module) {
  const p = probe();
  console.log(process.argv.includes('--json') ? JSON.stringify(p, null, 2) : report(p));
}
