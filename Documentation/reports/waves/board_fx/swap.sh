#!/usr/bin/env bash
# Puts the effects' files of before this work (5e48758) in place ("before"), or this branch's back
# ("after"), for measure.sh. Only these files; run from the repository's root.
set -euo pipefail
files=(Game/windsurfer/effects.gd Game/world/effects/water_particles.gd Game/world/effects/wake_trail.gd Game/world/effects/wake_foam.gdshader)
if [[ "$1" == "before" ]]; then
	for f in "${files[@]}"; do git show "5e48758:$f" > "$f"; done
else
	git checkout HEAD -- "${files[@]}"
fi
