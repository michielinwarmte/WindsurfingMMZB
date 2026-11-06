#!/usr/bin/env bash
# The autopilot's test suite (Documentation/reports/autopilot/PLAN.md, section 3; the lake's chop:
# Documentation/reports/autopilot/lake_chop_training.md): one round of variants, each run through
# the reach check (nine cases on flat water, the CSVs kept), the push check in gusts and waves at
# the neutral dial (nine cases) and at the pushed dial (18 and 24 kt, six cases), the manoeuvre
# matrix, and Lake Silvaplana on its own waves (the reaches at ten times of day, the lake's
# manoeuvre matrix in the map's wind, and every manoeuvre in a steady 18 and 24 kt); on request a
# race on T2 on the lake with four AI skippers. Every case is its own Godot process in one pool
# (tools/autopilot_suite.py), so a round uses the whole PC. Everything lands in
# .sim_output/autopilot/<round>/<label>/, and tools/autopilot_summary.py <round> prints one table
# per variant (--table: one line per variant).
#
#   tools/autopilot_suite.sh --round=r1 --variants=Documentation/reports/autopilot/rounds/r1.txt
#   tools/autopilot_suite.sh --round=r0 --variants=- <<< "base:"          (one variant from stdin)
#   tools/autopilot_suite.sh --round=r1 --variants=... --only=reach,push   (part of the suite)
#   tools/autopilot_suite.sh --round=r1 --variants=... --only=lake         (the lake only)
#   tools/autopilot_suite.sh ... --only=lake,race                          (and the T2 race on the lake)
#   tools/autopilot_suite.sh ... --lake_wave_scale=1.5                     (the lake's waves 1.5 times higher)
#   tools/autopilot_suite.sh ... --cores=14                                (Godot processes at once; 14)
#
# The parts: reach, push, pushed, matrix, lake (the default: all five) and race. The variants file
# has one variant per line: "<label>: <overrides>", where the overrides are the --pilot.<field>=,
# --controller.<field>=, --sailor.<field>=, --sail.<field>=, --board.<field>= and --fin.<field>=
# settings the harnesses take (each harness takes the groups it knows: the reach check sails the
# Autopilot itself, so --controller. does not reach it). Lines starting with # are skipped. The
# pushed dial is GP0's: --pilot.hike_share=1.6. Godot's headless runs rewrite two project files on
# their own; the suite puts them back at the end.
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"
python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
status=0
"$python_bin" -I "$REPO_ROOT/tools/autopilot_suite.py" "--godot=$godot" "$@" || status=$?
(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
exit $status
