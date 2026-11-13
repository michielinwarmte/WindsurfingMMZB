# The 1.0 backlog: how it works

This folder is the plan from today to version 1.0, cut into chunks the team and an AI session can pick up one at a time. It is written for Max, Michiel and every AI session alike: plain text, one fixed layout, nothing clever.

**Three levels.** An **epic** is one of the big promises of 1.0 (the twelve spots, the gear, the AI characters...). A **story** is a chunk of an epic that one session, one agent or one play-test can finish and show (a few days at most). A **task** is a tick box inside a story. You plan in stories, you work in tasks, you judge 1.0 by epics.

**What lives where.**

| File | What it is | Who changes it, when |
|---|---|---|
| [1.0.md](1.0.md) | **What 1.0 is**: the definition of done per epic, the version ladder from 0.2 to 1.0, and what is out of scope | The team, when a decision changes the goal |
| [QUESTIONS.md](QUESTIONS.md) | The open questions with a number each (Q1, Q2...), the lead's recommendation and the team's answer | Max and Michiel answer; the session that reads the answer moves it into 1.0.md and the epics |
| [BOARD.md](BOARD.md) | **Where we stand**: the audit of today, the current sprint (Now / Next / Blocked / Done this sprint), what waits on whom | Every session, at its start and its end |
| [epics/](epics/) | One file per epic: the goal, done-when, the stories with their tasks | The session that works on a story |
| `tools/backlog.py` | Prints the progress per epic and checks the files' layout (`python -I tools/backlog.py`); with `--html` it writes the dashboard | Nobody; run it |
| [dashboard.html](dashboard.html) | **The dashboard**: one page generated from the files above: the headline bars, who is waited on, the sprint, the milestones, the epics (click one for its stories), every story with filters and its tasks. It travels with the repository: pull the branch and open the file in a browser (or VS Code's preview). A Claude account can also publish it as its own private page, but a page published from one account (the company's) cannot be shared with another (Max's private one), so the file in git is the one copy everyone has | Generated: never edit it; `python -I tools/backlog.py --html` |
| [../../ROADMAP.md](../../ROADMAP.md) | The detailed item ledger (GP1, PH6, RA27...): every measurement and decision behind an item. It stays. A story names the roadmap items it covers | As before (CLAUDE.md) |

**The layout of a story** (the script reads these lines; keep them exactly like this):

```
### E04.S02 · Brouwersdam
Status: todo | Size: L | Owner: Max | Milestone: M10 | Needs: E04.S01, E02.S03 | Roadmap: MA7
Done when: the beach, the dam, the Grevelingen side and the sea side sail like the real spot in a 20 kt south-wester, checked by Max.
- [ ] T1 The data: AHN4 terrain, Rijkswaterstaat depths, PDOK aerial photos
- [ ] T2 The wind: ...
- [x] T3 ...
Notes: anything worth keeping (measurements, decisions, links to reports).
```

- **IDs:** `E04` is the epic, `E04.S02` the story, `E04.S02.T1` a task. An ID is never reused or renumbered; a dropped story keeps its number and gets `Status: dropped`.
- **Status:** `todo` (not started) · `next` (chosen for the coming sprint) · `doing` (someone is on it) · `review` (built; waits on Max's play-test or Michiel's OK) · `done` · `blocked` (say on what, in Needs or Notes) · `dropped`.
- **Size:** `S` a session or less · `M` one package (one agent, or one session of the lead) · `L` several packages · `XL` a milestone's worth (split it before it starts).
- **Owner:** who decides and checks it: Max, Michiel, Tarpie, the lead (an AI session), an agent. The physics (`Game/sim/`) is always Michiel's to OK.
- **Milestone:** the milestone it belongs to (M1 to M11 in 1.0.md). The milestones have no order: the tracks run in parallel (Max, 6 November 2026). `later` and `any` are allowed.
- **Needs:** the stories or questions it waits on (`Q12` means an answer in QUESTIONS.md).
- **Roadmap:** the ROADMAP.md item IDs it covers. When the story is done, those items move to the changelog as before.

**The rules for a session, human or AI.**

1. Start by reading [BOARD.md](BOARD.md). Take a story from Now (or Next), set it to `doing` with your name and the date in Notes.
2. Work in the tasks: tick them as they are verified, not as they are written. A task that turns out bigger becomes a new story (next free number) and the old task points to it.
3. Finish: set `review` (if a person has to look or OK it) or `done`; write one line under "Done this sprint" in BOARD.md; update the ROADMAP.md rows and the progress log as CLAUDE.md asks.
4. A new wish from the team becomes a story in the right epic with `Status: todo`, never a loose note. A new big promise becomes a new epic (next free number) and a line in 1.0.md.
5. Never delete a story, a task or a note. Move, mark, strike through.
6. Run `python -I tools/backlog.py` before you commit: it prints the counts and complains about a line it cannot read. Then `python -I tools/backlog.py --html` so the dashboard matches the files, and commit and push it with them: the pushed file is how the other PCs and accounts get the new page.

**How the dashboard stays true.** The files in this folder are the only source; the page is rebuilt from them by one command, so it can never disagree with the files for longer than a session.

**Reviewing from the page.** You can edit on the dashboard: open a story and set its status, click a task to tick it, write a note (what you saw, what needs improving, a decision), or add a story to an epic. The page keeps your edits in your browser, shows them with an "edited here" chip, and the panel "Your changes on this page" turns them into a short text:

```
backlog-changes v1
by Max on 2026-11-07 10:12
E01.S03 status doing
E01.S03 task T2 done
E01.S03 note: the spin-out feels too soft at 24 kt
E05 story: A beach bar with a webcam of the wind | done when: you can read the wind from the bar
```

Copy it and paste it to the lead (any Claude session, on any account), or download it and run `python -I tools/backlog.py --apply=<the file>` yourself. The script changes the status line, ticks the task, appends the note with your name and the date, or adds the story with the next free number and the status `todo`; it never deletes and it says what it could not read. Then the page is rebuilt (`--html`), committed and pushed, and your browser drops the changes that are now in the files. A new story from the page gets `Size: ?`, `Owner: ?` and `Milestone: ?`: the next session fills them in.

**The rhythm (proposed, Q38).** A sprint is one week, from one LAN play-test evening to the next. At the evening: play the build, answer the questions, choose Next. Between: the lead and the agents build; Michiel reviews the physics commits in one batch; Max play-tests the folder of the day.
