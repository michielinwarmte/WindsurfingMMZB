#!/usr/bin/env bash
# Runs a Blender script headless, the way every map-track script in tools/blender/ is run:
# no window, factory settings (so personal add-ons and preferences can't change the result).
# Arguments after the script go to the script itself.
#
# Example: tools/blender.sh tools/blender/roundtrip_test.py Game/maps/silvaplana/dev/roundtrip_hill.glb
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ $# -lt 1 ]]; then
	echo "Usage: tools/blender.sh <script.py> [script arguments...]" >&2
	exit 2
fi
script="$1"
shift

blender="$(find_blender)"
exec "$blender" --background --factory-startup --python-exit-code 1 --python "$script" -- "$@"
