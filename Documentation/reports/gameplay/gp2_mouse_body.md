# GP2: the sailor's body on the mouse (package B), the first play-testable build

**Branch:** `gp2/mouse-body`, from `main` at 1de5791. 5 November 2026, for the play-test of 6 November. One Opus builder, no agents. **Nothing in `Game/sim/` changed:** the mouse writes two numbers the push slider already writes (the PH3 hooks `SimControls.rail_bank_extra_deg` and `trim_aim_extra_deg`); every speed, bounce and fall below is the simulation's own answer. The design is section 5 of [feedback_5_november_2026.md](../playtest/feedback_5_november_2026.md); the items are GP2 and GD7 in [ROADMAP.md](../../../ROADMAP.md).

## 1. In short

- **Start it:** `tools/play_body.sh` (18 kt, gusts and waves, a beam reach, the slider at 75 %, the body on). In the game: Esc > Settings > **Body** > "Mouse body (experiment)".
- **The mouse is the sailor's body while sailing.** Sideways is the rail (how far the leeward rail goes down; the other way, a flat board). Pull the mouse back (toward you) and the weight goes onto the back foot: the nose lifts. Push it forward and the weight goes forward. Left in the middle, the sailor sails with their own technique, exactly as before (proven bit for bit by a test). The push slider (Up/Down) works as before; the body adds to it.
- **Max's open choices (GD7) are settings**, each with the lead's recommendation as the default, switchable while sailing (Esc > Settings > Body).
- **Measured (section 5)**, with the body held by script in GP0's harness (gusts and waves): the back foot and the rail change the speed and the risk as GP0 found, "as far back as you dare, more rail when it gets wild":
  - 18 kt broad reach, once planing: the back foot **+7 %**, the rail **+15 %**, both **+24 %** (10.0 → 12.4 m/s), no falls;
  - 24 kt beam reach: the back foot **+7.6 %**, with 3° more rail **+10 %** and steady; the full back foot on the technique's rail catapulted (in both runs);
  - 24 kt broad reach: a flat board bounces (pitch rate 17 °/s against 8 to 10) and is 6 to 11 % slower; 5° of rail is the fastest and steady;
  - the risk: all 13 falls in the runs came at 24 kt with the board flat or at the technique's rail (13 in 46 case-stretches), none with 5° of rail or more (35); most came after the nose had bounced by 3 to 14° (the warning);
  - 18 kt beam reach: the back foot +3 to +5 %; there the technique's 2° is the best rail (flat and 8° both 5 to 6 % slower).
- **For Michiel (section 7), nothing built:** on a broad reach the feet hold only a fifth to a third of the rail asked, and in waves the sailor's own chatter reflex mutes the back foot (the trim moves a tenth to a third of what is asked).
- **For the lead:** the push harness's `--push` silently sailed without the slider from 1 to 5 November; fixed (section 4).
- **LAN:** each PC sends its whole board; the other PC shows the body's rail and trim exactly (section 6). `tools/lan_test.sh` passes, with and without the body.

## 2. What was built

