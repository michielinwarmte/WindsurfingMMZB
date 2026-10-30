# Flying the board: what it takes for the autopilot to ride the tail with the nose up

For Max and Michiel. Written 30 October 2026 by the lead (Fable 5.1) from the three reviews of the branch `ph28/sail-and-hull` (`review_sail.md`, `review_hull.md`, `review_sim.md`), the reviewers' follow-up answers, the hull balance report (`hull_balance.md`), GP0's report, the spec, and the sources listed at the end. Nothing in the game was changed for this report. Numbers that are mine are labelled "estimate".

## 1. In short

Max's goal: the autopilot sails the board the way a slalom sailor does, riding on the tail with the nose up, the lift under the rider's control, and the push dial turning that control up until the board bounces or catapults.

Today the board cannot do it, for three reasons in this order of weight:

1. **The hull model parks the board long and nose-down.** Its rule that a strip of the bottom may push but never pull (assumption A-05) acts on the JP SL 72's rocker. It lifts the board at a lower pitch than a flat planing surface needs, puts the water's push 0.2 m too far forward, and is the stiffness the 1.8 Hz bounce runs on. The lift for a board riding on 0.6 to 1.0 m at 1 to 2.5 degrees exists in the model; nothing static stops it. The clip is what fills the gap first.
2. **The moment balance is real physics, and it is against us.** The sail's drive, 300 N at 1.5 m up, and the sail's upward pull at the tail (the rig raked to its stop) hold the nose down. Only the sailor's weight lifts it, and the sailor is already at the back strap. Gourlay & Martellotta's own force balance, with the game's numbers in it, gives the push at about 1.0 to 1.1 m from the tail, which is what the game measures. To get to their 0.6 to 0.8 m, three levers have to act together: less rake so the sail's upward pull sits near the push, a front-foot and back-foot couple, and a lower drive line. Each alone is not enough.
3. **The sailor model and the autopilot have no lever to fly with.** The autopilot holds its course with the rake alone, so the rake sits at its stop and the sail's force at the tail. The trim press is a controller that is already at its reach. The feet can only move weight, not pull up on the front strap. The rig's lean is a fixed share of the hike. The push dial today changes how much pull the sailor holds, not where the board rides.

What "flying" is in numbers, from the sources: the board rides on its last 0.6 to 1.0 m at about 1 to 2.5 degrees of trim at 15 to 18 m/s, falling with speed. The nose looks high because of the rocker, not the trim. Three to four degrees at these speeds would mean riding on 0.1 to 0.3 m, outside what any planing theory covers. The validation targets (1.5 to 4 degrees) are too high at the top and should be rewritten.

The work splits as: Michiel for the hull's clip and the feet's couple (sections 4 and 5), an AI session for the autopilot and the dial (section 6), and Max for four measurements of his own sailing (section 7).

## 2. What the real world says about a flying slalom board

No measured trim or wet length of a modern slalom board exists in our sources or on the web (a tank test, photos from below, a motion sensor). What there is:

