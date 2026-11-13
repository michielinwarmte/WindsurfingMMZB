"""Measure the AI skipper's own races by the same criteria as the real races (analyse_roundings.py).

Usage: python -I tools/real_races/ai_suite_measure.py <suite run folder> [<more run folders>] --what=roundings|starts|legs [--csv=<out.csv>]

A suite run (tools/heads/random_suite.py) leaves, per race rNNNN: the log (logs/rNNNN.log: COURSE_JSON, the wind, one
HEADS_RESULT per board) and a CSV per board (rNNNN/<board>.csv: race_time_s with 0 at the gun, x_m east, z_m south,
heading_deg (compass), speed_ms, next_step, doing). This reads them into the same track format as the GPX reader and
runs the same measures:
  --what=roundings  every MARK step a board rounds (gates are left out: the real race had none), with the course's
                    turn there, sorted into situations by that turn (small: under 100 deg, full: 130 deg and more);
  --what=starts     per start: the boards' crossing of the line toward mark 1 (the gun is known here: race time 0),
                    the spread, the last gybe before the line, the speed over the line against the board's own top
                    speed in the 30 s after, how far behind the line at -10 s and -5 s.
The AI sails fin boards; the real riders foils. Compare only the measures marked "carries over" in analyse_roundings.
Report: Documentation/reports/real_races/HEAD_PLAN.md
"""
import csv
import glob
import json
import math
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse_roundings import LAST_GYBE_OFF_DEG, rounding  # noqa: E402
from read_gpx_race import heading_change  # noqa: E402

MS_TO_KT = 1.0 / 0.514444
SIDES = {1: 'port', 2: 'starboard'}


def option(name, default=None):
    for arg in sys.argv[1:]:
        if arg.startswith('--' + name + '='):
            return arg.split('=', 1)[1]
    return default


def compass(vx, vz):
    """A direction in game coordinates (x east, z south) as a compass bearing."""
    return math.degrees(math.atan2(vx, -vz)) % 360.0


def read_board(path):
    """A board's track. A line that cannot be read (two writes run together in a few files) is left out."""
    track = []
    for row in csv.DictReader(open(path, encoding='utf-8', errors='replace')):
        try:
            point = {'t': float(row['race_time_s']), 'x': float(row['x_m']), 'y': -float(row['z_m']),
                     'kt': float(row['speed_ms']) * MS_TO_KT, 'course': float(row['heading_deg']),
                     'next_step': int(row['next_step']), 'doing': row['doing'] or ''}
        except (TypeError, ValueError):
            continue
        if track and point['t'] <= track[-1]['t']:
            continue
        track.append(point)
    return track


def read_race(run_dir, label):
    log_path = os.path.join(run_dir, 'logs', label + '.log')
    if not os.path.exists(log_path):
        return None
    log = open(log_path, encoding='utf-8', errors='replace').read()
    course_m = re.search(r'COURSE_JSON (\{.*\})', log)
    wind_m = re.search(r'wind ([\d.]+) kt from ([\d.]+) deg', log)
    if not course_m:
        return None
    course = json.loads(course_m.group(1))
    boards = {}
    for path in sorted(glob.glob(os.path.join(run_dir, label, '*.csv'))):
        boards[os.path.splitext(os.path.basename(path))[0]] = read_board(path)
    results = [json.loads(m) for m in re.findall(r'HEADS_RESULT (\{.*\})', log)]
    return {'label': label, 'course': course, 'boards': boards, 'results': results,
            'wind_kt': float(wind_m.group(1)) if wind_m else float('nan'),
            'wind_from': float(wind_m.group(2)) if wind_m else float('nan')}


def races(run_dirs):
    for run_dir in run_dirs:
        for d in sorted(glob.glob(os.path.join(run_dir, 'r[0-9][0-9][0-9][0-9]'))):
            race = read_race(run_dir, os.path.basename(d))
            if race and race['boards']:
                race['run'] = os.path.basename(run_dir.rstrip('/\\'))
                yield race


