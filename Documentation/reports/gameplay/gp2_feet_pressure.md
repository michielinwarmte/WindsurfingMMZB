# GP2: the feet's press, the mouse as pressure in the straps (package B, after Max's play-test)

**Branch:** `gp2/feet-pressure`, from `gp2/mouse-body` at 15577e3. 6 November 2026, one Opus builder, no agents. **This changes the physics** (`Game/sim/`, Michiel's), on this branch only: [PHYSICS_SPEC.md](../../PHYSICS_SPEC.md) section 7.5, "The feet's press", and its table of changes. With the mouse in the middle, or the setting off, the board sails exactly as before (section 6). The first build of the body on the mouse is [gp2_mouse_body.md](gp2_mouse_body.md); this report follows on from it.

## 1. In short

- **What Max said** after playing the first build: "mouse controls does not do a lot". Asked what to do: **"the feet need to stay in the straps (like real life) but the pressure and rotation is different"**.
- **Why it did little:** the first build only moved two targets of the sailor's technique (the rail and the trim it aims for), and the technique muted both. The rail was scaled by how far the sailor hikes out (to a fifth or a third on a broad reach). The trim was searched for at 3 cm a second, and the technique's "chatter reflex" pushed the weight forward whenever the board bounced more than 1.7°/s, which on the game's sea it always does (in the middle the weight sits on the front strap: section 5.3).
- **Now the mouse is how the feet press, the feet staying in the straps:**
  - **sideways, the toes against the heels:** the toes turn the board up to 10° further onto its leeward rail than the technique does, and the feet press as hard as they must to get it there, up to all the roll moment two feet can pass (120 N·m, unchanged). The heels bring it back to flat;
  - **forward and back, the front foot against the back foot:** pull the mouse back and the weight goes onto the back foot, all of it on the back strap at the end, and the front foot pulls up in its strap; push it forward and the weight goes onto the front strap.
  - It takes 0.4 s from the middle to an end (a deliberate weight shift), and works only planing in the straps and not in a turn. The technique's own search for the trim (and its chatter reflex) stands aside as far as you press.
- **Measured** (section 5, the body held by script in the push harness, gusts and waves):
  - **18 kt broad reach:** the toes **+11 %**, the back foot half way **+11 %**, both all the way **+25 %** (10.0 → 12.5 m/s) with no falls; the back foot all the way on a flat board falls 4 times in 110 s. That is GP0's skill again: "as far back as you dare, more rail when it gets wild".
  - **24 kt beam reach:** the back foot half way **+5 %** and the steadiest board of all; all the way back it porpoises and falls 4 times in 110 s. The toes heel the board **10.5°** of the 11.7° asked, 2 % slower and bouncier (an over-railed board). The heels flatten it, 1.5 % slower.
  - The heel follows the toes in about a second; the gauge shows the weight on the back foot go from the front strap to the back strap.
- **The gauge** (picture: [gp2_feet_pressure_gauge.png](gp2_feet_pressure_gauge.png), 1280 × 720, the toes all the way and two thirds of the weight back) shows what the feet do now, whoever asks: TOES or HEELS as a share of their roll moment with the board's heel, and the share of the weight on the BACK FOOT with the board's trim; "works" when the press reaches the board.
- **Checks:** unit tests, the project check, the validation suite (8 known reds, the same numbers), the LAN test with the body on open water and on the lake: section 8.

## 2. What was built

| What | Where |
|---|---|
| Two new controls of the simulation, each −1 to +1, 0 by default: `feet_roll_press` (the toes +, the heels −) and `feet_pitch_press` (the back foot +, the front foot −) | `Game/sim/sim_controls.gd` |
| The feet's press in the simulation, in a block of its own: where it acts and how fast it moves (`_move_the_feet_press`, `_planing_share`), the toes' bank and their pressure (`_pressed_bank_rad`, `_pressed_reach_rad`, used in `_fin_load_bank_rad`), the weight between the straps (`_feet_pressure_point_m`, used in `_set_posture`), the front foot's pull with the back foot (in `_front_foot_couple_nm`), the technique standing aside (`_technique_share`, in `_trim_by_feel`), the telemetry (`_fill_feet_telemetry`) | `Game/sim/windsurfer_sim.gd` (the feet and body code only; nothing in the hull or the water) |
| Four numbers: the press's pace (0.4 s), the toes' 10°, the planing gate (0.2 to 0.4 of the weight on the planing lift) | `Game/sim/config/sailor_config.gd`, `Game/config/sailor_default.tres` |
| The telemetry: `feet_roll_press`, `feet_pitch_press`, `toes_share`, `back_foot_share`, `feet_press_reach` | `Game/sim/telemetry.gd` |
| The body on the mouse writes the two presses (no more aims); the far side's heels ease off at a flat board | `Game/windsurfer/mouse_body.gd`, `Game/windsurfer/player_controller.gd` (`_move_the_body`) |
| The gauge: the toes or heels and the weight on the back foot, as the feet press now, with the heel and the trim | `Game/ui/body_gauge.gd` |
| The settings (GD7): "Rail" became **Toes and heels** (the share of a full press at the end of the mouse's travel), "Back foot" the share of the weight it moves onto a strap; the others as before | `Game/ui/settings_values.gd`, `settings_menu.gd`, `tools/play_body.sh` (`--toes=`, `--weight=`) |
| The push harness: the feet's columns, and `--trace` (the feet's numbers every few ticks) | `Game/dev/run_push.gd` |
| The LAN test carries the feet's press on its TRACK and SEEN lines and compares it | `Game/net/net_boards.gd`, `tools/lan/check_sync.py`, `tools/lan_test.sh` |
| Tests | `Game/tests/unit/test_feet_press.gd` (new: exactly as before in the middle, the pace, the back strap, the toes and heels, nothing below planing or in a turn), `test_mouse_body.gd`, `test_body_gauge.gd` |

## 3. The model, and why

The feet stay where they are, in the straps. What the mouse changes is how they press. Two movements, as Max described them:

### 3.1 The toes against the heels: rotation and pressure

- **Rotation.** A full press of the toes turns the board **10°** further onto its leeward rail than the technique's own bank on this course (2° across the wind, more toward the wind, flat on a run); the heels the same the other way, which the body on the mouse stops at a flat board (or at 4° of windward rail with "Windward rail" on). The 10° is **not scaled by the hike**, as the technique's own bank is: the rider presses on purpose with the feet in the straps, however far the body hangs out. That scaling was what muted the first build's rail to a fifth on a broad reach.
- **Pressure.** The feet's reflex holds the board at that bank exactly as it holds the technique's: the same stiffness (1500 N·m per radian) and damping, within the same 120 N·m the body's balance leaves. When the board stays short of the bank (the water and the fin holding it up), the feet aim further, as far as their reflex reaches, so they press harder, up to all their roll moment on the toes. (The heels have this already: the technique aims further to windward when the board heels past its bank.)
- **Why this way, and not a pure moment.** I first built the toes as a moment of their own on top of the reflex, with the reflex's hold standing aside ("model A", section 7). The board then rolled freely under the press, the heel depended on the waves, and on the 24 kt beam reach a full press heeled it only 5°, less than the first build's 9° (with its 6 November limits, 11° asked; the same harness run on 15577e3). Keeping the reflex as the hold and moving its bank makes the heel follow the mouse predictably (a closed loop, as the technique always had), keeps the roll damped in waves, and still uses all the feet's moment when the board resists. The feet's moment is not increased: 120 N·m is already what two feet across a board can pass (section 4).

### 3.2 The front foot against the back foot: the weight between the straps

- **The weight.** The feet's pressure point (where the weight goes into the board) moves from where the technique has it toward the back strap, all the way at a full press: all the weight on the back foot. The body's weight goes with it, as it does with the technique's own press (the posture hangs from the feet's pressure point). That is a pitch moment of the weight on the feet (about 850 N) times how far it moves (up to the 0.59 m between Max's straps). Pushing the mouse forward moves it to the front strap.
- **The front foot.** Pressing the back foot, the front foot also pulls up in its strap, at least as hard as you press (up to its held pull, 150 N over the straps' 0.59 m: 88.5 N·m). Pressing the back foot and lifting the front are one movement. Without the pull, the weight on the back strap only took the place of the body hanging back from the front foot's pull: the centre of mass did not move and neither did the trim (measured on flat water: the trim 1.18° → 1.20°, the hang-back 0.26 m → 0). Pressing the front foot, the technique's own pull stands aside; its pull on a sudden nose drop (after a crest, PH43) stays.
- **The technique's closed loop.** The technique's search for the trim (and its chatter reflex) keeps running, but its moves are scaled down by how far you press: all of it in the middle, none at a full press. Its own press stays where it was, so when you let the mouse come back to the middle the weight goes back to the technique's place at the same pace and the search goes on from there. Why: the technique's loop is slow (3 cm/s) and pushes the other way on every bounce, so letting it fight the mouse is exactly what made the first build mute; letting it pause is what a rider who decides where the weight goes does.

### 3.3 Where and how fast

- From the middle to an end in **0.4 s**, the pace of a deliberate weight shift (section 4).
- Only **planing in the straps**: from 0.4 of the weight carried by the planing lift fully, fading to nothing at 0.2. (A first version pressed from the hump's speed on: at 24 kt the toes and the front foot held the board in the hump at 3 m/s, nose up 12°, for 80 s. Pressing the tail of a board that is not planing rears its nose.)
- The toes and heels not while steering asks for a carve (that bank is the turn's). In a tack or a gybe the body presses nothing; in the air off a crest the weight stays where it is.

### 3.4 The settings (GD7), what they mean now

| Setting | Now | Default |
|---|---|---|
| Mouse body (experiment) | as before | off (`tools/play_body.sh` turns it on) |
| Mouse left alone | as before (stays, or springs back); back to the middle at every tack, gybe and fall | stays |
| Sideways | as before (the board rolls with the mouse, or right is always more rail) | rolls with the mouse |
| **Toes and heels** (was "Rail", degrees) | the share of a full press at the end of the mouse's travel (a full press: 10° more rail) | 100 % |
| Windward rail | off: the heels stop at a flat board; on: on to 4° of windward rail | off |
| **Back foot** (was degrees of trim) | the share of the weight the end of the travel moves onto a strap | 100 % |
| Mouse travel | as before | 300 px |
| Level | 2: the technique's own correction of the heel slows to 2 s (a gust heels the board further when you are not pressing) | 1 |

The settings file has new keys (`toes_share`, `weight_share`); the first build's `rail_deg` and `trim_deg` are left unread.

## 4. The sources and the estimates

| Number | Value | Reliability | Where it comes from |
|---|---|---|---|
| The feet's roll moment (unchanged) | 120 N·m | estimate (the spec's, section 7.5) | The pressure under a foot can move from the heel to the first metatarsophalangeal joints, the forward limit of the functional base of support ([PMC6931099](https://pmc.ncbi.nlm.nih.gov/articles/PMC6931099); the functional base of support is much smaller than the foot's outline: Millard and Sloot 2025, [Univ. Stuttgart](https://elib.uni-stuttgart.de/items/a27e2a81-bd05-463a-b591-27caaae24f62/full)); at rest it sits about 11.5 cm ahead of the heel line (the same search). On a 0.26 m foot across the board that is some 0.06 to 0.08 m either way: 50 to 70 N·m at the body's 834 N; the straps add the instep's pull (150 to 200 N held, the U1 sources: hip flexors and dinghy hiking straps) over about 0.1 m a foot. No measured windsurf footstrap moment was found (a search for instrumented boards found only forum talk). |
| The toes' rotation | 10° past the technique's bank | Max (an estimate) | Max, 30 October 2026: "upwind up to 10, I think", the most rail the technique asks; GP0 measured more than 8° only slower ([gp0_measure.md](gp0_measure.md)). |
| All the weight on one foot | the back or front strap | obvious | Anyone can stand on one leg; the straps' places are Max's board (0.235 and 0.825 m from the tail). |
| The front foot's pull with the back foot | 150 N held × 0.59 m = 88.5 N·m | estimate (the spec's, PH28) | The U1 sources (hip-flexor strength, dinghy hiking-strap forces); Max: "correct". |
| The press's pace | 0.4 s from the middle to an end | estimate | A person shifts the weight onto one foot in about 0.3 to 0.6 s before a step (the anticipatory postural adjustment of gait initiation; e.g. Caderby et al. 2017, [Frontiers in Human Neuroscience 11:127](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2017.00127/full), whose durations are in a figure I could not read); a rider in the straps moves less than a walker. |
| The planing gate | 0.2 to 0.4 of the weight on the planing lift | estimate, measured | A planing reach carries 0.55 to 0.75 on the lift; a board railed 10° dips to 0.46; the hump trap of section 3.3 sat below 0.2. |
| What the technique says | the toes roll the board to leeward, the heels keep it flat; a flat board is fast; too much back foot sinks the tail and slows | technique, anecdotal | seabreeze.com.au forum threads ([Footstraps steering](https://www.seabreeze.com.au/forums/Windsurfing/General/Footstraps-steering), [Board foot pressure](https://www.seabreeze.com.au/forums/Windsurfing/Gps/Board-foot-pressure)); Windsurf magazine, "Move on up: get on the front foot" ([Magzter](https://react.magzter.com/stories/Boating-Sailing/Windsurf/MOVE-ON-UP-GET-ON-THE-FRONT-FOOT)); the spec's U2 sources ("a flat board is a fast board"). |

## 5. What it measured

### 5.1 How

GP0's harness as the first build used it (`tools/push_check.sh`, `Game/dev/run_push.gd`): the player's beginner controller with the auto-sheet, an AI's hands holding the true wind angle, the game's open water with waves, the wind's height gradient and gusts (0.2 every 8 s), from rest on starboard tack, the body held by script (`body.side`: +1 the toes all the way, −1 the heels; `body.back`: +1 all the weight on the back foot, −1 on the front). The 24 kt beam reach (TWA 100) for 150 s, the means over the last 110 s; the 18 kt broad reach (TWA 135) planing across the wind first and bearing away from 11 m/s, for 180 s, the means over the last 110 s. No push slider. Each case is the same water and the same gusts, so the cases compare like for like; a fall is a rare event in 110 s.

```
tools/push_check.sh --winds=24 --twas=100 --seconds=150 --from=40 --jobs=5 --run=feetC_r24 --sweep=body.side=-1,0,1 --sweep2=body.back=0,0.5,1
tools/push_check.sh --winds=18 --twas=135 --seconds=180 --from=70 --point_from_ms=11 --jobs=6 --run=feetB_b18 --sweep=body.side=-1,0,1 --sweep2=body.back=0,0.5,1
tools/push_check.sh ... --run=feetC_r24_front / feetC_b18_front --sweep=body.side=0,1 --sweep2=body.back=-1      (the front foot)
```

The CSVs are in `.sim_output/push/<run>/` (not in git; a run takes 5 to 10 minutes).

### 5.2 The 24 kt beam reach (TWA 100)

Made good, m/s (and the change against the middle); falls in 110 s:

| Toes and heels \ back foot | 0 (the technique's) | half way | all the way |
|---|---|---|---|
| Heels all the way | 13.85 (−1.5 %) | 14.60 (+3.8 %) | 6.79, **7 falls** |
| **The technique's (middle)** | **14.06** | **14.78 (+5.1 %)** | 10.38, **4 falls** (3 catapults) |
| Toes all the way | 13.76 (−2.1 %) | 14.03 (−0.2 %) | 8.10, **5 falls** |

What the board did:

| Case | Heel to leeward: asked → mean (max) | Weight on the back foot | Trim, mean | Pitch SD | Wet length |
|---|---|---|---|---|---|
| Middle | 1.7° (the technique's) → 1.71° (5.4°) | 7 % | 1.06° | 1.13° | 1.45 m |
| Toes | 11.7° → **10.45°** (18.5°) | 0 % | 1.46° | 2.07° | 1.68 m |
| Heels | flat → **0.60°** | 4 % | 1.03° | 1.32° | 1.55 m |
| Back foot half way | – | **52 %** | **1.34°** | **0.93°** | 1.27 m |
| Back foot all the way | – | **86 %** | 1.25° (bouncing) | 5.61° | 1.12 m |

The back foot half way is the fastest and the steadiest board (pitch SD 0.93° against 1.13°); all the way back it porpoises (pitch SD 5.6°) and catapults. The toes heel the board 9/10 of what is asked: across the wind the fin rails it too, so the feet hardly need to press (their roll moment is 22 % on the toes on average); an over-railed board is slower and bouncier (pitch rate 13.9 °/s against 6.2). The heels bring it flat and the feet press hard on them (47 %).

### 5.3 The 18 kt broad reach (TWA 135), planing

| Toes and heels \ back foot | 0 (the technique's) | half way | all the way |
|---|---|---|---|
| Heels all the way | 10.02 (+0.1 %) | 11.44 (+14 %) | 7.48, **4 falls** |
| **The technique's (middle)** | **10.01** | **11.15 (+11 %)** | 8.57, **4 falls** |
| Toes all the way | **11.10 (+11 %)** | 11.44 (+14 %) | **12.47 (+25 %), no falls** |

| Case | Heel to leeward: asked → mean (max) | Weight on the back foot | Trim, mean | Pitch SD | Wet length |
|---|---|---|---|---|---|
| Middle | 1.1° → 0.52° (3.8°) | 2 % | 2.33° | 1.56° | 1.48 m |
| Toes | 11.1° → **2.62°** (20.8°) | 11 % | 2.10° | 1.35° | 1.25 m |
| Heels | flat → **−0.15°** | 1 % | 2.28° | 1.63° | 1.51 m |
| Back foot half way | – | **50 %** | 2.43° | 1.44° | 1.22 m |
| Back foot all the way | – | 86 % | 2.76° | 4.62° | 0.99 m |
| Toes and back foot all the way | 11.1° → **5.28°** | **100 %** | **3.60°** | **1.07°** | **0.92 m** |

On a broad reach the planing board is stiff in roll: the toes, pressing with 89 % of the feet's roll moment, get a quarter of the bank asked (2.6°), half of it with the back foot on (5.3°). The back foot all the way on a flat board bounces and falls; with the toes pressed it is the fastest and steadiest board of all (the wet length 0.92 m, the pitch SD 1.07°): **more back foot needs more rail**, as GP0 found.

Note the middle: the technique keeps all the weight on the front strap on this sea (2 % on the back foot), because its chatter reflex eases forward on every bounce (the first build's section 7, point 2). The back foot half way (50 %) is worth 11 % here.

### 5.4 The front foot

All the weight on the front strap (the mouse pushed all the way forward):

| Case | Made good | Trim, mean | Wet length | Falls |
|---|---|---|---|---|
| 24 kt beam, the front foot | 14.22 (+1.1 %) | 1.06° → **0.61°** | 1.45 → 1.60 m | 0 |
| 24 kt beam, the front foot and the toes | 12.67 (−9.9 %) | 1.35° (heel 9.2°) | 1.74 m | 0 |
| 18 kt broad, the front foot | 9.85 (−1.6 %) | 2.33° → **1.91°** | 1.48 → 1.65 m | 0 |
| 18 kt broad, the front foot and the toes | 10.25 (+2.4 %) | 1.88° (heel 2.9°) | 1.40 m | 0 |

The nose goes down by about 0.4°, the wet part grows, and the board is a little slower on the broad reach and as fast across the wind at 24 kt (where the technique's own weight is already forward). Railed and nose down at 24 kt is the slowest of all: a board that ploughs.

### 5.5 Against the first build

| | The first build (gp2_mouse_body.md, section 5) | Now |
|---|---|---|
| 24 kt beam, the rail | +6° asked (8° in all) → 6.5° of heel; −1 % | +10° asked (11.7°) → 10.5°; −2 % |
| 24 kt beam, the back foot | +1.5° of trim asked → +0.47°; +7.6 % at two thirds, a catapult at all the way | half the weight back → +0.28° of trim, +5 %; all the way: porpoising, 4 falls |
| 18 kt broad, the rail | 8° asked → 1.6°; +15 % | 11.1° asked → 2.6°; +11 % |
| 18 kt broad, the back foot | +1.5° asked → +0.12° of trim; +7 % | half the weight back → +0.10°, +11 %; all the way: 4 falls |
| 18 kt broad, both | +24 % (1.6° of heel) | +25 % (5.3° of heel, 3.6° of trim, wet 0.92 m) |
| What answers the mouse | targets the technique muted | the weight and the feet's moment themselves |

The prizes are about the same size; what changed is that the board now answers in the open: the weight on the back foot goes from the front strap (2 to 7 %) to the back strap within half a second, the heel follows the toes within a second and to 9/10 of the bank across the wind, the heels flatten, and too much back foot now porpoises and falls where the first build only lost a little.

## 6. Exactly as before in the middle

- `test_feet_press.gd`, `test_left_in_the_middle_the_board_sails_exactly_as_before`: the 18 kt beam reach (the slider at 75 %) and the 24 kt broad reach, in waves and gusts, sailed 25 s by the player's controller with a body in the middle; their position, speed, heel, pitch, trim press, lean, hang-back, the bank aimed for and the felt heel and trim, recorded on the code before this build (commit 29568e1 holds the test with those numbers, on the old physics), equal to the last printed digit after it.
- The push harness's middle cases are row for row the same as before the change (the 18 kt broad reach and the 24 kt beam reach, 120 s, run on the old code and on each version of the new).
- Every change in the simulation is behind `feet_roll_press != 0` or `feet_pitch_press != 0`, which stay 0 while the controls are 0 (the AI boards, the autopilot, a player without the body or with it in the middle).

## 7. What was tried and dropped

- **Model A, the toes as a moment of their own.** The toes pushed `press × 120 N·m` through the feet and the reflex's hold stood aside as far as they pressed, keeping only its damping. Measured: 24 kt beam, the toes heeled the board only 5.1° (of nothing asked: the heel depended on the waves) and the speed fell 2 %; 18 kt broad 2.7° and −3 %; the heels did nearly nothing, because across the wind the technique's reflex already presses the heels to hold the board against the body's balance. Dropped for 3.1's rotation and pressure.
- **The weight on the back strap without the front foot's pull** (section 3.2): +23 % on the 18 kt broad reach with no falls, but the trim did not move at all (the body came forward over the feet as far as the feet went back). Kept the pull: now the trim and the bounce answer, and all the way back is too far.
- **Pressing from the hump's speed** (section 3.3): the hump trap. Gated on planing.

## 8. Checks

- `tools/test.sh` (unit): **765 of 765 passed** (81 scripts, 83 684 asserts, 421 s), on the committed code (ac99e65). New: `test_feet_press.gd` (5 tests); rewritten for the press: `test_mouse_body.gd` (19), `test_body_gauge.gd` (4).
- `tools/check.sh`: **427 files, 0 failed**.
- `tools/test.sh validation`: **36 pass, 8 fail, 2 pending** (805 s), the eight known reds with **the same numbers** as before (PROGRESS_LOG.md, the merge of 5 November): the polar sweep's speeds (TWA 75 to 120 at 11.85 to 14.67 m/s, 135 at 7.65), its shape (45°: 5.45 after 5.79), the top speed 14.67 m/s and the planing onset 14.4 kn; the fin's side force 745 N; the push warning (0 catapults where 2 are wanted); the skipper's 12 kt limit at 12:21.2; the settled speed on waves at TWA 120, 12.09 against 14.67 m/s. Nothing new: the validation sails without the body, and with the presses at 0 the physics is the same.
- `tools/lan_test.sh --body=1,0.67` (both players' boards with the body held, the heels all the way on starboard tack and two thirds of the weight back):

| | Moments compared (guest shows host / host shows guest) | Worst difference: place, heel, pitch, bank aim, the feet's toes, back foot | Largest sent: toes, weight on the back foot | Sync |
|---|---|---|---|---|
| Open water | 369 / 208 | 0.0000 m, 0.0000°, 0.0000°, 0.0001°, 0.0000, 0.0000 | 1.00, 0.80 | PASS |
| Lake Silvaplana (`--map=lake`) | 385 / 228 | 0.0000 m, 0.0000°, 0.0001°, 0.0001°, 0.0000, 0.0000 | 1.00, 0.79 | PASS |

  The new fields of the simulation travel by themselves (`BoardSnapshot` reads the layout from the scripts); both PCs need the same build, as always (the layout's hash changes with this build).
- Screenshots, looked at (`.screenshots/gp2_feet/`, not in git): the sailing scene at 18 kt with the body held by script at 1280 × 720 (`gauge_1280.png`: the toes all the way and two thirds of the weight back: TOES 100 %, BACK FOOT 67 %, trim 3.2°, "works") and at Max's 3137 × 1263 (`gauge_3137.png`: the toes all the way and half the weight back, caught a moment after the over-railed board dropped off the plane: heel 14°, the feet pressing the heels (HEELS 54 %) to bring it up, the dot dimmed and the corner saying "plane in the straps"); the Body tab at both sizes (`body_tab_1280.png`, `body_tab_3137.png`: the rows fit, the hints are not cut). The gauge's pad, words and bars are readable at both sizes. The mouse capture and the feel could not be checked from here.

## 9. The play-test checklist for Max

Start with `tools/play_body.sh` (18 kt, gusts and waves, a beam reach, the slider at 75 %); `tools/play_body.sh --wind=24` for the strong wind. Watch the BODY gauge at the bottom: it shows how your feet press now (TOES or HEELS, BACK FOOT) and what the board does (heel, trim). Answer in a numbered list.

1. **Leave the mouse alone.** It should sail exactly as before. Note the gauge: in waves the sailor's own technique keeps the weight on the front foot (BACK FOOT near 0 %).
2. **The back foot, 18 kt.** Once planing, pull the mouse slowly back. BACK FOOT should climb to 100 % within half a second of your hand; the wet part shortens, the board speeds up. Half way is worth about 11 %. All the way on a flat board it starts to bounce and then falls: did you see or feel the bounce coming?
3. **The toes, 18 kt broad reach.** Bear away to about 135°, then move the mouse toward the toes (the tinted half of the pad). The board should roll onto its leeward rail within a second (a few degrees: a broad reach is stiff). Then add the back foot: toes and back foot together were the fastest and steadiest, +25 %. Does that feel like the "more rail when you push" you know?
4. **The heels.** The other way the heels bring the board flat. Across the wind it is a little slower; is that what a flat board does for you?
5. **24 kt beam reach.** The back foot half way is the best (+5 %, the steadiest board). All the way back it porpoises and catapults. The toes all the way rail it 10° and it gets bouncy and slower. Can you find the edge?
6. **The pace.** 0.4 s from the middle to an end. Too quick, too slow?
7. **The settings** (Esc > Settings > Body): "Toes and heels" and "Back foot" now set how much of a full press the end of the mouse's travel gives (try 50 % for a gentler mouse). Are 100 % and 100 % too much?
8. **Does the board now answer the mouse?** That was the point: say where it still does too little or too much.
9. **The basics**, as before: Esc frees the mouse; the right mouse button or C looks around; it works in your big window.
10. **With a friend on the LAN**, both with the body on: does the other board heel and lift as the friend presses?

## 10. Open points

- **The feel**: everything in section 9; nothing here says how it feels.
- **The 24 kt broad reach**, the 18 kt beam reach and the close reaches were not measured with the press (the brief asked for the two cases above). A screenshot run on the 18 kt beam reach with the toes all the way caught the board heeled 14° and off the plane for a moment (section 8): over-railing there can drop the board off the plane; how often was not measured.
- **The heels across the wind** have little to give: the technique already holds the board with its heels against the body's balance (the feet's moment 47 % on the heels when pressed, the heel 1.7° → 0.6°).
- **For Michiel**: the press uses the feet's existing 120 N·m and the front foot's 150 N; the new numbers (0.4 s, 10°, the 0.2 to 0.4 gate) are estimates. The roll reflex's reaction on the body is, as before, not moved into the lean (a point-mass sailor has no ankles); a sustained 120 N·m would shift an 85 kg sailor's weight by some 0.14 m over the feet.
- **The gamepad's right stick** (GP5) could press the same two controls.
- `CLAUDE.md`'s commands table could list `tools/play_body.sh` (left to the lead).
