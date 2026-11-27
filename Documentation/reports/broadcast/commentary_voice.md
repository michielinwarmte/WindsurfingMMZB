# The commentary heard: a computer voice says the commentator's lines (27 to 28 November 2026)

Max, 27 November 2026: "tomorrow morning i want a fully working livestream with audable commentary". The commentary
director already shows the commentator's lines as subtitles ([commentary_director.md](commentary_director.md)). Now
the same lines are also **heard**.

Branch `broadcast/voice` (from `broadcast/study-27nov`), worktree `WindsurfingMMZB-voice`. Not yet heard by anyone:
nobody on the team has listened to it. The checks below were done without ears.

## It is NOT the commentator's voice

The commentator is a real person. Copying his voice waits for his own yes (PLAN.md, "When the commentator is
asked"), and we don't have it yet. So the voice tonight is a **ready-made computer voice**: a British man's voice
from the Piper project, downloaded as it is. Nothing was trained or tuned on the streams' audio. No voice was cloned.
It does not try to sound like him. His **words** are used (the lines of the bank), not his voice.

When he says yes, phase P7 of the plan can make his own voice; the game's side (this voice player) stays the same.

## What it does, in plain words

1. When the game starts a race to watch, it starts a small **speech program** beside the game (Piper). It runs on
   this PC, offline: nothing is sent to the internet. It loads its voice once and then waits for lines.
2. When the commentary director starts a line, the game gives the words to the speech program. The program writes the
   spoken line as a sound file. The game plays it at once, on its own sound channel ("Commentary").
3. Every line spoken is **kept on the disk** (in the game's own user folder, `commentary_voice/`). The next time the
   same words come, the sound plays straight away, with no wait.
4. While nothing is being said, the program **makes lines ahead** in the background: the race's sailors' names on
   their own ("Hana."), then the bank's lines that have no name in them, the most said first (up to 400).
5. When the director knows the next line early (the second line of a pair: "Wow." and then the pass), that line is
   made while the first is being said.
6. **Too late is dropped, not said late.** If a line's sound is not ready in time, that line stays silent (its
   subtitle still shows). In time means: within 30 % of the line's length, at least 0.3 s and at most 0.8 s.
7. **One voice at a time.** A new line, or a big moment that cuts in, fades the old sound out in 0.06 s (no click).
8. **How excited:** a calm line (level 1) is said a little slower, lower and softer; a shouted line (level 4) a little
   faster, higher and louder. Modest on purpose. The numbers are below.
9. **The computer voice is often slower than him.** When its sound is longer than his line was, the director is told,
   and the next line waits for the sound to end (plus the usual breath). The subtitle stays up as long. So a line is
   never cut off by the next one just because the computer voice is slower.

If the speech program is not there, the game shows the subtitles as before, writes one line in its log, and shows no
error.

## The program and the voice, and their licences

| What | Which | Where from | Licence |
|---|---|---|---|
| The speech program | Piper 2023.11.14-2, the Windows build (`piper.exe`) | https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip | MIT. It carries espeak-ng (GPL-3.0; turns words into speech sounds) and onnxruntime (MIT). They run as a separate program beside the game, not inside it. |
| The voice | `en_GB-northern_english_male-medium`, one British man, 22 kHz | https://huggingface.co/rhasspy/piper-voices, pinned to commit `e9c8a39444359388adaa94255becb37a5a2b8e51` (20 November 2026), folder `en/en_GB/northern_english_male/medium/` | The recordings: OpenSLR 83 (British and Irish English speakers), CC BY-SA 4.0. **But** the voice was trained on top of Piper's U.S. "lessac" voice, whose recordings are licensed for **research only** (Blizzard 2013 Lessac licence: no commercial use, no redistribution). |

The files and their SHA-256 sums:

| File | SHA-256 |
|---|---|
| `piper_windows_amd64.zip` (22,477,236 bytes) | `f3c58906402b24f3a96d92145f58acba6d86c9b5db896d207f78dc80811efcea` |
| `en_GB-northern_english_male-medium.onnx` (63,201,294 bytes) | `57a219ae8e638873db7d18893304be5069c42868f392bb95c3ff17f0690d0689` |
| `en_GB-northern_english_male-medium.onnx.json` | `69557ed3d974463453e9b0c09dd99a7ed0e52b8b87b64b357dbeeb2540a97d47` |
| `MODEL_CARD` | `75661c3a50c0ba82b32b3a438e54103d8dfe5bbe8fbb864ac687a040e79948bb` |

**What the licence means for us:** fine for the team's own play tests tonight. **Not fine for a public release.**
Before anything goes public, the voice must change: the commentator's own voice after his yes (P7), or a voice with a
clean licence. Piper's maker retrains its voices on clean bases right now (this very voice was retrained on 23 November
2026 from a CC0 base), but the retrained voices need Piper 1.5 or newer, which exists only as a Python package, with no
Windows program. The game must not need Python, so tonight's voice is the last version before the retraining.

