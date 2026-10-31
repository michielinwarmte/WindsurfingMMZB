#!/usr/bin/env python3
"""Writes the gear page's catalogue from the gear table: one GearItem file (Game/gear/gear_item.gd)
per item of tools/blender/gear_set.py, in Game/gear/boards/, Game/gear/sails/ and Game/gear/fins/
(Documentation/reports/fleet_gear/gear_page.md, "How to add an item"; gear_models.md).

Run from the repository root, after building the models (tools/blender/build_gear_models.py writes
Game/assets/models/gear/gear_set.json, which names each item's model and pictures):

    python -I tools/gear/make_catalogue.py

Each item gets the brand, the model name, the line, the size, a line for its card, a wind range,
its model and pictures and its numbers. The numbers are a sub-resource in the item's file: the
default config's (Game/config/board_default.tres, sail_default.tres, fin_default.tres: "everything
else as the default", brand_research.md section 3.1) with the table's numbers in their place. The
default board and the default sail (gear_set.py marks them) point at their Game/config/ files
instead, so they stay the game's default gear number for number (tests/unit/test_gear.gd). A sail's
cloth is white: its picture already has the brand's colours (white keeps them).

The other files in those folders (the gear page's stand-in items) are deleted, except the default
fin (pj_new_sealand_slalom_38.tres), which is not in the table: it stays as it is.
"""

import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "blender"))
import gear_set  # noqa: E402

GAME = REPO / "Game"
TABLE = GAME / "assets" / "models" / "gear" / "gear_set.json"
FOLDERS = {"board": GAME / "gear" / "boards", "sail": GAME / "gear" / "sails", "fin": GAME / "gear" / "fins"}
KINDS = {"board": 0, "sail": 1, "fin": 2}
LINES = {"slalom": 0, "freerace": 1}
DEFAULT_CONFIGS = {"board": "board_default.tres", "sail": "sail_default.tres", "fin": "fin_default.tres"}
CONFIG_SCRIPTS = {"board": "res://sim/config/board_config.gd", "sail": "res://sim/config/sail_config.gd",
                  "fin": "res://sim/config/fin_config.gd"}
KEPT = {"pj_new_sealand_slalom_38.tres"}   # the default fin: not in the table, kept as it is
# The table's sail numbers that are SailConfig's (rig_mass_real_kg is the table's alone).
SAIL_FIELDS = ["area_m2", "luff_m", "boom_m", "boom_height_m", "mast_m", "camber", "rig_mass_kg", "rig_com_height_m",
               "ce_height_fraction", "ce_boom_fraction"]
CARD_LENGTH = 90   # a card's line, characters at most (three lines on the card)


def config_lines(kind: str) -> list:
    """The default config's numbers as (name, the value as written) in the file's order."""
    lines = []
    in_resource = False
    for line in (GAME / "config" / DEFAULT_CONFIGS[kind]).read_text(encoding="utf-8").splitlines():
        if line.strip() == "[resource]":
            in_resource = True
            continue
        match = re.match(r"^(\w+) = (.+)$", line)
        if in_resource and match and match.group(1) != "script":
            lines.append((match.group(1), match.group(2)))
    return lines


def number(value) -> str:
    """A number as Godot writes it in a .tres (always with a point, so it stays a float)."""
    return repr(float(value))


def twist_pressure_pa(area_m2: float) -> float:
    """The sail's twist pressure (SailConfig.twist_pressure_pa): an estimate by size, straight
    through the game's two sails (the 8.0 has 125 Pa, the 6.5 140 Pa). Which number each size
    should have is a physics question (PH14, brand_research.md section 5, question 10)."""
    return round(min(155.0, max(110.0, 140.0 - 10.0 * (area_m2 - 6.5))), 1)


def config_numbers(item: dict) -> list:
    """The item's config: the default's numbers with the table's in their place."""
    kind = item["kind"]
    table = item["config"]
    if kind == "sail":
        table = {key: table[key] for key in SAIL_FIELDS}
        table["twist_pressure_pa"] = twist_pressure_pa(item["config"]["area_m2"])
    return [(key, number(table[key]) if key in table else raw) for key, raw in config_lines(kind)]


def wind_range(item: dict) -> tuple:
    """The wind the item is made for, knots, for its card: smaller gear for more wind. A rule of
    thumb (Point-7's chart for a rider of 75 to 90 kg, brand_research.md section 1.3, puts an 8.0
    at about 12 to 22 kt); the gear sails in any wind."""
    if item["kind"] == "sail":
        start = round(44.0 - 4.0 * item["size"])
        return start, start + 10
    if item["kind"] == "board":
        start = round(37.0 - 0.2 * item["size"])
        return start, start + 12
    start = round(52.0 - 0.95 * item["size"])
    return start, start + 11


