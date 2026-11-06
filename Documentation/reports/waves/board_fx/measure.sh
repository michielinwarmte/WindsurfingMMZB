#!/usr/bin/env bash
# The board's effects' cost, before (5e48758) and after (this branch), measured alternately: one board
# on the open water at 24 kt (planing, the spray in view of the follow camera), the editor build, at
# 1280 x 720 and 3137 x 1263, `rounds` times each. Prints the graphics card's time per frame and the
# board's visuals per physics tick (the effects' work on the processor). Run from the repository's
# root with GODOT set: Documentation/reports/waves/board_fx/measure.sh [rounds]
set -euo pipefail
here="$(dirname "$0")"
rounds="${1:-2}"
settings="$(pwd)/.screenshots/board_fx/measure_24.cfg"
mkdir -p "$(dirname "$settings")"
printf '[wind]\nspeed_kt=24\n' > "$settings"
for round in $(seq 1 "$rounds"); do
	for which in before after; do
		bash "$here/swap.sh" "$which"
		for size in 1280x720 3137x1263; do
			log=".logs/board_fx_measure_${which}_${size}_${round}.log"
			timeout 120 "$GODOT" --path Game --audio-driver Dummy --resolution "$size" res://main.tscn -- --autopilot=1 --camera=1 --hud=0 --measure=10 --settings="$settings" > "$log" 2>&1 || true
			gpu="$(grep -o 'the graphics card: [0-9.]* ms' "$log" | grep -o '[0-9.]*' | head -n 1)"
			fps="$(grep -o 'boards: [0-9]* fps' "$log" | grep -o '[0-9]* fps' | head -n 1)"
			visuals="$(grep -o 'visuals [0-9.]* ms' "$log" | head -n 1)"
			echo "$round $which $size gpu ${gpu:-none} ms, ${fps:-?}, ${visuals:-?}"
		done
	done
done
bash "$here/swap.sh" after
