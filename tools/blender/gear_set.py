"""The game's gear set: every board, sail and fin the gear page offers, with every number the
simulation needs and the shape and livery its 3D model gets.

A plain Python module (no Blender in it), read by tools/blender/build_gear_models.py (the 3D
models) and later by the catalogue's generator. Run it on its own to see the table:

    python3 tools/blender/gear_set.py                 the table, one line per item
    python3 tools/blender/gear_set.py --json <file>   the same as JSON (what the builder writes
                                                      next to the models as gear_set.json)

Where the numbers come from: Documentation/reports/fleet_gear/brand_research.md, section 3. The
brands' published numbers (length, width, volume, weight; area, luff, boom, mast, extension) are
copied here; every other number comes from the rules of section 3.1, coded below exactly as the
research's own scripts (tools/gear/research_scripts/) computed its tables, so the results equal
section 3's tables. The sizes are the lead's choice (31 October 2026): per board brand the real
slalom sizes nearest to about 95, 112 and 127 litres and one free race board of about 115 L
(Savanna makes free race boards only: two sizes); per sail brand the real slalom sizes nearest to
6.2, 7.0, 7.8 and 8.6 m2 and one free race sail of about 7.0 m2; five fins of the game's own.

Copyright: the game's brands and model names are made up. The real board or sail each item is
modelled on is written in a comment beside it and never in a field, so it cannot reach the game
(Game/tests/unit/test_gear_models.gd checks the names).
"""

import json
import sys

# --------------------------------------------------------------------------------------------
# The fins: five sizes of the game's own fin (no brand), with the area of a real slalom fin of
# that depth (Select's Rhino Pro, brand_research.md section 1.4: a real 38 cm fin has 311 cm2,
# the game's default 38 cm fin 365 cm2). None of the eleven brands makes fins, so they have a
# brand of their own (Game/gear/brands/montag.tres).
# --------------------------------------------------------------------------------------------

# The Rhino Pro's area per depth, cm2 (section 1.4's table, and the research script's in-between
# sizes).
RACE_FIN_AREA_CM2 = {29: 216, 30: 226, 31: 236, 32: 247, 33: 257, 34: 267, 35: 278, 36: 286, 37: 296,
                      38: 311, 39: 322, 40: 333, 41: 344, 42: 358, 43: 369, 44: 378, 45: 390, 46: 405,
                      47: 416, 48: 428}
FIN_SIZES_CM = [34, 38, 40, 42, 46]


FIN_BRAND = "montag"   # the fins' own brand (the lead's decision, 1 November 2026; Michiel may rename it)


def fin(span_cm: int) -> dict:
    """A fin of the game's own: only its depth and area differ from the default fin (section 3.6:
    keep the default's planform and bending numbers). Its root's place depends on the board, so
    each board carries it (fin_root_local)."""
    return {
        "kind": "fin",
        "id": f"{FIN_BRAND}_slalom_{span_cm}",
        "brand": FIN_BRAND,
        "line": "slalom",
        "model_name": "Swift",
        "size": span_cm,
        "config": {"span_m": span_cm / 100.0, "area_m2": RACE_FIN_AREA_CM2[span_cm] / 1e4},
    }


def recommended_fin(width_m: float) -> str:
    """The fin a board of this width gets: the depth the brands recommend grows almost in a
    straight line with the width (section 1.4: span = 0.30 + 0.64 x (width - 0.60) m), rounded to
    the nearest of the five fins."""
    span_cm = 100.0 * (0.30 + 0.64 * (width_m - 0.60))
    nearest = min(FIN_SIZES_CM, key=lambda size: (abs(size - span_cm), size))
    return f"{FIN_BRAND}_slalom_{nearest}"


# --------------------------------------------------------------------------------------------
# The boards. The rules of section 3.1 (boards), as tools/gear/research_scripts/catalogue.py.
# --------------------------------------------------------------------------------------------

def block_factor(width_m: float, line: str) -> float:
    """Rule 3: how much of the box length x width x thickness a board's volume fills (Starboard's
    ten published thicknesses): 0.56 for slalom boards up to 73 cm wide, 0.61 from 77 cm, straight
    between; 0.59 for free race boards."""
    if line == "freerace":
        return 0.59
    if width_m <= 0.73:
        return 0.56
    if width_m >= 0.77:
        return 0.61
    return 0.56 + (width_m - 0.73) / 0.04 * 0.05


