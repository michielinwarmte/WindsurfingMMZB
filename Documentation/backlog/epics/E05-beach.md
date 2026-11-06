# E05 · The beach: the world on foot

Owner: Max for the design and the look, the lead for the build | Roadmap: MA3, PR4 | Questions: Q34, Q35, Q36

**Goal.** Every spot has a walkable beach that is also the menu: you start the game on the beach, walk to the gear hut (tent, shed, container, depending on the spot) carrying your gear to change it, walk up the watch tower to see the wind and the waves (the wind viewer), set the course at the race director's table, enter a race at the race office, take a lesson from the coach, and walk your board into the water to beach-start. No loading screens except travelling to another spot.

**Done when (1.0).** The start menu is gone; the game opens on a beach; every place on the list (Q35) is reachable on foot on every spot; the gear change happens in the hut with the gear carried there; the beach start hands over to the physics at knee depth; the pause menu holds the settings; the whole flow is play-tested by someone who has never seen the menus.

**Where things stand (6 November 2026).** Nothing on foot exists: no character controller, no beach meshes, no hut, no tower, no interaction system (`CharacterBody3D` has zero uses). The sailing starts 40 m off the camping beach in 23 m of water; the shore is a stop ("Aground off the shore. R"); the fly-over and the wind viewer are separate scenes; the gear is a menu page; the main scene is the start menu with the open water sailing behind it as a backdrop; the lake "loads for a few seconds". The sailor figure is procedural (E08) and has no walking.

## Stories

