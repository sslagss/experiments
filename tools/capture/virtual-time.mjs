// Shared by scenarios for pages animated purely by requestAnimationFrame:
// swaps in a fake rAF whose callbacks only run when __tick(ms) advances the
// clock. Inject `virtualTime` as (part of) a scenario's `init`.
// The window survives document swaps (the self-unpacking bundles), so this holds there too.
export const virtualTime = `
  (() => {
    // performance.now() follows the same virtual clock, so velocities and
    // timestamps the page computes agree with the frames we step.
    const realNow = performance.now.bind(performance);
    let q = [], id = 0, now = realNow();
    performance.now = () => now;
    window.requestAnimationFrame = (cb) => { q.push([++id, cb]); return id; };
    window.cancelAnimationFrame = (h) => { q = q.filter(([i]) => i !== h); };
    window.__tick = (ms) => {
      now += ms;
      const run = q; q = [];
      for (const [, cb] of run) { try { cb(now); } catch (e) { console.error(e); } }
    };
  })();
`;

// Extra CSS injected once the page's DOM is ready (and again if a bundle swaps the document).
export const injectCss = (css) => css ? `
  (() => {
    const css = ${JSON.stringify(css)};
    const add = () => { if (document.getElementById('__cap_css')) return; const s = document.createElement('style'); s.id = '__cap_css'; s.textContent = css; (document.head || document.documentElement).appendChild(s); };
    addEventListener('DOMContentLoaded', add);
    setInterval(add, 200);
  })();
` : '';

// "<seconds>:<js>" cues, separated by ";;", run at those times.
export function cueRunner(spec) {
  const cues = (spec || '').split(';;').filter(Boolean).map((c) => {
    const i = c.indexOf(':');
    return { frame: Math.round(+c.slice(0, i) * 30), js: c.slice(i + 1) };
  });
  let frame = 0;
  return async (ev) => { for (const c of cues) if (c.frame === frame) await ev(c.js); frame++; };
}
