# LAN multiplayer: two players and the AI fleet (plan and progress)

**The ask** (Max, 3 November 2026, Session 69): "research LAN multiplayer for 2 people with AIs. Full physics synced rigs. All of it. ... make the full plan and do it yourself and test and make decisions yourself. If possible full rig sharing in position of player and rig. Rules: game host and game join. Admin can choose map, wind etc." And during the work: "document on the fly so we don't lose information."

**Max's quick answers before he left:**
1. Branch from `gp/sea-follows-wind` (the beta.2 work, 4 commits not pushed): the branch is `mp/lan`. **Push nothing.**
2. At the end a test build: a `0.2.0-beta.3` zip in `.release/`, nothing published.

**Who builds:** Claude Opus 5.5 alone, no agents (Max: "do it yourself").

This file is the live state of the work: the design, the steps, and at the end the progress log. If the session stops, the next one reads the progress log at the bottom and continues.

---

## 1. What the code has today (the facts the design rests on)

- **One board = one `WindsurferNode`** (`Game/windsurfer/windsurfer.gd`) that owns a `WindsurferSim` (`Game/sim/windsurfer_sim.gd`, plain GDScript, no engine physics) and copies the sim's state onto the visuals each tick (`_copy_state_to_visuals()`: the board's transform, the rig (`RigVisuals`), the sailor (`SailorFigure`), the effects (`WindsurferEffects`)). Nothing visual feeds back into the physics (rule 2).
- **The visuals read many sim fields**, not just the board's place: the body (origin, basis, velocities), the rig frame, the sail (mast and boom directions, lift, drag, side, backwinded, ...), the fin (bend, force, centre of pressure), the hull, the buoyancy, the sailor's posture (stance, lean, feet, hands, harness tension, trim press), the fall (kind, side, time fallen) and the telemetry. A second player's board that should look exactly like the owner's needs **all of that**, not a position and a heading.
- **How much state is that?** Measured (a probe in the scratchpad, 3 November 2026): the sim and its parts (body, sailor, mass model, buoyancy, hull, fin, sail, rig frame, telemetry) hold about **2.7 kB of numbers** (floats, ints, bools, vectors, bases, two strings), plus scratch arrays the physics rebuilds every tick. A large part is constants worked out once from the gear (the `_xxx` fields of `WindsurferSim`).
- **The physics runs at 60 ticks a second** (`physics/common/physics_ticks_per_second` = 60).
- **The wind has no dice:** `WindField` gusts and shifts follow from the config and the field's own clock (`time_s`, `travel_m`, and on the lake the time of day). A race already keeps every board on one clock with `RaceWindClock` (RA13). Two PCs with the same settings and the same clock have the same wind.
- **The waves have no dice either:** `WaveField` is built from the `WaveSetConfig` alone; the water's height depends on the board's own `sim.time_s` (reset to 0 at `sim.reset()`). Two PCs must keep the boards' `time_s` on one clock, or the same wave is in a different place.
- **The race** (`Game/race/race_sim.gd`, `RaceSim`) is a plain class: the clock, the phase, and per board the next step, the splits, the finish time, the penalty, OCS and the wrong-side warning. `RaceRules` (`race_rules.gd`) judges right of way and penalties. `RaceRunner` (`race_runner.gd`) builds the AI boards, steps every board's physics (side by side on worker threads), poses them, and tells the race where they are. `RaceHud` reads the race and the rules.
- **The settings** (`ui/settings_values.gd`, autoload `GameSettings`) hold the wind, the waves, the controls, the graphics and the gear choice, saved to the player's file.
- **No board collisions exist** (RA3/PH12 are 0.3 items), so multiplayer adds none either.

## 2. The design (decisions made by Claude, with the reasons)

