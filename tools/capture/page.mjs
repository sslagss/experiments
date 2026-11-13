// Generic scenario for any rAF-animated page (see virtual-time.mjs).
//   PAGE      path from the repo root (required), e.g. "typelab/typelab.html"
//   READY     JS expression that's truthy once the page is set up (default: 2 s in)
//   CUES      "<seconds>:<js>;;<seconds>:<js>" run at those times (clicks, keys, API calls)
//   CSS       extra CSS, e.g. to hide overlays
//   CLEAR_STORAGE=1  start from empty localStorage (pages that remember camera, progress...)
//   W, H      viewport (default 1200 x 480)
import { virtualTime, injectCss, cueRunner } from './virtual-time.mjs';

export const url = encodeURI(process.env.PAGE || '');
export const width = +(process.env.W || 1200);
export const height = +(process.env.H || 480);
export const init = (process.env.CLEAR_STORAGE ? 'try { localStorage.clear(); } catch (e) {}\n' : '') + virtualTime + injectCss(process.env.CSS);
export const ready = process.env.READY ? `(__tick(33), ${process.env.READY})` : `(__tick(33), (window.__capWait = (window.__capWait || 0) + 1) > 20 && document.readyState === 'complete')`;
const cue = cueRunner(process.env.CUES);
export async function step({ ev, fps }) {
  await cue(ev);
  await ev(`__tick(${1000 / fps})`);
}
