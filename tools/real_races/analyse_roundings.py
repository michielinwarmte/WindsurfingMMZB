"""Measure a real race's starts, legs and mark roundings by fixed criteria, for the AI skipper's head training.

Usage: python -I tools/real_races/analyse_roundings.py <course.json> <folder with .gpx files> [--csv=<out.csv>]

The course file (tools/real_races/courses/*.json) holds the virtual marks: drawn by Max on a picture of the tracks,
with the side each is rounded on, the start line and the starts. Every measure below has one fixed definition (the
CRITERIA table), as close as possible to the AI suite's own (Documentation/AI_TRAINING_METHOD.md), so a real rider's
number and the AI's number mean the same thing.

FOIL, NOT FIN (Max, 13 November 2026). These races are iQFOiL: the boards fly on a foil and turn on a wider radius
than the game's fin boards. So every measure is marked:
  carries over  - a shape or a timing that does not depend on the board's size of turn (seconds, shares, multiples
                  of the rider's own turn radius, sides, counts): use it for the fin AI;
  foil only     - metres, speeds and radii: the foil's own numbers; for the fin AI only through a ratio.
The game's AI never copies a foil number in metres or knots.
Report: Documentation/reports/real_races/metasail_event930.md (section 13)
"""
import csv
import glob
import json
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from read_gpx_race import heading_change, read_track  # noqa: E402  (same folder; python -I leaves it off the path)

STEADY_DEG = 6.0         # the heading "holds" when it changes less than this ...
STEADY_S = 2.0           # ... over this many seconds (the AI suite's definition of out of the turn)
ROUNDED_WITHIN_M = 50.0  # a mark counts as rounded only if the rider came this close, on the right side
GYBE_DEG = 60.0          # a gybe or tack on a leg: the heading turns more than this ...
GYBE_S = 15.0            # ... within this many seconds
LAST_GYBE_OFF_DEG = 70.0 # the start's last gybe: the last moment the heading was this far off the line's crossing direction

CRITERIA = [
    # (measure, definition, carries over to fins?)
    ('rounded', f'came within {ROUNDED_WITHIN_M:.0f} m of the mark with the mark on the required side (port or starboard) at the closest approach', 'carries over'),
    ('closest_m', 'the nearest the track came to the mark (between GPS points too: the track taken as straight lines)', 'foil only'),
    ('closest_r', 'closest_m in multiples of the rider\'s own turn radius at that mark', 'carries over'),
    ('turn_start', f'the last moment before the closest approach when the heading held (changed under {STEADY_DEG:.0f} deg in {STEADY_S:.0f} s)', '-'),
    ('start_m / start_s', 'the distance from the mark, and the seconds before the closest approach, at the turn start', 'foil only / carries over'),
    ('start_r', 'start_m in multiples of the turn radius: how early the turn begins', 'carries over'),
    ('exit', f'the first moment after the closest approach when the heading holds again (under {STEADY_DEG:.0f} deg in {STEADY_S:.0f} s): the AI suite\'s "out of the turn". How soon a rider is out depends on what it does next (Max: the race\'s own tactic), so compare exits only between like situations', '-'),
    ('exit_m / exit_s', 'the distance from the mark, and the seconds after the closest approach, at the exit (exit_m is the AI suite\'s exit_m)', 'foil only / carries over'),
    ('exit_r', 'exit_m in multiples of the turn radius', 'carries over'),
    ('turned_deg', 'the heading change from the turn start to the exit (+ right, - left)', 'carries over'),
    ('extra_turn_deg', 'how much more the rider turned than the course turns at the mark (the bearing from the last mark '
                       'to this one against the bearing to the next): the AI suite\'s gate measure; over about 60 deg = a '
                       'gybe or a loop inside the rounding; below 0 = the rider came in already turned (a leg not sailed '
                       'straight, such as a downwind leg)', 'carries over'),
    ('radius_m', 'the path from the turn start to the exit divided by the angle turned (radians)', 'foil only'),
    ('turn_s', 'the seconds from the turn start to the exit', 'carries over (roughly)'),
    ('apex_share', 'when in the turn the rider is closest to the mark: 0 = at the turn start, 1 = at the exit; over 0.5 = wide in, tight out', 'carries over'),
    ('kt_in / kt_min / kt_out', 'the speed: the mean of the 5 s before the turn start, the slowest in the turn, at the exit', 'foil only'),
    ('kept', 'kt_out / kt_in: the share of the speed kept through the turn', 'carries over (roughly)'),
    ('leg_s', 'the seconds from the rider\'s crossing of the start line (or its closest approach to the last mark) to its closest approach to the next mark', 'foil only'),
    ('sailed_share', 'the distance sailed on the leg divided by the straight distance (1.00 = straight)', 'carries over'),
    ('gybes', f'the turns of more than {GYBE_DEG:.0f} deg within {GYBE_S:.0f} s on the leg (not counting the roundings)', 'carries over'),
    ('start: over_s', 'the seconds after the fleet\'s first board that the rider crossed the start line toward the first mark (the gun is not in the GPS)', 'carries over'),
    ('start: kt_over', 'the speed crossing the line', 'foil only'),
    ('start: behind_m_10s / _5s', 'how far behind the line the rider was 10 s and 5 s before the fleet\'s first board crossed', 'foil only'),
    ('start: last_gybe_s / _m', f'the last moment before the crossing when the heading was over {LAST_GYBE_OFF_DEG:.0f} deg off the crossing direction: its seconds and metres before the line', 'carries over (s) / foil only (m)'),
    ('start: past_m_30s', 'how far past the line the rider was 30 s after the fleet\'s first board crossed (the AI suite\'s score_m)', 'foil only'),
]


