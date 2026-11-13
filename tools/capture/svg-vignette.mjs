// Renders one of the homepage's own SVG vignettes (SMIL animations) to frames:
// the card's vignette is blown up to fill the viewport, its animations are
// paused, and each step sets the exact time with svg.setCurrentTime().
//
//   CARD   the vignette's class suffix, e.g. "dayz" for .vignette-dayz (required)
//
// The DayZ clip is this card's original vignette (7 s route cycle + 0.5 s for the crossfade):
//   CARD=dayz node tools/capture/cdp.mjs tools/capture/svg-vignette.mjs --mode take --from 0 --to 7.5 --out /tmp/dz-take
//   tools/capture/cut.sh /tmp/dz-take 0 224 previews/dayz-field-card.mp4 1600000 15
const card = process.env.CARD;
if (!card) throw new Error('set CARD, e.g. CARD=dayz');

export const url = 'index.html';
export const width = 1200;
export const height = 480;

const sel = `.vignette-${card}`;
export const init = `
  addEventListener('DOMContentLoaded', () => {
    const s = document.createElement('style');
    s.textContent = \`
      body { overflow: hidden !important; }
      ${sel} { position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important; aspect-ratio: auto !important; z-index: 2147483647 !important; }
      ${sel} .vignette-video { display: none !important; }
    \`;
    document.head.appendChild(s);
  });
`;
export const ready = `!!document.querySelector('${sel} svg') && document.readyState === 'complete'`;

let frame = 0;
export async function step({ ev, fps }) {
  frame++;
  await ev(`(() => { const svg = document.querySelector('${sel} svg'); svg.pauseAnimations(); svg.setCurrentTime(${frame / fps}); })()`);
}
