// Synthlab capture scenario: the Build tab (waveform + Randomize / Mutate)
// while short phrases play on the keyboard. Uses ?debug's window.synthlab to
// press keys, and virtual time for the 0.08 s key transitions.
//
// The homepage clip:
//   node tools/capture/cdp.mjs tools/capture/synthlab.mjs --mode take --from 0 --to 9.8 --out /tmp/syn-take
//   tools/capture/cut.sh /tmp/syn-take 20 285 previews/synthlab.mp4 1600000 15
import { virtualTime } from './virtual-time.mjs';

export const url = 'synthlab/index.html?debug';
export const width = 1200;
export const height = 480;
// Fresh storage, so the built-in presets and default settings show.
export const init = 'try { localStorage.clear(); } catch (e) {}\n' + virtualTime;
export const ready = `(__tick(33), !!window.synthlab && (window.__capWait = (window.__capWait || 0) + 1) > 20)`;

// Button by label (labels are uppercased by CSS; match the real text).
const btn = (label) => `[...document.querySelectorAll('button')].find(b => b.textContent.trim().toLowerCase() === ${JSON.stringify(label.toLowerCase())})`;
// A scripted click shows no :active state, so fake the pressed look briefly.
const tap = (label) => `(() => { const b = ${btn(label)}; b.style.transform = 'scale(0.94)'; b.style.boxShadow = '0 0 16px rgba(190, 255, 60, 0.7)'; b.click(); window.__tapped = b; })()`;
const untap = `(() => { const b = window.__tapped; if (b) { b.style.transform = ''; b.style.boxShadow = ''; } })()`;
const down = (n) => `synthlab.keyboard.press(${n}, 'cap${n}')`;
const up = (n) => `synthlab.keyboard.release(${n}, 'cap${n}')`;

// Timeline in seconds.
const T = [];
const at = (t, js) => T.push({ frame: Math.round(t * 30), js });
const arp = (t0, notes = [60, 64, 67, 72], step = 0.28, hold = 0.24) =>
  notes.forEach((n, i) => { at(t0 + i * step, down(n)); at(t0 + i * step + hold, up(n)); });
const press = (t, label) => { at(t, tap(label)); at(t + 0.2, untap); };

at(0.3, `${btn('Build')}.click()`);
press(1.0, '+ New');
arp(1.5);
press(3.0, 'Randomize');
arp(3.5, [62, 65, 69, 74]);
press(5.0, 'Mutate');
arp(5.5, [57, 60, 64, 69]);
press(7.0, 'Mutate');
[60, 64, 67, 71].forEach((n) => { at(7.5, down(n)); at(8.6, up(n)); });

let frame = 0;
export async function step({ ev, fps }) {
  for (const c of T) if (c.frame === frame) await ev(c.js);
  frame++;
  await ev(`__tick(${1000 / fps})`);
}

export const state = ({ ev }) => ev(`synthlab.current && synthlab.current.name`);
