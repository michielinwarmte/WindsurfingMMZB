# A realistic wave system: research for PH44 (5 November 2026)

For Max and Michiel, for the session of 6 November 2026. Written by Claude Opus 5.5 on Max's PC, on the branch `docs/photos-and-roadmap-5nov` (1de5791). No code was changed.

Max: "we need a really good wave system, this one is really bad. A realistic one with sea bottom simulation and all." Later the same evening: on Lake Silvaplana the waves must be realistic in space (flat at the upwind shore, growing downwind with the fetch, the gusts changing them) and cheap on the CPU. Section 1 answers that second request first, because a builder starts on it tonight.

**How to read the numbers.** Every number is one of three kinds, and the text says which:
- **sourced**: from a page or paper opened in this session, listed in section 9 with its link;
- **measured**: run on this PC (AMD Ryzen 7 5800X3D) or read from the map's own data, with the script named;
- **computed**: arithmetic from sourced formulas, or **estimated** (a judgement), labelled as such.

**In short.**
- **Keep the physics' sea on the CPU**, as one function of place and time that both PCs and the shader compute. A GPU sea is unavailable in the headless tools and not bit-portable between graphics cards.
- **Make the lake's chop realistic first:** a few wave bands whose amplitudes follow the fetch-limited spectrum at each point, with the gusts raising only the short waves (section 1). This costs the same CPU as today.
- **Do the bottom offline** (SWAN on the lake's survey) when a map needs it. On Silvaplana the bottom affects 5.5 % of the lake, mostly where the board is already stopped.
- **The hull's slam on short chop (PH9, PH10) decides how much of the real chop the physics can take.** Plan the sea and the hull together.

---

## 1. Lake Silvaplana: waves that grow with the fetch and answer the gusts (for tonight's builder)

### 1.1 What the lake itself says (measured from the game's depth grid)

From `Game/maps/silvaplana/terrain/shore_heights.bin` (swissBATHY3D lakebed on a 2 m grid), with the scripts `lake_depths.py`, `start_fetch.py` and `fetch_compare.py` (scratchpad, read only):

| | Value |
|---|---|
| Lake area in the grid (Lej da Champfèr is joined to it) | 2.89 km² |
| Shallower than 0.5 / 1 / 2 / 3.5 / 5 / 10 m | 1.2 / 1.9 / 3.4 / 5.5 / 6.8 / 11.4 % of the lake |
| Distance of the 3.5 m depth line from the shore | median 14 m (10–90 %: 6–56 m) |
| Depth at the start spot (LV95 2780880 / 1147510) | 23.5 m |
| Fetch upwind of the start, straight line, wind from 222 / 230 / 236 / 245° | 2000 / 772 / 634 / 448 m |
| Depth along the 222° line through the start, toward the north-east shore | 15 m at 20 m, 2.9 m at 40 m, 1.1 m at 60 m |

Two conclusions for the builder:
1. **The Maloja chop is deep-water chop on 94 % of the lake.** A wave feels the bottom when the depth is less than half its length (sourced: coastalwiki, h/L ≥ 0.5 is deep water). The fetch-law peak waves are 1.2 to 7 m long (table 1.4), so they feel the bottom only where the water is shallower than 0.6 to 3.5 m, which is a band about 6 to 56 m wide along the shore. The board is stopped by the shore check at 0.5 m (`shore_check.gd`: the fin's 0.38 m plus 0.12 m). The bottom can wait for the lake (section 5); the fetch cannot.
2. **The fetch at a point changes a lot with the wind direction.** At the start it drops from 2 km to 450 m when the Maloja veers from 222° to 245° (the afternoon's range in `waves_direction.md`). By the growth law (1.3) that halves the wave height and makes the waves about a third as long, for the same wind (computed: 16 kt gives Hs 0.19 m and 3.9 m waves at 2 km, 0.09 m and 1.5 m at 450 m). So the fetch map must be per direction. One fixed lake-axis fetch is not enough.

### 1.2 Point fetch or effective fetch on a narrow lake

The lake is about 3 km long (the R6 table) and much narrower than it is long. There are two ways to measure the fetch at a point:
- **Straight line**: the distance over water straight upwind.
- **Radial average**: the SPM's cosine-weighted mean of 9 rays 6° apart around the wind (sourced: the `lakefetch` docs describe the SPM 1984 method this way).

The GRASS `r.windfetch` tutorial (sourced) says the broad SPM arc "generally better reflects real-world spreading of wave energy". It adds that a restricted arc "can be more appropriate in environments with long, narrow fetches such as estuaries or channels."

**Not sourced (not opened):** a search snippet attributes to the Coastal Engineering Manual (CEM, 2002) the advice to use the straight-line fetch and not the fetch width, after Resio and Vincent (1979). The CEM pages could not be opened here: the mirror's certificate failed, and the official PDF is behind a browser check. Treat that advice as unverified.

Measured on the lake (`fetch_compare.py`), at points up the 222° line from the start:

| Point (m upwind of the start) | Wind 222°: straight / 9-ray cosine (m) | Wind 240°: straight / 9-ray cosine (m) |
|---|---|---|
| 0 (the start) | 2000 / 1424 | 538 / 849 |
| 300 | 1700 / 1218 | 412 / 674 |
| 600 | 1400 / 989 | 314 / 506 |
| 1000 | 1000 / 780 | 222 / 397 |
| 1500 | 500 / 386 | 328 / 338 |

The cosine average is about 30 % shorter along the lake's axis, and longer where the straight ray hits a near shore. **Recommendation (estimate):** use the 9-ray cosine fetch.
- It is smooth in space: a straight ray jumps where it grazes a headland, and the waves would jump with it.
- Wave height grows as the square root of the fetch, so a 30 % shorter fetch costs only 16 % of the height. That is inside the scatter of the lake measurements in 1.6.

### 1.3 Which growth law for 0.1 to 3 km at 10 to 25 kt

Two laws were opened, and both fit in one line of code:

| Law | Height | Period | Source |
|---|---|---|---|
| SPM 1984 (JONSWAP based), with U10 directly. This is what `wind_waves.gd` does today | g·Hs/U² = 0.0016·(gF/U²)^½ | g·Tp/U = 0.286·(gF/U²)^⅓ | the spec 9.16's references; the code |
| CEM 2002 (Resio et al. 2003), with the friction velocity u*² = 0.001·(1.1 + 0.035·U10)·U10² | g·Hm0/u*² = 0.0413·(gF/u*²)^½, at most 211.5 | g·Tp/u* = 0.651·(gF/u*²)^⅓, at most 239.8 | the `waver` package's reference manual, which cites Resio, Bratos and Thompson (2003), CEM chapter II-2 |

The two agree on the height to within 7 % over the whole table below. **They disagree on the period by 25 %** (16 kt over 3 km: 1.82 s and 5.2 m waves against 1.38 s and 3.0 m). On a 2.4 m board that is the difference between waves two board lengths long and waves just over one. Nothing here settles which is right for this lake. Max's eye can (section 8), and the code makes it a switch.

**Not opened:**
- Kahma and Calkoen (1992) and Young and Verhagen (1996, finite depth): their copies sit on a server that refused this session.
- Karimpour et al. (2017), which uses Young and Verhagen: its equations are images in the text that was opened.
- Donelan (1985) was not looked up. Young and Verhagen matter only where the lake is shallower than half a wavelength, which is the shore band of 1.1.

What lake measurements say (sourced: Casas, Bleninger and Stips 2025, a reanalysis of the Lake Neuchâtel campaign of 1996):
- "field wave heights lie significantly below the JONSWAP prediction for wind speeds of up to 7 m/s" (Simon 1997).
- Guseva et al. (2021) found their data from two small German lakes "greatly overestimated by the JONSWAP formula for the whole range of observed wind speeds".
- In strong, steady wind the Neuchâtel data "better followed the JONSWAP formulation".
- The authors suggest "methods for spatially averaging wind speed along the fetch may be necessary".
- The largest Neuchâtel wave in that campaign was Hs 0.66 m, with wind up to 13.0 m/s measured at 2.8 m and a 9 km fetch.

**Computed, for comparison only:** the SPM law gives 0.63 m for 13 m/s over 9 km. The wind heights differ, so this only shows that the order of magnitude is right.

So the laws are right in a strong Maloja and may overstate the waves in a light one. A per-band scale factor, measured on the water later, covers that.

### 1.4 How the spectrum changes with the fetch, and amplitudes for fixed bands

As the fetch grows:
- **The peak moves to longer waves**, with Tp growing as F^⅓ (the laws above).
- **The waves shorter than the peak saturate.** Their level is set by the spectrum's tail, α·g²·ω⁻⁵. In the three-parameter JONSWAP form (sourced: SINTEF SIMA docs), α = 5.061·Hs²/Tp⁴·(1 − 0.287·ln γ).
- **The tail's level α falls slowly with the fetch.** With the SPM laws it goes as F^(−⅓) (computed).

So a band of fixed wavelength first appears when the peak passes it, grows to a maximum near the peak, and then stays roughly constant or drops a little as the peak moves on. This is why a few fixed bands can take their amplitudes from the local spectrum.

The spectrum (sourced, SIMA, the same as the classic JONSWAP):

```
S(ω) = α g² ω⁻⁵ exp(−1.25 (ωp/ω)⁴) γ^r,   r = exp(−(ω − ωp)² / (2 σ² ωp²)),
σ = 0.07 for ω ≤ ωp, 0.09 above;  γ = 3.3;  ωp = 2π/Tp;  α = 5.061 Hs²/Tp⁴ (1 − 0.287 ln γ)
band amplitude a_i = sqrt(2 ∫ S dω over the band)      (so Σ a_i²/2 = m0 = (Hs/4)²)
```

Tp and Hs come from the SPM law at the local fetch. The bands are an octave wide (L/√2 to L·√2) and the band frequencies use deep-water dispersion. All values are computed with `band_table2.py`; integrating over every frequency gives back the law's Hs to the millimetre, as a check.

**Table 1.4: the SPM and CEM waves, and the RMS amplitude of each band in mm (JONSWAP shape on the SPM Hs and Tp)**

| Wind (kt) | Fetch (m) | SPM Hs (m) | SPM Tp (s) | SPM Lp (m) | CEM Hs (m) | CEM Tp (s) | CEM Lp (m) | α | 0.5 m band | 1 m band | 2 m band | 4 m band | 8 m band |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | 100 | 0.032 | 0.53 | 0.4 | 0.030 | 0.40 | 0.3 | 0.042 | 9 | 2 | 0 | 0 | 0 |
| 12 | 300 | 0.055 | 0.77 | 0.9 | 0.051 | 0.58 | 0.5 | 0.029 | 10 | 15 | 4 | 0 | 0 |
| 12 | 1000 | 0.100 | 1.14 | 2.0 | 0.093 | 0.86 | 1.2 | 0.019 | 9 | 16 | 28 | 9 | 0 |
| 12 | 3000 | 0.173 | 1.65 | 4.3 | 0.162 | 1.24 | 2.4 | 0.013 | 8 | 15 | 27 | 49 | 17 |
| 16 | 100 | 0.042 | 0.58 | 0.5 | 0.040 | 0.44 | 0.3 | 0.050 | 12 | 4 | 0 | 0 | 0 |
| 16 | 300 | 0.073 | 0.84 | 1.1 | 0.070 | 0.64 | 0.6 | 0.035 | 11 | 21 | 8 | 0 | 0 |
| 16 | 1000 | 0.133 | 1.26 | 2.5 | 0.128 | 0.96 | 1.4 | 0.023 | 10 | 19 | 37 | 19 | 1 |
| 16 | 3000 | 0.230 | 1.82 | 5.2 | 0.221 | 1.38 | 3.0 | 0.016 | 9 | 17 | 31 | 62 | 37 |
| 20 | 100 | 0.053 | 0.63 | 0.6 | 0.052 | 0.48 | 0.4 | 0.058 | 15 | 8 | 1 | 0 | 0 |
| 20 | 300 | 0.091 | 0.91 | 1.3 | 0.090 | 0.70 | 0.8 | 0.040 | 12 | 25 | 15 | 1 | 0 |
| 20 | 1000 | 0.166 | 1.36 | 2.9 | 0.164 | 1.04 | 1.7 | 0.027 | 11 | 21 | 40 | 35 | 4 |
| 20 | 3000 | 0.288 | 1.96 | 6.0 | 0.284 | 1.50 | 3.5 | 0.019 | 9 | 18 | 35 | 66 | 66 |
| 25 | 100 | 0.066 | 0.68 | 0.7 | 0.067 | 0.53 | 0.4 | 0.068 | 16 | 14 | 2 | 0 | 0 |
| 25 | 300 | 0.114 | 0.98 | 1.5 | 0.116 | 0.76 | 0.9 | 0.047 | 14 | 26 | 26 | 3 | 0 |
| 25 | 1000 | 0.208 | 1.46 | 3.3 | 0.211 | 1.13 | 2.0 | 0.031 | 12 | 23 | 41 | 54 | 10 |
| 25 | 3000 | 0.360 | 2.11 | 6.9 | 0.366 | 1.63 | 4.2 | 0.022 | 10 | 20 | 38 | 67 | 97 |

How to read it: at 16 kt the 0.5 m band is already 12 mm at 100 m of fetch and never grows after that (saturated). The 4 m band does not exist before about 1 km, then grows to 62 mm at 3 km. The "flat water at the upwind shore" follows from the formula itself: at a fetch of zero, Hs and Tp go to zero and every band's amplitude goes to zero.

### 1.5 How fast the waves answer a gust

There are two different clocks:

**The wind's direct push on a short wave.** The energy growth rate measured by Plant (1982), quoted in Polnikov's review (sourced). The PDF's text layer lost the Greek letters. The form below, with (u*/c)² = (u*·ω/g)² in deep water, is the usual way of writing it and fits the symbols that survive; that reading is an estimate.

```
γ = (0.04 ± 0.02) (u*/c)² ω cos(θ − θ_wind)      energy grows as E(t) = E0 e^(γ t)
```

Computed with the CEM's u* and the phase speed c including surface tension, the energy e-folding time 1/γ in seconds (the amplitude's is twice as long):

| Wind (kt) | u* (m/s) | 5 cm ripples | 10 cm | 0.3 m | 1 m | 2 m | 5 m |
|---|---|---|---|---|---|---|---|
| 12 | 0.22 | 1.2 | 3.2 | 16 | 99 | 280 | 1108 |
| 16 | 0.31 | 0.6 | 1.7 | 8.7 | 53 | 150 | 591 |
| 20 | 0.39 | 0.4 | 1.0 | 5.3 | 32 | 91 | 360 |
| 25 | 0.51 | 0.2 | 0.6 | 3.2 | 19 | 55 | 217 |

**The time the whole fetch needs to fill up.** A fetch-limited sea is reached when the waves have had time to cross the fetch at their group velocity, c/2 in deep water (sourced: coastalwiki). Computed for the peak waves of the SPM law:
- 300 m of fetch: 6.5 to 8.4 minutes;
- 1 km: 15 to 19 minutes;
- 3 km: 30 to 39 minutes (25 kt to 12 kt).

What this means for the game (estimate, from the two tables): a gust that lasts tens of seconds visibly roughens waves shorter than about 0.3 m within seconds (the cat's paws). It barely touches the 1 to 7 m chop. That chop follows the wind averaged over a quarter to half an hour, which on the lake is the Maloja's slow pulses (13 to 45 minutes, spec 8.10), not its gusts.

**Not sourced:** how fast the short waves die after the gust passes. The table gives the growth only. Use the same time constant both ways until someone measures it.

### 1.6 Measurements of waves on Alpine lakes or on Silvaplana

- **Silvaplana: none found.** The searches (English and German) found spot guides with the wind's strength and no wave heights. SRF Meteo (sourced) gives "zwischen 4 und 5 Beaufort mit Böen um 6 Beaufort" on typical Maloja days, with gusts "von knapp 50 Kilometer pro Stunde".
- **The map's own aerial photo.** The SWISSIMAGE 10 cm tile `2780-1147` (2025 flight, already in `.map_data/raw`) was checked at the start spot with `aerial_waves.py`. The water is calm, with no crests, so the flight was not in a Maloja. The map's Sentinel-2 photos are 10 m per pixel, too coarse for 1 to 7 m waves.
- **Swiss lakes:** the Lake Neuchâtel campaign of 1996 (1.3) is the only one whose numbers were opened. Lake Geneva has an Eawag wave buoy at LéXPLORE, with hourly data for 2022 to 2024, but its page refused this session. It is the best place to look next for a lake's measured Hs and period against wind and fetch.

### 1.7 The builder's recipe (estimates where marked; everything else from above)

1. **Fetch map:** per wind direction, every 5° over the Maloja sector (estimate: 202 to 292°, the sector of `MALOJA_WIND_RESEARCH.md`), on a grid of 8 to 16 m (estimate). Cast the 9 cosine-weighted rays 6° apart on `shore_heights.bin`. Bake it like the wind patterns.
2. **Hs and Tp per cell** from the SPM law with the local fetch and the local mean wind (not the gusts). CEM is a switch. Averaging the wind along the upwind ray is the lake paper's own suggestion (1.3).
3. **Bands:** about five fixed wavelengths, e.g. 0.5, 1, 2, 4 and 8 m, with amplitudes from table 1.4's formula. Keep every band's direction and wavelength the same over the whole lake and vary only its amplitude in space. A direction that changes from place to place makes the surface jump (spec 9.12). For a veering wind, cross-fade between two sets of directions.
4. **Physics and picture:**
   - The physics should get only the bands of about 1 m and longer. The hull's buoyancy rows are about 0.4 m apart, so a 0.5 m wave would alias (estimate). The strips already overstate the slam on waves shorter than about 7 m (spec 17.12, PH10).
   - The 0.5 m band and the ripples can be picture-only, in the shader.
5. **Gusts:**
   - Raise the shader-only short bands with the local wind over the last few seconds (table 1.5: 1 to 10 s), not the long ones.
   - Make the amplitude a pure function of place and time, for example from the mean of the deterministic wind field over the last τ seconds at that point, rather than a filter with memory. Then the CPU, the shader and both LAN PCs compute the same sea without sharing state.
6. **Steepness:** each band's Gerstner steepness is k·a, and the sum must stay at or below 1 (spec 9.8). At 25 kt over 3 km all five bands sum to 0.55, and the four physics bands to 0.43 (computed from table 1.4), so there is room.

---

## 2. What exists today

**The sea** (`sim/wave_field.gd`, spec section 9) is a sum of at most four Gerstner waves (`WaveSetConfig.MAX_WAVES = 4`, fixed by the shader's four slots). The surface is computed in two places with the same formulas (plan decision D5):
- `sim/wave_field.gd` for the physics;
- `world/gerstner.gdshaderinc` for the picture.

How a query works:
- A point's height comes from a fixed-point solve for the rest point that moved there (at most 8 passes, 1 mm).
- The normal is exact.
- The velocity is the surface's orbital velocity, with no decay below the surface (spec 9.7).

Every wave moves at its **deep-water** speed, sqrt(g/k), in both the code and the shader.

The default sea (`waves_default.tres`) is mostly swell:
- a 14 m wave of 8 cm;
- chop of 2 cm, 5 mm and 2 mm "for the look".

The reason is that the hull's strip theory slams on short chop (spec 17.12): a single 7 m wave of 6 cm halved the speed.

**The wind's chop** (`sim/wind_waves.gd`, spec 9.16) is a preset, not the default. It works like this:
- The SPM fetch law turns the wind and the fetch into Hs and Tp.
- Two waves are made from them: the peak wave, and one at 1.5 times the peak frequency with 0.33 of its amplitude, turned 30°.
- The depth caps Hs at 0.6·d.
- The depth shortens the wavelength, but the wave field then moves that wave at its deep-water speed. In 2 m of water the 18 m wave goes 5.3 m/s instead of 4.1 (spec 9.16, "Open").

**On the lake:**
- `OceanNode` draws the Gerstner water in the 400 m around the camera, with the chop lined up with `wind_silvaplana.tres`'s 222°. The far water is flat.
- The depth grid is used for the shore stop and for the water's colour, never for the waves.
- The ripples are a normal map (shading only). Their 90° error was fixed in GR8.

**Why it looks bad (estimate, from the code):**
1. Four regular waves are visibly periodic and long-crested, the same everywhere on the water. Since Session 67 the wave spread of 0.25 makes them even more parallel.
2. On the default sea the heights do not follow the wind.
3. Nothing changes in space: no fetch, no lee, no shore.
4. The real chop is held at trace heights because the hull cannot take it yet (PH9, PH10).
5. The crest foam starts at a steepness of 0.3 (spec 17.12), and the default waves are at 0.04 or less, so there is never foam or a whitecap.

**What it costs (measured, `tools/sea_bench.sh`, this PC, the editor engine, headless):**

| Query | Time |
|---|---|
| `height_at` (4 waves) | 5.93 µs |
| one wave sum (`displacement_at`) | 1.72 µs |
| `sample_at` (height, normal, velocity from one solve), cold / warm | 9.26 / 7.23 µs |
| a board's physics per tick on waves / on flat water | 2.523 / 1.502 ms, so **the sea costs 1.02 ms per board per tick** |
| 8 boards with waves on threads, the whole tick | 7.71 ms |

1.02 ms at about 7.2 µs a sample is about 140 samples a tick: 47 per substep at 3 substeps (computed). That matches the code:
- 21 buoyancy points (7 × 3);
- 12 hull strips and 12 rail strips;
- 4 single points;
- the fin's own velocity query and the foot.

Every query loops over the waves, so the sea's cost grows in proportion to the number of waves (the code's structure). Sixteen waves would cost about 4 ms per board per tick (estimate).

## 3. What the board's physics needs from the sea

- **Height, normal and orbital velocity**, at about 47 points within the board's 2.4 m, 180 times a second (section 2).
- **One clock.** Every query takes the simulation's `time_s` (spec 9.10). In a LAN game the guest's board runs on the host's water clock (`Documentation/reports/multiplayer/PLAN.md`, D7). The guest simulates its own board on its own PC, so the two PCs need **the same function**, not the same bits.
- **Headless.** The unit tests (`test.sh`), `simulate.sh`, `matrix.sh`, `race.sh` and the AI training (`train.sh`) all start Godot with `--headless`. "RenderingDevice is not available when running in headless mode" (Godot docs, sourced), so a compute-shader sea cannot serve the physics there. Even in a window, reading a texture back "will block the GPU from working until the data is retrieved", and the asynchronous read arrives `frame_queue_size` frames late, 2 by default (Godot class reference, sourced).
- **CPU determinism, run to run.** The regression tests hash the whole state every tick (`reports/racing/no_wait.md`). A GPU result is not portable bit for bit:
  - Vulkan only requires sin and cos to have an "Absolute error ≤ 2^-11 inside the range [-π, π]" and lets implementations rearrange operations (sourced).
  - NVIDIA: "different math libraries cannot be expected to compute exactly the same result" (sourced).
  - So **the physics' sea stays on the CPU.** The GPU may add detail the physics does not need.
- **The orbital velocity at the fin, not at the surface.** Below the surface the orbital velocity falls as cosh(k(z+h))/sinh(kh), which is e^(kz) in deep water (coastalwiki, sourced). At the fin's centre of pressure (0.4 × 0.38 m = 0.15 m below the root) that is 53 % of the surface value for a 1.5 m wave and 85 % for a 6 m wave (computed). Today the fin takes the full surface value, which overstates the chop's effect on the fin's angle. This also matters for PH6 (ventilation in chop).
- **The hull and short waves.**
  - The lake chop is 1.2 to 7 m long (table 1.4), all of it below the "about three hull lengths" where the strip theory overstates the slam (spec 17.12, PH10).
  - A board at 10 m/s downwind over 4.6 m waves moving at 2.7 m/s meets a crest every 0.63 s (computed).
  - A realistic sea will expose PH9 and PH10. The sea and the hull have to be planned together.

## 4. The options, with sources

### 4.1 Spectra and spreading

- **Pierson-Moskowitz** describes a fully developed sea: S(ω) = a/ω⁵·exp(−b/ω⁴), a = 0.0081 g² (SIMA).
- **JONSWAP** is PM times a peak enhancement γ (3.3 as the mean), for fetch-limited seas (SIMA; section 1.4). That fits a lake.
- **TMA** multiplies JONSWAP by the Kitaigorodskii depth function Φ(ω_h), with ω_h = ω·sqrt(h/g). Φ = ½ω_h² up to ω_h = 1, then rises to 1 near ω_h = 2 (Horvath 2015, sourced, the Thompson and Vincent approximation).
  - For the lake's 1.7 s waves in 3 m of water ω_h = 2.05, so TMA changes nothing outside the shore band (computed).
- **Directional spreading:**
  - Horvath compares cos², Mitsuyasu (cos^2s(θ/2)), Hasselmann and Donelan-Banner.
  - Horvath's default is "the TMA non-directional spectrum, and the Donelan-Banner directional spreading function", and "only the directional spreading ever needs to be modified in practice".
  - Shorter waves spread more around the wind (Mitsuyasu, cited by spec 9.16).
  - The Goda-Suzuki values (s = 10 for wind sea, 25 to 75 for swell) appeared only in search snippets and are **not sourced** here.

### 4.2 Making a surface in real time

- **A sum of Gerstner waves (what we have).** It is the classic game method: GPU Gems (2004) limits itself to "four geometric waves" and adds "about 15 waves" in textures. Depth there only fades the amplitude toward the shore (sourced).
  - A single Gerstner wave is an exact solution only for infinite depth; it has no Stokes drift, and "solutions for finite fluid depth are lacking" (Wikipedia, Trochoidal wave, sourced).
  - The finite-depth fix used in graphics follows from linear theory, by the same coastalwiki formulas: ω² = gk·tanh(kh), and a horizontal orbit A·coth(kh) instead of A (computed).
  - Cost per query grows with the number of waves (section 2).
- **FFT (Tessendorf).** One inverse FFT makes the whole field. Grids of "128 to 512 are sufficient"; the tile repeats in space; frequencies are quantized so the animation loops after a time T (Tessendorf's notes, eq. 35, sourced). Its limit is that "You either get the whole surface, or you don't compute it", and depth is only possible for "a flat bottom".
  - **Measured on this PC** (numpy's compiled FFT, which includes Python's call overhead), one inverse real 2D FFT takes:
    - 30 µs at 32², 42 µs at 64², 103 µs at 128² and 387 µs at 256².
    - A physics tile needs about 8 fields: the height, two slopes, three velocity components and two horizontal displacements. At 128² that is about 0.9 ms an update, **once for all boards** (computed).
  - GDScript has no FFT, so this needs native code: a GDExtension with pocketfft ("3-clause BSD", "header-only") or KissFFT ("Revised BSD"), both sourced.
  - A fetch that varies in space does not fit a homogeneous FFT tile. It needs one tile per band, blended by local amplitude, at the cost of more FFTs (estimate).
- **Wave particles** (Yuksel 2007) have no dispersion ("our wave speed is constant"). They suit a board's wake, not the sea.
- **Water wave packets** (Jeschke and Wojtan 2017) handle what an FFT cannot. The reference code has:
  - dispersion with depth and refraction by "snells law (depending on water depth)";
  - reflection at shores;
  - shoaling through "the amplitude from energy flux".

  It "runs in real time for moderately challenging scenarios" (abstract). No cost in ms was found. It is research code.
- **Water surface wavelets** (Jeschke et al. 2018) handle obstacles. Their reference code is deep water only.

### 4.3 What the bottom does (all coastalwiki, sourced)

| Effect | Rule |
|---|---|
| Dispersion | ω² = gk·tanh(kh); deep for h/L ≥ 0.5, shallow for h/L ≤ 0.04 |
| Group velocity | c_g = (c/2)·[1 + 2kh/sinh(2kh)] |
| Shoaling | H/H₀ = sqrt(c_g0/c_g), without loss |
| Refraction | sin α / c constant along a ray (Snell); the crests turn toward the depth lines |
| Breaking | steepness H/L < 1/7; depth-limited breaker index H_b/h_b, about 0.78 for regular waves, ranging from about 0.4 to 1.2 with the beach slope and the breaker type; Battjes: γ_b = 1.06 + 0.14 ln ξ_b |

The irregular-sea cap Hs ≤ 0.6·d in `wind_waves.gd` is the CEM's rule as the spec cites it. It was not re-opened here.

### 4.4 Nearshore models

- **Shallow-water equations (NLSW)** are cheap on a GPU but "cannot create wake patterns, because all wavelengths travel at the same speed" (Jeschke and Wojtan 2023, sourced). Their dispersive hybrid ran 512 × 512 at "comfortably over 40fps" on an RTX 2080 laptop.
- **Boussinesq.** Celeris (sourced) solves the extended Boussinesq equations on the GPU "faster than real-time". In one benchmark it took under 15 s on a 234 × 201 grid that took 3.3 h on one CPU; its largest test was 601 × 601 cells of 5 cm.
  - The Maloja chop needs cells of about 0.25 to 0.5 m (estimate: 10 to 20 cells a wavelength), so the lake's 2.89 km² is 11.6 to 46 million cells (computed). That is 30 to 130 times Celeris's largest test, it runs on the GPU only, and it is not deterministic.
  - **Not for this game**, neither for the physics nor for the look.
- **SWAN**, offline (sourced). It is "a third-generation wave model" for "coastal regions and inland waters", free under the GPL, for "coastal areas, lakes and estuaries".
  - Processes: wind growth, whitecapping, bottom friction, depth-induced breaking, shoaling, refraction and wave-wave interactions.
  - It computes the wave statistics (the action balance), not a moving surface, and "does not properly handle diffraction in harbours or in front of reflecting obstacles".
  - Run once per wind direction and speed on the swissBATHY3D grid, it would bake Hs, Tp and the mean direction per cell. **This is "the sea bottom simulated" done properly, at no cost in the game**, the same way WindNinja bakes the wind.

### 4.5 How others give their physics the surface

| Product | Surface | How the physics gets it | Source |
|---|---|---|---|
| Unreal Engine Water | Gerstner | "self-contained copy of wave params for physics thread use"; "Math mirrors UGerstnerWaterWaves::GetWaveHeightAtPosition": **our pattern** | Epic API docs |
| VRX (ROS/Gazebo) | 3 Gerstner waves in the shader | the CPU "is using the same parameters as used by the visual plugin": **our pattern** | VRX wiki |
| Unity HDRP Water | GPU FFT bands | GPU readback ("a few frames delay"), or an optional CPU copy of the simulation ("half resolution" unless full is chosen; "significantly increase the CPU cost") | Unity docs and forum |
| Crest (Unity) | GPU FFT and Gerstner | GPU queries "can take a couple of frames"; the CPU Gerstner is "deprecated" and "does not include wave attenuation from water depth"; the newer CPU option is a baked, looping FFT, "Only a single set of waves" | Crest docs 4.11, 4.23 |
| Sea of Thieves | Tessendorf FFT, plus "a GPU water surface simulation based on [Mei et al. 2007]" for shallow detail | not stated | SIGGRAPH 2018 talk |
| asv_wave_sim (Gazebo) | CPU FFT (FFTW), 128 cells on a 256 m tile, deep-water dispersion | ray cast against the CPU mesh | GitHub |

### 4.6 Godot 4

- **GodotOceanWaves (2Retr0).** A compute-shader FFT with "the Texel-Marsen-Arsloe (TMA) spectrum described in Horvath" and several cascades of one size (128² to 1024², default 1024). It updates "one cascade each frame".
  - It has no CPU readback and no buoyancy (in the files checked).
  - It still says "frames during which the wave generation pipeline runs still stutter".
- **godot4-oceanfft (tessarakkt).** Compute FFT at 256² with three cascades. Buoyancy reads the GPU texture back with the blocking `texture_get_data`, and the code warns that "high frameskip settings may cause floating objects to appear disconnected from the rendered waves".
- **OceanPro** (paid, Godot 4.7): "GPU surface sampling and ready-to-use buoyancy". No method or cost is published.

None of them gives a headless, deterministic CPU surface. All three would serve the **look**, layered over a CPU sea for the physics.

### 4.7 The options side by side

Costs are per board per tick unless marked. The ms figures come from section 2's measurement, scaled in proportion to the number of waves (estimate).

| Option | Realism | The physics gets | CPU | GPU | Deterministic | Effort | Risk |
|---|---|---|---|---|---|---|---|
| A. Today: 4 hand-set Gerstner waves | low: regular, the same everywhere | height, normal, surface velocity | 1.0 ms | trivial | yes | – | – |
| B. **Fetch bands** (section 1): 4 physics bands of 1 to 8 m, amplitudes from the local spectrum, the short bands and ripples in the shader only | good on the lake: grows downwind, gusts on the short waves | the same, plus depth decay at the fin (Michiel) | about 1.0 ms (the same 4 waves) + a fetch-map lookup | a little more shader | yes | S–M | the regular look of 4 waves remains; the hull on real chop (PH10) |
| C. 16 to 64 Gerstner waves per point in GDScript | better spectrum | the same | 4 to 16 ms | fine | yes | S | too dear for 20 boards |
| D. CPU FFT tiles in a GDExtension, shared by all boards and uploaded to the shader | high: short-crested, many waves | interpolated height, normal, velocity | about 1 to 2 ms per update **for all boards** + cheap lookups | upload ~1 MB a frame | yes (one binary) | L | native build on two PCs; tiles repeat; fetch needs a tile per band |
| E. GPU FFT for the look (GodotOceanWaves-like) over B or D for the physics | high look | from B or D | as B or D | 1–2 ms (not measured) | physics yes | M–L | picture and physics agree only on the shared bands |
| F. SWAN offline, baked per wind (the bottom) | the real fetch, refraction, shoaling, breaking, as statistics | feeds B, D or E | none in the game | none | yes | M (tooling) | no lake data to validate against |
| G. Live Boussinesq or shallow-water solver | the shore done right | – | – | 11–46 M cells | no | XL | not feasible |
| H. Wave packets near the shore | refraction and breakers in the shore band | possible | unknown | – | yes if on the CPU | L | research code; only 5.5 % of the lake |

## 5. Recommendation and staged plan

**Recommendation.**
1. Keep the physics' sea a CPU function of place and time, shared by both PCs and drawn by the shader with the same formulas.
2. Make it realistic where it matters first: the lake's fetch-limited, gust-touched chop in a few spectral bands (option B, section 1).
3. Add the bottom offline (SWAN, option F) when a map needs it, rather than simulating water live.
4. A GPU FFT or a native CPU FFT is for later, when the hull can ride the real chop and measurements show the banded sea too regular or too dear.

| Stage | What | Why now or later | Size |
|---|---|---|---|
| 1 (now, tonight's builder) | Lake fetch map, bands, short bands and ripples raised by gusts in the shader only (section 1.7). The finite-depth dispersion ω² = gk·tanh(kh) in `wave_field.gd` and the shader (spec 9.16's open item). Seeded phases. | Max's request; no new technology; costs the same CPU as today | S–M |
| 2 (with PH9/PH10, = PH11) | The full chop amplitudes into the physics. The fin's orbital velocity at depth. The validation on lake chop. The open sea as JONSWAP chop plus a narrow-spread swell. | The hull must take short chop first (17.12) | M |
| 3 (look) | More shader-only components with Donelan-Banner spreading, or GPU FFT cascades for detail. Whitecaps from steepness (Tessendorf's Jacobian J < 0 marks folding crests). | A visible gain once 1 and 2 hold; the physics stays the same | M |
| 4 (the bottom) | SWAN on the lake grid for the Maloja sector: check the fetch map, and bake Hs, Tp and direction for the shore band. For a future sea spot with a beach: SWAN plus shoaling, refraction and breaking amplitudes, and breakers for the look. | On Silvaplana the bottom touches 5.5 % of the water, mostly where the board is stopped | M |
| Only if measured necessary | A CPU FFT in a GDExtension (option D) | If 20 boards on a richer banded sea cost too much, or Max finds the bands too regular | L |
| No | A live Boussinesq or shallow-water solver; a GPU-only sea for the physics | Cost, headless tools, determinism | – |

## 6. What Michiel must decide

1. **The growth law:** SPM (today) or CEM. They agree on the height and differ by 25 % on the period. Possibly per map, after Max's observation.
2. **The fetch definition:** straight line, or the 9-ray cosine (1.2). Also whether to average the wind along the upwind ray (the Neuchâtel paper's suggestion).
3. **The physics cut-off:** the shortest band the hull and buoyancy see (1 m suggested; the rows are 0.4 m apart), and how this meets PH10's smoothing of the surface the strips see.
4. **Depth decay of the orbital velocity** for the fin and the strips (e^(kz) per wave, cheap).
5. **Finite-depth dispersion** in the wave field and shader, with a per-map reference depth or the local depth. The local depth changes the phase along a ray (refraction); a per-map depth does not.
6. **The LAN contract:** the same function within a millimetre (D7), not bit-equal. Tests stay bit-exact on one PC.
7. **Native code:** whether a GDExtension is acceptable later. It decides whether option D is ever possible.

## 7. Open technical questions

- How fast short waves die after a gust (not sourced; 1.5).
- Whether the Maloja's waves on Silvaplana follow the laws at all. The lake measurements found the laws too high in light wind (1.3).
- The float32 phase in the shader over a long session. At a phase of 18 000 rad (an hour at ω = 5 rad/s) a float32 step is about 0.002 rad (computed). Tessendorf's looping frequencies, or wrapping the clock, would bound it.

## 8. Questions for Max (what you see on the water)

1. **Wave length.** On a typical Maloja afternoon at the camping beach, how many board lengths from crest to crest? About two (the SPM law, 5 m) or about one (the CEM law, 3 m)? A short video with the board in view would settle it, and so would counting the crests that pass a fixed point in 30 seconds.
2. **Height.** About how high from trough to crest at the beach, mid-lake and near Sils? Knee, shin or ankle?
3. **Whitecaps.** From what wind do you see whitecaps, and where on the lake?
4. **Direction.** When the Maloja comes from further west (afternoon), do the waves at the downwind end still run along the lake, or with the wind?
5. **Gusts.** In a gust, does only the water's texture change (cat's paws), or do the waves you jump get bigger within a minute?
6. **The shore.** Do waves break on the beach at the launch? Is the water near the north-east shore choppier or confused (waves bouncing off the steep shore)?
7. **Which spot needs a sea bottom first:** Silvaplana's shore, or a sea spot you want next?

## 9. Sources

Opened in this session. Some were opened by research helpers working for this report; their key numbers were checked against the text where marked ✓.

**Waves and the lake**
- SINTEF SIMA, wave spectra (PM, JONSWAP 3-parameter): https://sima.sintef.no/docs/5.0/simo/modelling/environment/waves.html
- Coastal Wiki, Shallow-water wave theory (dispersion, group velocity, shoaling, refraction, orbital velocity, breaking): https://www.coastalwiki.org/wiki/Shallow-water_wave_theory
- Coastal Wiki, Breaker index: https://www.coastalwiki.org/wiki/Breaker_index
- `waver` R package reference manual (the CEM fetch laws, citing Resio, Bratos and Thompson 2003): https://cran.rstudio.com/web/packages/waver/refman/waver.html
- `lakefetch` docs (the SPM cosine fetch): https://docs.ropensci.org/lakefetch/reference/fetch_calculate.html
- GRASS r.windfetch tutorial (SPM and restricted arcs): https://grass-tutorials.osgeo.org/content/tutorials/windfetch/windfetch.html
- Casas, Bleninger and Stips (2025), Reanalysis of wind-wave growth in a lake (Lake Neuchâtel) ✓: https://files.abrhidro.org.br/Eventos/Trabalhos/248/XXVI-SBRH0789-1-0-20250623-165748.pdf
- Polnikov, Numerical modelling of wind-waves (quotes Plant 1982 and Snyder 1981) ✓: https://arxiv.org/pdf/1009.2056
- Karimpour, Chen and Twilley (2017), Wind wave behavior in fetch and depth limited estuaries (full text, equations as images): https://www.ebi.ac.uk/europepmc/webservices/rest/PMC5241670/fullTextXML
- SRF Meteo, Malojawind: https://www.srf.ch/meteo/meteo-storys/thermischer-wind-malojawind
- Wikipedia, Trochoidal wave: https://en.wikipedia.org/wiki/Trochoidal_wave
- SWAN: https://swanmodel.sourceforge.io/home.htm, https://swanmodel.sourceforge.io/features/features.htm, https://swanmodel.sourceforge.io/online_doc/swantech/node5.html
- Celeris (Tavakkol and Lynett) ✓: https://arxiv.org/abs/1611.05984v2

**Real-time methods**
- Tessendorf, Simulating Ocean Water (2004 notes) ✓: https://jtessen.people.clemson.edu/reports/papers_files/coursenotes2004.pdf
- Horvath (2015), Empirical directional wave spectra for computer graphics: https://cdn.shopify.com/s/files/1/0134/1131/9867/files/EmpiricalDirectionalWaveSpectra_DigiPro2015_Jun20_2015_Optimized.pdf
- GPU Gems, ch. 1, Effective water simulation from physical models: https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models
- Yuksel et al. (2007), Wave particles: http://www.cemyuksel.com/research/waveparticles/waveparticles.pdf
- Jeschke and Wojtan (2017), Water wave packets: https://history.siggraph.org/?p=102417 and https://raw.githubusercontent.com/jeschke/water-wave-packets/master/SimpleSampleDirectXTK/Packets.cpp
- Jeschke et al. (2018), Water surface wavelets: https://history.siggraph.org/?p=100753 and https://raw.githubusercontent.com/lecopivo/WaterSurfaceWavelets/master/src/WaveGrid.cpp
- Jeschke and Wojtan (2023), Dispersive waves in shallow water: https://research.nvidia.com/labs/prl/shallow-water-simulation/files/Dispersive_Waves_in_SWE.pdf

**Engines and games**
- Unreal, FBuoyancyGerstnerWaveData: https://dev.epicgames.com/documentation/unreal-engine/API/Plugins/Buoyancy/FBuoyancyGerstnerWaveData
- Unity HDRP water: https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@14.0/manual/WaterSystem-Properties.html, https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition@15.0/manual/WaterSystem-scripting.html, https://docs.unity.cn/Packages/com.unity.render-pipelines.high-definition@15.0/api/UnityEngine.Rendering.HighDefinition.WaterSurface.html, https://discussions.unity.com/t/water-level-in-water-system/1688088
- Crest: https://crest.readthedocs.io/en/4.11/user/collision-shape-for-physics.html, https://crest.readthedocs.io/en/4.23.0/user/collision-shape-and-buoyancy-physics.html
- Sea of Thieves (SIGGRAPH 2018): https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf
- asv_wave_sim: https://github.com/srmainwaring/asv_wave_sim
- VRX wave field: https://github.com/osrf/vrx/wiki/documentation-wavefield_generation
- GodotOceanWaves: https://github.com/2Retr0/GodotOceanWaves (README, `wave_generator.gd`)
- godot4-oceanfft: https://github.com/tessarakkt/godot4-oceanfft (`Ocean3D.gd`)
- OceanPro: https://forum.godotengine.org/t/oceanpro-1-0-gpu-fft-ocean-system-for-godot-4-7/144004
- Godot RenderingDevice ✓: https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html and https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/RenderingDevice.xml

**Determinism and FFT libraries**
- Vulkan SPIR-V precision: https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/main/appendices/spirvenv.adoc
- NVIDIA, Floating point and IEEE 754: https://docs.nvidia.com/cuda/floating-point/index.html
- pocketfft: https://github.com/mreineck/pocketfft; KissFFT: https://github.com/mborgerding/kissfft; FFTW FAQ: https://www.fftw.org/faq/section1.html, https://www.fftw.org/faq/section3.html

**Gaps (searched, not opened)**
- The Coastal Engineering Manual itself: the mirror's certificate failed, and the official PDF is behind a browser check.
- Kahma and Calkoen (1992), Young and Verhagen (1996) and Plant (1982) in the original: IFREMER refused the connection, and Wiley returned 403.
- Atakturk and Katsaros (1999, Lake Washington).
- The LéXPLORE wave buoy data (Lake Geneva): bot check.
- The Goda-Suzuki spreading values.
- Any wave measurement on Silvaplana.

**Measurements and scripts.** `tools/sea_bench.sh`, run on 5 November 2026. The scratchpad scripts `lake_depths.py`, `start_fetch.py`, `fetch_compare.py`, `band_table2.py` and `aerial_waves.py` read the map's data and write nothing to the repo. Kept in the session's scratchpad; ask if they should go into `tools/`.

