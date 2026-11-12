# The dirty wind as it is on the water: research (13 November 2026)

Max, 12 November 2026: "the dirty wind is a disappointment and is straight downwind even when players are moving
forward. the dirty wind moves while speeding up. this way slalom starts are way more fair because the sailors are
sailing into the wind. research this." Then: "implement it like real life".

A research agent read the sources below (web only) on the night of 12 to 13 November. Each finding is marked
**solid** (measured or read in full), **plausible** (second-hand or read off a plot) or **estimate**.

## What the game did until 12 November

`WindShadows` laid a cone **straight down the true wind** from where each sail is now: 30 m long (six mast heights of a
4.9 m windsurf mast), 30 % less wind close behind (full for 5 m, then fading to nothing at 30 m), 2.5 m half-width at
the sail widening at 8 degrees, several shadows adding up to at most 50 %. A board going fast on a reach therefore threw
its dirty wind forward onto the boards ahead and to leeward of it: on a broad reach of 120 degrees the true wind blows
toward 60 degrees off the bow, to leeward.

## Findings

**1. The shadow lies along the apparent wind of the board that casts it, not the true wind.**
- Richards, Le Pelley, Jowett, Little and Detlefsen (2012), *Wind tunnel investigation of the interaction between two
  sailing yachts*, 18th Australasian Fluid Mechanics Conference
  (https://people.eng.unimelb.edu.au/imarusic/proceedings/18/279%20-%20Richards.pdf), read in full (**solid**): "the
  blanketing zone should therefore be aligned with the apparent wind rather than the true wind". The zone of lost drive
  lies along the apparent wind's line, bent a little toward the casting boat's stern: about 5 degrees upwind (apparent
  wind angle 20), about 9 degrees on a reach (60, asymmetric spinnaker).
- Marchaj, *Sail Theory and Practice* (1982), quoted by Richards (**solid**, second-hand): the wake is "deflected away
  from the line of the apparent toward the stern"; Hooper's J-class tunnel data show the least drive along the apparent
  wind's line.
- Caponnetto (1997), *International Shipbuilding Progress* 44(439), a vortex-lattice model (**solid**): the worst place
  at 22 degrees off the bow for an apparent wind angle of 25: along the apparent wind.
- Spenkuch, Turnock, Scarponi and Shenoi (2008 HPYD; 2011, *J. Marine Science and Technology*,
  doi 10.1007/s00773-010-0115-9): their race simulator sheds the sail's wake every time step as elements that drift with
  the local wind and decay: the trail the game now uses (method **solid**; the full text was blocked, no numbers).
- The physics (**solid**): the air a sail disturbs drifts on with the true wind; seen from the moving board it then lies
  along its apparent wind.

**2. Shape and strength.**
- The loss of drive on the wake's line, upwind (Caponnetto via Richards, **solid**): about -78 % at half a mast height,
  -60 % at one, -48 % at two (part of it a change of direction, not of speed).
- The wind speed at a third of the mast's height, upwind, in the tunnel (**plausible**, read off a colour plot): 22 to
  25 % less at 2 to 3 mast heights, 12 to 15 % less at about 4 (the end of the measured area).
- The direction changes in the wake (**solid**): about 4 degrees at 3 mast heights upwind (Richards); 10 to 13 degrees
  on the axis at 2 (Nivelleau's tunnel data in Roncin and Kobus 2004, *Sports Engineering* 7); more than 30 degrees in
  places close behind on a reach. A header for a board on the same tack.
- Roncin and Kobus 2004 (**solid**): upwind the effect is mostly the change of direction, on a run mostly the loss of
  speed; the deficit decays as 1/sqrt(distance) and does not depend on the speed.
- Width (**plausible**): the drive back to about 100 % one boat length to either side of the centre line (Hooper); the
  loss of speed in a narrow core, the change of direction about +-0.7 to 1 mast height wide (Roncin).
- Length (**plausible**, tactics books): 5 to 10 boat lengths (Marchaj; Dellenbaugh: about 10 in light air, 5 in
  strong; Horton and Powlison: 10 against 6; Ed Baird: 8 to 10 in light air): for a dinghy about 3.3 to 6.6 mast heights.

**3. The good places.** About +20 % drive in the "safe leeward" place, 0.6 boat lengths to leeward, abreast across the
apparent wind (Hooper and Marchaj, **solid**, second-hand); +5 % at most just behind and up to 30 degrees to windward of
astern in the tunnel (Richards, **solid**). Nothing beyond about one mast height.

**4. Drift and how long it lasts.** The wake moves with the true wind (**plausible**: Speer, Tillerman, Spenkuch);
SailGP sailors say the fleet's dirty air "travels down the course" and boats sail back into it after the bottom gate.
Nobody measured how long it lasts; because the decay goes with the distance behind the sail and not its speed, it lasts
about its length divided by the apparent wind (**estimate**): a 30 m shadow some 3 s for a planing slalom board, 6 to 7
s for a slow one. The same length in metres, closer to the track, fewer seconds.

**5. Windsurfing and slalom starts.** No measured data. Anecdotes only: John Skye (Windsurf Magazine, the slalom start
line): to leeward on the line, someone sailing over the top puts you "straight away in their dirty air ... and going
nowhere"; Sean O'Brien (Formula windsurfing): in planing conditions sail over the boards in the middle of the line,
taking their clean air.

A worked example (the agent's): 18 kt at 135 degrees off the bow, the board at 30 kt: its apparent wind is about 36
degrees off the bow at 21.5 kt, so its shadow trails 36 degrees off the stern to leeward (about 30 with the bend). The
same board at 8 kt in 12 kt: the shadow almost straight abeam to leeward. Stopped: 45 degrees ahead to leeward.

## What was built (13 November 2026, branch ai/roundings-13nov)

`Game/race/wind_shadow_trail.gd` (WindShadowTrail): every 0.25 s each sail that is up leaves a puff where it is; the
puff drifts with the true wind it was left in, turned up to `stern_bend_deg` (7, from Richards' 5 to 9) toward the
board's stern as seen from the board; a puff is as far down the wake as the air has moved past the sail since (the
apparent wind speed it was left in times its age) and is forgotten at `length_m`. `WindShadows` lays the shadow along
the trail, with the same strength and widths as the cone by the distance down the wake. A board that falls leaves no
new puffs; its old ones drift off and fade. A board put elsewhere (R, a drop) starts a fresh trail. The game, the LAN
guest, the training environment and the race tool all feed it; `follows_apparent_wind` in
`Game/config/wind_shadow_default.tres` (true) switches back to the old cone, and the race tool's `--shadow_trail=0`
does the same for one race. Tests: `Game/tests/unit/test_wind_shadow_trail.gd`.

**Not changed (Michiel's numbers, for him to decide with the table below):** the length (30 m), the deficit (30 %),
how it fades (full to 5 m), the widths, the cap (50 %). **Not built:** the change of the wind's direction in the wake
(the physics' `WindDisturbance` gives a factor only: a change in `Game/sim/`, Michiel's), and the gain in the safe
leeward place. **Not changed on purpose (Max: "the skippers need to adapt. but that is for later"):** the skipper's own
guess of where the dirty wind is (`WindShadows.factor_from()`, used by the slalom start's clean-wind spot) is still the
cone straight downwind.

## The agent's recommended numbers for a windsurf sail (mast height h = 4.9 m)

| Number | Value | Basis |
|---|---|---|
| Axis | a trail drifting with the true wind (along the caster's apparent wind) | Richards 2012, Spenkuch, physics (built) |
| Extra bend toward the caster's stern | 5 to 9 degrees | Richards 2012 (built: 7) |
| Deficit close behind | 25 % (20 to 30), strongest at 1 to 3 h (5 to 15 m) | plot reading; estimate (game: 30 %) |
| Decay | held to about 10 m, then to nothing at 25 to 35 m (about 12 % at 20 m) | plot reading and rules of thumb; estimate (game: held to 5 m, nothing at 30 m) |
| Length | 30 m in light wind, about 20 to 25 m planing | rules of thumb by mast height; estimate (game: 30 m) |
| Core half-width | 1.5 to 2.5 m, widening to about 3.5 to 5 m | Hooper, Roncin; estimate (game: 2.5 m, 8 degrees) |
| Change of direction | about 5 degrees close, fading with the deficit (a header on the same tack) | Richards 4, Nivelleau 10 to 13; estimate (not built) |
| Safe leeward gain | +2 to 3 % wind within about 1 h ahead to leeward | Hooper, Richards (not built) |
| Drift speed | 0.9 to 1.0 times the true wind | physics; a forum guess (built: 1.0) |
| Several shadows | multiply what is left, keep the 50 % cap | no source; estimate (game: added up, capped at 50 %) |

Gaps: the Spenkuch full text and the WindCheck pages could not be read; nobody gave a time in seconds for how long a
wake lasts, or numbers for fleets of more than two boats.