def board(brand: str, line: str, model_name: str, length_m: float, width_m: float, volume_m3: float,
          bare_kg: float, research_fin_cm, shape: str, livery: str, tail_width_m=None, thickness_m=None,
          tail_rocker_m: float = 0.0) -> dict:
    """One board: the brand's published numbers in, every BoardConfig number out (section 3.1).
    `tail_width_m` and `thickness_m` are Starboard's where it publishes them (None: the rules).
    `research_fin_cm` is the fin section 3 gives the board, which its mass includes (None: the
    width rule); the fin the game puts on it is `fin` (recommended_fin)."""
    if tail_width_m is None:   # rule 2: the width one foot from the tail
        tail_width_m = 0.848 * width_m - 0.117 if line == "slalom" else 0.571 * width_m + 0.051
    if thickness_m is None:    # rule 3
        thickness_m = volume_m3 / (block_factor(width_m, line) * length_m * width_m)
    if research_fin_cm is None:
        research_fin_cm = round((0.30 + (width_m - 0.60) * 0.64) * 100)
    fin_kg_per_cm = 0.017 if line == "slalom" else 0.024   # rule 7: carbon, or the G10 fin a free race board has
    track_centre = 0.581 * length_m                        # rule 12
    track_back = round(track_centre - 0.08, 3)
    config = {
        "length_m": length_m,
        "width_m": width_m,
        "widest_point_from_tail_m": round((0.50 if line == "slalom" else 0.48) * length_m, 2),   # rule 4
        "tail_width_m": round(tail_width_m, 3),
        "nose_width_m": round((0.78 if line == "slalom" else 0.70) * width_m, 3),               # rule 5
        "thickness_m": round(thickness_m, 3),
        "tail_thickness_m": 0.045 if line == "slalom" else 0.050,                               # rule 6
        "nose_thickness_m": 0.040,
        "volume_m3": volume_m3,
        "mass_kg": round(bare_kg + 0.45 + research_fin_cm * fin_kg_per_cm, 2),                  # rule 7
        "nose_rocker_m": 0.128,                                                                 # rule 8
        "nose_rocker_length_m": round(0.70 * length_m, 2),
        "tail_rocker_m": tail_rocker_m,
        "tail_rocker_length_m": 0.35,
        "hard_rail_to_m": round(0.526 * length_m, 2),                                           # rule 9
        "soft_rail_from_m": round(0.877 * length_m, 2),
        "rail_edge_height_m": 0.03,
        "deadrise_deg": 1.0,
        "back_strap_from_tail_m": 0.235,                                                        # rule 10
        "front_strap_from_tail_m": 0.825,
        "back_strap_out_m": round(0.5 * tail_width_m - 0.095, 3),
        "front_strap_out_m": round(0.5 * width_m - 0.11, 3),
        "fin_box_back_screw_from_tail_m": 0.12,                                                 # rule 11
        "fin_box_front_screw_from_tail_m": 0.235,
        "mast_track_back_from_tail_m": track_back,                                              # rule 12
        "mast_track_front_from_tail_m": round(track_centre + 0.08, 3),
    }
    return {
        "kind": "board",
        "brand": brand,
        "line": line,
        "model_name": model_name,
        "size": round(volume_m3 * 1000),
        "id": f"{brand}_{line}_{round(volume_m3 * 1000)}",
        "fin": recommended_fin(width_m),
        "shape": shape,
        "livery": livery,
        "config": config,
        # Rule 11 and 12: where the fin's root and the mast foot go on this board. They are numbers
        # of FinConfig (root_local) and SailConfig (mast_foot_local) in the game, but they belong
        # to the board, so the catalogue copies them from here when it puts gear together. The
        # heights (y) need the hull's shape and are filled in by the model builder.
        "fin_root_from_tail_m": 0.18,
        "mast_foot_from_tail_m": round(track_back + 0.02, 3),
    }


