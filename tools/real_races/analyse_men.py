"""Offline analysis of Metasail event 930's men's races (rider lists with the tracker's ranking).

Usage: python -I tools/real_races/analyse_men.py .sim_output/real_races/metasail_930/men_races930.json
Reads the file made by men_athletes.py. No network. Prints plain numbers only (no names).
Ranking 0 = the tracker logged no finish (DNF, OCS, DNS, a recall, or a tracker gap).
Report: Documentation/reports/real_races/metasail_event930.md
"""
import json, sys, re, statistics, collections, random

men = json.load(open(sys.argv[1], encoding='utf-8'))


def division(name):
    return 'U17' if 'Under 17' in name else 'U19'


def kind(name):
    if 'General recall' in name:
        return 'recall'
    if 'Aband' in name or 'Abband' in name:
        return 'abandoned'
    return 'race'


def stage(name):
    if 'FINAL' in name:
        return 'final series'
    if 'Gold' in name and 'Heat' in name:
        return 'gold heats (30 Oct)'
    if 'Silver' in name and 'Heat' in name:
        return 'silver heats (30 Oct)'
    if 'Gold' in name:
        return 'gold fleet (28 Oct)'
    if 'Silver' in name:
        return 'silver fleet (28 Oct)'
    return 'qualifying heats (25+27 Oct)'


for r in men:
    r['div'] = division(r['name'])
    r['kind'] = kind(r['name'])
    r['stage'] = stage(r['name'])
    r['n'] = len(r['athletes'])
    r['ranked'] = sum(1 for a in r['athletes'] if a['Ranking'])

print('== 1. The format: entries per division and stage ==')
for div in ['U19', 'U17']:
    for st in ['qualifying heats (25+27 Oct)', 'gold fleet (28 Oct)', 'silver fleet (28 Oct)',
               'gold heats (30 Oct)', 'silver heats (30 Oct)', 'final series']:
        rs = [r for r in men if r['div'] == div and r['stage'] == st]
        if not rs:
            continue
        c = collections.Counter(r['kind'] for r in rs)
        sizes = sorted(collections.Counter(r['n'] for r in rs).items())
        print(f"{div} {st:30s} entries {len(rs):3d}  races {c['race']:2d} recalls {c['recall']} abandoned {c['abandoned']}  fleet sizes {sizes}")

print()
print('== 2. Starts and recalls per division ==')
for div in ['U19', 'U17']:
    rs = [r for r in men if r['div'] == div]
    c = collections.Counter(r['kind'] for r in rs)
    starts = len(rs)
    print(f"{div}: {starts} starts recorded, {c['recall']} labelled general recalls ({100*c['recall']/starts:.0f} %), {c['abandoned']} abandoned")
    per_day = collections.Counter((r['date'], r['kind']) for r in rs)
    for d in sorted({r['date'] for r in rs}):
        print(f"   {d}: races {per_day[(d,'race')]}, recalls {per_day[(d,'recall')]}, abandoned {per_day[(d,'abandoned')]}")

# Valid races: real races (not recall/abandoned) where at least half the fleet has a tracked finish.
valid = [r for r in men if r['kind'] == 'race' and r['ranked'] >= r['n'] / 2 and r['n'] >= 10]
empty = [r for r in men if r['kind'] == 'race' and r['ranked'] < r['n'] / 2]
print()
print('== 3. Tracked finishes ==')
print(f"races labelled as races: {sum(1 for r in men if r['kind']=='race')}; with fewer than half the fleet ranked (left out): {len(empty)}")
for r in empty:
    print(f"   left out: {r['id']} {r['name']} ({r['ranked']} of {r['n']} ranked)")
for st in ['qualifying heats (25+27 Oct)', 'gold fleet (28 Oct)', 'silver fleet (28 Oct)', 'gold heats (30 Oct)', 'silver heats (30 Oct)']:
    rs = [r for r in valid if r['stage'] == st]
    if not rs:
        continue
    share = [1 - r['ranked'] / r['n'] for r in rs]
    print(f"   {st:30s} {len(rs):2d} races: boards without a tracked finish, median {100*statistics.median(share):.0f} %, range {100*min(share):.0f} to {100*max(share):.0f} %")

print()
print('== 4. How much of a place is the rider, how much the race ==')
# Normalised place: 0 = winner, 1 = last tracked finisher. Only tracked finishers.
def places(rs):
    by_rider = collections.defaultdict(list)
    for r in rs:
        fin = [a for a in r['athletes'] if a['Ranking']]
        m = max(a['Ranking'] for a in fin)
        if m < 2:
            continue
        for a in fin:
            by_rider[a['Seriale']].append((a['Ranking'] - 1) / (m - 1))
    return by_rider


