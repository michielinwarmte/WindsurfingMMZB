# PH6 (a real spin-out) and PH15 (the wind shadow): research (5 November 2026)

For Michiel and Max, for the session of 6 November 2026. Written by Claude Opus 5.5 on Max's PC (branch `docs/photos-and-roadmap-5nov`). No code was changed. The number labels are the same as in `reports/waves/wave_system_research.md`: **sourced** (opened, linked at the end), **computed** (arithmetic on sourced numbers or the game's config), and **estimate** or **unsourced**.

## PH6. Fin ventilation: a spin-out that comes suddenly

### Where it plugs in

`FinModel.compute()` (`sim/fin_model.gd`) works out the following each substep:
- the immersed share of the span, from the root's depth below the local surface (`surface.depth_at`);
- the slip angle in the fin's plane, and from it `cl` and `cd` on the stall curve (linear to 8°, peak at 12°, a drop to 70 % by 16°, deep stall at 25°; `fin_default.tres`).

The model keeps no state between ticks. Ventilation needs one number of state, the **ventilated share v**, between 0 and 1. It belongs in the hashed state and is cleared by `reset()`.

### What the sources say

| Question | Number | Conditions | Source |
|---|---|---|---|
| Ventilation inception angle | spontaneous at 15–18° (circular-arc strut), 22–26° (NACA 4412); none below 13° / 19° at 9.1 m/s | surface-piercing struts, chord 2.5–3 in, immersed AR 0.5–2 | Breslin & Skalak 1959 (NASA) |
| | fully wetted below 15°; inception rises from about 15° at Fr 0.5 to over 25° at Fr 1.25, and stays above 20° up to Fr 2.5 | Fr = U/√(g·h), h = immersion; AR 1–1.5 | Ferreira et al. 2026 (JFM) |
| | boundary about 15° at ARh 1, Fnh 1.5; 14.5° is "close to the natural (stall-induced) ventilation boundary" at Fnh ≈ 3.45; slightly lower at higher ARh and Fnh | the Michigan foil, c = 27.9 cm | Young et al. 2023, Part 1 |
| | spontaneous only "at or beyond the stall point" | AR 1.96 | Kiceniuk 1954 (Caltech) |
| Triggers | needs low pressure and separation, plus an air path; a disturbance (a sand strip) lowered inception from 22° to 19°; rough water lowered the ventilation speed | | Wadlin 1958, Breslin, Wetzel 1957, Barden & Binns 2012 |
| On a sailboard | air is drawn "from the surface of the water spanwise down across the fin" past the board's edge; the fin root sits about 4 in from the tail | | patent US5683280 |
| Lift lost | ventilation halves the side force to drag ratio | NACA strut, AR 2, 25° | Breslin |
| | "a 70 % drop in CM but only a 40 % drop in CL" (partly cavitating to fully ventilated) | α 5°, Fnh 3.0 | Young et al. 2023, Part 2 |
| | the drop is "more severe for cases with higher Fnh" | | Young et al. 2023, Part 1 |
| | ventilated flat plate: Cn = 2π sin α / (4 + π sin α) | 2D theory, zero cavitation number | Johnson (ONR) |
| Hysteresis | cavities "fair into an asymptotic line given by CsFh² = 5"; below it "it cannot be sustained" (Cs: the unventilated side-force coefficient, Fh: the submergence Froude number) | | Breslin |
| | washout boundary restated as Cl about 5·Fnh⁻² for Fnh > 3 (the inequality signs are lost in the PDF) | kite-foil mast | Bartesaghi et al. 2021 |
| | ventilation kept "down to yaw angles of −2°" after inception at 22–26° | | Breslin |
| | ventilation could be kept "at an attack angle of zero" | | Kiceniuk |
| How fast | nose ventilation "about 0.4 s or 3.5τ", tail ventilation "approximately 0.8 s or 7τ", with τ = t·U/c (chord transits) | | Ferreira et al. |
| | "so rapid that one could see only the initial and final states" at 128 frames/s | | Breslin |

Checked against the text: Breslin's closure line and the 50 % ratio, Young Part 2's 40 %, Ferreira's 15°, 25° and 3.5τ.

### Proposed model (for Michiel to review)

**Inputs.**
- The slip α (deg) and the flow speed U in the fin's plane. Both are already there; the orbital velocity should be taken at depth (waves report, section 3).
- The immersed span h = `immersed_fraction` × 0.38 m.
- The root's depth below the local surface.
- The fully wetted coefficient CL_w(α) from today's curve.
- The mean chord c = area / span = 0.096 m (computed from `fin_default.tres`).

