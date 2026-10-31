#!/usr/bin/env bash
# The gear's contact sheets: every item of the gear table (tools/blender/gear_set.py, as built in
# Game/assets/models/gear/gear_set.json) drawn by the gear view (Game/dev/gear_view.tscn) and put
# together with ImageMagick:
#
#   .screenshots/gear/<brand slug>.png   the brand's boards (from above, from below, from the
#                                        starboard side) and sails (from the port side: the prints
#                                        read; from the starboard side: they show mirrored)
#   .screenshots/gear/all_boards.png     every board from above and from below
#   .screenshots/gear/all_sails.png      every sail from the port side
#   .screenshots/gear/views/             the single pictures
#
# Usage: tools/gear/contact_sheets.sh [--brand=<slug>] [--gamescope]
#   --brand=<slug>  one brand only (the "all" sheets are then left as they are)
#   --gamescope     draws in a headless gamescope session: when the screens are off or locked, a
#                   game window gets no frames and the view waits for ever (Linux only)
# Needs ImageMagick 7 (magick). Takes about a minute per brand.
set -euo pipefail
source "$(dirname "$0")/../common.sh"

brand_wanted=""
use_gamescope=0
for arg in "$@"; do
	case "$arg" in
		--brand=*) brand_wanted="${arg#--brand=}" ;;
		--gamescope) use_gamescope=1 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

out="$REPO_ROOT/.screenshots/gear"
views="$out/views"
mkdir -p "$views"
table="$PROJECT_DIR/assets/models/gear/gear_set.json"
python="$(command -v python3 || command -v python)"

# The items of one brand and kind, comma-separated.
items_of() {
	"$python" -I -c 'import json, sys
table = json.load(open(sys.argv[1], encoding="utf-8"))
print(",".join(i["id"] for i in table if i["brand"] == sys.argv[2] and i["kind"] == sys.argv[3]))' "$table" "$1" "$2"
}

brands="$("$python" -I -c 'import json, sys
table = json.load(open(sys.argv[1], encoding="utf-8"))
print(" ".join(dict.fromkeys(i["brand"] for i in table if i["kind"] != "fin")))' "$table")"

draw() {   # draw <items>: the gear view's pictures of these items into $views
	local shot=(tools/screenshot.sh res://dev/gear_view.tscn "$views/last.png" 20000 "--items=$1")
	if [[ $use_gamescope -eq 1 ]]; then
		gamescope --backend headless -w 1280 -h 720 -W 1280 -H 720 -- "${shot[@]}"
	else
		"${shot[@]}"
	fi
}

label_args() {   # label_args <items> <views...>: "-label <id view> <file>" for montage
	local items="$1"; shift
	local id view
	for id in ${items//,/ }; do
		for view in "$@"; do
			printf '%s\n' -label "$id $view" "$views/${id}_${view}.png"
		done
	done
}

background="#E6EDF3"
for brand in $brands; do
	[[ -n "$brand_wanted" && "$brand" != "$brand_wanted" ]] && continue
	boards="$(items_of "$brand" board)"
	sails="$(items_of "$brand" sail)"
	all="${boards}${boards:+${sails:+,}}${sails}"
	echo "== $brand: $all"
	(cd "$REPO_ROOT" && draw "$all")
	parts=()
	if [[ -n "$boards" ]]; then
		mapfile -t args < <(label_args "$boards" deck bottom side)
		magick montage "${args[@]}" -tile 3x -geometry 860x+6+6 -pointsize 22 -background "$background" "$out/${brand}_boards.png"
		parts+=("$out/${brand}_boards.png")
	fi
	if [[ -n "$sails" ]]; then
		mapfile -t args < <(label_args "$sails" port starboard)
		magick montage "${args[@]}" -tile 10x -geometry +6+6 -pointsize 22 -background "$background" "$out/${brand}_sails.png"
		parts+=("$out/${brand}_sails.png")
	fi
	magick "${parts[@]}" -background "$background" -gravity center -append -resize '2600x>' "$out/$brand.png"
	echo "Sheet: $out/$brand.png"
done

if [[ -z "$brand_wanted" ]]; then
	all_boards="$("$python" -I -c 'import json, sys
print(",".join(i["id"] for i in json.load(open(sys.argv[1], encoding="utf-8")) if i["kind"] == "board"))' "$table")"
	all_sails="$("$python" -I -c 'import json, sys
print(",".join(i["id"] for i in json.load(open(sys.argv[1], encoding="utf-8")) if i["kind"] == "sail"))' "$table")"
	mapfile -t args < <(label_args "$all_boards" deck bottom)
	magick montage "${args[@]}" -tile 4x -geometry 640x+4+4 -pointsize 16 -background "$background" "$out/all_boards.png"
	mapfile -t args < <(label_args "$all_sails" port)
	magick montage "${args[@]}" -tile 12x -geometry 235x+4+4 -pointsize 12 -background "$background" "$out/all_sails.png"
	echo "Sheets: $out/all_boards.png, $out/all_sails.png"
fi
