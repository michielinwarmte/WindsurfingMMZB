#!/usr/bin/env bash
# A frozen copy of Game/ for the skipper's suite (8 November 2026), so the worktree can be edited while
# a pool of Godot jobs runs on the copy. The first time it copies all of Game/ (about 600 MB, with the
# import cache); after that it only refreshes the scripts and courses that change during the work.
#
#   tools/heads/freeze.sh            make or refresh .sim_output/heads/frozen/Game
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
frozen="$REPO_ROOT/.sim_output/heads/frozen"
if [[ ! -d "$frozen/Game/.godot" ]]; then
	mkdir -p "$frozen"
	cp -r "$REPO_ROOT/Game" "$frozen/" || true
	echo "frozen copy made"
else
	for part in race dev windsurfer maps/course maps/silvaplana/courses sim config; do
		cp -r "$REPO_ROOT/Game/$part/." "$frozen/Game/$part/" || true
	done
	echo "frozen copy refreshed"
fi
