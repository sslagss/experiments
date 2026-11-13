#!/bin/bash
# Cut frames FIRST..LAST from a take folder into a looping mp4.
#   tools/capture/cut.sh <take-dir> <first> <last> <out.mp4> [bitrate=1600000] [xfade=15]
# The clip comes out (LAST-FIRST+1-xfade) frames long: its last xfade frames
# dissolve into its first ones, so the loop has no hard cut.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
take=$1 first=$2 last=$3 out=$4 br=${5:-1600000} xf=${6:-15}
files=()
for ((f = first; f <= last; f++)); do files+=("$take/$(printf 'f%05d.jpg' "$f")"); done
size=$(sips -g pixelWidth -g pixelHeight "${files[0]}" | awk '/pixel/ {print $2}' | xargs)
swift "$here/encode.swift" "$out" ${size% *} ${size#* } "$br" 30 "$xf" "${files[@]}" 2>&1 | grep -v warning
ls -l "$out" | awk '{printf "%s: %.0f KB\n", $NF, $5/1024}'
