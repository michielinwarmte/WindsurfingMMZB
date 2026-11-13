"""Fetch the riders of every men's race of a Metasail event, and build the GPX export links.

Usage: python -I tools/real_races/men_athletes.py <races.json> <men_races.json>
Asks the website's own rider list (the Export button's) once per race, half a second apart.
Writes the riders (name, tracker id, the tracker's place; 0 = no tracked finish) and the GPX links,
at most 10 boards per link as on the website. The links themselves were refused by the server
("400 Bad Request") on 13 November 2026: see the report.
The output holds junior riders' names: keep it in .sim_output/ (ignored by git), never in git or Game/.
Report: Documentation/reports/real_races/metasail_event930.md
"""
import json, sys, time, urllib.request, urllib.parse

races = json.load(open(sys.argv[1]))
out = sys.argv[2]
men = [r for r in races if ' Men' in r['name']]
for i, r in enumerate(men):
    data = urllib.parse.urlencode({'action': 'get_athletes_list', 'eventId': r['id']}).encode()
    try:
        with urllib.request.urlopen('https://www.metasail.com/wp-admin/admin-ajax.php', data, timeout=30) as f:
            j = json.load(f)
        r['athletes'] = j.get('data') if j.get('success') else []
        if not j.get('success'):
            r['error'] = str(j.get('data'))
    except Exception as e:
        r['athletes'] = []
        r['error'] = repr(e)
    ath = r['athletes'] or []
    ser = [a['Seriale'] for a in sorted(ath, key=lambda a: (a.get('Ranking') or 999))]
    r['gpx_urls'] = []
    for k in range(0, len(ser), 10):
        q = [('idg', r['id'])] + [('s%d' % n, s) for n, s in enumerate(ser[k:k + 10])]
        r['gpx_urls'].append('https://app.metasail.it/Export/DownloadGpx.ashx?' + urllib.parse.urlencode(q))
    print(i + 1, r['id'], len(ath), r['name'], r.get('error', ''), flush=True)
    time.sleep(0.5)
json.dump(men, open(out, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
