# 01 · Sotavento speed run: first reading

**Status (25 Nov 2026): first reading, then Max's answers (below).** The full, updated write-up
(the automatic labels, the gear sizes, the wind direction, the ideas for the game) is in Max's
Claude Doc "Windsurf video analysis"; see [INDEX.md](INDEX.md). Times are video seconds.

**Max's answers (25 Nov 2026):** 1. real speed: he floats because the sail makes lift at that
angle. 2. Gear: JP Slalom 62(.5), 233 x 62.5 cm, 97 l (jp-australia.com); NeilPryde RS:Racing
EVO 5.6, luff 426 cm, boom 174-180 cm, mast 400 (dealer page, 2026 model). 3. The loose arm is
showing off; shots C and D are different gybes. 4. Wind direction unknown: measured from the
video as offshore, probably closer to straight offshore than cross-offshore from the left
(estimate). 5. The colours may be the uploader's grading.

**Automatic labels** (`python tools/video/analyse.py 01_sotavento_speedrun`, checked on the
frames): straight A, B, C, E; gybe D 12.87-14.57 s; jump F 18.17-20.27 s (frame by frame
17.80-20.15 s); water chop in A, B, E, rough in F, none in the close-ups. Board speed could not
be measured (no fixed point; the wake travels with the board).

Video: https://youtube.com/shorts/yWc4jUGIm7c ("Fuerteventura: 30+ knots offshore", uploaded
20 Nov 2026). Max's context is in [INDEX.md](INDEX.md#01-sotavento-speed-run-added-25-nov-2026).

## The video itself

