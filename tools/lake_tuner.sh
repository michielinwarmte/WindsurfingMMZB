#!/usr/bin/env bash
# The lake tuner (tools/lake_tuner.py), run on a frozen copy of Game/ so the worktree can be edited
# while it runs: the copy is made once in .sim_output/lake_speed/project (rm -r it to copy afresh).
# Resumable: run it again and it carries on from .sim_output/lake_speed/tuner_state.json; stop it with
# touch .sim_output/lake_speed/STOP. It stops by itself when it has converged. Output:
# .sim_output/lake_speed/tuner.log, leaderboard.md, Documentation/reports/autopilot/lake_speed/best.txt.
#
#   tools/lake_tuner.sh [--cores=12] [--fresh=1]
set -uo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
out="$REPO_ROOT/.sim_output/lake_speed"
mkdir -p "$out"
if [ ! -f "$out/project/project.godot" ]; then
	import_project "$godot"
	rm -rf "$out/project.tmp"
	# cp can report a file that was busy (a Godot writing its cache); the copy counts when it matches.
	cp -r "$REPO_ROOT/Game" "$out/project.tmp" || true
	if ! diff -rq "$REPO_ROOT/Game" "$out/project.tmp" >> "$out/tuner.log" 2>&1; then
		echo "the frozen copy differs from Game/: not started" >> "$out/tuner.log"
		exit 1
	fi
	mv "$out/project.tmp" "$out/project"
	(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
fi
python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
rm -f "$out/STOP"
exec "$python_bin" -I "$REPO_ROOT/tools/lake_tuner.py" "--godot=$godot" "--project=$out/project" "$@" >> "$out/tuner.log" 2>&1
