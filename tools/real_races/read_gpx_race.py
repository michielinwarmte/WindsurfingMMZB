"""Read one race's Metasail GPX tracks (one file per rider) and print what the riders did, in plain numbers.

Usage: python -I tools/real_races/read_gpx_race.py <folder with .gpx files> [--svg=<out.svg>] [--from_s=0 --to_s=end]
    [--start_line=<mark 1 x>,<mark 1 y>,<first leg deg>,<line to mark 1 m>,<after s>] [--points=x,y;x,y (marks to draw)] [--marks=0 (tracks only)] [--find_start=<from s>,<to s>,<wind from deg>] [--size_px=900]
(--from_s and --to_s: the racing part, in seconds from the first point; the summary and the picture use only that)

What it measures (no names printed; riders are rider1, rider2, ... by file name):
- the time line: every rider's speed every 10 s, to see the pre-start, the start and the finish;
- the turns: every change of heading of more than 50 degrees within 12 s while sailing faster than 8 kt: when,
  where, the heading in and out, the speed in, at the slowest and out, the radius of the arc;
- the marks: the turns of different riders that happen within 60 m of each other, grouped, their middle point;
- per rounding: how close the rider's track came to that middle point, and how far past it the rider was when its
  heading held steady again (under 6 degrees change in 2 s: the AI suite's "out of the turn").
Optional: an SVG picture of the tracks with the marks.

The tracks are iQFOiL races: foils, not fin boards. Use the geometry and the timing for the AI's racing, never
the speeds for the physics. Report: Documentation/reports/real_races/metasail_event930.md (section 12).
"""
import glob
import math
import os
import re
import statistics
import sys
from datetime import datetime, timezone

KNOT_MS = 0.514444
METRES_PER_DEG_LAT = 111195.0


def option(name, default=None):
    for arg in sys.argv[2:]:
        if arg.startswith('--' + name + '='):
            return arg.split('=', 1)[1]
    return default


def read_track(path):
    """Points as dicts: t (s since the first point of all tracks is set later), lat, lon, kt, course."""
    text = open(path, encoding='utf-8-sig').read()
    pattern = (r'<trkpt lat="([-\d.]+)" lon="([-\d.]+)">\s*<time>([^<]+)</time>.*?'
               r'<gpxtpx:speed>([-\d.]+)</gpxtpx:speed>\s*<gpxtpx:course>([-\d.]+)</gpxtpx:course>')
    points = []
    for lat, lon, time, kt, course in re.findall(pattern, text, re.S):
        stamp = datetime.fromisoformat(time.replace('Z', '+00:00')).timestamp()
        points.append({'stamp': stamp, 'lat': float(lat), 'lon': float(lon), 'kt': float(kt), 'course': float(course)})
    return points


def to_metres(tracks):
    """East (x) and north (y) in metres from the middle of all points; t in seconds from the earliest point."""
    lat0 = statistics.mean(p['lat'] for tr in tracks.values() for p in tr)
    lon0 = statistics.mean(p['lon'] for tr in tracks.values() for p in tr)
    t0 = min(tr[0]['stamp'] for tr in tracks.values())
    east = METRES_PER_DEG_LAT * math.cos(math.radians(lat0))
    for tr in tracks.values():
        for p in tr:
            p['x'] = (p['lon'] - lon0) * east
            p['y'] = (p['lat'] - lat0) * METRES_PER_DEG_LAT
            p['t'] = p['stamp'] - t0
    return t0


def heading_change(a, b):
    """Signed change from heading a to heading b, degrees, -180 to 180."""
    return (b - a + 540.0) % 360.0 - 180.0


