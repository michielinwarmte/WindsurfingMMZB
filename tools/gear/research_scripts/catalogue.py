"""The game's gear set: published numbers plus the derivation rules of brand_research.md section 3."""
RHINO = {29: 216, 30: 226, 31: 236, 32: 247, 33: 257, 34: 267, 35: 278, 36: 286, 37: 296, 38: 311, 39: 322,
         40: 333, 41: 344, 42: 358, 43: 369, 44: 378, 45: 390, 46: 405, 47: 416, 48: 428}
SMAX_ODD = {29: 211, 31: 231, 33: 252, 35: 273, 37: 291, 39: 312, 41: 332, 43: 357, 45: 384, 47: 407, 49: 430}

def smax(cm):
    if cm in SMAX_ODD:
        return SMAX_ODD[cm]
    return (SMAX_ODD[cm - 1] + SMAX_ODD[cm + 1]) / 2

def k_block(W, kind):
    if kind == "F":
        return 0.59
    if W <= 0.73:
        return 0.56
    if W >= 0.77:
        return 0.61
    return 0.56 + (W - 0.73) / 0.04 * 0.05

# name, modelled on, L, W, V(m3), published kg, tail (None=rule), thickness (None=rule), fin cm (None=rule), fin note, kind
SLALOM = [
    ("Moonboard", "iSonic 60 (2026, Carbon Reflex)", 2.25, .60, .091, 5.70, .392, .120, 30, "28-32", "S"),
    ("Moonboard", "iSonic 63 (2026, CR)", 2.26, .63, .098, 6.05, .414, .122, 32, "30-34", "S"),
    ("Moonboard", "iSonic 67 (2026, CR)", 2.28, .67, .111, 6.34, .457, .130, 36, "34-38", "S"),
    ("Moonboard", "iSonic 73 (2026, CR)", 2.28, .73, .123, 6.66, .502, .132, 38, "36-40", "S"),
    ("Moonboard", "iSonic 77 (2026, CR)", 2.29, .77, .129, 6.81, .545, .120, 41, "38-44", "S"),
    ("PJ New Sealand", "JP Slalom S-TEC 62.5 (2026)", 2.30, .625, .097, 5.9, None, None, None, "-", "S"),
    ("PJ New Sealand", "JP Slalom S-TEC 66 (2026)", 2.30, .66, .105, 6.0, None, None, None, "-", "S"),
    ("PJ New Sealand", "JP Slalom S-TEC 72 (2025 SL 72 = board_default.tres)", 2.28, .72, .117, 6.6, .49, .13, 38, "-", "S"),
    ("PJ New Sealand", "JP Slalom S-TEC 76 (2026)", 2.28, .76, .125, 6.9, None, None, None, "-", "S"),
    ("Tripletone", "Duotone Falcon_Fin D/LAB 89 (2026)", 2.26, .60, .089, 6.00, None, None, None, "est.", "S"),
    ("Tripletone", "Duotone Falcon_Fin SLS 98 (2026)", 2.26, .63, .098, 6.40, None, None, 35, "34-36", "S"),
    ("Tripletone", "Duotone Falcon_Fin SLS 111 (2026)", 2.25, .68, .111, 6.95, None, None, 38, "36-40", "S"),
    ("Tripletone", "Duotone Falcon_Fin SLS 118 (2026)", 2.25, .72, .118, 7.20, None, None, 40, "38-42", "S"),
    ("Tripletone", "Duotone Falcon_Fin SLS 129 (2026)", 2.24, .80, .129, 7.60, None, None, 44, "42-46", "S"),
    ("BMX Boards", "FMX Invictus Pro 88 (2026)", 2.33, .61, .088, 5.8, None, None, 31, "29-33", "S"),
    ("BMX Boards", "FMX Invictus Pro 98 (2026)", 2.33, .63, .098, 6.0, None, None, 32, "30-34", "S"),
    ("BMX Boards", "FMX Invictus Pro 108 (2026)", 2.33, .70, .108, 6.6, None, None, 36, "34-38", "S"),
    ("BMX Boards", "FMX Invictus Pro 118 (2026)", 2.33, .72, .118, 6.85, None, None, 37, "35-39", "S"),
    ("BMX Boards", "FMX Invictus Pro 128 (2026)", 2.28, .81, .128, 7.2, None, None, 41, "39-44", "S"),
    ("Forbidden", "Tabou Manta 61 (2026, Team)", 2.33, .61, .096, 6.1, None, None, None, "-", "S"),
    ("Forbidden", "Tabou Manta 66 (2026, Team)", 2.33, .66, .106, 6.2, None, None, None, "-", "S"),
    ("Forbidden", "Tabou Manta 71 (2026, Team)", 2.33, .71, .116, 6.8, None, None, None, "-", "S"),
    ("Forbidden", "Tabou Manta 77 (2026, Team)", 2.32, .77, .122, 7.4, None, None, None, "-", "S"),
    ("Forbidden", "Tabou Manta 85 (2026, Team)", 2.32, .85, .135, 7.8, None, None, None, "-", "S"),
]
FREERACE = [
    ("Moonboard", "Starboard Futura 110 (2026, Wood Sandwich)", 2.29, .71, .110, 7.0, .466, .115, 38, "36-40", "F"),
    ("Moonboard", "Starboard Futura 120 (2026, WS)", 2.30, .76, .120, 7.4, .487, .116, 42, "40-44", "F"),
    ("Moonboard", "Starboard Futura 135 (2026, WS)", 2.34, .83, .135, 8.0, .525, .119, 44, "42-46", "F"),
    ("PJ New Sealand", "JP Super Sport 111 (2026, Wood Pro)", 2.34, .70, .111, 7.2, None, None, 40, "Slalom 40 G10", "F"),
    ("PJ New Sealand", "JP Super Sport 122 (2026)", 2.34, .76, .122, 7.8, None, None, 44, "Slalom 44 G10", "F"),
    ("PJ New Sealand", "JP Super Sport 133 (2026)", 2.34, .82, .133, 8.1, None, None, 48, "Slalom 48 G10", "F"),
    ("Tripletone", "Duotone Blitz SLS 116 (2026)", 2.34, .68, .116, 7.0, None, None, 38, "F_Ride 38", "F"),
    ("Tripletone", "Duotone Blitz SLS 126 (2026)", 2.35, .71, .126, 7.4, None, None, 42, "F_Ride 42", "F"),
    ("Tripletone", "Duotone Blitz SLS 136 (2026)", 2.38, .77, .136, 7.8, None, None, 44, "F_Ride 44", "F"),
    ("BMX Boards", "FMX Invictus GTR 98 (2026)", 2.33, .63, .098, 6.5, None, None, 32, "30-34", "F"),
    ("BMX Boards", "FMX Invictus GTR 118 (2026)", 2.33, .72, .118, 7.4, None, None, 37, "35-39", "F"),
    ("Forbidden", "Tabou Rocket+ 113 (2026, LTD)", 2.32, .73, .113, 7.6, None, None, 38, "MFC 38", "F"),
    ("Forbidden", "Tabou Rocket+ 123 (2026, LTD)", 2.32, .77, .123, 7.9, None, None, 40, "MFC 40", "F"),
    ("Forbidden", "Tabou Rocket+ 133 (2026, LTD)", 2.32, .81, .133, 8.1, None, None, 44, "MFC 44", "F"),
    ("Savanna", "Severne Fox Pro 105 (2026)", 2.39, .65, .105, 6.07, None, None, 36, "36", "F"),
    ("Savanna", "Severne Fox Pro 115 (2026)", 2.41, .69, .115, 6.49, None, None, 40, "40", "F"),
    ("Savanna", "Severne Fox Pro 125 (2026)", 2.44, .71, .125, 6.79, None, None, 42, "42", "F"),
]

