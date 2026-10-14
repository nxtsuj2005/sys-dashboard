const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '../src/index.html'), 'utf8');
const source = html.slice(html.indexOf('  const GLIDE_MIN_DT'), html.indexOf('  function redrawCanvases'));

function harness(fps = 14) {
  let now = 0, id = 0, frames = 0, paints = 0;
  const tasks = new Map(), events = {};
  const add = (fn, at, frame = false) => {
    tasks.set(++id, { fn, at, frame });
    return id;
  };
  const context = {
    GLIDE_FPS: fps, performance: { now: () => now },
    document: { hidden: false, addEventListener: (name, fn) => { events[name] = fn; } },
    setTimeout: (fn, delay) => add(fn, now + Math.max(1, delay)),
    clearTimeout: key => tasks.delete(key),
    requestAnimationFrame: fn => add(fn, (Math.floor(now / (1000 / 60) + 1e-8) + 1) * (1000 / 60), true),
    cancelAnimationFrame: key => tasks.delete(key),
    scrollFrac: () => 0.5, sysSampleTs: 0, netSampleTs: 0, storeSampleTs: 0,
    SYS_MS: 2500, NET_MS: 2000, STORE_MS: 2500,
    drawSysGraph: () => { paints++; }, drawNetBottom() {}, drawKpiCpu() {},
    drawKpiRam() {}, drawKpiNet() {}, drawKpiStore() {}, lerpCores() {},
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  return {
    context, tasks,
    get frames() { return frames; }, get paints() { return paints; },
    kick: () => context.kickGlide(), stop: () => context.stopGlide(),
    hide(hidden) { context.document.hidden = hidden; events.visibilitychange(); },
    advance(ms) {
      const end = now + ms;
      while (tasks.size) {
        const [key, task] = [...tasks].sort((a, b) => a[1].at - b[1].at)[0];
        if (task.at > end) break;
        tasks.delete(key); now = task.at;
        if (task.frame) { frames++; task.fn(now); } else task.fn();
      }
      now = end;
    },
  };
}

test('preserves graph cadence without a display-rate callback loop', () => {
  const h = harness(); h.kick(); h.advance(10000);
  assert.ok(h.paints >= 110 && h.paints <= 140, `${h.paints} paints`);
  assert.ok(h.frames <= h.paints + 2, `${h.frames} frames for ${h.paints} paints`);
  assert.ok(h.tasks.size <= 1);
});

test('repeated sample kicks cannot create duplicate animation loops', () => {
  const h = harness();
  for (let i = 0; i < 50; i++) { h.kick(); h.advance(20); }
  assert.ok(h.tasks.size <= 1);
  assert.ok(h.frames < 16);
});

test('hiding cancels the timer; showing starts exactly one loop', () => {
  const h = harness(); h.kick(); h.advance(20); h.hide(true);
  const paints = h.paints;
  assert.equal(h.tasks.size, 0); h.advance(5000); assert.equal(h.paints, paints);
  h.kick(); assert.equal(h.tasks.size, 0);
  h.hide(false); h.advance(100); assert.ok(h.paints > paints); assert.equal(h.tasks.size, 1);
});

test('hiding and teardown also cancel a queued animation frame', () => {
  const h = harness(); h.kick(); h.hide(true); assert.equal(h.tasks.size, 0);
  h.hide(false); h.stop(); assert.equal(h.tasks.size, 0);
  h.advance(1000); assert.equal(h.paints, 0);
});

test('zero-FPS mode paints samples without scheduling background work', () => {
  const h = harness(0); h.kick(); h.advance(10000);
  assert.equal(h.paints, 1); assert.equal(h.frames, 0); assert.equal(h.tasks.size, 0);
  h.kick(); assert.equal(h.paints, 2);
});

test('low hardware tier retains its configured repaint limit', () => {
  const h = harness(6); h.kick(); h.advance(10000);
  assert.ok(h.paints >= 50 && h.paints <= 61);
  assert.ok(h.frames <= h.paints + 2);
});

test('all inline scripts remain valid JavaScript', () => {
  for (const [, script] of html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)) new vm.Script(script);
});
