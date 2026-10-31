"""Builds the 3D models of the gear page's boards, sails and fins (tools/blender/gear_set.py),
shaped and coloured after the game's brands (Documentation/reports/fleet_gear/gear_models.md).

Run it from the repository root:

    tools/blender.sh tools/blender/build_gear_models.py [--brand=<slug>] [--only=boards|sails|fins] [--item=<id>]

It writes into Game/assets/models/gear/:

    <brand slug>/<item id>.glb          a board ("Hull", "DeckPads", "Footstraps", "FinBox",
                                        "MastTrack") or a sail ("SailCloth", "SailClewRing",
                                        "TackFairing"), with the same node and material names,
                                        origins and axes as the default parts that
                                        build_rig_models.py builds (its header has the rules), so
                                        RigVisuals places them unchanged
    <brand slug>/<item id>_deck.png     a board's deck and bottom pictures, in the hull's UV
    <brand slug>/<item id>_bottom.png
    <brand slug>/<item id>_panels.png   a sail's panel picture, in the sail's UV, with the alpha
                                        code of sail_panels.png (1 the brand's cloth, 0.75 a print
                                        that keeps its colours, 0.55 and 0.35 a print on one side,
                                        0 clear film)
    fins/fin_<cm>.glb                   the game's own fins ("Fin")
    gear_set.json                       the gear table as the models were built from it, with the
                                        files of each item (for the gear view and the tests)

How it works: build_rig_models.py builds the default board and sail from the numbers in
Game/config/, which it keeps in module-level names (BOARD, BOARD_L, SAIL, BOOM_M, FULL_BATTENS,
...) that its functions read. This script imports it as a module, puts one item's numbers in those
names (use_board_numbers, use_sail_numbers, use_fin_numbers: the same formulas the module uses
when it reads the configs) and calls its functions to build the parts. What the default rig does
not have is written here: each brand's outline, cut-outs, bottom vee, pads, batten layout, sleeve
and windows (BOARD_SHAPES, SAIL_SHAPES). The pictures (the brands' liveries) are drawn in
gear_liveries.py. Before it builds anything, it checks that putting the default board's and sail's
numbers in through these functions gives exactly the module's own numbers.
"""

import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_rig_models as rig   # noqa: E402  (the default rig's builder, used as a library)
import gear_liveries as livery   # noqa: E402
import gear_set                  # noqa: E402

GEAR_DIR = rig.REPO / "Game" / "assets" / "models" / "gear"
RES_GEAR_DIR = "res://assets/models/gear"

# The module's own traced numbers, kept before anything here changes them: JP's nose rocker and
# outline (2.28 x 0.72 m), and the HGO's batten layout as fractions of its luff.
TRACED_NOSE_ROCKER = list(rig.JP_NOSE_ROCKER)
TRACED_OUTLINE = list(rig.JP_OUTLINE)
TRACED_LENGTH, TRACED_WIDTH = rig.JP_LENGTH, rig.JP_WIDTH
# JP's pad wedge between the back straps, from the tail (the module's WEDGE_T, which its back pad's
# outline and its fin box's screws read).
JP_WEDGE_T = rig.WEDGE_T


# --------------------------------------------------------------------------------------------
# The boards' shapes, per brand and line (brand_research.md sections 2 and 4). What each number
# means:
#   outline        "traced": JP's traced outline (the default board), scaled to the size. Or a
#                  dict for the outline drawn through the board's own tail, nose and widest
#                  point (BoardConfig, section 3) with:
#       transom        the tail's end, full width as a share of the board's width (JP: 0.19)
#       tail_fill      how full the tail is between its end and one foot in: 0 is a straight
#                      line, more is squarer (JP: 0.17)
#       mid_fill       the same between one foot from the tail and the parallel middle (JP: 0.14)
#       parallel       how long the middle is within a few millimetres of the full width, as a
#                      share of the length (JP: 0.22)
#       nose_shoulder  the width 15 cm from the nose as a share of the width one foot from the
#                      nose: a wide, round nose is more (JP: 0.70)
#       nose_tip       the same 4 cm from the nose: a pointed nose is less (JP: 0.33)
#   transom_corner the radius of the tail's corners, m (square tails have small ones)
#   deck_exponent  the deck's dome across: 2 is round, 3 and more flatter with tighter edges
#   rail_fraction  how high the rail's widest line is, as a share of the thickness (a high apex
#                  is more, rails tucked under the board less)
#   vee            the bottom's vee, m: how much higher its edges are than its centreline at the
#                  tail, at the straps (0.35 of the length) and in front (0.7); negative is an
#                  inverse vee. A little deeper than the real ones (7 to 10 mm), so the shading
#                  shows it. The centreline stays where the physics has the bottom.
#   concave        the double concave in front, m: two hollows either side of the centreline
#   steps          the cut-outs: (from the tail to t m, the planing bottom's half width from a to
#                  b m) per step, for a 72 cm board (scaled by the width); where a step ends the
#                  bottom widens at once, so the deck overhangs the bottom behind it
#   pads           the deck pads' layout (build_deck_pads)
# The colours of the pads, the straps' trim and the like are the livery's (gear_liveries.py).
# --------------------------------------------------------------------------------------------

