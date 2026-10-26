#!/usr/bin/env bash
# GP0's playtest: sail into catapults yourself and see what warns (point 4 of
# Documentation/reports/gameplay/gp0_measure.md: before a catapult the sailor strains and the board
# rounds up into the wind; the fin does not warn).
#
# The open water, 24 kt from the West with gusts (0.2 every 8 s) and the waves, beginner mode with
# the auto-sheet, starting on starboard tack heading 150 (a 120 degree reach), with your sailor
# holding the push dial's top as GP0 measured it (--push=1: more pull held, easing late). Keep the
# reach with A/D and wait for the gusts. The detail panel (F1) shows live:
#   - "feet overload ... toward the sail": the pull the feet cannot hold, which tips you over;
#   - "fin ... load .. % of stall": the fin's load;
#   - "yaw rate", "pitch" and "heel" (the bow turning, the nose, the rail);
# and after a fall, at its bottom, the table "LAST FALL": the same numbers 1 s and 0.5 s before it
# and just before it, frozen until the next fall. Esc pauses, R waterstarts at once.
#
#   tools/play_push.sh                         24 kt, gusts 0.2, pushed
#   tools/play_push.sh --push=0                the same wind with 0.1's own sailor (compare)
#   tools/play_push.sh --wind=18 --gusts=0.3   another wind; --heading=<deg> another course
#
# The settings are written to .sim_output/playtest/push.cfg each time (the game also saves to it
# if you change a setting in the menu); your own settings file is not touched.
set -euo pipefail
source "$(dirname "$0")/common.sh"

wind=24
gusts=0.2
push=1
heading=150
for arg in "$@"; do
	case "$arg" in
		--wind=*) wind="${arg#--wind=}" ;;
		--gusts=*) gusts="${arg#--gusts=}" ;;
		--push=*) push="${arg#--push=}" ;;
		--heading=*) heading="${arg#--heading=}" ;;
		*) echo "Unknown option $arg (see the header of $0)" >&2; exit 1 ;;
	esac
done

cfg="$REPO_ROOT/.sim_output/playtest/push.cfg"
mkdir -p "$(dirname "$cfg")"
cat > "$cfg" <<EOF
[wind]
speed_kt=$wind
from_deg=270.0
gusts_enabled=true
gust_intensity=$gusts
gust_period_s=8.0
shifts_enabled=false

[waves]
enabled=true

[sailing]
control_mode=0
auto_sheet=true
start_heading_deg=$heading
show_hud_panel=true
EOF
# Godot on Windows wants C:/... rather than /c/...
if command -v cygpath >/dev/null 2>&1; then
	cfg="$(cygpath -m "$cfg")"
fi
exec "$REPO_ROOT/tools/play.sh" res://main.tscn "--settings=$cfg" "--push=$push"
