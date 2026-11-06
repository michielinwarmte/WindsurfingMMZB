# E07 · The player's controls

Owner: Max and Tarpie for the design and the feel, the lead for the build; Michiel where a control is a new physics input | Roadmap: GP1 to GP12, GD1 to GD7, UI2 | Questions: Q21, Q22, Q23, Q24, Q25

**Goal.** Interactive, learnable and progressable control of the sailor: easy to just go, a little challenging to go fast, fun even on a long straight. A ladder of control from "the autopilot sails and you steer" to "every control is yours", each step a real sailor's skill on real physics, on keyboard and mouse and on a gamepad, taught by lessons.

**Done when (1.0).** The control ladder (Q21) is in the game with its levels named on the HUD; every level is fun on a long straight by the feel checklist (gust reading and easing, the rail and the trim, pumping, chop timing, the wind-shadow duel, speed runs); the gamepad sails every level; the five lessons exist; the gybe's timing and the chop's timing are measured windows; the push's risk is real in every wind (E01.S06).

**Where things stand (6 November 2026).** Two keyboard modes (beginner: A/D steer, W/S push and ease since 6 November, Space with A/D chooses tack or gybe; advanced: raw rake, tilt, weight, sheet), the push dial on the keys and the mouse (wheel and a burst), the body on the mouse as the feet's press (toes and heels, front and back foot), the interactive manoeuvres (the turn follows A/D, the body carves, the flip on a second Space), the recovery reflex, the time trial with splits against your best, gust patches you can read on the water, the fin's hum and the rig's creak, the chatter and the spray. A gamepad works in the menus only. No lessons (the How to sail page is eight static tips, partly stale), no levels or unlocks, no profile, no feedback on technique, no pumping, no chop absorb, no held gybe flip. The seven gameplay decisions GD1 to GD7 are built as settings but not decided; GP3 (tuning by play) was never done. Max on the mouse body, 6 November: "works nice".

## Stories

### E07.S01 · The controls of 6 November checked, and GD1 to GD7 decided
Status: review | Size: S | Owner: Max, Tarpie | Milestone: M1 | Needs: the night3 build | Roadmap: GP2, GP12, GD1 to GD7
Done when: Max has played the push on the mouse, the feet's press, Space with A/D and the interactive manoeuvres and answered the open questions of the four gameplay reports, and GD1 to GD7 have a decision each in the roadmap.
- [ ] T1 The push on the mouse: the wheel's direction, the burst's form, the reading of "push in combination with mouse control" (`gp2_push_on_mouse.md` section 8)
- [ ] T2 The feet's press: the feel, the 100 % back foot that stalls a broad reach (`gp2_feet_pressure.md` section 10)
- [ ] T3 The manoeuvres: a flip without a cue a little late so a good cue pays, the sheet keys as a cue, the gauge's "carving" (`gp_manoeuvres_6nov.md` section 7)
- [ ] T4 GD1 to GD7 decided (the dial's place is W/S now; spring-back; neutral's speed; the modes; the HUD; the mouse's centre and roll)

### E07.S02 · Tuning by play
Status: todo | Size: M | Owner: Max, Tarpie | Milestone: M2 | Needs: E07.S01 | Roadmap: GP3
Done when: the push curve's range and neutral per wind strength, the body's ranges and level, and the manoeuvre windows are tuned with the checklist ("could you just go? did pushing pay? did you see the fall coming? could you find and hold the best rail?") in 12, 18 and 24 kt on flat water and chop.
- [ ] T1 Three play-test rounds with the checklist; the numbers in the configs
- [ ] T2 The reflex's numbers swept (the night run's part B) and the chosen variant played

### E07.S03 · The control ladder
Status: todo | Size: M | Owner: the lead, Max for the names | Milestone: M2 | Needs: Q21, E07.S01 | Roadmap: GP6, GP5
Done when: the levels (a proposal: 1 Autopilot: steer only; 2 Push; 3 Push and body; 4 Manual) are presets of a list of assists (auto-sheet, the balance reflex, the recovery reflex, the automatic flip, the automatic rail), the HUD names the level, the settings show the list for whoever wants to mix, and the AI's hands are untouched.
- [ ] T1 The assists as one list in the settings with the presets
- [ ] T2 The level on the HUD and in the results (a time trial record per level)
- [ ] T3 Advanced mode folded into level 4 (or kept apart: Max)
- [ ] T4 Package B made permanent (GP6): the mouse through `SimControls` fields, not the config copy