def measure_roundings(race):
    rows = []
    steps = race['course']['steps']
    for k, step in enumerate(steps):
        if step['kind'] != 'MARK' or step.get('side') not in SIDES:
            continue
        turn = heading_change(compass(*step['in']), compass(*step['out']))
        mx, mz = step['points'][0]
        mark = {'x': mx, 'y': -mz, 'rounding': SIDES[step['side']]}
        for board, track in race['boards'].items():
            heading_for = [i for i, p in enumerate(track) if p['next_step'] == k]
            if not heading_for:
                continue
            after = [i for i, p in enumerate(track) if p['next_step'] > k]
            if not after:
                continue  # never rounded it (the race or the drill ended first)
            i_from = heading_for[0]
            t_end = track[after[0]]['t'] + 30.0
            i_to = max(i for i, p in enumerate(track) if p['t'] <= t_end)
            if i_to - i_from < 20:
                continue
            rd = rounding(track, mark, turn, i_from, i_to)
            situation = 'small (under 100)' if abs(turn) < 100 else ('full (130+)' if abs(turn) >= 130 else 'middle (100-130)')
            next_doing = track[min(len(track) - 1, after[0] + 50)]['doing']
            # How the board came in: its angle to the wind 10 s before the mark (a beat into a top mark, or a
            # reach or run into a gybe mark: the real race's mark C is a reach into a full gybe).
            before = track[max(i_from, rd['i_closest'] - 100)]
            twa_in = abs(heading_change(race['wind_from'], before['course'])) if math.isfinite(race['wind_from']) else float('nan')
            approach = 'beat' if twa_in < 70 else ('reach' if twa_in < 140 else 'run')
            rows.append({'run': race['run'], 'race': race['label'], 'board': board, 'mark': step['name'],
                         'course_turn': turn, 'situation': situation, 'approach': approach, 'twa_in': twa_in,
                         'wind_kt': race['wind_kt'], 'next_doing': next_doing.split(' (')[0],
                         **{k2: v for k2, v in rd.items() if k2 != 'i_closest'}})
    return rows


def measure_legs(race):
    """Per downwind leg (the leg's bearing at least 140 deg off the wind): how the board sails it. The board's angle to
    the wind (TWA, 0 = head to wind, 180 = dead downwind) while it sails the leg faster than 5 kt, its gybes (turns of
    more than 60 deg in 15 s), and the distance sailed against the straight line."""
    rows = []
    steps = race['course']['steps']
    points = []
    for step in steps:
        x, z = step['points'][0] if len(step['points']) == 1 else (
            (step['points'][0][0] + step['points'][1][0]) / 2, (step['points'][0][1] + step['points'][1][1]) / 2)
        points.append((x, -z))
    wind = race['wind_from']
    if not math.isfinite(wind):
        return rows
    for k in range(1, len(steps)):
        (ax, ay), (bx, by) = points[k - 1], points[k]
        leg_bearing = math.degrees(math.atan2(bx - ax, by - ay)) % 360.0
        leg_twa = abs(heading_change(wind, leg_bearing))
        if leg_twa < 140.0:
            continue
        straight = math.hypot(bx - ax, by - ay)
        for board, track in race['boards'].items():
            leg = [p for p in track if p['next_step'] == k]
            if len(leg) < 50 or not any(p['next_step'] > k for p in track):
                continue
            twas = [abs(heading_change(wind, p['course'])) for p in leg if p['kt'] > 5.0]
            sailed = sum(math.hypot(b['x'] - a['x'], b['y'] - a['y']) for a, b in zip(leg, leg[1:]))
            gybes, i = 0, 0
            while i < len(leg) - 1:
                j = i
                while j + 1 < len(leg) and leg[j + 1]['t'] - leg[i]['t'] <= 15.0:
                    j += 1
                turned = sum(heading_change(a['course'], b['course']) for a, b in zip(leg[i:j], leg[i + 1:j + 1]))
                if abs(turned) > 60.0:
                    gybes += 1
                    i = j + 1
                else:
                    i += 1
            rows.append({'run': race['run'], 'race': race['label'], 'board': board, 'leg': k, 'leg_twa': leg_twa,
                         'straight_m': straight, 'sailed_share': sailed / straight if straight else float('nan'),
                         'twa_median': statistics.median(twas) if twas else float('nan'),
                         'twa_share_over_160': sum(1 for t in twas if t > 160.0) / len(twas) if twas else float('nan'),
                         'gybes': gybes, 'gybes_per_km': gybes / (straight / 1000.0) if straight else float('nan'),
                         'leg_s': leg[-1]['t'] - leg[0]['t'], 'wind_kt': race['wind_kt'], 'group': 'downwind legs'})
    return rows