def find_turns(track):
    """Turns: the heading changes by more than 50 degrees within 12 s at speed. Returns one entry per turn."""
    turns = []
    i = 0
    n = len(track)
    while i < n - 12:
        p = track[i]
        if p['kt'] < 8.0:
            i += 1
            continue
        j = i + 1
        while j < n and track[j]['t'] - p['t'] <= 12.0:
            j += 1
        window = track[i:j]
        total = sum(heading_change(a['course'], b['course']) for a, b in zip(window, window[1:]))
        if abs(total) < 50.0:
            i += 1
            continue
        # The turn: from where the heading starts to change to where it holds again.
        start = i
        end = j - 1
        while end + 2 < n and abs(heading_change(track[end]['course'], track[end + 2]['course'])) >= 6.0:
            end += 1
        arc = track[start:end + 1]
        turned = sum(heading_change(a['course'], b['course']) for a, b in zip(arc, arc[1:]))
        length = sum(math.hypot(b['x'] - a['x'], b['y'] - a['y']) for a, b in zip(arc, arc[1:]))
        radius = length / math.radians(abs(turned)) if turned else float('inf')
        apex = min(arc, key=lambda q: q['kt'])
        turns.append({'start': start, 'end': end, 'in_course': track[start]['course'], 'out_course': track[end]['course'],
                      'turned': turned, 'kt_in': track[start]['kt'], 'kt_min': apex['kt'], 'kt_out': track[end]['kt'],
                      'radius_m': radius, 'mid': arc[len(arc) // 2], 't': arc[len(arc) // 2]['t'],
                      'seconds': arc[-1]['t'] - arc[0]['t']})
        i = end + 1
    return turns


def group_marks(all_turns, reach_m=60.0):
    """Turns of different riders within reach_m of each other form one mark (taken as their middle point)."""
    marks = []
    for rider, turn in all_turns:
        for mark in marks:
            if math.hypot(mark['x'] - turn['mid']['x'], mark['y'] - turn['mid']['y']) < reach_m:
                mark['turns'].append((rider, turn))
                mark['x'] = statistics.mean(t['mid']['x'] for _, t in mark['turns'])
                mark['y'] = statistics.mean(t['mid']['y'] for _, t in mark['turns'])
                break
        else:
            marks.append({'x': turn['mid']['x'], 'y': turn['mid']['y'], 'turns': [(rider, turn)]})
    return [m for m in marks if len({r for r, _ in m['turns']}) >= 2]


def write_svg(tracks, marks, path, t_from, t_to, extra_lines=(), extra_points=(), size_px=900.0):
    xs = [p['x'] for tr in tracks.values() for p in tr if t_from <= p['t'] <= t_to]
    ys = [p['y'] for tr in tracks.values() for p in tr if t_from <= p['t'] <= t_to]
    pad = 40.0
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
    scale = size_px / max(x1 - x0, y1 - y0)
    w, h = (x1 - x0) * scale, (y1 - y0) * scale
    colours = ['#1f77b4', '#d62728', '#2ca02c', '#9467bd', '#ff7f0e', '#8c564b']
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h + 30:.0f}" viewBox="0 0 {w:.0f} {h + 30:.0f}">',
           f'<rect width="100%" height="100%" fill="white"/>']
    for k, (rider, tr) in enumerate(sorted(tracks.items())):
        pts = ' '.join(f"{(p['x'] - x0) * scale:.1f},{(y1 - p['y']) * scale:.1f}" for p in tr if t_from <= p['t'] <= t_to)
        out.append(f'<polyline points="{pts}" fill="none" stroke="{colours[k % len(colours)]}" stroke-width="1.5"/>')
        out.append(f'<text x="10" y="{h + 20:.0f}" dx="{k * 110}" fill="{colours[k % len(colours)]}" font-size="14" font-family="sans-serif">{rider}</text>')
    for (ax, ay), (bx, by) in extra_lines:
        out.append(f'<line x1="{(ax - x0) * scale:.1f}" y1="{(y1 - ay) * scale:.1f}" x2="{(bx - x0) * scale:.1f}" '
                   f'y2="{(y1 - by) * scale:.1f}" stroke="black" stroke-width="3"/>')
    for n, (px, py) in enumerate(extra_points):
        cx, cy = (px - x0) * scale, (y1 - py) * scale
        out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="8" fill="none" stroke="black" stroke-width="3"/>')
    for n, m in enumerate(marks):
        cx, cy = (m['x'] - x0) * scale, (y1 - m['y']) * scale
        out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="6" fill="none" stroke="black" stroke-width="2"/>')
        out.append(f'<text x="{cx + 9:.1f}" y="{cy - 9:.1f}" font-size="14" font-family="sans-serif">M{n + 1}</text>')
    bar = 100.0 * scale
    out.append(f'<line x1="{w - bar - 10:.1f}" y1="{h + 20:.0f}" x2="{w - 10:.1f}" y2="{h + 20:.0f}" stroke="black" stroke-width="2"/>')
    out.append(f'<text x="{w - bar - 10:.1f}" y="{h + 15:.0f}" font-size="12" font-family="sans-serif">100 m, north up</text>')
    out.append('</svg>')
    open(path, 'w', encoding='utf-8').write('\n'.join(out))


def position_at(track, t):
    """The rider's position, speed and heading at time t, straight between the two GPS points around it."""
    for a, b in zip(track, track[1:]):
        if a['t'] <= t <= b['t']:
            f = 0.0 if b['t'] == a['t'] else (t - a['t']) / (b['t'] - a['t'])
            return (a['x'] + f * (b['x'] - a['x']), a['y'] + f * (b['y'] - a['y']), a['kt'] + f * (b['kt'] - a['kt']), b['course'])
    return None


