# E12 · Multiplayer

Owner: Max tests on real PCs, the lead builds | Roadmap: MP1 to MP13 | Questions: Q4 (internet), Q35 (the beach)

**Goal.** Racing with friends: up to eight players on a LAN with the AI fleet, the host as the race director, late joining, spectating, races one after another, every format, on every spot; the same physics on every PC with the states travelling exactly.

**Done when (1.0).** Eight real PCs race on any spot in any format with the director's live course and the AI fleet for an evening without a resync or a crash; collisions and the wind's changes travel; the other players are heard; the lobby, chat or emotes and the return to the lobby exist; the spot and the build are checked at the door; internet play is either built through a private network (Tailscale) or explicitly out of 1.0 (Q4).

**Where things stand (6 November 2026).** LAN multiplayer works: the host is the admin (map, race or free sailing, course, AI fleet 0 to 19, countdown, laps, level, rules, shadows, lake time, wind, waves), a guest joins with its name and gear and says Ready; each PC sails its own board's full physics, the host the AI's; every board's whole state travels (475 fields, about 1.5 kB a tick after a keyframe) and is written into a puppet; the host's clock and race; exact sync measured (0.0000 m). Two players passed on Max's two PCs (MP1, 5 November). Built 6 November, tested only as three instances on one PC: up to 8 players through the host's relay, late join, gear between races, races back to back, the race director's live course, the AI off the shore, spectating (Tab, Shift+Tab, L; retire; race again). Limits: LAN only; one fixed port (47520; a test collides with a live game); the same build hash on every PC; no pause; the host's wind fixed for the game; no collisions; the other boards unheard; the host's cost with 19 AI boards 3 to 5 ms a tick, the traffic 0.7 MB/s, eight real PCs never measured; no chat, no return to the lobby; the director view's wind streaks wrong.

## Stories

### E12.S01 · The 6 November multiplayer tested on real PCs
Status: review | Size: S | Owner: Max and Michiel | Milestone: M1 | Needs: the night3 build on both PCs | Roadmap: MP5, MP6, MP10, MP12, MP13
Done when: two (or more) real PCs have run a race director evening: the live course, a late joiner, spectating a racer, a retire and a race again, three races back to back; the open choices of spectating are answered; the findings are tasks here.
- [ ] T1 The LAN evening's checklist from the evening folder's README run on two PCs
- [ ] T2 MP13's choices: the camera after a finish, a "Sail now" between races, spectating alone with the AI or in free sailing, one Esc entry or two
- [ ] T3 The findings written into `Documentation/reports/multiplayer/RACE_DIRECTOR.md`

### E12.S02 · What else must travel: the wind, the collisions, the sound
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E11.S01, E03.S08 | Roadmap: MP2, MP3, MP4
Done when: the host's wind change reaches every PC at one tick with both seas rebuilt (MP3), the contact between two players' boards happens the same on both PCs (MP2: the host judges, the puppets show the push), and the other player's splashes and sail are heard near you (MP4).
- [ ] T1 The wind change over the wire; the seas' rebuild contract
- [ ] T2 Collisions between players and with the AI (the host's physics owns the AI; the two players' contact resolved by the host?)
- [ ] T3 The sound of the puppets (with SO5)

### E12.S03 · An evening without trouble: stability and the host's cost
Status: todo | Size: M | Owner: the lead, Max for the eight-PC test | Milestone: M2 | Needs: E12.S01 | Roadmap: MP8, MP9
Done when: eight real PCs race for an evening; a guest that drops rejoins where it was; the port can be changed (two games on one network); the return to the lobby, a chat line or emotes, the host's cost with 19 AI boards and 7 guests measured and within budget (MP8: the snapshot's loop, the AI at 10 to 15 a second if needed).
- [ ] T1 The eight-PC test (the LAN party) and its measurements
- [ ] T2 Reconnect; the port as a setting; a pause for the host?
- [ ] T3 The lobby's return, the chat or emotes (MP9)
- [ ] T4 The host's cost: the snapshot's GDScript loop (a native helper, or fewer AI states a second)

### E12.S04 · Every spot and every format over LAN
Status: todo | Size: M | Owner: the lead | Milestone: M7 | Needs: E04.S01, E11.S03, E11.S05 | Roadmap: —
Done when: the lobby picks any spot (checked at the door), the day's conditions travel (the tide, the current, the climate draw), the elimination ladder runs with players in the heats, and the long-distance race and the speed run work with players.
- [ ] T1 The spot id and the day in the handshake
- [ ] T2 The ladder with players (the heats' assignment, the spectating of the other heats)
- [ ] T3 The long-distance race and the speed run over LAN

### E12.S05 · Internet play
Status: todo | Size: L | Owner: the lead | Milestone: later (Q4) | Needs: Q4 | Roadmap: MP7
Done when: either a documented way over a private network (Tailscale: the host's lobby lists its addresses, the guest types one; the pacing holds at internet latency) or a relay server, as the team decides; or the story is dropped for 1.0 with the reason.
- [ ] T1 A Tailscale test between Max's two PCs over the internet (the laptop on another network)
- [ ] T2 The pacing and the snapshot rate at 50 to 150 ms latency
- [ ] T3 The decision

### E12.S06 · Players on the beach, and a season with friends
Status: todo | Size: M | Owner: the lead | Milestone: later | Needs: E05.S11, E13.S03 | Roadmap: —
Done when: players see each other on the beach and a season can be sailed together over several evenings (the save shared by the host).
- [ ] T1 The on-foot states over the wire
- [ ] T2 The shared season save
