import QtQuick
import QtCore

// Rotating Proxmox guest tree: host in the middle, guests on two tilted orbits,
// blue = running, red = stopped, VMIDs only. The greeter has no network, so it reads
// a status file a user service keeps fresh; missing or stale (laptop away) → grey.
Canvas {
    id: tree
    property string font: "monospace"
    property bool animate: true
    property real rot: 0
    property var guests: []           // [{ id, up }]
    property bool live: false

    readonly property url statusFile: StandardPaths.writableLocation(StandardPaths.GenericCacheLocation) + "/sassydash/pve.json"
    readonly property int staleAfter: 120   // seconds

    function tick() {
        if (animate) rot += 0.0035;
        requestPaint();
    }

    function load() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            try {
                const d = JSON.parse(xhr.responseText);
                const fresh = Date.now() / 1000 - Number(d.ts) < staleAfter;
                guests = (d.guests || []).slice(0, 24).map(g => ({ id: Number(g.id), up: !!g.up }));
                live = fresh && guests.length > 0;
            } catch (e) {
                if (live) console.warn("sassydash-lock: guest status unreadable:", e);
                live = false;
            }
        };
        xhr.open("GET", statusFile);
        xhr.send();
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: tree.load() }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.02 }
        font { family: tree.font; pixelSize: Math.max(9, Math.min(13, tree.height * 0.022)) }
        textFormat: Text.StyledText
        color: "#91a0b1"
        text: tree.live
            ? "<font color='#4f9cf9'>●</font> " + tree.guests.filter(g => g.up).length + " live    "
              + "<font color='#f85149'>●</font> " + tree.guests.filter(g => !g.up).length + " offline"
            : "<font color='#5b6573'>●</font> Proxmox nicht erreichbar"
    }

    onPaint: {
        const ctx = getContext("2d");
        const W = width, H = height;
        ctx.reset();
        const cx = W / 2, cy = H / 2, R = [W * 0.25, W * 0.42], tilt = [0.62, -0.5], off = W * 0.07;
        const list = live ? guests : Array.from({ length: 12 }, (_, i) => ({ id: 0, up: true }));
        const n = list.length;
        const pts = list.map((g, i) => {
            const ring = i % 2, a = (i / n) * Math.PI * 2 + ring * 0.4 + rot * (ring ? -0.7 : 1);
            const r = R[ring], z = Math.sin(a) * r;
            return { g, x: cx + Math.cos(a) * r, y: cy + z * tilt[ring] + (ring ? off : -off), depth: (z / r + 1) / 2 };
        });
        const col = (up, al) => !live ? `rgba(91,101,115,${al})` : up ? `rgba(79,156,249,${al})` : `rgba(248,81,73,${al})`;

        ctx.lineWidth = 1;
        ctx.strokeStyle = "rgba(145,160,177,0.08)";
        for (let i = 0; i < 2; i++) {
            ctx.beginPath();
            ctx.ellipse(cx - R[i], cy + (i ? off : -off) - Math.abs(R[i] * tilt[i]), R[i] * 2, Math.abs(R[i] * tilt[i]) * 2);
            ctx.stroke();
        }
        pts.sort((p, q) => p.depth - q.depth);
        for (const p of pts) {
            ctx.strokeStyle = col(p.g.up, 0.08 + p.depth * 0.22);
            ctx.setLineDash(p.g.up ? [] : [3, 4]);
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(p.x, p.y); ctx.stroke();
        }
        ctx.setLineDash([]);

        ctx.fillStyle = "#161b22";
        ctx.strokeStyle = live ? "#4f9cf9" : "#5b6573";
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(cx, cy, W * 0.045, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
        ctx.fillStyle = "#9aa7b4";
        ctx.font = Math.round(Math.max(9, W * 0.032)) + "px '" + tree.font + "'";
        ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.fillText("pve", cx, cy);

        const pulse = (Math.sin(Date.now() / 260) + 1) / 2;
        for (const p of pts) {
            const s = W * (0.014 + p.depth * 0.016) * (live && !p.g.up ? 1 + pulse * 0.25 : 1);
            ctx.fillStyle = col(p.g.up, 0.35 + p.depth * 0.65);
            ctx.beginPath(); ctx.arc(p.x, p.y, s, 0, Math.PI * 2); ctx.fill();
            if (live && p.depth > 0.45) {
                ctx.fillStyle = `rgba(145,160,177,${(p.depth - 0.45) * 1.4})`;
                ctx.font = Math.round(Math.max(8, W * 0.026)) + "px '" + tree.font + "'";
                ctx.fillText(String(p.g.id), p.x, p.y + s + W * 0.03);
            }
        }
    }
}
