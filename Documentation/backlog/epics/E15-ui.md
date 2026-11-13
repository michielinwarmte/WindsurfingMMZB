# E15 · The UI, the HUD and the menus

Owner: Max's eye, the lead | Roadmap: UI1 to UI11 | Questions: Q20, Q35

**Goal.** A screen that shows what a sailor sees and a racer needs, at any window size, on keyboard, mouse and gamepad; menus that live in the world (the beach) with a pause menu for the rest; results, rankings, season and career screens that are a pleasure to read; and one visual theme for the whole game (Max, 6 November 2026: "the UI and main menu is very AI-like, we need to pick a theme for our game to make it more united").

**Done when (1.0).** Every page of the start menu has its place on the beach or in the pause menu; the HUD, the race card, the standings, the mini-map, the gauges and the results fit any window size at the chosen UI scale; the gamepad navigates everything; the controls and the how-to pages match the game; the results, ranking, season, career and profile screens exist; colour-blind-safe buoys and flags; key remapping.

**Where things stand (6 November 2026).** The start menu (13 buttons and pages), the race page, the gear page (with the fin slider), the settings (wind, waves, sailing, body, graphics, audio), the controls and how-to pages (partly stale: they still say W/S sheet), the LAN page, the credits, the pause menu; the HUD with cards and gauges, the race card at the top, the standings down the right, the keys as chips, the mini-map with a size setting, the finish list in frame, UI scale 75 to 150 % for the in-game screen (not the menus), draw distance, the race types in the course maker (not on the race page), bigger marks and striped pins. 2D stretch for any window; sharp at Max's 3137 by 1263.

## Stories

### E15.S01 · Max's eye on the 6 November screens
Status: review | Size: S | Owner: Max | Milestone: M1 | Needs: the night3 build | Roadmap: UI7, UI8, UI9, UI10, UI11, GR10
Done when: Max has answered: the race card, the standings and the gauges' places; the mini-map's size; the finish list after a real race; UI scale for the menus too; the marks' sizes and the pins' pink; the LAN menu's board at the player's level.
- [ ] T1 The answers written into the roadmap rows; the follow-ups as tasks here

### E15.S02 · The controls and how-to pages rewritten
Status: todo | Size: S | Owner: the lead | Milestone: M1 | Needs: E07.S01 | Roadmap: UI2
Done when: the Controls page, the How to sail page and the README's controls table say what the keys do today (push on W/S, sheet on the arrows, the mouse body, Space with A/D, the cue), and the README's "Known gaps" is current.
- [ ] T1 The three texts rewritten; the gamepad's section when E07.S04 lands
- [ ] T2 The README's known gaps

### E15.S03 · The race page and the formats
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: E11.S03, E11.S04 | Roadmap: RA27
Done when: the race page offers the spot, the course, the race type and the format (a race, a series, an elimination ladder), the fleet by name or by level, and the day's conditions or a hand-set wind.
- [ ] T1 The race type and format on the page
- [ ] T2 The fleet picker by name (E10.S06 T2)

### E15.S04 · The in-world menu flow
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E05.S09 | Roadmap: —
Done when: the start menu is retired (E05.S09), the pause menu holds settings, controls, how to sail, the quick gear page, the LAN lobby, credits and quit, and the world's panels (the hut, the tower, the office, the board, the coach, the travel map) share one UI style.
- [ ] T1 The pause menu's new entries and the world panels' style
- [ ] T2 UI scale for the menus (UI10's open point)

### E15.S05 · Results, rankings, season and career screens
Status: todo | Size: M | Owner: the lead | Milestone: M7 | Needs: E11.S07, E13.S03, E14 | Roadmap: UI9
Done when: the results (a race, a series, a ladder), the ranking, the season's calendar, the event's table, the profile and the career's ledger, sponsors and quiver have their screens in the office and the pause menu, readable at any size.
- [ ] T1 The results and ranking screens
- [ ] T2 The season and career screens

### E15.S06 · The gamepad in every menu and panel
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: E07.S04 | Roadmap: UI2
Done when: every menu, settings page, world panel and the race screen can be used with the gamepad alone (focus order, the shoulder buttons for the tabs as today).
- [ ] T1 The focus order on the new pages and panels

### E15.S07 · Accessibility and options
Status: todo | Size: S | Owner: the lead | Milestone: M8 | Needs: — | Roadmap: —
Done when: the buoys and flags have a colour-blind-safe option, the HUD's text size follows the UI scale, the keys can be remapped in the settings, and a "reduce motion" option tames the camera.
- [ ] T1 Key remapping
- [ ] T2 Colour-blind buoys and flags; text size; reduce motion

### E15.S08 · Languages
Status: todo | Size: M | Owner: the team | Milestone: later | Needs: a decision | Roadmap: —
Done when: the team has decided whether 1.0 ships English only (the lead's recommendation) or adds Dutch; if so, the strings go through `tr()` and a translation file exists.
- [ ] T1 The decision
- [ ] T2 The `tr()` pass and the file, if yes

### E15.S09 · One theme for the game
Status: next | Size: M | Owner: Max and Michiel choose; the lead builds | Milestone: M2 | Needs: Q46 | Roadmap: UI6
Done when: the team has chosen one visual theme (a direction with a name, a moodboard, three colours, two typefaces, the shapes of panels and buttons, the sound of a click) written as `Documentation/STYLE_GUIDE.md`, and every screen that exists today (the start menu and its pages, the settings, the HUD's cards and gauges, the race card, the standings, the results, the LAN lobby, the course maker's panels) follows it, so nothing looks generated and everything looks like one game; the world's panels of E05 and the screens of E13 and E14 are built in it from the start.
- [ ] T1 Three directions as moodboards with one screen each mocked up (for example: the race-broadcast look of a PWA live stream; a beach-club and surf-poster look; a clean instrument look like a GPS watch), from Max's references
- [ ] T2 The choice (Q46) and the style guide
- [ ] T3 A `Theme` resource and the HUD style (`HudStyle`) rebuilt from it; the fonts' licences noted
- [ ] T4 Every existing screen restyled; screenshots at 1280 by 720 and 3137 by 1263 checked by Max
- [ ] T5 The rule in CLAUDE.md: new UI reads the theme, no ad-hoc colours or fonts
