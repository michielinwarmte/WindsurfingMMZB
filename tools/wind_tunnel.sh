#!/usr/bin/env bash
# The wind tunnel (PH15): a windsurfer's rig in the air on the GPU (an NVIDIA card with CUDA), its force and
# the wind it leaves behind (the shadow a following board sails in). A lattice-Boltzmann air solver in
# PyTorch; the rig posed from the game's own steady states. The report: Documentation/reports/ph15_wind_tunnel/.
#
# Needs the shared venv's torch with CUDA (the same one tools/train.sh uses; see its header to make it).
#
#   tools/reach_check.sh --twas=48,100,135 --winds=12,18,24 --csv=1     the game's steady states, once
#   tools/wind_tunnel.sh states                                         their sail numbers, averaged, to JSON
#   tools/wind_tunnel.sh --check=plate                                  the solver's checks (about 5 min each)
#   tools/wind_tunnel.sh --check=wing
#   tools/wind_tunnel.sh --case=reach_18_100 --mode=calibrate           the twist that pulls the game's lift
#   tools/wind_tunnel.sh --case=reach_18_100 --mode=wake                the long tunnel (about 25 min at 0.1 m)
#   tools/wind_tunnel.sh analyse [--cases=reach_18_100,...]             the shadow's maps, tables and fit
#
# Options are at the top of tools/cfd/wind_tunnel.py and tools/cfd/analyse_wake.py. Results go to
# .sim_output/cfd/ (the fields are large; they are not committed).
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
shared_venv_python="$HOME/.local/venvs/windsurf/bin/python"
if [[ -n "${PYTHON:-}" ]]; then
	python_bin="$PYTHON"
elif [[ -x "$shared_venv_python" ]]; then
	python_bin="$shared_venv_python"
else
	python_bin="python"
fi
mkdir -p .sim_output/cfd .logs
case "${1:-}" in
	states)
		shift
		exec "$python_bin" -I tools/cfd/steady_states.py .sim_output/reach --json=.sim_output/reach/steady_states.json "$@"
		;;
	analyse)
		shift
		exec "$python_bin" -I tools/cfd/analyse_wake.py "$@"
		;;
esac
log=".logs/wind_tunnel_$(date +%Y%m%d_%H%M%S).log"
echo "log: $log"
"$python_bin" -I tools/cfd/wind_tunnel.py "$@" 2>&1 | tee "$log"
exit "${PIPESTATUS[0]}"
