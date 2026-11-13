# E17 · Tech: performance, tools, builds and releases

Owner: the lead; Michiel for the physics' cost; Max's PCs | Roadmap: TE1 to TE7, RA4, TE3, PR3, PR4 | Questions: Q5, Q8, Q45

**Goal.** The game runs a fleet of 32 at 60 fps on the team's PCs and a named minimum machine, builds and tests itself without a person, ships as a download of a reasonable size (or spot packs), saves safely, and can be released in one command.

**Done when (1.0).** 32 boards at 60 fps with the full waves on Max's PC and 20 on the minimum machine; CI runs the check and the unit tests on every push; the release script makes the Windows build (and Linux if Q4 says so) with the changelog and the tag; the download fits the budget with thirteen spots; crash logs reach the team from play-testers; the tech debt list is empty or accepted; a second machine runs the nights.

**Where things stand (6 November 2026).** Godot 4.7.2, typed GDScript, 323 scripts (77,000 lines), 87 unit test files (955 tests) and 11 validation files (48 tests, 8 red), GUT 9.7.1, no CI, one Windows export preset, `tools/release.sh build`, zips of about 300 MB (the lake's terrain and photos, 429 MB imported), Git LFS for 165 files (117 MB), no licence file, English only, settings and time-trial bests in `user://`. 20 boards at 65 to 68 fps on the release build with the full waves (the editor build collapses at a few boards: a global engine lock on every field read from a thread); 32 boards cost 22.6 ms of physics a tick; the +2.3 ms per tick of the lake-full branch is unexplained. Godot rewrote the audio bus file (TE1, fixed 5 November); Max's PC lacks Blender 4.5 (TE2); the physics spec is 1 MB (TE7). RA11 is used for two roadmap rows.

## Stories

### E17.S01 · Fifty boards at 60 fps, the physics untouched
Status: todo | Size: L | Owner: the lead, Michiel | Milestone: M11 | Needs: E01.S01 T5 | Roadmap: RA4, TE5, PH19, PH20
Done when: a race of fifty boards with the full lake waves runs at 60 fps on Max's PC on the release build at 1280 by 720 and at 3137 by 1263, measured on an idle PC by the night-run script, with every board on the same physics (rule 7: no simplified far boards, Max, 6 November 2026, Q8); if fifty cannot be reached without that, the measured maximum is the game's fleet limit and the number is written in 1.0.md. The frame is understood (a budget table per part). The steps: 32 first, then 50.
- [ ] T1 The +2.3 ms per tick found (E01.S01 T5)
- [ ] T2 The remaining engine locks in the physics (about 85 field reads and 25 Basis values per substep, the telemetry per tick) removed (the no_wait method)
- [ ] T3 The hands' cost (PH19) and the fin's sea queries (PH20)
- [ ] T4 A native sea function (GDExtension) if the sea's cost demands it (E02.S03 T4); the LAN contract kept
- [x] T5 The catch-up cap (2 instead of 8 ticks; Max's gameplay choice: a slowed clock instead of a collapse): **no** (Max, 13 November 2026, after trying it at 25 and 31 boards: "full speed or nothing"). The race clock never slows; the fleet is held to what runs at full speed (this story's done-when: the measured maximum is the fleet limit)
- [x] T6 The budget table in `Documentation/reports/racing/fleet_frame.md` (13 November 2026, with three speed-ups that leave the race the same: 17 AI boards at 60 fps on the lake instead of 15, 23 at 33 fps instead of 8)
- [ ] T7 From 32 to 50: the sea's cost per board, the snapshot and telemetry per board, the render of fifty rigs; the measured maximum written in 1.0.md if 50 is out of reach

### E17.S02 · The minimum machine and the fps gate
Status: todo | Size: S | Owner: Max for the machine, the lead | Milestone: M11 | Needs: Q8 | Roadmap: —
Done when: a minimum machine is named (Max's laptop?), its numbers (20 boards at 60 fps, 1280 by 720) are the gate in the night run, and the settings' presets (Low, Normal, High) are set for it.
- [ ] T1 The machine and the measurement
- [ ] T2 The presets and the gate

### E17.S03 · The download's size
Status: todo | Size: M | Owner: the lead | Milestone: M11 | Needs: E04.S02 | Roadmap: TE3
Done when: the budget is decided (one download under 2 GB, or a base under 1 GB plus spot packs), the lake's far tiles and photos are reduced to what the camera can see, the imported textures use a compressed format, and the size per spot is measured and kept.
- [ ] T1 The budget and the format
- [ ] T2 The lake reduced; the compression
- [ ] T3 Spot packs, if chosen (E04.S17)

### E17.S04 · Continuous integration
Status: todo | Size: M | Owner: the lead | Milestone: M11 | Needs: the GitHub repository's settings | Roadmap: —
Done when: every push runs `tools/check.sh` and `tools/test.sh` on GitHub Actions with headless Godot 4.7.2 on Linux (LFS pulled), the result shows on the pull request, and a nightly job runs the validation suite and the autopilot gate (E09.S08) on a self-hosted runner (the second machine) if the team wants it.
- [ ] T1 The workflow for check and unit tests
- [ ] T2 The nightly on the second machine (optional)

### E17.S05 · The release pipeline
Status: todo | Size: M | Owner: the lead | Milestone: M11 | Needs: Q5 | Roadmap: PR3, PR4
Done when: `tools/release.sh` takes the version once (today in `project.godot` and a placeholder in the menu scene), writes the changelog's section into the release notes, builds Windows (and Linux when decided), zips, tags and, with `gh` installed, drafts the GitHub release; the 0.2 release is the first through it.
- [ ] T1 The version in one place; the notes from the changelog
- [ ] T2 `gh` on Max's PC (or the API with a token); the draft release step
- [ ] T3 The Linux export (Q4) and a Steam Deck check if a deck is at hand
- [ ] T4 Later: the Steam build if Q5 says so (SteamCMD, the depot, the store page in E18.S07)

### E17.S06 · The save system
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E13.S04 | Roadmap: —
Done when: the profile, the season and the career save to `user://` with a version, a migration path and a backup of the last good save; a corrupt save never blocks the game.
- [ ] T1 The format and the versioning (with E13.S04)
- [ ] T2 The backup and the corruption guard

### E17.S07 · The second machine, and the tools on every PC
Status: todo | Size: S | Owner: Max, Michiel | Milestone: M1 | Needs: Q45 | Roadmap: TE2, MA8
Done when: a second machine (Michiel's PC, the laptop, or a small server) runs the nights (the autopilot suite, the training, SWAN, the polars) so Max's PC stays free, and every PC has Blender 4.5, the Python packages, the export templates and LFS.
- [ ] T1 The machine and its access (Tailscale: `max-school` was offline on 5 November)
- [ ] T2 Blender 4.5 and the packages on Max's PC (TE2); the Linux PC's tools (MA8)
- [ ] T3 The night scripts run from there; the results pulled into the repository

### E17.S08 · Code hygiene and the documents
Status: todo | Size: S | Owner: the lead | Milestone: any | Needs: — | Roadmap: TE4, TE6, TE7
Done when: the listed items are done: `windsurfer.gd` calls `_rig.bend_fin()` (TE4), the archived racing plan's times corrected (TE6), the physics spec split (TE7, E01.S14 T5), the duplicated RA11 row renumbered, the stale roadmap rows (RA2, RA24, UI4, SO3 built on 5 to 6 November) closed, and the stash `ph43-wip-5nov` dropped or archived.
- [ ] T1 TE4, TE6
- [ ] T2 RA11's duplicate; the stale rows; the stash

### E17.S09 · Crash reports and logs from play-testers
Status: todo | Size: S | Owner: the lead | Milestone: M11 | Needs: — | Roadmap: —
Done when: a crash or a NaN writes a report (the log, the settings, the last states) that a tester can send with one click, and the team's build number is in it.
- [ ] T1 The report file and the button
- [ ] T2 The build number in the log's first line

### E17.S10 · The session recorder: from play-test to repeatable test
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: —
Done when: a play-tester can mark a moment while recording, a recording can be replayed headless as a repeatable test, the AI boards and a two-PC LAN race can be recorded, and `Documentation/reports/playtest/session_recorder.md` says how.
- [x] T1 The recorder in the game: `--record=<file.csv>`, 10 rows a second (the telemetry, the controller's choices, the controls, the mouse body, the keys held), the settings on the first line; the play folder's "Record a session" launcher (7828498)
- [ ] T2 A marker key (for example F8) that writes a "this was weird" row
- [ ] T3 Replay: a recording's keys fed back into the game headless, so before and after a fix sail the same input
- [ ] T4 The AI boards recorded in a race
- [ ] T5 LAN: both PCs record a two-PC race and the boards are compared
- [ ] T6 The window size, UI scale and frame time in the rows (for the UI on any window size and the 60 fps goal)
Notes: built 7 November after Max asked "how can I get to you that you are not fixing the problem, what do you need?" The harnesses do not see the game's input and settings; the recorder runs in the real game. It found the start's spin (E01.S18) and the sheet keys' dump (E07.S12). Close to E17.S09 (crash reports).