**1. Inception.** The fin starts to ventilate (target 1) when both hold:
- **α > α_inc.** α_inc = `stall_peak_deg` + 3° = 15° by default. The sourced range is 13–26°, and Kiceniuk puts it at or past the stall.
- **There is an air path.** Either the tail is lifting (`immersed_fraction` < 1) or the root is less than `vent_path_depth_m` below the surface. In chop or with the tail loose, α_inc drops by `vent_rough_drop_deg` = 3°, from Breslin's 22 to 19° with a disturbance. The path depth is **unsourced**; nothing was found on how deep a root must be sealed. It is a play-test number.

**2. Washout.** It re-wets (target 0) when the lift the wetted fin would have falls below Breslin's line: CL_w(α) · Fn_h² < 5, with Fn_h = U / √(g·h). For this fin (lift slope 5.0 per rad, computed from the config) that means:

| Speed (m/s) | 5 | 7.5 | 10 | 12.5 | 15 |
|---|---|---|---|---|---|
| Fn_h | 2.6 | 3.9 | 5.2 | 6.5 | 7.8 |
| Re-wets below | 8.5° | 3.8° | 2.1° | 1.4° | 0.9° |
| Inception spreads in (3.5–7 c/U) | 67–134 ms | 45–90 ms | 34–67 ms | 27–54 ms | 22–45 ms |

So a fin that lets go at planing speed comes back only when the sailor nearly unloads it: bearing away, easing the sheet, or slowing down. That is the learnable "spin-out and recover" of real sailing. **Caveat:** Breslin's area basis for Cs could not be read in the scan, and our Fn_h (2.6 to 7.8) is beyond the 1.5 to 3.45 that Young and Ferreira tested.

**3. Spreading.** v moves toward its target with the time constant τ = k · c / U:
- k_inc = 5 for inception (sourced range 3.5 to 7);
- k_wash = 7 for washout (**unsourced**: no washout time was found; "the upstream flow of the re-entrant jet" is the mechanism in Harwood 2016).

**4. Forces.** CL = (1 − v)·CL_w + v·r·CL_w, with r = 0.4 by default. The sourced range for r:
- 0.2 to 0.33: the ventilated flat plate against this fin's wetted CL at 12° (0.28 against 0.85, computed);
- 0.6: Young's 40 % drop.

Take the low end at the fin's high Fn_h. Keep CD as it is in a first version: the sources disagree on its sign ("can be either greater or smaller", Young Part 1).

**Telemetry.** `ventilated_share`, plus the margins α_inc − α and α − α_wash. A dev overlay can then show the warning that a player learns to read.

### Tests that would prove it

1. **Nothing changes below α_inc.** On flat water the validation suite and `matrix.sh` give identical state hashes when α never passes α_inc.
2. **Inception.** At α = α_inc + 1° and 10 m/s, v passes 0.95 within 3τ (3 × 48 ms), and the lift falls to 1 − 0.95·(1 − r) of the wetted lift.
3. **Hysteresis.** Ramp α up past α_inc and back down. The fin ventilates on the way up and re-wets only below the table's angle on the way down. The same downward ramp started wetted never ventilates.
4. **Speed dependence.** Washout at 8.5° at 5 m/s and 2.1° at 10 m/s, within 0.2°.
5. **No path, no ventilation.** A root sealed deeper than the path depth does not ventilate before deep stall.
6. **A spin-out scenario.** A 24 kt beam reach, sheeted hard, the weight back. Measure the time from crossing α_inc to the lift collapsing (under 0.15 s), the slip and yaw that follow, and the recovery after bearing away. Compare with today's soft post-stall.
7. **Max's play-test.** Is it sudden, and can the signs be learned?

## PH15. The wind shadow: what is known, and a simulation instead of a guess

### Today

`WindShadows` (`race/wind_shadows.gd`, spec 8.11) puts a cone behind every sail:
- along the **true** wind at the query point;
- 2.5 m half-width, widening at 8°;
- a 30 % deficit up to 5 m, fading out at 30 m;
- the shadows of several sails adding to at most 50 %;
- the **speed only**: `WindDisturbance.factor_at()` returns a scalar.

The numbers are "from the sailing books".

### What the sources say

