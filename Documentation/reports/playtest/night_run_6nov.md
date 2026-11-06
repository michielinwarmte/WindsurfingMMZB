# The night run of 6 to 7 November 2026: the AI on the courses, and the rest of the evening's checks

Max, 6 November 2026 at about 21:00, on the race-types agent's AI race sweeps: *"finish this now, this is not necessary right now, this will be the night's run. Then this will continue. Document good please."* So the long headless measurements of the evening's work run tonight, unattended, on the final play-test code (`play/6nov-evening`, the `WindsurfingMMZB-play-6nov2026-night3` build), and the next session reads the results before the work continues.

Everything here is headless simulation: the AI fleet (the eleven personas) and the autopilot sail the courses with the game's own physics; nobody is at the keys. The evening's ledger with every branch, report and open question is [six_asks_6nov.md](six_asks_6nov.md).

## How it runs

- The script: `Documentation/reports/playtest/night_run_6nov.sh`, run from the repository root of the worktree `WindsurfingMMZB-playtest` (it `cd`s there itself). The lead starts it detached at the end of the session, so it survives the session's end. It runs the parts below one after another and writes every log to `.logs/night_6nov/`; `00_progress.txt` there says which part it is on and when each finished.
- The summary: `python -I Documentation/reports/playtest/night_run_6nov.py` reads those logs and writes [night_run_6nov_results.md](night_run_6nov_results.md) (the tables below, filled in). The script runs it at the end; it can be run again at any time for a partial picture.
- Stopping it: close the console window it runs in, or end the `bash` process; each part's Godot processes end with it. Nothing it does changes the code; it only writes under `.logs/` and `.sim_output/`.
- The PC should be idle (the frame-time part needs that); the LAN part needs the game's port 47520 free (no play build running).

## The parts, in order, with the commands

### A. The AI fleet on every iQFOiL course, by race type (about 2.5 to 3 hours)

Why: the race-types agent's slalom start (the boards wait upwind of the committee boat and reach down onto the line) and the race type on each template were built, but its measurement of the fleet's starts per type was stopped on Max's word. Each course is raced once with the eleven personas on Lake Silvaplana at 14:30, the lake's own waves, seed 1, the race ending 10 minutes after the first finisher:

```
P=persona:hana,persona:marco,persona:mara,persona:bruno,persona:liv,persona:aiko,persona:elin,persona:greta,persona:ines,persona:jonas,persona:kofi
for c in iq_pd3 iq_sd3 iq_lg2 iq_lr2 iq_o2 iq_i2 iq_us3 iq_us4 iq_pm1 iq_sm1; do
  tools/race.sh --course=$c --map=lake --skippers=$P --seed=1 --finish_window=600 > .logs/night_6nov/race_$c.log 2>&1
done
tools/race.sh --course=t2_slalom --skippers=$P --seed=1 --finish_window=600 --wind_kt=18 > .logs/night_6nov/race_t2_slalom.log 2>&1
tools/race.sh --course=t1_loop --skippers=$P --seed=1 --finish_window=600 --wind_kt=18 > .logs/night_6nov/race_t1_loop.log 2>&1
```

The race type comes from the template (PD3 and SD3 and T2 slalom; LG2, LR2, O2, I2 course; US3, US4, PM1, SM1 hybrid). What to read per race: finishers and DNF, the first finisher's time, the fleet's falls, boards over early (OCS), not started, outside the sailing area at the gun, the longest start delay (the "start" summary each race prints). What a good result looks like: no OCS, everyone started within about 40 s, no groundings (a DNF with "to mark" far from the course means a board stuck), falls near the 1 per race the autopilot work measured on O2 and LG2.

To compare a slalom sailed as a course race (the old upwind start): `tools/race.sh --course=iq_pd3 --map=lake --skippers=$P --seed=1 --race_type=course`. Not in the script (a morning question, if the slalom numbers look wrong).

### B. The autopilot's recovery reflex, swept (about 1.5 hours)

Why: the stay-on-the-board agent set the reflex's numbers from the fall records and did not sweep them ("not swept" in its report), and the lake sets were not re-run after its last change (the one-second wait before the step forward). The suite runs the lake part and the manoeuvre matrix for each variant in `Documentation/reports/autopilot/rounds/night6nov_reflex.txt` (the base = the shipped numbers, then one number moved at a time: the reflex earlier or later, a deeper ease, the last chance later, a stronger bear-away, the tip reflex earlier):

