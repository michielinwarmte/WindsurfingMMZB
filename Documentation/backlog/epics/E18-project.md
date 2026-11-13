# E18 · The project: the plan, the process, the legal side, the release

Owner: Max (the product), Michiel (the physics), the lead (the sessions and the agents) | Roadmap: PR1 to PR4 | Questions: Q1 to Q5, Q40 to Q45

**Goal.** The team knows what 1.0 is, works in sprints with a visible board, merges safely, keeps the legal side clean (open data credits, brand look-alikes, altered names), and ships releases from main.

**Done when (1.0).** The 1.0 definition is agreed and every epic's done-when is met; every release went through the pipeline; the credits page names every data source per spot with its licence; the brands and the names have passed a legal review for the chosen distribution (Q5); the store page, a trailer and a website exist if the team distributes beyond GitHub.

**Where things stand (6 November 2026).** The roadmap with its ID scheme (157 rows in 11 sections), a progress log of 73 sessions since 28 September, a changelog, the document map, CLAUDE.md's rules; the lead-and-agents workflow (three agents at a time, worktrees, reports, a token ledger); 173 commits on the play branch wait for main after Michiel's OKs and Max's checks; four branches unpushed (their commits are inside the pushed play branch); no licence file (PR1 closed: none); the 0.1.0 release page to check (PR2); the 0.2 release prepared and on hold (PR3). This backlog was written on 6 November 2026.

## Stories

### E18.S01 · The 1.0 definition agreed
Status: next | Size: S | Owner: Max and Michiel | Milestone: M1 | Needs: — | Roadmap: —
Done when: the questions in `QUESTIONS.md` are answered, the answers are moved into `1.0.md` and the epics, and the version ladder is confirmed.
- [ ] T1 The session of 6 November 2026: the questions answered (as many as fit)
- [ ] T2 The rest answered by Max in numbered lists over the next days
- [ ] T3 The lead moves the answers into the files; the questions struck through

