# The physics realism audit (7 November 2026)

**Asked by Max** (7 November 2026, 18:00): "do the full version as I want it as realistic as possible. Use
real papers and science/physics. Don't spawn any agents, do everything yourself." The lead (Claude) does it
alone on branch `physics/realism-7nov` (from `autopilot/lake-speed` 061b442) in `WindsurfingMMZB-fixes`.
`Game/sim/` is Michiel's: every change is one commit with the before and after numbers, and nothing merges
without his review.

**The training is paused** (the lake tuner stopped at 18:03 after 183 candidates, best 1068.1 against the
baseline's 1206.0; state in `.sim_output/lake_speed/tuner_state.json`, resumable with
`tools/lake_tuner_detached.sh`). It continues after the physics build, starting from its best set; then the
results are compared with now.

**If cut off by the usage limit:** a one-shot wake-up at 20:33 resumes from this file's "Where we are".

## Where we are

- [x] The tuner paused, the branch made, this file.
- [ ] A. The fin's upward force (the bend, H6)
- [ ] B. The sailor's stance getting going (H7)
- [ ] C. The planing hull: trim, lift, drag (H1, H3)
- [ ] D. The sail's forces (H2), against Zhang et al. 2025
- [ ] E. The waves' cost
- [ ] F. The moments together (pitch, roll, yaw), the mast foot
- [ ] G. The fixes built, one commit each, before and after
- [ ] H. The regression (unit, check, validation, suites) and the comparison
- [ ] I. The tuner resumed on the new physics

## Sources in the repo (`Documentation/Science/`)

- Zhang, Bertrand, Rabaud, Augier, Fermigier (2025), *Flying shape and aerodynamics of a full-scale flexible
  Olympic windsurf sail*, arXiv 2501.13254: the iQFOiL sail's forces measured at full scale.
- Fagg (1997), *The development of a reversible and finitely variable camber windsurf fin*, PhD thesis,
  Bournemouth University: fin forces and loads.
- Maciel et al. (2021), *Monocular 3D reconstruction of sail flying shape*, Machine Vision and Applications.
- Souppez and Viola (2024), *Water tunnel testing of downwind yacht sails*, Experiments in Fluids.

## Findings

(Each: what the sim does, what the science says with the source, the evidence, the fix, its effect.)

### A. The fin's upward force (H6): real physics, calibrated; not the nose dive

- **The sim:** the bent fin's lift is square to each bent strip, so a fin bent toward its lift pushes partly
  up toward the deck (`fin_model.gd _bend`, U2). On flat water at x1.3 the upward part grows with speed:
  40 N at 30 km/h, 113 N at 48, 150 to 185 N at 55 to 60 (about a fifth of the sideways force: 10 to 11
  degrees of tilt).
- **The science:** the geometry is a wing's (lift square to the local span). The stiffness is calibrated
  on the only measured slalom fin, the F-Hot 37 cm (Nascimento 2017: 100 N at 80 % span -> 20 mm; 55.2 N/mm
  at 40 %), checked against its FEA (Cardoso de Brito 2021: 61 mm at the tip at 594 N), PHYSICS_SPEC 4.
- **Getting going it pushes nothing:** 0 to 9 N in the first 2 s from rest (the fin's force goes with the
  speed squared). The tail rising while the nose is in the water there is the stance (B), not the fin.
- **What it costs at speed:** in the pitch budget (24 kt, 100 deg, 62 km/h) the fin's up force acts 0.63 m
  behind the water's centre of push: -75 N m of the system's balance, which moves the push about 0.12 m
  forward (about 0.17 m more wetted length, about 17 % more friction). Max asked for the fin's lift in U2;
  it stays, and its share is now known.

### B. The sailor's stance getting going (H7): a fault

- **The sim:** `WindsurferSim._update_sailor`: the stance (0 at the mast foot, 1 in the back straps) is
  `smoothstep(3.5, 7.0 m/s, speed)`, whatever the sail's power; only above the hump speed (about 2.3 m/s)
  does a low bow send the weight back, at `stance_rate_per_s` 1.0.
