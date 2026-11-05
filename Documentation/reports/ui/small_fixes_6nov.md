# Six small fixes for the play-test of 6 November 2026

Branch `fix/small-6nov` (from `1de5791`), worktree `WindsurfingMMZB-fixes`. Six items of the roadmap: RA24, RA2, TE1, UI4, SO3 and MA2. Nothing in `Game/sim/` changed. ROADMAP.md, the progress log and the changelog were not touched (the lead updates them).

**Checks before the last commit:** `tools/check.sh`: 426 files checked, 0 failed. `tools/test.sh` (all unit tests): 79 scripts, 751 of 751 tests pass, 83,544 asserts (309 s). `tools/lan_test.sh` (a race on the open water, 40 s) and `tools/lan_test.sh --map=lake --seconds=60`: SYNC CHECK: PASS on the final code (both PCs saw every board in the same place; the worst difference was 0.0000 m; no script errors in either log). Both also passed after RA24 and RA2.

**What I could not check:** how the start sounds sound (I cannot listen), and how the AI boards behave at the lake's shore in a whole race (no headless tool runs the scene's race on the lake). Max checks both in his play-test.

## The commits

| Commit | What |
|---|---|
| `a958d9d` | `tools/screenshot.sh --resolution=WxH`: a screenshot in another window size (needed for UI4 and MA2) |
| `0b881d5` | TE1: the bus layout file in the form Godot itself writes, and a test that keeps it so |
| `cbe2f45` | TE1: `project.godot` as the editor saves it |
| `6cfd63f` | RA24: in a race a new wind waits for R, then blows for every board |
| `74adaac` | RA2: the AI boards stop at the lake's shore |
| `d5ea9b0` | SO3: the start's horns, beeps and gun |
| `b830d5d` | UI4: the start menu fits any window |
| `6949b02` | RA24, RA2: a change in the runner so `tools/check.sh` passes again (see "A trap in Godot" below) |
| `54d8fe4` | MA2: the Credits page |
| (this report) | The report and four screenshots |

---

## RA24: a wind changed in the pause menu during a race

**What was wrong.** `main.gd`'s `_apply_wind_settings_live()` turned the player's wind only. Each AI board sails its own copy of the wind (a board stepped on a worker thread must share nothing), so the fleet kept the old wind; the course stayed laid to the old wind; and at R the AI boards did not get the new sea either: `_restart_run()` rebuilt only the player's.

**The decision: in a race the new wind waits for R, then every board gets it at once.** Why:
1. The sea already waits for R in a race (Session 67). Turning only the wind would leave the waves running with a wind nobody sails in, which is what Max asked to avoid on 2 November.
2. The course is laid to the wind. It cannot move under the boards in the middle of a race, but it can be laid again at a new start.
3. A race is sailed in the conditions it started in, the same for the whole fleet, as in a real race.
4. It is the safe choice: nothing changes while the boards are being stepped, and the AI skippers start from a clean state.

**What changed.**
- In a race the pause menu says "Restart (R) to sail with the new wind" (and "the new waves" when the sea changed too).
- At R the player's board gets the new wind and waves. Every AI board takes a copy of them (`RaceRunner.give_the_fleet_the_sea_of()`). A course laid for the wind (T1 and the iQFOiL templates on the open water) is laid again for a turned wind, with its buoys, the mini-map and the area where the AI boards sail free. The time trial looks up the best time for the new wind.
- Free sailing does not change: there the new wind blows at once.
- On the lake nothing changes: the lake keeps its own wind.
- LAN games do not change: the host's wind stays fixed for the whole game (MP3), and the host's R restarts the race without a new sea.

**How it was checked.** A new test (`test_menus.gd`): in a race with two AI boards, a new wind (24 kt from 300°) leaves all three boards in the old wind and the pause menu says R brings it. After R all three sail 24 kt from 300°, each with its own copy and one wind clock; the course is laid for 300° and the race is sailed on it. A second test: after R every AI board sails the new waves too. `tools/lan_test.sh` passes on the open water and on the lake.

**What Max should check.** Race on open water. Esc, Settings, turn the wind to another direction and speed, Back: the race goes on in the old wind, and the menu says R brings the new one. Press R: the buoys are laid for the new wind, and the AI boards sail in it (watch the wind arrow and their sails).

**Left open.** The AI personas choose their gear for the wind of the race's first start, and keep it after a new wind at R. Giving them new gear means building their boards again; that is a bigger change.

## RA2: the AI boards stop at the lake's shore

**What was wrong.** The player's board stops where the water is shallower than its fin plus 12 cm (`main.gd`'s `_check_shore()`, `ShoreCheck`). The AI boards sailed on through the land.

