"""Write a snippet that downloads every GPX file of an event in your own browser, in one go.

Usage: python -I tools/real_races/make_browser_download.py <men_races.json> <snippet.js> [--every_s=3]

Why: the GPX export refuses scripts ("400 Bad Request"), and clicking Export 130 times by hand is too much.
The snippet does in the browser exactly what the website's Export button does (its own code builds a link
to app.metasail.it/Export/DownloadGpx.ashx and clicks it), once per file, a few seconds apart.

How to use it (Max):
  1. Open https://www.metasail.com/past/602/ in Chrome or Edge.
  2. Press F12, open the Console tab. (The first time, Chrome asks you to type "allow pasting".)
  3. Paste the snippet, press Enter. Allow "download multiple files" when the browser asks.
  4. The files land in your Downloads folder; the console counts along. If the page turns into
     "Bad Request", the export refused that file and the snippet stops there.
Report: Documentation/reports/real_races/metasail_event930.md (section 6)
"""
import json
import sys


def option(name, default):
    for arg in sys.argv[3:]:
        if arg.startswith('--' + name + '='):
            return arg.split('=', 1)[1]
    return default


def plain_name(name):
    """True when the name fits in Latin-1. Metasail's GPX export is a ZIP with one file per rider, named after the
    rider; on 13 November 2026 a file holding a rider with a letter outside Latin-1 (the Turkish S with a cedilla)
    answered "Bad Request" while the same kind of file without one downloaded fine. Such riders are left out
    (13 of 198 at event 930, 4 of 101 at event 602) until Metasail fixes it."""
    try:
        name.encode('latin-1')
        return True
    except UnicodeEncodeError:
        return False


def links_for(race):
    """The race's export links, at most 10 riders each (the website's limit), only riders with a plain name."""
    riders = sorted(race['athletes'], key=lambda a: (a.get('Ranking') or 999))
    ids = [a['Seriale'] for a in riders if plain_name(a['Nome'])]
    links = []
    for k in range(0, len(ids), 10):
        query = '&'.join([f"idg={race['id']}"] + [f"s{n}={s}" for n, s in enumerate(ids[k:k + 10])])
        links.append('https://app.metasail.it/Export/DownloadGpx.ashx?' + query)
    return links


races = json.load(open(sys.argv[1], encoding='utf-8'))
every_ms = int(float(option('every_s', '3')) * 1000)
links = [url for race in sorted(races, key=lambda r: r['start']) for url in links_for(race)]
left_out = {a['Seriale'] for race in races for a in race['athletes'] if not plain_name(a['Nome'])}
print(f"riders left out (a letter outside Latin-1 in the name): {len(left_out)}")

snippet = f"""// Metasail GPX download: {len(links)} files, one every {every_ms / 1000:g} s (about {len(links) * every_ms / 60000:.0f} minutes).
// Does what the Export button's "Download GPX" does, once per file. Made by tools/real_races/make_browser_download.py.
(async () => {{
  const links = {json.dumps(links, indent=1)};
  for (let i = 0; i < links.length; i++) {{
    const a = document.createElement('a');
    a.href = links[i];
    document.body.appendChild(a);
    a.click();
    a.remove();
    console.log(`GPX ${{i + 1}} of ${{links.length}}`);
    await new Promise(done => setTimeout(done, {every_ms}));
  }}
  console.log('All GPX files asked for. Tell Claude they are in the Downloads folder.');
}})();
"""
open(sys.argv[2], 'w', encoding='utf-8').write(snippet)
print(f"{len(links)} files, about {len(links) * every_ms / 60000:.0f} minutes: {sys.argv[2]}")
