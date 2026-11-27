#!/usr/bin/env bash
# The game as a release build: the engine without the editor, running the project packed as
# .release/wsim.pck. The release engine scales the AI boards' physics over worker threads where
# the editor build collapses (Session 51: eight boards at 244 fps against 4 fps), so a race with
# many boards is played with this. The physics is the same; only the engine's debug bookkeeping
# is gone.
#
#   tools/release.sh build                    export the pack and put the engine next to it
#   tools/release.sh [--options...]           build if there is no pack yet, then run it; the
#                                             options go to the game: --race=t1_loop
#                                             [--skippers=a,b,c] [--prestart=20] [--measure=12]
#   tools/release.sh --mute [--options...]    the same without sound (a measurement or a bench
#                                             run is always silent: Max sleeps next to the laptop)
#   tools/release.sh tts [<play folder>]      only copy the commentary's speech program and voice
#                                             into .release/tts (or <play folder>/tts)
#
# Rebuild after a change to the game (the pack is a copy). Needs the Windows export templates of
# this Godot version installed once: in the editor, Editor > Manage Export Templates > Download,
# or copy windows_release_x86_64.exe and windows_release_x86_64_console.exe from the
# Godot_v4.7.2-stable_export_templates.tpz into %APPDATA%/Godot/export_templates/4.7.2.stable/.
#
# The commentary's voice (Documentation/reports/broadcast/commentary_voice.md): the build also copies
# the speech program and its voice into .release/tts/ (piper/ and voices/), where the game looks for
# them beside its executable; a play folder made from .release keeps that tts/ folder next to wsim.exe.
# They come from MMZB_TTS_DIR, else from ../pwa_broadcast/tts beside the repository (Max's PC; fetch
# them with python -I tools/tts/fetch_tts.py <folder>). Without them the game shows the commentary as
# subtitles only.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out="$REPO_ROOT/.release"
appdata="${APPDATA:-$HOME/AppData/Roaming}"
if command -v cygpath >/dev/null 2>&1; then
	appdata="$(cygpath -u "$appdata")"
fi
templates="$appdata/Godot/export_templates/4.7.2.stable"

build() {
	if [[ ! -f "$templates/windows_release_x86_64.exe" ]]; then
		echo "No export templates at $templates: install them first (see the top of this script)." >&2
		exit 1
	fi
	mkdir -p "$out"
	local godot
	godot="$(find_godot)"
	import_project "$godot"
	"$godot" --headless --path "$PROJECT_DIR" --export-pack "Windows Desktop" "$out/wsim.pck" > "$REPO_ROOT/.logs/release.log" 2>&1
	cp "$templates/windows_release_x86_64.exe" "$out/wsim.exe"
	cp "$templates/windows_release_x86_64_console.exe" "$out/wsim_console.exe"
	echo "Built $out/wsim.pck ($(du -h "$out/wsim.pck" | cut -f1)) with the engine beside it."
	copy_speech_program
}

# The commentary's speech program and voice into .release/tts/ (see the top of this script).
copy_speech_program() {
	local source="${MMZB_TTS_DIR:-$REPO_ROOT/../pwa_broadcast/tts}"
	if [[ ! -f "$source/piper/piper.exe" || ! -d "$source/voices" ]]; then
		echo "No speech program in $source: the commentary will be subtitles only (python -I tools/tts/fetch_tts.py <folder>, then MMZB_TTS_DIR=<folder>)."
		return 0
	fi
	mkdir -p "$out/tts"
	cp -r "$source/piper" "$source/voices" "$out/tts/"
	echo "Copied the commentary's speech program and voice from $source to $out/tts ($(du -sh "$out/tts" | cut -f1))."
}

if [[ "${1:-}" == "tts" ]]; then
	# tools/release.sh tts [<play folder>]: only the speech program and its voice, into .release/tts
	# or into <play folder>/tts (no build).
	if [[ -n "${2:-}" ]]; then out="$2"; fi
	copy_speech_program
	exit 0
fi
if [[ "${1:-}" == "build" ]]; then
	build
	exit 0
fi
if [[ ! -f "$out/wsim.pck" ]]; then
	build
fi
# Silent when asked, and for every measurement or bench run (they run at night, unattended).
engine_args=()
game_args=()
for arg in "$@"; do
	case "$arg" in
		--mute) engine_args+=(--audio-driver Dummy) ;;
		--measure=*|--bench=*) engine_args+=(--audio-driver Dummy); game_args+=("$arg") ;;
		*) game_args+=("$arg") ;;
	esac
done
exec "$out/wsim_console.exe" "${engine_args[@]}" -- "${game_args[@]}"