BOARD_SHAPES = {
    # The JP Slalom S-TEC: the traced outline, a "transforming vee" (deepest ahead of the mast,
    # narrow between the straps, opening to the tail), high-apex rails, the double-step tail with
    # the deck wide over it, the pad wedge between the back straps.
    "pj_slalom": dict(outline="traced", transom_corner=0.015, deck_exponent=2.6, rail_fraction=0.38,
                      vee=(0.008, 0.004, 0.012), concave=0.0,
                      steps=[(0.11, 0.050, 0.068), (0.22, 0.085, 0.105)], pads="jp"),
    # The Super Sport: a parallel outline at the mast base, a wider tail, small tail cut-outs.
    "pj_freerace": dict(outline=dict(transom=0.22, tail_fill=0.18, mid_fill=0.16, parallel=0.24,
                                     nose_shoulder=0.66, nose_tip=0.33),
                        transom_corner=0.015, deck_exponent=2.6, rail_fraction=0.36,
                        vee=(0.006, 0.006, 0.012), concave=0.0, steps=[(0.16, 0.12, 0.16)], pads="jp"),
    # The Falcon: compact and parallel, a wide square tail with two steps, a flatter deck.
    "tripletone_slalom": dict(outline=dict(transom=0.30, tail_fill=0.32, mid_fill=0.22, parallel=0.30,
                                           nose_shoulder=0.74, nose_tip=0.40),
                              transom_corner=0.006, deck_exponent=3.0, rail_fraction=0.38,
                              vee=(0.003, 0.004, 0.008), concave=0.003,
                              steps=[(0.14, 0.070, 0.100), (0.30, 0.150, 0.190)], pads="diamond"),
    # The Blitz: narrower, more vee from the mast track back, a smaller cut-out.
    "tripletone_freerace": dict(outline=dict(transom=0.22, tail_fill=0.15, mid_fill=0.12, parallel=0.18,
                                             nose_shoulder=0.66, nose_tip=0.33),
                                transom_corner=0.010, deck_exponent=2.8, rail_fraction=0.36,
                                vee=(0.006, 0.009, 0.012), concave=0.003, steps=[(0.18, 0.12, 0.16)],
                                pads="diamond"),
    # The iSonic: a square, wide outline with the widest point near the middle, double-step cut-
    # aways (the triangle between them is painted), a flat vee to double concave.
    "moonboard_slalom": dict(outline=dict(transom=0.26, tail_fill=0.25, mid_fill=0.20, parallel=0.26,
                                          nose_shoulder=0.72, nose_tip=0.38),
                             transom_corner=0.012, deck_exponent=2.6, rail_fraction=0.35,
                             vee=(0.002, 0.004, 0.006), concave=0.004,
                             steps=[(0.12, 0.060, 0.090), (0.26, 0.130, 0.170)], pads="rect"),
    # The Futura: a wide but thin, spoon-shaped nose with a narrow tail.
    "moonboard_freerace": dict(outline=dict(transom=0.18, tail_fill=0.10, mid_fill=0.12, parallel=0.18,
                                            nose_shoulder=0.80, nose_tip=0.52),
                               transom_corner=0.020, deck_exponent=2.6, rail_fraction=0.36,
                               vee=(0.004, 0.005, 0.010), concave=0.003, steps=[(0.16, 0.11, 0.15)],
                               pads="rect"),
    # The Invictus: the longest outline, a wide nose, a parallel middle, a curved tail, separate
    # cut-out plates (painted as plates with screws), vee and double concave in the nose and an
    # inverted vee in the tail, a flat deck.
    "bmx_slalom": dict(outline=dict(transom=0.20, tail_fill=0.12, mid_fill=0.18, parallel=0.34,
                                    nose_shoulder=0.80, nose_tip=0.45),
                       transom_corner=0.012, deck_exponent=3.2, rail_fraction=0.33,
                       vee=(-0.005, 0.000, 0.008), concave=0.004, steps=[(0.30, 0.100, 0.160)], pads="arrow"),
    # The GTR: the same outlines and plates.
    "bmx_freerace": dict(outline=dict(transom=0.20, tail_fill=0.12, mid_fill=0.18, parallel=0.34,
                                      nose_shoulder=0.80, nose_tip=0.45),
                         transom_corner=0.012, deck_exponent=3.2, rail_fraction=0.35,
                         vee=(-0.003, 0.002, 0.008), concave=0.004, steps=[(0.30, 0.100, 0.160)], pads="arrow"),
    # The Manta: more curve in the outline, large cut-outs, an extra tail vee and a deep front
    # vee, rails tucked under in the tail, hexagon pads.
    "forbidden_slalom": dict(outline=dict(transom=0.20, tail_fill=0.18, mid_fill=0.10, parallel=0.16,
                                          nose_shoulder=0.68, nose_tip=0.34),
                             transom_corner=0.015, deck_exponent=2.4, rail_fraction=0.30,
                             vee=(0.008, 0.006, 0.016), concave=0.0,
                             steps=[(0.16, 0.050, 0.080), (0.34, 0.110, 0.160)], pads="hex"),
    # The Rocket+: a rounder deck at the back straps, a deeper vee in the nose, tail cut-outs.
    "forbidden_freerace": dict(outline=dict(transom=0.18, tail_fill=0.14, mid_fill=0.10, parallel=0.14,
                                            nose_shoulder=0.70, nose_tip=0.36),
                               transom_corner=0.018, deck_exponent=2.2, rail_fraction=0.32,
                               vee=(0.004, 0.006, 0.016), concave=0.0, steps=[(0.16, 0.11, 0.15)], pads="hex"),
    # The Fox: long, with a tapered nose, a moderate tail, a pronounced vee, medium cut-outs.
    "savanna_freerace": dict(outline=dict(transom=0.17, tail_fill=0.10, mid_fill=0.08, parallel=0.12,
                                          nose_shoulder=0.58, nose_tip=0.28),
                             transom_corner=0.020, deck_exponent=2.4, rail_fraction=0.33,
                             vee=(0.010, 0.010, 0.014), concave=0.0, steps=[(0.18, 0.12, 0.16)], pads="rounded"),
}

BOARD_STATIONS = 50   # cross-sections along the hull (the default board has 120; the shape needs fewer)
RING_POINTS = 40      # points round a cross-section (48)
STRAP_POINTS = 15     # points along a footstrap's arch (the default board's have 25)
STRAP_SIDES = 12      # points round its cross-section (16)


def outline_table(length_m: float, width_m: float, config: dict, style) -> list:
    """The deck's outline as (metres from the tail, full width in metres) points."""
    if style == "traced":
        return [(x * length_m / TRACED_LENGTH, w * width_m / TRACED_WIDTH) for x, w in TRACED_OUTLINE]
    s = style
    one_foot = rig.ONE_FOOT_M
    tail = config["tail_width_m"] / width_m
    nose = config["nose_width_m"] / width_m
    widest = config["widest_point_from_tail_m"]
    half_parallel = 0.5 * s["parallel"] * length_m
    full = 0.992   # the parallel middle's ends, a few millimetres under the full width
    points = [
        (0.0, s["transom"]),
        (0.5 * one_foot, s["transom"] + (tail - s["transom"]) * (0.5 + s["tail_fill"])),
        (one_foot, tail),
        (0.5 * (one_foot + widest - half_parallel), tail + (full - tail) * (0.5 + s["mid_fill"])),
        (widest - half_parallel, full),
        (widest, 1.0),
        (widest + half_parallel, full),
        (length_m - one_foot, nose),
        (length_m - 0.15, nose * s["nose_shoulder"]),
        (length_m - 0.04, nose * s["nose_tip"]),
        (length_m, 0.0),
    ]
    return [(t, f * width_m) for t, f in points]


# --------------------------------------------------------------------------------------------
# The sails' shapes, per brand and line. What each number means (the default sail's, the
# Severne HGO 8.0, in brackets; build_rig_models.py describes them):
#   head_x         the head's aft corner, as a share of the drawing's clew chord (0.384): a high,
#                  narrow head is less
#   foot_aft_x     the foot's aft corner, the same way (0.865): a long foot is more
#   foot_rise      how high the foot's aft corner is over the tack, m (0.21): a low foot that
#                  closes the gap to the deck is less
#   foot_sag       how far the foot bows down between its corners, m (0.03)
#   clew_bulge     how far the leech under the clew bows out, m (0.05): a cutaway clew is negative
#   roach          how far the leech above the clew bows out, m (0.03)
#   battens        the full battens, top to bottom: (luff end, leech end) as shares of the luff
#                  from the tack; "clew" is the batten that ends at the clew, "foot" the one just
#                  over the foot's aft corner (the default's seven: 0.919/head, 0.814/0.823,
#                  0.686/0.675, 0.551/0.519, 0.401/0.353, 0.241/clew, 0.114/foot)
#   sleeve         the luff sleeve's depth behind the mast where the battens have cams, m (0.20):
#                  a race sail's wide sleeve is more, a free race sail's narrow one less
# The cams are the item's (gear_set.py): they sit on the lowest battens, where the sleeve is deep.
# --------------------------------------------------------------------------------------------

