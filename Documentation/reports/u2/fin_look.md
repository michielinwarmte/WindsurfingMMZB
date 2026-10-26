# U2 agent 4, `fin_look`: report

**Done** on `u2/fin_look`.

1. **The bend.** `fin_bend.gdshader` moves each fin vertex along the board's x by `FinModel.bend_tip_m` times the beam's own shape: a 21-value table from `beam_deflections`, with its slope to turn the normals. No power law fits (s^1.9 near the root, s^1.6 near the tip). The tip goes to the side of the fin's force: windward on either tack. `rig_visuals.gd` sets it as `material_override`, copies the imported colour, roughness, metallic and specular, and stretches the model to the configured span. Nothing new in the sim.
   **Departure:** `windsurfer.gd` isn't mine, so the rig reads its parent's `sim` in `_process`. A one-line `_rig.bend_fin(sim.fin, sim.body.basis)` there would be cleaner.
2. **HUD:** `load 33 % of stall  bend 19.4 deg  up 223 N` (`game_hud.png`).
3. **Screenshots** (`.screenshots/u2/`, single moments). From the stern camera the water hides the fin. Under water from astern (a temporary `figure_view.gd` patch, reverted), the fin curves to windward, most at the tip, so its force tilts up. **No 44 cm shots:** figure_view takes no `--fin.` overrides, and a temporary `fin_default.tres` edit was refused. A unit test checks the 44 cm stretch.

**Checks:** unit 360/360 (4 new); check 196 files, 0 failed. Not verified: the 44 cm look, the feel.

| Shot | Speed kt | Lift N | Stall % | Bend ° | Tip mm | Up N | Heel ° |
|---|---|---|---|---|---|---|---|
| fin38_12kt_t030 | 17.3 | 396 | 32 | 10.4 | 43 | 57 | -2.5 |
| fin38_18kt_t030 | 25.0 | 613 | 26 | 16.1 | 67 | 159 | -6.3 |
| fin38_24kt_t027 | 28.4 | 870 | 26 | 22.9 | 96 | 229 | -2.6 |
| fin38_24kt_t030 | fallen | 0 | – | 0 | 0 | 0 | -0.4 |

## Play-test checklist (Max)

- The fin is under water: try the orbit camera low behind the tail. Want a fin camera?
- F1 fin line, powered: 15 to 23° of bend, a quarter of stall, 150 to 230 N up.
- Powered up: do you feel the fin's push and a looser board?
- Heel: 2° is wanted, these moments show up to 6.9°. Right?
- Overdone at 24 kt: spin-out (`STALLED`)? The autopilot fell there.
- No 44 cm option in the game yet.
- Anything that feels wrong.
