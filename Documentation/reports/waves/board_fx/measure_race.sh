#!/usr/bin/env bash
# The board's effects in a 12-board race (11 AI boards and the player's board on the autopilot), before
# (5e48758) and after (this branch): the release build is built for each (swap.sh), then
# tools/fleet_measure.sh races T1 with a 5 s countdown (so the boards race while it measures) and the
# follow camera, at 1280 x 720 and drawn at 3137 x 1263. Prints fleet_measure's row and the graphics
# card's time per frame; each run's log is kept as .logs/board_fx_race_<which>_<size>.log.
# Run from the repository's root with GODOT set: Documentation/reports/waves/board_fx/measure_race.sh
set -euo pipefail
here="$(dirname "$0")"
for which in before after; do
	bash "$here/swap.sh" "$which"
	tools/release.sh build > /dev/null
	for size in 1280x720 3137x1263; do
		extra=(--prestart=5 --autopilot=1 --camera=1 --hud=0)
		if [[ "$size" != "1280x720" ]]; then extra+=(--render_size="$size"); fi
		row="$(tools/fleet_measure.sh --sizes=11 --seconds=12 "${extra[@]}" | tail -n 1)"
		gpu="$(grep -o 'the graphics card: [0-9.]* ms' .logs/fleet_measure_11.log | head -n 1)"
		cp .logs/fleet_measure_11.log ".logs/board_fx_race_${which}_${size}.log"
		echo "$which $size: $row ${gpu:-no graphics card time}"
	done
done
bash "$here/swap.sh" after
