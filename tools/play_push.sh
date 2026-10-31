#!/usr/bin/env bash
# The push dial's playtest: sail with the dial pushed and feel where it pays and where it
# catapults (Documentation/reports/autopilot/autopilot_rework.md, section 3 and 7; the dial's
# numbers are Game/sim/push_dial.gd). Until GP1 puts the dial on a key, this is how to sail it.
#
# The open water, 24 kt from the West with gusts (0.2 every 8 s) and the waves, beginner mode with
# the auto-sheet, starting on starboard tack heading 150 (a 120 degree reach). The dial:
#   pushed   the sailor holds 1.6 of the hike's pull and leans the rig 35 degrees to windward:
#            faster across the wind, a catapult waiting on the broad reach (heading 210 to 225);
#   neutral  1.0 and 25 degrees, the autopilot's own numbers (the comparison);
#   eased    0.8 and 25 degrees.
# Keep the reach with A/D and wait for the gusts. The detail panel (F1) shows live:
#   - its second line: which dial setting is sailed;
#   - "feet overload ... toward the sail": the pull the feet cannot hold, which tips you over;
#   - "fin ... load .. % of stall": the fin's load;
#   - "yaw rate", "pitch" and "heel" (the bow turning, the nose, the rail);
# and after a fall, at its bottom, the table "LAST FALL": the same numbers 1 s and 0.5 s before it
# and just before it, frozen until the next fall. Esc pauses, R waterstarts at once.
#
#   tools/play_push.sh                         24 kt, gusts 0.2, the dial pushed
#   tools/play_push.sh --dial=neutral          the same wind at the dial's middle (compare)
#   tools/play_push.sh --wind=18 --gusts=0.3   another wind; --heading=<deg> another course
#   tools/play_push.sh --push=1                GP0's older "pushed" margin instead of the dial: the
#                                              same pull plus the late ease, which the suite found
#                                              catapults the close reach (gp0_measure.md)
#
# The settings are written to .sim_output/playtest/push.cfg each time (the game also saves to it
# if you change a setting in the menu); your own settings file is not touched.
set -euo pipefail
source "$(dirname "$0")/common.sh"

wind=24
gusts=0.2
dial=pushed
push=0
heading=150
for arg in "$@"; do
	case "$arg" in
		--wind=*) wind="${arg#--wind=}" ;;
		--gusts=*) gusts="${arg#--gusts=}" ;;
		--dial=*) dial="${arg#--dial=}" ;;
		--push=*) push="${arg#--push=}"; dial="" ;;
		--heading=*) heading="${arg#--heading=}" ;;
		*) echo "Unknown option $arg (see the header of $0)" >&2; exit 1 ;;
	esac
done

cfg="$REPO_ROOT/.sim_output/playtest/push.cfg"
mkdir -p "$(dirname "$cfg")"
cat > "$cfg" <<CFG
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
CFG
# Godot on Windows wants C:/... rather than /c/...
if command -v cygpath >/dev/null 2>&1; then
	cfg="$(cygpath -m "$cfg")"
fi
options=("--settings=$cfg")
if [[ -n "$dial" ]]; then options+=("--dial=$dial"); fi
if [[ "$push" == "1" ]]; then options+=("--push=1"); fi
exec "$REPO_ROOT/tools/play.sh" res://main.tscn "${options[@]}"
