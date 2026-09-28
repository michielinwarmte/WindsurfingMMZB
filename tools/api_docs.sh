#!/usr/bin/env bash
# Writes the API reference of the exact Godot version we use to .godot_api/ as XML files
# (about 1000 classes, 7 MB, takes a few seconds). Use it to look up the exact name and
# arguments of a class, method, property or signal instead of guessing. For example:
#
#   grep -A6 '<method name="signed_angle_to"' .godot_api/doc/classes/Vector3.xml
#
# Classes from modules (GDScript, FBX, ...) are in .godot_api/modules/*/doc_classes/.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out="$REPO_ROOT/.godot_api"
mkdir -p "$out"

godot="$(find_godot)"
"$godot" --headless --no-header --doctool "$out" >/dev/null
echo "Godot $GODOT_VERSION API reference: $out ($(find "$out" -name '*.xml' | wc -l) classes)"
