#!/usr/bin/env python3
"""The 1.0 backlog's progress, printed from the epic files.

Run from the repository root: `python -I tools/backlog.py [--epic=E04] [--status=doing] [--milestone=0.4]`.

It reads every `Documentation/backlog/epics/E*.md`, finds the stories (a `### E04.S02 · Title` heading
followed by its `Status: ... | Size: ... | ...` line) and their tasks (`- [ ]` / `- [x]` lines), and prints
one table per epic plus a total. It also complains about a story line it cannot read, so a session sees
at once when it broke the layout. Nothing is written.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EPICS_DIR = ROOT / "Documentation" / "backlog" / "epics"

STATUSES = ["todo", "next", "doing", "review", "done", "blocked", "dropped"]
STORY_RE = re.compile(r"^### (E\d{2})\.(S\d{2})\s*[·\-:]\s*(.+?)\s*$")
EPIC_RE = re.compile(r"^# (E\d{2})\s*[·\-:]\s*(.+?)\s*$")
FIELD_RE = re.compile(r"(\w+):\s*([^|]*)")
TASK_RE = re.compile(r"^\s*- \[([ xX])\]\s*(T\d+)?")


def parse_epic(path: Path) -> dict:
    """One epic file -> its name and its stories with their fields and task counts."""
    epic = {"id": path.stem[:3], "title": path.stem, "stories": [], "problems": []}
    story = None
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.rstrip()
        epic_match = EPIC_RE.match(line)
        if epic_match:
            epic["id"], epic["title"] = epic_match.group(1), epic_match.group(2)
            continue
        story_match = STORY_RE.match(line)
        if story_match:
            story = {
                "id": f"{story_match.group(1)}.{story_match.group(2)}",
                "title": story_match.group(3),
                "fields": {},
                "tasks_done": 0,
                "tasks_all": 0,
                "line": number,
            }
            epic["stories"].append(story)
            continue
        if line.startswith("### ") and not story_match:
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
        task_match = TASK_RE.match(line)
        if task_match:
            story["tasks_all"] += 1
            if task_match.group(1).lower() == "x":
                story["tasks_done"] += 1
    for story in epic["stories"]:
        if "status" not in story["fields"]:
            epic["problems"].append(f"{path.name}:{story['line']}: {story['id']} has no 'Status:' line under its heading")
    return epic


def wanted(story: dict, filters: dict) -> bool:
    for key, value in filters.items():
        if value and story["fields"].get(key, "").lower() != value.lower():
            return False
    return True


def main(argv: list[str]) -> int:
    # Windows consoles default to cp1252, which cannot print names like Brač; print UTF-8 instead.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    filters = {"status": "", "milestone": "", "owner": ""}
    only_epic = ""
    for arg in argv:
        if arg.startswith("--epic="):
            only_epic = arg.split("=", 1)[1].upper()
        else:
            for key in filters:
                if arg.startswith(f"--{key}="):
                    filters[key] = arg.split("=", 1)[1]
    if not EPICS_DIR.is_dir():
        print(f"No epics folder at {EPICS_DIR}")
        return 1
    totals = {status: 0 for status in STATUSES}
    tasks_done = tasks_all = 0
    problems: list[str] = []
    for path in sorted(EPICS_DIR.glob("E*.md")):
        epic = parse_epic(path)
        problems.extend(epic["problems"])
        if only_epic and epic["id"] != only_epic:
            continue
        stories = [s for s in epic["stories"] if wanted(s, filters)]
        if not stories:
            continue
        counts = {status: 0 for status in STATUSES}
        for story in stories:
            counts[story["fields"].get("status", "todo")] = counts.get(story["fields"].get("status", "todo"), 0) + 1
            totals[story["fields"].get("status", "todo")] = totals.get(story["fields"].get("status", "todo"), 0) + 1
            tasks_done += story["tasks_done"]
            tasks_all += story["tasks_all"]
        live = [s for s in stories if s["fields"].get("status") != "dropped"]
        done = sum(1 for s in live if s["fields"].get("status") == "done")
        share = f"{100 * done // len(live)} %" if live else "-"
        print(f"\n{epic['id']} {epic['title']}  [{done}/{len(live)} stories done, {share}]")
        for story in stories:
            f = story["fields"]
            tasks = f"{story['tasks_done']}/{story['tasks_all']}" if story["tasks_all"] else "-"
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


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
