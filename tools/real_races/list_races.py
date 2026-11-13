"""List every race of a Metasail event from its saved race page (no network).

Usage: python -I tools/real_races/list_races.py <event.html> <races.json>
The page is www.metasail.com/wp-content/themes/metasail/ajax/event.php?id=<event>, saved by hand or with curl.
Writes one entry per race: its Metasail id, the day, when Metasail opened it (not the gun) and its name.
Report: Documentation/reports/real_races/metasail_event930.md
"""
import re, sys, json, html
src = open(sys.argv[1], encoding='utf-8').read()
races = []
date = None
for m in re.finditer(r'<h4>(\d\d/\d\d/\d{4})</h4>|ViewRecordedRace2018\.aspx\?idgara=(\d+)[^"]*"[^>]*>\s*<strong>([^<]*)</strong>|data-id="(\d+)" data-start-at="([^"]*)"', src):
    if m.group(1): date = m.group(1)
    elif m.group(2): races.append({'id': int(m.group(2)), 'name': html.unescape(m.group(3)).strip(), 'date': date})
    elif m.group(4):
        for r in races[::-1]:
            if r['id'] == int(m.group(4)): r['start'] = m.group(5); break
json.dump(races, open(sys.argv[2], 'w'), indent=1)
men = [r for r in races if ' Men' in r['name']]
print(len(races), 'races,', len(men), 'men')
for r in races: print(r['id'], r['date'], r.get('start','-'), r['name'])
