#!/usr/bin/env bash
# The commentary's computer voice without ears: speaks every line of the commentary bank (the slots
# filled with the game's names), every name alone and in a sentence, to WAV files through the game's
# own speech engine, and writes what came out (made or not, seconds of sound, seconds it took) to
# <out>/manifest.json. Then: python -E -P tools/tts/read_back.py <out> (Whisper reads them back).
#
#   tools/tts/speak_lines.sh [--out=<folder>] [--tts_dir=<folder>] [--names=<file>] [--count=<n>]
#
# The speech program is found as the game finds it: --tts_dir, else MMZB_TTS_DIR, else tts/ beside
# the executable (tools/tts/fetch_tts.py fetches it). The default out folder: .sim_output/voice.
set -euo pipefail
source "$(dirname "$0")/../common.sh"

out_dir="$REPO_ROOT/.sim_output/voice"
mkdir -p "$out_dir"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/voice_run.gd -- \
	"--out=$out_dir" "$@"
