#!/usr/bin/env bash
# LAN multiplayer's check with two game instances on this PC (Documentation/reports/multiplayer/PLAN.md):
# a host and a guest connect through 127.0.0.1 and race (or sail free) headless. Each prints, every
# 30 host ticks, the boards it sails (TRACK) and what it shows of the other PC's boards (SEEN), and
# at the end of a race both PCs' results; tools/lan/check_sync.py then compares them: the place,
# heading, speed, mast and lean each PC shows of a board against what the PC that sails it had at that
# same tick, and the two finish lists.
#
#   tools/lan_test.sh [--seconds=40] [--mode=race|free] [--map=open|lake] [--skippers=allrounder,rookie|none] [--lake_wave_scale=1.5]
#                     [--prestart=20] [--robot=allrounder] [--release=1] [--body=1,0.67]
#                     [--guests=1] [--late=0] [--time_limit=0] [--director_gap=0] [--host_options="--x=1 --y=2"]
#                     [--spectate=0] [--retire_at=-1]
#
# --guests=<n> joins that many guests (up to 7; RACE_DIRECTOR.md R1); --late=<s> lets the last of them
# join that many seconds after the others, while the game runs (R2). --time_limit=<s> ends each race
# that long after its gun and --director_gap=<s> starts the next countdown that long after a race
# ends (R4: a race after a race); --host_options passes more options to the host only (the race
# director's scripted changes, --director_move=...). The sync check runs for every pair of PCs.
#
# Spectating (Documentation/reports/multiplayer/spectate_6nov.md): --spectate=<n> lets the n-th guest
# join as a spectator (no board in the race; its camera goes to the next racer every 3 s, as Tab);
# the check then wants it to have seen every board and the others to have drawn none of it.
# --retire_at=<s> lets the first guest choose Spectate at that race time (it retires: every PC's
# finish list says "retired"). The host spectates with --host_options="--lan_spectate=1 --lan_tab_every=3".
#
# --robot=<skipper> lets a scripted skipper sail both players' boards (so a race can finish; without
# it the two boards sail straight on). --release=1 runs the exported game (tools/release.sh build).
# --body=<side>,<back> puts both players' boards on the body on the mouse (package B, GP2), held there
# by script (each -1 to 1: main.gd's --body); the check then also shows the rail and the trim the feet
# aimed for and how they pressed (the feet's press), as each PC sent them and the other showed them.
# The logs are in .logs/lan/host.log and .logs/lan/guest.log.
set -euo pipefail
source "$(dirname "$0")/common.sh"

seconds=40
mode=race
map=open
skippers="allrounder,rookie"
prestart=20
robot=""
release=0
body=""
lake_wave_scale=""
guests=1
late=0
time_limit=0
director_gap=0
host_options=""
spectate=0
retire_at=""
for arg in "$@"; do
	case "$arg" in
		--seconds=*) seconds="${arg#*=}" ;;
		--mode=*) mode="${arg#*=}" ;;
		--map=*) map="${arg#*=}" ;;
		--skippers=*) skippers="${arg#*=}" ;;
		--prestart=*) prestart="${arg#*=}" ;;
		--robot=*) robot="${arg#*=}" ;;
		--release=*) release="${arg#*=}" ;;
		--body=*) body="${arg#*=}" ;;
		--lake_wave_scale=*) lake_wave_scale="${arg#*=}" ;;
		--guests=*) guests="${arg#*=}" ;;
		--late=*) late="${arg#*=}" ;;
		--time_limit=*) time_limit="${arg#*=}" ;;
		--director_gap=*) director_gap="${arg#*=}" ;;
		--host_options=*) host_options="${arg#*=}" ;;
		--spectate=*) spectate="${arg#*=}" ;;
		--retire_at=*) retire_at="${arg#*=}" ;;
		*) echo "Unknown option $arg" >&2; exit 2 ;;
	esac
done

repo="$(cd "$(dirname "$0")/.." && pwd)"
logs="$repo/.logs/lan"
mkdir -p "$logs"
if [[ "$release" == "1" ]]; then
	exe="$repo/.release/wsim_console.exe"; [[ -f "$exe" ]] || exe=""
	if [[ -z "$exe" ]]; then echo "No release build in .release/ (tools/release.sh build)." >&2; exit 1; fi
	run=("$exe" --headless)
else
	godot="$(find_godot)"
	import_project "$godot"
	run=("$godot" --headless --path "$PROJECT_DIR")
fi
common=(--settings=defaults --lan_report=10 --lan_track=30)
if [[ -n "$robot" ]]; then common+=(--lan_robot="$robot"); fi
if [[ -n "$body" ]]; then common+=(--body="$body"); fi
# Both PCs sail the lake's waves at the same height (PHYSICS_SPEC.md 9.18).
if [[ -n "$lake_wave_scale" ]]; then common+=(--lake_wave_scale="$lake_wave_scale"); fi

host_quit=$((seconds + 4))
host_extra=()
if [[ "$time_limit" != "0" ]]; then host_extra+=(--time_limit="$time_limit"); fi
if [[ "$director_gap" != "0" ]]; then host_extra+=(--director_gap="$director_gap"); fi
if [[ -n "$host_options" ]]; then read -r -a more <<< "$host_options"; host_extra+=("${more[@]}"); fi
# With several guests the host waits a little longer after the last one is ready, so the guests that
# do not join late are all in the game from its start.
if [[ $guests -gt 1 ]]; then host_extra+=(--lan_start=5); fi
"${run[@]}" -- "${common[@]}" --lan_host=Host --lan_mode="$mode" --lan_map="$map" --lan_skippers="$skippers" \
	--lan_prestart="$prestart" --lan_quit="$host_quit" "${host_extra[@]}" > "$logs/host.log" 2>&1 &
host_pid=$!
sleep 3
# The guests: guest.log for the first (as before), guest2.log ... for the others; the last of several
# joins --late seconds after the others, while the game runs.
guest_pids=()
guest_logs=()
for ((g = 1; g <= guests; g++)); do
	log="$logs/guest.log"
	name="Guest"
	if [[ $g -gt 1 ]]; then log="$logs/guest$g.log"; name="Guest$g"; fi
	guest_logs+=("$log")
	quit="$seconds"
	if [[ $g -eq $guests && $guests -gt 1 && "$late" != "0" ]]; then
		sleep "$late"
		quit=$((seconds - late))
	fi
	extra=()
	if [[ $g -eq $spectate ]]; then extra+=(--lan_spectate=1 --lan_tab_every=3); fi
	if [[ $g -eq 1 && -n "$retire_at" ]]; then extra+=(--lan_retire_at="$retire_at"); fi
	"${run[@]}" -- "${common[@]}" --lan_join=127.0.0.1 --lan_name="$name" --lan_quit="$quit" "${extra[@]}" > "$log" 2>&1 &
	guest_pids+=($!)
	sleep 1
done
for pid in "${guest_pids[@]}"; do wait "$pid" || true; done
wait "$host_pid" || true
status=0
for log in "${guest_logs[@]}"; do
	echo "=== host and $(basename "$log" .log)"
	python -I "$repo/tools/lan/check_sync.py" "$logs/host.log" "$log" || status=1
done
for ((a = 0; a < ${#guest_logs[@]}; a++)); do
	for ((b = a + 1; b < ${#guest_logs[@]}; b++)); do
		echo "=== $(basename "${guest_logs[$a]}" .log) and $(basename "${guest_logs[$b]}" .log)"
		python -I "$repo/tools/lan/check_sync.py" "${guest_logs[$a]}" "${guest_logs[$b]}" || status=1
	done
done
exit $status