| # | Decision | Why |
|---|---|---|
| D1 | **Godot's own networking: ENet** (`ENetMultiplayerPeer`) with RPCs on one autoload node, `Lan` (`Game/net/lan_session.gd`), present at the same path on both PCs. Port 47520 for the game (UDP). | Built into Godot 4.7, works in the exported game, reliable and unreliable channels, no extra library. |
| D2 | **Host and guest.** The host is the admin: it picks the map (open water or Lake Silvaplana), free sailing or a race, the wind and the waves, the course, the laps, the AI fleet and its level. The guest sees those settings (read only), picks its own name and gear, and says Ready. The host presses Start. At most 2 players (`Lan.MAX_PLAYERS`), the code written for N where it costs nothing. | Max: "rules game host and game join, admin can choose map wind etc."; "for 2 people". |
| D3 | **Each PC sails its own board's full physics; the host also sails every AI board's.** Nothing is simulated twice. | Rule 7 (every board the same full physics) holds; no one waits for the network to steer; the AI already runs on the host's threads. |
| D4 | **What travels is the board's whole physics state, not a position.** Every tick the owner sends a snapshot of the sim and its parts (body, sailor, mass model, buoyancy, hull, fin, sail, rig frame, telemetry: every number the visuals, effects, HUD and race read). On the other PC the board is a **puppet**: a real `WindsurferSim` with the same gear that is not stepped; the snapshot is written into it and the normal visuals pose it. So the other player's rig, sail shape, sailor's posture, falls and spray are exactly what their physics did. | Max: "full physics synced rigs, all of it, full rig sharing in position of player and rig". Writing the state into a real sim means the visuals need no new code and stay right when Michiel changes the physics. |
| D5 | **The snapshot's layout comes from the scripts themselves** (Godot's property list of each object, in a fixed order), and both PCs check it matches at connect (a hash with the game version). Constants do not travel: each board first sends one full **keyframe** (reliable), after that each snapshot carries only the numbers that differ from it (a bit mask plus those numbers). | A hand-written list would go stale with every physics change; the keyframe makes the constants free without any acknowledgement logic. |
| D6 | **Players' boards every tick (60 Hz), AI boards every 2nd tick (30 Hz)**, on the unreliable-ordered channel. The receiver keeps a small buffer and shows each remote board about 2 ticks behind its newest snapshot, interpolating between snapshots (floats and vectors in between, rotations by slerp, angles across 360 taken as they are, on/off values from the nearer snapshot). | Smooth on screen without waiting; to be measured and tuned (the bandwidth is in the progress log). |
| D7 | **One clock: the host's.** Every snapshot from the host carries its tick, the water clock and the wind clock (`RaceWindClock`). The guest keeps its own board's `sim.time_s` and wind field on the host's clock (corrected each tick by a few milliseconds at most). | Same waves and same gusts under every board on both PCs (section 1). |
| D8 | **The race is the host's.** The host's `RaceRunner` holds every board: its own, the AI boards (stepped) and the guest's puppet (not stepped). The race and the rules judge the guest's board where it is **now**: its last place moved on by its speed for the ticks the snapshot is old. The host sends the race's state (clock, phase, every board's step, splits, finish, OCS, penalties) 10 times a second; the guest's `RaceSim` and `RaceRules` mirror it and do not judge themselves, so both screens show the same places and results. | One judge, no disagreement; the age correction keeps the guest's start and finish times fair. |
| D9 | **Finding a game:** the host announces itself on the LAN (a UDP broadcast once a second on port 47521: game, version, host name, players); the Join page lists what it hears, and an IP address can be typed too. | Two PCs at home should find each other without typing; typing covers networks that block broadcasts. |
| D10 | **Keys in a network game:** the game never pauses (Esc opens the menu but the water keeps going); R waterstarts after a fall; only the host restarts the race (pause menu), for everyone. A guest that leaves loses its board on the host's screen; a host that leaves ends the game for the guest with a message. | A shared race cannot pause for one player; one admin. |
| D11 | **The guest's own settings file is never changed by the host's choices**: the host's wind, waves and map are applied for the session only and the guest's own come back afterwards. | Don't lose the guest's settings. |

## 3. The steps

| Step | What | Test |
|---|---|---|
| M1 | **The snapshot** (`Game/net/board_state.gd`): the layout from the scripts, the keyframe, the diff, encode/decode, interpolation, writing it into a puppet sim. | Unit tests: round trip, a puppet equals the original after apply, interpolation halfway, angle wrap; the size in bytes. |
| M2 | **The session** (`Game/net/lan_session.gd`, autoload `Lan`): host, join, the handshake (version and layout hash), the lobby (players, names, gear, ready), the host's game settings, discovery. | Two headless Godots on this PC connect, exchange the lobby and disconnect cleanly. |
| M3 | **Free sailing together** (`Game/net/net_boards.gd` in the sailing scene): puppets for the other player's board, the snapshots both ways, the shared clock. | Two Godots: the host's view of the guest's board equals the guest's own within the interpolation delay; screenshot from the guest showing the host's board. |
| M4 | **Racing together with the AI fleet:** `RaceRunner` with remote boards (host) and as a mirror (guest); the AI puppets on the guest; the race state and the rules mirrored. | Two Godots race T1 with AI boards headless: both finish lists agree; places and splits match. |
| M5 | **The menus:** the Multiplayer page on the start menu (Host / Join, name, found games, IP), the lobby (host: map, mode, wind and waves, race page; guest: read-only summary, gear, Ready). | Screenshots of the pages; a full run host and join through the menus by command-line options. |
| M6 | **Documentation, the roadmap item, the changelog, `0.2.0-beta.3` zip** in `.release/` (not published). | `tools/check.sh`, `tools/test.sh`, the release build's two-instance smoke test. |

## 4. What cannot be verified on one laptop

- Two real PCs over Wi-Fi or a cable (tested here: two game instances on the same PC through 127.0.0.1, and the discovery broadcast on the loopback). The real-network test is Max's with the beta.3 zip on both PCs.
- **Windows Firewall** will ask, the first time the game hosts, whether to allow it on private networks: say **Allow**, or the guest cannot connect.
- How it feels to race the other player.

---

## Progress log (newest first)

### 3 November 2026, Session 69
- Branch `mp/lan` made from `gp/sea-follows-wind` (12ca5f1).
- Read: `main.gd`, `race_runner.gd`, `windsurfer.gd`, `race_sim.gd`, `race_wind_clock.gd`, the wind field's state, the settings' fields; the sim's state measured (2.7 kB per board, 60 Hz physics).
- This plan written (D1 to D11, M1 to M6).
