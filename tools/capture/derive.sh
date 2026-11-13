#!/bin/bash
# Make each card's lighter assets from its finished clip in previews/:
#   <slug>.jpg      poster, 1200 wide (desktop)       <slug>-sm.jpg  poster, 720 wide (phones, tablets)
#   <slug>-sm.mp4   the clip at 600x240, ~500 kbps (phones)
# Run from the repo root after (re)shooting a clip:  tools/capture/derive.sh [slug ...]
# The poster time per card is a moment that reads on its own (a still is all a
# slow connection or data-saver visitor sees).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
poster_at() {
  case $1 in
    dayz-field-card) echo 2.0 ;;   # marker mid-route
    synthlab)        echo 7.4 ;;   # fat waveform, chord held
    vector-wars)     echo 2.6 ;;   # boss shattering
    typelab)         echo 2.7 ;;   # EXPERIMENT melting
    solscape)        echo 6.6 ;;   # Saturn's rings
    scoville)        echo 2.8 ;;   # the giants
    meridian-gp)     echo 0.6 ;;   # VEYRA TAKES THE LEAD
    *)               echo 1.0 ;;
  esac
}
slugs=("$@")
if [ ${#slugs[@]} -eq 0 ]; then
  for f in previews/*.mp4; do s=$(basename "$f" .mp4); [[ $s == *-sm || $s == placeholder ]] || slugs+=("$s"); done
fi
for s in "${slugs[@]}"; do
  t=$(poster_at "$s")
  swift "$here/derive.swift" poster "previews/$s.mp4" "previews/$s.jpg" "$t" 1200 0.55 2>&1 | grep -E "^(wrote|failed)|error:" || true
  swift "$here/derive.swift" poster "previews/$s.mp4" "previews/$s-sm.jpg" "$t" 720 0.7 2>&1 | grep -E "^(wrote|failed)|error:" || true
  swift "$here/derive.swift" scale "previews/$s.mp4" "previews/$s-sm.mp4" 600 240 500000 2>&1 | grep -E "^(wrote|failed)|error:" || true
done
ls -l previews | awk 'NR > 1 {printf "%7.0f KB  %s\n", $5/1024, $9}'
