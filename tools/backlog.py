#!/usr/bin/env python3
"""The 1.0 backlog: the counts in the terminal, and the dashboard page.

Run from the repository root:
  python -I tools/backlog.py                      the progress per epic, printed
  python -I tools/backlog.py --epic=E04 --status=doing --milestone=M10 --owner=Max   filtered
  python -I tools/backlog.py --html               writes Documentation/backlog/dashboard.html
  python -I tools/backlog.py --html=some/path.html

It reads every `Documentation/backlog/epics/E*.md`, finds the stories (a `### E04.S02 · Title` heading
followed by its `Status: ... | Size: ... | ...` line), their tasks (`- [ ]` / `- [x]` lines), the `Done when:`
and `Notes:` lines, the epic's Goal, Done when and Where things stand paragraphs, the milestone names in
`1.0.md` and the sprint in `BOARD.md`. It complains about a story line it cannot read, so a session sees at
once when it broke the layout. The dashboard is one self-contained HTML file (the data inside it as JSON):
open it from the folder, or the lead publishes it as the team's private page after each session.
"""
import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKLOG_DIR = ROOT / "Documentation" / "backlog"
EPICS_DIR = BACKLOG_DIR / "epics"

STATUSES = ["todo", "next", "doing", "review", "done", "blocked", "dropped"]
STORY_RE = re.compile(r"^### (E\d{2})\.(S\d{2})\s*[·\-:]\s*(.+?)\s*$")
EPIC_RE = re.compile(r"^# (E\d{2})\s*[·\-:]\s*(.+?)\s*$")
FIELD_RE = re.compile(r"(\w+):\s*([^|]*)")
TASK_RE = re.compile(r"^\s*- \[([ xX])\]\s*(.*)$")
PARA_RE = re.compile(r"^\*\*(Goal|Done when[^*]*|Where things stand[^*]*)\.\*\*\s*(.*)$")


def parse_epic(path: Path) -> dict:
    """One epic file -> its name, its paragraphs and its stories with their fields, tasks and texts."""
    epic = {"id": path.stem[:3], "title": path.stem, "goal": "", "done_when": "", "where": "",
            "stories": [], "problems": []}
    story = None
    in_stories = False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.rstrip()
        epic_match = EPIC_RE.match(line)
        if epic_match:
            epic["id"], epic["title"] = epic_match.group(1), epic_match.group(2)
            continue
        para = PARA_RE.match(line)
        if para and not in_stories:
            key = para.group(1).lower()
            if key.startswith("goal"):
                epic["goal"] = para.group(2)
            elif key.startswith("done when"):
                epic["done_when"] = para.group(2)
            elif key.startswith("where"):
                epic["where"] = para.group(2)
            continue
        if line.startswith("## "):
            in_stories = line.strip() == "## Stories"
            story = None
            continue
        story_match = STORY_RE.match(line)
        if story_match:
            story = {
                "id": f"{story_match.group(1)}.{story_match.group(2)}",
                "title": story_match.group(3),
                "fields": {},
                "done_when": "",
                "notes": "",
                "tasks": [],
                "line": number,
            }
            epic["stories"].append(story)
            continue
        if line.startswith("### "):
            epic["problems"].append(f"{path.name}:{number}: a story heading I cannot read: {line}")
            story = None
            continue
        if story is None:
            continue
        if line.startswith("Status:"):
            for key, value in FIELD_RE.findall(line):
                story["fields"][key.lower()] = value.strip()
            status = story["fields"].get("status", "")
            if status not in STATUSES:
                epic["problems"].append(
                    f"{path.name}:{number}: {story['id']} has the status '{status}'; use one of {', '.join(STATUSES)}"
                )
            continue
        if line.startswith("Done when"):
            story["done_when"] = line.split(":", 1)[1].strip() if ":" in line else line
            continue
        if line.startswith("Notes:"):
            story["notes"] = line[len("Notes:"):].strip()
            continue
        task_match = TASK_RE.match(line)
        if task_match:
            story["tasks"].append({"text": task_match.group(2).strip(), "done": task_match.group(1).lower() == "x"})
    for story in epic["stories"]:
        if "status" not in story["fields"]:
            epic["problems"].append(f"{path.name}:{story['line']}: {story['id']} has no 'Status:' line under its heading")
    return epic


def read_milestones() -> dict:
    """The milestone names from 1.0.md's table: | **M1 The sailor** | ... |"""
    names = {}
    path = BACKLOG_DIR / "1.0.md"
    if path.is_file():
        for m in re.finditer(r"\|\s*\*\*(M\d+) ([^*|]+?)\*\*\s*\|", path.read_text(encoding="utf-8")):
            names[m.group(1)] = m.group(2).strip()
    return names


