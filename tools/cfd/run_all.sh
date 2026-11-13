#!/usr/bin/env bash
# The wind tunnel's whole set (PH15), one run after another on the GPU (about 45 minutes a gusty case on an
# RTX 3080 Ti; the defaults are in tools/cfd/wind_tunnel.py): each case in gusty air (the realistic shadow), the
# 18 kt beam reach in smooth air too (the longest a shadow can be), the cells' check (smooth air in a smaller
# tunnel, 15 against 10 cm), then the analysis.
#
#   tools/cfd/run_all.sh [case ...]        (default: the cases below)
# The steady states must be there: tools/reach_check.sh --twas=48,100,135 --winds=12,18,24 --csv=1, then
# tools/wind_tunnel.sh states. Logs in .logs/wind_tunnel_*.log; results in .sim_output/cfd/.
set -uo pipefail
cd "$(dirname "$0")/../.."
cases=("$@")
if [[ ${#cases[@]} -eq 0 ]]; then
	# By what the game needs most: the planing reach, the beat, the slow board (a start), the broad reach, then
	# the other winds.
	cases=(reach_18_100 reach_18_48 reach_12_135 reach_18_135 reach_24_100 reach_12_100)
fi
for case in "${cases[@]}"; do
	if [[ -f ".sim_output/cfd/${case}_dx15.npz" ]]; then
		echo "=== $case: already there"
		continue
	fi
	echo "=== $case: gusty air ($(date +%H:%M))"
	tools/wind_tunnel.sh --case="$case" --mode=wake || echo "failed: $case"
done
if [[ ! -f ".sim_output/cfd/reach_18_100_dx15_calm.npz" ]]; then
	echo "=== reach_18_100: smooth air ($(date +%H:%M))"
	tools/wind_tunnel.sh --case=reach_18_100 --mode=wake --gusts=0 || echo "failed: smooth air"
fi
echo "=== the cells' check: smooth air, 8 + 30 m x 30 m x 12 m, 15 and 10 cm ($(date +%H:%M))"
for dx in 0.15 0.10; do
	tools/wind_tunnel.sh --case=reach_18_100 --mode=wake --gusts=0 --dx=$dx --down_m=30 --width_m=30 --height_m=12 \
		--tag=_cells || echo "failed: cells $dx"
done
echo "=== analysis ($(date +%H:%M))"
tools/wind_tunnel.sh analyse --dx=15
tools/wind_tunnel.sh analyse --dx=15 --suffix=_calm
tools/wind_tunnel.sh analyse --dx=15 --suffix=_calm_cells
tools/wind_tunnel.sh analyse --dx=10 --suffix=_calm_cells
echo "=== done ($(date +%H:%M))"
