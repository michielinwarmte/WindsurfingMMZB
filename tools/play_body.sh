#!/usr/bin/env bash
# Package B's playtest: the sailor's body on the mouse (an experiment, ROADMAP GP2; the report and the
# checklist are in Documentation/reports/gameplay/gp2_mouse_body.md).
#
# The mouse is captured while you sail and is the sailor's body; the feet stay in the straps and the
# mouse is how they press (the feet's press, 6 November 2026: gp2_feet_pressure.md):
#   - sideways: the toes against the heels (the toes put the leeward rail down; the heels the other
#     way bring the board flat);
#   - pull it back (toward you): the weight onto the back foot, the nose lifts (faster, until it
#     bounces, and at 24 kt a catapult); push it forward: the weight onto the front foot.
# Leave it in the middle and the sailor sails with their own technique, as before. It works only
# planing in the footstraps and not in a turn; it comes back to the middle at every tack, gybe and
# fall. Esc frees the mouse (the pause menu), and Esc > Settings > Body switches Max's choices while
# sailing. Hold the right mouse button or C to look around with the orbit camera (key 2; with it held
# the wheel zooms). The push is on the mouse too (gp2_push_on_mouse.md): the wheel moves it in steps
# of 10 % (up is more) and the left button held is a burst to 100 % that comes back to your level when
# you let go; W/S still move it, Up/Down sheet, A/D steer. F1 shows the numbers (for tuning only; the
# strip shows none).
#
# The open water, 18 kt from the West with gusts (0.2 every 8 s) and the waves, beginner mode with the
# auto-sheet, starting on starboard tack heading 180 (a beam reach, where the board gets planing), the
# push slider at 75 % (the game's start). Once planing, bear away (A, away from the wind) to a broad
# reach, heading about 135: from rest the board does not get over the hump there (GP11).
#
#   tools/play_body.sh                          18 kt beam reach, the defaults
#   tools/play_body.sh --wind=24                24 kt: too much back foot on a flat board bounces and falls
#   tools/play_body.sh --heading=150            start on another course (compass degrees)
#   tools/play_body.sh --level=2                the feet correct slowly: your hand holds the rail
#   tools/play_body.sh --centre=spring          the mouse springs back to the middle (--spring=<s>)
#   tools/play_body.sh --sideways=right         right is always more rail (default: the board rolls
#                                               with the mouse, as seen from behind)
#   tools/play_body.sh --windward=1             the far side goes on to a windward rail
#   tools/play_body.sh --weight=0.5             a gentler back foot (half the weight at the end; default all)
#   tools/play_body.sh --toes=0.5               gentler toes and heels (half the feet's roll moment at
#                                               the end; default all of it)
#   tools/play_body.sh --travel=500             a slower mouse (pixels from end to end; default 300)
#   tools/play_body.sh --push=100 --gusts=0.3   the slider and the gusts as in tools/play_push.sh
#   tools/play_body.sh --push_mouse=wheel       the push on the mouse: off (W/S only), wheel, or
#                                               button (the wheel and the left button's burst, default)
#   tools/play_body.sh --push_step=0.05         the wheel's step a notch (0.05 to 0.25; default 0.1)
#   tools/play_body.sh --body=0                 the same water without the body, to compare
#
# The settings are written to .sim_output/playtest/body.cfg each time (the game also saves to it if
# you change a setting in the menu); your own settings file is not touched.
set -euo pipefail
source "$(dirname "$0")/common.sh"

wind=18
gusts=0.2
push=75
heading=180
body=true
level=1
centre=0
spring=1.5
sideways=0
windward=false
toes=1.0
weight=1.0
travel=300
push_mouse=2
push_step=0.1
for arg in "$@"; do
	case "$arg" in
		--wind=*) wind="${arg#--wind=}" ;;
		--gusts=*) gusts="${arg#--gusts=}" ;;
		--push=*) push="${arg#--push=}" ;;
		--heading=*) heading="${arg#--heading=}" ;;
		--body=0) body=false ;;
		--body=1) body=true ;;
		--level=*) level="${arg#--level=}" ;;
		--centre=stays) centre=0 ;;
		--centre=spring) centre=1 ;;
		--spring=*) spring="${arg#--spring=}" ;;
		--sideways=seen) sideways=0 ;;
		--sideways=right) sideways=1 ;;
		--windward=1) windward=true ;;
		--windward=0) windward=false ;;
		--weight=*) weight="${arg#--weight=}" ;;
		--toes=*) toes="${arg#--toes=}" ;;
		--travel=*) travel="${arg#--travel=}" ;;
		--push_mouse=off) push_mouse=0 ;;
		--push_mouse=wheel) push_mouse=1 ;;
		--push_mouse=button) push_mouse=2 ;;
		--push_step=*) push_step="${arg#--push_step=}" ;;
		*) echo "Unknown option $arg (see the header of $0)" >&2; exit 1 ;;
	esac
done

cfg="$REPO_ROOT/.sim_output/playtest/body.cfg"
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
show_hud_panel=false

[body]
mouse_body=$body
centre=$centre
spring_s=$spring
sideways=$sideways
windward_rail=$windward
toes_share=$toes
weight_share=$weight
travel_px=$travel
level=$level
push_on_mouse=$push_mouse
push_step=$push_step
CFG
# Godot on Windows wants C:/... rather than /c/...
if command -v cygpath >/dev/null 2>&1; then
	cfg="$(cygpath -m "$cfg")"
fi
exec "$REPO_ROOT/tools/play.sh" res://main.tscn "--settings=$cfg" "--push=$push"