# The default board (Game/config/board_default.tres) is the JP Slalom 72 of 2025: PJ New
# Sealand's middle slalom board keeps its numbers exactly (section 3.1, rule 1).
DEFAULT_BOARD = {
    "length_m": 2.28, "width_m": 0.72, "widest_point_from_tail_m": 1.14, "tail_width_m": 0.49,
    "nose_width_m": 0.56, "thickness_m": 0.13, "tail_thickness_m": 0.045, "nose_thickness_m": 0.04,
    "volume_m3": 0.117, "mass_kg": 7.8, "nose_rocker_m": 0.128, "nose_rocker_length_m": 1.6,
    "tail_rocker_m": 0.0, "tail_rocker_length_m": 0.35, "hard_rail_to_m": 1.2, "soft_rail_from_m": 2.0,
    "rail_edge_height_m": 0.03, "deadrise_deg": 1.0, "back_strap_from_tail_m": 0.235,
    "front_strap_from_tail_m": 0.825, "back_strap_out_m": 0.15, "front_strap_out_m": 0.25,
    "fin_box_back_screw_from_tail_m": 0.12, "fin_box_front_screw_from_tail_m": 0.235,
    "mast_track_back_from_tail_m": 1.245, "mast_track_front_from_tail_m": 1.405,
}


def default_board(brand: str, model_name: str, shape: str, livery: str) -> dict:
    item = board(brand, "slalom", model_name, 2.28, 0.72, 0.117, 6.6, 38, shape, livery)
    item["config"] = dict(DEFAULT_BOARD)
    item["mast_foot_from_tail_m"] = 1.265
    item["default"] = True
    return item


# Line by line: brand slug, line, the game's model name, length m, width m, volume m3, the
# brand's bare weight kg, the fin cm section 3 gives (its mass includes it), the shape style and
# the livery style (build_gear_models.py), then Starboard's published tail and thickness.
BOARDS = [
    # Moonboard. Modelled on the Starboard iSonic 63, 67 and 77 (2026, Carbon Reflex) and the
    # Futura 120 (2026, Wood Sandwich). Futura 110 and 120 are equally near 115 L: ties go to the
    # bigger board.
    board("moonboard", "slalom", "uSonic", 2.26, 0.63, 0.098, 6.05, 32, "moonboard_slalom", "moonboard",
          tail_width_m=0.414, thickness_m=0.122),
    board("moonboard", "slalom", "uSonic", 2.28, 0.67, 0.111, 6.34, 36, "moonboard_slalom", "moonboard",
          tail_width_m=0.457, thickness_m=0.130),
    board("moonboard", "slalom", "uSonic", 2.29, 0.77, 0.129, 6.81, 41, "moonboard_slalom", "moonboard",
          tail_width_m=0.545, thickness_m=0.120),
    board("moonboard", "freerace", "Orbit", 2.30, 0.76, 0.120, 7.4, 42, "moonboard_freerace", "moonboard",
          tail_width_m=0.487, thickness_m=0.116),
    # PJ New Sealand. Modelled on the JP Australia Slalom S-TEC 62.5 and 76 (2026), the SL 72 of
    # 2025 (the default board) and the Super Sport 111 (2026, Wood Pro).
    board("pj_new_sealand", "slalom", "Slalom T-SEC", 2.30, 0.625, 0.097, 5.9, None, "pj_slalom", "pj_new_sealand"),
    default_board("pj_new_sealand", "Slalom T-SEC", "pj_slalom", "pj_new_sealand"),
    board("pj_new_sealand", "slalom", "Slalom T-SEC", 2.28, 0.76, 0.125, 6.9, None, "pj_slalom", "pj_new_sealand"),
    board("pj_new_sealand", "freerace", "Hyper Sport", 2.34, 0.70, 0.111, 7.2, 40, "pj_freerace", "pj_new_sealand"),
    # Tripletone. Modelled on the Duotone Falcon_Fin SLS 98, 111 and 129 (2026) and the Blitz SLS
    # 116 (2026).
    board("tripletone", "slalom", "Hawk_Fin", 2.26, 0.63, 0.098, 6.40, 35, "tripletone_slalom", "tripletone"),
    board("tripletone", "slalom", "Hawk_Fin", 2.25, 0.68, 0.111, 6.95, 38, "tripletone_slalom", "tripletone"),
    board("tripletone", "slalom", "Hawk_Fin", 2.24, 0.80, 0.129, 7.60, 44, "tripletone_slalom", "tripletone"),
    board("tripletone", "freerace", "Thunder", 2.34, 0.68, 0.116, 7.0, 38, "tripletone_freerace", "tripletone"),
    # BMX Boards. Modelled on the FMX Racing Invictus Pro 98, 108 and 128 (2026) and the Invictus
    # GTR 118 (2026).
    board("bmx_boards", "slalom", "Invincible", 2.33, 0.63, 0.098, 6.0, 32, "bmx_slalom", "bmx_boards"),
    board("bmx_boards", "slalom", "Invincible", 2.33, 0.70, 0.108, 6.6, 36, "bmx_slalom", "bmx_boards"),
    board("bmx_boards", "slalom", "Invincible", 2.28, 0.81, 0.128, 7.2, 41, "bmx_slalom", "bmx_boards"),
    board("bmx_boards", "freerace", "Invincible GTS", 2.33, 0.72, 0.118, 7.4, 37, "bmx_freerace", "bmx_boards"),
    # Forbidden. Modelled on the Tabou Manta 61, 71 and 77 (2026, Team) and the Rocket+ 113 (2026,
    # LTD).
    board("forbidden", "slalom", "Stingray", 2.33, 0.61, 0.096, 6.1, None, "forbidden_slalom", "forbidden"),
    board("forbidden", "slalom", "Stingray", 2.33, 0.71, 0.116, 6.8, None, "forbidden_slalom", "forbidden"),
    board("forbidden", "slalom", "Stingray", 2.32, 0.77, 0.122, 7.4, None, "forbidden_slalom", "forbidden"),
    board("forbidden", "freerace", "Missile+", 2.32, 0.73, 0.113, 7.6, 38, "forbidden_freerace", "forbidden"),
    # Savanna (no slalom board: the brand it is named after makes none). Modelled on the Severne
    # Fox Pro 105 and 125 (2026), with the regular Fox's fin in the mass; 1 mm of tail rocker as
    # surf-magazin measured on the Fox.
    board("savanna", "freerace", "Jackal", 2.39, 0.65, 0.105, 6.07, 36, "savanna_freerace", "savanna",
          tail_rocker_m=0.001),
    board("savanna", "freerace", "Jackal", 2.44, 0.71, 0.125, 6.79, 42, "savanna_freerace", "savanna",
          tail_rocker_m=0.001),
]