def read_sprint() -> dict:
    """The current sprint from BOARD.md: its heading, its goal line and the items of each '### ' part."""
    sprint = {"title": "", "goal": "", "sections": []}
    path = BACKLOG_DIR / "BOARD.md"
    if not path.is_file():
        return sprint
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((i for i, l in enumerate(lines) if l.startswith("## Sprint")), None)
    if start is None:
        return sprint
    sprint["title"] = lines[start][3:].strip()
    section = None
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        if line.startswith("**Sprint goal:**"):
            sprint["goal"] = line.replace("**Sprint goal:**", "").strip()
            continue
        if line.startswith("### "):
            section = {"name": line[4:].strip(), "items": []}
            sprint["sections"].append(section)
            continue
        item = re.match(r"^\s*(?:-|\d+\.)\s+(.*)$", line)
        if item and section is not None:
            section["items"].append(item.group(1).strip())
    return sprint


def git_commit() -> str:
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def wanted(story: dict, filters: dict) -> bool:
    for key, value in filters.items():
        if value and value.lower() not in story["fields"].get(key, "").lower():
            return False
    return True


def load_all() -> tuple[list, list]:
    epics, problems = [], []
    for path in sorted(EPICS_DIR.glob("E*.md")):
        epic = parse_epic(path)
        problems.extend(epic["problems"])
        epics.append(epic)
    return epics, problems


def print_report(epics: list, problems: list, filters: dict, only_epic: str) -> int:
    totals = {status: 0 for status in STATUSES}
    tasks_done = tasks_all = 0
    for epic in epics:
        if only_epic and epic["id"] != only_epic:
            continue
        stories = [s for s in epic["stories"] if wanted(s, filters)]
        if not stories:
            continue
        for story in stories:
            status = story["fields"].get("status", "todo")
            totals[status] = totals.get(status, 0) + 1
            tasks_done += sum(1 for t in story["tasks"] if t["done"])
            tasks_all += len(story["tasks"])
        live = [s for s in stories if s["fields"].get("status") != "dropped"]
        done = sum(1 for s in live if s["fields"].get("status") == "done")
        share = f"{100 * done // len(live)} %" if live else "-"
        print(f"\n{epic['id']} {epic['title']}  [{done}/{len(live)} stories done, {share}]")
        for story in stories:
            f = story["fields"]
            t_done = sum(1 for t in story["tasks"] if t["done"])
            tasks = f"{t_done}/{len(story['tasks'])}" if story["tasks"] else "-"
            print(
                f"  {story['id']}  {f.get('status', '?'):8} {f.get('size', '?'):3} {f.get('milestone', '?'):5} "
                f"tasks {tasks:6} {story['title']}"
            )
    live_total = sum(v for k, v in totals.items() if k != "dropped")
    print("\nAll epics:", ", ".join(f"{k} {v}" for k, v in totals.items() if v), f"| stories {live_total}",
          f"| tasks {tasks_done}/{tasks_all}")
    if problems:
        print("\nProblems in the files:")
        for problem in problems:
            print("  " + problem)
        return 2
    return 0


def build_data(epics: list) -> dict:
    data = {
        "generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "commit": git_commit(),
        "milestones": read_milestones(),
        "sprint": read_sprint(),
        "epics": [],
    }
    for epic in epics:
        stories = []
        for s in epic["stories"]:
            f = s["fields"]
            stories.append({
                "id": s["id"], "title": s["title"], "status": f.get("status", "todo"), "size": f.get("size", ""),
                "owner": f.get("owner", ""), "milestone": f.get("milestone", ""), "needs": f.get("needs", ""),
                "roadmap": f.get("roadmap", ""), "done_when": s["done_when"], "notes": s["notes"], "tasks": s["tasks"],
            })
        data["epics"].append({"id": epic["id"], "title": epic["title"], "goal": epic["goal"],
                              "done_when": epic["done_when"], "where": epic["where"], "stories": stories})
    return data


def write_html(epics: list, out: Path) -> None:
    data = build_data(epics)
    payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    html = TEMPLATE.replace("__DATA__", payload)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} kB; {len(data['epics'])} epics, "
          f"{sum(len(e['stories']) for e in data['epics'])} stories)")


