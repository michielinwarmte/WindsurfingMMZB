# F1: the sea query (agent sea_query, 20 October 2026)

Branch `f1/sea_query`, from `feature/p9-racing` at c927332, 3 substeps. No formula changed.

**What changed.** The models ask the sea once per point per substep (`WaterSurface.sample_at`). On waves there is one solve of 9.5, with the same 1 mm tolerance and cap of 8. It starts from the same point's answer a substep ago: the new point less that answer's sideways displacement, which takes 1.3 passes where a cold start takes 2.5. One pass over the waves then gives the height, the normal and the velocity. The grid keeps its 21 answers. The hull reuses the centre column's answers (the same `point_world`, checked) and keeps its own for its 27 other points. `reset()` forgets them all. The answers are numbers in a packed array: an object per point (a first version) made eight boards on threads twice as slow.

**The same answers?** A cold solve gives the old answers bit for bit. A warm one is within 0.002 mm in height, 3e-6 in the normal and 1.3e-5 m/s. Flat water is bit for bit the same, so the reach check and the 18 kt matrix are identical. On waves the 120 s beam reach keeps every printed mean, maximum and minimum; two last-tick values moved by 1 N (fin lift 480 to 479, planing lift 226 to 225), less than a 0.001° nudge of the start heading moves them. The skipper races moved likewise: times by 0.4 to 6 s, and the 24 kt fall is gone. Every assertion passes.

| | Before | After |
|---|---|---|
| Bench: `height_at` / three answers / one solve and three `_rest` / one wave sum (µs) | 3.9–4.0 / 12.5–12.8 / 6.2–6.6 / 0.96 | 3.3–4.1 / 10.5–13.6 / 5.5–6.1 / 0.91–0.97; **the warm sample: 3.5–4.3** |
| A board's tick on waves (bench) / the sea in it (ms) | 2.42–2.59 / 1.36–1.48 | 1.60–1.76 / 0.47–0.62 |
| `simulate.sh beam_reach 120 --waves=1` (s) | 22.1–22.5 | 17.5 |
| Game, 4 boards, per board (editor) / one board alone (ms) | 3.56–3.76 / 2.48–2.53 | 3.00–3.13 / 1.84–1.86 |
| Release race, all boards' physics per tick: 4 / 8 boards (ms) | 2.79–2.82 / 4.11–4.28 | 2.20 / 3.91–4.09 |
| Reach check and 18 kt matrix identical | | yes, yes |
| Unit tests; validation | 446/446; lead: 40 pass, 1 fail, 2 pending | 453/453; 40 pass, 1 fail (onset), 2 pending |

**Not gained:** at eight boards on threads the physics is level with before. The time there most likely goes to waiting: reading another object's field takes a global engine lock, and the physics reads `board.*` and `body.*` everywhere.