### E05.S01 · The design of the beach and the flow
Status: todo | Size: M | Owner: Max with the lead | Milestone: M4 | Needs: Q35, Q36 | Roadmap: —
Done when: a short design (a page with a sketch per spot type) says what is on the beach, how you move (third person, the camera), how you interact (walk up, one key), how the gear is carried, how the water is entered, what the pause menu holds, how you travel, and how a new player's first five minutes go.
- [ ] T1 The list of places and their actions (from Q35) and which spot type has which building (hut, tent, shed, container, club)
- [ ] T2 The movement and camera on foot (third person over the shoulder, Q34 answered 6 November 2026; the follow camera's family)
- [ ] T3 The interaction model: a prompt when near, one key, no menus deeper than one page in world
- [ ] T4 The first five minutes: where the player spawns, the coach's first lesson, the first sail
- [ ] T5 The design checked with a non-programmer's eye (Max) and written in `Documentation/BEACH_DESIGN.md`

### E05.S02 · The character on foot
Status: todo | Size: L | Owner: the lead | Milestone: M4 | Needs: E05.S01, E08.S05 | Roadmap: PR4
Done when: the sailor walks and runs on the beach terrain, up stairs and ramps, into shallow water, with a camera that works on any spot's beach, on keyboard, mouse and gamepad, at 60 fps with the fleet on the water.
- [ ] T1 A `CharacterBody3D` controller on the terrain mesh (collision from the terrain chunks near the beach only)
- [ ] T2 The camera on foot and its hand-over to the sailing camera
- [ ] T3 The animations from E08.S05 (idle, walk, run, carry)
- [ ] T4 Gamepad and keyboard; the mouse look

### E05.S03 · The gear hut
Status: todo | Size: M | Owner: the lead, Max for the look | Milestone: M4 | Needs: E05.S02, E06.S06 | Roadmap: GE4
Done when: the player carries the board and the rig to the hut (or the tent, shed, container), chooses gear there on a world panel (the gear page's content: brands, sizes, the fin slider, the quiver in the career), rigs up, and walks out with the new gear visible in the hands.
- [ ] T1 The hut per spot type and its interior panel
- [ ] T2 Carrying: pick up the board and the rig (one at a time, as in life? or both: Max), the figure's carry pose, the speed on foot with gear
- [ ] T3 The gear choice saved and sailed (as the page does today); the pause menu keeps the quick page (Q20)
- [ ] T4 The AI's gear visible on the beach racks (nice)

### E05.S04 · The watch tower
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E05.S02, E03.S05 | Roadmap: MA4
Done when: the player walks up the tower (or the dune, the club's terrace) and the view becomes the wind viewer over the spot: the gusts, the waves, the course, the clock, the tactics tools; the race director's table is there in LAN and in free sailing.
- [ ] T1 The tower per spot type and the hand-over to the viewer's camera from the top
- [ ] T2 The viewer's panels in the world's UI style
- [ ] T3 The course table (the course maker) on the tower; the director's panel for the LAN host

### E05.S05 · The beach start and the walk into the water
Status: todo | Size: M | Owner: the lead, Michiel for the hand-over | Milestone: M4 | Needs: E05.S02, E01.S12 | Roadmap: —
Done when: the player carries the gear into the water, and at knee depth a short scripted beach start hands the board and the rig to the physics with way on; coming back, the board is walked out; a fall far out ends in the water start as today.
- [ ] T1 The hand-over point and pose; the physics takes over with the sail filled and the board moving
- [ ] T2 The shore break's push at the start where the spot has one (E02.S06)
- [ ] T3 Coming ashore: the board stops at knee depth, the figure steps off and carries
- [ ] T4 The R key's "back to the start" becomes "back to the beach" where a beach exists

### E05.S06 · The race office and the notice board
Status: todo | Size: M | Owner: the lead | Milestone: M7 | Needs: E05.S02, E13.S03 | Roadmap: —
Done when: at the race office the player enters the day's races and reads the results and the rankings; the notice board shows the forecast, the season's calendar, the sponsors' letters and the story's notes.
- [ ] T1 The office's panel (enter, results, rankings)
- [ ] T2 The board's panel (the day draw, the calendar, the letters)

### E05.S07 · The coach
Status: todo | Size: M | Owner: the lead, Max for the lessons' words | Milestone: M4 | Needs: E05.S02, E07.S09 | Roadmap: UI2
Done when: a coach on the beach gives the five lessons of the control ladder (E07.S09), each a two-minute drill on the water with a pass mark and a plain-language debrief.
- [ ] T1 The coach's place and panel; the lesson's launch and return
- [ ] T2 The five drills (from E07.S09) and their pass marks
- [ ] T3 The debrief from the telemetry (why you fell, what to try)

### E05.S08 · Travel between spots
Status: todo | Size: S | Owner: the lead | Milestone: M4 | Needs: E04.S01, E05.S02 | Roadmap: —
Done when: a travel board (a map of the tour) on the beach is the one place with a loading screen; the player arrives on the next beach with the gear carried over; the season's calendar drives it in E13.
- [ ] T1 The map panel with the spots, their today's wind, the distance
- [ ] T2 The loading screen with the spot's photo and a tip

### E05.S09 · The menu-less flow
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E05.S02, E05.S03, E05.S04 | Roadmap: UI2
Done when: the game starts on the beach of the last spot (Silvaplana the first time), the start menu's every button has a place on the beach or in the pause menu, the LAN lobby is reachable from the beach, and a first-time player finds the water within a minute.
- [ ] T1 The start menu retired; the pause menu holds settings, controls, how to sail, credits, quit, the quick gear page, the LAN lobby
- [ ] T2 The loading of a spot at the game's start measured; a splash while it loads
- [ ] T3 A play-test by someone who never saw the menus

### E05.S10 · The beach on every spot
Status: todo | Size: L | Owner: Max | Milestone: M7 | Needs: E05.S09, E04 | Roadmap: MA3
Done when: every spot's story in E04 has its beach ticked (task 6 of the template) with the spot's own buildings and props from E04.S16.
- [ ] T1 Silvaplana's camping beach (the first)
- [ ] T2 Each spot as it is built

### E05.S11 · Later: others on the beach
Status: todo | Size: M | Owner: the lead | Milestone: later | Needs: E05.S09, E12 | Roadmap: —
Done when: LAN players see each other walking on the beach, the AI characters rig up and idle at the racks, and a race can be watched from the beach or the tower.
- [ ] T1 LAN players on foot
- [ ] T2 The AI on the beach (E09.S11)
- [ ] T3 Watching from the beach
