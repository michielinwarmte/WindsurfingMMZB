# GP2: the push on the mouse, and how the push and the body work together

**Branch:** `gp2/push-mouse`, from `play/6nov-evening` at f72f565. 6 November 2026, one Opus builder, no agents. **No physics change:** nothing in `Game/sim/` was touched.

**Max's ask:** "Push in combination with mouse control."

**The assumption (Max could not be asked; please correct it if it is wrong):** with the body on the mouse (Settings > Body, "Mouse body"), the push should be on the mouse as well, so one hand does everything; and the push and the body must work together, without one silently cancelling the other. If you meant something else (for example the push *instead of* the body on the mouse, or the push on the mouse's forward and back movement), say so and it is a small change.

## 1. In short

- **Nothing was broken.** W and S still move the push with the body on and the mouse captured (a new test presses W and S with the body on: 40 % a second, exactly as without it). The PUSH and BODY gauges sit side by side without overlap at 1280 × 720 and at your 3137 × 1263 (section 6).
- **New: the push is on the mouse too**, whenever the body is (a new Body setting, "Push on the mouse", on by default):
  - **the wheel:** one notch up is 10 % more push, one notch down 10 % less (from the 75 % start, one notch up is the ladder's 85 %, two notches 95 %);
  - **the left button held:** a **burst** to 100 % push, like a pump; let go and the push comes back to the level the wheel and the keys had. The gauge says **BURST** and shows a small marker where it will come back to;
  - **W and S keep working**, also during a burst (they move the level the burst comes back to).
- **The push and the body add up; neither cancels the other in a way you would not expect** (section 3, measured): the push sets how hard the sail is sheeted and how much pull you hold; the mouse sets how your feet press. The toes add rail on top of the push's rail, the heels take it away (that is what you ask for with the heels). Pulling the mouse back or pushing it forward takes over the trim, including the push's own small trim (+0.5° at 100 %): your back foot then decides the trim, which is the point of the back foot. So I changed nothing in how they combine.
- **Best measured combination at 18 kt:** on a beam reach, push 100 % and the mouse pulled all the way back is the fastest of all (14.3 m/s, against 13.2 with the mouse in the middle), with no falls. On a broad reach the same is a crash (5 falls in 110 s); half way back is the fastest there (11.4 against 9.9 m/s). That is the skill the push and the body are meant to give.

## 2. What was broken, and the fix

Checked first, with the body on (a settings file with `[body] mouse_body=true` and a body held by script, `--body=0.6,0.5`):

| Check | Result |
|---|---|
| Do W and S move the push while the body has the mouse? | **Yes.** The keys are read from the keyboard, which the mouse capture does not touch. A unit test now holds W for a second with the body on: the push goes from 50 % to 90 %, the same 40 % a second as without the body (`test_w_and_s_still_move_the_push_with_the_body_on_the_mouse`). Not checked by hand on a captured mouse: a screenshot run never captures the mouse. |
| Do the PUSH and BODY gauges overlap? | **No**, at 1280 × 720 and at 3137 × 1263 (section 6), at 0 %, 50 % and 100 % push. |

Two small things fixed on the way:
- `tools/play_body.sh`'s header still said "Up/Down still move the push slider" (from before this afternoon's swap to W/S). It now says W/S, and the wheel and the button.
- The key strip along the bottom said nothing about the mouse. With the body on it now shows **W S Wheel** push, **Hold left** burst and **Mouse** body (section 6).

## 3. How the push and the body combine (traced in the code, then measured)

### 3.1 What each one sets

**The push** (the ladder in `Game/config/push_curve_default.tres`, through `PushDial.apply_level()`) sets, at each level:

| Push | Sail's drive | Pull held (hike) | Rig lean extra | Rail extra | Rail for the sea (up to) | Trim extra | "Back foot" (sideways against the fin) |
|---|---|---|---|---|---|---|---|
| 50 % | 0.85 | 0.8 | 0° | 0° | 3° | 0° | 0 |
| 75 % | 1.0 | 1.0 | 0° | 0° | 3° | 0° | 0 |
| 85 % | 1.0 | 1.3 | 3° | 0° | 3° | 0° | 0 |
| 95 % | 1.0 | 1.5 | 7° | 1° | 1° | 0.3° | 0 |
| 100 % | 1.0 | 1.6 | 10° | 1° | 0° | 0.5° | 0 |

**The body** (the mouse) sets only how the feet press, planing in the straps and not in a turn: the toes against the heels (up to 10° more leeward rail, or back to flat), and the weight between the back strap and the front strap.

### 3.2 Where they meet, and which one wins

| What | The push | The body | Together |
|---|---|---|---|
| The sail's drive, the pull held, the rig's lean | sets them | does not touch them | **Only the push.** The body never changes how hard the sail is sheeted. |
| The rail (the leeward rail down) | its rail extra and the rail for the sea are added to the sailor's own rail | the toes add up to 10° more; the heels take the board back toward flat | **They add.** With the heels all the way, the board ends flat, whatever rail the push asked: that is what the heels are for. |
| The trim (the nose up or down) | its trim extra is added to the trim the sailor's own technique searches for | the back foot or the front foot moves the weight toward that strap, and the technique's search **stands aside as far as you press** (`_technique_share()` in the simulation) | **The body wins, as far as you press.** Mouse in the middle: the push's trim counts fully. Half way: half. All the way: the weight sits on the strap and the push's trim no longer counts. The push's trim is small (at most +0.5°); the back foot all the way adds about 2.5° at 50 % push. |
| The easing off on a bounce (the technique's "chatter" reflex) | (none) | stands aside as far as you press, like the trim | With the mouse pulled back you hold the tail down through a bounce. With the push at 100 % on a broad reach that is a crash (below). The gauge's words already say "crash likely" there. |
| "Back foot" in the push's ladder | the back foot pushing *sideways* against the fin (to steer), 0 at every level of today's ladder | the back foot's *weight* (fore and aft) | Two different things with the same name in the F1 panel; they do not interfere. |
| Below planing (push 0 to 25 %, or the hump) | (sets the sail) | does nothing (the feet press only planing in the straps) | The BODY gauge says "plane in the straps" then, so it is not silent. |

### 3.3 Measured: 18 kt, the game's open water (waves, gusts 0.2), 110 s per case

The push harness (`tools/push_check.sh`, the player's beginner controller with the auto-sheet, the body held where the case puts it). Each cell: the speed made good, the falls, the mean heel to leeward and the mean trim. Two runs: `--sweep=push.level=0.5,0.75,1 --sweep2=body.side=-1,0,1` and `--sweep2=body.back=-1,0.5,1`, `--winds=18 --twas=100,135 --point_from_ms=11` (the results in `.sim_output/push/push_body_side/` and `push_body_back/`, not in git).

**Beam reach (TWA 100°):**

| Mouse | Push 50 % | Push 75 % | Push 100 % |
|---|---|---|---|
| In the middle | 10.66 m/s, heel 1.7°, trim 2.2° | 12.79 m/s, heel 2.1°, trim 1.6° | 13.17 m/s, heel 2.9°, trim 0.7° |
| Toes all the way | 11.61 m/s, heel 11.7° | 11.37 m/s, heel 11.8° | 10.17 m/s, heel 9.0°, **1 catapult** |
| Heels all the way | 10.61 m/s, heel 0.4° | 12.14 m/s, heel 0.6° | 13.16 m/s, heel 1.2° |
| Back foot half way | 10.70 m/s, trim 2.9° | 12.88 m/s, trim 1.7° | 13.63 m/s, trim 1.0° |
| Back foot all the way | 10.48 m/s, trim 4.8° | 13.57 m/s, trim 2.2° | **14.30 m/s**, trim 1.5° |
| Front foot all the way | 10.54 m/s, trim 1.8° | 12.38 m/s, trim 0.8° | 13.16 m/s, trim 0.4° |

**Broad reach (TWA 135°):**

| Mouse | Push 50 % | Push 75 % | Push 100 % |
|---|---|---|---|
| In the middle | 8.96 m/s, heel 1.2°, trim 2.5° | 9.64 m/s, heel 0.7°, trim 2.4° | 9.92 m/s, heel 1.0°, trim 2.3° |
| Toes all the way | 8.93 m/s, heel 4.9° | 9.84 m/s, heel 3.4° | 10.05 m/s, heel 4.1° |
| Heels all the way | 8.47 m/s, heel 0.1° | 9.65 m/s, heel 0.1° | 9.73 m/s, heel 0.0° |
| Back foot half way | 8.70 m/s, trim 3.1° | 10.61 m/s, trim 2.6° | **11.40 m/s**, trim 2.4° |
| Back foot all the way | 7.94 m/s, trim 6.1° | 9.42 m/s, trim 3.1°, **2 catapults** | 7.28 m/s, trim 3.1°, **5 falls** (3 catapults, 2 off the board) |
| Front foot all the way | 8.67 m/s, trim 2.1° | 9.50 m/s, trim 2.1° | 9.68 m/s, trim 2.0° |

In words, the sentences you asked for:
- **At push 100 % with the mouse pulled all the way back:** the sail is sheeted for the most drive and you hold 1.6 times the pull, the rig leans 10° further; all your weight is on the back strap, so the push's own +0.5° of trim no longer counts (your back foot decides), and the technique's easing off on a bounce is off. On a beam reach that is the fastest of everything measured (14.3 m/s, +9 % on the middle); on a broad reach it is a crash, 5 falls in 110 s.
- **At push 100 % with the mouse pulled half way back:** half your weight to the back strap, the technique still trims with the other half. The best on a broad reach (11.4 m/s, +15 % on the middle), no falls.
- **At push 100 % with the toes all the way:** the push's 1° of rail and your 10° add; the board heels 9° (a little less than at 75 %, because at 100 % the feet also hold more of the sail's pull). On a beam reach at 18 kt that much rail is slower (10.2 against 13.2 m/s) and catapulted once: in this simulation a flat board is fastest when fully planing (ROADMAP PH27).
- **At push 100 % with the heels all the way:** the push's rail is taken away, the board is flat (1.2°), as fast as the middle.
- **At push 50 % with anything:** the mouse still works (the board planes at 18 kt) but changes little; the push is the bigger lever there.

**So it is right as it is**, and I did not change how they combine. Each one still changes the result at every level where the board planes; where one takes over from the other (the heels over the push's rail, the back foot over the push's trim) that is what you ask for when you move the mouse.

## 4. The new controls and settings

| Control | What it does | When |
|---|---|---|
| **Wheel** up / down | the push 10 % more / less a notch (the setting "Wheel step") | the body on the mouse, sailing (the mouse captured) |
| **Left button** held | a burst: the push goes to 100 % in a quarter of a second, and back to your level in about the same when you let go | the same, with "Push on the mouse" on "Wheel and left button" |
| **W / S** | the push more / less, 40 % a second, as before | always |
| Right button or **C** held + wheel | zooms the orbit camera (as before; without the look key the wheel is now the push's) | the body on the mouse |

The wheel and the button are read only while the mouse is the body's: while sailing, not in a menu (Esc), not while spectating, not behind the autopilot, never for the AI. A burst is let go by itself when the mouse is freed (Esc while holding the button does not leave the push at 100 %).

**Why the burst ramps instead of jumping:** at 100 % the ladder leans the rig 10° further. Done in one tick, that would throw the rig over in a sixtieth of a second. The level the sailor is at (`PlayerController.push_now`) follows the level you chose at a full range a second: from 75 % to 100 % in a quarter of a second, a notch of the wheel in a tenth. W and S are slower than that, so with the keys alone nothing changes.

**Settings > Body** (two new rows, both off with the mouse body):
- **Push on the mouse:** Off (W and S only) / Wheel / **Wheel and left button** (the default). Saved as `[body] push_on_mouse=0/1/2`. A settings file without it (like the evening play folder's `push_and_body.cfg`) gets the default, so the push is on the mouse as soon as the body is.
- **Wheel step:** 5 % to 25 % a notch, default 10 %. Saved as `[body] push_step`.

**The screens:** the key strip along the bottom (with the body on), the Controls page (two new rows) and the F1 panel (the body's line, and "burst: back to 75 % when let go" on the push's "now" line) list the new controls. The PUSH gauge says BURST in a burst, with a thin marker at the level it comes back to.

**For testing:** `tools/play_body.sh --push_mouse=off|wheel|button --push_step=0.05`; the game's `--burst=1` (with `--body=<side>,<back>`) holds the burst by script, for screenshots.

**LAN:** nothing new travels. The push's effect is already in each board's state; the other PC sees the board, not the mouse. `tools/lan_test.sh` could not be run (section 7).

## 5. What Max should try

1. Start with the play folder's "push and body on the mouse" launcher (or `tools/play_body.sh`). Get planing on the beam reach.
2. Turn the wheel up two notches: the PUSH gauge goes 75 → 85 → 95 %. Down again. Does a notch feel like the right size? (Settings > Body > Wheel step.)
3. Hold the left button for a few seconds: the gauge says BURST at 100 %, a marker at 75 %. Let go: back to 75 %. Does the burst feel like a pump? Is a quarter of a second up and back right?
4. Hold the burst while pulling the mouse back on a beam reach (the fastest combination measured), then try it on a broad reach (the crash measured). Do you feel the difference coming?
5. Use W and S while the mouse is captured: they still move the push. Hold the burst and press S: when you let go, the push comes back to the lower level.
6. Press Esc while holding the left button: the push must not stay at 100 % after the menu.
7. Hold the right mouse button and turn the wheel: the orbit camera zooms (camera 2), the push does not move.
8. Settings > Body > Push on the mouse: try "Wheel" (the left button does nothing) and "Off" (the wheel zooms the camera again).
9. Look at the two gauges side by side on your wide window.

## 6. The screenshots (looked at)

- **In git:** [gp2_push_on_mouse_burst.png](gp2_push_on_mouse_burst.png), 1280 × 720: the body held by script (the heels, half the weight back), the push at 50 % with the burst held: the gauge says BURST 100 %, "most speed, crash likely", the marker at 50 %; the F1 panel says "burst to 100 % NOW", the push line shows 100 % and the line under it "burst: back to 50 % when let go"; the BODY gauge beside it; the key strip with "W S Wheel push", "Hold left burst", "Mouse body".
- **Not in git** (`.screenshots/push_mouse/`): the push at 0, 50 and 100 % at 1280 × 720 (`p0_1280.png`, `p50_1280.png`, `p100_1280.png`) and at 3137 × 1263 (`p0_wide.png`, `p50_wide.png`, `p100_wide.png`): the two gauges side by side, no overlap, the key strip fits at both sizes (at 1280 it uses the whole width). At 0 % the BODY gauge says "plane in the straps" (the sail let fly). The Controls page at 1280 × 720 (`controls_page_1280.png`): the two new rows fit, nothing cut. The Body tab (`body_tab_1280.png`): the new rows are below the fold of its scroll list (as "Mouse travel" and "Level" already were).
- Not checked: the mouse captured for real (a screenshot run never captures the mouse), and how the wheel and the burst feel.

## 7. Checks

- `tools/test.sh`: **883 of 883** passing (872 before this work, and 11 new in `Game/tests/unit/test_push_on_mouse.gd`).
- `tools/check.sh`: 460 files, 0 failed.
- `tools/lan_test.sh`: **not run to the end.** At 16:23 Max's play build (`wsim.exe` from the evening play folder) was hosting the LAN play-test on this PC, on the game's fixed port 47520, so the test's own host could not open the port, and the test's headless guest ("Guest", the body held by script) joined that live game for about 40 seconds and then left by itself. Nothing of the play-test was changed, but a board called Guest may have shown up for those 40 seconds. The test needs running again once the play-test is over (`tools/lan_test.sh --body=1,0.67`). Nothing that travels between the PCs changed (the push's effect was already in each board's state, and the layout's hash matched the play build's).
- The slow validation suite was not run: nothing in the physics changed.

## 8. Open questions

1. **Is the assumption right?** (top of this report).
2. **The wheel's direction:** up is more push. Some games use up for "zoom in"; if it feels backwards, it is one line.
3. **The burst:** 100 % and back, a quarter of a second each way. Should it instead be "+25 % for as long as you hold"? Or should a burst have a cost (for example, only a few seconds at a time, like a pump that tires the arms)?
4. **The name "back foot"** means two things in the F1 panel: the push's sideways push against the fin and the body's weight on the back strap. The push's line comes from `Game/sim/push_dial.gd` (Michiel's); renaming it to "fin push" would be a one-word physics-folder change for him to OK.
5. For Michiel: at push 100 % the toes reach less heel (9° against 11.8° at 75 %) because the feet hold more of the sail's pull; that is the simulation's own answer, noted, not changed.

## 9. Token use

About 0.3 M tokens (one Opus builder, no agents).
