#!/usr/bin/env bash
# Trains a learned skipper by neuroevolution, without a window (RACING_PLAN.md, "If PPO disappoints"):
# a population of small neural networks sails the T1 training loop, the best are kept and copied with
# small random changes, generation after generation, on all the cores. One line per generation; the
# same lines in .sim_output/evolve/<run>.csv; the brains in Game/race/brains/<run>_best.json (each
# time the best improves) and <run>_gen<N>.json (generation 1 and every 10th).
#
#   tools/race_evolve.sh --run=smoke --population=16 --generations=3 --episode_s=120   a quick check
#   tools/race_evolve.sh --run=night --hours=6                                         the overnight run
#
# The options are explained in Game/dev/evolve.gd. The physics commit goes into every brain file.
set -euo pipefail
source "$(dirname "$0")/common.sh"

commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/evolve.gd -- \
	"--commit=$commit" "$@"
