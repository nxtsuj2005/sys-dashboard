const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const UI = path.join(__dirname, '../plasmoid/org.nxtsuj.sassydash/contents/ui');
const qml = (file) => fs.readFileSync(path.join(UI, file), 'utf8');

// QML `command: "…" + "…"` property → its JS string expression, evaluated.
function commandExpr(src, id, scope = {}) {
  const at = id ? src.indexOf(`id: ${id}`) : 0;
  const start = src.indexOf('command:', at) + 'command:'.length;
  const end = src.indexOf('\n        on', start);
  return new Function(...Object.keys(scope), `return (${src.slice(start, end)});`)(...Object.values(scope));
}

// A QML function body with its type annotations stripped, as plain JS.
function qmlFunction(src, name) {
  const a = src.indexOf(`function ${name}(`);
  let i = src.indexOf('{', a), depth = 0;
  for (; i < src.length; i++) { if (src[i] === '{') depth++; if (src[i] === '}' && --depth === 0) break; }
  return src.slice(a, i + 1)
    .replace(/^(function \w+\()([^)]*)\)\s*(:\s*\w+)?/, (m, head, args) =>
      head + args.replace(/\s*:\s*\w+/g, '') + ')');
}

// Mirrors Command.qml's `source` wrapper.
const wrapSrc = qml('Command.qml');
const wrapExpr = wrapSrc.slice(wrapSrc.indexOf('readonly property string source:') + 'readonly property string source:'.length,
                               wrapSrc.indexOf('\n\n', wrapSrc.indexOf('readonly property string source:')));
const wrap = (command, timeout = 30) => new Function('command', 'timeout', `return (${wrapExpr});`)(command, timeout);
const sh = (cmd, env = process.env) => spawnSync('sh', ['-c', cmd], { encoding: 'utf8', env });

test('Command wrapper keeps nested quotes intact', () => {
  const r = sh(wrap(`sh -c 'printf "%s|" "a b" '"'"'c'"'"''`));
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout, "a b|c|");
});

test('Command wrapper kills a hung process with exit 124', () => {
  const r = sh(wrap('sleep 5', 1));
  assert.equal(r.status, 124);
});

test('EventsCard poll command runs through the wrapper', () => {
  const r = sh(wrap(commandExpr(qml('EventsCard.qml'))));
  assert.match(r.stdout, /^@sassydash-user\n[\s\S]*@sassydash-user-exit:\d+\n@sassydash-system\n[\s\S]*@sassydash-system-exit:\d+\n$/);
});

test('ProcsCard top command yields pid/cpu/res/name rows', { skip: !fs.existsSync('/usr/bin/top') }, () => {
  const r = sh(wrap(commandExpr(qml('ProcsCard.qml'), null, { card: { rows: 3 } })));
  assert.equal(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n');
  assert.ok(rows.length >= 1 && rows.length <= 3);
  for (const row of rows) assert.match(row, /^\d+\t[\d.]+\t\S+\t\S+/);
});

test('AppSearch scan: a Hidden user override hides the system entry', () => {
  const sys = fs.readdirSync('/usr/share/applications').find(f => f.endsWith('.desktop'));
  assert.ok(sys, 'needs at least one system .desktop file');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'sassydash-'));
  const apps = path.join(home, '.local/share/applications');
  fs.mkdirSync(apps, { recursive: true });
  const id = sys.replace(/\.desktop$/, '');
  const run = () => sh(wrap(commandExpr(qml('AppSearch.qml'), 'scan')), { ...process.env, HOME: home })
    .stdout.split('\n').filter(Boolean).map(l => l.split('\t')[0]);
  try {
    const before = run();
    fs.writeFileSync(path.join(apps, sys), '[Desktop Entry]\nType=Application\nName=X\nExec=true\nHidden=true\n');
    const after = run();
    if (before.includes(id)) assert.ok(!after.includes(id), `${id} still listed`);
    assert.equal(new Set(after).size, after.length, 'duplicate ids');
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('ShortcutsCard falls through a candidate that fails fast', () => {
  const src = qml('ShortcutsCard.qml');
  const bin = fs.mkdtempSync(path.join(os.tmpdir(), 'sassydash-bin-'));
  const stub = (name, body) => fs.writeFileSync(path.join(bin, name), `#!/bin/sh\n${body}\n`, { mode: 0o755 });
  stub('alpha', 'exit 3');
  stub('beta', `echo started > "${bin}/beta.ran"; sleep 3`);
  const launchCommand = new Function('candidates', `${qmlFunction(src, 'launchCommand')}; return launchCommand;`)(
    { demo: [['alpha'], ['beta']], none: [['alpha']] });
  const env = { ...process.env, PATH: `${bin}:/usr/bin:/bin` };
  try {
    let r = sh(wrap(launchCommand('demo')), env);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.ok(fs.existsSync(path.join(bin, 'beta.ran')));
    r = sh(wrap(launchCommand('none')), env);
    assert.equal(r.status, 127);
  } finally {
    fs.rmSync(bin, { recursive: true, force: true });
  }
});

test('WeatherCard rejects shell metacharacters and encodes the place', () => {
  const src = qml('WeatherCard.qml');
  const requestCommand = new Function(`${qmlFunction(src, 'requestCommand')}; return requestCommand;`)();
  for (const bad of ["x'; rm -rf ~", 'a$(id)', 'a`id`', 'a\nb', 'x'.repeat(65), '...']) {
    assert.throws(() => requestCommand(bad), undefined, bad);
  }
  assert.match(requestCommand("L'Aquila"), /wttr\.in\/L%27Aquila\?format=j1'$/);
  assert.match(requestCommand(''), /wttr\.in\/\?format=j1'$/);
});

test('WeatherCard parses a minimal j1 response', () => {
  const src = qml('WeatherCard.qml');
  const parse = new Function(['weatherIcon', 'firstValue', 'metric', 'parseWeather']
    .map(n => qmlFunction(src, n)).join('\n') + '; return parseWeather;')();
  const w = parse(JSON.stringify({
    current_condition: [{ temp_C: '7', FeelsLikeC: '4', humidity: '81', windspeedKmph: '12',
                          visibility: '10', weatherCode: '116', lang_de: [{ value: 'Teilweise bewölkt' }] }],
    nearest_area: [{ areaName: [{ value: 'Kassel' }] }],
  }));
  assert.equal(w.city, 'Kassel');
  assert.equal(w.temperature, '7°');
  assert.equal(w.icon, 'partly');
  assert.throws(() => parse('{}'));
});
