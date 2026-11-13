// Solscape capture scenario. Solscape has no step hook, but its loop runs off
// requestAnimationFrame's timestamp, so we swap in a fake rAF and feed it
// virtual time: each step() runs every queued callback with now += 1/30 s.
// (This works for any page whose animation is driven purely by rAF.)
//
// CUES scripts what happens, as "<seconds>:<action>" pairs, comma-separated:
//   <body id>    fly to it (sun, earth, jupiter, saturn, ... see sim/bodies-data.js)
//   system       fly back out to the whole system
//   true|model   switch scale
//   speed<n>     time speed index
//   pause|play
// HIDE_UI=1 hides the HTML overlays (header, controls, info panel), leaving the
// 3D scene and its in-space labels.
// e.g. CUES="1:saturn,9:system" node tools/capture/cdp.mjs tools/capture/solscape.mjs --mode scout --to 16 --every 1
export const url = 'solscape/index.html';
export const width = 1200;
export const height = 480;

export const init = `
  (() => {
    let q = [], id = 0, now = null;
    window.requestAnimationFrame = (cb) => { q.push([++id, cb]); return id; };
    window.cancelAnimationFrame = (h) => { q = q.filter(([i]) => i !== h); };
    if (${JSON.stringify(process.env.HIDE_UI || '')}) addEventListener('DOMContentLoaded', () => {
      const st = document.createElement('style');
      st.textContent = '[data-screen-label] > :not(:first-child) { display: none !important; }';
      document.head.appendChild(st);
    });
    window.__tick = (ms) => {
      if (now === null) now = performance.now();
      now += ms;
      const run = q; q = [];
      for (const [, cb] of run) cb(now);
    };
  })();
`;

// Keep ticking while the textures load; ready once the loading overlay is gone.
export const ready = `(__tick(33), !!window.__solsim && !/ASSEMBLING|INITIALIZING/.test(document.body.innerText))`;

const cues = (process.env.CUES || '').split(',').filter(Boolean).map((c) => {
  const [t, action] = c.split(':');
  return { frame: Math.round(+t * 30), action };
});
let frame = 0;

function cueJs(a) {
  if (a === 'system') return '__solsim.clearSelection()';
  if (a === 'true' || a === 'model') return `__solsim.setScale('${a}')`;
  if (a === 'pause' || a === 'play') return `__solsim.setPaused(${a === 'pause'})`;
  if (a.startsWith('speed')) return `__solsim.setSpeedIdx(${+a.slice(5)})`;
  return `__solsim.select('${a}')`;
}

export async function step({ ev, fps }) {
  for (const c of cues) if (c.frame === frame) await ev(cueJs(c.action));
  frame++;
  await ev(`__tick(${1000 / fps})`);
}

export const state = ({ ev }) => ev(`(() => { const d = __solsim.debug(); return { mode: d.mode, sel: d.sel }; })()`);