def board_row(b, fmt):
    brand, model, L, W, V, kg, tail, t, fin, finnote, kind = b
    est = []
    if tail is None:
        tail = 0.848 * W - 0.117 if kind == "S" else 0.571 * W + 0.051
        est.append("tail")
    if t is None:
        t = V / (k_block(W, kind) * L * W)
        est.append("thick")
    if fin is None:
        fin = round((0.30 + (W - 0.60) * 0.64) * 100)
        est.append("fin")
    wp = (0.50 if kind == "S" else 0.48) * L
    nose = (0.78 if kind == "S" else 0.70) * W
    tt = 0.045 if kind == "S" else 0.05
    fin_kg = fin * (0.017 if kind == "S" else 0.024)
    mass = kg + 0.45 + fin_kg
    area = (RHINO[fin] if kind == "S" else smax(fin)) / 1e4
    hard, soft = 0.526 * L, 0.877 * L
    nose_len = 0.70 * L
    track_c = 0.581 * L
    back_out = 0.5 * tail - 0.095
    front_out = 0.5 * W - 0.11
    tail_rocker = 0.001 if "Fox" in model else 0.0
    return fmt.format(brand=brand, model=model, L=L, W=W, wp=wp, tail=tail, nose=nose, t=t, tt=tt, V=V, mass=mass,
                      kg=kg, nr=0.128, nrl=nose_len, tr=tail_rocker, hard=hard, soft=soft, tb=track_c - 0.08,
                      tf=track_c + 0.08, bo=back_out, fo=front_out, fin=fin / 100, area=area, finnote=finnote,
                      est=",".join(est) or "-")

FMT1 = ("| {model} | {L:.2f} | {W:.3f} | {wp:.2f} | {tail:.3f} | {nose:.3f} | {t:.3f} | {tt:.3f} | 0.040 | {V:.3f} | "
        "{mass:.2f} ({kg:.2f}) | {est} |")
FMT2 = ("| {model} | {nr:.3f} / {nrl:.2f} | {tr:.3f} / 0.35 | {hard:.2f} / {soft:.2f} | 0.235 / 0.825 | {bo:.3f} / {fo:.3f} | "
        "0.120 / 0.235 | {tb:.3f} / {tf:.3f} | {fin:.2f} | {area:.4f} | {finnote} |")

if __name__ == "__main__":
    import sys
    group = SLALOM if sys.argv[1] == "S" else FREERACE
    current = None
    print("| Modelled on | length_m | width_m | widest_point_from_tail_m | tail_width_m | nose_width_m | thickness_m | tail_thickness_m | nose_thickness_m | volume_m3 | mass_kg (published) | derived |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for b in group:
        if b[0] != current:
            current = b[0]
            print(f"| **{current}** | | | | | | | | | | | |")
        print(board_row(b, FMT1))
    print()
    print("| Modelled on | nose_rocker_m / _length_m | tail_rocker_m / _length_m | hard_rail_to_m / soft_rail_from_m | back / front strap from tail | back / front strap out | fin box screws from tail | mast track back / front | fin span_m | fin area_m2 | fin (brand's range) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    current = None
    for b in group:
        if b[0] != current:
            current = b[0]
            print(f"| **{current}** | | | | | | | | | | |")
        print(board_row(b, FMT2))
