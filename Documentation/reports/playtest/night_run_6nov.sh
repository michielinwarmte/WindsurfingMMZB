#!/usr/bin/env bash
# The night run of 6 to 7 November 2026 (Documentation/reports/playtest/night_run_6nov.md): the AI
# fleet on every iQFOiL course by race type, the autopilot's reflex swept, the manoeuvres with the
# player's hands, the frame time on an idle PC, the validation suite with its names, and LAN on the
# release build with a spectator and a late joiner. Headless, unattended; nothing changes the code.
#
#   Documentation/reports/playtest/night_run_6nov.sh            run everything, in order
#   Documentation/reports/playtest/night_run_6nov.sh --only=A,C  only those parts (A to F)
#
# Every log lands in .logs/night_6nov/; 00_progress.txt says where it is. The summary at the end:
# python -I Documentation/reports/playtest/night_run_6nov.py (writes night_run_6nov_results.md).
set -u
cd "$(dirname "$0")/../../.."
export GODOT="${GODOT:-/c/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe}"
log=".logs/night_6nov"
mkdir -p "$log"
only="${1:-}"
only="${only#--only=}"
[[ -z "$only" ]] && only="A,B,C,D,E,F"
wanted() { [[ ",$only," == *",$1,"* ]]; }
note() { echo "$(date '+%H:%M:%S') $*" | tee -a "$log/00_progress.txt"; }
note "night run starts on $(git rev-parse --short HEAD) ($(git branch --show-current)); parts: $only"

P="persona:hana,persona:marco,persona:mara,persona:bruno,persona:liv,persona:aiko,persona:elin,persona:greta,persona:ines,persona:jonas,persona:kofi"

if wanted A; then
	note "A: the AI fleet on every iQFOiL course, by race type"
	for c in iq_pd3 iq_sd3 iq_lg2 iq_lr2 iq_o2 iq_i2 iq_us3 iq_us4 iq_pm1 iq_sm1; do
		tools/race.sh --course=$c --map=lake --skippers=$P --seed=1 --finish_window=600 > "$log/race_$c.log" 2>&1
		note "A: $c done (exit $?)"
	done
	tools/race.sh --course=t2_slalom --skippers=$P --seed=1 --finish_window=600 --wind_kt=18 > "$log/race_t2_slalom.log" 2>&1
	note "A: t2_slalom done (exit $?)"
	tools/race.sh --course=t1_loop --skippers=$P --seed=1 --finish_window=600 --wind_kt=18 > "$log/race_t1_loop.log" 2>&1
	note "A: t1_loop done (exit $?)"
fi

if wanted B; then
	note "B: the autopilot's recovery reflex swept (lake and matrix)"
	tools/autopilot_suite.sh --round=night6nov_reflex --variants=Documentation/reports/autopilot/rounds/night6nov_reflex.txt --only=lake,matrix --cores=10 > "$log/reflex_suite.log" 2>&1
	note "B: suite done (exit $?)"
	python -I tools/autopilot_summary.py night6nov_reflex --table > "$log/reflex_table.txt" 2>&1
	note "B: table done (exit $?)"
fi

if wanted C; then
	note "C: the manoeuvres with the player's hands at 24 kt"
	tools/matrix.sh --winds=24 --hold_turn --body_carve --body_back --cue > "$log/matrix_all_24.log" 2>&1
	note "C: all at once done (exit $?)"
	tools/matrix.sh --winds=24 --hold_turn --body_carve --cue > "$log/matrix_no_back_foot_24.log" 2>&1
	note "C: without the back foot done (exit $?)"
	tools/matrix.sh --winds=24 --hold_turn --body_back --cue > "$log/matrix_no_carve_24.log" 2>&1
	note "C: without the carve done (exit $?)"
fi

if wanted D; then
	note "D: the frame time on an idle PC (the release pack in .release/)"
	tools/fleet_measure.sh --sizes=12,20 --seconds=12 --course=t1_loop > "$log/fps_open.log" 2>&1
	note "D: open water done (exit $?)"
	tools/release.sh --mute --race=iq_o2 --map=lake --skippers=$P --measure=12 > "$log/fps_lake_12.log" 2>&1
	note "D: lake 12 boards done (exit $?)"
	tools/release.sh --mute --race=iq_o2 --map=lake --skippers=$P --measure=12 --render_size=3137x1263 > "$log/fps_lake_12_wide.log" 2>&1
	note "D: lake 12 boards wide done (exit $?)"
fi

if wanted E; then
	note "E: the validation suite"
	tools/test.sh validation > "$log/validation.log" 2>&1
	note "E: validation done (exit $?)"
fi

if wanted F; then
	note "F: LAN on the release build"
	tools/lan_test.sh --map=lake --seconds=40 --release=1 > "$log/lan_lake.log" 2>&1
	note "F: lake done (exit $?)"
	tools/lan_test.sh --map=lake --guests=2 --spectate=1 --late=20 --time_limit=25 --director_gap=5 --robot=allrounder --prestart=10 --seconds=90 --release=1 > "$log/lan_lake_spectate_late.log" 2>&1
	note "F: lake with a spectator and a late joiner done (exit $?)"
fi

python -I Documentation/reports/playtest/night_run_6nov.py > "$log/summary.log" 2>&1
note "summary written (exit $?): Documentation/reports/playtest/night_run_6nov_results.md"
note "night run done"
