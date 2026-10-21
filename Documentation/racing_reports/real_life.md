# real_life (F3 of AI_FLEET_PLAN.md): wind shadows and the racing rules

Built 21 October 2026 (Session 53, the afternoon) by Claude Fable 5.1 itself, on `feature/p9-racing` while the laptop trained F5's first stage. Max: "I have no time, continue." F3's third item, gear per persona, goes with F4 (the personas), where the sheets that choose the gear are made.

## What was built

**1. Wind shadows (`Game/race/wind_shadows.gd`, `wind_shadow_config.gd`, `Game/config/wind_shadow_default.tres`).** Behind every sail that is up lies a cone of slower air: 2.5 m wide either side at the sail, widening at 8 degrees, 30 % of the wind missing within 5 m of the sail and fading to nothing at 30 m (about six mast heights), with a smooth profile across the cone (full on its axis, nothing at its edge); several shadows add up to at most half the wind; a sail in the water casts none, and a board's own sail casts none on itself. The cone lies along the wind at the point (on the lake it varies from place to place). The numbers are **Michiel's to set** (decision 1 of the plan) in the config file; the defaults are the sailing books' five to seven mast heights, strongest within two.

**2. One hook in the physics (`Game/sim/wind_disturbance.gd`; `wind_field.gd`, `map_wind_field.gd`; PHYSICS_SPEC.md 8.11).** The wind field knows nothing of sails. It has `disturbance`, a `WindDisturbance` (a plain class whose `factor_at(point, undisturbed)` answers 1), null by default; both fields' `velocity_at()` multiply their answer by it when one is set. With none set the answer is bit for bit what it was: the tests, the validation suite and the matrix run without one. The sail's true and apparent wind and the sailor's windage are the three queries that feel it. The F1 thread rule is kept: each board's field gets its own `WindShadows` with its own copy of the fleet's places every tick, so a board stepped on a worker thread reads only its own fields.

**3. Where the shadows are cast.** The game's race (`RaceRunner._cast_shadows()` every tick before the physics; the player's board included; `--shadows=0` turns them off), the race tool (`tools/race.sh`, `--shadows=1` by default) and the trainer's stages with company (S5 and S6, `RaceEnv.Options.shadows`). The racing HUD's wind line says "in a wind shadow: 24 % less" when the player's sail is in one.

