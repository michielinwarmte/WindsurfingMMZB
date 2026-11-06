#!/usr/bin/env bash
# The board's effects on the water (board_fx.md): the same views before and after, saved under
# .screenshots/board_fx/<tag>/. Run from the repository's root, with GODOT set:
#   Documentation/reports/waves/board_fx/shoot.sh <tag> [open|lake|moments|wide|all]
# Then python Documentation/reports/waves/board_fx/sheet.py <tag> makes the contact sheets.
# The game runs at a fixed 60 frames a second, so 600 frames is 10 s of sailing.
set -euo pipefail
tag="${1:?a tag: before or after}"
which="${2:-all}"
out=".screenshots/board_fx/$tag"
mkdir -p "$out"
knots=(12 18 24)
# The lake's multipliers for 12, 18 and 24 kt at 10 m at 14:30 (wind_on_water.md).
lake_scales=(0.66 1.0 1.32)
lake="res://maps/silvaplana/sail_silvaplana.tscn"
follow=(--autopilot=1 --camera=1 --hud=0)
# The orbit camera held on the leeward side, a little from behind, 12 degrees up, 8 m away.
side=(--autopilot=1 --hud=0 --side_view=lee,12,8)
shot() { tools/screenshot.sh "$@" > /dev/null || echo "failed: $2"; }
settings_for() {
	local file="$out/open_$1.cfg"
	printf '[wind]\nspeed_kt=%s\n' "$1" > "$file"
	echo "$(pwd)/$file"
}

if [[ "$which" == "open" || "$which" == "all" ]]; then
	for i in 0 1 2; do
		s="$(settings_for "${knots[$i]}")"
		shot res://main.tscn "$out/open_follow_${knots[$i]}.png" 600 "${follow[@]}" --settings="$s"
		shot res://main.tscn "$out/open_side_${knots[$i]}.png" 600 "${side[@]}" --settings="$s"
	done
fi
if [[ "$which" == "lake" || "$which" == "all" ]]; then
	for i in 0 1 2; do
		shot "$lake" "$out/lake_follow_${knots[$i]}.png" 600 "${follow[@]}" --lake_wind_scale="${lake_scales[$i]}"
	done
	shot "$lake" "$out/lake_side_24.png" 600 "${side[@]}" --lake_wind_scale=1.32
fi
if [[ "$which" == "moments" || "$which" == "all" ]]; then
	s="$(settings_for 18)"
	# The start: 2.5 s after rest, at displacement speed, from the side.
	shot res://main.tscn "$out/open_start_18.png" 150 --autopilot=1 --hud=0 --side_view=lee,15,7 --settings="$s"
	# The start at 12 kt, 5 s after rest (the board has gone some metres at displacement speed: the bow
	# wave's V), from behind and above.
	s12="$(settings_for 12)"
	shot res://main.tscn "$out/open_start_12.png" 300 --autopilot=1 --hud=0 --side_view=30,25,9 --settings="$s12"
	# A bear-away carve at 24 kt: the beam reach to 150 degrees at 8 s, seen from behind and above.
	s24="$(settings_for 24)"
	shot res://main.tscn "$out/open_carve_24.png" 580 --autopilot=1 --hud=0 --side_view=0,20,9 --twa_at=8,150 --settings="$s24"
	# A catapult fall at 8 s; the splash 0.75 s later.
	shot res://main.tscn "$out/open_fall_18.png" 534 --autopilot=1 --hud=0 --side_view=lee,15,10 --fall=8 --settings="$s"
	# The strongest wind, 30 kt on the open water, follow camera: the spray blown off the crests.
	s30="$(settings_for 30)"
	shot res://main.tscn "$out/crest_30.png" 600 "${follow[@]}" --settings="$s30"
	# Landings on the lake at x1.65 (30 kt): a picture every 12 frames from 7 s; the sheet picks one.
	shot "$lake" "$out/lake_landing_30.png" 420 "${side[@]}" --lake_wind_scale=1.65 --sequence=12 --every=12
fi
if [[ "$which" == "wide" || "$which" == "all" ]]; then
	s24="$(settings_for 24)"
	shot res://main.tscn "$out/wide_open_follow_24.png" 600 "${follow[@]}" --settings="$s24" --resolution=3137x1263
	shot "$lake" "$out/wide_lake_side_24.png" 600 "${side[@]}" --lake_wind_scale=1.32 --resolution=3137x1263
fi
echo "Pictures in $out"
