#!/usr/bin/env bash
# Builds the Silvaplana map from Swiss open data, step by step (Documentation/MAP_SILVAPLANA_PLAN.md).
# Safe to run again: it only downloads what is missing and rewrites its own output.
# What each step does: tools/map/README.md.
#
# At the end it opens the picture of what can be seen from the lake and the cameras. When the
# script was started by double-clicking it, the window stays open until you press Enter.
set -euo pipefail
source "$(dirname "$0")/../common.sh"
cd "$REPO_ROOT"

# A double-clicked script runs in a fresh window whose shell is the first one (SHLVL 1);
# from a terminal the script is a second shell. Keep a double-clicked window open, also after an error.
pause_if_double_clicked() {
	if [[ -t 0 && "${SHLVL:-1}" -le 1 ]]; then
		echo
		read -rp "Press Enter to close this window." _
	fi
}
trap pause_if_double_clicked EXIT

# Opens a picture in the system's image viewer, but only when a person is watching the output.
show_picture() {
	local picture="$1"
	[[ -t 1 ]] || return 0
	case "$(uname -s)" in
		MINGW* | MSYS* | CYGWIN*) cmd.exe //c start "" "$(cygpath -w "$picture")" || true ;;
		Darwin) open "$picture" || true ;;
		*) if command -v xdg-open >/dev/null 2>&1; then xdg-open "$picture" >/dev/null 2>&1 & fi ;;
	esac
}

# Python 3: $PYTHON if set, else python3 (Linux), else python (Windows, where python3 is only a
# Microsoft Store shortcut).
if [[ -n "${PYTHON:-}" ]]; then
	py="$PYTHON"
elif python3 -c "import sys" >/dev/null 2>&1; then
	py="python3"
else
	py="python"
fi

echo "== Download heights, lakebed and wind (M0)"
"$py" tools/map/download.py heights wind
echo
echo "== Lake level and map position (M0)"
"$py" tools/map/lake_level.py
echo
echo "== What can be seen from the lake and the cameras (M0)"
"$py" tools/map/visible.py
echo
echo "== Aerial photos (2 m) of everything visible (M0)"
"$py" tools/map/download.py photos-far

echo
echo "== A preview of the valley in Blender (not the game terrain yet)"
"$py" tools/map/preview_data.py
preview="$REPO_ROOT/.map_data/work/preview"
if find_blender >/dev/null 2>&1; then
	tools/blender.sh tools/blender/build_preview.py 2>&1 | grep -E "^Camera|^Rendered|^Saved C|Error|Traceback" | grep -v "Shadow buffer" || true
else
	echo "Blender $BLENDER_VERSION was not found, so there is no Blender preview (see tools/map/README.md)."
fi

# Later phases add their steps here: heights.py and the Blender terrain (M1), photos.py and the
# 10 cm photos of the shore band (M2), the surface model for trees and buildings (M4).

echo
echo "Map build done. Raw data: $(du -sh .map_data | cut -f1) in .map_data/"
echo "To look at:"
echo "  .map_data/work/visible_map.png                    what can be seen (orange: the sailor, yellow: only the cameras)"
echo "  .map_data/work/preview/renders/*.png              pictures of the valley from four viewpoints"
echo "  .map_data/work/preview/silvaplana_preview.blend   open in Blender and fly around (cameras: launch_beach, ...)"
echo "There is nothing to see in Godot yet: the 3D terrain for the game comes in phase M1."
show_picture "$REPO_ROOT/.map_data/work/visible_map.png"
show_picture "$preview/renders/valley_overview.png"