- **The axis is the apparent wind.** Richards et al. (2012, wind tunnel, models with a 2.25 m mast):
  - "The blanketing zone should therefore be aligned with the apparent wind rather than the true wind", because the boat moves on while its wake drifts downwind.
  - Measured, the band lies "approximately along the apparent wind direction", turned further aft by the sail's lift, by "near 5" degrees close-hauled and "around 9" degrees downwind.
- **The wind is turned, not only slowed.**
  - Richards: about 3 mast heights behind, the downstream yacht gets "a weaker flow" that is "effectively 4" degrees "further away from the true wind direction", from the masthead vortex. Downwind the direction "is adversely changed by over 30" degrees in places, with "turbulence intensities over 40%".
  - Gentry (1973, potential flow, 10 kt apparent): behind and to windward "8.8 knots" and "a header of 4.7°". In the safe leeward spot "11.0 knots and a flow angle of +5.7°".
- **Strength and length.**
  - Hooper's tunnel data (in Richards): drive force "down to 0-10%" along the apparent wind line downstream, back to "nearly 100% one boat length either side", and "a gain of 20%" at the safe leeward.
  - Caponnetto's vortex lattice (in Richards): "a 60% reduction in drive force" at one mast height.
  - Marchaj (in Richards): felt "for up to ten boat lengths".
  - Baird (Sailing World): "8 to 10 boatlengths to leeward" in light air.
- **No windsurfer measurement** was found.

### Sourced models for the parts

