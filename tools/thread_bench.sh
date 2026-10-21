#!/usr/bin/env bash
# Where do boards on worker threads wait for each other? Times small pieces of GDScript work on
# 1, 4, 8 and 16 threads at once (Game/dev/thread_bench.gd; F1 `fleet_wait` in
# Documentation/AI_FLEET_PLAN.md). About a minute.
#
#   tools/thread_bench.sh                     on the editor engine
#   tools/thread_bench.sh --release           on the release engine (tools/release.sh build first)
#   ... [--threads=1,4,8,16] [--iterations=100000] [--only=basis,arrays]
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ "${1:-}" == "--release" ]]; then
	shift
	exec "$REPO_ROOT/.release/wsim_console.exe" --headless -- --bench=thread "$@"
fi
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -- --bench=thread "$@"
