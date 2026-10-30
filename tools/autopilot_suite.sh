#!/usr/bin/env bash
# The autopilot's test suite (Documentation/reports/autopilot/PLAN.md, section 3): one round of
# variants, each run through the reach check (nine cases on flat water, the CSVs kept), the push
# check in gusts and waves at the neutral dial (nine cases) and at the pushed dial (18 and 24 kt,
# six cases), and the manoeuvre matrix. Everything lands in .sim_output/autopilot/<round>/<label>/,
# and tools/autopilot_summary.py <round> prints one table per variant.
#
#   tools/autopilot_suite.sh --round=r1 --variants=Documentation/reports/autopilot/rounds/r1.txt
#   tools/autopilot_suite.sh --round=r0 --variants=- <<< "base:"          (one variant from stdin)
#   tools/autopilot_suite.sh --round=r1 --variants=... --only=reach,push   (part of the suite)
#   tools/autopilot_suite.sh ... --jobs=3                                  (the push check's processes)
#
# The variants file has one variant per line: "<label>: <overrides>", where the overrides are the
# --pilot.<field>=, --sailor.<field>=, --sail.<field>=, --board.<field>= and --fin.<field>= settings
# the harnesses take (the matrix takes --pilot., --sailor. and --sail.; --board. and --fin. go to the
# reach check and the push check).
# Lines starting with # are skipped. The pushed dial is GP0's: --pilot.hike_share=1.6.
set -euo pipefail
source "$(dirname "$0")/common.sh"

round=""
variants=""
only="reach,push,pushed,matrix"
jobs=3
for arg in "$@"; do
	case "$arg" in
		--round=*) round="${arg#--round=}" ;;
		--variants=*) variants="${arg#--variants=}" ;;
		--only=*) only="${arg#--only=}" ;;
		--jobs=*) jobs="${arg#--jobs=}" ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done
if [[ -z "$round" || -z "$variants" ]]; then
	echo "Usage: tools/autopilot_suite.sh --round=<name> --variants=<file or -> [--only=reach,push,pushed,matrix] [--jobs=3]" >&2
	exit 2
fi
out_root="$REPO_ROOT/.sim_output/autopilot/$round"
mkdir -p "$out_root"
if [[ "$variants" == "-" ]]; then
	lines="$(cat)"
else
	lines="$(cat "$variants")"
fi

wants() { [[ ",$only," == *",$1,"* ]]; }

while IFS= read -r line; do
	[[ -z "$line" || "$line" == \#* ]] && continue
	label="${line%%:*}"
	overrides="${line#*:}"
	label="$(echo "$label" | tr -d '[:space:]')"
	# shellcheck disable=SC2206
	over=($overrides)
	dir="$out_root/$label"
	mkdir -p "$dir"
	echo "$overrides" > "$dir/overrides.txt"
	echo "=== $round / $label: $overrides"
	if wants reach; then
		mkdir -p "$dir/reach"
		"$REPO_ROOT/tools/reach_check.sh" --seconds=90 --from=60 "--out_dir=$dir/reach" ${over[@]+"${over[@]}"} > "$dir/reach.txt" 2>&1 || echo "reach check failed (exit $?)" >> "$dir/reach.txt"
	fi
	if wants push; then
		"$REPO_ROOT/tools/push_check.sh" --winds=12,18,24 --seconds=120 "--jobs=$jobs" "--run=${round}_${label}_neutral" ${over[@]+"${over[@]}"} > "$dir/push_neutral.txt" 2>&1 || echo "push check failed (exit $?)" >> "$dir/push_neutral.txt"
	fi
	if wants pushed; then
		"$REPO_ROOT/tools/push_check.sh" --winds=18,24 --seconds=120 "--jobs=$jobs" "--run=${round}_${label}_pushed" --pilot.hike_share=1.6 ${over[@]+"${over[@]}"} > "$dir/push_pushed.txt" 2>&1 || echo "push check failed (exit $?)" >> "$dir/push_pushed.txt"
	fi
	if wants matrix; then
		matrix_over=()
		for o in ${over[@]+"${over[@]}"}; do
			case "$o" in --pilot.*|--sailor.*|--sail.*) matrix_over+=("$o") ;; esac
		done
		"$REPO_ROOT/tools/matrix.sh" ${matrix_over[@]+"${matrix_over[@]}"} > "$dir/matrix.txt" 2>&1 || echo "matrix failed (exit $?)" >> "$dir/matrix.txt"
	fi
	# Godot's headless runs rewrite two project files on their own; keep the tree clean.
	(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
done <<< "$lines"
echo "ROUND_DONE $round"
