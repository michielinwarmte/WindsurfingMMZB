#!/usr/bin/env bash
# Starts the lake tuner detached from any terminal (it survives the session that started it). From
# PowerShell, through the short path so it has no spaces:
#   Start-Process -FilePath "C:\Program Files\Git\usr\bin\bash.exe" -ArgumentList @('-l', '/c/Users/MAXDED~1/source/WindsurfingMMZB-fixes/tools/lake_tuner_detached.sh') -WindowStyle Minimized
export PATH="/usr/bin:/mingw64/bin:/bin:$PATH"
export GODOT="${GODOT:-/c/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .sim_output/lake_speed
exec tools/lake_tuner.sh --cores=12 "$@"
