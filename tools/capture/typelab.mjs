// Type Lab capture scenario: rAF on virtual time, plus a scripted pointer
// stroke stirring the word. Keys 1-7 pick the liquid mode
// (1 FLAME, 2 ACID, 3 WIND, 4 THERMAL, 5 CHROMA, 6 FERRO, 7 INK).
//
// PLAN is a list of "<seconds>:<action>" (comma-separated):
//   mode<n>   switch to mode n (it also picks a new random word)
//   stir<sec> drag one sweep across the word over that many seconds
//   reset     heal the letters (R)
// The homepage clip (Thermal, the word came up EXPERIMENT):
//   PLAN="0.1:mode4,1:stir2" node tools/capture/cdp.mjs tools/capture/typelab.mjs --mode take --from 0 --to 10 --out /tmp/tl-take
//   tools/capture/cut.sh /tmp/tl-take 20 235 previews/typelab.mp4 1600000 15
import { virtualTime, injectCss } from './virtual-time.mjs';

export const url = 'typelab/typelab.html';
export const width = +(process.env.W || 1200);
export const height = +(process.env.H || 480);
export const init = virtualTime + injectCss(process.env.HIDE_UI ? '[data-screen-label] > :not(canvas) { display: none !important; }' : '');
export const ready = `(__tick(33), (window.__capWait = (window.__capWait || 0) + 1) > 20 && !!document.querySelector('canvas'))`;

const plan = (process.env.PLAN || '').split(',').filter(Boolean).map((c) => {
  const i = c.indexOf(':');
  return { frame: Math.round(+c.slice(0, i) * 30), a: c.slice(i + 1) };
});
let frame = 0, stirUntil = -1, stirFrom = 0, stirLen = 1;

// The stroke: one left-to-right sweep across the word, waving up and down.
// u runs 0 -> 1 over the stir.
function strokeAt(u) {
  const x = 0.1 + 0.8 * u;
  const y = 0.37 + 0.12 * Math.sin(u * Math.PI * 4);
  return [Math.round(x * width), Math.round(y * height)];
}
const ptr = (type, [x, y], buttons) => `(() => { const el = document.querySelector('[data-screen-label]'); el.dispatchEvent(new PointerEvent('${type}', { clientX: ${x}, clientY: ${y}, buttons: ${buttons}, pointerId: 1, pointerType: 'mouse', isPrimary: true, bubbles: true })); })()`;
const key = (k) => `dispatchEvent(new KeyboardEvent('keydown', { key: '${k}' }))`;

export async function step({ ev, fps }) {
  for (const p of plan) {
    if (p.frame !== frame) continue;
    const a = p.a;
    if (a.startsWith('mode')) await ev(key(a.slice(4)));
    else if (a === 'reset') await ev(key('r'));
    else if (a.startsWith('stir')) { stirFrom = frame; stirLen = Math.round(+a.slice(4) * fps); stirUntil = frame + stirLen; await ev(ptr('pointerdown', strokeAt(0), 1)); }
  }
  if (frame < stirUntil) await ev(ptr('pointermove', strokeAt((frame - stirFrom) / stirLen), 1));
  else if (frame === stirUntil) {
    await ev(ptr('pointerup', strokeAt(1), 0));
    await ev(ptr('pointermove', [-200, -200], 0));   // park the cursor ring off-screen
  }
  frame++;
  await ev(`__tick(${1000 / fps})`);
}
