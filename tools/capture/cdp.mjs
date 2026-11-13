// Frame-exact page capture over the Chrome DevTools Protocol. No dependencies (Node 22+).
//
//   node tools/capture/cdp.mjs <scenario.mjs> [--mode scout|take] [--from S] [--to S] [--every S] [--out DIR]
//
// Needs Chrome running headless with remote debugging (see README.md) and the
// repo served over http (ES modules don't load from file://).
//
// A scenario module exports:
//   url        page to open, relative to BASE (default http://127.0.0.1:8000/)
//   width, height   viewport (default 1200 x 480, the homepage cards' 5:2)
//   init       optional script injected before the page's own scripts
//   ready      optional expression; the driver waits until it is truthy
//   start(api) optional: kick things off (press Start, pick a level...)
//   step(api)  advance exactly one frame (1/30 s)
//   state(api) optional: a short JSON-able status logged next to each frame
//
// Modes:
//   scout  a PNG still every --every seconds from --from to --to (find the moment)
//   take   every frame from --from to --to as JPEG, plus log.txt (cut the clip from it)
import { writeFileSync, mkdirSync, appendFileSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const { values: opt, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    mode: { type: 'string', default: 'scout' },
    from: { type: 'string', default: '0' },
    to: { type: 'string', default: '30' },
    every: { type: 'string', default: '3' },
    out: { type: 'string' },
    port: { type: 'string', default: process.env.CDP_PORT || '9333' },
    base: { type: 'string', default: process.env.BASE || 'http://127.0.0.1:8000/' },
  },
});
if (!positionals[0]) { console.error('usage: node cdp.mjs <scenario.mjs> [--mode scout|take] [--from S] [--to S] [--every S] [--out DIR]'); process.exit(1); }

const FPS = 30;
const sc = await import(pathToFileURL(resolve(positionals[0])).href);
const OUT = resolve(opt.out || `capture-${opt.mode}`);
const url = new URL(sc.url, opt.base).href;

// --- CDP plumbing --------------------------------------------------------
const target = await (await fetch(`http://127.0.0.1:${opt.port}/json/new?about:blank`, { method: 'PUT' })).json();
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let seq = 0; const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  const p = m.id && pending.get(m.id);
  if (p) { pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
});
const send = (method, params = {}) => new Promise((res, rej) => { const id = ++seq; pending.set(id, { res, rej }); ws.send(JSON.stringify({ id, method, params })); });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function ev(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
}
async function grab(path, format) {
  const { data } = await send('Page.captureScreenshot', format === 'jpeg' ? { format, quality: 92 } : { format });
  writeFileSync(path, Buffer.from(data, 'base64'));
}
const api = { ev, send, sleep, fps: FPS };

try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: sc.width || 1200, height: sc.height || 480, deviceScaleFactor: 1, mobile: false });
  if (sc.init) await send('Page.addScriptToEvaluateOnNewDocument', { source: sc.init });
  await send('Page.navigate', { url });
  if (sc.ready) {
    let ok = false;
    for (let i = 0; i < 150 && !ok; i++) { ok = await ev(sc.ready).catch(() => false); if (!ok) await sleep(100); }
    if (!ok) throw new Error(`page never became ready: ${sc.ready} (is the server running at ${opt.base}?)`);
  }
  await ev('document.fonts.ready.then(() => 1)');
  await sleep(300);
  if (sc.start) await sc.start(api);

  const from = Math.round(+opt.from * FPS), to = Math.round(+opt.to * FPS);
  for (let f = 0; f < from; f++) await sc.step(api);

  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });
  const every = opt.mode === 'take' ? 1 : Math.max(1, Math.round(+opt.every * FPS));
  for (let f = from; f < to; f++) {
    await sc.step(api);
    if ((f + 1 - from) % every) continue;
    const st = sc.state ? JSON.stringify(await sc.state(api)) : '';
    const name = opt.mode === 'take' ? `f${String(f).padStart(5, '0')}.jpg` : `t${((f + 1) / FPS).toFixed(1).padStart(5, '0')}s.png`;
    await grab(`${OUT}/${name}`, opt.mode === 'take' ? 'jpeg' : 'png');
    appendFileSync(`${OUT}/log.txt`, `${f} ${st}\n`);
    if (opt.mode !== 'take') console.log(name, st);
  }
  console.log(`done: ${OUT}`);
} finally {
  await fetch(`http://127.0.0.1:${opt.port}/json/close/${target.id}`).catch(() => {});
  ws.close();
}