SEVEN_BATTENS = [(0.919, "head"), (0.814, 0.823), (0.686, 0.675), (0.551, 0.519), (0.401, 0.353),
                 (0.241, "clew"), (0.114, "foot")]
# Raked: each batten's leech end lower than the default's, as NielsTrots' raked layout.
SEVEN_RAKED = [(0.919, "head"), (0.818, 0.800), (0.690, 0.645), (0.556, 0.490), (0.405, 0.330),
               (0.241, "clew"), (0.114, "foot")]
SIX_BATTENS = [(0.905, "head"), (0.770, 0.775), (0.610, 0.590), (0.440, 0.400),
               (0.241, "clew"), (0.110, "foot")]

SAIL_SHAPES = {
    # The Warp_Fin: tall and narrow, a large cutaway at the clew.
    "tripletone_slalom": dict(head_x=0.36, foot_aft_x=0.80, foot_rise=0.17, foot_sag=0.03, clew_bulge=-0.10,
                              roach=0.035, battens=SEVEN_BATTENS, sleeve=0.20),
    "tripletone_freerace": dict(head_x=0.38, foot_aft_x=0.80, foot_rise=0.22, foot_sag=0.02, clew_bulge=-0.07,
                                roach=0.030, battens=SEVEN_BATTENS, sleeve=0.15),
    # The Mach: a race outline with one seamless foot panel, long and low.
    "savanna_slalom": dict(head_x=0.39, foot_aft_x=0.88, foot_rise=0.15, foot_sag=0.035, clew_bulge=0.04,
                           roach=0.030, battens=SEVEN_BATTENS, sleeve=0.20),
    "savanna_freerace": dict(head_x=0.40, foot_aft_x=0.84, foot_rise=0.22, foot_sag=0.03, clew_bulge=0.03,
                             roach=0.030, battens=SEVEN_BATTENS, sleeve=0.15),
    # The AC-1: the XXL race sleeve, the foot cut straight and low along the deck.
    "point9_slalom": dict(head_x=0.37, foot_aft_x=0.92, foot_rise=0.08, foot_sag=0.0, clew_bulge=0.02,
                          roach=0.030, battens=SEVEN_BATTENS, sleeve=0.26),
    "point9_freerace": dict(head_x=0.38, foot_aft_x=0.88, foot_rise=0.13, foot_sag=0.0, clew_bulge=0.02,
                            roach=0.030, battens=SEVEN_BATTENS, sleeve=0.17),
    # The RS:Racing: a high, narrow head, the battens raked to the sailing rake.
    "nielstrots_slalom": dict(head_x=0.30, foot_aft_x=0.86, foot_rise=0.18, foot_sag=0.03, clew_bulge=0.0,
                              roach=0.040, battens=SEVEN_RAKED, sleeve=0.21),
    "nielstrots_freerace": dict(head_x=0.33, foot_aft_x=0.84, foot_rise=0.22, foot_sag=0.03, clew_bulge=0.0,
                                roach=0.035, battens=SEVEN_RAKED, sleeve=0.14),
    # The Slalom Race: the inflatable sleeve (as wide all the way up), a plain outline; the free
    # race sail has six battens and no cams.
    "southsails_slalom": dict(head_x=0.38, foot_aft_x=0.86, foot_rise=0.19, foot_sag=0.03, clew_bulge=0.03,
                              roach=0.030, battens=SEVEN_BATTENS, sleeve=0.18),
    "southsails_freerace": dict(head_x=0.40, foot_aft_x=0.83, foot_rise=0.24, foot_sag=0.03, clew_bulge=0.03,
                                roach=0.030, battens=SIX_BATTENS, sleeve=0.12),
    # The Venom: a classic race outline with two clew eyelets.
    "s3kauai_slalom": dict(head_x=0.38, foot_aft_x=0.87, foot_rise=0.18, foot_sag=0.03, clew_bulge=0.03,
                           roach=0.030, battens=SEVEN_BATTENS, sleeve=0.20, clew_rings=2),
    "s3kauai_freerace": dict(head_x=0.39, foot_aft_x=0.84, foot_rise=0.22, foot_sag=0.03, clew_bulge=0.02,
                             roach=0.030, battens=SEVEN_BATTENS, sleeve=0.14, clew_rings=2),
    # The Vapor: a race outline with a big clew cut-out and a wide undercut.
    "gg_slalom": dict(head_x=0.37, foot_aft_x=0.82, foot_rise=0.16, foot_sag=0.03, clew_bulge=-0.08,
                      roach=0.035, battens=SEVEN_BATTENS, sleeve=0.20),
    "gg_freerace": dict(head_x=0.38, foot_aft_x=0.80, foot_rise=0.20, foot_sag=0.03, clew_bulge=-0.06,
                        roach=0.030, battens=SEVEN_BATTENS, sleeve=0.14),
}

SAIL_ROW_SPACING = 0.12   # m up the luff between the cloth's rows (the default sail has 0.085)
SAIL_COLUMNS = 26         # columns from the luff to the leech (the default sail has 40)


# --------------------------------------------------------------------------------------------
# One item's numbers into build_rig_models.py's module-level names.
# --------------------------------------------------------------------------------------------

def use_board_numbers(config: dict, shape: dict, mast_foot_from_tail_m: float) -> None:
    """Puts a board's numbers (BoardConfig's) where build_rig_models.py's board functions read
    them, worked out the way the module works them out from board_default.tres."""
    length, width = config["length_m"], config["width_m"]
    rig.BOARD = dict(config)
    rig.BOARD_L = length
    rig.BOARD_HALF_W = 0.5 * width
    rig.BOARD_THICK = config["thickness_m"]
    # The outline: the module scales its table from JP_LENGTH x JP_WIDTH to the board; this
    # board's table is already in its own metres.
    rig.JP_OUTLINE = outline_table(length, width, config, shape["outline"])
    rig.JP_LENGTH, rig.JP_WIDTH = length, width
    rig.TRANSOM_CORNER = shape["transom_corner"]
    # JP's traced nose (the rise of the bottom near the nose), at the same share of the length.
    scale = length / TRACED_LENGTH
    rig.JP_NOSE_ROCKER = [(x * scale, y) for x, y in TRACED_NOSE_ROCKER]
    rig.NOSE_TRACE_FROM = 1.8 * scale
    rig.CUTOUT_LENGTH = shape["steps"][-1][0]
    rig.MAST_TRACK_BACK = config["mast_track_back_from_tail_m"]
    rig.MAST_TRACK_FRONT = config["mast_track_front_from_tail_m"]
    rig.UV_HALF_SPAN = rig.BOARD_HALF_W + 0.02
    rig.RING_POINTS = shape.get("ring_points", RING_POINTS)
    rig.DECK_EXPONENT = shape["deck_exponent"]
    rig.RAIL_FRACTION = shape["rail_fraction"]
    # The mast foot on the deck, at the board's own place (the default's: 0.081 m up, the deck).
    rig.MAST_FOOT = np.array([0.0, rig.deck_y(0.0, mast_foot_from_tail_m), rig.board_z(mast_foot_from_tail_m)])
    rig.BACK_STRAP_T = config["back_strap_from_tail_m"]
    rig.FRONT_STRAP_T = config["front_strap_from_tail_m"]
    rig.BACK_STRAP_OUT = config["back_strap_out_m"]
    rig.FRONT_STRAP_OUT = config["front_strap_out_m"]
    rig.STRAPS = [(side * rig.FRONT_STRAP_OUT, rig.FRONT_STRAP_T, 10.0) for side in (-1.0, 1.0)] + \
                 [(side * rig.BACK_STRAP_OUT, rig.BACK_STRAP_T, 18.0) for side in (-1.0, 1.0)]


