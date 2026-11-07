# The session recorder: what the real game did, from Max's own sailing

Built 7 November 2026 (commit 7828498, branch `physics/realism-7nov`) after Max asked "how can I get to you
that you are not fixing the problem, what do you need?". The test harnesses (`run_lake`, `run_night`,
`run_lake_speed`) drive the controller without the game's input, menus and settings, so a fault that only
shows in the game never shows in them. The recorder runs inside the real game.

## For Max: how to record

1. In the play folder, double-click **"Record a session - push and body on the mouse.bat"**. It starts the
   game like "Start the game - push and body on the mouse", and records to `recording.csv` next to the
   launcher. Each launch overwrites the last recording, so copy the file away to keep it.
2. Sail. When the weird thing happens, note roughly when (seconds after the start, or what you did just
   before).
3. Close the game and tell Claude where the file is and what happened. The file is written as you sail,
   so it is complete however the game ends.

## What is in the file

- Line 1: `# settings: night_tuning=... recovery_reflex=... balance_stance=... mode=... auto_sheet=...
  autopilot=... body=...`, so a recording says which switches were on.
- Line 2: the column names. Then one row every 6 physics ticks (10 rows a second) while sailing; nothing is
  written while a menu is open.
- Columns: the full telemetry row (`Telemetry.csv_header()`: time, position, speed, heading, pitch, heel,
  the wind at the sail, the sail's angle and forces, the fin, the hull, the sailor's stance and forces, the
  yaw, roll and pitch moments), then:
  - the controller: `c_wanted_rate_dps`, `c_held_heading_deg`, `c_turn_key`, `c_push_now`, `c_push_level`,
    `c_reflex`, `c_player_steered`, `c_head_up_deg`, `c_manoeuvre`;
  - the controls sent to the physics: `ctl_rake`, `ctl_rig_tilt`, `ctl_lean`, `ctl_back_foot`, `ctl_sheet`;
  - the mouse body: `body_side`, `body_back`;
  - `keys`: the actions held (space-separated: steer_left, steer_right, steer_sharp, tack, sheet_in,
    sheet_out, push_more, push_less, rake_back, rake_forward).

## For the lead: running it without Max

The same recorder runs headless on any scene, with Max's settings file:

```
"$GODOT" --headless --path Game --quit-after 4000 res://maps/silvaplana/sail_silvaplana.tscn -- \
  --settings=<path/to/push_and_body.cfg> --record=<out.csv>
```

`--quit-after` counts frames (4000 is about 67 s). With no keys held this records the autopilot's start; to
compare builds, run the same command in another worktree (for example `WindsurfingMMZB-old6nov`, the
6 November evening-keys build f72f565) and compare the rows.

## What it has found so far

- **The start's spin** (7 November): at 2.5 s and 7 km/h the nose is 0.24 m under and the water's yaw moment
  (280 to 413 N m) pivots the board about 30 degrees off the wind; the 6 November build does the same. Hull
  physics, open (backlog E01.S18). Report: `Documentation/reports/physics/realism_audit_7nov2026.md`, last section.
- **The sheet keys' stall and dump** (Max's recording `.sim_output/realgame/max_recording_2355.csv`, rows 103
  to 137): fixed in 9e97706.

## Where it can help next (backlog E17.S10)

The recorder is a general tool, not a physics one. Ideas, none built yet:

- **A marker key** (for example F8) that writes a "this was weird" row, so the moment is easy to find.
- **Replay**: feed a recording's keys back into the game headless, so a play-test turns into a repeatable
  test; then before and after a fix can be compared on the exact same input.
- **Record the AI boards** in a race (`--record_ai=`), to see why an AI falls or sails a strange line.
- **LAN**: record on both PCs in a two-PC race and compare the boards' positions (the sync check).
- **Settings and screens**: a row with the window size and UI scale, for the UI-on-any-window-size work.
- **Performance**: the frame time per row, for the 60 fps goal (E17).
