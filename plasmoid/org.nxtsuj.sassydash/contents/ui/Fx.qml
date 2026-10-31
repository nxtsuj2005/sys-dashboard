import QtQuick

// Effects controller (Electron runBoot / revealDashboard / idleGlitch / crashDashboard).
// Sequences are generator functions that `yield` milliseconds to sleep; one timer
// wakes whichever is due next. Everything moves in hard steps (CSS steps(1)), so a
// running effect costs a handful of repaints, and nothing runs between effects.
Item {
    id: fx

    property Item app                  // whole-dashboard container (tears as one)
    property FxState appFx
    property BootScreen boot
    property Rectangle black           // crash backdrop
    property Item topBar
    property Item terminal
    property var groups: []            // shuffle groups of cards, never the terminal

    property bool reduced: false       // reducedMotion: no boot, no glitches, no crash
    property string debug: ""          // "glitch": idle glitch every ~25 s, "crash": crash 20 s after boot
    property bool busy: false          // boot / reveal / crash running
    property bool glitching: false

    readonly property var cards: [].concat(...groups)
    readonly property var everything: [topBar].concat(cards, [terminal]).filter(x => x)

    // ── scheduler ───────────────────────────────────────────────
    property var tasks: []
    property bool pumping: false
    Timer { id: clock; onTriggered: fx.pump() }

    function spawn(gen) { tasks.push({ gen, at: Date.now() }); if (!pumping) pump(); }
    function pump() {
        pumping = true;
        try {
            for (let guard = 0; guard < 500; guard++) {
                const now = Date.now();
                const t = tasks.find(x => x.at <= now);
                if (!t) break;
                let r;
                try { r = t.gen.next(); } catch (e) { console.warn("sassydash fx:", e); r = { done: true }; }
                if (r.done) tasks.splice(tasks.indexOf(t), 1);
                else t.at = now + Math.max(0, Number(r.value) || 0);
            }
        } finally { pumping = false; }
        if (!tasks.length) { clock.stop(); return; }
        clock.interval = Math.max(1, Math.min(...tasks.map(x => x.at)) - Date.now());
        clock.restart();
    }

    function rnd(a, b) { return a + Math.random() * (b - a); }
    function shuffled(arr) { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
    function pick(arr, n) { return shuffled(arr).slice(0, n); }

    // ── keyframes (Electron @keyframes, steps(1, end)) ──────────
    // [percent, { tx, skew, cutTop, cutBottom, alpha }]
    readonly property var kBootHiccup: [
        [0, {}], [8, { tx: -16, cutBottom: .55, alpha: .85 }], [16, { tx: 12, cutTop: .42, cutBottom: .28 }],
        [24, { tx: -4, alpha: .4 }], [32, { tx: 20, skew: -4, cutBottom: .74 }], [42, { cutTop: .66, alpha: .9 }],
        [52, { tx: -9, alpha: .5 }], [62, { tx: 6, skew: 3, cutTop: .18, cutBottom: .52 }], [78, { tx: -3 }], [100, {}]]
    readonly property var kBootFreeze: [[0, {}], [30, { tx: 5, alpha: .7 }], [60, { tx: -3, alpha: .9 }], [100, {}]]
    readonly property var kDashHiccup: [
        [0, { tx: -18, cutBottom: .6, alpha: .6 }], [14, { tx: 14, cutTop: .35, cutBottom: .2 }], [28, { alpha: .5 }],
        [42, { tx: -10, skew: 2, cutBottom: .8 }], [58, { tx: 8, cutTop: .55, alpha: .8 }], [74, { tx: -3 }], [100, {}]]
    readonly property var kDashHiccupS: [
        [0, { tx: 8, cutTop: .2, cutBottom: .4 }], [35, { tx: -6, alpha: .7 }], [70, { tx: 2, cutBottom: .7 }], [100, {}]]
    readonly property var kCard: [
        [0, { tx: -9, cutBottom: .55, alpha: .7 }], [30, { tx: 7, cutTop: .4, cutBottom: .1 }], [55, { alpha: .6 }],
        [80, { tx: -3, skew: 1.5, cutBottom: .7 }], [100, {}]]
    readonly property var kCrash: [
        [0, { tx: -26, skew: 3, cutBottom: .65, alpha: .6 }], [10, { tx: 30, cutTop: .3, cutBottom: .1 }],
        [20, { tx: -12, alpha: .4 }], [32, { tx: 18, skew: -4, cutTop: .6 }], [44, { tx: -34, cutBottom: .8, alpha: .7 }],
        [56, { tx: 6, cutTop: .15, cutBottom: .4 }], [68, { tx: -20, skew: 2, alpha: .5 }],
        [80, { tx: 24, cutTop: .45, cutBottom: .2 }], [90, { tx: -8, alpha: .8 }], [100, {}]]

    function* keys(state, frames, ms, delay) {
        if (delay > 0) yield delay;
        try {
            for (let i = 0; i < frames.length; i++) {
                state.frame(frames[i][1]);
                if (i + 1 < frames.length) yield (frames[i + 1][0] - frames[i][0]) / 100 * ms;
            }
        } finally { state.frame({}); }
    }
    function stutter(items, tMin, tMax, dMax) {
        for (const c of items) fx.spawn(fx.keys(c.fx, fx.kCard, fx.rnd(tMin, tMax) * 1000, fx.rnd(0, dMax) * 1000));
    }

    // Slot geometry: centre of every card in dashboard coordinates, read at effect start.
    function centres(items) {
        return items.map(c => { const p = c.mapToItem(fx.app, c.width / 2, c.height / 2); return { x: p.x, y: p.y }; });
    }
    // Put item i at the slot of item slot[i] (translate only — the layout never changes).
    function place(items, home, slot) {
        items.forEach((c, i) => { c.fx.dx = Math.round(home[slot[i]].x - home[i].x); c.fx.dy = Math.round(home[slot[i]].y - home[i].y); });
    }
    function resetAll() {
        for (const c of everything) c.fx.reset();
        appFx.reset();
        app.z = 0;
        black.visible = false;
        Theme.backdrop = Theme.bg;
    }

    // ── boot + reveal ───────────────────────────────────────────
    function startBoot(rebooted) {
        if (reduced) { resetAll(); busy = false; return; }
        busy = true;
        spawn(bootSeq(rebooted));
        if (rebooted) spawn(survivorsSeq());
    }
    function* bootSeq(rebooted) {
        try {
            for (const c of everything) c.fx.hidden = true;     // dash-pre
            boot.reset();
            boot.probe.run();
            boot.visible = true;
            yield 40;
            boot.logoOn = true;
            yield 240;
            spawn(keys(boot.fx, kBootHiccup, 340));
            yield 340;
            boot.tagOn = true;
            yield 170;
            for (let w = 0; !boot.facts && w < 350; w += 50) yield 50;
            const f = boot.facts || {};
            const up = f.uptime || 0, d = Math.floor(up / 86400), h = Math.floor(up % 86400 / 3600), m = Math.floor(up % 3600 / 60);
            const gb = Math.round(Stats.ramTotal / 1073741824);
            boot.lines = [
                ["host", (Stats.host || "local system").toUpperCase()],
                ["kernel", f.kernel || "linux"],
                ["processor", Stats.cores > 1 ? Stats.cores + " cores" : "online"],
                ["memory", gb ? gb + " GB" : "online"],
                ["uptime", up ? (d ? d + "d " + h + "h" : h ? h + "h " + m + "m" : m + "m") : "—"],
                ["selfcheck", "plasma · " + (f.battery ? "battery" : "ac")]
            ];
            for (let i = 0; i < boot.lines.length; i++) {
                boot.shown = i + 1;
                yield 70;
                if (i === 3) { spawn(keys(boot.fx, kBootFreeze, 220)); yield 220; }   // the screen stalls for a beat
            }
            yield 110;
            boot.barOn = true;
            yield 20;
            boot.barFill = 1;
            yield 560;
            boot.readyOn = true;
            yield 340;
            for (let s = 0; s <= 3; s++) { boot.burstStep = s; yield 55; }
            yield 70;
            boot.visible = false;
            yield* revealSeq();
        } finally {
            boot.visible = false;
            resetAll();
            busy = false;
            if (debug === "crash") crashAt = Date.now() + 20000;
        }
    }
    // Cards pop in staggered, get shuffled inside their row, then snap back.
    function* revealSeq() {
        spawn(keys(appFx, kDashHiccup, 380));
        for (const c of everything) spawn((function* (it) { yield fx.rnd(0, 240); it.fx.hidden = false; })(c));
        yield 240;
        const placed = [];
        for (const g of groups) {
            const home = centres(g);
            const perm = shuffled(g.map((_, i) => i));
            place(g, home, perm);
            placed.push(g);
        }
        yield 480;
        spawn(keys(appFx, kDashHiccupS, 200));
        for (const g of placed) for (const c of g) { c.fx.dx = 0; c.fx.dy = 0; }
        yield 220;
    }
    // After a crash, 1–2 tiles flicker in on top of the boot screen, glitch around, vanish.
    function* survivorsSeq() {
        const picks = pick(cards.concat([topBar]), 1 + Math.floor(Math.random() * 2));
        try {
            yield rnd(500, 800);
            if (!boot.visible) return;
            app.z = 20;                                         // above the boot screen
            for (let k = 0; k < 2; k++) {
                for (const c of picks) {
                    c.fx.hidden = false;
                    c.fx.dx = Math.round(rnd(-160, 160)); c.fx.dy = Math.round(rnd(-60, 60));
                }
                stutter(picks, .2, .4, 0);
                yield rnd(160, 320);
                for (const c of picks) { c.fx.hidden = true; c.fx.dx = 0; c.fx.dy = 0; }
                yield rnd(120, 300);
            }
        } finally {
            if (boot.visible) for (const c of picks) c.fx.hidden = true;
            app.z = 0;
        }
    }

    // ── idle glitch: every 1–15 min one card / a few / a row / everything ──
    Timer {
        id: idleTimer
        running: !fx.reduced
        interval: fx.debug === "glitch" ? 25000 : 60000 + Math.floor(Math.random() * 14 * 60000)
        onTriggered: {
            interval = fx.debug === "glitch" ? 25000 : 60000 + Math.floor(Math.random() * 14 * 60000);
            restart();
            fx.glitch();
        }
    }
    function glitch() {
        if (busy || glitching || reduced) return;
        glitching = true;
        spawn(glitchSeq());
    }
    function* glitchSeq() {
        const gs = groups.filter(g => g.length > 1);
        const all = [].concat(...gs);
        const hit = new Set();
        try {
            if (!all.length) return;
            const mode = pick(["one", "one", "few", "few", "group", "all", "stutter"], 1)[0];
            const targets = mode === "one" ? pick(all, 1)
                : mode === "few" ? pick(all, Math.floor(rnd(2, 5)))
                : mode === "group" ? pick(gs, 1)[0]
                : mode === "stutter" ? pick(all, Math.floor(rnd(1, 4)))
                : all;
            targets.forEach(c => hit.add(c));
            stutter(targets, .2, .4, .15);
            if (mode !== "stutter") {
                for (const g of gs) {
                    let sub = mode === "all" ? g : targets.filter(c => g.includes(c));
                    if (!sub.length) continue;
                    // permute only the chosen cards among their own slots; a lone card swaps with a neighbour
                    if (sub.length === 1) sub = [sub[0], pick(g.filter(x => x !== sub[0]), 1)[0]];
                    const home = centres(sub);
                    let perm;
                    do { perm = shuffled(sub.map((_, i) => i)); } while (perm.every((v, i) => v === i));
                    place(sub, home, perm);
                    sub.forEach(c => hit.add(c));
                }
            }
            yield rnd(300, 900);
            if (Math.random() < 0.7) stutter([...hit], .2, .4, .15);     // "oh, passt doch"
            for (const c of hit) { c.fx.dx = 0; c.fx.dy = 0; }
            yield 500;
        } finally {
            for (const c of all) { c.fx.dx = 0; c.fx.dy = 0; }
            glitching = false;
        }
    }

    // ── crash: once per session, 60 % chance, 1–5 h in; the shell survives ──
    property double crashAt: 0
    Component.onCompleted: {
        if (!reduced && Math.random() < 0.6) crashAt = Date.now() + rnd(1, 5) * 3600e3;
    }
    Timer {   // wall-clock deadline, so laptop suspend can't stretch it
        running: !fx.reduced && fx.crashAt > 0
        interval: fx.debug === "crash" ? 2000 : 30000
        repeat: true
        onTriggered: if (Date.now() >= fx.crashAt && !fx.busy && !fx.glitching) { fx.crashAt = 0; fx.crash(); }
    }
    function crash() {
        if (busy) return;
        busy = true;
        spawn(crashSeq());
    }
    function* termGlitch(steps, endVisible) {
        for (const [on, ms] of steps) {
            terminal.fx.hidden = !on;
            terminal.fx.dx = on ? Math.round(rnd(-90, 90)) : 0;
            terminal.fx.dy = on ? Math.round(rnd(-20, 20)) : 0;
            if (ms) yield ms;
        }
        terminal.fx.dx = 0; terminal.fx.dy = 0;
        terminal.fx.hidden = !endVisible;
        if (!endVisible) {   // frame goes down with its window: one last stutter, then gone
            terminal.fx.hidden = false;
            yield* keys(terminal.fx, kCard, 260);
            terminal.fx.hidden = true;
        }
    }
    function* crashSeq() {
        let rebooting = false;
        try {
            const tiles = [topBar].concat(cards);
            const home = centres(tiles);
            const slot = tiles.map((_, i) => i);
            const alive = new Set(tiles.keys());
            const swapStep = (maxPairs) => {
                const pool = [...alive];
                const n = Math.min(maxPairs, Math.floor(pool.length / 2));
                const hit = [];
                for (let k = 0; k < n; k++) {
                    const a = pool.splice(Math.floor(Math.random() * pool.length), 1)[0];
                    const b = pool.splice(Math.floor(Math.random() * pool.length), 1)[0];
                    [slot[a], slot[b]] = [slot[b], slot[a]];
                    hit.push(tiles[a], tiles[b]);
                }
                place(tiles, home, slot);
                stutter(hit, .15, .3, 0);
            };
            const kill = (i) => { alive.delete(i); tiles[i].fx.hidden = true; };

            // wave 1: tear, partial recovery, tear again — it does not go down without a fight
            spawn(keys(appFx, kCrash, 750));
            spawn(termGlitch([[false, 150], [true, 90], [false, 210], [true, 70], [false, 130], [true, 160], [false, 120], [true, 100]], true));
            for (let t = 0; t < 5; t++) { yield 150; swapStep(1); }
            yield 100;
            slot.forEach((_, i) => { slot[i] = i; });
            place(tiles, home, slot);
            yield rnd(350, 700);                     // looks almost fine for a beat
            spawn(keys(appFx, kCrash, 750));
            spawn(termGlitch([[false, 110], [true, 130], [false, 90], [true, 80], [false, 180], [true, 110], [false, 100], [true, 150], [false, 0]], false));
            // wave 2: tiles swap faster and wilder, then drop out one by one
            for (let t = 0; t < 14; t++) { yield rnd(70, 170); swapStep(1 + Math.floor(t / 4)); }
            app.z = 20;                              // above the black layer, so survivors show on it
            const order = shuffled([...alive]);
            const survivors = order.slice(0, Math.max(3, Math.round(tiles.length * 0.3)));
            for (const i of order.filter(i => !survivors.includes(i))) { kill(i); swapStep(2); yield rnd(40, 110); }
            for (let t = 0; t < 3; t++) { swapStep(1); yield rnd(90, 170); }   // survivors try to hold their tiles
            for (const i of survivors) { kill(i); yield rnd(40, 90); }
            black.visible = true;
            Theme.backdrop = black.color;
            yield rnd(250, 450);
            // "boot screen": a few survivors respawn on black, still sliding between slots, then vanish
            const ghosts = pick(survivors, 3 + Math.floor(Math.random() * 2));
            ghosts.forEach(i => { alive.add(i); tiles[i].fx.hidden = false; });
            for (let t = 0; t < 3; t++) { swapStep(2); yield rnd(80, 140); }
            ghosts.forEach(kill);
            yield rnd(150, 300);
            yield rnd(250, 500);
            rebooting = true;
        } finally {
            resetAll();
            busy = false;
            // "reload": boot plays again; the terminal card was only hidden, its shell kept running
            if (rebooting) startBoot(true);
        }
    }
}
