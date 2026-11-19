const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const src = fs.readFileSync(path.join(__dirname, '../src/main.js'), 'utf8');
const block = (name) => {
  const a = src.indexOf(`// >>> ${name}`), b = src.indexOf(`// <<< ${name}`);
  assert.ok(a >= 0 && b > a, `marker ${name} missing`);
  return src.slice(a, b);
};
const ctx = {
  os: { cpus: () => [] },
  path,
  stripFieldCodes: (e) => e.replace(/%[fFuUdDnNickvm]/g, '').replace(/\s+/g, ' ').trim(),
  parseDesktopEntry: null,
};
// parseDesktopEntry / stripFieldCodes live outside the marked blocks; extract them too.
const fnSrc = (name) => {
  const a = src.indexOf(`function ${name}(`);
  let i = src.indexOf('{', a), d = 0;
  for (; i < src.length; i++) { if (src[i] === '{') d++; if (src[i] === '}' && --d === 0) break; }
  return src.slice(a, i + 1);
};
vm.createContext(ctx);
vm.runInContext([fnSrc('stripFieldCodes'), fnSrc('parseDesktopEntry'),
  block('geom-validate'), block('cpu-delta'), block('desktop-scan'),
  'this.sanitizeGeom = sanitizeGeom; this.cpuDelta = cpuDelta; this.pickDesktopEntry = pickDesktopEntry;'].join('\n'), ctx);

test('sanitizeGeom rejects null and non-finite input', () => {
  for (const bad of [null, undefined, 5, 'x', {}, { x: 0, y: 0, w: NaN, h: 1 },
    { x: Infinity, y: 0, w: 1, h: 1 }, { x: '1', y: 0, w: 1, h: 1 }]) {
    assert.equal(ctx.sanitizeGeom(bad), null);
  }
});

test('sanitizeGeom rounds and clamps', () => {
  assert.deepEqual({ ...ctx.sanitizeGeom({ x: 1.6, y: -5e9, w: 0, h: 9e9 }) },
    { x: 2, y: -100000, w: 1, h: 100000 });
});

test('cpuDelta computes per-core load', () => {
  const s = [{ idle: 0, total: 0 }, { idle: 0, total: 0 }];
  const e = [{ idle: 50, total: 100 }, { idle: 100, total: 100 }];
  assert.deepEqual([...ctx.cpuDelta(s, e)], [50, 0]);
});

test('cpuDelta discards samples when core count changes', () => {
  assert.equal(ctx.cpuDelta([{ idle: 0, total: 0 }], [{ idle: 1, total: 2 }, { idle: 1, total: 2 }]), null);
});

test('cpuDelta tolerates zero time delta', () => {
  assert.deepEqual([...ctx.cpuDelta([{ idle: 1, total: 1 }], [{ idle: 1, total: 1 }])], [0]);
});

test('hidden user entry reserves id against system entry', () => {
  const seen = new Set();
  const user = '[Desktop Entry]\nName=Foo\nExec=foo\nHidden=true\n';
  const sys = '[Desktop Entry]\nName=Foo\nExec=foo\n';
  assert.equal(ctx.pickDesktopEntry(seen, 'foo', user, '/u/foo.desktop'), null);
  assert.equal(ctx.pickDesktopEntry(seen, 'foo', sys, '/s/foo.desktop'), null);
});

test('visible user entry wins over system entry', () => {
  const seen = new Set();
  const e = ctx.pickDesktopEntry(seen, 'foo', '[Desktop Entry]\nName=U\nExec=u %U\n', '/u/foo.desktop');
  assert.equal(e.name, 'U');
  assert.equal(e.exec, 'u');
  assert.equal(ctx.pickDesktopEntry(seen, 'foo', '[Desktop Entry]\nName=S\nExec=s\n', '/s/foo.desktop'), null);
});

test('user desktop dirs are scanned before system dirs', () => {
  const a = src.indexOf('const DESKTOP_DIRS');
  const list = src.slice(a, src.indexOf('];', a));
  assert.ok(list.indexOf('.local/share/applications') < list.indexOf("'/usr/share/applications'"));
});