### E07.S04 · Sailing on a gamepad
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E07.S03, Q23 | Roadmap: GP5, GD1, UI2
Done when: every level sails on a gamepad (the left stick steers, the triggers push and ease, the right stick is the body, the face buttons the manoeuvres and the cue), with dead zones and sensitivity in the settings, rumble at the fin's limit, and the menus already navigable.
- [ ] T1 The input map and the controller's reading of sticks and triggers
- [ ] T2 Dead zones, sensitivity, rumble
- [ ] T3 The Controls page for the gamepad; a Steam Deck check if one is at hand

### E07.S05 · The gybe in two presses
Status: todo | Size: M | Owner: the lead, Michiel for PH4 | Milestone: M2 | Needs: E01.S09 T2 | Roadmap: GP8, GP9, PH4
Done when: the gybe is a carve on the first press and a flip on the second, with a window that shrinks with the wind; too early stalls, too late backs and catapults; the tack stays one press; measured at 12, 18 and 24 kt.
- [ ] T1 The held flip (`SimControls.hold_side`) until the second press; the window from GP9's measurement
- [ ] T2 The foot change in the gybe (E08.S03)
- [ ] T3 The reward for a good cue (the hands-off flip a little late: Max's call)

### E07.S06 · Pumping
Status: todo | Size: S | Owner: the lead | Milestone: M3 | Needs: E01.S09 T1 | Roadmap: PH39
Done when: a pump key (or the body's rhythm on the mouse) gets the board onto the plane from a deep course and out of a lull, costs effort, and the AI pumps too.
- [ ] T1 The key and the rhythm; the effort meter (no HUD number: the sailor's breathing in the sound?)
- [ ] T2 The time trial's start from rest uses it

### E07.S07 · Absorbing chop with timing
Status: todo | Size: M | Owner: the lead | Milestone: M3 | Needs: E01.S07 T3 | Roadmap: GP7, PH5
Done when: a timing press as the nose meets a wave face keeps the board in the water and the fin gripping; bad timing launches the board, the fin loses grip in the air and it lands in a spin-out or a catapult; the rhythm follows the real wave spacing.
- [ ] T1 The knees as the input (PH5) on the press; the window from the wave spacing and the speed
- [ ] T2 Measured on the lake's chop and the sea's at 18 and 24 kt
- [ ] T3 The body on the mouse as the alternative (forward and back in rhythm)

### E07.S08 · Feedback: why you fell
Status: todo | Size: S | Owner: the lead | Milestone: M4 | Needs: — | Roadmap: —
Done when: after a fall a one-line plain-language note says what happened (a catapult in a gust with the sail sheeted in; a spin-out at 30 kt with the back foot pressed; a nose dive after a crest) from the telemetry, and a ten-second replay can be watched.
- [ ] T1 The fall's cause from the fall recorder (`Game/dev/fall_log.gd`)
- [ ] T2 The replay of the last ten seconds (the state ring buffer; the camera free)

### E07.S09 · The lessons
Status: todo | Size: M | Owner: Max for the words, the lead | Milestone: M4 | Needs: E07.S03, E05.S07 | Roadmap: UI2
Done when: five lessons mirror the ladder (1 steer and tack; 2 push and ease for a gust; 3 the rail and the trim; 4 the gybe; 5 pumping and chop), each a two-minute drill with a pass mark and a debrief, given by the coach on the beach and from the pause menu; the How to sail page is rewritten as the reference (UI2).
- [ ] T1 The five drills designed (the condition, the task, the pass mark)
- [ ] T2 Built on the open water spot; the debrief from the telemetry
- [ ] T3 The How to sail and Controls pages and the README's table rewritten for the push and the ladder

### E07.S10 · Speed runs and the record per spot
Status: todo | Size: S | Owner: the lead | Milestone: M7 | Needs: E04.S14 | Roadmap: GP4
Done when: a speed run over 500 m (and the 10-second and 2-second bests, GPS style) is a race type with a record per spot, level and gear, and Lüderitz's canal is its home.
- [ ] T1 The speed run as a race type and its HUD
- [ ] T2 The records in the profile (E13.S04)

### E07.S11 · Progression in the career
Status: todo | Size: S | Owner: the lead | Milestone: M8 | Needs: Q22, E14.S01 | Roadmap: —
Done when: the career unlocks the levels by lessons passed or results (Q22), free sailing stays open, and the HUD shows the next step.
- [ ] T1 The unlock rules
- [ ] T2 The coach's and the office's prompts
