# Homepage preview captures

Tools for recording the looping clips on the homepage cards. Each card plays
`previews/<slug>.mp4` when it exists and `previews/placeholder.mp4` otherwise,
so adding a file is all it takes to replace a placeholder.

| Card | File |
|---|---|
| DayZ Field Card | `dayz-field-card.mp4` |
| Synthlab | `synthlab.mp4` |
| Vector Wars | `vector-wars.mp4` (done: level 2 mini-boss kill) |
| Track Companion | `track-companion.mp4` |
| Type Lab | `typelab.mp4` |
| Solscape | `solscape.mp4` |
| Scoville | `scoville.mp4` |
| Meridian GP | `meridian-gp.mp4` |

Target: 5:2 (1200×480), 30 fps, about 5 s, H.264 around 1.6 Mbps (≈1 MB).

Nothing to install: it uses your Chrome, Node 22+ and macOS's own AVFoundation
(through `swift`, which comes with Xcode or the Command Line Tools).

## How it works

Screen-recording a WebGL page in headless Chrome stutters, so instead the page
is stepped one frame (1/30 s) at a time and screenshotted after each step. The
clip comes out perfectly smooth however slow the rendering is. This needs a way
to advance the prototype by hand. Vector Wars has one (`?debug` →
`window.vectorWars.step()`); for other prototypes, write a scenario whose
`step` does the equivalent (or add a small step hook to the prototype).

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
- `cut.sh` → `encode.swift`: frames to a looping H.264 mp4 with an end-to-start crossfade.
- `montage.swift`: contact sheet of stills.
- `testclip.swift`: regenerates `previews/placeholder.mp4`.
