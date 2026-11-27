#!/usr/bin/env bash
# The reality check for the TV director (Documentation/reports/broadcast/tv_director_stream.md): watched
# races run without a window, the TV director on, every take written down with the framing it really had
# (the sail's and the horizon's place measured from the camera and the board, the camera's height,
# distance and angle), then set beside the real stream (Documentation/reports/broadcast/data/
# stream_profile.json) by tools/broadcast/director_check.py, per phase of a heat. The report:
# .sim_output/tv_check/<run>/report.md.
#
#   tools/tv_check.sh                          3 races on the open water's sprint slalom (PD3 at 60 %)
#   tools/tv_check.sh --races=5 --seed=7       5 races, the first race's dice 7 (the next ones 8, 9, ...)
#   tools/tv_check.sh --director=12nov         the director of 12 November, for comparing
#   tools/tv_check.sh --map=lake               on Lake Silvaplana (T2 sprint slalom; the beach cam on the shore)
#   tools/tv_check.sh --map=res://maps/<spot>/<scene>.tscn --course=<name>    any map's sailing scene
#   tools/tv_check.sh --report_only=1 --run=<name>    the report again from a run's logs
#
# Options: --map=open|lake|<a map's sailing scene, res://...tscn> (default open: the open water),
# --run=<name> (default: stream or 12nov), --course=<name> (default template:PD3@60 on the open water,
# t2_slalom on the lake; a map scene: one of its own courses), --skippers=<a,b,...> (default eight: the stream's heats have 8), --wind=<kt>,
# --threads=<n> (default 0: the boards one after the other on one core, the PC is shared), --gap=<s> (after the race until the next countdown,
# default 45). One race after the other, one Godot at a time; a race of about 5 minutes takes about
# 5 to 8 minutes. Each race's log: .sim_output/tv_check/<run>/race_<n>.csv.
set -euo pipefail
source "$(dirname "$0")/common.sh"

races=3
seed=1
director="stream"
map="open"
course=""
skippers="allrounder,cautious,gambler,rookie,allrounder,cautious,gambler,rookie"
wind=""
threads=0
gap=45
run=""
report_only=0
for option in "$@"; do
	case "$option" in
		--races=*) races="${option#--races=}" ;;
		--seed=*) seed="${option#--seed=}" ;;
		--director=*) director="${option#--director=}" ;;
		--map=*) map="${option#--map=}" ;;
		--course=*) course="${option#--course=}" ;;
		--skippers=*) skippers="${option#--skippers=}" ;;
		--wind=*) wind="${option#--wind=}" ;;
		--threads=*) threads="${option#--threads=}" ;;
		--gap=*) gap="${option#--gap=}" ;;
		--run=*) run="${option#--run=}" ;;
		--report_only=*) report_only="${option#--report_only=}" ;;
		*) echo "Unknown option $option" >&2; exit 2 ;;
	esac
done
[[ -n "$run" ]] || run="$director"
scene="res://main.tscn"
if [[ "$map" == "lake" ]]; then
	scene="res://maps/silvaplana/sail_silvaplana.tscn"
	[[ -n "$course" ]] || course="t2_slalom"
elif [[ "$map" == res://* ]]; then
	scene="$map"
	[[ -n "$course" ]] || { echo "A map scene needs --course=<one of its courses>" >&2; exit 2; }
fi
[[ -n "$course" ]] || course="template:PD3@60"
out_dir="$REPO_ROOT/.sim_output/tv_check/$run"
mkdir -p "$out_dir" "$REPO_ROOT/.logs/tv_check"

if [[ "$report_only" != "1" ]]; then
	godot="$(find_godot)"
	import_project "$godot"
	for ((i = 0; i < races; i++)); do
		dice=$((seed + i))
		log="$out_dir/race_$((i + 1)).csv"
		extra=()
		[[ -n "$wind" ]] && extra+=("--wind=$wind")
		echo "Race $((i + 1)) of $races (dice $dice) ..."
		# A frame is 1/60 s of the race (--fixed-fps): the director's clock is the picture's. The game ends
		# itself once the race has been filmed to the next countdown; --quit-after is the safety net.
		status=0
		timeout 3600 "$godot" --headless --no-header --fixed-fps 60 --path "$PROJECT_DIR" --quit-after 72000 "$scene" -- \
			--settings=defaults --course="$course" --skippers="$skippers" --seed="$dice" --spectate=1 --tv=1 \
			--tv_director="$director" --tv_log="$log" --tv_log_races=1 --tv_seed="$dice" \
			--director_gap="$gap" --threads="$threads" "${extra[@]}" \
			>"$REPO_ROOT/.logs/tv_check/${run}_race_$((i + 1)).log" 2>&1 || status=$?
		grep -E "SCRIPT ERROR|^ERROR|TV LOG" "$REPO_ROOT/.logs/tv_check/${run}_race_$((i + 1)).log" 2>/dev/null | grep -v "resources still in use" || true
		if [[ $status -ne 0 ]]; then echo "Race $((i + 1)) ended with exit code $status (log: .logs/tv_check/${run}_race_$((i + 1)).log)" >&2; fi
	done
fi

python -I "$REPO_ROOT/tools/broadcast/director_check.py" "$out_dir" \
	--profile="$REPO_ROOT/Documentation/reports/broadcast/data/stream_profile.json" --out="$out_dir/report.md"
