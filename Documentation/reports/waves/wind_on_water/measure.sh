#!/usr/bin/env bash
# The graphics card's time per frame in a 20-board race on Lake Silvaplana (the T2 slalom, 19 AI boards and
# the player), the release build, at 1280 x 720 and drawn at 3137 x 1263 (wind_on_water.md, Cost). Run from
# the repository's root after tools/release.sh build: measure.sh <label> [lake wind multiplier]
# Prints the main.gd --measure lines; the logs are .logs/wow_measure_<label>_<size>.log.
set -euo pipefail
label="${1:-now}"
scale="${2:-1.0}"
skippers="allrounder,gambler,rookie,cautious,allrounder,gambler,rookie,cautious,allrounder,gambler,rookie,cautious,allrounder,gambler,rookie,cautious,allrounder,gambler,rookie"
for size in 1280x720 3137x1263; do
	log=".logs/wow_measure_${label}_${size}.log"
	.release/wsim_console.exe --audio-driver Dummy --resolution "$size" -- --race=t2_slalom --skippers="$skippers" --measure=20 --render_size="$size" --lake_wind_scale="$scale" > "$log" 2>&1 || true
	echo "== $label $size (lake wind x$scale)"
	grep -i "measured\|graphics card\|gpu" "$log" | head -n 4
done
