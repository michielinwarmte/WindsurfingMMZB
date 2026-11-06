#!/usr/bin/env bash
# LAN multiplayer's check with two game instances on this PC (Documentation/reports/multiplayer/PLAN.md):
# a host and a guest connect through 127.0.0.1 and race (or sail free) headless. Each prints, every
# 30 host ticks, the boards it sails (TRACK) and what it shows of the other PC's boards (SEEN), and
# at the end of a race both PCs' results; tools/lan/check_sync.py then compares them: the place,
# heading, speed, mast and lean each PC shows of a board against what the PC that sails it had at that
# same tick, and the two finish lists.
#
#   tools/lan_test.sh [--seconds=40] [--mode=race|free] [--map=open|lake] [--skippers=allrounder,rookie|none] [--lake_wave_scale=1.5]
#                     [--prestart=20] [--robot=allrounder] [--release=1]
#
# --robot=<skipper> lets a scripted skipper sail both players' boards (so a race can finish; without
# it the two boards sail straight on). --release=1 runs the exported game (tools/release.sh build).
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
lake_wave_scale=""
for arg in "$@"; do
	case "$arg" in
		--seconds=*) seconds="${arg#*=}" ;;
		--mode=*) mode="${arg#*=}" ;;
		--map=*) map="${arg#*=}" ;;
		--skippers=*) skippers="${arg#*=}" ;;
		--prestart=*) prestart="${arg#*=}" ;;
		--robot=*) robot="${arg#*=}" ;;
		--release=*) release="${arg#*=}" ;;
		--lake_wave_scale=*) lake_wave_scale="${arg#*=}" ;;
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
# Both PCs sail the lake's waves at the same height (PHYSICS_SPEC.md 9.18).
if [[ -n "$lake_wave_scale" ]]; then common+=(--lake_wave_scale="$lake_wave_scale"); fi

host_quit=$((seconds + 4))
"${run[@]}" -- "${common[@]}" --lan_host=Host --lan_mode="$mode" --lan_map="$map" --lan_skippers="$skippers" \
	--lan_prestart="$prestart" --lan_quit="$host_quit" > "$logs/host.log" 2>&1 &
host_pid=$!
sleep 3
"${run[@]}" -- "${common[@]}" --lan_join=127.0.0.1 --lan_name=Guest --lan_quit="$seconds" > "$logs/guest.log" 2>&1 || true
wait "$host_pid" || true
python -I "$repo/tools/lan/check_sync.py" "$logs/host.log" "$logs/guest.log"
