# E08 · The sailor figure

Owner: Max for the look, the lead and an agent for the build, Michiel where the figure reads new physics | Roadmap: GR3, PR4 (a rigged sailor) | Questions: Q34

**Goal.** A realistic sailor (Max, 6 November 2026: "more realistic graphics and joints, with wetsuit, impact vest and lycra for the competition"): a rigged, skinned character with joints that deform like a body's, driven by the simulation's body (the stance, the feet, the hands, the harness), dressed in a wetsuit, an impact vest and the competition lycra over it, with animations for what the physics does not pose (the tack's and gybe's foot change, the water start, the beach start, pumping, walking and carrying on the beach), customisable for the player and varied across the fifty AI characters.

**Done when (1.0).** The figure is a skinned model with clothing, a harness with lines, a face and hair; every manoeuvre has its animation blended with the physics pose; the player chooses sex, size, weight (the weight is a physics number), skin, hair, wetsuit or lycra with the sponsor's logos; the AI characters look different from each other; the glitches list is empty on Max's screen; a 32-board fleet of figures stays within the frame budget.

**Where things stand (6 November 2026).** The figure is procedural: capsules for the limbs, tapered tubes for the torso, balls at the joints, a belt, a cap and glasses, posed every tick by a two-bone inverse kinematics from the sim's centre of mass, feet and hand grips (Winter's proportions), with springs for the hips and the neck; the feet plant and step into the windward straps while planing; the hands hold, slide and regrip; the rig is drawn through a spring. The 6 November polish fixed the body shake, the hand jumps and arm snaps, the one-tick sail flips, the feet sliding and the mid-board stance. Still open: the elbows on plain reaches, the knees with the back foot pressed and in the 24 kt gybe, the catapult's splash, the mast hand folded at the shoulder in a tack, the hips pulled a metre after a gybe flip, no real foot change in the gybe; none of it seen moving on Max's screen; no model file, no Blender source, no animation.

## Stories

### E08.S01 · The polished figure seen on Max's screen, and the glitches left
Status: review | Size: S | Owner: Max | Milestone: M1 | Needs: the night3 build | Roadmap: GR3
Done when: Max has watched the figure sail, tack, gybe and fall on his screen (the 6 November polish) and listed what still jumps; the list is in this story's tasks.
- [ ] T1 Max's look: the body, the arms and hands, the tacks and gybes, the feet and legs, the stance downwind pushed and railed
- [ ] T2 The open glitches of `Documentation/reports/sailor/sailor_polish_6nov.md` fixed in the procedural figure or deferred to the rigged one (E08.S02)
- [ ] T3 GR3: the push and the body shown (hanging out and low when pushing, the ankles rolling the rail, the weight on the back foot), checked with the contact sheets of `res://dev/figure_view.tscn`

### E08.S02 · A rigged, skinned sailor model
Status: todo | Size: L | Owner: Max (Blender) with an agent | Milestone: M4 | Needs: Q34 | Roadmap: PR4
Done when: a Blender character (a mesh with real joints: shoulders, elbows, hips, knees and ankles that bend without pinching; a skeleton with the game's joint names; the wetsuit, the impact vest and the competition lycra with the number and the sponsors over it; the harness with its lines; face, hair, cap and glasses) is exported to the game, posed by the same IK targets the procedural figure uses, and sails bit for bit the same (the pose is the physics'), at a vertex budget that allows 32 on screen.
- [ ] T1 The skeleton's contract (the joint names and the targets the sim gives: hips, feet, hands, head, knees)
- [ ] T2 The model (own build or a licensed base mesh re-rigged; the licence noted); the joints' deformation checked in the hiked, the crouched and the gybe poses
- [ ] T2b The clothing as layers: the wetsuit (long or short by the spot's water temperature), the impact vest, the competition lycra with the sail number and the sponsors, the harness with its lines; the wet look and the water running off
- [ ] T3 The game's skinning on the IK targets; the procedural figure kept as the fallback and the test reference
- [ ] T4 Levels of detail for the fleet; the frame measured with 32 figures

### E08.S03 · Animation on top of the physics pose
Status: todo | Size: L | Owner: the lead, Max for the reference videos | Milestone: M4 | Needs: E08.S02, E07.S05 | Roadmap: —
Done when: the tack's and the gybe's foot and hand changes, the water start, the beach start, pumping, the catapult, the fall off the back and the climb back on are animated clips blended with the physics pose, timed by the simulation's events, and look right against reference videos.
- [ ] T1 The clips list and the triggers from the sim's states; the blending rule (the physics pose wins for the hips and the hands)
- [ ] T2 The tack and the gybe with a real foot change
- [ ] T3 The water start and the climb back on; the beach start (E05.S05)
- [ ] T4 Pumping, the catapult, the fall off the back
- [ ] T5 Reference videos from Max and the contact-sheet tool extended for the clips

### E08.S04 · Customisation: the player and the fifty
Status: todo | Size: M | Owner: the lead, Max for the looks | Milestone: M6 | Needs: E08.S02, E10.S03 | Roadmap: —
Done when (Q34 answered 6 November 2026: yes, third person, customisable): the player picks sex, height, weight (65 to 100 kg, the physics' sailor mass), skin, hair, wetsuit or lycra and the sponsor's logos (E14), and the fifty AI characters each get a look from the same system (their persona sheet names it).
- [ ] T1 The look as a resource; the body's proportions from the height and weight (Winter's proportions scaled)
- [ ] T2 The weight into `SailorConfig` for the player; the polars at three weights (E01.S13)
- [ ] T3 The sponsor logos on the lycra and the sail (E14.S03)
- [ ] T4 The fifty looks assigned (E10.S03)

### E08.S05 · On foot: walk, run, carry, rig up
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E08.S02, E05.S02 | Roadmap: —
Done when: the figure walks and runs on the beach, carries the board under the arm and the rig over the head (or both as Max decides), rigs up at the hut, and stands idle naturally.
- [ ] T1 The locomotion clips and the blend by speed and slope
- [ ] T2 The carry poses with the board and the rig; the speed with gear
- [ ] T3 The rigging-up clip at the hut; idle variations

### E08.S06 · The fleet's figures within budget
Status: todo | Size: S | Owner: the lead | Milestone: M6 | Needs: E08.S02 | Roadmap: RA4
Done when: a 32-board race with rigged figures costs no more than the procedural figures did on the frame, with LODs by distance and the far boards' figures simplified.
- [ ] T1 The frame measured with 32 figures at 1280 by 720 and at Max's 3137 by 1263
- [ ] T2 LODs and the far simplification