- 21.4 s, 720 × 1280 (the uploader's best quality), a 30 fps file.
- **25 real pictures per second:** every 6th frame is an exact copy of the one before (107 of 638
  frames). The editor put 25 fps footage into a 30 fps file. Timings are therefore in steps of
  0.04 s, and the edit did not stretch the clip.
- **Not known: whether the drone itself filmed in slow motion** (for example 50 fps played at 25).
  That would make everything slower than real by the same factor. Question 1 below.
- Six drone shots (hard cuts measured frame by frame):

| Shot | Time (s) | Camera | What happens |
|---|---|---|---|
| A | 0.00–3.90 | High, looking at the sandbank and the beach | Straight-line speed just outside the sandbank; another sailor jumps in front (0.0 s) |
| B | 3.93–11.17 | Looking out to sea, horizon in view | Long straight run parallel to the beach, spray blowing away |
| C | 11.20–12.77 | Close, beside him | One hand on the boom, then he starts to carve into a gybe |
| D | 12.80–14.83 | Close, from above | The gybe: carve, sail flip, sheet in, planing away |
| E | 14.87–17.23 | From behind, looking out to sea | Sailing out between the swell lines |
| F | 17.27–21.41 | Looking at the beach and the lagoon | A jump off a chop/swell, rig laid flat in the air, landing and sailing on |

## For the map (Sotavento is spot E04.S12; colour by depth is E02's task T3)

**The layout, seen from the sea towards the land (shots A, B, F):** deep blue open sea with a
fairly sharp border to a **turquoise band** over sand, where he sails → the **sandbank**, dry at
the moment of filming, with a line of **breaking whitewater** on its seaward edge → the **lagoon**,
pale and greyish, flat with small ripples, full of sailors → the **beach** → low scrub, white
buildings and palms (the hotel area), then bare brown-pink hills (shot F).

**Colours measured** (the median of each box; the boxes are drawn on the frames in
`colours/`, see the file list at the end). These are the colours the camera and the uploader's
grading produced, not the true colours, so the **steps between them** are the useful part.

| Surface | Shot A (0.5 s) | Shot B (7.0 s) | Shot F (19.6 s) |
|---|---|---|---|
| Deep sea, far out | | `#2b4c7a` | |
| Sea, mid distance | | `#24547d` | |
| Turquoise band over sand | `#59a59b` (near `#4f9b90`) | `#458790` | `#599194` |
| Shallow water right below the drone | | `#80a896` | |
| Whitewater on the sandbank | `#ede9ed` | | |
| Sandbank, dry sand | `#dac4bd` | | `#d8c1be` |
| Lagoon water | `#aab4b2` | | `#a6b5ba` |
| Beach beyond the lagoon | `#f4dcd1` (far, bright) | | `#c5b7b4` |
| Land, dunes and hills | | | `#cfb5b0` |
| Sky near the horizon | | `#b3c0db` | |

- The same surface measured in two shots agrees closely (sandbank `#dac4bd` / `#d8c1be`, lagoon
  `#aab4b2` / `#a6b5ba`), so the numbers are stable within this video.
- The turquoise looks bluer in shot B (`#458790`) than in A and F (`#59a59b`, `#599194`). Shot B
  looks at the water at a flatter angle, so it shows more reflected sky.
- The sand comes out pinkish-beige. That may be the uploader's grading. Question 5.
- The lagoon is far paler and greyer than the sea outside: very shallow water over sand (the
  spot dossier says 35–85 cm at high tide).

## Water

- **Two wave systems at once:** short wind chop with **many small whitecaps** everywhere,
  densest on the deep blue water (fits 30+ kn), and **longer swell lines** coming in from the sea
  (dark bands in shot B; clear crest lines in shot E).
- **The swell breaks on the sandbank** as a line of whitewater (shots A and F). Inside the
  sandbank, in the lagoon, the swell is gone and only ripples are left.
- **Offshore wind against the swell:** in shot E (16.1–17.1 s) the crests in front of him feather.
  The wind blows spray back off the top of the swell, out to sea. This look belongs with the
  offshore spots and the wave shader.
- The chop runs in streaks along the wind (shots B and F).

## Wind

- **Offshore:** the title says so, and the frames agree. In shot B the camera looks out to sea
  and sees his back, so the wind blows from the beach side towards the sea. The spot dossier says
  "cross-offshore from the left". Question 4.
- **Spray is blown into clouds:** the spray off the tail does not just fall back. It blows
  downwind as a cloud (shot B 4.4–5.4 s). The spray from the jump's take-off hangs and drifts
  for about 1.5 s (shot F 17.8–19.4 s) while the camera follows him.

## Board

- **Planing flat on the tail,** with a wide sheet of spray off the back (shots A, B, C).
- **The board keeps planing through the whole gybe:** spray comes off the tail all the way through
  shot D, including while the sail flips (13.8 s).
- **The jump (shot F), timed frame by frame on zoomed grids:**
  - take-off off a chop or swell crest: **17.80 s** (spray from 17.67 s; the board is clear of
    it from 17.80–17.87 s);
  - landing, tail first: **20.15 s** (the tail touches at 20.15 s, the board is flat at 20.18–20.22 s,
    and he planes on at once with no visible loss of speed);
  - **in the air for 2.35 s ± 0.1 s of video time.**
  - Gravity check: in pure free flight (no lift from the sail), 2.35 s in the air would need about
    **6.8 m of height** (h = g·t²/8). Less if the sail carries him, and it may well do that,
    see the rig below. If the drone filmed at 2× slow motion: 1.2 s and about 1.7 m.
    **Do not use either number before question 1 is answered.**
  - His shadow is visible on the water during the jump (shot F, around 19.8–20.1 s). With the
    time of day, the gap between rig and shadow could give the height. Not done.

## Sail and rig

- **Straight line (shots A, B, C):** mast raked back and towards the wind, the foot of the sail
  sheeted down close to the deck (gap closed), **the mast bending back at the top and the top of
  the sail twisting open** to leeward, letting the gusts through (best seen at 11.25–11.75 s).
- **The gybe (shot D):** the rig leans into the carve (12.8–13.5 s); the **sail flips from about
  13.6 s to 14.2 s** (about 0.6 s); sheeted in and pulling again at about 14.5 s.
  - Game comparison: the drawn rig (`Game/windsurfer/drawn_rig.gd`) turns the sail at 5 rad/s
    with a 0.35 s minimum, so a half turn takes about 0.63 s. That's the same as the video,
    *if* the video is at real speed.
  - Shot C ends with the carve starting (12.4–12.77 s), but the cut to D may skip time, so the
    whole gybe can't be timed as one piece.
- **The jump (shot F):** right after take-off he **lays the rig flat** (flat by about 18.3 s) and
  holds it horizontal above him until about 19.8 s. Then he swings it upright again for the landing
  (upright at about 20.2 s). A flat sail in 30+ kn works as a wing, which would explain a long
  float.

## The sailor: controlling the whole rig

- **Straight line:** hips out and low, long arms, hooked into the harness, weight on the back foot,
  head up.
- **Shot C (11.2–11.9 s):** he sails at full speed with **one hand on the boom** and the other arm
  hanging loose. All the load is in the harness and the feet.
- **The gybe:** knees bent and weight forward into the carve, then the feet change and the sail
  flips while the board still planes, then the front arm reaches forward and he sheets in.
- **The jump:** he lifts the board off a crest, then lays the rig flat and keeps it there (rig
  control in the air), and brings it upright to land tail first, so he keeps planing.

## Questions for Max

1. **Real speed or slow motion?** Watch the gybe and the jump. Does it look like real time to
   you, or slowed down? (This decides the jump's height and every timing above.)
2. **Scale:** the board's length (you said about 62 cm wide) and the sail's mast or luff
   length. With those I can measure the swell spacing, the gybe's radius and the jump's height.
3. **Shot C to D:** is the gybe in D the same carve that starts at the end of C, or did the
   editor cut to another gybe?
4. **Wind direction:** straight offshore, or cross-offshore from the left (the dossier) on that
   day?
5. **Colours:** do they look right to you, especially the pinkish sand? Which ones do you want
   for the map?

## Files (outside git, in `C:/Users/Max de Dikke/source/WindsurfingMMZB-videos/01_sotavento_speedrun/`)

- `original_yWc4jUGIm7c.mp4` and `.info.json`: the download, never overwritten.
- `grids/`: the whole video at 1 picture per second; each shot denser (A 5/s, B 4/s, C 10/s,
  D 10/s, E 5/s, F 8/s); zoomed full-rate grids of the take-off (17.55–18.05 s), the landing
  (19.85–20.40 s) and the close-up (11.25–11.95 s).
- `colours/`: the three frames with the colour boxes drawn on them.
- `frames/`: the full-size single frames used (0.50, 7.00, 13.80, 19.60 s).
- `frame_motion.txt`: how much each frame changes from the one before (the cuts and the copied
  frames come from this).

Made with `tools/video/video.py`, `tools/video/frame_motion.py` and
`tools/video/sample_colours.py`.