def find_start(tracks, t_from, t_to, wind_from_deg):
    """Max's way to find the start (13 November 2026): play the tracks back and find the moment the riders are in
    one line along the wind (a reaching start: the line runs with the wind, the boards cross it on a reach).
    For every second: the best straight line through all riders (least squares), how far they are off it,
    the line's angle to the wind, their speeds and headings."""
    found = []
    t = t_from
    while t <= t_to:
        here = [position_at(tr, t) for tr in tracks.values()]
        if all(here):
            xs = [h[0] for h in here]
            ys = [h[1] for h in here]
            mx, my = statistics.mean(xs), statistics.mean(ys)
            sxx = sum((x - mx) ** 2 for x in xs)
            syy = sum((y - my) ** 2 for y in ys)
            sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
            # The line's direction: the main axis of the points (east = x, north = y), as a compass bearing.
            angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
            bearing = (90.0 - math.degrees(angle)) % 180.0
            dx, dy = math.cos(angle), math.sin(angle)
            along = [(x - mx) * dx + (y - my) * dy for x, y in zip(xs, ys)]
            off = [abs(-(x - mx) * dy + (y - my) * dx) for x, y in zip(xs, ys)]
            to_wind = abs(heading_change(bearing, wind_from_deg))
            to_wind = min(to_wind, 180.0 - to_wind)
            found.append({'t': t, 'off_m': max(off), 'length_m': max(along) - min(along), 'bearing': bearing,
                          'to_wind': to_wind, 'kt': [h[2] for h in here], 'course': [h[3] for h in here],
                          'mid': (mx, my)})
        t += 1.0
    return found


def start_line_crossings(tracks, mark_x, mark_y, leg_deg, back_m, after_s):
    """The start line, estimated: perpendicular to the first leg (leg_deg, the way from the line to mark 1),
    back_m metres before mark 1 (Metasail's statistics give the line's distance to mark 1). Returns the line's two
    ends (60 m either side of its middle) and, per rider, the first crossing toward mark 1 after after_s."""
    leg = math.radians(leg_deg)
    ux, uy = math.sin(leg), math.cos(leg)
    mid_x, mid_y = mark_x - back_m * ux, mark_y - back_m * uy
    ends = ((mid_x - 60 * uy, mid_y + 60 * ux), (mid_x + 60 * uy, mid_y - 60 * ux))
    crossings = {}
    for rider, track in tracks.items():
        for a, b in zip(track, track[1:]):
            to_go_a = (mark_x - a['x']) * ux + (mark_y - a['y']) * uy
            to_go_b = (mark_x - b['x']) * ux + (mark_y - b['y']) * uy
            if a['t'] >= after_s and to_go_a > back_m >= to_go_b and abs(heading_change(leg_deg, b['course'])) < 45:
                crossings[rider] = b
                break
    return ends, crossings


