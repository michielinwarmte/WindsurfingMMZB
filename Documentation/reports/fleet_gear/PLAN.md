# The fleet's training and the gear: the plan (Session 64, 31 October 2026)

Michiel's brief (31 October 2026): (1) improve the AI's setup and train it anew to get round the different courses in different conditions; first train it to be as fast as possible round all the courses in every wind and sea, then make a selection of about 20 characters of different skill and speed; the whole PC may be used (16 cores, an RTX 3080 Ti, 31 GB). (2) Meanwhile, in-depth online research of the brands in the sport and their gear, slalom first, free race too; then boards and sails shaped and coloured after the brands' designs, shapes and sizes. (3) Then a gear selection page in the game. No real manufacturers' names (copyright): the game's brands are Michiel's, with logos inspired by the names:

| Real brand | The game's brand | Makes |
|---|---|---|
| Duotone | Tripletone | sails and boards |
| Severne | Savanna | sails and boards |
| Point-7 | Point.9 | sails |
| Starboard | Moonboard | boards |
| NeilPryde | NielsTrots | sails |
| JP Australia | PJ New Sealand | boards |
| FMX Boards | BMX Boards | boards |
| North Sails | SouthSails | sails |
| S2Maui | s3kauai | sails |
| Tabou | Forbidden | boards |
| GA Sails | GG Sails | sails |

Opus agents do the building (Michiel: "use Opus agents to limit Fable use"); the lead (Fable) plans, briefs, reads the diffs, merges and measures. At most three agents at a time, each in its own worktree on its own branch, from this plan's branch `gear/lead` (made from `gp4/time-trial`, the top of Session 63's chain, so the training sees the gust patches of PH7 and nothing has to be merged twice). Nothing goes to `main` without the team.

## The parts

| Part | Branch, worktree | Agent | What it delivers | After |
|---|---|---|---|---|
| 1. The training | `race/train-all`, `../WindsurfingMMZB-train` | trainer | The Python stack on this machine; the trainer verified here; every stage drawing the full range of winds, seas, gusts (the patches) and both waters; the brain's own push (RA12 learned); the all-rounder's yardstick; the unattended run of S1 to S6 launched; the report `training.md` | now |
| 2. The brands | `gear/research`, `../WindsurfingMMZB-research` | researcher | `brand_research.md`: every brand's slalom and free race boards and sails, with sizes, shapes, liveries and sources, and the game's gear set with the numbers `BoardConfig` and `SailConfig` need | now |
| 3. The logos | `gear/logos`, `../WindsurfingMMZB-logos` | designer | The eleven brands' logos (SVG and PNG), their palettes, a `Brand` resource per brand, a contact sheet | now |
| 4. The gear models | `gear/models` | shaper | Boards and sails of the researched sizes, shaped and coloured after the brands, built by the Blender builder; a contact sheet per brand | 2 and 3 |
| 5. The gear page | `gear/page` | builder | The catalogue (board, sail, fin per brand and size, each with its sim config and its models), the page in the start menu, the choice kept in the settings, the chosen gear sailed and shown | 4 (its data model with 4) |
| 6. The characters | `race/characters` | trainer 2 | About 20 personas on the trained head, from rookie to pro, with their speed and their push; the persona matrix | 1's brain |

## Decisions by the lead (to be confirmed by the team)

1. **The base is `gp4/time-trial`.** The four branches of Session 63 are not merged yet; this work sits on top of them so it is merged after them, in order.
2. **The training uses 12 of the 16 cores** while the other agents run tests and Blender; the rest when they are done. The GPU is used by the trainer's updates when a CUDA torch installs on Python 3.14; the physics (Godot, on the CPU) is the real cost either way.
3. **The brain gets a fourth output, the push** (RA12's "learned brains' input"): "as fast as possible in every condition" is a question of how hard to push where, and the falls already cost the brain 50 m each. Brains without it sail the pilot's margin as before.
4. **PH14 stays Michiel's:** the sail sizes do not sail right yet (a 7.8 is slower off the line than a 6.5 in 12 kt). The gear page sets the sizes anyway and the report measures them, so the team sees what PH14 must fix before the gear changes the speed honestly.
5. **No physics change by any agent** (`Game/sim/` untouched); the fleet's gust clocks (RA13) are fixed outside `Game/sim/` if the trainer finds it cheap.

## The stops

- After part 1's short try: the lead reads the diff (the push output, the stages' conditions) before the long run is launched.
- After parts 2 and 3: the team looks at the logos and the gear set before the models are built.
- After part 5: the team plays the gear page.
- After the nights: the team races the brain, then part 6.