# The page. One file, no libraries; the data is the JSON in #data. Layout: a one-column page of sections,
# the summary before the detail: the headline bars, who is waited on, the sprint, the milestones, the epic
# cards (click one for its stories), then every story with filters.
TEMPLATE = r"""<title>Road to 1.0</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700&display=swap">
<style>
/* Layout: one column, the summary first; the race-board vocabulary of the game (marks, the fleet) in the
   milestones and the status chips. Colours as tokens, light first, dark below. */
:root {
  --bg: #f4f6f3; --surface: #fcfcfb; --surface-2: #eef1ec; --fg: #0f1512; --fg-2: #4d5650; --muted: #8a918c;
  --line: #dde2dc; --accent: #1c5cab; --accent-soft: #cde2fb; --fill: #2a78d6; --fill-track: #e1e5df;
  --good: #0ca30c; --warn: #fab219; --crit: #d03b3b; --buoy: #eb6834; --on-fill: #ffffff;
  --display: "Barlow Condensed", "Arial Narrow", "Roboto Condensed", sans-serif;
  --body: system-ui, -apple-system, "Segoe UI", sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0f1311; --surface: #1a1f1c; --surface-2: #222826; --fg: #eef0ec; --fg-2: #bfc5be; --muted: #8a918c;
    --line: #2e3531; --accent: #6da7ec; --accent-soft: #1c3a5c; --fill: #3987e5; --fill-track: #2a302d;
    --good: #0ca30c; --warn: #fab219; --crit: #e66767; --buoy: #f0774a; --on-fill: #ffffff; color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0f1311; --surface: #1a1f1c; --surface-2: #222826; --fg: #eef0ec; --fg-2: #bfc5be; --muted: #8a918c;
  --line: #2e3531; --accent: #6da7ec; --accent-soft: #1c3a5c; --fill: #3987e5; --fill-track: #2a302d;
  --good: #0ca30c; --warn: #fab219; --crit: #e66767; --buoy: #f0774a; --on-fill: #ffffff; color-scheme: dark;
}
* { box-sizing: border-box; }
body { background: var(--bg); color: var(--fg); font-family: var(--body); font-size: 14px; line-height: 1.45;
  padding-block: 20px 48px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.wrap { max-width: 1180px; margin: 0 auto; display: grid; gap: 28px; }
h1, h2, h3 { font-family: var(--display); font-weight: 600; letter-spacing: 0.01em; margin: 0; text-wrap: balance; }
h1 { font-size: 40px; line-height: 1; }
h2 { font-size: 24px; line-height: 1.1; }
h3 { font-size: 18px; }
p { margin: 0; }
a { color: var(--accent); }
code { font-family: ui-monospace, Consolas, monospace; font-size: 12.5px; background: var(--surface-2); padding: 1px 4px; border-radius: 3px; }
.eyebrow { font-size: 11.5px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); font-weight: 600; }
.sub { color: var(--fg-2); }
.num { font-variant-numeric: tabular-nums; }
header { display: grid; gap: 14px; }
.headline { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 14px; }
.tile { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px; display: grid; gap: 8px; min-width: 0; }
.tile .big { font-family: var(--display); font-size: 34px; line-height: 1; font-weight: 600; }
.bar { height: 8px; background: var(--fill-track); border-radius: 4px; overflow: hidden; }
.bar > i { display: block; height: 100%; background: var(--fill); border-radius: 4px; min-width: 0; }
.bar.good > i { background: var(--good); }
.chip { display: inline-flex; align-items: center; gap: 4px; padding: 1px 8px; border-radius: 999px; font-size: 12px; font-weight: 600;
  border: 1px solid var(--line); background: var(--surface-2); color: var(--fg-2); white-space: nowrap; }
.chip.done { background: var(--good); border-color: var(--good); color: var(--on-fill); }
.chip.review { background: var(--warn); border-color: var(--warn); color: #0b0b0b; }
.chip.blocked { background: var(--crit); border-color: var(--crit); color: var(--on-fill); }
.chip.doing { background: var(--accent); border-color: var(--accent); color: var(--on-fill); }
.chip.next { border-color: var(--accent); color: var(--accent); background: transparent; }
.chip.dropped { text-decoration: line-through; }
.chip.mini { padding: 0 6px; font-size: 11px; }
.cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px; }
.card { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.card h3 { display: flex; gap: 8px; align-items: baseline; }
.list { display: grid; gap: 6px; }
.row { display: grid; grid-template-columns: auto 1fr auto; gap: 8px; align-items: baseline; min-width: 0; }
.row .id { font-family: var(--display); font-weight: 600; color: var(--muted); font-size: 15px; }
.row .t { min-width: 0; overflow-wrap: anywhere; }
.counts { display: flex; flex-wrap: wrap; gap: 6px; }
.milestones { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
.ms { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 10px 12px; display: grid; gap: 6px; min-width: 0; }
.ms .name { display: flex; gap: 8px; align-items: center; font-family: var(--display); font-size: 17px; font-weight: 600; }
.ms .name::before { content: ""; width: 10px; height: 10px; border-radius: 50%; background: var(--buoy); flex: none; box-shadow: 0 0 0 2px var(--surface), 0 0 0 3px var(--buoy); }
.ms.reached .name::before { background: var(--good); box-shadow: 0 0 0 2px var(--surface), 0 0 0 3px var(--good); }
.epics { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 12px; }
.epic { cursor: pointer; text-align: left; font: inherit; color: inherit; }
.epic:hover, .epic:focus-visible { border-color: var(--accent); outline: none; box-shadow: 0 0 0 3px var(--accent-soft); }
.epic .pct { font-family: var(--display); font-size: 26px; font-weight: 600; line-height: 1; }
.epic .now { color: var(--fg-2); font-size: 13px; display: grid; gap: 2px; }
.epic .now span { overflow-wrap: anywhere; }
dialog { border: 1px solid var(--line); border-radius: 12px; background: var(--surface); color: var(--fg); width: min(960px, calc(100vw - 32px)); max-height: calc(100vh - 48px); padding: 0; }
dialog::backdrop { background: rgba(10, 14, 12, 0.55); }
.dlg { padding: 18px 20px 24px; display: grid; gap: 14px; }
.dlg-head { display: flex; justify-content: space-between; gap: 12px; align-items: start; }
button.x { font: inherit; background: var(--surface-2); border: 1px solid var(--line); border-radius: 8px; padding: 6px 12px; color: var(--fg); cursor: pointer; }
button.x:focus-visible { outline: 2px solid var(--accent); }
details.story { border: 1px solid var(--line); border-radius: 8px; background: var(--surface); }
details.story > summary { list-style: none; cursor: pointer; padding: 9px 12px; display: grid; grid-template-columns: auto 1fr auto; gap: 10px; align-items: center; }
details.story > summary::-webkit-details-marker { display: none; }
details.story > summary:focus-visible { outline: 2px solid var(--accent); border-radius: 8px; }
details.story .meta { display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
details.story .body { padding: 0 12px 12px 12px; display: grid; gap: 8px; border-top: 1px solid var(--line); padding-top: 10px; color: var(--fg-2); }
details.story .body p { max-width: 80ch; }
.tasks { display: grid; gap: 3px; }
.task { display: grid; grid-template-columns: 18px 1fr; gap: 8px; align-items: start; }
.task .box { width: 14px; height: 14px; border: 1.5px solid var(--muted); border-radius: 3px; margin-top: 3px; display: inline-grid; place-items: center; font-size: 11px; line-height: 1; }
.task.done .box { background: var(--good); border-color: var(--good); color: var(--on-fill); }
.task.done .txt { color: var(--muted); text-decoration: line-through; }
.filters { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.filters input, .filters select { font: inherit; padding: 6px 10px; border: 1px solid var(--line); border-radius: 8px; background: var(--surface); color: var(--fg); min-width: 0; }
.filters input { flex: 1 1 220px; }
.filters input:focus-visible, .filters select:focus-visible { outline: 2px solid var(--accent); }
.stories { display: grid; gap: 6px; }
.empty { color: var(--muted); padding: 12px; }
.goal { color: var(--fg-2); max-width: 80ch; }
footer { color: var(--muted); font-size: 12.5px; display: grid; gap: 4px; }
@media (max-width: 520px) { h1 { font-size: 32px; } .row { grid-template-columns: auto 1fr; } .row .chip { grid-column: 2; justify-self: start; } details.story > summary { grid-template-columns: auto 1fr; } details.story .meta { grid-column: 1 / -1; justify-content: flex-start; } }
@media (prefers-reduced-motion: no-preference) { .bar > i { transition: width 300ms ease; } }
</style>

<div class="wrap">
  <header>
    <div class="eyebrow">WindsurfingMMZB · the backlog to version 1.0</div>
    <h1>Road to 1.0</h1>
    <p class="sub" id="updated"></p>
    <div class="headline" id="headline"></div>
  </header>

  <section>
    <h2>Who is waited on</h2>
    <p class="sub">Stories in review, blocked, doing or next, by the name in their owner line. A review means a person has to look or OK it.</p>
    <div class="cols" id="people" style="margin-top:12px"></div>
  </section>

  <section id="sprint"></section>

  <section>
    <h2>The milestones</h2>
    <p class="sub">The marks of the course, in no order: a milestone is reached when its stories are done.</p>
    <div class="milestones" id="milestones" style="margin-top:12px"></div>
  </section>

  <section>
    <h2>The epics</h2>
    <p class="sub">Stories done per epic. Click an epic for its stories and their tasks.</p>
    <div class="epics" id="epics" style="margin-top:12px"></div>
  </section>

  <section>
    <h2>Every story</h2>
    <div class="filters" style="margin-top:12px">
      <input id="q" type="search" placeholder="Search a title, an ID, a roadmap item, a word in the tasks" aria-label="Search">
      <select id="fstatus" aria-label="Status"><option value="">Any status</option></select>
      <select id="fmilestone" aria-label="Milestone"><option value="">Any milestone</option></select>
      <select id="fowner" aria-label="Owner"><option value="">Any owner</option></select>
      <select id="fepic" aria-label="Epic"><option value="">Any epic</option></select>
      <span class="sub num" id="count"></span>
    </div>
    <div class="stories" id="stories" style="margin-top:12px"></div>
  </section>

  <footer>
    <span>The source of this page is <code>Documentation/backlog/</code> (one file per epic). A session changes the files and runs <code>python -I tools/backlog.py --html</code>; this page is that output.</span>
    <span id="foot"></span>
  </footer>
</div>

<dialog id="dlg"><div class="dlg" id="dlgbody"></div></dialog>

<script id="data" type="application/json">__DATA__</script>
<script>
(function () {
  var D = JSON.parse(document.getElementById('data').textContent);
  var STATUS_ORDER = ['doing', 'next', 'review', 'blocked', 'todo', 'done', 'dropped'];
  var GLYPH = { done: '✓', doing: '◐', next: '▷', review: '⚑', blocked: '⊘', todo: '○', dropped: '–' };
  var PEOPLE = [
    { name: 'Max', test: function (o) { return /\bmax\b/i.test(o); } },
    { name: 'Michiel', test: function (o) { return /\bmichiel\b/i.test(o); } },
    { name: 'The lead and the agents', test: function (o) { return /\b(lead|agent)/i.test(o); } }
  ];

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'text') e.textContent = attrs[k];
      else if (k === 'html') e.innerHTML = attrs[k];
      else if (k === 'class') e.className = attrs[k];
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { if (c) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c); });
    return e;
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function md(s) { // the little markdown the board lines use: **bold** and `code`
    return esc(s).replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>').replace(/`([^`]+)`/g, '<code>$1</code>');
  }
  function chip(status, mini) { return el('span', { class: 'chip ' + status + (mini ? ' mini' : ''), text: GLYPH[status] + ' ' + status }); }
  function bar(done, all, good) {
    var pct = all ? Math.round(100 * done / all) : 0;
    var b = el('div', { class: 'bar' + (good ? ' good' : ''), role: 'img', 'aria-label': done + ' of ' + all });
    b.appendChild(el('i', { style: 'width:' + pct + '%' }));
    return b;
  }
  function live(stories) { return stories.filter(function (s) { return s.status !== 'dropped'; }); }
  function countBy(stories) {
    var c = {}; stories.forEach(function (s) { c[s.status] = (c[s.status] || 0) + 1; }); return c;
  }
  function taskCount(stories) {
    var d = 0, a = 0; stories.forEach(function (s) { s.tasks.forEach(function (t) { a++; if (t.done) d++; }); }); return [d, a];
  }

  var ALL = []; D.epics.forEach(function (e) { e.stories.forEach(function (s) { s.epic = e.id; s.epicTitle = e.title; ALL.push(s); }); });
  var LIVE = live(ALL);

  // Header
  document.getElementById('updated').textContent = 'Updated ' + D.generated + (D.commit ? ' from commit ' + D.commit : '') + '. ' +
    D.epics.length + ' epics, ' + LIVE.length + ' stories, ' + taskCount(LIVE)[1] + ' tasks.';
  var doneStories = LIVE.filter(function (s) { return s.status === 'done'; }).length;
  var tc = taskCount(LIVE);
  var counts = countBy(LIVE);
  var head = document.getElementById('headline');
  head.appendChild(el('div', { class: 'tile' }, [el('div', { class: 'eyebrow', text: 'Stories done' }),
    el('div', { class: 'big num', text: doneStories + ' / ' + LIVE.length }), bar(doneStories, LIVE.length, true)]));
  head.appendChild(el('div', { class: 'tile' }, [el('div', { class: 'eyebrow', text: 'Tasks ticked' }),
    el('div', { class: 'big num', text: tc[0] + ' / ' + tc[1] }), bar(tc[0], tc[1], true)]));
  var attention = (counts.review || 0) + (counts.blocked || 0);
  var stat = el('div', { class: 'tile' }, [el('div', { class: 'eyebrow', text: 'By status' })]);
  var cc = el('div', { class: 'counts' });
  STATUS_ORDER.forEach(function (st) { if (counts[st]) cc.appendChild(el('span', { class: 'chip ' + st, text: GLYPH[st] + ' ' + st + ' ' + counts[st] })); });
  stat.appendChild(cc);
  stat.appendChild(el('div', { class: 'sub num', text: attention + ' waiting on a person (review or blocked), ' + ((counts.doing || 0) + (counts.next || 0)) + ' in the sprint (doing or next)' }));
  head.appendChild(stat);

  // People
  var people = document.getElementById('people');
  PEOPLE.forEach(function (p) {
    var mine = LIVE.filter(function (s) { return ['review', 'blocked', 'doing', 'next'].indexOf(s.status) >= 0 && p.test(s.owner); });
    mine.sort(function (a, b) { return STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status); });
    var card = el('div', { class: 'card' }, [el('h3', {}, [el('span', { text: p.name }), el('span', { class: 'sub num', text: mine.length + '' })])]);
    var list = el('div', { class: 'list' });
    if (!mine.length) list.appendChild(el('div', { class: 'empty', text: 'Nothing waiting.' }));
    mine.slice(0, 14).forEach(function (s) {
      var r = el('a', { class: 'row', href: '#', style: 'color:inherit;text-decoration:none' }, [el('span', { class: 'id', text: s.id }), el('span', { class: 't', text: s.title }), chip(s.status, true)]);
      r.addEventListener('click', function (ev) { ev.preventDefault(); openEpic(s.epic, s.id); });
      list.appendChild(r);
    });
    if (mine.length > 14) list.appendChild(el('div', { class: 'sub', text: '+ ' + (mine.length - 14) + ' more in the list below' }));
    card.appendChild(list);
    people.appendChild(card);
  });

  // Sprint
  var sp = document.getElementById('sprint');
  if (D.sprint && D.sprint.sections.length) {
    sp.appendChild(el('h2', { text: D.sprint.title || 'The sprint' }));
    if (D.sprint.goal) sp.appendChild(el('p', { class: 'sub', html: 'Goal: ' + md(D.sprint.goal) }));
    var cols = el('div', { class: 'cols', style: 'margin-top:12px' });
    D.sprint.sections.forEach(function (sec) {
      var c = el('div', { class: 'card' }, [el('h3', { text: sec.name })]);
      var l = el('div', { class: 'list' });
      if (!sec.items.length) l.appendChild(el('div', { class: 'empty', text: 'Nothing.' }));
      sec.items.forEach(function (it) { l.appendChild(el('div', { class: 't', html: md(it) })); });
      c.appendChild(l); cols.appendChild(c);
    });
    sp.appendChild(cols);
  }

  // Milestones
  var msWrap = document.getElementById('milestones');
  var msIds = Object.keys(D.milestones);
  LIVE.forEach(function (s) { if (s.milestone && msIds.indexOf(s.milestone) < 0) msIds.push(s.milestone); });
  msIds.sort(function (a, b) { var na = parseInt(a.replace(/\D/g, ''), 10), nb = parseInt(b.replace(/\D/g, ''), 10); if (isNaN(na) && isNaN(nb)) return a < b ? -1 : 1; if (isNaN(na)) return 1; if (isNaN(nb)) return -1; return na - nb; });
  msIds.forEach(function (m) {
    var ss = LIVE.filter(function (s) { return s.milestone === m; });
    if (!ss.length) return;
    var d = ss.filter(function (s) { return s.status === 'done'; }).length;
    var box = el('div', { class: 'ms' + (d === ss.length ? ' reached' : '') }, [
      el('div', { class: 'name', text: m + (D.milestones[m] ? ' ' + D.milestones[m] : '') }),
      bar(d, ss.length, true),
      el('div', { class: 'sub num', text: d + ' of ' + ss.length + ' stories done' })
    ]);
    msWrap.appendChild(box);
  });

  // Epics
  var ep = document.getElementById('epics');
  D.epics.forEach(function (e) {
    var ss = live(e.stories); var d = ss.filter(function (s) { return s.status === 'done'; }).length;
    var c = countBy(ss); var t = taskCount(ss);
    var now = ss.filter(function (s) { return s.status === 'doing' || s.status === 'next'; });
    var card = el('button', { class: 'card epic', type: 'button', 'aria-label': e.id + ' ' + e.title });
    card.appendChild(el('h3', {}, [el('span', { class: 'sub', text: e.id }), el('span', { text: e.title })]));
    card.appendChild(el('div', { class: 'row' }, [el('span', { class: 'pct num', text: (ss.length ? Math.round(100 * d / ss.length) : 0) + '%' }), el('span', { class: 'sub num', text: d + ' of ' + ss.length + ' stories, ' + t[0] + ' of ' + t[1] + ' tasks' }), el('span')]));
    card.appendChild(bar(d, ss.length, true));
    var cc2 = el('div', { class: 'counts' });
    STATUS_ORDER.forEach(function (st) { if (c[st] && st !== 'done' && st !== 'todo') cc2.appendChild(el('span', { class: 'chip mini ' + st, text: GLYPH[st] + ' ' + st + ' ' + c[st] })); });
    if (c.todo) cc2.appendChild(el('span', { class: 'chip mini todo', text: GLYPH.todo + ' todo ' + c.todo }));
    card.appendChild(cc2);
    if (now.length) {
      var nw = el('div', { class: 'now' });
      now.slice(0, 3).forEach(function (s) { nw.appendChild(el('span', { text: GLYPH[s.status] + ' ' + s.id + ' ' + s.title })); });
      card.appendChild(nw);
    }
    card.addEventListener('click', function () { openEpic(e.id); });
    ep.appendChild(card);
  });

  // The story element (used in the dialog and in the list)
  function storyEl(s, open) {
    var det = el('details', { class: 'story', id: 'story-' + s.id });
    if (open) det.open = true;
    var sum = el('summary', {}, [el('span', { class: 'row', style: 'grid-template-columns:auto 1fr' }, [el('span', { class: 'id', text: s.id }), el('span', { class: 't', text: s.title })]), el('span'), el('span', { class: 'meta' })]);
    var meta = sum.querySelector('.meta');
    meta.appendChild(chip(s.status, true));
    if (s.milestone) meta.appendChild(el('span', { class: 'chip mini', text: s.milestone }));
    if (s.size) meta.appendChild(el('span', { class: 'chip mini', text: s.size }));
    var td = s.tasks.filter(function (t) { return t.done; }).length;
    if (s.tasks.length) meta.appendChild(el('span', { class: 'chip mini num', text: td + '/' + s.tasks.length }));
    det.appendChild(sum);
    var body = el('div', { class: 'body' });
    body.appendChild(el('p', { html: '<strong>Owner:</strong> ' + esc(s.owner || '–') + (s.needs && s.needs !== '—' ? ' · <strong>Needs:</strong> ' + esc(s.needs) : '') + (s.roadmap && s.roadmap !== '—' ? ' · <strong>Roadmap:</strong> ' + esc(s.roadmap) : '') + ' · <strong>Epic:</strong> ' + esc(s.epic + ' ' + s.epicTitle) }));
    if (s.done_when) body.appendChild(el('p', { html: '<strong>Done when:</strong> ' + md(s.done_when) }));
    if (s.tasks.length) {
      var tl = el('div', { class: 'tasks' });
      s.tasks.forEach(function (t) { tl.appendChild(el('div', { class: 'task' + (t.done ? ' done' : '') }, [el('span', { class: 'box', text: t.done ? '✓' : '' }), el('span', { class: 'txt', html: md(t.text) })])); });
      body.appendChild(tl);
    }
    if (s.notes) body.appendChild(el('p', { html: '<strong>Notes:</strong> ' + md(s.notes) }));
    det.appendChild(body);
    return det;
  }

  // The epic dialog
  var dlg = document.getElementById('dlg'), dlgBody = document.getElementById('dlgbody');
  function openEpic(id, storyId) {
    var e = D.epics.filter(function (x) { return x.id === id; })[0]; if (!e) return;
    dlgBody.innerHTML = '';
    var close = el('button', { class: 'x', type: 'button', text: 'Close' }); close.addEventListener('click', function () { dlg.close(); });
    dlgBody.appendChild(el('div', { class: 'dlg-head' }, [el('h2', { text: e.id + ' · ' + e.title }), close]));
    if (e.goal) dlgBody.appendChild(el('p', { class: 'goal', html: '<strong>Goal.</strong> ' + md(e.goal) }));
    if (e.done_when) dlgBody.appendChild(el('p', { class: 'goal', html: '<strong>Done when.</strong> ' + md(e.done_when) }));
    if (e.where) { var w = el('details', {}, [el('summary', { class: 'sub', text: 'Where things stand' }), el('p', { class: 'goal', html: md(e.where), style: 'margin-top:8px' })]); dlgBody.appendChild(w); }
    var ss = e.stories.slice().sort(function (a, b) { return STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status) || (a.id < b.id ? -1 : 1); });
    var list = el('div', { class: 'stories' });
    ss.forEach(function (s) { list.appendChild(storyEl(s, s.id === storyId)); });
    dlgBody.appendChild(list);
    if (typeof dlg.showModal === 'function') dlg.showModal(); else dlg.setAttribute('open', '');
    if (storyId) { var t = document.getElementById('story-' + storyId); if (t) t.scrollIntoView({ block: 'center' }); }
  }
  dlg.addEventListener('click', function (ev) { if (ev.target === dlg) dlg.close(); });

  // Every story, with filters
  var selStatus = document.getElementById('fstatus'), selMs = document.getElementById('fmilestone'), selOwner = document.getElementById('fowner'), selEpic = document.getElementById('fepic'), q = document.getElementById('q');
  STATUS_ORDER.forEach(function (st) { selStatus.appendChild(el('option', { value: st, text: st })); });
  msIds.forEach(function (m) { selMs.appendChild(el('option', { value: m, text: m + (D.milestones[m] ? ' ' + D.milestones[m] : '') })); });
  PEOPLE.forEach(function (p) { selOwner.appendChild(el('option', { value: p.name, text: p.name })); });
  D.epics.forEach(function (e) { selEpic.appendChild(el('option', { value: e.id, text: e.id + ' ' + e.title })); });
  var listEl = document.getElementById('stories'), countEl = document.getElementById('count');
  function render() {
    var words = q.value.trim().toLowerCase();
    var st = selStatus.value, m = selMs.value, ow = selOwner.value, epv = selEpic.value;
    var p = PEOPLE.filter(function (x) { return x.name === ow; })[0];
    var rows = ALL.filter(function (s) {
      if (st && s.status !== st) return false;
      if (m && s.milestone !== m) return false;
      if (epv && s.epic !== epv) return false;
      if (p && !p.test(s.owner)) return false;
      if (words) {
        var hay = (s.id + ' ' + s.title + ' ' + s.roadmap + ' ' + s.owner + ' ' + s.needs + ' ' + s.done_when + ' ' + s.notes + ' ' + s.tasks.map(function (t) { return t.text; }).join(' ')).toLowerCase();
        if (hay.indexOf(words) < 0) return false;
      }
      return true;
    });
    listEl.innerHTML = '';
    countEl.textContent = rows.length + ' of ' + ALL.length;
    if (!rows.length) { listEl.appendChild(el('div', { class: 'empty', text: 'No story matches. Clear a filter.' })); return; }
    rows.forEach(function (s) { listEl.appendChild(storyEl(s, false)); });
  }
  [selStatus, selMs, selOwner, selEpic].forEach(function (x) { x.addEventListener('change', render); });
  q.addEventListener('input', render);
  render();

  document.getElementById('foot').textContent = 'Statuses: todo, next (chosen for the sprint), doing, review (built, waiting for a person), done, blocked, dropped. Sizes S, M, L, XL. Milestones M1 to M11 have no order.';
})();
</script>
"""


def main(argv: list[str]) -> int:
    # Windows consoles default to cp1252, which cannot print names like Brač; print UTF-8 instead.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    filters = {"status": "", "milestone": "", "owner": ""}
    only_epic = ""
    html_out = None
    for arg in argv:
        if arg.startswith("--epic="):
            only_epic = arg.split("=", 1)[1].upper()
        elif arg == "--html":
            html_out = BACKLOG_DIR / "dashboard.html"
        elif arg.startswith("--html="):
            html_out = Path(arg.split("=", 1)[1])
        else:
            for key in filters:
                if arg.startswith(f"--{key}="):
                    filters[key] = arg.split("=", 1)[1]
    if not EPICS_DIR.is_dir():
        print(f"No epics folder at {EPICS_DIR}")
        return 1
    epics, problems = load_all()
    if html_out is not None:
        if problems:
            print("Not written: fix the files first.")
            for problem in problems:
                print("  " + problem)
            return 2
        write_html(epics, html_out)
        return 0
    return print_report(epics, problems, filters, only_epic)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
