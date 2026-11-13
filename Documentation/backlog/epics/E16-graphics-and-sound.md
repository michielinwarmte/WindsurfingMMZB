# E16 · Graphics and sound

Owner: Max's eye and the team's ears, the lead and agents | Roadmap: GR1 to GR13, SO1 to SO6, GR9 | Questions: —

**Goal.** A look and a sound that tell the sailor what the physics is doing (the spray, the chatter, the fin's hum, the gusts on the water, the waves' faces) and that make each spot feel like itself (its sky, its light, its water's colour, its shore), with a camera that does not get in the way and a fleet you can hear.

**Done when (1.0).** The team's look at the effects and the water (GR6) and careful listen (SO4) are done and their findings fixed; every spot has its own sky, sun path, haze, water colour and bottom; the camera is steady on Max's screen and has a spectator and replay camera; the board at the limit sounds (SO2), the fleet and the other player are heard (SO5, MP4), the beach has its ambience, and menu sounds exist; music and a commentary voice are built or dropped by decision.

**Where things stand (6 November 2026).** The spray, the chatter and the wake grow with the fin's load and the heel; gust patches darken and roughen the water; the lake's wind shading (Cox-Munk, whitecaps, foam, wind rows); the board's effects re-drawn after photos (6 November); draw distance; the close follow camera; the camera's jitter fixed in code but not seen on Max's screen (GR9); the buoys, boats and pins. Every sound is synthesised at startup (wind, water, the sail's flutter and crack, the fin's hum, the rig's creak, the start's horns, beeps and gun); no sound files; no board chatter sound, no fleet sound, no music, no menu sounds, no beach ambience. The sun is fixed at mid-July 15:00 on both waters; the open water has no land and no time of day.

## Stories

### E16.S01 · The team's look and listen
Status: review | Size: S | Owner: Max, Michiel | Milestone: M1 | Needs: the night3 build | Roadmap: GR6, SO4, GR1, GR2, GR11, GR12, GR13
Done when: the team has looked at the water's colour, the foam, the far edge, the spray, the wake, the splash, the gust patches' readability and the draw distance's default, and listened to the mix with the list "What to listen for" (the archived rebuild plan, phase 8); the findings are tasks here.
- [ ] T1 The look (GR6) with the night3 folder: the answers per item
- [ ] T2 The listen (SO4): the hum as a warning you learn, the creak, the mix
- [ ] T3 The draw distance's default (GR13: is Far worth its cost?)

### E16.S02 · The camera
Status: todo | Size: M | Owner: the lead, Max's screen | Milestone: M2 | Needs: E16.S01 | Roadmap: GR9, GR4
Done when: the rig camera is steady on Max's screen on waves and flat water (GR9 verified, his refresh rate known), the follow camera's look point is smoothed against heave and yaw, a spectator camera (TV-style, from the committee boat and a drone) exists for watching and replays, and an onboard view is an option.
- [ ] T1 GR9 on Max's screen; the look point's smoothing
- [ ] T2 The spectator cameras (with E12.S01's spectating and E11.S08's replays); the watch mode's TV camera (drones, helicopter, committee boat) is E11.S11 (review, 12 Nov 2026)
- [ ] T3 The onboard view (the helmet camera)

### E16.S03 · The look per spot
Status: todo | Size: L | Owner: Max with the lead | Milestone: M10 | Needs: E04.S01 | Roadmap: MA3
Done when: a spot's resource sets its sky (a procedural sky per climate, or an HDRI set), the sun's path by date and latitude following the clock, the haze and the air's colour, the water's colour and clarity, the bottom's look, the shore's materials; Silvaplana and the open water keep their look; each new spot gets its own (task 8 of the spot template).
- [ ] T1 The sun's path from the date, the latitude and the clock (today fixed); the shadows that follow
- [ ] T2 The sky and haze per climate (alpine, Mediterranean, North Sea, trade-wind, desert); clouds as a day-draw outcome
- [ ] T3 The water's colour and clarity per spot (with E02.S07 T3)
- [ ] T4 The far scenery: islands, mountains, the opposite shore from the DEM; the open water gets a horizon of choice

### E16.S04 · The sea's look
Status: todo | Size: M | Owner: the lead | Milestone: M3 | Needs: E02.S03, E02.S04 | Roadmap: GR11, GR12
Done when: the swell's groups, the breaking crests, the surf zone's white water, the foam streaks, the spray off crests and the bottom through shallow water look right from the follow camera within the graphics budget (E02.S07 T4).
- [ ] T1 The groups and the breaking crests in the shader from the sea function's bands and the SWAN field
- [ ] T2 The surf zone and the run-up on the beach mesh
- [ ] T3 Max's eye at Brouwersdam and Pozo

### E16.S05 · The sound of the board, the fleet and the beach
Status: todo | Size: M | Owner: the lead, the team's ears | Milestone: M4 | Needs: E16.S01 | Roadmap: SO2, SO5, MP4, SO6
Done when: the board chatters and slaps on chop, the tail spray is louder when pushing, the leeward spray of a railed board hisses (SO2); the other boards' splashes, sails and gybes are heard by distance and direction (SO5, MP4); the beach has wind in the trees or the dunes, the shore break, voices and the race office's horn; the menus click; the ObjectDB warning at quit is gone (SO6).
- [ ] T1 SO2: the board at the limit
- [ ] T2 SO5 and MP4: the fleet and the other player, mixed by distance
- [ ] T3 The beach ambience per spot type; the menu sounds
- [ ] T4 SO6

### E16.S06 · Music and the commentary voice
Status: todo | Size: M | Owner: the team | Milestone: M8 | Needs: a decision, E13.S06 | Roadmap: —
Done when: the team has decided on music (none, a licensed set, or commissioned; menus and the beach only, never while sailing?) and on a commentary voice for the race and the interviews (none, or a voice bank), and the chosen things are built.
- [ ] T1 The decision and the licences
- [ ] T2 The build

### E16.S07 · The figure's and the gear's look at the limit
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: E08.S01 | Roadmap: GR3, GR5
Done when: the figure shows the push and the body (GR3), the catapult's warning (the nose lifting and the round-up in the last half second) is visible, the board model has its flat tail and the 44 cm fin looks right (GR5).
- [ ] T1 GR3 and the catapult's warning
- [ ] T2 GR5: the board's rebuild and the fin's look
