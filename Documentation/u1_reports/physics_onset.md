# U1 agent 4, `physics`: the planing onset (report)

**Stop rule fired: the fix makes four other checks fail, and its phase-in has no direct source. Nothing changes by default.**

**What the model misses.** A planing bottom gets less buoyancy than Archimedes: the water leaves the transom and the rails, so the pressure there is the air's. Zarnick (1978, p. 15) keeps half the static buoyancy, after Shuford's (1958) steady-planing tests. Savitsky's (1964) buoyant term gives 0.43 to 0.61 of Archimedes. Garme (2005) calls this the traditional correction. The grid gives full Archimedes, so at 21 kn the dynamic lift carries only 0.60 of the weight (Savitsky: about 0.8), and the onset waits until 13.3 kn.

**Built, switched off:** `BoardConfig.planing_buoyancy_factor` (default 1.0, the same as today). It is phased in over Faltinsen's (2005) semi-displacement range, Froude 0.4 to 1.0 on the hull's length. The push stays at the centre of buoyancy, because Savitsky's centre-of-pressure equation is exactly that split. Test added; spec 5 F21, 14, 16, 17.2.

**With 0.5** the onset is 9.9 kn, about the same in every wind, and the onset check is green. But the broad reaches ploughing or bouncing break four other checks (table). Both look like the sailor and the rig, not the hull (not proven): the sailor keeps the weight aft once the bow is up, and the mast foot carries 540 N (U1.2, U1.3).

**Options for Michiel:**
1. Turn 0.5 on after U1.6, U1.2 and U1.3, and test again (recommended; `tools/reach_check.sh --board.planing_buoyancy_factor=0.5`).
2. Turn it on now: validation goes from one red check to four.
3. Use Savitsky's value, which depends on the wet length, instead of one half: onset 11.8 kn, still red.

Either way the shape of the phase-in is an estimate. If it ends at Froude 1.2 instead of 1.0, the onset is 10.6 kn.

| | Factor 1.0 (default) | Factor 0.5 |
|---|---|---|
| Onset at 12, 15, 18, 24 kt (kn) | 16.0, 13.3, 11.0, 11.0 | 8.8, 9.9, 9.4, 9.5 |
| Dynamic share at full speed, 15 kt | 0.60 | 0.75 |
| 12 kt 135°: speed, trim | 5.73 m/s, 4.95° | 3.75 m/s, 9.27° |
| 24 kt 135°: pitch SD | 0.29° | 0.64° |
| Wet front at 18 and 24 kt, 100° and 135° (m) | 2.00, 2.24, 1.93, 1.93 | 1.94, 2.21, 1.94, 2.13 |
| Validation | 21 pass, onset fails, 2 pending | 18 pass: onset green; 24 kt 135° falls (2 checks), polar 150° too slow, a recovery run falls |

## Why the board is steady above Savitsky's flat-bottom limit

A bounce feeds itself when the water pushes the board up as hard on the way up as on the way down: then nothing takes energy out of the swing. Savitsky's limit (about 1.2° of trim on the 18 kt beam reach) comes from tank tests of flat, level plates. Under such a plate the water covers the whole width right from the spray root, so moving up or down hardly changes how much water it meets. A board is never that plate. It runs with 2 to 4° of heel and has a 1° vee in the tail, so just behind the spray root only part of its width is wet. When that part sinks, the water spreads across the bottom faster and more water is set moving: a harder push. When it rises, the water spreads less: a softer push. That difference brakes every bounce (Zarnick's 1978 rate of change of the water's momentum, already in the model). It is also why Day and Haag (1952) and Savitsky measured a higher limit for vee bottoms. Without heel and vee the model has no such brake: before U1 it bounced right at the limit, as agent 3 measured.