# --------------------------------------------------------------------------------------------
# The sails. The rules of section 3.1 (sails), as tools/gear/research_scripts/sails.py.
# --------------------------------------------------------------------------------------------

MAST_KG = {370: 1.30, 400: 1.42, 430: 1.55, 460: 1.77, 490: 2.07, 520: 2.10}   # rule 5
DEFAULT_RIG_MASS_RATIO = 9.5 / 12.4   # the default 8.0 keeps 9.5 kg of its real 12.4 kg (sail_config.gd)


def boom_kg(boom_m: float) -> float:
    """Rule 5: the boom's weight by the sail's boom length (Severne's Enigma booms)."""
    if boom_m <= 1.80:
        return 2.23
    if boom_m <= 2.00:
        return 2.61
    if boom_m <= 2.15:
        return 2.68
    if boom_m <= 2.30:
        return 3.49
    return 3.52


def sail(brand: str, line: str, model_name: str, area_m2: float, luff_m: float, boom_m: float, mast_cm: int,
         extension_m, sail_kg: float, cams, battens: int, shape: str, livery: str) -> dict:
    """One sail: the brand's published numbers in (the boom at its longest setting, the mast's
    length and the extension where published, None for the rule), every SailConfig number of
    section 3 out. `cams` is 4, 3, 2, 0 or "air" (North's inflatable sleeve)."""
    mast_m = luff_m + 0.02 if extension_m is None else mast_cm / 100 + extension_m   # rule 2
    boom_height_m = 1.50 if luff_m >= 4.80 else (1.45 if luff_m >= 4.40 else 1.40)    # rule 3
    camber = {4: 0.075, 3: 0.072, 2: 0.070, 0: 0.068, "air": 0.072}[cams]            # rule 4
    rig_real_kg = sail_kg + MAST_KG[mast_cm] + boom_kg(boom_m) + 1.3                  # rule 5
    size_slug = f"{area_m2:.1f}".replace(".", "_")
    return {
        "kind": "sail",
        "brand": brand,
        "line": line,
        "model_name": model_name,
        "size": area_m2,
        "id": f"{brand}_{line}_{size_slug}",
        "battens": battens,
        "cams": cams,
        "mast_cm": mast_cm,
        "shape": shape,
        "livery": livery,
        "config": {
            "area_m2": area_m2,
            "luff_m": luff_m,
            "boom_m": boom_m,
            "boom_height_m": boom_height_m,
            "mast_m": round(mast_m, 2),
            "camber": camber,
            # Rule 5 gives the whole real rig; the default 8.0 deliberately keeps 9.5 kg of its
            # real 12.4 kg (for the tack in 18 kt). Which one the catalogue uses is Michiel's call
            # (brand_research.md section 5, question 2): both are here, rig_mass_kg is the
            # default's ratio.
            "rig_mass_kg": round(rig_real_kg * DEFAULT_RIG_MASS_RATIO, 1),
            "rig_mass_real_kg": round(rig_real_kg, 1),
            "rig_com_height_m": round(0.345 * luff_m, 2),                                   # rule 6
            "ce_height_fraction": 0.41 if line == "slalom" else 0.42,                      # rule 7
            "ce_boom_fraction": 0.35,
        },
    }