def board_rank(item: dict) -> str:
    """"small", "middle" or "big" among the brand's slalom boards."""
    sizes = sorted(i["size"] for i in gear_set.items("board", item["brand"]) if i["line"] == "slalom")
    position = sizes.index(item["size"])
    return "small" if position == 0 else ("big" if position == len(sizes) - 1 else "middle")


def description(item: dict) -> str:
    """One line for the item's card."""
    c = item["config"]
    if item["kind"] == "board":
        size = f"{round(c['length_m'] * 100)} x {round(c['width_m'] * 100)} cm"
        if item["line"] == "freerace":
            return f"Free race board, {size}: slalom speed with an easier, more forgiving ride."
        return {"small": f"Small slalom board for strong wind, {size}: quick and in control.",
                "middle": f"The all-round slalom size, {size}: fast from medium wind up.",
                "big": f"Big slalom board for light wind, {size}: early to plane."}[board_rank(item)]
    if item["kind"] == "sail":
        cams = {4: "4 cams", 3: "3 cams", 2: "2 cams", 0: "no cams", "air": "an air sleeve"}[item["cams"]]
        if item["line"] == "freerace":
            return f"Free race sail, {item['battens']} battens and {cams}: easier to rig and pump, luff {c['luff_m']:.2f} m."
        return f"Race sail, {item['battens']} battens and {cams}: luff {c['luff_m']:.2f} m, boom {c['boom_m']:.2f} m."
    width = round(100 * (0.60 + (c["span_m"] - 0.30) / 0.64))
    return f"Carbon slalom fin, {item['size']} cm deep, {round(c['area_m2'] * 1e4)} cm²: for boards about {width} cm wide."


def item_file(item: dict, files: dict) -> str:
    """The item's .tres, as Godot writes a GearItem."""
    kind = item["kind"]
    resources = [("Script", "res://gear/gear_item.gd"), ("Resource", f"res://gear/brands/{item['brand']}.tres")]
    default = item.get("default", False)
    if default:
        resources.append(("Resource", f"res://config/{DEFAULT_CONFIGS[kind]}"))
    else:
        resources.append(("Script", CONFIG_SCRIPTS[kind]))
    looks = [("model", "PackedScene")] + [(name, "Texture2D") for name in ("deck", "bottom", "panels") if name in files]
    for name, kind_name in looks:
        resources.append((kind_name, files[name]))
    out = ['[gd_resource type="Resource" script_class="GearItem" format=3]', ""]
    for index, (type_name, path) in enumerate(resources, start=1):
        out.append(f'[ext_resource type="{type_name}" path="{path}" id="{index}"]')
    out.append("")
    if not default:
        out.append('[sub_resource type="Resource" id="Resource_config"]')
        out.append('script = ExtResource("3")')
        out += [f"{key} = {value}" for key, value in config_numbers(item)]
        out.append("")
    low, high = wind_range(item)
    text = description(item)
    if len(text) > CARD_LENGTH:
        raise ValueError(f"{item['id']}: the card's line is {len(text)} characters: {text}")
    out += [
        "[resource]",
        'script = ExtResource("1")',
        f"kind = {KINDS[kind]}",
        'brand = ExtResource("2")',
        f'model_name = "{item["model_name"]}"',
        f"line = {LINES[item['line']]}",
        f"size = {number(item['size'])}",
        f'description = "{text}"',
        f"wind_from_kt = {number(low)}",
        f"wind_to_kt = {number(high)}",
        'config = ExtResource("3")' if default else 'config = SubResource("Resource_config")',
    ]
    for index, (name, _) in enumerate(looks, start=4):
        out.append(f'{name} = ExtResource("{index}")')
    if kind == "sail":
        out.append("cloth = Color(1, 1, 1, 1)")
    return "\n".join(out) + "\n"


def main() -> None:
    built = {entry["id"]: entry for entry in json.loads(TABLE.read_text(encoding="utf-8"))}
    written = {kind: set() for kind in FOLDERS}
    for item in gear_set.ITEMS:
        if item["id"] not in built:
            raise SystemExit(f"{item['id']} is not in {TABLE}: build the models first")
        files = built[item["id"]]["files"]
        for path in files.values():
            if not (GAME / path.removeprefix("res://")).exists():
                raise SystemExit(f"{item['id']}: {path} is missing: build the models first")
        name = f"{item['id']}.tres"
        (FOLDERS[item["kind"]] / name).write_text(item_file(item, files), encoding="utf-8")
        written[item["kind"]].add(name)
    for kind, folder in FOLDERS.items():
        for path in sorted(folder.glob("*.tres")):
            if path.name not in written[kind] and path.name not in KEPT:
                os.remove(path)
                print(f"Deleted the stand-in {path.relative_to(REPO)}")
        print(f"{folder.relative_to(REPO)}: {len(written[kind])} items written")


if __name__ == "__main__":
    main()