Why this voice: of Piper's British voices, the two men are "alan" and "northern_english_male". Alan's recordings say
"All Rights Reserved" (Mycroft AI); northern_english_male's recordings are CC BY-SA 4.0. Both sit on the same research-
only base. So northern_english_male is the less restricted one. The commentator is British, and so are his lines.

Why Piper: it is small (about 85 MB with the voice), fast on a processor (about 0.2 s for a line, below), works offline,
and has a mode where it stays running and takes one line after another, so the voice is loaded once. Other options
looked at: Windows' own voices (not on every PC, and they sound worse); sherpa-onnx with the Kokoro voices (better
sound and Apache-2.0, but its Windows program loads the voice again for every line, about a second each); the new
Piper (Python only).

## Fetching them again

`python -I tools/tts/fetch_tts.py <folder>` downloads the same four files, checks every sum, and lays them out:
`<folder>/piper/piper.exe` (with its DLLs and `espeak-ng-data`), `<folder>/voices/<voice>.onnx`, `.onnx.json` and
`.MODEL_CARD`, and `<folder>/downloads/` (the files as downloaded). `--check` only checks. On Max's PC they are in
`C:/Users/Max de Dikke/source/pwa_broadcast/tts`.

## Where the game looks for the speech program

The first of these that has `piper/piper.exe` and the voice:

1. `--tts_dir=<folder>` on the game's command line (after `--`);
2. the environment variable `MMZB_TTS_DIR` (for the development tree:
   `export MMZB_TTS_DIR="C:/Users/Max de Dikke/source/pwa_broadcast/tts"`);
3. the folder `tts` next to the game's own program: **in a play folder, `<play folder>/tts/`**.

## A play folder: what to copy where

`tools/release.sh build` now also copies the speech program and the voice into `.release/tts/` (from `MMZB_TTS_DIR`,
else from `../pwa_broadcast/tts` beside the repository). To add them to a play folder that is already built:

```
tools/release.sh tts "C:/Users/Max de Dikke/source/<play folder>"
```

That makes, next to `wsim.exe`:

```
<play folder>/tts/piper/piper.exe        (+ espeak-ng.dll, onnxruntime.dll, onnxruntime_providers_shared.dll,
                                           piper_phonemize.dll, libtashkeel_model.ort, espeak-ng-data/)
<play folder>/tts/voices/en_GB-northern_english_male-medium.onnx
<play folder>/tts/voices/en_GB-northern_english_male-medium.onnx.json
<play folder>/tts/voices/en_GB-northern_english_male-medium.MODEL_CARD
```

About 98 MB. The game's log says at the start of a watched race either "Commentary voice: ...piper.exe with the voice
..." (it speaks) or "Commentary voice: no speech program found (looked in ...)" (subtitles only).

## The keys and the settings