def use_sail_numbers(config: dict, shape: dict) -> None:
    """Puts a sail's numbers (SailConfig's) and its shape where build_rig_models.py's sail
    functions read them, worked out in the module's own order."""
    rig.SAIL = dict(rig.SAIL, **{key: config[key] for key in ("area_m2", "luff_m", "boom_m", "boom_height_m",
                                                               "mast_m", "camber")})
    rig.MAST_M = config["mast_m"]
    rig.BOOM_M = config["boom_m"]
    rig.BOOM_H = config["boom_height_m"]
    rig.TOP_Y = rig.MAST_M - 0.02
    rig.LUFF_H = rig.TOP_Y - rig.TACK_Y
    rig.BEND_START_Y = rig.BOOM_H
    rig.CHORD_PER_DRAWING = rig.BOOM_M / 0.963
    rig.HEAD_Y = rig.drawing_y(0.952)
    rig.HEAD_X = shape["head_x"] * rig.CHORD_PER_DRAWING
    # The foot's aft corner stays ahead of the clew (the default's is 0.22 m ahead).
    rig.FOOT_AFT_X = min(shape["foot_aft_x"] * rig.CHORD_PER_DRAWING, rig.BOOM_M - 0.12)
    rig.FOOT_AFT_Y = rig.TACK_Y + shape["foot_rise"]
    rig.FOOT_SAG = shape["foot_sag"]
    rig.LOWER_LEECH_BULGE = shape["clew_bulge"]
    # The roach (the leech bowing out above the clew) at most so much that the clew stays the
    # sail's aftmost point: on a short boom with a wide head the leech runs nearly straight up
    # from the clew, and a full roach would push it out behind the clew.
    head_rigged_x = rig.HEAD_X + float(rig.mast_bend(rig.HEAD_Y))
    rig.ROACH_M = min(shape["roach"], max(0.0, 0.8 * (rig.BOOM_M - head_rigged_x) / math.pi))
    rig.FULL_BATTENS = [(rig.drawing_y(luff), batten_leech_y(leech)) for luff, leech in shape["battens"]]
    rig.OUTER, rig.FOOT_END = rig.build_outer_edge()
    rig.OUTER_P = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(rig.OUTER, axis=0), axis=1))])
    rig.CLIMB = rig.OUTER[rig.FOOT_END:]
    rig.CLIMB_P = rig.OUTER_P[rig.FOOT_END:]
    rig.ANCHOR_LUFF_Y = [rig.TACK_Y] + [luff for luff, _ in reversed(rig.FULL_BATTENS)] + [rig.TOP_Y]
    rig.ANCHOR_P = [0.0] + [rig.p_at_height(leech) for _, leech in reversed(rig.FULL_BATTENS)] + \
                   [float(rig.OUTER_P[-1])]
    rig.ROW_SPACING = shape.get("row_spacing", SAIL_ROW_SPACING)
    rig.ROW_VS = [(y - rig.TACK_Y) / rig.LUFF_H for y in rig.row_heights()]
    rig.COLUMNS = shape.get("columns", SAIL_COLUMNS)


def fit_sail_outline(config: dict, shape: dict) -> dict:
    """The shape with its widths (the head's, the foot's and the roach) scaled together so the
    model's outline has the configured area: the luff, the clew and the boom height are the
    config's, and how wide the head and the foot are is each brand's style (within a few per cent,
    the scale found by halving)."""
    def area(scale: float) -> float:
        use_sail_numbers(config, scaled(scale))
        return rig.polygon_area_centroid(rig.sail_outline())[0]

    def scaled(scale: float) -> dict:
        return dict(shape, head_x=shape["head_x"] * scale, foot_aft_x=min(0.97, shape["foot_aft_x"] * scale),
                    roach=shape["roach"] * scale)

    low, high = 0.7, 1.4
    for _ in range(14):
        middle = 0.5 * (low + high)
        if area(middle) < config["area_m2"]:
            low = middle
        else:
            high = middle
    return scaled(0.5 * (low + high))


def batten_leech_y(leech) -> float:
    """A batten's leech end: a share of the luff, or the head's corner, the clew or the foot (as
    the default's #1, #6 and #7)."""
    if leech == "head":
        return rig.HEAD_Y - 0.01
    if leech == "clew":
        return rig.BOOM_H
    if leech == "foot":
        return rig.FOOT_AFT_Y + 0.12
    return rig.drawing_y(leech)


def use_fin_numbers(span_m: float, area_m2: float) -> None:
    """Puts a fin's depth and area where build_rig_models.py's build_fin reads them. The module
    scales the default fin's chord with the area; here the chord is set so the model's area is
    the configured one at this depth (the default fin's planform: a tip chord of 0.37 of the
    root's, a rounded tip)."""
    rig.FIN = dict(rig.FIN, span_m=span_m, area_m2=area_m2)
    rig.FIN_SPAN = span_m
    rig.FIN_SWEEP = 0.30 * span_m
    # The chord's share of the root chord along the span, averaged: the module's fin_chord with a
    # root chord of 1.
    rig.FIN_ROOT_CHORD, rig.FIN_TIP_CHORD = 1.0, 0.37
    mean_share = sum(rig.fin_chord((i + 0.5) / 200) for i in range(200)) / 200
    rig.FIN_ROOT_CHORD = area_m2 / (span_m * mean_share)
    rig.FIN_TIP_CHORD = 0.37 * rig.FIN_ROOT_CHORD


