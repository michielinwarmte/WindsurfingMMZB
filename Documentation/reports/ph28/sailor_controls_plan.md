# The sailor's controls: what a rider really does, read from the photos, and the plan to build it

For Max and Michiel. Written 30 October 2026 by the lead (Fable 5.1), after Max: "in real life we can pull on the straps; you need to fix a lot of small things the sailor can do; the fin is a precise thing to control; analyse the photos and come up with a plan." It builds on `flying_the_board.md` (the balance and the hull) and the three reviews in this folder. Every number read from a photo is an estimate by eye, with the board's length (2.3 to 2.5 m) and the boom's height (about 1.5 m above the deck) as the rulers. Nothing in the game was changed.

## 1. In short

The thirteen photos in `Documentation/images/Real life photos/` all show the same rider shape, and it is not the model's:

- **The rider hangs, low and far back.** On the slalom photos (Max's own and 141) the hips are 0.45 to 0.6 m above the deck and the body 30 to 45 degrees above the water; on the five speed-event photos (40 cm wide speed boards, Max's note) the riders sit lower still, hips 0.3 to 0.4 m and the body 25 to 30 degrees. In all of them the hook is 0.4 to 0.5 m from the boom, the front arm straight, the back arm bent, the front leg straight, the back leg bent, the hips behind the back foot. The model's full hike has the hips 0.42 m up at the end of a line of about 1 m, the body reaching 1.11 m plus the hang-back, more than one body.
- **The board flies on its tail with the nose high.** The wet part is the last 0.6 to 1.0 m in every powered photo; the nose tip rides 10 to 25 cm clear. The rail, from Max (30 October 2026, correcting the lead's first reading of the photos): a 72 cm board sails flat downwind, and crosswind and upwind with the windward rail up, the leeward rail down; the wider the board, the more. The model has that sign (2 degrees of leeward rail, `fin_load_bank_deg`), from a placeholder, not from Max; how many degrees, and where it stops, is his to give (PH27). The model rides on 1.2 to 1.3 m with its nose down.
- **The rig is raked back 15 to 25 degrees and leaned to windward 15 to 35 degrees,** more when more powered, with the head twisted open. The model's rake runs to a 25 degree stop for steering, and its lean is a fixed share of the hike.
- **The feet do things the model cannot:** the front foot pulls up in its strap against the back foot pressing down (a nose-up couple without moving weight), the back foot pushes sideways against the fin to load it, the toes and heels set the rail, the knees absorb the chop.

The plan is six packages, small on purpose, each with a source, a test and a photo to check against: the feet (P1), the body (P2), the rig as the rider's lever (P3), the fin as a precise control (P4), the hull that must allow it (P5, from the flying report), and the autopilot and the dial that use all of it (P6). Michiel owns P1, P2, P4 and P5; an AI session builds P3 and P6 after them. Four photos are copyrighted proofs and should stay out of git (section 7).

## 2. What each photo shows

Point of sail and attitude by eye. "Wet" is where the spray root sits, as a share of the board from the tail. Hips and body are above the deck and above the water. The five GSYPHOTO proofs are from a speed event on 40 cm wide speed boards (Max), not slalom boards: their posture is a speed sailor's and their flat attitude is a narrow board's. Where a photo shows the board railed, the lead first read it as the windward rail down; Max says a wide board rails the other way (the windward rail up), so the rows give the amount only.

| Photo | Scene | Board | Rider | Rig |
|---|---|---|---|---|
| 005.JPG | Max, lake, chop, close to beam reach, an older board | railed about 10 degrees, nose 20 cm clear, wet: the tail only | hooked in, legs nearly straight, body about 35 degrees, hips about 0.5 m, front arm straight | leaned to windward about 15, raked about 15 |
| 0af_9431 (GSY proof) | speed event, Karpathos, a 40 cm speed board, beam to broad reach | flat, nose 15 cm clear, spray from the back straps | very low, hips about 0.4 m, body about 30, back foot across the tail | raked about 20, leaned about 20 |
| 121.JPG (olivermaier.com) | NED-61, Patrik, Finish fins, beam reach in chop | flat, nose up, wet from the front strap back | low behind the sail, arms long | raked about 20 |
| 141.JPG | two riders on a lake, close reach | left (NED-61) railed a little; right rider railed about 8, nose up | both at about 45 degrees, hooked in | both leaned to windward 10 to 15 |
| 1b2_9431 (GSY proof) | SWE-10, speed event, a 40 cm board, broad reach | flat, nose up about 5, wet the last 0.8 m | the lowest of all: hips about 0.3 m, body about 25, front leg straight, back knee bent | raked about 25, leaned about 15 |
| 1c1_9431 (GSY proof) | B52, speed event, a 40 cm board, near a mark | flat, nose up | low, hips about 0.4 m | raked about 20 |
| 2015-08-18 | NED-61, lake, Racing Blade, beam reach | nose 25 cm clear, wet the last 0.8 m | hidden by the sail | raked about 20, sheeted in |
| 5c5_9431 (GSY proof) | speed event, a 40 cm board, beam reach, fully powered, flat water | flat, nose up, spray from the tail | hips about 0.3 m above the water, body about 25, both arms straight | leaned to windward about 35, raked about 15 |
| 8d5_9431 (GSY proof) | NED-57, speed event, a 40 cm board, broad reach | nose up about 5, wet about 0.7 m | low, hips about 0.4 m, back knee bent, front leg straight | raked about 25 |
| FTHZ9294 | lake, turbines, reach in chop | railed about 10, nose up | far back and out: body about 35, hips about 0.5 m, arms straight | leaned about 15, raked about 20 |
| IMG_4743 | Max 2025, Severne HGO with Octant, beam reach, powered | railed about 5, nose 15 cm clear, wet the last 0.8 m | hips about 0.55 m, body about 45, front arm straight, back arm bent, front leg straight, back leg bent; hook to boom about 0.45 m | leaned about 15, raked about 15, the head twisted open about 15 |
| IMG_7594 | NED-61, lake, buoys, beam reach | flat, nose a little up | body about 40 | raked about 20 |
| SPST4453 | NED-61, lake 2025, beam reach, powered | flat, nose 10 cm clear, wet behind the front strap | body about 30, hips about 0.45 m, both arms straight, hips behind the back foot | leaned about 20, raked about 20 |

**The pattern, as numbers for the config (estimates):**

| What | Photos | Model today |
|---|---|---|
| Hips above the deck, powered | slalom photos 0.45 to 0.6 m, 0.5 typical; the speed boards 0.3 to 0.4 m | 0.42 m at full hike (the lean's height drop 0.48 from standing) |
| Body above the water | slalom photos 30 to 45 degrees, 35 typical; the speed boards 25 to 30; lower the more powered | 30 degrees (Gourlay & Martellotta), chosen for its effect |
| The hook to the boom | 0.4 to 0.5 m | about 1 m (the fit from the hips to the grip) |
| Reach of the body from the feet | one body: the hips 0.6 to 0.9 m outboard and 0.2 to 0.4 m behind the back foot | 1.11 m out plus up to 0.8 m back |
| Rig lean to windward | 15 to 35 degrees, more when more powered | 25 degrees times the hike |
| Rake back | 15 to 25 degrees | up to 25, driven by the steering, usually at the stop on a reach |
| The rail, crosswind and upwind | Max: the windward rail up (the leeward rail down), the wider the board the more; the photos show about 5 to 10 degrees of rail | leeward rail down 2 degrees (`fin_load_bank_deg` 2.0, a placeholder with the right sign) |
| The rail, downwind | Max: flat | the same 2 degrees, faded by the point of sail from `fin_load_twa_fade_deg` |
| The nose | 10 to 25 cm clear | about 0 to 5 cm (pitch −0.3 degrees plus the rocker) |
| Wet part | the last 0.6 to 1.0 m | 1.2 to 1.3 m |
| Arms | front straight, back bent (sheeting with the back hand) | one hand force at `hand_grip_m` |
| Legs | front straight (pulling in its strap), back bent (pressing the tail) | two springs under one point |

## 3. The rider's controls against the model

| What a rider does | What it does to the board | In the model today | Missing |
|---|---|---|---|
| **Pulls up on the front strap, presses the back foot** | a nose-up couple of 60 to 100 N·m held, about 170 briefly (U1 estimate), without moving any weight; the main way the nose comes up at speed | the feet only push along the legs; the pitch part of the feet's moment is not even capped (`windsurfer_sim.gd:1328` caps roll only); the trim press moves weight | the couple as a control, bounded |
| **Pushes the back foot sideways against the fin** | the tail goes a little to leeward, the fin's angle of attack rises, its lift and its upward part grow; too far and it spins out | the fin's slip is whatever the board's drift gives; the helm steers by rake first; the feet's yaw lever (`rail_yaw_nm`) is an estimate and off in the pilot | the back foot's sideways push as the rider's fin control (with PH6, the real spin-out, as its failure) |
| **Rails the board with toes and heels** | on a wide board crosswind and upwind the windward rail comes up and the leeward rail goes down, the wider the board the more; flat downwind (Max) | `rail_press`, `fin_load_bank_deg`: built, 2 degrees to leeward by default, the right sign but a placeholder amount. GP0's sim map said the opposite rail was faster at 12 kt and flat at 18 kt, so the sim disagrees with Max: a hull question (PH27, the heeled hull's lift), not a technique one | the amount and the fade by point of sail from Max; the rail as a control the pilot uses; the hull made to agree with the water |
| **Hangs low on a short line, hips behind the back foot** | the weight far back and out on one body's reach; the sail's pull carried by the hips, the arms steering only | the hike reaches 1.11 m plus the hang-back on a 1 m line; the harness carries 800 to 857 N against 368 to 415 measured | one body's reach, the hook 0.4 to 0.5 m from the boom, the hips' height from the photos |
| **Leans the rig to windward** | more of the sail's force points up; the hull carries less; the centre of effort moves to windward | the lean is a fixed share of the hike; `rig_tilt` exists as a control but the pilot uses it only for steering | the lean as the rider's own lever, apart from steering |
| **Rakes the rig** | steers, and moves the sail's force fore and aft | the pilot's main steering, to a 25 degree stop | a sourced stop (the photos say 15 to 25, the tunnel 18); steering shared with the feet |
| **Sheets with the back hand** | the drive and the pull | the sheet, the pilot's | fine |
| **Bends the knees in chop** | absorbs the hull's jolts, damps the bounce | the legs as a spring and damper (1.2 Hz, 0.9) | fine; the main pitch damper, and the chatter the rider feels should be the board's, not the sea's (review_sim 3.1) |
| **Steps back when planing** | the weight onto the tail, into the straps | the stance and the straps | fine |

## 4. The plan: six packages

Each package is small, measured before and after with `tools/reach_check.sh`, the push check in gusts and waves, and the validation suite, and checked against a photo. Nothing is fitted: where a number has no source it is labelled an estimate and Max's answer replaces it.

### P1. The feet (Michiel, with the balance of `flying_the_board.md` section 5)

1. **The front foot's pull.** A nose-up couple at the feet: the front foot pulling up in its strap against the back foot pressing, bounded by the U1 estimate (60 to 100 N·m held, 170 briefly) until Max gives his own (section 6). Driven by the trim the rider aims for, so the rider uses it only when the nose is below where they want it. Cap the pitch part of the feet's moment at the same place the roll is capped. Source: the photos (front leg straight in every powered one), U1's hip-flexor estimate. Risk: a new controller unless the cap is its only number. Test: a unit test that the couple is bounded and lifts the nose at a held speed; `test_planing_wet_area.gd` targets 3 and 4 with the rewritten numbers (0.6 to 1.0 m, 1.0 to 2.5 degrees).
2. **The back foot's sideways push** (the fin control, P4.1): the rider yaws the tail to leeward by a bounded moment through the feet, so the fin's angle of attack is the rider's, not only the drift's. Source: slalom technique (Max); the helm's third lever already in `helm.gd`. Risk: the spin-out, which is what it should give when pushed too far (PH6). Test: the fin's slip follows the push within its bound; over the bound the fin stalls and the board spins out from the physics.
3. **The rail's amount, and the hull that answers it.** Max: a 72 cm board sails flat downwind, and crosswind and upwind with the windward rail up; the wider the board, the more. The model's sign is right; its 2 degrees is a placeholder, and its fade by point of sail (`fin_load_twa_fade_deg`) should give flat downwind. The sim's own map (GP0, PH27) found the other rail faster at 12 kt and flat fastest at 18 kt, so the hull model does not yet reward what a real board rewards: the heeled hull's lift at short wet parts (P5, `flying_the_board.md` section 4.4). Test: with Max's degrees the reach check is not slower than flat crosswind and upwind.

### P2. The body (Michiel)

1. **One body.** Cap the hike plus the hang-back at one body's reach (0.57 of the height, Gourlay & Martellotta), the hips 0.2 to 0.4 m behind the back foot and 0.6 to 0.9 m outboard (the photos). Test: the centre of mass's distance from the feet never exceeds one body.
2. **The short line.** The hook 0.4 to 0.5 m from the boom (IMG_4743; U1's 0.30 to 0.40 m rule). The hooked-in option (`harness_line_m`) is built and off because the rig leaned out and the board spun out while the rake alone held the course; with P6.1 (the feet steer first) it can come on. Test: `test_hooked_in_rig_lean.gd`; the harness tension inside Walls & Gale's 368 to 415 N scaled to 80 kg as a validation band.
3. **The hips' height and the body's angle** from the photos: 0.45 m and 35 degrees typical, lower when more powered (5c5: 0.3 m and 25 degrees). The 30 degrees of Gourlay & Martellotta is inside that range, so `lean_max_m` 1.11 stays until P2.1 caps the reach; `lean_height_drop_m` moves to what 0.45 m gives. Test: the posture's numbers against the table in section 2.

### P3. The rig as the rider's lever (an AI session, after P1 and P2)

1. **The lean to windward as the rider's own input**, apart from the hike and the steering: `SimControls.rig_tilt` exists (plus or minus 30 degrees); the pilot sets it from the power (more powered, more lean, as the photos show from 15 to 35 degrees) and the push dial raises it. No physics change. Test: the sail's upward share follows the lean on both tacks (`test_sail.gd` mirror symmetry with the twist and the square boom on, which the sail reviewer found untested).
2. **The rake's stop** to a sourced value: the photos say 15 to 25 degrees, the tunnel's rig-back was 18. Estimate: about 60 N·m less nose-down at full rake on the 24 kt broad reach. Test: the reach check's rake and heading with P6.1.
3. **The centre of effort's height by angle of attack** (the tunnel's Fig. 8d), from the sail review. Measured. Test: the height at 5 degrees is 0.85 of that at 12.

### P4. The fin as a precise control (Michiel)

The fin is where the rider's small inputs meet: the sideways push of the back foot (its angle), the rail (where its force points), the weight on the tail (what the hull leaves to it), the sheet (what it must answer). Today none of them is the rider's on purpose.

1. **The angle of attack as the rider's** through P1.2, bounded, with the drift underneath it.
2. **Where its force points** through P1.3: with the windward rail down the fin's lift points partly up and lifts the tail out; the bending tip adds to it under load (built: `fin_model.gd` `_bend`). Then the balance of `flying_the_board.md` section 3 decides whether that lifts the nose: only with the rider's weight behind the fin (P2.1), which the photos show (hips behind the back foot).
3. **The spin-out** (PH6): ventilation, the sudden loss after warning signs. Pushing the fin is only a precise control if too much has a real cost. Source: spec section 4 open question T10; needs a source for the ventilation onset.
4. **The fin itself:** Max's 39 cm slalom fin's area and stiffness. The model's flex is a 37 cm freeride fin's (Nascimento 2017), soft for slalom. Max's fin's maker and model would give its span, area and, if published, its flex (section 6).
5. **The fin's place:** at Max's fin box (0.18 m from the tail, the sweep an estimate) with the mast foot 2 cm from a bounce, built in Session 60 against "for Michiel" (review_hull.md finding 2). Michiel's call, with P5 first.

### P5. The hull that must allow it (Michiel; `flying_the_board.md` section 4)

The clip on the rocker (A-05) parks the board long and nose-down and is the spring the 1.8 Hz bounce runs on. Replace it by consistent strip theory with a bounded suction, pin the push's position to Savitsky's, fix the transom relief and the heeled lift at short wet parts, keep the porpoising limit reported only. Without this, P1 to P4 press against a hull that will not ride short.

### P6. The autopilot and the dial (an AI session, after P1 to P5)

1. **Steer with the feet and the rail before the rake** (`lean_share` above 0 on reaches, the feet's yaw lever), so the rig stands where the hike and the power put it and the rake does not sit at its stop. Test: the 24 kt broad reach holds its course with the rake below 0.8 and no spin-out.
2. **The pilot rides the fin:** the back foot's push and the rail set from the power, within their bounds, eased when the fin's slip nears the stall (the fin's warning, which the push feature needs).
3. **Trimming by feel fixed first** (review_sim 3.1: the 3 s sawtooth; the chatter saturated by the waves).
4. **The dial onto the technique:** the trim aimed for by speed (Gourlay's curve), the front foot's couple (P1.1), the rig's lean (P3.1), the fin's push and the rail (P4), the bounce tolerance and `hike_share`, through the player's own `SailorConfig` copy as package B does. Over-push fails from physics that exist: the bounce, the spin-out (PH6), the catapult. Tests: `test_trim_by_feel.gd` extended, `test_push_warning.gd`, the reach check's pitch SD below 0.3 degrees at the eased setting, GP0's sweep rerun at the top of the dial.
5. **Package B, the mouse,** then maps sideways to the rail and the fin's push, forward and back to the front foot's couple and the trim aim: the same fields.

## 5. The order

1. Michiel: the three reviews, A-05 and the rig's lag decided; P5 built, with the bounce check first.
2. Michiel: P1 and P2 together (the couple and one body change the balance the same way), measured against the photos' table and the rewritten targets.
3. Michiel: P4.3 (the spin-out) and P4.4 (Max's fin).
4. An AI session: P3, then P6, then Max plays it.
5. Max's answers (section 6) at any time; each replaces an estimate.

## 6. For Max

1. **The front foot:** when you fly the board, how hard do you pull up on the front strap? A share of your weight is enough (half? all?). The estimate is 150 to 250 N.
2. **The back foot against the fin:** how much do you push sideways, and what do you feel just before a spin-out?
3. **The rail at speed:** you said the windward rail up crosswind and upwind, flat downwind, more on a wider board. How many degrees on the 72, and from which wind angle does it go flat?
4. **Your fin:** maker, model, span and area, and whether its flex is published.
5. **Your lines and hook:** the line length and how far the hook hangs from the boom when powered (IMG_4743 reads about 0.45 m).
6. **One photo from behind** at full speed would give the rig's lean and the rail exactly; one from the side on flat water would give the wet length and the nose's height, the measurement nobody has.

## 7. The photos in git

Nine of the thirteen are untracked. Your own (FTHZ9294, IMG_7594, and the earlier six) are yours to commit. Five carry a photographer's mark and should stay out of git like 121.JPG already does: the four GSYPHOTO.COM proofs (0af, 1b2, 1c1, 5c5, 8d5: five files) and 121.JPG (olivermaier.com). They are fine to read from, which is all this plan does.

## Sources

- The thirteen photos (estimates by eye, this report, section 2).
- `flying_the_board.md`: the balance, the hull and the sources behind them (Gourlay & Martellotta 2011, Savitsky 1964, Zhang et al. 2025, Walls & Gale 2001, Sutherland 1993, the shapers).
- `review_sail.md`, `review_hull.md`, `review_sim.md` (30 October 2026) and their follow-ups.
- U1's sources report (`reports/u1/sources.md`): the front foot's pull, the hook, the line.
- GP0's report: the rail map (PH27), the push dial's settings.
- `PHYSICS_SPEC.md` sections 4 (the fin, T10), 5 (F22, A-05), 7.5 (the sailor), 14 (U1 and U2).