### E18.S02 · Main brought up to date, and the 0.2 release
Status: next | Size: M | Owner: the lead; Michiel's OK; Max's checks | Milestone: M1 | Needs: E01.S01, E09.S01 | Roadmap: PR3, PR2
Done when: `play/6nov-evening` (with the night run's reds fixed) is merged into main with a merge commit, a release build of main is played by Max on two PCs, the version is 0.2.0 (the changelog's section written from the 173 commits), the zip and the GitHub release page exist, and PR2 (the 0.1.0 page) is checked.
- [ ] T1 The night run's reds fixed (E09.S01)
- [ ] T2 Michiel's OKs (E01.S01) and Max's checks (E02.S09, E03.S01, E06.S01, E07.S01, E08.S01, E12.S01, E15.S01, E16.S01)
- [ ] T3 The roadmap rows and the progress log for the 6 November work (the agents left them to the lead)
- [ ] T4 The merge into main (done 13 Nov 2026: `merge/main-13nov`, everything since 485eae5, pushed to main on the team's word with Michiel's OKs of E01.S01 still open; validation: the eight known reds and the old fleet-start test, E09.S25 T11; again 13 Nov evening: `merge/main-13nov-evening`, the frame budget, the C++ wave test, the real races and PH15's wind tunnel, pushed on Michiel's word; unit 1115/1117 (TE8's two), check 522/0, validation the same nine reds); the release build played; the 0.2.0 release (E17.S05 T1 for the steps)
- [ ] T5 PR2 checked

### E18.S03 · The sprint rhythm and the backlog adopted
Status: doing | Size: S | Owner: the lead, the team | Milestone: M1 | Needs: Q41, Q42 | Roadmap: —
Done when: CLAUDE.md points every session at `Documentation/backlog/`, ROADMAP.md's top says where the 1.0 plan is, the document map lists the folder, the first sprint is on BOARD.md, and the team has agreed the rhythm (Q41).
- [x] T1 The backlog written (6 November 2026): README, 1.0, QUESTIONS, BOARD, 18 epics, `tools/backlog.py`
- [x] T2 CLAUDE.md, ROADMAP.md and the document map point at it
- [ ] T3 The first sprint agreed; the rhythm written in README.md
- [ ] T4 Committed on a docs branch and merged
Notes: the lead, 2026-11-06: the review loop from the dashboard (edits on the page, a change list, tools/backlog.py --apply) built and tested with this very note

### E18.S04 · Branch and folder hygiene
Status: todo | Size: S | Owner: the lead; Max decides on the folders | Milestone: M1 | Needs: E18.S02 | Roadmap: —
Done when: the four unpushed branches are pushed, the night and play-test integration branches are marked archived in their names or a list, the stash is dropped or archived, the old play folders and zips in `source/` are kept or removed as Max decides (never without asking), and the worktrees are reduced to what the next sprint needs.
- [ ] T1 Push `gr/sailor-polish`, `ui/race-screen`, `ph44/swan`, `mp/race-director`
- [ ] T2 The archive list of integration branches (`playtest/6nov`, `night2/*`, `play/6nov-evening` after the merge)
- [ ] T3 The stash; the play folders and zips (ask Max: the 2 and 5 November folders, the beta.1 folder and zips, the publish scripts). 13 Nov 2026 (Max: "old play folders and zips clean up but dont delete important stuff"): fourteen old play folders and four zips removed (about 10 GB); their launchers, settings, READMEs and the 7 Nov `recording.csv` kept in `WindsurfingMMZB/.logs/play-folder-archive-13nov2026/` (its README names each build's commit); kept: the 12 Nov TV and 13 Nov roundings folders with their zips, the beta.1 zip. The stash and the publish scripts still open

### E18.S05 · The legal side
Status: todo | Size: M | Owner: Max, the lead for the lists | Milestone: M11 | Needs: Q5, Q18, Q28, Q43 | Roadmap: PR1, MA2, GE2
Done when: a `Documentation/LEGAL.md` lists per spot the data sources and their licences with the credit lines (the credits page reads it), the brand look-alike rule and the makers' answers (E06.S09), the altered-name rule and the review (E10.S08), the fonts and third-party code (GUT, fonts, libraries), the game's own licence decision (none, or a licence file for the code), and the distribution's requirements (Q5).
- [ ] T1 The data licences per spot (from the dossiers; the credits page per spot)
- [ ] T2 The brands and the names reviewed
- [ ] T3 The third-party list; the game's licence decision
- [ ] T4 If Steam: the company, the tax forms, the store's requirements

### E18.S06 · Play-testers beyond the team
Status: todo | Size: S | Owner: Max | Milestone: M4 | Needs: E17.S09 | Roadmap: —
Done when: a handful of testers (Tarpie and sailing friends) get a build each milestone with a short form (the feel checklist's lines and a free field), and their notes become stories.
- [ ] T1 The tester list and the form
- [ ] T2 The first round at 0.5 (the beach)

### E18.S07 · The store page, the trailer, the website
Status: todo | Size: M | Owner: Max | Milestone: M11 | Needs: Q5, Q44 | Roadmap: —
Done when: if the team distributes beyond GitHub, the game has its name (Q44), a store page with screenshots and a trailer, a website or a page on the MMZB site, and the press kit.
- [ ] T1 The name
- [ ] T2 The trailer (the spectator cameras of E16.S02) and the screenshots
- [ ] T3 The page

### E18.S08 · The documents kept honest
Status: todo | Size: S | Owner: the lead | Milestone: any | Needs: — | Roadmap: —
Done when: every milestone's release updates the README (features, controls, known gaps), the changelog, the document map, and archives the finished plans; the roadmap's open rows are moved into the stories at 0.4 (Q40).
- [ ] T1 The README and the changelog at each release
- [ ] T2 The roadmap's rows into the stories at 0.4 (if Q40 says so)

### E18.S09 · The review loop: edits made on the dashboard go into the files with tools/backlog.py --apply
Status: review | Size: S | Owner: the lead; Max tries it | Milestone: M1 | Needs: — | Roadmap: —
Done when: Max changes a status, ticks a task, writes a note and adds a story on the page, pastes the text to the lead, and the next build of the page shows them from the files.
- [x] T1 The page's controls: the status select, the tasks that tick on a click, the note box, "Add a story" in an epic; the edits kept in the browser and shown with an "edited here" chip
- [x] T2 The "Your changes" panel: the text (one line per change, the name and the date), copy, download, show, clear
- [x] T3 `tools/backlog.py --apply`: the status, the tick, the note with the author, the new story with the next free number; bad lines reported, nothing deleted; tested on this story
- [ ] T4 Max's first round trip from his own PC and browser (the file from git or the GitHub-served link), pasted to a session on his account
Notes: added from the dashboard by the lead, 2026-11-06, as the first test of the loop; the fields filled by hand afterwards (a story from the page gets ? for its size, owner and milestone until a session fills them).
