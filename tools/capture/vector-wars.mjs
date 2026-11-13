// Vector Wars capture scenario. The game's ?debug hook (window.vectorWars.step)
// advances it one frame at a time, so we take the game loop off
// requestAnimationFrame and only our steps move and render it.
//
// The homepage clip (previews/vector-wars.mp4) is the level 2 mini-boss kill:
//   node tools/capture/cdp.mjs tools/capture/vector-wars.mjs --mode scout --from 0 --to 63 --every 3
//   node tools/capture/cdp.mjs tools/capture/vector-wars.mjs --mode take --from 38 --to 62 --out /tmp/vw-take
// then find the kill in log.txt (first line whose squads is "") and cut ~2.5 s
// either side of it. Runs are not fully repeatable, so always cut from a take.
//
// LEVEL=n picks the level (?level=n jumps to just before its gate); LEVEL=1 is a fresh run.
const level = parseInt(process.env.LEVEL || '2', 10);

export const url = `Vector%20Wars/index.html?debug${level > 1 ? `&level=${level}` : ''}`;
export const width = 1200;
export const height = 480;

export const init = `
  window.requestAnimationFrame = () => 0;
  addEventListener('DOMContentLoaded', () => {
    const s = document.createElement('style');
    s.textContent = '#debug, [id^=dbg] { display: none !important; }';   // ?debug-only overlays
    document.head.appendChild(s);
  });
`;

export const ready = '!!window.vectorWars';

// Enter on the title screen starts a Story run.
export const start = ({ ev }) => ev(`dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }))`);

export const step = ({ ev, fps }) => ev(`void vectorWars.step(1, ${1 / fps})`);

export const state = ({ ev }) => ev(`(() => { const s = vectorWars.step(0); return { state: s.state, N: s.N, squads: s.squads, danger: s.danger, timeScale: s.timeScale }; })()`);