**What changed.** After each tick the race runner checks every AI board with the same `ShoreCheck`, with that board's own fin. A board that has run aground is no longer sailed or stepped: it stays where it is until the next start (R, or the host's R in a LAN game), when every board is afloat again at its start spot. The race goes on without it (it does not finish). The race's wind clock is read from a board that still sails. On the open water (no shore) nothing changes. The physics' own version (PH13) comes later.

**How it was checked.** A new test (`test_race_runner.gd`) puts an AI board on land with the shore between it and the player: the AI board stops and stays where it is, the player sails on, the wind clock goes on, and after R the AI board sails again. `tools/lan_test.sh --map=lake` passes.

**What Max should check.** Race on Lake Silvaplana and watch the AI boards near the shore: a board that reaches the shallows should stop there, not sail onto the land. Tell me if many boards stop in a normal race; that would mean the AI skippers sail too close to the shore (not measured: no headless tool runs this race in the scene).

## TE1: why Godot rewrote `Game/default_bus_layout.tres`

**The cause.** The editor's Audio panel (Godot's `EditorAudioBuses`) loads the bus layout when the editor starts, marks it as edited, and saves it again 0.8 s later (`save_timer`, wait time 0.8 s, in `editor/audio/editor_audio_buses.cpp` of Godot 4.7.2). The editor also starts inside `godot --headless --import`, which every tool script runs first (`import_project` in `tools/common.sh`). A short import quits before the 0.8 s are up, so only the long runs saved the file: the first import of a new checkout or worktree, an import after many changed files, and every time the editor is opened.

The hand-written file was not in the form Godot writes: it had no uid in its first line, and it wrote out a value that is Godot's default (the flutter filter's cutoff of 2000 Hz). So Godot's save differed from the file, git showed it as changed, every session restored it, and the next long run wrote it again.

**The fix.** The file is now exactly what Godot writes: its uid in the first line, and the default cutoff left out (the cutoff is still 2000 Hz, Godot's default). The editor still saves it, but with the same bytes, so git sees no change. A new test (`test_audio.gd`) loads the file, saves it again and compares: a hand edit that Godot would rewrite now fails the tests. (The new Signals bus of SO3 was added in Godot's form, and the test passes.)

Opening the editor also saved `project.godot` without the line `buses/default_bus_layout="res://default_bus_layout.tres"`, because that is Godot's default value (this is why `tools/steer_check.sh` and `tools/autopilot_suite.sh` restore `project.godot` too). That line is gone now; the game loads the same layout (the bus tests pass).

**The proof (git status before and after each run):**