def check_numbers_like_the_module() -> None:
    """Puts the default board's and sail's numbers in through use_board_numbers and
    use_sail_numbers and checks they give the module's own numbers (read from Game/config/ when
    it was imported): so the gear's parts are built by the same formulas as the default ones."""
    names = ["BOARD_L", "BOARD_HALF_W", "BOARD_THICK", "MAST_TRACK_BACK", "MAST_TRACK_FRONT", "UV_HALF_SPAN",
             "BACK_STRAP_T", "FRONT_STRAP_T", "BACK_STRAP_OUT", "FRONT_STRAP_OUT", "STRAPS",
             "MAST_M", "BOOM_M", "BOOM_H", "TOP_Y", "LUFF_H", "HEAD_Y", "HEAD_X", "FOOT_AFT_X", "FOOT_AFT_Y",
             "FULL_BATTENS", "OUTER", "OUTER_P", "ANCHOR_LUFF_Y", "ANCHOR_P", "ROW_VS"]
    before = {name: np.array(getattr(rig, name), dtype=float) for name in names}
    foot_before = np.array(rig.MAST_FOOT, dtype=float)
    outline_before = [rig.outline_width(t) for t in np.linspace(0.0, rig.BOARD_L, 50)]
    rocker_before = [rig.bottom_rise(t) for t in np.linspace(0.0, rig.BOARD_L, 50)]
    default_shape = dict(BOARD_SHAPES["pj_slalom"], deck_exponent=rig.DECK_EXPONENT, rail_fraction=rig.RAIL_FRACTION,
                         ring_points=rig.RING_POINTS)
    use_board_numbers(dict(gear_set.DEFAULT_BOARD), default_shape, 1.265)
    hgo = dict(head_x=0.384, foot_aft_x=0.865, foot_rise=0.21, foot_sag=0.03, clew_bulge=0.05, roach=0.03,
               battens=SEVEN_BATTENS, row_spacing=0.085, columns=40)
    default_sail = {key: rig.SAIL[key] for key in ("area_m2", "luff_m", "boom_m", "boom_height_m", "mast_m", "camber")}
    use_sail_numbers(default_sail, hgo)
    for name in names:
        after = np.array(getattr(rig, name), dtype=float)
        if after.shape != before[name].shape or not np.allclose(after, before[name], atol=1e-9):
            raise RuntimeError(f"use_*_numbers gives another {name} than build_rig_models.py for the default rig")
    # The mast foot: the default config's 0.081 m is the deck's height there, rounded to the mm.
    if not np.allclose(rig.MAST_FOOT, foot_before, atol=0.001):
        raise RuntimeError(f"the mast foot {rig.MAST_FOOT} is not on the default board's deck {foot_before}")
    if not np.allclose(outline_before, [rig.outline_width(t) for t in np.linspace(0.0, rig.BOARD_L, 50)]) or \
            not np.allclose(rocker_before, [rig.bottom_rise(t) for t in np.linspace(0.0, rig.BOARD_L, 50)]):
        raise RuntimeError("use_board_numbers gives another outline or rocker than build_rig_models.py")
    print("Checked: the default board's and sail's numbers put in here give the module's own.")


# --------------------------------------------------------------------------------------------
# The board.
# --------------------------------------------------------------------------------------------

def bottom_half_width(t: float, shape: dict) -> float:
    """The planing bottom's half width at t m from the tail: the deck's, except over the cut-
    outs, where each step narrows it (the step's numbers are for a 72 cm board)."""
    deck = rig.half_width(t)
    scale = rig.BOARD["width_m"] / 0.72
    start = 0.0
    for end, a, b in shape["steps"]:
        if t < end:
            share = (t - start) / max(end - start, 1e-6)
            return min(deck, scale * (a + (b - a) * share))
        start = end
    return deck


def vee_depth(t: float, shape: dict) -> float:
    """How much higher the bottom's edges are than its centreline at t (shape["vee"] at the tail,
    0.35 and 0.7 of the length), fading out toward the nose's tip."""
    tail, middle, front = shape["vee"]
    s = t / rig.BOARD_L
    depth = float(np.interp(s, [0.0, 0.35, 0.7, 1.0], [tail, middle, front, 0.5 * front]))
    return depth * rig.tip_factor(t)


def concave_depth(t: float, shape: dict) -> float:
    """The double concave's depth at t: in front of the mast track, none in the tail."""
    s = t / rig.BOARD_L
    return shape["concave"] * float(np.interp(s, [0.0, 0.45, 0.65, 0.9, 1.0], [0.0, 0.0, 1.0, 0.6, 0.0]))


def hull_ring_points(t: float, shape: dict) -> list:
    """The cross-section at t, as build_rig_models.py's hull_ring_points (a superellipse, domed on
    the deck and flat with a tighter edge on the bottom, the shelf of the cut-outs at the rail's
    height), with this brand's cut-outs and the bottom's vee and double concave."""
    w, y_bottom, y_rail, y_deck = rig.section(t)
    w_low = max(bottom_half_width(t, shape), 0.01)
    low = rig.bottom_exponent(t)
    vee, concave = vee_depth(t, shape), concave_depth(t, shape)
    points = []
    for k in range(rig.RING_POINTS):
        a = 2 * math.pi * k / rig.RING_POINTS
        c, s = math.cos(a), math.sin(a)
        if s >= 0:
            x = w * math.copysign(abs(c) ** (2 / rig.DECK_EXPONENT), c)
            y = y_rail + (y_deck - y_rail) * abs(s) ** (2 / rig.DECK_EXPONENT)
        else:
            x = w_low * math.copysign(abs(c) ** (2 / low), c)
            y = y_rail - (y_rail - y_bottom) * abs(s) ** (2 / low)
            # The vee lifts the bottom toward its edges, the concave between the centreline and
            # the edges; both fade out at the rail, so the rail stays where it is.
            across = abs(x) / w_low
            fade = abs(s) ** 0.5
            y += (vee * across + concave * math.sin(math.pi * across) ** 2) * fade
        points.append(rig.vec(x, y, rig.board_z(t)))
    return points


def board_stations(shape: dict) -> list:
    """Where the hull's cross-sections are, m from the tail: evenly spaced, with both sides of
    each cut-out step close together and more toward the nose's point."""
    special = [0.005, 0.01]
    for end, _, _ in shape["steps"]:
        special += [end - 0.003, end]
    tip = [rig.BOARD_L - d for d in (0.03, 0.02, 0.013, 0.008, 0.004, 0.0015)]
    stations = sorted(set(list(np.linspace(0.0, rig.BOARD_L - 0.04, BOARD_STATIONS)) + special + tip))
    kept = []
    for t in stations:
        if kept and t - kept[-1] < 0.002:
            continue
        if kept and t - kept[-1] < 0.01 and t not in special and kept[-1] in special:
            continue
        if kept and t in special and t - kept[-1] < 0.01 and kept[-1] not in special:
            kept[-1] = t
            continue
        kept.append(t)
    return kept