def measure_starts(race):
    steps = race['course']['steps']
    start = next(s for s in steps if s['kind'] == 'START')
    (ax, az), (bx, bz) = start['points']
    a, b = (ax, -az), (bx, -bz)
    first_mark = next(s for s in steps if s['kind'] in ('MARK', 'GATE'))
    mx, mz = first_mark['points'][0]
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    toward = math.degrees(math.atan2(mx - mid[0], -mz - mid[1])) % 360.0
    nx, ny = math.sin(math.radians(toward)), math.cos(math.radians(toward))

    def side(p):
        return (b[0] - a[0]) * (p['y'] - a[1]) - (b[1] - a[1]) * (p['x'] - a[0])

    def past(p):
        return (p['x'] - mid[0]) * nx + (p['y'] - mid[1]) * ny

    crossings = {}
    for board, track in race['boards'].items():
        for p, q in zip(track, track[1:]):
            if q['t'] >= -30 and side(p) * side(q) < 0 and abs(heading_change(toward, q['course'])) < 60 and past(q) > past(p):
                crossings[board] = (q['t'], q['kt'], track.index(q))
                break
    if not crossings:
        return []
    first = min(c[0] for c in crossings.values())
    rows = []
    for board, (t_c, kt_c, i_c) in crossings.items():
        track = race['boards'][board]
        at = lambda t: min(track, key=lambda p: abs(p['t'] - t))
        before = [p for p in track if t_c - 150 <= p['t'] <= t_c]
        off = [p for p in before if abs(heading_change(toward, p['course'])) > LAST_GYBE_OFF_DEG]
        last = max(off, key=lambda p: p['t']) if off else None
        top = max([p['kt'] for p in track if t_c <= p['t'] <= t_c + 30] or [kt_c])
        rows.append({'run': race['run'], 'race': race['label'], 'board': board, 'boards': len(race['boards']),
                     'over_after_gun_s': t_c, 'over_after_first_s': t_c - first, 'kt_over': kt_c,
                     'share_of_top': kt_c / top if top else float('nan'),
                     'behind_m_10s': -past(at(-10.0)), 'behind_m_5s': -past(at(-5.0)),
                     'last_gybe_s': t_c - last['t'] if last else float('nan'),
                     'last_gybe_m': -past(last) if last else float('nan'),
                     'past_m_30s': past(at(30.0)), 'wind_kt': race['wind_kt']})
    return rows


def summary(rows, keys, group):
    groups = {}
    for r in rows:
        groups.setdefault(r[group], []).append(r)
    for name, rs in sorted(groups.items()):
        print(f'\n  {group} = {name}: {len(rs)}')
        for key in keys:
            vals = sorted(v for v in (r[key] for r in rs) if isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v))
            if not vals:
                continue
            q = lambda f: vals[min(len(vals) - 1, int(f * len(vals)))]
            print(f'    {key:22s} median {statistics.median(vals):8.2f}   middle half {q(0.25):8.2f} to {q(0.75):8.2f}   (n {len(vals)})')
        for key in ('rounded', 'side_ok'):
            if key in rs[0]:
                print(f'    {key:22s} {sum(1 for r in rs if r[key])} of {len(rs)}')


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith('--')]
    what = option('what', 'roundings')
    rows = []
    measure = {'roundings': measure_roundings, 'starts': measure_starts, 'legs': measure_legs}[what]
    for race in races(dirs):
        rows += measure(race)
    print(f'{len(rows)} {what} measured in {", ".join(os.path.basename(d.rstrip("/")) for d in dirs)}')
    if what == 'legs':
        summary(rows, ['leg_twa', 'twa_median', 'twa_share_over_160', 'gybes', 'gybes_per_km', 'sailed_share', 'leg_s'], 'group')
    elif what == 'roundings':
        summary(rows, ['closest_m', 'closest_r', 'start_s', 'start_r', 'exit_s', 'exit_r', 'apex_share', 'extra_turn_deg',
                       'radius_m', 'turn_s', 'kept', 'kt_in'], 'situation')
    else:
        summary(rows, ['over_after_gun_s', 'over_after_first_s', 'kt_over', 'share_of_top', 'behind_m_10s', 'behind_m_5s',
                       'last_gybe_s', 'last_gybe_m', 'past_m_30s'], 'boards')
    out = option('csv')
    if out and rows:
        fields = list(rows[0].keys())
        with open(out, 'w', newline='', encoding='utf-8') as f:
            w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
            w.writeheader()
            for r in rows:
                w.writerow({k: (round(v, 3) if isinstance(v, float) else v) for k, v in r.items()})
        print(f'\nCSV: {out}')


if __name__ == '__main__':
    main()
