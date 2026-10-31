# The windsurf brands and their slalom and free race gear

*Research for the game's gear set: part 2 of the fleet and gear plan ([PLAN.md](PLAN.md)), Session 64. Written on 31 October 2026 by the researcher agent on the branch `gear/research`. This is an internal document: it uses the real brand names. The game never does; it uses the team's own names, given in brackets.*

**How to read this.** Section 1 explains in plain language what slalom and free race are and how their boards, sails and fins differ, with a glossary. Section 2 goes brand by brand: the 2025 and 2026 slalom and free race lines, with every size the brands publish, the shapes, the colours and a short history. Section 3 proposes the game's gear set, with every number the physics needs in the units of the config scripts. Section 4 is for the shaper who builds the 3D models. Section 5 lists the questions for the team, and section 6 every source.

**Marks used in the tables.** *pub.*: published by the brand (or a shop's copy of the brand's table). *meas.*: weighed or measured by a magazine. *est.*: our estimate; the rule is always written next to it. Brand tables keep the brands' own units (cm, L, kg); section 3 uses the game's units (m, m², m³, kg).

---

## In short

- **Covered:** all eleven brands Michiel named, in depth: about 45 models of their 2025 and 2026 slalom and free race lines, with some 280 published sizes (boards and sails), their shapes, liveries and histories. Twelve other brands get a paragraph each (about 20 more models).
- **The game's gear set (section 3):** 24 slalom boards and 17 free race boards for the six board brands, 32 slalom sails and 26 free race sails for the seven sail brands, each with the full set of numbers for `BoardConfig`, `SailConfig` and `FinConfig`, and a fin per board.
- **The three findings that matter most for the game:**
  1. **Every brand's sails sit on one geometric curve.** Across seven brands, slalom and free race sails from 5.5 to 9.0 m² all have an aspect ratio (luff² / area) of 2.9 to 3.4, the same as the default 8.0 (3.41), and the game's two sails already match the real ones of their size: the 6.5 (luff 4.60 m, boom 1.95 m) sits between the real 6.5s (luff 4.56 to 4.64 m, boom 1.92 to 1.98 m). What really changes from one size to the next is the area, the boom length and the rig's weight: a complete real rig weighs about 10.0 kg as a 5.6 and 13.7 kg as a 9.0. Nothing in the real sails explains PH14 (a 7.8 slower than a 6.5 in 12 kt): every brand's chart has the bigger sail faster in light wind. The numbers for every real size are now here; the brands sell them in steps of 0.8 to 1.0 m² (the PWA's "Slalom X" steps are 5.7, 6.7 and 7.7; from 2026 the largest fin-race sail allowed is 8.5 m²).
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
| **Length** | 224 to 233 cm. The brands' boards of up to about 118 L are 225 to 233 cm; the wide ones a little shorter (Duotone's 2026 Falcons are 224 to 226 cm, "shorter in every size") | 225 to 249 cm. Most are 229 to 238 cm; Severne's Fox is the longest at 236 to 249 cm |
| **Width and volume** | 52 to 85 cm (52 to 54 cm are speed boards), 74 to 147 L. Brands name their sizes by width (iSonic 73, Slalom 72, Manta 71) or by volume (Falcon 118, Invictus 118) | 59 to 90 cm, 95 to 185 L |
| **Tail width (one foot from the tail)** | Wide: 0.65 to 0.71 of the board's width (iSonic: 39.2 cm on the 60 to 60.4 cm on the 85). A wide tail gives leverage on a big fin | Narrower for the width: 0.63 to 0.69 (Futura: 38.8 cm on the 95 to 52.5 cm on the 135) |
| **Cut-outs** | On every 2026 slalom board: the bottom steps in near the tail, often in two steps of different heights, so less of the bottom is wet at speed while the deck above stays wide for the back straps. FMX's are removable plates | Smaller cut-outs (Futura's "refined cutaways with a triangle stabilizer", the Jag's two-step, the Rocket+'s tail cut-outs, the Fox's "medium cut-outs") |
| **Rails** | Hard, sharp-edged rails in the tail; JP's "high apex, full parabolic" rails; some sizes "more tucked-in in the tail" (Manta 64) | Thinner rails for easier jibes (JP Super Sport), or thick boxy rails with volume aft (surf-magazin) |
| **Rocker** (the bottom's curve along the length) | A flat tail with no kick and a "scoop" toward the nose: the JP 72's bottom rises 6 mm at 1.0 m from the tail, 63 mm at 1.8 m and 205 mm at the tip (traced from JP's side view, in `tools/blender/build_rig_models.py`) | The same slalom-derived flat line (Jag 128: "the planing surface runs straight to the tail without upturn"; Fox 135: 1 mm of tail rocker) |
| **Bottom (vee and concaves)** | A vee or double concave in front to cushion chop, flat or a slight vee (or even an inverted vee) in the tail: iSonic "flat vee to double concave", FMX "double concave, vee to inverse vee", Manta "deep front vee" on the 61 to 71 | More vee for comfort: Jag 110 a flat vee of 7 mm at 33 cm from the tail; Goya Bolt 10 mm; Blitz a "continuous, gentle vee" |
| **Deck** | Concave decks and a recess around the mast track so the rig sits lower (JP, FMX "deep deck concave", Duotone D/LAB). Small, minimal EVA pads; a pad wedge between the back straps (JP) | Bigger, softer pads; concave around the mast base (JP Super Sport, Futura) |
| **Fin box** | Short or medium Tuttle up to about 118 L, deep Tuttle (often foil-approved) on the bigger sizes. No fin included | Deep Tuttle, foil-approved on most; Powerbox on the Fox. A fin included (G10, 36 to 50 cm) |
| **Footstraps** | Far out on the rails; two rows of plugs (FMX), double plugs with four screws per strap (JP) | Inboard and outboard positions, the outer ones "for advanced riders" (Rocket+) |
| **Weight (bare)** | 5.6 to 8.0 kg | 5.8 to 8.8 kg |
| **Construction and price** | Carbon sandwich (iSonic Carbon Reflex, Falcon D/LAB full custom); about €2,400 to €3,700 | Wood or glass-carbon sandwich; about €1,900 to €2,800 |

### 1.3 How the sails differ

| | Slalom race sail | Free race sail |
|---|---|---|
| **Cams** (plastic forks at the batten ends that hold the sail's curve against the mast) | 3 or 4: Point-7 has 3, Severne, NeilPryde, Duotone, GA and S2Maui have 4. North uses an "air cam" (an inflatable sleeve, no hard cams) | 2 or 3 (S_Pace and Overdrive 3, V8, Wicked, Cosmic and AC-2 2), or none (NCX, X_Pace, Free Speed, Banshee) |
| **Battens** | 7 (6 on a few of the smallest sizes) | 6 or 7 |
| **Luff and boom** | At 7.6 to 7.8 m²: luff 4.81 to 4.98 m, boom 2.09 to 2.17 m | At 7.6 to 7.8 m²: luff 4.76 to 4.97 m, boom 2.00 to 2.14 m. Shorter booms are a free race selling point (Overdrive: "10 cm shorter boom") |
| **Mast** | SDM (standard diameter), 100 % carbon, for 6.5 m² and up; RDM (reduced diameter) for 5.9 m² and down. The race sails' size steps follow the mast lengths: about 5.5 to 5.9 on 400, 6.5 to 6.8 on 430, 7.3 to 7.8 on 460, 8.2 to 8.8 on 490 | The same lengths; more of them take RDM masts |
| **Sleeve** | Wide (Point-7 "XXL"), layered (NeilPryde "quadruple luff"): it gives the cams room and makes the front of the sail a stiff wing | About 20 to 33 % narrower (Point-7 AC-3, Severne Overdrive) |
| **Foot** | Long and low, cut to close the gap to the deck (Point-7 "base outline closes the gap to the board"; Severne "single seamless foot panel"). The 2026 trend is a bigger cutaway at the clew (Duotone Warp_Fin, GA Vapor) | A little higher and shorter |
| **Profile** | Deep and locked in the lower sail, flatter and twisting above (S2Maui Venom-XI: "flatter above the boom at battens 4 and 5, locked below at 6 and 7") | Shallower, more twist: easier but with a smaller wind range |
| **Panels and windows** | Vertical luff panels, radial or horizontal body panels; clear or grey film windows in the lower sail | The same layouts, fewer special materials |
| **Weight (sail only)** | 7.4 to 7.8 m²: 5.5 to 6.6 kg (North's moulded 3Di 7.7: 4.7 kg) | 7.7 to 7.8 m²: 4.7 to 5.5 kg with cams, about 4.6 kg without |

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

The middle of these ranges follows the width almost in a straight line: **span ≈ 0.30 + 0.64 × (width − 0.60) m**, which gives 0.38 m for a 72 cm board (the game's default fin is 0.38 m). Duotone recommends 2 to 3 cm more than Starboard and FMX for the same width.

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
| **Tuttle, deep Tuttle, short Tuttle, Powerbox** | The fin box standards. A Tuttle fin has a block held by two screws through the deck; a deep Tuttle is taller (and takes foils); a Powerbox fin is held by a single screw from below, a standard used more on freeride boards |
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

**Who they are.** Founded in 2003 in Australia (2002 in one source) by the sail designer Ben Severne (its CEO and designer in a 2017 profile); based in Perth ([isthmussailboards.com](https://isthmussailboards.com/windsurfing-sail/severne-sails.html), [windsurfing-mag.jp](https://windsurfing-mag.jp/brands/2017/01/5239/)). Antoine Albeau, many times world champion and a speed record holder, is the face of the race sail (he is on every picture of Severne's Mach 9 page). Character: understated and engineered; red race sails; the logo is a "boomerang" mark with "SV". Severne's "Xtended Range" idea is to sell fewer race sizes, each with a wider range ("skip a size up or down"): its race sail comes in only five sizes. **Severne makes no slalom board**; its fast board is the Fox, a performance freeride and free race board.

**Free race board: Fox (version 4).**

| Size | Length cm | Width cm | Fox kg (Powerbox) | Fox Pro kg (Tuttle, 2026) | Sail m² | Fin cm (Fox) | Fin cm (Fox Pro) |
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
- *Slalom S-TEC deck*: a mottled purple carbon (#5F4685 measured; the builder script's medians (119, 93, 159) = #775D9F and darker (85, 62, 123) = #553E7B) with a white-outlined "JP" logo on the nose, a lighter purple around the recessed mast track; white and grey pads; the tail a navy band (about #322A47, the builder's (50, 42, 71)) turning orange-red at the very tail (#C04A46 measured), where "SLALOM S-TEC" sits in white with the dimensions ("V119 L229 W72") beside it.
- *Bottom*: purple at the nose fading to navy (#24274B measured) and dark navy toward the tail, with "JP-AUSTRALIA" in orange letters along the centreline near the nose; an orange-red tail tip.
- *Super Sport*: a navy deck (about #2A3050, est.) fading through purple to orange-red at the tail, an orange "JP" on the nose, "SUPER SPORT" with the size by the back straps, grey pads.
- JP's published Pantone colours for the Slalom: 805 C (fluorescent red, about #FF7276), 021 C (orange, #FE5000), 433 C (near-black, #1D252D), 260 C (plum purple, about #5F2167), a mix of 811 C (fluorescent orange, #FF7F41) and 021 C, and 1495 C (orange, #FF8F1C). For the Super Sport: 432 C (dark grey, #333F48), 8480 C (a metallic), 805 C, 433 C, 021 C, 430 C (grey, #7C878E) and 1495 C.

### 2.7 FMX Racing (game: BMX Boards): boards

**Who they are.** The brand of Finian Maynard, a former world champion and speed sailing record holder (FMX counts 25 world titles and records, 14 of them as a rider and 11 as designer and shaper), who built boards on Maui from 1991. He decided on his own label in 2018 and showed the first boards, all black, at boot Düsseldorf in 2019; he shapes them himself, the factory is Kinetic ([surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/fmx-racing-maynard-with-his-own-brand/), [fmxracing.com](https://www.fmxracing.com/)). Small and race-only: the Invictus (fin slalom and speed), the Hyperion (foil slalom), the Veloce (fast freeride; the LTD "for the expert free racer") and the Diablo (wave). Character: PWA-focused and proud of it ("PWA Slalom-X Constructors Vice-World Champion 2024/2025", the 2024 men's slalom world champion's board), with removable cut-out plates as its signature.

**Slalom boards: Invictus (Pro).** No fin; two rows of strap plugs; "Pro Elite Carbon"; two sets of removable cut-out plates ("RTS, Range Trim System": carbon and high-density PVC) to tune the release; "V5 Vector Cuts"; an inverted-vee bottom (vee and double concave in the nose, an inverted vee in the tail; "double concave reverse vee" on the 74 to 98); a deep deck concave with a recess around the mast box; a "scoop-rocker line"; an "America's Cup grade" bottom finish; a short Tuttle "Strong Box" with double the carbon.

| Size | Length cm | Width cm | 2025 kg | 2026 kg | Fin box | Fin cm | Sail m² |
|---|---|---|---|---|---|---|---|
| 74 (speed) | 229 | 52 | 5.0 | - | short Tuttle | 20-25 | 4.7-7.0 |
| 78 | 233 | 59 | 5.6 | 5.6 | short Tuttle | 28-32 | 4.5-6.5 |
| 88 | 233 | 61 | 5.8 | 5.8 | short Tuttle | 29-33 | 4.7-7.0 |
| 98 | 233 | 63 | 5.95 | 6.0 | short Tuttle | 30-34 | 5.0-7.0 |
| 104 | 233 | 67 | 6.4 | 6.3 | short Tuttle | 32-36 | 5.8-7.8 |
| 108 | 233 | 70 | 6.6 | 6.6 | short Tuttle | 34-38 | 6.3-8.6 |
| 118 | 233 | 72 | 6.8 | 6.85 | short Tuttle | 35-39 | 7.0-8.6 |
| 124 | 228 | 77 | 6.95 | 6.95 | deep Tuttle | 37-41 | 7.0-8.6 |
| 128 | 228 | 81 | 7.3 | 7.2 | deep Tuttle | 39-44 | 7.8-9.2 |
| 138 | 228 | 85 | 7.7 | 7.6 | deep Tuttle | 42-48 | 7.8-9.6 |

The size is the volume. Sources: [fmxracing.com, Invictus Pro 118 (2026)](https://www.fmxracing.com/invictus-pro-118/), [ssi-windsurf.com, Invictus 2025](https://ssi-windsurf.com/en/inicio/72-fmx-racing-invictus-2025.html) (€2,399). The weights leave out the cut-out plates and include 12 extra strap plugs (about 100 g); the foil-Tuttle option adds 200 g. The 2025 boards differ from 2024's only by a "25" on the deck; 2024 brought new noses and cut-outs and new moulds for the 78, 88 and 98. The 118, in FMX's words: "a compact feel with a wide nose, parallel mid-section and curved tail section". For 2026 FMX adds the Invictus Speed F44, F54 and 74.

**Free race boards: Invictus GTR (new 2026).** "Performance freerace slalom": the Invictus outlines in a heavier, more forgiving PVC sandwich of carbon and glass, legal for any slalom race, with the same two sets of cut-out plates.

| Size | Length cm | Width cm | kg | Sail m² |
|---|---|---|---|---|
| 98 | 233 | 63 | 6.5 | 5.0-7.0 |
| 118 | 233 | 72 | 7.4 | 7.0-8.6 |
| 138 | 228 | 85 | 8.2 | 7.8-9.6 |

Sources: [fmxracing.eu](https://www.fmxracing.eu/products/fmx-racing-invictus-2026-gtr), [nicosurf.it](https://nicosurf.it/shop/windsurf/nuovo/tavole/fmx-racing-invictus-gtr-2026/).

**What makes the shapes recognisable.** The longest slalom boards of the field (233 cm up to 118 L), a wide nose, and separate cut-out plates screwed into the tail (visible as panels of a different finish).

**Livery 2026** (FMX's pictures: [Invictus Pro 118](https://www.fmxracing.com/wp-content/uploads/2025/10/2026_invictus_pro_118.png), [GTR 118](https://www.fmxracing.com/wp-content/uploads/2025/11/2026_invictus_gtr_118-263x600.png)): the Pro is bright red all over, deck and bottom (#E51B26 to #DF0E0E measured). On the deck, a forward-pointing chevron of thin white lines runs from both rails to meet on the centreline ahead of the mast track; behind the track a black arrow-shaped panel holds the black pads; FMX's white "vortex" logo (a spinning disc of curved blades, like a sun) sits on the nose's port side; "FMXRACING" runs vertically beside the mast track, "COMMITMENT TO EXCELLENCE" beside it; "INVICTUS PRO" and the dimensions ("233 - 72 - 118") in black on the tail, the tail tip white. The bottom: red with a big white vortex at the nose and "FMXRACING" in big white letters along the centreline. The GTR is the same design in neon green (#0FDE2A measured) with black lines and logo. (The first boards, in 2019, were black.)

### 2.8 North Sails (game: SouthSails): sails

**Who they are.** North Sails is the American sailmaker founded by Lowell North in 1957; today part of the North Technology Group (owned by Oakley Capital). Its windsurf sails were made under licence by Boards & More from 1981 to 2018 (they became Duotone, section 2.1). The North Actionsports Group, based in the Netherlands, relaunched **North Windsurfing** in April 2022 with sails moulded in North's "3Di" technology (a tape laminate first made for yachts): the Wave first, then the X-Over, the Race and the Foil; the team included Chris Williams, Pieter Bijl and the sail designer Niek Huisman ([windsurfjournal.com](https://www.windsurfjournal.com/article,news,the-return-of-north-windsurfing,9324,en), [windsurf.co.uk](https://www.windsurf.co.uk/north-windsurfing-brand-relaunched/), [North Sails on Wikipedia](https://en.wikipedia.org/wiki/North_Sails)). For late 2026 North is bringing back the name **Prisma** for a new race sail in conventional laminate with cams, by the world champion Pierre Mortefon and the designer Alex Udin ([surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/windsurfing-sails/freerace-and-race/new-racing-sail-north-sails-brings-back-the-prisma/)). Character: technical, grey and white, the yacht-sail look; the compass-like "NS" circle logo.

**Slalom sails: Slalom Race (2025), Slalom Race GEN3 3Di (2026), Prisma Fin (late 2026).** An "air cam" (an inflatable sleeve that holds the profile instead of hard cams), split batten pockets and battens, "EZ Clew" (two boom lengths), 3Di "Dyneema aramid tape" with a "Carbon Helix SL" load path, a 3Di composite sleeve.

| Size | 2025 luff cm | 2025 boom cm | 2025 mast | | 2026 GEN3 mast | 2026 extension cm | 2026 luff cm | 2026 boom cm | 2026 kg |
|---|---|---|---|---|---|---|---|---|---|
| 5.2 | 412 | 180 | 400 MDM | | 400 | 6 | 406 | 166 / 169 | 4.10 |
| 6.0 | 443 | 179 (as listed) | 430 MDM | | 430 | 8 | 438 | 180 / 183 | 4.30 |
| 6.8 | 460 | 191 | 430 MDM | | 430 | 26 | 456 | 192 / 196 | 4.50 |
| 7.7 | 489 | 207 | 460 SDM | | 460 or 490 | 32 or 2 | 492 | 210 / 215 | 4.70 |
| 8.6 | 518 | 217 | 490 SDM | | - | - | - | - | - |

Sources: [telstarsurf.com, 2025](https://www.telstarsurf.com/north-sails-slalom-race-117981.html), [surfpirates.de, 2026](https://www.surfpirates.de/NORTH-SAILS-Slalom-Race-Gen3-2026-77m_1) (€2,199 to €2,299), [northactionsports.com](https://northactionsports.com/products/north-slalom-race-2026). The 2025 table lists 7 battens, the 2026 shop 6: one may be a typo. The 2026 8.6 is sold, but its row was not found. The *Prisma Fin* comes in 4.9, 5.4, 6.0, 6.7, 7.7 and 8.4 (€1,099; a sleeve of "MECZ 30", a carbon scrim in the foot, a zip that closes the boom opening; [northactionsports.com](https://northactionsports.com/products/north-prisma-fin-sail)); no luff or boom lengths were published yet.

**Free race sails: Free Speed (no cams, 6 battens) and Freerace (air cam).** Only single sizes were found: the Free Speed 6.0 (2025): luff 432, boom 189, mast 430 or 400 ([telstarsurf.com](https://www.telstarsurf.com/north-sails-free-speed-2025-117979.html)); the Free Speed 7.7 (2024 test): luff 490, boom 204 to 209, mast 460 or 490 ([windsurf.co.uk](https://www.windsurf.co.uk/north-free-speed-7-7m-test-review-2024/)); the Freerace 7.7 (2024 test): luff 492, boom 203 to 206, 6 battens, 3 air cams, mast 460 or 490 MDM ([windsurf.co.uk](https://www.windsurf.co.uk/north-freerace-7-7m-test-review-2024/)).

**What makes the shapes recognisable.** The moulded 3Di membrane: one smooth grey skin with the fibre lines showing through, no panel seams, blue lines along the battens; cut-out window boxes in the lower sail.

**Livery** ([North's picture of the GEN3](https://northactionsports.com/cdn/shop/files/product_image_55000260001_100_01_61037db9-ffd3-4872-a4af-e9d099a9575d_grande.png)): a slate-grey membrane (#5D6F7D to #7F8A97 measured) with a fine pattern of fibre lines; thin royal-blue lines along the battens (about #2E5FB0, est.); North's round "NS" compass logo in a white circle high up near the luff; "RACE" and "NORTH" in small white letters in the middle of the sail; the lower panel cut into white-framed clear windows; the size printed near the head. The 2025 Slalom Race is listed as white ([telstarsurf.com](https://www.telstarsurf.com/north-sails-slalom-race-117981.html)).

### 2.9 S2Maui (game: s3kauai): sails

**Who they are.** "S2" stands for Szpunar and Spanier: the designers Artur Szpunar and Barry Spanier, whose collaboration goes back more than twenty years, founded the brand in 2015 on Maui; Spanier is now "designer emeritus" ([S2Maui 2026 catalogue](https://www.windsurfing44.com/matos/S2Maui/2026/S2Maui_2026_en.pdf), p. 2). The Venom race sail has won two PWA slalom world titles (S2Maui's world champions include Delphine Cousin and Justine Lemeteyer); the team includes Lohan Jules (Défi Wind champion), Brendan Lorho, Bruno Martini, Lina Erzen and Micah Buzianis. Character: many sizes, light materials ("Light-Film" bi-ply instead of monofilm, Technora "Spacelight" in the leech, Dyneema), bright horizontal colour bands. **S2Maui publishes no sail weights.** (The brief's "Kaneda" does not exist at S2Maui; its race sail is the Venom.)

**Slalom sails: Venom-X (2025), Venom-XI (2026).** Four cams ("wide-footprint multi-roller cams"), seven battens of carbon and fibreglass tubes, a fixed head; "multiple, full-length vertical luff panels"; two stainless clew eyelets. The 2026 profile is flatter above the boom (battens 4 and 5) and locked below it (6 and 7), with a "turbo leech" that opens progressively.

| Size (2025 / 2026) | Mast | IMCS | Luff cm | Boom cm | Extension cm |
|---|---|---|---|---|---|
| 4.7 | 370 | 17 | 393 | 171 / 169 | 23 |
| 5.0 / 5.1 | 400 | 19 | 405 | 174 / 171 | 5 |
| 5.6 | 400 | 19 | 413 | 185 / 182 | 13 |
| 6.1 | 430 | 21 | 434 | 191 / 187 | 4 |
| 6.7 | 430 | 21 | 460 | 202 / 199 | 30 |
| 7.5 / 7.6 | 460 | 25 | 481 | 217 / 214 | 21 |
| 8.2 | 460 | 25 | 491 | 229 / 226 | 31 |
| 9.0 | 490 | 29 | 516 | 240 | 26 |

Sources: the S2Maui catalogues for [2025](https://www.windsurfing44.com/matos/S2Maui/2025/S2Maui_2025_en.pdf) and [2026](https://www.windsurfing44.com/matos/S2Maui/2026/S2Maui_2026_en.pdf) (the column "downhaul" is the extension: mast plus downhaul equals the luff), [windforce.ca](https://windforce.ca/products/s2-maui-venom-2025). The two boom lengths are the two clew eyelets.

**Free race sails: Wicked (2 cams), Banshee (no cams, "RAF").**

| Wicked (2025 and 2026) | 4.6 | 5.2 | 5.8 | 6.3 | 6.7 | 7.0 | 7.6 | 8.2 |
|---|---|---|---|---|---|---|---|---|
| Mast | 370 | 400 | 430 | 430 | 430 | 430 | 460 | 460 |
| Luff cm | 389 | 413 | 433 | 435 | 456 | 458 | 476 | 489 |
| Boom cm | 163 | 171 | 182 | 192 | 198 | 204 | 212 | 224 |
| Extension cm | 19 | 13 | 3 | 5 | 26 | 28 | 16 | 29 |

"Venom-derived performance in a more forgiving package", seven battens, "one of the lightest production free race sails"; it won the 2024 IFCA youth and junior slalom worlds. Sources: [2026 catalogue](https://www.windsurfing44.com/matos/S2Maui/2026/S2Maui_2026_en.pdf), [windforce.ca](https://windforce.ca/products/s2-maui-wicked-2025).

| Banshee (2026, 6 battens, no cams) | 5.8 | 6.4 | 7.0 | 7.6 | 8.2 |
|---|---|---|---|---|---|
| Mast | 430 | 430 | 460 | 460 | 460 |
| Luff cm | 436 | 443 | 464 | 478 | 487 |
| Boom cm | 177 | 188 | 198 | 209 | 219 |

**What makes the shapes recognisable.** Wide horizontal bands of colour across the whole sail, and two clew eyelets.

**Livery** (the catalogue's pictures, pp. 46 to 50): the Venom-XI in horizontal bands: sky blue (#00B5FF measured) across the upper panels, two orange bands (#FC6501 measured) around and just above the boom, a white and clear lower body outlined in black; red-orange battens; a black luff panel strip; the "S2MAUI" logo (a red "S2" with an orange swoosh and "MAUI") on the lower sail under the orange band; "VENOM-XI" in black with an orange "XI" across the foot. New for 2026: a "Hot Yellow" Dyneema foot panel on some models.

### 2.10 Tabou (game: Forbidden): boards

**Who they are.** Founded by the French shaper Fabien Vollenweider, who flew from Marseille to Maui in 1990 and made the first Tabou there in 1991; he still shapes, now near Marseille, and is a shareholder ([tabou-boards.com](https://tabou-boards.com/boards/), [easy-surfshop.com](https://easy-surfshop.com/tabou)). Tabou shares its distribution with GA Sails (section 2.11), so the brands' teams sail each other's gear. Character: colourful, cartoon-like graphics with hexagons and a line-drawn figure as logo; the colours change every year.

**Slalom boards: Manta** ("Team" construction; the size is the width).

| Size | Length cm | Width cm | Volume L | kg (± 10 %) | Fin box |
|---|---|---|---|---|---|
| 48 Speed Custom | 228 | 48 | 64 | 4.7 | short Tuttle |
| 54 Speed Custom | 228 | 54 | 75 | 5.4 | short Tuttle |
| 61 | 233 | 61 | 96 | 6.1 | short Tuttle |
| 64 | 233 | 64 | 102 | not given | short Tuttle |
| 66 | 233 | 66 | 106 | 6.2 | short Tuttle |
| 71 | 233 | 71 | 116 | 6.8 | short Tuttle |
| 77 | 232 | 77 | 122 | 7.4 | deep Tuttle foil box |
| 85 | 232 | 85 | 135 | 7.8 | deep Tuttle foil box |

The same table for 2025 and 2026. Sources: [tabou-boards.com, 2026](https://tabou-boards.com/boards/manta/), [2025](https://tabou-boards.com/archive/windsurf-boards-2025/manta-2025/). Tabou publishes no tail widths, fin ranges or sail ranges. Large cut-outs, designed per size; an extra tail vee; a deep front vee on the 61 to 71 for chop; a lowered mast track; "more tucked-in rails in the tail" on the 64; an EPS core, PVC, glass and carbon shells.

**Free race boards: Rocket+** ("the best freerace performance"; listed under freeride; a fin included).

| Size | Length cm | Width cm | kg MTE / LTD / Team | Fin box | Fin included |
|---|---|---|---|---|---|
| 103 | 232 | 69 | - / 7.2 / 6.7 | Tuttle | MFC 36 HF Ride |
| 113 | 232 | 73 | - / 7.6 / 6.9 | foil box (deep Tuttle) | MFC 38 |
| 123 | 232 | 77 | 9.0 / 7.9 / 7.5 | foil box | MFC 40 |
| 133 | 232 | 81 | 9.3 / 8.1 / 7.9 | foil box | MFC 44 |
| 143 | 232 | 85 | 9.6 / 8.7 / 8.3 | foil box | MFC 46 |

Source: [tabou-boards.com](https://tabou-boards.com/boards/rocket-plus/) (2026). A low entry rocker, a deeper vee in the nose, a slight vee in the tail, extra tail volume, tail cut-outs, a rounder deck at the back straps, several strap positions. In surf-magazin's 2024 test it was the widest of five 110 L boards; in 2026 its "Fifty" was the free race board best suited to foiling. (Also: the Rocket, freeride; the Bullitt, a 258 cm long freeride board.)

**What makes the shapes recognisable.** Big cut-outs shown in a contrasting colour (magenta in 2026); hexagonal pads and graphics.

**Livery.**
- *Manta 2026* ([Tabou's picture](https://tabou-boards.com/wp-content/uploads/2025/10/2026-Tabou-Manta-Duo.png); published main colour Pantone 313 C, about #0092BC, second colour Pantone Rubine Red C, about #CE0058): the deck cyan-blue at the nose and the rails (#1879B4 measured) fading to violet across the middle (#7966A3 measured); dark navy pads (#132238 measured) cut as hexagons with white outlines; hexagon outlines and the logo on the nose; a yellow line-drawn figure in the middle of the deck; "MANTA" in navy and white by the tail rail; the cut-out steps and the tail edge magenta (#E34978 measured). The bottom sky blue (#5CCAFD measured) with "TABOU" in big navy outline letters near the nose.
- *Manta 2025*: Pantone 185 C (red, about #E4002B) and white.
- *Rocket+ 2026* ([picture](https://tabou-boards.com/wp-content/uploads/2025/10/TABOU_2026-Tabou-Rocket-Plus-113-LTD_242.png); Pantone 032 C, about #EF3340, and 309 C, about #003B49): a red deck fading to deep plum and dark teal across the middle; light sky-blue pads (about #9AD7EE, est.); hexagon outlines and the logo on the nose; "ROCKET+ 113 LTD" in light blue by the mast track.

### 2.11 GA Sails (game: GG Sails): sails

**Who they are.** Gaastra is a Dutch sailmaker founded in 1897 by Douwe Gaastra in Sneek, Friesland; it made windsurf sails from 1980, for riders such as Robby Naish and Pete Cabrinha. In 2014 the sails took the "GA" logo (first on the Vapor, then the whole 2015 range), partly to keep them apart from the Gaastra clothing brand; they are now "GA Sails" ([windsurfjournal.com](https://www.windsurfjournal.com/article,news,gaastra-devient-presque-ga-sails,2948), [isthmussailboards.com](https://isthmussailboards.com/windsurfing-sail/gaastra-sails.html)). It shares its distribution and team with Tabou. Character: bright cyan, magenta and lime, with the big "GA" logo whose "A" is a triangle with a shark.

**Slalom sails: Vapor.** Four cams, seven battens, a fixed head.

| Size | Luff cm | Boom cm | Mast | IMCS | Extension cm | kg | 2025 luff cm | 2025 extension cm |
|---|---|---|---|---|---|---|---|---|
| 5.3 | 405 | 177 | 400 RDM | 19 | 6 | 5.07 | 406 | 6 |
| 5.7 | 425 | 187 | 400 RDM | 19 | 26 | 5.27 | 424 | 24 |
| 6.7 | 461 | 196 | 430 SDM | 21 | 32 | 5.80 | 464 | 34 |
| 7.7 | 494 | 209 | 460 SDM | 25 | 34 | 6.15 | 496 | 36 |
| 8.4 (2026) / 8.7 (2025) | 515 | 217 | 490 SDM | 29 | 26 | 6.39 | 528 | 38 |

Sources: [ga-windsurfing.com](https://ga-windsurfing.com/sails/vapor/) (2026), [easy-surfshop.com 2026](https://easy-surfshop.com/do/item/N-GA-020126NA-SL/Windsurf-sail-GA-Sails-Vapor-2026), [2025](https://easy-surfshop.com/do/item/N-GA-25-VAPOR/Windsurf-sail-GA-Sails-Vapor-2025) (RRP from €1,399). New for 2026: "Project 85" aramid in the whole sleeve and the batten pockets, a coloured monofilm foot panel, a reworked twist and more mid-sleeve tension for close reaching, a bigger clew cut-out, a "continuous radial panel layout" (panels radiating from the sail's centre, no cross seams) and a cross batten. Colourway C1 Blue.

**Free race sails: Cosmic** (2 mini cams, 7 battens, a "race-inspired outline with a wide undercut", the continuous radial panels new for 2026, a moderate tension).

| Size | Luff cm | Boom cm | Extension cm | Mast | 2022-23 kg |
|---|---|---|---|---|---|
| 5.7 | 424 | 182 | 24 | 400 RDM | - |
| 6.2 | 448 | 187 | 18 | 430 SDM | 4.6 |
| 6.7 | 465 | 195 | 36 | 430 SDM | 4.8 |
| 7.2 | 481 | 202 | 22 | 460 SDM | 4.9 |
| 7.7 | 492 | 212 | 32 | 460 SDM | 5.1 |
| 8.3 | 503 | 220 | 14 | 490 SDM | 5.3 |
| 9.0 | 518 | 235 | 28 | 490 SDM | 5.6 |

Sources: [ga-windsurfing.com](https://ga-windsurfing.com/sails/cosmic/), [windlounge.de](https://en.windlounge.de/products/ga-sails-cosmic-2026) (2026 weights "to be announced"), [ga-windsurfing.com, Cosmic 2022](https://ga-windsurfing.com/media/archive/products-2022/cosmic-2022/) (the older weights, with 1 to 3 cm shorter luffs and booms). GA also makes the Matrix (no cams).

**What makes the shapes recognisable.** The giant "GA" on the upper luff, the lime battens and the radial panels.

**Livery** ([Vapor 2026](https://tabou-boards.com/wp-content/uploads/2025/10/2026GA_VAPOR-800x800.png), [Cosmic 2026](https://tabou-boards.com/wp-content/uploads/2025/09/2026GA_COSMIC_C1-1-800x800.png)): the Vapor's body cyan blue (#009CCD measured) with a darker teal-blue luff panel (#357A98 measured); the huge "GA" logo high on the luff panel (a black "G" with diagonal stripes beside a magenta triangle (#CA4CA2 measured, a vivid magenta in the drawing) holding a black shark); the leech side lighter and clear, with "GA-SAILS" in lime-yellow outline letters running down it; lime-yellow battens (about #D7E83A, est.); magenta tape along the leech and the foot; a white foot panel with the "VAPOR" logo and magenta, yellow and cyan bars; a navy sleeve bottom.

### 2.12 Other slalom and free race brands worth knowing

- **Patrik** (boards and sails): the brand of Patrik Diethelm, a former PWA slalom racer turned shaper; Max sails a Patrik 115 (its layout is the game's default). Slalom boards: the new Slalom-X (92, 97 and 115 L, 232 cm, 60 to 70.5 cm; "a refined rocker with a slight tail kick", a slight vee under the back foot and a double concave between the front straps), the premium Slalom AirInside V2 (95 to 140 L, 5.12 to 6.46 kg, made in Ukraine, €3,399 to €3,699) and the standard Slalom (85 to 150 L, on close-out; graphics by Fabio Canella); free race: the F-Race ("racer with comfort" in surf-magazin's 2026 test) ([patrikinternational.com](https://www.patrikinternational.com/en/shop/windsurfing/windsurf-boards/patrik-slalom-x.html), [Slalom AirInside](https://www.patrikinternational.com/en/shop/windsurfing/windsurf-boards/slalom-airinside-v2.html)).
- **Goya Windsurfing**: the Bolt free race board (Bolt 4 Carbon 2024-25: 99 to 139 L, full carbon deck, racing tail cut-outs; the Bolt "offers the purest racing feel with the fewest compromises" in the 2026 test) and the Mark (no cams, 6 battens) and Mark 2 (2 cams) free race sails ([hydrostationwatersports.com](https://hydrostationwatersports.com/shop/goya-bolt-4-carbon-2024-2025/), [goyawindsurfing.com](https://goyawindsurfing.com/sails/y2022/mark-2/)).
- **Loft Sails** (designer Monty Spindler): the Racingblade, a "purpose-built fin slalom sail" in 5.2, 5.8, 6.6, 7.4 and 8.2 for 2026 (a higher aspect ratio, "TekCam III" cams 35 % lighter, Kevlar radials from the clew to the sleeve; €1,199 to €1,359), the Skyblade (foil) and the Formulablade ([loftsails.com](https://www.loftsails.com/products/racingblade-7-4-white-2026), [easy-surfshop blog](https://blog.easy-surfshop.com/racingblade-2026-just-landed/)).
- **Challenger Sails (CHS)** (Italy; hand-built by Claudio Badiali): won the PWA slalom title in 2022 with Maciek Rutkowski; the SLX fin slalom sail (€1,399 to €1,649) and the Fluido T3 (3 cams, 7 battens, freeride to free race, registered for the 2025 PWA) ([chswindsolutions.com](https://chswindsolutions.com/shop/vele-sails/fluido-t3/), [challengersails.co.uk](https://challengersails.co.uk/)).
- **Avanti Sails**: the Machine race sail ("the first membrane sail to win a PWA World Cup event"), carbon booms from 2019; no 2025 race sail table found ([avantisails.com](https://avantisails.com/22-sails/machine-m-9/)).
- **Simmer Style** (sail designer Tomas Persson): the S-Max 2025 slalom sail (5.5, 6.0, 6.5, 7.1, 7.8, 8.5; TekCam, for SDM or RDM by swapping the bottom cam) and the Evoq ([simmerstyle.com](https://simmerstyle.com/product/2025-s-max/)).
- **Exocet**: the RS V6 Carbon fin slalom board, new for 2026 (80, 95, 110 and 140 L, all 232 cm, 58 to 85 cm, 6.11 to 8.65 kg), the RF V4 foil slalom and the Scross V3 free race (115, 125, 145 L) ([exocet-original.com](https://www.exocet-original.com/products/rs-v6-carbon-71), [windsurf.co.uk](https://www.windsurf.co.uk/exocet-2024/)).
- **Sonntag** (Germany): not sails but **custom carbon fins**, handmade by Jörg Sonntag for slalom, Formula and speed (the SL-P slalom fin from 30 to 53 cm, rake 7.5 to 12 degrees; the SL-S slalom-speed fin) ([sonntag-fins.com](https://sonntag-fins.com/)).
- **Carbon Art** (New Zealand): custom hand-built boards since 1995, slalom shapes developed with Phil McGain on Maui and registered for the PWA (SL 78 to SL 99; "RTS cut-outs with a turbo tab"; 5.1 to 6.2 kg) ([carbonartwindsurf.com](https://www.carbonartwindsurf.com/boards/slalom/)).
- **AV Boards**: custom speed and slalom boards; a 2027 collection with two new speed and three new slalom shapes ([avboards.com](https://www.avboards.com/)).
- **I-99** (Italy, "NoveNove", Cesare Cantagalli): the AM·PRO slalom series shaped by Patrizio Pelizzaro with Thomas Fauster at Lake Garda (SL 61: 89 L 235 × 61 cm; SL 63: 97 L; SL 73: 125 L; SL 85: 145 L) and the Grand Tour free race board ([i-99.it](https://www.i-99.it/am-pro-slalom/)).
- **Future Fly**: the White Tiger, a "true freerace" board in surf-magazin's 2026 test ([surf-magazin.de](https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/test-2026-ten-freerace-boards-put-to-the-test-highway-to-heaven/)).

---

## 3. The game's gear set

This is a proposal for the gear page (part 5 of the plan) and the shaper (part 4): per game brand the sizes to build, each with the numbers its `.tres` file needs, in the units of `Game/sim/config/board_config.gd`, `sail_config.gd` and `fin_config.gd`. Each entry names the real board or sail it is modelled on. Published numbers come first; every other number comes from one of the rules below, and the last column of the board tables says which of a board's numbers were derived.

What it holds: **24 slalom boards** (five brands, 88 to 135 L), **17 free race boards** (six brands, 98 to 136 L), **32 slalom sails** (seven brands, 5.5 to 9.0 m²) and **26 free race sails** (seven brands, 5.8 to 8.6 m²), and a fin for every board. Savanna (Severne) has no slalom board, because Severne makes none; see the open questions.

### 3.1 The rules for the numbers the brands do not publish

**Boards.**

1. **Length, width, volume, mass** are the brands' (2026 where there is one; the PJ 72 stays the 2025 board of `board_default.tres`).
2. **Tail width one foot from the tail** (`tail_width_m`): Starboard's where published. Otherwise, for a slalom board, **0.848 × width − 0.117 m**, a straight line through Starboard's six iSonics (every one within 0.9 cm); it gives 0.494 m for a 72 cm board, where JP's traced 72 has 0.50 m. For a free race board, **0.571 × width + 0.051 m**, fitted on Starboard's Futura (within 1 cm, except the 105 whose two published tails disagree).
3. **Thickness** (`thickness_m`): Starboard's where published. Otherwise **volume / (k × length × width)**, with k = 0.56 for slalom boards up to 73 cm wide, 0.61 from 77 cm (straight between), 0.59 for free race boards. Starboard's ten published thicknesses give k = 0.559 to 0.564 (iSonic 60 to 73), 0.610 and 0.619 (iSonic 77 and 85) and 0.584 to 0.595 (Futura). For the JP 72 it gives 0.127 m (the default has 0.13). (A first try, solving the thickness from the shape functions of `BoardConfig` calibrated on the default board, came out 3 to 15 mm too thick against Starboard's numbers, so the simpler rule is used.)
4. **Widest point from the tail**: 0.50 × length for slalom (the default: 1.14 of 2.28 m); 0.48 × length for free race (est.: their volume sits further back).
5. **Nose width one foot from the nose**: 0.78 × width for slalom (JP's traced 72: 0.55 to 0.56 m); 0.70 × width for free race (est.: a tapered nose, between JP and the old freeride default's 0.625).
6. **Tail and nose thickness**: 0.045 and 0.040 m for slalom (the default); 0.050 and 0.040 for free race (est.: "thicker, boxier rails").
7. **Mass** (`mass_kg`, "the bare board with straps and fin"): the brand's bare weight + 0.45 kg for four straps and their screws (est.) + the fin: 0.017 kg per cm of a carbon slalom fin, 0.024 kg per cm of the G10 fin a free race board comes with (est.). For the JP 72 this gives 6.6 + 0.45 + 0.65 = 7.70 kg; keep the default's 7.8 for it.
8. **Rocker**: the default's nose rocker (0.128 m) over 0.70 × length; no tail rocker (the brands' "flat tails"; the Fox 0.001 m, measured by surf-magazin); `tail_rocker_length_m` 0.35.
9. **Rails**: hard to 0.526 × length, soft from 0.877 × length (the default's 1.2 and 2.0 m of 2.28 m); `rail_edge_height_m` 0.03 and `deadrise_deg` 1.0 as the default.
10. **Straps**: back straps 0.235 m and front straps 0.825 m from the tail on every board (Max's Patrik 115; est. for the others: the straps sit where the fin and the stance put them, which hardly changes with the length). Out from the centreline: back = 0.5 × tail width − 0.095 m, front = 0.5 × width − 0.11 m (both give Max's 0.15 and 0.25 m on the default). Free race boards also have inboard positions; the outboard ones are given.
11. **Fin box**: screws 0.12 and 0.235 m from the tail on every board (Max's; est. for the others). Keep the fin's root 0.18 m from the tail (`FinConfig.root_local.z` = length / 2 − 0.18).
12. **Mast track**: centred at 0.581 × length from the tail (the default: 1.325 of 2.28 m), 0.16 m long. Put the sail's mast foot 0.02 m ahead of the track's back end, as the default does (`SailConfig.mast_foot_local.z` = length / 2 − (track back + 0.02)).
13. **Fin**: the middle of the brand's recommended range, or the fin it comes with; where the brand gives none, **0.30 + 0.64 × (width − 0.60) m** (section 1.4). The area from Select's tables: the Rhino Pro for slalom boards, the S.MAX for free race boards (its even sizes as the mean of the odd ones around them).
14. **Cut-outs**: the physics' `cutout_from_tail_m` and `cutout_depth_m` stay 0 (off, PH16, Michiel's). For the 3D models, section 4 describes each brand's.

**Sails.**

1. **Area, luff, boom** are the brands' (the boom at its longest setting).
2. **`mast_m` (the masthead above the mast foot)** = the mast's length + the extension, where the brand gives the extension; otherwise **luff + 0.02 m** (the published pairs give mast + extension = the luff to the luff + 2 cm; the default 8.0: 5.22 + 0.04).
3. **`boom_height_m`**: 1.40 m for a luff under 4.40 m, 1.45 m up to 4.80 m, 1.50 m above (est.; the default 8.0 has 1.50, Max's range 1.40 to 1.60).
4. **`camber`** (the profile's depth as a share of the chord): **no brand publishes it**, and the only windsurf sail ever measured is the iQFOiL 8.0 in the wind tunnel (6.3 to 7.6 %; `sail_config.gd`). Proposed: 0.075 for four cams, 0.072 for three cams or North's air cam, 0.070 for two cams, 0.068 for none (est.: cams hold a deeper, locked lower profile; testers describe no-cam sails as flatter in the lulls). Keeping 0.07 on every sail is equally defensible: Michiel's call (PH14).
5. **`rig_mass_kg`**: the real rig is the sail + the mast + the boom + 1.3 kg for the extension, base and lines (the default's own estimate). Masts by length: 370 cm 1.30 kg (est.), 400 cm 1.42 kg (Severne Apex Pro), 430 cm 1.55, 460 cm 1.77, 490 cm 2.07 kg (Apex Team), 520 cm 2.10 kg (Apex Team 530). Booms by the sail's boom: up to 1.80 m 2.23 kg, to 2.00 m 2.61, to 2.15 m 2.68, to 2.30 m 3.49, above 3.52 kg (Severne's Enigma 160-210 to 210-250). Where a brand gives no sail weight, it is estimated from sails of the same type and size (marked). The tables give the real total and, beside it, the same times 9.5 / 12.4: the default 8.0 deliberately keeps 9.5 kg of its real 12.4 kg (`sail_config.gd`, for the tack in 18 kt); which to use is Michiel's call.
6. **`rig_com_height_m`**: 0.345 × luff (the default: 1.8 m for 5.22 m; est.).
7. **`ce_height_fraction`**: 0.41 for race sails (the default 8.0), 0.42 for free race and no-cam sails (est.: a foot cut a little higher and shorter). `ce_boom_fraction` stays 0.35.
8. **Everything else** (the lift and drag curves, the twist, the controls) as the default 8.0; `twist_pressure_pa` per size is a physics question (section 5).

### 3.2 Slalom boards

The shape:

| Modelled on | length_m | width_m | widest_point_from_tail_m | tail_width_m | nose_width_m | thickness_m | tail_thickness_m | nose_thickness_m | volume_m3 | mass_kg (published) | derived |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Moonboard** | | | | | | | | | | | |
| iSonic 60 (2026, Carbon Reflex) | 2.25 | 0.600 | 1.12 | 0.392 | 0.468 | 0.120 | 0.045 | 0.040 | 0.091 | 6.66 (5.70) | - |
| iSonic 63 (2026, CR) | 2.26 | 0.630 | 1.13 | 0.414 | 0.491 | 0.122 | 0.045 | 0.040 | 0.098 | 7.04 (6.05) | - |
| iSonic 67 (2026, CR) | 2.28 | 0.670 | 1.14 | 0.457 | 0.523 | 0.130 | 0.045 | 0.040 | 0.111 | 7.40 (6.34) | - |
| iSonic 73 (2026, CR) | 2.28 | 0.730 | 1.14 | 0.502 | 0.569 | 0.132 | 0.045 | 0.040 | 0.123 | 7.76 (6.66) | - |
| iSonic 77 (2026, CR) | 2.29 | 0.770 | 1.15 | 0.545 | 0.601 | 0.120 | 0.045 | 0.040 | 0.129 | 7.96 (6.81) | - |
| **PJ New Sealand** | | | | | | | | | | | |
| JP Slalom S-TEC 62.5 (2026) | 2.30 | 0.625 | 1.15 | 0.413 | 0.488 | 0.120 | 0.045 | 0.040 | 0.097 | 6.89 (5.90) | tail,thick,fin |
| JP Slalom S-TEC 66 (2026) | 2.30 | 0.660 | 1.15 | 0.443 | 0.515 | 0.124 | 0.045 | 0.040 | 0.105 | 7.03 (6.00) | tail,thick,fin |
| JP Slalom S-TEC 72 (2025 SL 72 = board_default.tres) | 2.28 | 0.720 | 1.14 | 0.490 | 0.562 | 0.130 | 0.045 | 0.040 | 0.117 | 7.80 (6.60) | - (as the default) |
| JP Slalom S-TEC 76 (2026) | 2.28 | 0.760 | 1.14 | 0.527 | 0.593 | 0.121 | 0.045 | 0.040 | 0.125 | 8.03 (6.90) | tail,thick,fin |
| **Tripletone** | | | | | | | | | | | |
| Duotone Falcon_Fin D/LAB 89 (2026) | 2.26 | 0.600 | 1.13 | 0.392 | 0.468 | 0.117 | 0.045 | 0.040 | 0.089 | 6.96 (6.00) | tail,thick,fin |
| Duotone Falcon_Fin SLS 98 (2026) | 2.26 | 0.630 | 1.13 | 0.417 | 0.491 | 0.123 | 0.045 | 0.040 | 0.098 | 7.45 (6.40) | tail,thick |
| Duotone Falcon_Fin SLS 111 (2026) | 2.25 | 0.680 | 1.12 | 0.460 | 0.530 | 0.130 | 0.045 | 0.040 | 0.111 | 8.05 (6.95) | tail,thick |
| Duotone Falcon_Fin SLS 118 (2026) | 2.25 | 0.720 | 1.12 | 0.494 | 0.562 | 0.130 | 0.045 | 0.040 | 0.118 | 8.33 (7.20) | tail,thick |
| Duotone Falcon_Fin SLS 129 (2026) | 2.24 | 0.800 | 1.12 | 0.561 | 0.624 | 0.118 | 0.045 | 0.040 | 0.129 | 8.80 (7.60) | tail,thick |
| **BMX Boards** | | | | | | | | | | | |
| FMX Invictus Pro 88 (2026) | 2.33 | 0.610 | 1.17 | 0.400 | 0.476 | 0.111 | 0.045 | 0.040 | 0.088 | 6.78 (5.80) | tail,thick |
| FMX Invictus Pro 98 (2026) | 2.33 | 0.630 | 1.17 | 0.417 | 0.491 | 0.119 | 0.045 | 0.040 | 0.098 | 6.99 (6.00) | tail,thick |
| FMX Invictus Pro 108 (2026) | 2.33 | 0.700 | 1.17 | 0.477 | 0.546 | 0.118 | 0.045 | 0.040 | 0.108 | 7.66 (6.60) | tail,thick |
| FMX Invictus Pro 118 (2026) | 2.33 | 0.720 | 1.17 | 0.494 | 0.562 | 0.126 | 0.045 | 0.040 | 0.118 | 7.93 (6.85) | tail,thick |
| FMX Invictus Pro 128 (2026) | 2.28 | 0.810 | 1.14 | 0.570 | 0.632 | 0.114 | 0.045 | 0.040 | 0.128 | 8.35 (7.20) | tail,thick |
| **Forbidden** | | | | | | | | | | | |
| Tabou Manta 61 (2026, Team) | 2.33 | 0.610 | 1.17 | 0.400 | 0.476 | 0.121 | 0.045 | 0.040 | 0.096 | 7.08 (6.10) | tail,thick,fin |
| Tabou Manta 66 (2026, Team) | 2.33 | 0.660 | 1.17 | 0.443 | 0.515 | 0.123 | 0.045 | 0.040 | 0.106 | 7.23 (6.20) | tail,thick,fin |
| Tabou Manta 71 (2026, Team) | 2.33 | 0.710 | 1.17 | 0.485 | 0.554 | 0.125 | 0.045 | 0.040 | 0.116 | 7.88 (6.80) | tail,thick,fin |
| Tabou Manta 77 (2026, Team) | 2.32 | 0.770 | 1.16 | 0.536 | 0.601 | 0.112 | 0.045 | 0.040 | 0.122 | 8.55 (7.40) | tail,thick,fin |
| Tabou Manta 85 (2026, Team) | 2.32 | 0.850 | 1.16 | 0.604 | 0.663 | 0.112 | 0.045 | 0.040 | 0.135 | 9.03 (7.80) | tail,thick,fin |

The layout and the fin (all in metres; the strap and box positions from the tail along the centreline, "out" from the centreline):

| Modelled on | nose_rocker_m / _length_m | tail_rocker_m / _length_m | hard_rail_to_m / soft_rail_from_m | back / front strap from tail | back / front strap out | fin box screws from tail | mast track back / front | fin span_m | fin area_m2 | fin (brand's range) |
|---|---|---|---|---|---|---|---|---|---|---|
| **Moonboard** | | | | | | | | | | |
| iSonic 60 (2026, Carbon Reflex) | 0.128 / 1.57 | 0.000 / 0.35 | 1.18 / 1.97 | 0.235 / 0.825 | 0.101 / 0.190 | 0.120 / 0.235 | 1.227 / 1.387 | 0.30 | 0.0226 | 28-32 |
| iSonic 63 (2026, CR) | 0.128 / 1.58 | 0.000 / 0.35 | 1.19 / 1.98 | 0.235 / 0.825 | 0.112 / 0.205 | 0.120 / 0.235 | 1.233 / 1.393 | 0.32 | 0.0247 | 30-34 |
| iSonic 67 (2026, CR) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.00 | 0.235 / 0.825 | 0.134 / 0.225 | 0.120 / 0.235 | 1.245 / 1.405 | 0.36 | 0.0286 | 34-38 |
| iSonic 73 (2026, CR) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.00 | 0.235 / 0.825 | 0.156 / 0.255 | 0.120 / 0.235 | 1.245 / 1.405 | 0.38 | 0.0311 | 36-40 |
| iSonic 77 (2026, CR) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.01 | 0.235 / 0.825 | 0.178 / 0.275 | 0.120 / 0.235 | 1.250 / 1.410 | 0.41 | 0.0344 | 38-44 |
| **PJ New Sealand** | | | | | | | | | | |
| JP Slalom S-TEC 62.5 (2026) | 0.128 / 1.61 | 0.000 / 0.35 | 1.21 / 2.02 | 0.235 / 0.825 | 0.112 / 0.203 | 0.120 / 0.235 | 1.256 / 1.416 | 0.32 | 0.0247 | - |
| JP Slalom S-TEC 66 (2026) | 0.128 / 1.61 | 0.000 / 0.35 | 1.21 / 2.02 | 0.235 / 0.825 | 0.126 / 0.220 | 0.120 / 0.235 | 1.256 / 1.416 | 0.34 | 0.0267 | - |
| JP Slalom S-TEC 72 (2025 SL 72 = board_default.tres) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.00 | 0.235 / 0.825 | 0.150 / 0.250 | 0.120 / 0.235 | 1.245 / 1.405 | 0.38 | 0.0311 | - |
| JP Slalom S-TEC 76 (2026) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.00 | 0.235 / 0.825 | 0.169 / 0.270 | 0.120 / 0.235 | 1.245 / 1.405 | 0.40 | 0.0333 | - |
| **Tripletone** | | | | | | | | | | |
| Duotone Falcon_Fin D/LAB 89 (2026) | 0.128 / 1.58 | 0.000 / 0.35 | 1.19 / 1.98 | 0.235 / 0.825 | 0.101 / 0.190 | 0.120 / 0.235 | 1.233 / 1.393 | 0.30 | 0.0226 | est. |
| Duotone Falcon_Fin SLS 98 (2026) | 0.128 / 1.58 | 0.000 / 0.35 | 1.19 / 1.98 | 0.235 / 0.825 | 0.114 / 0.205 | 0.120 / 0.235 | 1.233 / 1.393 | 0.35 | 0.0278 | 34-36 |
| Duotone Falcon_Fin SLS 111 (2026) | 0.128 / 1.57 | 0.000 / 0.35 | 1.18 / 1.97 | 0.235 / 0.825 | 0.135 / 0.230 | 0.120 / 0.235 | 1.227 / 1.387 | 0.38 | 0.0311 | 36-40 |
| Duotone Falcon_Fin SLS 118 (2026) | 0.128 / 1.57 | 0.000 / 0.35 | 1.18 / 1.97 | 0.235 / 0.825 | 0.152 / 0.250 | 0.120 / 0.235 | 1.227 / 1.387 | 0.40 | 0.0333 | 38-42 |
| Duotone Falcon_Fin SLS 129 (2026) | 0.128 / 1.57 | 0.000 / 0.35 | 1.18 / 1.96 | 0.235 / 0.825 | 0.186 / 0.290 | 0.120 / 0.235 | 1.221 / 1.381 | 0.44 | 0.0378 | 42-46 |
| **BMX Boards** | | | | | | | | | | |
| FMX Invictus Pro 88 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.105 / 0.195 | 0.120 / 0.235 | 1.274 / 1.434 | 0.31 | 0.0236 | 29-33 |
| FMX Invictus Pro 98 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.114 / 0.205 | 0.120 / 0.235 | 1.274 / 1.434 | 0.32 | 0.0247 | 30-34 |
| FMX Invictus Pro 108 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.143 / 0.240 | 0.120 / 0.235 | 1.274 / 1.434 | 0.36 | 0.0286 | 34-38 |
| FMX Invictus Pro 118 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.152 / 0.250 | 0.120 / 0.235 | 1.274 / 1.434 | 0.37 | 0.0296 | 35-39 |
| FMX Invictus Pro 128 (2026) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.00 | 0.235 / 0.825 | 0.190 / 0.295 | 0.120 / 0.235 | 1.245 / 1.405 | 0.41 | 0.0344 | 39-44 |
| **Forbidden** | | | | | | | | | | |
| Tabou Manta 61 (2026, Team) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.105 / 0.195 | 0.120 / 0.235 | 1.274 / 1.434 | 0.31 | 0.0236 | - |
| Tabou Manta 66 (2026, Team) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.126 / 0.220 | 0.120 / 0.235 | 1.274 / 1.434 | 0.34 | 0.0267 | - |
| Tabou Manta 71 (2026, Team) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.148 / 0.245 | 0.120 / 0.235 | 1.274 / 1.434 | 0.37 | 0.0296 | - |
| Tabou Manta 77 (2026, Team) | 0.128 / 1.62 | 0.000 / 0.35 | 1.22 / 2.03 | 0.235 / 0.825 | 0.173 / 0.275 | 0.120 / 0.235 | 1.268 / 1.428 | 0.41 | 0.0344 | - |
| Tabou Manta 85 (2026, Team) | 0.128 / 1.62 | 0.000 / 0.35 | 1.22 / 2.03 | 0.235 / 0.825 | 0.207 / 0.315 | 0.120 / 0.235 | 1.268 / 1.428 | 0.46 | 0.0405 | - |

Not built, but available if the team wants a bigger light-wind board: the iSonic 85 (147 L, 229 × 85 cm, tail 0.604, 0.122 thick, 7.65 kg, fin 44 to 48 cm), the JP 85 (139 L, 228 × 85, 7.5 kg), the Falcon_Fin SLS 139 (224 × 85, 7.95 kg, fin 46 to 50) and the Invictus 138 (228 × 85, 7.6 kg, fin 42 to 48).

### 3.3 Free race boards

The shape:

| Modelled on | length_m | width_m | widest_point_from_tail_m | tail_width_m | nose_width_m | thickness_m | tail_thickness_m | nose_thickness_m | volume_m3 | mass_kg (published) | derived |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Moonboard** | | | | | | | | | | | |
| Starboard Futura 110 (2026, Wood Sandwich) | 2.29 | 0.710 | 1.10 | 0.466 | 0.497 | 0.115 | 0.050 | 0.040 | 0.110 | 8.36 (7.00) | - |
| Starboard Futura 120 (2026, WS) | 2.30 | 0.760 | 1.10 | 0.487 | 0.532 | 0.116 | 0.050 | 0.040 | 0.120 | 8.86 (7.40) | - |
| Starboard Futura 135 (2026, WS) | 2.34 | 0.830 | 1.12 | 0.525 | 0.581 | 0.119 | 0.050 | 0.040 | 0.135 | 9.51 (8.00) | - |
| **PJ New Sealand** | | | | | | | | | | | |
| JP Super Sport 111 (2026, Wood Pro) | 2.34 | 0.700 | 1.12 | 0.451 | 0.490 | 0.115 | 0.050 | 0.040 | 0.111 | 8.61 (7.20) | tail,thick |
| JP Super Sport 122 (2026) | 2.34 | 0.760 | 1.12 | 0.485 | 0.532 | 0.116 | 0.050 | 0.040 | 0.122 | 9.31 (7.80) | tail,thick |
| JP Super Sport 133 (2026) | 2.34 | 0.820 | 1.12 | 0.519 | 0.574 | 0.117 | 0.050 | 0.040 | 0.133 | 9.70 (8.10) | tail,thick |
| **Tripletone** | | | | | | | | | | | |
| Duotone Blitz SLS 116 (2026) | 2.34 | 0.680 | 1.12 | 0.439 | 0.476 | 0.124 | 0.050 | 0.040 | 0.116 | 8.36 (7.00) | tail,thick |
| Duotone Blitz SLS 126 (2026) | 2.35 | 0.710 | 1.13 | 0.456 | 0.497 | 0.128 | 0.050 | 0.040 | 0.126 | 8.86 (7.40) | tail,thick |
| Duotone Blitz SLS 136 (2026) | 2.38 | 0.770 | 1.14 | 0.491 | 0.539 | 0.126 | 0.050 | 0.040 | 0.136 | 9.31 (7.80) | tail,thick |
| **BMX Boards** | | | | | | | | | | | |
| FMX Invictus GTR 98 (2026) | 2.33 | 0.630 | 1.12 | 0.411 | 0.441 | 0.113 | 0.050 | 0.040 | 0.098 | 7.72 (6.50) | tail,thick |
| FMX Invictus GTR 118 (2026) | 2.33 | 0.720 | 1.12 | 0.462 | 0.504 | 0.119 | 0.050 | 0.040 | 0.118 | 8.74 (7.40) | tail,thick |
| **Forbidden** | | | | | | | | | | | |
| Tabou Rocket+ 113 (2026, LTD) | 2.32 | 0.730 | 1.11 | 0.468 | 0.511 | 0.113 | 0.050 | 0.040 | 0.113 | 8.96 (7.60) | tail,thick |
| Tabou Rocket+ 123 (2026, LTD) | 2.32 | 0.770 | 1.11 | 0.491 | 0.539 | 0.117 | 0.050 | 0.040 | 0.123 | 9.31 (7.90) | tail,thick |
| Tabou Rocket+ 133 (2026, LTD) | 2.32 | 0.810 | 1.11 | 0.514 | 0.567 | 0.120 | 0.050 | 0.040 | 0.133 | 9.61 (8.10) | tail,thick |
| **Savanna** | | | | | | | | | | | |
| Severne Fox Pro 105 (2026) | 2.39 | 0.650 | 1.15 | 0.422 | 0.455 | 0.115 | 0.050 | 0.040 | 0.105 | 7.38 (6.07) | tail,thick |
| Severne Fox Pro 115 (2026) | 2.41 | 0.690 | 1.16 | 0.445 | 0.483 | 0.117 | 0.050 | 0.040 | 0.115 | 7.90 (6.49) | tail,thick |
| Severne Fox Pro 125 (2026) | 2.44 | 0.710 | 1.17 | 0.456 | 0.497 | 0.122 | 0.050 | 0.040 | 0.125 | 8.25 (6.79) | tail,thick |

The layout and the fin:

| Modelled on | nose_rocker_m / _length_m | tail_rocker_m / _length_m | hard_rail_to_m / soft_rail_from_m | back / front strap from tail | back / front strap out | fin box screws from tail | mast track back / front | fin span_m | fin area_m2 | fin (brand's range) |
|---|---|---|---|---|---|---|---|---|---|---|
| **Moonboard** | | | | | | | | | | |
| Starboard Futura 110 (2026, Wood Sandwich) | 0.128 / 1.60 | 0.000 / 0.35 | 1.20 / 2.01 | 0.235 / 0.825 | 0.138 / 0.245 | 0.120 / 0.235 | 1.250 / 1.410 | 0.38 | 0.0301 | 36-40 |
| Starboard Futura 120 (2026, WS) | 0.128 / 1.61 | 0.000 / 0.35 | 1.21 / 2.02 | 0.235 / 0.825 | 0.148 / 0.270 | 0.120 / 0.235 | 1.256 / 1.416 | 0.42 | 0.0345 | 40-44 |
| Starboard Futura 135 (2026, WS) | 0.128 / 1.64 | 0.000 / 0.35 | 1.23 / 2.05 | 0.235 / 0.825 | 0.168 / 0.305 | 0.120 / 0.235 | 1.280 / 1.440 | 0.44 | 0.0370 | 42-46 |
| **PJ New Sealand** | | | | | | | | | | |
| JP Super Sport 111 (2026, Wood Pro) | 0.128 / 1.64 | 0.000 / 0.35 | 1.23 / 2.05 | 0.235 / 0.825 | 0.130 / 0.240 | 0.120 / 0.235 | 1.280 / 1.440 | 0.40 | 0.0322 | Slalom 40 G10 |
| JP Super Sport 122 (2026) | 0.128 / 1.64 | 0.000 / 0.35 | 1.23 / 2.05 | 0.235 / 0.825 | 0.147 / 0.270 | 0.120 / 0.235 | 1.280 / 1.440 | 0.44 | 0.0370 | Slalom 44 G10 |
| JP Super Sport 133 (2026) | 0.128 / 1.64 | 0.000 / 0.35 | 1.23 / 2.05 | 0.235 / 0.825 | 0.165 / 0.300 | 0.120 / 0.235 | 1.280 / 1.440 | 0.48 | 0.0418 | Slalom 48 G10 |
| **Tripletone** | | | | | | | | | | |
| Duotone Blitz SLS 116 (2026) | 0.128 / 1.64 | 0.000 / 0.35 | 1.23 / 2.05 | 0.235 / 0.825 | 0.125 / 0.230 | 0.120 / 0.235 | 1.280 / 1.440 | 0.38 | 0.0301 | F_Ride 38 |
| Duotone Blitz SLS 126 (2026) | 0.128 / 1.65 | 0.000 / 0.35 | 1.24 / 2.06 | 0.235 / 0.825 | 0.133 / 0.245 | 0.120 / 0.235 | 1.285 / 1.445 | 0.42 | 0.0345 | F_Ride 42 |
| Duotone Blitz SLS 136 (2026) | 0.128 / 1.67 | 0.000 / 0.35 | 1.25 / 2.09 | 0.235 / 0.825 | 0.150 / 0.275 | 0.120 / 0.235 | 1.303 / 1.463 | 0.44 | 0.0370 | F_Ride 44 |
| **BMX Boards** | | | | | | | | | | |
| FMX Invictus GTR 98 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.110 / 0.205 | 0.120 / 0.235 | 1.274 / 1.434 | 0.32 | 0.0242 | 30-34 |
| FMX Invictus GTR 118 (2026) | 0.128 / 1.63 | 0.000 / 0.35 | 1.23 / 2.04 | 0.235 / 0.825 | 0.136 / 0.250 | 0.120 / 0.235 | 1.274 / 1.434 | 0.37 | 0.0291 | 35-39 |
| **Forbidden** | | | | | | | | | | |
| Tabou Rocket+ 113 (2026, LTD) | 0.128 / 1.62 | 0.000 / 0.35 | 1.22 / 2.03 | 0.235 / 0.825 | 0.139 / 0.255 | 0.120 / 0.235 | 1.268 / 1.428 | 0.38 | 0.0301 | MFC 38 |
| Tabou Rocket+ 123 (2026, LTD) | 0.128 / 1.62 | 0.000 / 0.35 | 1.22 / 2.03 | 0.235 / 0.825 | 0.150 / 0.275 | 0.120 / 0.235 | 1.268 / 1.428 | 0.40 | 0.0322 | MFC 40 |
| Tabou Rocket+ 133 (2026, LTD) | 0.128 / 1.62 | 0.000 / 0.35 | 1.22 / 2.03 | 0.235 / 0.825 | 0.162 / 0.295 | 0.120 / 0.235 | 1.268 / 1.428 | 0.44 | 0.0370 | MFC 44 |
| **Savanna** | | | | | | | | | | |
| Severne Fox Pro 105 (2026) | 0.128 / 1.67 | 0.001 / 0.35 | 1.26 / 2.10 | 0.235 / 0.825 | 0.116 / 0.215 | 0.120 / 0.235 | 1.309 / 1.469 | 0.36 | 0.0282 | 36 |
| Severne Fox Pro 115 (2026) | 0.128 / 1.69 | 0.001 / 0.35 | 1.27 / 2.11 | 0.235 / 0.825 | 0.127 / 0.235 | 0.120 / 0.235 | 1.320 / 1.480 | 0.40 | 0.0322 | 40 |
| Severne Fox Pro 125 (2026) | 0.128 / 1.71 | 0.001 / 0.35 | 1.28 / 2.14 | 0.235 / 0.825 | 0.133 / 0.245 | 0.120 / 0.235 | 1.338 / 1.498 | 0.42 | 0.0345 | 42 |

The Fox Pro is sold without a fin; its mass assumes the regular Fox's G10 fin of the same length. The Rocket+ is given in the mid-priced LTD construction (the Team is 0.4 to 0.7 kg lighter).

### 3.4 Slalom sails

All in the units of `SailConfig` (m, m², kg). "Mast (cm)" is the recommended mast; `mast_m` adds the extension. The rig mass is the whole rig; see rule 5 for the two columns. The last column says what was estimated beyond the rules that apply to every sail (boom height, camber, centre of effort).

| Modelled on | area_m2 | luff_m | boom_m | mast (cm) | mast_m (mast + extension) | boom_height_m | cams | camber | sail kg | rig_mass_kg real | rig_mass_kg at the default's ratio | ce_height_fraction | aspect ratio (luff²/area) | estimated |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Tripletone** | | | | | | | | | | | | | | |
| Duotone Warp_Fin 5.7 (2026) | 5.7 | 4.26 | 1.88 | 400 | 4.28 | 1.40 | 4 | 0.075 | 5.10 | 10.4 | 8.0 | 0.41 | 3.18 | mast_m |
| Warp_Fin 6.2 (2026) | 6.2 | 4.32 | 1.92 | 430 | 4.34 | 1.40 | 4 | 0.075 | 5.40 | 10.9 | 8.3 | 0.41 | 3.01 | mast_m |
| Warp_Fin 6.7 (2026) | 6.7 | 4.62 | 2.02 | 430 | 4.64 | 1.45 | 4 | 0.075 | 5.60 | 11.1 | 8.5 | 0.41 | 3.19 | mast_m |
| Warp_Fin 7.7 (2026) | 7.7 | 4.88 | 2.14 | 460 | 4.90 | 1.50 | 4 | 0.075 | 6.00 | 11.8 | 9.0 | 0.41 | 3.09 | mast_m |
| Warp_Fin 8.5 (2026) | 8.5 | 5.14 | 2.28 | 490 | 5.16 | 1.50 | 4 | 0.075 | 6.30 | 13.2 | 10.1 | 0.41 | 3.11 | mast_m |
| **Savanna** | | | | | | | | | | | | | | |
| Severne Mach 9 5.5 (026) | 5.5 | 4.28 | 1.77 | 400 | 4.30 | 1.40 | 4 | 0.075 | 5.30 | 10.2 | 7.9 | 0.41 | 3.33 | mast_m |
| Mach 9 6.5 (026) | 6.5 | 4.56 | 1.98 | 430 | 4.58 | 1.45 | 4 | 0.075 | 5.96 | 11.4 | 8.7 | 0.41 | 3.20 | mast_m |
| Mach 9 7.5 (026) | 7.5 | 4.90 | 2.08 | 460 | 4.92 | 1.50 | 4 | 0.075 | 6.33 | 12.1 | 9.3 | 0.41 | 3.20 | mast_m |
| Mach 9 8.5 (026) | 8.5 | 5.18 | 2.22 | 490 | 5.20 | 1.50 | 4 | 0.075 | 6.74 | 13.6 | 10.4 | 0.41 | 3.16 | mast_m |
| **Point.9** | | | | | | | | | | | | | | |
| Point-7 AC-1 LTD 5.9 (026, stitched) | 5.9 | 4.42 | 1.92 | 400 | 4.44 | 1.45 | 3 | 0.072 | 5.30 | 10.6 | 8.1 | 0.41 | 3.31 | - |
| AC-1 LTD 6.5 (026) | 6.5 | 4.64 | 1.96 | 430 | 4.66 | 1.45 | 3 | 0.072 | 5.80 | 11.3 | 8.6 | 0.41 | 3.31 | - |
| AC-1 LTD 7.3 (026) | 7.3 | 4.98 | 2.10 | 460 | 5.00 | 1.50 | 3 | 0.072 | 6.50 | 12.2 | 9.4 | 0.41 | 3.40 | - |
| AC-1 LTD 7.8 (026) | 7.8 | 4.98 | 2.12 | 460 | 5.00 | 1.50 | 3 | 0.072 | 6.60 | 12.3 | 9.5 | 0.41 | 3.18 | - |
| AC-1 LTD 8.8 (025/026) | 8.8 | 5.24 | 2.30 | 490 | 5.26 | 1.50 | 3 | 0.072 | 6.90 | 13.8 | 10.5 | 0.41 | 3.12 | - |
| **NielsTrots** | | | | | | | | | | | | | | |
| NeilPryde RS:Racing EVO XVII 5.6 (2026) | 5.6 | 4.26 | 1.80 | 400 | 4.26 | 1.40 | 4 | 0.075 | 5.00 | 10.0 | 7.6 | 0.41 | 3.24 | - |
| RS:Racing EVO XVII 6.5 | 6.5 | 4.58 | 1.92 | 430 | 4.58 | 1.45 | 4 | 0.075 | 5.30 | 10.8 | 8.2 | 0.41 | 3.23 | - |
| RS:Racing EVO XVII 7.4 | 7.4 | 4.86 | 2.06 | 460 | 4.86 | 1.50 | 4 | 0.075 | 5.50 | 11.2 | 8.6 | 0.41 | 3.19 | - |
| RS:Racing EVO XVII 8.2 | 8.2 | 5.12 | 2.16 | 490 | 5.12 | 1.50 | 4 | 0.075 | 6.10 | 13.0 | 9.9 | 0.41 | 3.20 | - |
| RS:Racing EVO XVII 9.0 | 9.0 | 5.38 | 2.26 | 520 | 5.38 | 1.50 | 4 | 0.075 | 6.40 | 13.3 | 10.2 | 0.41 | 3.22 | - |
| **SouthSails** | | | | | | | | | | | | | | |
| North Slalom Race GEN3 6.0 (2026) | 6.0 | 4.38 | 1.83 | 430 | 4.38 | 1.40 | air cam | 0.072 | 4.30 | 9.8 | 7.5 | 0.41 | 3.20 | - |
| Slalom Race GEN3 6.8 (2026) | 6.8 | 4.56 | 1.96 | 430 | 4.56 | 1.45 | air cam | 0.072 | 4.50 | 10.0 | 7.6 | 0.41 | 3.06 | - |
| Slalom Race GEN3 7.7 (2026) | 7.7 | 4.92 | 2.15 | 460 | 4.92 | 1.50 | air cam | 0.072 | 4.70 | 10.5 | 8.0 | 0.41 | 3.14 | - |
| Slalom Race 8.6 (2025 luff/boom) | 8.6 | 5.18 | 2.17 | 490 | 5.20 | 1.50 | air cam | 0.072 | 4.95 | 11.8 | 9.0 | 0.41 | 3.12 | mast_m, sail kg |
| **s3kauai** | | | | | | | | | | | | | | |
| S2Maui Venom-XI 5.6 (2026) | 5.6 | 4.13 | 1.85 | 400 | 4.15 | 1.40 | 4 | 0.075 | 5.20 | 10.5 | 8.1 | 0.41 | 3.05 | mast_m, sail kg |
| Venom-XI 6.7 (2026) | 6.7 | 4.60 | 2.02 | 430 | 4.62 | 1.45 | 4 | 0.075 | 5.80 | 11.3 | 8.7 | 0.41 | 3.16 | mast_m, sail kg |
| Venom-XI 7.6 (2026) | 7.6 | 4.81 | 2.17 | 460 | 4.83 | 1.50 | 4 | 0.075 | 6.20 | 12.8 | 9.8 | 0.41 | 3.04 | mast_m, sail kg |
| Venom-XI 8.2 (2026) | 8.2 | 4.91 | 2.29 | 460 | 4.93 | 1.50 | 4 | 0.075 | 6.40 | 13.0 | 9.9 | 0.41 | 2.94 | mast_m, sail kg |
| Venom-XI 9.0 (2026) | 9.0 | 5.16 | 2.40 | 490 | 5.18 | 1.50 | 4 | 0.075 | 6.80 | 13.7 | 10.5 | 0.41 | 2.96 | mast_m, sail kg |
| **GG Sails** | | | | | | | | | | | | | | |
| GA Vapor 5.7 (2026) | 5.7 | 4.25 | 1.87 | 400 | 4.26 | 1.40 | 4 | 0.075 | 5.27 | 10.6 | 8.1 | 0.41 | 3.17 | - |
| Vapor 6.7 (2026) | 6.7 | 4.61 | 1.96 | 430 | 4.62 | 1.45 | 4 | 0.075 | 5.80 | 11.3 | 8.6 | 0.41 | 3.17 | - |
| Vapor 7.7 (2026) | 7.7 | 4.94 | 2.09 | 460 | 4.94 | 1.50 | 4 | 0.075 | 6.15 | 11.9 | 9.1 | 0.41 | 3.17 | - |
| Vapor 8.4 (2026) | 8.4 | 5.15 | 2.17 | 490 | 5.16 | 1.50 | 4 | 0.075 | 6.39 | 13.2 | 10.2 | 0.41 | 3.16 | - |

Left out: sizes below 5.5 m² (speed and storm sizes) and Severne's 5.0, Point-7's 5.4, S2Maui's 6.1 and NeilPryde's 4.9 and 5.3, which the brands make but which are below the game's range or between its steps. Point-7's 6.8 and 8.2 are the in-between sizes of the 6.5 and 7.8 (same luff, longer boom).

### 3.5 Free race sails

| Modelled on | area_m2 | luff_m | boom_m | mast (cm) | mast_m (mast + extension) | boom_height_m | cams | camber | sail kg | rig_mass_kg real | rig_mass_kg at the default's ratio | ce_height_fraction | aspect ratio (luff²/area) | estimated |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Tripletone** | | | | | | | | | | | | | | |
| Duotone S_Pace 6.0 (2026) | 6.0 | 4.42 | 1.90 | 430 | 4.44 | 1.45 | 3 | 0.072 | 4.90 | 10.4 | 7.9 | 0.42 | 3.26 | mast_m |
| S_Pace 6.6 (2026) | 6.6 | 4.62 | 2.00 | 430 | 4.64 | 1.45 | 3 | 0.072 | 5.10 | 10.6 | 8.1 | 0.42 | 3.23 | mast_m |
| S_Pace 7.3 (2026) | 7.3 | 4.76 | 2.04 | 460 | 4.78 | 1.45 | 3 | 0.072 | 5.30 | 11.1 | 8.5 | 0.42 | 3.10 | mast_m |
| S_Pace 7.8 (2026) | 7.8 | 4.88 | 2.14 | 460 | 4.90 | 1.50 | 3 | 0.072 | 5.50 | 11.2 | 8.6 | 0.42 | 3.05 | mast_m |
| S_Pace 8.3 (2026) | 8.3 | 5.00 | 2.22 | 490 | 5.02 | 1.50 | 3 | 0.072 | 5.70 | 12.6 | 9.6 | 0.42 | 3.01 | mast_m |
| **Savanna** | | | | | | | | | | | | | | |
| Severne Overdrive M4 6.2 | 6.2 | 4.33 | 1.86 | 430 | 4.35 | 1.40 | 3 | 0.072 | 4.40 | 9.9 | 7.6 | 0.42 | 3.02 | mast_m |
| Overdrive M4 7.0 | 7.0 | 4.61 | 1.89 | 430 | 4.63 | 1.45 | 3 | 0.072 | 4.65 | 10.1 | 7.7 | 0.42 | 3.04 | mast_m |
| Overdrive M4 7.8 | 7.8 | 4.89 | 2.00 | 460 | 4.91 | 1.50 | 3 | 0.072 | 4.90 | 10.6 | 8.1 | 0.42 | 3.07 | mast_m |
| Overdrive M4 8.6 | 8.6 | 5.12 | 2.08 | 490 | 5.14 | 1.50 | 3 | 0.072 | 5.20 | 11.2 | 8.6 | 0.42 | 3.05 | mast_m |
| **Point.9** | | | | | | | | | | | | | | |
| Point-7 AC-2 5.8 (025-026) | 5.8 | 4.40 | 1.92 | 400 | 4.42 | 1.45 | 2 | 0.070 | 4.70 | 10.0 | 7.7 | 0.42 | 3.34 | - |
| AC-2 6.8 | 6.8 | 4.63 | 2.04 | 430 | 4.66 | 1.45 | 2 | 0.070 | 4.80 | 10.3 | 7.9 | 0.42 | 3.15 | - |
| AC-2 7.8 | 7.8 | 4.97 | 2.12 | 460 | 5.00 | 1.50 | 2 | 0.070 | 4.90 | 10.7 | 8.2 | 0.42 | 3.17 | - |
| **NielsTrots** | | | | | | | | | | | | | | |
| NeilPryde V8 6.2 (2026) | 6.2 | 4.30 | 1.94 | 400 | 4.30 | 1.40 | 2 | 0.070 | 4.20 | 9.5 | 7.3 | 0.42 | 2.98 | - |
| V8 7.2 (2026) | 7.2 | 4.67 | 2.04 | 460 | 4.68 | 1.45 | 2 | 0.070 | 4.50 | 10.2 | 7.9 | 0.42 | 3.03 | - |
| V8 7.7 (2026) | 7.7 | 4.86 | 2.09 | 460 | 4.86 | 1.50 | 2 | 0.070 | 4.70 | 10.5 | 8.0 | 0.42 | 3.07 | - |
| V8 8.2 (2026) | 8.2 | 5.05 | 2.13 | 490 | 5.06 | 1.50 | 2 | 0.070 | 4.90 | 11.0 | 8.4 | 0.42 | 3.11 | - |
| **SouthSails** | | | | | | | | | | | | | | |
| North Free Speed 6.0 (2025) | 6.0 | 4.32 | 1.89 | 430 | 4.34 | 1.40 | 0 | 0.068 | 4.00 | 9.5 | 7.2 | 0.42 | 3.11 | mast_m, sail kg |
| North Free Speed 7.7 (2024 test) | 7.7 | 4.90 | 2.09 | 460 | 4.92 | 1.50 | 0 | 0.068 | 4.60 | 10.3 | 7.9 | 0.42 | 3.12 | mast_m, sail kg |
| **s3kauai** | | | | | | | | | | | | | | |
| S2Maui Wicked 5.8 (2026) | 5.8 | 4.33 | 1.82 | 430 | 4.35 | 1.40 | 2 | 0.070 | 4.20 | 9.7 | 7.4 | 0.42 | 3.23 | mast_m, sail kg |
| Wicked 6.7 (2026) | 6.7 | 4.56 | 1.98 | 430 | 4.58 | 1.45 | 2 | 0.070 | 4.50 | 10.0 | 7.6 | 0.42 | 3.10 | mast_m, sail kg |
| Wicked 7.6 (2026) | 7.6 | 4.76 | 2.12 | 460 | 4.78 | 1.45 | 2 | 0.070 | 4.80 | 10.6 | 8.1 | 0.42 | 2.98 | mast_m, sail kg |
| Wicked 8.2 (2026) | 8.2 | 4.89 | 2.24 | 460 | 4.91 | 1.50 | 2 | 0.070 | 5.00 | 11.6 | 8.9 | 0.42 | 2.92 | mast_m, sail kg |
| **GG Sails** | | | | | | | | | | | | | | |
| GA Cosmic 6.2 (2026) | 6.2 | 4.48 | 1.87 | 430 | 4.48 | 1.45 | 2 | 0.070 | 4.70 | 10.2 | 7.8 | 0.42 | 3.24 | sail kg |
| Cosmic 7.2 (2026) | 7.2 | 4.81 | 2.02 | 460 | 4.82 | 1.50 | 2 | 0.070 | 5.00 | 10.8 | 8.2 | 0.42 | 3.21 | sail kg |
| Cosmic 7.7 (2026) | 7.7 | 4.92 | 2.12 | 460 | 4.92 | 1.50 | 2 | 0.070 | 5.20 | 11.0 | 8.4 | 0.42 | 3.14 | sail kg |
| Cosmic 8.3 (2026) | 8.3 | 5.03 | 2.20 | 490 | 5.04 | 1.50 | 2 | 0.070 | 5.40 | 12.3 | 9.4 | 0.42 | 3.05 | sail kg |

North publishes too little of its free race line for more than two sizes; the two Free Speed rows rest on single-size shop and test data (section 2.8). Point-7's free race sail could also be the 3-cam AC-3 (5.4 to 8.2, the AC-1 LTD's body with a 20 % slimmer sleeve); the AC-2 is proposed because it looks and rigs differently from the race sail.

### 3.6 The fins in short

Every board in 3.2 and 3.3 has its own fin (the columns `fin span_m` and `fin area_m2`), from 0.30 m and 0.0226 m² (the 60 cm boards) to 0.46 m and 0.0405 m² (the Manta 85) for slalom, and 0.32 to 0.48 m for free race. For a `.tres` per fin, keep the default's planform and bending numbers (`tip_chord_ratio` 0.37, the flex test of the 37 cm carbon fin; `flex_test_span_m` and `flex_test_area_m2` stay those of the test fin, as `fin_config.gd` says) and change only `span_m`, `area_m2` and `root_local` (rule 11). The free race boards come with G10 (glass) fins, softer than carbon: a softer flex test would be the honest number, but no published flex test of a G10 fin was found (an open question).

### 3.7 Names for the models (a suggestion)

The brief names only the brands. If the gear page needs model names, these keep the spirit of the team's brand names (a twist on the real one, never the real one). They are only a proposal for the team.

| Game brand | Slalom board / sail | Free race board / sail | Real model |
|---|---|---|---|
| Tripletone | "Hawk_Fin" board, "Weft_Fin" sail | "Bolt" board, "T_Pace" sail | Falcon_Fin, Warp_Fin; Blitz, S_Pace |
| Savanna | (no slalom board) "Mach 10" sail | "Wolf" board, "Underdrive" sail | Mach 9; Fox, Overdrive |
| Point.9 | "BC-1" sail | "BC-2" sail | AC-1 LTD; AC-2 |
| Moonboard | "uSonic" board | "Futurama" board | iSonic; Futura |
| NielsTrots | "RT:Racing" sail | "V9" sail | RS:Racing; V8 |
| PJ New Sealand | "Slalom T-SEC" board | "Hyper Sport" board | Slalom S-TEC; Super Sport |
| BMX Boards | "Invincible" board | "Invincible GTS" board | Invictus Pro; Invictus GTR |
| SouthSails | "Slalom Sprint" sail | "Free Sprint" sail | Slalom Race GEN3; Free Speed |
| s3kauai | "Viper" sail | "Wild" sail | Venom-XI; Wicked |
| Forbidden | "Stingray" board | "Missile+" board | Manta; Rocket+ |
| GG Sails | "Vapour" sail | "Cosmos" sail | Vapor; Cosmic |

### 3.8 What this means for the personas and for PH14

- The personas rig a 7.8 below 16 kt and a 6.2 above (`Game/race/persona.gd`). Every free race line in 3.5 has sizes within 0.2 m² of both, except Point-7's AC-2 (7.8, and 5.8 or 6.8). Of the race lines, Duotone (7.7, 6.2), North (7.7, 6.0) and S2Maui (7.6, 6.1) do too; Severne (7.5, 6.5), Point-7 (7.8, 5.9 or 6.5), NeilPryde (7.4, 6.5) and GA (7.7, 5.7 or 6.7) are 0.3 to 0.5 m² off one of them. The gear page can map a persona's two sizes to the nearest of its brand.
- PH14 (the sizes do not sail right yet) is Michiel's. The facts this research adds: the real sails' geometry changes smoothly with the size (aspect ratio 2.9 to 3.4 everywhere), the real rig weighs about 1 kg more per 1 m² of sail at the large end (10 kg as a 5.6, 12 to 13.7 kg from 7.5 up), and the brands' wind ranges overlap widely (Point-7: one rider of 75 to 90 kg sails a 7.3 or 7.8 from 16 to 21 kt and an 8.2 below). A 7.8 that is slower than a 6.5 in 12 kt contradicts every brand's chart.

---

## 4. Notes for the shaper

For each game brand: the look to aim for, the palette, the details that make the brand recognisable at ten metres, and where the real brand puts its logo and model name (and how big), so the game's own logos (from the logo designer, part 3 of the plan) can go in the same places. The builder `tools/blender/build_rig_models.py` already draws every part these notes refer to: the outline (traced as a table of widths, `JP_OUTLINE`), the rocker (with a traced nose, `JP_NOSE_ROCKER`), the rails, the cut-outs (`CUTOUT_LENGTH`, `CUTOUT_BOTTOM_HALF_W`), the deck pads and the wedge, the straps, the fin box, the mast track, and on the sail the panels, battens, windows, sleeve, clew, the stripe, the number boxes and the foot letters, all painted into `board_deck.png`, `board_bottom.png` and `sail_panels.png`. Logo sizes below are estimated from the brands' pictures (scaled by the board's known length or the sail's known luff), to about ±20 %.

**Sail numbers.** Production pictures show none; racing sails carry the rider's number (country letters and digits) on both sides of the upper middle sail. The game already draws two number boxes (`NUMBER_BOX_STARBOARD` and `_PORT`, between 0.43 and 0.65 of the luff): keep them on every brand, in the brand's contrast colour (black on light sails, white on dark ones).

### Tripletone (Duotone): boards and sails

- **The look.** Boards: clean and light, a white deck marbled lengthwise with cyan, turning lilac at the tail, black pads; the bottom a deep royal blue. Sails: technical and graphic, teal edges, a black upper sail with a huge "D" broken into pixels, white below.
- **Palette.** Deck white #EEF5FB, cyan streaks #2BB5D8 (est.), lilac #9C8FD6, violet #8246AF (Pantone 2097 C), pads black #16212C, bottom blue #094AC3, letters red #E63A3F (est.), cut-out aqua #3FC4E0 (est.). Sail teal #249AAB, black #20211C, white #F8F9F8, red #E5323B (est.).
- **At ten metres.** (1) A white board with a blue belly. (2) The aqua two-step cut-outs at the tail, visible from the side. (3) One black pad wedge across the tail and black diamonds under the front straps. (4) On the sail: the giant pixelated "D" in the black upper half and the teal luff.
- **Shape.** Board: compact and parallel, 2.24 to 2.26 m, a wide square tail with two steps; on the slalom D/LAB a recessed mast track. Sail: seven battens, a large cutaway clew, the boom range printed on the sleeve at boom height.
- **Logo placement (real).** The angular "D" mark, about 0.20 m tall, on the deck's nose centreline and near the bottom's nose; "Duotone" along the bottom's centreline, about 0.7 m long and 0.15 m tall, reading along the board; the model name ("Falcon Fin SLS") small (about 0.15 m) beside the mast track, the size on the tail. On the sail: the "D" fills the upper body (about 1 m tall), "DUOTONE" runs down the leech (about 1.4 m), a small logo on the foot.

### Savanna (Severne): boards and sails

- **The look.** Everything red. The sail a translucent deep red with black battens; the board a deep red, marbled carbon with thin orange outline graphics.
- **Palette.** Sail red #C8161D (daylight est.; #A21310 to #B01D1D on the render), black #1A1A1A, white #FFFFFF (the SV badge). Board red #B0252F (est. from #963039 on a dark render), orange outlines #E2624B, pads charcoal #262626, the tail's grey #3E4043.
- **At ten metres.** (1) An all-red sail with black battens. (2) Severne's big outlined "boomerang" (an open chevron) on the leech above the boom. (3) Huge black "M9" letters filling the foot. (4) On the board (the Fox): long and narrow-nosed, with large outlined letters drawn in thin orange lines along the deck and a striped orange chevron on the bottom's nose.
- **Shape.** Sail: race outline with a single seamless foot panel, thin black vertical luff panels. Board: 2.39 to 2.44 m, the longest of the game's boards, a tapered nose, medium cut-outs.
- **Logo placement (real).** On the sail: the boomerang about 1.1 m long over the leech, a white-on-black "SV" badge about 0.25 m wide mid-sail by the luff, "M9" about 0.5 m tall in the foot with "MACH" small beside it. On the board: an orange "SV" tab about 0.2 m on the nose's port side, the size ("125") on the tail and on the bottom near the tail, the striped boomerang about 0.5 m wide on the bottom's nose.

### Point.9 (Point-7): sails

- **The look.** Black and white, smoked and minimal: a stealth race sail.
- **Palette.** Smoke black film #1E1F22 (est.), white pearl #F2F2EE (est.), grey window #8A8D92 (est.), the accent yellow #FFC600 (Pantone 7548 C) if one is wanted.
- **At ten metres.** (1) A dark, smoky sail where most others are bright. (2) White rectangular blocks near the head and a white strip along the foot (the stitched version). (3) The very wide race sleeve. (4) The foot cut straight and low along the deck.
- **Shape.** Seven battens, three cams, the XXL sleeve, an S-shaped bottom batten.
- **Logo placement (real).** "P7" about 0.25 m near the clew, the year ("026") at the tack, the model name small on the foot panel.

### Moonboard (Starboard): boards

- **The look.** Sporty blue with red-orange tips and two white racing stripes; the same family look on every board (the wood free race board swaps the blue carbon for bare pine).
- **Palette.** Deck blue #2B6C95 to #3175A3, dark navy band #1F3550 (est.), red-orange #FC1A0D to #FD340A, stripes white #F1F2F5, bottom sky blue #05B8E8 to #009AC6, wood #D9B48A (Futura, est.).
- **At ten metres.** (1) Two white stripes running from the nose down the deck either side of the centre. (2) A red-orange tail with the size in giant white-outlined numbers. (3) A bright sky-blue bottom with red-orange nose and tail tips. (4) The tiki logo in a red tab on the nose.
- **Shape.** Square, wide outline with the widest point near the middle; double-step cut-aways, and on the 2026 63, 67 and 73 a small triangle between them; a thin, spoon-shaped nose on the free race board.
- **Logo placement (real).** The tiki figure in a red-orange tab about 0.21 × 0.29 m on the deck's nose (port side) and on the bottom's nose; "STARBOARD" in white letters about 0.6 m long and 0.09 m tall along the bottom's centreline; the size number about 0.30 m wide on the tail; "iSONIC" or "FUTURA" small and vertical by the tail rail.

### NielsTrots (NeilPryde): sails

- **The look.** Loud: a magenta-purple sail with a black luff and an orange-red foot, big brand letters up the luff.
- **Palette.** Magenta-purple #D10FAD to #BD1199, pink-red #E83A6A (est., where the rings fade toward the boom), black #1C1C1E (est.), orange-red #F14D36, window white #FCFCFC.
- **At ten metres.** (1) The purple upper sail printed with concentric rings like a target. (2) "NEILPRYDE" in tall orange-red letters running up the black luff panel. (3) A white window band below the boom. (4) An orange-red foot.
- **Shape.** A high, narrow head, a raked batten layout, seven battens, the four-layer sleeve.
- **Logo placement (real).** The brand name up the luff panel, about 1.7 m long and 0.18 m tall, from the boom up; "RS:RACING EVO XVII" about 0.6 m long in black just under the boom; the size printed on the foot near the clew.

### PJ New Sealand (JP Australia): boards

- **The look.** Dark and rich: mottled purple carbon fading to navy, with a hot orange-red tail. The game's default board already wears it.
- **Palette.** Purple #775D9F and dark purple #553E7B (the builder's medians), navy #322A47, bottom navy #24274B, orange-red #C04A46 to #E0563A, orange letters #F27028 (the builder's (242, 112, 40)), pads white and grey #D0D0D8. Pantone references: 260 C (about #5F2167), 021 C (#FE5000), 805 C (#FF7276), 433 C (#1D252D).
- **At ten metres.** (1) A purple board with an orange-red tail. (2) The sunken, lighter purple recess around the mast track. (3) The white-outlined "JP" on the nose. (4) A navy bottom with orange "JP-AUSTRALIA".
- **Shape.** The traced S-TEC 72 outline, a parallel middle, the double-step tail with the wide deck over it, a pad wedge between the back straps.
- **Logo placement (real).** "JP" about 0.18 m wide on the nose; "SLALOM S-TEC" (or "SUPER SPORT") about 0.2 m on the tail with the dimensions beside it; "JP-AUSTRALIA" about 0.7 m along the bottom's centreline from the nose.

### BMX Boards (FMX Racing): boards

- **The look.** One bold colour, red for the race board and neon green for the free race board, with a white chevron and a black arrow down the deck.
- **Palette.** Red #E51B26 (#DF0E0E in shade), white #FFFFFF, black #0A0A0A, GTR neon green #0FDE2A.
- **At ten metres.** (1) A solid red (or green) board, deck and bottom. (2) A forward-pointing white chevron of thin lines meeting ahead of the mast track. (3) The black arrow-shaped panel behind the track that holds black pads. (4) The white "vortex" (a disc of curved blades) on the nose.
- **Shape.** The longest slalom outline (2.33 m up to 118 L), a wide nose, straight rails, separate cut-out plates screwed into the tail (draw them as panels of another finish with screw heads), two rows of strap plugs.
- **Logo placement (real).** The vortex about 0.25 m across on the deck's nose (port side) and about 0.4 m on the bottom's nose; "FMXRACING" vertical beside the mast track (about 0.4 m) and along the bottom's centreline (about 0.7 m, white); "INVICTUS PRO" and "233 - 72 - 118" in black on the tail.

### SouthSails (North Sails): sails

- **The look.** A yacht sail: a smooth grey moulded membrane with the fibre lines showing, no panel seams, thin blue lines and clean windows.
- **Palette.** Slate grey #5D6F7D to #7F8A97, fibre lines #3E4A55 (est.), royal blue #2E5FB0 (est.), white #FFFFFF.
- **At ten metres.** (1) A grey sail where the others are coloured. (2) The fibre pattern (lines fanning from the clew and the head). (3) White-framed clear windows in the lower panel. (4) A round white compass logo high on the luff.
- **Shape.** Six or seven battens, no hard cams (an air-filled sleeve), split batten pockets.
- **Logo placement (real).** The round "NS" logo about 0.3 m across high near the luff; "RACE" and "NORTH" small (about 0.3 m) in the middle of the sail; the size near the head.

### s3kauai (S2Maui): sails

- **The look.** Bright horizontal bands across the whole sail: sky blue on top, orange around the boom, white and clear below.
- **Palette.** Sky blue #00B5FF, orange #FC6501, white #FCFCFC, black outlines #111111, logo red #E3262B (est.), "Hot Yellow" #F2E500 (est.).
- **At ten metres.** (1) The blue top and the two orange bands. (2) Red-orange battens. (3) The red "S2" logo with an orange swoosh on the lower sail. (4) Two clew eyelets.
- **Shape.** Seven battens, four cams, vertical luff panels.
- **Logo placement (real).** "S2MAUI" about 0.6 m wide on the lower sail just under the orange bands; "VENOM-XI" about 0.8 m wide across the foot.

### Forbidden (Tabou): boards

- **The look.** Playful: a cyan-to-violet gradient deck, hexagon-shaped navy pads outlined in white, magenta cut-outs and a line-drawn cartoon figure; the colours change every year (2025 was red and white).
- **Palette.** Cyan #1879B4 to #2A8FD0 (Pantone 313 C: #0092BC), violet #7966A3, navy #132238, magenta #E34978 (Pantone Rubine Red C: #CE0058), bottom sky blue #5CCAFD, logo yellow #F2E64A (est.). The free race board: red #EF3340 (Pantone 032 C), dark teal #003B49 (309 C), light blue pads #9AD7EE.
- **At ten metres.** (1) The cyan-to-violet deck. (2) Magenta cut-out steps at the tail. (3) Hexagon pads with white outlines. (4) "TABOU" in big outline letters on the bottom.
- **Shape.** 2.32 to 2.33 m, large cut-outs per size, a deep front vee, more tucked rails in the tail.
- **Logo placement (real).** Hexagon outlines and the logo on the deck's nose (about 0.3 m); the cartoon figure about 0.25 m between the straps; "MANTA" (or "ROCKET+") about 0.25 m by the tail rail with the size; "TABOU" about 0.5 m in outline letters on the bottom near the nose.

### GG Sails (GA Sails): sails

- **The look.** Cyan blue with a giant logo, magenta edges and lime battens.
- **Palette.** Cyan #009CCD, teal-blue luff panel #357A98, magenta #CA4CA2 (a more vivid #E0359B in the drawing, est.), lime #D7E83A (est.), black #111111, white #FFFFFF, navy sleeve bottom #1C3550 (est.).
- **At ten metres.** (1) The huge "GA" (a black "G" beside a magenta triangle) high on the luff. (2) Lime-yellow battens. (3) Magenta tape along the leech and foot. (4) "GA-SAILS" in lime outline letters running down the leech.
- **Shape.** Seven battens, four cams, radial panels fanning from the sail's centre, a big clew cut-out, a coloured foot panel.
- **Logo placement (real).** "GA" about 1.3 m tall on the upper luff panel of a 7.7 (from just under the head to about a third down); "GA-SAILS" about 1.6 m long and 0.15 m tall down the leech; "VAPOR" with three colour bars about 0.5 m on the white foot panel.

---

## 5. Open questions for the team

1. **Which year to build.** The catalogue uses the 2026 boards and sails, but keeps the PJ 72 as the 2025 board of `board_default.tres` (117 L, 228 × 72 cm). Update the default to the 2026 72 (119 L, 6.7 kg), or keep it?
2. **The rig's mass** (Michiel, PH14): build the sails with the real rig weight, or with the default's ratio (9.5 of a real 12.4 kg)? Section 3 gives both columns.
3. **The camber per sail type** (Michiel): 0.075 to 0.068 by the number of cams (estimates), or 0.07 for all?
4. **The fins' area** (Michiel): the game's 38 cm fin has the area of a real 42 to 43 cm fin. Section 3 gives every board a real fin (Select's areas); that changes the default board's fin from 0.0365 to 0.0311 m² if it is applied to the PJ 72 too. Apply, or keep the default fin as it is?
5. **The cut-outs in the physics** (Michiel, PH16): every 2026 slalom board has them, and they differ by brand (JP's two steps, Starboard's triangle, FMX's plates). Keep them visual only, as now?
6. **Brands without a full line.** Savanna (Severne) has no slalom board: leave it out of the slalom boards, or invent one? SouthSails (North) has only two free race sizes with thin data, and North is replacing its 3Di race sail with the Prisma in November 2026, whose luff and boom are not published yet: build the GEN3 now and the Prisma later?
7. **Model names.** Section 3.7 suggests names; the team decides (and the logo designer may want them).
8. **The strap and fin box positions** are Max's Patrik 115 on every board (an estimate). Could Max measure one more board (a wide slalom or a free race board) to check the rule, and his board's inboard strap positions?
9. **The free race boards' G10 fins** are softer than the carbon fin the game's flex test describes. Use the same stiffness, or estimate a softer one?
10. **`twist_pressure_pa` per size** (Michiel): the default has 125 Pa for the 8.0 and 140 Pa for the 6.5, both estimates. A rule for the other sizes is a physics question this research cannot answer.
11. **Speed and storm sizes** (below 5.5 m² and 85 L) are left out: wanted for the 24 kt races?

---

## 6. Sources

Every web page and document used, grouped by brand (a page about two brands is listed under the first). Product pictures used for the colours are included. All were read on 31 October 2026; shop pages change with the seasons. The S2Maui catalogues and the Select fin catalogue were downloaded and read as text; Duotone's own spec tables do not render outside a browser, so its numbers come from shops' copies.

**Duotone (Tripletone)**

- <https://cdn.boards-and-more.com/system/product_picture_gallery_pictures/files/66e0/4834/b16a/4001/2d25/85df/original/DTW25_Warp_Fin_Rendering_C31_Web72.png>
- <https://duotonequipment.com/product/falcon_fin-d-lab-2025/>
- <https://easy-surfshop.com/do/blog/post/north-sails-and-nkb-have-changed-name-for-duotone>
- <https://easy-surfshop.com/do/item/N-DTW-14260-1015/Windsurf-board-Duotone-FALCON_FIN-SLS-2026>
- <https://en.windlounge.de/products/duotone-blitz-board-2026>
- <https://surf-center.com/en/duotone-blitz-2026>
- <https://surf-center.com/en/duotone-warp-fin-2026>
- <https://worthingwatersports.com/en-us/products/dtw-warp_fin-mto-2026>
- <https://worthingwatersports.com/en-us/products/duotone-warp_fin-2025>
- <https://worthingwatersports.com/en-us/products/duotone-windsurfing-falcon-fin-d-lab-2027>
- <https://worthingwatersports.com/en-us/products/used-duotone-falcon_fin-d-lab-2025-116>
- <https://www.boardwise.co.uk/products/2024-duotone-falcon-fin-d-lab>
- <https://www.continentseven.com/fanatic-becomes-duotone-an-interview/>
- <https://www.duotonesports.com/en/us/products/duotone-falcon_fin-d-lab-mto-no-fin-2026-14260-1066>
- <https://www.duotonesports.com/en/us/products/duotone-falcon_fin-sls-2026-14260-1015>
- <https://www.fluid-lines.co.uk/product/duotone-x-pace-windsurfing-sail-2026-4/>
- <https://www.ozu-tarifa.com/en/products/duotone-s_pace-2026>
- <https://www.roho.co.uk/2026-duotone-s-pace-windsurf-sail>
- <https://www.roho.co.uk/duotone-jag-sls-freerace-windsurf-board-14240-1003>
- <https://www.surf-magazin.de/en/windsurfing/scene-and-events/goodbye-northsails-hello-duotone/>
- <https://www.surf-magazin.de/en/windsurfing/scene-and-events/traditional-brand-disappears-fanatic-becomes-duotone/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboard-2025-duotone-jag-128-on-test-sporty-but-easy/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2024-duotone-jag-110-on-test-sporty-fast-and-controllable/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-duotone-blitz-136-sls/>
- <https://www.telstarsurf.com/duotone-falcon-fin-sls-2026-121912.html>
- <https://www.telstarsurf.com/duotone-jag-sls-117845.html>
- <https://www.telstarsurf.com/duotone-warp-fin-118920.html>
- <https://www.windsurf.co.uk/duotone-s-pace-7-8m-test-review-2024/>
- <https://www.windsurf.co.uk/new-duotone-warp_fin-falcon_fin-d-lab/>

**Severne (Savanna)**

- <https://andybiggs.co.uk/shop/brands/severne-shop/2025-severne-mach-8-pro-slalom-windsurfing-sail/>
- <https://isthmussailboards.com/severne-fox-4-windsurf-board.html>
- <https://isthmussailboards.com/windsurfing-sail/severne-sails.html>
- <https://surf-center.com/en/severne-fox-pro-2026>
- <https://www.pooleharbour.co.uk/products/severne-mach-8-sail-2025>
- <https://www.severnesails.com/boards/fox/>
- <https://www.severnesails.com/sails/mach-9/>
- <https://www.severnesails.com/sails/ncx/>
- <https://www.severnesails.com/sails/overdrive/>
- <https://www.severnesails.com/wp-content/uploads/2024/11/025-fox-render-final-square-800.jpg>
- <https://www.severnesails.com/wp-content/uploads/2026/03/026-Mach-9-render-final-square-800.jpg>
- <https://www.severneshop.com/shop/product/2025-severne-fox/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-severne-fox-135/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freeride/freerideboards-2025-severne-fox-135-in-test/>
- <https://www.telstarsurf.com/severne-mach-8-118891.html>
- <https://windsurfing-mag.jp/brands/2017/01/5239/>

**Point-7 (Point.9)**

- <https://point-7.com/our-story/>
- <https://point-7.com/wp-content/uploads/2025/09/AC1-ltd_Q-Bond_026.png>
- <https://point-7.com/wp-content/uploads/2025/09/AC1-ltd_White_026.png>
- <https://point-7.com/zero-25-overview/ac-2-2cam-race-025/>
- <https://point-7.com/zero-25-overview/ac1-ltd-pro-racing-025/>
- <https://point-7.com/zero-26/ac1-ltd-racing-026/>
- <https://point-7.com/zero-26/ac3-racing-026/>
- <https://www.pwaworldtour.com/athletes/cucchi-andrea-i-1/>
- <https://www.telstarsurf.com/point-7-ac-1-pro-race-2025-118965.html>

**Starboard (Moonboard)**

- <https://boardsportscalifornia.com/product/2026-starboard-isonic-copy/>
- <https://en.wikipedia.org/wiki/Svein_Rasmussen>
- <https://star-board.com/cdn/shop/files/2026-Starboard-Windsurf-iSonic-Carbon-Reflex-Sandwich-new.jpg?v=1768814785>
- <https://star-board.com/pages/windsurfing>
- <https://star-board.com/products/2025-futura-windsurf-board>
- <https://star-board.com/products/2025-isonic-windsurf-board>
- <https://star-board.com/products/2026-futura-windsurf-board>
- <https://star-board.com/products/2026-isonic-windsurf-board>
- <https://star-board.com/products/2027-isonic-windsurf-board>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2026-review-of-the-starboard-futura-120/>
- <https://www.surfdoctor.com/products/starboard-futura-2026-wood-sandwich>
- <https://www.watersportsbase.com/product/starboard-isonic-2025/>

**NeilPryde (NielsTrots)**

- <https://easy-surfshop.com/do/item/N-NP-161032-9596/Windsurf-sail-NeilPryde-RSRacing-EVO-XVII-2026>
- <https://en.wikipedia.org/wiki/Neil_Pryde_Ltd.>
- <https://en.windlounge.de/products/neilpryde-v8-2026>
- <https://industrialhistoryhk.org/neil-pryde-founded-fanling-1970/>
- <https://surf-center.com/en/neilpryde-rs-racing-evo-xvii-2026>
- <https://surf-center.com/en/neilpryde-v8-2026>
- <https://www.nauticexpo.com/prod/neilpryde-windsurfing/product-21433-567701.html>
- <https://www.neilpryde.com/cdn/shop/files/NP_RS-Racing-Evo-XVII_161032_C5_1_3a298735-4e3c-440a-80e0-76d7bb150f37.jpg?v=1764372585&width=2048>
- <https://www.neilpryde.com/products/rs-racing-evoxvi>
- <https://www.neilpryde.com/products/rs-racing-evoxvii>
- <https://www.neilpryde.com/products/speedster>
- <https://www.neilpryde.com/products/v8>
- <https://www.shq.com.au/collections/sails/neilpryde>
- <https://www.surf-magazin.de/en/windsurfing/windsurfing-sails/freerace-and-race/no-cam-2026-freeride-sail-testing-the-neilpryde-speedster-evo/>

**JP Australia (PJ New Sealand)**

- <https://24-7boardsports.com/jp-slalom-2025-windsurfing-board/>
- <https://en.wikipedia.org/wiki/Jason_Polakow>
- <https://jp-australia.com/p/windsurfing/boards/slalom-s-tec/>
- <https://jp-australia.com/p/windsurfing/boards/speed/>
- <https://jp-australia.com/p/windsurfing/boards/super-sport/>
- <https://jp-australia.com/who-we-are/>
- <https://jp-australia.com/wp-content/uploads/2025/11/JP_SLALOM-S-TEC_261224_1-320x1024.webp>
- <https://jp-australia.com/wp-content/uploads/2025/11/JP_SLALOM-S-TEC_261224_2-330x1024.webp>
- <https://jp-australia.com/wp-content/uploads/2025/11/JP_SUPER-SPORT-WOOD-PRO_261214_1-330x1024.webp>
- <https://windsurfing-mag.jp/jp-australia/>
- <https://www.pooleharbour.co.uk/products/jp-slalom-windsurf-board-2025>

**FMX Racing (BMX Boards)**

- <https://nicosurf.it/shop/windsurf/nuovo/tavole/fmx-racing-invictus-gtr-2026/>
- <https://ssi-windsurf.com/en/inicio/72-fmx-racing-invictus-2025.html>
- <https://www.fmxracing.com/>
- <https://www.fmxracing.com/invictus-pro-118/>
- <https://www.fmxracing.com/wp-content/uploads/2025/10/2026_invictus_pro_118.png>
- <https://www.fmxracing.com/wp-content/uploads/2025/11/2026_invictus_gtr_118-263x600.png>
- <https://www.fmxracing.eu/products/fmx-racing-invictus-2026-gtr>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/fmx-racing-maynard-with-his-own-brand/>

**North Sails (SouthSails)**

- <https://en.wikipedia.org/wiki/North_Sails>
- <https://northactionsports.com/cdn/shop/files/product_image_55000260001_100_01_61037db9-ffd3-4872-a4af-e9d099a9575d_grande.png>
- <https://northactionsports.com/products/north-prisma-fin-sail>
- <https://northactionsports.com/products/north-slalom-race-2026>
- <https://www.surf-magazin.de/en/windsurfing/windsurfing-sails/freerace-and-race/new-racing-sail-north-sails-brings-back-the-prisma/>
- <https://www.surfpirates.de/NORTH-SAILS-Slalom-Race-Gen3-2026-77m_1>
- <https://www.telstarsurf.com/north-sails-free-speed-2025-117979.html>
- <https://www.telstarsurf.com/north-sails-slalom-race-117981.html>
- <https://www.windsurf.co.uk/north-free-speed-7-7m-test-review-2024/>
- <https://www.windsurf.co.uk/north-freerace-7-7m-test-review-2024/>
- <https://www.windsurf.co.uk/north-windsurfing-brand-relaunched/>
- <https://www.windsurfjournal.com/article,news,the-return-of-north-windsurfing,9324,en>

**S2Maui (s3kauai)**

- <https://windforce.ca/products/s2-maui-venom-2025>
- <https://windforce.ca/products/s2-maui-wicked-2025>
- <https://www.windsurfing44.com/matos/S2Maui/2025/S2Maui_2025_en.pdf>
- <https://www.windsurfing44.com/matos/S2Maui/2026/S2Maui_2026_en.pdf>

**Tabou (Forbidden)**

- <https://easy-surfshop.com/tabou>
- <https://tabou-boards.com/archive/windsurf-boards-2025/manta-2025/>
- <https://tabou-boards.com/boards/>
- <https://tabou-boards.com/boards/manta/>
- <https://tabou-boards.com/boards/rocket-plus/>
- <https://tabou-boards.com/wp-content/uploads/2025/10/2026-Tabou-Manta-Duo.png>
- <https://tabou-boards.com/wp-content/uploads/2025/10/TABOU_2026-Tabou-Rocket-Plus-113-LTD_242.png>

**GA Sails (GG Sails)**

- <https://easy-surfshop.com/do/item/N-GA-020126NA-SL/Windsurf-sail-GA-Sails-Vapor-2026>
- <https://easy-surfshop.com/do/item/N-GA-25-VAPOR/Windsurf-sail-GA-Sails-Vapor-2025>
- <https://en.windlounge.de/products/ga-sails-cosmic-2026>
- <https://ga-windsurfing.com/media/archive/products-2022/cosmic-2022/>
- <https://ga-windsurfing.com/sails/cosmic/>
- <https://ga-windsurfing.com/sails/vapor/>
- <https://isthmussailboards.com/windsurfing-sail/gaastra-sails.html>
- <https://tabou-boards.com/wp-content/uploads/2025/09/2026GA_COSMIC_C1-1-800x800.png>
- <https://tabou-boards.com/wp-content/uploads/2025/10/2026GA_VAPOR-800x800.png>
- <https://www.windsurfjournal.com/article,news,gaastra-devient-presque-ga-sails,2948>

**Other brands**

- <https://avantisails.com/22-sails/machine-m-9/>
- <https://blog.easy-surfshop.com/racingblade-2026-just-landed/>
- <https://challengersails.co.uk/>
- <https://chswindsolutions.com/shop/vele-sails/fluido-t3/>
- <https://goyawindsurfing.com/sails/y2022/mark-2/>
- <https://hydrostationwatersports.com/shop/goya-bolt-4-carbon-2024-2025/>
- <https://simmerstyle.com/product/2025-s-max/>
- <https://sonntag-fins.com/>
- <https://www.avboards.com/>
- <https://www.carbonartwindsurf.com/boards/slalom/>
- <https://www.exocet-original.com/products/rs-v6-carbon-71>
- <https://www.i-99.it/am-pro-slalom/>
- <https://www.loftsails.com/products/racingblade-7-4-white-2026>
- <https://www.patrikinternational.com/en/shop/windsurfing/windsurf-boards/patrik-slalom-x.html>
- <https://www.patrikinternational.com/en/shop/windsurfing/windsurf-boards/slalom-airinside-v2.html>
- <https://www.windsurf.co.uk/exocet-2024/>

**Fins and rig parts**

- <https://www.select-hydrofoils.com/assets/select_fins_2023_catalog.pdf>
- <https://www.severneshop.com/shop/product/severne-enigma-booms/>
- <https://www.severneshop.com/shop/product/severne-apex-sdm-masts/>
- <https://www.severnesails.com/masts/apex-team/>

**The disciplines, the rules and the magazine tests**

- <https://surf-forum.com/forum/thread/30041-pwa-2026/>
- <https://www.pwaworldtour.com/fileadmin/user_upload/Rule_changes.htm>
- <https://www.pwaworldtour.com/index.php?id=1373>
- <https://www.surf-magazin.de/en/windsurfing/scene-and-events/world-cup-pwa-presents-slalom-x-as-a-new-racing-discipline/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/freeraceboards-2024-test-five-fast-boards-for-hobby-racers-compared/>
- <https://www.surf-magazin.de/en/windsurfing/windsurf-boards/freerace-and-race/test-2026-ten-freerace-boards-put-to-the-test-highway-to-heaven/>

**In the repository**

- `Game/sim/config/board_config.gd`, `sail_config.gd`, `fin_config.gd`: the numbers each entry needs.
- `Game/config/board_default.tres`, `board_freeride_240.tres`, `sail_default.tres`, `sail_6_5.tres`, `fin_default.tres`: the defaults the rules are anchored on.
- `tools/blender/build_rig_models.py`: the traced JP outline and nose rocker, the builder's colour medians, the parts the shaper can draw.
- `Game/race/persona.gd` (the gear group) and `ROADMAP.md` (PH14, RA8).