def build_hull(shape: dict) -> bpy.types.Object:
    """The hull, as build_rig_models.py's build_hull with this brand's cross-sections."""
    b = rig.MeshBuilder("Hull")
    rings = []
    for t in board_stations(shape):
        rings.append([b.vertex(p, rig.hull_uv(p[0], t)) for p in hull_ring_points(t, shape)])
    rig.loft(b, rings, lambda i, k: "board_bottom" if k >= rig.RING_POINTS // 2 else "board_deck")
    rig.cap(b, rings[0], rig.vec(0, 0, 1), "board_bottom")
    _, _, y_rail, _ = rig.section(rig.BOARD_L)
    rig.point_cap(b, rings[-1], rig.vec(0, y_rail, rig.board_z(rig.BOARD_L)), "board_deck", tip_uv=(0.5, 1.0))
    return b.build()


def pad_layout(style: str) -> list:
    """The deck pads: (outline as (x, t) points for the starboard side or the centre, mirrored to
    port, height m, top material, side material). The outlines stay inside the rail."""
    front_t, back_t = rig.FRONT_STRAP_T, rig.BACK_STRAP_T
    front_out, back_out = rig.FRONT_STRAP_OUT, rig.BACK_STRAP_OUT
    rig.WEDGE_T = JP_WEDGE_T   # JP's back pad and wedge are drawn round it

    def clip(points: list) -> list:
        return [(min(x, rig.rail_in(t)), t) for x, t in points]

    def rounded_box(x0: float, x1: float, t0: float, t1: float) -> list:
        return clip([(x0, t0), (x1, t0), (x1, t1), (x0, t1)])

    def hexagon(x: float, t: float, radius: float) -> list:
        return clip([(x + radius * math.cos(math.radians(a)), t + 1.15 * radius * math.sin(math.radians(a)))
                     for a in range(0, 360, 60)])

    if style == "jp":   # build_rig_models.py's: JP's compact pads and the wedge
        return [(rig.front_pad_outline(), rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (rig.back_pad_outline(), rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (rig.wedge_outline(), rig.WEDGE_THICK, "pad_edge", "pad_edge", False)]
    if style == "diamond":   # a diamond under each front strap, one wedge across the tail
        diamond = clip([(front_out, front_t - 0.17), (front_out + 0.10, front_t),
                        (front_out, front_t + 0.15), (front_out - 0.10, front_t)])
        t0, t1 = 0.07, back_t + 0.17
        tail = [(-rig.rail_in(t0), t0), (rig.rail_in(t0), t0), (rig.rail_in(t1), t1), (-rig.rail_in(t1), t1)]
        return [(diamond, rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (tail, 0.012, "pad_dark", "pad_dark", False)]
    if style == "rect":   # minimal pads, one under each strap
        return [(rounded_box(front_out - 0.10, front_out + 0.10, front_t - 0.17, front_t + 0.12),
                 rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (rounded_box(back_out - 0.09, back_out + 0.11, back_t - 0.15, back_t + 0.16),
                 rig.PAD_THICK, "deck_pad", "pad_edge", True)]
    if style == "arrow":   # black pads on the black arrow panel (painted on the deck)
        return [(rounded_box(front_out - 0.10, front_out + 0.09, front_t - 0.17, front_t + 0.11),
                 rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (rounded_box(0.03, back_out + 0.11, 0.07, back_t + 0.17), rig.PAD_THICK, "deck_pad", "pad_edge", True)]
    if style == "hex":   # hexagons, one under each strap
        return [(hexagon(front_out, front_t - 0.02, 0.125), rig.PAD_THICK, "deck_pad", "pad_edge", True),
                (hexagon(back_out, back_t + 0.01, 0.12), rig.PAD_THICK, "deck_pad", "pad_edge", True)]
    # "rounded": soft pads under the straps and a small wedge between the back straps
    return [(rounded_box(front_out - 0.10, front_out + 0.10, front_t - 0.18, front_t + 0.12),
             rig.PAD_THICK, "deck_pad", "pad_edge", True),
            (rounded_box(back_out - 0.08, back_out + 0.11, 0.07, back_t + 0.17), rig.PAD_THICK, "deck_pad", "pad_edge", True),
            (rig.wedge_outline(), rig.WEDGE_THICK, "pad_edge", "pad_edge", False)]


def build_deck_pads(style: str) -> bpy.types.Object:
    """The deck pads (build_rig_models.py's add_raised_pad for each), with this brand's layout. A
    pad over the fin box lifts its screws (the module's WEDGE_T and WEDGE_THICK)."""
    b = rig.MeshBuilder("DeckPads")
    layout = pad_layout(style)
    screws_on = ((-1.0, -1.0), 0.0)   # no pad over the fin box's screws: they sit on the deck
    for outline, height, top, side, mirrored in layout:
        sides = (-1.0, 1.0) if mirrored else (1.0,)
        for sign in sides:
            points = [(sign * x, t) for x, t in outline]
            if sign < 0:
                points.reverse()
            rig.add_raised_pad(b, points, height, top, side)
        xs, ts = [x for x, _ in outline], [t for _, t in outline]
        if not mirrored and min(xs) < 0.0 < max(xs) and min(ts) < 0.12 and max(ts) > 0.235:
            screws_on = ((min(ts), max(ts)), height)
    rig.WEDGE_T, rig.WEDGE_THICK = screws_on
    return b.build()


def build_footstraps() -> bpy.types.Object:
    """The footstraps, as build_rig_models.py's build_footstraps (padded arches over the pads,
    screwed down in front of and behind the foot, each on its configured place and turned by its
    angle), with fewer points: they are small, and the gear's files should stay small."""
    b = rig.MeshBuilder("Footstraps")
    profile = [(math.copysign(abs(c) ** 0.4, c), math.copysign(abs(s) ** 0.4, s)) for c, s in rig.circle(STRAP_SIDES)]
    for x, t, angle in rig.STRAPS:
        a = math.radians(angle)
        outboard = math.copysign(1.0, x)
        forward = rig.vec(outboard * math.sin(a), 0.0, -math.cos(a))
        across = rig.vec(math.cos(a), 0.0, outboard * math.sin(a))
        centre = rig.vec(x, 0.0, rig.board_z(t))
        path, scales = [], []
        for i in range(STRAP_POINTS):
            phi = math.radians(-12.0 + 204.0 * i / (STRAP_POINTS - 1))
            p = centre + forward * (rig.STRAP_HALF_SPAN * math.cos(phi))
            ground = rig.deck_y(float(p[0]), rig.BOARD_L / 2 - float(p[2])) + rig.PAD_THICK
            path.append(rig.vec(p[0], ground + rig.STRAP_HEIGHT * math.sin(phi), p[2]))
            pad = 0.5 + 0.5 * math.sin(max(0.0, min(math.pi, phi)))   # thicker padding on top
            scales.append((0.028, 0.006 + 0.007 * pad))
        rig.sweep(b, path, profile, scales, "strap", up_hint=across)
        for end in (-1, 1):
            p = centre + forward * (end * rig.STRAP_HALF_SPAN)
            ground = rig.deck_y(float(p[0]), rig.BOARD_L / 2 - float(p[2])) + rig.PAD_THICK
            rig.tube(b, [rig.vec(p[0], ground - 0.002, p[2]), rig.vec(p[0], ground + 0.004, p[2])], 0.014,
                     "hardware", sides=10)
    return b.build()


def deck_height(t: float) -> float:
    """The deck's height on the centreline at t m from the tail."""
    return rig.deck_y(0.0, t)


def build_board(item: dict, out_dir: Path) -> dict:
    """The board's model and pictures. Returns the numbers the model fixes (the mast foot's and
    the fin root's heights) for the table."""
    shape = BOARD_SHAPES[item["shape"]]
    config = item["config"]
    reset_scene()
    use_board_numbers(config, shape, item["mast_foot_from_tail_m"])
    colours = livery.board_materials(item)
    for name, colour in colours.items():
        rig.MATERIALS[name] = colour
    objects = [build_hull(shape), build_deck_pads(shape["pads"]), build_footstraps(), rig.build_fin_box(),
               rig.build_mast_track()]
    rig.export_glb(objects, out_dir / f"{item['id']}.glb")
    geometry = BoardGeometry(shape)
    livery.draw_board_pictures(item, geometry, out_dir / f"{item['id']}_deck.png", out_dir / f"{item['id']}_bottom.png")
    foot_t = item["mast_foot_from_tail_m"]
    root_t = item["fin_root_from_tail_m"]
    return {
        "mast_foot_local": [0.0, round(deck_height(foot_t), 3), round(rig.board_z(foot_t), 3)],
        # The default fin's root is 5 mm up in the hull's bottom (FinConfig.root_local y -0.06 on
        # a 0.13 m board).
        "fin_root_local": [0.0, round(-0.5 * config["thickness_m"] + 0.005, 3), round(rig.board_z(root_t), 3)],
    }


class BoardGeometry:
    """What the board's pictures need to know about its shape (gear_liveries.py)."""

    def __init__(self, shape: dict):
        self.shape = shape
        self.length = rig.BOARD_L
        self.width = rig.BOARD["width_m"]
        self.uv_half_span = rig.UV_HALF_SPAN
        self.mast_track = (rig.MAST_TRACK_BACK, rig.MAST_TRACK_FRONT)
        self.straps = list(rig.STRAPS)
        self.pads = [(outline, mirrored) for outline, _, _, _, mirrored in pad_layout(shape["pads"])]
        self.steps = [end for end, _, _ in shape["steps"]]

    def half_width(self, t: float) -> float:
        return rig.half_width(t)

    def bottom_half_width(self, t: float) -> float:
        return bottom_half_width(t, self.shape)

    def grid(self, width: int, height: int):
        return rig.board_picture_grid(width, height)


# --------------------------------------------------------------------------------------------
# The sail.
# --------------------------------------------------------------------------------------------

class SailGeometry:
    """What the sail's picture and its clear film need to know about its shape (gear_liveries.py),
    all in the flat sail's metres: x back from the mast, y up from the mast foot."""

    def __init__(self, item: dict, shape: dict):
        self.item = item
        self.shape = shape
        self.boom_m, self.boom_height = rig.BOOM_M, rig.BOOM_H
        self.tack_y, self.top_y, self.luff_h = rig.TACK_Y, rig.TOP_Y, rig.LUFF_H
        self.head = (rig.HEAD_X, rig.HEAD_Y)
        self.foot_aft = (rig.FOOT_AFT_X, rig.FOOT_AFT_Y)
        self.battens = [rig.batten_line(i) for i in range(len(rig.FULL_BATTENS))]
        # The lowest battens carry the cams (an air cam: none here; the sleeve is wide all the way).
        cams = item["cams"] if isinstance(item["cams"], int) else 0
        self.cam_battens = list(range(len(self.battens) - cams, len(self.battens)))

    def batten_y(self, index: int, X):
        return rig.batten_y(index, X)

    def leech_x(self, Y):
        return rig.leech_x(np.maximum(Y, rig.FOOT_AFT_Y))

    def drawing_y(self, share: float) -> float:
        return rig.drawing_y(share)

    def grid(self, width: int, height: int):
        """(X, Y, U, chord) for every pixel of a picture in the sail's (u, v): pixel column = u
        (the luff on the left), pixel row = 1 - v (the head at the top), as draw_sail_panels."""
        u = (np.arange(width) + 0.5) / width
        v = 1.0 - (np.arange(height) + 0.5) / height
        luff = rig.luff_point(v)
        outer = rig.outer_point(v)
        chord = np.linalg.norm(outer - luff, axis=-1)[:, None]
        U = np.broadcast_to(u[None, :], (height, width))
        P = luff[:, None, :] + U[..., None] * (outer - luff)[:, None, :]
        return P[..., 0], P[..., 1], U, chord


def cell_near_film(clear, u0: float, u1: float, v0: float, v1: float, chord: float, margin: float = 0.05) -> bool:
    """Whether the clear film reaches within about `margin` m of a cell of the grid (u0 to u1,
    v0 to v1), as the module's near_clear_film, in the sail's (u, v): the cell then gets the
    window's material, and the picture's alpha draws the film's exact edge."""
    du, dv = margin / max(chord, 0.1), margin / rig.LUFF_H
    U, V = np.meshgrid([u0 - du, u0, 0.5 * (u0 + u1), u1, u1 + du], [v0 - dv, v0, 0.5 * (v0 + v1), v1, v1 + dv])
    return bool(np.any(clear(U, V)))


def build_sail_cloth(geometry: SailGeometry) -> bpy.types.Object:
    """The cloth as a grid along the battens, as build_rig_models.py's build_sail_cloth, with this
    sail's clear film (the cells near it get the window's material) and its own sleeve."""
    b = rig.MeshBuilder("SailCloth")
    clear = livery.sail_clear_film(geometry)
    rows = []
    for r, v in enumerate(rig.ROW_VS):
        chord = float(np.linalg.norm(rig.outer_point(v) - rig.luff_point(v)))
        if r == 0:   # the tack: every row starts here
            rows.append([b.vertex(rig.vec(0.0, rig.TACK_Y, 0.0), (0.0, 0.0), (0.0, 0.0))] * (rig.COLUMNS + 1))
            continue
        row = []
        for k in range(rig.COLUMNS + 1):
            u = k / rig.COLUMNS
            x, y = rig.sail_point(u, v)
            row.append(b.vertex(rig.vec(x, y, 0.0), (u, v), (chord, 0.0)))
        rows.append(row)
    for r in range(len(rows) - 1):
        v0, v1 = rig.ROW_VS[r], rig.ROW_VS[r + 1]
        chord = float(np.linalg.norm(rig.outer_point(v1) - rig.luff_point(v1)))
        for k in range(rig.COLUMNS):
            film = cell_near_film(clear, k / rig.COLUMNS, (k + 1) / rig.COLUMNS, v0, v1, chord)
            material = "sail_window" if film else "sail_cloth"
            if r == 0:
                b.face([rows[0][0], rows[1][k], rows[1][k + 1]], material)
            else:
                b.face([rows[r][k], rows[r][k + 1], rows[r + 1][k + 1], rows[r + 1][k]], material)
    b.face_toward(0, len(b.faces), rig.vec(0, 0, 1))
    build_sleeve(b, geometry)
    area, _, centre_y = rig.polygon_area_centroid(rig.sail_outline())
    print(f"Sail {geometry.item['id']}: outline area {area:.2f} m2 (config {rig.SAIL['area_m2']:.2f}), "
          f"{len(rig.ROW_VS)} rows x {rig.COLUMNS} columns, area centre {centre_y / rig.SAIL['luff_m']:.2f} of the luff up")
    return b.build(uv2=True)


def build_sleeve(b, geometry: SailGeometry) -> None:
    """The luff sleeve around the mast, as build_rig_models.py's build_sleeve: deep (the shape's
    sleeve depth) down from the highest batten with a cam, tapering above; an air cam sleeve (no
    hard cams) is deep all the way up."""
    radius = 0.034
    depth_full = geometry.shape["sleeve"]
    if geometry.cam_battens:
        deep_below = geometry.battens[geometry.cam_battens[0]][0][1]
    else:
        deep_below = rig.TOP_Y if geometry.item["cams"] == "air" else rig.FULL_BATTENS[len(rig.FULL_BATTENS) - 2][0]
    rings = []
    for v in rig.ROW_VS:
        chord = float(np.linalg.norm(rig.outer_point(v) - rig.luff_point(v)))
        y = float(rig.luff_point(v)[1])
        above = max(0.0, (y - deep_below) / max(rig.TOP_Y - deep_below, 0.01))
        depth = depth_full - (depth_full - 0.11) * above
        tail_x = max(0.05, min(depth, 0.7 * chord))
        tangent_angle = math.acos(radius / tail_x)
        profile = [(tail_x, 0.0)]
        for i in range(13):
            a = tangent_angle + (2 * math.pi - 2 * tangent_angle) * i / 12
            profile.append((radius * math.cos(a), radius * math.sin(a)))
        ring = []
        for x, z in profile:
            u = max(x, 0.0) / chord if chord > 0.01 else 0.0
            ring.append(b.vertex(rig.vec(x, y, z), (u, v), (chord, 0.0)))
        rings.append(ring)
    rig.loft(b, rings, "sail_sleeve")
    rig.point_cap(b, rings[-1], rig.vec(0.0, rig.TOP_Y + 0.012, 0.0), "sail_sleeve", tip_uv=(0.0, 1.0))


def build_clew_rings(count: int) -> bpy.types.Object:
    """The clew's eyelets (the module's build_clew_ring); some sails have two, for two boom
    lengths."""
    b = rig.MeshBuilder("SailClewRing")
    for i in range(count):
        centre_x = rig.BOOM_M - 0.02 - 0.075 * i
        path = [rig.vec(centre_x + 0.02 * math.cos(a), rig.BOOM_H + 0.02 * math.sin(a), 0.0)
                for a in np.linspace(0, 2 * math.pi, 17)]
        rig.tube(b, path[:-1] + [path[0] + rig.vec(0, 1e-4, 0)], 0.005, "metal", sides=8)
    return b.build()


def build_sail(item: dict, out_dir: Path) -> None:
    shape = fit_sail_outline(item["config"], SAIL_SHAPES[item["shape"]])
    reset_scene()
    use_sail_numbers(item["config"], shape)
    for name, colour in livery.sail_materials(item).items():
        rig.MATERIALS[name] = colour
    geometry = SailGeometry(item, shape)
    objects = [build_sail_cloth(geometry), build_clew_rings(shape.get("clew_rings", 1)), rig.build_tack_fairing()]
    rig.export_glb(objects, out_dir / f"{item['id']}.glb")
    livery.draw_sail_picture(item, geometry, out_dir / f"{item['id']}_panels.png")


# --------------------------------------------------------------------------------------------
# The fin.
# --------------------------------------------------------------------------------------------

def build_fin(item: dict, out_dir: Path) -> None:
    reset_scene()
    use_fin_numbers(item["config"]["span_m"], item["config"]["area_m2"])
    rig.MATERIALS["fin"] = livery.FIN_MATERIAL
    rig.export_glb([rig.build_fin()], out_dir / f"{item['id']}.glb")


# --------------------------------------------------------------------------------------------
# The run.
# --------------------------------------------------------------------------------------------

def reset_scene() -> None:
    """An empty Blender scene and no materials left from the item before."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rig._material_cache.clear()


def item_files(item: dict) -> dict:
    """The res:// paths of an item's model and pictures."""
    folder = f"{RES_GEAR_DIR}/{item['brand'] or 'fins'}"
    files = {"model": f"{folder}/{item['id']}.glb"}
    if item["kind"] == "board":
        files.update(deck=f"{folder}/{item['id']}_deck.png", bottom=f"{folder}/{item['id']}_bottom.png")
    elif item["kind"] == "sail":
        files.update(panels=f"{folder}/{item['id']}_panels.png")
    return files


def write_table(fixed: dict) -> None:
    """gear_set.json: the gear table as built, with each item's files and the numbers the models
    fix (a board's mast foot and fin root). The real gear an item is modelled on is not in it."""
    table = []
    for item in gear_set.ITEMS:
        entry = dict(item, files=item_files(item))
        entry.update(fixed.get(item["id"], {}))
        table.append(entry)
    path = GEAR_DIR / "gear_set.json"
    path.write_text(json.dumps(table, indent=1) + "\n", encoding="utf-8")
    print(f"Wrote {path.relative_to(rig.REPO)} ({len(table)} items)")


def read_arguments() -> dict:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    options = {}
    for arg in args:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
    return options


def previous_fixed_numbers() -> dict:
    """The mast foot and fin root heights of the last full build, so a partial build (one brand)
    keeps the others' in gear_set.json."""
    path = GEAR_DIR / "gear_set.json"
    if not path.exists():
        return {}
    fixed = {}
    for entry in json.loads(path.read_text(encoding="utf-8")):
        if "mast_foot_local" in entry:
            fixed[entry["id"]] = {"mast_foot_local": entry["mast_foot_local"], "fin_root_local": entry["fin_root_local"]}
    return fixed


def main() -> None:
    options = read_arguments()
    brand, only, wanted = options.get("brand", ""), options.get("only", ""), options.get("item", "")
    check_numbers_like_the_module()
    fixed = previous_fixed_numbers()
    for item in gear_set.ITEMS:
        if (brand and item["brand"] != brand) or (wanted and item["id"] != wanted):
            continue
        if only and item["kind"] + "s" != only:
            continue
        out_dir = GEAR_DIR / (item["brand"] or "fins")
        out_dir.mkdir(parents=True, exist_ok=True)
        if item["kind"] == "board":
            fixed[item["id"]] = build_board(item, out_dir)
        elif item["kind"] == "sail":
            build_sail(item, out_dir)
        else:
            build_fin(item, out_dir)
    write_table(fixed)


if __name__ == "__main__":
    main()
    sys.stdout.flush()