| Key / setting | What it does |
|---|---|
| **V** (watch mode) | The commentary on or off as a whole: the subtitles and the voice together (it comes on with the TV director, T, as before). |
| **Shift+V** (watch mode) | The voice alone on or off; the subtitles stay. |
| **Settings > Audio > Commentary** | The voice's loudness, 0 to 100 % (saved with the other volumes; on top of the master volume). |
| `--commentary_voice=0` | No voice at all (subtitles only). `--commentary_voice=1` lets a headless run speak too (for checks). |
| `--voice_log=1` | A line in the log for every line spoken: its wait and its length. |
| `--tts_dir=<folder>` | Where the speech program is (see above). |

The key row at the bottom of the full screen says "V, Shift+V commentary, voice" (checked in a 1280 x 720 screenshot:
the row still fits). The corner card says "Commentary on (V), voice on (Shift+V)"; the Watch button's tooltip on the
Race page names Shift+V.

## The numbers (all in `Game/config/commentary_default.tres`, group "The voice")

| Number | Value | Why |
|---|---|---|
| `voice_name` | `en_GB-northern_english_male-medium` | above |
| `voice_length_scale` | 0.9 | a little faster than Piper's own pace. He talks fast: at 1.0 the voice took 1.15 to 1.17 times his seconds for the starter lines; at 0.9 it is 7 % shorter (1.04 times his seconds with the characters' short names, 1.12 with the event's full names), and Whisper read the lines back as well (word errors 9 % against 11 %) |
| `voice_sentence_silence_s` | 0.15 s | the pause after each sentence (Piper's own: 0.2 s) |
| `voice_noise_scale`, `voice_noise_w` | 0.667, 0.8 | the voice's own defaults (its `.onnx.json`) |
| `voice_rate_by_level` | 0.97, 1.0, 1.03, 1.06 | levels 1 to 4. The sound is played that much faster: faster and higher together, like a tape. 1.06 is 6 % faster and one semitone higher. Piper cannot change the pitch or the speed per line while it stays running, so this is done when the sound is played. |
| `voice_db_by_level` | -2, 0, +1.5, +3 dB | levels 1 to 4: a shout a little louder |
| `voice_wait_share`, `_min_s`, `_max_s` | 0.3, 0.3 s, 0.8 s | how long a line's sound may be waited for |
| `voice_fade_s` | 0.06 s | the fade when a line is cut |
| `voice_warm_up_lines` | 400 | lines made ahead in the background (each 40 to 150 kB on the disk) |
| `voice_spellings` | 34 names (below) | names the voice says badly, spelled the way it says them well; only the sound changes, the subtitle keeps the name |

## The names: how the voice says them, and the spelling table

The voice reads every name by English rules (espeak-ng's British English). Most of the game's 20 characters come out
fine. Many of the event week's 64 provisional sailors (French, Dutch, Polish, Italian, Spanish, Danish, German ...) did
not: "Kacper Nowacki" came back as "caponarchy", "Daan Veldhuis" as "down well due", "Noe Roussel" as "no rustle".

How the table was made, without ears: every name was spoken in a sentence ("And it's <name> in first place.") and read
back by Whisper. For the names that came back badly a spelling was tried (68 words), spoken and read back again; a
spelling was kept only when the name came back nearer the sound it should have (34 kept; the other 34 changed nothing or
made it worse, and were dropped). This is a check by a speech recogniser, not by an ear: Max should listen to the names.

The table (`voice_spellings`; the written name -> what the voice is given; whole words only; the subtitle keeps the
name): Aiko -> Eye-ko, Elin -> Ellin, Ines -> Eeness, Noor -> Noo-er, Pia -> Peea, Tomas -> Tommas (the characters);
Noe -> Noay, Roussel -> Roossell, Thijmen -> Taymen, Malo -> Mallo, Garrec -> Garreck, Hinrichs -> Hinriks, Norgaard ->
Norgord, Tymon -> Timon, Zielinski -> Zhelinski, Dijkman -> Dikeman, Tiago -> Tee-ahgo, Corentin -> Corontan, Faure ->
Fore, Unai -> Oonai, Ole -> Oleh, Wilke -> Vilkeh, Kacper -> Katsper, Nowacki -> Novatski, Daan -> Dahn, Veldhuis ->
Velthouse, Gian -> Jahn, Baumann -> Bowman, Vasseur -> Vassur, Mathis -> Mateess, Giulio -> Julio, Tibault -> Teebo,
Marchetti -> Marketti, Croes -> Kroos.

Still said badly by the read-back, with and without a spelling tried (Max, listen to these first): Sven, Arne Declercq,
Wout Vermeire, Duarte Vilela, Axel Jaouen, Yanis Levasseur, Caio Fontes, Bastien Pradel, Iker Betancor, Loris Kerbrat,
Lucien Guivarc (the hard G), Koen Zeilstra, Gaspard Morvan, Callum Pengelly. Names that the read-back gets "wrong" but
that sound right in British English were left alone: Lena (heard "leaner"), Marco ("Mako"), Liv ("live"), Tobias ("to
bias"), Yusuf ("use of"), Ruben Brouwer ("Reuben Brower"), Jonas Lorenz ("Lawrence").

## The wait before a line is heard

Measured on this PC tonight, while it was busy (the speech-to-text of the streams on 10 threads, Whisper, two or
three other workers' Godot runs).

**The speech program alone** (`tools/tts/speak_lines.sh`, every line made afresh, one at a time, the program kept
running): 244 lines (the 76 bank lines with names filled in, 84 names alone, 84 names in a sentence). Making a line
takes **0.19 s** in the middle, 90 % within 0.28 s, the worst 0.81 s (the first line: the program was still loading its
voice). A name alone: 0.12 s.

**In the game** (a watched race, headless, the editor build, 8 AI boards on the T1 course, TV director and commentary
on, `--commentary_voice=1 --voice_log=1`; 4 minutes): 56 lines heard.

| | Lines | Wait before the sound |
|---|---|---|
| From the disk (spoken before, or made ahead in the background) | 26 | 0.001 s in the middle, worst 0.003 s |
| Made when the line started | 29 | 0.36 s in the middle, 90 % within 0.68 s, worst 0.72 s |
| Too late: silent (only its subtitle) | 1 | the very first line, while the program was still loading its voice |

Over all 55 lines played: 0.18 s in the middle, worst 0.72 s. An earlier, shorter run (6 boards, 24 lines): 12 from the
disk, 11 made, 1 too late (again the first line); worst 0.47 s.

In the game the lines made on the spot wait longer than in the tool (0.36 against 0.19 s): the game's own work (8 boards'
physics in the editor build) shares the processor with the speech program. The release build needs less. A line on the
disk has no wait at all, and the disk fills as the game is played: the bank's fixed lines are made ahead in the first
minute, the race's names alone first.

**So the subtitle and the sound:** the subtitle shows at once; the sound comes at once for a line on the disk and about
a third of a second later for a new line on this busy PC. The subtitle does not wait for the sound (a short lead, as TV
subtitles often have); a line whose sound would come more than 0.3 to 0.8 s late is not said.

## Read back by Whisper: does the voice say the words right?

RESULT_READBACK

## What is tested

`Game/tests/unit/test_commentary_voice.gd`, 19 tests, with a stand-in for the speech program (no program runs, no
real sound): a line asked and played when made, kept under its real name only when complete; a line on the disk
played at once; the same words the same file, other voice numbers another; too late dropped, not said late; the wait
allowed; a new line fading the old one out; a line cut short fading out; a cut line whose sound comes later not
played; the voice switched off; the level's rate and loudness; a pair's second line made ahead; the names' spelling
(whole words only); the warm-up's lines and order, one at a time; the race's names first; the director waiting for a
slower voice and the breath after it; the voice telling the length of its sound; the missing program (silent, no
error). Also: the Commentary bus and its slider (`test_audio.gd`), the setting saved and loaded
(`test_game_settings.gd`), watch mode's key (`test_commentary.gd`).

## Files

- `Game/race/commentary/speech_engine.gd` (`SpeechEngine`): finds and runs the speech program, one line at a time.
- `Game/race/commentary/commentary_voice.gd` (`CommentaryVoice`): the voice in the game: the lines, the disk, the
  waits, the fades, the levels.
- `Game/race/commentary/commentary.gd`: makes the voice; passes on `line_stopped` and `line_ahead`; `line_lasts()`.
- `Game/race/commentary/commentary_director.gd`: `line_ahead` (a pair's second line), `line_lasts()` (wait for the
  voice).
- `Game/race/commentary/commentary_subtitles.gd`: `last_at_least()` (the subtitle stays as long as the voice).
- `Game/race/commentary/commentary_config.gd`, `Game/config/commentary_default.tres`: the voice's numbers.
- `Game/default_bus_layout.tres`: the Commentary bus. `Game/audio/game_audio.gd`, `Game/ui/settings_values.gd`,
  `Game/ui/settings_menu.gd`: its volume slider.
- `Game/race/watch_mode.gd`, `Game/ui/race_page.gd`: Shift+V and the help.
- `Game/dev/voice_run.gd`, `tools/tts/speak_lines.sh`: every line of the bank and every name to WAV files, without
  the game. `tools/tts/read_back.py`: Whisper reads them back. `tools/tts/fetch_tts.py`: the downloads and their sums.
- `tools/release.sh`: copies the speech program into `.release/tts` (and `tools/release.sh tts <play folder>`).

## What is not done, and what Max should listen for

**Not verified:**
- **Nobody has heard it.** Whisper says the words mostly come out right; it cannot say whether the voice sounds good,
  flat or robotic, whether the shouted lines sound natural, or whether it is loud enough over the wind and the water.
- **The release build and a play folder with the voice.** Not built here (the lead builds it). The copy step
  (`tools/release.sh tts <folder>`) was run into a scratch folder (98 MB, the right files), and a copy of the engine
  put in that folder, started without `MMZB_TTS_DIR`, found `<folder>/tts` beside itself and spoke. The game's own
  headless runs used the editor build with `MMZB_TTS_DIR`.
- **On Michiel's or another PC.** The speech program needs no install (a folder of files), but only this PC ran it.
- **Real speakers.** The tests and the headless runs use Godot's silent audio driver.

**Not done:**
- **His voice.** On purpose: it waits for his yes (above).
- **A voice we may release.** The voice's base is licensed for research only (above). Before anything goes public,
  another voice.
- **Pitch and speed per line inside the speech program.** The program kept running takes one speed for all lines; the
  levels change the playback rate instead (faster and higher together, modestly).
- **The subtitle waiting for the sound.** It shows at once; a new line's sound follows a third of a second later on a
  busy PC (above). It could wait for the sound, at the cost of the subtitle coming later.
- **Cleaning up the disk.** Every new line (with its names) is a file of 40 to 150 kB in the game's user folder
  (`commentary_voice/`); nothing deletes old ones. A long evening of watching makes some tens of MB. The folder can be
  deleted at any time; it fills again.
- **The bank of thousands of lines.** Built for (the same format; up to 400 of its fixed lines are made ahead), but
  only run with the 76 starter lines.
- **The player's own race, a LAN game.** The voice is where the commentary is: watch mode only today.

**What Max should listen for:**
1. Can you understand it over the wind and the water? Too soft or too loud: Settings > Audio > Commentary.
2. Does the voice come with the subtitle? (A new line about a third of a second after its subtitle is expected; more
   than that, or a line that never speaks, tell us.)
3. The names, above all a name on its own: the list of names still said badly is above.
4. The shouted lines (a lead change, a fall, the finish): a little faster, higher and louder. Natural, too little, or
   silly?
5. The pace: is it too slow next to the real commentator? (`voice_length_scale`; see the numbers.)
6. Any line cut off in the middle, or a click when a big moment cuts in?
7. Shift+V (the voice off, subtitles only) and V (all off) do what you expect?