| Run | Before | After |
|---|---|---|
| A fresh import (Godot's cache moved away first: the run that used to rewrite the file) | clean | clean; the file's time stamp changed, so Godot did save it, with the same bytes |
| `tools/screenshot.sh` | clean | clean |
| `tools/play.sh` (30 s) | clean | clean |
| `tools/edit.sh` (the editor, 45 s) | clean | first time: `project.godot` (the default line, now committed); twice more after that: clean |
| `tools/test.sh` (all unit tests, 5 minutes) | clean | no tracked file changed (only this report's new files, written during the run) |

Before the fix, the first import of this new worktree changed the file (the uid added, the cutoff line removed).

**What Max should check.** Nothing in the game. After pulling this branch, `git status` should stay clean after an import, the tests and opening the editor. If the file shows up again, tell me which command you ran.

**Left open.** `tools/steer_check.sh` and `tools/autopilot_suite.sh` still restore both files after their runs; that is harmless now and can go later.

## UI4: the start menu at any window size

**What was wrong.** In a 1280 × 720 window the main page needed 749 pixels of height and the Race page 837 (measured), so both were cut off: the title at the top and the buttons at the bottom. In Max's 3137 × 1263 window the menu stayed small in a corner. (Screenshot before: `small_fixes_menu_before_1280x720.png`.)

**What changed.** While the start menu is up, the window uses Godot's own "canvas items" stretch for a layout of 1280 × 800 that expands with the window: the pages are drawn as big, compared to the window, as in a 1280 × 800 window; a wider window gives them more room across; and Godot draws the text, lines and panels at the window's full resolution, so they stay sharp. No `Control.scale`. The project's stretch settings do not change: when the menu goes (the game starts, or the lake, the wind viewer or a LAN game takes over), the window gets its own scaling back, so the HUD keeps its sizes. The wind viewer does the same for its panels. The pages stay anchored to the window's edges or centred in it. The Race page's list of skippers is 110 pixels high instead of 150 (it scrolls), so that page fits too.

In numbers (worked out from the 1280 × 800 layout): a 1280 × 720 window draws the menu at 0.9 of its old size, 1920 × 1080 at 1.35, and 3137 × 1263 at 1.58.

**How it was checked.** Screenshots at 1280 × 720, 1920 × 1080 and 3137 × 1263, before and after, which I looked at: the title, every button and the version line are on screen in all three, and the text is sharp. The Race page at 1280 × 720 shows its title and its Start button. A race started from the menu shows the HUD at its usual size. A new test (`test_menus.gd`) checks the scaling while the menu is up, that the main page (with its "Loading..." line) and the Race and How to sail pages fit in 800 pixels, and that the game gets the window's scaling back. Screenshots: `small_fixes_menu_after_1280x720.png`, `small_fixes_race_page_after_1280x720.png`.

**What Max should check.** Open the game in your usual wide window, in a small one and in full screen: the title and every button of the start menu, and of each page (Gear, Settings, Race, Credits), should be in full view and sharp. Then start a race and check that the HUD looks as it always did.

## SO3: the countdown sounds and the gun

**What was intended.** The archived `RACING_PLAN.md` (Phase 9A): "Sounds at 60, 30, 10 and 5 to 1, and the gun, made from noise like everything in Phase 8."

**How the game makes its sounds.** `SoundBank` (`audio/sound_bank.gd`) makes every sound from numbers when the game starts (noise and tones shaped by filters and envelopes; no sound files). `GameAudio` plays them on Godot's audio buses (`default_bus_layout.tres`: Wind, Water, Sail and their filters), at levels from `config/sound_mix_default.tres`.

**What changed, the same way.**
- `RaceStartSignals` (`race/race_start_signals.gd`) says which signal is due as the countdown runs, as at a real start: the start boat's long horn at every whole minute before the gun (and at the countdown's first moment when that is not a whole minute); a short horn at 30 s; the beep of the sailor's start watch at 10 s and at 5, 4, 3, 2 and 1 s; the gun at 0.
- `SoundBank` makes four sounds:
  - the horn (2 s long, 0.8 s short): a bright, brassy 400 Hz tone, every harmonic up to 5 kHz, with a second reed at 403 Hz so the blare beats slowly, as a real air horn's does. It rises into tune over the first tenth of a second while the air pressure builds, with a breath of air under it;
  - the beep: 0.12 s of a square-ish 2.8 kHz tone, like a small piezo speaker;
  - the gun: a sharp crack, a low boom sliding from 110 to 45 Hz, a rumble, and two duller echoes from the shore after 0.4 s and 1.1 s.
- They are made when a race is set up, not when the game starts: they take 0.25 to 0.38 s (measured four times on this PC), which a game without a race need not wait for.
- They play on a new bus, Signals (into Master), at `horn_db = -4`, `beep_db = -14` and `gun_db = 0` in `config/sound_mix_default.tres` (change them there, or move the Signals fader in the editor's Audio tab). A far camera does not make them quieter: they are the race's call. The player's Master volume covers them.
- On a LAN guest the race's mirror sounds the same signals on the host's clock. A signal never sounds twice when the guest's clock is set to the host's, and a guest that joins late does not hear the missed signals all at once.

**How it was checked.** Tests (`test_race_start_signals.gd`, `test_audio.gd`): a 60 s countdown gives the long horn, the short horn, six beeps and the gun, each once and on the tick of its moment; 3 minutes gives a horn at every minute; a clock that jumps back plays nothing twice. The horn's strongest tone is 400 Hz (more than three times 300 or 500 Hz) with strong harmonics, and it swells in. The beep is 2.8 kHz. The gun is loudest in its first 10 ms, has a low boom, and its echo comes back after 0.4 s. A race in the scene sounds its start on the Signals bus. To listen without a race, the four sounds are saved as WAV files in the worktree's `.sim_output/start_sounds/` (not committed).

**What Max should listen for** (I cannot listen, so this is the real check):
1. The horn: does it sound like a start boat's air horn, not like a car horn or an organ? Too buzzy, too thin, or the wobble too strong?
2. The long horn (2 s) against the short one (0.8 s): clearly different?
3. The beeps: like a watch on your wrist? Loud enough to count down the last seconds over the wind, not piercing?
4. The gun: a sharp bang with a boom and an echo from the shore, not a click or a thud? Does it startle a little, as a gun should?
5. The levels against the wind and the water at 18 kt: can you hear every signal?
6. The timing: does each signal fall on the countdown's number? (The sound starts on the tick; there is no delay for the sound to travel from the start boat.)

## MA2: the credits screen

**What changed.** The start menu has a Credits button between "How to sail" and "Quit". The page (`ui/credits_page.gd`, `.tscn`) is anchored top to bottom, centred, scrolls (mouse wheel, arrow keys, Page Up and Down; Esc or Back goes back), and fits the menu's window (UI4). Screenshot: `small_fixes_credits_1280x720.png`.

**What it says.**
1. The game: made by the MMZB team; the models, the brands and the sounds are the game's own; the text uses the computer's own fonts.
2. The open data: the roadmap's line "Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU.", then each source in the wording its provider's terms ask for:
   - swisstopo: "Federal Office of Topography swisstopo" and "©swisstopo" are the accepted forms ([swisstopo, OGD conditions](https://www.swisstopo.admin.ch/ogd-conditions); a game may name its sources in a list: [swisstopo, attribution FAQ](https://www.swisstopo.admin.ch/en/source-reference-ogd-swisstopo)).
   - swissALTIRegio (the distant mountains, from `tools/map/heights.py`) has its own, longer reference, which names the neighbouring countries' height models, TINITALY among them ([swisstopo, swissALTIRegio](https://www.swisstopo.admin.ch/en/height-model-swissaltiregio)). The page gives the wording for the versions of 2025 and later; the first 2024 version names EU-DEM instead of the Baden-Württemberg model.
   - MeteoSwiss: "Source: MeteoSwiss", under CC BY 4.0, and it must not suggest that MeteoSwiss supports the game ([MeteoSwiss, terms of use](https://opendatadocs.meteoswiss.ch/general/terms-of-use)).
   - BAFU: its terms for hydrological data could not be opened (the PDF's address gave "404 Not Found"), so the roadmap's "Lake level: BAFU" stands.
3. Godot Engine: "This game uses Godot Engine, available under the following license:" with Godot's MIT text, as [Godot's own page on licences](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html) recommends. Then every part Godot is made of (102 components: FreeType, HarfBuzz, mbedTLS and so on) with its copyright holders and licence, and all 19 licence texts. These are read from the engine (`Engine.get_license_text()`, `get_copyright_info()`, `get_license_info()`), so they always match the Godot the game is built with.
4. Third-party files I found in the repository: only GUT, the test framework (`Game/addons/gut/`, MIT, Copyright (c) 2018 Tom "Butch" Wesley), with four fonts under the SIL Open Font License 1.1: Anonymous Pro, Courier Prime, Lobster Two and a bitmap font named Source Code Pro (by Adobe; that one is labelled from its name). The export preset ships every resource (`export_filter="all_resources"`), so GUT is in the game's package and its notices are on the page. The game's own fonts are system fonts (`SystemFont` in `ui/theme.tres`), its sounds are generated, its models are built by the team's Blender scripts, and its icon is the team's own. No satellite pictures (Copernicus) are in `Game/`.

The text has 90,000 characters and is put together the first time the page opens (measured: about 0.1 s).

**How it was checked.** A new test (`test_menus.gd`): the Credits button opens the page; it contains the roadmap's line, each provider's wording, Godot's notice and copyright, its parts, GUT and its fonts, and every licence text; the page fits; Back returns to the main page. Screenshots at 1280 × 720 and 3137 × 1263, which I looked at.

**What Max should check.** Open Credits from the start menu and scroll through it. Check that the data line reads as you want it.

**Left open, for the team.**
- BAFU's wording is not checked against its terms.
- Which swissALTIRegio version `tools/map/download.py` fetched (it takes the current one) decides which of the two wordings applies; the page has the 2025 one.
- GUT need not be in the shipped game. Leaving `addons/gut/` out of the export (an `exclude_filter` in `export_presets.cfg`) would make the game smaller, and its notice could then go. I did not change the export.

---

## A trap in Godot found on the way

After RA24, `tools/check.sh` failed although every script loaded: when Godot quit it reported "63 ObjectDB instances leaked" and "54 resources still in use", and the check counts every ERROR line. The game itself ran as before. Bisecting the branch's commits and then the race runner's changes found the cause: a small helper (`_shore_grid()`) replacing the scene lookup in `setup_race()`. With the lookup back where it was, the leak is gone (`6949b02`). Why this one change makes Godot's script clean-up at exit miss a cycle is not clear (a quirk of the engine). Worth knowing: if `tools/check.sh` fails with only "leaked at exit" lines, run a script that does nothing (`godot --headless --path Game --script empty.gd`) to see whether loading the project alone leaks, and bisect.

## Changes to the tools

`tools/screenshot.sh` takes `--resolution=WxH` among its extra options (the default stays 1280x720), for example `tools/screenshot.sh res://ui/start_menu.tscn wide.png 120 --resolution=3137x1263`. CLAUDE.md does not mention it yet (the lead may add it).
