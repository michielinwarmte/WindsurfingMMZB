#!/usr/bin/env bash
# Builds the game's native library (native/, C++ on godot-cpp; the test of 13 November 2026) and
# hands it to Godot (Game/native/windsurf_native.gdextension), then runs the wave query's test:
#
#   tools/native.sh            build (the first time also godot-cpp, about 10 minutes) and test
#   tools/native.sh build      only build
#   tools/native.sh test       only the test (Game/dev/native_sea_bench.gd), in the editor engine;
#                              the release engine: .release/wsim_console.exe --headless -- --native_sea_bench=10
#                              after tools/release.sh build, with the library copied next to the exe
#
# Needs, once per PC (nothing needs administrator rights):
#   - the C++ compiler Godot's own engine is built with: WinLibs MinGW-w64 GCC 15.2.0, msvcrt, r7
#     (github.com/brechtsanders/winlibs_mingw, winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64msvcrt-
#     14.0.0-r7.zip), unpacked into %LOCALAPPDATA%/Programs/winlibs-15.2.0-msvcrt-r7 (or set MINGW to
#     its mingw64/bin folder). The same compiler as the engine, so sin and cos are the engine's own.
#   - godot-cpp at its godot-4.5-stable tag in %LOCALAPPDATA%/Programs/godot-cpp-4.5 (or set
#     GODOT_CPP): git clone --depth 1 --branch godot-4.5-stable https://github.com/godotengine/godot-cpp.git
#   - SCons: python tools/python_no_wmi.py pip install --user scons
# The library and the .gdextension file are built files, not in git (Game/native/ in .gitignore).
set -euo pipefail
source "$(dirname "$0")/common.sh"

what="${1:-all}"
local_programs="$(cygpath -u "$LOCALAPPDATA")/Programs"
mingw="${MINGW:-$local_programs/winlibs-15.2.0-msvcrt-r7/mingw64/bin}"
godot_cpp="${GODOT_CPP:-$local_programs/godot-cpp-4.5}"
gdextension="$PROJECT_DIR/native/windsurf_native.gdextension"
library="res://native/bin/windsurf_native.windows.template_release.x86_64.dll"

build() {
	[[ -x "$mingw/g++.exe" ]] || { echo "No C++ compiler at $mingw (see the top of this script)." >&2; exit 1; }
	[[ -f "$godot_cpp/SConstruct" ]] || { echo "No godot-cpp at $godot_cpp (see the top of this script)." >&2; exit 1; }
	mkdir -p "$REPO_ROOT/.logs"
	echo "Building the native library (the first time also godot-cpp: about 10 minutes)..."
	(cd "$REPO_ROOT/native" && PATH="$mingw:$PATH" python "$REPO_ROOT/tools/python_no_wmi.py" SCons \
		-j"$(nproc)" platform=windows use_mingw=yes target=template_release \
		godot_cpp="$(cygpath -m "$godot_cpp")") > "$REPO_ROOT/.logs/native_build.log" 2>&1 \
		|| { echo "The build failed. The log: .logs/native_build.log" >&2; tail -n 30 "$REPO_ROOT/.logs/native_build.log" >&2; exit 1; }
	# Godot finds the library through this file; the editor and the release engine both take the
	# release build of it (it holds no editor parts).
	cat > "$gdextension" <<EOF
[configuration]
entry_symbol = "windsurf_native_init"
compatibility_minimum = "4.5"
reloadable = false

[libraries]
windows.debug.x86_64 = "$library"
windows.release.x86_64 = "$library"
EOF
	import_project "$(find_godot)"
	echo "Built: Game/native/bin/$(basename "$library")"
}

run_test() {
	"$(find_godot)" --headless --no-header --path "$PROJECT_DIR" -s res://dev/native_sea_bench_main.gd -- "${@}"
}

case "$what" in
	build) build ;;
	test) shift; run_test "$@" ;;
	*) build; run_test ;;
esac
