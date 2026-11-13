# Homepage preview captures

Tools for recording the looping clips on the homepage cards. Each card plays
`previews/<slug>.mp4` when it exists and `previews/placeholder.mp4` otherwise,
so adding a file is all it takes to replace a placeholder. All eight cards have
real clips now; the placeholder stays as the fallback for any new card.

| Card | File |
|---|---|
| DayZ Field Card | `dayz-field-card.mp4` (done: the card's original SVG vignette, rendered) |
| Synthlab | `synthlab.mp4` (done: Build tab, New → Randomize → Mutate with phrases played) |
| Vector Wars | `vector-wars.mp4` (done: level 2 mini-boss kill) |
| Track Companion | `track-companion.mp4` (done: drive screen, Della Roggia → Lesmo 1 → Lesmo 2) |
| Type Lab | `typelab.mp4` (done: Thermal sweep through EXPERIMENT, then it heals) |
| Solscape | `solscape.mp4` (done: fly to Saturn, UI hidden) |
| Scoville | `scoville.mp4` (done: Galaxy view, Orbits → Giants → Orbits) |
| Meridian GP | `meridian-gp.mp4` (done: The Move, Follow cam, panels hidden) |

Target: 5:2 (1200×480), 30 fps, about 5 s, H.264 around 1.6 Mbps (≈1 MB).

Nothing to install: it uses your Chrome, Node 22+ and macOS's own AVFoundation
(through `swift`, which comes with Xcode or the Command Line Tools).

## How it works

Screen-recording a WebGL page in headless Chrome stutters, so instead the page
is stepped one frame (1/30 s) at a time and screenshotted after each step. The
clip comes out perfectly smooth however slow the rendering is. This needs a way
to advance the prototype by hand:

- **A step hook**, if the prototype has one. Vector Wars: `?debug` →
  `window.vectorWars.step()` (`vector-wars.mjs`).
- **Virtual time**, for anything animated purely by `requestAnimationFrame`.
  `virtual-time.mjs` swaps in a fake rAF (and `performance.now()`) and runs
  the queued callbacks with the clock advanced 1/30 s per step. `page.mjs`
  applies it to any page, driven by env vars; `solscape.mjs` and
  `typelab.mjs` add page-specific cues. Timers and CSS transitions still run
  in real time. It also works on the self-unpacking bundles (Scoville, MGP),
  since the window survives their document swap.

## Walkthrough (Vector Wars)

1. Serve the repo and start headless Chrome (two terminals, both left running):

   ```bash
   python3 -m http.server 8000
   ```

   ```bash
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --remote-debugging-port=9333 --user-data-dir=/tmp/capture-chrome --mute-audio --hide-scrollbars about:blank
   ```

2. Scout: a still every 3 s, with game state printed beside each.

   ```bash
   node tools/capture/cdp.mjs tools/capture/vector-wars.mjs --mode scout --from 0 --to 63 --every 3 --out /tmp/vw-scout
   ```

   Look at them together on a contact sheet:

   ```bash
   swift tools/capture/montage.swift /tmp/vw-scout.png 3 400 /tmp/vw-scout/*.png
   ```

3. Take: every frame across the moment you picked (JPEG plus `log.txt`, one
   line of state per frame). Runs aren't fully repeatable, so always cut from a
   take rather than re-running to the same moment.

   ```bash
   node tools/capture/cdp.mjs tools/capture/vector-wars.mjs --mode take --from 38 --to 62 --out /tmp/vw-take
   ```

4. Find the frame you want in `log.txt` (for the boss kill, the first line where
   `squads` is empty), then cut and encode around it:

   ```bash
   tools/capture/cut.sh /tmp/vw-take 1486 1650 previews/vector-wars.mp4
   ```

5. Open the homepage and check the card. (Python's server can't seek video, so
   scrubbing won't work locally; playback and looping do.)

## Files

- `cdp.mjs`: the driver (scenario in, stills or frames out).
- `vector-wars.mjs`: the Vector Wars scenario. `LEVEL=n` env picks the level.
- `solscape.mjs`: the Solscape scenario. `CUES` scripts fly-tos and toggles,
  `HIDE_UI=1` drops the overlays. The homepage clip:
  `HIDE_UI=1 CUES="1:saturn" node tools/capture/cdp.mjs tools/capture/solscape.mjs --mode take --from 0 --to 13 --out /tmp/sol-take`,
  then `tools/capture/cut.sh /tmp/sol-take 40 290 previews/solscape.mp4 1600000 20`.
- `typelab.mjs`: Type Lab. `PLAN` picks modes (keys 1-7) and drags a stroke
  through the word. The homepage clip:
  `PLAN="0.1:mode4,1:stir2" node tools/capture/cdp.mjs tools/capture/typelab.mjs --mode take --from 0 --to 10 --out /tmp/tl-take`,
  then `tools/capture/cut.sh /tmp/tl-take 20 235 previews/typelab.mp4 1600000 15`.
  Switching mode also picks a random word; this take came up EXPERIMENT.
- `page.mjs` + `virtual-time.mjs`: any rAF page. `PAGE`, `READY`, `CUES`
  (`"<s>:<js>;;<s>:<js>"`), `CSS`, `CLEAR_STORAGE=1`. See below for Scoville and MGP.

- `synthlab.mjs`: Synthlab's Build tab with scripted key phrases and
  New / Randomize / Mutate (it fakes the pressed look, since scripted clicks
  show no `:active`). Command in the file's header.
- `svg-vignette.mjs`: renders one of the homepage's own SMIL vignettes
  (`CARD=dayz`) frame by frame with `svg.setCurrentTime()`. Command in the file's header.

### Scoville, Track Companion and Meridian GP (generic `page.mjs`)

```bash
click() { echo "[...document.querySelectorAll('button')].find(b => b.textContent.trim().toLowerCase() === '$1'.toLowerCase()).click()"; }
```

(Match case-insensitively: CSS often uppercases labels, e.g. Synthlab's "Build".)

Scoville (the card links to the Index view; the clip is the Galaxy view it opens):

```bash
PAGE="Scoville Galaxy (Standalone).html" READY="!!document.querySelector('canvas') && (window.__capWait = (window.__capWait || 0) + 1) > 30" CUES="0.2:$(click Orbits);;3:$(click Giants);;6:$(click Orbits)" node tools/capture/cdp.mjs tools/capture/page.mjs --mode take --from 0 --to 9 --out /tmp/scg-take
tools/capture/cut.sh /tmp/scg-take 45 255 previews/scoville.mp4 1600000 20
```

Track Companion: the drive screen on the default 1:55.00 target, across two
corner hand-overs (it re-renders instantly; there's no scroll animation):

```bash
CLEAR_STORAGE=1 PAGE="track-companion/index.html" READY="!!document.getElementById('start-btn') && (window.__capWait = (window.__capWait || 0) + 1) > 15" CUES="0.3:document.getElementById('start-btn').click()" node tools/capture/cdp.mjs tools/capture/page.mjs --mode take --from 44.5 --to 53.1 --out /tmp/tc-take
tools/capture/cut.sh /tmp/tc-take 1345 1590 previews/track-companion.mp4 1600000 15
```

Meridian GP. It remembers its camera in localStorage, so clear it and pick
Follow explicitly. Hide the panels after the chapter starts (hiding `#intro`
from load stops playback starting):

```bash
HIDE="document.head.appendChild(Object.assign(document.createElement('style'), { textContent: '#topbar, #leaderboard, #driver-card, #transport, #intro { visibility: hidden !important; }' }))"
CLEAR_STORAGE=1 PAGE="MGP-recap.html" READY="!!window.MGP && (window.__capWait = (window.__capWait || 0) + 1) > 30" CUES="0.2:$(click 'PLAY RECAP');;1:$(click 'THE MOVE');;1.1:$(click FOLLOW);;3:$HIDE" node tools/capture/cdp.mjs tools/capture/page.mjs --mode take --from 0 --to 17 --out /tmp/mgp-take
tools/capture/cut.sh /tmp/mgp-take 95 300 previews/meridian-gp.mp4 1600000 20
```

- `cut.sh` → `encode.swift`: frames to a looping H.264 mp4 with an end-to-start crossfade.
- `montage.swift`: contact sheet of stills.
- `testclip.swift`: regenerates `previews/placeholder.mp4`.