**4. The racing rules (`Game/race/race_rules.gd`).** A judge fed every board's place, heading, tack and speed each tick: port keeps clear of starboard (rule 10); on the same tack the windward board keeps clear when overlapped (11) and the board clear astern when not (12); inside the zone (15 m) round the mark both are sailing to, the inside board of two overlapped boards gets room (18). Overlapped means neither hull is behind the line across the other's stern (2.4 m hulls). A breach is a touch (within 2.6 m: the boards pass through each other, so that stands for contact) by the board that had to keep clear while it was closing on the other; one penalty per incident (the same pair gets no second one within 10 s). A penalty is cleared by a full turn (the heading sweeping 330 degrees since it was given, the sailing rules' one-turn penalty) or, uncleared at the finish, costs 20 s of race time (decision 2: a penalty turn for the AI, a warning and a time penalty for the player).

**5. The rules in the race.** `RaceSim.set_time_penalty_s()` (the finish adds what stands), the results and the race tool's lines "(+20 s penalty)", a penalty report after the start report. The game (`RaceRunner._judge()`, `--rules=0` turns it off): the player and the learned skippers are warned on the HUD ("Penalty: port gives way to starboard. Turn a full circle, or +20 s at the finish", then a shorter line while it stands) and carry the time to the finish unless they turn a circle. The scripted skippers (`Skipper`) keep clear **by the rules** now: only the board that must keep clear bears away, and only from the board it must keep clear of (rule 6 before F3 had everyone bear away from everyone close by); a right-of-way board holds its course. A penalty is taken at once while racing (not in the pre-start crowd): a tack, then a gybe from 120 degrees off the wind, a full circle the judge sees sweep round; given up and tried again after 45 s if it did not come round. The trainer's company stages (S5, S6) keep the rules too: a penalty costs 50 m of reward at once, no turn (the brain is not asked to turn circles).

## Measured

- **Unit tests:** `test_wind_shadows.gd` (7: the cone's numbers, the sum's cap, the own sail and the fallen sail, the wind's direction, the field's hook), `test_race_rules.gd` (8: each rule, the breach, the incident, the turn, the water, the distance), `test_rules_in_race.gd` (3: a penalised scripted skipper turns a full circle in a headless race and the judge clears it about 16 s after the penalty; a standing penalty adds 20 s at the finish; a race with the rules on sails on), and a RaceEnv test (a board 6 m dead downwind of another close-hauled is the slower one with the shadows on and as fast with them off). The suite: 525 of 525 after the rules (the suite ran again after the personas and the Race page: see P9_PROGRESS.md); `tools/check.sh` 257 files, 0 failed.
- **Eight characters on T1 at 15 kt, headless, with and without the shadows** (`tools/race.sh --skippers=allrounder,cautious,gambler,rookie x2 --prestart=60 --seconds=600`, seed 1): with the shadows (and without the rules, which landed between the two runs: not a clean comparison, to be redone on a quiet laptop) all eight finish between 8:27 and 9:23 with no fall, mark 1 rounded between 2:46 and 3:16; without the shadows and with the rules the winner takes 7:57, the field spreads to 9:38 with one board still 64 m from the last gate when the race ends, and the starts are 1.4 to 4.9 s after the gun. So eight boards race on with both; what the shadows cost in time and the rules in penalties wants the clean pair of races (and Fleet on t1_loop, the release build, 12 s measured per size (the player's board as well).

| AI boards | fps | A frame, average / worst (ms) | All boards' physics per tick, side by side (ms) | A board's own step, median / worst (ms) | The rest of a frame (ms) |
|---|---|---|---|---|---|
| 8 | 143 | 7.0 / 20.4 | 5.34 | 3.24 / 3.33 | 5.1 |
| 16 | 36 | 27.6 / 90.2 | 8.05 | 2.93 / 3.38 | 5.7 |
| 24 | 5 | 185.9 / 211.2 | 11.62 | 3.08 / 3.51 | 7.2 |
| 32 | 4 | 243.2 / 262.0 | 14.77 | 3.13 / 3.55 | 8.5 |
| 40 | 3 | 292.7 / 311.6 | 17.88 | 3.16 / 3.60 | 9.8 | for the frame) once the training is off the laptop.
- The cost of the shadows and the judge in a fleet is not measured yet (the laptop was training; `tools/fleet_measure.sh` on a quiet machine). The shadow sum is a few flops per other sail per wind query (three queries per substep per board); the judge looks at every pair within 15 m once per tick.

## Not verified

- How it looks and feels in a crowd (F3's Stop: Max races in a crowd): the release pack is rebuilt with it (`tools/release.sh --race=t1_loop --skippers=allrounder,cautious,gambler,rookie,allrounder,cautious,gambler,rookie`); nobody has played it.
- Michiel's numbers for the shadow (the shape, the strength, the length) and his view of the hook.
- The rules' effect on a 16-board start (penalties given, turns taken) over many races; the AI's penalty turn in a crowd (it turns where it is: a danger to the others, as a real penalty turn is).
- Mark room between boards on opposite tacks (rule 18 is applied on the same tack only; port still keeps clear of starboard at a mark).
- The validation suite's skipper races were not rerun (they build their races without the judge and without shadows: nothing changed for them).

## Open for the lead and for Max

- Gear per persona with F4.
- A penalty turn for the learned skippers once the brains know how (a "turn" action, or the hands' turn as a skill): for now they carry the time.
- Collisions proper (RD6: a gentle push apart and a loss of speed) are a contact force in `Game/sim/`, Michiel's; the judge would then see real touches.
