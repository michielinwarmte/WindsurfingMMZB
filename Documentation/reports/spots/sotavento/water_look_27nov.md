# Sotavento's water set to the stream's (27 November 2026)

Max, looking at the game beside the PWA stream of the same beach: "the water shader really is off and the vibe is really off. try to match the water look". Branch `gr/sotavento-water-look` (from `spot/sotavento` 86275b8). Not seen by Max on his screen yet.

## What was measured

`tools/broadcast/water_look.py` (on the branch `broadcast/study-27nov`) cuts the water between the horizon and the picture's bottom into five bands, far to near, and measures the water's own colour, the share of white water and the texture (how much the brightness varies). The stream: one frame from each of 102 drone shots of the nine slalom heats of the World Cup Fuerteventura 2026. The game: two screenshots from a drone's place (8 m above the water, 400 m off the tower, a 47 degree lens, 30 kt of wind), one towards the land and one out to sea.

| Band | The stream (R G B) | The game before | The game now |
|---|---|---|---|
| 1, far | 51 123 150 | 48 68 94 | 66 125 162 |
| 2 | 42 126 149 | 29 79 108 | 38 132 156 |
| 3 | 35 123 145 | 28 108 125 | 32 134 152 |
| 4 | 22 120 137 | 30 128 133 | 30 136 150 |
| 5, near | 20 122 133 | 35 140 138 | 29 137 148 |
| White water | 3 to 6 % (0.6 to 8.9) | 2 % | 3 to 3.6 % |
| Texture | 0.18 to 0.26 | 0.08 to 0.19 | 0.10 to 0.12 |
| The sky just above the horizon | 166 178 204 | 190 192 192 | 164 174 190 |

## What was wrong, and what changed

1. **The far water went navy, almost black.** The shader measured how much water the light passes along the straight line of sight, so far away the look "passed through" tens of metres of water and lost the sandy bottom's glow. Light bends steeply down into water (at most 48.6 degrees from straight up), so shallow water over sand stays turquoise far out. New: `refracted_bed_path` in `Game/world/water.gdshader`.
2. **A rough sea was treated as a mirror at a glancing look,** and the engine's mirror fades on rough water, so the far sea got neither its own colour nor the sky's. New: `mirror_most` (how much of a flat sea's mirror a pixel keeps) and `sky_fill_color` (the sky each small face mirrors).
3. **The surface was smooth:** on a lake's or a sea spot's own waves the ripples' normal map was left out. New: `lake_ripple_strength`.
4. **Sotavento's own settings** (`sotavento_water.tres`): the water takes more green and red out (absorption 0.6, 0.115, 0.05 per metre), bluer own colours, more and smaller whitecaps in rows along the wind (`whitecap_water_factor` 1.6, `whitecap_active_share` 0.6, `foam_life_s` 1.6, `whitecap_fray_scale` 0.5, `wind_rows_strength` 1.0, rows of 60 by 7 m), ripples at 4 m.
5. **The air** (`sotavento.tscn`): the haze three times thicker (fog 0.00013 per metre: land 15 km away nearly gone, as in the stream) and bluer; the sky near the horizon bluer.

The four new shader values are off by default, so the open water and Lake Silvaplana are drawn as before. `tools/check.sh`: 538 files, 0 failed. The Sotavento tests pass. Also new: `--overview_fov=<degrees>` on a spot's fixed camera, for pictures to set beside a real camera's.

## Still different

- **The chop's light and dark.** The stream's sea is mottled: every wave has a dark face and a pale back, and the boards leave long white wakes. The game's is evenly lit with small white flecks; its texture number is about half the stream's. A try at mirroring the sky per wave face made the far water pale and the surface flatter, and was pulled back to a light touch. This needs the waves themselves drawn with more relief near the camera (and perhaps a bigger chop off the beach in this wind, which is the sea's physics and Michiel's to OK).
- The stream's two drones grade their pictures differently (one blue and saturated, one grey-green); the numbers above are the middle of both.
- The game's near water is about 10 % brighter than the stream's.