class Frame:
    """Local metres: x east, y north, from a reference point (the course's first mark)."""

    def __init__(self, lat, lon):
        self.lat, self.lon = lat, lon
        self.east = 111195.0 * math.cos(math.radians(lat))

    def xy(self, lat, lon):
        return ((lon - self.lon) * self.east, (lat - self.lat) * 111195.0)


def bearing(ax, ay, bx, by):
    return math.degrees(math.atan2(bx - ax, by - ay)) % 360.0


def nearest_on_segment(px, py, ax, ay, bx, by):
    """The point of the segment a-b nearest to p, and where along it (0 to 1)."""
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    f = 0.0 if length2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2))
    return ax + f * dx, ay + f * dy, f


def holds_at(track, i):
    """Does the heading hold at point i: under STEADY_DEG of change over the next STEADY_S seconds?"""
    j = i
    while j + 1 < len(track) and track[j]['t'] - track[i]['t'] < STEADY_S:
        j += 1
    if track[j]['t'] - track[i]['t'] < STEADY_S - 0.5:
        return False
    return abs(heading_change(track[i]['course'], track[j]['course'])) < STEADY_DEG


def turned_between(track, i, j):
    return sum(heading_change(a['course'], b['course']) for a, b in zip(track[i:j], track[i + 1:j + 1]))


def path_between(track, i, j):
    return sum(math.hypot(b['x'] - a['x'], b['y'] - a['y']) for a, b in zip(track[i:j], track[i + 1:j + 1]))


def mean_speed(track, t_from, t_to):
    speeds = [p['kt'] for p in track if t_from <= p['t'] <= t_to]
    return statistics.mean(speeds) if speeds else float('nan')


def closest_approach(track, mx, my, i_from, i_to):
    """(distance, index of the segment's first point, time, x, y) of the nearest approach to (mx, my)."""
    best = None
    for i in range(i_from, min(i_to, len(track) - 1)):
        a, b = track[i], track[i + 1]
        x, y, f = nearest_on_segment(mx, my, a['x'], a['y'], b['x'], b['y'])
        d = math.hypot(x - mx, y - my)
        if best is None or d < best[0]:
            best = (d, i, a['t'] + f * (b['t'] - a['t']), x, y)
    return best