def icc(by_rider, min_races=3):
    """Share of the variance of the normalised place that is between riders (one-way ICC, unequal group sizes)."""
    groups = [v for v in by_rider.values() if len(v) >= min_races]
    allv = [x for g in groups for x in g]
    grand = statistics.mean(allv)
    k = len(groups)
    N = len(allv)
    ssb = sum(len(g) * (statistics.mean(g) - grand) ** 2 for g in groups)
    ssw = sum(sum((x - statistics.mean(g)) ** 2 for x in g) for g in groups)
    msb = ssb / (k - 1)
    msw = ssw / (N - k)
    n0 = (N - sum(len(g) ** 2 for g in groups) / N) / (k - 1)
    return (msb - msw) / (msb + (n0 - 1) * msw), k, N


def split_half(by_rider, min_races=4):
    """Correlation between a rider's mean place in odd and even races (Spearman by ranks)."""
    pairs = [(statistics.mean(v[0::2]), statistics.mean(v[1::2])) for v in by_rider.values() if len(v) >= min_races]
    def ranks(xs):
        order = sorted(range(len(xs)), key=lambda i: xs[i])
        rk = [0] * len(xs)
        for pos, i in enumerate(order):
            rk[i] = pos
        return rk
    a = ranks([p[0] for p in pairs])
    b = ranks([p[1] for p in pairs])
    return statistics.correlation(a, b), len(pairs)


def sd_within(by_rider, min_races=3):
    return statistics.median(statistics.pstdev(v) for v in by_rider.values() if len(v) >= min_races)


for div in ['U19', 'U17']:
    for label, sts in [('qualifying heats', ['qualifying heats (25+27 Oct)']),
                       ('gold (fleet + heats)', ['gold fleet (28 Oct)', 'gold heats (30 Oct)']),
                       ('silver (fleet + heats)', ['silver fleet (28 Oct)', 'silver heats (30 Oct)'])]:
        rs = [r for r in valid if r['div'] == div and r['stage'] in sts]
        if len(rs) < 3:
            continue
        br = places(rs)
        ic, k, N = icc(br)
        sh, npairs = split_half(br)
        print(f"{div} {label:24s} {len(rs):2d} races, {k} riders with 3+ races: rider share of the spread (ICC) {ic:.2f}; "
              f"odd vs even races rank correlation {sh:.2f} ({npairs} riders); a rider's own spread of place (median SD) {sd_within(br):.2f} of the fleet")

print()
print('== 5. Winners ==')
for div in ['U19', 'U17']:
    for label, sts in [('qualifying heats', ['qualifying heats (25+27 Oct)']),
                       ('gold (fleet + heats)', ['gold fleet (28 Oct)', 'gold heats (30 Oct)'])]:
        rs = [r for r in valid if r['div'] == div and r['stage'] in sts]
        br = places(rs)
        winners = [next(a['Seriale'] for a in r['athletes'] if a['Ranking'] == 1) for r in rs if any(a['Ranking'] == 1 for a in r['athletes'])]
        c = collections.Counter(winners)
        # Leave-one-out: where does a race's winner stand by mean place in the other races of the stage?
        pct = []
        for r in rs:
            w = [a['Seriale'] for a in r['athletes'] if a['Ranking'] == 1]
            if not w:
                continue
            others = places([x for x in rs if x is not r])
            means = {s: statistics.mean(v) for s, v in others.items() if len(v) >= 2}
            if w[0] not in means:
                continue
            fleet = [means[a['Seriale']] for a in r['athletes'] if a['Seriale'] in means]
            better = sum(1 for m in fleet if m < means[w[0]])
            pct.append(better / max(1, len(fleet) - 1))
        top = sum(1 for p in pct if p <= 0.10)
        print(f"{div} {label:24s} {len(winners)} wins by {len(c)} different riders (most wins by one rider: {max(c.values())}); "
              f"winner among its fleet's best 10 % on the other races: {top} of {len(pct)}; median standing of a winner {100*statistics.median(pct):.0f} % from the top")

print()
print('== 6. When Metasail opened each race (not the gun): the cycle on the fleet days ==')
for div in ['U19', 'U17']:
    for st in ['gold fleet (28 Oct)', 'silver fleet (28 Oct)']:
        rs = sorted([r for r in men if r['div'] == div and r['stage'] == st], key=lambda r: r['start'])
        t = [int(r['start'][11:13]) * 60 + int(r['start'][14:16]) for r in rs]
        gaps = [b - a for a, b in zip(t, t[1:])]
        print(f"{div} {st:22s} {[r['start'][11:16] for r in rs]} gaps (min) {gaps}")