```
tools/autopilot_suite.sh --round=night6nov_reflex --variants=Documentation/reports/autopilot/rounds/night6nov_reflex.txt --only=lake,matrix --cores=10
python -I tools/autopilot_summary.py night6nov_reflex --table
```

What to read: falls and the speed made good per variant against the base; a variant is only better if it falls less at the same speed (within 2 %). The base row is also the re-run of the lake sets on the shipped code.

### C. The manoeuvres with the player's hands, everything at once (about 15 minutes)

Why: the manoeuvres agent measured 5 falls in 45 at 24 kt with every new part used at once (the key, the body carve, the back foot and the cue); which part tips it over is not known.

```
tools/matrix.sh --winds=24 --hold_turn --body_carve --body_back --cue > .logs/night_6nov/matrix_all_24.log 2>&1
tools/matrix.sh --winds=24 --hold_turn --body_carve --cue > .logs/night_6nov/matrix_no_back_foot_24.log 2>&1
tools/matrix.sh --winds=24 --hold_turn --body_back --cue > .logs/night_6nov/matrix_no_carve_24.log 2>&1
```

What to read: the falls per run (the agent's rows: hands-off 0, each part alone 0, all 5).

### D. The frame time on an idle PC (about 10 minutes)

Why: every frame-time number of the evening was taken on a shared PC (other agents' Godot runs, the live play-test). The release pack in `.release/` is the night3 build's.

```
tools/fleet_measure.sh --sizes=12,20 --seconds=12 --course=t1_loop > .logs/night_6nov/fps_open.log 2>&1
tools/release.sh --mute --race=iq_o2 --map=lake --skippers=$P --measure=12 > .logs/night_6nov/fps_lake_12.log 2>&1
tools/release.sh --mute --race=iq_o2 --map=lake --skippers=$P --measure=12 --render_size=3137x1263 > .logs/night_6nov/fps_lake_12_wide.log 2>&1
```

What to read: fps and the graphics card's ms per frame; the morning's reference of 6 November was 65 to 68 fps for a 20-board lake race at 1280 x 720 (full waves), 82 with the old waves.

### E. The validation suite, with the names (15 minutes)

Why: the lead's evening run on the merged tree gave 38 pass, 8 fail, 2 pending, the known counts, but the command kept only the summary, not the eight names.

```
tools/test.sh validation > .logs/night_6nov/validation.log 2>&1
```

What to read: the eight failing names must be the known reds (the planing onset, the 12 kt skipper limit 12:21.4 and the others listed in the autopilot report's checks); a ninth name, or a missing one, is news for Michiel.

### F. LAN on the release build, with a spectator and a late joiner (10 minutes)

Why: the spectate agent's LAN tests ran on the editor build; the night3 release build was not LAN-tested on this PC.

```
tools/lan_test.sh --map=lake --seconds=40 --release=1 > .logs/night_6nov/lan_lake.log 2>&1
tools/lan_test.sh --map=lake --guests=2 --spectate=1 --late=20 --time_limit=25 --director_gap=5 --robot=allrounder --prestart=10 --seconds=90 --release=1 > .logs/night_6nov/lan_lake_spectate_late.log 2>&1
```

What to read: "SYNC CHECK: PASS" in each, and the spectator's and the late joiner's lines of the check.

## What the morning session does with it

1. Run the summary (`python -I Documentation/reports/playtest/night_run_6nov.py`) and read [night_run_6nov_results.md](night_run_6nov_results.md).
2. Put the race-type numbers into the race-types report (`Documentation/reports/ui/race_types_6nov.md`, section 3: "before and after" has the before; the night gives the after per course) and the reflex table into the autopilot report's rounds.
3. Anything red (an OCS fleet on a slalom, a grounding, a new validation name, a LAN FAIL) becomes a roadmap row and a line for Max before anything else is built.
4. Then the evening's open questions for Max and Michiel (the ledger's list), and the work continues.

## What the night cannot answer

The look and the feel: the whitecap amount, the crest bursts at 30 kt, the spray, whether the fall's bar is now too lenient for a player, the flip cue, the start pins' look, UI scale for the menus. Those are Max's eye on his screen, with the night3 folder. And the physics numbers of the fall's bar and the fins' stiffness are Michiel's OK.