def rounding(track, mark, course_turn, i_from, i_to):
    """Every criterion for one rider at one mark (see CRITERIA)."""
    d, i, t_c, cx, cy = closest_approach(track, mark['x'], mark['y'], i_from, i_to)
    p = track[i]
    h = math.radians(p['course'])
    left = math.sin(h) * (mark['y'] - p['y']) - math.cos(h) * (mark['x'] - p['x']) > 0
    side_ok = (mark['rounding'] == 'port') == left
    start = i
    while start > i_from and not holds_at(track, start):
        start -= 1
    # The exit: the AI suite's rule exactly. (A first version also asked for half the course's turn; a board that
    # comes in already angled, from a beat or a downwind gybe, never turns that much, so its exit came far too late.)
    end = i + 1
    while end < i_to and not holds_at(track, end):
        end += 1
    turned = turned_between(track, start, end)
    path = path_between(track, start, end)
    radius = path / abs(math.radians(turned)) if turned else float('inf')
    t_s, t_e = track[start]['t'], track[end]['t']
    start_m = math.hypot(track[start]['x'] - mark['x'], track[start]['y'] - mark['y'])
    exit_m = math.hypot(track[end]['x'] - mark['x'], track[end]['y'] - mark['y'])
    kt_in = mean_speed(track, t_s - 5, t_s)
    return {
        'rounded': d <= ROUNDED_WITHIN_M and side_ok, 'side_ok': side_ok, 'closest_m': d, 'closest_r': d / radius,
        't_closest': t_c, 'start_m': start_m, 'start_s': t_c - t_s, 'start_r': start_m / radius,
        'exit_m': exit_m, 'exit_s': t_e - t_c, 'exit_r': exit_m / radius, 'turned_deg': turned,
        'extra_turn_deg': abs(turned) - abs(course_turn), 'radius_m': radius,
        'turn_s': t_e - t_s, 'apex_share': (t_c - t_s) / (t_e - t_s) if t_e > t_s else float('nan'),
        'kt_in': kt_in, 'kt_min': min(q['kt'] for q in track[start:end + 1]), 'kt_out': track[end]['kt'],
        'kept': track[end]['kt'] / kt_in if kt_in else float('nan'), 'i_closest': i,
    }


def line_crossing(track, a, b, toward_deg, t_from, t_to):
    """The first crossing of the (endless) line a-b heading within 60 deg of toward_deg: (time, kt, x, y)."""
    def side(p):
        return (b[0] - a[0]) * (p['y'] - a[1]) - (b[1] - a[1]) * (p['x'] - a[0])
    for p, q in zip(track, track[1:]):
        if t_from <= q['t'] <= t_to and side(p) * side(q) < 0 and abs(heading_change(toward_deg, q['course'])) < 60:
            f = side(p) / (side(p) - side(q))
            return (p['t'] + f * (q['t'] - p['t']), q['kt'], p['x'] + f * (q['x'] - p['x']), p['y'] + f * (q['y'] - p['y']))
    return None


def count_gybes(track, i_from, i_to, skip):
    """Turns of more than GYBE_DEG within GYBE_S, outside the given (start, end) index spans of the roundings."""
    count, i = 0, i_from
    while i < i_to:
        if any(s <= i <= e for s, e in skip):
            i += 1
            continue
        j = i
        while j + 1 < i_to and track[j + 1]['t'] - track[i]['t'] <= GYBE_S:
            j += 1
        if abs(turned_between(track, i, j)) > GYBE_DEG and not any(s <= j <= e for s, e in skip):
            count += 1
            i = j + 1
        else:
            i += 1
    return count


def fmt(v, digits=0):
    if isinstance(v, bool):
        return 'yes' if v else 'NO'
    if isinstance(v, float) and math.isnan(v):
        return '-'
    return f'{v:.{digits}f}'


