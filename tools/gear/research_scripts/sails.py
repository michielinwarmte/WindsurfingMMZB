"""The game's sails: published numbers plus the rig rules of brand_research.md section 3."""
MAST_KG = {370: 1.30, 400: 1.42, 430: 1.55, 460: 1.77, 490: 2.07, 520: 2.10}

def boom_kg(boom_m):
    if boom_m <= 1.80: return 2.23
    if boom_m <= 2.00: return 2.61
    if boom_m <= 2.15: return 2.68
    if boom_m <= 2.30: return 3.49
    return 3.52

CAMBER = {4: 0.075, 3: 0.072, 2: 0.070, 0: 0.068, "air": 0.072}
# brand, model, area, luff m, boom m (max), mast cm, extension m (None = luff + 0.02 rule), sail kg (None = est), est kg, cams, kind
RACE = [
    ("Tripletone", "Duotone Warp_Fin 5.7 (2026)", 5.7, 4.26, 1.88, 400, None, 5.10, None, 4, "R"),
    ("Tripletone", "Warp_Fin 6.2 (2026)", 6.2, 4.32, 1.92, 430, None, 5.40, None, 4, "R"),
    ("Tripletone", "Warp_Fin 6.7 (2026)", 6.7, 4.62, 2.02, 430, None, 5.60, None, 4, "R"),
    ("Tripletone", "Warp_Fin 7.7 (2026)", 7.7, 4.88, 2.14, 460, None, 6.00, None, 4, "R"),
    ("Tripletone", "Warp_Fin 8.5 (2026)", 8.5, 5.14, 2.28, 490, None, 6.30, None, 4, "R"),
    ("Savanna", "Severne Mach 9 5.5 (026)", 5.5, 4.28, 1.77, 400, None, 5.30, None, 4, "R"),
    ("Savanna", "Mach 9 6.5 (026)", 6.5, 4.56, 1.98, 430, None, 5.96, None, 4, "R"),
    ("Savanna", "Mach 9 7.5 (026)", 7.5, 4.90, 2.08, 460, None, 6.33, None, 4, "R"),
    ("Savanna", "Mach 9 8.5 (026)", 8.5, 5.18, 2.22, 490, None, 6.74, None, 4, "R"),
    ("Point.9", "Point-7 AC-1 LTD 5.9 (026, stitched)", 5.9, 4.42, 1.92, 400, 0.44, 5.3, None, 3, "R"),
    ("Point.9", "AC-1 LTD 6.5 (026)", 6.5, 4.64, 1.96, 430, 0.36, 5.8, None, 3, "R"),
    ("Point.9", "AC-1 LTD 7.3 (026)", 7.3, 4.98, 2.10, 460, 0.40, 6.5, None, 3, "R"),
    ("Point.9", "AC-1 LTD 7.8 (026)", 7.8, 4.98, 2.12, 460, 0.40, 6.6, None, 3, "R"),
    ("Point.9", "AC-1 LTD 8.8 (025/026)", 8.8, 5.24, 2.30, 490, 0.36, 6.9, None, 3, "R"),
    ("NielsTrots", "NeilPryde RS:Racing EVO XVII 5.6 (2026)", 5.6, 4.26, 1.80, 400, 0.26, 5.0, None, 4, "R"),
    ("NielsTrots", "RS:Racing EVO XVII 6.5", 6.5, 4.58, 1.92, 430, 0.28, 5.3, None, 4, "R"),
    ("NielsTrots", "RS:Racing EVO XVII 7.4", 7.4, 4.86, 2.06, 460, 0.26, 5.5, None, 4, "R"),
    ("NielsTrots", "RS:Racing EVO XVII 8.2", 8.2, 5.12, 2.16, 490, 0.22, 6.1, None, 4, "R"),
    ("NielsTrots", "RS:Racing EVO XVII 9.0", 9.0, 5.38, 2.26, 520, 0.18, 6.4, None, 4, "R"),
    ("SouthSails", "North Slalom Race GEN3 6.0 (2026)", 6.0, 4.38, 1.83, 430, 0.08, 4.30, None, "air", "R"),
    ("SouthSails", "Slalom Race GEN3 6.8 (2026)", 6.8, 4.56, 1.96, 430, 0.26, 4.50, None, "air", "R"),
    ("SouthSails", "Slalom Race GEN3 7.7 (2026)", 7.7, 4.92, 2.15, 460, 0.32, 4.70, None, "air", "R"),
    ("SouthSails", "Slalom Race 8.6 (2025 luff/boom)", 8.6, 5.18, 2.17, 490, None, None, 4.95, "air", "R"),
    ("s3kauai", "S2Maui Venom-XI 5.6 (2026)", 5.6, 4.13, 1.85, 400, None, None, 5.2, 4, "R"),
    ("s3kauai", "Venom-XI 6.7 (2026)", 6.7, 4.60, 2.02, 430, None, None, 5.8, 4, "R"),
    ("s3kauai", "Venom-XI 7.6 (2026)", 7.6, 4.81, 2.17, 460, None, None, 6.2, 4, "R"),
    ("s3kauai", "Venom-XI 8.2 (2026)", 8.2, 4.91, 2.29, 460, None, None, 6.4, 4, "R"),
    ("s3kauai", "Venom-XI 9.0 (2026)", 9.0, 5.16, 2.40, 490, None, None, 6.8, 4, "R"),
    ("GG Sails", "GA Vapor 5.7 (2026)", 5.7, 4.25, 1.87, 400, 0.26, 5.27, None, 4, "R"),
    ("GG Sails", "Vapor 6.7 (2026)", 6.7, 4.61, 1.96, 430, 0.32, 5.80, None, 4, "R"),
    ("GG Sails", "Vapor 7.7 (2026)", 7.7, 4.94, 2.09, 460, 0.34, 6.15, None, 4, "R"),
    ("GG Sails", "Vapor 8.4 (2026)", 8.4, 5.15, 2.17, 490, 0.26, 6.39, None, 4, "R"),
]
FREE = [
    ("Tripletone", "Duotone S_Pace 6.0 (2026)", 6.0, 4.42, 1.90, 430, None, 4.90, None, 3, "F"),
    ("Tripletone", "S_Pace 6.6 (2026)", 6.6, 4.62, 2.00, 430, None, 5.10, None, 3, "F"),
    ("Tripletone", "S_Pace 7.3 (2026)", 7.3, 4.76, 2.04, 460, None, 5.30, None, 3, "F"),
    ("Tripletone", "S_Pace 7.8 (2026)", 7.8, 4.88, 2.14, 460, None, 5.50, None, 3, "F"),
    ("Tripletone", "S_Pace 8.3 (2026)", 8.3, 5.00, 2.22, 490, None, 5.70, None, 3, "F"),
    ("Savanna", "Severne Overdrive M4 6.2", 6.2, 4.33, 1.86, 430, None, 4.40, None, 3, "F"),
    ("Savanna", "Overdrive M4 7.0", 7.0, 4.61, 1.89, 430, None, 4.65, None, 3, "F"),
    ("Savanna", "Overdrive M4 7.8", 7.8, 4.89, 2.00, 460, None, 4.90, None, 3, "F"),
    ("Savanna", "Overdrive M4 8.6", 8.6, 5.12, 2.08, 490, None, 5.20, None, 3, "F"),
    ("Point.9", "Point-7 AC-2 5.8 (025-026)", 5.8, 4.40, 1.92, 400, 0.42, 4.7, None, 2, "F"),
    ("Point.9", "AC-2 6.8", 6.8, 4.63, 2.04, 430, 0.36, 4.8, None, 2, "F"),
    ("Point.9", "AC-2 7.8", 7.8, 4.97, 2.12, 460, 0.40, 4.9, None, 2, "F"),
    ("NielsTrots", "NeilPryde V8 6.2 (2026)", 6.2, 4.30, 1.94, 400, 0.30, 4.2, None, 2, "F"),
    ("NielsTrots", "V8 7.2 (2026)", 7.2, 4.67, 2.04, 460, 0.08, 4.5, None, 2, "F"),
    ("NielsTrots", "V8 7.7 (2026)", 7.7, 4.86, 2.09, 460, 0.26, 4.7, None, 2, "F"),
    ("NielsTrots", "V8 8.2 (2026)", 8.2, 5.05, 2.13, 490, 0.16, 4.9, None, 2, "F"),
    ("SouthSails", "North Free Speed 6.0 (2025)", 6.0, 4.32, 1.89, 430, None, None, 4.0, 0, "F"),
    ("SouthSails", "North Free Speed 7.7 (2024 test)", 7.7, 4.90, 2.09, 460, None, None, 4.6, 0, "F"),
    ("s3kauai", "S2Maui Wicked 5.8 (2026)", 5.8, 4.33, 1.82, 430, None, None, 4.2, 2, "F"),
    ("s3kauai", "Wicked 6.7 (2026)", 6.7, 4.56, 1.98, 430, None, None, 4.5, 2, "F"),
    ("s3kauai", "Wicked 7.6 (2026)", 7.6, 4.76, 2.12, 460, None, None, 4.8, 2, "F"),
    ("s3kauai", "Wicked 8.2 (2026)", 8.2, 4.89, 2.24, 460, None, None, 5.0, 2, "F"),
    ("GG Sails", "GA Cosmic 6.2 (2026)", 6.2, 4.48, 1.87, 430, 0.18, None, 4.7, 2, "F"),
    ("GG Sails", "Cosmic 7.2 (2026)", 7.2, 4.81, 2.02, 460, 0.22, None, 5.0, 2, "F"),
    ("GG Sails", "Cosmic 7.7 (2026)", 7.7, 4.92, 2.12, 460, 0.32, None, 5.2, 2, "F"),
    ("GG Sails", "Cosmic 8.3 (2026)", 8.3, 5.03, 2.20, 490, 0.14, None, 5.4, 2, "F"),
]