| What | Where |
|---|---|
| The body itself: where the mouse has put it, the mapping to degrees, the clamps inside GP0's bands, the spring-back, the re-centring, level 2's slower feet, the technique's own rules for the base | `Game/windsurfer/mouse_body.gd` (`MouseBody`) |
| The controller adds the body's rail and trim to the slider's (and the sea's rail) every tick; in a manoeuvre it adds nothing; it re-centres at every tack, gybe, fall and restart | `Game/windsurfer/player_controller.gd` (`body`, `_move_the_body()`) |
| Level 2 written into the player's own copy of the sailor's config only (`lean_feel_time_s`), never a shared one | `Game/windsurfer/windsurfer.gd` (`use_body_level()`) |
| The mouse captured while the body is on and the player sails; free in every menu (Esc, the start menu, a network game's menu), while spectating, behind the autopilot, and in headless and screenshot runs; its movement read in screen pixels (the same hand movement on any window size); `--body=<side>,<back>` holds the body by script | `Game/main.gd` (`_input()`, `_update_mouse_capture()`, `_apply_body_settings()`) |
| The orbit camera turns while the look key is held: the right mouse button (as before) or C (new action `camera_look`) | `Game/project.godot`, `Game/camera/camera_rig.gd` |
| The settings, saved in the `[body]` section, clamped when read | `Game/ui/settings_values.gd` |
| A sixth settings tab, **Body**, with the switch, the choices and a short explanation | `Game/ui/settings_menu.gd`, `settings_menu.tscn` |
| One line in the F1 panel (for tuning only; the strip shows nothing new) | `Game/ui/hud.gd` |
| The play script | `tools/play_body.sh` |
| The push harness: a `body.` group (`body.side`, `body.back` and the body's settings, sweepable), the rail aimed for in the results, and `--point_from_ms` (plane across the wind first, then bear away) | `Game/dev/run_push.gd` |
| The LAN test: `--body=<side>,<back>` on both boards; the TRACK/SEEN lines carry the heel, the pitch and the feet's bank and trim aims, and the check compares them | `tools/lan_test.sh`, `Game/net/net_boards.gd`, `tools/lan/check_sync.py` |
| Unit tests (19) | `Game/tests/unit/test_mouse_body.gd` |

**How the mouse maps** (the body's place is `side` and `back`, each −1 to +1; the middle is 0):

- **The rail.** Toward more rail, the body adds up to the "Rail" setting (6°) to the leeward rail the feet already aim for, never past **8° in all** (GP0: beyond 8 is only slower). The other way, the whole travel takes the board to **flat** (0°), or, with "Windward rail" on, on to 4° of windward rail. "In all" counts the technique's own rail on this course (5° close-hauled falling to 2° on a beam reach, flat from 160°: `SailorConfig.fin_load_bank_*`), the slider's (+1° at the top) and the sea's.
- **The back foot.** ±1.5° of trim (the "Back foot" setting) on the trim the feet press for, kept inside **0.5 to 3.5° in all** (GP0's band). The technique's own trim is 2.0°, falling to 1.5° above 24 to 26 kn.
- **Where it acts:** the simulation aims for these targets only planing, in the footstraps and not in a turn, so the mouse does nothing below planing or in a manoeuvre, as the design wants. The rail is also scaled by how far the sailor hikes out (see section 7).
- **The mouse travel:** 300 px from one end to the other (150 px from the middle to an end), in screen pixels as Windows reports a captured mouse, so the window's size does not change it.

## 3. The settings and their defaults

Esc > Settings > **Body** (also in the start menu's settings). Changes apply as you leave the settings page (Back), also in the middle of a run; the body keeps its place.

| Setting | Default | The other choices | From |
|---|---|---|---|
| **Mouse body (experiment)** | Off | On (`tools/play_body.sh` turns it on) | the design: "a setting turns package B off" |
| Mouse left alone | **Stays where you put it** (and back to the middle at every tack, gybe and fall) | Springs back to the middle | GD7 (a), the lead's recommendation |
| Spring-back time | 1.5 s (95 % of the way back) | 0.5 to 4 s | the design: 1 to 2 s |
| Sideways | **The board rolls with the mouse** (as seen from behind the board: right puts the starboard rail down, so on starboard tack left is more rail, on port tack right is) | Right is always more rail | GD7 (b), the lead's recommendation |
| Rail | up to +6° (8° in all at most) | 2 to 8° | the design's +6; GP0's 8 |
| Windward rail | Off (the other way ends at a flat board) | On: on to 4° of windward rail | the design: "the other way flat"; GP0's follow-up tried −4 |
| Back foot | ±1.5° | 0.5 to 2° (±1° is the gentler one) | the design |
| Mouse travel | 300 px end to end | 100 to 800 px | the design: about 300 px |
| Level | **1: the feet hold the rail** (they correct a gust's heel within 0.4 s) | 2: you hold the rail (the feet correct in 2 s, so a gust heels the board past your angle) | GP2's two levels; GP0 measured level 2 at 2 s |

`tools/play_body.sh` takes every one as an option: `--level=2`, `--centre=spring --spring=1`, `--sideways=right`, `--windward=1`, `--rail=4`, `--trim=1`, `--travel=500`, `--wind=24`, `--heading=150`, `--push=100`, `--gusts=0.3`, and `--body=0` for the same water without the body.

## 4. How it was measured

GP0's harness, `tools/push_check.sh` (`Game/dev/run_push.gd`): the player's beginner controller with the auto-sheet, an AI's hands holding the true wind angle, on the game's open water with the waves, the wind's height gradient and gusts (0.2 every 8 s), from rest on starboard tack; 150 s per case and the means over the last 110 s (run 4: 340 s, the last 300 s). The new `body.` group holds the body where the case puts it, as a hand holding the mouse there all the time (here "right" is always more rail):

| `body.side` | the rail aimed for in all (beam and broad reach) | `body.back` | the trim aimed for |
|---|---|---|---|
| −1 | 0° (flat) | −1 | the technique's −1.5° (0.5° at the least) |
| 0 | the technique's (2°; the slider and the sea add theirs) | 0 | the technique's (2.0°, 1.5° at speed) |
| +0.5 | +3° | +0.67 | +1° |
| +1 | +6°, 8° in all at most | +1 | +1.5° (3.5° at the most) |

Each case is one stretch of water with the same gusts and waves, so the cases compare like for like; but a fall is a rare event in 110 s, so a single fall is a sign, not a rate. "Made good" is the speed along the course (m/s); "pitch rate" is the root mean square of the nose's up-and-down rate, the bounce. GP0's numbers came from the physics of Session 56; the physics has moved since (PH28's rail by point of sail, PH43's launch, the fin), so this run is today's map, not a repeat of GP0's.

```
C="--seconds=150 --from=40 --jobs=6"
tools/push_check.sh --winds=18,24 --twas=100,135 $C --run=gp2_b1_body --sweep=body.side=-1,0,0.5,1 --sweep2=body.back=-1,0,0.67,1
tools/push_check.sh --winds=18,24 --twas=100,135 $C --run=gp2_b2_push75 --push=0.75 --sweep=body.side=-1,0,1 --sweep2=body.back=-1,0,0.67,1
tools/push_check.sh --winds=24 --twas=100,135 $C --run=gp2_b3_level2 --body.level=2 --sweep=body.side=-1,0,0.5,1 --sweep2=body.back=0,0.67
tools/push_check.sh --winds=24 --twas=135 --seconds=340 --from=40 --jobs=6 --run=gp2_b4_long24 --sweep=body.side=-1,0,0.5 --sweep2=body.back=0,0.67,1
tools/push_check.sh --winds=18 --twas=135 --seconds=180 --from=70 --point_from_ms=11 --jobs=6 --run=gp2_b5_broad18 --sweep=body.side=-1,0,1 --sweep2=body.back=-1,0,0.67,1
```

The CSVs are in `.sim_output/push/gp2_b*/` (not in git; each run takes 3 to 10 minutes and makes them again).

**A harness bug found on the way:** since the skipper's speed package (601b8c4, 1 November 2026) the harness's `--push` and `--sweep=push.level` did nothing: hands with no level let go of the slider (`PlayerController._release_the_slider()`), and the harness's hands never had one, so every such case sailed without a slider (its CSV says `push_level` −1). Fixed in 1496ec9 (the hands hold the case's level). Run 2 above is the rerun after the fix. **Any slider measurement made with the harness between 1 and 5 November should be looked at again.**

## 5. What it measured

### 5.1 The 18 kt beam reach (TWA 100): the back foot pays, the technique's rail is the best rail

Made good (m/s), without the slider (run 1) and with the slider at 75 %, the game's start (run 2); no falls in any case.

| Rail \ back foot | −1 (forward) | 0 | +0.67 | +1 (back) |
|---|---|---|---|---|
| Flat | 12.14 / 11.98 | 12.28 / 12.10 | 12.28 / 12.06 | 12.32 / 12.11 |
| **The technique (2°)** | 12.49 / 12.32 | **13.03 / 12.66** | 13.31 / 13.06 | **13.39 / 13.34** |
| +3° (5°) | 12.51 | 12.54 | 12.45 | 12.97 |
| +6° (8°) | 12.42 / 12.24 | 12.31 / 12.22 | 12.43 / 12.24 | 12.57 / 12.41 |

The back foot fully back is worth **+2.7 %** (no slider) and **+5.4 %** (the slider at 75 %); forward costs 4 %. Flat costs 6 % and 8° of rail 5 %: today the technique's 2° is the best rail across the wind at 18 kt (GP0, in older physics, had the flattest board fastest).

### 5.2 The 24 kt beam reach (TWA 100): the back foot pays most, and too much on too little rail falls

| Rail \ back foot | −1 | 0 | +0.67 | +1 |
|---|---|---|---|---|
| Flat | 13.77 / 13.60 | 13.81 / 13.62 | 14.31 / 13.91 | 14.37 / 14.15 |
| **The technique (2°)** | 14.02 / 13.91 | **14.06 / 14.00** | **15.13 / 15.05** | 14.23, 1 catapult, pitch SD 2.5° / 13.77, 1 catapult, pitch SD 3.9° |
| +3° (5°) | 14.22 | 14.16 | 15.45 | **15.49** |
| +6° (8°) | 14.10 / 14.01 | 13.95 / 13.86 | 14.83 / 14.80 | 15.05 / 14.98 |

(Run 1 / run 2.) The back foot is worth **+7.6 %** with the technique's rail (both runs), and with 3° more rail the full back foot is **+10 %** (15.49) and steady (pitch SD 0.9°), where the same back foot on the technique's rail catapulted in both runs after its pitch SD rose to 2.5 to 3.9°. That is GP0's "rail buys stability" again: more back foot needs more rail.

### 5.3 The 24 kt broad reach (TWA 135): a flat board bounces and falls, rail rides

Over 300 s (run 4, no slider):

| Rail \ back foot | 0 | +0.67 | +1 |
|---|---|---|---|
| Flat | 13.25, 1 catapult (pitch rate 17.5 °/s) | 13.95 (16.8 °/s) | 13.82 (16.4 °/s) |
| The technique (2°) | 14.85 (10.2 °/s) | 12.31, **4 falls** (2 catapults, 2 fell off) | 14.85 (10.5 °/s) |
| +3° (5°) | **15.19** (8.6 °/s) | **15.23** (8.1 °/s) | **15.23** (8.4 °/s) |

In 110 s (runs 1 and 2) the same picture: flat 13.2 to 13.5 m/s with a pitch SD of 2.4 to 2.6° against 1.5 to 1.7 (and with the slider, flat with the full back foot fell 3 times: 10.63 m/s); 5 to 8° of rail 14.7 to 14.8 m/s and steady. **Rail is what keeps a 24 kt broad reach on the water.** The back foot itself is worth little here (section 7, point 2).

**All falls in every run** (13, all at 24 kt): every one with the board flat or at the technique's rail and, but for two, with the back foot pulled. In the 46 case-stretches at 24 kt with the rail at the technique's or flatter there were 13 falls; in the 35 with 5° of rail or more, none. Before 11 of the 13 the nose swung by 3 to 14° within the last 2 s (the falls CSVs keep the pitch 2, 1 and 0.5 s before each): the bounce is the warning the player can see and hear. The two catapults on the 24 kt beam reach came without it (the pitch steady within 2°).

### 5.4 The 18 kt broad reach (TWA 135): the biggest prize, once planing

From rest the harness's board points at 135° from 5 m/s and then sits on the hump at 9 m/s (GP11), whatever the body does (run 1: 8.8 to 9.5 m/s). Planing across the wind first and bearing away from 11 m/s (run 5, `--point_from_ms=11`, no slider, the last 110 of 180 s):

| Rail \ back foot | −1 | 0 | +0.67 | +1 |
|---|---|---|---|---|
| Flat | 9.89 | 10.08 | 10.16 | 10.57 |
| The technique (2°) | 9.98 | **10.01** | 10.36 | 10.73 |
| +6° (8°) | 10.44 | 11.56 | 11.61 | **12.41** |

No falls. The back foot alone is worth **+7 %**, the rail alone **+15 %**, both **+24 %** (10.01 → 12.41 m/s): the wet length falls from 1.48 to 0.99 m and the board stops bouncing (pitch rate 6.6 → 3.6 °/s). This is GP0's broad-reach prize, bigger: here the board is at the edge of planing, where rail lets it go (GP0's follow-up found the same in light wind).

### 5.5 Level 2 (the feet correct in 2 s), 24 kt (run 3)

Much as level 1 on the beam reach (13.8 to 14.7). On the broad reach the flat board with the back foot at +0.67 fell once with a pitch SD of 6.6° (level 1: 2.5°); with 3° more rail 14.9 to 15.1 and steady. As GP0 found: level 2 makes the 24 kt broad reach need the rail.

### 5.6 What the feet actually did with what the mouse asked

| Case | Rail asked: flat / technique / 8° → the board's mean heel | Trim asked: −1.5 / 0 / +1.5 → the board's mean trim |
|---|---|---|
| 18 kt beam reach | 0.4 / 1.9 / **7.1°** | 1.05 / 1.51 / 1.83° |
| 24 kt beam reach | 0.4 / 1.7 / 6.5° | 0.91 / 1.06 / 1.53° |
| 24 kt broad reach | 0.4 / 1.0 / **2.8°** | 0.77 / 0.94 / **0.99°** |
| 18 kt broad reach, planing | 0.1 / 0.5 / **1.6°** | 2.12 / 2.33 / 2.45° |

Across the wind the feet hold nearly what is asked. On a broad reach they hold a fifth to a third of the rail, and in waves the trim moves by a tenth to a third of what the back foot asks, at 24 kt on the broad reach hardly at all. The speed still changes (the wet length, the bounce), but the player's hand is muted there. Section 7 has the two reasons for Michiel.

## 6. LAN multiplayer

Nothing new has to travel: the body only sets two of the player's controls, which the simulation copies into its own fields, and every field of the simulation and its telemetry already travels (`BoardSnapshot` reads the layout from the scripts). So the other PC's puppet shows the heel and the pitch the body caused. To check it, the LAN test can now hold the body on both players' boards, and its TRACK and SEEN lines carry the heel, the pitch and the bank and trim the feet aim for:

| `tools/lan_test.sh` | Moments compared (guest shows host / host shows guest) | Worst difference: place, heel, pitch, bank, trim aim | The largest trim aim sent | Sync check |
|---|---|---|---|---|
| no body (as before) | 382 / 221 | 0.0000 m, 0.0000°, 0.0001°, 0.0001°, 0.0000° | 2.00° | PASS |
| `--body=1,1` (both boards, the back foot fully back) | 360 / 220 | 0.0000 m, 0.0000°, 0.0001°, 0.0000°, 0.0000° | **3.50°** | PASS |
| `--robot=allrounder --seconds=60 --body=-1,0.67` (a race sailed by robots, with the body) | 577 / 313 | 0.0000 m, 0.0000°, 0.0001°, 0.0001°, 0.0000° | **3.00°** | PASS |

So the other PC shows the board exactly as its own PC sails it, the body's rail and trim included. (The host's judge, which moves the guest's newest state on by its speed for the state's age, was 0.59 m off once in 79 moments in the second run against 0.02 m in the first; the shown boards themselves matched to the last decimal. A sharp change of speed is where that estimate errs; worth a look if a race's judge ever matters at that scale.) Both PCs need the same build, as always; the body adds no field to the state, so the layout's hash is unchanged.

## 7. For Michiel (requests, nothing built)

Nothing in `Game/sim/` was changed. Three findings and a small wish, with the numbers of section 5:

1. **On a broad reach the feet hold a fifth to a third of the rail the mouse asks** (section 5.6: 8° asked, 1.6° of heel on the planing 18 kt broad reach and 2.8° at 24 kt, where the 18 kt beam reach gets 7.1°). In `WindsurferSim._fin_load_bank_rad()` the aimed bank is scaled by the hike (`|lean|`, 0.55 to 0.8 on these reaches against 0.96 across the wind), by the stance and by "not turning" (`1 − |asked|`, where the beginner's heading hold uses the rail to steer), and then the feet's reach and the fin's roll decide the rest. Whether a sailor in the straps can rail a board on a broad reach without hanging out (with the ankles) is Michiel's call; if so, the rider's own extra (`rail_bank_extra_deg`) could skip the hike's share, behind a number whose 0 keeps today's answers bit for bit.
2. **In waves the sailor's chatter reflex overrides the back foot.** `_trim_by_feel()` eases the weight forward whenever the felt bounce (the pitch rate's RMS) is above `bounce_tolerance_dps`, 1.7 °/s. On the game's sea the pitch rate is 3 to 18 °/s all the time (section 5), so the rider is always "chattering", and the back foot's +1.5° moved the mean trim by +0.12 to +0.47°, at 24 kt on the broad reach by +0.05°. The back foot still pays (the press and the wet length change), but much less than the player asks. A tolerance measured against the sea's own pitching, or a rider who trusts the player's back foot while the body is on, would be Michiel's choice.
3. **The 18 kt broad reach sits on the hump from rest** (GP11, PH16): the play script now starts on a beam reach; nothing new.
4. *(A wish, small.)* `MouseBody.technique_rail_deg()` and `technique_trim_deg()` copy the simulation's `_rail_bank_deg_by_point_of_sail()` and `_running_trim_target_deg()`, because the body clamps the totals; `test_the_technique_rules_are_the_simulations_own` fails if the two drift apart. If Michiel prefers one source, the simulation could report both targets in the telemetry (a physics change, so not done).

PH3's other half ("the rail and the back foot as real controls", override fields in `SimControls`) is **not needed** for this experiment: the extras do the job.

## 8. The play-test checklist for Max

Start with `tools/play_body.sh` (or double-click `tools/play.sh` and switch the body on in Esc > Settings > Body). The mouse disappears while you sail; Esc frees it. F1 shows the body's line ("rail +3.0 deg (aim 5.0) ... back foot +1.0 deg (trim aim 3.0)") if you want to see what you asked; try first without it. Answer in a numbered list, as usual.

1. **Could you just go?** Leave the mouse alone: it should sail exactly as before (A/D to steer, Up/Down the slider).
2. **The back foot on the 18 kt beam reach.** Once planing, pull the mouse slowly back toward you. Feel for the nose lifting, the spray moving back, the sound rising; then the board starting to bounce: that is the warning. Push it forward: the nose goes down and the board slows. Did the back foot pay (measured: a small prize here, 3 to 5 %)? Did you see or hear the bounce before it went wrong?
3. **The rail on the same reach.** Move the mouse sideways both ways. More rail heels the board to leeward and loads the fin; flat (the other way) is slower here in today's physics (section 5). Could you find the best rail and hold it?
4. **24 kt** (`tools/play_body.sh --wind=24`). On the beam reach pull the back foot fully back with the board flat or at the technique's rail: it bounces and can catapult. Add rail and try the same back foot: it should be steadier and the fastest of all. That is the skill GP0 found: "as flat and as far back as you dare, more rail when it gets wild". Did it feel like that?
5. **Max's two choices (GD7).** Esc > Settings > Body, while sailing: "Mouse left alone" (stays / springs back) and "Sideways" (the board rolls with the mouse / right is always more rail). Which one feels like your body? With "rolls with the mouse", after a tack the same side means the other rail; the body goes back to the middle at the tack, so you start again from the technique. Is that natural or confusing?
6. **Level 2** (`--level=2`, at 24 kt): the feet no longer fix the heel for you; a gust heels the board past your angle and your hand must hold it. Too hard, or the right next step?
7. **The ranges and the speed of the mouse:** "Back foot" ±1.5 against ±1 (gentler); "Mouse travel" 300 px (try 200 and 500); "Rail" 6 against 4.
8. **The broad reach, the biggest prize:** get planing on the beam reach, then bear away (A, away from the wind) to about 135°. Measured there: the back foot fully back and the most rail together +24 % (section 5.4), although the feet hold only a fifth of the rail you ask (section 7). Can you feel the board come free?
9. **The basics:** Esc always gives you the mouse back; key 2 and the right mouse button (or C) turn the orbit camera; it works in your big window and after Alt+Tab.
10. **With a friend on the LAN:** both switch the body on; does the other board heel and lift its nose the way the friend says they do?

## 9. Checks

- `tools/test.sh` (the unit tests, after the last code change): **756 of 756 passed** (79 scripts, 83 602 asserts, 328 s; the same 756 before the harness's slider fix). The new `test_mouse_body.gd`: 19 tests (the body's movement and ends, the mapping both ways and both tacks, the clamps inside GP0's bands, stays and springs back, scripted, level 2, the technique's rules against the simulation's own, the controller adding to the slider, bit for bit with the body in the middle, the re-centring, the settings saved, read and clamped, level 2 only on a board's own config, the sailing scene switching it on and off, the Body tab).
- `tools/check.sh`: **424 files, 0 failed**.
- `tools/lan_test.sh`: PASS without and with the body (section 6).
- Screenshots, looked at: the Body tab at 1280 × 720 and at 3137 × 1263 (the menu centred, the rows readable, nothing cut), and the sailing scene with the body held (`--body`), the F1 line showing the mapping (left on starboard tack is more rail: "rail +6.0 deg (aim 8.0)"). The mouse capture itself (hidden cursor, Esc frees it, Alt+Tab, the look key) **could not be checked from here**: screenshot and headless runs never capture the mouse, on purpose, so Max's PC is not grabbed. That and the feel are Max's to check (section 8).

## 10. What is left open

- **The feel**: everything in section 8. Nothing here says the mouse feels like a body; that is the play-test.
- **The mouse capture by hand**: Esc, the pause menu, Alt+Tab, a race's end, the start menu, the big window (could not be checked headless).
- **Max's choices (GD7)**: answered by playing; the defaults are the lead's guesses.
- **Step 3 of the design** (the sea's automatic rail switched off above a slider level, so the player must rail in waves) and **step 4** (absorb, GP7) are not built.
- **The gamepad's right stick** (GP5) is not mapped to the body yet; the body takes any `move(Vector2)`, so it is a small step.
- **The Controls and How-to pages and the README** (UI2) do not mention the body yet; the Body tab has its own note.
- **CLAUDE.md's commands table** could list `tools/play_body.sh` beside `tools/play_push.sh` (left to the lead, to avoid a clash).
- **For Michiel**: section 7 (the broad reach's rail, the chatter reflex in waves).
- **For the lead**: the harness's `--push` sailed without the slider from 1 to 5 November (section 4).
