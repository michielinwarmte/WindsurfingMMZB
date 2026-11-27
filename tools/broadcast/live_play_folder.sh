#!/usr/bin/env bash
# Makes the play folder of the live slalom week (Documentation/reports/broadcast/EVENT_WEEK_PLAN.md)
# from the release build in .release/ (tools/release.sh build): the game, the commentary's speech
# program and voice, the launchers and a README.
#
#   tools/broadcast/live_play_folder.sh "<play folder>" ["<older play folder>"]
#
# The older play folder gives body.cfg and push_and_body.cfg (the mouse body's settings Max plays
# with); without it the play launchers use a small settings file with the mouse body on.
# Run it again after a new build: the game's files and the launchers are written again, the
# settings files that are already there are kept (the game saves Max's changes to them).
set -euo pipefail
source "$(dirname "$0")/../common.sh"

dest="${1:?usage: tools/broadcast/live_play_folder.sh <play folder> [<older play folder>]}"
older="${2:-}"
release="$REPO_ROOT/.release"
if [[ ! -f "$release/wsim.exe" || ! -f "$release/wsim.pck" ]]; then
	echo "No release build in $release: run tools/release.sh build first." >&2
	exit 1
fi
mkdir -p "$dest"
cp "$release/wsim.exe" "$release/wsim_console.exe" "$release/wsim.pck" "$dest/"
if [[ -f "$release/tts/piper/piper.exe" ]]; then
	rm -rf "$dest/tts"
	cp -r "$release/tts" "$dest/tts"
else
	echo "NO SPEECH PROGRAM in $release/tts: the commentary will be subtitles only (tools/release.sh tts)."
fi

# The settings files: Max's own from an older play folder, else small ones with the mouse body on.
for cfg in body.cfg push_and_body.cfg; do
	if [[ -f "$dest/$cfg" ]]; then
		continue
	fi
	if [[ -n "$older" && -f "$older/$cfg" ]]; then
		cp "$older/$cfg" "$dest/$cfg"
	else
		printf '[body]\r\nmouse_body=true\r\npush_on_mouse=2\r\n' > "$dest/$cfg"
	fi
done
# The broadcast's settings: Max's play settings with the sound set for a broadcast (his play
# settings have the master volume at 5 %: the commentator would not be heard).
if [[ ! -f "$dest/live.cfg" ]]; then
	sed -e 's/^master_volume=.*/master_volume=0.6/' -e 's/^wind_volume=.*/wind_volume=0.3/' \
		-e 's/^water_volume=.*/water_volume=0.4/' -e 's/^sail_volume=.*/sail_volume=0.3/' \
		"$dest/push_and_body.cfg" > "$dest/live.cfg"
	if ! grep -q '^master_volume=' "$dest/live.cfg"; then
		printf '\r\n[audio]\r\nmaster_volume=0.6\r\nwind_volume=0.3\r\nwater_volume=0.4\r\nsail_volume=0.3\r\ncommentary_volume=1.0\r\n' >> "$dest/live.cfg"
	fi
fi

# A launcher: its file name, the settings file, the game's options, then the lines of its remark.
launcher() {
	local name="$1" cfg="$2" options="$3"
	shift 3
	{
		echo "@echo off"
		for line in "$@"; do
			echo "rem $line"
		done
		echo 'cd /d "%~dp0"'
		echo "set \"cfg=%~dp0$cfg\""
		echo 'set "cfg=%cfg:\=/%"'
		echo "start \"\" \"wsim.exe\" -- $options \"--settings=%cfg%\""
	} | sed 's/$/\r/' > "$dest/$name.bat"
}

eight="persona:mara,persona:hana,persona:kofi,persona:liv,persona:noor,persona:tobias,persona:lena,persona:sven"
week="--spot=sotavento --course=pwa_slalom_x --skippers=$eight --spectate=1 --tv=1 --screen=tv --wind=30 --event=sotavento_2026"
keys="Keys: B the ladder and the standings, H the screen (full / TV / clean), V the commentary on or off, Shift+V the voice alone, T the TV director, Tab next board, L leader, 5-9 a TV shot by hand, - + 0 speed, P freeze, N names, I the AI's head."

launcher "1 LIVE - the Sotavento slalom week (goes on where it stopped)" live.cfg "$week" \
	"The live broadcast of the game's slalom week at Sotavento: 64 sailors, 16 heats of 8 per elimination, 11 eliminations." \
	"Heat after heat by itself: a 60 s countdown, the race, the result, the next heat. The TV director films, the commentator talks (a computer voice, NOT the real commentator's) with subtitles." \
	"The week is saved after every heat: start this again and it goes on with the next heat." \
	"$keys"
launcher "2 LIVE - a NEW Sotavento slalom week from heat 1" live.cfg "$week --event_new=1" \
	"The same broadcast, but a new week from the first heat of elimination 1 (the saved week is replaced)." \
	"$keys"
launcher "3 LIVE - the Sotavento slalom week, subtitles only (no voice)" live.cfg "$week --commentary_voice=0" \
	"The same broadcast without the computer voice: the commentary as subtitles only." \
	"$keys"
launcher "4 Watch one Sotavento slalom heat (TV director and commentary, 8 AI boards)" live.cfg \
	"--spot=sotavento --course=pwa_slalom_x --skippers=$eight --spectate=1 --tv=1 --screen=tv --wind=30 --prestart=60" \
	"One heat of eight of the game's own characters on the Sotavento course, no event round it. R: a new race." \
	"$keys"
launcher "5 Sail at Sotavento yourself (body on the mouse)" push_and_body.cfg "--spot=sotavento" \
	"Sail at Sotavento yourself, the push gauge and the body on the mouse (settings in push_and_body.cfg next to this file)." \
	"The game saves to push_and_body.cfg if you change a setting; your own settings are not touched."
launcher "6 Start the game - push and body on the mouse" push_and_body.cfg "" \
	"The start menu with the push gauge AND the body on the mouse (settings in push_and_body.cfg next to this file)."

echo "Play folder: $dest"
ls -1 "$dest" | sed 's/^/  /'
du -sh "$dest" | cut -f1