def main():
    course = json.load(open(sys.argv[1], encoding='utf-8'))
    first = course['marks'][0]
    frame = Frame(first['lat'], first['lon'])
    for m in course['marks']:
        m['x'], m['y'] = frame.xy(m['lat'], m['lon'])
    line_a = frame.xy(course['start_line']['end_1']['lat'], course['start_line']['end_1']['lon'])
    line_b = frame.xy(course['start_line']['end_2']['lat'], course['start_line']['end_2']['lon'])
    line_mid = ((line_a[0] + line_b[0]) / 2, (line_a[1] + line_b[1]) / 2)
    finish = course.get('finish')
    finish_xy = frame.xy(finish['lat'], finish['lon']) if finish else None
    toward_first = bearing(line_mid[0], line_mid[1], first['x'], first['y'])

    from datetime import datetime
    zero = datetime.fromisoformat(course['time_zero_utc'].replace('Z', '+00:00')).timestamp()
    tracks = {}
    for path in sorted(glob.glob(os.path.join(sys.argv[2], '*.gpx'))):
        track = read_track(path)
        for p in track:
            p['x'], p['y'] = frame.xy(p['lat'], p['lon'])
            p['t'] = p['stamp'] - zero
        tracks[os.path.splitext(os.path.basename(path))[0]] = track

    print(f"{course['race']}\n{course['board']}\n")
    print('== The criteria ==')
    for name, definition, carries in CRITERIA:
        print(f'  {name}: {definition} [{carries}]')

    rows = []
    # --- the starts ---
    counted_start = None
    for s in course['starts']:
        crossings = {r: line_crossing(tr, line_a, line_b, toward_first, s['search_from_s'], s['search_to_s']) for r, tr in tracks.items()}
        crossings = {r: c for r, c in crossings.items() if c}
        if not crossings:
            continue
        gun = min(c[0] for c in crossings.values())
        nx, ny = math.sin(math.radians(toward_first)), math.cos(math.radians(toward_first))

        def past(x, y):
            return (x - line_mid[0]) * nx + (y - line_mid[1]) * ny  # metres past the line toward mark 1 (roughly)
        label = s['label'] + (' (over early)' if s.get('over_early') else '') + (' (counted)' if s.get('counted') else '')
        print(f"\n== {label}: the fleet's first board over at t={gun:.0f} s ==")
        print('  rider   over_s  kt_over  behind_m_10s  behind_m_5s  last_gybe_s  last_gybe_m  past_m_30s')
        for r, c in sorted(crossings.items(), key=lambda rc: rc[1][0]):
            tr = tracks[r]
            at = lambda t: min(tr, key=lambda q: abs(q['t'] - t))
            before = [q for q in tr if c[0] - 150 <= q['t'] <= c[0]]
            off = [q for q in before if abs(heading_change(toward_first, q['course'])) > LAST_GYBE_OFF_DEG]
            last = max(off, key=lambda q: q['t']) if off else None
            row = {'rider': r, 'item': s['label'], 'over_s': c[0] - gun, 'kt_over': c[1],
                   'behind_m_10s': -past(at(gun - 10)['x'], at(gun - 10)['y']), 'behind_m_5s': -past(at(gun - 5)['x'], at(gun - 5)['y']),
                   'last_gybe_s': c[0] - last['t'] if last else float('nan'), 'last_gybe_m': -past(last['x'], last['y']) if last else float('nan'),
                   'past_m_30s': past(at(gun + 30)['x'], at(gun + 30)['y']), 'over_early': bool(s.get('over_early'))}
            rows.append(row)
            print(f"  {r:7s} {fmt(row['over_s']):>6s} {fmt(row['kt_over'], 1):>8s} {fmt(row['behind_m_10s']):>13s} {fmt(row['behind_m_5s']):>12s} "
                  f"{fmt(row['last_gybe_s']):>12s} {fmt(row['last_gybe_m']):>12s} {fmt(row['past_m_30s']):>11s}")
        if s.get('counted'):
            counted_start = (gun, crossings)

    if counted_start is None:
        print('\nNo counted start found: no roundings measured.')
        return
    gun, crossings = counted_start

    # --- the roundings and the legs (after the counted start) ---
    marks = course['marks']
    points = [line_mid] + [(m['x'], m['y']) for m in marks] + ([finish_xy] if finish_xy else [])
    legs = [bearing(*points[k], *points[k + 1]) for k in range(len(points) - 1)]
    results = {}
    for r, tr in tracks.items():
        if r not in crossings:
            continue
        i_from = next(i for i, p in enumerate(tr) if p['t'] >= crossings[r][0])
        i_to = max(i for i, p in enumerate(tr) if p['t'] <= course['race_end_s'])
        res, i = [], i_from
        for k, m in enumerate(marks):
            turn = heading_change(legs[k], legs[k + 1]) if k + 1 < len(legs) else 90.0
            # the mark is searched from the last rounding on, up to the race's end
            rd = rounding(tr, m, turn, i, i_to)
            res.append(rd)
            i = rd['i_closest'] + 1
        results[r] = res

    print('\n== The roundings (after the counted start) ==')
    keys = ['rounded', 'closest_m', 'closest_r', 'start_m', 'start_s', 'start_r', 'exit_m', 'exit_s', 'exit_r',
            'turned_deg', 'extra_turn_deg', 'radius_m', 'turn_s', 'apex_share', 'kt_in', 'kt_min', 'kt_out', 'kept']
    digits = {'closest_r': 2, 'start_r': 2, 'exit_r': 2, 'apex_share': 2, 'kept': 2, 'kt_in': 1, 'kt_min': 1, 'kt_out': 1}
    for k, m in enumerate(marks):
        print(f"\n  Mark {m['name']} ({m['rounding']}), the course turns {heading_change(legs[k], legs[k + 1]) if k + 1 < len(legs) else float('nan'):+.0f} deg there")
        print('    ' + 'rider    ' + ' '.join(f'{key:>10s}' for key in keys))
        for r in sorted(results):
            rd = results[r][k]
            print('    ' + f'{r:8s} ' + ' '.join(f'{fmt(rd[key], digits.get(key, 0)):>10s}' for key in keys))
            rows.append({'rider': r, 'item': f"mark {m['name']}", **{key: rd[key] for key in keys}})
        med = {key: statistics.median(results[r][k][key] for r in results) for key in keys if key != 'rounded'}
        print('    ' + f'{"median":8s} ' + ' '.join(f'{fmt(med.get(key, float("nan")), digits.get(key, 0)):>10s}' for key in keys))

    print('\n== The legs (after the counted start) ==')
    names = ['start'] + [m['name'] for m in marks] + (['finish (provisional)'] if finish_xy else [])
    for k in range(len(points) - 1):
        straight = math.hypot(points[k + 1][0] - points[k][0], points[k + 1][1] - points[k][1])
        print(f"  {names[k]} -> {names[k + 1]}: {straight:.0f} m straight, bearing {legs[k]:.0f} deg")
        for r in sorted(results):
            tr = tracks[r]
            t_a = crossings[r][0] if k == 0 else results[r][k - 1]['t_closest']
            if k < len(marks):
                t_b = results[r][k]['t_closest']
            else:
                near = closest_approach(tr, finish_xy[0], finish_xy[1], results[r][-1]['i_closest'], len(tr) - 1)
                t_b = near[2]
            i_a = next(i for i, p in enumerate(tr) if p['t'] >= t_a)
            i_b = max(i for i, p in enumerate(tr) if p['t'] <= t_b)
            sailed = path_between(tr, i_a, i_b)
            spans = []
            for rd in results[r]:
                s_i = next(i for i, p in enumerate(tr) if p['t'] >= rd['t_closest'] - rd['start_s'])
                e_i = next(i for i, p in enumerate(tr) if p['t'] >= rd['t_closest'] + rd['exit_s'])
                spans.append((s_i, e_i))
            gy = count_gybes(tr, i_a, i_b, spans)
            row = {'rider': r, 'item': f'leg {names[k]}->{names[k + 1]}', 'leg_s': t_b - t_a,
                   'sailed_share': sailed / straight if straight else float('nan'), 'gybes': gy,
                   'mean_kt': mean_speed(tr, t_a, t_b)}
            rows.append(row)
            print(f"    {r:8s} leg_s {fmt(row['leg_s']):>4s}  sailed_share {fmt(row['sailed_share'], 2):>5s}  gybes {gy}  mean {fmt(row['mean_kt'], 1)} kt")

    out = None
    for arg in sys.argv[3:]:
        if arg.startswith('--csv='):
            out = arg.split('=', 1)[1]
    if out:
        fields = []
        for row in rows:
            for key in row:
                if key not in fields:
                    fields.append(key)
        with open(out, 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=fields)
            w.writeheader()
            for row in rows:
                w.writerow({k: (round(v, 3) if isinstance(v, float) else v) for k, v in row.items()})
        print(f'\nCSV: {out} ({len(rows)} rows)')


if __name__ == '__main__':
    main()
