#!/usr/bin/env bash
# Fits the race courses to Lake Silvaplana (RACING_PLAN.md, T2 "Placed to fit the water";
# Game/maps/course/course_fitter.gd) and saves the sprint slalom as the team's course
# Game/maps/silvaplana/courses/t2_slalom.json. Prints each course's size, axis, clearances and
# legs, and how long the fit took. Game/dev/fit_courses.gd.
#
#   tools/fit_courses.sh                 the lake's wind at 14:30, the sailing's start time
#   tools/fit_courses.sh --time=17:00    another time of day's wind
#   tools/fit_courses.sh --save=0        don't write t2_slalom.json
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/fit_courses.gd -- "$@"
