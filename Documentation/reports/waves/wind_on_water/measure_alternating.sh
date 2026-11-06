#!/usr/bin/env bash
# The water's cost on the graphics card, before (f72f565, today's play-test look) and after (this branch),
# measured alternately on the lake with one board (the editor build; the graphics card's time per frame is
# the same as the release build's, and one board keeps the processor out of the way), at 1280 x 720 and
# drawn at 3137 x 1263, at 24 kt (Lake wind x1.32), `rounds` times each; the least of each is the cost
# with the least disturbance from other programs. Run from the repository's root with GODOT set:
#   measure_alternating.sh <swap script> [rounds]
# The swap script puts today's files in place ("before") or this branch's back ("after").
set -euo pipefail
swap="$1"
rounds="${2:-3}"
lake="res://maps/silvaplana/sail_silvaplana.tscn"
for round in $(seq 1 "$rounds"); do
	for which in before after; do
		bash "$swap" "$which" > /dev/null
		for size in 1280x720 3137x1263; do
			log=".logs/wow_alt_${which}_${size}_${round}.log"
			"$GODOT" --path Game --audio-driver Dummy --resolution "$size" "$lake" -- --autopilot=1 --measure=12 --render_size="$size" --lake_wind_scale=1.32 > "$log" 2>&1 || true
			gpu="$(grep -o 'the graphics card: [0-9.]* ms' "$log" | grep -o '[0-9.]*' | head -n 1)"
			echo "$round $which $size ${gpu:-none}"
		done
	done
done
bash "$swap" after > /dev/null
