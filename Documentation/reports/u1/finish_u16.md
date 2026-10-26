# U1 agent 5, `finish`: U1.6 report

**Done on `u1/finish`** (spec 10 "U1.6", 14, 16):
- **Why the rig stands up.** The pilot and the beginner's heading hold steer through `Helm.steer`, which tilts the rig to leeward as far as it rakes it back. A beam reach needs a steady heading-up helm of 0.57 (the sail's centre of effort sits 0.37 m ahead of the fin), so the hiked rig leans only 8°.
- **Rake-first hold** (`Autopilot.trim_with_rake_first`): built and tested, **off by default**. With it, the rig leans 23°, the harness line shortens from 1.44 to 1.05 m, and the sail's lift carries 27 % of the weight (real: 7 to 24 %). It stays off because the rake then hits its 25° stop on every beam reach, and the grip moving aft worsens U1.3's bow-down problem (lower trims, the 18 kt broad reach rocks). Switch it on with U1.3's fix. Agent 4's "rig at 25°" run was actually sailing at 130°.
- **Fin loading:** `fin_load_bank_deg` 4.5°, **an estimate** (the middle of the 3 to 6° placeholder; Max, please give yours). The sailor aims for that heel and banks only what the board isn't already giving, so the beam reaches (already at 4.5 to 4.9°) are unchanged. A unit test confirms the sail's lift reaches the sailor and the board.
- **Railing out** (information only): the board holds the aimed heel up to 21° and loses control at 24°.

**For U1.2, the 18 kt beam reach now:** harness 954 N, the hands lift 91 % of the weight, the line is 1.44 m. With rake-first on: 854 N, 93 %, 1.05 m. A real 0.3 to 0.4 m line needs the hips higher.

**Checks:** unit 341 of 341; validation fails only on the onset (now 12.7 kn). No manoeuvres run.

| Reach check | 12/60 | 12/100 | 12/135 | 18/60 | 18/100 | 18/135 | 24/60 | 24/100 | 24/135 |
|---|---|---|---|---|---|---|---|---|---|
| Speed m/s, Latest → now | 7.80 → 7.73 | 10.28 → 10.29 | 5.73 → 5.69 | 9.00 → 8.76 | 12.28 → 12.26 | 11.23 → 11.88 | 9.37 → 9.16 | 13.79 → 13.74 | 15.58 → 15.46 |
| Pitch SD ° now | 0.00 | 0.01 | 0.01 | 0.00 | 0.01 | 0.01 | 0.01 | 0.01 | 0.07 |
| Trim ° now | 3.05 | 1.82 | 5.09 | 2.95 | 1.35 | 1.49 | 3.01 | 1.32 | 1.21 |
