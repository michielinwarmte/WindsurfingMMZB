#!/usr/bin/env bash
# The wind on the water at five strengths (wind_on_water.md): the same views of Lake Silvaplana with the
# lake wind multiplier (--lake_wind_scale) and of the open water with the settings' wind (a settings file
# per wind), saved under .screenshots/wind_on_water/. Run from the repository's root, with GODOT set:
#   Documentation/reports/waves/wind_on_water/shoot.sh [lake|open|wide|all]
# Then python -I Documentation/reports/waves/wind_on_water/sheet.py makes the contact sheets.
set -euo pipefail
which="${1:-all}"
out=".screenshots/wind_on_water"
mkdir -p "$out"
# The lake's multipliers for 8, 12, 18, 24 and 30 kt at 10 m at 14:30 (the measured day: 18.2 kt).
lake_scales=(0.44 0.66 1.0 1.32 1.65)
knots=(8 12 18 24 30)
lake="res://maps/silvaplana/sail_silvaplana.tscn"
# The views: the follow camera behind the board at the start; 40 m up at the camping beach looking down
# the lake toward a gust coming (last night's view 5).
near=(--autopilot=1 --camera=1 --hud=0)
high=(--autopilot=1 --hud=0 --overview=2781250,1147300,40 --overview_look=2780300,1146150)

if [[ "$which" == "lake" || "$which" == "all" ]]; then
	for i in 0 1 2 3 4; do
		tools/screenshot.sh "$lake" "$out/lake_near_${knots[$i]}.png" 300 "${near[@]}" --lake_wind_scale="${lake_scales[$i]}" > /dev/null
		tools/screenshot.sh "$lake" "$out/lake_high_${knots[$i]}.png" 300 "${high[@]}" --lake_wind_scale="${lake_scales[$i]}" > /dev/null
	done
fi
if [[ "$which" == "open" || "$which" == "all" ]]; then
	for i in 0 1 2 3 4; do
		settings="$out/open_${knots[$i]}.cfg"
		printf '[wind]\nspeed_kt=%s\n' "${knots[$i]}" > "$settings"
		tools/screenshot.sh res://main.tscn "$out/open_near_${knots[$i]}.png" 300 "${near[@]}" --settings="$(pwd)/$settings" > /dev/null
		tools/screenshot.sh res://main.tscn "$out/open_high_${knots[$i]}.png" 300 --autopilot=1 --hud=0 --camera=4 --settings="$(pwd)/$settings" > /dev/null
	done
fi
if [[ "$which" == "wide" || "$which" == "all" ]]; then
	tools/screenshot.sh "$lake" "$out/wide_lake_near_24.png" 300 "${near[@]}" --lake_wind_scale=1.32 --resolution=3137x1263 > /dev/null
	tools/screenshot.sh "$lake" "$out/wide_lake_high_30.png" 300 "${high[@]}" --lake_wind_scale=1.65 --resolution=3137x1263 > /dev/null
fi
echo "Pictures in $out"