# The default sail's numbers (Game/config/sail_default.tres): the HGO 8.0 keeps 9.5 kg of its real
# 12.4 kg rig and a mast foot 2 cm over the board's default mast track (section 3.1).
DEFAULT_SAIL = {
    "area_m2": 8.0, "luff_m": 5.22, "boom_m": 2.2, "boom_height_m": 1.5, "mast_m": 5.26, "camber": 0.07,
    "rig_mass_kg": 9.5, "rig_mass_real_kg": 12.4, "rig_com_height_m": 1.8, "ce_height_fraction": 0.41,
    "ce_boom_fraction": 0.35,
}


def default_sail(brand: str, model_name: str, shape: str, livery: str) -> dict:
    item = sail(brand, "slalom", model_name, 8.0, 5.22, 2.2, 490, 0.36, 6.0, 4, 7, shape, livery)
    item["config"] = dict(DEFAULT_SAIL)
    item["default"] = True
    return item


# Line by line: brand slug, line, the game's model name, area m2, luff m, boom m, mast cm, the
# extension m (None: the rule), the sail's weight kg (published, or estimated where marked), the
# cams, the battens, the shape style and the livery style.
SAILS = [
    # Tripletone. Modelled on the Duotone Warp_Fin 6.2, 6.7, 7.7 and 8.5 (2026) and the S_Pace 7.3
    # (2026). 6.6 and 7.3 are both near 7.0: 7.3 is nearer.
    sail("tripletone", "slalom", "Weft_Fin", 6.2, 4.32, 1.92, 430, None, 5.40, 4, 7, "tripletone_slalom", "tripletone"),
    sail("tripletone", "slalom", "Weft_Fin", 6.7, 4.62, 2.02, 430, None, 5.60, 4, 7, "tripletone_slalom", "tripletone"),
    sail("tripletone", "slalom", "Weft_Fin", 7.7, 4.88, 2.14, 460, None, 6.00, 4, 7, "tripletone_slalom", "tripletone"),
    sail("tripletone", "slalom", "Weft_Fin", 8.5, 5.14, 2.28, 490, None, 6.30, 4, 7, "tripletone_slalom", "tripletone"),
    sail("tripletone", "freerace", "T_Pace", 7.3, 4.76, 2.04, 460, None, 5.30, 3, 7, "tripletone_freerace", "tripletone"),
    # Savanna. Modelled on the Severne Mach 9 5.5, 6.5, 7.5 and 8.5 (026): the brand makes only
    # five race sizes, so its four nearest different sizes are these. The free race sail on the
    # Severne Overdrive M4 7.0.
    sail("savanna", "slalom", "Cheetah", 5.5, 4.28, 1.77, 400, None, 5.30, 4, 7, "savanna_slalom", "savanna"),
    sail("savanna", "slalom", "Cheetah", 6.5, 4.56, 1.98, 430, None, 5.96, 4, 7, "savanna_slalom", "savanna"),
    sail("savanna", "slalom", "Cheetah", 7.5, 4.90, 2.08, 460, None, 6.33, 4, 7, "savanna_slalom", "savanna"),
    sail("savanna", "slalom", "Cheetah", 8.5, 5.18, 2.22, 490, None, 6.74, 4, 7, "savanna_slalom", "savanna"),
    sail("savanna", "freerace", "Gazelle", 7.0, 4.61, 1.89, 430, None, 4.65, 3, 7, "savanna_freerace", "savanna"),
    # The default sail (Game/config/sail_default.tres, the Severne HGO iQFOiL 8.0) as Savanna's,
    # with its own numbers kept exactly (the catalogue's test compares them).
    default_sail("savanna", "Cheetah", "savanna_slalom", "savanna"),
    # Point.9. Modelled on the Point-7 AC-1 LTD 5.9, 6.8 and 7.8 (026, stitched) and 8.8 (025),
    # and the AC-2 6.8 (025-026). The AC-1 LTD 6.8 is not in section 3's table (an in-between
    # size): its numbers are from section 2.3 (luff 464, boom 204, mast 430 + 36, 6.1 kg) with
    # the same rules. 5.9 and 6.5 are equally near 6.2; 5.9 keeps the four sizes apart.
    sail("point9", "slalom", "BC-1", 5.9, 4.42, 1.92, 400, 0.44, 5.3, 3, 7, "point9_slalom", "point9"),
    sail("point9", "slalom", "BC-1", 6.8, 4.64, 2.04, 430, 0.36, 6.1, 3, 7, "point9_slalom", "point9"),
    sail("point9", "slalom", "BC-1", 7.8, 4.98, 2.12, 460, 0.40, 6.6, 3, 7, "point9_slalom", "point9"),
    sail("point9", "slalom", "BC-1", 8.8, 5.24, 2.30, 490, 0.36, 6.9, 3, 7, "point9_slalom", "point9"),
    sail("point9", "freerace", "BC-2", 6.8, 4.63, 2.04, 430, 0.36, 4.8, 2, 7, "point9_freerace", "point9"),
    # NielsTrots. Modelled on the NeilPryde RS:Racing EVO XVII 6.5, 7.4, 8.2 and 9.0 (2026) and the
    # V8 7.2 (2026).
    sail("nielstrots", "slalom", "RT:Racing", 6.5, 4.58, 1.92, 430, 0.28, 5.3, 4, 7, "nielstrots_slalom", "nielstrots"),
    sail("nielstrots", "slalom", "RT:Racing", 7.4, 4.86, 2.06, 460, 0.26, 5.5, 4, 7, "nielstrots_slalom", "nielstrots"),
    sail("nielstrots", "slalom", "RT:Racing", 8.2, 5.12, 2.16, 490, 0.22, 6.1, 4, 7, "nielstrots_slalom", "nielstrots"),
    sail("nielstrots", "slalom", "RT:Racing", 9.0, 5.38, 2.26, 520, 0.18, 6.4, 4, 7, "nielstrots_slalom", "nielstrots"),
    sail("nielstrots", "freerace", "V9", 7.2, 4.67, 2.04, 460, 0.08, 4.5, 2, 7, "nielstrots_freerace", "nielstrots"),
    # SouthSails. Modelled on the North Sails Slalom Race GEN3 6.0, 6.8 and 7.7 (2026) and the
    # Slalom Race 8.6 (2025's luff and boom, the weight estimated), and the Free Speed 7.7 (2024
    # test; no cams, 6 battens; the weight estimated).
    sail("southsails", "slalom", "Slalom Sprint", 6.0, 4.38, 1.83, 430, 0.08, 4.30, "air", 7, "southsails_slalom", "southsails"),
    sail("southsails", "slalom", "Slalom Sprint", 6.8, 4.56, 1.96, 430, 0.26, 4.50, "air", 7, "southsails_slalom", "southsails"),
    sail("southsails", "slalom", "Slalom Sprint", 7.7, 4.92, 2.15, 460, 0.32, 4.70, "air", 7, "southsails_slalom", "southsails"),
    sail("southsails", "slalom", "Slalom Sprint", 8.6, 5.18, 2.17, 490, None, 4.95, "air", 7, "southsails_slalom", "southsails"),
    sail("southsails", "freerace", "Free Sprint", 7.7, 4.90, 2.09, 460, None, 4.6, 0, 6, "southsails_freerace", "southsails"),
    # s3kauai. Modelled on the S2Maui Venom-XI 6.1, 6.7, 7.6 and 9.0 (2026) and the Wicked 7.0
    # (2026). S2Maui publishes no weights (estimated, as section 3 does). The Venom-XI 6.1 and the
    # Wicked 7.0 are not in section 3's tables: their numbers are from section 2.9 with the same
    # rules (6.1: luff 434, boom 187, mast 430, 5.5 kg est.; 7.0: luff 458, boom 204, mast 430,
    # 4.6 kg est.). 8.2 and 9.0 are equally near 8.6: ties go to the bigger sail.
    sail("s3kauai", "slalom", "Viper", 6.1, 4.34, 1.87, 430, None, 5.5, 4, 7, "s3kauai_slalom", "s3kauai"),
    sail("s3kauai", "slalom", "Viper", 6.7, 4.60, 2.02, 430, None, 5.8, 4, 7, "s3kauai_slalom", "s3kauai"),
    sail("s3kauai", "slalom", "Viper", 7.6, 4.81, 2.17, 460, None, 6.2, 4, 7, "s3kauai_slalom", "s3kauai"),
    sail("s3kauai", "slalom", "Viper", 9.0, 5.16, 2.40, 490, None, 6.8, 4, 7, "s3kauai_slalom", "s3kauai"),
    sail("s3kauai", "freerace", "Wild", 7.0, 4.58, 2.04, 430, None, 4.6, 2, 7, "s3kauai_freerace", "s3kauai"),
    # GG Sails. Modelled on the GA Sails Vapor 5.7, 6.7, 7.7 and 8.4 (2026) and the Cosmic 7.2
    # (2026; the weight from the 2022-23 table, estimated).
    sail("gg_sails", "slalom", "Vapour", 5.7, 4.25, 1.87, 400, 0.26, 5.27, 4, 7, "gg_slalom", "gg_sails"),
    sail("gg_sails", "slalom", "Vapour", 6.7, 4.61, 1.96, 430, 0.32, 5.80, 4, 7, "gg_slalom", "gg_sails"),
    sail("gg_sails", "slalom", "Vapour", 7.7, 4.94, 2.09, 460, 0.34, 6.15, 4, 7, "gg_slalom", "gg_sails"),
    sail("gg_sails", "slalom", "Vapour", 8.4, 5.15, 2.17, 490, 0.26, 6.39, 4, 7, "gg_slalom", "gg_sails"),
    sail("gg_sails", "freerace", "Cosmos", 7.2, 4.81, 2.02, 460, 0.22, 5.0, 2, 7, "gg_freerace", "gg_sails"),
]

