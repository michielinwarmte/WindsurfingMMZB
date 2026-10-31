# The windsurf brands and their slalom and free race gear

*Research for the game's gear set: part 2 of the fleet and gear plan ([PLAN.md](PLAN.md)), Session 64. Written on 31 October 2026 by the researcher agent on the branch `gear/research`. This is an internal document: it uses the real brand names. The game never does; it uses the team's own names, given in brackets.*

**How to read this.** Section 1 explains in plain language what slalom and free race are and how their boards, sails and fins differ, with a glossary. Section 2 goes brand by brand: the 2025 and 2026 slalom and free race lines, with every size the brands publish, the shapes, the colours and a short history. Section 3 proposes the game's gear set, with every number the physics needs in the units of the config scripts. Section 4 is for the shaper who builds the 3D models. Section 5 lists the questions for the team, and section 6 every source.

**Marks used in the tables.** *pub.*: published by the brand (or a shop's copy of the brand's table). *meas.*: weighed or measured by a magazine. *est.*: our estimate; the rule is always written next to it. Brand tables keep the brands' own units (cm, L, kg); section 3 uses the game's units (m, m², m³, kg).

---

## In short

- **Covered:** all eleven brands Michiel named, in depth (their 2025 and 2026 slalom and free race lines), and twelve other brands in a paragraph each. In total about 70 models and some 330 published sizes (boards and sails), from 41 board sizes in the brands' slalom lines to 9 sails a line.
- **The game's gear set (section 3):** 24 slalom boards and 17 free race boards for the six board brands, 32 slalom sails and 26 free race sails for the seven sail brands, each with the full set of numbers for `BoardConfig`, `SailConfig` and `FinConfig`, and a fin per board.
- **The three findings that matter most for the game:**
  1. **Every brand's sails sit on one geometric curve.** Across seven brands, slalom and free race sails from 5.5 to 9.0 m² all have an aspect ratio (luff² / area) of 2.9 to 3.4, the same as the default 8.0 (3.41), and the game's two sails already match the real ones of their size: the 6.5 (luff 4.60 m, boom 1.95 m) sits between the real 6.5s (luff 4.56 to 4.64 m, boom 1.92 to 1.98 m). What really changes from one size to the next is the area, the boom length and the rig's weight: a complete real rig weighs about 10.0 kg as a 5.6 and 13.7 kg as a 9.0. So the problem of PH14 (a 7.8 slower than a 6.5 in 12 kt) is not in the sails' sizes: the numbers to build the sizes are now all here, and the brands sell them in steps of 0.8 to 1.0 m² (the PWA's "Slalom X" steps are 5.7, 6.7 and 7.7; from 2026 the largest fin-race sail allowed is 8.5 m²).
  2. **Each board needs its own fin, and the real fins are smaller than the game's.** The fin the brands recommend grows almost in a straight line with the board's width: about 30 cm on a 60 cm wide board, 38 cm on a 72 and 46 cm on an 85 (rule: span ≈ 0.30 + 0.64 × (width − 0.60) m, fitted on Starboard's and FMX's tables). And a real slalom fin of 38 cm has about 311 cm² (Select's Rhino Pro catalogue), where the game's 38 cm fin has 365 cm², the area of a real 42 to 43 cm fin.
  3. **The shapes the brands do not publish can be derived reliably from length, width and volume.** Starboard is the only brand that publishes tail widths and thicknesses (sixteen boards). From them: the tail width one foot from the tail is 0.848 × width − 0.117 m for a slalom board (all six iSonics within 1 cm, and JP's traced 72 too), and the thickness is volume / (0.56 × length × width) (0.61 for slalom boards of 77 cm and wider, 0.59 for free race boards). The 2026 slalom boards of five brands are so close in size at the same volume that what makes them recognisable is the cut-outs, the deck and above all the livery, not the outline.

---

## 1. Slalom against free race

### 1.1 The disciplines

**Slalom** is windsurfing's sprint: a fleet starts together and races around a few buoys, mostly on broad reaches across the wind, with fast gybes at the marks. It is about acceleration out of the gybes and top speed between them. The world tour is the PWA (Professional Windsurfers Association):

- **Fin slalom, called "Slalom X" since 2024**, is raced on boards with a normal fin, in stronger wind. Riders register a limited quiver for the whole season: in 2024 and 2025 two boards and three sails; from 2026 three fin boards a year (at most two per event) and four fin sails a year (at most three per event), with the largest fin-race sail limited to 8.5 m². Fins and footstraps are free. Where an event runs both, racing switches from foil to fin between 15 and 17 knots of wind, and the extra board and sail of 2026 are meant to make fin racing possible from about 12 to 16 knots. ([surf-magazin.de on Slalom X](https://www.surf-magazin.de/en/windsurfing/scene-and-events/world-cup-pwa-presents-slalom-x-as-a-new-racing-discipline/), [PWA rule changes](https://www.pwaworldtour.com/fileadmin/user_upload/Rule_changes.htm), [the 2026 rules on surf-forum.com](https://surf-forum.com/forum/thread/30041-pwa-2026/))
- **Foil slalom** is raced on boards with a hydrofoil in lighter wind (a separate quiver: in 2025 five sails, one board and one foil set). The game does not have foils; this research leaves foil gear out except where a brand's line mixes the two.
- **IFCA** (the International Funboard Class Association) runs fin slalom world championships on production gear, with youth and junior classes; S2Maui's Wicked (a 2-cam free race sail) won the 2024 IFCA youth and junior title ([S2Maui 2026 catalogue](https://www.windsurfing44.com/matos/S2Maui/2026/S2Maui_2026_en.pdf)).
- **National and club racing** uses the same production slalom gear, often a size or two bigger, and long-distance races such as the Défi Wind (Starboard's Futura 95 and Duotone's Warp_Fin 6.2 were made for it).

**Free race** is the line between freeride (relaxed cruising) and slalom: gear that looks and goes like slalom gear but is easier to use. Surf-magazin's 2026 test of ten free race boards sums the boards up as "shorter, wider, faster" than freeride boards: shorter for less swing weight, wider to plane through lulls and give the straps leverage, with thicker, boxier rails and the volume pushed back into the tail. They are 2 to 4 km/h faster than freeride boards with the straps on the outside, but need more skill and jibe less automatically ([surf-magazin.de, freerace test 2026](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/test-2026-ten-freerace-boards-put-to-the-test-highway-to-heaven/)). Free race sails have fewer cams (two or three, or none) and a narrower sleeve than race sails, so they rig and rotate more easily and pull less on the back hand.

### 1.2 How the boards differ

| | Slalom (race) | Free race |
|---|---|---|
| **Length** | 224 to 233 cm. The brands' boards of up to about 118 L are 226 to 233 cm; the wide ones a little shorter (Duotone's 2026 Falcons are 224 to 226 cm, "shorter in every size") | 225 to 249 cm. Most are 229 to 238 cm; Severne's Fox is the longest at 236 to 249 cm |
| **Width and volume** | 52 to 85 cm (52 to 54 cm are speed boards), 74 to 147 L. Brands name their sizes by width (iSonic 73, Slalom 72, Manta 71) or by volume (Falcon 118, Invictus 118) | 59 to 90 cm, 95 to 185 L |
| **Tail width (one foot from the tail)** | Wide: 0.65 to 0.71 of the board's width (iSonic: 39.2 cm on the 60 to 60.4 cm on the 85). A wide tail gives leverage on a big fin | Narrower for the width: 0.63 to 0.69 (Futura: 38.8 cm on the 95 to 52.5 cm on the 135) |
| **Cut-outs** | On every 2026 slalom board: the bottom steps in near the tail, often in two steps of different heights, so less of the bottom is wet at speed while the deck above stays wide for the back straps. FMX's are removable plates | Smaller cut-outs (Futura's "refined cutaways with a triangle stabilizer", the Jag's two-step, the Rocket+'s tail cut-outs, the Fox's "medium cut-outs") |
| **Rails** | Hard, sharp-edged rails in the tail; JP's "high apex, full parabolic" rails; some sizes "more tucked-in in the tail" (Manta 64) | Thinner rails for easier jibes (JP Super Sport), or thick boxy rails with volume aft (surf-magazin) |
| **Rocker** (the bottom's curve along the length) | A flat tail with no kick and a "scoop" toward the nose: the JP 72's bottom rises 6 mm at 1.0 m from the tail, 63 mm at 1.8 m and 205 mm at the tip (traced from JP's side view, in `tools/blender/build_rig_models.py`) | The same slalom-derived flat line (Jag 128: "the planing surface runs straight to the tail without upturn"; Fox 135: 1 mm of tail rocker) |
| **Bottom (vee and concaves)** | A vee or double concave in front to cushion chop, flat or a slight vee (or even an inverted vee) in the tail: iSonic "flat vee to double concave", FMX "double concave, vee to inverse vee", Manta "deep front vee" on the 61 to 71 | More vee for comfort: Jag 110 a flat vee of 7 mm at 33 cm from the tail; Goya Bolt 10 mm; Blitz a "continuous, gentle vee" |
| **Deck** | Concave decks and a recess around the mast track so the rig sits lower (JP, FMX "deep deck concave", Duotone D/LAB). Small, minimal EVA pads; a pad wedge between the back straps (JP) | Bigger, softer pads; concave around the mast base (JP Super Sport, Futura) |
| **Fin box** | Short or medium Tuttle up to about 118 L, deep Tuttle (often foil-approved) on the bigger sizes. No fin included | Deep Tuttle, foil-approved on most; Powerbox on the Fox. A fin included (G10, 36 to 50 cm) |
| **Footstraps** | Far out on the rails; two rows of plugs (FMX), double plugs with four screws per strap (JP) | Inboard and outboard positions, the outer ones "for advanced riders" (Rocket+) |
| **Weight (bare)** | 5.6 to 7.7 kg | 6.1 to 8.8 kg |
| **Construction and price** | Carbon sandwich (iSonic Carbon Reflex, Falcon D/LAB full custom); about €2,400 to €3,700 | Wood or glass-carbon sandwich; about €1,900 to €2,800 |

### 1.3 How the sails differ

| | Slalom race sail | Free race sail |
|---|---|---|
| **Cams** (plastic forks at the batten ends that hold the sail's curve against the mast) | 3 or 4: Point-7 has 3, Severne, NeilPryde, Duotone, GA and S2Maui have 4. North uses an "air cam" (an inflatable sleeve, no hard cams) | 2 or 3 (S_Pace and Overdrive 3, V8, Wicked, Cosmic and AC-2 2), or none (NCX, X_Pace, Free Speed, Banshee) |
| **Battens** | 7 (6 on a few of the smallest sizes) | 6 or 7 |
| **Luff and boom** | At 7.7 to 7.8 m²: luff 4.88 to 4.98 m, boom 2.09 to 2.17 m | At 7.7 to 7.8 m²: luff 4.86 to 4.97 m, boom 2.00 to 2.14 m. Shorter booms are a free race selling point (Overdrive: "10 cm shorter boom") |
| **Mast** | SDM (standard diameter), 100 % carbon, for 6.5 m² and up; RDM (reduced diameter) for 5.9 m² and down. The race sails' size steps follow the mast lengths: about 5.5 to 5.9 on 400, 6.5 to 6.8 on 430, 7.3 to 7.8 on 460, 8.2 to 8.8 on 490 | The same lengths; more of them take RDM masts |
| **Sleeve** | Wide (Point-7 "XXL"), layered (NeilPryde "quadruple luff"): it gives the cams room and makes the front of the sail a stiff wing | About 20 to 33 % narrower (Point-7 AC-3, Severne Overdrive) |
| **Foot** | Long and low, cut to close the gap to the deck (Point-7 "base outline closes the gap to the board"; Severne "single seamless foot panel"). The 2026 trend is a bigger cutaway at the clew (Duotone Warp_Fin, GA Vapor) | A little higher and shorter |
| **Profile** | Deep and locked in the lower sail, flatter and twisting above (S2Maui Venom-XI: "flatter above the boom at battens 4 and 5, locked below at 6 and 7") | Shallower, more twist: easier but with a smaller wind range |
| **Panels and windows** | Vertical luff panels, radial or horizontal body panels; clear or grey film windows in the lower sail | The same layouts, fewer special materials |
| **Weight (sail only)** | 7.5 to 7.8 m²: 5.5 to 6.6 kg | 7.7 to 7.8 m²: 4.7 to 5.5 kg with cams, 4.4 to 4.7 kg without |

**Wind range per size.** Only Point-7 publishes one. Its chart for the AC-1 LTD, for a rider of 75 to 90 kg ([point-7.com](https://point-7.com/zero-26/ac1-ltd-racing-026/)):

| Wind | Sail |
|---|---|
| 6 to 16 kt | 8.2 |
| 16 to 21 kt | 7.3 or 7.8 |
| 21 to 25 kt | 6.5 or 6.8 |
| 25 to 31 kt | 5.9 or 6.5 |
| 35 kt and more | 5.4 |

(For 60 to 75 kg it is one size smaller, for 90 kg and more one size bigger.) The game's personas switch at 16 kt from a 7.8 to a 6.2 (`Game/race/persona.gd`), which fits this chart.

### 1.4 Fins

A slalom fin is a thin, swept carbon wing of 28 to 48 cm. Most race fins come from fin makers (Select, Sonntag, Z-Fins, Black Project, Deboichet, Drake, MFC), not from the board brands, and no slalom board comes with one. The board brands publish a recommended range per size:

| Board | Width | Recommended fin |
|---|---|---|
| iSonic 60 / 63 / 67 / 73 / 77 / 85 | 60 / 63 / 67 / 73 / 77 / 85 cm | 28-32 / 30-34 / 34-38 / 36-40 / 38-44 / 44-48 cm |
| FMX Invictus Pro 78 / 88 / 98 / 104 / 108 / 118 / 124 / 128 / 138 | 59 / 61 / 63 / 67 / 70 / 72 / 77 / 81 / 85 cm | 28-32 / 29-33 / 30-34 / 32-36 / 34-38 / 35-39 / 37-41 / 39-44 / 42-48 cm |
| Duotone Falcon_Fin SLS 98 / 111 / 118 / 129 / 139 | 63 / 68 / 72 / 80 / 85 cm | 34-36 / 36-40 / 38-42 / 42-46 / 46-50 cm |

The middle of these ranges follows the width almost in a straight line: **span ≈ 0.30 + 0.64 × (width − 0.60) m**, which gives 0.38 m for a 72 cm board (the game's default fin is 0.38 m). Duotone recommends 2 to 4 cm more than Starboard and FMX for the same width.

**Fin area.** Select, one of the biggest slalom fin makers, publishes the area of every size ([Select 2023 catalogue](https://www.select-hydrofoils.com/assets/select_fins_2023_catalog.pdf)). Its race fin, the Rhino Pro ("performance slalom boards, slalom racing"):

| Span (cm) | 30 | 32 | 34 | 36 | 38 | 40 | 42 | 44 | 46 | 48 |
|---|---|---|---|---|---|---|---|---|---|---|
| Area (cm²) | 226 | 247 | 267 | 286 | 311 | 333 | 358 | 378 | 405 | 428 |

Its S.MAX ("slalom, free race and freeride boards from 90 to 165 L") is about the same area for the size (37 cm: 291 cm², 41 cm: 332 cm², 45 cm: 384 cm²). Select advises "for slalom choose 1 cm bigger" than its fin chart. **The game's 38 cm fin has 365 cm²** (`Game/config/fin_default.tres`), the area of a real 42 to 43 cm slalom fin: its mean chord is 9.6 cm where the real fin's is 8.2 cm. (Brands measure a fin's size along its depth below the box; the game's `span_m` is the depth below the hull, which may differ by a centimetre or two where the fin's base is thick.)

### 1.5 Glossary

| Word | Meaning |
|---|---|
| **1 ft off (OFO)** | A board's width measured one foot (30.48 cm) in from the tail or the nose. What the game's `tail_width_m` and `nose_width_m` are |
| **Cut-out, cutaway, step** | Where the bottom near the tail is cut back from the deck's outline, so the water leaves the board at a sharp step. "Double step": two steps of different heights |
| **Triangle stabilizer** | Starboard's 2026 detail: a small triangular surface between the cut-outs, for fin control |
| **RTS plates** | FMX's "Range Trim System": removable carbon cut-out plates; two sets come with the board |
| **Rocker, scoop, tail kick** | The bottom's curve along the length; the scoop is its rise toward the nose, the tail kick a small rise at the tail |
| **Vee, double concave, inverse vee** | The bottom's shape across: a vee is a ridge down the middle (smooth in chop), a double concave two hollows either side of the middle (lift), an inverse vee the opposite of a vee |
| **Rail: hard, soft, tucked, apex** | The board's edge. Hard: a sharp edge where the bottom meets the side. Soft or tucked: rounded under the board. The apex is the rail's widest, highest point |
| **Tuttle, deep Tuttle, short Tuttle, Powerbox** | The fin box standards. A Tuttle fin has a block held by two screws through the deck; a deep Tuttle is taller (and takes foils); a Powerbox is a different, lighter standard |
| **Cam (camber inducer)** | A plastic fork at the front end of a batten that pushes against the mast, so the sail keeps its curve when the wind drops. Race sails have 3 or 4 |
| **Batten** | A stiff rod across the sail that holds its shape. Race sails have 7 |
| **Luff, leech, foot, head, tack, clew** | The sail's front edge (along the mast), back edge, bottom edge, top, bottom-front corner and bottom-back corner (where the boom ends) |
| **Sleeve (luff sleeve)** | The tube along the luff that the mast slides into |
| **RDM, SDM, IMCS** | Reduced-diameter mast (thin, for small sails) and standard-diameter mast; IMCS is the mast's stiffness index (17 for a 370 to 33 for a 520) |
| **Extension, base** | The extension lengthens the mast at the bottom (it holds the downhaul pulleys); the base joins it to the board |
| **Downhaul, outhaul** | The lines that pull the tack down (shaping the luff and twist) and the clew out (the profile's depth) |
| **Monofilm, X-ply, 3Di, Dyneema, Technora** | Sail materials: clear film, film with a cross of fibres, North's moulded tape laminate, and two strong low-stretch fibres |
| **Aspect ratio** | Luff² / area: how tall and narrow a sail is. 2.9 to 3.4 for every sail in this report |
| **Slalom X** | The PWA's fin slalom discipline since 2024 |
| **D/LAB, SLS, Carbon Reflex, Team, LTD, MTE, Wood Pro** | The brands' construction names, from lightest and dearest to heaviest and cheapest |

---
