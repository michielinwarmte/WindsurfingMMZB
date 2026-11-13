#!/usr/bin/env bash
# An interim build from the lake tuner in one step (Documentation/reports/autopilot/lake_speed/README.md):
# puts the current best.txt into PlayerController.NIGHT_TUNING (the player's board only), runs the
# night-tuning and lake unit tests and the load check, commits it, builds the release
# (tools/release.sh build) and makes the play folder
# C:/Users/Max de Dikke/source/WindsurfingMMZB-play-7nov2026-lake-<hhmm> with the morning folder's
# launchers, cfgs and README. The running tuner is not disturbed (it sails its own frozen copy).
#
#   tools/lake_tuner_apply.sh [--no_commit=1]
set -euo pipefail
source "$(dirname "$0")/common.sh"
cd "$REPO_ROOT"

python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
best="Documentation/reports/autopilot/lake_speed/best.txt"
"$python_bin" -I tools/lake_tuner_apply.py "--best=$best"
tools/test.sh unit -gselect=test_night_tuning
tools/test.sh unit -gselect=test_controller_lake_speed
tools/check.sh
if [ "${1:-}" != "--no_commit=1" ]; then
	git add Game/windsurfer/player_controller.gd "$best"
	candidate="$(grep -o 'candidate c[0-9]*' "$best" | head -1)"
	git commit -m "The lake tuner's best set on the player's board (NIGHT_TUNING, $candidate)

From Documentation/reports/autopilot/lake_speed/best.txt by tools/lake_tuner_apply.sh; the AI fleet
keeps the code's defaults.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
fi
tools/release.sh build
stamp="$(date +%H%M)"
morning="/c/Users/Max de Dikke/source/WindsurfingMMZB-play-7nov2026-morning"
folder="/c/Users/Max de Dikke/source/WindsurfingMMZB-play-7nov2026-lake-$stamp"
mkdir -p "$folder"
cp .release/wsim.exe .release/wsim_console.exe .release/wsim.pck "$folder/"
cp "$morning"/*.bat "$morning"/*.cfg "$morning"/README.txt "$folder/"
{
	echo ""
	echo "Lake tuning ($(date '+%d %B %Y %H:%M')): the player's board sails the lake tuner's best set"
	echo "(Settings > Sailing > Night-tuned steering; off: the code's own numbers). Commit $(git rev-parse --short HEAD)."
} >> "$folder/README.txt"
echo "Play folder: $folder"