FINS = [fin(span_cm) for span_cm in FIN_SIZES_CM]

ITEMS = BOARDS + SAILS + FINS


def items(kind: str = "", brand: str = "") -> list:
    """The items of one kind ("board", "sail", "fin") and one brand's slug ("" for all)."""
    return [item for item in ITEMS if (not kind or item["kind"] == kind) and (not brand or item["brand"] == brand)]


def find(item_id: str) -> dict:
    for item in ITEMS:
        if item["id"] == item_id:
            return item
    raise KeyError(item_id)


def table_line(item: dict) -> str:
    c = item["config"]
    if item["kind"] == "board":
        return (f"{item['id']:32} {item['model_name']:15} {c['length_m']:.2f} x {c['width_m']:.3f} m, "
                f"{c['volume_m3'] * 1000:.0f} L, {c['mass_kg']:.2f} kg, tail {c['tail_width_m']:.3f}, "
                f"thick {c['thickness_m']:.3f}, {item['fin']}")
    if item["kind"] == "sail":
        return (f"{item['id']:32} {item['model_name']:15} {c['area_m2']:.1f} m2, luff {c['luff_m']:.2f}, "
                f"boom {c['boom_m']:.2f}, mast {c['mast_m']:.2f}, boom height {c['boom_height_m']:.2f}, "
                f"rig {c['rig_mass_kg']:.1f} ({c['rig_mass_real_kg']:.1f}) kg, {item['battens']} battens")
    return f"{item['id']:32} {c['span_m']:.2f} m, {c['area_m2']:.4f} m2"


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--json":
        with open(sys.argv[2], "w", encoding="utf-8") as out:
            json.dump(ITEMS, out, indent=1)
        print(f"Wrote {len(ITEMS)} items to {sys.argv[2]}")
    else:
        for entry in ITEMS:
            print(table_line(entry))
        print(f"{len(BOARDS)} boards, {len(SAILS)} sails, {len(FINS)} fins")
