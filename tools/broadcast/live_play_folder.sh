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
# settings have the master volume at 5 %: the commentator would not be heard), and the spot's sea at
# 0.7 of its height, as in Max's own settings and as the test heats of 27 November were sailed
# (crests up to about 1.0 m in 30 kt; at 1.0 they are 1.5 m).
if [[ ! -f "$dest/live.cfg" ]]; then
	sed -e 's/^master_volume=.*/master_volume=0.6/' -e 's/^wind_volume=.*/wind_volume=0.3/' \
		-e 's/^water_volume=.*/water_volume=0.4/' -e 's/^sail_volume=.*/sail_volume=0.3/' \
		-e 's/^lake_wave_scale=.*/lake_wave_scale=0.7/' \
		"$dest/push_and_body.cfg" > "$dest/live.cfg"
	if ! grep -q '^lake_wave_scale=' "$dest/live.cfg"; then
		printf '\r\n[waves]\r\nlake_wave_scale=0.7\r\n' >> "$dest/live.cfg"
	fi
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

# The README: what this build is, how to start it, the keys, what is not there yet. The part under
# "KNOWN" comes from tools/broadcast/live_known.txt when it is there (the state of the night).
commit="$(git -C "$REPO_ROOT" log -1 --format='%h, %cd' --date=format:'%d %B %Y %H:%M')"
branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
{
	cat <<EOF
Windsurf MMZB - the live slalom week at Sotavento
=================================================

Build: branch $branch at $commit (not pushed, not merged into main).

What it is
----------
The game's own slalom world cup at Fuerteventura, Sotavento, as a live broadcast: 64 sailors,
11 eliminations of 16 heats (a first round of 8 heats, 4 quarter-finals, 2 semi-finals, the losers'
final and the winners' final; the first four of a heat go through). Every heat is sailed on the
water by eight AI sailors, filmed by the TV director (set to the pictures of the real 2026 streams)
and talked through by the commentator: his lines as subtitles, and said by a computer voice.
The voice is NOT the real commentator's: a ready-made British computer voice. His own voice waits
for his yes.

Start
-----
1 LIVE - the Sotavento slalom week (goes on where it stopped).bat
    The broadcast. It runs by itself: a 60 s countdown, the heat, the result, the next heat
    (a heat is over when its fourth board is home: the four who go through; a final when all
    eight are, or a minute after its winner).
    The week is saved after every heat; start it again and it goes on with the next heat.
2 LIVE - a NEW Sotavento slalom week from heat 1.bat
    The same, from the first heat of elimination 1 (the saved week is replaced).
3 LIVE - the Sotavento slalom week, subtitles only (no voice).bat
4 Watch one Sotavento slalom heat (TV director and commentary, 8 AI boards).bat
5 Sail at Sotavento yourself (body on the mouse).bat
6 Start the game - push and body on the mouse.bat

Keys while watching
-------------------
B       the ladder of this elimination and the standings (the last elimination's result and the
        standings also come up by themselves when the next elimination begins, and at the end
        of the week)
H       the screen: full (every card and the keys) / TV (what a viewer needs) / clean
V       the commentary on or off;  Shift+V  the voice alone (subtitles stay)
T       the TV director on or off;  5 to 9  one TV shot by hand;  1 to 4  your own cameras
Tab, L  the next board, the leader
- + 0   slower, faster, normal speed;  P  freeze
N       the names above the boards;  I  the AI's head (what a skipper is doing)
R       this heat again with a new start

The results as text
-------------------
After every heat the week writes its results (the standings of all 64 with every elimination's
points, each elimination's first sixteen, the ladder being sailed) to
  %APPDATA%\\Godot\\app_userdata\\Windsurfing Simulator\\event_week_sotavento_2026_results.txt

The sound
---------
The live launchers use live.cfg next to this file: your play settings with the master volume at
60 % and the wind, water and sail sounds lower, so the commentator is heard (your play settings
have the master volume at 5 %). Change it in Settings > Audio (Commentary has its own slider).
The speech program is in the tts folder next to wsim.exe; without it there are subtitles only.

EOF
	if [[ -f "$REPO_ROOT/tools/broadcast/live_known.txt" ]]; then
		cat "$REPO_ROOT/tools/broadcast/live_known.txt"
	fi
} | sed 's/\r$//' | sed 's/$/\r/' > "$dest/README.txt"

echo "Play folder: $dest"
ls -1 "$dest" | sed 's/^/  /'
du -sh "$dest" | cut -f1
