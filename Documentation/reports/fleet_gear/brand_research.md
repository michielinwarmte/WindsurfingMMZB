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

## 2. The brands

Each brand has the same parts: who they are, the slalom and free race lines of 2025 and 2026 (tables), what makes the shapes recognisable, and the livery (the colours and graphics). Colours given as hex were measured as the median of a patch of the brand's own product picture (studio renders and photos, so lighting shifts them a little) or converted from the Pantone numbers the brands publish; both are marked. The sources of every table are listed under the table and again in section 6.

### 2.1 Duotone (game: Tripletone): sails and boards

**Who they are.** Duotone is the windsurf brand of Boards & More, an Austrian-German company. Boards & More made and sold the North Sails windsurf sails under licence from 1981; after a dispute with the owner of the North name it renamed its products Duotone for 2019, with the same designers and the same model names (Warp, E_Type) ([surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/scene-and-events/goodbye-northsails-hello-duotone/), [easy-surfshop blog](https://easy-surfshop.com/do/blog/post/north-sails-and-nkb-have-changed-name-for-duotone)). Its board brand Fanatic, one of the oldest board names in the sport, was folded into Duotone for the 2024 model year (announced on 4 September 2023): the Falcon and the Jag became Duotone boards ([surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/scene-and-events/traditional-brand-disappears-fanatic-becomes-duotone/), [continentseven.com](https://www.continentseven.com/fanatic-becomes-duotone-an-interview/)). Kai Hopf designs the sails and Sebastian Wenzel shapes the boards. Character: a big, technical brand with three construction levels for every board (D/LAB the semi-custom top, SLS the light production board, plain or CNC the cheapest) and product names with an underscore (Falcon_Fin, Warp_Fin, S_Pace). The boards still carry Fanatic's animal names.

**Slalom boards: Falcon_Fin.**

*2025: Falcon_Fin D/LAB* (item 14240-1015; the same shapes as 2024; no fin; "full custom" construction with a CNC-milled foam core and no mould; two-step cut-outs; a recessed mast base):

| Size | Length cm | Width cm | Weight kg | Max sail m² |
|---|---|---|---|---|
| 90 | 233 | 60 | 6.20 | 6.2 (7.4 for speed) |
| 99 | 233 | 63 | 6.35 | 7.2 (7.8 for speed) |
| 107 | 233 | 68.5 | 6.55 | 8.4 |
| 116 | 230 | 71.5 | 6.70 | 8.8 |
| 130 | 228 | 80 | 7.20 | 9.0 |
| 140 | 228 | 85 | 7.60 | 10.0 |

Sources: [boardwise.co.uk](https://www.boardwise.co.uk/products/2024-duotone-falcon-fin-d-lab), [duotonequipment.com](https://duotonequipment.com/product/falcon_fin-d-lab-2025/), [worthingwatersports.com (the 2024 table)](https://worthingwatersports.com/en-us/products/used-duotone-falcon_fin-d-lab-2025-116). The size is the volume in litres. The 99 is the one "everyone calls the magic board"; the 90 (2024) is built on it for PWA racing. Duotone: the smaller the board, the higher its aspect ratio (long and narrow) for control.

*2026: Falcon_Fin SLS* (new: a "completely redesigned tail" with two-step cut-outs, shorter in every size with less nose lift, higher rails, a less recessed mast track than the D/LAB, S-Glass+ instead of most carbon, up to 250 g lighter; optional inboard strap plugs; no fin):

| Size | Length cm | Width cm | Weight kg | Fin box | Fin cm | Max sail m² |
|---|---|---|---|---|---|---|
| 98 | 226 | 63 | 6.40 | short Tuttle | 34-36 | 7.2 |
| 111 | 225 | 68 | 6.95 | medium Tuttle | 36-40 | 8.4 |
| 118 | 225 | 72 | 7.20 | medium Tuttle | 38-42 | 8.8 |
| 129 | 224 | 80 | 7.60 | deep Tuttle | 42-46 | 9.0 |
| 139 | 224 | 85 | 7.95 | deep Tuttle | 46-50 | 10.0 |

Sources: [duotonesports.com](https://www.duotonesports.com/en/us/products/duotone-falcon_fin-sls-2026-14260-1015) (the shape text; its table does not render outside a browser), [easy-surfshop.com](https://easy-surfshop.com/do/item/N-DTW-14260-1015/Windsurf-board-Duotone-FALCON_FIN-SLS-2026), [telstarsurf.com](https://www.telstarsurf.com/duotone-falcon-fin-sls-2026-121912.html). Shops disagree on the box names (one lists a mini Tuttle on the 98, another a deep Tuttle from the 111).

*2026: Falcon_Fin D/LAB*: sizes 89, 98, 111, 118, 124 (new), 129 and 139, all 224 to 226 cm long; weights 6.00 (89), 6.60 (111), 6.80 (118), 7.10 (124), 7.30 kg (129); a 2027 listing gives widths of 60, 63, 68, 72, 76 and 85 cm ([duotonesports.com](https://www.duotonesports.com/en/us/products/duotone-falcon_fin-d-lab-mto-no-fin-2026-14260-1066), [worthingwatersports.com, 2027](https://worthingwatersports.com/en-us/products/duotone-windsurfing-falcon-fin-d-lab-2027)).

**Free race boards: Jag (2025), Blitz (2026).**

*2025: Jag SLS* (the same as 2024; a narrower outline than a slalom board, a two-step cut-out, more vee from the mast track back; no fin):

| Size | Length cm | Width cm | Weight kg | Fin box | Fin cm (Duotone Race fin) | Max sail m² |
|---|---|---|---|---|---|---|
| 94 | 235 | 61 | 6.40 | Tuttle | 31-34 (34) | 7.5 |
| 110 | 235 | 70 | 7.20 | Tuttle / foil | 35-38 (38) | 8.0 |
| 128 | 235 | 76 | 7.60 | Tuttle / foil | 39-43 (42) | 8.8 |
| 138 | 232 | 83 | 8.10 | Tuttle / foil | 43-46 (46) | 9.0 |
| 158 | 230 | 90 | 8.80 | Tuttle / foil | 45-48 (48) | 10.0 |

Sources: [roho.co.uk](https://www.roho.co.uk/duotone-jag-sls-freerace-windsurf-board-14240-1003), [telstarsurf.com](https://www.telstarsurf.com/duotone-jag-sls-117845.html). Surf-magazin measured the 110 (2024): a planing surface of 84 cm, 2.5 mm of rocker and a flat vee of 7 mm at 33 cm from the tail; the 128 (2025): a straight planing surface to the tail, a minimal flat vee at the back and a slight double concave with a slight vee under the mast track, colour-contrasting cut-outs, €2,499 ([110](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2024-duotone-jag-110-on-test-sporty-fast-and-controllable/), [128](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboard-2025-duotone-jag-128-on-test-sporty-but-easy/)).

*2026: Blitz* (new, replaces the Jag in the 2026 tests; "volume yet control": pick 10 L more than with another brand; CNC, SLS and D/LAB constructions; Tuttle, foil-approved; an F_Ride fin included):

| Size | Length cm | Width cm | Weight kg (shop, construction not stated) | SLS kg | Fin included | Max sail m² |
|---|---|---|---|---|---|---|
| 104 | 233 | 63 | 6.40 | - | F_Ride 34 | 7.8 |
| 116 | 234 | 68 | 6.80 | - | F_Ride 38 | 8.3 |
| 126 | 235 | 71 | 7.20 | 7.4 | F_Ride 42 | 8.5 |
| 136 | 238 | 77 | 7.50 | 7.8 (meas. 8.2) | F_Ride 44 | 8.8 |
| 146 | 241 | 83 | 7.70 | 8.1 | F_Ride 46 | 9.0 |
| 165 | 247 | 80 (as listed) | 7.90 | - | F_Ride 48 | 9.5 |
| 185 | 250 | 90 | 8.70 | - | F_Ride 50 | 10.0 |

Sources: [surf-center.com](https://surf-center.com/en/duotone-blitz-2026), [windlounge.de](https://en.windlounge.de/products/duotone-blitz-board-2026), [surf-magazin.de, Blitz 136 SLS](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-duotone-blitz-136-sls/). The CNC version weighs 7.8 (116), 8.2 (126) and 8.5 kg (136). Prices of the 136: CNC €1,899, SLS €2,549, D/LAB €2,899. Shape: a continuous, gentle vee with gentle double concaves in front.

**Slalom sails: Warp_Fin.** Four HYPER.CAM 2.0 cams (their length set with a screw), seven battens, a fixed head, Platinum SDM masts; batten tension set at the factory with a torque wrench; the right boom length printed on the sleeve at boom height.

| Size | 2025 boom max cm | 2025 luff max cm | 2025 kg | 2025 mast | | 2026 size | 2026 boom cm | 2026 luff cm | 2026 kg |
|---|---|---|---|---|---|---|---|---|---|
| 5.0 | 176 | 392 | 4.70 | 380 | | 5.2 | 176 | 392 | 4.70 |
| 5.8 | 190 | 426 | 5.10 | 400 | | 5.7 | 188 | 426 | 5.10 |
| - | - | - | - | - | | 6.2 (new) | 192 | 432 | 5.40 |
| 6.8 | 204 | 462 | 5.60 | 430 | | 6.7 | 202 | 462 | 5.60 |
| 7.8 | 216 | 488 | 6.00 | 460 | | 7.7 | 214 | 488 | 6.00 |
| 8.4 | 224 | 514 | 6.30 | 490 | | 8.5 | 228 | 514 | 6.30 |

Sources: [worthingwatersports.com 2025](https://worthingwatersports.com/en-us/products/duotone-warp_fin-2025), [2026](https://worthingwatersports.com/en-us/products/dtw-warp_fin-mto-2026), [telstarsurf.com](https://www.telstarsurf.com/duotone-warp-fin-118920.html), [surf-center.com](https://surf-center.com/en/duotone-warp-fin-2026), [windsurf.co.uk](https://www.windsurf.co.uk/new-duotone-warp_fin-falcon_fin-d-lab/). The 2026 sizes were renamed for the Slalom X steps (5.7, 6.7, 7.7) with a new 6.2 for speed and the Défi Wind; a shorter boom, a bigger cutaway clew and stiffer battens 2 to 4. Several 2026 luffs and weights equal the 2025 ones: the shop may have carried them over (a 2027 listing gives 4.70 to 6.60 kg).

**Free race sails: S_Pace (3 cams), X_Pace (no cams).**

| S_Pace 2026 | Boom max cm | Luff max cm | kg | Mast (SDM) |
|---|---|---|---|---|
| 5.4 | 178 | 426 | 4.60 | 400 |
| 6.0 | 190 | 442 | 4.90 | 430 |
| 6.6 | 200 | 462 | 5.10 | 430 / 460 |
| 7.3 | 204 | 476 | 5.30 | 460 |
| 7.8 | 214 | 488 | 5.50 | 460 |
| 8.3 | 222 | 500 | 5.70 | 490 / 460 |

Seven battens, three cams plus a sleeve inducer, the "biggest upgrade since 2020" (a bigger cutaway clew from the Warp_Fin, more twist, a reduced luff curve), from £899. Sources: [roho.co.uk](https://www.roho.co.uk/2026-duotone-s-pace-windsurf-sail), [ozu-tarifa.com](https://www.ozu-tarifa.com/en/products/duotone-s_pace-2026). One shop lists 2 to 6 cm longer booms (older numbers; Windsurf Magazine's 2024 test of the 7.8 had a 220 cm boom: [windsurf.co.uk](https://www.windsurf.co.uk/duotone-s-pace-7-8m-test-review-2024/)).

| X_Pace 2026 (no cams, 7 battens) | 5.4 | 5.8 | 6.2 | 6.6 | 7.3 | 7.8 |
|---|---|---|---|---|---|---|
| Boom cm | 172 | 178 | 186 | 194 | 204 | 210 |
| Luff cm | 412 | 424 | 446 | 458 | 482 | 494 |
| kg | 3.80 | 3.90 | 4.10 | 4.20 | 4.40 | 4.60 |
| Mast | RDM 400 | RDM 400 | 430 | 430 | 460 | 460 |

Source: [fluid-lines.co.uk](https://www.fluid-lines.co.uk/product/duotone-x-pace-windsurfing-sail-2026-4/). (The E_Pace, 6 battens and no cams, is Duotone's freeride sail: colours C14 white/mustard and C15 white/grey.)

**What makes the shapes recognisable.** The Falcon: a compact board with a parallel middle and a wide, square-cornered tail whose two-step cut-outs show in a contrasting colour (aqua on the 2026 SLS, seen from below and from the side); a recessed mast track on the D/LAB. The Warp_Fin: a tall, narrow race sail with seven battens, a large cutaway at the clew and the boom range printed on the sleeve.

**Livery.**
- *Falcon_Fin SLS 2026* (Duotone's studio picture): a white deck (#CCE5F7 measured, white with a pale blue cast) streaked lengthwise with cyan pigment, like marbled resin, fading to lilac and violet toward the tail (#99B5E2 to #8B7CD0); black EVA pads (a black diamond under each front strap, one black wedge across the tail); Duotone's angular black "D" logo large on the nose, on the centreline; a small "DUOTONE" tag with red near the front, and "Falcon Fin SLS" in small black letters beside the mast track. The bottom is a streaked royal blue (#094AC3 measured) with "Duotone" in big red letters (about #E63A3F, est.) running along the centreline, a black "D" near the nose, the small "SLS", and aqua cut-out steps (about #3FC4E0, est.). Duotone's repair colour for this board is Pantone 2097 C (a violet, about #8246AF).
- *Warp_Fin 2025*, colour C31 ([Duotone's render](https://cdn.boards-and-more.com/system/product_picture_gallery_pictures/files/66e0/4834/b16a/4001/2d25/85df/original/DTW25_Warp_Fin_Rendering_C31_Web72.png)): teal (#249AAB measured) luff sleeve and leech and foot edges; a black upper body (#20211C) with a huge white and grey "D" broken into pixels; a white lower body with red batten pockets and stripes (about #E5323B, est.); "DUOTONE" in tall letters running down the leech; the logo again on the foot.

### 2.2 Severne (game: Savanna): sails and boards

**Who they are.** Founded in 2003 in Australia (2002 in one source) by the sail designer Ben Severne, who still designs; based in Perth ([isthmussailboards.com](https://isthmussailboards.com/windsurfing-sail/severne-sails.html), [windsurfing-mag.jp](https://windsurfing-mag.jp/brands/2017/01/5239/)). Antoine Albeau, the most decorated slalom racer of all and a speed record holder, rides the race sails. Character: understated and engineered; red race sails; the logo is a "boomerang" mark with "SV". Severne's "Xtended Range" idea is to sell fewer race sizes, each with a wider range ("skip a size up or down"): its race sail comes in only five sizes. **Severne makes no slalom board**; its fast board is the Fox, a performance freeride and free race board.

**Free race board: Fox (version 4).**

| Size | Length cm | Width cm | Fox kg (Powerbox, fin incl.) | Fox Pro kg (Tuttle, 2026) | Sail m² | Fin cm (Fox) | Fin cm (Fox Pro) |
|---|---|---|---|---|---|---|---|
| 95 | 236 | 61 | 6.19 | 5.82 | 4.7-6.7 | 32 | 30-34 |
| 105 | 239 | 65 | 6.59 | 6.07 | 5.5-7.8 | 36 | - |
| 115 | 241 | 69 | 6.90 | 6.49 | 6.0-8.0 | 40 | - |
| 125 | 244 | 71 | 7.33 | 6.79 | 6.5-8.5 | 42 | - |
| 135 | 249 | 76 | 7.84 | 7.21 | 7.5-9.5 | 44 | 40-44 |

Sources: [isthmussailboards.com](https://isthmussailboards.com/severne-fox-4-windsurf-board.html), [severneshop.com](https://www.severneshop.com/shop/product/2025-severne-fox/), [surf-center.com, Fox Pro](https://surf-center.com/en/severne-fox-pro-2026). The same shapes in 2025 and 2026; the Fox Pro (new for 2026) takes a Tuttle fin and is 330 to 460 g lighter. A continuous rocker, a moderate tail, a pronounced vee; pigmented resin over biax carbon, S-glass and E-glass. Surf-magazin measured the 135: 249.8 × 76 cm and 8.0 kg (2025, €2,749), 7.85 kg (2026, €2,646), 1 mm of tail rocker, medium cut-outs, a straight 44 cm fin; by far the longest board of its test ([2025](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freeride/freerideboards-2025-severne-fox-135-in-test/), [2026](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-severne-fox-135/)).

**Slalom sails: Mach 8 (2025), Mach 9 (2026).** Four cams, seven battens, fixed head; RDM masts on the 5.0 and 5.5, Severne's Apex Team SDM on the rest.

| Size | Mach 8 luff cm | Mach 8 boom cm | Mach 8 kg | Mach 9 luff cm | Mach 9 boom cm | Mach 9 kg | Mast | Enigma boom |
|---|---|---|---|---|---|---|---|---|
| 5.0 | 397 | 165 | 4.75 | 402 | 162 | 4.99 | RDM Red 370 | 160 |
| 5.5 | 428 | 177 | 5.05 | 428 | 177 | 5.30 | RDM Red 400 | 160 |
| 6.5 | 461 | 193 | 5.70 | 456 | 198 | 5.96 | Apex Team 430 | 170 |
| 7.5 | 491 | 203 | 6.03 | 490 | 208 | 6.33 | Apex Team 460 | 180 |
| 8.5 | 521 | 212 | 6.38 | 518 | 222 | 6.74 | Apex Team 490 | 190 |

Sources: [pooleharbour.co.uk, Mach 8](https://www.pooleharbour.co.uk/products/severne-mach-8-sail-2025), [andybiggs.co.uk, Mach 8](https://andybiggs.co.uk/shop/brands/severne-shop/2025-severne-mach-8-pro-slalom-windsurfing-sail/), [severnesails.com, Mach 9](https://www.severnesails.com/sails/mach-9/). The Mach 9 (labelled "026") has a seamless single-panel foot with hidden load patches, a sleeve joined to the body top to bottom, and "CarbonFusion" strips.

**Free race sails: Overdrive M4 (3 cams), NCX (no cams).**

| Overdrive M4 | Luff cm | Boom cm | Battens | kg | Mast |
|---|---|---|---|---|---|
| 4.6 | 381 | 164 | 6 | 3.65 | RDM Red 370 |
| 5.0 | 402 | 167 | 6 | 3.85 | Apex Pro 400 |
| 5.5 | 416 | 178 | 6 | 4.00 | Apex Pro 400 |
| 6.2 | 433 | 186 | 7 | 4.40 | Apex Pro 430 |
| 7.0 | 461 | 189 | 7 | 4.65 | Apex Pro 430 |
| 7.8 | 489 | 200 | 7 | 4.90 | Apex Pro 460 |
| 8.6 | 512 | 208 | 7 | 5.20 | Apex Pro 490 |
| 9.4 | 520 | 218 | 7 | 5.40 | Apex Pro 490 |

"Slalom blasting": three cams, a moderately wide sleeve (a third narrower than the old race sail), a 10 cm shorter boom, a single-panel head and foot and an "auto-adjust" foot that twists. Source: [severnesails.com](https://www.severnesails.com/sails/overdrive/) (no model year on the page; images date from 2021).

| NCX (026, "no cam slalom", 7 battens) | 5.0 | 5.4 | 5.8 | 6.3 | 6.7 | 7.2 | 7.6 | 8.2 |
|---|---|---|---|---|---|---|---|---|
| Luff cm | 402 | 423 | 433 | 455 | 460 | 466 | 488 | 496 |
| Boom cm | 170 | 172 | 177 | 186 | 193 | 201 | 203 | 211 |
| kg | 3.63 | 3.78 | 3.93 | 4.21 | 4.36 | 4.50 | 4.63 | 4.79 |
| Mast (RDM Red) | 400 | 400 | 400 | 430 | 430 | 460 | 460 | 460 |

Source: [severnesails.com](https://www.severnesails.com/sails/ncx/).

**What makes the shapes recognisable.** The Mach: a uniformly red, translucent sail with black battens, black vertical luff panels and a seamless foot. The Fox: long (up to 2.5 m) with a tapered nose, the longest board of every free race test.

**Livery.** *Mach 9* ([Severne's render](https://www.severnesails.com/wp-content/uploads/2026/03/026-Mach-9-render-final-square-800.jpg)): translucent deep red all over (measured #A21310 to #B01D1D on a dark render background; in daylight about #C8161D, est.); black battens; thin black vertical strips in the luff panel; a big outlined Severne "boomerang" in black over the leech just above the boom; a small white "SV" on a black flag in the middle of the sail near the luff; huge black "M9" letters filling the foot, with "MACH" small beside them. The Mach 8 (2025) is red too ([telstarsurf.com](https://www.telstarsurf.com/severne-mach-8-118891.html)).

### 2.3 Point-7 (game: Point.9): sails

**Who they are.** An Italian family business founded by Andrea Cucchi, a PWA slalom racer since 1997, who had the idea in 2005; the first sails came out in summer 2006 (some sources say 2007). The sail designer Peter Munzlinger helped at the start ([point-7.com, our story](https://point-7.com/our-story/), [PWA profile](https://www.pwaworldtour.com/athletes/cucchi-andrea-i-1/)). Character: black and white, smoked film, minimal graphics; model names "AC-0" to "AC-3" by the number of cams (the AC-1 race sail is the exception, with three).

**Slalom sails: AC-1 (2025) and AC-1 LTD (2026).** Three cams, seven tube battens, a wide "XXL" race sleeve, a 4 mil X-ply body, a 5 mil X-ply foot panel with an S-shaped bottom batten, a grey transparent window.

| Size | Luff cm | Mast | Extension cm | Boom cm | AC-1 2025 kg | AC-1 LTD kg (2025 / 2026 stitched) |
|---|---|---|---|---|---|---|
| 4.9 | 400 | 370 RDM | 32 | 174 | - | 4.8 / 4.8 |
| 5.4 | 424 | 400 RDM | 26 | 180 | 4.6 | 5.0 / 5.0 |
| 5.9 | 442 | 400 RDM | 44 | 192 | 4.7 | 5.3 / 5.3 |
| 6.5 (new 2026) | 464 | 430 SDM | 36 | 196 | - | - / 5.8 |
| 6.8 | 464 | 430 SDM | 36 | 204 | 5.4 | 5.8 / 6.1 |
| 7.3 (new 2026) | 498 | 460 SDM | 40 | 210 | - | - / 6.5 |
| 7.8 | 498 | 460 SDM | 40 | 212 | 5.7 | 6.6 / 6.6 |
| 8.2 (new 2026) | 524 | 490 SDM | 36 | 222 | - | - / 6.8 |
| 8.8 | 524 | 490 SDM | 36 | 230 | 5.9 or 6.9 (unclear) | 6.9 / n.a. |

Sources: [point-7.com, AC-1 025](https://point-7.com/zero-25-overview/ac1-ltd-pro-racing-025/), [point-7.com, AC-1 LTD 026](https://point-7.com/zero-26/ac1-ltd-racing-026/), [telstarsurf.com](https://www.telstarsurf.com/point-7-ac-1-pro-race-2025-118965.html) (€1,049). The AC-1 and AC-1 LTD differ only in the sleeve's width. 2026 adds in-between sizes and a sleeve tuned per size from the 7.8 down; the LTD comes stitched or "Q-Bond" (one ultrasonically fused panel; weights to be confirmed).

**Free race sails: AC-3 (3 cams) and AC-2 (2 cams).**

| AC-3 (026) | 5.4 | 5.9 | 6.8 | 7.3 | 7.8 | 8.2 |
|---|---|---|---|---|---|---|
| Luff cm | 424 | 442 | 464 | 498 | 498 | 498 |
| Boom cm | 180 | 192 | 204 | 210 | 212 | 220 |
| kg | 4.6 | 4.7 | 5.4 | 5.6 | 5.7 | 5.8 |
| Mast | 400 RDM | 400 RDM | 430 SDM | 460 SDM | 460 SDM | 460 SDM |

The AC-1 LTD's body with a 20 % slimmer sleeve: "race-level performance without the physical toll" ([point-7.com](https://point-7.com/zero-26/ac3-racing-026/)).

| AC-2 (025-026) | 4.8 | 5.3 | 5.8 | 6.8 | 7.8 | 8.8 |
|---|---|---|---|---|---|---|
| Luff cm | 391 | 424 | 440 | 463 | 497 | 520 |
| Boom cm | 174 | 182 | 192 | 204 | 212 | 230 |
| Extension cm | 24 | 26 | 42 | 36 | 40 | 32 |
| kg | 4.3 | 4.5 | 4.7 | 4.8 | 4.9 | 5.0 |
| Battens / cams | 6 / 2 | 6 / 2 | 7 / 2 | 7 / 2 | 7 / 2 | 7 / 2 |
| Mast | 370 RDM | 400 RDM | 400 RDM | 430 SDM | 460 SDM | 490 SDM |

"A good first cam sail": a wide Dacron sleeve below the boom and a narrow one above it, a foot cut to close the gap to the board, smoke black only ([point-7.com](https://point-7.com/zero-25-overview/ac-2-2cam-race-025/)). Point-7 also makes the AC-0 (no-cam race) and the RUSH-1 ("free blaster"); no tables were found for them.

**What makes the shapes recognisable.** Black and smoked film everywhere, the wide race sleeve, and a foot cut straight along the deck.

**Livery** ([AC-1 LTD white](https://point-7.com/wp-content/uploads/2025/09/AC1-ltd_White_026.png), [Q-Bond](https://point-7.com/wp-content/uploads/2025/09/AC1-ltd_Q-Bond_026.png)). The stitched AC-1 LTD: a "White Pearl" body (about #F2F2EE, est.) over "Smoke Black" film and window (about #1E1F22, est.): smoky black dominates the lower and middle sail, with white rectangular blocks near the head and a white strip along the foot; the "P7" logo near the clew and "026" printed at the tack. The Q-Bond: all smoke black with white "7" graphics. Point-7 lists black, white, yellow, green and greys as its films, and a "7548 yellow" (Pantone 7548 C, about #FFC600).

### 2.4 Starboard (game: Moonboard): boards

**Who they are.** Founded in 1994 in Thailand by Svein Rasmussen, a Norwegian who sailed the 1984 Olympics, with the shaper Jean-Louis Colmas, whose wood sandwich became Starboard's trademark construction ([Svein Rasmussen on Wikipedia](https://en.wikipedia.org/wiki/Svein_Rasmussen), [star-board.com](https://star-board.com/pages/windsurfing)). The biggest board brand in the sport, with an eco-minded image (it publishes each board's carbon footprint). Its logo is a small tiki figure. It also makes the iQFOiL Olympic board (the game's default sail is the iQFOiL's Severne HGO). **The only brand that publishes tail widths and thicknesses**, which is why its tables anchor the rules of section 3.

**Slalom boards: iSonic.**

| Size | Volume L | Length cm | Width cm | Tail width cm | Thickness cm | 2026 kg Carbon Reflex | 2026 kg Wood Sandwich | Fin box | Fin cm | Sail m² |
|---|---|---|---|---|---|---|---|---|---|---|
| 60 | 91 | 225 | 60 | 39.2 | 12.0 | 5.70 | - | Tuttle | 28-32 | 5.0-6.2 |
| 63 | 98 | 226 | 63 | 41.4 | 12.2 | 6.05 | 6.10 | Tuttle | 30-34 | 5.5-7.0 |
| 67 | 110 (2025) / 111 (2026) | 228 | 67 | 45.7 | 13.0 | 6.34 | 6.50 | Tuttle | 34-38 | 6.2-7.8 |
| 73 | 123 | 228 | 73 | 50.2 | 13.2 | 6.66 | 7.00 | deep Tuttle | 36-40 | 7.0-8.6 |
| 77 | 129 | 229 | 77 | 54.5 | 12.0 | 6.81 | 7.24 | deep Tuttle | 38-44 | 7.8-9.2 |
| 85 | 147 | 229 | 85 | 60.4 | 12.2 | 7.65 | 8.00 | foil box | 44-48 | 7.8-10.0 |

Sources: [boardsportscalifornia.com, 2026](https://boardsportscalifornia.com/product/2026-starboard-isonic-copy/) ($2,999 to $3,449), [watersportsbase.com, 2025](https://www.watersportsbase.com/product/starboard-isonic-2025/), [star-board.com 2026](https://star-board.com/products/2026-isonic-windsurf-board), [2025](https://star-board.com/products/2025-isonic-windsurf-board), [2027](https://star-board.com/products/2027-isonic-windsurf-board). The 2025 and 2026 boards have the same dimensions; for 2026 the 63, 67 and 73 got new shapes ("revised cutaways" and a "triangle stabilizer"), the 60, 77 and 85 carried over. 2025's changes: the 60 a 5 cm longer central flat and a narrower outline behind the straps; the 67 a 1.5 cm wider tail outline; the 73 widened to 73 cm with 2 cm more width at the back straps; the 85 a wider tail, larger second-step cut-aways and a refined forward vee. All have a "flat vee to double concave" bottom and double-step cut-aways. The 2027 range has the same sizes, with a new 77 (129 L) using the 2026 73's cut-aways. No fin comes with the boards (Starboard recommends its Drake Slalom DW fins of 30 to 40 cm). Also: the iSonic Speed 40, 45 and 52 (55, 65 and 74 L, 227 cm long, tails 22.2, 27.5 and 31.3 cm).

**Free race boards: Futura.**

| | 2025 | | | | | 2026 (Wood Sandwich only) | | | | | | | |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Size | Width cm | Tail cm | kg | Fin cm | | Length cm | Width cm | Tail cm | Thickness cm | kg | Fin box | Fin cm | Sail m² |
| 95 (new 2026) | - | - | - | - | | 225 | 59 | 38.8 | 13.0 | 6.4 | Tuttle | 30-34 | 4.0-6.5 |
| 100 (2025) | 63 | 40.9 | 6.3 | 30-34 | | - | - | - | - | - | - | - | - |
| 105 | 67 | 44.7 | 6.7 | 34-38 | | 229 | 67 | 46.8 | 11.5 | 6.8 | Tuttle | 34-38 | 4.5-7.5 |
| 110 | 71 | 46.6 | 6.8 | 36-40 | | 229 | 71 | 46.6 | 11.5 | 7.0 | deep Tuttle | 36-40 | 5.0-8.0 |
| 120 | 76 | 48.7 | 7.3 | 40-44 | | 230 | 76 | 48.7 | 11.6 | 7.4 | deep Tuttle | 40-44 | 5.5-8.5 |
| 135 | 83 | 52.5 | 8.0 | 42-46 | | 234 | 83 | 52.5 | 11.9 | 8.0 | deep Tuttle | 42-46 | 6.0-9.0 |

Sources: [star-board.com 2026](https://star-board.com/products/2026-futura-windsurf-board), [2025](https://star-board.com/products/2025-futura-windsurf-board), [surfdoctor.com](https://www.surfdoctor.com/products/starboard-futura-2026-wood-sandwich), [surf-magazin.de, Futura 120](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-starboard-futura-120/). The 105's tail is 44.7 cm in the 2025 list and 46.8 cm in the 2026 list although Starboard calls it unchanged: one is a typo. The 95 (for the Défi Wind) has a 90 cm long flat with extra vee; the 110, 120 and 135 got refined cut-aways with the triangle stabilizer. A Drake fin is included. Surf-magazin weighed the 120 at 7.5 kg (€2,799); the mast track is more than a centimetre lower, the front slightly concave; in the 2024 test the Futura had "a wide but thin, spoon-shaped nose with a narrow tail and thick rails" ([surf-magazin.de, 2024](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2024-test-five-fast-boards-for-hobby-racers-compared/)).

**What makes the shapes recognisable.** A short, wide, square outline with the widest point near the middle, double-step cut-aways and (2026) a small triangle between them; a thin, spoon-shaped nose on the Futura.

**Livery.** Starboard's 2026 family look, on the iSonic and the Futura alike ([iSonic picture](https://star-board.com/cdn/shop/files/2026-Starboard-Windsurf-iSonic-Carbon-Reflex-Sandwich-new.jpg?v=1768814785)):
- *iSonic Carbon Reflex deck*: a mid-blue carbon weave (#2B6C95 to #3175A3 measured) with a darker navy band ahead of the tail; two white stripes (#F1F2F5) running from the nose back along the deck either side of the centre, widening toward the mast track like racing stripes; a red-orange tab (#FC1A0D to #FD340A measured) with the white tiki logo on the nose's port side; the tail red-orange, with the size ("73") in big white-outlined block numbers across it; "iSONIC" in small vertical letters by the tail rail; white EVA pads.
- *Bottom*: a bright sky blue (#05B8E8 to #009AC6 measured) with "STARBOARD" in white letters along the centreline, a red-orange nose tip carrying the tiki, and red-orange around the tail and the cut-aways.
- *Futura Wood Sandwich*: the same layout, with natural pine wood (about #D9B48A, est.) instead of the blue carbon on the deck and "FUTURA 120" on the red-orange tail. The Wood Sandwich iSonics are "fresh blue paint and stickers over the natural grain".

### 2.5 NeilPryde (game: NielsTrots): sails

**Who they are.** Founded in Hong Kong in 1970 by Neil Pryde, a New Zealand sailmaker who sailed for Hong Kong at the 1968 Olympics; windsurf sails carried the company from the late 1970s. NeilPryde built the RS:X, the Olympic windsurfer from 2008. The Pryde Group (owned by Shriro) also owns JP Australia and Cabrinha ([Wikipedia](https://en.wikipedia.org/wiki/Neil_Pryde_Ltd.), [industrialhistoryhk.org](https://industrialhistoryhk.org/neil-pryde-founded-fanling-1970/)). Character: loud colours and big "NEILPRYDE" letters; the RS:Racing "holds more world titles and speed records than any other racing sail over the past 20 years" (the brand's claim, [neilpryde.com](https://www.neilpryde.com/products/rs-racing-evoxvii)).

**Slalom sails: RS:Racing EVO XVI (2025), EVO XVII (2026).** Four cams (the retailers' tables), seven battens of which six are pure carbon tubes, a "quadruple luff" sleeve with taffeta in the upper part, carbon ribs on the upper sleeve's leading edge where there are no cams, an "airflow" batten layout, internally printed panels, an ultra-clear window.

| EVO XVII (2026) | Mast | Extension cm | Luff cm | Boom cm | kg |
|---|---|---|---|---|---|
| 4.9 | RDM 370 | 26 | 396 | 166-172 | 4.7 |
| 5.3 | RDM 400 | 16 | 416 | 168-174 | 4.9 |
| 5.6 | RDM 400 | 26 | 426 | 174-180 | 5.0 |
| 6.5 | MDM 430 | 28 | 458 | 186-192 | 5.3 |
| 7.4 | SDM 460 | 26 | 486 | 200-206 | 5.5 |
| 8.2 | SDM 490 | 22 | 512 | 210-216 | 6.1 |
| 9.0 | SDM 520 | 18 | 538 | 220-226 | 6.4 |

Sources: [surf-center.com](https://surf-center.com/en/neilpryde-rs-racing-evo-xvii-2026), [easy-surfshop.com](https://easy-surfshop.com/do/item/N-NP-161032-9596/Windsurf-sail-NeilPryde-RSRacing-EVO-XVII-2026). The 2025 EVO XVI has the same seven sizes ([neilpryde.com](https://www.neilpryde.com/products/rs-racing-evoxvi)); for 2026 only the sizes from 5.6 down changed (from NeilPryde's 2024 speed-record sail; the 5.6 is the 5.7 speed sail with a smaller foot). An older table ([nauticexpo.com](https://www.nauticexpo.com/prod/neilpryde-windsurfing/product-21433-567701.html)) gives 4.9 to 6.5 kg for 4.9 to 9.0.

**Free race sails: V8 (2 cams), Speedster and Speedster EVO (no cams).**

| V8 (2026) | Mast | Extension cm | Luff cm | Boom cm | kg |
|---|---|---|---|---|---|
| 5.7 | RDM 400 | 14 | 413 | 182-188 | 4.1 |
| 6.2 | RDM 400 | 30 | 430 | 188-194 | 4.2 |
| 6.7 | SDM 430 | 18 | 448 | 193-199 | 4.4 |
| 7.2 | SDM 460 | 8 | 467 | 198-204 | 4.5 |
| 7.7 | SDM 460 | 26 | 486 | 203-209 | 4.7 |
| 8.2 | SDM 490 | 16 | 505 | 207-213 | 4.9 |
| 8.7 | SDM 490 | 32 | 522 | 213-220 | 5.1 |
| 9.4 | SDM 520 | 20 | 540 | 218-225 | 5.3 |

"Our original, best-selling power freeride sail": two mini cams, a narrow sleeve, seven battens, for fin and foil; Ultra PE X-ply in the foot and clew for 2026. Sources: [surf-center.com](https://surf-center.com/en/neilpryde-v8-2026), [windlounge.de](https://en.windlounge.de/products/neilpryde-v8-2026), [neilpryde.com](https://www.neilpryde.com/products/v8). The Speedster takes its outline from the RS:Racing and is "the fastest NeilPryde sail without cams"; the Speedster EVO is "sleek, cam-free slalom" (no size table found: [neilpryde.com](https://www.neilpryde.com/products/speedster), [surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/windsurfing-sails/freerace-and-race/no-cam-2026-freeride-sail-testing-the-neilpryde-speedster-evo/)). Prices in Australia: RS:Racing from AUD 2,470, V8 from AUD 1,540 ([shq.com.au](https://www.shq.com.au/collections/sails/neilpryde)).

**What makes the shapes recognisable.** The race sail's high, narrow head, the black carbon-look luff panel and the batten layout raked to follow the sailing rake.

**Livery.** *RS:Racing EVO XVII*, colourway C5 "Purple - Juicy Orange" ([NeilPryde's picture](https://www.neilpryde.com/cdn/shop/files/NP_RS-Racing-Evo-XVII_161032_C5_1_3a298735-4e3c-440a-80e0-76d7bb150f37.jpg?v=1764372585&width=2048)): the upper body a vivid magenta-purple (#D10FAD to #BD1199 measured), printed with fine concentric rings like a target that fade into pink-red toward the boom; a black carbon-look luff panel with "NEILPRYDE" in big orange-red letters running up it; a white, clear window band below the boom with "RS:RACING EVO XVII" in black just under the boom; an orange-red (#F14D36 measured) foot panel and lower luff, an orange head cap and clew patch. The 2025 EVO XVI was C3 "Juicy Orange / Purple".

### 2.6 JP Australia (game: PJ New Sealand): boards

**Who they are.** Founded in spring 1997 and named after Jason Polakow, the Australian wave sailor (the first non-Hawaiian to win a wave world cup in Hawaii, in 1991). The boards are shaped by Werner Gnigler and the brand is run from Kirchdorf, Austria, by JP Marketing GmbH, part of the Pryde Group (with NeilPryde); the boards are made in Thailand ([jp-australia.com](https://jp-australia.com/who-we-are/), [windsurfing-mag.jp](https://windsurfing-mag.jp/jp-australia/)). Character: carbon textures, purple and orange, "S-TEC" for the top construction; strong in wave boards, a long-standing slalom line. **The game's default board is JP's Slalom 72 (2025).**

**Slalom boards: Slalom S-TEC.** Deep Tuttle box (not for foils), no fin; a full biax-carbon deck, high-density PVC sandwich, no paint, compact pads, double strap plugs with four screws per strap, a strap scale and a sail positioning scale.

| Size | 2025 length cm | 2025 volume L | 2025 kg | 2026 length cm | 2026 volume L | 2026 kg | Sail m² (recommended) | Sail m² (ideal) |
|---|---|---|---|---|---|---|---|---|
| 62.5 | 233 | 97 | 5.9 | 230 | 97 | 5.9 | < 7.4 | 5.0-7.0 |
| 66 | 230 | 105 | 6.3 | 230 | 105 | 6.0 | 5.5-8.2 | 5.6-7.8 |
| 72 | 228 | 117 | 6.6 | 228 | 119 | 6.7 | 6.5-8.6 | 7.0-8.2 |
| 76 (new 2025) | 228 | 125 | 6.8 | 228 | 125 | 6.9 | 7.0-9.0 | 7.4-8.6 |
| 85 | 228 | 139 | 7.4 | 228 | 139 | 7.5 | > 7.4 | 7.6-9.0 |

The size is the width in cm. Sources: [jp-australia.com, 2026](https://jp-australia.com/p/windsurfing/boards/slalom-s-tec/), [pooleharbour.co.uk, 2025](https://www.pooleharbour.co.uk/products/jp-slalom-windsurf-board-2025), [24-7boardsports.com, 2025](https://24-7boardsports.com/jp-slalom-2025-windsurfing-board/). JP publishes no tail widths and no fin ranges. The shape: "dual tail outlines": the cut-outs narrow the bottom while the deck above stays wide, so the back straps sit further out; double-step cut-outs (two heights) on the 62.5 and 76 in 2025 and on the 62.5 to 76 in 2026; a pad wedge between the back straps; a thin nose; the rail's apex raised from the middle toward the nose; a concave, aerodynamic deck with a recess at the mast box so the sail's foot seals the gap; a "transforming vee" (deepest ahead of the mast base, narrower between the straps, opening again to the tail); high-apex, full parabolic rails; a compact, parallel middle. The game's model already traces the 2026 72's outline and nose rocker from JP's pictures (`tools/blender/build_rig_models.py`).

**Free race boards: Super Sport (Wood Pro).**

| Size | Length cm | Width cm | kg | Fin included | Fin box | Sail m² (recommended) | Sail m² (ideal) |
|---|---|---|---|---|---|---|---|
| 111 | 234 | 70 | 7.2 | Slalom 40 G10 | foil Tuttle | 5.0-8.2 | 5.7-7.7 |
| 122 | 234 | 76 | 7.8 | Slalom 44 G10 | foil Tuttle | 6.2-9.0 | 6.7-8.2 |
| 133 | 234 | 82 | 8.1 | Slalom 48 G10 | foil Tuttle | > 6.7 | 7.2-9.0 |

Source: [jp-australia.com](https://jp-australia.com/p/windsurfing/boards/super-sport/) (2026; the same in the 2024 test, where it suited "a more traditional, outboard stance"). A parallel outline at the mast base, a wider tail with less volume and tail cut-outs, a concave deck around the mast base, a slalom-derived bottom with "V-flow", thinned rails for jibing; a full paulownia wood bottom. JP also makes the Speed 40 and 45 (45 and 53 L, 227 and 228 cm) ([jp-australia.com](https://jp-australia.com/p/windsurfing/boards/speed/)).

**What makes the shapes recognisable.** The deck's recess around the mast track (visible in the top view as a lighter, sunken area around the track), the wide deck over the narrow stepped bottom at the tail, the pad wedge between the back straps.

**Livery** (JP's 2026 pictures: [top](https://jp-australia.com/wp-content/uploads/2025/11/JP_SLALOM-S-TEC_261224_1-320x1024.webp), [bottom](https://jp-australia.com/wp-content/uploads/2025/11/JP_SLALOM-S-TEC_261224_2-330x1024.webp), [Super Sport](https://jp-australia.com/wp-content/uploads/2025/11/JP_SUPER-SPORT-WOOD-PRO_261214_1-330x1024.webp)):
- *Slalom S-TEC deck*: a mottled purple carbon (#5F4685 measured; the builder script's medians (119, 93, 159) = #775D9F and darker (85, 62, 123) = #553E7B) with a white-outlined "JP" logo on the nose, a lighter purple around the recessed mast track; white and grey pads; the tail a navy band (about #32 2A 47, the builder's (50, 42, 71)) turning orange-red at the very tail (#C04A46 measured), where "SLALOM S-TEC" sits in white with the dimensions ("V119 L229 W72") beside it.
- *Bottom*: purple at the nose fading to navy (#24274B measured) and dark navy toward the tail, with "JP-AUSTRALIA" in orange letters along the centreline near the nose; an orange-red tail tip.
- *Super Sport*: a navy deck (about #2A3050, est.) fading through purple to orange-red at the tail, an orange "JP" on the nose, "SUPER SPORT" with the size by the back straps, grey pads.
- JP's published Pantone colours for the Slalom: 805 C (fluorescent red, about #FF7276), 021 C (orange, #FE5000), 433 C (near-black, #1D252D), 260 C (plum purple, about #5F2167), a mix of 811 C (fluorescent orange, #FF7F41) and 021 C, and 1495 C (orange, #FF8F1C). For the Super Sport: 432 C (dark grey, #333F48), 8480 C (a metallic), 805 C, 433 C, 021 C, 430 C (grey, #7C878E) and 1495 C.