def row(s):
    brand, model, area, luff, boom, mast, ext, kg, est_kg, cams, kind = s
    notes = []
    if ext is None:
        mast_m = luff + 0.02
        notes.append("mast_m")
    else:
        mast_m = mast / 100 + ext
    sail_kg = kg if kg is not None else est_kg
    if kg is None:
        notes.append("sail kg")
    total = sail_kg + MAST_KG[mast] + boom_kg(boom) + 1.3
    boom_h = 1.50 if luff >= 4.80 else (1.45 if luff >= 4.40 else 1.40)
    ce = 0.41 if kind == "R" else 0.42
    camber = CAMBER[cams]
    ar = luff * luff / area
    cams_txt = "air cam" if cams == "air" else str(cams)
    return (f"| {model} | {area:.1f} | {luff:.2f} | {boom:.2f} | {mast} | {mast_m:.2f} | {boom_h:.2f} | {cams_txt} | {camber:.3f} | "
            f"{sail_kg:.2f} | {total:.1f} | {total * 9.5 / 12.4:.1f} | {ce:.2f} | {ar:.2f} | {', '.join(notes) or '-'} |")

if __name__ == "__main__":
    import sys
    group = RACE if sys.argv[1] == "R" else FREE
    print("| Modelled on | area_m2 | luff_m | boom_m | mast (cm) | mast_m (mast + extension) | boom_height_m | cams | camber | sail kg | rig_mass_kg real | rig_mass_kg at the default's ratio | ce_height_fraction | aspect ratio (luff²/area) | estimated |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    cur = None
    for s in group:
        if s[0] != cur:
            cur = s[0]
            print(f"| **{cur}** | | | | | | | | | | | | | | |")
        print(row(s))
