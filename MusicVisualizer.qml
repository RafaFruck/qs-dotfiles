import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "config.js" as Config

// Music visualizer wallpaper: a bundle of jagged lines (the "ribbon") that
// reacts to the music.
//
//   qs ipc call musicvisualizer toggle     (also: on / off)
//
// Needs cava.conf next to shell.qml.

Scope {
  id: root

  // ---------- state shared by every monitor ----------
  property bool active: false
  property var bars: []          // 0 to 1 per frequency band, low -> high
  property real level: 0         // average of all bands (overall loudness)

  // ---------- look and feel: tweak here ----------
  property int lineCount: 6             // how many lines in the ribbon
  property real fade: 0.50              // higher = shorter trails
  property real intensity: 2.5
  // higher that 1 = bigger lines; lower than 1 = smaller lines

  property color colBg: Config.colors.bg
  property color colBgDark: Config.colors.bgDark
  property color colFg: Config.colors.fg
  property color colMuted: Config.colors.muted
  property color colRed: Config.colors.red
  property color colGreen: Config.colors.green
  property color colSkyBlue: Config.colors.skyBlue
  property color colOrange: Config.colors.orange
  property color colTurquoise: Config.colors.turquoise
  property color colBlue: Config.colors.blue
  property color colYellow: Config.colors.yellow
  property color colCrystalGreen: Config.colors.crystalGreen
  property color colPurple: Config.colors.purple
  property color colCyan: Config.colors.cyan
  property color colWhite: Config.colors.white

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

  // x goes 0 -> 1 over  seconds and the result should go 0 -> 1 too.
  // Linear for now: comment it out and uncomment another one (or write your own) to tinker.
  function ease(x) {
    return x;                                                          // linear
    // return x * x;                                                   // ease in
    // return 1 - (1 - x) * (1 - x);                                   // ease out
    // return x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;  // ease in-out
  }

  IpcHandler {
    target: "musicvisualizer"
    function toggle(): void { root.active = !root.active }
    function on(): void { root.active = true }
    function off(): void { root.active = false }
  }

  Process {
    running: root.active
    command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
    stdout: SplitParser {
      onRead: data => {
        const p = data.split(";");
        const v = [];
        for (let i = 0; i < p.length; i++) {
          const n = parseInt(p[i]);
          if (!isNaN(n)) v.push(n / 100);
        }
	if (v.length === 0) return;

        let all = 0;
        for (let i = 0; i < v.length; i++) all += v[i];
	all /= v.length;

        root.level = all;
        root.bars = v;
      }
    }
  }

  Variants {
    model: root.active ? Quickshell.screens : []

    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "MusicVisualizer"
      color: root.colBgDark
      mask: Region {}                       // click-through

      Canvas {
        id: cv
        anchors.fill: parent
	renderTarget: Canvas.FramebufferObject

        property real t: 0
        property real dt: 0.016

        FrameAnimation {
          running: true
          onTriggered: { cv.dt = frameTime; cv.t += frameTime; cv.requestPaint(); }
	}

        onPaint: {
          const ctx = getContext("2d");
          const w = width, h = height, t = cv.t;
          const bars = root.bars, n = bars.length;
	  const level = root.level;

          // fade the previous frame: short trails and a bit of glow
          ctx.fillStyle = root.withAlpha(root.colBgDark, root.fade);
	  ctx.fillRect(0, 0, w, h);

          // ================= ribbon: a bundle of jagged lines =================
          const N = root.lineCount;
          const steps = 140;
	  const midY = h * 0.5;

          function bandAt(u) {
            if (n === 0) return 0;
            const f = u * (n - 1);
            const k = Math.floor(f);
            const r = f - k;
            const lo = bars[k];
            const hi = bars[Math.min(n - 1, k + 1)];
            return lo + (hi - lo) * r;
	  }

          function wobble(i, u) {
            const p = i * 2.399;      // golden angle: every line gets its own phase
            return 0.50 * Math.sin(u * 14 + p + t * (1.3 + 0.17 * i))
                 + 0.30 * Math.sin(u * 37 - p * 1.7 - t * (2.1 + 0.11 * i))
                 + 0.15 * Math.sin(u * 83 + p * 2.3 + t * 3.4)
                 + 0.10 * Math.sin(u * 167 - p * 3.1 - t * 4.7);
	  }

          // how far the lines may swing at each x (louder band = bigger swings)
          const env = [];
          for (let j = 0; j <= steps; j++) {
            env.push(h * (0.24 * (0.5 * Math.sqrt(bandAt(j / steps)) + 0.5 * level)) * intensity);
	  }

          ctx.lineJoin = "round";
          ctx.lineCap = "round";

          for (let i = 0; i < N; i++) {
            const ys = [];
            for (let j = 0; j <= steps; j++) ys.push(midY + wobble(i, j / steps) * env[j]);
            const alpha = 0.35 + 0.55 * (((i * 5) % N) / N);     // brightness varies per line
            for (let pass = 0; pass < 2; pass++) {
              ctx.lineWidth = pass === 0 ? 10 : 3.2;           // wide faint glow, then a thin core
              ctx.strokeStyle = root.withAlpha(pass === 0 ? root.colGreen : root.colCrystalGreen, pass === 0 ? alpha * 0.30 : alpha);
              ctx.beginPath();
              ctx.moveTo(0, ys[0]);
              for (let j = 1; j <= steps; j++) ctx.lineTo((j / steps) * w, ys[j]);
              ctx.stroke();
            }
	  }
        }
      }
    }
  }
}