| What | Number | Source | Reliability |
|---|---|---|---|
| Trim of a planing sailboard | 3 degrees at 12 kn, 2 at 14 kn, falling with the speed squared: about 1.1 at 20 kn and 0.75 at 24 kn (estimate from their curve's shape) | Gourlay & Martellotta 2011, two-dimensional planing theory on the RS:X: 110 kg all up, the sailor's weight at the rear strap 0.3 m from the tail, the rig raked 20 degrees, the sail's drive 150 N at 1.8 m up | theory |
| Wet length | about 0.8 m, constant from 8 to 24 kn, 1.3 times the push's distance from the tail (0.6 m) | the same | theory |
| Wet length | "observed values of mean wetted length are approximately 1.0 m" | Sutherland 1993 (narrower 1993 boards) | observed, method not given |
| The flat a modern board rides on | "the flat section is only about 80 cm"; "you are really standing right at the back, just riding on the gliding surface" | Gnigler, JP's shaper, surf-magazin 2025 | shaper |
| Where the wet part ends | "if the area under the front foot is spending most of the time in the water, the board isn't flying" | O'Shea & Crossley, Windsurf Magazine 2022 | expert |
| Trim, a Formula board at 20 kn | 6.8 degrees ("illustrative") | Drake 2005 | theory, a 1 m wide board; treat with care |
| Trim and wet length for the game's 72 cm board and 97 kg, by Savitsky's equations | at 15 m/s, 0.6 to 1.0 m wet goes with 0.95 to 1.5 degrees if the hull carries 540 N (today's split, the fin and rig carrying the rest), 1.2 to 1.9 degrees at 700 N, 1.6 to 2.5 degrees if it carries everything; at 18 m/s about 0.3 degrees less | the hull reviewer, Savitsky 1964 | theory |
| The porpoising limit | Savitsky's chart does not cover a load this light for its width; extrapolated it gives 0.4 to 0.9 degrees, below where the board rides steadily | spec F22, the hull reviewer | not usable as a gate; the rider's legs are the damper the chart's free models did not have |
| The harness | 368 to 415 N for a 75 kg sailor with a 5.0 to 6.5 m2 sail | Walls & Gale 2001 | measured, one sailor |
| The front foot's pull in its strap | 150 to 250 N held, about 400 N briefly; a nose-up couple of 60 to 100 N·m held, about 170 briefly | U1 sources report | estimate from hip-flexor and dinghy hiking-strap forces |
| The body's hike | 20 to 30 degrees above horizontal, the centre of mass 1.03 m from the feet | Gourlay & Martellotta 2011 | theory; Max's photo reads 40 to 50 degrees with the hips 0.6 m up (estimate) |

So "flying" is a board on its last 0.6 to 1.0 m at 1 to 2.5 degrees, the nose high above the water because the rocker lifts it 13 cm over the last 1.6 m, the windward rail a few degrees down, and no bounce. Gourlay's balance is worth repeating because it is the one worked example: the rider's weight at the rear strap, the rig raked 20 degrees, and the push lands 0.6 m from the tail with a drive of 150 N. The game's reaches have twice that drive at nearly the same height, and that is the whole story of section 3.

## 3. Where the game is, and why

The shipped default, 18 kt beam reach, flat water (the hull reviewer's probe, means over 30 to 60 s): 14.96 m/s, the hull's pitch −0.29 degrees (nose down), the strips' trim 0.43 degrees, 1.27 m wet, the push 1.13 m from the tail. The hull carries 540 N of the 955 N; the fin's upward force (146 N) and the rig carry the rest. Asking the sailor to aim at 3 degrees changes nothing: the press is already at the back strap.

**The moment balance, with Gourlay's method and the game's numbers (estimate).** Sailor 785 N at 0.17 m from the tail, rig 93 N at about 0.5 m, board 77 N at 1.14 m, the drive 300 N at 1.5 m, the sail's upward pull 211 N at the tail (the rig leaned 24 degrees and raked to its stop), the fin's upward 146 N at 0.18 m. Solved for the push: about 1.1 m. The game measures 0.9 to 1.13 m. Each lever from there, alone:

| Lever | The push moves | Note |
|---|---|---|
| The rake from 25 to 18 degrees, so the sail's upward pull acts at about 0.5 m from the tail instead of at the tail | about −0.15 m | the tunnel's rig-back was 18 degrees; the sim's 25 degree stop has no source |
| A front-foot and back-foot couple of 80 N·m nose-up | about −0.12 m | the U1 estimate's range; not in the model |
| The drive line from 1.5 to 1.2 m up (the boom lower, the centre of effort lower) | about −0.14 m | the tunnel puts the force 2.0 m up the mast when powered, so this one is limited |
| The sailor's weight 0.2 m further aft | about −0.2 m | the body cannot reach: the hike and the hang-back already add up to more than one body (review_sim.md, section 12 of the hull report) |
| The fin's upward force to zero | about −0.19 m | the fin's lift at the tail is nose-down in the balance; a real rider hangs further back to use it |

Together the first three give about 0.65 m, Gourlay's number. None alone gets there. This is why section 14 of the hull report found nothing that shortened the wet part: the levers were tried one at a time, and the hull's clip was holding the push forward on top.

**About "mast foot pressure".** In a rigid-body balance the mast foot and the harness are inside the windsurfer: whatever the line lifts into the rig comes down on the foot and the feet give it back. The rider cannot push the nose down by pulling on the boom. What a rider feels as mast foot pressure is the sail's force; the only ways to change the trim with it are the ones the model has: the rig's lean (how much of the force points up), the rake (where it acts), the sheet (how much). The levers that are real and missing are the front foot pulling up in its strap against the back foot pressing (a couple with no weight moved), and one body hanging back behind a short harness line.

**About the fin.** Max feels the fin lifting the nose. In the balance a fin pushing up at the tail is nose-down, unless the rider's weight is behind it. In the sim the whole windsurfer's centre of mass sits right above the fin. The real feel is more likely the board rising out of the water as the fin takes 150 to 250 N off the hull, with the rider hanging far enough back that the nose stays up. No source gives a fin's vertical force.

## 4. The hull (Michiel), in order

From `review_hull.md` and the hull reviewer's follow-up. The hull model's planing lift is strip theory anchored to Savitsky. Step 6 of `_apply_planing_lift` (`hull_model.gd:525` and `:536`) drops every strip whose force would be negative. On the old flat board that did nothing below 1.5 m wet. On the SL 72's rocker, which starts 0.68 m from the tail, every planing wet length ends on it: at 2 degrees of heel the lift is 2.1 times Savitsky's at 1.28 m and 3.2 times at 1.5 m, and the push sits at 1.13 m where Savitsky's centroid is 0.93 m. The board then carries its load at a lower pitch than a flat surface needs (−0.3 degrees against about +0.8), so it rides long and nose-down, and the steep rise of lift with wet length (about 1000 N over 0.28 m) is the spring the 1.8 Hz bounce runs on (estimate: 3 Hz on the clip's stiffness, 1.1 Hz on Savitsky's, 1.8 observed with the legs coupled in).

1. **Replace the clip by consistent strip theory with a bounded suction.** Sources: Zarnick 1978 (already cited in the file), the thin-wing sign for a rockered bottom (Savitsky 1964, Savitsky & Brown 1976, spec line 2481), the bound being the water's head above the bottom (geometry). Risk: the board sits lower or longer until the balance is retuned; the old board changes only beyond 1.5 m. Test: on the default board at 15 m/s, 1 degree, 2 degrees of heel, the lift within 25 % of Savitsky's at 1.0, 1.28 and 1.5 m and rising smoothly; the old-rocker board unchanged below 1.5 m.
2. **Pin the push's position:** the centroid within 0.05 m of Savitsky's on both boards from one to two and a half beams of wet length.
3. **The transom relief at short wet parts:** Savitsky's lift already contains the transom's fall-off; the half-beam relief double-counts it, 0.87 of his level at 0.6 m. Risk: 5 to 13 % more lift at short wet parts. Test: within 10 % of Savitsky level from one to two beams.
4. **The heeled lift at short wet parts:** 0.44 to 0.56 of Savitsky at 0.6 m and 2 degrees of heel; NACA TN 4187 (in the repo) is the source, the probe's TN column the target. Test: within 15 % of TN 4187 at 0.6 to 1.0 m, 2 to 4.5 degrees.
5. **Keep the porpoising limit reported only,** and say so in the spec's F22: the chart does not cover a board this light for its width.
6. **Before any of it, find out whether the bounce is the clip's:** rerun the bouncing case with the old rocker (a real porpoising survives, an artefact goes); 13 rows and a halved substep (an artefact of the grid changes, physics does not); split the clipped share out of the water's +4.5 W in `pitch_budget.gd`. And pass the substep to `_hold_the_rig` at `pitch_budget.gd:141` first: with the rig's lag on, the tool measured a different rig from the game (review_sim.md 3.6).

## 5. The balance and the sailor (Michiel), in order

From `review_sim.md`, `review_sail.md` and their follow-ups.

1. **The front foot's couple.** A nose-up pitch couple at the feet, the rider pulling up on the front strap against the back foot, capped at the U1 estimate (60 to 100 N·m held, 170 briefly; no windsurf measurement exists; Max can say whether that is what he feels). Today the feet's moment is capped only in roll (`windsurfer_sim.gd:1328`); the pitch part passes uncapped, and the trim press only moves weight. Risk: it is a new controller unless the cap is its only number; drive it from the trim aimed for. Test: a unit test that the couple is bounded and lifts the nose at a held speed; validation targets 3 and 4 of `test_planing_wet_area.gd` with the numbers of section 8.
2. **One body.** Cap the hike plus the hang-back at one body's reach (0.57 of the height, Gourlay & Martellotta), and shorten the harness line toward 0.3 to 0.5 m (U1's sources; Max's photo). The model's line is about 1 m and the body reaches 1.11 m plus the hang-back. This moves the weight in, so it costs trim and righting moment: do it together with step 1. Tests: the centre of mass's distance from the feet; the harness tension against Walls & Gale's 368 to 415 N as a validation band (today 800 to 857 N).
3. **The rake's stop** from 25 degrees to a sourced value (the tunnel's rig-back was 18 degrees; Max's photos). At full rake the sail's upward pull acts at the tail, 280 N·m nose-down on the 24 kt broad reach. Estimate: about 60 N·m less at 18 degrees, and less steering authority, which step 6.1 gives back through the rail.
4. **The centre of effort's height by angle of attack** (the tunnel's Fig. 8d: 1.0 m at 1 degree, 1.7 at 5, 1.95 at 9, 2.0 from 12): a small table in `SailConfig` at `sail_model.gd:137`. Measured. No effect on the powered reach; less heeling and nose-down when eased, in a bear-away and a tack. Test: the height at 5 degrees is 0.85 of that at 12.
5. **Fix trimming by feel before the dial uses it:** the 3 s, 8 cm sawtooth (an integral controller with a 1.5 s lag and a 10 to 1 rate asymmetry), and the chatter detector saturated by the waves' own motion, so that in any sea the rider never trims aft (review_sim.md 3.1). The bounce the rider feels should be the board's own, not the sea's.
6. **The review's open decisions that touch this:** the rig's pitch lag is on at 0.3 s while every document says off; the fin at the fin box with the mast foot 2 cm from a bounce; the 30 degree hike chosen for its effect. They are in the three reviews.

## 6. The autopilot and the push dial (an AI session, after 4 and 5)

1. **Steer with the feet and the rail before the rake.** The pilot holds a course with the rake alone (`trim_with_rake_first`, `autopilot.gd:44-53`; `lean_share` 0: "a flat board"), so on a reach the rake sits at its stop and drags the centre of effort to the tail. A slalom sailor steers with the feet and the rail and leaves the rig where the hike puts it. The helm's third lever exists (`helm.gd:9-11`, `hull.rail_yaw_nm`, an estimate). Risk: the spin-out section 13 saw with the fin at the box. Test: the 24 kt broad reach holds its course with the rake below 0.8 and no spin-out; the heads-up-on-rake-back test on both tacks.
2. **The rig's lean as the rider's own input,** apart from the hike: `SimControls.rig_tilt` exists already (plus or minus 30 degrees). The push can use it with no physics change: more lean means more of the sail's force points up and the hull carries less. The physical link (the hooked-in line) is built and off.
3. **The dial onto technique.** Today the dial reaches `hike_share` and the ease timing: how much pull the sailor holds. For the push to control the lift it must set the sailor's technique, through the player's own `SailorConfig` copy as package B does: the trim aimed for by speed (`running_trim_deg`, from Gourlay's curve: 3 degrees at 12 kn, 2 at 14, about 1 at 20), `bounce_tolerance_dps` (how much chatter before easing), the couple of step 5.1, the rig's tilt of step 6.2, the rail (`fin_load_bank_deg`), and `hike_share`. Over-push then fails from physics that exist: the bounce (the hull's porpoising, with the rider's legs as the damper) and the catapult (the righting moment). Tests: `test_trim_by_feel.gd` extended; `test_push_warning.gd` (the pushed rider catapults); the reach check's pitch SD below 0.3 degrees at the eased setting; GP0's sweep rerun at the top of the dial.
4. **GP0's measurement stands:** pushing pays only with the late ease, and the risk at 18 kt needs the sailor's reaction time (PH25). The dial's three settings come from GP0's table; the lift control is what makes the middle of the dial feel like something.

## 7. For Max

Four things only you can give, each a measurement or a photo, not a guess:

1. **A photo or a video from the side at full speed on flat water**, showing the nose and the tail against the water: how much of the board is wet, and how high the nose rides. That is the one measurement nobody has.
2. **How far back and out you hang when fully powered on a reach:** where your hips are against the back strap and the tail, and how long your lines are. Session 60 read 0.6 m up and 40 to 50 degrees from one photo; a second photo from behind would settle it.
3. **The front foot:** when you fly the board, do you pull up on the front strap, and how hard (a share of your weight)? The model has no such pull; the estimate is 150 to 250 N.
4. **Which way the board is railed at speed** (PH27): windward rail down, and by how much. The sim says flat is fastest fully planing; you said a flat board is not the fastest.

## 8. The validation targets, rewritten

U1's targets 3 and 4 came from Gourlay's 12 kn upwind case. At the game's reaches the same theory gives lower trims. Proposed, for Michiel to confirm:

| Target | Today | Proposed | Source |
|---|---|---|---|
| The wet front at 18 and 24 kt on the beam and broad reach | 0.6 to 1.0 m | 0.6 to 1.0 m (unchanged) | Gourlay 0.8 m; Sutherland about 1.0; the shapers' 0.8 |
| The trim, the same cases | 1.5 to 4 degrees | 1.0 to 2.5 degrees, falling with speed | Savitsky's equations for this load and width; Gourlay's curve |
| The push's centre | 0.45 to 0.75 m | 0.45 to 0.75 m (unchanged) | Gourlay 0.6 m |
| The harness tension on a planing reach | none | 300 to 500 N for 80 kg | Walls & Gale 2001 scaled by weight (one sailor) |
| The hull's lift against Savitsky at the ridden state | none | within 25 % | Savitsky 1964 |

## 9. The order of work

1. Michiel reads the three reviews and decides A-05 (section 4.1), the rig's lag and the fin's place.
2. The hull steps 4.1 to 4.5, with the bounce check 4.6 first. Expect the board to sit longer at first: that is the honest state.
3. The balance steps 5.1 to 5.4 together, measured against section 8.
4. The autopilot steps 6.1 and 6.2, then the dial 6.3, then Max plays it.
5. Max's four answers (section 7) can come at any time and change the numbers in 5.1, 5.2 and 8.

Nothing in this plan is fitted to a result. Where a number has no source it is labelled an estimate, and the first thing a step does is measure.

## Sources

- Gourlay, T. and Martellotta, J. (2011), *Aero-hydrodynamics of an RS:X Olympic racing sailboard*, Curtin University CMST Research Report 2011-02 (cmst.curtin.edu.au). Read in full for this report: section 7, the planing calculations.
- Savitsky, D. (1964), *Hydrodynamic design of planing hulls*; Savitsky & Brown (1976). The hull reviewer's equations.
- Zhang et al. (2025), the iQFOiL 8 m2 wind-tunnel study, arXiv 2501.13254 (`Documentation/Science/`): Fig. 8d for the centre of effort's height.
- Walls, J. and Gale, J. (2001), harness line forces (abstract only).
- Sutherland (1993), Drake (2005), the shapers and Windsurf Magazine: as listed in the archived `PLAYTEST_UPGRADES.md`, "What the real world says".
- U1's sources report (`Documentation/reports/u1/sources.md`): the front foot's pull, the hook's height, the line.
- The three reviews in this folder, the hull balance report sections 2, 3, 10, 12, 13 and 14, GP0's report, `PHYSICS_SPEC.md` F22 and section 7.5.