- **The speed deficit** has a wind-turbine analogue, valid in the far wake only:
  - Jensen: deficit (1 − √(1 − C_T))·(r₀ / (r₀ + k·x))², k = 0.075, or 0.04 offshore (WAsP).
  - Bastankhah–Porté-Agel: C(x) = 1 − √(1 − C_T / (8(σ/d₀)²)), σ/d₀ = k*·x/d₀ + ε, ε = 0.2√β, β = (1 + √(1 − C_T)) / (2√(1 − C_T)) (PyWake), with k* = 0.38·TI + 0.004 (FLORIS).
  - **Computed** with C_T replaced by a sail drag coefficient of 0.4 (an assumption) and a 7 m² disc (d₀ = 2.99 m):

    | Behind the sail | Jensen, k = 0.075 | Gaussian centre, k* = 0.04 |
    |---|---|---|
    | 5 m | 14 % | 39 % (outside the model's range) |
    | 10 m | 10 % | 23 % |
    | 15 m | 7 % | 16 % |
    | 30 m | 3.6 % | 6.8 % |

    The widening is 2.3 to 5.7° against the game's 8°.
- **The turned wind** is lifting-line downwash. "The downwash velocity in the far wake is twice the downwash at the lifting line" (Cantwell, Stanford), with α_i = CL / (π·AR) for elliptic loading (MIT 16.01).
  - **Computed:** at CL 1 and AR 3 (4.6² / 7) the far wake turns about 12°. With the foot sealed (AR about 6, unverified) it turns about 6°. That is the same order as the 4 to 6° headers measured.

### Proposal: simulate it on this PC

1. **Inviscid first (Python, an afternoon).**
   - AeroSandbox (pip, Python ≥ 3.10) has a vortex-lattice method whose `get_induced_velocity_at_points` "Computes the induced velocity at a set of points in the flowfield".
   - Model the default sail from `sail_default.tres` (8 m², luff 5.22 m, boom 2.2 m), mirrored in the water surface.
   - Use the fleet's apparent-wind angles and the CL the game's sail model reports.
   - Sample the field 1 to 10 mast heights behind it at 1/3 and 2/3 of the mast height, as Richards probed.
   - Output: maps of the header or lift (degrees) and the induced speed change, left and right of the axis. **Check** them against Richards' 4° at 3 h and Gentry's 4.7° header, −12 % and +5.7° safe leeward.
2. **Viscous, if the deficit matters.**
   - OpenFOAM's native Windows build ("the easiest method to obtain the latest OpenFOAM version on Microsoft Windows systems"; no dynamic code) can run a steady RANS of a rigid cambered sail at three apparent-wind angles.
   - The run time on this PC is **unknown** (estimate: hours each).
   - Output: the centre deficit and width against the distance, fitted to the Gaussian form above, which gives C_T,eff, k* and ε for the config.
3. **What changes in the config and the code.**
   - Today's six numbers become:
     - the axis: the caster's apparent wind, plus `deflection_deg` (5° upwind, 9° downwind: sourced);
     - the deficit curve: C_T,eff, k* and ε, from the simulation, else the turbine values;
     - the turn: a header in the wake and a lift to leeward in degrees against the distance, from step 1;
     - the cap.
   - `WindDisturbance` must return a velocity change, not a scalar, for the turn to reach the sail. That is an interface change for Michiel.
   - How several shadows combine was not researched; keep the cap until it is.

## Sources (opened in this session; ✓ = checked against the text)

**PH6**
- Breslin & Skalak 1959, NASA Memo 2-23-59W ✓: https://ntrs.nasa.gov/api/citations/19980228299/downloads/19980228299.pdf
- Ferreira et al. 2026 (JFM 1028 A25), arXiv 2503.18015 ✓: https://arxiv.org/html/2503.18015v1
- Young et al. 2023, JFM 963 A37 (Part 1) ✓: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/9E6C59B1B84C3C97EDA017B7D7C84B9A/S0022112023001271a.pdf
- Young et al. 2023, JFM 965 A3 (Part 2) ✓: https://www.cambridge.org/core/services/aop-cambridge-core/content/view/BAC5D23899E725C316C000035BE20B71/S0022112023002549a.pdf
- Harwood, Young & Ceccio 2016, JFM 800 (abstract): https://www.cambridge.org/core/product/3A3C55533CD1A36BAA53B4AA2102C068
- Wetzel 1957: https://www.onr.navy.mil/media/document/ventilation-bodies-piercing-free-surface
- Wadlin 1958: https://www.onr.navy.mil/media/document/mechanics-ventilation-inception
- Johnson (ONR), supercavitating hydrofoils: https://www.onr.navy.mil/media/document/influence-depth-submersion-aspect-ratio-and-thickness-supercavitating-hydrofoils
- Kiceniuk 1954, Caltech E-55.2: https://authors.library.caltech.edu/records/paew4-zs356/files/E-55.2.pdf
- Bartesaghi et al., MARINE 2021: https://journals.ed.ac.uk/MARINE2021/article/download/6828/9025/22204
- Barden & Binns 2012, AFMC: https://people.eng.unimelb.edu.au/imarusic/proceedings/18/170%20-%20Binns.pdf
- Patents US5683280 and US4850917: https://patents.google.com/patent/US5683280A/en, https://patents.google.com/patent/US4850917A/en

**PH15**
- Richards et al. 2012, AFMC ✓: https://people.eng.unimelb.edu.au/imarusic/proceedings/18/279%20-%20Richards.pdf
- Gentry 1973, Why the Safe Leeward Works ✓: https://www.ftp.tognews.com/Publications/Arvel%20Gentry%20Articles/06_Why_the_Save_Leeward_Works.pdf
- Baird 1995, Sailing World: https://www.sailingworld.com/?p=68754
- WAsP wake model: https://wasp.dtu.dk/software/wasp/wake-effect-model
- PyWake: https://topfarm.pages.windenergy.dtu.dk/PyWake/notebooks/WakeDeficitModels.html, https://topfarm.pages.windenergy.dtu.dk/PyWake/notebooks/literature_verification/Gaussian.html
- β formula: https://arxiv.org/html/2406.00695
- FLORIS `gauss.py`: https://raw.githubusercontent.com/NREL/floris/main/floris/core/wake_velocity/gauss.py
- Cantwell, AA200 ch. 12: https://web.stanford.edu/~cantwell/AA200_Course_Material/AA200_Lectures/AA200_Ch_12_Wings_of_finite_span_Brian_Cantwell.pdf
- MIT 16.01 notes F7: https://ocw.mit.edu/courses/16-01-unified-engineering-i-ii-iii-iv-fall-2005-spring-2006/35607679ab26928b4fdf99324aa17bc2_f07_0304.pdf
- AeroSandbox: https://pypi.org/project/AeroSandbox/ and https://aerosandbox.readthedocs.io/en/master/_modules/aerosandbox/aerodynamics/aero_3D/vortex_lattice_method.html
- OpenFOAM for Windows: https://www.openfoam.com/openfoam-mingw-cross-compilation

**Gaps**
- Harwood's thesis and full 2016 paper, and the 2017 review: paywalled or refused.
- Any windsurf-fin ventilation test, any washout duration, and any number for root sealing.
- Any windsurf-sail wake measurement.
- The Southampton yacht-wake papers (Spenkuch): refused.
- How several wakes combine.