def main():
    files = sorted(glob.glob(os.path.join(sys.argv[1], '*.gpx')))
    tracks = {os.path.splitext(os.path.basename(f))[0]: read_track(f) for f in files}
    t0 = to_metres(tracks)
    print(f"{len(tracks)} riders; time 0 = {datetime.fromtimestamp(t0, timezone.utc).strftime('%Y-%m-%d %H:%M:%S')} UTC")

    print('\n== Speed (kt) every 10 s ==')
    end = max(tr[-1]['t'] for tr in tracks.values())
    print('  t(s)  ' + '  '.join(f'{r:>7s}' for r in sorted(tracks)))
    for t in range(0, int(end) + 1, 10):
        row = []
        for r in sorted(tracks):
            near = min(tracks[r], key=lambda p: abs(p['t'] - t))
            row.append(f"{near['kt']:7.1f}" if abs(near['t'] - t) <= 3 else '      -')
        print(f'  {t:5d}  ' + '  '.join(row))

    all_turns = []
    print('\n== Turns (more than 50 deg in 12 s, faster than 8 kt) ==')
    for r in sorted(tracks):
        for turn in find_turns(tracks[r]):
            all_turns.append((r, turn))
            print(f"  {r} t={turn['t']:6.0f}s at ({turn['mid']['x']:6.0f},{turn['mid']['y']:6.0f}) m  "
                  f"{turn['in_course']:3.0f} -> {turn['out_course']:3.0f} deg ({turn['turned']:+5.0f}) in {turn['seconds']:4.0f} s, "
                  f"speed {turn['kt_in']:4.1f} / {turn['kt_min']:4.1f} / {turn['kt_out']:4.1f} kt, radius {turn['radius_m']:4.0f} m")

    marks = group_marks(all_turns)
    print('\n== Marks (turns of 2 or more riders within 60 m) ==')
    for n, m in enumerate(marks):
        riders = sorted({r for r, _ in m['turns']})
        print(f"  M{n + 1} at ({m['x']:.0f},{m['y']:.0f}) m: {len(m['turns'])} turns by {len(riders)} riders, "
              f"t {min(t['t'] for _, t in m['turns']):.0f} to {max(t['t'] for _, t in m['turns']):.0f} s")
        for r, turn in sorted(m['turns'], key=lambda rt: rt[1]['t']):
            tr = tracks[r]
            arc = tr[max(0, turn['start'] - 10):turn['end'] + 1]
            closest = min(math.hypot(p['x'] - m['x'], p['y'] - m['y']) for p in arc)
            out = tr[turn['end']]
            past = math.hypot(out['x'] - m['x'], out['y'] - m['y'])
            print(f"     {r} t={turn['t']:5.0f}s  closest {closest:4.0f} m, steady again {past:4.0f} m from the middle, "
                  f"turned {turn['turned']:+4.0f} deg, radius {turn['radius_m']:4.0f} m, speed {turn['kt_in']:4.1f} -> {turn['kt_min']:4.1f} -> {turn['kt_out']:4.1f} kt")

    t_from = float(option('from_s', '0'))
    t_to = float(option('to_s', str(end)))
    full = [t for _, t in all_turns if t_from <= t['t'] <= t_to and 150.0 <= abs(t['turned']) <= 215.0]
    if full:
        med = lambda key: statistics.median(t[key] for t in full)
        kept = [t['kt_out'] / t['kt_in'] for t in full if t['kt_in'] > 0]
        print(f"\n== Full turns (150 to 215 deg) between {t_from:.0f} and {t_to:.0f} s: {len(full)} ==")
        print(f"  median: {med('seconds'):.0f} s, radius {med('radius_m'):.0f} m (range {min(t['radius_m'] for t in full):.0f} to "
              f"{max(t['radius_m'] for t in full):.0f}), speed in {med('kt_in'):.1f} kt, slowest {med('kt_min'):.1f} kt, out {med('kt_out'):.1f} kt; "
              f"speed out / speed in {statistics.median(kept):.2f}; ended under 6 kt (touch-down or fall): {sum(1 for t in full if t['kt_out'] < 6.0)}")

    fs = option('find_start')
    if fs:
        f_from, f_to, wind = (float(v) for v in fs.split(','))
        moments = find_start(tracks, f_from, f_to, wind)
        good = [m for m in moments if m['length_m'] >= 20.0 and min(m['kt']) >= 10.0 and m['to_wind'] <= 30.0]
        good.sort(key=lambda m: m['off_m'])
        print()
        print(f"== Riders in one line along the wind ({wind:.0f} deg), {f_from:.0f} to {f_to:.0f} s: the best moments ==")
        print("  (all faster than 10 kt, spread over 20 m or more, the line within 30 deg of the wind; sorted by the farthest rider off the line)")
        for m in good[:12]:
            print(f"  t={m['t']:5.0f} s: off the line at most {m['off_m']:4.1f} m, line {m['length_m']:4.0f} m long, "
                  f"bearing {m['bearing']:3.0f}/{(m['bearing'] + 180) % 360:3.0f} ({m['to_wind']:2.0f} deg off the wind), "
                  f"middle ({m['mid'][0]:.0f},{m['mid'][1]:.0f}) m, speeds {' '.join(f'{k:.0f}' for k in m['kt'])} kt, "
                  f"headings {' '.join(f'{c:.0f}' for c in m['course'])}")

    lines = []
    start = option('start_line')
    if start:
        mark_x, mark_y, leg_deg, back_m, after_s = (float(v) for v in start.split(','))
        ends, crossings = start_line_crossings(tracks, mark_x, mark_y, leg_deg, back_m, after_s)
        lines.append(ends)
        print(f"\n== The start line ({back_m:.0f} m before mark 1 at ({mark_x:.0f},{mark_y:.0f}), first leg {leg_deg:.0f} deg), crossed after {after_s:.0f} s ==")
        for rider, p in sorted(crossings.items(), key=lambda rp: rp[1]['t']):
            print(f"  {rider}: t={p['t']:.0f} s at {p['kt']:.1f} kt, heading {p['course']:.0f}")
        if crossings:
            ts = [p['t'] for p in crossings.values()]
            print(f"  all {len(ts)} over within {max(ts) - min(ts):.0f} s, at {min(p['kt'] for p in crossings.values()):.1f} to {max(p['kt'] for p in crossings.values()):.1f} kt")
    points = []
    if option('points'):
        points = [tuple(float(v) for v in xy.split(',')) for xy in option('points').split(';')]

    svg = option('svg')
    if svg:
        auto = [] if points else [m for m in marks if any(t_from <= t['t'] <= t_to for _, t in m['turns'])]
        if option('marks', '1') == '0':  # the tracks only, for Max to draw the marks in
            auto, lines, points = [], [], []
        write_svg(tracks, auto, svg, t_from, t_to, lines, points, float(option('size_px', '900')))
        print(f'\nSVG: {svg}')


if __name__ == '__main__':
    main()
