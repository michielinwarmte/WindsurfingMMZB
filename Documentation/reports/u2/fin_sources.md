# U2 agent 1, `fin_sources`: report

**Done.** PHYSICS_SPEC.md section 14 has a new subsection, "U2: the fin's stiffness, its size and its flex", with a placeholder row for Max's fins. Every number is sourced or labelled an estimate; the game is unchanged.

**1. The flex test (the default).** The only measured test of the right size: a 37 cm F-Hot carbon slalom fin, loaded at 80 % of the span. **100 N moves the load point 20 mm** (5.0 N/mm; Nascimento 2017, IST Lisbon). Set `flex_test_load_n = 100`, `flex_test_position = 0.8` and 0.020 m **at the load point**, or 0.030 m if the calibration measures the tip.

Why: the fin's FEA, calibrated on this test, bends the tip 0.106 mm per newton of sailing lift; the brief's beam gives 0.112 mm, within 6 %. No G10 test of 36 to 44 cm was found. A G10 freeride fin is probably 2 to 4 times stiffer, being thicker (estimate).

**2. Dimensions.** Unifiber G10 freeride: 38 cm 365 cm², 44 cm 411 cm², so about 350 cm² at 37 cm. Root chords are unpublished; the game's 0.14 m is plausible. **Catch:** the brief's `c_root = 0.14·sqrt(area/0.0365)` gives the 44 cm fin 9 % too much area and 1.4 times the stiffness. `c_root = area / (0.686·span)` keeps the area right.

**3. Flex and lift.** Makers say a soft tip lifts the board and shrinks the wet area (Gasoil, Select). No source gives a number for the upward force. Spin-out (stall): 8 to 16° in three measurements. The 2024 VPP abstract could not be read.

**4. For Max:** the brand and model of his fins, and a home test: clamp the base, hang 5 to 10 kg at the tip, measure the tip's movement.

**Preview (estimate):** the brief's beam with the default test, no cap.

| Fin, force | Tip bend | Tip angle | Upward push from the bend |
|---|---|---|---|
| 38 cm, 527 N (18 kt beam reach) | 58 mm | 13.9° | 70 N |
| 38 cm, 800 N | 88 mm | 21° | 161 N |
| 44 cm, area-true law, 527 N | 100 mm | 21° | 105 N |
| 44 cm, area-true law, 800 N | 152 mm | 32° | 238 N |
