#!/usr/bin/env bash
# Trains the learned head (AI_FLEET_PLAN.md, D6b): PPO in Python on races Godot sails headless, one
# curriculum stage at a time, a brain file for the game every half hour. Needs, once:
# pip install torch stable-baselines3 (the CPU torch is enough: the network is tiny).
#
#   tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4  the nights unattended: every stage in turn,
#                                                             each from the one before's best brain, each
#                                                             ended when its "done when" number holds at an
#                                                             hourly check or after 4 hours (up to a day)
#   tools/train.sh --stage=S1 --hours=3                       stage 1 (the beat), 3 hours, run "s1"
#   tools/train.sh --stage=S2 --hours=3 --resume=Game/race/brains/s1_best.json
#                                                             the next stage from the last one's best brain
#   tools/train.sh --stage=S1 --minutes=10 --workers=4        a short try
#   tools/train.sh --stage=S1 --hours=3                       again: continues the run "s1" where it stopped
#
#   tools/train.sh --evaluate=Game/race/brains/s1_best.json --stage=S1 [--episodes=20] [--reference=allrounder]
#                                                             how a brain does on a stage's drops, without
#                                                             Python; with --reference the all-rounder sails
#                                                             the same drops too (S1's yardstick)
#
# The options are explained at the top of tools/train/train.py (the trainer) and Game/dev/train_worker.gd
# (the evaluation). The run's log, curve (curve.csv) and model are in .sim_output/train/<run>/; the brains
# in Game/race/brains/<run>_gen<N>.json, <run>_best.json and <run>_latest.json. tools/gens.sh --run=<run>
# shows a run's generations racing; tools/race.sh --skippers=brain:<run>_best,allrounder races one.
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
export GODOT="$godot"
import_project "$godot"
mkdir -p "$REPO_ROOT/.sim_output/train"

for arg in "$@"; do
	case "$arg" in
		--evaluate=*)
			exec "$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/train_worker.gd -- "$@"
			;;
	esac
done

python_bin="${PYTHON:-python}"
if ! "$python_bin" -c "import torch, stable_baselines3" 2>/dev/null; then
	echo "The trainer needs torch and stable-baselines3: $python_bin -m pip install torch stable-baselines3" >&2
	exit 1
fi
exec "$python_bin" -u "$REPO_ROOT/tools/train/train.py" "$@"