- **The evidence:** x1.3, 130 deg from rest: the body passes 150 to 200 N m nose-down through the feet in
  the first 1.5 s, the nose 14 deg down, the bow 0.43 m under; planing starts only at 3 s.
- **How sailors do it:** in a strong wind the sailor starts with the weight back (back foot behind the
  centre, leaning against the rig) because the rig's pull high above the board drives the nose down; in a
  light wind he stands forward to keep the board level. The stance answers the pitch, not the speed.
- **The fix to build:** the stance follows the board's balance at every speed: the weight goes back as far
  as the bow needs (the existing hump rule, below the hump too, scaled by the rig's bow-down moment), and
  forward again only as the board levels.

### C. The planing hull: consistent with planing theory

- **The pitch budget** (24 kt, 100 deg, 17.2 m/s, sea-level air): trim 0.91 deg, wet length 0.98 m, the
  water's push 0.81 m forward of the tail, friction 210 N (Cf 0.00283 against ITTC-1957's 0.00274 at
  Re 1.7e7), planing drag 18 N, fin drag 54 N; the system's weight centre 0.06 m forward of the tail (the
  sailor's 0.12 m behind it); the sail's bow-down moment -722 N m against the sailor's weight +782 N m.
- **Savitsky's lift** at that trim and wet length (CL_beta about 0.016 for 600 N on a 0.5 m wet width)
  matches. Gourlay (2011, the RS:X, Tuck's 2-D planing theory) balances the board the same way: the wet
  length is about 1.3 times the centre of pressure's distance from the tail, the trim falls with speed at a
  nearly fixed wet length (3 deg at 12 kn, 2 deg at 14 kn); by his method the sim's drive (360 N at 1.6 to
  1.8 m) puts the centre of pressure near 0.95 m and the wet length near 1.2 m. So a flat board at speed is
  what the theory gives for this balance. Note: Savitsky's equations are fitted for trim 2 to 15 deg; the
  sim rides at 0.8 to 1.4 deg (outside the fit; Tuck's theory covers small trims).

### D. The sail: the twist formula extrapolated far beyond its data (a fault)

- **The sim:** `SailModel.twist_factor(q) = 1 / (1 + q / 125 Pa)` (floor 0.1) scales the lift below the
  stall (less near the peak: `twist_peak_share` 0.45). Fitted to Zhang et al. (2025): the full-scale sail's
  lift at 6 and 8 m/s is 0.85 and 0.75 of the untwisted line (q 22 to 38 Pa).
- **Where the game uses it:** on a reach at 56 km/h the apparent wind is 16 to 17 m/s (q about 140 Pa at
  0.98 kg/m3): factor 0.47, half the lift; at a 26 m/s gust-reach it would fall further toward the floor.
  Downwind (9 to 10 m/s, q about 45 Pa) it is 0.73. The formula's form is a guess fitted at two points; the
  data end at 8 m/s.
- **The physics:** twist opens the top of the sail under load (the loose leech, by design), and that top
  cannot carry less than nothing, while the bottom is held by the boom; so the loss must level off, not
  fall on toward zero. To test: the sensitivity (rigid against the formula), then a bounded law from the
  physics of the leech, checked against any twist data above 8 m/s.

### B, built: the balance stance (`SailorConfig.stance_balance_share` 0.5, `stance_dive_from_deg` 1, `stance_dive_full_deg` 6; `WindsurferSim._update_sailor`)

**Revised the same evening.** The first version anticipated the whole moment (share 1.0); the reach check's 12 kt broad reach (not planing, the sail eased and pulling forward) then put the weight in the straps, sank the tail (trim 23.6 deg) and fell, a new red in `test_planing_wet_area.gd`. The sailor's lean (the hang-back) already balances part of the pull, so the anticipation is half (0.5), and the rest is felt: the nose going down from 1 deg sends the weight back, fully at 6 deg, at any speed (above the hump speed `hump_trim_deg` did this already). With both: the 130 deg start -8.8 deg, the bow 0.22 m, planing at 3.57 s; the 90 deg start -2.7 deg, no dive, 3.28 s; the reach check all nine cases steady, no fall (12 kt 135 deg 5.57 m/s as before; 24 kt 135 deg 18.0 m/s). Test: `test_stance_balance.gd`.

The first version's table:

The stance aimed for is at least the share that cancels the pull's moment: the forward pull on the hands
times the boom's height, over the sailor's weight times the travel from the rest stance to the straps
(85 kg x 9.81 x 0.49 m = 409 N m for the default sailor). Strong-wind starts on flat water (x1.3, the
117 L / 7.5 m, between, 13:30):

| start | nose dive | bow under | planing after | 5 s |
|---|---:|---:|---:|---:|
| 130 deg, before | -14.8 deg | 0.43 m | 5.2 s | 26 km/h |
| 130 deg, balance | -8.8 deg | 0.22 m | 3.6 s | 32 km/h |
| 90 deg, before | -8.0 deg | 0.19 m | 3.6 s | 39 km/h |
| 90 deg, balance | -2.3 deg (no dive) | 0.07 m | 3.4 s | 39 km/h |

### The 135-degree cliff is in the validation too (known reds)

This morning's `tools/test.sh validation` polar (15 kt at the sail, sea level, 120 L, 6.5 m, 75 kg):
75 deg 23.0 kt, 90 deg 26.3, 105 deg 28.3, 120 deg 28.5 (each above its real-world range: 18, 20,
21.4, 22.1 kt +-15 %), 135 deg 14.9 kt (below its range: 21 kt +-20 %), 150 deg 11.2 (inside). On 26
October (Session 55) 135 deg was 18.3 kt and 120 deg 24.1: since then the reaches got faster and 135 deg
slower. The planing onset (dynamic lift carrying half the weight on a beam reach from rest at 15 kt) is
7.42 m/s (14.4 kn) against the real 8 to 10 kn of GPS tracks (seabreeze.com.au, The Windsurf Loop 2015).

**Drag reference:** Jim Drake (the windsurfer's co-inventor, an aeronautical engineer) puts a well-trimmed
board's drag at about 0.15 of its lift from about 6 to over 20 knots. The sim at 16 kn (135 deg, 16 kt
sea level): 152 N (friction 97, planing 44, fin 11) on about 1000 N: 0.15. So the planing drag at moderate
speed is right; the board is slow at 135 deg from rest because it stays in the hump: at 8.2 m/s 40 % of
its weight still on buoyancy, 1.61 m wet, while the apparent wind sits in its minimum (at 135 deg the
apparent wind is weakest at 0.71 of the true wind's speed). Over the hump (a flying start, or more wind)
it does 52 to 60 km/h (25 kt at 10 m, 21 at the sail).

### E. The waves (not settled)

Lake at x1.3 (between, 13:30), the 117 L / 7.5 m: beam 95 deg flat 55 km/h, half waves 49 (-11 %), full
48 (-14 %); broad 135 deg flat 55, half 38 (-31 %), full 34 (-38 %). Downwind in waves the board pitches
through every wave at about 1 Hz: the nose in (1.6 to 1.9 m wet, the water's lift up to 2.5 kN, the hull's
drag up to 420 N), then up to 8 deg and light (88 to 135 times a minute), landing nose-first. But the
flat run met 22.0 kt at the sail and the wave runs 20.2 to 20.5 (a faster board reaches other water), and
135 deg is bistable right there (31 km/h at 20 kt, 52 at 22): the waves' own cost downwind needs a steady
wind (to do). The validation's steady 18 kt beam reach: flat 25.8 kt, the lake's chop 19.0 (74 %), the
pitch -5.4 to 14.9 deg.

- **The legs** (`leg_natural_frequency_hz` 1.2, `leg_damping_ratio` 0.9; chosen in Session 37 to stay off
  a 1 Hz porpoising hull, not from data): softer legs (0.7 Hz, 0.6) do not change the wave runs (34 km/h)
  but stop the flat-water porpoising at 135 deg (pitch rate SD 2.46 -> 0.5 deg/s, light 23 -> 0 a minute,
  55 -> 58 km/h). Matsumoto and Griffin (1998) is passive standing; no measured figure for a sailor's
  active knees was found, so this is left for Michiel with the numbers, not applied.
- **The running trim** (the feet hold 2.0 deg, 1.5 fast): 3.5 or 5 deg changes the wave runs by about
  1 km/h. Not the cause.

### B, third round: the felt step only under the pull, and the bow-high release

Two more faults showed in the unit tests and the starts:
- **A board slowing off the plane** (the skipper's penalty turn easing down, `test_rules_in_race.gd`)
  settles its nose a little; the felt step sent the weight back and the board headed up into a tack
  instead of the gybe. A sailor steps forward there. The felt step now fades in with the pull
  (`smoothstep(0.15, 0.5, pull share)`): the nose driven down by the rig, not the nose settling.
- **The hump:** the hump rule sends the weight back while the bow is below `hump_trim_deg` and then holds
  it; with the weight already partly back the normal-wind start (x1.0, 100 deg) went up to +15.8 deg at the
  hump, the tail dragging, and planed 1.2 s later. Now a bow more than `stance_bow_high_deg` (4) above the
  hump trim lets the weight forward to what the speed and the pull ask for.

Starts (flat water, the 117 L / 7.5 m), old physics -> now:

| start | nose dive | bow under | planing after | the highest bow |
|---|---|---|---|---|
| x1.3, 130 deg | -14.8 -> -8.8 deg | 0.43 -> 0.22 m | 5.2 -> 3.5 s | 8.2 deg |
| x1.3, 90 deg | -8.0 -> -2.7 deg | 0.19 -> 0.08 m | 3.6 -> 3.3 s | 2.9 deg |
| x1.0, 90 deg, middle 14:30 | -8.0 -> -3.1 deg | 0.23 -> 0.12 m | 6.2 -> 5.65 s | 6.5 deg |
| x1.0, 100 deg, between 13:30 | -5.7 -> -3.1 deg | 0.17 -> 0.08 m | 12.6 -> 14.7 s | 8.9 -> 13.7 deg |

The last case sits at the planing threshold (12 to 15 s to plane) and swings with small changes: judged
on the lake suite's 30 cases (old physics from the tuner's frozen copy of 10:58, the same controller).
The unit tests that pin the old behaviour (`test_feet_press.gd`'s exact numbers, `test_push_controls.gd`'s
stance half-way at 2 s) run with the three switched off; with them off the feet-press numbers are bit for
bit the old ones, so the stance is the only change.

### B, final: the felt step and the bow-high release on, the anticipation off

Single runs in waves are chaotic (a start a second earlier meets other gusts and waves; one case can move
20 %). So each variant sailed the suite's nine start, strong and reach cases on the three gear combos at
four start times (13:30 and 1, 2 and 3 minutes later): 12 runs a case. The old physics is the tuner's
frozen copy of 10:58 (the same controller; it repeats the baseline's 1206.0 exactly). `seeds.py` in the
lead's scratchpad; tables in `.sim_output/audit/seeds_*.txt`.

| case (12 runs) | old | all three | felt + release (final) |
|---|---|---|---|
| start camping 100: planing, dive | 11.6 s, -6.7 | 11.1 s, -3.6 | 11.4 s, -5.5 |
| start between 120 | 14.3 s, -7.0 | 14.5 s, -4.4 | 14.0 s, -5.6 |
| start middle 90 port | 8.9 s, -8.0 | 8.0 s, -4.3 | 8.0 s, -4.8 |
| strong middle 100 | 4.9 s, -12.5 | 3.7 s, -6.1 (1 fall) | 4.1 s, -8.2 |
| strong between 130 | 8.1 s, -13.2 | 4.2 s, -6.5 | 5.8 s, -9.7 |
| beam middle x1.0, gusts | 38.2 km/h | 38.2 | 38.3 |
| beam south x1.0 port | 41.5 | 43.5 | 42.8 |
| beam between x1.3 | 40.6 | 37.5 | 38.4 |
| broad middle x1.3 | 35.0 (planing 9.0 s, dive -17.5) | 35.2 (7.3 s, -10.2) | 35.1 (8.0 s, -13.0) |

The anticipation alone (`stance_balance_share` 0.5) cost the strong beam reach 13 % (35.2 km/h, 12 runs)
and made two AI boards late at the T1 start (validation): it keeps the weight back whenever the sail pulls,
also on a board slowed by a wave, which then gets going again later. It stays in the code at 0. The felt
step reads the pitch over 0.5 s (`stance_feel_time_s`): with the raw pitch the waves' bobbing moved the
weight wave by wave once the board had slowed.

## Where we are (updated 19:30)

- [x] A. The fin: real physics, calibrated; its lift slope (5.1/rad against 5.0 from wing theory), drag
  (CD 0.010) and stall (12 deg; Fagg 1997: 9 to 14 deg for windsurf fins) checked.
- [x] B. The stance: built (the felt step, the bow-high release; the anticipation off).
- [x] C. The hull: consistent with Savitsky, Tuck/Gourlay and Drake's 0.15 (scaled with the speed squared).
- [x] D. The sail: the twist formula beyond its data (documented; little effect downwind; no data above
  8 m/s, so not changed).
- [x] E. The waves: measured in a steady wind (downwind 17 to 24 %, across 11 to 14 %); the legs and the
  trim are not the cause; no real figure to compare. The legs' flat-water porpoising: for Michiel.
- [x] F. The moments: the mast foot (about 40 % of the sailor's weight through the harness) and the sail's
  and fin's lift (37 % of the weight at 24 kt) explain the long wet part at speed; no measured mast-foot
  load was found to check it against.
- [ ] G/H. The final checks (unit, check, validation, the lake suite) and the commit.
- [ ] I. The tuner resumed on the new physics.

### B, the decision (20:05): in the code, off by default, a switch for Max

With the anticipation off and the bow-high release off, the felt step alone still showed falls the old
stance never had: in the lake suite one turn in 22 (a 24 kt gybe; in another run two 18 kt tacks, when the
step was also gated by the yaw rate) and in the 12-run sets one strong start in 12 (it fell at 29 s, after
a stop, so perhaps chance). Gated off while stepping round the mast and for 5 s after the sail goes across,
the suite still had 1 turn fall and 1 strong-start fall (1271.4 against 1206.0). A turn sits on a knife's
edge: any step during it can tip it. So:

- **Every board sails the old stance by default** (`stance_dive_full_deg` 0, `stance_balance_share` 0,
  `stance_bow_high_deg` 0): the physics is the old one bit for bit (the unit tests that pin it pass), so the
  AI fleet, the validation and the training keep what they were measured on.
- **The player can switch it on:** Settings > Sailing > "Balance stance (test)" (off by default;
  `SettingsValues.balance_stance`, `Windsurfer.use_balance_stance`, at `SailorConfig.BALANCE_STANCE_FULL_DEG`
  6 deg, the felt pitch over 0.5 s, not while stepping or for 5 s after a flip). On, the strong starts dive
  about a third less and plane a second or two sooner; Max judges the feel and whether the rare fall in a
  turn shows on his screen.
- To make it the default later: the falls in turns need a cause (which moment of the gybe the step hurts),
  then the lake suite at several start times, the turns included.

## The training

The lake tuner's run on the old physics (10:58 to 18:03, 184 candidates, best 1068.1 against 1206.0) is
kept in `.sim_output/lake_speed/oldphysics_run_7nov1058/` (state, leaderboard, log, candidates, and a copy
of its frozen project). Its best set had `gust_bear_away_deg` 3.75: the autopilot bearing away in gusts,
which Max ruled out ("b: no"); the lead set it to 0 in best.txt and took it and its two thresholds out of
the tuner. The physics by default is unchanged, so the new run starts fresh from that best set (applied to
`NIGHT_TUNING` with the gust at 0) on the same physics.
