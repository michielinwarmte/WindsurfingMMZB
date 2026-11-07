#!/usr/bin/env bash
# The night tuner (tools/night_tuner.py), run on a frozen copy of Game/ so the worktree can be edited
# while it runs: the copy is made once in .sim_output/night7nov/project (rm -r it to copy afresh).
# Resumable: run it again and it carries on from .sim_output/night7nov/tuner_state.json; stop it with
# touch .sim_output/night7nov/STOP. Output: .sim_output/night7nov/tuner.log, leaderboard.md, and
# Documentation/reports/autopilot/night_7nov/best.txt.
#
#   tools/night_tuner.sh [--until=09:00] [--cores=14] [--fresh=1]
set -uo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
out="$REPO_ROOT/.sim_output/night7nov"
mkdir -p "$out"
if [ ! -f "$out/project/project.godot" ]; then
	import_project "$godot"
	cp -r "$REPO_ROOT/Game" "$out/project.tmp" && mv "$out/project.tmp" "$out/project"
	(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
fi
python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
rm -f "$out/STOP"
exec "$python_bin" -I "$REPO_ROOT/tools/night_tuner.py" "--godot=$godot" "--project=$out/project" "$@" >> "$out/tuner.log" 2>&1
