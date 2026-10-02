# Physics Specification

Written for Phase 1 of the [rebuild plan](REBUILD_PLAN.md) in Session 29 (28 September to 2 October 2026). This is the engine-neutral description of every force model in the windsurfing simulator, taken from the Unity version in `Legacy/` and translated into the conventions the Godot rebuild uses (plan decision D4). Phase 2 builds `Game/sim/` from this document alone, without opening `Legacy/` again.

**Core mechanic (plan decision D8).** The game simulates real windsurfing physics; it does not imitate it. Every force below comes from a physical model with real-world coefficients and real equipment dimensions, and the speeds, the fastest point of sail, the planing onset and the response to the controls are outcomes of the simulation, never numbers we choose. There are no behaviour targets, no speed caps and no artificial torques. The Unity version is used as a list of lessons (section 12), not as a reference for behaviour; section 14 gives real-world ranges for Phase 4 to compare against, and a disagreement means a model error to find.

## How to read this document

- **Section 0** defines the frames, signs and names every other section uses. Read it first.
- **Sections 1 to 10** describe one model each: what it does, the formulas, the numbers and where they came from, where the force acts, the sign traps when translating from Unity, the stabilisers that were bolted on, what Phase 2 must build, and the tests it should write.
- **Section 11** is the master table of every tuning value, with its legacy sources and the value the rebuild starts with.
- **Section 12** is the register of every stabiliser and fudge in the legacy code, each with an identifier (`F-01` to `F-36`) and a keep / drop / re-evaluate recommendation. The default is to start without them.
- **Section 13** resolves the contradictions between the legacy documents, the legacy code, the setup wizard and the scene file.
- **Section 14** chooses the default equipment (a real freeride setup) and gives the real-world plausibility ranges Phase 4 compares against.
- **Section 15** records the decisions that settled the former open questions under D8, and the model checks Phase 4 must run.
- **Section 16** is the tuning log. Every coefficient change from Phase 2 on is recorded there, with the reason.

Formulas are written in plain text so they read the same in a terminal and in a Markdown viewer: `*` or `×` multiplies, `^` or `²` is a power, `sqrt()` is the square root. Every quantity inside the simulation is in SI units (metres, seconds, kilograms, newtons, radians); degrees, knots and km/h appear only in tables and are marked as such. Formula labels such as `F0.8` (section 0, formula 8) or `F11` inside section 5 are local to their section.

A source such as `AdvancedSail.cs:296-355` means that file under `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/` (each section gives the full path the first time it names a file). Line numbers refer to the files as they are in the `Legacy/` folder, which is frozen. `MainScene.unity` is `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity`; "commit b5ed2ea" and similar refer to this repository's git history, where the Unity project lived before it was moved to `Legacy/`.

## Six things about the Unity version that its own documents do not tell you

The sections prove each of these; they are collected here because they change how every legacy number should be read.

1. **The scene file holds the values that ran, and they are not the documented ones.** Unity keeps serialised inspector values in `MainScene.unity`, and they override the C# defaults. The scene was written once by the setup wizard in Session 22; the C# defaults were changed in Sessions 24 to 26 without rewriting the scene. The last played scene (commit b5ed2ea, Session 26) therefore still had the Session 22 numbers: vertical damping 800 (docs say 4000, code 8000), planing lift coefficient 0.15 and cap 0.4 (docs say 0.8 and 0.85, code 1.0 and 1.0), submersion drag multiplier 3 (docs and code 12). Sections 11 and 13.
2. **The planing lift that was play-tested was at most 6 % of the weight** (0.4 × 0.15), and it was a speed ramp, not the Savitsky formula the docs describe: the Savitsky code existed for one commit on 1 January 2026 and was replaced the same day. Section 5 F13 and F14, section 12 F-26.
3. **The body weighed 94 kg while every weight-based cap used 91 kg.** Two components carried their own masses. The centre of mass was forced to 0.15 m above the board centre, and the inertia came from the 0.6 × 0.12 × 2.5 m box collider (roll 2.9 kg·m²), fifteen times too easy to roll for a body that is 80 % standing sailor. Section 7.
4. **The sail force acted at the board origin** since Session 26 (no heeling moment, no weather helm, no geometric rake steering), which is why the rake, pitch, anti-capsize and weight-shift couples were needed. Sections 2, 3 and 12.
5. **The sail side was set by the Space key, not by the wind**, and the legacy true wind angle had the opposite sign of the legacy apparent wind angle. The port and starboard tables in `PHYSICS_VALIDATION.md` are the wrong way round; the code is right. Sections 0, 1 and 13.
6. **The validated runs were on flat water in 15 kt from the West** (the Session 26 commit stored 22 kt, unexplained), with gusts of 20 % on and the wind sampled at the board origin, so the sail saw 72 to 100 % of the configured wind depending on how high the hull floated. Sections 8 and 9.

## The default configuration at a glance

Chosen in section 14 as a real, common freeride setup (section 15, Q3). Every test and the default `.tres` files use these values.

| Item | Value |
|---|---|
| Board | 120 L, 2.40 m × 0.72 m × 0.12 m, nose rocker 0.08 m, tail rocker 0.02 m, 9 kg |
| Sail | 6.5 m², luff 4.60 m, boom 1.95 m, mast 4.60 m, camber 0.10, boom 1.40 m above the mast foot |
| Mast foot | (0, +0.06, −0.05) m in the body frame: on the deck, 0.05 m forward of the board centre |
| Fin | 38 cm, 0.0365 m², mean chord 0.096 m, aspect ratio 3.96, root at (0, −0.06, +0.90) m |
| Masses | sailor 75 kg, rig 8 kg, board 9 kg: 92 kg in total (902.5 N), floating 74.8 % submerged at rest |
| Test conditions | 15 kt (7.717 m/s) steady wind from 270° (West), flat sea water of 1025 kg/m³ |

The **worked examples and hand-calculated test values in sections 2 to 7 and 11 use the legacy configuration instead**, because that is what the legacy code was checked against: a 2.5 × 0.6 × 0.12 m hull, luff 4.7 m, boom 2.0 m, fin 0.035 m² and 0.40 m deep, 91 kg (hull model) or 94 kg (rigid body). The formulas are the same; a test that reproduces one of those numbers builds the legacy configuration explicitly, and the default configuration is validated in Phase 4.

## Contents

- [0. Conventions and notation](#0-conventions-and-notation)
- [1. Apparent wind and sailing state](#1-apparent-wind-and-sailing-state)
- [2. Sail: lift, drag, centre of effort, sail side and sheeting](#2-sail-lift-drag-centre-of-effort-sail-side-and-sheeting)
- [3. Rake steering, pitch stabilisation and angular damping](#3-rake-steering-pitch-stabilisation-and-angular-damping)
- [4. Fin](#4-fin)
- [5. Hull drag, displacement lift and Savitsky planing](#5-hull-drag-displacement-lift-and-savitsky-planing)
- [6. Buoyancy and water damping](#6-buoyancy-and-water-damping)
- [7. Mass, inertia and the sailor's centre of mass](#7-mass-inertia-and-the-sailors-centre-of-mass)
- [8. Wind field: base wind, gusts, shifts and height gradient](#8-wind-field-base-wind-gusts-shifts-and-height-gradient)
- [9. Gerstner waves and the water surface](#9-gerstner-waves-and-the-water-surface)
- [10. Controls: from keys to rake, sheet and weight shift](#10-controls-from-keys-to-rake-sheet-and-weight-shift)
- [11. Every tuning value and where it came from](#11-every-tuning-value-and-where-it-came-from)
- [12. Stabilisers and fudges in the legacy code](#12-stabilisers-and-fudges-in-the-legacy-code)
- [13. Legacy contradictions and their resolution](#13-legacy-contradictions-and-their-resolution)
- [14. Default configuration and real-world plausibility checks](#14-default-configuration-and-real-world-plausibility-checks)
- [15. Decisions under the simulation principle, and the checks still to run](#15-decisions-under-the-simulation-principle-and-the-checks-still-to-run)
- [16. Tuning log](#16-tuning-log)
- [17. Phase 2 implementation notes](#17-phase-2-implementation-notes)

---

## 0. Conventions and notation

### Purpose

Every other section of this spec writes its formulas in one set of axes, angles and names. This section defines that set (the plan's decision D4, expanded), shows how to translate a Unity formula into it, lists what the legacy code and docs actually do (and where the docs are wrong), and gives hand-calculated examples that Phase 2 turns into unit tests.

Why this matters: the legacy project lost several sessions to sign mistakes (Legacy/Documentation/PROGRESS_LOG.md:282-297). Unity is left-handed with the bow on +Z; Godot is right-handed with the bow on −Z. Any cross product, signed angle, rotation or torque copied from Unity comes out mirrored. So we do not copy vector maths. We derive each direction here, once, and pin it with tests.

Reading guide for the team: a "frame" is just a set of three axes to measure positions and directions in. "World frame" is fixed to the water; "body frame" is glued to the board and turns with it. A "bearing" is a compass direction in degrees, clockwise from North.

### Inputs and outputs

This section defines no force. It defines the quantities the other sections take as inputs and the names they must use. The complete list is the shared notation table in 0.3.

### Formulas

#### 0.1 The world frame

Godot, right-handed, +Y up. North is world −Z and East is world +X (D4, Documentation/REBUILD_PLAN.md D4 table). Seen from above:

```
                 North  (−Z)
                    ▲
                    │
                    │
  West (−X) ◄───────┼───────► East (+X)
                    │
                    │
                    ▼
                 South  (+Z)

  +Y points out of the page (up, toward the sky).
```

A compass bearing `b` (degrees, clockwise from North) becomes a horizontal unit vector like this:

**(F0.1)**  `dir_from_bearing(b_rad) = Vector3(sin(b_rad), 0.0, -cos(b_rad))`

Check: b = 0 gives (0, 0, −1) = North; b = 90° gives (1, 0, 0) = East; b = 180° gives (0, 0, 1) = South; b = 270° gives (−1, 0, 0) = West. The `-cos` is the only difference from Unity's `(sin b, 0, cos b)` (Legacy/WindsurfingGame/Assets/Scripts/Environment/WindSystem.cs:176-181), because Unity's North is +Z.

The reverse, a horizontal direction to a bearing:

**(F0.2)**  `bearing_rad(dir) = atan2(dir.x, -dir.z)`, then wrap with `fposmod(rad_to_deg(bearing_rad), 360.0)` for display.

Check: North (0, 0, −1) → atan2(0, 1) = 0. East (1, 0, 0) → atan2(1, 0) = +π/2 = 90°. South (0, 0, 1) → atan2(0, −1) = π = 180°. West (−1, 0, 0) → atan2(−1, 0) = −π/2 → wraps to 270°. Unity's helper is `Atan2(x, z)` (Legacy/WindsurfingGame/Assets/Scripts/Utilities/PhysicsHelpers.cs:47-50); the same with z → −z.

#### 0.2 The body frame

Glued to the board. Bow = local −Z (`Vector3.FORWARD`), starboard = local +X (`Vector3.RIGHT`), up = local +Y (`Vector3.UP`). These three facts are pinned by Game/tests/unit/test_engine_conventions.gd (tests `test_forward_is_negative_z`, `test_right_is_positive_x`, `test_up_is_positive_y`). Seen from above:

```
                  bow  (−Z, Vector3.FORWARD)
                    ▲
                ╱───┴───╲
               │         │
  port (−X) ◄──│    ●    │──► starboard (+X)
               │  mast   │
               │         │
                ╲───┬───╱
                    ▼
                 tail  (+Z)

  +Y (up) points out of the page.
```

The board's orientation is a `Basis` (three orthonormal columns). In world coordinates:

**(F0.3)**
```
starboard_world = basis.x            # body +X
up_world        = basis.y            # body +Y
aft_world       = basis.z            # body +Z, points from bow to tail
fwd_world       = -basis.z           # the bow direction, = basis * Vector3.FORWARD
```

A world direction `v_world` is expressed in the body frame with the inverse basis (for an orthonormal basis the inverse is the transpose):

**(F0.4)**  `v_local = basis.inverse() * v_world`  (equivalently `Vector3(v_world.dot(basis.x), v_world.dot(basis.y), v_world.dot(basis.z))`)

Directions do not include the position, so use the basis, not the full `Transform3D`. (Unity's `transform.InverseTransformDirection` at Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs:255 does the same job; it also ignores scale for our purposes.)

#### 0.3 Heading

The heading is the compass bearing of the bow, from the horizontal part of the forward vector:

**(F0.5)**  `heading_rad = atan2(fwd_world.x, -fwd_world.z)`  and  `heading_deg = fposmod(rad_to_deg(heading_rad), 360.0)`

Check: a board with an identity basis has fwd_world = (0, 0, −1) → heading 0° = North. A board turned to face +X has fwd_world = (1, 0, 0) → +90° = East. Both agree with F0.2. When the bow points nearly straight up or down (a crash), the horizontal part is tiny; keep the previous heading if `fwd_world.x² + fwd_world.z² < 1e-6`.

Note: the legacy `SailingState.HeadingAngle` field (Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:16) was never assigned anywhere in the legacy scripts (checked with grep for `HeadingAngle =`), so there is no legacy formula to compare with; F0.5 is derived from F0.2.

#### 0.4 True wind: from a compass bearing to a velocity vector

Sailors say where the wind comes FROM. The simulation needs the velocity of the air, which points the other way.

**(F0.6)**
```
wind_from_dir  = dir_from_bearing(deg_to_rad(wind_from_bearing_deg))         # unit vector, F0.1
v_wind_true    = -wind_from_dir * wind_speed_ms
               = Vector3(-sin(b_rad), 0.0, cos(b_rad)) * wind_speed_ms
```

Check: wind from the North (b = 0) at 8 m/s gives v_wind_true = (0, 0, +8): the air moves toward +Z = South. Correct, a north wind blows southward.

Legacy: WindSystem.cs:160-168 adds 180° to the bearing and uses `(sin, 0, cos)`; WindSystem.cs:174-182 gives the FROM vector without the 180°. Same idea, Unity axes. Beware the older `WindManager.cs` (Legacy/WindsurfingGame/Assets/Scripts/Physics/Wind/WindManager.cs:84-89 and :127): it builds `(sin b, 0, cos b)` and returns that times the speed with no 180° flip, so there the bearing is the direction the wind blows TO, the opposite convention. It was only the fallback wind source (AdvancedSail.cs:102-115); the wizard-built scene used WindSystem (Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs:511-548). Do not use WindManager as a reference.

#### 0.5 Apparent wind

The wind a moving sailor feels is the true wind minus the boat's own velocity: moving into the wind makes it stronger, running with it makes it weaker.

**(F0.7)**
```
v_apparent          = v_wind_true - v_boat                      # world frame, m/s
apparent_speed_ms   = v_apparent.length()
apparent_from_world = -v_apparent                               # where the apparent wind comes FROM
```

Legacy: SailingState.cs:100 and Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/ApparentWindCalculator.cs:85 (same formula; vector subtraction is identical in both engines because no axis is crossed).

Height: the legacy WindSystem scaled the wind with height (WindSystem.cs:151-158). The wind section owns that; here v_wind_true means the wind at the point where the section using it samples it.

#### 0.6 True and apparent wind angle (TWA, AWA)

Angle between the bow and where the wind comes from. 0 = head to wind, ±π = dead downwind, **positive = wind from starboard** (D4). Computed in the body frame with the horizontal components only:

**(F0.8)**
```
from_local = basis.inverse() * apparent_from_world               # F0.4; for TWA use wind_from_dir instead
awa_rad    = atan2(from_local.x, -from_local.z)
twa_rad    = atan2(from_true_local.x, -from_true_local.z)
```

The y component is ignored by construction (atan2 only sees x and z), which is what the legacy code did by zeroing y (SailingState.cs:108-109, AdvancedSail.cs:180-181).

Check (pinned by `test_atan2_formula_gives_positive_angle_for_starboard`): wind from dead ahead, from_local = (0, 0, −1) → atan2(0, 1) = 0. From starboard, (1, 0, 0) → atan2(1, 0) = +π/2. From port, (−1, 0, 0) → −π/2. From astern, (0, 0, 1) → atan2(0, −1) = π. Note that at exactly ±π the sign depends on floating-point signed zero (atan2(−0.0, −1) = −π); tests at a dead run must compare `abs(awa_rad)` with π.

**Do not use `Vector3.FORWARD.signed_angle_to(from_local, Vector3.UP)`.** In Godot that is positive toward port (pinned by `test_signed_angle_to_is_positive_toward_port`), so it equals `-awa_rad`. Section 0.4 of the translation below explains why.

Small-wind guard (legacy SailingState.cs:103-118): when `apparent_speed_ms < 0.1`, the legacy code kept `ApparentWindAngle = TrueWindAngle`. For Phase 2: when the apparent wind is below 0.1 m/s, keep the previous awa_rad (direction of a near-zero vector is noise). See "Stabilisers" below.

#### 0.7 Sail side, tack names

The sail flies on the leeward side, away from the wind. The sail side is the side the boom and clew are on:

**(F0.9)**  `sail_side = -sign(awa_rad)`  → +1 = boom on the starboard side, −1 = boom on the port side. Define `sign(0) = +1`? No: at awa = 0 (head to wind) keep the previous sail_side; see "Stabilisers".

Tack names (D4 table, row "Tack"):

| awa_rad | wind from | sail_side | boom is on | tack name |
|---|---|---|---|---|
| > 0 | starboard | −1 | port | **starboard tack** |
| < 0 | port | +1 | starboard | **port tack** |

A tack is named after the side the wind comes from (the windward side), which is the side the sailor stands on. The boom is always on the other side.

The numeric meaning of sail_side is the same as the legacy `SailingState.SailSide` (SailingState.cs:30: "+1 = starboard, −1 = port") and the legacy `_manualTack` is its negative (AdvancedSail.cs:66 and :206). What changed is how it is computed; see the legacy table in 0.5.

#### 0.8 Sheet and sail angle

`sheet` runs from 0 = fully out (boom far from the centreline) to 1 = fully in (boom pulled toward the centreline). **This is the reverse of the legacy `_sheetPosition`** (AdvancedSail.cs:27: "0 = sheeted in, 1 = fully eased"). Convert with `sheet = 1.0 - sheet_legacy`.

The boom angle from the centreline, from the legacy straight-line map of 12° (in) to 85° (out) (AdvancedSail.cs:224-226):

**(F0.10)**  `sheet_angle_rad = lerp(deg_to_rad(85.0), deg_to_rad(12.0), sheet)`  (so sheet 0 → 85°, sheet 1 → 12°; the numbers belong to the sail section's config)

The signed boom direction in the body frame: the boom trails aft from the mast (toward +Z, the tail) and swings out to the sail side:

**(F0.11)**  `boom_dir_local = Vector3(sail_side * sin(sheet_angle_rad), 0.0, cos(sheet_angle_rad))`

Check: sail_side = +1, sheet_angle = 90° → (1, 0, 0), boom straight out to starboard. sheet_angle = 0 → (0, 0, 1), boom along the centreline pointing at the tail. Legacy (AdvancedSail.cs:239-244) used `(sin a, 0, -cos a)` because Unity's tail is −Z; the z sign flips in Godot.

Angle of attack `alpha` (the angle between the apparent wind and the sail's chord) belongs to the sail section, which must define it so that its sign is consistent with sail_side. The legacy sail computed it from the sail normal (AdvancedSail.cs:328-330 and Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs:142-151).

#### 0.9 Rake

`rake` runs from −1 (fully forward) to +1 (fully back, mast top toward the tail). Positive rake makes the board head up (turn toward the wind) on both tacks (D4). The physical mast angle:

**(F0.12)**  `rake_rad = rake * max_rake_rad`, with max_rake_rad = deg_to_rad(15.0) (AdvancedSail.cs:42 and WindsurferSetup.cs:736; in the legacy code this angle was only used by the visuals, e.g. Legacy/WindsurfingGame/Assets/Scripts/Visual/SailVisualizer.cs:234; the physics used the dimensionless `_mastRake` directly, AdvancedSail.cs:506-522).

Tilting the mast back moves the sail's centre of effort behind the fin's centre of lateral resistance; the sail force then pushes the tail downwind, so the bow swings up into the wind. That is why "rake back = head up" holds on both tacks.

#### 0.10 Heel and pitch

Derived from the basis vectors, not from Euler angles (Euler order differs between engines and Godot's default order is YXZ; basis vectors are unambiguous).

**(F0.13)**
```
pitch_rad = asin(clamp(fwd_world.y, -1.0, 1.0))          # positive = bow up
heel_rad  = atan2(-starboard_world.y, up_world.y)          # positive = heeled to starboard (starboard rail down)
```

Check pitch: rotate the board about body +X (starboard axis) by +θ in a right-handed frame. `Vector3.FORWARD.rotated(Vector3.RIGHT, θ)` = (0, sin θ, −cos θ): the bow goes up, so a positive rotation about +X is a positive pitch. Check heel: rotate about the forward axis: `Vector3.RIGHT.rotated(Vector3.FORWARD, θ)` = (cos θ, −sin θ, 0): the starboard rail goes down, so a positive rotation about `Vector3.FORWARD` (= −Z) is a positive heel. Equivalently, heel is **negative** rotation about body +Z.

Unity: `transform.eulerAngles.x` positive = bow **down** (that is why Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs:426-428 negates it to get the trim angle) and `transform.eulerAngles.z` positive = heel to **port** (AdvancedSail.cs:399, AdvancedHullDrag.cs:420; the controller's `SignedAngle(up, ..., forward)` at Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs:280-282 has the same sign). Both are the opposite of F0.13. Every legacy heel or pitch formula that uses the sign (not just the absolute value) needs a minus sign here.

#### 0.11 Angular velocity, yaw rate and torque signs

Godot is right-handed: a positive rotation about an axis is counter-clockwise when looking from the tip of the axis toward the origin. About +Y (looking down from above) counter-clockwise is a **left turn**. Proof with the velocity of the bow point: for angular velocity ω = (0, ω_y, 0) and the bow at r = (0, 0, −1), v = ω × r = (ω_y·(−1) − 0, 0, 0) = (−ω_y, 0, 0). Positive ω_y moves the bow toward −X, which is port. Pinned by `test_positive_rotation_about_up_turns_the_bow_to_port`.

**(F0.14)**
```
yaw_rate   = omega_local.y              # rad/s, positive = bow turning to PORT (left)
pitch_rate = omega_local.x              # rad/s, positive = bow rising
roll_rate  = -omega_local.z             # rad/s, positive = heeling further to starboard
```

Torques follow the same rule: a torque with a positive Y component turns the bow to port.

**Head-up torque on starboard tack is negative about +Y.** On starboard tack the wind comes from starboard (awa > 0). Heading up means turning the bow toward the wind, i.e. to starboard, i.e. a right turn, i.e. clockwise seen from above, i.e. negative about +Y. On port tack heading up is a left turn, positive about +Y. So a steering term that heads up when rake > 0, on either tack, is:

**(F0.15)**  `torque_yaw = -K * rake * sign(awa_rad) = K * rake * sail_side`  (K > 0 in N·m; the value belongs to the rake section)

Check: starboard tack, rake = +0.5, K = 200 N·m → torque_yaw = −200 × 0.5 × (+1) = −100 N·m → right turn → toward the wind ✓. Port tack, same rake → +100 N·m → left turn → toward the wind (which is on the left) ✓. Rake −0.5 on starboard tack → +100 N·m → left turn → away from the wind = bearing away ✓.

The legacy formula is `AddTorque(Vector3.up * (rake * tack * ...))` with `tack = -SailSide` (AdvancedSail.cs:474, :494, :506-524). In Unity positive Y is a right turn (left-handed), so the Unity torque is `+K * rake * sign(AWA)`. Same physics, opposite sign of the number. Every "turn toward X" torque in the legacy code (fin tracking, Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs:174-186; weight shift, AdvancedWindsurferController.cs:257-266) gets the same sign flip: compute the angle with the atan2 rule (positive = to starboard) and apply `torque_yaw = -K * angle`.

Leeway (slip) angle, for the fin section, uses the same construction as AWA with the velocity instead of the wind:

**(F0.16)**  `v_local = basis.inverse() * v_boat`, `leeway_rad = atan2(v_local.x, -v_local.z)`  → positive = the board is sliding toward starboard.

The legacy `SignedAngle(finForward, velocity, up)` (Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Hydrodynamics.cs:136) is also positive for velocity to starboard of the bow, so the fin section can keep the legacy sign for the angle and only flips the torque.

### Values

| Name | Value | Unit | Source | Notes |
|---|---|---|---|---|
| rho_air | 1.225 | kg/m³ | Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:12; Legacy/Documentation/PHYSICS_DESIGN.md:291 | sea level, 15 °C |
| rho_water | 1025 | kg/m³ | PhysicsConstants.cs:13 | seawater |
| g | 9.81 | m/s² | PhysicsConstants.cs:18 | |
| KNOT_MS (1 knot) | 1852/3600 = 0.514444… | m/s | PhysicsConstants.cs:22 (0.514444); PhysicsConstants.cs:21 has MS_TO_KNOTS = 1.94384 | Define one constant `KNOT_MS = 1852.0 / 3600.0` and derive the other; the two legacy constants are not exact inverses (1/1.94384 = 0.514446) |
| max_rake_deg | 15 | deg | AdvancedSail.cs:42 (default), WindsurferSetup.cs:736 (wizard) | Same value in both. Only used by visuals in the legacy code |
| sheet angle, fully in | 12 | deg | AdvancedSail.cs:224 | value belongs to the sail config |
| sheet angle, fully out | 85 | deg | AdvancedSail.cs:225 | |
| Minimum apparent wind speed for a valid AWA | 0.1 | m/s | SailingState.cs:103 | below it the legacy code used the TWA (with the wrong sign, see 0.5) |
| Minimum true wind speed for a valid TWA | 0.1 | m/s | AdvancedSail.cs:178 | |
| Default wind FROM bearing | **270** (scene and field default) / 45 (wizard, never applied) / 45 (old WindManager) | deg | MainScene.unity:821; WindSystem.cs:22 / WindsurferSetup.cs:63 and :540-542 / WindManager.cs:16 | The wizard's 45° never reached the scene: until Session 27 it wrote to a field name that does not exist (section 8). Every committed scene has 270° (from the West). The WindManager value is history (and its bearing means TO, not FROM). |
| Default wind speed | **15** (scene in Sessions 22 and 27, field default) / 22 (the Session 26 commit) / 12 (wizard, never applied) | kt | MainScene.unity:822; WindSystem.cs:26 / git show b5ed2ea / WindsurferSetup.cs:62 and :536-538 | The wizard's 12 kt never reached the scene (section 8). The Session 26 commit stored 22 kt, unexplained (section 8, OPEN 2). The validation targets are defined at 15 kt. |
| Initial board position | (0, 0.5, 0) | m | WindsurferSetup.cs:683 | Unity axes, but only Y matters; identity rotation, so the initial heading was North (Unity +Z) |
| Initial rig mass in Rigidbody | 91 | kg | WindsurferSetup.cs:689 | vs 95 kg in the mass component (WindsurferSetup.cs:779). The mass section owns this conflict; listed here because the frames sketch assumes one rigid body |

### Where the force acts

Not applicable: this section defines no force. For all other sections: forces are applied at a point given in the body frame, `r_local`, and produce the torque `tau = r_world × F_world` with `r_world = basis * r_local` (the lever arm from the centre of mass). This cross product is the right-handed one and already follows F0.14; do not add sign corrections to it.

### Signs and the Unity-to-Godot translation

#### The axis map

| Meaning | Unity (left-handed) | Godot (right-handed) |
|---|---|---|
| Up | +Y | +Y |
| Forward / bow / North | +Z | −Z |
| Right / starboard / East | +X | +X |

So the map is `godot = Vector3(unity.x, unity.y, -unity.z)`. This is a reflection (it flips one axis), and a reflection has determinant −1. That single fact explains every sign change below.

#### The rule

1. **Dot products, lengths and vector sums do not change.** `v_apparent = v_wind_true - v_boat`, `0.5 * rho * v²`, projections onto a direction: copy them, then map each vector.
2. **Cross products, signed angles, rotations, angular velocities and torques flip sign.** For a reflection R: `cross(R a, R b) = -R cross(a, b)`. In words: map both inputs to Godot, take the Godot cross product, and you get the mapped Unity result with a minus sign. Anything built on a cross product (signed angles, "rotate by +θ about an axis", torque and angular velocity vectors) inherits the flip.
3. **Practical recipe:** never translate a formula symbol by symbol. Write down what the formula is supposed to do physically ("torque that turns the bow toward the wind", "lift perpendicular to the wind on the leeward side"), derive the Godot vector for that from F0.1 to F0.16, and check it with one numeric example that has an obvious answer.

#### Worked example A: cross product

Unity: `Cross(up, forward) = Cross((0,1,0), (0,0,1)) = (1·1 − 0·0, 0·0 − 0·1, 0·0 − 1·0) = (1, 0, 0)` = starboard.
Godot: `Vector3.UP.cross(Vector3.FORWARD) = cross((0,1,0), (0,0,−1)) = (1·(−1) − 0, 0, 0) = (−1, 0, 0)` = port.
Same expression, opposite side. The legacy comment at Aerodynamics.cs:187 says `Cross(up, windDir)` "points 90° left of wind"; in Unity it points to the right (as just shown). It only mattered as the last fallback (Aerodynamics.cs:237), but it shows how easily this goes wrong. In Godot the comment would be right.

#### Worked example B: signed angle (this is the AWA trap)

Both engines compute the signed angle the same way: `angle(a, b) · sign(dot(axis, cross(a, b)))` (Unity `Vector3.SignedAngle`, Godot `Vector3.signed_angle_to`). Only the meaning of the inputs changes.

Unity, wind from starboard: `SignedAngle(forward=(0,0,1), from=(1,0,0), up)`; `cross = (0·0 − 1·0, 1·1 − 0·0, 0) = (0, 1, 0)`, dot with up = +1 → **+90°**. This is SailingState.cs:113, and it is why the legacy AWA is positive for wind from starboard.
Godot, same physical situation: `Vector3.FORWARD.signed_angle_to(Vector3.RIGHT, Vector3.UP)`; `cross((0,0,−1), (1,0,0)) = (0·0 − (−1)·0, (−1)·1 − 0·0, 0) = (0, −1, 0)`, dot with up = −1 → **−90°**.
So the "same" line of code gives the opposite sign in Godot. Hence F0.8 uses `atan2(from_local.x, -from_local.z)`, which reads the starboard component directly and is engine-independent once the frame is fixed.

#### Worked example C: rotation direction

Unity: `Quaternion.Euler(0, 90, 0) * forward` = (1, 0, 0): a positive yaw of 90° turns the bow to the right.
Godot: `Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(90))` = (−1, 0, 0) = `Vector3.LEFT` (pinned by `test_positive_rotation_about_up_turns_the_bow_to_port`): a positive yaw turns the bow to the left.
Consequence: `Vector3.up * torque` in Unity is a right-turn torque; `Vector3.UP * torque` in Godot is a left-turn torque. Negate every yaw torque and every yaw rate when translating (F0.15).

#### Worked example D: pitch and roll rotations

Unity, rotate forward (0,0,1) about +X by +θ with the standard matrix: (0, −sin θ, cos θ), bow **down**. Godot, `Vector3.FORWARD.rotated(Vector3.RIGHT, θ)` = (0, sin θ, −cos θ), bow **up**. So Unity `eulerAngles.x` and a Godot pitch angle have opposite signs (F0.13).
Roll about +Z: both engines send up (0,1,0) to (−sin θ, cos θ, 0), mast top toward −X = port. So "+Z roll" means heel to port in both, and our heel_rad (positive = starboard) is the negative of a rotation about +Z in both engines. Here the sign does not flip between engines, only against our convention.

#### Worked example E: a full formula (rake steering)

Unity (AdvancedSail.cs:506, :524): `AddTorque(Vector3.up * (rake * tack * force * 0.3))` with `tack = -SailSide = sign(AWA_unity)`. Physical intent (AdvancedSail.cs:454-459): rake back heads up on both tacks.
Godot: head up on starboard tack is a right turn = negative about +Y (0.11). `torque_yaw = -K * rake * sign(awa_rad)`. Do not write `Vector3.UP * (rake * tack * K)`; that would bear away when raking back.

### Legacy sign conventions: code, docs and D4

"Code" is the state at the last Unity commit (b5ed2ea, Session 26, 2026-01-02; the Legacy/ folder is that state).

| # | Quantity | What the legacy code does | What the legacy docs claim | Verdict | D4 equivalent |
|---|---|---|---|---|---|
| 1 | AWA sign | `SignedAngle(fwdHorizontal, -awHorizontal, up)` (SailingState.cs:113). In Unity this is **positive for wind from starboard** (worked example B), as the code comment at SailingState.cs:112 says and as the tack comment at AdvancedSail.cs:458 assumes. | PHYSICS_VALIDATION.md:46-51: "Port → POSITIVE, Starboard → NEGATIVE". PROGRESS_LOG.md:301-302 says the same. | **Docs wrong, code right** (plan pitfall 1). | `awa_rad = atan2(from_local.x, -from_local.z)`, positive = starboard. Same sign as the legacy code. |
| 2 | TWA sign | `SignedAngle(-twHorizontal, fwdHorizontal, up)` (AdvancedSail.cs:182): the arguments are in the **opposite order** from the AWA line, so the legacy TWA is positive for wind from **port**. It was only shown on the HUD (Legacy/WindsurfingGame/Assets/Scripts/UI/AdvancedTelemetryHUD.cs:190) and used as the AWA fallback below 0.1 m/s (SailingState.cs:117), where the sign mismatch could flip the sail side for a frame. | Not documented. | **Code inconsistent** with its own AWA. | `twa_rad = atan2(from_true_local.x, -from_true_local.z)`, positive = starboard, same convention as AWA. |
| 3 | Sail side | Since Session 22 (commit 5a1857a, 2025-12-28): `sailSide = -_manualTack` (AdvancedSail.cs:206), where `_manualTack` is toggled by the Space key (AdvancedSail.cs:549-554, AdvancedWindsurferController.cs:178-182). The wind is not consulted. Before that (commit 4c45223, 2025-12-27): `sailSide = -Sign(AWA)` with 5° hysteresis (old AdvancedSail.cs:217-228 in that commit). Both Session 24 and Session 26 code contain only the manual version. | PHYSICS_VALIDATION.md:57-87 and PROGRESS_LOG.md:77, :304-306 describe `-Sign(AWA)` with hysteresis. PHYSICS_VALIDATION.md:69-70 labels "AWA > 0 (wind from port) → −1 → sail on starboard": both labels in that row are flipped (AWA > 0 is starboard wind, and sailSide −1 is port per SailingState.cs:30), so the physical statement is right and the numbers are wrong. | **Docs out of date** (they describe the 2025-12-27 code). | `sail_side = -sign(awa_rad)`, +1 = boom on starboard. The manual tack is a control-layer question, see OPEN below. |
| 4 | Rake tack factor | `tack = -SailSide` (AdvancedSail.cs:474, :494), torque about Unity +Y = right turn (AdvancedSail.cs:524). Rake back heads up on both tacks (AdvancedSail.cs:454-459). | PHYSICS_VALIDATION.md:160-182 agrees (table at :174-179 is correct). PROGRESS_LOG.md:79 says `tack = sailSide` (missing the minus; PROGRESS_LOG.md:311 has it right). PHYSICS_VALIDATION.md:297-298 checklist says "Rake back = bear away, rake forward = head up", which contradicts :181-182 and the code. | **Checklist lines wrong, code right** (plan pitfall 1). | `torque_yaw = -K * rake * sign(awa_rad)` (F0.15). Sign flipped relative to the Unity number because +Y yaw is a left turn in Godot. |
| 5 | Rake torque size | Three terms: `rake·tack·|F_sail|·0.3·scale` + `rake·tack·(200 or 350)·scale` + `rake·tack·min(v, 8)·25·scale`, scale = lerp(1, 0.5, (kt−15)/15) floored at 0.4 (AdvancedSail.cs:497-524). | PHYSICS_VALIDATION.md:166-169: one term with 0.5; :189-192: scale = lerp(1, 0.3, (kt−15)/10). Plan lists "150 × rake" and "to 0.3 between 15 and 25 kt". | **Values conflict**; the code is the last validated state. Rake section owns the numbers. | Rake section. |
| 6 | Sheet direction | `_sheetPosition` 0 = sheeted in (12°), 1 = eased (85°) (AdvancedSail.cs:27, :224-226); W decreases it (AdvancedWindsurferController.cs:147-150). | PHYSICS_VALIDATION.md:236 "SAIL ANGLE = sheetPosition × sailSide" (loose; the real map is the 12°–85° lerp). | Consistent, but reversed from rule 5. | `sheet` 1 = in, 0 = out; `sheet = 1 - sheet_legacy` (F0.10). |
| 7 | Boom direction | `(sin a, 0, -cos a)` in Unity local, boom trails toward −Z = tail (AdvancedSail.cs:236-244). PROGRESS_LOG.md:1272 records that an earlier version had it pointing forward. | PHYSICS_VALIDATION.md:239 same as code. | Correct for Unity. | `Vector3(sail_side·sin θ, 0, +cos θ)` (F0.11): the z sign flips because the tail is +Z in Godot. |
| 8 | Sail normal / lift direction | `Cross(chord, up)` then flipped to face the wind (AdvancedSail.cs:252-266); lift = projection of −normal onto the plane perpendicular to the wind (Aerodynamics.cs:207-238). | PHYSICS_VALIDATION.md:91-156. | The "flip to face the wind" step makes the result independent of the cross product's sign, so it is correct in both engines. Still, derive it again in the sail section instead of copying (rule 3). | Sail section. |
| 9 | Heel sign | `eulerAngles.z` (AdvancedSail.cs:399, AdvancedHullDrag.cs:420) and `SignedAngle(up, boardUp, forward)` (AdvancedWindsurferController.cs:280-282): positive = heel to **port**. Only the absolute value is used in the physics files; the controller uses the sign for the anti-capsize torque. | Not documented. | Correct for Unity. | `heel_rad` positive = starboard (F0.13). Negate when a legacy formula uses the sign. |
| 10 | Pitch sign | `eulerAngles.x` positive = bow **down**; trim = −pitch (AdvancedHullDrag.cs:426-428); pitch stabiliser uses the raw sign (AdvancedSail.cs:420-444). | PHYSICS_VALIDATION.md:317: "τ = trim angle (degrees, bow-up)". | Correct for Unity. | `pitch_rad` positive = bow up (F0.13), so `trim = pitch_rad` with no minus. |
| 11 | Leeway / fin slip angle | `SignedAngle(finForward, velocity, up)` (Hydrodynamics.cs:136; AdvancedFin.cs:174 for the tracking torque): positive = velocity to starboard of the bow. | Not documented. | Correct for Unity. | `leeway_rad = atan2(v_local.x, -v_local.z)` (F0.16), same sign; the tracking torque sign flips (F0.15 rule). |
| 12 | Wind bearing → vector | WindSystem.cs:160-168: bearing is FROM, vector = bearing + 180°. WindManager.cs:84-89, :127: bearing is treated as TO. | WindSystem.cs:20 tooltip "where the wind comes FROM, 0=North, 90=East"; WindManager.cs:15 "0 = North/+Z, 90 = East/+X" (ambiguous). | WindSystem right; WindManager the opposite convention. | F0.6. |
| 13 | Old `ApparentWindCalculator` | `Vector3.Angle` (unsigned) for the AWA (ApparentWindCalculator.cs:95); a separate signed `GetApparentWindSide()` with the same SignedAngle as #1 (ApparentWindCalculator.cs:110). | Comment at :105 says positive = starboard (correct in Unity). | Old non-Advanced component; the wizard only adds it in the legacy "upgrade selected board" path (WindsurferSetup.cs:1312-1313), not to the Advanced windsurfer (WindsurferSetup.cs:676 onward). | Not used. Phase 2 has one signed AWA (F0.8). |
| 14 | "In irons" flag | Two definitions: `|AWA| < 30° && speed < 1` (SailingState.cs:89) and `|AWA| < 20° && speed < 1` (AdvancedSail.cs:316), the 30° version wins because `SailingState.UpdateDerivedValues()` runs last (AdvancedSail.cs:316 sets 20°, then :351 overwrites it with 30°). | PHYSICS_VALIDATION.md does not mention it. | Inconsistent, cosmetic (only a flag). | Sail section decides; suggest one definition in the telemetry. |

### Stabilisers and fudges in this model

The conventions themselves have no fudges, but three small pieces of the legacy angle code are worth a decision:

1. **Sail-side hysteresis of 5° around head to wind** (commit 4c45223 AdvancedSail.cs:217-220; PHYSICS_VALIDATION.md:78-87). Added in Session 18 so the sail did not flip back and forth while pointing into the wind. It hides nothing physical: the sail side is genuinely undefined at awa = 0 (and at ±π), so some memory is needed. **Recommendation: keep**, as "if `abs(awa_rad) < deg_to_rad(5.0)`: keep the previous sail_side", and add the same rule near ±π for gybes. Test it.
2. **Manual tack (Space key) replacing the wind-driven sail side** (AdvancedSail.cs:200-208, Session 22). Not documented in the legacy progress log for Session 22 (checked PROGRESS_LOG.md:337-455; no mention of tack or Space). It probably hid the sail flipping at the wrong moment during tacks with the old hysteresis, and it made "steering inverted on port tack" a controller problem (KNOWN_ISSUES.md:84). It also lets the sail sit on the windward side, which is not physical. **Recommendation: re-evaluate in the sail section.** Physics default: `sail_side = -sign(awa_rad)` with hysteresis (item 1). The plan's Phase 3 "tack or gybe (Space)" can be a controller action that steers through the wind rather than a flag that overrides the physics. OPEN: the team decides whether Space should flip the sail directly (arcade) or start a steered tack (simulation).
3. **AWA fallback to TWA below 0.1 m/s apparent wind** (SailingState.cs:103-118). Harmless in intent, but in the legacy code the TWA had the opposite sign (table row 2). **Recommendation: keep the fallback to the TWA**, which is harmless now that both angles share one sign convention (section 1, Formula 5), or keep the previous awa_rad; either way nothing flips while the board sits in a lull.
4. **Control smoothing** (sheet moves at 1.5 per second, rake at 3.0 per second: AdvancedSail.cs:32, :45, :147-152; controller rake speed 2.0 per second and auto-centre 1.0 per second: AdvancedWindsurferController.cs:39-45, :225-236). These are controller behaviour, not physics. **Recommendation: keep them out of `Game/sim/`**; the sim takes the already-smoothed `sheet` and `rake` values each step. The controller section (Phase 3) owns the rates.

### What Phase 2 must implement

- [ ] A `Conventions` (or `SimMath`) helper in `Game/sim/` with static functions for F0.1, F0.2, F0.5, F0.6, F0.7, F0.8, F0.13 and F0.16, each with the formula and the check values in a comment.
- [ ] `dir_from_bearing(b_rad)` = `Vector3(sin b, 0, -cos b)` and `bearing_rad(dir)` = `atan2(dir.x, -dir.z)`.
- [ ] `heading_rad(basis)` from `fwd_world = -basis.z`.
- [ ] `true_wind_velocity(bearing_deg, speed_ms)` = `-dir_from_bearing(...) * speed_ms`.
- [ ] `apparent_wind(v_wind_true, v_boat)` returning the vector, its speed and `apparent_from_world`.
- [ ] `wind_angle_rad(basis, from_world)` = `atan2(from_local.x, -from_local.z)`, used for both TWA and AWA; never `signed_angle_to`.
- [ ] `sail_side` = `-sign(awa_rad)` with the 5° hysteresis at 0 and ±π and a remembered previous side.
- [ ] `sheet` with 1 = in, 0 = out; `sheet_angle_rad` from F0.10; `boom_dir_local` from F0.11 with `+cos` on z.
- [ ] `rake` −1…1 with rake_rad = rake × deg_to_rad(15) (config value).
- [ ] `heel_rad` and `pitch_rad` from the basis (F0.13), never from Euler angles.
- [ ] Yaw torque helper: "turn toward angle θ (positive = starboard)" applies `-K * θ` about +Y (F0.15).
- [ ] One constant `KNOT_MS = 1852.0 / 3600.0`; km/h and knots only in display and test names.
- [ ] Telemetry reports heading_deg, twa_deg, awa_deg (signed, positive = starboard), sail_side, heel_deg, pitch_deg; conversion to degrees happens there and nowhere else.

### Tests Phase 2 should write

All angles in the expected values are exact (they come from `atan2(8, 5)` etc.); use a tolerance of 1e-6 rad on angles and 1e-6 m/s on vectors unless noted.

**Bearings and heading**
- `dir_from_bearing(0)` = (0, 0, −1); 90° → (1, 0, 0); 180° → (0, 0, 1); 270° → (−1, 0, 0).
- `heading_deg` of the identity basis = 0 (North); of `Basis(Vector3.UP, deg_to_rad(-90))` (a right turn of 90°) = 90 (East); of a left turn of 90° = 270 (West). This also re-checks that a negative rotation about +Y is a right turn.
- `bearing_rad(dir_from_bearing(b))` round-trips for b = 0, 45, 90, 135, 180, 225, 270, 315°.

**Example 1: wind from the North at 8 m/s, board heading East at 5 m/s**
- wind_from_dir = (0, 0, −1); v_wind_true = (0, 0, 8); fwd_world = (1, 0, 0); starboard_world = (0, 0, 1); v_boat = (5, 0, 0).
- v_apparent = (0, 0, 8) − (5, 0, 0) = **(−5, 0, 8)**; apparent_speed_ms = √89 = **9.433981 m/s**.
- apparent_from_world = (5, 0, −8); from_local = (from · starboard, 0, from · aft) = (−8, 0, −5).
- awa_rad = atan2(−8, 5) = **−1.012197 rad = −57.9946°** (wind from port, ahead of the beam: the board's own motion pulls the apparent wind forward).
- twa_rad = atan2(−1, 0) = **−π/2 = −90°** (true wind on the port beam).
- sail_side = **+1** (boom on starboard), tack name **port tack**.

**Example 2: the mirror, wind from the North at 8 m/s, board heading West at 5 m/s**
- fwd_world = (−1, 0, 0); starboard_world = (0, 0, −1); v_boat = (−5, 0, 0).
- v_apparent = **(5, 0, 8)**; speed **9.433981 m/s**; apparent_from_world = (−5, 0, −8); from_local = (8, 0, −5).
- awa_rad = atan2(8, 5) = **+1.012197 rad = +57.9946°**; twa_rad = **+90°**; sail_side = **−1** (boom on port), **starboard tack**.
- Symmetry assert: awa(example 2) = −awa(example 1) and the speeds are equal.

**Example 3: beam reach on starboard tack, wind from the East at 10 m/s, board heading North at 6 m/s**
- wind_from_dir = (1, 0, 0); v_wind_true = (−10, 0, 0); fwd_world = (0, 0, −1); starboard_world = (1, 0, 0); v_boat = (0, 0, −6).
- v_apparent = **(−10, 0, 6)**; speed = √136 = **11.661904 m/s**; from_local = (10, 0, −6).
- awa_rad = atan2(10, 6) = **+1.030377 rad = +59.0362°**; twa_rad = **+90°**; sail_side = **−1**, **starboard tack**.

**Example 4: dead run, wind from the North at 8 m/s, board heading South at 3 m/s**
- fwd_world = (0, 0, 1); starboard_world = (−1, 0, 0); v_boat = (0, 0, 3).
- v_apparent = (0, 0, 8) − (0, 0, 3) = **(0, 0, 5)**; speed **5 m/s** (weaker than the true wind, as expected when running); from_local = (0, 0, 5).
- `abs(awa_rad)` = **π**; `abs(twa_rad)` = **π**. Do not assert the sign at exactly ±π (signed zero); assert that sail_side keeps its previous value (hysteresis).

**Example 5: head to wind, stopped, wind from the North at 8 m/s, heading North**
- v_apparent = (0, 0, 8); from_local = (0, 0, −8); awa_rad = **0**; twa_rad = **0**; sail_side keeps its previous value.

**Example 6: outrunning the wind, wind from the North at 8 m/s, heading South at 12 m/s**
- v_apparent = (0, 0, 8) − (0, 0, 12) = **(0, 0, −4)**: the apparent wind now comes from dead ahead; awa_rad = **0** while twa_rad = **±π**. Shows why AWA and TWA must be separate values.

**Signs**
- `Vector3.FORWARD.signed_angle_to(from_local, Vector3.UP)` equals `-awa_rad` for from_local = (−8, 0, −5) (i.e. +57.9946°). This test documents the trap.
- Yaw: a body with angular velocity (0, +1, 0) rad/s has bow-point velocity (−1, 0, 0) (toward port), from `omega.cross(Vector3.FORWARD)`.
- F0.15: with K = 200, rake = 0.5: awa = +45° gives torque_yaw = −100 N·m; awa = −45° gives +100 N·m; rake = −0.5 and awa = +45° gives +100 N·m. Then integrate one step and assert the heading moved toward the wind for the first two and away for the third.
- Heel and pitch: `Basis(Vector3.RIGHT, deg_to_rad(10))` gives pitch_rad = +10° (bow up) and heel_rad = 0; `Basis(Vector3.FORWARD, deg_to_rad(10))` gives heel_rad = +10° (starboard rail down, i.e. `basis.x.y < 0`) and pitch_rad = 0; `Basis(Vector3(0,0,1), deg_to_rad(10))` gives heel_rad = −10°.
- Boom direction: sail_side = +1, sheet = 0 (out, 85°) → boom_dir_local = (sin 85°, 0, cos 85°) = (0.996195, 0, 0.087156); sail_side = −1, sheet = 1 (in, 12°) → (−0.207912, 0, 0.978148). Both have z > 0 (boom trails aft).
- Leeway: v_local = (1, 0, −5) → leeway_rad = atan2(1, 5) = +0.197396 rad (sliding to starboard).

### Sources

- Documentation/REBUILD_PLAN.md: D4 table; "Known legacy pitfalls" 1 and 2; Phase 2 tests list.
- CLAUDE.md: "Architecture rules" 4 to 6.
- Game/tests/unit/test_engine_conventions.gd: the six pinned Godot facts (lines 7 to 42).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:13-30 (state fields and their comments), :60-92 (derived values, in-irons flag at :89), :97-119 (apparent wind and AWA).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs:27-45 (control fields), :65-66 and :80-81 (sail side and manual tack fields), :137-153 (control smoothing), :158-192 (wind state, TWA at :182), :197-276 (sail geometry: manual tack :206, sheet map :224-226, chord :239-244, normal :252-266), :296-352 (forces, in-irons at :316), :396-445 (pitch stabiliser, Euler angles at :399 and :420), :450-525 (rake steering), :549-564 (SwitchTack, SetTack), :729-736 (tack gizmo comment).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/ApparentWindCalculator.cs:74-111.
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs:138-151 (angle of attack), :186-189 (cross-product fallback), :207-249 (lift direction).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Hydrodynamics.cs:120-136 (leeway angle).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs:160-187 (tracking torque).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs:418-431 (heel and trim from Euler angles).
- Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs:145-182 (keys, port-tack inversion, Space), :248-266 (weight-shift torque), :276-296 (heel angle).
- Legacy/WindsurfingGame/Assets/Scripts/Environment/WindSystem.cs:19-26 (defaults), :99-100, :108-139 (gusts and shifts), :147-182 (bearing to vector).
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Wind/WindManager.cs:15-16, :84-89, :95-128.
- Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:12-24.
- Legacy/WindsurfingGame/Assets/Scripts/Utilities/PhysicsHelpers.cs:47-50.
- Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs:62-63, :511-548 (wind), :676-700 (windsurfer root, mass), :736 (max rake), :779 (mass component), :1312-1313 (old calculator in the upgrade path).
- Legacy/Documentation/PHYSICS_VALIDATION.md sections 1 to 5 (:23-195) and 9 to 10 (:270-303).
- Legacy/Documentation/PHYSICS_DESIGN.md section 3 (:263-296) and section 5 (:463-484).
- Legacy/Documentation/PROGRESS_LOG.md:72-82 (formula table), :277-330 (Session 18 sign-convention revert), :337-380 (Session 22 entry, no tack note), :1268-1273.
- Legacy/Documentation/KNOWN_ISSUES.md:81-86 (Session 26 fixes).
- Git history: ca7a7b1 (2025-12-27, Session 13), 4c45223 (2025-12-27, "revert sailSide to -Sign(AWA)"), 5a1857a (2025-12-28, Session 22, manual tack introduced), c62f577 (2026-01-01), b5ed2ea (2026-01-02, Session 26, last Unity commit).
- Literature: the apparent-wind triangle and the tack naming are standard sailing theory (for example C. A. Marchaj, *Sail Performance*, chapter on apparent wind); the right-hand rule for cross products and the reflection rule `cross(Ra, Rb) = det(R)·R·cross(a, b)` are standard vector algebra.

---

## 1. Apparent wind and sailing state

### Purpose

The sail does not feel the "real" wind. It feels the wind that is left over after you subtract the board's own movement. Sailors call the real wind the **true wind** and the wind the sail feels the **apparent wind**. When you sail fast across the wind, the apparent wind comes more from ahead and is stronger than the true wind; when you sail away from the wind it gets weaker. Every sail force in section 2 is computed from the apparent wind, so this section must be right before anything else can be.

This section also defines the small set of "where am I relative to the wind" numbers that the rest of the simulation, the HUD and the tests share: the true wind angle (TWA), the apparent wind angle (AWA), the speed made good toward the wind (VMG), the compass heading, which side the wind is on, and the flags for "in irons" (stuck head to wind), "sail stalled" and "luffing" (sail not filled).

In the legacy Unity build this lived in three places: `WindSystem.cs` (the true wind), `SailingState.cs` (the apparent wind, AWA, VMG and the flags) and `AdvancedSail.UpdateWindState()` (which glued them together each physics tick). An older component, `ApparentWindCalculator.cs`, did the same job for the pre-"Advanced" stack; it was not on the validated windsurfer and is treated as history below.

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `wind_from_bearing_deg` | Compass bearing the true wind comes FROM (0 = from North, 90 = from East, 270 = from West) | deg (display and config only) |
| `wind_speed_ms` | True wind speed at the sampling height | m/s |
| `v_wind_true` | True wind **velocity** vector in the world frame (the direction the air moves; the FROM direction is `-v_wind_true.normalized()`) | m/s, Vector3 |
| `position_sail` | World point where the wind is sampled (see Formula 2) | m, Vector3 |
| `v_boat` | Velocity of the board in the world frame | m/s, Vector3 |
| `basis` | Orientation of the board (its body frame axes in the world frame) | – |
| `omega` | Angular velocity of the board in the world frame (needed only if the wind is sampled at a point away from the centre of mass, Formula 3) | rad/s, Vector3 |
| **Outputs** | | |
| `forward_h`, `right_h` | Horizontal unit vectors of the bow direction and the starboard direction ("heading frame", Formula 4) | – |
| `heading_deg` | Compass heading of the bow, 0..360 | deg (display) |
| `v_apparent` | Apparent wind velocity vector, world frame | m/s, Vector3 |
| `v_apparent_h` | Its horizontal part (y set to 0) | m/s, Vector3 |
| `aws_ms` | Apparent wind speed | m/s |
| `awa_rad` | Apparent wind angle, +pi..-pi, **positive = wind from starboard** | rad |
| `tws_ms` | True wind speed at the sampling point | m/s |
| `twa_rad` | True wind angle, same sign rule as AWA | rad |
| `wind_side` | `sign(awa_rad)`: +1 wind from starboard, -1 from port, 0 dead ahead/astern | – |
| `vmg_ms` | Velocity made good toward the wind (positive = going upwind) | m/s |
| `boat_speed_ms` | `v_boat.length()` | m/s |
| `is_in_irons` | Head to wind and (almost) stopped, display/audio flag | bool |
| `is_sail_stalled` | `abs(alpha) > stall angle`, display flag (alpha comes from section 2) | bool |
| `is_luffing`, `luff_amount` | Sail not filled (0..1), for cloth and audio only | – |
| `point_of_sail` | Name for the HUD (Formula 10), display only | enum |

### Formulas

All vectors are in the Godot world frame (+Y up, North = -Z, East = +X) unless a name ends in `_local`.

**1. From a compass bearing to vectors.**
The bearing says where the wind comes FROM, clockwise from North. North is -Z and East is +X, so:

```
b = deg_to_rad(wind_from_bearing_deg)
from_world  = Vector3(sin(b), 0.0, -cos(b))      # unit vector pointing toward where the wind comes from
v_wind_true = -from_world * wind_speed_ms         # the air moves the opposite way
```

Check: 270 (from the West) gives `from_world = (-1, 0, 0)` (West is -X) and `v_wind_true = (+8, 0, 0)` for 8 m/s: the air moves East. Zero gives `from_world = (0, 0, -1)` = North.

The legacy `WindSystem.GetWindAtPosition()` does the same thing in two steps: it adds 180 degrees to the FROM bearing and builds `(sin, 0, cos)` (WindSystem.cs:161-168). The `+180` is physics (FROM to TO), not a coordinate-system artefact, and stays. What changes is the sign of the z-component, because Unity's North is +Z (see "Signs" below).

**2. Where and at which height the wind is sampled.**
The legacy samples the wind at the board's origin, `transform.position` (AdvancedSail.cs:163 and :168; ApparentWindCalculator.cs:79), every physics tick. The wind speed there is the current base speed (with gusts and shifts from section 8) multiplied by a height factor:

```
# legacy WindSystem.cs:152-158
if enable_height_gradient and position.y > 0.1:
    height_factor = (max(position.y, 0.1) / reference_height_m) ** shear_exponent    # ref 1 m, exponent 0.14
    speed *= height_factor
```

This is the standard power-law wind profile (wind gets stronger with height above the water because the water surface slows the air near it). Two problems with how the legacy used it:

- The board's origin is at roughly water level (it spawns at y = 0.5 m, WindsurferSetup.cs:683, and then floats at whatever height buoyancy gives it), so the sail's wind was taken at 0 to 0.5 m height, never at the sail. Below the 1 m reference height the factor is *less than 1*: 0.5^0.14 = 0.908, 0.11^0.14 = 0.734.
- The `> 0.1` test makes a step: at y = 0.10 m the factor is 1.0, at y = 0.11 m it is 0.734. The board's origin crossing 0.1 m (every wave, every heave) switched the sail's wind by 27 %. Nothing in the logs mentions this; it is a silent flicker in the validated build.

The spec does this instead:

```
position_sail = centre of effort of the sail in the world frame (section 2 gives it; if the CE is at the
                board origin, use origin + Vector3.UP * boom_height_m)
height_m      = max(position_sail.y - water_height_at(position_sail), 0.2)   # height above the local water surface
v_wind_true   = wind_field.velocity_at(position_sail.x, position_sail.z, height_m)   # section 8 applies the gradient
```

No step at 0.1 m: the clamp to 0.2 m only stops the power law from going to zero at the surface. OPEN: which height Phase 2 should use as the *reference* for "15 kt of wind" in the validation targets. The legacy scene said 15 kt at 1 m; a 1.4 m boom height gives 1.4^0.14 = 1.048 times that. Recommendation: define the configured wind speed at the sail's CE height (that is what the validation polars mean by "wind speed") and let the gradient only act on the difference between the CE height and, later, other heights (flags, spray). Until section 8 decides, Phase 2 may treat the wind as uniform in height.

Sampling with the board's x/z position matters only when the wind varies in space (gust patches, section 8). The legacy `WindSystem` had no spatial variation at all (WindSystem.cs:147-169 uses `position` only for the height); the older `WindManager` used Perlin noise on x/z (WindManager.cs:104-107, history).

**3. The apparent wind vector.**
The apparent wind is the true wind minus the velocity of the point where the sail is:

```
v_point    = v_boat + omega.cross(position_sail - position_cm)   # velocity of the CE; equals v_boat when CE = centre of mass
v_apparent = v_wind_true - v_point
```

Reasoning: if you move at `v` through still air you feel a wind of `-v`. Adding the real wind gives the vector above. The legacy used the rigidbody's linear velocity (the velocity of the centre of mass) without the rotation term (SailingState.cs:100; ApparentWindCalculator.cs:84-85). That was exact for the validated build only because its CE was forced to the origin (AdvancedSail.cs:278-286). As soon as section 2 restores a CE above the deck, the rotation term is what makes a spinning rig feel the extra wind; it is one cross product, so implement it from the start. With `omega = 0` the two formulas agree, which the tests below use.

Vertical component: `v_wind_true` is horizontal, but `v_boat` is not (heave on waves, pitching). The legacy kept the full 3D vector: the apparent wind *speed* used for the sail force was the 3D length (SailingState.cs:101; Aerodynamics.cs:129), the *angle* used the horizontal projection (SailingState.cs:108-113), the angle of attack used the 3D direction (AdvancedSail.cs:328-330; Aerodynamics.cs:150-151), and the resulting force's vertical part was thrown away anyway (AdvancedSail.cs:362-365). That is inconsistent: a board heaving upward at 1 m/s in a 3 m/s head wind got a sail force computed from 3.16 m/s. The spec uses the horizontal apparent wind for speed, angle and (in section 2) forces:

```
v_apparent_h = Vector3(v_apparent.x, 0.0, v_apparent.z)
aws_ms       = v_apparent_h.length()
```

Keep `v_apparent` (3D) available in telemetry for the visuals, but nothing in the physics reads its y. This is a deliberate simplification: a sail is a nearly vertical surface, and the vertical relative flow from heave is a few percent of the wind and changes sign every wave; ignoring it removes a source of force jitter without losing anything the team could feel. Section 2 must agree with this (its input is `v_apparent_h`).

**4. The heading frame.**
The wind angles are measured in the horizontal plane against the bow direction, so they do not change when the board heels or pitches. Build two horizontal unit vectors from the board's basis:

```
forward_world = -basis.z                                  # Godot: the bow is local -Z
forward_h     = Vector3(forward_world.x, 0.0, forward_world.z).normalized()
right_h       = forward_h.cross(Vector3.UP)               # starboard, horizontal (checked below)
heading_deg   = fposmod(rad_to_deg(atan2(forward_h.x, -forward_h.z)), 360.0)
```

Check of `right_h`: for a bow pointing North, `forward_h = (0, 0, -1)` and `(0,0,-1) x (0,1,0) = (0*0 - (-1)*1, (-1)*0 - 0*0, 0*1 - 0*0) = (1, 0, 0)` = East = starboard. Correct. Check of the heading: North gives `atan2(0, 1) = 0`, East `(1,0,0)` gives `atan2(1, 0) = 90 deg`.

If the board is pitched more than about 80 degrees `forward_h` degenerates; keep the previous frame in that case (the board is not sailing anyway). The legacy did the same projection (SailingState.cs:109; AdvancedSail.cs:181) and had no guard.

The rebuild plan's D4 row writes the AWA as `atan2(from_local.x, -from_local.z)` in the board's *local* frame. The two agree exactly when the board is level, and differ by a small amount when heeled (at 30 degrees of heel and 45 degrees of AWA the local-frame value is 40.9 degrees). The spec uses the heading frame (like the legacy) because the wind angle a sailor and a polar diagram mean is the one in the horizontal plane. The tests for D4 run with a level board, where both formulas give the same number.

**5. Apparent wind angle (AWA).**

```
if aws_ms > 0.1:
    from_h  = -v_apparent_h / aws_ms                     # unit vector toward where the apparent wind comes from
    awa_rad = atan2(from_h.dot(right_h), from_h.dot(forward_h))
else:
    awa_rad = twa_rad                                    # same sign convention, see Formula 6 (legacy fallback fixed)
```

`atan2(sideways part, forward part)` gives 0 for wind dead ahead, +pi/2 for wind from starboard, -pi/2 from port and +-pi from dead astern. This is the D4 rule: **positive = wind from starboard**. With a level board `from_h.dot(right_h) = from_local.x` and `from_h.dot(forward_h) = -from_local.z`, so it is D4's `atan2(from_local.x, -from_local.z)`.

The legacy threshold of 0.1 m/s (SailingState.cs:103) stays: below it the direction of a 0.1 m/s wind is noise. The legacy fallback copied `TrueWindAngle`, which in the legacy had the *opposite* sign convention (see Formula 6), so in near-calm the AWA sign flipped. In the spec both angles share one convention, so the fallback is harmless.

Useful closed form for tests (boat moving straight ahead, no leeway):

```
tan(awa) = tws * sin(twa) / (tws * cos(twa) + boat_speed)
aws^2    = tws^2 + boat_speed^2 + 2 * tws * boat_speed * cos(twa)
```

**6. True wind angle (TWA).**

```
tws_ms = Vector3(v_wind_true.x, 0.0, v_wind_true.z).length()
if tws_ms > 0.1:
    from_true_h = -v_wind_true_h / tws_ms
    twa_rad     = atan2(from_true_h.dot(right_h), from_true_h.dot(forward_h))
else:
    twa_rad stays at its previous value
```

Same formula as the AWA with the true wind instead of the apparent wind. **Legacy bug:** `AdvancedSail.cs:182` computed `SignedAngle(-twHorizontal, fwdHorizontal, up)` with the arguments in the *reverse* order of the AWA line (`SignedAngle(fwdHorizontal, -awHorizontal, up)`, SailingState.cs:113). Reversing the arguments negates a signed angle, so the legacy TWA was positive for wind from **port** while the legacy AWA was positive for wind from **starboard**. It only showed on the HUD (AdvancedTelemetryHUD.cs:190) and in the near-calm fallback, so nobody noticed. The spec makes TWA and AWA use one sign rule (D4).

**7. Which side the wind is on.**

```
wind_side = sign(awa_rad)          # +1 starboard, -1 port, 0 exactly ahead or astern
```

The shared notation `sail_side = -wind_side` (boom on the side away from the wind) and the tack name (starboard tack = wind from starboard = `awa > 0`) are used by section 3. Note for section 3: the validated legacy build did **not** derive the tack from the AWA. `AdvancedSail` had a manual `_manualTack` that the player flipped with Space (AdvancedSail.cs:66, :200-208, :551-556; AdvancedWindsurferController.cs:178-182) and `sailSide = -_manualTack`. The `sailSide = -Sign(AWA)` with 5 degree hysteresis that PHYSICS_VALIDATION.md:57-88 describes is an older version; the current code keeps a `_lastSailSide` field but never reads it for hysteresis. The progress log does not say in which session (between 18 and 26) or why the manual tack replaced the automatic one. OPEN for section 3 and the team: automatic side from the AWA (with hysteresis, as the plan's shared notation assumes) or manual with Space.

**8. Velocity made good (VMG).**

```
if tws_ms > 0.5:
    vmg_ms = v_boat.dot(from_true_h)     # from_true_h is horizontal, so v_boat.y drops out
else:
    vmg_ms = 0.0
```

VMG is the part of your speed that takes you toward the wind. Positive = gaining upwind, negative = going downwind. It equals `boat_speed * cos(course angle to the wind)` when the board moves the way it points. Legacy: SailingState.cs:72-80, threshold 0.5 m/s, identical maths.

**9. State flags.**

```
is_in_irons     = abs(awa_rad) < deg_to_rad(30.0) and boat_speed_ms < 1.0     # display/audio only
is_sail_stalled = abs(alpha_rad) > deg_to_rad(25.0)                           # alpha from section 2, display only
```

"In irons" means pointing at the wind with no way on; the sail cannot fill. The legacy set this flag twice each tick: `AdvancedSail.cs:316` with 20 degrees, then `SailingState.UpdateDerivedValues()` (called at AdvancedSail.cs:351) overwrote it at SailingState.cs:89 with 30 degrees. So the effective legacy value was **30 degrees and 1 m/s**; the early return when the apparent wind is under 0.5 m/s (AdvancedSail.cs:303-312) forces it to false. Only the sail cloth (SailDeformer.cs:325) and the sail-flap audio (SailFlapAudio.cs:105) read it. No physics reads it, and the spec keeps it that way: the sail forces at small angles come out of the lift/drag curves in section 2.

`is_sail_stalled` is display only (SailingState.cs:90; AdvancedTelemetryHUD.cs:210). The legacy `IsFinStalled = abs(LeewayAngle) > 15` (SailingState.cs:91) never worked: `SailingState.LeewayAngle` is never assigned anywhere in the code base, so the flag was always false; the fin kept its own stall flag with the configured 14 degrees (AdvancedFin.cs:123; SailingState.cs:191). Section 4 owns the fin stall; this section does not define a fin flag.

Luffing (sail not filled) is a visual/audio quantity, not physics. The legacy rule, shared by cloth and sound so that they agree (SailDeformer.cs:320-331; SailFlapAudio.cs:98-114):

```
if aws_ms > 2.0:
    a = abs(alpha_deg)
    if a < 6.0 or is_in_irons:   luff_target = 1.0
    elif a < 12.0:               luff_target = 1.0 - (a - 6.0) / 6.0
    else:                        luff_target = 0.0
else:                            luff_target = 0.0
luff_amount = lerp(luff_amount, luff_target, 1.0 - exp(-6.0 * dt))    # 6 per second response, frame time
```

Keep it as a telemetry value computed from `alpha`, so phases 6 and 8 read one number.

**10. Point of sail names (display only).**
The validated legacy stack had no point-of-sail classifier (the old `TelemetryHUD` with one was removed in Session 26, PROGRESS_LOG.md:88-89 of the summary table). Two legacy places used bands of the AWA: `PhysicsValidation.cs:75-93` (under 60 degrees "upwind", under 120 "reaching", else "downwind") and the retired `WindsurferControllerV2.cs:398-409` (60 / 90 / 120 / 150 degrees for auto-sheet). Neither is physics. The spec defines names on the **true** wind angle, with standard sailing terminology, for the HUD and for test names:

| Name | abs(TWA), degrees | Note |
|---|---|---|
| In irons / no-go zone | 0 to 35 | the sail cannot drive the board; the upwind Phase 4 test expects no lasting progress here |
| Close-hauled | 35 to 60 | upwind, best VMG around 45 |
| Close reach | 60 to 80 | |
| Beam reach | 80 to 100 | wind from the side |
| Broad reach | 100 to 160 | usually the fastest point for a planing board (open question 2 in the plan) |
| Run | 160 to 180 | dead downwind |

Add 2 degrees of hysteresis at each boundary in the HUD so the label does not flicker. The 35 degree no-go edge is the legacy `ApparentWindCalculator.IsInNoGoZone` default (ApparentWindCalculator.cs:117-120); the old `Sail.cs` used 45 (Sail.cs:146-147) and the plan's Phase 4 test says "about 35 to 40". These numbers describe the outcome of the physics; they must not be fed back into it.

**11. Smoothing and hysteresis.** There is none on the true wind, apparent wind, AWA, TWA or VMG in the legacy: all are recomputed from scratch every 0.02 s physics tick (PHYSICS_DESIGN.md:512). The spec keeps them unsmoothed. Smoothing exists only on the controls (sheet and rake, section on controls), on the luff amount (Formula 9) and, if section 3 chooses automatic sail side, on the tack switch.

### Values

| Name | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `rho_air` | 1.225 | kg/m3 | PhysicsConstants.cs:12 | none |
| `rho_water` | 1025 | kg/m3 | PhysicsConstants.cs:13 | none |
| `g` | 9.81 | m/s2 | PhysicsConstants.cs:18 | none |
| knots to m/s | 0.514444 (1 / 1.94384) | – | PhysicsConstants.cs:21-22 | none |
| Default true wind, validated build | 15 kt = 7.717 m/s from 270 (West) | kt, deg | MainScene.unity:821-822; same as the C# defaults WindSystem.cs:22 and :26 | Wizard slider defaults are 12 kt from 45 (WindsurferSetup.cs:62-63), but until Session 27 the wizard wrote the wrong property names and its wind values were silently ignored (KNOWN_ISSUES.md:77; PROGRESS_LOG.md:119), so scenes built by it kept the C# defaults. Session 27 was never run. **Use 15 kt from 270.** The Session 26 commit stored 22 kt (section 8, OPEN 2). History: the pre-Advanced `WindManager` had 8 m/s and 45 (WindManager.cs:13,16; scene_config.json:198-199). |
| Gusts in the validated scene | on, intensity 0.2, period 8 s; shifts off (15 deg, 60 s if on) | – | MainScene.unity:823-828; WindSystem.cs:30-47 | section 8 |
| Height gradient | on, reference 1 m, exponent 0.14, applied only when y > 0.1 m | – | MainScene.unity:829-831; WindSystem.cs:51-58, :152-158 | spec removes the 0.1 m step (Formula 2) |
| Minimum apparent wind speed for an angle | 0.1 | m/s | SailingState.cs:103; ApparentWindCalculator.cs:91 | none |
| Minimum true wind speed for a TWA | 0.1 | m/s | AdvancedSail.cs:178 | none |
| Minimum true wind speed for VMG | 0.5 | m/s | SailingState.cs:72 | none |
| Apparent wind below which the sail force is zero | 0.5 | m/s | AdvancedSail.cs:303; Aerodynamics.cs:131 | belongs to section 2 |
| In-irons flag | abs(AWA) < 30 deg and speed < 1 m/s | deg, m/s | SailingState.cs:89 (effective, it runs last) | AdvancedSail.cs:316 sets 20 deg first and is overwritten; ApparentWindCalculator.cs:117 uses 35 deg (unused component); Sail.cs:146-147 used 45 deg (old stack) |
| Sail stalled flag | abs(alpha) > 25 | deg | SailingState.cs:90; AdvancedTelemetryHUD.cs:210 | none |
| Fin stalled flag | 15 (never worked) vs 14 (fin config) | deg | SailingState.cs:91 vs SailingState.cs:191 and AdvancedFin.cs:123 | section 4 decides; 14 was the one in use |
| Luffing | alpha < 6 deg full, fades to 0 at 12 deg, only when AWS > 2 m/s, response 6 /s | deg, m/s, 1/s | SailDeformer.cs:52, :62, :320-335; SailFlapAudio.cs:28, :42, :98-114 | none |
| Upwind force penalty (section 2) | factor `clamp((abs(AWA_deg) - 10) / 20, 0, 1)` below 30 deg | – | AdvancedSail.cs:319-324 | Session 22 log says the dead zone went "from 25 to 10 degrees" (PROGRESS_LOG.md:406); SailPhysicsDebugger.cs:108-110 still warns "AWA < 25 - force is zeroed", which is stale |
| Physics tick | 0.02 | s | PHYSICS_DESIGN.md:512 | Godot uses 1/60 s with substeps (plan Phase 2) |

### Where the force acts

This model produces no force. It produces the wind vector that section 2 turns into a force, and the point where that force acts is the sail's centre of effort (section 2). The only geometric decision here is that the apparent wind is evaluated **at that same point** (Formula 3), so that the sail sees the air flow at the place where it pushes. The legacy evaluated it at the board origin and applied the force at the origin too (its CE was zeroed in Session 26, AdvancedSail.cs:278-286), so the two were consistent by accident.

### Signs and the Unity-to-Godot translation

Each direction derived in D4, with the place where Unity would give the opposite sign:

1. **North.** Unity: +Z. Godot: -Z. Every compass vector flips its z: Unity `from = (sin b, 0, cos b)` (WindSystem.cs:176-181) becomes Godot `from = (sin b, 0, -cos b)`. East stays +X in both.
2. **Bow.** Unity `transform.forward` is local +Z; Godot's bow is local -Z, i.e. `-basis.z` (`Vector3.FORWARD`). Starboard is local +X in both.
3. **Starboard from a cross product.** The component formula for the cross product is the same in both engines, but the axes are mirrored, so the same expression names the opposite side. Godot: `forward.cross(UP) = (0,0,-1) x (0,1,0) = (1,0,0)` = starboard. Unity: `Cross(forward, up) = (0,0,1) x (0,1,0) = (-1,0,0)` = port; Unity's starboard is `Cross(up, forward)`. Never copy a cross-product line from `Legacy/`; recompute which side it names.
4. **Signed angles.** Unity's `Vector3.SignedAngle(from, to, up)` is positive when `to` lies clockwise from `from` seen from above (its sign is `sign(up . Cross(from, to))`, and `Cross(forward, right) = (0,1,0)` in Unity). So `SignedAngle(forward, windFrom, up)` at SailingState.cs:113 is **+90 for wind from starboard**; the code and its comment (SailingState.cs:112) are right and the table in PHYSICS_VALIDATION.md:46-50 (port = positive) is wrong, as the plan says. In Godot, `forward.signed_angle_to(starboard, UP)` is **-90** (`(0,0,-1) x (1,0,0) = (0,-1,0)`, dot UP negative), so `signed_angle_to` would silently flip every wind angle. That is why D4 and this section use `atan2(sideways, forward)`, which is engine-independent.
5. **Legacy TWA had the opposite sign to the legacy AWA** because of reversed arguments (AdvancedSail.cs:182 vs SailingState.cs:113), not because of handedness. The spec uses one rule for both.
6. **Yaw.** A positive rotation about +Y turns the bow to starboard in Unity (left-handed) and to **port** in Godot (right-handed): rotating `(0,0,-1)` by +90 degrees about +Y gives `(-1,0,0)`. So `yaw_rate > 0` means turning to port in Godot, and every legacy `AddTorque(Vector3.up * T)` where `T > 0` meant "turn right" (AdvancedSail.cs:523) needs its sign re-derived in the steering section. This section does not apply torques, but the tack-from-velocity fallback at AdvancedSail.cs:480-484 (`Cross(velocity, apparentWind).y > 0`) is one more cross product whose meaning flips.
7. **Leeway sign (for the fin section, since the state flag lived here).** `Hydrodynamics.cs:136` uses `SignedAngle(finForward, velocity, up)`: positive = the board slides toward starboard in Unity. The Godot equivalent with the same meaning is `atan2(v_local.x, -v_local.z)` on the horizontal velocity in the heading frame, exactly like the wind angles.
8. **FROM versus TO.** `WindSystem.GetWindAtPosition()` returns the wind **velocity** (the TO direction times the speed; WindSystem.cs:146, :161-168), and `SailingState.CalculateApparentWind()` negates it to get the FROM direction for the angle (SailingState.cs:111-113). The `-1` at SailingState.cs:113 and ApparentWindCalculator.cs:94 is that negation, nothing else. The pre-Advanced `WindManager` is a trap: its `_windDirectionDegrees` (documented "0 = North/+Z, 90 = East/+X", WindManager.cs:15-16) is turned into `(sin, 0, cos)` **without** the 180 degree flip and returned as the velocity (WindManager.cs:84-89, :127), so there the bearing is the direction the wind blows **toward**. The two legacy providers used opposite conventions for the same-looking field. The spec has one: the config stores the FROM bearing, the wind field returns the velocity (Formula 1).
9. **Heading.** Legacy `SailingState.HeadingAngle` ("degrees from North (Z+)", SailingState.cs:16) was never assigned. The spec's `heading_deg = atan2(forward_h.x, -forward_h.z)` gives 0 = North, 90 = East, clockwise, which is the compass convention of D4 and of `wind_from_bearing_deg`.

### Stabilisers and fudges in this model

| What | Why it was there | What it probably hides | Recommendation |
|---|---|---|---|
| 0.1 m/s minimum before computing an angle (SailingState.cs:103; AdvancedSail.cs:178) | avoid `atan2(0, 0)` noise in calm air | nothing; it is a numerical guard | **Keep** (Formulas 5 and 6). |
| AWA falls back to the TWA in near-calm (SailingState.cs:117) | give the HUD a sensible number when there is no apparent wind | the legacy TWA sign bug made this fallback flip the sign | **Keep** with one shared sign convention. |
| Height gradient with the `y > 0.1` step and sampling at the board origin (WindSystem.cs:152-158; AdvancedSail.cs:163) | Session 18 added the gradient for realism; the step was probably meant to avoid `pow(0, a)` | the sail never saw the wind at its own height; the effective wind was 72 to 100 % of the configured value depending on how high the origin floated, and stepped by 27 % across y = 0.1 m | **Drop the step and sample at the CE height** (Formula 2). This changes the effective wind versus the validated build, so retune in Phase 4 rather than reproduce it. |
| 3D apparent wind speed (SailingState.cs:101; Aerodynamics.cs:129) while the force's vertical part is discarded (AdvancedSail.cs:362-365) | never a decision, just how `Vector3.magnitude` works | on waves the heave velocity inflated the sail force by up to a few percent every wave, adding pitch/heave excitation to the porpoising the team fought in Sessions 24 to 26 | **Use the horizontal apparent wind** for speed, angle and forces (Formula 3). |
| Centre-of-mass velocity instead of the CE point velocity (SailingState.cs:100) | the CE was at the origin, so they were equal | nothing while CE = origin; it becomes wrong the moment section 2 raises the CE | **Implement the point velocity** from the start (Formula 3); it costs one cross product. |
| In-irons flag at 30 deg / 1 m/s, written twice (AdvancedSail.cs:316 then SailingState.cs:89) | Session 12 wanted a no-go zone; Session 22 reduced the physics dead zone and left the flag for visuals | nothing; the flag drives cloth and audio only | **Keep as a display/audio flag** with the effective legacy values, never as a physics input. |
| Upwind force penalty, factor 0 at 10 deg to 1 at 30 deg of AWA (AdvancedSail.cs:319-324) | Session 12 "no-go zone" (PROGRESS_LOG.md:685, :726), softened in Session 22 (PROGRESS_LOG.md:406-407) to a ramp | a sail sheeted to 12 degrees with the wind 15 degrees off the bow has a negative or tiny angle of attack; the lift/drag curves already give no drive and the drag pushes the board back. The penalty probably hid a lift-direction bug of the early sail model that Session 18 fixed | **Drop** (owned by section 2). Re-add only if the Phase 4 no-go test shows lasting progress inside 35 degrees. |
| Manual tack with Space instead of `-sign(AWA)` (AdvancedSail.cs:200-208, :551-556) | undocumented; between Sessions 18 and 26 | the automatic version flapped during tacks (the 5 degree hysteresis in PHYSICS_VALIDATION.md:80-87 was the first fix); manual control also let the sail be "backwinded" on the wrong side, which the normal flip at AdvancedSail.cs:255-266 then hid | **Re-evaluate in section 3**; this section only delivers `wind_side` and `awa_rad`. OPEN. |
| `ApparentWindCalculator` unsigned 3D angle via `Vector3.Angle` (ApparentWindCalculator.cs:91-100) | Session 4 first version | nothing today; not on the validated windsurfer (the wizard adds it only in the "legacy setup" path, WindsurferSetup.cs:1312-1313) | **Drop**; superseded by Formula 5. |

### What Phase 2 must implement

- [ ] `WindField` interface: `velocity_at(position: Vector3) -> Vector3` returning the true wind **velocity** (TO direction times speed, horizontal) from a FROM bearing and a speed in m/s; config stores `wind_from_bearing_deg` and `wind_speed_kt` (or m/s; convert once with 0.514444). Constant wind now; gusts and gradient in section 8.
- [ ] `Vector3(sin(b), 0, -cos(b))` for the FROM direction and its negative for the velocity (Formula 1), with a test at 0, 90, 180, 270.
- [ ] Sample the wind at the sail's CE point (Formula 2), never at the board origin; no 0.1 m step.
- [ ] `v_apparent = v_wind_true - (v_boat + omega x r_ce)` (Formula 3); horizontal part for `aws_ms`.
- [ ] Heading frame `forward_h`, `right_h = forward_h.cross(UP)`, `heading_deg` (Formula 4), with a guard for a near-vertical board.
- [ ] `awa_rad` and `twa_rad` with `atan2(side, forward)` and one sign rule, positive = starboard (Formulas 5 and 6); thresholds 0.1 m/s.
- [ ] `wind_side = sign(awa_rad)` for section 3 (Formula 7).
- [ ] `vmg_ms` (Formula 8), threshold 0.5 m/s.
- [ ] Flags `is_in_irons` (30 deg, 1 m/s), `is_sail_stalled` (25 deg), `luff_amount` (Formula 9) in the `Telemetry` snapshot, none of them read by the physics.
- [ ] `point_of_sail` name from the TWA table (Formula 10), HUD only, with 2 degrees of hysteresis.
- [ ] No smoothing on any of the wind quantities (Formula 11).
- [ ] Do not use `signed_angle_to` anywhere for wind or leeway angles; `tests/unit/test_engine_conventions.gd` pins why.

### Tests Phase 2 should write

True wind for all cases: 8.0 m/s from 270 (West). `from_world = (-1, 0, 0)`, `v_wind_true = (8, 0, 0)`. Level board, `omega = 0`, board moving straight ahead (no leeway). Values rounded to 4 decimals; use a tolerance of 0.01 m/s and 0.1 degrees.

| Case | Heading | `forward_h` | `right_h` | Boat speed | `v_boat` | `v_apparent` | `aws_ms` | AWA (deg) | TWA (deg) | Tack | `vmg_ms` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A: close-hauled, starboard tack | 225 (SW) | (-0.7071, 0, 0.7071) | (-0.7071, 0, -0.7071) | 4.0 | (-2.8284, 0, 2.8284) | (10.8284, 0, -2.8284) | 11.192 | **+30.36** | **+45.0** | starboard (`awa > 0`, sail to port) | +2.8284 |
| B: close-hauled, port tack | 315 (NW) | (-0.7071, 0, -0.7071) | (0.7071, 0, -0.7071) | 4.0 | (-2.8284, 0, -2.8284) | (10.8284, 0, 2.8284) | 11.192 | **-30.36** | **-45.0** | port | +2.8284 |
| C: broad reach, starboard tack | 135 (SE) | (0.7071, 0, 0.7071) | (-0.7071, 0, 0.7071) | 6.0 | (4.2426, 0, 4.2426) | (3.7574, 0, -4.2426) | 5.667 | **+86.53** | **+135.0** | starboard | -4.2426 |
| D: broad reach, port tack | 45 (NE) | (0.7071, 0, -0.7071) | (0.7071, 0, 0.7071) | 5.0 | (3.5355, 0, -3.5355) | (4.4645, 0, 3.5355) | 5.695 | **-96.62** | **-135.0** | port | -3.5355 |

How the numbers were made (case A): `forward_h = (sin 225, 0, -cos 225)`; `right_h = forward_h x UP`; `v_apparent = (8,0,0) - v_boat`; `from_h = -v_apparent / aws`; `awa = atan2(from_h . right_h, from_h . forward_h) = atan2(0.5054, 0.8628) = 30.36 deg`. Cross-check with the closed form: `tan(awa) = 8 sin 45 / (8 cos 45 + 4) = 5.657 / 9.657`, `aws^2 = 64 + 16 + 64 cos 45 = 125.25`. Case C: `tan(awa) = 8 sin 135 / (8 cos 135 + 6) = 5.657 / 0.343` gives 86.5 degrees, the apparent wind has swung almost to the beam although the true wind is well aft, which is exactly what fast reaching feels like. Case D is in the third quadrant (both dot products negative), which is why `atan2` and not `atan` is required.

More tests:

- **Bearing to vector:** 0 gives `from = (0,0,-1)`, 90 gives `(1,0,0)`, 180 gives `(0,0,1)`, 270 gives `(-1,0,0)`; `v_wind_true` is the negative times the speed.
- **Heading:** a board with `forward_h = (0,0,-1)` reports 0; `(1,0,0)` reports 90; `(-0.7071,0,0.7071)` reports 225.
- **Mirror symmetry:** cases A/B and C/D must give equal `aws`, equal `abs(awa)`, equal `vmg` and opposite signs of `awa` and `twa` (the Phase 4 port/starboard symmetry test starts here).
- **Head to wind at rest:** heading 270, speed 0: `awa = twa = 0`, `aws = 8`, `is_in_irons = true`, `vmg = 0`, `wind_side = 0`.
- **No true wind, moving:** `v_wind_true = 0`, heading 0, speed 3 m/s: `v_apparent = (0,0,3)`, `aws = 3`, `awa = 0` (wind from dead ahead), `vmg = 0` (below the 0.5 m/s true-wind threshold).
- **Vertical velocity is ignored:** same as the previous test with `v_boat = (0, 1, -3)`: `v_apparent = (0, -1, 3)`, but `aws_ms = 3.0` (not 3.162) and `awa = 0`.
- **Point velocity:** `v_boat = 0`, `omega = (0, 1, 0)` rad/s, CE at `(0, 0, -1)` relative to the centre of mass, no wind: `v_point = omega x r = (0,1,0) x (0,0,-1) = (-1, 0, 0)`, so `v_apparent = (1, 0, 0)`; with `omega = 0` it is zero.
- **Threshold:** `aws < 0.1` returns `awa = twa` and does not produce NaN.
- **Heel does not change the angles:** roll the board 30 degrees about its own forward axis in case A; `awa` and `twa` stay 30.36 and 45.0 (heading frame). Pitch it 10 degrees: same.
- **Below the true-wind threshold:** `tws = 0.05` gives `vmg = 0` and leaves `twa` unchanged.
- **Convention pin:** `Vector3.FORWARD.signed_angle_to(Vector3.RIGHT, Vector3.UP)` is `-PI/2` in Godot (this is the trap; the pin exists in `test_engine_conventions.gd`, keep it).
- **Point of sail:** TWA 20 gives "in irons", 45 "close-hauled", 90 "beam reach", 135 "broad reach", 170 "run"; the label does not change between 99 and 101 degrees when it was "beam reach" (hysteresis).

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/Scripts/`):
- `Environment/WindSystem.cs:17-58` (fields and defaults), `:87` (knots to m/s), `:99-100` (init), `:103-139` (gust/shift update, per rendered frame), `:147-169` (`GetWindAtPosition`, height gradient and FROM-to-TO flip), `:174-182` (`GetWindFromDirection`), `:187-208` (setters).
- `Physics/Wind/WindManager.cs:13-31` (legacy defaults), `:84-89` and `:95-128` (bearing used as the TO direction), `Physics/Wind/IWindProvider.cs:12-15`.
- `Physics/Core/SailingState.cs:13-24` (fields), `:60-92` (`UpdateDerivedValues`: VMG, totals, flags), `:97-119` (`CalculateApparentWind`), `:16` and `:48` (never-assigned `HeadingAngle`, `LeewayAngle`), `:191` (fin stall angle 14).
- `Physics/Board/AdvancedSail.cs:65-66, :78-79` (manual tack fields), `:92-116` (wind source lookup), `:118-125` (tick order), `:158-192` (`UpdateWindState`, TWA at `:182`), `:200-208` (sail side from manual tack), `:255-266` (normal flipped toward the wind), `:278-286` (CE zeroed), `:296-352` (`CalculateSailForces`: early return `:303-312`, in-irons `:316`, upwind penalty `:319-324`, AoA `:328-330`, derived values `:351`), `:362-365` (vertical force dropped), `:462-484` (tack fallback with a cross product), `:551-566` (`SwitchTack`, `SetTack`), `:586-605` (optimal sheet from the AWA).
- `Physics/Board/ApparentWindCalculator.cs:52-66` (WindManager only), `:74-101` (3D unsigned angle), `:107-111` (`GetApparentWindSide`), `:117-120` (35 degree no-go).
- `Physics/Core/Aerodynamics.cs:129-142` (3D wind speed and direction), `:150-151` (AoA from the 3D direction), `:177-184` (horizontal wind for lift), `:241` (3D drag direction).
- `Physics/Core/PhysicsConstants.cs:12-13, :18, :21-22`.
- `Physics/Core/Hydrodynamics.cs:106-136` (leeway sign).
- `Physics/Board/AdvancedFin.cs:85-123` (fin's own stall flag).
- `Editor/WindsurferSetup.cs:62-63` (wizard wind defaults), `:511-547` (`EnsureWindSystem`), `:683` (spawn height), `:725-741` (sail config), `:1312-1313` (`ApparentWindCalculator` only in the legacy setup path).
- `Player/AdvancedWindsurferController.cs:153-169` (steering inverted on port tack), `:178-182` (Space switches tack).
- `Player/WindsurferControllerV2.cs:398-409` (retired point-of-sail bands), `Physics/Board/Sail.cs:146-147` (old 45 degree no-go).
- `Debug/PhysicsValidation.cs:75-93` (AWA bands 60/120), `Debug/SailPhysicsDebugger.cs:108-110` (stale "AWA < 25" warning).
- `UI/AdvancedTelemetryHUD.cs:188-191, :199-201, :210` (what the HUD showed).
- `Visual/SailDeformer.cs:52, :62, :320-335` and `Audio/SailFlapAudio.cs:28, :42, :98-114` (luffing rule).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:803-831` (the WindSystem values of the validated scene).

Legacy documents:
- `Legacy/Documentation/PHYSICS_DESIGN.md:263-280` (true vs apparent wind), `:463-483` (Unity coordinate system), `:486-512` (update loop, 0.02 s tick).
- `Legacy/Documentation/PHYSICS_VALIDATION.md:23-53` (AWA table, port/starboard swapped), `:57-88` (older automatic sail side with 5 degree hysteresis).
- `Legacy/Documentation/PROGRESS_LOG.md:76-77` (formula table), `:119` and `Legacy/Documentation/KNOWN_ISSUES.md:77` (wizard wind values ignored before Session 27), `:283-313` (Session 18 sign chain), `:406-407` (Session 22 dead-zone change), `:685, :716, :726` (Session 12 no-go zone), `:930, :946` (Session 4 apparent wind).
- `Legacy/Documentation/scene_config.json:185-199` (2025-12-27 WindManager values, history only).

This project:
- `Documentation/REBUILD_PLAN.md:57-71` (D4 table), `:290-300` (known legacy pitfalls), `:209-216` (Phase 4 validation tests that consume TWA and VMG).
- `CLAUDE.md`, "Architecture rules" 4 and 5.

Literature and engine facts:
- Apparent wind triangle and VMG: any sailing-theory text, e.g. C. A. Marchaj, *Sail Performance: Theory and Practice*, chapter on apparent wind; the closed forms in Formula 5 follow from the law of cosines.
- Power-law wind profile with exponent 0.10 to 0.15 over open water: e.g. Larsson and Eliasson, *Principles of Yacht Design*, chapter on the sailing environment.
- Unity `Vector3.SignedAngle` sign: `sign(axis . Cross(from, to))` (UnityEngine reference source, `Vector3.cs`); Godot `Vector3.signed_angle_to`: sign of `cross(to).dot(axis)` (Godot 4.7 `vector3.h`; confirm with `tools/api_docs.sh` and `.godot_api/doc/classes/Vector3.xml`).

---

## 2. Sail: lift, drag, centre of effort, sail side and sheeting

### Purpose

The sail is the engine. Air flows past it, and because the sail is a curved surface set at an angle to that flow, the air on one side speeds up and its pressure drops. The pressure difference is a force on the cloth. Following aircraft practice we split that force in two: **lift**, at right angles to the apparent wind, and **drag**, along the apparent wind. Lift is what lets a windsurfer sail across and even against the wind; drag is what pushes it on a run and what holds it back everywhere else.

This section says how the game turns the apparent wind (section 1) and the sailor's two rig controls, **sheet** (how far the boom is pulled in) and **sail side** (which side of the board the boom is on), into a force vector and the point on the rig where it acts. The fin (section 4) and the hull (sections 5 and 6) turn that force into motion. Mast rake steering, pitch stabilisation and speed-dependent angular damping also live in the legacy sail file, but they are section 3.

The legacy Unity build has two sail models. `AdvancedSail.cs` plus `Aerodynamics.cs` is the one that was in the validated scene from Session 13 onwards (it is the only sail component in `MainScene.unity` at Session 24 and at Session 27). The older `Sail.cs` was not in the scene after Session 13; it matters here only as history and because the Session 24 "downforce" was written into it.

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `v_apparent` | apparent wind velocity, world frame, sampled at the centre of effort (section 1, Formula 3) | m/s |
| `v_apparent_local` | the same vector in the body frame (`basis.inverse() * v_apparent`) | m/s |
| `aws_ms` | `v_apparent.length()` | m/s |
| `awa_rad` | apparent wind angle, `atan2(from_local.x, -from_local.z)` with `from_local = -v_apparent_local`; positive = wind from starboard (section 1) | rad |
| `sheet` | control, 0 = fully out, 1 = fully in (F0.10) | – |
| `sail_side` | state, +1 = boom on the starboard side (port tack), −1 = boom on the port side (starboard tack) (F0.9) | – |
| `rake` | control, −1 to +1, positive = mast raked back (section 3 owns its effect on steering; here it only moves the centre of effort) | – |
| `rake_rad` | `rake * rake_max_rad` | rad |
| `sail_area_m2`, `luff_m`, `boom_m`, `camber`, `boom_height_m`, `mast_foot_local` | sail geometry from `SailConfig` (Values table) | m², m, m, –, m, m |
| `sheet_angle_rad` | output: angle between the boom and the centreline, 0 = boom along the centreline | rad |
| `alpha_rad` | output: signed angle of attack, positive = the wind hits the sail's windward (pressure) face | rad |
| `cl`, `cd` | output: lift and drag coefficients | – |
| `f_lift`, `f_drag`, `f_sail` | output: lift, drag and their sum, world frame, horizontal | N |
| `ce_local`, `ce_world` | output: centre of effort, the point where `f_sail` acts | m |
| `is_luffing` | output: `alpha_rad <= 0` (the sail is eased past the wind or on the windward side) | bool |

Everything in the formulas is SI (m, s, kg, N, rad). Degrees appear only in tables and in the names of test cases.

### Formulas

The legacy computed most of this in 3D with world-frame vectors, then threw the vertical component away (AdvancedSail.cs:363-364) and used only the horizontal part of the sail normal for the lift direction (Aerodynamics.cs:207-224). The net effect is a **two-dimensional model in the horizontal plane** with the rig standing vertically over the water. The spec makes that explicit: every direction below is a horizontal unit vector in the body frame, and the rig is assumed vertical regardless of the board's heel and pitch (that is what a windsurfer does with the universal joint at the mast foot; the old `Sail.cs:215-218` said the same). See "Signs" for what heel did in the legacy 3D code.

**2.1 Sheet position to boom angle.** The sheet control sets the boom angle from the centreline directly (no wind-relative trimming inside the sail since Session 22, PROGRESS_LOG.md:404):

```
sheet_angle_rad = lerp(sheet_angle_out_rad, sheet_angle_in_rad, sheet)      # F0.10
                = deg_to_rad(85.0) + (deg_to_rad(12.0) - deg_to_rad(85.0)) * sheet
```

The legacy is `Mathf.Lerp(12f, 85f, _sheetPosition)` with 0 = in and 1 = eased (AdvancedSail.cs:224-226); the spec's `sheet` is `1 - _sheetPosition`, hence the reversed lerp. A real sail cannot be pulled to the centreline (the boom hits the sailor and the sail would stall), so the range is clamped to [12°, 85°]. Physically the boom angle is what the sailor's arms hold; the wind does not move it in this model.

**Rate of change.** The legacy sail moved `_sheetPosition` toward its target at 1.5 per second (AdvancedSail.cs:32, :147-148), but the controller that fed it moved its own value at 0.8 per second (AdvancedWindsurferController.cs:29, :220) after smoothing the key press over 1/8 s (:68, :198), so the effective rate in the validated build was **0.8 per second: full travel from 85° to 12° in 1.25 s**. Following section 0 (fudge 4), the sim takes `sheet` as given and the rates belong to the controller (Phase 3). Also note: the controller's `_currentSheetPosition` had no initialiser (:80) and was written to the sail every tick (:223), so the validated build started with the sail's 0.65 default overridden to **0 = fully sheeted in (12°)** within half a second of pressing Play, not the 0.65 the scene file shows.

**2.2 Boom (chord) direction and the reference normal.** The chord runs from the mast to the clew, aft and toward the sail side (F0.11):

```
chord_local = Vector3(sail_side * sin(sheet_angle_rad), 0.0, cos(sheet_angle_rad))
n0_local    = Vector3(cos(sheet_angle_rad), 0.0, -sail_side * sin(sheet_angle_rad))
```

`n0_local` is the horizontal unit normal to the chord that points **away from the sail side**, i.e. toward the side the wind should come from when the sail is on the leeward side. Check: `chord_local.dot(n0_local) = sail_side·sinθ·cosθ − cosθ·sail_side·sinθ = 0`; for the boom to port (sail_side = −1) and θ small, `n0_local ≈ (1, 0, small)` = starboard. The legacy built its normal as `Cross(chord, up)` and then flipped it to face the wind (AdvancedSail.cs:252-266); the flip makes the cross product's handedness irrelevant, and the spec avoids the cross product altogether.

**2.3 Angle of attack.** Let `w_hat` be the horizontal unit vector of the apparent wind's direction of travel and `from_hat = -w_hat` where it comes from, both in the body frame:

```
w_hat    = Vector3(v_apparent_local.x, 0.0, v_apparent_local.z).normalized()
from_hat = -w_hat
sin_alpha = clamp(from_hat.dot(n0_local), -1.0, 1.0)
alpha_rad = asin(sin_alpha)                                   # signed, in [-π/2, +π/2]
```

`alpha_rad` is the angle between the wind and the sail's chord line. Positive means the wind hits the face of the sail that faces away from the boom side: the normal, powered situation. Negative means the wind hits the other face: the sail is **backwinded** (eased past the wind, or the boom is on the windward side because the tack was not switched). In the everyday case of the sail on the leeward side and the wind forward of the beam, this reduces to

```
alpha_rad = abs(awa_rad) - sheet_angle_rad          # valid while abs(awa) - sheet_angle is within ±π/2
```

Derivation for wind from starboard at angle `a` (from_hat = (sin a, 0, −cos a)), boom to port (sail_side = −1, n0 = (cos θ, 0, sin θ)): `from_hat·n0 = sin a cos θ − cos a sin θ = sin(a − θ)`, so `alpha = a − θ`. On a run the `asin` folds the angle back: wind dead astern (a = 180°) and the boom at 85° gives `sin(95°) = 0.996`, `alpha = 85°`, which is the right "plate almost square to the wind" value.

The legacy computed `AngleOfAttack = 90° − acos(dot(−awDir, sailNormal))` with the 3D normal that had already been flipped toward the wind (AdvancedSail.cs:328-330, Aerodynamics.cs:150-151), so its angle of attack was always **≥ 0** and equal to `abs(alpha_rad)` here. The sign was lost; the spec keeps it because luffing (2.9) needs it.

**2.4 Aspect ratio and the 3D lift slope.** A short, wide wing loses lift at its tips, so the lift per degree is lower than the thin-airfoil value 2π per radian. The Helmbold/Prandtl correction for a finite wing is

```
aspect_ratio = luff_m * luff_m / sail_area_m2                        # 4.7² / 6.5 = 3.398
lift_slope_per_rad = 2.0 * PI * aspect_ratio / (aspect_ratio + 2.0) * 0.9   # = 3.560 per rad for AR 3.398
```

The 0.9 is an unexplained "reduction for sail flexibility and gaps" (Aerodynamics.cs:38). The aspect ratio is `LuffLength²/Area` (SailingState.cs:160). `Aerodynamics.cs:24` and `:79` have a default parameter of 4, but `AdvancedSail.cs:339` always passed the configured value, so 4 was never used.

**2.5 Camber (zero-lift angle).** A cambered sail already lifts at zero angle of attack, because its curve turns the air even when the chord is aligned with the flow. The legacy shifts the curve by

```
alpha_zero_lift_rad = -camber * deg_to_rad(60.0)        # camber 0.10 → -6°
alpha_eff_rad = alpha_rad - alpha_zero_lift_rad         # = alpha + 6° for camber 0.10
```

(Aerodynamics.cs:32-33). Thin-airfoil theory for a circular-arc section gives `alpha_zero_lift = -2 * camber` rad = −11.5° for camber 0.10; the legacy's 60°-per-unit-camber is about half of that, a plausible allowance for a soft sail that does not hold its full shape. No literature source is cited in the legacy for the 60. `Twist` (10°, SailingState.cs:148) is **not used** by the physics; only the cloth visual reads it (SailDeformer.cs:341).

**2.6 Lift coefficient curve (legacy, exactly as coded).** With `a = abs(alpha)` in degrees for the region tests, `k = lift_slope_per_rad` and `d = deg_to_rad`:

```
if a < 12:      cl = k * (d(a) - alpha_zero_lift_rad)                      # linear, includes camber
elif a < 18:    cl = k * d(12) + 0.3 * (a - 12) / 6                        # NOTE: k*d(12), camber dropped
elif a < 25:    cl_max = k * d(12) + 0.3
                cl = lerp(cl_max, 0.85 * cl_max, (a - 18) / 7)
elif a < 45:    cl_stall = 0.85 * k * d(12)                                # NOTE: not 0.85 * cl_max
                cl = lerp(cl_stall, 0.5, (a - 25) / 20)
else:           cl = 0.5 * cos(d(a - 45))
```

(Aerodynamics.cs:42-72.) The physics behind the shape: lift grows linearly with angle until the flow starts to separate from the leeward side (12°), keeps growing more slowly to a peak (18°), then the sail stalls and lift falls; past 45° the sail is a flapping plate whose "lift" is whatever sideways component the plate force has, falling to zero when the plate is square to the wind (at 135°, which never happens because `asin` limits alpha to 90°).

**This curve is wrong at two points.** The transition branch (:50) computes `linearCl` from 12° *without* the 6° camber shift that the linear branch (:45) uses, so at 12° the coefficient **drops from 1.118 to 0.746** (a 33 % step). The post-stall branch (:64) starts from `0.85 × k×d(12)` while the near-stall branch ends at `0.85 × (k×d(12) + 0.3)`, so at 25° it **drops from 0.889 to 0.634**. These are bugs, not modelling choices: a 33 % jump in sail force when the sheet moves by one degree cannot be what anyone intended, and the validated build had the auto-trim target of 17° sitting inside the 12° to 18° band where the curve is lowest. The table under "Values" lists both curves at each angle.

**2.7 Lift coefficient curve (spec).** Keep the legacy shape and numbers, remove the two steps by using the same base value in every branch, and add a luff fade (2.9):

```
cl_12  = k * (d(12) - alpha_zero_lift_rad)          # value of the linear branch at 12°: 1.118
cl_max = cl_12 + 0.3                                # 1.418 at 18°
if a < 12:      cl = k * (d(a) - alpha_zero_lift_rad)
elif a < 18:    cl = cl_12 + 0.3 * (a - 12) / 6
elif a < 25:    cl = lerp(cl_max, 0.85 * cl_max, (a - 18) / 7)
elif a < 45:    cl = lerp(0.85 * cl_max, 0.5, (a - 25) / 20)
else:           cl = 0.5 * cos(d(a - 45))
```

`cl_max = 1.418` at 18° is inside the range the yacht-design literature gives for a single soft sail (about 1.3 to 1.6, Marchaj; Larsson and Eliasson). Because the continuous curve is up to 50 % higher than the legacy one between 12° and 25°, **Phase 4 must retune** rather than expect the legacy speeds. The 12/18/25/45° breakpoints, the +0.3, the 0.85 and the 0.5 are config values so the team can tune them.

**2.8 Drag coefficient.** Drag has three physical parts: skin friction and mast/boom drag (constant), induced drag (the price of lift on a short wing, growing with the square of lift), and separation drag once the flow detaches:

```
cd_parasitic = 0.015
cd_induced   = cl * cl / (PI * aspect_ratio * 0.75)                    # Oswald efficiency e = 0.75
cd_separation = 0.5 * ((a - 15) / 30)² if a > 15 else 0
cd_form       = 1.2 * sin(d(a))        if a > 45 else 0
cd = cd_parasitic + cd_induced + cd_separation + cd_form
```

(Aerodynamics.cs:84-105.) `PI * 3.398 * 0.75 = 8.008`, so at cl = 0.896 the induced part is 0.100. **Doubtful:** the separation term is unbounded (3.125 at 90°) and stacks on the 1.2 form term, giving `cd = 4.36` at 90°. A flat plate square to the flow has cd ≈ 1.2 (Hoerner, *Fluid-Dynamic Drag*), and a sail on a run is quoted at about 1.2 to 1.5 (Marchaj). With the legacy numbers a dead run in 15 kt of wind at 5 m/s boat speed gives 393 N of drag-drive from a 6.5 m² sail, roughly three times the physical value, and that is the main reason the legacy could run downwind faster than it should. **Spec: clamp `cd` to `cd_max = 1.3`** (config value; OPEN 2.1 asks Phase 4 to confirm). With the legacy formula the clamp engages from about 48° upward, which makes the plate drag flat between 48° and 90°; that is crude but closer to Hoerner's plate data than 4.36.

**2.9 Luffing (spec; nothing equivalent in the legacy).** A soft sail cannot carry lift when the wind comes at it from the wrong face: the luff collapses and the cloth flaps. The legacy had no such rule; because its angle of attack was unsigned (2.3) it treated a backwinded sail as a rigid plate producing full lift toward the other side, and covered the near-head-to-wind case with an AWA-based penalty (fudge S2.2). The spec replaces both with a factor on lift only:

```
if alpha_rad <= 0.0:                     luff_factor = 0.0          # backwinded: flapping, no lift
elif alpha_rad < alpha_luff_rad:         luff_factor = alpha_rad / alpha_luff_rad
else:                                    luff_factor = 1.0
cl = cl * luff_factor
is_luffing = alpha_rad <= 0.0
```

with `alpha_luff_rad = deg_to_rad(5.0)`. The 5° is a spec choice, not a legacy physics value: the only legacy number is the cloth visual's `_luffAngleOfAttack = 6°` (SailDeformer.cs:52, display only). The drag is not reduced (a flapping sail still has at least its parasitic drag, and at alpha ≤ 0 the coefficient formula gives `cd_parasitic + cd_induced(cl=0) = 0.015`). OPEN 2.2: the value of `alpha_luff` and whether the no-go zone (no lasting progress inside about 35° to 40° TWA) then emerges from the force balance with the fin and hull, which is what the Phase 4 test must show.

**2.10 Dynamic pressure and force magnitudes.**

```
q_pa = 0.5 * rho_air * aws_ms * aws_ms          # rho_air = 1.225 kg/m³
lift_n = q_pa * sail_area_m2 * cl
drag_n = q_pa * sail_area_m2 * cd
```

(Aerodynamics.cs:158-162; PhysicsConstants.cs:12.) If `aws_ms < 0.5` the sail produces nothing (Aerodynamics.cs:131-136; AdvancedSail.cs:303-312): keep this early return, it only avoids dividing by a zero-length wind vector.

**2.11 Force directions.** Drag acts along the apparent wind's travel direction. Lift is perpendicular to it, on the side toward which the sail pushes the air away, which is the side its suction face is on:

```
drag_dir_local = w_hat
force_normal   = -sign(alpha_rad) * n0_local           # from the pressure face to the suction face
lift_dir_local = (force_normal - force_normal.dot(w_hat) * w_hat)   # the part of it perpendicular to the wind
if lift_dir_local.length() > 0.1:  lift_dir_local = lift_dir_local.normalized()
else:                              lift_n = 0.0                        # plate square to the wind: no lift direction
f_lift_local = lift_dir_local * lift_n
f_drag_local = drag_dir_local * drag_n
f_sail_local = f_lift_local + f_drag_local
f_sail = basis * f_sail_local                                          # rotate into the world frame; y stays 0
```

This is exactly the legacy "project −sailNormal onto the wind-perpendicular plane" (Aerodynamics.cs:219-228; PHYSICS_VALIDATION.md:116-129) written with the signed alpha: the legacy normal was always flipped toward the wind, so its `−sailNormal` equals `−sign(alpha)·n0` here. The projection uses dot products only, so it is the same in a left- and a right-handed frame. It generalises correctly past the beam: with the wind dead astern and the boom at 85° to port the force normal is `(−0.087, 0, −0.996)`, mostly forward (drive by drag) with a small lift to port.

For the everyday case (sail on the leeward side, `0 < abs(awa) − sheet_angle < 90°`) there is a shortcut that Phase 2 tests can use as a cross-check: `lift_dir_local = sail_side * Vector3.UP.cross(w_hat)`, i.e. the lift is the apparent wind's travel direction rotated 90° toward the bow. It is **not** valid past the fold in 2.3, so the implementation must use the projection.

The legacy also had a "liftSign" from the sign of its angle of attack with a 1° dead band (Aerodynamics.cs:245-248); because the angle was never negative the sign was always +1, and the spec drops it. The legacy edge cases for a vertical wind (Aerodynamics.cs:177-183) and a vertical normal (:207-216) cannot occur in the 2D model.

**2.12 Vertical force and heel.** The spec's force is horizontal by construction. The legacy zeroed `y` after the fact (AdvancedSail.cs:363-364). A raked rig does produce a small vertical component in reality; it is left out (OPEN 2.3, later phase). Heel of the board does **not** change the sail force: the rig is held vertical by the sailor. The legacy had no explicit "effective area when heeled" term either; its 3D normal tilted with the board, which shrank the angle of attack by roughly `cos(heel)` for a beam wind (AdvancedSail.cs:269, :329), an accidental effect that the 2D spec removes on purpose. If Phase 4 wants heel to matter, the physical place is a rig-heel control (the sailor raking the rig to windward), not the board's heel.

**2.13 Centre of effort.** The point on the rig where the net force is taken to act. In the body frame:

```
ce_height_m  = ce_height_fraction * luff_m                       # 0.40 × 4.7 = 1.88 m above the mast foot, along the mast
ce_aft_m     = ce_boom_fraction * boom_m                         # 0.35 × 2.0 = 0.70 m from the mast along the chord
ce_local = mast_foot_local
         + Vector3(0.0, ce_height_m * cos(rake_rad), ce_height_m * sin(rake_rad))   # up the (raked) mast; +z = aft
         + chord_local * ce_aft_m                                                    # along the boom
ce_world = position + basis * ce_local
```

Raking the mast back (rake_rad > 0) swings the CE aft by `ce_height_m * sin(rake_rad)` (0.49 m at 15°) and lowers it slightly; this is the geometric source of rake steering (section 3). The lateral position follows the boom (to leeward when sheeted out), which is what gives a sail its weather helm.

What the legacy did, in order (see "Stabilisers", S2.4): height from the config (0.8 m) and 50 % of the boom in Session 13; 0.3 m and a fixed 0.1 m to the side in Session 16; 0.0 m, 35 % of the boom sideways and 0.3 × that aft in Session 25; and `Vector3.zero` (the board origin) from Session 26 on (AdvancedSail.cs:283-291). The last validated build therefore applied the sail force at the board's origin, producing **no torque from the sail at all** except through the origin-to-centre-of-mass offset (see "Where the force acts"). The fractions 0.40 and 0.35 above are spec choices: for a soft sail the centre of pressure sits at roughly 35 to 40 % of the chord aft of the luff (a flat plate's is at 25 %, camber moves it aft; Marchaj), and the area centroid of a triangular sail is at one third of its height, higher for the fuller heads of modern windsurf sails. OPEN 2.4: in Phase 6 compute the area centroid of the sail mesh (the `sail.fbx` cloth is 5.08 m by 2.8 m) and put the measured height and chord fractions in the config.

**How the force is applied**, given the rigid-body model (one body: board, sailor and rig; section 7):

- Option A (default for Phase 2): apply `f_sail` at `Vector3(ce_local.x, mast_foot_local.y, ce_local.z)`, that is at the CE's horizontal position but at deck height. Reasoning: the yaw moment depends only on the horizontal position, so it is exact. The heeling and pitching moments of a windsurf rig are taken by the sailor's arms and stance (the mast foot is a universal joint and transmits no moment); until the sailor model (section 7) can lean against them, assuming the sailor cancels them is the honest approximation. This is the Session 25 geometry with the height at deck level and without its unexplained 0.3 on the aft offset.
- Option B (Phase 4 experiment, with the sailor's counter-lean from section 7): apply at the full `ce_local`. Then the sail's heeling moment (about 535 N·m in the worked example below) and bow-down moment (about 400 N·m) act on the body and the sailor's weight has to balance them. This is what the plan's known issue 1 (KNOWN_ISSUES.md:30-46, "sail-to-board roll transfer") asks for.

**2.14 Sail side and tacking.** The physics side is F0.9 with hysteresis (section 0, fudge 1):

```
if abs(awa_rad) >= deg_to_rad(5.0) and abs(awa_rad) <= PI - deg_to_rad(5.0):
    sail_side = -sign(awa_rad)          # +1 = boom to starboard when the wind is from port
else:
    sail_side = previous sail_side      # head to wind or dead downwind: keep the side
```

The legacy validated build did **not** do this: since Session 22 (commit 5a1857a) `sailSide = -_manualTack`, where `_manualTack` starts at +1 (starboard tack, boom to port, AdvancedSail.cs:66) regardless of the wind, and the Space key flips it (AdvancedSail.cs:549-554; AdvancedWindsurferController.cs:178-182). The switch was instant (the boom angle jumped from +θ to −θ in one 0.02 s tick, no swing through the centreline) and there was no check that the new side was leeward, so the sail could sit on the windward side; the plate model (2.11) then still produced a force. The Session 18 version had `sailSide = -Sign(AWA)` with "keep the last side if |AWA| < 5°" (commit 4c45223 AdvancedSail.cs:211-229; PHYSICS_VALIDATION.md:57-87), only at head to wind, so a dead run chattered between ±180°. The spec adds the same 5° band at ±π for gybes. The flip is instant in the sim; whether Phase 3's Space key flips `sail_side` directly (arcade) or only steers through the wind and lets the physics flip (simulation) is the OPEN question section 0 raised; in either case the physics luffs (2.9) while the sail is on the windward side, which is what a real backwinded sail does.

**2.15 Automatic trimming (legacy; controller-level in the spec).** Two legacy helpers put the sail at a target angle of attack of 17° by setting the boom angle to `abs(awa) − 17°`:

- inside the sail, `_autoTrim` (off by default, AdvancedSail.cs:35; MainScene.unity:344): `optimalSailAngle = clamp(|AWA| − 17°, 12°, 85°)`, converted to a sheet position by `(angle − 12) / 73` (AdvancedSail.cs:586-607);
- `Aerodynamics.CalculateOptimalSheetAngle` (:255-268) with the same 17° but a clamp to **5°**..85° (:265), used by the controller's auto-sheet (T key, off by default, AdvancedWindsurferController.cs:32, :210-216) through `GetOptimalSheetPosition` (AdvancedSail.cs:633-637), which maps with `(angle − 12) / 73` and can go negative for angles under 12°, harmlessly clamped later.

Neither was active in the validated build. The spec keeps the sim free of trimming; the Phase 4 autopilot trims the sheet for best speed on its own and may start from `sheet = 1 − (abs(awa_deg) − 17 − 12) / 73`.

**2.16 Worked example.** Apparent wind 10 m/s at `awa = +90°` (from starboard, dead abeam), sail 6.5 m², luff 4.7 m, camber 0.10, sheeted so that `alpha = 15°` (boom at 75° to port: `sheet_legacy = 0.863`, spec `sheet = 0.137`).

- `aspect_ratio = 3.398`; `lift_slope_per_rad = 2π × 3.398/5.398 × 0.9 = 3.560`.
- Legacy `cl(15°) = 3.560 × 0.2094 + 0.3 × 3/6 = 0.746 + 0.150 = 0.896`; `cd = 0.015 + 0.896²/8.008 + 0 = 0.015 + 0.100 = 0.115`.
- `q = 0.5 × 1.225 × 100 = 61.25 Pa`; `q × A = 398.1 N`.
- **Lift 356.6 N, drag 45.9 N** (legacy coefficients). With the spec curve (2.7) `cl = 1.118 + 0.150 = 1.268`, `cd = 0.015 + 1.268²/8.008 = 0.216`: lift 504.8 N, drag 85.9 N. With a 6.0 m² sail and the legacy curve: AR 3.682, slope 3.664, cl 0.917, cd 0.112, lift 337 N, drag 41 N.
- Directions in the body frame (Godot: bow −z, starboard +x): `w_hat = (−1, 0, 0)` (the air travels to port). `n0 = (cos 75°, 0, sin 75°) = (0.259, 0, 0.966)`; `from_hat·n0 = 0.259 = sin 15°` ✓. `force_normal = −n0 = (−0.259, 0, −0.966)`; projecting out the wind leaves `(0, 0, −0.966)`, normalised `(0, 0, −1)`: **lift points straight forward**. Drag points to port.
- `f_lift_local = (0, 0, −356.6) N`, `f_drag_local = (−45.9, 0, 0) N`, `f_sail_local = (−45.9, 0, −356.6) N`: 356.6 N of drive, 45.9 N of side force to port (leeward).

The same rig at `awa = +45°` and `alpha = 15°` (boom at 30°): `w_hat = (−0.707, 0, 0.707)`, lift direction `(−0.707, 0, −0.707)`, `f_sail_local = (−284.5, 0, −219.7) N`: drive `L sin 45° − D cos 45° = 219.7 N`, side force `L cos 45° + D sin 45° = 284.5 N` to port.

### Values

| Name | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `rho_air` | 1.225 | kg/m³ | PhysicsConstants.cs:12; Sail.cs:92 | none |
| `sail_area_m2` | **6.5** | m² | SailingState.cs:130 (default); PhysicsConstants.cs:43; WindsurferSetup.cs:729; MainScene.unity:334 | 6.0 in PHYSICS_DESIGN.md:544 and scene_config.json:75 (old `Sail`, 2025-12-27); 7.5 in Sail.cs:24 (old). The validated build used 6.5: the scene file and the wizard both say so, and the wizard's summary text (WindsurferSetup.cs:852) calls it "6.5m²". |
| `luff_m` | 4.7 | m | SailingState.cs:133; PhysicsConstants.cs:44; WindsurferSetup.cs:730; MainScene.unity:335 | none |
| `boom_m` | 2.0 | m | SailingState.cs:136; PhysicsConstants.cs:45; WindsurferSetup.cs:731; MainScene.unity:336; Sail.cs:48 | none |
| `mast_height_m` | 4.6 | m | SailingState.cs:139; PhysicsConstants.cs:46; WindsurferSetup.cs:732; MainScene.unity:337 | 4.5 in Sail.cs:45. Not used by the physics (gizmo only, AdvancedSail.cs:755-756). Note that the luff (4.7) is longer than the mast; harmless. |
| `camber` | 0.10 | – | SailingState.cs:144 (range 0.05 to 0.20, :143); WindsurferSetup.cs:733; MainScene.unity:338; Aerodynamics.cs:24 default | none |
| `twist_deg` | 10 | deg | SailingState.cs:148; MainScene.unity:339 | visual only (SailDeformer.cs:341); not a physics input |
| `mast_foot_local` | (0, 0.1, −0.1) Unity = **(0, 0.1, +0.1) Godot** (0.1 m above the origin, 0.1 m aft) | m | SailingState.cs:152; WindsurferSetup.cs:46 and :734; MainScene.unity:340 | (0, 0.1, −0.05) in Sail.cs:42 and in the wizard's help text WindsurferSetup.cs:117, which also wrongly calls it "slightly forward of center" (−z is aft in Unity). Since Session 26 it affected only the gizmos and the visual mast. OPEN 2.5: the real mast track of a 2.5 m board is about 0.05 to 0.15 m *forward* of mid-length; the value must be set with the board origin chosen in Phase 6. |
| `boom_height_m` | 1.4 | m | SailingState.cs:155; WindsurferSetup.cs:735; MainScene.unity:341 | 1.8 in Sail.cs:51 and PHYSICS_DESIGN.md:363. Used by the physics only through the retired `CenterOfEffortHeight` (SailingState.cs:166 = 0.1 + 0.7 = 0.8 m, used in Session 13) and the gizmo (AdvancedSail.cs:694). |
| `aspect_ratio` | 3.398 (computed) | – | SailingState.cs:160 | Aerodynamics.cs:24, :79 default 4 (never used) |
| `sheet_angle_in_deg` | 12 | deg | AdvancedSail.cs:224; :601; :604; :636 | 15 in Sail.cs:316 (old); 5 in Aerodynamics.cs:265 (auto-sheet clamp) |
| `sheet_angle_out_deg` | 85 | deg | AdvancedSail.cs:225 | 80 in Sail.cs:317 (old) |
| sheet default | 0.65 legacy (= 0.35 spec) | – | AdvancedSail.cs:29; MainScene.unity:342; PROGRESS_LOG.md:1462 (0.5 → 0.65 in Session 16) | 0.5 in Sail.cs:35; effectively **0 legacy = 1 spec (fully in)** at start because AdvancedWindsurferController.cs:80 and :223 overwrite it |
| sheet rate | 1.5 (sail), 0.8 (controller, effective) | 1/s | AdvancedSail.cs:32, :147-148; AdvancedWindsurferController.cs:29, :220 | 2.0 in Sail.cs:38. Controller-owned in the spec. |
| input smoothing | 8 | 1/s | AdvancedWindsurferController.cs:68, :198 | controller-owned |
| auto-trim target alpha | 17 | deg | AdvancedSail.cs:599; Aerodynamics.cs:261 | off by default (AdvancedSail.cs:35; MainScene.unity:344; AdvancedWindsurferController.cs:32); auto-sheet speed 0.3 /s (:35) |
| `rake_max_deg` | 15 | deg | AdvancedSail.cs:42; WindsurferSetup.cs:736; MainScene.unity:346; Sail.cs:66 | none (section 3) |
| rake rate | 3 (sail), 2 (controller), 1 auto-centre | 1/s | AdvancedSail.cs:45, :151-152; AdvancedWindsurferController.cs:39, :45 | 5 in Sail.cs:69; section 3 |
| sail-side hysteresis | 5 | deg | commit 4c45223 AdvancedSail.cs:217; PHYSICS_VALIDATION.md:80-87 | removed from the code in Session 22; the spec restores it and adds it at ±180° |
| initial manual tack | +1 (boom to port) | – | AdvancedSail.cs:66 | spec: from the wind |
| `alpha_zero_lift` | −60 × camber = −6 | deg | Aerodynamics.cs:32 | thin-airfoil theory would give −2 × camber rad = −11.5° |
| lift slope factor | 0.9 | – | Aerodynamics.cs:38 | no source given |
| curve breakpoints | 12, 18, 25, 45 | deg | Aerodynamics.cs:42, :47, :54, :61 | none |
| transition gain | +0.3 over 12° to 18° | – | Aerodynamics.cs:51, :57 | none |
| stall retention | 0.85 | – | Aerodynamics.cs:59, :64 | none |
| deep-stall cl | 0.5 × cos(alpha − 45°) | – | Aerodynamics.cs:66, :71 | none |
| `cd_parasitic` | 0.015 | – | Aerodynamics.cs:84 | 0.5 in Sail.cs:30 (old, a different model) |
| Oswald `e` | 0.75 | – | Aerodynamics.cs:88 | none |
| separation drag | 0.5 × ((alpha − 15°)/30°)² above 15° | – | Aerodynamics.cs:93-96 | spec clamps total cd |
| form drag | 1.2 × sin(alpha) above 45° | – | Aerodynamics.cs:100-103 | spec clamps total cd |
| `cd_max` (spec) | 1.3 | – | Hoerner flat plate ≈ 1.2; Marchaj sail on a run 1.2 to 1.5 | not in the legacy; OPEN 2.1 |
| `alpha_luff` (spec) | 5 | deg | spec choice; visual luff threshold 6° in SailDeformer.cs:52 | not in the legacy; OPEN 2.2 |
| minimum apparent wind | 0.5 | m/s | Aerodynamics.cs:131; AdvancedSail.cs:303 | 0.1 in Sail.cs:131 (old) |
| lift-direction threshold | 0.1 (length²  0.01) | – | Aerodynamics.cs:226 | spec: zero lift instead of the fallback |
| upwind penalty | 0 at 10°, 1 at 30° of AWA | deg | AdvancedSail.cs:320-324 | dropped (S2.2) |
| in-irons flag | AWA < 20° and speed < 1 m/s, overwritten to 30° | deg, m/s | AdvancedSail.cs:316; SailingState.cs:89 | display only; section 1 |
| high-speed force reduction | ×1 at 20 kt to ×0.6 at 35 kt | – | AdvancedSail.cs:369-374 | dropped (S2.3) |
| `ce_height_fraction` (spec) | 0.40 of luff (1.88 m) | – | spec choice (area centroid; Marchaj) | legacy 0.8 m (Session 13), 0.3 m (16), 0.0 m (25), origin (26) |
| `ce_boom_fraction` (spec) | 0.35 of boom (0.70 m) | – | commit c62f577 AdvancedSail.cs:302 (Session 25) | 0.5 in commit ca7a7b1 :211 (Session 13); 0.1 m fixed in commit 4c45223 :316 (Session 16 to 24); 0.6 in Sail.cs:253 and PHYSICS_DESIGN.md:357 (old) |
| downforce onset / fraction / ramp | 35 km/h / 0.25 / 20 km/h | km/h, –, km/h | Sail.cs:55, :58; commit fa79027 Sail.cs:238-247 | never active (S2.7) |

**Coefficient table** (AR 3.398, camber 0.10; `cd` uses each curve's own `cl`; legacy `cd` without the clamp):

| alpha (deg) | cl legacy | cd legacy | cl spec (2.7, luff fade included) | cd spec (clamped 1.3) |
|---|---|---|---|---|
| 0 | 0.373 | 0.032 | 0.000 | 0.015 |
| 2.5 | 0.528 | 0.050 | 0.264 | 0.024 |
| 5 | 0.683 | 0.073 | 0.683 | 0.073 |
| 10 | 0.994 | 0.138 | 0.994 | 0.138 |
| 12 (just below) | 1.118 | 0.171 | 1.118 | 0.171 |
| 12 (at and above) | 0.746 | 0.084 | 1.118 | 0.171 |
| 15 | 0.896 | 0.115 | 1.268 | 0.216 |
| 18 | 1.046 | 0.157 | 1.418 | 0.271 |
| 20 | 1.001 | 0.154 | 1.357 | 0.259 |
| 25 (just below) | 0.889 | 0.169 | 1.205 | 0.252 |
| 25 (at and above) | 0.634 | 0.121 | 1.205 | 0.252 |
| 30 | 0.600 | 0.185 | 1.029 | 0.272 |
| 45 | 0.500 | 0.546 | 0.500 | 0.546 |
| 60 | 0.483 | 2.208 | 0.483 | 1.300 |
| 90 | 0.354 | 4.356 | 0.354 | 1.300 |

### Where the force acts

`f_sail` acts at the centre of effort of 2.13 (Option A: its horizontal position at deck height; Option B: the full point). The torque about the centre of mass, with `r = ce_applied_local - com_local` and `F = f_sail_local` (both body frame, `F.y = 0`, Godot right-handed cross product):

```
tau = r.cross(F)
tau.x = r.y * F.z            # pitch: positive = bow up.  CE above the COM and drive forward (F.z < 0) → bow DOWN
tau.y = r.z * F.x - r.x * F.z   # yaw: positive = bow to PORT
tau.z = -r.y * F.x           # roll about +z: positive = starboard rail up = heel to PORT (heel_rad = -angle about +z)
```

Physical readings, for the sail on the port side and the wind from starboard (`F.x < 0` to leeward, `F.z < 0` forward):

- **Yaw from the lateral offset**: the CE is to port (`r.x < 0`), the drive is forward (`F.z < 0`): `tau.y = -r.x * F.z < 0` → bow to starboard → into the wind. This is weather helm: a sail sheeted out makes the board want to head up.
- **Yaw from the fore/aft offset**: side force to port at a point aft of the COM (`r.z > 0`): `tau.y = r.z * F.x < 0` → bow to starboard → head up. Raking back moves the CE aft and strengthens this; raking forward moves it ahead of the COM and reverses it. That is rake steering by geometry (section 3 compares it with the legacy's artificial torques).
- **Heel** (Option B only): `tau.z = -r.y * F.x > 0` → heel to port = to leeward. With `r.y = 1.88 m` and 284.5 N of side force (the 45° example), 535 N·m.
- **Pitch** (Option B only): `tau.x = r.y * F.z < 0` → bow down: 1.88 m × 219.7 N = 413 N·m. This is the real "nose-dive" tendency at speed that windsurfers counter by moving aft.

**Legacy (Session 26 build):** the force was applied at the board's transform origin (AdvancedSail.cs:287, :377), not at the rigidbody's centre of mass. `BoardMassConfiguration` moved the COM (sailor at 0.4 m up, shifting aft when planing, PHYSICS_DESIGN.md:419-425; section 7), so `r = origin − COM` was a small vector pointing down and slightly forward, and the sail force produced a small **reversed** heel moment (pulling the bottom of the body sideways) and a small bow-up moment. Nobody intended that; it is a by-product of the "CE = zero" fudge. The old `Sail.cs` applied its force at a real boom-height CE (Sail.cs:242-267) and its downforce at the COM (:270-273).

### Signs and the Unity-to-Godot translation

| Item | Unity (legacy) | Godot (spec) | Note |
|---|---|---|---|
| AWA | `SignedAngle(fwdHorizontal, −awHorizontal, up)` (SailingState.cs:113); in Unity's left-handed frame `Cross(forward, right) = up`, so this is positive for wind from **starboard** (code comment :112) | `atan2(from_local.x, -from_local.z)` (section 1) | Same physical sign. Godot's `signed_angle_to` would give the opposite (right-handed), so it is not used. The tables in PHYSICS_VALIDATION.md:46-50 and :67-70 are the wrong way round (plan pitfall 1). |
| TWA | `SignedAngle(−twHorizontal, fwdHorizontal, up)` (AdvancedSail.cs:182): the arguments are in the **opposite order** to the AWA, so the legacy TWA was positive for wind from **port** | same convention as the AWA | Legacy inconsistency; only the HUD and the AWA fallback at `aws ≤ 0.1` (SailingState.cs:117) saw it. |
| Aft direction | −Z | +Z | Chord `(sin θ, 0, −cos θ)` (AdvancedSail.cs:240-244) becomes `(sail_side·sin θ, 0, +cos θ)` (F0.11). |
| Starboard | +X (`transform.right`) | +X | Same. |
| Sail normal | `Cross(chord, up)` then flipped toward the wind (AdvancedSail.cs:252-266) | `n0_local` by components (2.2), no flip | The flip made the cross product's handedness irrelevant; in Godot `chord.cross(UP)` would point the other way, which is why the spec writes the normal out. |
| Fallback perpendicular | `Cross(up, windHoriz)` "points 90° left of wind" (Aerodynamics.cs:187-189) | `UP.cross(w_hat)` points 90° **left** in Godot | The legacy comment is wrong for Unity (there it points right); the fallback was almost never reached. |
| Lift direction | projection of `−sailNormal` onto the wind-perpendicular (Aerodynamics.cs:219-228) | same projection with `−sign(alpha)·n0` (2.11) | Dot products only: no sign change. |
| Sign of the angle of attack | always ≥ 0 (unsigned, from the flipped normal) | signed (2.3) | The spec needs the sign for luffing. |
| Sheet | 0 = in, 1 = eased (AdvancedSail.cs:27) | 0 = out, 1 = in (F0.10) | `sheet = 1 − sheet_legacy`. |
| Sail side | `SailSide` +1 = starboard (SailingState.cs:30); `_manualTack` +1 = starboard tack = boom to port (AdvancedSail.cs:66) | `sail_side` +1 = boom to starboard (F0.9) | Same number; the spec computes it from the wind. |
| Rake CE offset | `ceForwardOffset = −sin(rake)·h` in z (aft is −Z) (commit c62f577 AdvancedSail.cs:294) | `+h·sin(rake_rad)` in z (aft is +Z) (2.13) | Same physical direction (aft), opposite sign because the axis flips. |
| Yaw torque | `AddTorque(Vector3.up * T)`, positive T turns the bow to **starboard** | positive about +Y turns the bow to **port** | Every legacy yaw torque changes sign in Godot (section 3). |
| Roll from `eulerAngles.z` | heel read as the Euler z angle (AdvancedSail.cs:399) | `heel_rad` positive = heeled to starboard = negative rotation about +z | Section 3. |
| Board heel and the sail | the 3D normal tilted with the board, shrinking alpha by about cos(heel) (AdvancedSail.cs:269, :329) | rig vertical, board heel ignored (2.12) | Deliberate change, see 2.12. |
| Visual sail rotation | `_invertSailRotation = true` (WindsurferSetup.cs:817; EquipmentVisualizer.cs:64, :236) negated the physics sail angle for the FBX | n/a | A model-orientation fix, not a physics sign; Phase 6 sets its own. |

### Stabilisers and fudges in this model

| # | What | Why it was added | What it probably hides | Recommendation |
|---|---|---|---|---|
| S2.1 | Two discontinuities in the lift curve at 12° and 25° (Aerodynamics.cs:50, :64) | Not added on purpose: the transition branches were written without the camber offset (Session 13, commit ca7a7b1) | Nothing; it is a bug. The validated tuning silently compensated for a sail 33 % weaker than intended between 12° and 25° | **Fix** (2.7). Retune in Phase 4. |
| S2.2 | Upwind force penalty: total sail force × clamp01((abs(AWA) − 10°)/20°) for AWA under 30° (AdvancedSail.cs:319-324) | Session 12 "no-go zone" (PROGRESS_LOG.md:685, :726), softened in Session 22 from a hard 25° cut-off (commit ca7a7b1 :230) to a 10°→30° ramp (PROGRESS_LOG.md:406-407) | The missing luff rule: with an unsigned angle of attack and a 12° minimum boom angle, a sail 15° off the wind still produced lift, so a penalty on the AWA was bolted on | **Drop**; replace by luffing on `alpha` (2.9). Re-add only if the Phase 4 no-go test fails. |
| S2.3 | High-speed force reduction: sail force × lerp(1, 0.6, (kt − 20)/15) above 20 kt (AdvancedSail.cs:366-374) | Session 22 (commit 5a1857a) "to prevent nose-diving and flipping" | The bow-down moment of the CE at height plus the absent sailor counter-lean; after Session 26 (CE at the origin) it only capped the top speed | **Drop.** If the top speed is wrong in Phase 4, fix the hull drag, not the sail. |
| S2.4 | Centre of effort lowered and finally zeroed: 0.8 m (Session 13, commit ca7a7b1 :200, :211), 0.3 m height and 0.1 m lateral (Session 16, commit 4c45223 :305, :316; PROGRESS_LOG.md:1462-1479 "was ~3 m causing wild rotations"), 0.0 m height with 35 % boom lateral and 0.3 × aft (Session 25, commit c62f577 :291-307; KNOWN_ISSUES.md:100), `Vector3.zero` (Session 26, AdvancedSail.cs:283-291; PROGRESS_LOG.md:160-166 "porpoising") | Wild rotation (Session 16) and porpoising (Sessions 25 and 26) | Two things: no sailor counter-lean to take the heeling moment, and pitch damping problems in the hull/buoyancy model (the porpoising was fixed in the same session by also moving the planing lift to the COM, so which change mattered is unknown). Zeroing the horizontal position also removed the physical weather helm and the geometric rake steering, which the artificial rake torques (section 3) then had to replace | **Re-evaluate**: Option A (horizontal position exact, height at deck level) as the Phase 2 default; Option B (full height) as a Phase 4 experiment with the sailor model. Never `Vector3.zero`. |
| S2.5 | Vertical force component removed (AdvancedSail.cs:361-364; Sail.cs:215-228) | Session 22, "vertical component causes instability" | Nothing much; the legacy lift was already horizontal and only the drag could have a vertical part from a vertical apparent wind (heave) | **Keep** in the sense that the spec model is 2D by construction (2.12). |
| S2.6 | Manual tack with the initial side fixed to "boom to port" (AdvancedSail.cs:66, :206) and instant flip | Session 22 (commit 5a1857a), not explained in the progress log | Probably the sail flipping at the wrong moment with the old 5° hysteresis during tacks, and the "steering inverted on port tack" problem it created was then patched in the controller (KNOWN_ISSUES.md:84) | **Re-evaluate** (section 0 fudge 2): physics side from the wind with hysteresis at 0 and ±180° (2.14); Space becomes a controller action. OPEN for the team (arcade flip or steered tack). |
| S2.7 | High-speed sail downforce: above 35 km/h a downward force of up to 25 % of the horizontal sail force, ramping in over 20 km/h, applied at the COM (Sail.cs:53-58; commit fa79027 Sail.cs:230-247, :283-287; PROGRESS_LOG.md:256) | Session 24, "board flies out at 45+ km/h" (KNOWN_ISSUES.md:181) | It was written into the old `Sail.cs`, which was **not in the scene** (MainScene.unity at commit fa79027 has only `AdvancedSail`), so it never acted; Session 26 removed dead code (Sail.cs:230-233; PROGRESS_LOG.md:164). The flying-out was addressed by the planing-lift cap in the hull model (section 5) | **Drop.** A raked rig's real vertical force is small and, if anything, upward. |
| S2.8 | Old `Sail.cs` no-go zone: inside 45° of the apparent wind no lift and a backward drag of 0.15 × q × A (Sail.cs:144-157), plus "never push backward": if the total force had a backward component, keep half the sideways part and add 10 N backward (Sail.cs:200-208) | Session 12 (PROGRESS_LOG.md:685, :726-727) | The old model's lift direction was a plain `Cross(up, wind)` flipped by the wind side (Sail.cs:183-189), which pointed backward on some points of sail | **Drop** (history; the Advanced model replaced it in Session 13). |
| S2.9 | Sheet and rake rate limits inside the sail (AdvancedSail.cs:137-153) | Session 13, "smooth control" | Nothing physical | **Move to the controller** (section 0 fudge 4). |
| S2.10 | `liftSign` 1° dead band (Aerodynamics.cs:245-246) | Session 13 | Nothing: the sign was always +1 | **Drop**, replaced by the signed alpha and the luff fade. |

### What Phase 2 must implement

- [ ] `SailConfig` resource: `area_m2 = 6.5`, `luff_m = 4.7`, `boom_m = 2.0`, `camber = 0.10`, `boom_height_m = 1.4`, `mast_foot_local = Vector3(0, 0.1, 0.1)` (OPEN 2.5), `sheet_angle_in_deg = 12`, `sheet_angle_out_deg = 85`, `lift_slope_factor = 0.9`, `zero_lift_deg_per_camber = 60`, the four breakpoints `12, 18, 25, 45`, `transition_gain = 0.3`, `stall_retention = 0.85`, `deep_stall_cl = 0.5`, `cd_parasitic = 0.015`, `oswald_e = 0.75`, `cd_max = 1.3`, `alpha_luff_deg = 5`, `ce_height_fraction = 0.40`, `ce_boom_fraction = 0.35`, `ce_at_deck_height = true` (Option A), `min_apparent_wind_ms = 0.5`, `side_hysteresis_deg = 5`, `rake_max_deg = 15` (shared with section 3).
- [ ] `SailModel` (RefCounted) with `compute(v_apparent_local, awa_rad, sheet, rake, sail_side, config) -> SailResult` holding `sheet_angle_rad`, `alpha_rad`, `cl`, `cd`, `f_lift_local`, `f_drag_local`, `f_sail_local`, `ce_local`, `ce_applied_local`, `is_luffing`, `is_stalled (abs(alpha) > 25°)`; no state inside except what the caller passes.
- [ ] Sail-side state with the 5° hysteresis at 0 and ±π (2.14), owned by `WindsurferSim`, plus a `set_sail_side()` entry for the controller (OPEN, section 0).
- [ ] `sheet_angle_rad` from F0.10; boom and normal from 2.2; signed alpha from 2.3 with `asin` and the clamp.
- [ ] Continuous `cl` curve (2.7) with the luff fade (2.9); `cd` (2.8) with the `cd_max` clamp.
- [ ] Force directions by projection (2.11), with lift set to zero when the projected direction is shorter than 0.1; early return for `aws < 0.5 m/s`.
- [ ] Centre of effort with rake and boom offsets (2.13); apply with `add_force_at(ce_applied_world, f_sail)`.
- [ ] Sample the apparent wind at `ce_world` (section 1, Formula 3), not at the board origin.
- [ ] Telemetry: `alpha_deg`, `sheet_angle_deg`, `sail_side`, `cl`, `cd`, `sail_lift_n`, `sail_drag_n`, `drive_n = -f_sail_local.z`, `side_force_n = f_sail_local.x`, `is_luffing`, `is_stalled`.
- [ ] No upwind penalty, no speed reduction, no downforce, no rate limits in the sim. Write in the config comments why each is absent (this section's S numbers) so nobody re-adds them by reflex.

### Tests Phase 2 should write

- **Aspect ratio and slope**: 4.7 m and 6.5 m² give `aspect_ratio = 3.398 ± 0.001` and `lift_slope_per_rad = 3.560 ± 0.002`.
- **Sheet mapping**: `sheet = 1` → 12°, `sheet = 0` → 85°, `sheet = 0.5` → 48.5°; `sheet_legacy = 0.863` (spec 0.137) → 75°.
- **Coefficient table**: `cl` and `cd` at 0, 5, 10, 12, 15, 18, 25, 30, 45, 60 and 90° match the "spec" columns of the coefficient table to ±0.002; `cl` is continuous (no step larger than 0.01 between alpha and alpha + 0.01°) over 0° to 90°; `cd ≤ 1.3` everywhere.
- **Angle of attack sign**: wind from starboard at `awa = 60°`, boom at 45° to port → `alpha = +15°`; boom at 75° → `alpha = −15°` and `is_luffing`; same with mirrored inputs (`awa = −60°`, boom to starboard) → the same alpha. Wind dead astern, boom at 85° → `alpha = 85°`.
- **Worked example** (2.16): `aws = 10`, `awa = +90°`, `alpha = 15°`, area 6.5: with the spec curve lift 504.8 N ± 1, drag 85.9 N ± 0.5, `f_sail_local = (−85.9, 0, −504.8)`; with the legacy curve (a test may call the legacy branch values directly to pin the derivation) lift 356.6 N, drag 45.9 N. Lift direction `(0, 0, −1)`, drag direction `(−1, 0, 0)`.
- **Close reach**: `awa = +45°`, `alpha = 15°`: lift direction `(−0.707, 0, −0.707)`, drive = `L·sin45° − D·cos45°`, side force = `L·cos45° + D·sin45°` to port; with the legacy magnitudes 219.7 N and 284.5 N.
- **Shortcut cross-check**: for `awa` in {30°, 60°, 90°, 120°} and `alpha` in {5°, 15°, 25°}, the projected lift direction equals `sail_side * UP.cross(w_hat)` to 1e-6.
- **Run**: `awa = 180°`, boom 85° to port: the force normal is `(−0.087, 0, −0.996)`, drive positive, lift to port, `cd = 1.3` (clamped).
- **Luffing**: `alpha ≤ 0` gives `lift = 0`, `cd = 0.015`; `alpha = 2.5°` gives half the unfaded `cl`.
- **Sail side**: `awa = +90°` → `sail_side = −1`; `awa = −90°` → +1; a sequence +10°, +3°, −3°, −6° gives −1, −1, −1, +1; a sequence 170°, 178°, −178°, −170° gives −1, −1, −1, +1.
- **Symmetry**: mirroring `awa` and `sail_side` mirrors `f_sail_local.x` and leaves `f_sail_local.z` unchanged (±1e-6).
- **Centre of effort**: rake 0 → `ce_local = mast_foot + (0, 1.88, 0) + chord·0.70`; rake +1 (15°) → z increases by `1.88·sin15° = 0.487 m` and y drops to `1.88·cos15° = 1.816 m` above the foot; the boom at 90° to port puts the CE 0.70 m to port of the mast.
- **Torque about the COM** (Option B geometry, `r = (−0.35, 1.88, 0.71)` for the 45° example with the foot at the COM height): `tau = r.cross((−284.5, 0, −219.7))` = `(−413, −279, +535)` N·m to ±1: bow down, bow to starboard (head up), heel to port. With Option A (`r.y = 0`): `tau.x = tau.z = 0`, `tau.y = −279` unchanged.
- **No wind**: `aws = 0.3` → all forces zero, `alpha = 0`.
- **Determinism**: two calls with the same inputs give bit-identical results.

### Sources

- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs`: :24-73 (lift coefficient: :32 zero-lift angle, :37-38 slope, :42-72 branches), :79-106 (drag: :84 cd0, :88 e, :89 induced, :93-96 separation, :100-103 form), :119-250 (`CalculateSailForces`: :131-136 minimum wind, :139-142 wind directions, :150-151 angle of attack, :154-155 coefficients with `Abs`, :158-162 magnitudes, :177-184 vertical-wind edge case, :187-189 fallback perpendicular, :207-216 horizontal normal, :219-224 projection, :226-238 normalise and fallback, :241 drag direction, :245-249 lift sign), :255-268 (optimal sheet angle 17°, clamp 5° to 85°).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs`: :24-45 (fields), :65-66 (`_lastSailSide`, `_manualTack`), :80-81, :125-132 (tick order), :137-153 (control smoothing, auto-trim), :158-192 (wind state; :163 sampled at the origin; :182 TWA), :197-276 (geometry: :206 side, :224-229 sheet to angle, :231 camber, :239-244 chord, :252 normal, :255-267 flip, :269), :283-291 (CE zero), :296-352 (forces: :303-312, :316, :319-324, :328-330, :333-342, :348, :351), :357-389 (apply: :359, :363-364, :368-374, :377), :532-543 (sheet setters), :549-564 (tack), :569-580, :586-607 (auto-trim), :617-628, :633-637, :681-748 (debug drawing; :694 boom height, :712 camber depth, :730-732 tack labels), :755-756 (mast gizmo).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/Sail.cs` (old, not in the validated scene): :24-72 (fields), :126-209 (forces: :131-138, :144-157 no-go zone, :163-170, :177-179, :183-189 lift direction, :200-208 backward clamp), :211-274 (apply: :215-228 horizontal, :230-233 downforce disabled, :242-264 CE, :267, :270-273), :303-321 (sail angle 15° to 80°), :328-349 (normal), :354-388 (old coefficient curves).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs`: :30, :60-92 (:66, :69, :89, :90), :97-119 (:100, :108-113, :117), :126-167 (`SailConfiguration`: :130, :133, :136, :139, :143-144, :148, :152, :155, :160, :166).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs`: :12, :21, :43-46.
- `Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs`: :29, :32, :35, :68, :80, :143-150, :158-159, :178-182, :184-189, :198, :210-223, :320.
- `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs`: :46, :117, :683, :689, :725-741, :817, :852.
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity`: :332-350 (the `AdvancedSail` block: :334-341 config, :342-347 controls). The scene holds these component values, contrary to the task brief; they agree with the wizard.
- `Legacy/WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs`: :64, :236-237. `Visual/SailDeformer.cs`: :52, :321-331, :341. `Audio/SailFlapAudio.cs`: :105. `Environment/WindSystem.cs`: :147-169, :174-182.
- Git history (paths as they were before the move to `Legacy/`): commit ca7a7b1 (Session 13) `AdvancedSail.cs:152-186, :191-220, :230`; commit 4c45223 (Session 18) `AdvancedSail.cs:196-289, :295-325`; commit 5a1857a (Session 22) diff against 4c45223 (manual tack, upwind penalty, speed reduction, pitch stabilisation, horizontal force); commit fa79027 (Session 24) `Sail.cs:230-247, :283-287` and `MainScene.unity` component list; commit c62f577 (Session 25 save point) `AdvancedSail.cs:282-311`; commit b5ed2ea (Session 26) diff against c62f577.
- `Legacy/Documentation/PHYSICS_VALIDATION.md`: :38-53 (AWA table, reversed), :57-87 (sail side and hysteresis, table reversed), :91-108 (normal), :112-157 (lift direction), :216-254 (chain), :270-287, :290-302 (:297-298 rake wrong).
- `Legacy/Documentation/PHYSICS_DESIGN.md`: :263-372 (wind force :287-296, curve sketch :300-313, geometry :315-348, CE :350-372), :419-425 (sailor COM), :512 (0.02 s tick), :544 (6.0 m²), :577-579 (downforce parameters).
- `Legacy/Documentation/KNOWN_ISSUES.md`: :30-46, :83-86, :100, :164, :181, :186.
- `Legacy/Documentation/PROGRESS_LOG.md`: :57, :67, :160-166, :251-258, :282-316, :404-407, :559-572, :685-686, :726-727, :1312-1335, :1462-1479, :1548-1561.
- `Legacy/Documentation/scene_config.json`: :72-75 (old `Sail`, area 6; history only).
- Literature: Marchaj, *Sail Performance: Theory and Practice* (sail lift and drag coefficients, centre of effort of soft sails); Larsson and Eliasson, *Principles of Yacht Design* (sail coefficient sets, induced drag with an Oswald factor); Hoerner, *Fluid-Dynamic Drag* (flat plate normal to the flow, cd ≈ 1.2); Wikipedia "Forces on sails" (cited by Aerodynamics.cs:117) for the lift/drag decomposition. Thin-airfoil theory (2π per radian, zero-lift angle of a circular arc −2 × camber) is textbook aerodynamics (Anderson, *Fundamentals of Aerodynamics*).

---

## 3. Rake steering, pitch stabilisation and angular damping

### Purpose

A windsurfer has no rudder. The sailor steers by tilting the rig: raking the mast back moves the sail's centre of effort (CE, the point where the sail force effectively acts) toward the tail, behind the point where the water pushes back (the fin and the hull, together the centre of lateral resistance, CLR). The sail's sideways force then turns the bow toward the wind ("head up"). Raking the mast forward moves the CE ahead of the CLR and the bow turns away from the wind ("bear away"). This is the same lever-arm effect as pushing a floating plank sideways at one end.

The Unity version did **not** simulate this lever. It set the CE to the board's origin (so rake moved nothing) and instead added an artificial yaw torque proportional to the rake input, with a tack sign, a constant "direct" term, a speed term and a high-speed scale-down. Around it grew a family of stabilisers: speed-dependent angular damping, Unity's own Rigidbody angular damping, a pitch spring-damper that fades out with heel, a fin "tracking" torque, an anti-capsize torque and a weight-shift yaw torque.

This section specifies:

1. how the rake input becomes a mast angle (limits, rate, auto-centre);
2. the physical CE-shift model the rebuild should use, derived in D4 with a worked estimate of how strong it is;
3. every artificial steering and stabilising term in the legacy code, exactly, with a keep/drop/re-evaluate recommendation;
4. what Phase 2 must build first and what Phase 4 must test.

The numbers in this section are for the legacy default setup: 6.5 m² sail, 4.7 m luff, 2.0 m boom, fin 0.035 m² at 0.9 m aft, total mass 91 to 94 kg (see "Values").

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `rake` | Rake control input after rate limiting, −1 (fully forward) to +1 (fully back) | – |
| `rake_target` | Rake the controller asks for this tick, −1 to +1 | – |
| `max_rake_rad` | Mast rake angle at `rake = ±1` | rad (15° in the legacy) |
| `rake_rad` | Mast rake angle, positive = raked back (mast top toward the tail) | rad |
| `rake_rate_per_s` | Fastest change of `rake` per second | 1/s |
| `sheet_angle_rad` | Boom angle from the centreline, 0 = along the centreline | rad |
| `sail_side` | +1 = boom on the starboard side (port tack), −1 = boom on the port side (starboard tack); `sail_side = -sign(awa_rad)` | – |
| `awa_rad` | Apparent wind angle, positive = wind from starboard | rad |
| `mast_foot_local` | Mast foot position in the body frame (x starboard, y up, z aft-positive) | m |
| `h_ce_m` | Height of the sail's CE above the mast foot, measured along the mast | m |
| `ce_along_boom_m` | Distance from the mast to the CE, measured along the boom | m |
| `ce_local` | CE position in the body frame (output of this section, input to the sail force application) | m |
| `f_sail_h` | Horizontal sail force in the body frame: `f_sail_h.x` = side force (+ = to starboard), `f_sail_h.z` = −drive | N |
| `com_local` | Centre of mass in the body frame (from the mass section) | m |
| `torque_yaw_nm` | Yaw torque about +Y produced by the sail force at the CE, positive = bow turns to port | N·m |
| `v_boat` | Board velocity in the world frame | m/s |
| `speed_ms` | `v_boat.length()` | m/s |
| `omega_world`, `omega_local` | Angular velocity in the world and body frames | rad/s |
| `pitch_rad`, `heel_rad` | Bow-up angle and starboard-rail-down angle | rad |
| `pitch_rate`, `yaw_rate`, `heel_rate` | Body-frame angular rates: +bow rising, +bow to port, +heeling to starboard | rad/s |
| `planing_ratio`, `submersion_ratio` | From the hull and buoyancy sections | – |
| `torque_damping` | Angular damping torque (only if a stabiliser is re-enabled) | N·m |

### Formulas

Everything below is in D4: world +Y up, North = −Z, East = +X; body: bow = −Z, starboard = +X, up = +Y. A positive rotation about +Y turns the bow to **port**. In the body frame, "aft" is **+Z**.

#### 3.1 Rake input to mast angle (legacy behaviour, both layers)

The legacy had two rate limiters in series: the controller integrates the key, the sail component follows the controller. Time steps are `dt` (Unity fixed step 0.02 s; frame step for the input smoothing).

1. **Input smoothing (controller, per frame).** The raw key value `rake_key` is −1, 0 or +1. Q/E give ±1 directly; A/D give ±1 multiplied by a tack sign (see 3.7).
   `smooth_rake_input = move_toward(smooth_rake_input, rake_key, 8.0 * dt_frame)`
   Reason: a key is a step; the sailor's arms are not. 8/s means a full step takes 0.125 s.
   Source: AdvancedWindsurferController.cs:68, :195-201.

2. **Dead zone and integration (controller, per physics tick).**
   ```
   if abs(smooth_rake_input) > 0.1:
       current_rake += smooth_rake_input * 2.0 * dt      # rake_control_speed = 2 per second
       current_rake = clamp(current_rake, -1.0, 1.0)
   elif auto_center_rake:                                # true in the last build
       current_rake = move_toward(current_rake, 0.0, 1.0 * dt)   # rake_center_speed = 1 per second
   ```
   So a held key moves the rake from 0 to full in 0.5 s and from −1 to +1 in 1.0 s; releasing the key returns full rake to neutral in 1.0 s. The dead zone means the rake only starts moving 12.5 ms after a key press.
   Source: AdvancedWindsurferController.cs:39-45, :225-236; wizard sets `_autoCenterRake = true` at WindsurferSetup.cs:800.

3. **Sail-side rate limit (sail component, per physics tick).**
   `mast_rake = move_toward(mast_rake, target_mast_rake, 3.0 * dt)` with `target_mast_rake = clamp(current_rake, -1, 1)`.
   Because 3/s is faster than the controller's 2/s, this limiter never binds during normal play; it only matters if something (an autopilot) sets the target in one jump.
   Source: AdvancedSail.cs:45, :151-152, :617-628.

4. **Mast angle.**
   `rake_rad = rake * max_rake_rad`, with `max_rake_rad = deg_to_rad(15.0) = 0.2618 rad`.
   In the last build this angle was used **only by the visualiser** (EquipmentVisualizer.cs:222-237). Nothing in the physics read `_maxRakeAngle`; the physics used the dimensionless `_mastRake` directly.
   Source: AdvancedSail.cs:41-42; WindsurferSetup.cs:736.

**What the spec keeps:** one rate limit in the simulation (`rake_rate_per_s = 3.0`, the sailor's arm speed) applied to whatever target the controller or autopilot sends, and the controller's 2/s integration, 0.1 dead zone and 1/s auto-centre as controller settings. The extra 8/s frame smoothing is a controller nicety; keep it only if the team feels the keys are too abrupt.

#### 3.2 The physical model: rake moves the centre of effort

The rig pivots on the mast foot (a universal joint). Raking back tilts the mast top toward the tail. Every point on the rig moves aft in proportion to its height above the foot. The CE of the sail sits at height `h_ce_m` up the mast and `ce_along_boom_m` back along the boom.

1. **Mast direction (body frame).** The mast leans aft (+Z) when raked back:
   `mast_dir = Vector3(0.0, cos(rake_rad), sin(rake_rad))`
   The rig also leans to windward or leeward in reality, but that is roll, not steering; it is ignored here.

2. **Boom direction (body frame, horizontal).** The boom trails aft from the mast and swings to the leeward side:
   `boom_dir = Vector3(sail_side * sin(sheet_angle_rad), 0.0, cos(sheet_angle_rad))`
   Check: `sail_side = +1` (wind from port) puts the clew at +X = starboard = leeward. Correct.
   The boom is really perpendicular to the raked mast, which lifts the clew by `ce_along_boom_m * sin(rake_rad)` (0.31 m at 15° for 1.2 m) and shortens its horizontal reach by 3.4 %. This is second order for yaw and is ignored.

3. **Centre of effort.**
   `ce_local = mast_foot_local + mast_dir * h_ce_m + boom_dir * ce_along_boom_m`
   The fore-aft shift caused by rake alone is
   `delta_z_rake = h_ce_m * sin(rake_rad)`  (positive = aft).
   With `h_ce_m = 1.8 m` and 15°: `delta_z_rake = 1.8 × 0.2588 = 0.466 m`, or **0.031 m per degree of rake**. Section 2 fixes `h_ce_m = 0.40 × luff = 1.88 m` and the along-boom distance at `0.35 × boom = 0.70 m`; the estimates in this section use 1.8 m and 1.2 m from an earlier draft and change by less than 5 % with section 2's values.
   The CE also drops by `h_ce_m * (1 − cos(rake_rad))` = 0.061 m at 15°; negligible.

4. **Yaw torque.** The sail section computes the horizontal sail force `f_sail_h` and applies it at `ce_local`. The integrator turns a force at a point into a torque about the centre of mass:
   `r = ce_local - com_local`
   `torque = r.cross(f_sail_h)`
   `torque_yaw_nm = torque.y = r.z * f_sail_h.x - r.x * f_sail_h.z`
   Two physical effects sit in this line:
   - `r.z * f_sail_h.x`: the side force acting aft (or forward) of the centre of mass. This is the rake steering lever. `r.z` grows with rake back and with sheeting in.
   - `−r.x * f_sail_h.z`: the drive force acting on the leeward side of the centreline (the clew is to leeward). This is the classic "weather helm" of a sail off the centreline. Sheeting out increases it.
   Both are real and both come for free once the force is applied at the real CE. No tack sign is needed: the side force already changes sign with the tack.

5. **Balance against the water.** The fin force (fin section) acts at the fin, about 0.8 m aft of the centre of mass, and the hull's lateral drag acts near the middle. The heading settles where the sail's yaw torque and the water's yaw torque cancel. Neutral rake gives a straight course only if the mast foot, `ce_along_boom_m` and the fin position are chosen so that the two levers match on a typical reach. Phase 4 tunes `mast_foot_local.z` for this. Note the sheet effect: between the legacy sheet limits of 12° and 85° the CE moves `ce_along_boom_m × (cos 12° − cos 85°)` = 1.07 m for 1.2 m (0.62 m for 0.7 m), **more than the full rake swing of 0.93 m**. Expect "sheet in = head up" to be a strong effect in the physical model; that is realistic but must be checked for playability (see "Tests").

#### 3.3 How strong is the physical mechanism? A worked estimate

Case: true wind 15 kt = 7.717 m/s, beam reach (TWA 90°), boat speed 5.0 m/s (9.7 kt, about planing onset), sail sheeted for about 12° angle of attack.

- Apparent wind: `aws = sqrt(7.717² + 5.0²) = 9.20 m/s`, `awa = atan2(7.717, 5.0) = 57.0°` (from starboard on starboard tack).
- Dynamic pressure: `q = 0.5 × 1.225 × 9.20² = 51.8 Pa`; `q × 6.5 m² = 337 N`.
- With `Cl = 1.1` and `Cd = 0.17` (Aerodynamics.cs curve at about 12° angle of attack, aspect ratio 3.4): lift 370 N, drag 56 N.
- Lift is perpendicular to the apparent wind and points to leeward-and-forward; drag points along the apparent wind. Side force (toward port, so negative x): `−(370 × cos 57° + 56 × sin 57°) = −248 N`. Drive (forward): `370 × sin 57° − 56 × cos 57° = +280 N`. Total force 374 N.
- **Physical rake yaw torque at full rake:** `248 N × 0.466 m = 116 N·m`, i.e. **7.8 N·m per degree of rake** (with `h_ce_m = 1.8 m`).
- **Legacy artificial torque in the same state** (formula in 3.4; speed 9.7 kt so no scale-down; AWA 57° so direct term 200): `0.3 × 374 + 200 + 25 × 5.0 = 437 N·m`. With the weight-shift torque that A/D also triggers (3.7): `+ 80 + 30 = 547 N·m`. The legacy pushed **4 to 5 times harder** than the real lever.
- **What limits the turn rate:** the fin. A yawing board drags its fin sideways, and the fin's lift resists. With the legacy fin (0.035 m², span 0.40 m, aspect ratio 4.6, lift slope about 4.4 per rad) at 5.0 m/s: `dL/dα = 0.5 × 1025 × 5² × 0.035 × 4.4 = 1970 N/rad`. A yaw rate `w` gives the fin (0.9 m aft) a slip angle of `0.9 w / 5.0`, so the fin's yaw damping is `1970 × 0.9 × 0.18 = 320 N·m per rad/s`. Yaw inertia is about 52 kg·m² (box 2.5 × 0.6 m, 94 kg), so the yaw rate settles in `52 / 320 = 0.16 s` and the steady turn rate is torque ÷ damping.
- **Steady turn rate, physical model:** `116 / 320 = 0.36 rad/s = 21°/s` at full rake. A 45° change of course takes about 2 s.
- **Steady turn rate, legacy:** `437 / 320 = 1.4 rad/s = 78°/s` before its own extra damping; the Session 12 log called rake steering "very powerful".
- At standstill in 15 kt the sail still gives about 260 N of force, so the physical model steers from rest as long as the sail is filled. It cannot steer when the sail is luffing head to wind: that is real (being "in irons"), and it is what the legacy's 350 N·m "direct" term was hiding.

Real windsurfers head up from a beam reach to close-hauled in roughly 2 to 4 s using the rig alone (10 to 20°/s); fast turns (carve gybes, 30 to 50°/s) use the rail and the sailor's weight as well. **Conclusion: the physical mechanism alone is in the right range but at the gentle end.** If Phase 4 finds it too gentle, the honest knobs are `h_ce_m` (1.6 to 2.0 m), `max_rake_rad` (15 to 20°), the mast foot position, and a separate, explicit weight-shift (rail) steering channel in the sailor section. Not a hidden constant.

#### 3.4 Legacy artificial rake torque (for the record; not to be built)

Source: AdvancedSail.cs:450-525, called every physics tick from ApplyForces (AdvancedSail.cs:388), even when the sail force is zero.

```
force_mag = |sail_force|                       # unreduced; the 20-35 kt force reduction at :366-374 is applied after this value is read
abs_awa   = |awa_deg|
kts       = speed_ms × 1.94384

# Tack sign. Both branches give the same answer; the velocity fallback (:476-488) is dead code
# because SailSide is always ±1 (manual tack, :206).
tack = -sail_side                              # = +1 on starboard tack (Unity: sign(AWA))

# High-speed scale-down
scale = 1
if kts > 15: scale = lerp(1, 0.5, (kts - 15) / 15)   # 0.5 at 30 kt; lerp clamps, so never below 0.5
scale = max(scale, 0.4)                                # never active

direct_strength = 200                                  # N·m
if abs_awa < 40 or abs_awa > 140: direct_strength = 350

torque_force  = rake × tack × force_mag × 0.3 × scale
torque_direct = rake × tack × direct_strength × scale
torque_speed  = rake × tack × min(speed_ms, 8) × 25 × scale       # 200 N·m max

AddTorque(Unity +Y × (torque_force + torque_direct + torque_speed))   # +Y = turn right in Unity
```

Translated to D4 (see "Signs"): `torque_yaw_nm = sail_side × rake × K`, i.e. `−sign(awa) × rake × K`. If a Phase 4 test ever needs an artificial helper, this is the form and sign to use. Recommendation: **drop** (3.9).

#### 3.5 Legacy speed-dependent angular damping

Source: AdvancedHullDrag.cs:513-545 (inside `ApplyResistance`, only when the board is floating, AdvancedHullDrag.cs:139-149, :86-87).

```
if omega_world.length_squared() > 0.001:
    base = 0.8 if is_planing else 1.5          # is_planing: planing_ratio > 0.5 or speed ≥ 6 m/s (:171-194)
    f_speed = 1
    if kts > 15: f_speed = min(1 + (kts - 15) / 5, 5)    # ×2 at 20 kt, ×4 at 30 kt, ×5 from 35 kt
    torque_damping = -omega_world × base × f_speed × total_mass × 0.1     # total_mass = 91 kg (HullConfiguration)
```

Coefficient: 13.7 N·m·s (displacement), 7.3 N·m·s (planing), up to 36 N·m·s at 35 kt and above. It is isotropic (same on roll, pitch and yaw) and works on the world-frame angular velocity, so it has no idea which axis is which. For scale, the fin's physical yaw damping at 5 m/s is about 320 N·m·s (3.3), 25 times larger, and it grows with speed on its own. The code comment says "ramps to 4.0 at 30 kn" (correct) but PHYSICS_VALIDATION.md:206-210 documents `lerp(1, 5, (kts−15)/15)`, a different curve. Recommendation: **drop** (3.9).

#### 3.6 Legacy Rigidbody angular damping and buoyancy rotational damping

- **Rigidbody.angularDamping = 0.3** (WindsurferSetup.cs:691; the "Quick add" path uses 0.5 at :1291 and so did the old scene, scene_config.json:23). PhysX multiplies the angular velocity by `(1 − 0.3 × dt)` every step, which is an exponential decay with a 3.3 s time constant. Equivalent continuous torque: `−0.3 × I × omega` per principal axis. With Unity's collider-derived inertia (94 kg box 2.5 × 0.6 × 0.12 m: yaw 52, pitch 49, roll 2.9 kg·m²) that is 16 N·m·s in yaw and pitch and under 1 N·m·s in roll. Recommendation: **drop**; there is no such thing in air or water.
- **Buoyancy rotational damping** (AdvancedBuoyancy.cs:64-65, :361-383; wizard sets the same 150 at WindsurferSetup.cs:718): body-frame torque `−omega_local × 150 × (4.0 pitch, 0.3 yaw, 3.0 roll) × (0.3 + 0.7 × submersion_ratio)`, applied when floating and submersion > 5 % (:314). That is 600, 45 and 450 N·m·s at full submersion and 180, 13.5 and 135 N·m·s when barely touching. This is the hull's real rotational water resistance in disguise and belongs to the buoyancy section; here it is listed because it is the largest legacy yaw damping after the fin. Recommendation: **re-evaluate in the buoyancy section**; keep a physically motivated pitch and roll damping, drop the yaw part (the fin and hull lateral drag do that).

#### 3.7 Legacy pitch stabilisation (Session 26 form)

Source: AdvancedSail.cs:381-384 (gate: speed > 12 kt) and :396-445.

```
heel_deg  = transform.eulerAngles.z wrapped to (−180, 180]       # body roll, Unity ZXY Euler
if |heel_deg| > 25: return                                        # off when heeled
heel_factor = 1                                                   # fade 1 → 0 between 15° and 25°
if |heel_deg| > 15: heel_factor = 1 − (|heel_deg| − 15) / 10
pitch_deg   = transform.eulerAngles.x wrapped                     # Unity: positive = bow DOWN
pitch_vel   = rigidbody.angularVelocity.x                          # WORLD x component, rad/s (see below)
speed_factor = clamp01((kts − 12) / 10)                            # 0 at 12 kt, 1 at 22 kt
f = speed_factor × heel_factor
correction = pitch_vel × 20 × f + pitch_deg × 4 × f                # N·m; damping per rad/s, spring per DEGREE
correction = clamp(correction, −300, 300)
AddTorque(−transform.right × correction)                           # about the starboard axis, bow-up for bow-down pitch
```

Facts worth knowing:
- The spring is 4 N·m per degree (229 N·m/rad) and the damping 20 N·m per rad/s. The hydrostatic pitch stiffness of a 2.5 × 0.6 m board floating level is `rho_water × g × L³ × W / 12 ≈ 7,900 N·m/rad = 138 N·m/deg`, 34 times the spring, and the buoyancy pitch damping (3.6) is 30 times the damping. The stabiliser only mattered when planing, when the waterplane is small.
- `angularVelocity.x` is the **world** X component. The torque is applied about the **body** starboard axis. They only agree when the board heads North or South. Heading East or West, the "pitch damping" reads the roll rate. This is a bug, and one reason it "spasmed" at high heel (KNOWN_ISSUES.md:30-46), which Session 26 then hid with the heel fade-out (PROGRESS_LOG.md:164-171).
- The ±300 N·m clamp is reached only at 75° of pitch by the spring or 15 rad/s by the damper: it is a guard, not a working limit.

Recommendation: **drop**. Porpoising is a hull-lift problem (Savitsky lift applied at the wrong point, CE height), not a missing spring. If Phase 4 shows a planing pitch oscillation, first check the planing-lift application point and the hydrostatic restoring, then add pitch damping in the hull section in body axes with a physical justification.

#### 3.8 Legacy anti-capsize (controller) and the missing sail-to-board roll transfer

Source: AdvancedWindsurferController.cs:57-65, :126-129, :276-307; wizard sets `_antiCapsize = true` at WindsurferSetup.cs:799.

```
heel_deg = SignedAngle(world_up, board_up projected on the plane ⟂ forward, forward)   # Unity: NEGATIVE when heeled to starboard
if |heel_deg| > 5:
    counter = heel_deg × 50 × 0.5 × clamp01(|heel_deg| / 45)      # = 0.556 × heel × |heel| N·m (heel in degrees), 222 N·m at 20°, 1125 N·m at 45°
    AddTorque(transform.forward × −counter)                        # restoring
if |heel_deg| > 45:
    AddTorque(transform.forward × (|heel_deg| − 45) × 100 × −sign(heel_deg))   # 100 N·m per degree beyond 45°
```

In the last build the CE was at the origin (AdvancedSail.cs:283-290), so the **sail produced no heeling moment at all**; the only roll inputs were the fin force below the water (about 0.4 m under the centre of mass) and waves. The anti-capsize was fighting almost nothing. The real system is: side force (about 250 N in 3.3) × CE height (about 1.8 m above the foot, 1.9 m above the centre of mass) = about 470 N·m of heeling moment, balanced by the sailor hanging to windward (75 kg × 9.81 × 0.6 m = 440 N·m). KNOWN_ISSUES.md:37-42 already names this as the proper fix ("sail-to-board roll transfer"). Recommendation: **drop** the torque; model the sailor's righting moment explicitly in the sailor section, and offer an explicit, documented "auto-hike" assist in beginner mode if Phase 3 shows the board capsizes. Note also that Unity's collider-derived roll inertia (2.9 kg·m², because `_useCustomInertia = false`, WindsurferSetup.cs:786) is about ten times too small for a sailor standing 0.9 m up; a correct inertia (mass section) removes much of the twitchiness these fudges answered.

#### 3.9 Legacy weight-shift yaw torque and fin tracking torque (related steering fudges)

- **Weight shift (controller).** A/D also drive `weight_input` (±1, same tack sign as the rake). `current_weight_shift` moves toward `weight_input × 20°` at 80°/s (AdvancedWindsurferController.cs:47-55, :238-242). Torque (:248-270), only when |shift| > 0.5°:
  `torque = (shift / 20) × 80 + (shift / 20) × 30 × clamp01(speed_ms / 3)` about Unity +Y (right turn positive), up to 110 N·m.
  **Bug:** the tack inversion at :157-170 was added for the rake torque (which contains `tack`), but this torque contains no tack factor, so on port tack the weight torque turns the wrong way and fights the rake torque. The rebuild must not copy this. Recommendation: **drop** this torque; a physical weight-shift channel (rail engagement, heel-induced turning) belongs to the sailor section and must be explicit.
- **Fin tracking torque** (AdvancedFin.cs:36-40, :78-81, :155-187): a yaw spring toward the velocity direction, `angle_error(deg) × strength × clamp01(speed/2) × (0.3 if stalled) × effectiveness`, clamped ±300 N·m, about Unity +Y. Strength 40 by default, **15 in the wizard** (WindsurferSetup.cs:754-755), so the last build most likely used 15 N·m/deg (cap reached at 20° of drift). This is a weathervane that directly opposes any turn. The real fin already provides it through its lift at a lever arm (3.3). Recommendation: **drop** (fin section).

#### 3.10 Angles and rates in D4 (for any stabiliser that is kept, and for telemetry)

```
var fwd: Vector3   = basis * Vector3.FORWARD                 # bow direction, world
var right: Vector3 = basis * Vector3.RIGHT                   # starboard, world
var up: Vector3    = basis * Vector3.UP
pitch_rad = asin(clamp(fwd.y, -1.0, 1.0))                    # + = bow up
var right_h: Vector3 = Vector3(right.x, 0.0, right.z).normalized()
heel_rad  = atan2(up.dot(right_h), up.y)                     # + = board up leans to starboard = starboard rail down
omega_local = basis.transposed() * omega_world               # basis is orthonormal
pitch_rate =  omega_local.x                                  # + = bow rising
yaw_rate   =  omega_local.y                                  # + = bow to port
heel_rate  = -omega_local.z                                  # + = heeling to starboard (rotation about +Z, aft, tilts up to port)
```
These use the body basis, so they are correct on every heading (unlike the legacy `angularVelocity.x`).

### Values

| Name | Value | Unit | Source | Notes / conflicts |
|---|---|---|---|---|
| `max_rake_rad` | 15 (0.2618) | deg (rad) | AdvancedSail.cs:41-42; WindsurferSetup.cs:736; EquipmentVisualizer.cs:54-55; Sail.cs:65-66 | All agree. Used only by the visualiser in the last build. |
| Sail rake rate limit | 3.0 | 1/s | AdvancedSail.cs:44-45 | Legacy Sail.cs:68-69 and Session 12 log (PROGRESS_LOG.md:749) used 5.0 for the old component. C# default; not set by the wizard. |
| Controller rake speed | 2.0 | 1/s | AdvancedWindsurferController.cs:38-39 | C# default. |
| Auto-centre speed | 1.0 | 1/s | AdvancedWindsurferController.cs:44-45; enabled at :41-42 and WindsurferSetup.cs:800 | |
| Input smoothing | 8.0 | 1/s | AdvancedWindsurferController.cs:67-68 | Frame-rate step, not physics step. |
| Rake dead zone | 0.1 | – | AdvancedWindsurferController.cs:226 | |
| Rake force multiplier | 0.3 | – | AdvancedSail.cs:506 | PHYSICS_VALIDATION.md:169 and Session 17 log (PROGRESS_LOG.md:1556) say 0.5; Session 16 log (:1461) says 0.05. Last build: 0.3 (code, Session 26 commit b5ed2ea). |
| Direct torque | 200; 350 when abs AWA < 40° or > 140° | N·m | AdvancedSail.cs:511-517 | Session 17 log (PROGRESS_LOG.md:1557) and the rebuild plan say 150. Last build: 200/350 (code). |
| Speed torque | 25 × min(speed, 8) | N·m | AdvancedSail.cs:522 | Session 17 log (:1558): 30 × speed, uncapped. Last build: code. |
| High-speed steering scale | lerp(1, 0.5, (kt−15)/15), floor 0.4 (inactive) | – | AdvancedSail.cs:498-503 | PHYSICS_VALIDATION.md:189-192: lerp(1, 0.3, (kt−15)/10); plan: "0.3 between 15 and 25 kt". Last build: code (0.5 at 30 kt). |
| Tack sign | tack = −sail_side (= sign(AWA) in Unity) | – | AdvancedSail.cs:474, :494; PHYSICS_VALIDATION.md:168; Session 19 log (PROGRESS_LOG.md:566-572) | PROGRESS_LOG.md:79 and ARCHITECTURE.md:22 print `tack = sailSide`, which is the pre-Session-19 (inverted) form. |
| Rake direction | back = head up | – | AdvancedSail.cs:452-455; PHYSICS_VALIDATION.md:174-182 | PHYSICS_VALIDATION.md:297-298 checklist says the opposite; wrong (plan pitfall 1). |
| Hull angular damping base | 1.5 displacement / 0.8 planing | – | AdvancedHullDrag.cs:530 | × mass × 0.1. |
| Hull angular damping speed factor | 1 + (kt−15)/5, max 5 | – | AdvancedHullDrag.cs:532-540 | PHYSICS_VALIDATION.md:206-210: lerp(1, 5, (kt−15)/15). Last build: code. |
| Mass in that damping | 91 (8 + 8 + 75) | kg | SailingState.cs:220-231; WindsurferSetup.cs:768-770 | Rigidbody mass was 91 at creation (WindsurferSetup.cs:690) but BoardMassConfiguration recomputes 8 + 6 + 80 = 94 and writes it at Start (BoardMassConfiguration.cs:110, :191; wizard values :780-782; the wizard's `_totalMass = 95` at :779 is overwritten). The last build ran at 94 kg with the damping computed from 91. |
| Rigidbody.angularDamping | 0.3 | 1/s | WindsurferSetup.cs:691 | 0.5 at WindsurferSetup.cs:1291 (quick-add path) and scene_config.json:23 (old scene). Last build: 0.3 (complete wizard). |
| Buoyancy rotational damping | 150 × (4.0, 0.3, 3.0) × (0.3 + 0.7 submersion) | N·m·s | AdvancedBuoyancy.cs:64-65, :369-378; WindsurferSetup.cs:718 | Agree. |
| Pitch stabiliser gate | > 12 kt, full at 22 kt | kt | AdvancedSail.cs:381, :427 | |
| Pitch damping gain | 20 | N·m per rad/s | AdvancedSail.cs:433 | Session 26 log: "reduced damping multipliers", earlier values not recorded. |
| Pitch spring gain | 4 | N·m per deg | AdvancedSail.cs:436 | Mixed units with the damping. |
| Pitch heel fade | 15° to 25°, off above 25° | deg | AdvancedSail.cs:406-417; KNOWN_ISSUES.md:36; PROGRESS_LOG.md:164-171 | Agree. |
| Pitch clamp | ±300 | N·m | AdvancedSail.cs:441 | |
| Anti-capsize strength | 50; dead zone 5°; max heel 45° | – / deg | AdvancedWindsurferController.cs:59-65, :287-306; WindsurferSetup.cs:799 | Enabled in the last build. |
| Weight shift | 20° max, 80°/s, base 80 N·m, speed term 30 N·m at ≥ 3 m/s | – | AdvancedWindsurferController.cs:47-55, :257-264 | Tack-sign bug on port tack (3.9). |
| Fin tracking strength | 15 | N·m per deg | WindsurferSetup.cs:754-755 | C# default 40 (AdvancedFin.cs:40). Last build: 15 (wizard, FindProperty). |
| Mast foot | (0, 0.1, −0.1) Unity = (0, 0.1, **+0.1**) D4 | m | SailingState.cs:152; WindsurferSetup.cs:46, :734 | 0.1 m aft of the origin. Old Sail.cs:42 and scene_config.json:80 used z = −0.05. |
| Boom height | 1.4 | m | SailingState.cs:155; WindsurferSetup.cs:735 | Old Sail.cs:51 and PHYSICS_DESIGN.md:354: 1.8. |
| Boom length | 2.0 | m | SailingState.cs:136; WindsurferSetup.cs:731 | |
| Luff length | 4.7 | m | SailingState.cs:133; WindsurferSetup.cs:730 | |
| CE height used by physics | 0 (CE at origin) | m | AdvancedSail.cs:283-290 (Session 25/26) | Session 16: 0.3 m; SailingState.cs:166 formula gives 0.8 m; never used by AdvancedSail. |
| CE along boom (legacy) | 0.6 × boom = 1.2 | m | Sail.cs:253; PHYSICS_DESIGN.md:361 | Aerodynamic centre of a foil is at 25 to 40 % of chord; section 2 fixes 0.35 × boom = 0.70 m. |
| `h_ce_m` (proposed) | 1.8 (≈ 38 % of the 4.7 m luff) | m | Literature (Marchaj, *Sail Performance*: CE of a triangular sail near the area centroid, about 40 % of the luff above the foot) | Not in the legacy physics. Section 2 fixes 1.88 m (0.40 × luff). |
| Sail area / aspect ratio | 6.5 / 3.4 | m² / – | SailingState.cs:130, :160; WindsurferSetup.cs:729 | For the estimate in 3.3. |
| Fin | 0.035 m², span 0.40 m, at (0, −0.1, −0.9) Unity = (0, −0.1, **+0.9**) D4 | m², m | WindsurferSetup.cs:749-752 | C# defaults are 0.06 m² and 0.45 m (SailingState.cs:177-180); the wizard wins. |

### Where the force acts

- **Physical model:** the horizontal sail force is applied at `ce_local` (3.2), a real point on the rig. The integrator's `add_force_at(point, force)` produces the yaw torque `r × F` about the centre of mass automatically, and also the pitch torque (drive × height) and the roll torque (side force × height). Whether the sail section applies the force at the full CE height or at a lower point for stability is that section's decision; **the fore-aft position `ce_local.z` and the sideways position `ce_local.x` must be the real ones**, because they are the steering. If the sail section lowers the application height, it must keep `x` and `z` unchanged.
- **Legacy artificial torque:** a pure couple, `AddTorque` about world +Y (no application point), summed with the weight-shift couple and the fin tracking couple. Nothing about these depended on the CE.
- **Pitch stabiliser:** a couple about the body starboard axis (−transform.right × correction in Unity).
- **Anti-capsize:** a couple about the body forward axis.
- **Angular damping (hull, Rigidbody):** couples on the world angular velocity vector; buoyancy damping: a couple in body axes.

### Signs and the Unity-to-Godot translation

| Quantity | Unity (left-handed, bow +Z, starboard +X) | Godot D4 (right-handed, bow −Z, starboard +X) | Flips? |
|---|---|---|---|
| AWA sign | `SignedAngle(fwd, −aw, up)` > 0 for wind from starboard (SailingState.cs:113; verified: cross((0,0,1),(1,0,0)) = (0,1,0)) | `atan2(from_local.x, −from_local.z)` > 0 for wind from starboard | No |
| `sail_side` | `−manualTack` (AdvancedSail.cs:206); +1 = boom to starboard | `−sign(awa_rad)`; +1 = boom to starboard | No |
| Positive yaw torque about +Y | turns the bow to **starboard** (right) | turns the bow to **port** | **Yes** |
| Artificial rake torque | `rake × sign(AWA) × K` about +Y | `rake × sail_side × K = −rake × sign(awa) × K` about +Y | **Yes** (because the yaw direction flips, not the AWA) |
| "Aft" in the body frame | −Z | +Z | **Yes** |
| CE aft of the centre of mass | `r.z < 0` | `r.z > 0` | **Yes** |
| Physical yaw torque `torque.y = r.z × F.x − r.x × F.z` | same formula | same formula | The formula is frame-independent; the signs of `r.z` and `F.z` both flip, so the result is the same physical turn. |
| Positive pitch angle | Euler x > 0 = bow **down** (AdvancedHullDrag.cs:426-428 negates it for trim) | `pitch_rad` > 0 = bow **up** | **Yes** |
| Positive rotation about the starboard axis | bow down | bow up | **Yes** |
| Heel sign in the controller | `SignedAngle(up, board_up, forward)` < 0 when heeled to starboard | `heel_rad` > 0 when heeled to starboard | **Yes** |
| Restoring roll torque | `transform.forward × (−k × heel_unity)` | `Vector3.FORWARD × (−k × heel_rad)` in body axes, i.e. torque z-component `+k × heel_rad` | Same expression, opposite heel sign, same physical result |
| Rotation about the aft axis (+Z in Godot) | – | tilts board-up to port, so `heel_rate = −omega_local.z` | – |
| Old Sail.cs rake CE offset | `rakeOffsetZ = +sin(rake) × boomHeight` (Sail.cs:243-247) moves the CE **forward** (+Z) for rake back: a sign bug in the abandoned component | `delta_z = +h_ce × sin(rake_rad)` moves it aft (+Z) | Note only |

Derivation of the "rake back = head up" sign on each tack, in D4:

| Tack | `awa` | `sail_side` | Side force `F.x` | CE aft of COM: `r.z > 0` | `torque.y = r.z × F.x` | Bow turns | Toward the wind? |
|---|---|---|---|---|---|---|---|
| Starboard (wind from starboard) | > 0 | −1 | < 0 (pushed to port) | yes | < 0 | to starboard | yes: head up |
| Port (wind from port) | < 0 | +1 | > 0 (pushed to starboard) | yes | > 0 | to port | yes: head up |

Rake forward makes `r.z` smaller (or negative), so the same table gives bear away. No tack switch is needed anywhere in the physical model. For the artificial form, the D4 sign is `torque_yaw_nm = sail_side × rake × K`: starboard tack, rake back → `−K` → bow to starboard → head up. Correct.

### Stabilisers and fudges in this model

| Term | What it is | Why it was added (session, symptom) | What it probably hides | Recommendation |
|---|---|---|---|---|
| Rake force term `0.3 × rake × tack × F` | Yaw couple proportional to sail force | Session 7 (Sail.cs, 0.5) because the board "couldn't point upwind"; tuned 3.5 → 0.6 (Session 12), 0.05 (Session 16), 0.5 (Session 17), 0.3 (final) | The CE never moved (CE height 0.3 m in Session 16, 0 in Session 25), so the real lever was missing | **Drop.** Build the CE-shift model (3.2). |
| Direct term 200 / 350 N·m | Constant yaw couple per unit rake, even with no wind | Session 17 ("150 base"), raised later; comment says "always works regardless of sail force" and "stronger when sail force is weak" | Missing rail/weight steering, and that in irons a real windsurfer cannot steer with the rig | **Drop.** Provide an explicit weight-shift channel in the sailor section and the Space-tack in Phase 3. |
| Speed term `25 × min(v, 8)` | Yaw couple growing with speed | Session 17 ("more fin effect") | The fin already turns harder at speed through its lift; the term double-counts | **Drop.** |
| High-speed scale-down to 0.5 at 30 kt | Multiplies the artificial torque | Session 18 commit 4c45223 ("high-speed stability damping"); symptom: instability above 15 kt | The artificial torque was 4 to 5× too strong and had no natural limit; the physical lever is self-limited by the fin | **Drop.** |
| Tack sign `tack = −sail_side` | Makes the artificial couple change sign with the tack | Session 19, rake direction was inverted | Nothing physical; an artefact of a torque that is not derived from a force at a point | **Drop** (not needed with the physical model). |
| Weight-shift yaw couple 80 + 30 N·m | Second artificial steering couple from A/D | Session 22 ("control at zero speed") | Same as the direct term; has a port-tack sign bug | **Drop**; replace with an explicit sailor-section model. |
| Fin tracking couple 15 N·m/deg | Yaw spring toward the velocity direction | Session 13/18 ("fin helps board go straight") | The fin's own lift at its lever arm does this physically | **Drop** (fin section). |
| Hull speed-dependent angular damping (×1 to ×5) | Isotropic couple against the world angular velocity | Session 18 commit 4c45223, "violent oscillations at planing speeds" | Missing physical damping (fin at speed, hull rotational drag) and over-strong steering couples | **Drop.** Re-evaluate only if a Phase 4 planing test oscillates, and then add physical damping in body axes. |
| Rigidbody.angularDamping 0.3 | PhysX exponential decay of angular velocity | Wizard default (Session 14/20), "minimal angular damping" | Nothing specific | **Drop.** |
| Buoyancy rotational damping 150 × (4, 0.3, 3) | Body-axis couple, scaled with submersion | Session 22, pitch and roll multipliers doubled in Session 24/25 against porpoising | Real rotational water resistance, but the yaw part duplicates the fin | **Re-evaluate in the buoyancy section**; keep pitch/roll with a physical basis, drop yaw. |
| Pitch spring-damper (20, 4, fade 15 to 25°, ±300) | Couple about the starboard axis at > 12 kt | Session 24 (porpoising), Session 26 (heel fade after "spasming") | Planing lift applied at the wrong point, wrong CE height, world/body axis bug | **Drop.** |
| Anti-capsize (dead zone 5°, 0.556 × heel × abs(heel) N·m, hard limit above 45°) | Couple about the bow axis | Session 8 (V2 controller), kept in Session 18 | No sailor righting-moment model; roll inertia ten times too small; no heeling moment to fight once the CE was at 0 | **Drop.** Model the sailor's righting moment explicitly; a documented "auto-hike" beginner assist may be added if Phase 3 needs it. |
| Sail force reduction to 0.6 between 20 and 35 kt (AdvancedSail.cs:366-374) | Scales the applied sail force | Session 18/24, "nose-diving and flipping" | Sail section topic; listed because the rake force term read the unreduced value | See the sail section. |
| Second rake rate limiter (3/s in the sail on top of 2/s in the controller) | Redundant smoothing | Session 13 design | Nothing | **Keep one** rate limit in the simulation (3/s) and the controller's integration; drop the duplicate. |

### What Phase 2 must implement

- [ ] `rake_target` input (−1 to 1) clamped and rate-limited in the simulation at `rake_rate_per_s = 3.0`; `rake_rad = rake * max_rake_rad` with `max_rake_rad = deg_to_rad(15.0)` in `SailConfig`.
- [ ] Controller-side (Phase 3, but the sim API must allow it): integrate A/D and Q/E at 2/s, dead zone 0.1, auto-centre at 1/s, and D4's "A left, D right on either tack" mapping: `rake_key = steer_key * sail_side`... check: on starboard tack (`sail_side = −1`) D (+1) must rake back (+1), so `rake_key = −steer_key * sail_side`. Write the test before the code.
- [ ] `SailConfig` fields: `mast_foot_local` (section 14), `h_ce_m` = 0.40 × luff (section 2.13), `ce_along_boom_m` = 0.35 × boom (section 2.13), `boom_length_m` and `luff_length_m` (section 14).
- [ ] `ce_local` from 3.2, recomputed every step from `rake_rad`, `sheet_angle_rad` and `sail_side`; exposed in `Telemetry` (so Phase 6 can draw the boom and the force arrow at the right place).
- [ ] The horizontal sail force applied with `add_force_at(ce_world, f_sail_h)` so that yaw, pitch and roll torques follow from geometry. No `AddTorque`-style rake couple anywhere.
- [ ] **No** artificial yaw torque, direct term, speed term, high-speed scale-down, tack sign, weight-shift couple, fin tracking couple, speed-dependent angular damping, Rigidbody-style angular damping, pitch stabiliser or anti-capsize torque. Each of these gets a one-line comment in `PHYSICS_SPEC.md`'s tuning log only if Phase 4 brings it back.
- [ ] The D4 angle and rate helpers of 3.10 (`pitch_rad`, `heel_rad`, `pitch_rate`, `yaw_rate`, `heel_rate`) in the rigid-body state, used by telemetry and tests.
- [ ] A validation-suite hook for Phase 4: log the steady yaw rate at full rake on a beam reach in 15 kt, both tacks, so the team can compare with the 21°/s estimate and decide.

### Tests Phase 2 should write

- **Rake to angle:** `rake = 1.0` → `rake_rad = 0.2618`; `rake = −0.5` → `−0.1309`; `rake = 1.7` is clamped to 1.0.
- **Rate limit:** from `rake = 0` with `rake_target = 1`, after one step of `dt = 0.1 s` the rake is 0.3; after 0.4 s it is 1.0 and stays.
- **Controller integration and auto-centre (Phase 3):** D held 0.25 s → `rake = +0.5` on starboard tack and `−0.5` on port tack; release → back to 0 after 0.5 s; Q/E are not tack-inverted.
- **CE shift:** `h_ce_m = 1.8`, `rake = 1`, sheet and side fixed → `ce_local.z` increases by 0.4659 m and `ce_local.y` drops by 0.0613 m compared with `rake = 0`. `rake = −1` gives the mirror.
- **Sheet shift:** `ce_along_boom_m = 1.2`, `sail_side = +1`: sheet angle 12° → boom offset (0.2495, 0, 1.1738); 85° → (1.1954, 0, 0.1046). Note the 1.07 m fore-aft swing.
- **Yaw sign, starboard tack:** a body at rest, `com_local = (0, 0, 0)`, force `(−250, 0, 0)` N at `(0, 0, 0.466)` → `torque = (0, −116.5, 0)` N·m; after integrating, `yaw_rate < 0` and the compass heading **increases** (bow to starboard). With `awa > 0` that is heading up.
- **Yaw sign, port tack:** force `(+250, 0, 0)` at the same point → `torque.y = +116.5` → heading decreases (bow to port) = heading up for `awa < 0`.
- **Weather-helm term:** force `(0, 0, −280)` (pure drive) at `(−0.77, 0, 1.0)` (clew to port, starboard tack) → `torque.y = −r.x × F.z = −(−0.77 × −280) = −215.6` N·m → bow to starboard = head up. Mirror for port tack.
- **No wind, no steering:** `f_sail_h = 0` and `rake = 1` → yaw torque exactly 0 (proves no hidden couple).
- **Full-sim behaviour (flat water, 15 kt, beam reach, fixed sheet):** hold `rake = +1` for 2 s → TWA decreases by at least 15° (estimate: about 40°); `rake = −1` → TWA increases by at least 15°; the two tacks agree within 2 %. Same test at standstill with the sail sheeted: the board starts turning within 1 s.
- **Angle and rate helpers:** a basis rotated +10° about +X → `pitch_rad = +0.1745`; rotated +10° about the bow axis (= −10° about +Z) → `heel_rad = +0.1745`; a 90° yaw first changes neither. `omega_world = (0, 1, 0)` for 0.1 s → the heading decreases by 5.73°; `omega_local = (0, 0, 1)` → `heel_rate = −1`.
- **Fin cross-check (fin section):** at 5 m/s with `yaw_rate = 0.36 rad/s` the fin's yaw torque is about −115 N·m (±30 %), matching 3.3.
- **Phase 4 targets to record, not assert yet:** steady turn rate at full rake in 15 kt on a beam reach (estimate 21°/s), and how much the heading changes when only the sheet is moved from 0.65 to 0.2 at neutral rake. If the sheet effect dominates the rake effect, lower `ce_along_boom_m` toward 0.7 m before touching anything else.

### Sources

- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs`: 37-45 (rake fields), 65-66, 80-81 (manual tack), 125-133 (tick order), 137-153 (control smoothing), 197-227 (sail side, sheet angle), 283-290 (CE = 0), 357-389 (force application, high-speed reduction, calls), 396-445 (pitch stabilisation), 450-525 (rake steering), 549-563 (tack switch), 617-628 (rake setters).
- `Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs`: 37-68 (settings), 152-176 (A/D tack inversion, Q/E), 195-201 (smoothing), 206-243 (integration, auto-centre, weight shift), 248-270 (weight-shift couple), 276-307 (anti-capsize).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/Sail.cs` (abandoned component, history): 60-72 (rake fields), 241-264 (CE with rake offset, sign bug at 243-247), 281-296 (untacked rake couple), 417-444 (setters).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs`: 86-87, 139-149 (floating gate), 160-194 (planing flag), 426-431 (Unity pitch sign), 513-545 (speed-dependent angular damping).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs`: 57-68 (damping fields), 312-384 (damping, rotational at 361-383).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs`: 36-40, 78-81, 131-149 (force point), 155-187 (tracking couple).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs`: 22-64 (masses, COM, inertia flags), 107-136 (mass recomputation), 141-181 (inertia), 186-205 (applied at Start).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs`: 97-119 (AWA), 126-167 (SailConfiguration), 173-197 (FinConfiguration), 203-242 (HullConfiguration).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs`: 24-73 (lift curve), 79-106 (drag), 119-250 (force directions) for the estimate in 3.3.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs`: 12-24, 26-51.
- `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs`: 46 (mast base), 676-700 (Rigidbody 91 kg, angularDamping 0.3), 723-741 (sail values, max rake), 744-756 (fin values, tracking 15), 759-771 (hull masses), 775-788 (mass config, custom inertia off), 791-801 (controller: anti-capsize and auto-centre on), 1271-1300 (quick-add path, angularDamping 0.5).
- `Legacy/WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs`: 54-55, 97-98, 222-237 (visual rake only).
- `Legacy/WindsurfingGame/Assets/Scripts/Player/WindsurferControllerV2.cs` (history, not in the wizard's scene): 53-62, 291-330 (5-point stabilisation), 219-236 (tack-flipped rake for the old Sail), 444-464 (anti-capsize).
- `Legacy/Documentation/PHYSICS_VALIDATION.md`: 160-193 (rake steering, high-speed damping), 197-213 (angular damping), 290-303 (checklist with the inverted rake lines).
- `Legacy/Documentation/KNOWN_ISSUES.md`: 30-46 (issue 1, pitch stabilisation and roll transfer), 81-87 (Session 26 fixes), 94-106 (Session 25).
- `Legacy/Documentation/PROGRESS_LOG.md`: 72-82 (summary table with the stale `tack = sailSide`), 139-213 (Session 26), 215-275 (Session 24), 277-335 (Session 18 validation), 337-453 (Session 22), 554-600 (Session 19 rake fix), 602-672 (Session 18 overhaul), 674-790 (Session 12 tuning history), 1054-1111 (Session 7, first rake steering), 1113-1190 (Session 8), 1443-1521 (Sessions 14-16), 1523-1580 (Session 17 steering formula). Sessions 23 and 25 have no entries in this log; their content is in KNOWN_ISSUES.md.
- `Legacy/Documentation/PHYSICS_DESIGN.md`: 346-366 (rake and CE description, 60 % of boom).
- `Legacy/Documentation/scene_config.json`: 23, 80-88, 136-146 (2025-12-27 old components; history only).
- `Legacy/Documentation/ARCHITECTURE.md`: 22 (stale `tack = sailSide`).
- Literature: C. A. Marchaj, *Sail Performance: Theory and Practice* (CE position and the helm-balance lever); L. Larsson and R. E. Eliasson, *Principles of Yacht Design* (CE/CLR balance, lead); fin lift slope from the finite-wing formula `2π·AR/(AR+2)`.
- Git: the last played physics is commit b5ed2ea (Session 26, 2026-01-02) for AdvancedSail.cs, AdvancedWindsurferController.cs, AdvancedHullDrag.cs and AdvancedBuoyancy.cs; AdvancedFin.cs last changed in 4c45223 (2025-12-27); WindsurferSetup.cs was edited again in 757d5cf (Session 27, unverified) but its physics values are unchanged from Session 22.

OPEN questions are collected in the return value; in the text they are: the CE height `h_ce_m` and the along-boom fraction (sail section), whether the abandoned `Sail` component was still active in the Session 26 scene (Session 24/26 logs edited it), which inspector values the played scene really carried (the wizard was run in Session 22; later hand-tweaks are unknowable), whether the last build ran at 91 or 94 kg, and the target turn rate the team wants at full rake.

---

## 4. Fin

### Purpose

The fin is a small underwater wing under the tail of the board. The sail pushes the board mostly sideways (to leeward). Without a fin the board would simply drift downwind. When the board slips a little sideways through the water, the water meets the fin at a small angle (the *slip angle* or *leeway angle*), and the fin produces a large sideways force back toward the wind, exactly like an aeroplane wing produces lift when air meets it at an angle. That side force is what turns the sail's sideways push into forward motion, and it is what makes sailing upwind possible.

The model has to give the game:

- A side force that is zero when the board goes straight, grows with the slip angle and with the square of the speed, and collapses when the slip angle gets too big (stall, which the sailor feels as "spin-out").
- A drag force from the fin: a small constant part (skin friction) plus a part that grows with the square of the side force (induced drag). Session 25 found this is what should make a broad reach faster than a beam reach.
- Because the fin sits behind and below the centre of mass, its side force also produces a roll moment and a yaw moment. Those come for free from applying the force at the right point.

The last played Unity build (Sessions 22 to 26, `MainScene.unity`) used **`AdvancedFin.cs`** with the helper functions in **`Hydrodynamics.cs`**. The older `FinPhysics.cs` was never on the board in `MainScene.unity` in any committed version (checked with `git show <commit>:…/MainScene.unity | grep FinPhysics` for commits 4c45223, 5a1857a, c62f577, e6756db, b5ed2ea and 757d5cf: zero hits, `AdvancedFin` present in all). `FinPhysics` was only reachable through the "Quick: Add Components to Selected" menu (`Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs:1321-1322`) and is described in the 2025-12-27 `scene_config.json`, which is history. This section therefore specifies the `AdvancedFin` model, and describes `FinPhysics` only far enough to show why nothing should be taken from it.

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `v_boat` | velocity of the board's centre of mass, world frame | m/s |
| `omega` | angular velocity of the board, world frame (new in the spec; legacy did not use it) | rad/s |
| `v_water` | velocity of the water at the fin (new in the spec; flat water gives 0; waves give the orbital velocity in Phase 5) | m/s |
| `basis` | orientation of the board (body axes: bow −Z, starboard +X, up +Y) | – |
| `fin_root_pos` | fin root position in the body frame | m |
| `fin_area_m2` | projected fin area | m² |
| `fin_span_m` | fin depth (root to tip) | m |
| `rho_water` | water density, 1025 | kg/m³ |
| **Output** `slip_rad` | slip (leeway) angle of the flow at the fin, positive when the board slips toward starboard | rad |
| **Output** `cl` | lift coefficient, signed like `slip_rad` | – |
| **Output** `cd` | drag coefficient (profile + induced + viscous) | – |
| **Output** `lift_force` | side force, world frame, perpendicular to the relative flow | N |
| **Output** `drag_force` | drag, world frame, along the relative flow | N |
| **Output** `application_point` | fin centre of pressure, body frame | m |
| **Output** `is_stalled` | true when |slip| is past the lift peak (display only) | – |

Controls do not enter this model. Rake, sheet and weight shift act through the sail and the sailor's mass, never on the fin directly.

### Formulas

Everything below is in D4 conventions (Godot, right-handed): body frame bow = −Z, starboard = +X, up = +Y; positive rotation about +Y turns the bow to port.

**4.1 Geometry.** The fin is a thin plate hanging straight down from the hull, chord fore-and-aft, thickness across the board (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs:234-237`).

```
aspect_ratio = fin_span_m * fin_span_m / fin_area_m2          # = 0.40² / 0.035 = 4.571
mean_chord_m = fin_area_m2 / fin_span_m                        # = 0.0875 m (the config "Chord = 0.10" is only used for the debug gizmo)
```

Source: `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:196` (`AspectRatio => Depth*Depth/Area`). Aspect ratio is span squared over area; a long, narrow fin (high AR) makes more lift per degree and less induced drag, like a glider wing.

**4.2 Relative water velocity at the fin.** The legacy code used the centre-of-mass velocity `_rigidbody.linearVelocity` (`AdvancedFin.cs:89`) and nothing else: no water velocity (no such API existed in `WaterSurface.cs`; grep for "velocity" in `Legacy/WindsurfingGame/Assets/Scripts/Physics/Water/*.cs` finds nothing) and no angular velocity. The spec adds both, because a fin 0.8 m behind the centre of mass sees extra sideways flow when the board is turning, and that is the real source of yaw damping (see 4.9):

```
r_fin_world   = basis * (cop_body)                       # cop_body from "Where the force acts"
v_fin_world   = v_boat + omega.cross(r_fin_world)        # velocity of the fin point itself
v_rel_world   = v_fin_world - v_water                    # fin velocity relative to the water
v_rel_body    = basis.inverse() * v_rel_world
v_plane_body  = Vector3(v_rel_body.x, 0.0, v_rel_body.z) # flow in the fin's own plane (chord × normal)
speed_ms      = v_plane_body.length()
```

The spanwise component `v_rel_body.y` (water flowing along the fin, up or down) makes no lift and only a little drag on a thin fin, so it is dropped. The legacy code instead used the full 3-D speed for the dynamic pressure and the full 3-D velocity for the drag direction (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Hydrodynamics.cs:108,118,143,154`), so a board bobbing up and down on waves got extra fin drag. The slip angle in the legacy code was taken from the *world-horizontal* projections of velocity and forward (`Hydrodynamics.cs:122-123,136`), which ignores heel and pitch; the spec uses the body-frame flow, which is the flow the fin really sees.

**4.3 Slip (leeway) angle.** The angle between the bow and the direction the fin is moving through the water, positive when the board slips toward starboard:

```
slip_rad = atan2(v_plane_body.x, -v_plane_body.z)
```

Going straight ahead gives `v_plane_body = (0, 0, -speed)` and `slip_rad = 0`. Slipping to starboard gives `x > 0` and a positive angle. This is the same `atan2(x, -z)` pattern as the wind angles in D4. The slip angle is the fin's angle of attack.

**4.4 Lift coefficient.** Lifting-line theory says a finite wing's lift per radian of angle of attack is smaller than the thin-aerofoil value 2π, by roughly `AR / (AR + 2)`. The legacy code multiplies by an extra `(1 + tau)` with `tau = 0.05` (`Hydrodynamics.cs:31-32`), and then uses a piecewise curve with fixed breakpoints in degrees (`Hydrodynamics.cs:38-69`). With `a_deg = abs(rad_to_deg(slip_rad))`:

```
lift_slope_per_rad = 2.0 * PI * aspect_ratio / (aspect_ratio + 2.0) * lift_slope_factor     # lift_slope_factor = 1.05 (legacy "1 + tau")
cl_8   = lift_slope_per_rad * deg_to_rad(8.0)             # end of the linear region
cl_max = cl_8 + 0.15                                       # lift peak, at 12°

if a_deg < 8.0:                                            # attached flow: lift rises linearly with angle
    cl_abs = lift_slope_per_rad * abs(slip_rad)
elif a_deg < 12.0:                                         # flow starts to separate: lift still rises, but more slowly
    cl_abs = cl_8 + (a_deg - 8.0) / 4.0 * 0.15
elif a_deg < 16.0:                                         # stall: lift falls from the peak to 70 % of it
    cl_abs = lerp(cl_max, 0.7 * cl_max, (a_deg - 12.0) / 4.0)
elif a_deg < 25.0:                                         # post-stall: lift fades toward a flat-plate value of 0.4
    cl_abs = lerp(0.7 * cl_max, 0.4, (a_deg - 16.0) / 9.0)      # SEE NOTE: legacy starts this branch at 0.7 * cl_8, not 0.7 * cl_max
else:                                                      # deep stall: the fin works as a flat plate; never below 0.1
    cl_abs = max(0.4 * cos(deg_to_rad((a_deg - 25.0) * 2.0)), 0.1)

cl = cl_abs * sign(slip_rad)                               # lift is antisymmetric: slipping the other way flips it
```

Note on the discontinuity: the legacy 16–25° branch starts at `liftSlope * 8° * 0.7` (`Hydrodynamics.cs:60`), which forgets the `+0.15` bump and so jumps from 0.5536 down to 0.4486 exactly at 16° (a step of −0.105, 19 %). A step in a force curve is a source of jitter. The spec starts the branch at `0.7 * cl_max` so the curve is continuous. All other numbers are unchanged.

Note on the stall angle setting: the config value `StallAngle = 14°` (`SailingState.cs:191`) is **not used by the curve**. It only sets the `_isStalled` flag (`AdvancedFin.cs:123`), which feeds the tracking torque (`AdvancedFin.cs:179`) and the HUD. The breakpoints 8, 12, 16 and 25° are hard-coded. The spec makes the breakpoints named config values (`stall_linear_end_deg = 8`, `stall_peak_deg = 12`, `stall_drop_end_deg = 16`, `deep_stall_deg = 25`, `stall_bump_cl = 0.15`, `deep_stall_cl = 0.4`, `min_cl = 0.1`) and defines `is_stalled = a_deg > stall_peak_deg`.

Note on `lift_slope_factor`: in the textbook form (Anderson, *Fundamentals of Aerodynamics*, lifting-line correction for non-elliptic loading) `tau` *reduces* the slope: `a = 2π / (1 + (2/AR)(1 + tau))`. The legacy factor increases it. On the other hand the hull acts as an end plate for the fin, which raises the effective aspect ratio (up to a factor 2 for a fin sitting flat against a wide hull), which would raise the slope further. The two effects go in opposite directions and neither is measured, so the spec keeps the legacy number as one named factor (`lift_slope_factor = 1.05`) to be re-evaluated in Phase 4.

Resulting table (legacy numbers, AR = 4.571, slope = 4.5895 per rad = 0.0801 per degree):

| slip (deg) | cl | note |
|---|---|---|
| 0 | 0.0000 | |
| 1 | 0.0801 | |
| 2 | 0.1602 | |
| 4 | 0.3204 | worked example |
| 6 | 0.4806 | |
| 8 | 0.6408 | end of linear region |
| 10 | 0.7158 | |
| 12 | 0.7908 | peak |
| 14 | 0.6722 | legacy `StallAngle` flag |
| 16 | 0.5536 | (legacy jumps to 0.4486 here) |
| 20 | 0.4270 | (legacy 0.4335) |
| 25 | 0.4000 | |
| 45 | 0.3064 | |
| ≥ 70 | 0.1000 | floor |

**4.5 Drag coefficient.** Three parts (`Hydrodynamics.cs:78-93`): profile (skin friction) drag of the section, induced drag from making lift (the tip vortex: `cl² / (π · AR · e)`, quadratic in lift, which is the Session 25 point), and an ad-hoc "viscous" increase with angle:

```
cd_profile = 0.008                                          # NACA 0012-like section, Re ~ 1e6 (legacy: "slightly higher for typical fin construction")
oswald_e   = 0.85                                           # span-efficiency factor
cd_induced = cl * cl / (PI * aspect_ratio * oswald_e)
cd_viscous = cd_profile * abs(cl) * 0.5                     # boundary layer thickening with angle (ad hoc, small)
cd = cd_profile + cd_induced + cd_viscous
```

Induced drag is the price of lift: to push water sideways the fin must leave a vortex behind, and the energy in that vortex is lost. Because it grows with `cl²`, a board that needs twice the side force (beam reach vs broad reach) pays four times the induced drag.

**4.6 Dynamic pressure and force magnitudes.**

```
q_pa    = 0.5 * rho_water * speed_ms * speed_ms
lift_n  = q_pa * fin_area_m2 * abs(cl)
drag_n  = q_pa * fin_area_m2 * cd
```

(`Hydrodynamics.cs:143-147`.) Dynamic pressure is the pressure a fluid exerts when it is stopped; force = pressure × area × coefficient.

**4.7 Force directions.** Drag acts along the relative flow (it pushes the fin the way the water is moving relative to it). Lift acts perpendicular to the relative flow, in the fin's plane, pointing against the slip:

```
flow_dir_body = v_plane_body / speed_ms                     # unit vector, direction the fin moves through the water
drag_dir_body = -flow_dir_body
lift_dir_body = sign(slip_rad) * Vector3(flow_dir_body.z, 0.0, -flow_dir_body.x)   # perpendicular to the flow, opposes the slip

lift_force = basis * (lift_dir_body * lift_n)
drag_force = basis * (drag_dir_body * drag_n)
```

Check: slipping to starboard (`slip > 0`, `flow_dir ≈ (sin β, 0, −cos β)`) gives `lift_dir ≈ (−cos β, 0, −sin β)`, i.e. to port. Slipping to port gives lift to starboard. The fin always pushes the board back toward where its bow points, which on a tack means toward the wind.

**This is a deliberate change from the legacy code.** The legacy lift direction was `-finRight * sign(leeway)` (`Hydrodynamics.cs:151`), i.e. exactly along the board's −X/+X axis, perpendicular to the *chord* rather than to the *flow*. A force perpendicular to the chord has a component of `lift_n · sin(slip)` pointing against the motion, which is extra drag that the code never reported. At the worked example (8 m/s, 4°) that hidden drag is 25.7 N, more than the 20.3 N of drag the model calculates. The `cl²/(π AR e)` formula already accounts for the tilt of the force caused by the downwash, so the legacy model counted the tilt twice (and the chord-normal tilt is about 2.7 times bigger than the induced-drag tilt for this fin). Aerofoil theory defines lift as perpendicular to the free stream and drag as along it; the spec does the same. This makes the fin noticeably less draggy than in the Unity build, so Phase 4 should expect higher speeds from this change alone.

**4.8 Low-speed guard.** Three thresholds existed in the legacy code:

1. `AdvancedFin.cs:93-103`: if `speed < _minEffectiveSpeed` (0.5 m/s) everything is zero and the function returns early.
2. `AdvancedFin.cs:105-106,126-127`: otherwise the forces are multiplied by `effectiveness = clamp((speed − 0.5) / (2.0 − 0.5), 0, 1)`, a linear fade-in from 0.5 m/s to 2.0 m/s.
3. `Hydrodynamics.cs:110-116` and `125-131`: zero force if the 3-D speed is below 0.3 m/s or the horizontal speed below 0.1 m/s (never reached because of 1).

The fade-in is a fudge (see "Stabilisers and fudges"). The spec keeps only a numeric guard so that nothing divides by zero:

```
if speed_ms < 0.05:      # forces at this speed are below 0.01 N anyway (q = 1.3 Pa)
    return zero forces, slip_rad = 0
```

**4.9 Legacy tracking torque (not part of the spec, documented for the record).** `AdvancedFin.ApplyTrackingTorque()` (`AdvancedFin.cs:155-187`) added a yaw torque that turns the bow toward the velocity direction:

```
angle_error_deg = SignedAngle(forward_horizontal, velocity_horizontal, up)      # Unity: positive when velocity is to the RIGHT of the bow
speed_factor    = clamp01(speed / 2.0)                                           # AdvancedFin.cs:178, uses _fullEffectSpeed
stall_factor    = 0.3 if is_stalled else 1.0                                     # AdvancedFin.cs:179
torque_nm       = angle_error_deg * tracking_strength * speed_factor * stall_factor * effectiveness   # AdvancedFin.cs:181
torque_nm       = clamp(torque_nm, -300, 300)                                    # AdvancedFin.cs:184
AddTorque(Vector3.up * torque_nm)                                                # AdvancedFin.cs:186, Unity: +Y turns the bow to the RIGHT
```

`tracking_strength` is in N·m per degree of slip: 15 in the played scene (`Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:318`; wizard `WindsurferSetup.cs:755`), 40 as the C# default since commit 4c45223 (`AdvancedFin.cs:40`). At 4° slip that is 60 N·m (scene) or 160 N·m (default). Skipped entirely when `speed < 0.5 m/s` or horizontal speed² < 0.01 (`AdvancedFin.cs:158,164`).

Why it is redundant: the fin's own lift, applied 0.8 m behind the centre of mass, already produces a yaw torque of `0.8 · lift_n` toward the velocity direction (see "Where the force acts"): 295 N·m at the worked example, five times the tracking torque. In the legacy code that physical torque existed too (the force was applied at the fin), so the tracking torque was a second copy of an effect the model already had. If the spec also feeds the angular velocity into the fin (4.2), the fin further damps yaw rotation by itself. The spec drops the tracking torque.

**4.10 The legacy `FinPhysics.cs` model (not used by the last build; for the record).** `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/FinPhysics.cs`: slip angle `atan2(v_local.x, max(0.1, |v_local.z|))` in degrees (line 110); lift coefficient curve `8 · 0.5 · a` below 1°, `8 · sqrt(a / 25)` up to the 25° stall, `8 · exp(−(a − 25) · 0.5 / 10)` beyond (lines 181-206, `_liftCoefficient = 8`, `_stallAngle = 25`, `_stallFalloff = 0.5` at lines 22, 43, 46); lift along `±transform.right` (line 125-126); fade-in 0.5 to 3 m/s (lines 29, 32, 113); induced drag made quadratic in Session 25 (commit e6756db, lines 132-137: hard-coded span 0.35 m, `e = 0.85`, `cd0 = 0.008`); tracking torque with strength 8 clamped to ±50 N·m (lines 36, 169-172); area 0.08 m² (line 19); position (0, −0.1, −0.8) (line 25). With these numbers, at 8 m/s and 4° slip the lift coefficient is `8 · sqrt(4/25) = 3.2` and the lift 8 397 N, nine times the weight of the sailor, so this model was clearly never tuned for use. Nothing from it goes into the spec. Important consequence: the Session 25 "quadratic induced drag" fix (`Legacy/Documentation/KNOWN_ISSUES.md:96`) changed only this unused file; the played build's fin drag came from `Hydrodynamics.CalculateFinDragCoefficient`, which has been quadratic since it was written in Session 13 (commit ca7a7b1, 2025-12-27; verified with `git show ca7a7b1:…/Hydrodynamics.cs`). So the Session 25 note "this should make broad reach faster" was never actually tested by that change.

**4.11 Worked example: 8 m/s, 4° slip, legacy coefficients.** Starboard tack (wind from starboard), the sail pushes the board to port, so the board slips to port: `slip_rad = −0.06981` (−4°). `v_plane_body = 8 · (−0.06976, 0, −0.99756)`.

```
aspect_ratio        = 0.40² / 0.035                 = 4.5714
lift_slope_per_rad  = 2π · 4.5714 / 6.5714 · 1.05   = 4.5895   (0.0801 per degree)
cl                  = −4.5895 · 0.06981              = −0.3204   (|slip| < 8°, linear branch)
q_pa                = 0.5 · 1025 · 8²                = 32 800 Pa
lift_n              = 32 800 · 0.035 · 0.3204        = 367.8 N
cd_induced          = 0.3204² / (π · 4.5714 · 0.85)  = 0.008410
cd_viscous          = 0.008 · 0.3204 · 0.5           = 0.001282
cd                  = 0.008 + 0.008410 + 0.001282    = 0.017692
drag_n              = 32 800 · 0.035 · 0.017692      = 20.31 N   (profile 9.18 N, induced 9.65 N, viscous 1.47 N)
```

Directions (spec, 4.7): `lift_dir_body = sign(−1) · (−0.99756, 0, +0.06976) = (+0.99756, 0, −0.06976)`, so the lift vector in the body frame is `(+366.9, 0, −25.7) N`: to starboard (to windward, against the slip) with a small bow-ward component. Drag `= −20.31 · (−0.06976, 0, −0.99756) = (+1.4, 0, +20.3) N`: aft. Along the course the fin only retards the board by 20.3 N; across the course it pushes 367.8 N to windward.

The same case in the legacy code: lift `(+367.8, 0, 0)` along +X, drag as above. Projected on the course direction the fin then retards the board by `367.8 · sin 4° + 20.2 = 46.0 N`, 2.3 times the spec value. The legacy build also multiplied by `effectiveness = 1` (speed above 2 m/s), added a tracking torque of `4 · 15 = 60 N·m`, and the 0.5-m/s guard did not apply.

Lower speeds with the same slip angle (lift scales with speed²): 4 m/s → 92.0 N lift, 5.1 N drag; 2 m/s → 23.0 N lift; 1.25 m/s → 9.0 N lift, which the legacy fade-in halved to 4.5 N.

### Values

Where the C# default, the wizard/scene and the docs disagree, all values are listed. The played build used the values serialized in `MainScene.unity`, because Unity's serialized values override the C# field initialisers; the wizard wrote the same numbers, and the `-S` git search shows they have been in the scene unchanged since commits 4c45223 / 5a1857a (27–28 Dec 2025), i.e. through Sessions 22–27.

| Name | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `rho_water` | 1025 | kg/m³ | `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:13`; `FinPhysics.cs:55` | none |
| `fin_area_m2` | **0.035** | m² | scene `MainScene.unity:310`; wizard `WindsurferSetup.cs:749`; `PhysicsConstants.cs:39` | C# default 0.06 (`SailingState.cs:177`, "increased from 0.035 for more lateral grip", commit 4c45223) never reached the scene; docs say 0.04 (`Legacy/Documentation/PHYSICS_DESIGN.md:562`, `PROGRESS_LOG.md:1028`, `scene_config.json:97`); `FinPhysics.cs:19` says 0.08. Build used 0.035. |
| `fin_span_m` (Depth) | **0.40** | m | scene `MainScene.unity:311`; wizard `WindsurferSetup.cs:750`; `PhysicsConstants.cs:37` | C# default 0.45 (`SailingState.cs:180`); `FinPhysics.cs:132` hard-codes 0.35. Build used 0.40. |
| `Chord` (gizmo only) | 0.10 | m | scene `:312`; wizard `:751`; `SailingState.cs:183` | `PhysicsConstants.cs:38` says 0.12. Not used in any force; `area/span` = 0.0875 m. |
| `aspect_ratio` | 4.571 (computed) | – | `SailingState.cs:196` | `PhysicsConstants.cs:40` and the default parameters in `Hydrodynamics.cs:23,78` say 4.5 (never passed; the computed value is used, `AdvancedFin.cs:114`). `FinPhysics` gave 1.53. |
| `fin_root_pos` (legacy `Position`, Unity frame) | (0, −0.10, −0.90) | m | scene `:313`; wizard `:752`; `SailingState.cs:187` | `FinPhysics.cs:25` and `scene_config.json:99`: (0, −0.1, −0.8). In D4: **(0, −0.10, +0.90)**. |
| centre-of-pressure depth fraction | 0.4 of span below the root | – | `AdvancedFin.cs:141-142` | comment at `:139` mentions "25 % of chord from leading edge" but no chordwise offset is coded |
| `lift_slope_factor` (1 + tau) | 1.05 | – | `Hydrodynamics.cs:31-32` | see 4.4 note |
| curve breakpoints | 8, 12, 16, 25 | deg | `Hydrodynamics.cs:38,43,50,57` | hard-coded, independent of `StallAngle` |
| `stall_bump_cl` | 0.15 | – | `Hydrodynamics.cs:47,53` | |
| post-stall fraction | 0.7 | – | `Hydrodynamics.cs:55,60` | legacy uses it inconsistently (see 4.4) |
| `deep_stall_cl` | 0.4 | – | `Hydrodynamics.cs:62,67` | |
| `min_cl` | 0.1 | – | `Hydrodynamics.cs:68` | |
| `StallAngle` (flag only) | 14 | deg | scene `:314`; wizard `:753`; `SailingState.cs:191` | `FinPhysics.cs:43`, `scene_config.json:104`, `PROGRESS_LOG.md:1019`: 25. Spec: flag at the 12° peak. |
| `cd_profile` | 0.008 | – | `Hydrodynamics.cs:82`; `FinPhysics.cs:135` | comment says NACA 0012 at Re ≈ 10⁶ is ≈ 0.006 |
| `oswald_e` | 0.85 | – | `Hydrodynamics.cs:85`; `FinPhysics.cs:134` | |
| viscous factor | 0.5 × cd_profile × |cl| | – | `Hydrodynamics.cs:89-90` | not in `FinPhysics` |
| `_minEffectiveSpeed` | 0.5 | m/s | `AdvancedFin.cs:31`; scene `:315` | `Hydrodynamics.cs:110` has its own 0.3 and `:125` 0.1; `FinPhysics.cs:29` 0.5 |
| `_fullEffectSpeed` | 2.0 | m/s | `AdvancedFin.cs:34`; scene `:316` | `FinPhysics.cs:32` and `scene_config.json:101`: 3.0 |
| `_trackingStrength` | **15** | N·m/deg | scene `:318`; wizard `:755` | C# default 40 (`AdvancedFin.cs:40`, raised from 15 in commit 4c45223 "Add high-speed stability damping"); `FinPhysics.cs:36`: 8; `scene_config.json:102`: 2. Build used 15. Spec: dropped. |
| tracking clamp | ±300 | N·m | `AdvancedFin.cs:184` | was ±100 before 4c45223; `FinPhysics.cs:172`: ±50 |
| tracking stall factor | 0.3 | – | `AdvancedFin.cs:179` | |
| `_enableTracking` | true | – | scene `:317`; wizard `:754`; `AdvancedFin.cs:37` | |
| force-apply threshold | |F|² < 0.01 → skip | N² | `AdvancedFin.cs:135-136` | harmless; spec drops it |
| Unity fixed time step | 0.02 | s | `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6` | nothing in the fin model depends on dt |
| board centre of mass (for the lever arms below) | (0, 0.15, −0.10) Unity → (0, 0.15, +0.10) D4 | m | scene `MainScene.unity:468`; `BoardMassConfiguration.cs:37` | shifts aft and down by up to (0, −0.10, +0.15) when planing (`BoardMassConfiguration.cs:222-228`); `Rigidbody.m_CenterOfMass` in the scene is (0,0,0) at `:217` but the script overrides it at runtime (`:194`). Belongs to the mass section. |

Default configuration for Phase 2 (`FinConfig.tres`): area 0.035 m², span 0.40 m, root at (0, −0.10, +0.90) in the body frame, centre of pressure 40 % of the span below the root, `cd_profile` 0.008, `oswald_e` 0.85, `lift_slope_factor` 1.05, breakpoints 8/12/16/25°, bump 0.15, post-stall fraction 0.7, deep-stall cl 0.4, min cl 0.1. Reason: these are the numbers of the last validated build and they are physically plausible for a 40 cm freeride fin (real fins: 0.03–0.04 m², AR 4–6). The 0.06 m² C# default was an untested tuning attempt.

### Where the force acts

Body frame, D4 (bow −Z, so "0.9 m aft" is +Z):

```
fin_root_body = Vector3(0.0, -0.10, 0.90)                   # legacy Position (0, -0.1, -0.9) with Z flipped
cop_body      = fin_root_body + Vector3(0.0, -0.4 * fin_span_m, 0.0)     # = (0, -0.26, 0.90); AdvancedFin.cs:141-142
```

The root sits 0.10 m below the board's origin (the geometric centre of the 2.5 × 0.6 × 0.12 m collider, `WindsurferSetup.cs:701`), so 4 cm below the hull bottom at −0.06 m: a small gap the legacy never noticed. Phase 2 may put the root at the hull bottom; the difference in lever arm is 4 cm. Section 14 does exactly that: the default root is (0, −0.06, +0.90). Both lift and drag are applied at `cop_body` (`AdvancedFin.cs:147-148`), as `add_force_at(basis * cop_body + position, force)`. Real fins have their centre of pressure at roughly 25 % chord and 40–45 % span; 40 % span is a fine choice, and the chordwise position is within a few centimetres of the root position anyway.

Torque = `r × F` with `r = cop_world − com_world`. For the legacy centre of mass (0, 0.15, +0.10): `r_body = (0, −0.41, +0.80)`. For the worked example (starboard tack, total fin force in the body frame `(368.3, 0, −5.4) N`):

- **Roll (about Z, the fore-aft axis):** `τ_z = r_x F_y − r_y F_x = −(−0.41)(368.3) = +151 N·m`. Positive rotation about +Z turns +X toward +Y: the starboard rail rises and the board heels to port, i.e. to leeward (negative `heel_rad` in the shared notation). This is real: the fin pushes to windward under the water while the sail pushes to leeward up in the air, and the pair rolls the board to leeward. The sailor's weight to windward has to hold it. Magnitude: `lift_n × 0.41 m`.
- **Yaw (about Y):** `τ_y = r_z F_x − r_x F_z = 0.80 · 368.3 = +295 N·m`. Positive about +Y turns the bow to port = to leeward on starboard tack = **bear away**. A fin behind the centre of mass pushing the tail to windward turns the bow away from the wind. Equivalently, when the board is slipping the fin turns the bow toward the velocity direction ("weathercocking"). This is the physical tracking effect that the tracking torque duplicated.
- **Pitch (about X):** `τ_x = r_y F_z − r_z F_y = (−0.41)(−5.4) = +2 N·m`, negligible.

Cross-section warning for the sail and rake sections: in the last Unity build the sail's centre of effort was moved to the board origin (Session 26, `Legacy/Documentation/PROGRESS_LOG.md:160-165`), 0.9 m ahead of the fin. The sail's leeward push ahead of the centre of mass *and* the fin's windward push behind it then both yaw the bow to leeward, a couple of roughly `0.9 m × side force` (≈ 330 N·m at the worked example) that the rake direct torque (200 to 350 N·m per unit rake, section 3) and the tracking torque had to fight. In a balanced rig the centre of effort sits above the centre of lateral resistance (fin plus hull), and rake moves it fore and aft to steer. Phase 2 must place the sail's CE and the fin so that their yaw moments nearly cancel at zero rake; see the sail and rake sections.

### Signs and the Unity-to-Godot translation

| Quantity | Unity (left-handed, bow +Z, starboard +X) | Godot D4 (right-handed, bow −Z, starboard +X) | Flips? |
|---|---|---|---|
| fin position | (0, −0.1, −0.9): −Z is aft | (0, −0.10, +0.90): +Z is aft | **Z sign flips** |
| slip angle sign | `Vector3.SignedAngle(forward, velocity, up)` (`Hydrodynamics.cs:136`): positive when the velocity is to the RIGHT of the bow, because Unity's `cross(forward, right) = +up` | `atan2(v_local.x, -v_local.z)`: positive when slipping to starboard. **Do not** use `forward.signed_angle_to(velocity, Vector3.UP)`: in Godot `Vector3.FORWARD.cross(Vector3.RIGHT) = (0, −1, 0)`, so it returns −90° for a velocity to starboard | **signed_angle_to flips; atan2 does not** |
| lift direction | `-finRight * sign(leeway)`: lift to the left when slipping right | `sign(slip) * (flow.z, 0, -flow.x)` in the body frame: lift to port when slipping to starboard (perpendicular to the flow, see 4.7) | same physical direction |
| drag direction | `-velocity.normalized` (3-D) | `-flow_dir` (in the fin plane) | same |
| yaw torque sign (tracking) | `AddTorque(+Y)` turns the bow to the right (clockwise seen from above) | positive torque about +Y turns the bow to **port** (counter-clockwise from above). A Godot tracking torque would need `-strength * slip`. The spec has no tracking torque | **flips** |
| roll from fin lift | `r × F` with the same physics | `r × F`; `+τ_z` heels to port | Godot's `cross()` is the same formula as Unity's; only the frame axes differ, so compute `r × F` in the Godot frame and do not copy the Unity sign |
| "stalled" flag | `abs(leeway) > StallAngle` | `abs(slip_deg) > stall_peak_deg` | none |
| rake and sheet | not used by the fin | not used by the fin | – |

Rule of thumb for Phase 2: get every fin direction from the body-frame components (`x` = starboard, `-z` = forward) and from `r × F` computed in Godot. Never copy a sign from the Unity code.

### Stabilisers and fudges in this model

| Item | What it is | Why it was added | What it probably hides | Recommendation |
|---|---|---|---|---|
| Tracking torque (`AdvancedFin.cs:155-187`, strength 15 in the scene, 40 default, clamp ±300, ×0.3 when stalled) | Extra yaw torque proportional to the slip angle in degrees, turning the bow toward the velocity | Session 6 (`PROGRESS_LOG.md:1005-1019`) in `FinPhysics` "so the board naturally wants to follow its velocity"; carried into `AdvancedFin` in Session 18 (`:655`); default raised 15→40 and clamp 100→300 in commit 4c45223 "Add high-speed stability damping" (Session 18/22 era, 27 Dec 2025) | The fin lift applied 0.8 m behind the centre of mass already gives this torque, five times stronger. The remaining need probably came from (a) the sail CE placed 0.9 m ahead of the fin, and (b) the missing angular-velocity term, so the model had no natural yaw damping | **Drop.** Feed `omega × r_fin` into the fin velocity instead (4.2). If Phase 4 shows yaw hunting, first check the CE/fin balance. |
| Speed fade-in 0.5→2.0 m/s (`AdvancedFin.cs:93-106,126-127`) | Forces multiplied by 0 below 0.5 m/s and ramped to 1 at 2 m/s | Sessions 6/18, "minimum speed for fin to generate significant lift" | Fin force already scales with speed², so at 1 m/s it is 1.6 % of the 8 m/s value. The fade mainly hid noisy slip angles when the velocity is tiny (SignedAngle of a near-zero vector) | **Drop**; keep only the 0.05 m/s numeric guard. |
| Internal thresholds 0.3 m/s and 0.1 m/s (`Hydrodynamics.cs:110,125`) | Early returns | Division-by-zero guards | nothing | Replace by the single 0.05 m/s guard. |
| Force-apply threshold |F|² < 0.01 (`AdvancedFin.cs:135`) | Skip applying forces under 0.1 N | micro-optimisation | nothing | Drop. |
| `StallAngle = 14°` not wired to the curve (`AdvancedFin.cs:123`, `Hydrodynamics.cs:38-69`) | A config value that only sets a flag | Oversight | The team could not tune the stall from the inspector | Fix: named breakpoints in `FinConfig`, flag from the peak. |
| Curve step at 16° (`Hydrodynamics.cs:60`) | Lift drops 19 % instantly | Bug | Possible jitter around 16° slip | Fix: continuous curve (4.4). |
| Lift along the chord normal (`Hydrodynamics.cs:151`) | Force perpendicular to the board's axis, not to the flow | Simplification | Double-counted the induced drag (25.7 N hidden drag at the worked example) and made the fin more than twice as draggy as its coefficients say | **Fix**: lift perpendicular to the flow (4.7). Expect higher speeds in Phase 4 from this alone. |
| `lift_slope_factor = 1.05` (`Hydrodynamics.cs:31-32`) | Multiplier on the lift slope | Comment says "τ accounts for non-elliptical loading" but the sign is the wrong way round | Small (6 %) | Keep as a named value; **re-evaluate** in Phase 4 together with the hull end-plate effect. |
| Viscous term `0.5 · cd_profile · |cl|` (`Hydrodynamics.cs:89-90`) | Ad-hoc drag increase with angle | Written with the model in Session 13 | Nothing; it is 7 % of the drag at 4° | Keep, named `cd_viscous_factor = 0.5`; re-evaluate if Phase 4 tunes the polar. |
| No water velocity, no angular velocity (`AdvancedFin.cs:89`) | Fin sees only the centre-of-mass velocity | No API for water velocity; angular term forgotten | No natural yaw damping (which the speed-dependent angular damping in `AdvancedHullDrag.cs:522-544` and the tracking torque then supplied); with waves the fin would ignore the orbital flow | Add both terms (4.2). Flat water gives `v_water = 0`. |
| Fin always in the water | Forces applied even when the tail is out of the water | Not considered | Nothing on flat water at the validated speeds; would be wrong when jumping | Phase 2: zero the fin force when the fin root is above the water surface. Immersed-span scaling: re-evaluate in Phase 5. |
| Ventilation / spin-out | Air sucked down the fin's low-pressure side at high slip, lift collapses suddenly | **Not modelled** in any legacy script | – | Do not model in Phase 2. The post-stall curve gives a soft version of spin-out (lift halves past 16°). Real spin-out (with hysteresis until the fin "bites" again) can be a Phase 4+ feature if the team wants it. |

### What Phase 2 must implement

- [ ] `FinConfig` resource with: `area_m2 = 0.035`, `span_m = 0.40`, `root_pos_body = (0, -0.10, 0.90)`, `cop_span_fraction = 0.4`, `cd_profile = 0.008`, `oswald_e = 0.85`, `lift_slope_factor = 1.05`, `stall_linear_end_deg = 8`, `stall_peak_deg = 12`, `stall_drop_end_deg = 16`, `deep_stall_deg = 25`, `stall_bump_cl = 0.15`, `post_stall_fraction = 0.7`, `deep_stall_cl = 0.4`, `min_cl = 0.1`, `cd_viscous_factor = 0.5`, `min_speed_ms = 0.05`. Each with a comment saying what it does.
- [ ] `aspect_ratio()` and `cop_body()` helpers on the config.
- [ ] Pure function `fin_lift_coefficient(slip_rad, aspect_ratio, config) -> float` (signed, continuous curve of 4.4).
- [ ] Pure function `fin_drag_coefficient(cl, aspect_ratio, config) -> float` (4.5).
- [ ] `FinModel.compute(v_boat, omega, basis, v_water_at_fin, config) -> FinResult` with `slip_rad`, `cl`, `cd`, `lift_force` (world), `drag_force` (world), `cop_body`, `is_stalled`, following 4.2, 4.3, 4.6, 4.7 and the 4.8 guard. No fade-in, no tracking torque.
- [ ] Velocity at the fin point includes `omega.cross(r_fin_world)`; relative velocity subtracts the `WaterSurface` velocity at the fin's world position (zero on flat water).
- [ ] Both forces applied at the centre of pressure with the integrator's `add_force_at(world_point, force)`, so roll and yaw moments arise from geometry.
- [ ] Zero fin force when the fin root is above the water surface.
- [ ] Telemetry: `fin_slip_deg`, `fin_lift_n`, `fin_drag_n`, `fin_stalled`.
- [ ] Nothing in the fin reads the sail, the controls or anything visual.

### Tests Phase 2 should write

Use `assert_almost_eq` with 1 % tolerances unless stated. Body frame, board level, flat water, `omega = 0`, `v_water = 0` unless stated.

- **Zero slip, zero side force.** `v_boat = (0, 0, −8)` world with identity basis: `slip_rad = 0`, `lift_force = 0`, `drag_force = (0, 0, +9.184)` N (profile drag only: 32 800 × 0.035 × 0.008).
- **Worked example.** `v_boat = 8 · (−0.06976, 0, −0.99756)` (slipping to port 4°): `slip_rad = −0.06981`, `cl = −0.3204`, `lift_n = 367.8`, `drag_n = 20.31`; lift vector `(+366.9, 0, −25.7)`, drag `(+1.4, 0, +20.3)`; the lift is perpendicular to the velocity (`lift_force.dot(v_boat) ≈ 0`) and points to starboard.
- **Mirror symmetry.** Slip +4° gives the same magnitudes with the lift to port (`lift_force.x < 0`), and `cl = +0.3204`.
- **Speed squared.** 4 m/s at 4° gives `lift_n = 91.96` (one quarter of 367.8).
- **Lift grows to the peak, then falls.** `fin_lift_coefficient` at 1, 4, 8, 12° = 0.0801, 0.3204, 0.6408, 0.7908; at 16° = 0.5536; at 25° = 0.4000; at 90° = 0.1. It is monotonic on 0–12° and never below 0.1 for |slip| ≥ 25°. The curve is continuous: `cl(16° − 1e-6) ≈ cl(16° + 1e-6)` (would fail with the legacy step).
- **Induced drag is quadratic.** `cd_induced(8°) / cd_induced(4°) = 4.00` (0.03364 / 0.00841); total `cd(4°) = 0.017692`, `cd(0°) = 0.008`.
- **The fin weathercocks the board.** With the centre of mass at (0, 0.15, +0.10) and the board slipping to port 4° at 8 m/s, the torque from the fin force about the centre of mass is `(≈ +2, +295, +151)` N·m in the body frame (`r = (0, −0.41, 0.80)`): +Y turns the bow toward the velocity direction (to port); +Z heels the board to port (leeward on starboard tack). Slipping to starboard flips the signs of the Y and Z components.
- **Yaw damping from the angular-velocity term.** Board moving straight at 5 m/s, `omega = (0, +0.5, 0)` (bow turning to port), fin centre of pressure at `r = (0, −0.41, 0.80)` from the centre of mass: the fin point moves to starboard at 0.40 m/s, so `slip_rad = atan2(0.40, 5.0) = +0.0798` (4.57°), the lift points to port and the resulting yaw torque is negative (opposes `omega`).
- **Guard.** `v_boat = (0.01, 0, −0.02)` gives zero forces and `slip_rad = 0`, no NaN; `v_boat = 0` likewise.
- **Out of the water.** Fin root 0.1 m above the water surface: zero forces.
- **Water velocity.** `v_boat = 0`, `v_water = (0, 0, +1)` (water flowing aft under a stationary board): the fin sees `v_rel = (0, 0, −1)`, zero slip, drag of `0.5 · 1025 · 1 · 0.035 · 0.008 = 0.1435 N` pointing aft (+Z), i.e. the current pushes the board along.
- **No tracking torque.** The fin model returns forces and an application point only; a test that sums the fin's contributions to the integrator checks that the total torque equals `r × (lift + drag)` and nothing more.
- **Determinism.** Same inputs twice give bit-identical outputs.

### Sources

Legacy code (read completely):
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs` — fields 27-44; `FixedUpdate` 73-82; `CalculateFinForces` 87-128; `ApplyForces` 133-149; `ApplyTrackingTorque` 155-187; `GetEfficiency` 193-202 (unused: no callers in `Assets/Scripts`); fin orientation comment 234-237.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Hydrodynamics.cs` — `CalculateFinLiftCoefficient` 23-72; `CalculateFinDragCoefficient` 78-93; `CalculateFinForces` 98-158.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs` — `FinConfiguration` 172-197.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs` — 12-18, 36-40.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/FinPhysics.cs` — whole file, 1-261 (not used by the played scene).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs` — 37, 194, 222-228 (centre of mass used for the lever arms).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs` — 291-302 (hull lateral drag, the other part of the lateral resistance) and 522-544 (speed-dependent angular damping that overlapped with the tracking torque).
- `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs` — 686-691 (rigidbody), 701 (collider), 744-756 (fin), 853, 1321-1322 (Quick-add path with `FinPhysics`).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` — 206-232 (Rigidbody), 308-320 (AdvancedFin values), 463-477 (BoardMassConfiguration values). Note: contrary to the assumption that the scene holds no component values, the fin block does hold them and they match the wizard.
- `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6` — fixed time step 0.02 s.
- Git history: ca7a7b1 (Session 13, 27 Dec 2025: `Hydrodynamics.cs` written with quadratic induced drag; `FinConfiguration` 0.035 / 0.40); 4c45223 (27 Dec 2025: `_trackingStrength` default 15→40, clamp ±100→±300, `FinConfiguration` defaults 0.06 / 0.45; scene values 0.035 / 0.40 / 15 first appear); 5a1857a (Session 22, scene rewritten, same fin values); c62f577 and e6756db (Session 25, 1 Jan 2026: `FinPhysics.cs` induced drag linear 0.01+0.02|cl| → 0.008+0.04|cl| → quadratic); b5ed2ea (Session 26) and 757d5cf (Session 27): fin untouched.

Legacy docs:
- `Legacy/Documentation/PHYSICS_DESIGN.md:450-459` (fin paragraph, formula only), `:562` (finArea 0.04).
- `Legacy/Documentation/KNOWN_ISSUES.md:96` (Session 25 quadratic induced drag, in `FinPhysics.cs`), `:106` (polar still to be verified).
- `Legacy/Documentation/PROGRESS_LOG.md:1003-1040` (Session 6, `FinPhysics` and tracking), `:602-672` (Session 18, `AdvancedFin`, tracking torque at 655), `:139-213` (Session 26, CE moved to origin at 160-165), `:215-275` (Session 24).
- `Legacy/Documentation/PHYSICS_VALIDATION.md:266, 377-380` (lists `AdvancedFin` as the fin in the validated stack; no numbers).
- `Legacy/Documentation/scene_config.json:94-106` (2025-12-27 `FinPhysics` values; history only).

Literature (as cited by the legacy code and used here to judge it):
- Abbott & von Doenhoff, *Theory of Wing Sections* (NACA 0012 section data: cd0 ≈ 0.006 at Re 10⁶, cl_max ≈ 1.2–1.5 in 2-D).
- Anderson, *Fundamentals of Aerodynamics*, lifting-line theory: `a = a0 / (1 + (a0 / (π AR))(1 + τ))`, induced drag `CDi = CL² / (π AR e)`.
- Marchaj, *Aero-Hydrodynamics of Sailing*; Larsson & Eliasson, *Principles of Yacht Design* (fin/keel side force, end-plate effect of the hull, lift perpendicular to the flow).

OPEN: whether any play-test ever used the Quick-add path with `FinPhysics` on the board (no evidence in the scene history; assumed not).
OPEN: where the sail section will put the centre of effort in Phase 2; the fin's yaw moment (≈ 0.8 m × side force) only makes sense once that is decided together.
OPEN: whether Phase 2's board origin is the geometric centre of the hull as in Unity (the fin position above assumes it).
OPEN: whether to apply the hull end-plate effect (effective aspect ratio up to 2 × geometric) in Phase 4; no measurement exists either way.
OPEN: no real-world fin data (lift slope, stall angle of a 40 cm freeride fin) is in the legacy repo; the curve is a NACA-0012-like guess and Phase 4 can only validate it indirectly through the polar.

---

## 5. Hull drag, displacement lift and Savitsky planing

This section covers everything the legacy `AdvancedHullDrag.cs` and `Hydrodynamics.cs` did to the board hull: how much the water slows the board down (resistance), and how much the moving water pushes the board up (hydrodynamic lift) before and during planing. Buoyancy (Archimedes) and water damping are section 6; the fin is section 4; mass and the centre of mass are section 7. Where those sections overlap with this one (the legacy hull file also applied vertical damping and angular damping), this section documents what the legacy did and says which section owns it in the rebuild.

**One warning before anything else.** The legacy docs (`PHYSICS_VALIDATION.md` section 11, `PHYSICS_DESIGN.md` section 3, `README.md`) say the last Unity build used the Savitsky planing equations. It did not. The Savitsky code existed only in the Session 24 commit (`fa79027`, 1 January 2026). The same day, the "WIP: Physics tuning" commit (`c62f577`) replaced it with a simple "lift = weight × planing ratio" model, with the code comment *"The Savitsky equations are too complex and produce insufficient lift"* (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs:443`). That simple model is what Sessions 25 and 26 played and "validated". Both versions are written out below, because the plan wants Savitsky (Phase 2 task list, "Savitsky planing lift depends on speed and trim") and Phase 2 needs to know what was actually tested.

### Purpose

A windsurf board behaves like two different boats:

- **Slow (displacement mode, under about 15 km/h):** the board sits in the water and pushes it aside. Resistance comes from skin friction over the wet surface, and from the waves the hull makes. Resistance grows quickly with speed and there is a "hump" just before planing.
- **Fast (planing mode, above about 20 km/h):** the board skims on top of the water. The water hitting the angled bottom of the board pushes it up (planing lift), so most of the hull leaves the water. Less wet surface means much less friction, and the resistance per unit of speed drops. This is why a planing windsurfer feels like it "lets go".

The game needs this model for three things: the top speed on each point of sail (resistance against sail drive), the feel of "getting on the plane" (the drop in resistance and the rise of the board), and stability at speed (the board must not sink at speed, fly out of the water, or bounce).

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `v_boat` | velocity of the board's centre of mass in the world frame | m/s |
| `v_water` | water velocity at the hull (0 on flat water; wave orbital velocity in Phase 5) | m/s |
| `v_rel = v_boat - v_water` | velocity of the hull through the water. The legacy used `v_boat` (Unity `linearVelocity`) directly | m/s |
| `speed_ms = v_rel.length()` | speed through the water. The legacy used the full 3D length, including the vertical component | m/s |
| `v_local = basis.inverse() * v_rel` | the same velocity in the body frame: `x` = toward starboard, `y` = up, `z` = toward the **tail** (Godot: bow is −Z) | m/s |
| `pitch_rad` | trim angle, positive = bow up. Compute from the basis, not from Euler angles: `pitch_rad = asin(clamp(-basis.z.y, -1, 1))` (the bow direction is `-basis.z`) | rad |
| `heel_rad` | heel, positive = heeled to starboard: `heel_rad = -asin(clamp(basis.x.y, -1, 1))`. This model only uses `abs(heel_rad)` | rad |
| `submersion_ratio` | submerged volume ÷ total board volume, from the buoyancy model (section 6), 0 to 1 | – |
| `is_floating` | at least one buoyancy sample point is under water (section 6) | bool |
| `length_m`, `width_m`, `thickness_m` | board length, width (beam) and thickness | m |
| `mass_total_kg` | board + rig + sailor | kg |
| `dt` | time step | s |
| **out** `planing_ratio` | 0 = displacement, 1 = fully planing (used by the sailor COM shift in section 7, by the HUD and by the effects) | – |
| **out** `is_planing` | `planing_ratio > 0.5` (legacy definition) | bool |
| **out** `froude_number` | display only in the legacy | – |
| **out** `resistance_force` (world) and its application point | the total hull resistance vector | N |
| **out** `displacement_lift_n`, `planing_lift_n` and the lift application point | vertical hydrodynamic lift | N |
| **out** `wetted_area_m2` | current wetted area, for the HUD/tests | m² |

Shared constants: `rho_water = 1025 kg/m³` (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:13`), `g = 9.81 m/s²` (`PhysicsConstants.cs:18`), kinematic viscosity of sea water `nu_water = 1.19e-6 m²/s` (`PhysicsConstants.cs:14`).

### Formulas

Everything below is written in D4 (Godot) conventions. "Legacy" means the last committed Unity code unless a session is named. Each formula has (a) what the legacy did, exactly, and (b) a **Spec decision** for Phase 2 where the legacy is doubtful.

#### F1. Gate: only when floating

The legacy did nothing at all (no resistance, no lift) when `is_floating` is false (`AdvancedHullDrag.cs:141-149`), and computed everything with the full 3D speed. Inside `CalculateHullResistance` a second gate returns zero resistance, zero planing ratio and `is_planing = false` when `speed_ms < 0.1` (`AdvancedHullDrag.cs:166-174`). `Hydrodynamics.CalculateHullResistance` has its own `speed < 0.1 → 0` (`Hydrodynamics.cs:171`).

Order of evaluation each physics tick (`AdvancedHullDrag.cs:151-155`): resistance → displacement lift → planing lift → apply resistance (and angular damping) → apply lift. The displacement lift and the planing lift read `planing_ratio` computed in the resistance step of the **same** tick.

**Spec decision:** keep the `is_floating` gate and the 0.1 m/s gate (they avoid dividing by zero speed). Use `v_rel`, not `v_boat`, so Phase 5 waves work without touching this model.

#### F2. Reference geometry (wetted area and waterline length at rest)

The legacy estimated the wet surface at rest from the box dimensions (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:236` and `:241`):

```
wetted_area_rest_m2   = length_m * width_m * 0.7 + 2.0 * (length_m + width_m) * 0.05
                      = 2.5 * 0.6 * 0.7 + 2 * 3.1 * 0.05 = 1.05 + 0.31 = 1.36 m²
waterline_length_m    = length_m * 0.8 = 2.0 m
```

Reasoning: about 70 % of the bottom plus a 5 cm strip of the rails is wet when the board floats level. The 0.7 and 0.05 have no source; they are guesses. Note that this wetted area does **not** change with `submersion_ratio`: a board that is 100 % under water has the same "wetted area" as one that is 30 % under. That is why the legacy needed the artificial submersion drag multipliers in F8.

**Spec decision:** keep these two numbers as the at-rest reference (they are only used to scale friction), and make the wetted area used for friction depend on submersion as described in F8's spec decision. Mark as tuning values in `BoardConfig`.

#### F3. Froude and Reynolds numbers

```
froude_number   = speed_ms / sqrt(g * waterline_length_m)                     (Hydrodynamics.cs:174)
reynolds_number = max(speed_ms * waterline_length_m / nu_water, 1e5)          (Hydrodynamics.cs:177-178)
```

The Froude number compares the boat speed with the speed of the waves it makes; wave-making resistance depends on it. The Reynolds number says how turbulent the boundary layer is; friction depends on it. The `1e5` floor keeps the ITTC formula valid at very low speed (`log10(1e5) − 2 = 3`). For the default board `Fn = 0.4` at 1.77 m/s and `Fn = 0.7` at 3.10 m/s. The legacy `froude_number` in `AdvancedHullDrag.cs:177` was only for display; the branch decision inside `Hydrodynamics.cs` recomputes it.

#### F4. Planing ratio (speed based, "not Froude")

Session 22 replaced a Froude-based transition with plain speed thresholds (`Legacy/Documentation/PROGRESS_LOG.md:382-391`, decision recorded at `:69`):

```
if speed_ms < planing_onset_speed_ms:            planing_ratio = 0            (AdvancedHullDrag.cs:181-185)
elif speed_ms < full_planing_speed_ms:
    planing_ratio = (speed_ms - planing_onset_speed_ms) / (full_planing_speed_ms - planing_onset_speed_ms)
                                                                                (AdvancedHullDrag.cs:186-190)
else:                                            planing_ratio = 1            (AdvancedHullDrag.cs:191-195)
is_planing = planing_ratio > 0.5     (in the middle branch; false below onset, true above full)
```

With `planing_onset_speed_ms = 4.0` and `full_planing_speed_ms = 6.0` (`AdvancedHullDrag.cs:31,34`), `planing_ratio` ramps linearly from 14.4 km/h to 21.6 km/h and `is_planing` flips at exactly 5.0 m/s (18 km/h). The tooltip at `:30` says "17 km/h = 4.7 m/s is typical" but the value is 4.0; `PROGRESS_LOG.md:391` claims the 4.0/6.0 pair "matches real-world windsurfing where planing starts around 17 km/h", which is not what the numbers say (4.0 m/s = 14.4 km/h). Reasoning for a speed-based ratio: it is simple, deterministic and does not depend on how deep the board sits, which is exactly the "trampoline" hard rule (F12).

**Spec decision:** keep the linear ramp on speed. Keep 4.0 and 6.0 m/s as defaults and let Phase 4 tune them to the plan's target (planing starts between 15 and 17 km/h, i.e. onset 4.2 to 4.7 m/s). Use `speed_ms` of `v_rel`.

#### F5. Wetted area while planing

```
wetted_area_m2 = lerp(wetted_area_rest_m2, wetted_area_rest_m2 * planing_wetted_area_ratio, planing_ratio)
                                                                                (AdvancedHullDrag.cs:198-200)
```

With `planing_wetted_area_ratio = 0.20` (`AdvancedHullDrag.cs:37`) the wetted area goes from 1.36 m² to 0.272 m². Reasoning: when planing only the tail touches. **Watch out:** F7 reduces this area a *second* time by 85 %, so the friction area at full planing is 1.36 × 0.20 × 0.15 = 0.041 m², which is the size of a sheet of A3 paper. That is not physical; a planing windsurfer still has roughly 0.4 to 0.6 m² of wet bottom (Savitsky: `lambda × beam²` ≈ 1.5 × 0.36 = 0.54 m²).

**Spec decision:** apply the reduction once: `wetted_area_m2 = lerp(wetted_area_rest_m2, lambda_planing * width_m^2, planing_ratio)` with `lambda_planing = 1.5` (the same wetted-length ratio the Savitsky lift uses in F11). For the default board that is 1.36 → 0.54 m². Drop `planing_wetted_area_ratio` and the 0.85 factor.

#### F6. Friction drag (ITTC 1957)

```
q_pa   = 0.5 * rho_water * speed_ms^2                                            (Hydrodynamics.cs:184)
cf     = 0.075 / (log10(reynolds_number) - 2.0)^2                                 (Hydrodynamics.cs:181)
r_friction_n = cf * q_pa * wetted_area_m2                                         (Hydrodynamics.cs:185)
```

`q_pa` is the dynamic pressure (the pressure the water would exert if brought to a stop). The ITTC 1957 line is the standard ship-model friction correlation (ITTC 1957, "Proceedings of the 8th ITTC"; also Larsson & Eliasson, *Principles of Yacht Design*, ch. 5). For the default board `cf` is 0.0037 at 2 m/s and 0.0029 at 8 m/s.

**Spec decision:** keep as is. This is real physics with a real source.

#### F7. Residuary drag, planing-branch reduction, spray drag and the hump blend

`Hydrodynamics.CalculateHullResistance(speed, displacement, wettedArea, waterlineLength, isPlaning)` (`Hydrodynamics.cs:164-222`). The `displacement` argument (the legacy passed `TotalMass`, `AdvancedHullDrag.cs:205`) is never used inside the function.

**Displacement branch** (`not is_planing or froude_number < 0.4`, `Hydrodynamics.cs:189-198`):

```
cr           = 0.001 * froude_number^4 * (1.0 + 5.0 * froude_number)             (Hydrodynamics.cs:194)
r_residuary_n = cr * q_pa * wetted_area_m2                                        (Hydrodynamics.cs:195)
r_hull_n     = r_friction_n + r_residuary_n                                       (Hydrodynamics.cs:197)
```

The comment says "Approximation based on Delft series". It is not: the Delft Systematic Yacht Hull Series (Keuning & Sonnenberg 1998, as tabulated in Larsson & Eliasson) is a polynomial in `Fn` for `Fn ≤ 0.6`, scaled by displacement volume, not by wetted area, and it does not go as `Fn^4 (1 + 5 Fn)`. This curve is an invention that rises without limit: `cr` is 0.0001 at 2 m/s, 0.0037 at 4 m/s (equal to `cf`) and 0.0108 at 5 m/s (3.5 × `cf`). There is also no separate **form drag** term anywhere in the legacy; the comment at `Hydrodynamics.cs:192` folds it into the residuary term.

**Planing branch** (`is_planing and froude_number ≥ 0.4`, `Hydrodynamics.cs:199-219`):

```
planing_factor      = clamp((froude_number - 0.4) / 0.3, 0, 1)                    (Hydrodynamics.cs:203)
reduced_wetted_m2   = wetted_area_m2 * (1.0 - 0.85 * planing_factor)              (Hydrodynamics.cs:207)
r_planing_friction  = cf * q_pa * reduced_wetted_m2                               (Hydrodynamics.cs:208)
spray_coefficient   = 0.01 * planing_factor                                       (Hydrodynamics.cs:213)
r_spray_n           = spray_coefficient * q_pa * reduced_wetted_m2                (Hydrodynamics.cs:214)
r_hump_n            = r_friction_n * 1.5                                          (Hydrodynamics.cs:217)
r_hull_n            = lerp(r_hump_n, r_planing_friction + r_spray_n, planing_factor)   (Hydrodynamics.cs:218)
```

Spray drag is the energy lost throwing water sideways off the planing surface; it really does grow with speed, which is the Session 25 fix (commit `e6756db`; `Legacy/Documentation/KNOWN_ISSUES.md:98`). Before that fix the spray term was `0.0005 * q * wettedArea * (1 - planingFactor)` (commit `c62f577`) and before Session 25's WIP commit it was `0.002 * q * wettedArea * (1 - planingFactor)` (Session 22, commit `5a1857a`), both *decreasing* with planing. The 0.01 coefficient is described as "realistic for high-speed planing" without a source; Savitsky's own spray-drag estimate is a function of trim, deadrise and `lambda` and is usually 10 to 20 % of the total planing drag, so 0.01 × q × wetted area is of the right order.

**Three defects in this branch:**

1. **The blend never blends.** `planing_factor` reaches 1 at `Fn = 0.7`, i.e. at 3.1 m/s, but `is_planing` only becomes true at 5.0 m/s (F4). So whenever the planing branch runs, `planing_factor` is already 1, the `r_hump_n` term (×1.5) is multiplied by zero, and the "transition hump" never exists.
2. **A cliff at 5.0 m/s.** At 4.99 m/s the displacement branch gives 144 N; at 5.01 m/s the planing branch gives 20 N (computed with the legacy values, wetted area already reduced to 0.816 m² by F5). Resistance drops by a factor of 7 in one time step. In play this is the moment the board "lets go", which the team may have liked, but it is a discontinuity, not physics.
3. **Planing resistance is far too low.** At 8 m/s the whole hull resistance is 17 N (see the worked example). A real planing hull carrying 930 N at a 4° trim has a pressure drag of `lift × tan(trim)` ≈ 46 to 65 N on its own, plus friction on ~0.5 m² ≈ 58 N, so 100 to 130 N is a realistic hull resistance. The legacy's missing 100 N was presumably absorbed by other tuning (fin induced drag, sail coefficients), which is why every section of this spec must be re-tuned together in Phase 4.

**Spec decision for the total resistance (Phase 2):** one continuous formula, blended by the speed-based `planing_ratio` from F4 instead of `is_planing`:

```
r_friction_n  = cf * q_pa * wetted_area_m2                       # F6, area from F5's spec decision
r_residuary_n = cr(froude_number) * q_pa * wetted_area_rest_m2 * (1.0 - planing_ratio)
r_pressure_n  = planing_lift_n * tan(tau_rad)                    # Savitsky pressure drag, see F11
r_spray_n     = 0.01 * planing_ratio * q_pa * (lambda_planing * width_m^2)
r_hull_n      = r_friction_n + r_residuary_n + r_pressure_n + r_spray_n
```

The pressure drag is the physically important new term: the planing lift is perpendicular to the board bottom, so it leans back by the trim angle and part of it is drag (Savitsky 1964, "Hydrodynamic Design of Planing Hulls", *Marine Technology* 1(4): D = Δ tan τ + D_f / cos τ). It couples drag to lift and to trim, which the legacy never had. Keep `cr = 0.001 Fn^4 (1 + 5 Fn)` as the default residuary curve for now (OPEN: replace with a sourced curve, see Open questions), but fade it out with `planing_ratio` so it cannot explode above 6 m/s. With these formulas the default board gives roughly 27 N at 3 m/s, 77 N at 4 m/s, ~130 N at 5 m/s (the hump), ~65 N at 6 m/s and ~120 N at 8 m/s: a hump and a drop, but no cliff.

Direction: `resistance_force = -v_rel.normalized() * r_hull_n` (`AdvancedHullDrag.cs:274`). This is the same in Unity and Godot.

#### F8. Submersion penalties on the resistance (legacy) and the spec's replacement

All of these multiply `r_hull_n` and run only when an `AdvancedBuoyancy` exists (`AdvancedHullDrag.cs:214`). `normal_submersion = 0.35` (`:220`).

**(a) The "12×" submersion drag multiplier** (Session 22 as 3×, Session 24 raised to 12×; `PROGRESS_LOG.md:257`):

```
if submersion_ratio > 0.35:
    excess = (submersion_ratio - 0.35) / (1.0 - 0.35)                                (AdvancedHullDrag.cs:225)
    r_hull_n *= 1.0 + excess^2 * submersion_drag_multiplier      # multiplier = 12    (AdvancedHullDrag.cs:227-228)
```

Factor 1.07 at 40 % submersion, 1.64 at 50 %, 2.78 at 60 %, 5.5 at 75 %, 13 at 100 %.

**(b) The underwater "×5" drag** (Session 23; `KNOWN_ISSUES.md:125`):

```
if submersion_ratio > 0.5 and speed_ms > 4.0:                                        (AdvancedHullDrag.cs:232)
    underwater_bonus = (submersion_ratio - 0.5) * 2.0          # 0 at 50 %, 1 at 100 %   (:236)
    speed_factor     = clamp((speed_ms - 4.0) / 4.0, 0, 1)      # 0 at 4 m/s, 1 at 8 m/s  (:237-238)
    r_hull_n *= 1.0 + underwater_bonus * speed_factor * 5.0                                (:241-242)
```

Combined with (a): at 60 % submersion and 8 m/s the resistance is multiplied by 2.78 × 2.0 = 5.5; at 100 % by 13 × 6 = 78.

**(c) Ride-high reduction** (only when `is_planing`):

```
if is_planing and submersion_ratio < 0.35:
    r_hull_n *= max(0.5, 1.0 - (0.35 - submersion_ratio) * 0.5)                      (AdvancedHullDrag.cs:247-251)
```

Factor 0.925 at 20 % submersion, 0.825 at 0 %. The `max(0.5, …)` can never bind (the minimum of the expression is 0.825).

Why they exist: the wetted area in F2 does not know how deep the board is, so a board pushed under water at speed had almost no extra drag and kept "sailing as a submarine" (issue 3, `KNOWN_ISSUES.md:108-133`). The multipliers are a stand-in for the wetted area and frontal area the model does not compute.

**Spec decision:** drop (a), (b) and (c) and compute the thing they stand in for:

```
# friction area grows with submersion: the reference area (F2/F5) is what a board at its
# normal 35 % submersion shows; a fully submerged board is wet all over (top and bottom).
area_full_wet_m2 = 2.0 * length_m * width_m + 2.0 * (length_m + width_m) * thickness_m   # 3.74 m² default
wetted_area_m2   = lerp(wetted_area_m2_from_F5, area_full_wet_m2, clamp((submersion_ratio - 0.35) / 0.65, 0, 1))
# form drag on the frontal area once the deck goes under (blunt body, Cd ≈ 0.8)
frontal_area_m2  = width_m * thickness_m * clamp((submersion_ratio - 0.5) / 0.5, 0, 1)
r_form_n         = 0.8 * q_pa * frontal_area_m2
```

At 8 m/s fully submerged this gives friction 0.0029 × 32 800 × 3.74 = 356 N plus form drag 0.8 × 32 800 × 0.072 = 1 890 N, which stops a submerged board just as firmly as the ×78 but for a physical reason. The Phase 4 "recovers from a nose-dive" test decides whether this is enough; if it is not, add a documented multiplier back then. Drag is *allowed* to depend on submersion (it is negative feedback: deeper → slower); only lift is not (F12).

#### F9. Submersion vertical damping (legacy, belongs to section 7)

Inside the resistance function, the legacy also pushed against vertical motion (`AdvancedHullDrag.cs:253-270`):

```
if abs(v_rel.y) > 0.02 and submersion_ratio > 0.1:
    f_damp_n = -v_rel.y * submersion_vertical_damping * submersion_ratio       # 600 N·s/m   (:261)
    if planing_ratio > 0.2 and submersion_ratio > 0.4: f_damp_n *= 2.0                       (:264-267)
    apply world-up force f_damp_n at the centre of mass                                     (:269)
```

The comment at `AdvancedHullDrag.cs:492-493` says "Vertical damping is handled by AdvancedBuoyancy, not here. This prevents duplicate damping forces", but this block *is* a duplicate: `AdvancedBuoyancy.ApplyDamping` applies `-v_y * _verticalDamping * submersion` as well (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs:326-337`, with `_verticalDamping` = 8000 in code at `:59`, 800 in the scene file `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:254`). 600 N·s/m on top of 800 or 8000 is small.

**Spec decision:** drop from this model. Vertical (heave) damping is defined once, in section 6.

#### F10. Directional drag: lateral and vertical (`ApplyDirectionalDrag`, `AdvancedHullDrag.cs:283-316`)

```
q_lin = 0.5 * rho_water * speed_ms                                # NOTE: speed, not speed²   (:288)
# lateral
if abs(v_local.x) > 0.1:
    lateral_area_m2 = length_m * thickness_m                      # 0.30 m²                    (:297)
    f_lat_n = 1.0 * q_lin * abs(v_local.x) * lateral_area_m2      # Cd = 1.0 "flat plate"      (:296,298)
    resistance_force += (-basis.x * sign(v_local.x) * f_lat_n) * (1.0 - 0.5 * planing_ratio)  (:301-302)
# vertical
if abs(v_local.y) > 0.1:
    vertical_area_m2 = length_m * width_m * 0.5                   # 0.75 m²                    (:310)
    f_vert_n = 1.2 * q_lin * abs(v_local.y) * vertical_area_m2    # Cd = 1.2                   (:309,311)
    resistance_force += -Vector3.UP * sign(v_local.y) * f_vert_n                              (:313-314)
```

Note the form: `0.5 ρ × speed × |v_x| × A`, i.e. the drag is proportional to the *total* speed times the sideways speed, not to the sideways speed squared. At 8 m/s with 0.5 m/s of leeway the legacy lateral drag is 615 N × (1 − 0.5) = 308 N; the proper quadratic form `0.5 ρ Cd A v_x²` gives 38 N. So the legacy hull resisted leeway 8 to 16 times harder than a flat plate would, which hides part of the fin's job (section 4) and makes the fin's tuning wrong. The vertical term is the same mixed form (1107 N for 0.3 m/s of heave at 8 m/s) and is a second heave damper on top of F9 and section 7. Neither block has a source. The vertical drag uses *body* `v_local.y` for the magnitude but pushes along *world* up (`:313`).

**Spec decision:** lateral drag stays in this model in the proper quadratic form, `f_lat_n = 0.5 * rho_water * 1.0 * lateral_area_m2 * v_local.x * abs(v_local.x)` with `lateral_area_m2 = length_m * thickness_m * (1.0 - 0.5 * planing_ratio)`, applied along `-basis.x`. Vertical drag moves to section 6 (heave damping), defined once. The 0.1 m/s dead-bands go away (they are not needed with a quadratic term).

#### F11. Hydrodynamic lift 1: displacement lift (legacy) and why the spec drops it

Session 22 added "displacement lift" because "Board sinks 75%+ at displacement speeds" (`KNOWN_ISSUES.md:190`; `PHYSICS_DESIGN.md:163-168`). Current code (`AdvancedHullDrag.cs:327-357`):

```
if not displacement_lift_enabled: return 0                                   (:331)
if speed_ms < 0.5: return 0                                                  (:335, value :54)
if submersion_ratio < 0.05: return 0                                         (:339)
planform_area_m2      = length_m * width_m * 0.8                              # 1.2 m²   (:345)
displacement_lift_n   = 0.12 * q_pa * planform_area_m2                        # CL 0.12  (:349, value :51)
displacement_lift_n   = min(displacement_lift_n, mass_total_kg * g * 0.3)     # 30 % cap (:352-353)
displacement_lift_n  *= (1.0 - planing_ratio)                                 # fade     (:356)
```

The Session 22 version scaled the lift with `submersion_ratio` twice (`liftCoeff = 0.12 × submersion` and `wettedArea = L × W × submersion`, commit `5a1857a` lines 295-302) with a 50 % cap (line 306); Session 24 removed the submersion scaling (trampoline, F12) and set the cap to 30 %.

What it actually does with the default numbers: the uncapped lift passes the 30 % cap (268 N) at only 1.9 m/s, so from 1.9 m/s to 4.0 m/s the "displacement lift" is a **constant 30 % of the weight**, then it fades linearly to zero at 6 m/s. It is not a lift curve; it is a step that lifts the board 30 % out of the water as soon as it moves.

**Re-evaluation against pitfall 8.** At rest a 120 L board carrying 91 kg (94 kg with the mass configuration, F16) displaces 91 / 1025 = 0.0888 m³ = 88.8 L, which is 74 % of its volume (77 % for 95 kg). That is Archimedes; the Session 22 "75 %+ submerged" symptom was the correct answer. Real boards do sit that deep at rest (a 120 L board is the smallest a 75 kg sailor can uphaul), and real hulls do generate some dynamic lift below planing speed, but nowhere near 30 % of the weight at 2 m/s (7 km/h): at 2 m/s the dynamic pressure is 2 kPa, and a lift coefficient of 0.12 on 1.2 m² would need the whole bottom to act like a wing at a positive angle. Larsson & Eliasson treat hulls below `Fn ≈ 0.5` as pure displacement bodies (no net lift).

**Spec decision: drop the displacement lift.** Start Phase 2 without it (`displacement_lift_enabled = false`, no formula). If the team finds low-speed sailing too "heavy", the physical fix is a bigger board (more litres in `BoardConfig`), not a fake lift. Keep the legacy formula above only as a record. The Phase 4 half-wind test (pitfall 6, "beam-reach submersion at low speed was never solved") will show whether the honest model needs anything here.

#### F12. HARD RULE: planing lift must not depend on how deep the board sits

Session 23 made the planing lift proportional to `submersion_ratio × 2` (`PROGRESS_LOG.md:223-227`, `KNOWN_ISSUES.md:186`). The board then bounced between 0 % and 100 % submersion at planing speed (the "trampoline"): deeper → more lift → board jumps out → no lift → falls back in. It is a positive feedback loop with the 50 Hz step and almost no heave damping.

**Rule for Phase 2 (plan pitfall 4):** the planing lift is a function of `speed_ms`, trim and heel only. `submersion_ratio` may only be used as an on/off gate ("is the board touching the water?") and never as a multiplier. The wetted length ratio `lambda` in the Savitsky formula is taken from `planing_ratio` (speed), not from the submerged depth. Ride height is then set by buoyancy (section 6) filling in whatever the planing lift does not carry. Phase 2 must write the test "lift at 8 m/s and 4° trim is identical at 10 %, 30 % and 45 % submersion".

For honesty: in real planing theory the wetted length *does* shrink as the hull rises, which is the physical heave spring of a planing boat. We deliberately leave that out because the legacy showed it needs proper heave damping to be stable, and section 7 is not tuned yet. Phase 4 may revisit it, with a test, once damping is right.

#### F13. Hydrodynamic lift 2, version A: Savitsky planing lift (Session 24 commit `fa79027`, lines 348-427 of that file version)

The Savitsky (1964) lift coefficient for a flat or low-deadrise planing surface:

```
tau_deg      = clamp(rad_to_deg(pitch_rad), 1.0, 10.0)             # trim in DEGREES (empirical fit)  (fa79027:381)
cv           = speed_ms / sqrt(g * width_m)                          # speed coefficient               (fa79027:388)
lambda_max   = length_m / width_m                                    # 4.17 for the default board     (fa79027:393)
lambda       = clamp(lerp(lambda_max, 1.5, planing_ratio), 1.0, 4.0) # wetted length / beam           (fa79027:394-395)
dynamic_term     = 0.012 * sqrt(lambda)                                                                 (fa79027:399)
hydrostatic_term = 0.0055 * lambda^2.5 / cv^2      if cv > 0.5 else 0.0                                 (fa79027:400)
cl0          = tau_deg^1.1 * (dynamic_term + hydrostatic_term)                                          (fa79027:402)
cl           = max(cl0 - 0.0065 * beta_deg * max(cl0, 0.01)^0.6, 0.0)    # deadrise beta = 3°            (fa79027:405-407)
lift_raw_n   = cl * q_pa * width_m^2                                     # reference area = beam²        (fa79027:411-414)
target_n     = lift_raw_n * planing_lift_coefficient * planing_ratio     # 0.8 in that version           (fa79027:414-417)
target_n     = min(target_n, mass_total_kg * g * max_lift_fraction)      # 0.85 in that version          (fa79027:420-421)
planing_lift_n = lerp(planing_lift_n_prev, target_n, lift_smoothing_factor)   # 0.08 per 50 Hz tick     (fa79027:425)
```

Physics in one sentence each: the `dynamic_term` is the lift a flat plate gets from deflecting the oncoming water downwards (grows with trim and with wetted length); the `hydrostatic_term` is the buoyant part of the pressure on the wetted bottom, which matters at low speed coefficients and vanishes at high `cv`; the deadrise correction removes lift for a V-shaped bottom (a windsurf board is almost flat, hence 3°). Source: Savitsky, D. (1964), "Hydrodynamic Design of Planing Hulls", *Marine Technology* 1(4), 71–95, equations for `C_L0` and `C_Lβ`; the same equations are in Larsson & Eliasson ch. 5 and in Faltinsen, *Hydrodynamics of High-Speed Marine Vehicles* (2005) ch. 9. Note the fit is for `2 ≤ tau_deg ≤ 15`, `0.6 ≤ cv ≤ 13` and `lambda ≤ 4`, so the clamps are inside the validity range.

Numbers for the default board (0.6 m beam, 91 kg) at 4° trim: 307 N at 5 m/s (`planing_ratio` 0.5), 397 N at 6 m/s (44 % of the weight), 660 N at 8 m/s (74 %), and the 0.85 cap (759 N) from about 9.3 m/s up. At 8 m/s the trim sensitivity is 137 N at 1°, 660 N at 4° and 2 300 N (capped) at 10°. So the formula does **not** "produce insufficient lift" in itself; it produces insufficient lift when the trim stays near the 1° clamp, which is what happens when nothing in the model trims the bow up (the legacy applied the lift at the centre of mass, F15, and the sail's centre of effort was set to zero, so trim was left to buoyancy).

#### F14. Hydrodynamic lift 2, version B: the simple target model (commit `c62f577` onward; the last played build)

Current code (`AdvancedHullDrag.cs:372-474`), after the gates in F15:

```
heel_abs_rad         = abs(heel_rad)                                                   (:420-422, Unity eulerAngles.z)
trim_deg             = rad_to_deg(pitch_rad); tau_deg = clamp(trim_deg, 1, 10)         (:426-431)  # computed, then UNUSED
effective_beam_factor = cos(heel_abs_rad)                                              (:436-440)
weight_n             = mass_total_kg * g                                               (:447-448)  # 91 kg → 892.7 N
target_n             = weight_n * max_lift_fraction * planing_ratio                    (:452-456)  # max_lift_fraction = 1.0
target_n            *= max(effective_beam_factor, 0.7)                                 (:460)
target_n            *= planing_lift_coefficient                                        (:463)      # 1.0
target_n             = min(target_n, weight_n * max_lift_fraction)                     (:467-468)
planing_lift_n       = lerp(planing_lift_n_prev, target_n, lift_smoothing_factor)      (:472-473)  # 0.08
```

This is not a hydrodynamic formula: the lift does not depend on speed² or trim at all, only on `planing_ratio` (a straight line from 0 at 4 m/s to 100 % of the weight at 6 m/s and above) and on heel. With `max_lift_fraction = 1.0` (C# default `:64` and scene file `MainScene.unity:290`), at full planing the lift equals the entire weight, so buoyancy goes to zero and the board rises until `submersion_ratio < 0.05`, where the gate in F15 decays the lift by 10 % per tick until the board falls back in. That is a slower, gated version of the trampoline, held in check by the smoothing and by the heavy vertical damping (section 7). `_optimalTrimAngle` (`:67`) is unused since this version.

**Spec decision:** do not implement version B. Implement version A (F13) with the changes in F15 and the Phase 2 checklist.

#### F15. Gates, decays, cap, smoothing and application point (both versions)

Gates, in order (`AdvancedHullDrag.cs:377-412`):

```
if not planing_lift_enabled or planing_ratio < 0.1:   planing_lift_n = 0; return              (:377-382)
if speed_ms < 3.0:            planing_lift_n = prev * 0.95; return   # decay, τ ≈ 0.39 s      (:385-390)
if submersion_ratio < 0.05:   planing_lift_n = prev * 0.90; return   # "barely in water", τ ≈ 0.19 s   (:393-399)
if submersion_ratio > 0.50:   planing_lift_n = prev * 0.80; return   # "can't plane underwater", τ ≈ 0.09 s (:405-412, value :73)
```

(The time constants assume Unity's 0.02 s fixed step, `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6`; a per-tick factor is frame-rate dependent.) The `speed < 3.0` branch is unreachable in practice because `planing_ratio < 0.1` already returns below 4.2 m/s. The Session 22 version also killed the lift when `abs(trim) > 15°` (commit `5a1857a` lines 342-346); that is gone.

**The progressive 35 to 50 % penalty never existed in code.** `KNOWN_ISSUES.md:124` and `PHYSICS_DESIGN.md:617-621` describe "Planing lift reduces progressively from 35% to 50% submersion" with `submersionPenalty = 1 − ((s − 0.35)/0.15) × 0.8`. No committed version of `AdvancedHullDrag.cs` contains it (`git log -S submersionPenalty` finds only the documentation commit), and the code says the opposite at `AdvancedHullDrag.cs:414-416`: "We do NOT penalize lift based on submersion during normal planing". Phase 2 must not implement it (it would break F12 anyway).

Cap: `min(target, weight × max_lift_fraction)`, 0.4 (Session 22) → 0.85 (Session 24, "prevents flying out at 45+ km/h", `PROGRESS_LOG.md:255`, `KNOWN_ISSUES.md:181`) → 1.0 (Session 25 WIP, scene). Smoothing: `lerp(prev, target, 0.08)` per tick, `:472`, time constant 0.24 s at 50 Hz.

Application (`ApplyHydrodynamicLift`, `AdvancedHullDrag.cs:483-508`): return if `submersion_ratio < 0.05` (`:486-490`) or `displacement_lift_n + planing_lift_n < 1 N` (`:496`); apply `Vector3.UP * total_lift` (world up, `:505`) at the body-frame point `(0, 0, 0)` (`:500-502`, Session 26). History of that point: Session 22 and 24 used `liftPointZ = +length × (0.5 − 0.25 × planing_ratio)` = +1.25 m to +0.625 m, which in Unity is **forward** of the origin (the comment "further aft (tail rides on water)" at `fa79027:452` was wrong about Unity's +Z), i.e. a bow-up moment of 400 to 800 N·m at planing speed. The Session 25 WIP commit `c62f577` negated it (now really aft), and Session 26 set it to zero "to prevent pitching moments (porpoising)" with the comment "Previously applied aft which caused nose-up moment" (`AdvancedHullDrag.cs:498-499`), which is backwards: a lift aft of the centre of mass gives a bow-*down* moment. The porpoising the team saw in Session 24 is best explained by the forward application point, not by "Savitsky".

**Spec decision for Phase 2:**

- Gates: keep `planing_ratio < 0.1 → 0` and the touching-water gate `submersion_ratio < 0.02 → 0` (a gate, allowed by F12). Drop the `> 0.5` gate and its decays to start with; F8's physical submerged drag should make the board slow down instead. If the Phase 4 nose-dive test fails, add it back as a smooth fade documented in this section.
- Cap: `planing_lift_n ≤ mass_total_kg * g` (fraction 1.0). This is not a fudge: a planing surface at steady state carries at most the weight on it; any more would lift the hull until the wetted length shrinks (F12 says we do not model that shrink, so the cap stands in for it). Do not add a separate `planing_lift_coefficient`; tune trim and `lambda` instead.
- Smoothing: replace the per-tick lerp with a time-based first-order filter, `lift += (target − lift) * (1.0 − exp(−dt / 0.2))`, or none at all if the Phase 2 heave test is stable without it. Never a per-tick constant.
- Heel: put the heel into the Savitsky beam, `beam_eff = width_m * cos(heel_rad)` (so lift ∝ cos²), and drop the `max(…, 0.7)` floor.
- Trim: `tau_deg = clamp(rad_to_deg(pitch_rad) + planing_trim_offset_deg, 1.0, 10.0)` with `planing_trim_offset_deg = 0` by default. OPEN: whether a built-in offset (the tail rocker of 0.02 m over the rear metre is about 1°) is needed for the board to get onto the plane; Phase 4 decides, see Open questions.
- Application point: default `(0, 0, 0)` in the body frame like the last build, with `planing_lift_point_z_m` in `BoardConfig` so Phase 4 can move it to the physical centre of pressure (see "Where the force acts").

#### F16. Assembly: total force, torque and the legacy angular damping

Per tick the legacy applied (`AdvancedHullDrag.cs:513-546` and `:483-508`):

1. `resistance_force` (F7 + F8 + F10) at body point `(0, 0, +0.1 × length_m)` in Godot (aft; the Unity code used `(0, 0, −0.1 L)`, `:518`), skipped when `|resistance_force|² < 0.01` (`:515`).
2. Total lift `displacement_lift_n + planing_lift_n` along world up at `(0, 0, 0)`.
3. An **angular damping torque** (`:522-545`), added in Session 18 (commit `4c45223`, "Add high-speed stability damping"):

```
speed_kn   = speed_ms * 1.94384
base_coeff = 0.8 if is_planing else 1.5                                                    (:530)
high_speed = 1.0 if speed_kn <= 15 else min(1.0 + (speed_kn - 15.0) / 5.0, 5.0)          (:535-540)
torque     = -angular_velocity * base_coeff * high_speed * mass_total_kg * 0.1              (:543)   # N·m per rad/s
```

That is 7.3 N·m·s/rad while planing below 15 kn, 14.6 at 20 kn, 29 at 30 kn, 36 (the ×5 cap) from 35 kn (with 91 kg). `PHYSICS_VALIDATION.md:203-211` describes it as `Lerp(1, 5, (kn − 15)/15)`, which is a different ramp (×5 at 30 kn); the code reaches ×5 at 35 kn. On top of this the Unity Rigidbody itself had `angularDamping = 0.3` (`WindsurferSetup.cs:691`, `MainScene.unity:216`), a hidden engine damping our own integrator will not have, and `AdvancedBuoyancy` applied a third rotational damping (`AdvancedBuoyancy.cs:362-384`).

**Spec decision:** the angular damping does not belong to the hull-drag model. Section 6 defines one rotational damping model; this section contributes nothing rotational except the torques that the forces above produce through their application points. The plan lists the "speed-dependent angular damping (up to ×5)" as a fudge to start without.

### Values

Board and mass values (`HullConfiguration`, `SailingState.cs:203-242`; set by `WindsurferSetup.cs:764-770`; saved in `MainScene.unity:272-279`):

| Name | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `length_m` | 2.5 | m | `SailingState.cs:207`, `WindsurferSetup.cs:764`, `MainScene.unity:273` | `BoardMassConfiguration` uses 2.4 (`WindsurferSetup.cs:783`); the FBX model is 2.28 m (plan, Phase 6) |
| `width_m` (beam) | 0.6 | m | `SailingState.cs:210`, `WindsurferSetup.cs:765` | model is 0.80 m (plan) |
| `thickness_m` | 0.12 | m | `SailingState.cs:213`, `WindsurferSetup.cs:766` | – |
| `volume_l` | 120 | L | `SailingState.cs:216` (unused by the hull model) | – |
| `mass_total_kg` (hull model) | 91 = 8 + 8 + 75 | kg | `SailingState.cs:220-231`, `WindsurferSetup.cs:768-770`, `MainScene.unity:277-279`; Rigidbody `m_Mass: 91` at `MainScene.unity:214` | **`BoardMassConfiguration` sets the Rigidbody mass to 94 kg (8 + 6 + 80) at runtime** (`BoardMassConfiguration.cs:191`, values `WindsurferSetup.cs:779-782`, `MainScene.unity:464`); `PHYSICS_DESIGN.md:554-556` says 90 (15 + 75); `PROGRESS_LOG.md:450` says 90. The last build therefore simulated a 94 kg body while all weight-based caps in this model used 91 kg (892.7 N). Phase 2: one mass, from one config. |
| `wetted_area_rest_m2` | 1.36 | m² | derived, `SailingState.cs:236` | – |
| `waterline_length_m` | 2.0 | m | derived, `SailingState.cs:241` | – |

**Correction from the git history (sections 11 and 13).** The scene that was actually played in Sessions 24 to 26 (commit b5ed2ea) still held the Session 22 values for these fields: planing lift coefficient 0.15, max lift fraction 0.4, submersion drag multiplier 3, planing wetted-area ratio 0.35, lift smoothing 0.15, water viscosity 400, optimal trim 2. The "Last build" column below shows the values in the repository today (the scene regenerated on 2 January 2026 and hand-edited in Session 27, equal to the C# defaults), which were never played. So the planing lift that was play-tested was at most 0.4 × 0.15 = 6 % of the weight, and the "12×" submersion multiplier ran as 3×.

Hull-drag settings (C# defaults in `AdvancedHullDrag.cs`; the setup script set none of them (`WindsurferSetup.cs:761-772`), so the scene holds the C# defaults of the day it was last saved, `MainScene.unity:280-293`; see the correction above for what was played):

| Name | Last build | Unit | Source (last build) | Other values and sources |
|---|---|---|---|---|
| `planing_onset_speed_ms` | 4.0 | m/s | `AdvancedHullDrag.cs:31`, `MainScene.unity:280` | tooltip `:30` "4.7 typical"; `PROGRESS_LOG.md:388` 4.0 |
| `full_planing_speed_ms` | 6.0 | m/s | `:34`, `MainScene.unity:281` | – |
| `planing_wetted_area_ratio` | 0.20 | – | `:37`, `MainScene.unity:282` | 0.35 in Sessions 22 and 24 (commits `5a1857a`, `fa79027` line 37) |
| Hydrodynamics planing area reduction | 0.85 | – | `Hydrodynamics.cs:207` | 0.5 in Sessions 22–24 (`5a1857a` line 205) |
| spray coefficient | 0.01 × planing_factor on the reduced area | – | `Hydrodynamics.cs:213-214` (Session 25, `e6756db`) | 0.002 × (1 − pf) on the full area (Session 22), 0.0005 × (1 − pf) (`c62f577`) |
| hump factor | 1.5 × friction | – | `Hydrodynamics.cs:217` | never effective (F7) |
| residuary curve | 0.001 Fn⁴ (1 + 5 Fn) | – | `Hydrodynamics.cs:194` | no literature source |
| `submersion_drag_multiplier` | 12 | – | `:41`, `MainScene.unity:283`, `PHYSICS_DESIGN.md:569`, `PHYSICS_VALIDATION.md:386` | 3.0 in Session 22 (`5a1857a` line 41); `PROGRESS_LOG.md:257` says "6x → 12x" |
| `normal_submersion` | 0.35 | – | `:220` (hard-coded) | – |
| underwater drag | up to ×5 above 50 % and 8 m/s | – | `:232-242` | added Session 23, `KNOWN_ISSUES.md:125` |
| `submersion_vertical_damping` | 600 | N·s/m | `:44`, `MainScene.unity:284` | duplicates section 7 |
| lateral Cd, area | 1.0, L × T = 0.30 m² | – | `:296-297` | – |
| vertical Cd, area | 1.2, L × W × 0.5 = 0.75 m² | – | `:309-310` | – |
| `displacement_lift_enabled` | true | – | `:48`, `MainScene.unity:285` | spec: false |
| `displacement_lift_coefficient` | 0.12 | – | `:51`, `MainScene.unity:286`, `PHYSICS_DESIGN.md:195,565` | – |
| `displacement_lift_min_speed_ms` | 0.5 | m/s | `:54`, `MainScene.unity:287` | – |
| displacement lift cap | 0.3 × weight | – | `:352`, `PHYSICS_DESIGN.md:187` | 0.5 in Session 22 (`5a1857a` line 306) |
| displacement planform area | L × W × 0.8 = 1.2 m² | m² | `:345` | Session 22 used L × W × submersion |
| `planing_lift_enabled` | true | – | `:58`, `MainScene.unity:288` | – |
| `planing_lift_coefficient` | 1.0 | – | `:61`, `MainScene.unity:289` | 0.15 (Session 22, `5a1857a` line 58; `PROGRESS_LOG.md:449`), 0.8 (Session 24 `fa79027` line 61; `PHYSICS_DESIGN.md:232,566`) |
| `max_lift_fraction` | 1.0 | – | `:64`, `MainScene.unity:290` | 0.4 (Session 22, `5a1857a` line 61), 1.2 (before Session 24 per `PROGRESS_LOG.md:255`), **0.85 (Session 24 `fa79027` line 64; `PHYSICS_DESIGN.md:233,567`; `KNOWN_ISSUES.md:181`)**. The docs' 0.85 was never what the played build used after 1 January 2026. |
| `optimal_trim_angle_deg` | 3 | deg | `:67`, `MainScene.unity:291` | 2 in Session 22; unused since `c62f577` |
| `lift_smoothing_factor` | 0.08 per tick | – | `:70`, `MainScene.unity:292`, `PHYSICS_DESIGN.md:234,568` | at 50 Hz (`TimeManager.asset:6`) |
| `max_planing_submersion` | 0.50 | – | `:73`, `MainScene.unity:293`, `KNOWN_ISSUES.md:129` | – |
| decay factors | 0.95 / 0.90 / 0.80 per tick | – | `:387`, `:396`, `:408` | – |
| planing-lift minimum speed | 3.0 | m/s | `:385` | unreachable (F15) |
| trim clamp | 1 to 10 | deg | `:431`; `fa79027:381` | – |
| Savitsky `lambda` | lerp(L/B = 4.17, 1.5, planing_ratio), clamp 1–4 | – | `fa79027:393-395`; `PHYSICS_VALIDATION.md:322` | – |
| Savitsky constants | 0.012, 0.0055, exponent 1.1, 2.5, 0.5 | – | `fa79027:399-402`; Savitsky 1964 | – |
| deadrise `beta_deg` | 3 | deg | `fa79027:405` | – |
| deadrise correction | 0.0065 β CL0^0.6 | – | `fa79027:406`; Savitsky 1964 | – |
| angular damping | 0.8 / 1.5 × (1…5) × mass × 0.1 | N·m·s/rad | `:530-543` | `PHYSICS_VALIDATION.md:209` describes a different ramp |
| resistance application point | 0.1 × L aft = 0.25 m | m | `:518` | – |
| lift application point | 0 (centre) | m | `:500` (Session 26) | +1.25…+0.625 m forward (Sessions 22–24, `fa79027:453`), the same distance aft (`c62f577`) |

Legacy `WaterDrag.cs` (the pre-Session-13 component, history only): `_forwardDrag = 0.08`, `_lateralDrag = 1.5`, `_verticalDrag = 4`, `_planingSpeed = 4 m/s`, `_planingDragMultiplier = 0.5` (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/WaterDrag.cs:17-30`), applied as `coefficient × v × |v|` per body axis with no density or area (`:77-79`), halved above the planing speed (`:69-70`). `scene_config.json:53-57` (27 December 2025) has `_forwardDrag 0.15`, `_lateralDrag 3`. Nothing from it carries over except the idea of a lateral term.

### Where the force acts

- **Resistance** `resistance_force = -v_rel.normalized() * r_hull_n + lateral term`, applied at body point `p_res = Vector3(0, 0, +0.1 * length_m)` = 0.25 m aft of the board origin, on the deck plane (`y = 0`). The legacy called this "the centre of lateral resistance, approximately mid-hull, slightly aft" (`AdvancedHullDrag.cs:517`). The torque is `(p_res − p_com) × F`. With the sailor the centre of mass sits well above the deck (0.15 m in the legacy override, about 0.9 m with the composite model of section 7), so a forward-motion drag of `R` newtons applied 0.4 m below it gives a bow-down pitching moment of about `0.4 R` N·m (44 N·m for a realistic 110 N). A lateral drag `F_lat` (drift to starboard, force to port) applied 0.25 m aft of the COM gives a yaw torque of `−0.25 F_lat` about +Y, which turns the bow to starboard, i.e. into the drift.
- **Planing lift** along world up (the legacy did not tilt it with the hull; physically it is normal to the bottom, which is what the `tan(tau)` pressure drag in F7 accounts for), at body point `(0, 0, planing_lift_point_z_m)`, default 0. **Note:** the legacy point `(0,0,0)` is the transform origin, not the Rigidbody centre of mass. `BoardMassConfiguration` moved the COM aft by `planingCOMShift × planing_ratio` (0.15 m in the scene, `MainScene.unity:476`; 0.3 m in code and docs) so at full planing the "centre" lift was 0.15 m *forward* of the COM: a bow-up moment of about 130 N·m that nobody intended. Phase 2 applies forces at explicit body points relative to the COM, so this must be decided, not inherited.
- **The physically right lift point.** For a planing surface Savitsky gives the centre of pressure at `l_p = lambda * b * (0.75 − 1 / (5.21 * cv² / lambda² + 2.39))` forward of the transom (tail). At 8 m/s, `lambda` 1.5, `cv` 3.30: `l_p = 0.9 × (0.75 − 1/27.6) = 0.64 m` forward of the tail, i.e. at `z = +1.25 − 0.64 = +0.61 m` (aft of the board centre) for the 2.5 m board. That is where the water pushes. Applied there, the lift makes a bow-down moment which the sailor's aft weight shift and the buoyancy of the tail must balance; the board then settles at the trim where moments balance. This is real planing behaviour and also a possible source of porpoising if the pitch damping is wrong, which is why the spec starts at the centre (no moment) and lets Phase 4 move it with a test.

### Signs and the Unity-to-Godot translation

| Item | Unity (left-handed, +Z forward) | Godot D4 (right-handed, −Z forward) | Flip? |
|---|---|---|---|
| Resistance direction | `-velocity.normalized` (`:274`) | `-v_rel.normalized()` | no |
| Resistance point | `(0, 0, -0.1 L)` = aft (`:518`) | `Vector3(0, 0, +0.1 * length_m)` = aft | **yes**, Z sign |
| Lift point (Sessions 22–24) | `(0, 0, +L(0.5 − 0.25 pr))` = **forward** (`fa79027:453`) | if ever used, aft would be `+z` | **yes**; and the legacy comment had it wrong |
| Lift direction | `Vector3.up` (`:505`) | `Vector3.UP` | no |
| Lateral drag direction | `-transform.right * Sign(localVelocity.x)` (`:301`) | `-basis.x * sign(v_local.x)` | no (starboard is +X in both) |
| Forward speed component | `localVelocity.z` (+ = forward) | `-v_local.z` (+Z is aft) | **yes** if you ever use it; this model does not |
| Trim (pitch) | `-transform.eulerAngles.x` after wrapping to ±180 (`:426-428`): Unity's positive X rotation tips the bow **down**, hence the minus | `pitch_rad = asin(-basis.z.y)`; in Godot a positive rotation about +X tips the bow (−Z) **up**, so no minus. Do not use `rotation.x` (Euler order issues); use the basis | **yes**, sign of the Euler angle |
| Heel | `transform.eulerAngles.z` wrapped, then `abs` (`:420-422`) | `heel_rad = -asin(basis.x.y)`, then `abs` | sign irrelevant here (only `abs` is used) |
| Vertical damping / vertical drag | `linearVelocity.y`, `Vector3.up` | `v_rel.y`, `Vector3.UP` | no |
| Angular damping | `-angularVelocity * k` | `-angular_velocity * k` | no (opposes whatever the spin is) |
| `Vector3.SignedAngle`, `Vector3.Cross` | not used in these two files | – | – |

Also: Unity's `Rigidbody.linearVelocity` is the velocity of the centre of mass, world frame; the legacy never subtracted the water velocity. Unity's `transform.InverseTransformDirection` is `basis.inverse() * v` in Godot for the direction part only (no translation), which is what `v_local` above means.

### Stabilisers and fudges in this model

| # | Fudge | Added | Symptom it treated | What it probably hides | Recommendation |
|---|---|---|---|---|---|
| 1 | Displacement lift, 30 % of weight from 1.9 m/s (F11) | Session 22 (cap 0.5), Session 24 (cap 0.3) | "board sinks 75 %+ at displacement speeds" | Nothing: 74–77 % is Archimedes for 91–95 kg on 120 L (pitfall 8) | **Drop.** Choose board volume for the feel instead. |
| 2 | Planing lift cap `max_lift_fraction` (0.85 docs, 1.0 build) (F15) | Session 24 | "board flies out at 45+ km/h" | Savitsky lift ∝ v² with `lambda` fixed by speed; in reality the wetted length shrinks | **Keep at exactly 1.0 × weight** as the stand-in for the wetted-length shrink we do not model; not a tuning knob. Re-evaluate in Phase 4 together with F12. |
| 3 | Planing off above 50 % submersion, with 0.8/tick decay (F15) | Session 23 | half-wind "submarine mode" (issue 3) | Missing submerged drag (F8) and the missing sail heeling/righting physics | **Drop to start**; re-add as a smooth fade only if the nose-dive test fails. |
| 4 | Progressive lift penalty 35–50 % | documented Session 23, never in committed code | same | – | **Drop** (never existed; would violate F12). |
| 5 | Submersion drag ×(1 + 12 excess²) (F8a) | Session 22 (×3), 24 (×12) | board digs in and does not slow | Wetted area independent of depth | **Replace** by wetted area and form drag that grow with submersion (F8 spec decision). |
| 6 | Underwater drag ×(1…6) above 50 % and 4–8 m/s (F8b) | Session 23 | same as 3 | same as 5 | **Replace** (same physical term). |
| 7 | Ride-high drag reduction ×0.825–1.0 (F8c) | Session 22 | – | double-counts the wetted-area reduction | **Drop.** |
| 8 | Double wetted-area reduction, 0.20 × 0.15 = 3 % (F5, F7) | Session 22 (0.35 × 0.5), Session 25 WIP (0.20 × 0.15) | make planing "let go" | Planing drag not modelled as `lift × tan(trim)` + friction | **Replace** by a single reduction to `lambda b²` plus the pressure drag (F7 spec decision). |
| 9 | Hump factor 1.5 in the Froude blend (F7) | Session 22 | – | never active | **Drop.** |
| 10 | Cliff: `is_planing` switch at 5 m/s between two resistance branches (F7) | Session 22 | – | the two branches were never made continuous | **Replace** by blending on `planing_ratio`. |
| 11 | Submersion vertical damping 600 N·s/m, ×2 when deep and planing (F9) | Session 24 | bobbing at the planing transition | heave damping defined in three places | **Drop here**; section 6 owns damping. |
| 12 | Vertical "drag" 1.2 × ½ρ·v·|v_y|·0.75 m² (F10) | Session 13/18 | bobbing | same | **Drop here**; section 6. |
| 13 | Lateral drag in the mixed `speed × |v_x|` form (F10) | Session 13/18 | leeway | fin tuning | **Keep the term, fix the form** to `v_x |v_x|`. |
| 14 | Lift smoothing 0.08/tick and decays 0.95/0.9/0.8 per tick (F15) | Session 22–24 | jitter and the trampoline | lack of heave damping; frame-rate dependent | **Replace** by a time-based filter or nothing. |
| 15 | Heel floor `max(cos heel, 0.7)` (F14) | Session 25 WIP | – | – | **Drop the floor**; use `beam_eff = b cos(heel)`. |
| 16 | Angular damping 0.8/1.5 × up to ×5 above 15 kn × mass × 0.1 (F16) | Session 18 | "violent oscillations at planing speeds" | wrong lift application point (forward), no trim feedback, PhysX | **Drop here**; section 6 defines one rotational damping, starting small. |
| 17 | Planing lift applied at the centre (F15) | Session 26 | porpoising | the earlier point was forward of the COM (a sign slip), not aft | **Keep as the Phase 2 default** (zero moment, simplest), with a config value so Phase 4 can test the Savitsky centre of pressure. |
| 18 | Trim clamp to 1–10° (F13) | Session 24 | keeps the fit in its valid range and avoids negative lift | possibly hides that nothing trims the bow up | **Keep** the clamp (it is the fit's validity range); add `planing_trim_offset_deg` = 0 as the honest knob. |
| 19 | Speed-based `planing_ratio` instead of Froude (F4) | Session 22 | planing started at 8 km/h with Froude | – | **Keep.** Simple and deterministic; tune the two speeds in Phase 4. |

### Worked example: 8 m/s (28.8 km/h, 15.6 kn), trim 4°, level, on the default board

Default board: L 2.5 m, B 0.6 m, T 0.12 m, 91 kg (weight 892.7 N), flat water, no drift, no heave, `submersion_ratio` 0.20.

**Legacy numbers (what the last build computed):**

| Step | Value |
|---|---|
| `planing_ratio`, `is_planing` | 1.0, true (F4) |
| `wetted_area_m2` | 1.36 × 0.20 = 0.272 m² (F5) |
| `froude_number` | 8 / √(9.81 × 2.0) = 1.806 (F3) |
| `reynolds_number` | 8 × 2.0 / 1.19e-6 = 1.34e7; `cf` = 0.075 / (7.129 − 2)² = 0.00285 (F6) |
| `q_pa` | 0.5 × 1025 × 64 = 32 800 Pa |
| `r_friction_n` (full 0.272 m²) | 0.00285 × 32 800 × 0.272 = 25.4 N |
| `planing_factor` | clamp((1.806 − 0.4)/0.3) = 1.0 |
| reduced area | 0.272 × 0.15 = 0.0408 m² |
| planing friction | 0.00285 × 32 800 × 0.0408 = 3.8 N |
| spray | 0.01 × 32 800 × 0.0408 = 13.4 N |
| hump term | 1.5 × 25.4 = 38.2 N, weight (1 − 1.0) = 0 |
| `r_hull_n` | lerp(38.2, 3.8 + 13.4, 1.0) = **17.2 N** |
| ride-high factor (0.20 < 0.35, planing) | 1 − (0.35 − 0.20) × 0.5 = 0.925 → **15.9 N** |
| lateral, vertical drag | 0 (no drift, no heave) |
| resistance force | 15.9 N pointing backwards, at 0.25 m aft |
| displacement lift | 0.12 × 32 800 × 1.2 = 4 723 N → cap 267.8 N → × (1 − 1.0) = **0 N** |
| planing lift, version B (last build) | 892.7 × 1.0 × 1.0 × max(cos 0, 0.7) × 1.0 = 892.7 N, cap 892.7 → target **892.7 N** (100 % of the weight; the smoothed value approaches it with τ ≈ 0.24 s) |
| planing lift, version A (Session 24 Savitsky, 0.8 coefficient, 0.85 cap) | `cv` = 8/√(9.81 × 0.6) = 3.297; `lambda` = 1.5; dynamic 0.012 × √1.5 = 0.01470; hydrostatic 0.0055 × 1.5^2.5 / 3.297² = 0.00139; `cl0` = 4^1.1 × 0.01609 = 4.595 × 0.01609 = 0.0739; deadrise 0.0065 × 3 × 0.0739^0.6 = 0.0041; `cl` = 0.0699; raw lift 0.0699 × 32 800 × 0.36 = 825 N; × 0.8 × 1.0 = 660 N; cap 758.8 → **660 N** (74 % of the weight) |
| angular damping coefficient | 0.8 × (1 + (15.55 − 15)/5) × 91 × 0.1 = 8.1 N·m·s/rad |

**Spec numbers (F7 spec decision, same state, Savitsky lift with no coefficient and cap 1.0):**

| Term | Value |
|---|---|
| planing lift | 825 N (92 % of 892.7 N; 89 % of the 94 kg weight) |
| friction on `lambda b²` = 0.54 m² | 0.00285 × 32 800 × 0.54 = 50 N (with `Re` on the 0.9 m wetted length, `cf` = 0.00328 → 58 N) |
| residuary | 0 (faded out by `planing_ratio` = 1) |
| pressure drag | 825 × tan 4° = 58 N |
| spray | 0.01 × 32 800 × 0.54 = 177 N — OPEN: this is larger than Savitsky's typical 10–20 % of total and must be tuned in Phase 4; 0.003 would give 53 N |
| total hull resistance | about 165 N with spray at 0.003, about 290 N with the legacy 0.01 |

For comparison, the Phase 4 top-speed target of 25 to 30 km/h in 15 kn of wind means the sail must deliver about this much drive plus the fin's drag at 8 m/s.

### What Phase 2 must implement

- [ ] `HullModel` (RefCounted) with `compute(state, dt) -> HullForces` returning: resistance vector and application point, planing lift and application point, `planing_ratio`, `is_planing`, `wetted_area_m2`, `froude_number`, and the individual drag terms for telemetry.
- [ ] Inputs from the state: `v_rel` (board velocity minus water velocity at the hull), the basis (for `pitch_rad`, `heel_rad`, `v_local`), `submersion_ratio` and `is_floating` from the buoyancy model of the same tick.
- [ ] Gates: nothing when `not is_floating`; nothing when `speed_ms < 0.1`.
- [ ] F4 planing ratio: linear on `speed_ms` between `planing_onset_speed_ms` (4.0) and `full_planing_speed_ms` (6.0); `is_planing = planing_ratio > 0.5`.
- [ ] F2/F5/F8 wetted area: at rest `L·W·0.7 + 2(L+W)·0.05`; planing `lambda_planing · W²` with `lambda_planing = 1.5`; blend by `planing_ratio`; grow toward the fully wet area `2LW + 2(L+W)T` between 35 % and 100 % submersion.
- [ ] F3/F6 friction: `Fn`, `Re` (floor 1e5), ITTC 1957 `cf`, `r_friction = cf · q · wetted_area`.
- [ ] F7 residuary: `cr = 0.001 Fn⁴ (1 + 5 Fn)` on the at-rest area, times `(1 − planing_ratio)`.
- [ ] F7 pressure drag `planing_lift · tan(tau_rad)` and spray `spray_coefficient · planing_ratio · q · lambda_planing · W²` (default 0.01, tune in Phase 4).
- [ ] F8 form drag on the frontal area `W·T` fading in from 50 % to 100 % submersion, Cd 0.8.
- [ ] F10 lateral drag: `0.5 ρ · 1.0 · L·T·(1 − 0.5 planing_ratio) · v_x |v_x|` along `−basis.x`.
- [ ] Total resistance along `−v_rel.normalized()` (plus the lateral vector) at body point `(0, 0, +0.1 L)`.
- [ ] F13 Savitsky planing lift: `tau_deg = clamp(deg(pitch_rad) + planing_trim_offset_deg, 1, 10)`, `beam_eff = W cos(heel)`, `cv = speed / √(g beam_eff)`, `lambda = clamp(lerp(L/W, 1.5, planing_ratio), 1, 4)`, `cl0`, deadrise correction with `beta_deg = 3`, `lift = cl · q · beam_eff² · planing_ratio`, cap at `mass_total · g`, gates `planing_ratio ≥ 0.1` and `submersion_ratio ≥ 0.02`. Time-based smoothing (τ = 0.2 s) or none.
- [ ] Lift along `Vector3.UP` at body point `(0, 0, planing_lift_point_z_m)`, default 0, relative to the COM.
- [ ] **No** displacement lift, no submersion multipliers, no `> 50 %` planing cut-off, no vertical damping, no angular damping in this model (sections 6 and 7 own those). Leave commented "see PHYSICS_SPEC §5 F8/F9/F16" so nobody re-adds them by accident.
- [ ] `BoardConfig` fields (with units in the names): `length_m`, `width_m`, `thickness_m`, `volume_l`, `planing_onset_speed_ms`, `full_planing_speed_ms`, `lambda_planing`, `spray_coefficient`, `planing_trim_offset_deg`, `deadrise_deg`, `planing_lift_point_z_m`, `lateral_drag_cd`, `submerged_form_drag_cd`, `lift_smoothing_time_s`.
- [ ] Telemetry: each drag term, the lift, `planing_ratio`, `wetted_area_m2`, `tau_deg`.

### Tests Phase 2 should write

Use the legacy board (2.5 × 0.6 × 0.12 m, 91 kg, the hull configuration the legacy code was checked against; section 14's default configuration is 2.40 × 0.72 m and 92 kg) and `rho_water` 1025, `g` 9.81, `nu` 1.19e-6. Tolerances ±1 % unless noted.

- **Reference geometry:** `wetted_area_rest_m2 == 1.36`, `waterline_length_m == 2.0`.
- **Planing ratio:** 3.9 m/s → 0; 5.0 m/s → 0.5 and `is_planing == false`; 5.01 m/s → `is_planing == true`; 6.0 and 12 m/s → 1.0.
- **Friction:** at 2 m/s, `Re == 3.36e6`, `cf == 0.00370`, friction on 1.36 m² == 10.2 N. At 8 m/s on 0.54 m²: `cf == 0.00285`, 50.0 N.
- **Residuary:** at 4 m/s (`Fn` 0.903): `cr == 0.00368`, `r_residuary == 40.9 N` on 1.36 m²; at 8 m/s it is 0 (faded).
- **Continuity:** total resistance sampled every 0.05 m/s from 0.1 to 12 m/s changes by less than 15 % between neighbouring samples (no cliff at 5 m/s).
- **Hump:** the total resistance has a local maximum between 4.5 and 5.5 m/s and is lower at 6.5 m/s than at that maximum.
- **Savitsky coefficient:** 8 m/s, 4°, level, `planing_ratio` 1: `cv == 3.297`, `lambda == 1.5`, `cl0 == 0.0739`, `cl == 0.0699`, lift == 825 N (±2 %). Same at 1°: 171 N; at 10° the cap (892.7 N) binds.
- **Cap:** at 12 m/s and 10° the lift equals `mass_total · g` exactly.
- **Hard rule F12:** lift at 8 m/s and 4° is identical (to the bit) at `submersion_ratio` 0.10, 0.30 and 0.45; it is 0 at 0.01 (gate).
- **Pressure drag:** at 8 m/s and 4° with 825 N of lift, `r_pressure == 57.7 N`.
- **Heel:** at 8 m/s, 4°, heel 30°, `beam_eff == 0.5196` and the lift is `cos²(30°) = 0.75` of the level value (before the cap).
- **Lateral drag:** `v_local.x` = 0.5 m/s, `planing_ratio` 0: force 38.4 N along `−basis.x`; with `v_local.x` = −0.5 the force is along `+basis.x`; at `planing_ratio` 1 the magnitude is halved.
- **Direction and point:** for a board moving along its bow with `basis = Basis.IDENTITY` at 8 m/s the resistance vector is `(0, 0, +r)` (pointing aft, i.e. +Z) and is applied at `(0, 0, 0.25)`.
- **Torque check:** lift of 800 N at `planing_lift_point_z_m = +0.6` on a COM at `(0, 0.4, 0)` gives a pitch torque about +X of `−480 N·m` (bow down); at 0 it gives 0.
- **Trim sign:** rotate the basis by +4° about +X (`Basis(Vector3.RIGHT, deg_to_rad(4))`): `pitch_rad` is +0.0698 (bow up). This pins the Unity-to-Godot flip.
- **Submerged drag:** at 8 m/s fully submerged (`submersion_ratio` 1.0) the total resistance is at least 10 × the value at 0.20.
- **Gate:** `is_floating == false` returns zero forces and `planing_ratio == 0`.
- **Determinism:** the same state twice gives identical outputs.

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/Scripts/`):
- `Physics/Board/AdvancedHullDrag.cs` (611 lines): fields 27–80; `FixedUpdate` 139–156; `CalculateHullResistance` 161–278; `ApplyDirectionalDrag` 283–316; `CalculateDisplacementLift` 327–357; `CalculatePlaningLift` 372–474; `ApplyHydrodynamicLift` 483–508; `ApplyResistance` (with angular damping) 513–546.
- `Physics/Core/Hydrodynamics.cs` (242 lines): `CalculateHullResistance` 164–222; `CalculateWaveResistance` 227–240 (no callers anywhere in the project; Phase 5 may look at it).
- `Physics/Core/SailingState.cs:203-242` (`HullConfiguration`).
- `Physics/Core/PhysicsConstants.cs:12-21`.
- `Physics/Buoyancy/AdvancedBuoyancy.cs:59-68` (damping fields), `:225-284` (`SubmergedRatio`, `IsFloating`), `:312-385` (damping).
- `Physics/Board/BoardMassConfiguration.cs:186-194` (mass and COM written to the Rigidbody).
- `Physics/Board/WaterDrag.cs:17-30, 61-91` (pre-Session-13 drag, history only).
- `Editor/WindsurferSetup.cs:688-694` (Rigidbody), `:706-720` (buoyancy), `:761-772` (hull drag), `:777-788` (mass configuration).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:214-216` (Rigidbody), `:240-257` (buoyancy), `:272-296` (hull drag), `:464-476` (mass configuration).
- `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6` (fixed step 0.02 s).
- Git history of `AdvancedHullDrag.cs`: `5a1857a` (Session 22), `fa79027` (Session 24, Savitsky, lines 348–427 and 445–466 of that version), `c62f577` (Session 25 WIP: simple lift model, submersion gate, underwater drag, 0.20 wetted ratio, coefficients 1.0/1.0), `e6756db` (Session 25: spray fix in `Hydrodynamics.cs`), `b5ed2ea` (Session 26: lift point to centre), `4c45223` (Session 18: angular damping).

Legacy documentation (`Legacy/Documentation/`):
- `PHYSICS_DESIGN.md:143-155` (generic drag), `:159-259` (lift system, describes the Savitsky version that was not the last build), `:379-413` (displacement vs planing), `:562-569` (tuning values), `:588-597` (trampoline), `:599-631` (issue 3 fix, includes the never-implemented penalty).
- `PHYSICS_VALIDATION.md:197-212` (angular damping, different ramp than the code), `:306-341` (Savitsky, "no submersion feedback"), `:344-365` (water damping), `:368-387` (legacy systems, "12x").
- `KNOWN_ISSUES.md:81-86` (Session 26), `:94-106` (Session 25), `:108-133` (issue 3), `:177-193` (Sessions 22–24).
- `PROGRESS_LOG.md:12-26` and `:60-82` (status and "do not change" table), `:139-211` (Session 26), `:215-274` (Session 24), `:337-452` (Session 22). There are no Session 23 or 25 entries in the progress log; those sessions are only in `KNOWN_ISSUES.md` and the git log.
- `scene_config.json:50-57` (2025-12-27 `WaterDrag` values, history only).

Literature:
- Savitsky, D. (1964). "Hydrodynamic Design of Planing Hulls". *Marine Technology*, 1(4), 71–95. Lift coefficient `C_L0 = τ^1.1 (0.0120 λ^0.5 + 0.0055 λ^2.5 / C_V²)`, deadrise correction `C_Lβ = C_L0 − 0.0065 β C_L0^0.6`, centre of pressure `l_p/(λb) = 0.75 − 1/(5.21 C_V²/λ² + 2.39)`, drag `D = Δ tan τ + D_f / cos τ`.
- ITTC (1957). Proceedings of the 8th International Towing Tank Conference, Madrid: model-ship correlation line `C_F = 0.075 / (log10 Re − 2)²`.
- Larsson, L. & Eliasson, R. E. *Principles of Yacht Design* (3rd ed., 2007), ch. 5 (resistance components, Delft series) and the planing notes in ch. 5/6.
- Faltinsen, O. M. *Hydrodynamics of High-Speed Marine Vehicles* (2005), ch. 9 (planing, Savitsky method, porpoising).

OPEN questions raised in this section (also returned in the structured output):
1. OPEN: which residuary curve to use in place of the unsourced `0.001 Fn⁴ (1 + 5 Fn)`; no legacy or literature value exists for a windsurf board hull.
2. OPEN: the spray coefficient (legacy 0.01 on the reduced area) gives 177 N at 8 m/s on the spec's 0.54 m²; a value near 0.003 matches Savitsky's "10–20 % of total". Phase 4 must tune it.
3. OPEN: whether a `planing_trim_offset_deg` (about 1° from tail rocker) is needed for the board to get onto the plane with the trim near the 1° clamp; only a Phase 2/4 simulation can tell.
4. OPEN: the planing lift application point: centre (legacy) or the Savitsky centre of pressure (0.6 m aft); to be decided by the Phase 4 porpoising test.
5. OPEN: which mass the last build really used for the hull caps: `HullConfiguration.TotalMass` 91 kg for all weight-based caps while the Rigidbody mass was overwritten to 94 kg by `BoardMassConfiguration`. The spec needs one number (see the mass section).
6. OPEN: whether the legacy's use of the full 3D speed (including heave) for `q` and `planing_ratio` should become the horizontal speed; the spec keeps the 3D length of `v_rel` for now.

---

## 6. Buoyancy and water damping

### Purpose

Buoyancy is what keeps the board on the water. Water pushes up on every part of the hull that is under the surface, and the total push equals the weight of the water the hull displaces (Archimedes). Because the push is spread over the whole hull bottom, it also does two things a single upward force could not do: it levels the board (a bow that dips gets pushed up harder than the tail) and it rights the board when it heels (the rail that goes under gets pushed up harder).

The game needs this model for three things:
1. To hold the board and sailor up at rest and at low speed, sinking to the right depth (about 92 L of a 120 L board with 94 kg on it, see 6.6).
2. To give the right pitch and roll stiffness, so the board sits level, rights itself after a tilt, and reacts to waves (Phase 5).
3. To report `submersion_ratio` (0 to 1), which the hull-drag and planing model (section 5) uses to decide whether the board is touching the water or is driven under.

Water damping belongs with buoyancy because it acts on the same motion: a hull that bobs up and down pushes water out of the way and radiates waves, and that costs energy. Without damping the board would bounce on its buoyancy "spring" for ever.

The legacy model is `AdvancedBuoyancy.cs` (Session 22 rewrite, tuned in Sessions 24 to 26). The older `BuoyancyBody.cs` is a spring-type float model that is not Archimedes; it is described in 6.8 for comparison only.

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `board_volume_m3` | total volume of the board (120 L = 0.120 m³) | m³ |
| `board_length_m`, `board_width_m`, `board_thickness_m` | hull box the sample grid is built from | m |
| `nose_rocker_m`, `tail_rocker_m` | how far the hull bottom curves up at the bow and at the tail | m |
| `length_samples`, `width_samples` | grid size (7 × 3 = 21 points) | – |
| `sample_points[i]` | position of sample point i in the body frame (bow = −Z, starboard = +X, up = +Y), relative to the body origin (see "Where the force acts" for the origin-to-COM offset) | m |
| `sample_volume_m3[i]` | the share of the total volume that sample point i represents | m³ |
| `position`, `basis` | body origin in the world frame and body orientation (from the rigid-body state) | m, – |
| `v_boat` | velocity of the body origin in the world frame | m/s |
| `omega_body` | angular velocity in the body frame (ω_x pitch, ω_y yaw, ω_z roll) | rad/s |
| `water.height_at(x, z)` | water surface height at a world point (flat: constant; Phase 5: Gerstner) | m |
| `water.normal_at(x, z)` | unit normal of the water surface at a world point (flat: `Vector3.UP`) | – |
| `rho_water` = 1025, `g` = 9.81 | shared constants | kg/m³, m/s² |
| **out** `depth_m[i]` | how far sample point i is below the water surface (negative = in the air) | m |
| **out** `point_force[i]` | buoyancy force at sample point i, world frame | N |
| **out** `submerged_volume_m3` | Σ submerged volume over all points | m³ |
| **out** `submersion_ratio` | `submerged_volume_m3 / board_volume_m3`, 0 to 1 | – |
| **out** `is_floating` | true when any buoyancy is acting | – |
| **out** `buoyancy_force_total` | Σ point forces (telemetry) | N |
| **out** `centre_of_buoyancy` | force-weighted mean of the submerged sample points (debug only) | m |
| **out** damping force and torque | see 6.5 | N, N·m |

### Formulas

All formulas are in the D4 body frame: bow = −Z, starboard = +X, up = +Y. The legacy code is in Unity's frame with bow = +Z; every place where that changes a sign is marked **[flip]** and repeated in the "Signs" subsection.

#### 6.1 Hull shape and the sample grid

The hull is described as a box `L × W × T` (2.5 m × 0.6 m × 0.12 m) with three corrections: the bottom curves up toward the ends (rocker), the board gets narrower toward the ends (width taper), and a board carries less volume near the ends (volume taper). There is **no thickness profile** in the legacy code: the thickness `T` is constant and is only used as the depth at which a sample point counts as fully under water (6.3). The rocker moves the sample points up; it does not change their volume.

The grid has `n_len` = 7 rows along the length and `n_wid` = 3 points across each row (rail, centre, rail). For row `i` (0 … 6) and column `j` (0 … 2):

1. Position along the length, from the tail to the bow, and the distance from the middle:
   ```
   t_i   = i / (n_len − 1)                       # 0 = tail row, 1 = bow row
   z_i   = +L/2 − L · t_i                        # body z: tail = +1.25 m, bow = −1.25 m   [flip: Unity uses z = −L/2 + L·t, bow at +Z]
   d_i   = |t_i − 0.5| · 2                       # 0 in the middle, 1 at either end
   ```
2. Rocker (the bottom curves up quadratically toward each end). The bow half uses the nose rocker, the tail half the tail rocker; the middle row (t = 0.5) has d = 0 so the choice does not matter there:
   ```
   rocker_i = nose_rocker_m · d_i²    if t_i > 0.5   (bow half, z_i < 0)
            = tail_rocker_m · d_i²    otherwise      (tail half, z_i ≥ 0)
   ```
   Source: AdvancedBuoyancy.cs:159-170.
3. Width taper: the half-width of the row shrinks quadratically toward the ends, to 70 % at the tips:
   ```
   width_factor_i   = 1 − 0.3 · d_i²
   half_width_i     = (W/2) · width_factor_i
   x_ij             = −half_width_i + 2 · half_width_i · j / (n_wid − 1)    # −half, 0, +half  (+X = starboard)
   ```
   Source: AdvancedBuoyancy.cs:172-174, 179-182. No sign change: starboard is +X in both engines.
4. Height of the sample point: the hull bottom, lifted by the rocker:
   ```
   y_i = −T/2 + rocker_i
   ```
   Source: AdvancedBuoyancy.cs:184-185. The body origin is therefore mid-thickness of the hull box, in the deck plane 0.06 m above the bottom.
5. Volume taper and the volume weight of each point. Boards carry less volume near the ends, so each row gets a linear volume factor (60 % at the tips) on top of the width factor:
   ```
   volume_factor_i = 1 − 0.4 · d_i
   weight_ij       = volume_factor_i · width_factor_i
   sample_volume_m3[ij] = board_volume_m3 · weight_ij / Σ_all weight
   ```
   Source: AdvancedBuoyancy.cs:176-177, 189-191, 197-201. The three points of a row have the same weight. The weights are normalised so that the 21 volumes add up exactly to the board volume.

The resulting grid for the default board (L = 2.5 m, W = 0.6 m, T = 0.12 m, nose rocker 0.08 m, tail rocker 0.02 m, 120 L). Σ weight = 14.36:

| Row (from bow) | z (m) | d | rocker (m) | y (m) | x of the three points (m) | weight | V per point (L) | V per row (L) |
|---|---|---|---|---|---|---|---|---|
| bow tip | −1.2500 | 1 | 0.0800 | +0.0200 | −0.210, 0, +0.210 | 0.42000 | 3.510 | 10.53 |
| | −0.8333 | 2/3 | 0.03556 | −0.02444 | −0.260, 0, +0.260 | 0.63556 | 5.311 | 15.93 |
| | −0.4167 | 1/3 | 0.008889 | −0.05111 | −0.290, 0, +0.290 | 0.83778 | 7.001 | 21.00 |
| middle | 0 | 0 | 0 | −0.0600 | −0.300, 0, +0.300 | 1.00000 | 8.357 | 25.07 |
| | +0.4167 | 1/3 | 0.002222 | −0.05778 | −0.290, 0, +0.290 | 0.83778 | 7.001 | 21.00 |
| | +0.8333 | 2/3 | 0.008889 | −0.05111 | −0.260, 0, +0.260 | 0.63556 | 5.311 | 15.93 |
| tail tip | +1.2500 | 1 | 0.0200 | −0.0400 | −0.210, 0, +0.210 | 0.42000 | 3.510 | 10.53 |

Note that the bow tip row sits at y = +0.02 m, above the body origin: with the nose rocker of 8 cm the bow points are 6 cm higher than the middle of the bottom, so at rest they are only just wet (6.6).

The legacy docs describe a different grid: PHYSICS_DESIGN.md:122-125 gives `taperFactor = 0.5` and an explicit weight list `{0.6, 0.8, 1.0, 1.0, 0.9, 0.7, 0.5}`, and the diagram at PHYSICS_DESIGN.md:88-104 shows a two-point "tail tip" row. None of that is in the code; the formulas above are what ran. Phase 2 follows the code.

#### 6.2 Where is the water?

For each sample point, transform it to the world frame and ask the water surface for its height and normal at that horizontal position:
```
p_world_i   = position + basis * sample_points[i]          # Godot: Transform3D * Vector3
h_water_i   = water.height_at(p_world_i.x, p_world_i.z)
n_water_i   = water.normal_at(p_world_i.x, p_world_i.z)
```
Flat water returns the base height (0 m in the legacy scene, WaterSurface.cs:168-176, MainScene.unity:643) and `Vector3.UP` (WaterSurface.cs:181-186). With waves the legacy code returns the Gerstner height at that (x, z) (WaterSurface.cs:175; the wave model itself is section 9) and a normal from finite differences with a 0.1 m step (WaterSurface.cs:50, 188-197). The depth is measured **vertically** (next step), not along the normal; only the force direction uses the normal.

#### 6.3 Depth, submerged volume and force per point

Each point stands for a column of hull `T` = 0.12 m tall with volume `sample_volume_m3[i]`. As the point goes under, the column fills up linearly; once the point is a full thickness under, the whole column counts:
```
depth_m[i]          = h_water_i − p_world_i.y                         # > 0 under water
if depth_m[i] > 0:
    fraction_i      = clamp(depth_m[i] / T, 0, 1)
    v_sub_i         = sample_volume_m3[i] · fraction_i                # m³
    f_i             = rho_water · g · v_sub_i                          # N, Archimedes for this column
    point_force[i]  = n_water_i · f_i                                  # along the water normal
else:
    v_sub_i = 0, point_force[i] = Vector3.ZERO
```
Source: AdvancedBuoyancy.cs:234-265. Physics: a body displaces water; the water it displaces weighs `rho_water · g · V`, and that weight is what pushes back. Spreading the volume over 21 columns gives an approximate but smooth answer for a tilted or partly submerged hull. Pointing the force along the water normal is exact on flat water (the normal is straight up). On waves it is the standard approximation for trochoidal (Gerstner) waves, where the water's own acceleration is close to perpendicular to the surface, so a floating body feels "down" as the surface normal. Keep it.

Two small consequences of the column model: (a) a rocker point's column reaches from `y_i` to `y_i + T`, which is above the deck plane at the tips; (b) full buoyancy needs every point 0.12 m under, i.e. the middle of the deck 0.06 m under water. Both are acceptable simplifications, and the stiffness they produce agrees with a proper metacentric calculation (6.7).

#### 6.4 Totals

```
buoyancy_force_total   = Σ point_force[i]
submerged_volume_m3    = Σ v_sub_i
if |buoyancy_force_total| > 0.1 N:
    centre_of_buoyancy = Σ (p_world_i · f_i) / Σ f_i        # legacy divides by |Σ point_force| (AdvancedBuoyancy.cs:269-271), same thing on flat water
    submersion_ratio   = submerged_volume_m3 / board_volume_m3
    is_floating        = true
else:
    centre_of_buoyancy = position
    submersion_ratio   = 0
    is_floating        = (number of points with depth > 0) > 0
```
Source: AdvancedBuoyancy.cs:219-284. `submersion_ratio` runs from 0 (dry) to 1 (every column full). The 0.1 N threshold and the `is_floating` fallback are numerical guards; on flat water `is_floating` is simply "some point is wet". `centre_of_buoyancy` is only used for the editor gizmo (AdvancedBuoyancy.cs:447-451); nothing in the physics reads it (checked with grep over `Scripts/`). Phase 2 may compute it for telemetry but must apply the forces per point, not at this centre. The water height at the body origin is also stored (`_waterLevel`, AdvancedBuoyancy.cs:283, 390-394) for the HUD; it is not used by the physics either.

The consumers of these outputs are the hull-drag model (section 5): `IsFloating` gates all hull forces (AdvancedHullDrag.cs:86-87, 142-149), and `SubmergedRatio` drives the submersion drag penalty (AdvancedHullDrag.cs:214-251), the extra vertical damping there (AdvancedHullDrag.cs:253-270), the displacement-lift gate (AdvancedHullDrag.cs:338-339) and the planing gate (AdvancedHullDrag.cs:393-399). The telemetry HUD shows the buoyancy magnitude (AdvancedTelemetryHUD.cs:235-237).

#### 6.5 Damping

The legacy damping is applied once per physics step, as one lumped force and one lumped torque, and only when `is_floating` and `submersion_ratio ≥ 0.05` (AdvancedBuoyancy.cs:314). All three parts scale with `submersion_ratio` (written `s` below).

**(a) Vertical damping**, on the world vertical velocity `v_y = v_boat.y`, only when `|v_y| > 0.01 m/s` (AdvancedBuoyancy.cs:322-338):
```
f_linear   = −v_y · c_vert_linear · s                    # N,  c_vert_linear in N·s/m
f_viscous  = −v_y · |v_y| · c_vert_viscous · s           # N,  c_vert_viscous in N·s²/m²
f_vertical = clamp(f_linear + f_viscous, −15000, +15000)  # N
apply f_vertical · Vector3.UP at the centre of mass
```
Physics: a hull pushed down into the water has to shove water aside. Two things resist that. One grows with the square of the speed: the drag of a flat plate moving face-on through water, `0.5 · rho_water · C_d · A · v²` with C_d ≈ 1.2 for a flat plate and A ≈ 0.8 · L · W ≈ 1.2 m² gives about 720 N·s²/m² at full submersion, so a viscous coefficient of the order of 800 N·s²/m² **is real physics**, not a fudge. The other grows linearly with speed: the energy radiated away as surface waves when the hull heaves ("wave-making" or radiation damping), plus the effect of the added mass of water that moves with the hull. Neither is easy to compute for a windsurf board; the linear term is a stand-in for them and its value has to come from tests (6.9).

How strong is the linear term? With all 21 columns in their linear range the buoyancy acts as a spring of stiffness `k_heave = rho_water · g · board_volume_m3 / T` = 1025 · 9.81 · 0.120 / 0.12 = **10 055 N/m** (6.7). For m = 94 kg that gives a natural bobbing period of `2π·sqrt(m / k)` = 0.61 s and a critical damping of `2·sqrt(k·m)` = 1944 N·s/m. So, at the resting submersion of 0.76:

| `c_vert_linear` | effective `c · s` | damping ratio ζ | behaviour |
|---|---|---|---|
| 800 N·s/m (scene, wizard, Session 22) | 611 N·s/m | 0.31 | one or two visible bounces, then still |
| 4000 N·s/m (Session 24 code default, docs) | 3056 N·s/m | 1.6 | no bounce, sluggish |
| 8000 N·s/m (Session 25/26 code default, KNOWN_ISSUES) | 6112 N·s/m | 3.1 | heavily overdamped: the board "sticks" in the water |

(The added mass of the water, which the legacy model ignores, would make the real period longer and the critical damping higher; see 6.9, open question.) Real ship heave is well damped but not overdamped, so 800 is the physically plausible starting value, and it is also what the validated Unity build actually used (see Values).

**(b) Horizontal (lateral) damping**, on sideways motion only (AdvancedBuoyancy.cs:344-359), when the horizontal speed exceeds 0.1 m/s:
```
v_local     = basis.transposed() * Vector3(v_boat.x, 0, v_boat.z)     # body frame; basis is orthonormal
v_lat       = v_local.x                                                # + = sliding to starboard
f_lateral   = −sign(v_lat) · |v_lat| · c_horizontal · 2 · s            # N, along the body +X axis
apply basis * Vector3(f_lateral, 0, 0) at the centre of mass
```
Forward motion gets no damping here (hull drag, section 5, does that). With `c_horizontal` = 20 N·s/m this is 40 N per m/s of sideslip at full submersion: about 30 N at 1 m/s at rest. For comparison, the side-on drag of the submerged hull (side area ≈ 2.5 m × 0.09 m ≈ 0.22 m², C_d ≈ 1) is about 115 · v² N, so this term is small and, being linear, has the wrong shape. See the fudge list.

**(c) Rotational damping** (AdvancedBuoyancy.cs:362-384):
```
omega_local = basis.transposed() * omega_world                 # or use the body-frame ω directly
factor      = 0.3 + 0.7 · s                                    # at least 30 % even when barely wet
torque_local = Vector3(
    −omega_local.x · c_rot · 4.0 · factor,                     # pitch (about +X)
    −omega_local.y · c_rot · 0.3 · factor,                     # yaw   (about +Y)
    −omega_local.z · c_rot · 3.0 · factor )                    # roll  (about +Z)
apply basis * torque_local
```
With `c_rot` = 150 N·m·s/rad the effective coefficients are 600 (pitch), 45 (yaw) and 450 (roll) N·m·s/rad at full submersion, and 501 / 38 / 376 at the resting 0.76 (factor 0.835). Physics: when a flat hull pitches or rolls, its ends or rails move up and down through the water, so the same wave-making and plate drag that damp heave also damp rotation. That means rotational damping is not independent of vertical damping; the per-point form in 6.9 gets it from one set of numbers. The yaw factor is small on purpose: the fin (section 4) and the hull's lateral drag do the yaw damping.

Unity's rigid body also had built-in angular damping 0.3 /s (WindsurferSetup.cs:691, MainScene.unity:216) and zero linear damping; the hull-drag model adds its own speed-dependent angular damping and a second vertical damper (AdvancedHullDrag.cs:44, 253-270: 600 N·s/m × s, doubled when planing and more than 40 % under). Those belong to section 5, but Phase 2 should have **one** vertical damping model, in this section, not two.

#### 6.6 Static equilibrium (worked out for the default configuration)

At rest on flat water the buoyancy equals the weight, so the submerged volume is `m / rho_water` exactly (this is Archimedes; the sample model reproduces it exactly as long as every wet column is in its linear range, which is the case here):

| Total mass | Weight | Submerged volume | `submersion_ratio` | Body origin below the water | Bottom depth at the middle row |
|---|---|---|---|---|---|
| 90 kg (plan's 75 + 15) | 882.9 N | 87.8 L | 0.732 | 0.0444 m | 0.1044 m |
| 91 kg (legacy Rigidbody / HullConfiguration) | 892.7 N | 88.8 L | 0.740 | 0.0454 m | 0.1054 m |
| **94 kg (what the legacy actually ran, BoardMassConfiguration 8 + 6 + 80)** | **922.1 N** | **91.7 L** | **0.764** | **0.0483 m** | **0.1083 m** |
| 95 kg (serialized `_totalMass`, overwritten at start) | 932.0 N | 92.7 L | 0.772 | 0.0493 m | 0.1093 m |

Per row at 94 kg, level, origin 0.0483 m under: depth / fraction / force per row from bow to tail = 0.0283 m / 0.236 / 25.0 N; 0.0728 / 0.606 / 97.2 N; 0.0994 / 0.829 / 175.0 N; 0.1083 / 0.903 / 227.6 N; 0.1061 / 0.884 / 186.7 N; 0.0994 / 0.829 / 132.8 N; 0.0883 / 0.736 / 77.9 N. Sum 922.1 N. The bow tip is only 2.8 cm wet because of the nose rocker; the deck at the middle is 1.2 cm above the water. "About three quarters submerged at rest" is correct physics for a 120 L board carrying 94 kg (REBUILD_PLAN.md, pitfall 8), not a bug, and the spec does not fight it.

The centre of buoyancy is slightly aft of the origin (the nose rocker lifts the bow columns out of the water), at body y = −0.049 m. With the legacy centre of mass at body (0, +0.15, +0.10) (converted from Unity's (0, 0.15, −0.1), BoardMassConfiguration.cs:37, MainScene.unity:468, [flip] in z) the level board feels a residual bow-down torque of −8.5 N·m, and settles at a static trim of 0.10° bow-down. That is level for all practical purposes.

#### 6.7 Restoring moments for a small tilt (metacentric reasoning with the grid)

While a column is in its linear range (0 < depth < T) it acts like a spring with stiffness `k_i = rho_water · g · sample_volume_m3[i] / T` (N per metre of depth). Equivalently, `A_i = sample_volume_m3[i] / T` is the piece of waterplane area that column stands for; ΣA_i = 1.0 m².

Tilt the body by a small angle θ about the centre of mass. Point i at body offset `r_i = sample_points[i] − com_body` moves vertically by `−(r_i.z) · θ` for pitch (bow up, positive about +X) and by `−(r_i.x) · θ` for a heel to starboard (positive about the bow axis, i.e. negative about +Z). Its force changes by `k_i` times that, and the torque of the existing forces changes because their arm rotates. Adding both up gives, for small angles:
```
K_pitch = rho_water · g · Σ A_i · (r_i.z)²  −  m · g · BG        # N·m per rad, restoring, bow up ↔ bow-down torque
K_roll  = rho_water · g · Σ A_i · (r_i.x)²  −  m · g · BG        # N·m per rad, restoring
BG      = com_body.y − y_centre_of_buoyancy                        # height of the COM above the centre of buoyancy, m
```
This is exactly the naval-architecture formula `K = m · g · GM` with `GM = BM − BG` and `BM = I_waterplane / V_submerged`: the first term is the waterplane inertia (the wide, long shape resists tilting), the second is the destabilising effect of a centre of mass above the centre of buoyancy.

For the default board, 94 kg, COM at body (0, 0.15, 0.10):

| Quantity | Pitch | Roll |
|---|---|---|
| Σ A_i (r_i)² (equivalent waterplane inertia) | 0.5294 m⁴ | 0.0493 m⁴ |
| BM = that / 0.0917 m³ | 5.77 m | 0.537 m |
| BG | 0.199 m | 0.199 m |
| GM | 5.57 m | 0.338 m |
| Waterplane term rho·g·ΣA r² | 5323 N·m/rad | 495.6 N·m/rad |
| Weight term m·g·BG | 183.5 N·m/rad | 183.5 N·m/rad |
| **Net stiffness K** | **5140 N·m/rad** (−98 N·m at 1°, after subtracting the −8.5 N·m level residual: −89.7 N·m ≈ 5140 × 0.01745) | **312 N·m/rad** (5.45 N·m at 1°) |

Checked numerically by rotating the grid about the COM at fixed height: 1° bow-up gives −98.2 N·m about +X (bow-down, restoring; the level residual is −8.5 N·m) and the total force drops to 904 N; 1° heel to starboard gives +5.45 N·m about +Z (restoring, i.e. toward port), 3° gives +15.4 N·m. For 90 kg: K_roll = 320 N·m/rad, K_pitch = 5147 N·m/rad. For a rectangle of the same size the waterplane inertia would be `L·W³/12` = 0.045 m⁴ (roll) and `W·L³/12` = 0.78 m⁴ (pitch), so the 21-point grid is a fair stand-in for a real tapered planform.

The roll stiffness is small on purpose: a windsurf board is narrow. A 312 N·m/rad stiffness means a 75 kg sailor standing 0.10 m off the centreline (74 N·m) heels the board 13.5°. And it depends strongly on the COM height: with the sailor's true COM near 0.45 m above the deck (BoardMassConfiguration.cs:114-123 computes (0, 0.457, −0.013) before the override), BG becomes 0.51 m, GM ≈ 0.03 m and the board is nearly neutral in roll, which is why a real windsurfer has to balance. The choice of COM height belongs to the mass model (section 7); the buoyancy tests below should read the COM from the config rather than hard-code it.

#### 6.8 The older `BuoyancyBody.cs` model (history only)

`BuoyancyBody.cs` (all lines 1-244) is a spring float, not Archimedes: four points at 40 % of the collider's half-extents and 30 % of the half-height below the collider centre (BuoyancyBody.cs:110-117); per point a force `1500 N · clamp(depth / 0.2 m, 0, 1) / 4` straight up (BuoyancyBody.cs:170-175) and a damping force `−v_point · 100 · clamp(depth/0.2) / 4` using the velocity of that point (BuoyancyBody.cs:178-180); `SubmergedPercentage` is the fraction of wet points, not a volume (BuoyancyBody.cs:185); and the angular velocity is multiplied by `(1 − 1.5 · dt)` each step while wet (BuoyancyBody.cs:192). Its total upward force is capped at 1500 N regardless of the board volume, so it cannot get the floating depth right. It was replaced in Session 22 (PROGRESS_LOG.md:345-364) and survives only as a fallback in AdvancedHullDrag (AdvancedHullDrag.cs:77, 86-87, 126-129) and in the "Add Components" helper of the wizard (WindsurferSetup.cs:1301-1309); scene_config.json (2025-12-27) describes this component (lines 36-44). The one idea worth keeping from it is damping each sample point with **that point's own velocity** (6.9), which gives rotational damping for free. The Session 13 predecessor of AdvancedBuoyancy also had a float-height stabiliser (`git show ca7a7b1`, lines 208-216: depth/0.3 m and an extra force toward a target height); gone since Session 22.

### Values

Three legacy sources exist for every number: the C# field default, the wizard `WindsurferSetup.cs` (`FindProperty`), and the saved scene `MainScene.unity`. **The scene file does hold serialized component values** (MainScene.unity:245-259 for AdvancedBuoyancy), and in Unity a serialized value overrides the C# default; the C# default is only used for a field that is missing from the scene. The wizard values and the scene values agree everywhere for this component.

| Name | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `board_volume_m3` | 0.120 (120 L) | m³ | AdvancedBuoyancy.cs:33; WindsurferSetup.cs:709; MainScene.unity:246; converted at :110 | none |
| `board_length_m` | 2.5 | m | AdvancedBuoyancy.cs:36; WindsurferSetup.cs:710; MainScene.unity:247 | BoardMassConfiguration uses 2.4 (BoardMassConfiguration.cs:44, WindsurferSetup.cs:783, MainScene.unity:470); the old board mesh is 2.28 m (REBUILD_PLAN.md Phase 6 notes). Buoyancy used 2.5. |
| `board_width_m` | 0.6 | m | AdvancedBuoyancy.cs:39; WindsurferSetup.cs:711; MainScene.unity:248 | none (mesh is 0.80 m wide, plan Phase 6) |
| `board_thickness_m` | 0.12 | m | AdvancedBuoyancy.cs:42; WindsurferSetup.cs:712; MainScene.unity:249 | none |
| `nose_rocker_m` | 0.08 | m | AdvancedBuoyancy.cs:45; WindsurferSetup.cs:713; MainScene.unity:250; PHYSICS_DESIGN.md:118 | none |
| `tail_rocker_m` | 0.02 | m | AdvancedBuoyancy.cs:48; WindsurferSetup.cs:714; MainScene.unity:251; PHYSICS_DESIGN.md:119 | none |
| `length_samples` × `width_samples` | 7 × 3 | – | AdvancedBuoyancy.cs:52-55; WindsurferSetup.cs:715-716; MainScene.unity:252-253 | docs diagram shows a 2-point tail row (PHYSICS_DESIGN.md:88-104): not in code |
| width taper | `1 − 0.3·d²` | – | AdvancedBuoyancy.cs:173 | PHYSICS_DESIGN.md:122 says "taperFactor 0.5": not in code |
| volume taper | `1 − 0.4·d` | – | AdvancedBuoyancy.cs:177 | PHYSICS_DESIGN.md:125 lists explicit weights: not in code |
| full-submersion depth | = `board_thickness_m` | m | AdvancedBuoyancy.cs:244 | Session 13 used 0.3 m (`git show ca7a7b1`, line 210) |
| `rho_water`, `g` | 1025, 9.81 | kg/m³, m/s² | PhysicsConstants.cs:13, 18; PHYSICS_DESIGN.md:76-81 | none |
| `c_vert_linear` | **800** (validated) | N·s/m | scene: MainScene.unity:254 (unchanged since Session 22, `git log -S`); wizard: WindsurferSetup.cs:717 | C# default 8000 (AdvancedBuoyancy.cs:59; was 800 in Session 22, 4000 in Session 24 `fa79027`, 8000 from the Session 25 save point `c62f577`); docs say 4000 (PHYSICS_DESIGN.md:131, :572; PHYSICS_VALIDATION.md:361; PROGRESS_LOG.md:253) and KNOWN_ISSUES.md:104 says 8000. **Because the scene serialized 800 in Session 22 and never changed, every play-test from Session 22 to 27 ran with 800.** The 4000/8000 changes only touched the C# default and never reached the scene. |
| `c_vert_viscous` | **800** (repository; 400 in the Session 26 commit) | N·s²/m² | scene: MainScene.unity:255 → see note; C# default AdvancedBuoyancy.cs:62 | The wizard never sets it (WindsurferSetup.cs:707-720). The field did not exist in the scene until Session 26, so the C# default applied: 400 during Session 24 (`fa79027`), 800 from the Session 25 save point. The Session 26 commit `b5ed2ea` saved 400 into the scene, and `dfbc3a0` (same evening, 2 Jan 2026) set it to 800, the value in MainScene.unity:255 now. Docs say 400 (PHYSICS_DESIGN.md:132, :573; PHYSICS_VALIDATION.md:362; PROGRESS_LOG.md:254); KNOWN_ISSUES.md:104 says 800. Most likely last validated value: 800. |
| vertical force cap | ±15 000 | N | AdvancedBuoyancy.cs:335 | none |
| vertical dead band | 0.01 | m/s | AdvancedBuoyancy.cs:323 | none |
| `c_rot` | 150 | N·m·s/rad | AdvancedBuoyancy.cs:65; WindsurferSetup.cs:718; MainScene.unity:256 | docs list "roll 150, pitch 150" (PHYSICS_DESIGN.md:133-134) without the multipliers below |
| rotational multipliers pitch / yaw / roll | 4.0 / 0.3 / 3.0 | – | AdvancedBuoyancy.cs:376-378 | Session 22: 1.5 / 0.3 / 1.2 (`5a1857a` lines 356-358, then × s); Session 24: 2.0 / 0.3 / 1.5 with the 0.3 floor (`fa79027` lines 376-385); Session 26 raised pitch to 4.0 and roll to 3.0 against porpoising (comments at AdvancedBuoyancy.cs:376, 378) |
| rotational floor | 0.3 | – | AdvancedBuoyancy.cs:369-370 | added in Session 24 (`fa79027` line 376) |
| `c_horizontal` (× 2 in the formula) | 20 (→ 40) | N·s/m | AdvancedBuoyancy.cs:68, 353; WindsurferSetup.cs:719; MainScene.unity:257 | none |
| damping gate | `submersion_ratio ≥ 0.05` | – | AdvancedBuoyancy.cs:314 | none |
| `is_floating` threshold | 0.1 N (total), 0.1 N per point for application | N | AdvancedBuoyancy.cs:269, 300 | none |
| total mass (for the equilibrium numbers) | **94** (runtime) | kg | BoardMassConfiguration.cs:110 sums 8 + 6 + 80 (MainScene.unity:465-467, WindsurferSetup.cs:780-782) and writes it to the Rigidbody at start (BoardMassConfiguration.cs:191) | Rigidbody serialized 91 (WindsurferSetup.cs:689, MainScene.unity:214); `_totalMass` serialized 95 (WindsurferSetup.cs:779, MainScene.unity:464) but recomputed; HullConfiguration 8 + 8 + 75 = 91 (SailingState.cs:220-231, WindsurferSetup.cs:768-770); docs 90 (PROGRESS_LOG.md:450); plan 75 + 15 = 90. Section 7 decides; this section's tests read the config. |
| centre of mass (body frame, D4) | (0, +0.15, +0.10) | m | BoardMassConfiguration.cs:37, :127-131 (override applies); MainScene.unity:468; Unity z −0.1 [flip] → +0.10 (aft) | shifts aft and down with planing (BoardMassConfiguration.cs:222-228), section 7 |
| initial drop height | body origin at y = 0.5 m | m | WindsurferSetup.cs:683; MainScene.unity:391 | none; a drop test should start there |


### Where the force acts

- Each buoyancy force `point_force[i]` is applied **at its own sample point** `p_world_i` (AdvancedBuoyancy.cs:298-305, `AddForceAtPosition`). In Phase 2: `body.add_force_at(p_world_i, point_force[i])`. The torque about the centre of mass is `(p_world_i − com_world) × point_force[i]`, summed over the points; this is what produces the pitch and roll stiffness of 6.7. Never apply the summed force at the centre of buoyancy: the sum is correct, but the torque would only be correct if the forces were parallel, and a single point loses the per-point clipping that makes the model behave when the bow lifts out.
- The sample points are defined relative to the **body origin** (mid-thickness of the hull box), not the centre of mass. The legacy COM sat at body (0, +0.15, +0.10): 0.15 m above the origin and 0.10 m aft. Relative to the COM the middle row is at (±0.3, −0.21, −0.10). Phase 2 keeps the points in origin coordinates and lets the rigid body do the COM offset, as Unity did.
- The vertical damping force and the lateral damping force are applied at the centre of mass (`AddForce`, AdvancedBuoyancy.cs:337, 358) and produce no torque. The rotational damping is a pure torque (AdvancedBuoyancy.cs:383). With the per-point scheme of 6.9 the damping acts at the sample points instead and its torque comes out of the cross product like the buoyancy torque.

### Signs and the Unity-to-Godot translation

| Quantity | Godot (D4) | Unity legacy | Flip? |
|---|---|---|---|
| Row position along the length | `z_i = +L/2 − L·t_i`; bow row z = −1.25 m, tail row +1.25 m | `z = Lerp(−L/2, +L/2, t)`, bow at +1.25 m (AdvancedBuoyancy.cs:153-155) | **yes**: `z_godot = −z_unity` |
| "Forward half uses the nose rocker" | `t_i > 0.5` ⇔ `z_i < 0` | `lengthT > 0.5` ⇔ z > 0 (:161) | test on `t_i`, not on the sign of z, and it carries over unchanged |
| Rail position across | `x = ±half_width`, +X = starboard | same (:182) | no |
| Height of the bottom | `y = −T/2 + rocker`, +Y up | same (:185) | no |
| Depth | `h_water − p_world.y` | same (:235) | no |
| Force direction | along `water.normal_at`, `Vector3.UP` on flat water | same (:255-256) | no |
| Water normal from finite differences | analytic: `Vector3(−dh/dx, 1, −dh/dz).normalized()`; if a cross product is used, `tangent_z.cross(tangent_x)` gives +Y in a right-handed frame, and a unit test must confirm `normal_at` on flat water is exactly `Vector3.UP` | `Cross(tangentZ, tangentX)` (WaterSurface.cs:194-197) | Unity's Cross uses the same component formula as Godot's, so the same order happens to work; do not rely on that, test it |
| Vertical velocity | `v_boat.y` | `linearVelocity.y` (:322) | no |
| Lateral velocity | `(basis.transposed() * v).x`, + = to starboard | `InverseTransformDirection(v).x` (:348) | no |
| Pitch rate ω_x | positive = bow **up** | positive = bow **down** (bow is +Z: rotating +X lowers +Z) | **yes**, but damping is `−c·ω` so the coefficient carries over unchanged |
| Yaw rate ω_y | positive = bow to **port** (shared notation) | positive = bow to **starboard** | **yes**, same remark |
| Roll rate ω_z | positive = starboard rail up = heel to **port** | positive = heel to port as well (+X rail rises with a positive rotation about +Z in both engines) | no |
| Rotational damping axes | x = pitch ×4.0, y = yaw ×0.3, z = roll ×3.0 (the pitch axis is +X and the roll axis is the Z line in both engines) | same components (:375-379). The Session 24 comment "Roll (X) … Pitch (Z)" at `fa79027` lines 379-381 was wrong; Session 26 relabelled x = pitch, z = roll, which matches the code | no |
| Heel angle `heel_rad` (positive = to starboard) | a positive rotation about the bow axis −Z, i.e. `−rotation about +Z`; the restoring torque for a starboard heel is **positive about +Z** (+5.45 N·m at 1°) | – | define once in the integrator and pin with a test |
| Pitch angle `pitch_rad` (positive = bow up) | positive rotation about +X; the restoring torque for bow-up is **negative about +X** (−98 N·m at 1°) | – | same |
| Body ↔ world | `p_world = position + basis * p_body`; `v_body = basis.transposed() * v_world` | `TransformPoint`, `InverseTransformDirection` (:229, :348, :365) | no |

### Stabilisers and fudges in this model

1. **Planing buoyancy reduction (removed).** `buoyancy_scale = 1 − 0.3 · planing_ratio` when `planing_ratio > 0.1`, multiplied into every point force (Session 22, `git show fa79027`, lines 294-311; comment "reduce buoyancy contribution to avoid excessive height"). Removed at the Session 25 save point `c62f577` and noted in KNOWN_ISSUES.md:102 ("pure Archimedes"). It hid that planing lift was being added on top of full buoyancy and that the lift depended on submersion (the trampoline, KNOWN_ISSUES.md:179, PROGRESS_LOG.md:219-247). **Drop.** Buoyancy is Archimedes; when planing lift raises the hull, less volume is wet and buoyancy falls by itself (comment at AdvancedBuoyancy.cs:294-297). The now-unused `_hullDrag` reference (AdvancedBuoyancy.cs:76, 107) is a leftover of this.
2. **Linear vertical damping 800 → 4000 → 8000.** Session 22: 800; Session 24: 4000 and the viscous term (symptom "water feels too bouncy", KNOWN_ISSUES.md:180, PROGRESS_LOG.md:253); Session 25: 8000 ("more stable water contact", KNOWN_ISSUES.md:104). Part of it is physics (wave radiation and added mass, see 6.5), but the increases were reactions to the trampoline, whose cause was in the planing model. And as the Values table shows, **the scene kept 800 the whole time**, so the validated behaviour never depended on the higher values. **Keep a linear term as a physics stand-in, start at 800 N·s/m (ζ ≈ 0.3), and re-evaluate in Phase 4** with the drop test (below). Do not start at 4000 or 8000: they overdamp the heave and make the board feel glued to the water.
3. **Viscous vertical damping 400 / 800.** Added in Session 24. Its size matches flat-plate drag (about 720 N·s²/m² at full submersion, 6.5), so it is **physics: keep**, at 800 N·s²/m² × `submersion_ratio`. It also does most of the work at speed: at 2 m/s vertical it gives 4× the linear term.
4. **±15 000 N cap** (AdvancedBuoyancy.cs:335). A safety clamp against solver blow-ups; with 800/800 it only bites above 4.5 m/s of vertical speed. **Drop** in Phase 2 (fixed substeps and per-point forces make it unnecessary); if a test shows a blow-up, fix the time step instead.
5. **Dead bands** `|v_y| > 0.01`, `|v_h|² > 0.01`, `|ω|² > 0.001` (AdvancedBuoyancy.cs:323, 345, 362) and the **5 % submersion gate** (:314). Numerical guards; the formulas are continuous at zero and already scale with `submersion_ratio`, so the gates only add tiny discontinuities. **Drop** all of them (damp whenever `submersion_ratio > 0`).
6. **Rotational damping 150 × (4.0, 0.3, 3.0) with a 0.3 floor.** Session 22 had 1.5 / 0.3 / 1.2 scaled by `s`; Session 24 raised them and added the floor because damping "was near-zero when planing" (comment at :381); Session 26 doubled pitch and roll against porpoising (KNOWN_ISSUES.md:83, :376-378). The floor makes a hull that is 5 % wet damp at 33 % strength, which is not physical, and the pitch/roll numbers were tuned against a symptom whose cause was elsewhere (planing lift point and sail downforce, section 5 and 3). With Unity's automatic inertia the roll inertia was only about 2.9 kg·m² (box 0.6 × 0.12 × 2.5 at 94 kg), so 450 N·m·s/rad meant a roll damping ratio above 6; anything would have looked "stable". **Re-evaluate: drop the lumped rotational damping and get pitch and roll damping from the per-point vertical damping (6.9).** Yaw damping is the fin's job; add an explicit yaw term only if a Phase 4 test asks for it.
7. **Lateral damping 40 · |v_x| · s.** Linear, small (30 N at 1 m/s) and overlapping with hull drag. **Drop**; the hull-drag model (section 5) should carry a quadratic lateral drag of the wet hull instead.
8. **Second vertical damper in hull drag** (`_submersionVerticalDamping` 600 N·s/m × s, ×2 when planing and > 40 % wet, AdvancedHullDrag.cs:44, 253-270). Two dampers on the same motion in two files were tuned blind against each other. **Drop it there** (section 5 to confirm) so that this section is the only vertical damping.
9. **Force along the water normal.** Not a fudge: keep (6.3).
10. **Legacy `BuoyancyBody` constants** (1500 N, 0.2 m, 100, 1.5): history, not to be ported (6.8).

#### 6.9 Recommended Phase 2 damping scheme (per sample point)

To avoid re-tuning three separate dampers, apply the damping at the sample points, using each point's own vertical velocity and its share of the volume. One pair of coefficients then damps heave, pitch and roll consistently, and the wet/dry state of each point handles "barely wet" automatically:
```
for each sample point i with v_sub_i > 0:
    w_i        = v_sub_i / board_volume_m3                              # this point's wet share, Σ w_i = submersion_ratio
    v_point    = v_boat + omega_world.cross(p_world_i − com_world)       # velocity of the point
    v_n        = v_point.dot(n_water_i)                                  # speed along the water normal (vertical on flat water)
    f_damp_i   = −(c_vert_linear · v_n + c_vert_viscous · v_n · |v_n|) · w_i
    body.add_force_at(p_world_i, n_water_i · f_damp_i)
```
Summed over a level, purely heaving board this is exactly the legacy vertical damping (`Σ w_i = s`). For a pure pitch rate it gives an effective pitch damping of `c_vert_linear · Σ w_i (r_i.z)²` ≈ 800 × 0.529 × 0.76 ≈ 320 N·m·s/rad plus the viscous part, and a roll damping of 800 × 0.0493 × 0.76 ≈ 30 N·m·s/rad: pitch is damped about as much as the legacy 500, roll far less (a flat board really does roll easily; the sailor and the sail damp roll in reality). The lumped legacy scheme of 6.5 stays documented above as the fallback if Phase 4 shows the per-point version needs help.

OPEN: the legacy model has no heave added mass. For a wide flat hull the water that moves with it in heave is of the order of the hull's own mass or more, which lengthens the bobbing period and changes what "critically damped" means. Phase 2 should start without added mass (as the legacy did and as the integrator in Phase 2 assumes); if the Phase 4 drop test bobs too fast compared with what the team expects, adding a heave added-mass term (or simply raising `c_vert_linear`) is the place to look.

### What Phase 2 must implement

- [ ] `BoardConfig` fields: `volume_m3` (0.120), `length_m` (2.5), `width_m` (0.6), `thickness_m` (0.12), `nose_rocker_m` (0.08), `tail_rocker_m` (0.02), `length_samples` (7), `width_samples` (3); `WaterConfig` fields: `density_kg_m3` (1025), `damping_linear_ns_m` (800), `damping_viscous_ns2_m2` (800). All in `.tres` files, none in code.
- [ ] A `WaterSurface` interface with `height_at(x, z) -> float` and `normal_at(x, z) -> Vector3`; a `FlatWater` implementation (constant height, `Vector3.UP`). Phase 5 swaps in the Gerstner field.
- [ ] `Buoyancy` (RefCounted): builds the 21 sample points and volumes from the config with the formulas of 6.1 (D4 frame: bow row at z = −L/2), normalises the volumes to the total.
- [ ] `Buoyancy.compute(state, water)`: per-point depth, clamped fraction, `v_sub_i`, force along the normal (6.3); totals `submerged_volume_m3`, `submersion_ratio`, `is_floating`, `buoyancy_force_total` (6.4); per-point application through `body.add_force_at` (never at the centre).
- [ ] Damping: the per-point scheme of 6.9 (recommended) with the linear and viscous coefficients scaled by the wet share; no cap, no dead bands, no 5 % gate, no lumped rotational or lateral damping. Keep the lumped legacy formulas of 6.5 in a comment or a second function only if Phase 4 asks for them.
- [ ] Telemetry: `submersion_ratio` (as %), `submerged_volume_m3` (as L), `buoyancy_force_total` (N), and the per-point depths for a debug view.
- [ ] Nothing in this model reads `planing_ratio` or anything from the hull-drag model (the removed reduction stays removed).
- [ ] Update `Documentation/PHYSICS_SPEC.md` (this section) with any coefficient change from Phase 4, with the reason.

### Tests Phase 2 should write

Use the default config (120 L, 2.5 × 0.6 × 0.12 m, rocker 0.08 / 0.02) and read the total mass and COM from the config. Expected values below are for 94 kg with the COM at body (0, 0.15, 0.10); for 90 kg use the 6.6/6.7 tables.

- **Grid geometry.** 21 points; Σ `sample_volume_m3` = 0.120 ± 1e-9; the bow row is at z = −1.25 m and y = +0.020 m, the tail row at z = +1.25 m and y = −0.040 m, the middle row at y = −0.060 m with x = ±0.300 m; row volumes 10.53 / 15.93 / 21.00 / 25.07 / 21.00 / 15.93 / 10.53 L (±0.01 L); the bow-tip point volume is 3.510 L and the middle-row point 8.357 L.
- **Archimedes for one point.** Middle-centre point 0.06 m under on flat water: `fraction` 0.5, force = 1025 × 9.81 × 0.008357 × 0.5 = 42.0 N straight up; at 0.12 m and at 0.5 m the force is 84.0 N (clamped); at −0.01 m it is 0.
- **Fully dry.** Body 1 m above the water: `submersion_ratio` 0, `is_floating` false, no force, no damping.
- **Static equilibrium (the plan's test).** Start level at the drop height (origin 0.5 m up), let it settle for 5 s of simulated time: submerged volume = 94 / 1025 = 91.7 L (± 2 %), `submersion_ratio` 0.764 ± 0.015, origin 0.048 m below the water (± 0.005), pitch within 0.5° of level (the model's own static trim is 0.10° bow-down), roll 0. The same with 90 kg: 87.8 L, 0.732.
- **Level trim residual.** Held level at the equilibrium height, the summed buoyancy torque about the COM is −8.5 N·m about +X (± 1 N·m) and 0 about +Z.
- **Pitch stiffness.** Held at the equilibrium height and pitched 1° bow-up about the COM: total force 904 N (± 2 %), torque about +X = −98 N·m (± 5 %), i.e. (−98 − (−8.5)) / 0.01745 ≈ −5140 N·m/rad restoring. Bow-down 1° gives the opposite sign of the difference.
- **Roll stiffness.** Held at the equilibrium height and heeled 1° to starboard: torque about +Z = +5.45 N·m (± 5 %), 3° gives +15.4 N·m; heeled to port the sign flips. Restoring means positive about +Z for a starboard heel (D4 rows in the Signs table).
- **Rights itself (the plan's test).** Released at 10° heel from the equilibrium height with the default damping, the heel angle passes through zero and stays below 1° after 5 s; the same from 5° bow-up.
- **Drop test and damping ratio.** Dropped from the 0.5 m start with 800 / 800: the height overshoots below equilibrium at most twice by a visible amount and is within 5 mm of equilibrium after 3 s; the heave period on the way is about 0.6 s. With `damping_linear_ns_m` = 0 and viscous 0 the same drop keeps oscillating (energy check: the amplitude after 3 s is more than half the initial one).
- **Damping values (per-point scheme, level board, pure heave).** At the equilibrium depth and `v_boat = (0, −0.5, 0)`: Σ damping force = +(800 × 0.5 + 800 × 0.25) × 0.764 = 458 N up (± 1 %); at −2 m/s: 3667 N. With the lumped legacy formula the same numbers apply (this is the cross-check between the two schemes). Pure pitch rate 0.5 rad/s, no heave: Σ damping torque about +X ≈ −(800 × 0.529 × 0.764 × 0.5) − viscous part, i.e. between −170 and −200 N·m; sign opposite to ω_x.
- **Legacy lumped values (only if the fallback is implemented).** Pitch rate 0.5 rad/s at s = 0.764: −250.5 N·m about +X; roll 0.5 rad/s: −187.9 N·m; yaw 0.5 rad/s: −18.8 N·m; sideslip 1 m/s to starboard: −30.6 N along body +X.
- **No feedback from planing.** Setting `planing_ratio` to 1 in the state changes nothing in the buoyancy output (guards against re-introducing fudge 1).
- **Normal on flat water.** `FlatWater.normal_at` returns exactly `Vector3.UP`; the force of a submerged point is exactly vertical.
- **Determinism.** Two runs of the drop test give identical telemetry.

### Sources

- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs` (all 470 lines): fields 28-72; grid 134-204; per-point buoyancy 219-284; force application 290-306; damping 312-385; height query 390-394; gizmos 396-468.
- History of the same file (`git show <commit>:WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs`): `ca7a7b1` Session 13 (lines 195-225: depth/0.3 model and float-height force); `5a1857a` Session 22 (59-65 damping 800/150/20; 291-302 planing reduction; 356-358 rotational 1.5/0.3/1.2 × s); `fa79027` Session 24 (59-68 damping 4000/400/150/20; 294-311 planing reduction; 342 cap; 376-385 rotational 2.0/0.3/1.5 with 0.3 floor); `c62f577` Session 25 save point (59-62 8000/800; reduction removed); `b5ed2ea` Session 26 (376-378 pitch 4.0, roll 3.0).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/BuoyancyBody.cs` 1-244 (spring float model; 110-117 points, 170-180 force and damping, 185 percentage, 192 angular damping).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Water/IWaterSurface.cs` 1-34; `WaterSurface.cs` 50, 168-197 (height and normal), 237-246 (default waves), 643-644 of the scene for base height 0 and waves on.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs` 13, 18.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs` 39-44, 72-73, 76-77, 86-87, 139-149, 211-271, 328-357, 393-399 (consumers of `IsFloating` and `SubmergedRatio`; the second vertical damper).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs` 24-37, 107-131, 186-205, 210-229 (mass 94 kg, COM (0, 0.15, −0.1) in Unity coordinates, dynamic shift).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs` 203-241 (`HullConfiguration`, TotalMass 91).
- `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs` 683 (start height), 689-691 (Rigidbody 91 kg, angular damping 0.3), 704-720 (AdvancedBuoyancy values), 763-771 (HullConfiguration), 776-788 (BoardMassConfiguration), 1301-1309 (legacy BuoyancyBody helper).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` 207-232 (Rigidbody), 245-259 (AdvancedBuoyancy), 283-293 (hull-drag submersion values), 391 (start position), 464-476 (BoardMassConfiguration), 643-644 (water). Git: `_verticalDamping: 800` present since `5a1857a`; `_waterViscosity` absent until `b5ed2ea` (400), then `dfbc3a0` (800).
- `Legacy/Documentation/PHYSICS_DESIGN.md` 69-157 (section 2: 71-82 Archimedes, 84-110 grid diagram, 112-126 hull shape with the wrong taper/weights, 128-141 damping 4000/400/150), 571-575 (parameter list), 588-597 (trampoline note).
- `Legacy/Documentation/PHYSICS_VALIDATION.md` 335-341 (no submersion feedback), 344-366 (section 12, damping 4000/400, vertical only), 368-376 (section 13).
- `Legacy/Documentation/KNOWN_ISSUES.md` 94-106 (Session 25: reduction removed, 8000/800), 108-133 (Session 23 submersion fix), 177-186 (Session 24 and 23 notes), 188-193 (Session 22).
- `Legacy/Documentation/PROGRESS_LOG.md` 215-275 (Session 24), 337-452 (Session 22: buoyancy rewrite, parameters table at 441-451), 455-503 (Session 21), 505-552 (Session 20); Sessions 23 and 25 have no entry in the log (only in KNOWN_ISSUES.md).
- `Legacy/Documentation/scene_config.json` 36-44 (BuoyancyBody, 2025-12-27, history only).
- `Documentation/REBUILD_PLAN.md`: D4 table (57-71), Phase 1 tasks (117-149), pitfalls 3-5 and 8 (290-299).
- Literature: Archimedes' principle and metacentric stability (GM = BM − BG, BM = I/V) from any naval-architecture text, e.g. Lewis (ed.), *Principles of Naval Architecture*, SNAME, vol. I, ch. 2 (cited by the legacy header at AdvancedBuoyancy.cs:22); flat-plate normal drag coefficient ≈ 1.1-1.3 from Hoerner, *Fluid-Dynamic Drag*, ch. 3; heave added mass and radiation damping: Newman, *Marine Hydrodynamics*, ch. 6 (the reason a linear vertical damping term is physically justified).

---

## 7. Mass, inertia and the sailor's centre of mass

### Purpose

Everything the wind and water push on (board, rig, sailor) is simulated as one rigid body. This section says how heavy that body is, where its centre of mass (COM) sits, and how hard it is to rotate about each axis (the inertia tensor). It also describes the one thing that makes a windsurfer different from a boat: most of the mass is a person who moves. The sailor steps back into the straps when the board starts planing, crouches, and leans out to windward to balance the sail. Moving the sailor moves the COM, and because every force turns the body about the COM, a COM shift changes the lever arm of every force in the other sections.

In Unity, most of this was done by the engine: `Rigidbody.mass`, `Rigidbody.centerOfMass`, an inertia tensor computed from the box collider, and a small built-in angular damping. Phase 2 has to do all of it in our own integrator (plan decision D2), so this section states exactly what the engine did and what we do instead.

Two facts to keep in mind while reading:

- The legacy setup wizard, the legacy component defaults and the legacy docs disagree on nearly every number here (90, 91, 94 and 95 kg for the total mass, 0.15 or 0.3 m for the planing shift, 6 or 8 kg for the rig). The Values table lists all of them with their sources and says what the last validated Unity build (Session 26, January 2026) most likely ran with.
- The legacy COM (0.15 m above the board's centre) is far too low for a system in which 80 of the 94 kg is a standing person. It was low because the legacy build applied the sail force at the board's origin (centre of effort set to (0,0,0), Session 25 and 26) and had no heeling physics to balance. Phase 2 must decide, together with the sail section, whether to keep that simplification or to model a real COM height plus a balancing sailor. This is OPEN (see the end of the section).

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `mass_board_kg` | Mass of the board (hull, straps, fin) | kg |
| `mass_rig_kg` | Mass of mast, sail, boom, extension and base | kg |
| `mass_sailor_kg` | Mass of the sailor with harness and wetsuit | kg |
| `mass_total_kg` | Sum of the three (output; never a separately tuned number) | kg |
| `board_length_m`, `board_width_m`, `board_thickness_m` | Box that stands in for the hull when computing its own inertia | m |
| `com_board`, `com_rig`, `com_sailor` | Position of each part's COM in the body frame, relative to the board origin (see 7.2) | m (Vector3) |
| `planing_ratio` | 0 = displacement sailing, 1 = fully planing; from the hull section (7.4) | - |
| `weight_shift` | Sailor's lateral weight position, -1 (fully to port) to +1 (fully to starboard); from the controller (7.5) | - |
| `planing_com_shift_aft_m`, `planing_com_shift_down_m` | How far the sailor's COM moves aft and down at `planing_ratio` = 1 | m |
| `weight_shift_max_m` | Lateral sailor COM offset at `weight_shift` = ±1 (proposal, see 7.5) | m |
| `com_offset` (output) | COM of the whole body in the body frame, relative to the board origin | m (Vector3) |
| `inertia_body` (output) | 3 x 3 inertia tensor about the COM, in body axes | kg m² |
| `inertia_body_inv` (output) | Its inverse, cached for the integrator | 1/(kg m²) |
| `f_gravity` (output) | Weight, world frame: `Vector3(0, -mass_total_kg * g, 0)`, applied at the COM | N |

### Formulas

#### 7.1 Total mass

```
mass_total_kg = mass_board_kg + mass_rig_kg + mass_sailor_kg
```

Plain physics: the three parts move together, so the body accelerates as one mass. The legacy `BoardMassConfiguration` also had a separate "total mass" field (default 95), but it overwrote it with this sum in `Awake()` (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs:110`), so the field was cosmetic. With the legacy parts (8 + 6 + 80) the sum is 94 kg, not 95; the "95kg" in the wizard's comments and log text (`WindsurferSetup.cs:25`, `849`) is simply wrong. Phase 2 must not have a separately editable total.

The weight is `mass_total_kg * g` with g = 9.81 m/s² (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:18`). The hull section's caps ("displacement lift at most 30 % of the weight", "planing lift at most `_maxLiftFraction` of the weight") used a *different* total mass: `HullConfiguration.TotalMass` = 8 + 8 + 75 = 91 kg (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:220-231`, used at `AdvancedHullDrag.cs:352` and `:448`). So the legacy build carried 94 kg while its lift caps were computed for 91 kg. In Phase 2 there is one `mass_total_kg` and every section reads it.

#### 7.2 Body frame and the board origin

D4 body frame: bow = -Z, starboard = +X, up = +Y. The **board origin** is the geometric centre of the hull box: mid-length, mid-width and mid-thickness. That is where the legacy `BoxCollider` was centred (`WindsurferSetup.cs:699-701`, size 0.6 x 0.12 x 2.5 m, centre (0,0,0)), so the deck is at y = +0.06 m and the bottom at y = -0.06 m. All positions below are relative to this origin, and all other sections (fin position, mast foot, buoyancy sample points) should use the same origin.

Unity-to-Godot note: Unity's bow is +Z, so every legacy z coordinate flips sign: legacy `(0, 0.15, -0.1)` ("0.1 m aft") becomes D4 `(0, 0.15, +0.1)`. x and y do not change.

#### 7.3 Centre of mass at rest

The COM of a set of parts is their mass-weighted average position:

```
com_offset = (mass_board_kg * com_board + mass_rig_kg * com_rig + mass_sailor_kg * com_sailor) / mass_total_kg
```

Physics: the body behaves as if all its mass were at this point. Gravity pulls at it, and forces applied elsewhere turn the body about it.

What the legacy code did (`BoardMassConfiguration.cs:112-131`), converted to D4:

| Part | Legacy position (Unity) | D4 position | Source |
|---|---|---|---|
| board | `(0, thickness/2, 0)` = (0, 0.06, 0) | (0, 0.06, 0) | `:114` |
| rig | `(0, 1.2 * 0.9, -0.2)` = (0, 1.08, -0.2) | (0, 1.08, +0.2) | `:117` |
| sailor | `(0, 0.5 * 0.9, 0)` = (0, 0.45, 0) | (0, 0.45, 0) | `:120` |

With 8, 6 and 80 kg the weighted average is (0, 0.457, -0.013) in Unity, i.e. D4 (0, 0.457, +0.013). **But this value was never used.** Lines 127-131 replace it with the inspector field `_centerOfMass` whenever that field is not exactly zero, and its default is (0, 0.15, -0.1) (`:37`; the scene file confirms `_centerOfMass: {x: 0, y: 0.15, z: -0.1}`, `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:468`). So the last build ran with:

```
com_base_legacy (D4) = Vector3(0.0, 0.15, +0.10)   # 0.15 m above the board centre, 0.10 m aft of it
```

Two remarks on the legacy positions:

- The sailor's COM at 0.45 m above the board is unphysical for a standing person (a 1.75 m person's COM is about 0.55 x height ≈ 0.96 m above the feet; literature: Winter, *Biomechanics and Motor Control of Human Movement*, segment tables). The 0.15 m override is lower still. It only "worked" because the legacy sail force acted at the origin and the roll physics were faked by the anti-capsize torque (7.9).
- The rig COM at 1.08 m is low for a 4.6 m mast. A rough physical estimate: sail cloth (≈4.5 kg, COM ≈1.8 m up the luff), mast (≈2 kg, ≈2.3 m), boom (≈2.8 kg, ≈1.4 m), base and extension (≈0.7 kg, ≈0.3 m) gives ≈1.7 m above the mast foot. These masses are estimates from typical product data, not legacy values.

**Spec proposal for Phase 2 (estimate, to confirm at the Phase 1 stop):**

| Part | Mass | D4 position at rest, no wind | Reason |
|---|---|---|---|
| board | 8 kg | (0, 0, 0) | Uniform box; its COM is the origin |
| rig | 7 kg | (0, 1.7, +0.1) | 1.7 m above the deck (estimate above), over the mast foot; the wizard's mast base is 0.1 m aft of the origin (`WindsurferSetup.cs:46`, Unity (0, 0.1, -0.1)) |
| sailor | 75 kg | (0, 1.0, 0) | Standing, COM ≈0.96 m above the feet, feet on the deck at +0.06 m |

This gives `mass_total_kg` = 90 kg and `com_offset` = (0, 0.966, 0.008) m. The 90 kg matches the plan's Phase 1 default ("75 kg sailor plus 15 kg of equipment", `Documentation/REBUILD_PLAN.md:146`) and the "120 L carrying 90 kg" check in pitfall 8 (`:299`). The 7 kg rig is the plan's 15 kg of equipment minus the 8 kg board; the legacy sources say 6 or 8. If the team prefers the legacy 94 kg (8 + 6 + 80), only the masses change; the formulas do not.

**Decision (section 14):** the default configuration is board 9 kg, rig 8 kg, sailor 75 kg (92 kg in total) on a 2.40 × 0.72 × 0.12 m hull, with the mast foot at (0, 0.06, −0.05). The worked numbers in this section use the 8 / 7 / 75 kg proposal above and the legacy 2.5 × 0.6 m box; they illustrate the method, and Phase 2 recomputes them from the config. With section 14's values and the same part positions (sailor at (0, 1.0, 0), rig at (0, 1.7, −0.05)) the composite gives `com_offset` ≈ (0, 0.963, −0.004) m and an inertia at rest of about pitch 50, yaw 6.2, roll 46 kg m².

#### 7.4 COM shift when planing

When the board starts planing the sailor moves aft into the back straps and lowers into the harness. Legacy (`BoardMassConfiguration.cs:210-229`), in D4:

```
planing_ratio  = clamp((speed_ms - 4.0) / (6.0 - 4.0), 0, 1)       # from the hull section, AdvancedHullDrag.cs:181-195
com_offset     = com_base + Vector3(0.0, -planing_com_shift_down_m, +planing_com_shift_aft_m) * planing_ratio
```

with `planing_com_shift_aft_m` = 0.15 (`:64`, `:222`; Unity z = -0.15 becomes D4 z = +0.15) and `planing_com_shift_down_m` = 0.1 (`:225`, hard-coded). At full planing the legacy COM was therefore at D4 (0, 0.05, +0.25).

Physics: this is real technique, not a fudge. Moving the mass aft moves the COM behind the centre of hydrodynamic lift, which trims the bow up (the Savitsky model in the hull section wants a positive trim angle), and lowering the body makes the sailor's weight act closer to the deck.

Details that matter:

- There is **no smoothing** in the legacy shift itself. `planing_ratio` is a piecewise-linear function of speed, so the COM moves smoothly with the speed. It was recomputed and written to `rb.centerOfMass` every physics step (`:96-102`, 50 Hz, `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset`, "Fixed Timestep: 0.02").
- `_dynamicCOM` was on (`:61`, wizard `:787`, scene `:475`).
- If the hull drag component was missing, `planing_ratio` was 0 and the COM stayed at the base (`:215-219`).
- In the spec the shift is applied to the **sailor's** position (`com_sailor`), not to the total COM, and the total is recomputed with 7.3. With a 75 kg sailor in a 90 kg body the total moves 75/90 of the sailor's shift: 0.15 m aft of sailor motion gives 0.125 m of COM motion. If the team wants the total COM to move exactly the legacy 0.15 m, set the sailor shift to 0.18 m. Recomputing from parts also keeps the inertia tensor consistent (7.6).
- The docs say 0.3 m aft (`Legacy/Documentation/PHYSICS_DESIGN.md:424`, `:557`; `Legacy/Documentation/PROGRESS_LOG.md:451`). The code never had 0.3: the file's only code commit (5a1857a, Session 22) already contains 0.15, and the scene file has `_planingCOMShift: 0.15` (`MainScene.unity:476`) in every commit. Use 0.15 as the validated value; 0.3 is a plausible physical value (feet move about 0.3-0.5 m back) to try in Phase 4.

#### 7.5 Lateral weight shift

**What the legacy code did.** There was no lateral COM shift at all. `BoardMassConfiguration` only shifts in y and z. The controller's "weight shift" (`Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs:238-270`) is a **pure yaw torque** applied about the world up axis; the magenta gizmo that draws a sideways lean (`:368-377`) is decoration. Converted to D4:

```
weight_target_deg   = smooth_weight_input * 20.0                                     # :49, :239
weight_deg          = move_toward(weight_deg, weight_target_deg, 4.0 * 20.0 * dt)    # :52, :240  (80 deg/s: full lean in 0.25 s)
if abs(weight_deg) < 0.5: no torque                                                  # :250
speed_factor        = clamp(speed_ms / 3.0, 0, 1)                                    # :260
torque_turn_right   = (weight_deg / 20.0) * 80.0 + (weight_deg / 20.0) * 30.0 * speed_factor   # :257, :261, :264   [N m]
torque_world        = Vector3(0, -torque_turn_right, 0)                              # D4: a positive (right-turning) torque is NEGATIVE about +Y in Godot
```

`smooth_weight_input` is the key input (-1, 0, +1) run through `move_toward` at 8 per second in the frame update (`:68`, `:200`), so it takes 0.125 s to reach full value. Maximum torque: 80 N m when stopped, 110 N m at 3 m/s and above. `weight_deg` is a nominal angle in degrees with no geometric meaning; nothing else reads it.

A legacy sign bug worth knowing: the controller inverts both the rake input and the weight input on port tack (`:158-169`, `steerDirection = -1`). Inverting the rake is right, because rake steering depends on the tack (`AdvancedSail.cs:452-459`, `:497-524`: torque = rake x tack x ...). Inverting the weight torque is wrong, because that torque is applied directly about the up axis with no tack factor. On starboard tack, D gives rake +1 (head up = turn right) and weight torque +Y in Unity (turn right): consistent. On port tack, D gives rake -1 (bear away = turn right) but weight torque -Y in Unity (turn left): the 80-110 N m weight torque fought the 200-350 N m rake torque. It was small enough that nobody noticed. Phase 2 must not copy this.

**Spec proposal.** Model weight shift as what it is physically: the sailor's COM moves sideways.

```
com_sailor.x = weight_shift * weight_shift_max_m        # weight_shift: -1 (port) .. +1 (starboard)
```

with `weight_shift_max_m` ≈ 0.5 m (estimate: a sailor hanging in the harness has the hips 0.4-0.8 m outboard of the rail). This produces a real roll moment (`mass_sailor_kg * g * x` ≈ 75 x 9.81 x 0.5 ≈ 370 N m at full lean), which is exactly what balances the sail's heeling moment in real windsurfing. It produces no yaw torque by itself; steering by heeling the board ("rail steering") is a hull effect and is left to the hull or rake sections, OPEN. Whether `weight_shift` comes from the player (advanced mode) or from an automatic balance rule in the sim (beginner mode, replacing the anti-capsize fudge in 7.9) is a controller decision for Phase 3; the mass model just takes the number.

#### 7.6 Inertia tensor

The inertia tensor says how much torque is needed for a given angular acceleration about each axis, the rotational equivalent of mass. Three versions exist; only the third is what Phase 2 should implement.

**(a) What Unity actually used: a uniform box.** `_useCustomInertia` was false (`BoardMassConfiguration.cs:54`, wizard `:786`, scene `:473`), so Unity/PhysX computed the tensor automatically from the only collider, a 0.6 x 0.12 x 2.5 m box, filled with uniform density and scaled to the Rigidbody mass. For a box of mass m and sides (a, b, c) along (x, y, z), the standard formula (any mechanics textbook, e.g. Goldstein, *Classical Mechanics*) is:

```
I_xx = m/12 * (b² + c²)       # about the athwartships axis: pitch
I_yy = m/12 * (a² + c²)       # about the vertical axis:     yaw
I_zz = m/12 * (a² + b²)       # about the bow-stern axis:    roll
```

With a = 0.6, b = 0.12, c = 2.5:

| Mass | pitch I_xx | yaw I_yy | roll I_zz |
|---|---|---|---|
| 91 kg (value at scene load, `MainScene.unity:214`) | 47.5 kg m² | 50.1 kg m² | 2.84 kg m² |
| 94 kg (after `Start()` set `rb.mass`, `BoardMassConfiguration.cs:191`) | 49.1 kg m² | 51.8 kg m² | 2.93 kg m² |

OPEN: whether Unity rescaled the automatic tensor when `rb.mass` was changed in `Start()` (Unity documents that the automatic tensor follows the colliders and mass, so 94 kg is the likely value), and whether it recomputed it about the shifted COM after `rb.centerOfMass` was set (PhysX keeps the mass-space tensor and only moves the COM frame, so most likely not). The difference is 3 %, far inside the tuning noise. The point that matters: **the legacy steering, damping and stabiliser torques were tuned against a yaw inertia of about 50 kg m² and a roll inertia of about 3 kg m².** Any physical model gives very different numbers (below), so those torques cannot be carried over unchanged.

The scene file's `m_InertiaTensor: {x: 1, y: 1, z: 1}` (`MainScene.unity:218`) is Unity's placeholder for "automatic", not a value that was used.

**(b) The legacy custom tensor (never enabled).** `CalculateInertiaTensor()` (`BoardMassConfiguration.cs:141-181`) built a diagonal tensor from a plate, a cylinder and a point mass:

```
board:   I_x = m_b/12 (w² + t²)          I_y = m_b/12 (L² + w²)         I_z = m_b/12 (L² + t²)      # :150-152, L = 2.4 (!), w = 0.6, t = 0.12
sailor:  I_x = m_s/12 (3 r² + h²) + m_s d²   I_y = m_s r² / 2   I_z = I_x       # :160-167, r = 0.2, h = 1.7, d = 0.45
rig:     I_x = m_r H²      I_y = m_r 0.3²      I_z = m_r H²                     # :170-173, H = 1.08
sum, each axis multiplied by _inertiaMultiplier (1, 1, 1)                        # :176-180
```

With 8, 80 and 6 kg: board (0.25, 4.08, 3.85), sailor (36.27, 1.60, 36.27), rig (7.00, 0.54, 7.00); total **(43.5, 6.2, 47.1) kg m²**. Problems: (1) the comments call x "roll" and z "pitch" (`:145-147`), but in Unity the long axis is z, so the x component (computed as the long-axis, i.e. roll, inertia) would have been applied to the pitch axis and vice versa; (2) the yaw inertia of 6.2 kg m² is 8 times smaller than the box value the torques were tuned for, which is why enabling it made the board "turn too easily" and it was switched off in Session 22 (`Legacy/Documentation/KNOWN_ISSUES.md:193`); (3) it uses a board length of 2.4 m while every other component uses 2.5 m; (4) the sailor's parallel-axis offset (0.45 m) does not match the cylinder's own geometry (a 1.7 m cylinder standing on the deck has its centre 0.85 m up). Do not implement this.

**(c) Spec: composite body with the parallel axis theorem.** For each part i with mass m_i, COM position r_i (body frame, relative to the board origin) and own inertia tensor I_i (about its own COM, in body axes):

```
com_offset = Σ m_i r_i / mass_total_kg
d_i        = r_i - com_offset
I_body     = Σ [ I_i + m_i * ( (d_i · d_i) * E - d_i ⊗ d_i ) ]        # E = identity, ⊗ = outer product
```

Physics: a part far from the COM is hard to swing around (the m d² term), on top of the difficulty of spinning the part about its own centre (I_i). The outer product gives the off-diagonal terms; they are small here but free to keep, so keep the full 3 x 3 (`Basis`) and invert it once per update.

Own inertias, all about the part's own COM, in body axes (x athwartships, y vertical, z fore-aft):

```
board, box (w, t, L) = (0.6, 0.12, 2.5) m:
    I_x = m/12 (t² + L²)     I_y = m/12 (w² + L²)     I_z = m/12 (w² + t²)
sailor, vertical cylinder r = 0.2 m, h = 1.7 m (legacy :156-157):
    I_x = I_z = m/12 (3 r² + h²)     I_y = m r² / 2
rig, vertical thin rod L_mast = 4.6 m (mast height, WindsurferSetup.cs:732):
    I_x = I_z = m L_mast² / 12       I_y = 0
```

Numbers for the proposal in 7.3 (8 / 7 / 75 kg, sailor at (0, 1.0, 0), rig at (0, 1.7, 0.1)):

| State | com_offset (m) | pitch I_xx | yaw I_yy | roll I_zz | I_yz |
|---|---|---|---|---|---|
| At rest, sailor centred | (0, 0.966, 0.008) | 46.7 | 5.97 | 42.7 | -0.51 |
| Fully planing (sailor 0.15 aft, 0.1 down) | (0, 0.882, 0.133) | 46.4 | 6.08 | 42.3 | -0.77 |
| Sailor 0.6 m to port, 0.1 down (hanging in the harness) | (-0.5, 0.882, 0.008) | 46.3 | 10.5 | 46.8 | I_xy = 0.80 |

(all in kg m²; own inertias: board (4.18, 4.41, 0.25), sailor (18.8, 1.5, 18.8), rig (12.3, 0, 12.3)).

Read these numbers before tuning anything: the physical yaw inertia is 6-10 kg m², not 50. The legacy "direct steering" torque of 200-350 N m (`AdvancedSail.cs:511-516`) would spin this body at 30-60 rad/s². That torque is a fudge (rake section) and must go; with physical inertia, physical torques (sail force x lever arm to the fin, a few tens of N m) give sensible turn rates. Pitch and roll inertia are dominated by the standing sailor and the rig and are 15 times larger than the legacy roll value; the roll damping numbers in the damping section were tuned against 3 kg m² and need re-tuning too.

The rig's own tensor ignores that the sail spreads about 2 m aft of the mast (adds ≈ 4.5 kg x 1 m² ≈ 4.5 kg m² to yaw and pitch) and that the mast is raked and leaned to windward. Add these in Phase 4 only if a test asks for them.

#### 7.7 What the integrator does with a moving COM

Unity did this inside PhysX; we do it ourselves. The rules:

1. **State.** Keep the COM's world position and velocity as the state, plus orientation `basis` and angular velocity. The board origin is derived: `origin_world = com_world - basis * com_offset`. (Keeping the origin as the state and deriving the COM works too, as long as torques are taken about the COM.)
2. **Force at a point.** `add_force_at(p_world, f)`: `force_sum += f`, `torque_sum += (p_world - com_world).cross(f)`. Every force in the other sections (buoyancy sample points, fin, sail at its centre of effort, hull resistance) goes through this, so a COM shift changes every lever arm automatically. A force applied exactly at the COM produces no torque. `add_torque(t)` adds a pure torque.
3. **Gravity** acts at the COM: `force_sum += Vector3(0, -mass_total_kg * g, 0)` and no torque. Unity had `useGravity = true` (`WindsurferSetup.cs:693`), which does the same. Applying gravity "at the origin" as a point force would be a bug: with the COM 0.1 m aft it would add a spurious 90 x 9.81 x 0.1 ≈ 88 N m pitch torque.
4. **Rotation.** `I_world = basis * I_body * basis.transposed()`, `alpha = I_world.inverse() * (torque_sum - omega.cross(I_world * omega))`. The gyroscopic term is tiny at windsurfer rates but costs nothing.
5. **When the COM offset changes** (planing shift, weight shift): recompute `com_offset` and `I_body` from the parts (7.3, 7.6), then move the COM state so that the board does not jump: `com_world += basis * (com_offset_new - com_offset_old)`. Keep the velocity and the angular velocity as they are. This is what Unity did: writing `rb.centerOfMass` (`BoardMassConfiguration.cs:228`) leaves `transform.position` alone and moves the physical COM inside the body. The sailor's own relative motion (0.15 m over the 2 s planing transition) is ignored as a momentum source, as it was in Unity.
6. **Angular velocity, not angular momentum, is kept** when `I_body` changes. PhysX does the same. The change is a few percent and slow, so no test will notice; note it in the code so nobody "fixes" it into an instability.

#### 7.8 The Rigidbody's built-in damping

`rb.linearDamping = 0` and `rb.angularDamping = 0.3` (`WindsurferSetup.cs:690-691`; scene `MainScene.unity:215-216`). PhysX applies damping as a per-step velocity scale (PhysX SDK guide, "Rigid Body Dynamics: Damping"):

```
omega *= max(0, 1 - 0.3 * dt)         # per 0.02 s step: factor 0.994, i.e. a decay time constant of 1/0.3 = 3.3 s
```

As a torque this is `-0.3 * I * omega`: about 16 N m s/rad on the legacy yaw axis (I = 52), 0.9 N m s/rad on the legacy roll axis (I = 3). It is negligible next to the explicit damping torques (buoyancy rotational damping 150 x 4 = 600 N m s/rad on pitch, `Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs:371-375`; hull angular damping 1.5 x 91 x 0.1 ≈ 14 N m s/rad in displacement mode, `AdvancedHullDrag.cs:530-543`). Linear damping 0 means the engine added no drag; the hull section owns all drag. Recommendation: none of this in Phase 2 (see Stabilisers).

#### 7.9 Anti-capsize: the sailor's balance as a torque

This is a stabiliser in the controller (`AdvancedWindsurferController.cs:276-307`), but it belongs here because it stands in for the sailor's righting moment. In D4, with `heel_rad` positive when the starboard rail is down:

```
heel_rad   = atan2(-basis.x.y, basis.y.y)                  # basis.x = starboard axis in world, basis.y = up axis in world
heel_deg   = rad_to_deg(heel_rad)
if abs(heel_deg) > 5:                                                              # :287 dead zone
    counter_factor = clamp(abs(heel_deg) / 45.0, 0, 1)                             # :291
    torque_restoring_Nm = heel_deg * 50.0 * 0.5 * counter_factor                   # :292   (units: N m per degree, squared through counter_factor)
if abs(heel_deg) > 45:                                                             # :299
    torque_restoring_Nm += (abs(heel_deg) - 45.0) * 50.0 * 2.0 * sign(heel_deg)    # :302-303
torque_body = Vector3(0, 0, +torque_restoring_Nm)                                  # about the body +Z (stern) axis; see Signs for why this sign restores
```

Values: 14 N m at 5°, 56 at 10°, 222 at 20°, 500 at 30°, 1125 at 45°, then +100 N m per extra degree. For scale, a 75 kg sailor leaning 0.6 m to windward gives 75 x 9.81 x 0.6 ≈ 440 N m. So the fudge is the right order of magnitude but has no lever arm, no mass and no limit on how hard the sailor can pull, and it works equally against a *windward* heel, which a real sailor would not resist. See Stabilisers.

### Values

Sources in short form: BMC = `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs`; WS = `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs`; PC = `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs`; SS = `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs`; AWC = `Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs`; Scene = `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity`; PD = `Legacy/Documentation/PHYSICS_DESIGN.md`.

The Scene column is what was on disk for the last validated build (commit b5ed2ea, Session 26; the values are identical in the Session 22 and Session 27 commits). The wizard wrote these values with `FindProperty`, so the scene and the wizard agree; the component defaults and the docs are the ones that differ.

| Name | Value | Unit | Sources and conflicts |
|---|---|---|---|
| `mass_board_kg` | **8** | kg | BMC:27; WS:768, 780; PC:34; SS:220; Scene:277, 465. PD:555 says 15 (doc only, never in code) |
| `mass_rig_kg` | **6** (mass model) / 8 (hull caps) | kg | BMC:30, WS:781, Scene:466 = 6. SS:223, WS:769, Scene:278 = 8. PD §8 has no rig line. Last build: the Rigidbody carried 6, the hull's lift caps assumed 8 |
| `mass_sailor_kg` | **80** (mass model) / 75 (hull caps, constants, docs) | kg | BMC:33, WS:782, Scene:467 = 80. PC:49, SS:226, WS:770, Scene:279, PD:556 = 75 |
| `mass_total_kg` | **94** (actual Rigidbody mass at run time) | kg | Computed at BMC:110 from 8 + 6 + 80 and written to `rb.mass` at BMC:191 in `Start()`. Other claims: 95 (BMC:24 field default, WS:779, WS:25/849 text, Scene:464; cosmetic, overwritten); 91 (WS:689 `rb.mass`, Scene:214, SS:231 8+8+75, `Legacy/Documentation/ARCHITECTURE.md:231,549`; in force until `Start()` ran, and used by the hull caps throughout); 90 (PD:554, `Legacy/Documentation/PROGRESS_LOG.md:450`, `Legacy/Documentation/COMPONENT_DEPENDENCIES.md:31`; doc only); 50 (old non-Advanced board: WS:1290, `Legacy/Documentation/scene_config.json:21`, `Legacy/Documentation/SCENE_CONFIGURATION.md:33`; history only) |
| `com_base` (D4) | **(0, 0.15, +0.10)** | m | BMC:37 (Unity (0, 0.15, -0.1)), Scene:468. PD:421 says (0, 0.4, 0) (doc only). Scene:217 Rigidbody `m_CenterOfMass` (0,0,0) is the pre-`Start()` value |
| `sailor_com_height_m` | 0.9 | m | BMC:40, Scene:469; only feeds the dead-code average and the unused custom tensor |
| `planing_com_shift_aft_m` | **0.15** | m | BMC:64, Scene:476 (wizard does not set it). PD:424, 557 and PROGRESS_LOG:451 say 0.3 (doc only) |
| `planing_com_shift_down_m` | 0.1 | m | BMC:225, hard-coded |
| `dynamic_com` | on | - | BMC:61, WS:787, Scene:475 |
| `use_custom_inertia` | off | - | BMC:54, WS:786, Scene:473; disabled in Session 22 (`KNOWN_ISSUES.md:193`) |
| Inertia box (Unity automatic) | 0.6 x 0.12 x 2.5 | m | WS:700, Scene:497 (`m_Size`). ARCHITECTURE.md:233 says "2.8 x 0.2 x 0.7" (doc only). Old quick-add collider 0.6 x 0.15 x 2.5 at WS:1298 (history) |
| Inertia (Unity, 94 kg box) | pitch 49.1, yaw 51.8, roll 2.93 | kg m² | Computed in 7.6(a); 47.5 / 50.1 / 2.84 at 91 kg |
| `board_length_m` for inertia | 2.4 (BMC) vs 2.5 (everything else) | m | BMC:44, WS:783, Scene:470 = 2.4; PC:30, WS:700/710/764, Scene:497 = 2.5. Spec uses 2.5 |
| `board_width_m`, `board_thickness_m` | 0.6, 0.12 | m | BMC:47, 50; PC:31-32; WS:700 |
| Sailor cylinder r, h | 0.2, 1.7 | m | BMC:156-157 (hard-coded) |
| Rig point-mass height (legacy) | 1.08 (= 1.2 x 0.9) | m | BMC:117, 170 |
| `rb.linearDamping` | 0 | 1/s | WS:690, Scene:215. COMPONENT_DEPENDENCIES.md:31 says "Drag: 0.5" (doc, old) |
| `rb.angularDamping` | 0.3 | 1/s | WS:691, Scene:216. 0.5 in WS:1291, scene_config.json:23, SCENE_CONFIGURATION.md:35 (old board); 2.0 in COMPONENT_DEPENDENCIES.md:31 (doc, old) |
| Weight shift max "angle" | 20 | deg (nominal) | AWC:49 |
| Weight shift rate | 4 x 20 = 80 | deg/s | AWC:52, 240 |
| Weight shift dead zone | 0.5 | deg | AWC:250 |
| Weight shift base torque | 80 | N m | AWC:257 (hard-coded) |
| Weight shift speed torque | 30, full above 3 m/s | N m, m/s | AWC:55, 260-261 |
| Input smoothing rate | 8 | 1/s | AWC:68, 198-200 |
| Anti-capsize on | true | - | AWC:59, WS:799 |
| Anti-capsize dead zone / max heel / strength | 5 / 45 / 50 | deg / deg / N m per deg | AWC:287 / 62 / 65 |
| Fixed time step (Unity) | 0.02 | s | `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset` ("Fixed Timestep: 0.02") |
| g | 9.81 | m/s² | PC:18 |
| Unity version | 6000.3.2f1 | - | `Legacy/WindsurfingGame/ProjectSettings/ProjectVersion.txt` |

**Spec proposal for the default configuration (estimates, to confirm at the Phase 1 stop):** `mass_board_kg` 8, `mass_rig_kg` 7, `mass_sailor_kg` 75 (total 90); `com_board` (0,0,0), `com_rig` (0, 1.7, 0.1), `com_sailor` (0, 1.0, 0); `planing_com_shift_aft_m` 0.15, `planing_com_shift_down_m` 0.1 (applied to the sailor); `weight_shift_max_m` 0.5; board box 2.5 x 0.6 x 0.12 m; sailor cylinder r 0.2 m, h 1.7 m; rig rod 4.6 m. Inertia at rest: pitch 46.7, yaw 5.97, roll 42.7 kg m².

### Where the force acts

- **Gravity** (`mass_total_kg * g`, straight down in the world frame) acts at the COM and produces no torque about it. This is the only force this section owns.
- **Every other force** turns the body about the COM: `torque = (point - com_world) x force`. So the COM position is an input to every section's torque. Examples with the legacy COM 0.1-0.25 m aft of the origin: the hull section's planing lift, applied at the origin (`AdvancedHullDrag.cs:500-507`), sits 0.1-0.25 m *ahead* of the COM and therefore gives a bow-up torque of lift x 0.1-0.25 m (about 200 N m at 800 N of lift and full planing). That is not a bug; it is how the aft COM trims the bow up. The hull resistance, applied 0.25 m aft of the origin (`:518`), sits within 0.15 m of the COM. The fin at (0, -0.1, +0.9) in D4 (`WindsurferSetup.cs:752`, Unity z = -0.9) is 0.65-0.8 m aft of the COM and 0.25 m below it.
- With the proposed physical COM (≈0.97 m above the origin), the vertical lever arms change a lot: the fin's side force acts ≈1.1 m *below* the COM (heeling to leeward when the fin pushes to windward, as in reality), and a sail force at a centre of effort ≈1.5-2 m up acts only ≈0.5-1 m *above* the COM. The sail and fin sections must apply their forces at their real points and let this section's COM do the rest; do not pre-bake lever arms into those sections.
- **Anti-capsize torque** (7.9, legacy only): a pure torque about the bow-stern axis.
- **Weight-shift torque** (7.5, legacy only): a pure torque about the world up axis.

### Signs and the Unity-to-Godot translation

| Quantity | D4 (Godot) | Unity (legacy) | Note |
|---|---|---|---|
| Aft direction | +Z | -Z | Every legacy z coordinate flips sign: COM (0, 0.15, -0.1) becomes (0, 0.15, +0.1); planing shift z = -0.15 becomes +0.15; rig COM z = -0.2 becomes +0.2 |
| Up, starboard | +Y, +X | +Y, +X | Unchanged |
| Yaw torque that turns the bow to starboard (right) | **negative** about +Y | positive about +Y | Right-handed vs left-handed. The legacy weight-shift torque `Vector3.up * torque` (AWC:266) and rake torque (`AdvancedSail.cs:524`) with a positive value turned right; in Godot the same intent needs `Vector3(0, -torque, 0)`. `yaw_rate` positive turns the bow to port in Godot |
| Pitch, bow up | positive rotation about +X (`pitch_rad = asin(-basis.z.y)`) | negative `eulerAngles.x` (the legacy took `trim = -pitchAngle`, `AdvancedHullDrag.cs:428`) | Sign flips |
| Heel to starboard (starboard rail down) | positive rotation about the bow axis -Z, i.e. **negative** about body +Z; `heel_rad = atan2(-basis.x.y, basis.y.y)` | `Vector3.SignedAngle(up, projected up, forward)` about +Z (bow) (AWC:280-282); the legacy took `abs()` in the hull (`AdvancedHullDrag.cs:420-422`) | Do not use `signed_angle_to` for this; the atan2 form above is unambiguous. The anti-capsize torque is self-consistent in any handedness because it measures the angle and applies the torque about the *same* axis; in D4 a restoring torque for a positive (starboard) heel is `+k * heel_rad` about body +Z |
| Cross product for torque, `r x F` | Godot `Vector3.cross`, right-hand rule | `Vector3.Cross`, same component formula in a mirrored frame | The formula does not change; only the frame does. Derive lever arms in D4 and test them (plan pitfall 2); the integrator test "off-centre force gives the expected torque" pins the sign |
| Weight shift sign | `weight_shift` +1 = sailor's COM to starboard (+X) | `_weightInput` +1 = "turn right" torque, inverted on port tack (AWC:158-169) | Different meaning: legacy is a steering torque, spec is a position. The legacy port-tack inversion made the torque fight the rake on port tack (7.5); do not copy |
| Planing ratio | 0 to 1 from speed, same in both | same | No change |
| Angular damping 0.3 | not used | PhysX per-step scale | Engine-specific, dropped (see below) |

### Stabilisers and fudges in this model

| Item | What it is | Why it was added | What it probably hides | Recommendation |
|---|---|---|---|---|
| **COM override at (0, 0.15, +0.1)** (BMC:127-131) | Replaces the physical mass-weighted COM with a hand-set point 0.15 m above the deck centre | Present since the file was created in Session 22 (commit 5a1857a); no logged symptom. Together with "CE at (0,0,0)" (Session 25/26, `KNOWN_ISSUES.md:83,100`) it removed almost all roll dynamics | That the build had no sailor-balance model: with a realistic COM and CE height the board would capsize because nothing leans out against the sail | **Re-evaluate at the Phase 1 stop, together with the sail section.** Physical option (recommended): real COM (≈1 m up) plus a balancing sailor (`weight_shift`, automatic in beginner mode). Simple option: keep a low COM and the sail force through the COM, accepting that heel is cosmetic. Do not mix the two: a high COM without balance, or a low COM with a high CE, both fail |
| **Planing COM shift** (7.4) | Sailor moves 0.15 m aft and 0.1 m down with `planing_ratio` | Session 22; the earlier version moved *forward*, which made the nose dig in ("Sailor moves forward at speed", `KNOWN_ISSUES.md:192`) | Nothing; it is real technique | **Keep**, implemented as a shift of the sailor part, value 0.15 m (validated). Try 0.3 m in Phase 4 if the board needs more bow-up trim |
| **Custom inertia tensor** (7.6 b) | Diagonal tensor from plate + cylinder + point mass, axes mislabelled | Written in Session 22, disabled in the same session ("Board turns too easily, pitches up", `KNOWN_ISSUES.md:193`) | That the steering torques were fudges sized for the box tensor | **Drop** the legacy formula; implement the composite model (7.6 c). Re-tune steering and damping against the physical inertia in Phase 4 |
| **Rigidbody angular damping 0.3** (7.8) | PhysX velocity scale, ≈ -0.3 I ω | Wizard default since Session 18 ("Minimal angular damping", WS:691) | Nothing; it is 1-3 % of the explicit damping | **Drop.** All rotational damping comes from the water models (damping section), where it has a physical reason and a testable value |
| **Rigidbody linear damping 0** | none | "Hull drag handles this" (WS:690) | - | **Keep at zero**; not a term at all in our integrator |
| **Weight-shift yaw torque** 80-110 N m (7.5) | Direct yaw torque from the A/D keys, no lever arm | "Base steering torque (80 N m) for control at zero speed", Session 22 (`PROGRESS_LOG.md:402`); the 30 N m speed term is older (Session 13-17 controller V2 had 12, `WindsurferControllerV2.cs:33`) | That the rake steering was not physical enough to turn the board at low speed | **Drop.** Replace with a lateral sailor COM offset (7.5). Steering at zero speed is not a real windsurfing capability (you cannot steer a board that is not moving), so nothing needs to replace the "works when stopped" behaviour. Note the port-tack sign bug |
| **Anti-capsize torque** (7.9) | Heel-proportional restoring torque, up to 1125 N m plus 100 N m per degree past 45° | Present since Session 22 ("All assists are enabled for stable, fun gameplay", AWC:17); no symptom logged | The missing sailor righting moment (75 kg x 0.5 m ≈ 370 N m) | **Drop as a torque.** In beginner mode, give the same job to an automatic `weight_shift`: the sailor leans out so that the roll moment is cancelled, limited to ±`weight_shift_max_m`. Then the righting moment has a real cap and a real lever arm, and it will not fight a windward heel |
| **Hull caps using a second total mass** (91 kg, 7.1) | `HullConfiguration.TotalMass` separate from the Rigidbody mass | Two components written at different times | That nobody checked that the "85 % of weight" cap was 85 % of the right weight | **Drop the duplicate.** One `mass_total_kg`, read by every section |

### What Phase 2 must implement

- [ ] `SailorConfig` / `BoardConfig` / `SailConfig` resource fields: `mass_board_kg`, `mass_rig_kg`, `mass_sailor_kg`, box dimensions, `com_rig`, `com_sailor` (at rest), `planing_com_shift_aft_m`, `planing_com_shift_down_m`, `weight_shift_max_m`, sailor cylinder `r`/`h`, `mast_length_m`. No editable total mass.
- [ ] A `MassModel` class (RefCounted, in `Game/sim/`) with `update(planing_ratio: float, weight_shift: float)` that recomputes the sailor position (`com_sailor_rest + Vector3(weight_shift * weight_shift_max_m, -planing_com_shift_down_m * planing_ratio, +planing_com_shift_aft_m * planing_ratio)`), then `mass_total_kg`, `com_offset` (7.3) and `inertia_body` + inverse (7.6 c, full `Basis`, parallel axis theorem).
- [ ] The rigid-body state stores the COM position; the integrator has `add_force_at(point_world, force)` taking torques about the current COM, `add_torque(torque_world)`, gravity applied at the COM, and `I_world = basis * I_body * basis.transposed()` (7.7).
- [ ] `set_com_offset(new_offset)` on the body: shifts the COM state by `basis * (new - old)` so the board origin stays put; velocity and angular velocity unchanged (7.7, rules 5-6).
- [ ] The windsurfer sim calls `mass_model.update(...)` once per step **before** any force is applied, using the previous step's `planing_ratio` (as the legacy did, `BoardMassConfiguration.cs:96-102`), so all forces in one step see the same COM.
- [ ] Telemetry: `mass_total_kg`, `com_offset`, the three diagonal inertia values.
- [ ] Not implemented: legacy custom tensor, weight-shift yaw torque, anti-capsize torque, Rigidbody damping, the second total mass.
- [ ] Config defaults from the Values proposal, with a comment at each number saying whether it is legacy-validated (0.15 m shift, 8 kg board, 2.5 x 0.6 x 0.12 m box) or an estimate (rig 7 kg, rig COM 1.7 m, sailor COM 1.0 m, `weight_shift_max_m` 0.5 m).

### Tests Phase 2 should write

Hand-calculated expected values use the proposal (8 / 7 / 75 kg, positions in 7.3).

- **Total mass:** `mass_total_kg == 90.0`; changing `mass_rig_kg` to 6 gives 89.
- **COM at rest:** `com_offset` ≈ (0, 0.9656, 0.0078) m (tolerance 1 mm). With the legacy parts and positions (8 kg at (0,0.06,0), 6 kg at (0,1.08,0.2), 80 kg at (0,0.45,0)) the average is (0, 0.457, +0.0128): this pins the dead-code formula and the z sign flip.
- **Inertia of a box alone:** a mass model with only the board (8 kg, 2.5 x 0.6 x 0.12) gives (4.176, 4.407, 0.250) kg m² and zero off-diagonals.
- **Parallel axis theorem:** a 1 kg point mass at (0, 0, 2) plus a 1 kg point mass at (0, 0, -2) gives COM (0,0,0) and I_xx = I_yy = 8, I_zz = 0. Same with the two masses at (0, 1, 2) and (0, -1, -2): I_xx = 10, I_yy = 8, I_zz = 2, I_yz = -4 (sign check of the outer product).
- **Full proposal at rest:** pitch 46.72, yaw 5.97, roll 42.73, I_yz ≈ -0.51 kg m² (tolerance 0.05).
- **Planing shift:** at `planing_ratio` = 1, `com_offset.z` ≈ 0.133 and `com_offset.y` ≈ 0.882; at 0.5, halfway; the tensor stays positive-definite.
- **Weight shift sign:** `weight_shift` = +1 moves `com_offset.x` to +0.417 (75/90 x 0.5): starboard is +X.
- **Gravity gives no rotation:** any COM offset, board at rest in space with only gravity: angular velocity stays exactly zero after 1 s (catches "gravity at the origin" bugs).
- **Force at the COM gives no rotation, off-centre force does:** 100 N in +Y at `com_world + basis * (0, 0, +1)` (1 m aft) gives torque (100, 0, 0) N m about +X, i.e. the bow pitches *down*... check: `(0,0,1) x (0,100,0) = (-100, 0, 0)`, so the torque is -100 N m about +X: stern lifts, bow pitches down. Positive about +X is bow up (7.9 / Signs). Pin this.
- **Yaw sign:** a torque of -10 N m about +Y makes `yaw_rate` negative, and the heading (compass) increases (turns to starboard). This is the D4 fact every steering test relies on.
- **COM change does not teleport the board:** with the board gliding at 5 m/s, switch `planing_ratio` from 0 to 1 in one step: the board origin's world position changes by less than 1 mm and the velocity by less than 1 mm/s.
- **No spurious spin from the shift:** same scenario, angular velocity stays below 1e-6 rad/s.
- **Static trim couples to the COM** (with the buoyancy section): floating at rest with the COM 0.1 m aft of the origin, the board settles bow-up (`pitch_rad` > 0) and the centre of buoyancy ends up within 1 cm horizontally of the COM.
- **Determinism:** two runs with the same inputs give bit-identical `com_offset` and tensors.

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/Scripts/`):
- `Physics/Board/BoardMassConfiguration.cs:22-67` (fields), `:83-102` (Awake/Start/FixedUpdate), `:107-136` (mass and COM), `:141-181` (custom inertia), `:186-205` (apply to Rigidbody), `:210-229` (dynamic COM). Git history: created in commit 5a1857a (Session 22, 2025-12-28); no later code changes.
- `Editor/WindsurferSetup.cs:25`, `:46` (mast base), `:686-694` (Rigidbody), `:699-701` (BoxCollider), `:761-772` (hull masses), `:775-788` (mass configuration), `:849-850` (log text), `:1287-1298` (old quick-add board). Git: `rb.mass = 91` and damping from commit 4c45223 (2025-12-27); mass configuration from 5a1857a.
- `Physics/Core/PhysicsConstants.cs:18`, `:30-34`, `:49-50`.
- `Physics/Core/SailingState.cs:203-244` (`HullConfiguration`, `TotalMass` at `:231`).
- `Physics/Board/AdvancedHullDrag.cs:31-34`, `:181-195` (planing ratio), `:205`, `:352`, `:448` (uses of `TotalMass`), `:428` (trim sign), `:500-507` (lift at the origin), `:518-520` (resistance point), `:524-545` (angular damping).
- `Player/AdvancedWindsurferController.cs:47-68`, `:152-170`, `:195-201`, `:238-242`, `:248-270`, `:276-307`, `:368-377`.
- `Player/WindsurferControllerV2.cs:33`, `:344-358` (older weight-shift torque, history only).
- `Physics/Board/AdvancedSail.cs:66`, `:80-81` (tack flag), `:283-291` (CE at zero), `:377`, `:424-444` (pitch stabiliser), `:452-459`, `:466-495` (tack sign), `:497-524` (rake torque).
- `Physics/Buoyancy/AdvancedBuoyancy.cs:361-384` (rotational damping, for the comparison in 7.8).
- Scene: `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:214-218` (Rigidbody), `:277-279` (hull masses), `:464-476` (BoardMassConfiguration), `:497` (collider size). Same values in commits 5a1857a, b5ed2ea, dfbc3a0, 757d5cf.
- `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset` (fixed step 0.02 s); `ProjectVersion.txt` (Unity 6000.3.2f1).

Legacy docs:
- `Legacy/Documentation/PHYSICS_DESIGN.md:415-434` (sailor COM section), `:486-513` (update loop), `:553-557` (mass parameters).
- `Legacy/Documentation/PROGRESS_LOG.md:160-166` (Session 26: lift at the COM), `:215-260` (Session 24), `:393-402` (Session 22: COM aft, base steering torque), `:441-451` (Session 22 parameter table), `:717-722` (Session 13-17 controller history).
- `Legacy/Documentation/KNOWN_ISSUES.md:83`, `:100`, `:192-193`.
- `Legacy/Documentation/ARCHITECTURE.md:231-233`, `:549`; `COMPONENT_DEPENDENCIES.md:31`; `SCENE_CONFIGURATION.md:33-36`; `scene_config.json:20-24` (2025-12-27, old board; history only).
- `Documentation/REBUILD_PLAN.md:57-71` (D4), `:130-143` (fudge list), `:146` (default configuration), `:157` (integrator tests), `:299` (pitfall 8).

Literature and engine documentation:
- Box, cylinder and rod inertia and the parallel axis theorem: any mechanics text, e.g. H. Goldstein, *Classical Mechanics*, ch. 5.
- Human COM height ≈ 0.55 x body height: D. A. Winter, *Biomechanics and Motor Control of Human Movement*, anthropometric tables.
- Unity Scripting API: `Rigidbody.mass`, `Rigidbody.centerOfMass` ("setting it does not move the transform"), `Rigidbody.inertiaTensor` (automatic from colliders unless set), `Rigidbody.angularDamping`.
- NVIDIA PhysX SDK Guide, "Rigid Body Dynamics: Damping" (per-step velocity scale `1 - damping * dt`).
- Rig component masses (sail ≈4.5 kg, mast ≈2 kg, boom ≈2.8 kg) are typical manufacturer figures for a 6 m² freeride rig, used here only for the rig COM height estimate.

---

## 8. Wind field: base wind, gusts, shifts and height gradient

### Purpose

The wind field answers one question for the rest of the simulation: "what is the true wind velocity at this point in the world, right now?" The sail model subtracts the board's velocity from that answer to get the apparent wind, and everything the sail does follows from the apparent wind. The wind field itself produces no force.

The legacy Unity game had two wind components:

- `WindSystem.cs` (Environment/): the one the last builds used. A single global wind, described by a compass bearing and a speed in knots, with optional gusts (a sum of sine waves), optional direction shifts (also sines) and an optional increase of speed with height above the water (a power law).
- `WindManager.cs` (Physics/Wind/): the older one from Session 4, used by the old (non-Advanced) components. Perlin noise in space and time. Kept in the scene tree only as a fallback; `AdvancedSail` used it only if no `WindSystem` existed (Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs:93-116).

This section specifies the `WindSystem` behaviour in D4 conventions, documents `WindManager` for reference (its spatial noise is a useful idea for the Phase 6 gust patches), and defines the interface Phase 2 needs: a `WindField` with `velocity_at(world_point)` and a constant-wind mode for tests.

Physics in one sentence: wind is air moving over the water. Near the surface friction slows it down, so it is stronger higher up; it also comes in gusts (a few seconds) and slowly swings in direction (a minute or more).

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `wind_from_bearing_deg` | compass bearing the wind comes FROM (0 = from North, 90 = from East, 180 = from South, 270 = from West) | deg (config only; converted to rad inside) |
| `base_speed_kt` | base (undisturbed) wind speed at the reference height, as the team enters it | kt (config only) |
| `base_speed_ms` | the same, in SI: `base_speed_kt * KNOT_MS` | m/s |
| `gusts_enabled` | gusts on or off | bool |
| `gust_intensity` | gust amplitude as a fraction of the base speed (0 to 0.5) | – |
| `gust_period_s` | period of the slowest gust component | s |
| `shifts_enabled` | direction shifts on or off | bool |
| `max_shift_deg` | amplitude of the main direction shift | deg (config only) |
| `shift_period_s` | period of the main direction shift | s |
| `height_gradient_enabled` | wind speed increases with height | bool |
| `reference_height_m` | height at which the wind speed equals `base_speed_ms` | m |
| `shear_exponent` | exponent of the power-law wind profile | – |
| `time_s` | simulation time since the wind field started (advanced by `step(dt)`) | s |
| `world_point` | the query position in the world frame (x = East, y = up, z = South) | m |
| **Output** `v_wind_true` | true wind VELOCITY at `world_point`: the direction the air moves, length = speed | m/s |
| **Output** `wind_from_dir` | unit vector pointing to where the wind comes from, horizontal; equals `-v_wind_true.normalized()` | – |
| **Output** `current_speed_ms` | wind speed at the reference height right now (base × gust factor) | m/s |
| **Output** `current_from_bearing_rad` | current FROM bearing (base + shift) | rad |

The wind field has no vertical component: `v_wind_true.y = 0` always (Legacy/WindsurfingGame/Assets/Scripts/Environment/WindSystem.cs:162-166 build the vector with `0f` for y).

### Formulas

All angles in radians inside the simulation. `KNOT_MS = 0.514444` m/s per knot (one international nautical mile, 1852 m, per hour; Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:21-22 define `MS_TO_KNOTS = 1.94384` and `KNOTS_TO_MS = 0.514444`). The legacy `WindSystem` divides knots by 1.94384 (WindSystem.cs:87, 99, 110); `WindManager` multiplies by 0.514444 (WindManager.cs:153). The two differ in the sixth digit; use `KNOT_MS = 0.514444`.

#### 8.1 Unit conversion

```
base_speed_ms = base_speed_kt * KNOT_MS                     # 15 kt -> 7.7167 m/s
wind_from_bearing_rad = deg_to_rad(wind_from_bearing_deg)
```

#### 8.2 Bearing to vectors (the D4 compass)

D4 says North is world −Z and East is world +X, and a bearing is measured clockwise from North (looking down from above). A unit vector pointing TOWARD a bearing `b` is therefore:

```
toward(b) = Vector3(sin(b), 0.0, -cos(b))
```

The wind comes FROM its bearing, so the from-vector points toward the bearing and the velocity points the opposite way:

```
wind_from_dir = Vector3(sin(b), 0.0, -cos(b))              # unit vector, toward where the wind comes from
v_wind_true   = -wind_from_dir * speed_ms
              = Vector3(-sin(b) * speed_ms, 0.0, cos(b) * speed_ms)
```

Check with the four cardinal bearings (speed 1 m/s):

| `wind_from_bearing_deg` | wind comes from | `wind_from_dir` | `v_wind_true` (air moves toward) | correct? |
|---|---|---|---|---|
| 0 | North | (0, 0, −1) = North | (0, 0, +1) = South | yes: a north wind blows south |
| 90 | East | (+1, 0, 0) = East | (−1, 0, 0) = West | yes |
| 180 | South | (0, 0, +1) = South | (0, 0, −1) = North | yes |
| 270 | West | (−1, 0, 0) = West | (+1, 0, 0) = East | yes |

Going back from a horizontal from-vector `f` to a bearing (needed for the HUD and for tests):

```
bearing_rad = atan2(f.x, -f.z)            # wrap to [0, 2*PI) with fposmod for display
```

Check: `f = (0,0,−1)` gives `atan2(0, 1) = 0` (North); `f = (1,0,0)` gives `atan2(1, 0) = +90°` (East); `f = (−1,0,0)` gives `atan2(−1, 0) = −90°`, which wraps to 270° (West). Note that this is the same formula as the D4 TWA formula applied in the world frame, where the "bow" is North.

The legacy code (WindSystem.cs:161-168) does `dirRad = (dir + 180°)`, then `(sin dirRad, 0, cos dirRad) * speed`. Because `sin(b + 180°) = −sin b` and `cos(b + 180°) = −cos b`, that is `(−sin b, 0, −cos b) * speed` in Unity's frame, where North is +Z. Flipping the Z sign for Godot's North = −Z gives exactly `(−sin b, 0, +cos b) * speed`, the formula above. The from-vector `GetWindFromDirection()` (WindSystem.cs:174-182) is `(sin b, 0, cos b)` in Unity and `(sin b, 0, −cos b)` in Godot.

#### 8.3 Gusts (speed variation in time)

The gust is a fixed sum of three sine waves with frequencies 1, 2.3 and 5.7 times the base gust frequency. The three periods (8 s, 3.48 s and 1.40 s at the default `gust_period_s = 8`) are not simple multiples of each other, so the sum looks irregular even though it is fully deterministic. There is no random number anywhere: every run of the game gets the same gust sequence, and the phase starts at zero, so the wind at `time_s = 0` is exactly the base wind.

```
gust_phase = 2 * PI * time_s / gust_period_s                      # WindSystem.cs:116 (accumulated as phase += dt / period * 2*PI)
gust = 0.6 * sin(gust_phase) + 0.3 * sin(2.3 * gust_phase) + 0.1 * sin(5.7 * gust_phase)   # WindSystem.cs:119-121
gust_factor = 1.0 + gust * gust_intensity                          # WindSystem.cs:123
current_speed_ms = base_speed_ms * gust_factor                     # WindSystem.cs:137
```

When gusts are off, `gust_factor = 1` (WindSystem.cs:113-114).

Properties (computed numerically over 8000 s of the default settings, see the sample table below): `gust` stays within ±0.957, never reaching ±1 because the three sines never peak together; its RMS value is 0.480. With `gust_intensity = 0.2` the speed stays between 0.809 and 1.191 times the base, that is 12.1 to 17.9 kt for a 15 kt base. The mean of `gust` is zero, so the average wind equals the base wind.

Timing detail: the legacy code advanced `_gustPhase` in `Update()` (every rendered frame, WindSystem.cs:103-106) with `Time.deltaTime`, while the sail read the wind in `FixedUpdate` (AdvancedSail.cs:118-125, 50 Hz per Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6). The result is frame-rate independent because the phase is time-based, but the wind value used in a physics tick was whatever the last rendered frame produced. In Godot (architecture rule 1) the wind field is stepped inside the simulation with the physics `dt`, so this quirk disappears. The phase must be wrapped (`fposmod(gust_phase, 2 * PI)`) so it does not grow without bound; the legacy code never wrapped it (float precision after an hour is still fine, about 0.0003 rad, but there is no reason to rely on that).

#### 8.4 Shifts (direction variation in time)

A shift is a slow swing of the FROM bearing. Two sines again: the main one with `shift_period_s` and amplitude `max_shift`, and a slower one at 0.37 times the frequency (period 162 s at the 60 s default) with 0.3 times the amplitude.

```
shift_phase = 2 * PI * time_s / shift_period_s                                          # WindSystem.cs:130
shift_rad = max_shift_rad * (sin(shift_phase) + 0.3 * sin(0.37 * shift_phase))          # WindSystem.cs:133-134
current_from_bearing_rad = wind_from_bearing_rad + shift_rad                            # WindSystem.cs:138
```

When shifts are off, `shift_rad = 0` (WindSystem.cs:127-128). The maximum swing is `1.3 * max_shift` = 19.5° for the 15° default. Shifts were OFF in every committed scene (MainScene.unity:826 `_enableShifts: 0`) and off by C# default (WindSystem.cs:40), so no validated behaviour depends on them.

Sign in D4: a positive `shift_rad` increases the bearing, that is the wind veers (swings clockwise, e.g. from West toward North-West). That is the same in Unity and Godot because a bearing is a compass number, not a vector; only the conversion to a vector (8.2) is frame-dependent.

#### 8.5 Height gradient (speed variation with height)

Wind is slower near the water because of friction with the surface. The legacy code uses the power law (Hellmann / "one-seventh power law"):

```
z = world_point.y                                       # height above the still-water plane, m
if height_gradient_enabled and z > 0.1:                 # WindSystem.cs:152
    height_factor = (max(z, 0.1) / reference_height_m) ** shear_exponent     # WindSystem.cs:155-156
else:
    height_factor = 1.0
speed_at_point_ms = current_speed_ms * height_factor    # WindSystem.cs:157
```

Two things in the legacy version are wrong and must not be copied:

1. **The factor jumps at 0.1 m.** For `z <= 0.1` the gradient is skipped and the factor is 1.0; at `z = 0.1001` it is `0.1^0.14 = 0.724`. A board rising through 0.1 m sees the wind drop by 28 % in one tick. The inner `max(z, 0.1)` (WindSystem.cs:155) was clearly meant as a floor, but the outer `position.y > 0.1f` test (WindSystem.cs:152) makes the floor unreachable. The spec formula is continuous:

```
z_eff = max(z, z_min)                                    # z_min = 0.1 m, floor below which the profile is held constant
height_factor = (z_eff / reference_height_m) ** shear_exponent
```

2. **The legacy sail sampled the wind at the board's origin, not at the sail.** `AdvancedSail.cs:163` calls `GetWindAtPosition(transform.position)`. The rigidbody origin sits about 0.03 m above the water at rest (hull bottom at local y = −0.06 m, AdvancedBuoyancy.cs:42 and :185, and about 73 % submersion, plan pitfall 8), so the gradient was usually skipped; when the board lifted onto the plane (origin at roughly 0.2 to 0.4 m) the factor became 0.80 to 0.88, so **the wind got weaker as the board started planing**. That is backwards: the sail's centre of effort is 2 to 3 m above the water, where the wind is stronger than at 1 m, and it hardly moves when the hull rises 0.3 m. The spec says: sample the wind at the sail's centre of effort (its world position, which the sail section defines; boom height 1.4 m and mast height 4.6 m per Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:155 and :139 and WindsurferSetup.cs:732-735), or, simpler and good enough, at a fixed `ce_height_m` above the water plane.

Physics behind the numbers: over open water the exponent is small because the surface is smooth. Hsu, Meindl and Gilhousen (1994, J. Applied Meteorology 33:757-765) measured about 0.11 over the sea in neutral conditions; the classic 1/7 ≈ 0.143 is the value for flat open land and is what the legacy chose (WindSystem.cs:58, tooltip "0.1-0.3 typical over water"). Meteorological wind speeds (forecasts, anemometers) are quoted at 10 m height (WMO Guide No. 8), while the legacy reference height is 1 m (WindSystem.cs:54). With `reference_height_m = 1`, "15 kt" means 15 kt at 1 m, which is 20.7 kt at 10 m and 16.5 kt at 2 m. See OPEN question 1 in the Values section.

The logarithmic profile `u(z) = u_ref * ln(z / z0) / ln(z_ref / z0)` with roughness length `z0 = 0.0002 m` (open sea, Wieringa 1992) is the alternative. For a sail at 2.5 m and a 10 m reference it gives a factor 0.872 against 0.824 for the power law with 0.14 and 0.859 with 0.11. The difference is small; keep the power law (fewer parameters, matches the legacy).

#### 8.6 The full query: `velocity_at(world_point)`

Putting 8.1 to 8.5 together, in evaluation order:

```
func step(dt: float) -> void:
    time_s += dt
    # 8.3 and 8.4 are functions of time_s only; compute once per tick and cache:
    current_speed_ms = base_speed_ms * gust_factor(time_s)
    current_from_bearing_rad = wind_from_bearing_rad + shift_rad(time_s)

func velocity_at(world_point: Vector3) -> Vector3:
    var speed_ms: float = current_speed_ms * height_factor(world_point.y)     # 8.5
    var b: float = current_from_bearing_rad
    return Vector3(-sin(b), 0.0, cos(b)) * speed_ms                           # 8.2

func from_direction() -> Vector3:
    var b: float = current_from_bearing_rad
    return Vector3(sin(b), 0.0, -cos(b))
```

There is **no horizontal spatial variation** in `WindSystem`: two points at the same height get the same vector, wherever they are. Only the height matters. (`WindManager` did have spatial variation, see 8.7.)

**Constant-wind mode** (for tests and for Phase 2): `gusts_enabled = false`, `shifts_enabled = false`, `height_gradient_enabled = false`. Then `velocity_at(p)` returns the same vector for every `p` and every `time_s`: `Vector3(-sin(b), 0, cos(b)) * base_speed_ms`. Phase 2's `WindField` is exactly this constant mode (plan Phase 2, "WindField (constant wind for now)").

#### 8.7 Legacy `WindManager` (Session 4), for reference only

`WindManager.cs` describes the wind as a speed in m/s (default 8 m/s, WindManager.cs:13) and a bearing (default 45°, WindManager.cs:16) and adds Perlin noise:

```
# WindManager.cs:63-64: two random offsets in [0, 1000) chosen once at start
# WindManager.cs:79-80: offset_speed += dt * gust_frequency ; offset_dir += dt * gust_frequency * 0.5   (gust_frequency = 0.1 /s, WindManager.cs:31)
# WindManager.cs:104-117:
pos_noise  = perlin(x * 0.01 + offset_speed, z * 0.01)         # spatial pattern, 100 m per noise unit, drifting along -x at 10 m/s
time_noise = perlin(offset_speed, 0)                            # global gust
combined   = (pos_noise + time_noise) * 0.5                     # perlin() is in [0, 1], neutral at 0.5
speed      = base_speed * (1 + (combined - 0.5) * 2 * speed_variation)          # speed_variation = 0.2 -> factor in [0.8, 1.2]
# WindManager.cs:120-124:
dir_noise  = perlin(offset_dir, x * 0.01)
bearing    = bearing_base + (dir_noise - 0.5) * 2 * direction_variation          # direction_variation = 10 deg -> +/-10 deg
velocity   = (sin(bearing), 0, cos(bearing)) * speed             # UNITY frame: this is the FROM direction, see below
```

Two remarks. First, `WindManager.GetWindAtPosition` (WindManager.cs:124-127) returns `direction * speed` where `direction` is built from the bearing directly, i.e. it points to where the wind comes FROM, while `IWindProvider.cs:13` promises "direction is where wind blows TO". So `WindManager` returned the wind velocity with the wrong sign relative to its own interface, and `WindSystem` (with its `+180°`) returned the right sign. Anything that used both would have disagreed by 180°. This is history (the Advanced stack never used `WindManager` when a `WindSystem` existed), but it is a good reason for the Phase 2 test "wind from bearing 0 blows toward +Z (South)". Second, the drift of the spatial pattern is tied to the noise offset, not to the wind: gust patches would move at 10 m/s along −X regardless of the wind direction. If Phase 6 wants moving gust patches on the water, they should move with `v_wind_true`, not like this.

#### 8.8 Wind angles from the field (the D4 check)

The sail section owns the apparent wind, but the wind field must make it easy to get the D4 angles right, so here is the derivation with the wind field's own outputs. `board_basis` is the board's rotation (orthonormal `Basis`), so `board_basis.inverse()` is its transpose.

```
from_world = wind_field.from_direction()                        # unit, horizontal
from_local = board_basis.inverse() * from_world                  # into the body frame: bow = -Z, starboard = +X
twa_rad = atan2(from_local.x, -from_local.z)                     # D4: positive = wind from starboard
heading_rad = atan2(forward.x, -forward.z)  where forward = -board_basis.z          # compass heading of the bow
# equivalently, in the horizontal plane only:
twa_rad = wrapf(current_from_bearing_rad - heading_rad, -PI, PI)
```

Checks with the wind from West (bearing 270°) and three headings:

| heading | `forward` (world) | starboard (world) | `from_local` | `twa` | meaning |
|---|---|---|---|---|---|
| 0° (North) | (0, 0, −1) | (+1, 0, 0) | (−1, 0, 0) | −90° | wind from port, port tack, beam reach |
| 90° (East) | (+1, 0, 0) | (0, 0, +1) | (0, 0, +1) | 180° | dead downwind |
| 180° (South) | (0, 0, +1) | (−1, 0, 0) | (+1, 0, 0) | +90° | wind from starboard, starboard tack, beam reach |

`wrapf(270° − 0°) = −90°`, `270° − 90° = 180°`, `270° − 180° = +90°`: the bearing-difference form agrees with the vector form. Note that a positive yaw rate (rotation about +Y) turns the bow to port in Godot, so it DEcreases `heading_rad`; a board turning left with the wind from the West goes from TWA −90° toward −180°.

The legacy scene starts the board at the identity rotation (MainScene.unity:390-391; WindsurferSetup.cs:683), that is heading North (Unity forward = +Z = North), with the wind from 270°: a port-tack beam reach, the first row of the table.

#### 8.9 Runtime changes to the wind

The legacy `WindSystem` had three setters (nothing in the shipped scripts called them; only the editor gizmos and the setup wizard touched the fields):

- `SetWind(directionDegrees, speedKnots)` (WindSystem.cs:187-191): `direction % 360` with C#'s `%`, which keeps a negative sign, so `SetWind(-10, ...)` stored −10, and no clamp on the speed.
- `AdjustWindSpeed(deltaKnots)` (WindSystem.cs:196-199): clamps to 0 to 50 kt.
- `AdjustWindDirection(deltaDegrees)` (WindSystem.cs:204-208): wraps into [0, 360).

Spec: `set_wind(bearing_rad, speed_ms)` wraps the bearing with `fposmod(bearing, 2 * PI)` and clamps the speed to [0, 50 kt] = [0, 25.7 m/s], the same range as the inspector slider (WindSystem.cs:25 `[Range(0, 50)]`). Changing the base wind while gusts are on must not restart the gust phase.

### Values

Three legacy sources exist for each number: the C# field default in `WindSystem.cs`, the values stored in `MainScene.unity` (the scene DOES hold the WindSystem's serialized fields, block at MainScene.unity:803-832), and the setup wizard `WindsurferSetup.cs`, which only writes speed and direction, and only when it creates a NEW WindSystem (WindsurferSetup.cs:511-518 return the existing one untouched). Until Session 27 the wizard wrote to field names that do not exist on `WindSystem` (`_baseWindSpeed`, `_baseWindDirection`; Legacy/Documentation/KNOWN_ISSUES.md:77 and PROGRESS_LOG.md:119), so a WindSystem created by the wizard before Session 27 silently got the C# defaults.

| Name (GDScript) | Value | Unit | Source | Conflicts |
|---|---|---|---|---|
| `wind_from_bearing_deg` | 270 (from West) | deg | C# default WindSystem.cs:22; MainScene.unity:821 in every commit from Session 13 to 27 | wizard default 45 (WindsurferSetup.cs:63, slider :141); WindManager default 45 (WindManager.cs:16); scene_config.json:199 45 (old WindManager, history) |
| `base_speed_kt` | 15 | kt | C# default WindSystem.cs:26; MainScene.unity:822 at commits ca7a7b1 (Session 13), 5a1857a (Session 22) and 757d5cf (Session 27) | 13.3 kt with gusts and gradient OFF at commit 4c45223 (2025-12-27, "Validate physics"); **22 kt** at commit b5ed2ea (Session 26, 2026-01-02); wizard 12 kt (WindsurferSetup.cs:62, slider range 5 to 30 at :140); WindManager 8 m/s = 15.55 kt (WindManager.cs:13); scene_config.json:198 8 m/s (history) |
| `base_speed_ms` | 7.7167 | m/s | 15 kt × 0.514444 | – |
| `gusts_enabled` | true | – | WindSystem.cs:30; MainScene.unity:823 | off at commit 4c45223 |
| `gust_intensity` | 0.2 | – | WindSystem.cs:34 (range 0 to 0.5, :33); MainScene.unity:824 | WindManager `_speedVariation` 0.2 (WindManager.cs:24) agrees |
| `gust_period_s` | 8 | s | WindSystem.cs:37; MainScene.unity:825 | – |
| gust harmonics | 1, 2.3, 5.7 × base frequency, weights 0.6, 0.3, 0.1 | – | WindSystem.cs:119-121 | – |
| `shifts_enabled` | false | – | WindSystem.cs:40; MainScene.unity:826 | – |
| `max_shift_deg` | 15 | deg | WindSystem.cs:44 (range 0 to 30, :43); MainScene.unity:827 | WindManager `_directionVariation` 10 (WindManager.cs:28) |
| `shift_period_s` | 60 | s | WindSystem.cs:47; MainScene.unity:828 | – |
| shift secondary | 0.37 × frequency, 0.3 × amplitude | – | WindSystem.cs:133-134 | – |
| `height_gradient_enabled` | true | – | WindSystem.cs:51; MainScene.unity:829 | off at commit 4c45223 |
| `reference_height_m` | 1 | m | WindSystem.cs:54; MainScene.unity:830 | meteorological standard is 10 m (WMO Guide No. 8); see OPEN 1 |
| `shear_exponent` | 0.14 | – | WindSystem.cs:58 (range 0.05 to 0.4, :57); MainScene.unity:831 | literature over open sea about 0.11 (Hsu et al. 1994); 1/7 = 0.143 is the flat-land value |
| `z_min` (gradient floor) | 0.1 | m | WindSystem.cs:152 and :155 | legacy skips the gradient below it (jump); spec floors it (continuous) |
| speed clamp | 0 to 50 | kt | WindSystem.cs:25 (slider) and :198 (`AdjustWindSpeed`) | – |
| `KNOT_MS` | 0.514444 | m/s per kt | PhysicsConstants.cs:22; exact value 1852/3600 = 0.514444… | PhysicsConstants.cs:21 `MS_TO_KNOTS = 1.94384` (1/0.514444 = 1.943846) |
| WindManager `_gustFrequency` | 0.1 | 1/s | WindManager.cs:31 | reference only |
| WindManager noise scale | 0.01 | 1/m | WindManager.cs:105-106, :120 | reference only |

**Which wind did the last validated Unity build use?** Most likely 15 kt from 270° with gusts (0.2, 8 s) and the height gradient (1 m, 0.14) on, shifts off. Reasons: those are the C# defaults, the scene file carried exactly those values in the Session 13, 22 and 27 commits, and the plan's validation targets ("25 to 30 km/h in 15 kt of wind", REBUILD_PLAN.md open question 1) were written against them in Session 22. Two deviations are on record: the 2025-12-27 validation commit (4c45223) ran 13.3 kt with gusts and gradient OFF, so the "physics validated" upwind results of that day were measured in steady wind; and the Session 26 commit (b5ed2ea) stored 22 kt, which the log does not explain (OPEN 2). The wizard's 12 kt from 45° never reached a committed scene.

Because the gradient was sampled at the board origin (8.5, point 2), the sail in those builds effectively saw the base wind at rest and 12 to 20 % LESS than the base wind while planing. Any Phase 4 comparison with legacy top speeds has to keep this in mind: the legacy "15 kt" was closer to 12.5 to 13.5 kt at the sail once planing.

**OPEN 1 (team decision):** at what height is the configured wind speed defined? Options: (a) `reference_height_m = 10` (forecast convention; the sail at 2.5 m then gets 0.82 × the configured speed, 15 kt → 12.4 kt); (b) `reference_height_m` = the centre-of-effort height, so the configured number is the wind at the sail and the gradient only matters for visuals (flags at other heights) and for a future rig-height dependence. Recommendation: (b) for Phase 2 to 5 (it is what "15 kt at the sail" in the validation targets means, and the constant-wind mode is then identical to the gradient mode at the sail), and revisit when a "forecast" wind display is added.

**OPEN 2:** why the Session 26 scene stored 22 kt (high-speed stability testing is the likely reason, since Session 26 fixed porpoising and 20+ kt stability, but the log does not say).

### Where the force acts

The wind field applies no force. Its output is consumed by:

- the sail model, which needs `v_wind_true` at the sail's centre of effort (legacy: at the board origin, AdvancedSail.cs:163; spec: at the CE, see 8.5) to form `v_apparent = v_wind_true - v_boat` (SailingState.cs:100);
- the wave field, whose wave directions follow the wind: waves travel toward `current_from_bearing + 180°` (WaterSurface.cs:111-114) and the water shader gets `-from_direction()` and the current speed (WaterSurface.cs:157-161);
- visuals and audio: the wind arrows on the water (WindDirectionIndicator.cs:145 and :159), the wind ambience (WindAmbienceAudio.cs:101, uses apparent wind when a sail exists).

None of these feed anything back into the wind field (architecture rule 2).

### Signs and the Unity-to-Godot translation

| Item | Unity (left-handed, North = +Z) | Godot D4 (right-handed, North = −Z) | Flips? |
|---|---|---|---|
| FROM unit vector for bearing `b` | `(sin b, 0, cos b)` (WindSystem.cs:176-181) | `(sin b, 0, -cos b)` | z sign flips |
| Velocity vector for bearing `b` | `(sin(b+180°), 0, cos(b+180°)) * s = (-sin b, 0, -cos b) * s` (WindSystem.cs:161-168) | `(-sin b, 0, cos b) * s` | z sign flips |
| Bearing from a FROM vector `f` | `atan2(f.x, f.z)` | `atan2(f.x, -f.z)` | z sign flips |
| Compass heading of the bow | `atan2(fwd.x, fwd.z)` with `fwd = transform.forward = +Z` | `atan2(fwd.x, -fwd.z)` with `fwd = -basis.z` | z sign flips |
| Bearing arithmetic (shift, wrap, `+180°`) | plain numbers | plain numbers | no |
| Gust factor, height factor | scalars | scalars | no |
| Positive shift | veers (clockwise on the compass) | veers | no |
| Positive rotation about +Y | turns the bow clockwise seen from above (to starboard) | turns the bow counter-clockwise seen from above (to PORT) | yes: a positive `yaw_rate` DEcreases the heading in Godot |
| `Vector3.SignedAngle(a, b, up)` for wind angles | positive when `b` is clockwise from `a` seen from above (uses the left-handed cross product) | `a.signed_angle_to(b, Vector3.UP)` is positive counter-clockwise, i.e. toward PORT | yes: do not use it; use `atan2(from_local.x, -from_local.z)` (CLAUDE.md rule 5) |
| TWA vs AWA sign in the legacy | `TrueWindAngle = SignedAngle(windFrom, fwd, up)` (AdvancedSail.cs:182) but `ApparentWindAngle = SignedAngle(fwd, windFrom, up)` (SailingState.cs:113): swapped arguments, so the legacy TWA was POSITIVE for wind from PORT while the AWA was positive for wind from starboard | one formula for both: `atan2(from_local.x, -from_local.z)` | legacy bug; the wrong-sign TWA reached the HUD (AdvancedTelemetryHUD.cs:190) and was used as the AWA fallback below 0.1 m/s apparent wind (SailingState.cs:117), where it could flip `sail_side` |
| `WindManager` velocity sign | returned the FROM vector times speed (WindManager.cs:124-127), contradicting IWindProvider.cs:13 | velocity = −from × speed | legacy bug, not to be copied |

The wind field is horizontal, so the only frame-dependent step is 8.2. Get that one right (the test with four bearings pins it) and everything downstream is a scalar or a compass number.

### Stabilisers and fudges in this model

The wind field contains no stabilisers in the plan's sense (nothing was added to hide another model's problem). There are four artificial or doubtful choices:

1. **Height gradient skipped below 0.1 m, jumping to 0.724 just above** (WindSystem.cs:152-156). Added in Session 13 (commit ca7a7b1, when `WindSystem` was created) as part of the original design, not in response to a symptom. It hides nothing, it is just a bug. **Drop the skip; keep a continuous floor at `z_min = 0.1 m`.**
2. **Wind sampled at the board origin** (AdvancedSail.cs:163), which turns the gradient into a "less wind when planing" effect. Not deliberate. It may have slightly masked an over-powered sail at planing speeds in the Session 22 to 26 tuning. **Drop: sample at the centre-of-effort height.** Phase 4 top-speed comparisons must expect a few percent MORE drive than the legacy had at the same configured wind.
3. **Deterministic gusts with phase 0 at start** (WindSystem.cs:66, :116). Deliberate simplicity. It is a feature for tests (reproducible) and a weakness for play (every session has the same gust sequence). **Keep for Phase 2 (off by default in the sim tests; on in the game); re-evaluate in Phase 6** by adding an optional random phase offset and a slow noise component, or the `WindManager`-style spatial noise so gust patches can be drawn on the water.
4. **Reference height 1 m and exponent 0.14.** Deliberate but unexamined choices. **Re-evaluate** with OPEN 1; the exponent can stay 0.14 (0.11 is more accurate over the sea; the difference at the sail is about 1 %).

And the plan's default applies: Phase 2 starts in constant-wind mode (gusts, shifts and gradient off). Gusts and the gradient are physics, not fudges, and come back in Phase 5 or 6 once the flat-water polar is validated in steady wind, exactly as the 2025-12-27 validation commit did (gusts and gradient off, 4c45223).

### What Phase 2 must implement

- [ ] `WindConfig` resource (`Game/config/wind_default.tres`) with: `wind_from_bearing_deg = 270`, `base_speed_kt = 15`, `gusts_enabled = false`, `gust_intensity = 0.2`, `gust_period_s = 8`, `shifts_enabled = false`, `max_shift_deg = 15`, `shift_period_s = 60`, `height_gradient_enabled = false`, `reference_height_m` (per OPEN 1; 1 m until decided), `shear_exponent = 0.14`, `z_min_m = 0.1`. Degrees and knots in the config because the team thinks in them; convert once when the `WindField` is created (`KNOT_MS = 0.514444`, `deg_to_rad`).
- [ ] `WindField` class in `Game/sim/` (RefCounted, no Nodes) with `step(dt)`, `velocity_at(world_point) -> Vector3`, `from_direction() -> Vector3`, `current_speed_ms`, `current_from_bearing_rad`, `set_wind(bearing_rad, speed_ms)` (wrap with `fposmod`, clamp 0 to 25.7 m/s), and `time_s`.
- [ ] Bearing → vector exactly as 8.2: `velocity = Vector3(-sin(b), 0, cos(b)) * speed`. No `signed_angle_to`, no `rotated()` tricks.
- [ ] Gusts as 8.3 (three sines, weights 0.6/0.3/0.1, harmonics 1/2.3/5.7), phase wrapped with `fposmod`, computed once per `step`.
- [ ] Shifts as 8.4 (two sines, 0.37 and 0.3), off by default.
- [ ] Height gradient as 8.5 with the continuous floor; the sail queries the wind at its centre-of-effort position, never at the board origin.
- [ ] Constant-wind mode is simply "all three toggles off"; tests construct the field that way. No separate class.
- [ ] `Telemetry` reports `true_wind_speed_ms`, `wind_from_bearing_deg` and the TWA computed with `atan2(from_local.x, -from_local.z)`; the HUD (Phase 3) converts to knots and degrees.
- [ ] Nothing visual (arrows, flags, shader) ever writes into `WindField` (rule 2).

### Tests Phase 2 should write

- **Cardinal bearings** (constant mode, 1 m/s): bearing 0° → `velocity_at(any) == Vector3(0, 0, 1)`; 90° → `(-1, 0, 0)`; 180° → `(0, 0, -1)`; 270° → `(1, 0, 0)`. And `from_direction()` is the negative of each. Use `assert_almost_eq` with 1e-6.
- **Knots conversion**: `base_speed_kt = 15` → `current_speed_ms == 7.71666` (±1e-4); 15 kt from 270° → `velocity_at(p) == Vector3(7.71666, 0, 0)`.
- **Bearing round trip**: for bearings 0, 45, 90, 135, 180, 225, 270, 315°, `fposmod(atan2(f.x, -f.z), 2*PI)` of `from_direction()` returns the bearing (±1e-6). For 45° the from-vector is `(0.70711, 0, -0.70711)` and the velocity at 12 kt (6.1733 m/s, the wizard's default) is `(-4.3652, 0, 4.3652)`.
- **TWA sign follows D4**: wind from 270°; board heading 0° → TWA −90° (wind from port); heading 180° → +90° (from starboard); heading 90° → 180° (±1e-6, compare with `wrapf`). Build the board basis with `Basis(Vector3.UP, -heading_rad)` (negative because +Y rotation turns the bow to port) and check `-basis.z` is the expected forward first.
- **Constant mode is constant**: after `step(0.02)` 500 times (10 s) and at points `(0,0,0)`, `(100, 5, -300)`, `(0, 0.05, 0)`, `velocity_at` is unchanged.
- **Gust factor**: `gust_period_s = 8`, `gust_intensity = 0.2`, gusts on: at `time_s = 0` the factor is exactly 1.0; at `time_s = 2.0` s (phase π/2) hand calculation gives `gust = 0.6·1 + 0.3·sin(3.6128) + 0.1·sin(8.9535) = 0.6 − 0.13620 + 0.04540 = 0.50920`, factor 1.10184, speed 8.5025 m/s for a 15 kt base (±1e-3). Also check the factor stays within [0.80, 1.20] over 1000 s of 0.02 s steps and that its mean over 8000 s is 1.000 ± 0.005.
- **Shift**: `max_shift_deg = 15`, `shift_period_s = 60`, shifts on: at `time_s = 15` s (phase π/2) hand calculation gives `15·1 + 4.5·sin(0.58119) = 15 + 2.4706 = 17.4706°`; `current_from_bearing_deg == 287.4706` for a 270° base (±0.01°). The velocity vector's bearing must then be 287.47° too.
- **Height gradient** (`reference_height_m = 1`, `shear_exponent = 0.14`, gradient on): factor at z = 2 m is `2^0.14 = 1.10191`; at 0.5 m `0.90752`; at 0.1 m `0.72444`; at 0.05 m the same 0.72444 (floor, no jump: the value at 0.0999 and 0.1001 differ by less than 1e-3). At 15 kt the speed at 2 m is 8.5028 m/s. With the gradient off the factor is 1 at every height.
- **Sample the sail, not the hull**: with the gradient on, raising the board origin by 0.3 m while the CE height stays the same must not change the sail's true wind (guards against re-introducing legacy point 2 of 8.5).
- **Setter**: `set_wind(deg_to_rad(-10), 30)` gives bearing 350° and speed 25.7222 m/s (clamped from 30 to 25.7222 = 50 kt); changing the base speed mid-gust does not reset `time_s`.
- **No vertical wind**: `velocity_at(p).y == 0` for any settings.

Sample outputs for the legacy defaults (15 kt from 270°, gusts 0.2 / 8 s on, shifts off, gradient on with 1 m and 0.14), useful as golden values once the toggles are on:

| `time_s` | query point (x, y, z) m | gust factor | height factor | speed m/s | speed kt | `v_wind_true` m/s |
|---|---|---|---|---|---|---|
| 0 | (0, 1.0, 0) | 1.0000 | 1.0000 | 7.717 | 15.00 | (7.717, 0, 0) |
| 0 | (0, 0.5, 0) | 1.0000 | 0.9075 | 7.003 | 13.61 | (7.003, 0, 0) |
| 0 | (0, 0.05, 0) | 1.0000 | 0.7244 (legacy: 1.0000) | 5.590 (legacy 7.717) | 10.87 (legacy 15.00) | (5.590, 0, 0) |
| 0 | (50, 2.0, −80) | 1.0000 | 1.1019 | 8.503 | 16.53 | (8.503, 0, 0) |
| 1.0 | (0, 1.0, 0) | 1.1237 | 1.0000 | 8.672 | 16.86 | (8.672, 0, 0) |
| 2.0 | (0, 1.0, 0) | 1.1018 | 1.0000 | 8.503 | 16.53 | (8.503, 0, 0) |
| 2.0 | (0, 0.5, 0) | 1.1018 | 0.9075 | 7.716 | 15.00 | (7.716, 0, 0) |
| 6.0 | (0, 1.0, 0) | 0.8405 | 1.0000 | 6.486 | 12.61 | (6.486, 0, 0) |
| 6.0 | (0, 0.5, 0) | 0.8405 | 0.9075 | 5.886 | 11.44 | (5.886, 0, 0) |
| 8.0 | (0, 1.0, 0) | 1.0380 | 1.0000 | 8.010 | 15.57 | (8.010, 0, 0) |

(The gust is not periodic with 8 s because of the 2.3 and 5.7 harmonics, which is why `time_s = 8` does not return the factor to 1.) With shifts on as well (15°, 60 s), the bearing at `time_s = 15` s would be 287.47°, giving `v_wind_true = speed × (−sin 287.47°, 0, cos 287.47°) = speed × (0.9538, 0, 0.3003)`: still mostly toward the East, with a component toward the South because the wind now comes from a little North of West.

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/`):

- `Scripts/Environment/WindSystem.cs`: fields and defaults :19-61; state :63-67; properties :72-87 (knots conversion :82, :87); `Awake` init :99-100; `Update` :103-106; `UpdateWind` :108-139 (gusts :113-124, shifts :126-135, apply :137-138); `GetWindAtPosition` :147-169 (gradient :151-158, vector :160-168); `GetWindFromDirection` :174-182; setters :187-208; gizmos :210-251.
- `Scripts/Physics/Wind/WindManager.cs`: fields :11-35; `Awake` random offsets :62-64; `Update` :74-82; `UpdateWindDirection` :84-89; `GetWindAtPosition` :95-128; `SetWindSpeedKnots` :151-154.
- `Scripts/Physics/Wind/IWindProvider.cs`: interface :9-26 (velocity "blows TO" :13).
- `Scripts/Editor/WindsurferSetup.cs`: wizard defaults :62-63; sliders and help text :140-142; `EnsureWindSystem` :511-547 (property writes :536-544); windsurfer start position :683; mast and boom heights :732-735.
- `Scenes/MainScene.unity`: WindSystem object :795-832 (values :821-831); windsurfer transform :390-391. History via `git show <commit>:WindsurfingGame/Assets/Scenes/MainScene.unity`: ca7a7b1 (Session 13, 2025-12-27) 15 kt; 4c45223 (2025-12-27) 13.3 kt, gusts and gradient off; 5a1857a (Session 22, 2025-12-28) 15 kt; b5ed2ea (Session 26, 2026-01-02) 22 kt; 757d5cf (Session 27, 2026-09-28) 15 kt.
- `Scripts/Physics/Board/AdvancedSail.cs`: wind source lookup :93-116; sampling at `transform.position` :161-168; legacy TWA :179-184.
- `Scripts/Physics/Core/SailingState.cs`: `CalculateApparentWind` :97-119 (apparent wind :100, AWA :113, TWA fallback :117); VMG :72-75; `MastHeight` 4.6 m :139; `BoomHeight` 1.4 m :155.
- `Scripts/Physics/Core/PhysicsConstants.cs`: `MS_TO_KNOTS` :21, `KNOTS_TO_MS` :22.
- `Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs`: board thickness 0.12 m :42; hull bottom at −thickness/2 :185.
- `Scripts/Physics/Water/WaterSurface.cs`: waves follow the wind :111-114; shader wind :157-161.
- `Scripts/Physics/Board/ApparentWindCalculator.cs:79`, `Scripts/Visual/WindDirectionIndicator.cs:145,159`, `Scripts/Audio/WindAmbienceAudio.cs:101`, `Scripts/UI/AdvancedTelemetryHUD.cs:188-191`: other consumers.
- `ProjectSettings/TimeManager.asset:6`: fixed time step 0.02 s.

Legacy documentation:

- `Legacy/Documentation/PHYSICS_DESIGN.md` §3 :263-296 (apparent wind and sail force only; gusts and the gradient are not documented there), §5 :463-484 (Unity frame), §6 :486-507 (update loop sampling `GetWind(position)`).
- `Legacy/Documentation/PROGRESS_LOG.md:610` (Session 18/13 entry: WindSystem created), :119 (Session 27: wizard field-name bug), :1456 (Session 15: WindManager fallback), :923-935 (Session 4: WindManager created).
- `Legacy/Documentation/KNOWN_ISSUES.md:77` (wizard wind bug).
- `Legacy/Documentation/scene_config.json:185-204` (old WindManager: 8 m/s from 45°; history only, 2025-12-27).
- `Documentation/REBUILD_PLAN.md`: D4 table :57-70; Phase 2 `WindField` :163; open question 1 (top speed at 15 kt) :304.

Literature:

- Hsu, S. A., Meindl, E. A., Gilhousen, D. B. (1994). "Determining the power-law wind-profile exponent under near-neutral stability conditions at sea." Journal of Applied Meteorology 33(6): 757-765. Exponent about 0.11 over the sea.
- Wieringa, J. (1992). "Updating the Davenport roughness classification." Journal of Wind Engineering and Industrial Aerodynamics 41: 357-368. Roughness length about 0.0002 m for open sea (log-law alternative).
- WMO (2018). Guide to Instruments and Methods of Observation (WMO-No. 8), Part I, Chapter 5: standard anemometer height 10 m.
- International nautical mile 1852 m (First International Extraordinary Hydrographic Conference, Monaco, 1929): 1 kt = 0.514444 m/s.

---

## 9. Gerstner waves and the water surface

### Purpose

The water surface tells the rest of the simulation where the water is. Buoyancy asks it "how high is the water at this point?" and "which way is the surface tilted?" for every sample point on the hull; drag and damping can ask "how fast is the water moving here?". In Phase 2 the answer is trivial (flat water at a fixed height, tilted nowhere, not moving). In Phase 5 the surface becomes a sum of up to four **Gerstner waves**, and the same wave parameters drive the ocean shader, so the board floats on exactly the surface the player sees (plan decision D5).

A Gerstner (trochoidal) wave is the classic deep-water wave model used in games: every point of the surface moves on a circle. That gives the familiar shape with pointed crests and flat troughs, unlike a plain sine wave. The price is that the surface points also move **sideways**, so to find the height at a given world position you must first find which surface point ended up there. That is the "fixed-point solve" described below.

Two facts about the legacy code shape this section:
- The **validated Unity build (Session 26) sailed on flat water**. Its `WaterSurface.cs` was a sine-wave stub with `_enableWaves = false` (pre-Session-27 code, see Values). Every tuning number in the other sections was found on flat water.
- The Gerstner code (Session 27) was **never compiled or played** (pitfall 9). The maths was re-derived and checked numerically for this section (Python, 20 000 random points); the results are in the Formulas and Tests subsections. Where the legacy is wrong or approximate, this section says what to do instead.

### Inputs and outputs

| Name | Meaning | Unit |
|---|---|---|
| `x`, `z` (world) | Horizontal world position to query. Godot frame: +X = East, +Z = South. | m |
| `t` (`time_s`) | Simulation time, passed in by the caller (the simulation clock, not a wall clock) | s |
| `base_height_m` | Still-water level, world Y of the undisturbed surface | m |
| `enable_waves` | `false` = flat water; the whole wave model is skipped | – |
| `wind_from_bearing_deg` | Where the wind comes from, compass bearing (only used to orient the wave set when `align_to_wind` is true) | deg (table only) |
| Per wave `i` (up to 4): `direction_offset_deg` | Travel direction of this wave, as a compass bearing offset from the downwind direction (positive = clockwise seen from above) | deg (table only) |
| Per wave `i`: `wavelength_m` (`L_i`) | Crest-to-crest distance | m |
| Per wave `i`: `amplitude_m` (`A_i`) | Half the crest-to-trough height | m |
| Per wave `i`: `steepness` (`S_i`) | Crest sharpness, 0 (sine) to 1 (cusp). The sum over all waves must stay ≤ 1 | – |
| **Output** `height_m` | Water surface Y at world (x, z) | m |
| **Output** `normal` | Unit surface normal at world (x, z), pointing up out of the water | – |
| **Output** `velocity_ms` | Velocity of the water surface at world (x, z) (orbital velocity) | m/s |
| **Output** `displacement` | (dx, dy, dz) of the surface point whose rest position is (x, z); the shader uses this per vertex | m |
| **Output** shader parameters | Direction, steepness, wavelength and amplitude per wave, time, wind (names in 9.13) | mixed |

Derived per wave (computed once from the config, not tuned):

| Name | Formula | Unit |
|---|---|---|
| `k_i` | wave number, `2π / L_i` | rad/m |
| `c_i` | phase speed, `sqrt(g / k_i)` | m/s |
| `omega_i` | angular frequency, `sqrt(g · k_i) = k_i · c_i` | rad/s |
| `T_i` | period, `L_i / c_i = 2π / omega_i` | s |
| `d_i` | unit travel direction in the horizontal plane, `Vector2(x, z)` | – |

### Formulas

Shared notation: `g = 9.81 m/s²`, sums `Σ` run over the active waves (those with `A_i > 0`). All angles in radians unless a name ends in `_deg`.

**9.1 Dispersion relation (how fast a wave of a given length travels).**
In deep water (depth much larger than half the wavelength; true for our lake) longer waves travel faster. This is the only physics in the model; everything else is geometry.

```
k_i     = 2π / max(0.5, L_i)              # wave number, rad/m (the 0.5 m floor is a legacy guard, see 9.14)
c_i     = sqrt(g / k_i)                   # phase speed, m/s      (legacy: GerstnerWave.cs:51, :89; shader :146)
omega_i = sqrt(g · k_i) = k_i · c_i       # angular frequency, rad/s (not written out in the legacy; implied by k·c)
T_i     = L_i / c_i = sqrt(2π · L_i / g)  # period, s             (legacy: GerstnerWave.cs:54)
```
The legacy writes the phase as `k · (d·r − c·t)`, which is the same as `k·(d·r) − omega·t` because `k·c = omega`. So the dispersion relation used is the standard deep-water one, `omega² = g·k`. There is no depth term and no surface-tension term.

**9.2 Travel direction (D4 frame).**
A wave's travel direction is a compass bearing: `travel_bearing_deg = base_bearing_deg + direction_offset_deg_i`, where `base_bearing_deg = wind_from_bearing_deg + 180` when `align_to_wind` is true (waves travel *with* the wind, so away from where it comes from), and `0` (waves travel North) when it is false or there is no wind source (legacy: WaterSurface.cs:110-125).

A compass bearing `b` (clockwise from North, seen from above) becomes a unit vector in the Godot horizontal plane as
```
d_i = Vector2( sin(b_rad),  -cos(b_rad) )       # (x, z): North = (0, -1), East = (1, 0), South = (0, 1), West = (-1, 0)
```
Reason for the minus: North is world −Z in Godot (D4). The legacy used `(sin b, cos b)` because Unity's North is +Z (GerstnerWave.cs:131-135). See "Signs" below. Keep the offsets as bearings and use this formula; do **not** build the direction by rotating a vector about +Y (that flips the sign of the offset in Godot).

**9.3 Phase.**
For a surface point whose *rest* (undisplaced) horizontal position is `r = (x_rest, z_rest)`:
```
phase_i = k_i · (d_i.x · x_rest + d_i.y · z_rest) − omega_i · t        # legacy: k·(d·r − c·t), GerstnerWave.cs:91, shader :148
```
`d_i · r` is the distance along the travel direction. The phase decreases with time, so the pattern moves in direction `+d_i`. The dot product is the same in any frame, so this line needs no translation once `d_i` is in D4.

**9.4 Displacement of a rest point (the Gerstner shape).**
Each rest point moves on a circle: sideways by `S_i / k_i` along the travel direction, and vertically by `A_i`.
```
horizontal_i = (S_i / k_i) · cos(phase_i)                                # m, along d_i
disp.x = Σ d_i.x · horizontal_i
disp.z = Σ d_i.y · horizontal_i
disp.y = Σ A_i · sin(phase_i)
world_point = (x_rest + disp.x,  base_height_m + disp.y,  z_rest + disp.z)   # legacy: GerstnerWave.cs:88-101, shader :154-155
```
Physical reasoning: in a deep-water wave each water particle goes round a circle once per period: forward on the crest, backward in the trough. Adding the circular motion to the rest position produces the trochoid. GPU Gems ch. 1 (Finch 2004) writes the horizontal radius as `Q_i · A_i`; the legacy writes it as `S_i / k_i`, so `Q_i = S_i / (k_i · A_i)`. This choice makes the crest sharpness depend only on `S_i`, whatever the amplitude (comment at GerstnerWave.cs:96-97). Note that a *physically consistent* trochoid has equal horizontal and vertical radii, i.e. `S_i = k_i · A_i`. The legacy defaults are 2.8 to 4.5 times steeper than that (table in Values); see 9.14.

Sign check at `t = 0`, single wave travelling North (`d = (0, −1)`), `L = 10 m`: `phase = k · (−z_rest)`. At `z_rest = −2.5 m` (2.5 m North of the origin) `phase = π/2`, `disp = (0, +A, 0)`: a crest, not shifted sideways. At `z_rest = 0`, `phase = 0`, `disp = (0, 0, −S/k)`: the point at mean height has moved North (toward the crest). That is the trochoid: points crowd toward the crests.

**9.5 Height at a world point (fixed-point solve).**
Buoyancy asks for the height *at* world `(x, z)`, but 9.4 gives the height of the point that *started* at `(x, z)`. We need the rest point `r` with `r + disp_xz(r, t) = (x, z)`. The legacy solves it by fixed-point iteration (GerstnerWave.cs:112-125):
```
r = (x, z)
repeat n_iter times:
    disp = displacement(r, t)
    r = (x − disp.x,  z − disp.z)
height_m = base_height_m + displacement(r, t).y
```
Why it converges: the horizontal displacement changes by at most `Σ S_i` per metre of rest position (that is the fold condition, 9.8), so with `Σ S_i < 1` each iteration shrinks the error by at least that factor. The legacy uses **3 iterations, no tolerance check** (`HEIGHT_QUERY_ITERATIONS = 3`, GerstnerWave.cs:66). Measured on the default four-wave set (`Σ S = 0.7`), worst case over 20 000 random points and times:

| Iterations | Worst horizontal error of `r` (m) | Worst height error (m) |
|---|---|---|
| 1 | 0.211 | 0.0263 |
| 2 | 0.077 | 0.0080 |
| 3 (legacy) | 0.032 | 0.0030 |
| 4 | 0.014 | 0.0011 |
| 5 | 0.0059 | 0.00043 |
| 6 | 0.0025 | 0.00018 |
| 8 | 0.0005 | 0.00003 |

Each iteration shrinks the error by about 0.42 for this set. **Spec:** iterate until the horizontal step `|r_new − r_old|` is below `1 mm`, with a hard cap of 8 iterations (the cap keeps cost bounded and the result deterministic). For the default set that is 6 to 7 iterations and a height error below 0.2 mm, which is negligible next to the 1-2 % buoyancy tolerance. With a single wave (`S = 0.25`) three iterations are already exact to 0.1 mm. The height is bounded: `|height_m − base_height_m| ≤ Σ A_i` (observed range −0.2008 to +0.1971 m for `Σ A = 0.202 m`).

**9.6 Surface normal.**
Three formulas exist; they are *not* equivalent for more than one wave:

(a) **Exact** normal of the displaced surface, from the two tangent vectors of 9.4 (derivatives with respect to `x_rest` and `z_rest`). This is what the spec prescribes for both GDScript and the shader:
```
T_x = ( 1 − Σ d_i.x² · S_i · sin(phase_i),   Σ A_i · k_i · d_i.x · cos(phase_i),   −Σ d_i.x · d_i.y · S_i · sin(phase_i) )
T_z = ( −Σ d_i.x · d_i.y · S_i · sin(phase_i),   Σ A_i · k_i · d_i.y · cos(phase_i),   1 − Σ d_i.y² · S_i · sin(phase_i) )
normal = normalize( T_z × T_x )          # flat water: (0,0,1) × (1,0,0) = (0, 1, 0), points up
```
It is evaluated at the *rest* point (the solved `r` from 9.5 when asked at a world point; the vertex's own position in the shader).

(b) **GPU Gems eq. 12**, used by the legacy shader (OceanWater.shader:157-161):
```
normal ≈ normalize( −Σ d_i.x · k_i · A_i · cos(phase_i),   1 − Σ S_i · sin(phase_i),   −Σ d_i.y · k_i · A_i · cos(phase_i) )
```
For a single wave this equals (a) exactly (checked: difference 2·10⁻⁶ °). For several waves it drops the cross terms of the tangent product. On the default set it is off by up to **4.3°** from (a). Do not use it for the physics, and do not use it in the shader either, since D5 wants one function; (a) costs a handful of extra multiplies per vertex.

(c) **Finite differences** of the world-point height, used by the legacy CPU side (WaterSurface.cs:181-198): heights at `(x, z)`, `(x + δ, z)`, `(x, z + δ)` with `δ = 0.1 m` (`NORMAL_SAMPLE_DELTA`, :50), then
```
normal = normalize( −(h_x − h_0)/δ,  1,  −(h_z − h_0)/δ )      # = normalize(Cross(tangent_z, tangent_x)) in the legacy
```
This is a correct heightfield normal in any frame (the cross-product algebra is identical in Unity and Godot), but it costs three fixed-point solves and, with the legacy's 3 iterations and `δ = 0.1 m`, is off by up to 1.8° on the default set (the shortest default wave is only 1.8 m long, so 0.1 m is 5.5 % of a wavelength). It also means the CPU normal and the GPU normal were *different formulas* in the legacy, against its own D5-style intent. Use (a).

Maximum slope of the default set: 10.3° (so `normal.y ≥ 0.984`).

**9.7 Orbital (surface) velocity.**
The legacy has no water-velocity query (IWaterSurface.cs:8-33 has height and normal only), but the Phase 2 interface needs one for drag and damping relative to moving water. It is the time derivative of 9.4 at a fixed rest point (checked against a numerical derivative, max error 3·10⁻⁸ m/s):
```
velocity.x = Σ d_i.x · S_i · c_i · sin(phase_i)
velocity.z = Σ d_i.y · S_i · c_i · sin(phase_i)
velocity.y = −Σ A_i · omega_i · cos(phase_i)
```
Reasoning: `d(phase)/dt = −omega_i`, so the horizontal term `(S_i/k_i)·cos` differentiates to `S_i·(omega_i/k_i)·sin = S_i·c_i·sin`, and the vertical term `A_i·sin` to `−A_i·omega_i·cos`. On a crest (`sin = 1`) the water moves forward with the wave at `S_i · c_i`; in the trough it moves backward; on the front face it rises. Evaluate at the solved rest point `r` from 9.5. This is the velocity of the surface itself; below the surface real orbital velocities decay as `exp(−k·depth)`, which we ignore because the hull sits within a few centimetres of the surface.

Caution (see 9.14): with the legacy steepness values the horizontal orbital speed is `S_i · c_i`, 2.8 to 4.5 times the physical `A_i · omega_i`. For the 14 m default wave that is 0.93 m/s instead of 0.21 m/s. If Phase 5 feeds this velocity into hull drag, either lower the steepness defaults toward `k_i · A_i` or use `A_i · omega_i` for the horizontal terms. **OPEN:** which of the two Phase 5 should use is a tuning decision to take when the validation suite runs on waves.

**9.8 Steepness limit (crests must not fold).**
Along the travel direction the world position of a rest point is `x_rest + (S/k)·cos(k·x_rest − …)`, whose derivative is `1 − S·sin(…)`. It reaches zero at the crest when `S = 1` and goes negative (the surface folds over itself, a loop) for `S > 1`. Checked numerically: minimum derivative 0.5, 0.0 and −0.2 for `S = 0.5, 1.0, 1.2`. With several waves the safe rule is
```
Σ S_i (active waves) ≤ 1             # legacy warns above 1: WaterSurface.cs:86-91, GerstnerMath.TotalSteepness :138-151
```
This is conservative when the waves travel in different directions, and it is also what keeps the fixed-point solve of 9.5 convergent. The config Resource should validate it (warn in the editor, clamp in tests).

**9.9 Flat-water mode and disabled waves.**
```
if not enable_waves:  height = base_height_m; normal = Vector3.UP; velocity = Vector3.ZERO      # legacy: WaterSurface.cs:170-173, 183-186
```
Waves with `A_i ≤ 0` are skipped in every sum (GerstnerWave.cs:86; shader :143) and do not count toward `Σ S_i` (:145-149). Slots beyond the configured count are published to the shader as direction `(0, 1)`, steepness 0, wavelength 10, amplitude 0 (WaterSurface.cs:147; note `(0, 1)` means "+Z = North" in Unity and "South" in Godot, irrelevant at amplitude 0 but use `(0, −1)` for tidiness). Phase 2 implements only this branch, as a `FlatWater` implementation of the same interface. **Also** treat `Σ A_i = 0` as flat: it lets the Phase 5 test "flat when the amplitude is 0" pass without a special case in the caller.

**9.10 Time source.**
The legacy used Unity's `Time.time` (scaled game time since start) both in the physics query (inside `FixedUpdate`, where `Time.time` equals the fixed-step time; WaterSurface.cs:175) and in the shader global set from `Update` (:152), so the two could differ by up to one fixed step (0.02 s, ProjectSettings/TimeManager.asset:6). **Spec:** the simulation owns a clock `time_s` that advances by `dt` in `step()`, and every water query takes `t` as an argument (architecture rule 1: the time step is passed in; no `Time`/`Engine` calls in `Game/sim/`). The visual side sets the shader's time uniform from the same clock each rendered frame, optionally plus `Engine.get_physics_interpolation_fraction() · physics_dt` so the water moves as smoothly as the interpolated board (both calls exist in 4.7: `Engine.get_physics_interpolation_fraction`, `RenderingServer.global_shader_parameter_set`, `ShaderMaterial.set_shader_parameter`). At `c = 4.7 m/s` one 60 Hz tick moves the longest default wave 8 cm, so the mismatch without the fraction is small but visible at the waterline.

**9.11 Helper values.**
```
total_amplitude_m = Σ max(0, A_i)                      # largest possible crest above base level; legacy TotalAmplitude :154-164
max_wave_height_m = enable_waves ? total_amplitude_m : 0    # legacy MaxWaveHeight, WaterSurface.cs:66
is_underwater(p)  = p.y < height_at(p.x, p.z, t)       # :212-215
depth_m(p)        = height_at(p.x, p.z, t) − p.y        # positive = below the surface; :220-223
```

**9.12 The wave set.**
The legacy does not *generate* waves from a spectrum or a seed; it holds a hand-written list of up to `MAX_WAVES = 4` components (GerstnerWave.cs:63, fixed by the four shader slots `_WaveA.._WaveD`). Only the directions depend on the wind (9.2); wavelength, amplitude and steepness are constants. There is no random seed and no dependence on wind speed. The default set ("gentle 15-knot chop: a long swell plus three shorter wind waves", WaterSurface.cs:233-246) is in Values. Direction offsets were refreshed every frame from the *current* wind direction, which includes the wind *shifts* (WindSystem.cs:138). Because `phase_i` depends on `d_i · r`, changing `d_i` while the game runs makes the whole surface jump at every point except the origin. Wind shifts were off by default (WindSystem.cs:40), so the legacy never saw this. **Spec:** compute `d_i` from the *base* wind bearing when the water is created or the base wind is changed by the user, never from the gust/shift term. If Phase 7 wants swell that slowly follows shifting wind, rotate the phase reference point, not the direction alone (out of scope here).

**9.13 Shader contract (names only, for D5).**
The legacy shader read these globals, published every frame by `WaterSurface.PublishShaderGlobals()` (WaterSurface.cs:132-163; OceanWater.shader:110-116):

| Legacy name | Content |
|---|---|
| `_WaveA`, `_WaveB`, `_WaveC`, `_WaveD` | `vec4(d.x, d.z, steepness, wavelength_m)` per wave |
| `_WaveAmplitudes` | `vec4` of the four amplitudes in m; 0 = slot disabled (also 0 for every slot when waves are off) |
| `_WaterTime` | time in s (9.10) |
| `_WaterWind` | `vec4(wind_to.x, wind_to.z, wind_speed_ms, 0)` for ripples and streaks; fallback North and 5 m/s (:155-156) |

Material properties the legacy shader exposed (rendering only, no physics meaning; OceanWater.shader:18-47): `_ShallowColor`, `_DeepColor`, `_DepthFade`, `_ScatterColor`, `_ScatterStrength`, `_RippleScale`, `_RippleStrength`, `_RippleSpeed`, `_Smoothness`, `_ReflectionStrength`, `_SpecularPower`, `_SpecularStrength`, `_RefractionStrength`, `_UseSceneDepth`, `_FoamColor`, `_EdgeFoamDistance`, `_CrestFoamThreshold`, `_CrestFoamStrength`, `_WindStreakStrength`, `_FoamScale`, `_GridEnabled`, `_GridColor`. The vertex stage also computed a rendering-only "crest factor" `Σ S_i·sin(phase_i) / Σ S_i` for foam (:163, :232); it is not part of the physics.

Proposed Godot layout (one Resource, D5): `WaveSetConfig extends Resource` with `enable_waves: bool`, `base_height_m: float`, `align_to_wind: bool`, `waves: Array[GerstnerWaveConfig]` (validated to at most 4 and `Σ S ≤ 1`), where `GerstnerWaveConfig extends Resource` has `direction_offset_deg`, `wavelength_m`, `amplitude_m`, `steepness`. The `WaveField` (sim side) and the water node (visual side) both read this Resource; the water node converts it to shader uniforms named `wave_a..wave_d` (or a `vec4[4]` array), `wave_amplitudes`, `water_time_s`, `water_wind`, mirroring the table above, with `d` computed by 9.2 so the shader never converts bearings itself.

**9.14 Guards and clamps in the legacy code (all kept, none is a fudge).**
- `wavelength_m` floor of 0.5 m in `k_i` (GerstnerWave.cs:48; shader :145) and inspector `[Min(0.5)]` (:26). Keep as validation in the Resource.
- `Period` guard `max(0.01, c)` (:54): unreachable with the 0.5 m floor (`c ≥ 0.88 m/s`); drop.
- Shader `normalize(d + (1e-5, 0))` (:147) guards a zero direction vector; unnecessary when `d` always comes from 9.2. Drop.
- `direction_offset_deg` range −180..180, `amplitude_m ≥ 0`, `steepness` 0..1 (:21-35): keep as `@export_range`.
- `count = min(waves.Length, MAX_WAVES, directions.Length)` and null checks (:82-86): the Resource validation replaces them.

### Values

Two legacy code generations exist. The **validated Session 26 build** used the older file; **Session 27** replaced it and was never run.

Wave component (class defaults, used when a wave is added in the inspector; GerstnerWave.cs):

| Name | Value | Unit | Source |
|---|---|---|---|
| `DirectionDegrees` | 0, range −180..180 | deg | GerstnerWave.cs:21-23 |
| `Wavelength` | 10, min 0.5 | m | GerstnerWave.cs:25-27, floor also :48 and OceanWater.shader:145 |
| `Amplitude` | 0.1, min 0 | m | GerstnerWave.cs:29-31 |
| `Steepness` | 0.25, range 0..1 | – | GerstnerWave.cs:33-35 |
| `MAX_WAVES` | 4 | – | GerstnerWave.cs:63; shader slots OceanWater.shader:110-113 |
| `HEIGHT_QUERY_ITERATIONS` | 3 (spec: tolerance 1 mm, cap 8; see 9.5) | – | GerstnerWave.cs:66, :117 |
| `g` | 9.81 | m/s² | PhysicsConstants.cs:18; OceanWater.shader:118 |

Water surface settings (Session 27 `WaterSurface.cs` and the hand-edited scene; the wizard `WindsurferSetup.cs` sets no `WaterSurface` field, it only creates the component at :409 and links it to buoyancy at :708, so the C# defaults applied):

| Name | Value | Unit | Source |
|---|---|---|---|
| `_baseHeight` | 0 (overwritten from the transform's Y on Awake, which is 0) | m | WaterSurface.cs:22, :71; MainScene.unity:643; water at origin WindsurferSetup.cs:399 |
| `_enableWaves` | **true** (Session 27) / **false** (pre-27 validated build) | – | WaterSurface.cs:26 and MainScene.unity:644 / pre-27 file (git `757d5cf^`) line 18, scene_config.json:175 |
| `_alignWavesToWind` | true | – | WaterSurface.cs:29; MainScene.unity:645 |
| `_driveShaderGlobals` | true | – | WaterSurface.cs:36; MainScene.unity:663 |
| `NORMAL_SAMPLE_DELTA` | 0.1 (not needed with the analytic normal) | m | WaterSurface.cs:50 |
| Base direction without wind | 0 (North) | deg | WaterSurface.cs:110 |
| Base direction with wind | `wind_from + 180` | deg | WaterSurface.cs:114 |
| Empty shader slot | dir (0, 1), steepness 0, wavelength 10, amplitude 0 | – | WaterSurface.cs:147, :143 |
| Fallback wind for the shader | North, 5 m/s | m/s | WaterSurface.cs:155-156 |
| Unity fixed time step | 0.02 | s | ProjectSettings/TimeManager.asset:6 |

Default wave set (WaterSurface.cs:237-246, identical in MainScene.unity:646-662; derived columns computed for this spec with `g = 9.81`):

| # | Offset (deg) | `L` (m) | `A` (m) | `S` | `k` (rad/m) | `c` (m/s) | `omega` (rad/s) | `T` (s) | `S/k` (m, horizontal radius) | `k·A` | `S/(k·A)` |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | +12 | 14 | 0.10 | 0.20 | 0.4488 | 4.675 | 2.098 | 2.994 | 0.446 | 0.0449 | 4.5 |
| 2 | −28 | 7 | 0.06 | 0.20 | 0.8976 | 3.306 | 2.967 | 2.117 | 0.223 | 0.0539 | 3.7 |
| 3 | +40 | 3.5 | 0.03 | 0.15 | 1.7952 | 2.338 | 4.197 | 1.497 | 0.084 | 0.0539 | 2.8 |
| 4 | −55 | 1.8 | 0.012 | 0.15 | 3.4907 | 1.676 | 5.852 | 1.074 | 0.043 | 0.0419 | 3.6 |
| Σ | | | **0.202** | **0.70** | | | | | | | |

The pre-Session-27 sine stub (the surface the tuning was done on, waves off): `_waveHeight 0.5 m`, `_waveLength 10 m`, `_waveSpeed 1 m/s`, `_waveDirection 0°`, `_enableWaves false` (git `757d5cf^:WindsurfingGame/Assets/Scripts/Physics/Water/WaterSurface.cs` lines 14-30; scene_config.json:174-180, history only). Its height formula was `A·sin(k·(d·r) − speed·k·t)` with a hand-set speed instead of the dispersion relation; it is superseded and not part of this spec.

Which values did the last validated build use? **Flat water** (`_enableWaves = false`). The Session 27 defaults (waves on, 0.2 m total amplitude) are untested. Phase 5 should start from the default set above because it is the only wave set anyone wrote down, but treat every number in it as a first guess. Literature check: for 15 kt of wind over a few kilometres of fetch, a significant wave height of 0.3-0.5 m and periods of 2-3 s are typical (PHYSICS_DESIGN.md:61-65 lists "calm: 0.1-0.3 m, 10-20 m, 3-5 s"); the default set (crest-to-trough up to 0.4 m, longest period 3.0 s) is in that range. Its steepness values are exaggerated compared with a physical trochoid (last column; a real wave has ratio 1), which sharpens the crests visually and inflates the horizontal orbital velocity (9.7).

Conflicts: `_enableWaves` (false in the validated build and scene_config.json, true in Session 27 code and scene). Class default wave (0°, 10 m, 0.1 m, 0.25) versus the four-wave default set: not a conflict, the class default is only what a *new* inspector entry gets. PHYSICS_DESIGN.md:47-55 writes the Gerstner shape as `x' = x − Q·A·sin(ψ)`, `y = A·cos(ψ)`; that is the same curve as 9.4 with `ψ = phase − π/2` and `Q·A = S/k`, so it is a notation difference, not a different wave.

### Where the force acts

This model produces **no force** itself. It is sampled by:
- Buoyancy: `height_at` at every hull sample point gives the local depth (legacy AdvancedBuoyancy.cs:229-236), and `normal_at` gave the direction of the per-point buoyancy force (:255-256). Physically, buoyancy is the resultant of water pressure and acts along `−g` (straight up) regardless of surface slope, so the buoyancy section should decide whether to keep the legacy's along-the-normal direction; for this section the normal is an output only.
- Hull drag and damping (Phase 5): the relative velocity `v_boat − velocity_at(point)` if the drag section adopts it.
- Visuals only: camera minimum height (ThirdPersonCamera.cs:234), spray and wake anchoring (BoardWakeEffects.cs:157-279). These read the same function but never feed back (D6).

Torque therefore arises only indirectly, through the buoyancy sample points sitting at different heights on a sloped surface.

### Signs and the Unity-to-Godot translation

| Item | Unity (legacy) | Godot (D4) | Flip? |
|---|---|---|---|
| North | +Z | −Z | **yes**: every `z` component of a compass vector changes sign |
| Bearing to unit vector | `(sin b, cos b)` as (x, z), GerstnerWave.cs:134 | `Vector2(sin b, −cos b)` as (x, z) | **yes** (z) |
| Positive direction offset | clockwise from downwind seen from above (bearing convention) | same, *if* built with the formula above | no, but a `+angle` rotation about +Y is clockwise in Unity and **counter-clockwise** in Godot, so never build `d` with `rotated(Vector3.UP, angle)` |
| `Vector3.forward` fallback (wind to North) | +Z, WaterSurface.cs:155 | `Vector3.FORWARD` = −Z = North | meaning unchanged, numbers flip |
| Phase `k·(d·r) − omega·t` | dot product | dot product | no |
| Vertical displacement, height, `+Y` up | +Y | +Y | no |
| Horizontal displacement `d · (S/k)·cos` | along `d` | along `d` | no once `d` is D4 |
| Heightfield normal `(−∂h/∂x, 1, −∂h/∂z)` from `Cross(tangentZ, tangentX)` | Unity `Vector3.Cross` uses the standard component formula | `Vector3.cross` uses the same formula; result `(0,1,0)` on flat water in both | no (the handedness of the *engine* does not change the algebra; only what `z` means changes) |
| Exact normal `T_z × T_x` (9.6a) | – | points up (checked on flat water) | – |
| Orbital velocity: forward on the crest | along `d` | along `d` | no |
| Wave travel with the wind | `wind_from + 180` | `wind_from_bearing_deg + 180` | no |
| `SignedAngle`, quaternions, `transform.forward` | not used in these files | – | – |

Worked example for a test: wind from the West (`wind_from_bearing_deg = 270`, the legacy default, WindSystem.cs:22). Base bearing 90 (waves travel East). Wave 1 (offset +12) travels at bearing 102: `d = (sin 102°, −cos 102°) = (0.9781, +0.2079)`, East and slightly **South** (toward +Z in Godot). In Unity the same wave had `d = (0.9781, −0.2079)`, also East and slightly South (−Z there). Same physical direction, opposite sign of the z component.

### Stabilisers and fudges in this model

There are no force stabilisers here (the model produces no force), but four things are artificial or doubtful:

1. **Exaggerated steepness** (`S ≈ 3-4.5 × k·A`, WaterSurface.cs:241-244). Added in Session 27 for looks (sharper crests at small amplitude). Hides nothing in the physics because the height stays within `Σ A`, but it inflates the horizontal orbital velocity three- to four-fold if 9.7 is used for drag. **Re-evaluate in Phase 5:** start with the legacy values for the look, and if wave-relative drag is enabled, either scale steepness toward `k·A` or use the physical horizontal speed `A·omega`.
2. **Fixed 3 iterations** in the height solve (GerstnerWave.cs:66). Chosen for cost; leaves up to 3 mm height and 3 cm horizontal error on the default set. **Replace** by the 1 mm tolerance / 8 cap of 9.5 (cost is still tiny: a few dozen sines per query).
3. **Approximate GPU normal** (eq. 12, OceanWater.shader:157-161) and **finite-difference CPU normal** (WaterSurface.cs:188-197): two different approximations of the same surface, up to 4.3° and 1.8° off. **Replace both** with the exact tangent cross product 9.6(a) so D5 holds literally.
4. **Per-frame re-alignment of wave directions to the shifting wind** (WaterSurface.cs:94-103). Makes the surface jump when shifts are on. **Drop:** align once to the base wind (9.12).

Nothing in this section was added to fight a symptom in another model, and nothing here needs to be re-added later; the flat-water branch (9.9) is not a fudge but the Phase 2 baseline.

### What Phase 2 must implement

Phase 2 (flat water only):
- [ ] A `WaterSurface` interface (an abstract RefCounted class) with `height_at(x: float, z: float, t: float) -> float`, `normal_at(x, z, t) -> Vector3`, `velocity_at(x, z, t) -> Vector3`, and a convenience `depth_at(point: Vector3, t) -> float` (= height − point.y).
- [ ] `FlatWater` implementing it: returns `base_height_m`, `Vector3.UP`, `Vector3.ZERO`.
- [ ] `WaterConfig` Resource with `base_height_m` (default 0) and `rho_water = 1025 kg/m³`; the wave fields can be added to it or to a separate `WaveSetConfig` in Phase 5.
- [ ] The simulation passes its own `time_s` to every call (rule 1; no engine time inside `Game/sim/`).

Phase 5 (waves), from this section alone:
- [ ] `GerstnerWaveConfig` and `WaveSetConfig` Resources (9.13 layout), with validation: at most 4 waves, `L ≥ 0.5`, `A ≥ 0`, `0 ≤ S ≤ 1`, `Σ S ≤ 1` (warn), offsets in −180..180.
- [ ] `WaveField` implementing `WaterSurface`: derived `k, c, omega, d` computed once from the config and the base wind bearing (9.1, 9.2); `displacement_at(rest_x, rest_z, t)` (9.4); `height_at` with the tolerance solve (9.5); `normal_at` exact (9.6a) at the solved rest point; `velocity_at` (9.7) at the solved rest point; flat behaviour when `enable_waves` is false or `Σ A = 0` (9.9).
- [ ] `shader_parameters()` on the config or field, returning the 9.13 table so the water node never recomputes directions.
- [ ] The ocean shader's vertex stage: the same 9.4 displacement and 9.6(a) normal, with a comment pointing at the GDScript function and vice versa (D5).
- [ ] The water node sets the time uniform from the simulation clock (9.10).

### Tests Phase 2 should write

All values below are for `base_height_m = 0`, `g = 9.81`, and a **single wave `L = 10 m`, `A = 0.1 m`, `S = 0.25`** (the class defaults) **travelling North** (bearing 0, `d = (0, −1)`), unless stated. Derived: `k = 0.628319 rad/m`, `c = 3.951342 m/s`, `omega = 2.482701 rad/s`, `T = 2.530786 s`, `S/k = 0.397887 m`. Use a tolerance of 1e-4 m unless a row says otherwise.

Phase 2 (flat):
- `FlatWater.height_at(any, any, any) == base_height_m`, `normal_at == Vector3.UP`, `velocity_at == Vector3.ZERO`; `depth_at(Vector3(1, −0.3, 2), t) == 0.3`.

Phase 5, derived quantities:
- `k`, `c`, `omega`, `T` for `L = 10` equal the numbers above; `omega == k·c`; `T == sqrt(2π·L/g)`.
- Direction: bearing 0 → `(0, −1)`; 90 → `(1, 0)`; 180 → `(0, 1)`; 270 → `(−1, 0)`; wind from 270 with offset +12 → `(0.9781, 0.2079)`.

Phase 5, displacement of rest points at `t = 0` (9.4):
| rest (x, z) | phase | displacement (dx, dy, dz) | meaning |
|---|---|---|---|
| (0, −2.5) | π/2 | (0, +0.1, 0) | crest, no sideways shift |
| (0, 0) | 0 | (0, 0, −0.397887) | mean level, shifted North toward the crest |
| (0, −5) | π | (0, 0, +0.397887) | mean level, shifted South toward the crest |
| (0, −7.5) | 3π/2 | (0, −0.1, 0) | trough |
| (0, +2.5) | −π/2 | (0, −0.1, 0) | trough |
| (3, 0) | 0 | (0, 0, −0.397887) | independent of x for a North-going wave |

Phase 5, `height_at` world points (9.5, the solve):
- world (0, −2.5), `t = 0` → `+0.1` (rest point equals world point).
- world (0, 0), `t = 0` → `−0.02403` (rest `z = +0.3863`, found by solving `z_r = 0.397887·cos(0.628319·z_r)`; hand check: `0.1·sin(−0.628319·0.3863) = −0.0240`). Tolerance 1e-3.
- world (3, 0), `t = 0` → `−0.02403` (same, x does not matter).
- world (0, 0), `t = T/4 = 0.632697` → `−0.1` exactly (phase −π/2 at rest (0, 0), no sideways shift).
- world (0, 0), `t = T = 2.530786` → `−0.02403` again (periodicity; also test `t + T` for random points, tolerance 1e-3).
- With `S = 0` the wave is a pure sine and the solve is exact after one pass: world (0, −5) → `0.0`; world (4, −1.25) → `0.070711` (= 0.1·sin(π/4)); world (0, −2.5) → `0.1`.
- Bound: 1000 random `(x, z, t)` on the default four-wave set give `|height| ≤ 0.202` (never exceeded; observed max 0.2008).
- Convergence: on the default set, `height_at` with the spec's tolerance solve agrees with a 40-iteration solve to 5e-4 m at 1000 random points; with the legacy's fixed 3 iterations the worst difference is about 3e-3 m (documents why the spec changed it).
- Residual: after the solve, `rest + displacement_xz(rest) ≈ world` within 1 mm.
- Flat when `enable_waves = false` or every `A = 0`: height 0, normal UP, velocity ZERO at random points.

Phase 5, normal (9.6a) at rest points, `t = 0`:
- (0, −2.5) crest → `(0, 1, 0)`; (0, −7.5) trough → `(0, 1, 0)`.
- (0, 0) → `(0, 0.99803, +0.06270)` (front face rising toward North tilts the normal toward +Z/South: `n.z = −k·A·d.z·cos 0 = +0.0628` before normalising).
- (0, −5) → `(0, 0.99803, −0.06270)`.
- Consistency: for 100 random points, the analytic normal at rest `r` equals the finite-difference normal at world `r + disp(r)` (δ = 0.005 m, tolerance-solved heights) within 0.2°; on the default four-wave set within 0.2° as well (the exact formula, not eq. 12, is what makes this pass).

Phase 5, orbital velocity (9.7) at rest points, `t = 0`:
- (0, −2.5) crest → `(0, 0, −0.987836)` (= `S·c` forward, toward North).
- (0, −7.5) trough → `(0, 0, +0.987836)` (backward).
- (0, 0) → `(0, −0.248270, 0)` (falling, = `−A·omega`); (0, −5) → `(0, +0.248270, 0)` (rising).
- Numerical check: `(disp(t+1e-4) − disp(t−1e-4)) / 2e-4` matches within 1e-5 m/s at random points.

Phase 5, steepness:
- Single wave `S = 1.0`: `d(world z)/d(rest z)` along the travel line is ≥ 0 everywhere (min 0 at the crest); `S = 1.2` gives a negative minimum (−0.2), so the validator must refuse `Σ S > 1`.
- `TotalSteepness` ignores waves with `A = 0`.

Phase 5, shader contract:
- `shader_parameters()` for the default set with wind from 270 gives `wave_a = (0.9781, 0.2079, 0.20, 14)` and `wave_amplitudes = (0.10, 0.06, 0.03, 0.012)`; with `enable_waves = false` all amplitudes are 0 and the directions unchanged.
- Screenshot test (Phase 5 "done when"): the board's waterline sits on the rendered surface; this is the only check that the shader copy of 9.4 matches GDScript.

### Sources

- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Water/GerstnerWave.cs`: wave component and defaults :19-55; `GerstnerMath` :60-165 (`MAX_WAVES` :63, iterations :66, `Displacement` :77-105, `HeightAt` :112-125, `DirectionVector` :131-135, `TotalSteepness` :138-151, `TotalAmplitude` :154-164).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Water/WaterSurface.cs` (Session 27): fields :20-36, shader IDs :38-48, `NORMAL_SAMPLE_DELTA` :50, `Awake/Start/OnValidate/Update` :68-103, `UpdateWaveDirections` :108-126, `PublishShaderGlobals` :132-163, `GetWaterHeight` :168-176, `GetSurfaceNormal` :181-198, `IsUnderwater`/`GetDepth` :212-223, `SetWavesEnabled` :228-231, `CreateDefaultWaves` :237-246.
- Pre-Session-27 `WaterSurface.cs` (validated flat-water build): `git show 757d5cf^:WindsurfingGame/Assets/Scripts/Physics/Water/WaterSurface.cs`, fields lines 14-30, sine formula lines 108-118.
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Water/IWaterSurface.cs` :8-33 (height, normal, both; no velocity).
- `Legacy/WindsurfingGame/Assets/Shaders/OceanWater.shader`: material properties :18-47, globals :110-116, gravity :118, `AccumulateGerstner` :140-164, vertex stage :205-236 (never compiled).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` :640-663 (hand-edited Session 27 values); `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs` :384-417 (creates the water at the origin, sets no wave fields), :708 (links buoyancy).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs` :13 (`WATER_DENSITY`), :18 (`GRAVITY`).
- `Legacy/WindsurfingGame/Assets/Scripts/Environment/WindSystem.cs` :20-22 (wind from 270° default), :40 (shifts off), :138 (`_currentDirection` includes shifts), :174-182 (`GetWindFromDirection`, Unity `(sin, 0, cos)`).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs` :206-213, :229-236, :255-256 (how the surface is sampled); `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset` :6.
- `Legacy/Documentation/PHYSICS_DESIGN.md` :31-65 (section 1: sine and Gerstner sketch, wave parameter table); `Legacy/Documentation/PROGRESS_LOG.md` :99-138 (Session 27, unverified); `Legacy/Documentation/KNOWN_ISSUES.md` :13-24 (verification checklist, waves on by default); `Legacy/Documentation/scene_config.json` :171-181 (2025-12-27 sine stub, history only).
- Literature: M. Finch, "Effective Water Simulation from Physical Models", GPU Gems ch. 1 (NVIDIA, 2004): Gerstner sum (eq. 9), steepness `Q`, normal eq. 12 (single-wave exact, multi-wave approximate). Deep-water dispersion `omega² = g·k`: any fluid-mechanics text (e.g. Kundu & Cohen, *Fluid Mechanics*, ch. on surface gravity waves).
- Numerical checks for this section: `gerstner_check.py` in the session scratchpad (Python, 20 000 random samples for the convergence table, 3 000 for the normal comparisons).

---

## 10. Controls: from keys to rake, sheet and weight shift

### Purpose

The physics in sections 2 to 9 only knows three control inputs: how far the sail is sheeted in (`sheet`), how far the mast is raked (`rake`), and where the sailor's weight is (`lean`). This section describes how key presses become those three numbers, and what the legacy controller did on top of that: smoothing, automatic centring of the rake, an automatic sheet, a tack/gybe action, a "weight shift" steering torque and an anti-capsize torque.

The game needs this layer because real windsurfing steering is not "left/right". You steer by raking the mast: rake back and the board heads up (turns toward the wind), rake forward and it bears away. Whether "head up" is a left or a right turn on screen depends on which side the wind comes from. A beginner wants A = left and D = right regardless; an advanced player wants to feel the real controls. Both are mappings from keys to the same three numbers.

The legacy source for this section is `Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs` (the controller in the last validated Unity build, Session 26). `WindsurferControllerV2.cs` is an older controller that was still in the project but not on the windsurfer; it is covered only for comparison.

### Inputs and outputs

Inputs read every frame (legacy) or every physics step (spec):

| Name | Meaning | Unit |
|---|---|---|
| `sheet_key` | +1 while W or Up is held (sheet in), -1 while S or Down is held (ease out), else 0 | - |
| `steer_key` | +1 while D or Right is held (turn right on screen), -1 while A or Left is held, else 0. D wins if both are held | - |
| `rake_key` | +1 while E is held (rake back), -1 while Q is held (rake forward), else 0. E wins if both are held | - |
| `tack_pressed` | true on the frame Space goes down (edge, not level) | - |
| `autosheet_toggle_pressed` | true on the frame T goes down | - |
| `awa_rad` | apparent wind angle from the sail model, positive = wind from starboard (needed by the auto-sheet and by the steering inversion) | rad |
| `sail_side` | which side the boom is on, +1 = starboard side (port tack), -1 = port side (starboard tack), from the sail-side model | - |
| `speed_ms` | board speed over the water (magnitude of `v_boat`) | m/s |
| `heel_rad` | heel angle, positive = heeled to starboard | rad |
| `dt` | time step | s |

Outputs handed to the simulation:

| Name | Meaning | Unit |
|---|---|---|
| `sheet` | 0 = fully out (boom 85 deg from the centreline), 1 = fully in (boom 12 deg). **Legacy stores the opposite** (`_sheetPosition`: 0 = in, 1 = eased); everything below is converted: `sheet = 1 - sheet_legacy` | - |
| `sheet_angle_rad` | boom angle from the centreline, `deg_to_rad(85 - 73 * sheet)` | rad |
| `rake` | -1 = fully forward, 0 = neutral, +1 = fully back | - |
| `rake_rad` | `rake * deg_to_rad(15)` (15 deg was only used by the visuals in the legacy build; see section 3, rake steering, for what the physics does with it) | rad |
| `lean` | sailor's weight shift, -1 = fully to port, +1 = fully to starboard (legacy: `_currentWeightShift` in degrees, -20 to +20) | - |
| `tack_switch` | the request to flip the sail to the other side (goes to the sail-side model) | - |
| `torque_yaw_weight_nm` | legacy only: a yaw torque from the weight shift, applied directly to the body | N m |
| `torque_roll_anticapsize_nm` | legacy only: a roll torque that fights heel | N m |

Telemetry the legacy controller exposed (`AdvancedWindsurferController.cs:87-88, 312-329`): `CurrentWeightShift` (degrees), `SailingState` (the sail's state object), and `GetStateDescription()`, a text block with speed in knots, AWA in degrees, VMG in knots, "Sheet In %" = `(1 - sheet_legacy) * 100` (so it is our `sheet * 100`), rake (-1 to 1), leeway in degrees and PLANING/Displacement. No other script calls `GetStateDescription()` or `CurrentWeightShift` (checked with grep across `Legacy/WindsurfingGame/Assets/Scripts`); the HUD (`AdvancedTelemetryHUD.cs:200-206`) reads the sail directly: tack name from `IsStarboardTack`, "Sheet In %" and the absolute sail angle.

### Legacy control modes and key bindings (what actually existed)

**There are no control modes in the last validated build.** `AdvancedWindsurferController.cs` (Session 26) has one behaviour: A/D combined steering, W/S manual sheet, Q/E fine rake, Space tack, T toggles auto-sheet, with the assists on (`AdvancedWindsurferController.cs:8-18`). The documentation that says the controller has "Beginner / Intermediate / Advanced" modes is stale:

- `Legacy/Documentation/PROGRESS_LOG.md:65` ("Three control modes"), `:660-666` (Session 18 table), `Legacy/Documentation/ARCHITECTURE.md:377-383`, `COMPONENT_DEPENDENCIES.md:49-51`, `QUICK_SETUP_CHECKLIST.md:56` and the setup wizard's success dialog `WindsurferSetup.cs:669` ("Tab = Cycle mode") all describe modes that were removed.
- Git history: the modes existed from commit `ca7a7b1` (2025-12-27, "Session 13") and were removed in commit `5a1857a` (2025-12-28, "Session 22"), which replaced them with the single combined scheme and added the 80 N m base steering torque. Commit `b5ed2ea` (2026-01-02, Session 26) added the port-tack inversion.

What the three modes did in the Session 13 version (`git show ca7a7b1:WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs`, lines 94-99, 158-192 and 292-319; Tab cycled the modes, line 123-126; the default was Intermediate, line 33):

| Mode | A/D | Q/E | W/S | Auto-sheet | Auto-centre rake | Anti-capsize |
|---|---|---|---|---|---|---|
| Beginner | rake **and** weight together (`_rakeInput = _weightInput = +1` for D) | ignored | manual | on | on | on |
| Intermediate | weight shift only | rake | manual | off | on | on |
| Advanced | weight shift only | rake | manual | off | off | off |

Note that the Session 13 Beginner mode had **no** tack inversion: D always raked back, so D turned left on port tack. That is the bug Session 26 fixed after the modes were already gone (`PROGRESS_LOG.md:147-157`; the code snippet printed there, `moveAction.x * steerDirection`, does not exist in the file; the real code is `AdvancedWindsurferController.cs:157-170`).

Key bindings in the last build. All keys are read directly from `Keyboard.current` with the Unity Input System; the action asset `Legacy/WindsurfingGame/Assets/InputSystem_Actions.inputactions` is Unity's untouched template (Move/Look/Attack/Interact/Crouch/Jump/Previous/Next/Sprint, lines 9-90; WASD composite for Move at lines 103-193; Space bound to "Jump" at line 380; E bound to "Interact" at line 435) and no script references it (grep for `InputActionAsset`, `PlayerInput`, `InputSystem_Actions` over the scripts finds nothing). It carries no information about the game's controls.

| Key | Action | Source |
|---|---|---|
| W / Up | sheet in | `AdvancedWindsurferController.cs:147-148` |
| S / Down | sheet out | `:149-150` |
| D / Right | turn right on screen: rake and weight, both multiplied by `steerDirection` | `:161-165` |
| A / Left | turn left on screen | `:166-170` |
| E | rake back (overrides the A/D rake, not the A/D weight; no tack inversion) | `:173-174` |
| Q | rake forward (same) | `:175-176` |
| Space (edge) | `_sail.SwitchTack()`: flip the sail to the other side | `:179-182`, `AdvancedSail.cs:549-554` |
| T (edge) | toggle auto-sheet | `:185-189` |
| F1 / F2 / F3 | HUD: detailed vs compact panel (the HUD is never fully hidden), force vectors, polar | `AdvancedTelemetryHUD.cs:94-99` |
| 1 / 2 / 3 / 4 | camera: FixedFollow, OrbitManual, TopDown, FreeLook | `SimpleFollowCamera.cs:12-18, 229-236` |
| W/A/S/D/Space/LCtrl in camera mode 4 | move the free camera **and still steer the board** (the camera does not capture the keys) | `SimpleFollowCamera.cs:327-332` |
| Tab | nothing in the last build (mode cycling in Session 13 and in V2) | `WindsurferControllerV2.cs:169-176` |
| R, Esc | nothing (no reset or pause existed) | grep for `rKey`, `escapeKey`: no hits |

Timing: keys are read and smoothed in `Update()` (once per rendered frame, `:116-120`) and applied in `FixedUpdate()` at Unity's fixed step of 0.02 s (`:122-130`; `Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6`). All rates below are per second, so the step length does not change them; the spec samples keys in the physics step instead (see "What Phase 2 must implement").

### Formulas

All angles in radians unless a table says degrees. `move_toward(a, b, step)` moves `a` toward `b` by at most `step` (Godot's `move_toward`, Unity's `Mathf.MoveTowards`).

**1. Which way is "head up"? (D4 derivation of the tack sign)**

Heading up means turning the bow toward where the wind comes from.

- Starboard tack: the wind comes from starboard (`awa_rad > 0`). The wind is on the right, so heading up is a turn to the right (to starboard). In Godot a positive rotation about +Y turns the bow (-Z) toward -X, which is port; so a right turn is a **negative** yaw rate.
- Port tack: the wind comes from port (`awa_rad < 0`). Heading up is a turn to the left, a **positive** yaw rate.

So the yaw direction of "head up" is `-sign(awa_rad)`, and rake back (`rake > 0`) produces a yaw torque with the sign of `-sign(awa_rad) * rake` in Godot. Define

    tack_sign = +1 on starboard tack, -1 on port tack            (1a)

In the legacy code `tack_sign = _sail.IsStarboardTack ? +1 : -1` (`AdvancedWindsurferController.cs:158-159`), where `IsStarboardTack = _manualTack > 0` (`AdvancedSail.cs:80-81`) and `_manualTack` is changed only by Space (`AdvancedSail.cs:549-554`; it starts at +1, line 66). The sail side is `sail_side = -_manualTack` (`AdvancedSail.cs:206`), so `tack_sign = -sail_side`. The sail's own rake-steering uses the same sign: `tack = -SailSide` (`AdvancedSail.cs:474, 494`), so in legacy the rake torque direction and the key inversion always agreed, even when the sail was on the wrong side of the wind.

Recommendation for the spec: take `tack_sign` from the real wind, `tack_sign = sign(awa_rad)`, with hysteresis (keep the previous value while `|awa_deg| < 10` or `> 170`). Reason: in the new model the rake torque comes from the sail force acting ahead of or behind the fin (section 3), and the sail force pushes to leeward whichever side the boom is on; so the "head up" direction follows the wind side, not the manual boom side. OPEN: the team must decide whether the sail side flips automatically when the wind crosses the bow (a real tack) or only on Space; that decision lives in the sail-side section, and this mapping works with either.

**2. Screen-relative steering ("D = turn right on either tack")**

D must turn the board right, which is a negative Godot yaw. Rake back heads up, and heading up is a right turn only on starboard tack. Therefore

    rake_cmd   = steer_key * tack_sign                            (2a)

Check: starboard tack (`tack_sign = +1`), D: `rake_cmd = +1`, rake back, head up = right turn. Port tack, D: `rake_cmd = -1`, rake forward, bear away; the wind is on the left, so bearing away (turning away from the wind) is a right turn. Both correct. This is exactly the legacy `steerDirection` (`AdvancedWindsurferController.cs:159, 163, 168`), and it needs no sign change between Unity and Godot because it is a statement about "toward the wind", not about an axis.

Fine rake keys override the A/D rake command and are never inverted (E = back on both tacks):

    if rake_key != 0: rake_cmd = rake_key                         (2b)   (`:172-176`)

Weight shift: D means "lean to the right". A weight shift that turns the board is a direct yaw torque (formula 7); a right turn is a right turn on either tack, so the weight command must **not** be inverted:

    lean_cmd = steer_key                                          (2c)

The legacy code did invert it: `_weightInput = 1f * steerDirection` (`:164, 169`). On port tack this makes the weight-shift torque push the wrong way and fight the rake: pressing D on port tack gives rake forward (correct, turns right) plus a weight torque to the left. The rake torque (200 to 350 N m direct term plus force and speed terms, `AdvancedSail.cs:506-524`) is larger than the weight torque (80 to 110 N m, formula 7), so the board still turns right, but weaker than on starboard tack. This is a legacy bug; the spec uses (2c).

**3. Input smoothing**

Each raw command ramps toward its target at a fixed rate (`:195-201`):

    sheet_in_smooth = move_toward(sheet_in_smooth, sheet_key, smoothing_rate * dt)
    rake_smooth     = move_toward(rake_smooth,     rake_cmd,  smoothing_rate * dt)
    lean_smooth     = move_toward(lean_smooth,     lean_cmd,  smoothing_rate * dt)

with `smoothing_rate = 8 /s`, so a key press ramps from 0 to 1 in 0.125 s. Legacy uses the render-frame `Time.deltaTime` here (line 197); the spec uses the physics `dt` so results are deterministic and testable.

**4. Sheet (W/S) and the auto-sheet**

Manual sheet integrates the smoothed key at a fixed rate and clamps (`:218-222`, converted to our convention where in = 1):

    sheet = clamp(sheet + sheet_in_smooth * sheet_rate * dt, 0.0, 1.0)     sheet_rate = 0.8 /s

Full travel therefore takes 1.25 s. If auto-sheet is on and no sheet key is held (`|sheet_in_smooth| < 0.1`, `:211-216`), the sheet instead moves toward a target at `autosheet_rate = 0.3 /s` (full travel 3.3 s):

    sheet = move_toward(sheet, sheet_auto, autosheet_rate * dt)

The auto-sheet target keeps the sail at a fixed angle of attack of 17 deg to the apparent wind, because a sail's best lift-to-drag is at roughly 15 to 20 deg. Angle of attack is the difference between the apparent wind angle and the boom angle, so boom angle = |AWA| - 17 deg (`Aerodynamics.cs:255-268`, called through `AdvancedSail.cs:633-637`):

    sail_angle_deg = clamp(abs(awa_deg) - 17.0, 5.0, 85.0)
    sheet_auto     = 1.0 - (sail_angle_deg - 12.0) / 73.0

Legacy bug: the lower clamp of 5 deg is below the sail's minimum boom angle of 12 deg, so for `|awa_deg| < 22` the legacy target `(sail_angle - 12)/73` is negative (-0.096), and the controller's own sheet variable is not clamped in the auto branch (only the sail clamps on receipt, `AdvancedSail.cs:534`). The spec clamps `sail_angle_deg` to `[12, 85]`, which is also what the sail's own (unused) `_autoTrim` path does (`AdvancedSail.cs:599-606`). Then `sheet_auto` is always in [0, 1].

The boom angle from the sheet (`AdvancedSail.cs:224-226`):

    sheet_angle_rad = deg_to_rad(85.0 - 73.0 * sheet)         (12 deg when fully in, 85 deg when fully out)

The sail then moves its own `_sheetPosition` toward the commanded value at 1.5 /s (`AdvancedSail.cs:32, 147-148`). Because 1.5 > 0.8 this second rate limit never binds during manual sheeting; it only matters at start-up (next paragraph). The spec keeps one rate limit, in the controller.

Start-up bug: the sail starts at `_sheetPosition = 0.65` (`AdvancedSail.cs:29`; scene `MainScene.unity:342`), but the controller's `_currentSheetPosition` starts at the C# default 0 and is never read from the sail (`AdvancedWindsurferController.cs:80`). On the first physics step the controller commands 0 (fully sheeted in) and the sail winds in from 0.65 to 0 in 0.43 s. So the last build effectively started fully sheeted in. The spec initialises the controller from the simulation's sheet value; recommended start `sheet = 0.35` (the legacy 0.65 eased, converted).

**5. Rake (A/D through the tack sign, or Q/E)**

Rake integrates the smoothed command while a key is held (dead band 0.1) and otherwise returns to neutral (`:226-236`):

    if abs(rake_smooth) > 0.1:
        rake = clamp(rake + rake_smooth * rake_rate * dt, -1.0, 1.0)       rake_rate = 2.0 /s
    elif auto_centre_rake:
        rake = move_toward(rake, 0.0, rake_centre_rate * dt)               rake_centre_rate = 1.0 /s

Holding D from neutral: the smoothed input ramps over 0.125 s, so `rake = 2 * (t - 0.0625)` for t > 0.125 s: 0.875 at 0.5 s and 1.0 at 0.5625 s. Releasing: back to 0 in about 1.1 s (the smoothed input takes 0.1125 s to fall below 0.1, during which the rake still creeps, then 1 s of centring).

The sail moves its own rake toward the command at `_rakeSpeed = 3 /s` (`AdvancedSail.cs:45, 151-152`); 3 > 2 so this never binds. The physical rake angle for the visuals is `rake_rad = rake * deg_to_rad(15)` (`AdvancedSail.cs:42`, `WindsurferSetup.cs:736`; the sail physics never used `_maxRakeAngle`, only the dimensionless `rake` as a torque multiplier, `AdvancedSail.cs:506-522`).

**6. Weight shift (lean)**

The smoothed steering key sets a target lean; the lean follows at a fixed rate (`:239-240`):

    lean_target = lean_smooth                       (fraction of the maximum, legacy: * 20 deg)
    lean        = move_toward(lean, lean_target, lean_rate * dt)

Legacy: `_maxWeightShift = 20 deg` and `_weightShiftSpeed = 4 /s`, so the rate is `4 * 20 = 80 deg/s`, or in our fraction form `lean_rate = 4.0 /s` (0 to full in 0.25 s). The legacy lean is a number in degrees that is **only** used to scale a torque; it is not a centre-of-mass shift, it moves no mass and produces no roll moment (`:248-270`). The magenta gizmo draws it as a sideways offset (`:368-377`), but nothing physical depends on that.

**7. Weight-shift steering torque (legacy)**

If `abs(lean) >= 0.025` (legacy: 0.5 deg of 20, `:250`):

    speed_factor          = clamp(speed_ms / 3.0, 0.0, 1.0)                        (`:260`)
    torque_yaw_weight_nm  = lean * (T_base + T_speed * speed_factor)               (`:257-264`)
    T_base = 80 N m,  T_speed = 30 N m

Legacy applies `+torque` about world up (`:266`), which in Unity is a right turn for positive lean. In Godot a right turn is a negative yaw, so

    torque_body = Vector3(0.0, -torque_yaw_weight_nm, 0.0)      (about the body's +Y; legacy used world up, see "Where the force acts")

At full lean: 80 N m when stopped, 110 N m from 3 m/s up. For scale, the last build's yaw inertia was about 50 kg m2 (PhysX computed it from the 0.6 x 0.12 x 2.5 m box collider and 91 kg: `91/12 * (0.6^2 + 2.5^2) = 50.1`; `WindsurferSetup.cs:689, 700-701`, `BoardMassConfiguration.cs:54, 197` with custom inertia off), so 80 N m alone is a yaw acceleration of about 1.6 rad/s2 before the fin and damping push back. This is a fudge; see "Stabilisers and fudges".

**8. Anti-capsize torque (legacy)**

Heel angle. Legacy: `heelAngle = Vector3.SignedAngle(Vector3.up, ProjectOnPlane(transform.up, transform.forward).normalized, transform.forward)` (`:279-282`). Two remarks. First, projecting the board's up onto the plane perpendicular to the board's forward is a no-op (they are already perpendicular), so this is the 3D angle between world up and board up, and it **includes pitch**: with 10 deg of bow-up trim and no heel it reports 10 deg (with an arbitrary sign, since the cross product is zero and `Mathf.Sign(0) = +1`). Second, working out Unity's sign (`sign = dot(cross(from, to), axis)`): a heel to starboard gives a **negative** `heelAngle` in the legacy code. The spec uses a proper heel angle that ignores pitch, positive to starboard:

    up_local = board_basis.inverse() * Vector3.UP          (world up expressed in the body frame)
    heel_rad = atan2(-up_local.x, up_local.y)              (positive = starboard rail down)

Check: heeled 20 deg to starboard, the starboard axis points 20 deg downward, so world up has a negative x component in the body frame and `heel_rad = +0.349`. Pure pitch gives `up_local.x = 0` and `heel_rad = 0`.

Torque (`:287-306`), written with the heel in degrees because the legacy gains are per degree:

    heel_deg = rad_to_deg(heel_rad)
    M1 = 0.0
    if abs(heel_deg) > 5.0:                                                   (dead zone, `:287`)
        factor = clamp(abs(heel_deg) / 45.0, 0.0, 1.0)                        (`:291`)
        M1 = abs(heel_deg) * 50.0 * 0.5 * factor                              (`:292`)  N m
    M2 = 0.0
    if abs(heel_deg) > 45.0:                                                  (`:299-303`)
        M2 = (abs(heel_deg) - 45.0) * 50.0 * 2.0                              N m
    torque_roll_anticapsize_nm = M1 + M2                                      (a magnitude, always restoring)

Below 45 deg, `M1 = 0.5556 * heel_deg^2` N m (`= 1824 * heel_rad^2`): 56 N m at 10 deg, 222 N m at 20 deg, 1125 N m at 45 deg. Above 45 deg the gains are 25 N m/deg (1432 N m/rad) plus 100 N m/deg (5730 N m/rad) on the excess: 3000 N m at 60 deg. For comparison, a 75 kg sailor hanging 1 m to windward gives `75 * 9.81 * 1 = 736` N m, so the legacy hard limit is several sailors' worth.

Direction in Godot: the torque must roll the board back toward level. A positive torque about the body's +Z (the tail axis) rotates +X toward +Y, that is, it lifts the starboard rail, which un-heels a starboard heel. So

    torque_body = Vector3(0.0, 0.0, torque_roll_anticapsize_nm * sign(heel_rad))

In Unity the same physical torque was `AddTorque(transform.forward * -counterTorque)` with the bow at +Z and the heel sign negative for starboard (`:295, 303-305`); the axis direction and the heel sign both flip between the frames, which is why the formula looks different but the physics is the same.

Note that in the last build the sail force acted at the centre of mass (`AdvancedSail.cs:283-291`) and was purely horizontal (`:363-364`), so the sail produced **no heeling moment at all**. The anti-capsize torque therefore only ever fought the buoyancy roll of the hull and the pitch leak described above. Its real effect in the last build was small.

**9. Tack or gybe (Space)**

`SwitchTack()` flips `_manualTack` and `_lastSailSide` (`AdvancedSail.cs:549-554`). Consequences on the next physics step: `sail_side = -_manualTack` flips, so the boom angle mirrors instantly (`AdvancedSail.cs:206, 229`), the rake-steering direction flips (`tack = -SailSide`, `:474, 494`), and the controller's `tack_sign` flips (`AdvancedWindsurferController.cs:158-159`). Nothing else changes: the sheet position, the rake and the lean keep their values, there is no transition time, no luffing phase and no check that the wind is actually on the other side. Space is edge-triggered (`wasPressedThisFrame`, `:179`), so holding it does nothing more. Whether Space performs a tack (bow through the wind) or a gybe (stern through the wind) is not decided by the controller; it just flips the sail side, and the physics decides what happens next.

Spec: `tack_switch = tack_pressed` is passed to the sail-side model. OPEN: whether the boom should swing over with a duration (about 1 s, sail luffing and powerless in between) is a sail-side model decision; for Phase 3 an instant flip is acceptable and matches the last build.

**10. Auto-sheet toggle (T)**

`_autoSheet = !_autoSheet` (`:185-189`). Default off (`:32`, scene `:370`). In the Session 13 Beginner preset it was on.

**11. Order of operations per physics step (spec)**

1. Read keys into `sheet_key`, `steer_key`, `rake_key`, `tack_pressed`, `autosheet_toggle_pressed`.
2. `tack_sign` from the last step's `awa_rad` (with hysteresis) or from `sail_side`, per formula 1.
3. Commands: (2a), (2b), (2c). Smooth: formula 3.
4. Sheet: formula 4. Rake: formula 5. Lean: formula 6.
5. Hand `sheet`, `rake`, `lean`, `tack_switch` to `WindsurferSim.step(dt, controls)`.
6. Inside the sim, if enabled by config: weight-shift yaw torque (7) and anti-capsize roll torque (8) as couples on the body.

### Values

| Name | Value | Unit | Source (C# default; scene; wizard) |
|---|---|---|---|
| `sheet_rate` (`_sheetControlSpeed`) | 0.8 | 1/s | `AdvancedWindsurferController.cs:29`; `MainScene.unity:369` (0.8); wizard does not set it |
| `autosheet_enabled` (`_autoSheet`) | false | - | `:32`; `MainScene.unity:370` (0); wizard does not set it. Session 13 Beginner preset: true (`ca7a7b1` line 300) |
| `autosheet_rate` (`_autoSheetSpeed`) | 0.3 | 1/s | `:35`; `MainScene.unity:371` |
| `autosheet_target_aoa_deg` | 17 | deg | `Aerodynamics.cs:261`; also `AdvancedSail.cs:599` |
| auto-sheet boom clamp | 5 to 85 (Aerodynamics) vs 12 to 85 (AdvancedSail) | deg | `Aerodynamics.cs:265` vs `AdvancedSail.cs:601`. The controller used the 5 to 85 version (`AdvancedSail.cs:635`). Spec: 12 to 85 |
| boom angle range (sheet 1 to 0) | 12 to 85 | deg | `AdvancedSail.cs:224-225` |
| sail's own sheet rate (`_sheetSpeed`) | 1.5 | 1/s | `AdvancedSail.cs:32`; `MainScene.unity:343` |
| start sheet (sail) | 0.65 legacy = 0.35 ours | - | `AdvancedSail.cs:29`; `MainScene.unity:342`. Conflict: controller starts at 0 legacy = 1.0 ours (`AdvancedWindsurferController.cs:80`, uninitialised) and wins after 0.43 s |
| `rake_rate` (`_rakeControlSpeed`) | 2.0 | 1/s | `:39`; `MainScene.unity:372` |
| `auto_centre_rake` (`_autoCenterRake`) | true | - | `:42`; `MainScene.unity:373`; `WindsurferSetup.cs:800` (true) |
| `rake_centre_rate` (`_rakeCenterSpeed`) | 1.0 | 1/s | `:45`; `MainScene.unity:374` |
| rake dead band | 0.1 | - | `:226` |
| sail's own rake rate (`_rakeSpeed`) | 3.0 | 1/s | `AdvancedSail.cs:45`; `MainScene.unity:347` |
| `rake_max_deg` (`_maxRakeAngle`) | 15 | deg | `AdvancedSail.cs:42`; `MainScene.unity:346`; `WindsurferSetup.cs:736` (visual only) |
| `lean_max_deg` (`_maxWeightShift`) | 20 | deg | `:49`; `MainScene.unity:375` |
| `lean_rate` (`_weightShiftSpeed`) | 4.0 (x 20 = 80 deg/s) | 1/s | `:52`; `MainScene.unity:376` |
| lean dead zone | 0.5 deg = 0.025 of max | deg | `:250` |
| `T_base` (base steering torque) | 80 | N m | hard-coded `:257`; added in Session 22 (`PROGRESS_LOG.md:405, 436`) |
| `T_speed` (`_weightShiftTorque`) | 30 | N m | `:55`; `MainScene.unity:377` |
| weight speed scale | speed / 3 | m/s | `:260` |
| `anticapsize_enabled` (`_antiCapsize`) | true | - | `:59`; `MainScene.unity:378`; `WindsurferSetup.cs:799` (true) |
| `heel_max_deg` (`_maxHeelAngle`) | 45 | deg | `:62`; `MainScene.unity:379` |
| `anticapsize_strength` | 50 | N m/deg (times 0.5 or 2) | `:65`; `MainScene.unity:380`; factors `:292` (0.5), `:303` (2) |
| heel dead zone | 5 | deg | `:287` |
| `smoothing_rate` (`_inputSmoothing`) | 8 | 1/s | `:68`; `MainScene.unity:381` |
| auto-sheet manual threshold | 0.1 | - | `:211` |
| fixed time step | 0.02 | s | `TimeManager.asset:6` |
| rigidbody angular damping | 0.3 | 1/s | `WindsurferSetup.cs:691`; `MainScene.unity:216` (affects how fast the yaw from these torques dies out) |

The scene file `MainScene.unity:365-381` does hold the controller's values (it was saved after the wizard ran), and every one equals the C# default. The wizard only sets `_antiCapsize` and `_autoCenterRake`, both true (`WindsurferSetup.cs:799-800`). So there is no conflict for this component: the last validated build used the C# defaults.

Comparison, `WindsurferControllerV2.cs` (not on the windsurfer in the last build; `MainScene.unity` references only the Advanced controller's script GUID `c9d0e1f2...`): two modes, Beginner and Advanced, toggled with Tab (`:86-90, 169-176`). Beginner: A/D gives `effectiveRake = steer * -sailSide` (`:223`, the same inversion as (2a) written with `sail_side`), fed as `AdjustRake(effectiveRake * 0.25 * dt * 5)` (`:228`, 1.25 /s), plus weight `steer * 0.15` (`:240`) and "edging" (a roll torque toward `-steer * 15 deg`, `:364-382`); auto-sheet from a table of AWA bands (0.2 / 0.35 / 0.5 / 0.65 / 0.75 legacy positions for AWA < 60 / 90 / 120 / 150 / else, `:401-410`) plus a "rotation correction" `-yaw_rate * 0.05` (`:415`); an auto-stabiliser when no key is held: yaw torque `-yaw_rate * 5 * 15` (`:315`), a 15 % cut of the yaw rate every step (`:319-323`), and a corrective rake `-yaw_rate * 0.3` (`:330`). Its weight torque uses `ForceMode.VelocityChange` with `lean_deg * 12 * clamp(speed/5) * dt` (`:354-357`), which is an angular-velocity change independent of mass, not a torque. Anti-capsize: above 30 deg of roll or pitch, `(excess) * 10` N m (`:444-465`). Values: `_weightShiftStrength 12`, `_maxLeanAngle 30`, `_weightShiftSpeed 6`, `_maxRollAngle 15`, `_stabilizationStrength 5`, `_inputResponsiveness 6` (`:33-66`; `SCENE_CONFIGURATION.md:204-225` agrees). None of this was in the validated build; listed so nobody reintroduces it by accident.

### Where the force acts

Rake, sheet and lean are inputs, not forces; their forces appear in the sail model (section 2), the rake-steering model (section 3) and the mass model (section 7).

The legacy controller itself applied two pure couples (torques with no application point) to the rigidbody:

- Weight-shift yaw torque: about **world** up (`Vector3.up`, `:266`), magnitude per formula 7. A world-vertical torque on a heeled board has a component about the body's roll and pitch axes; the spec applies it about the body's +Y instead, since it stands in for the sailor turning the board about its own vertical axis. At the heel angles of normal sailing the difference is small.
- Anti-capsize roll torque: about the body's bow axis (`transform.forward`, `:295, 305`), magnitude per formula 8.

If the lean is later made physical (recommended below), it becomes a lateral offset of the sailor's mass, `sailor_offset_m = lean * lean_reach_m` along body +X, and its effects are a righting or heeling moment `m_sailor * g * sailor_offset_m` and the inertia change from section 7. OPEN: `lean_reach_m` (how far the sailor's centre of mass can move sideways; 0.3 to 0.6 m is plausible for hiking with a harness) is not in the legacy code and must be chosen in Phase 4.

### Signs and the Unity-to-Godot translation

| Quantity | Unity (legacy) | Godot (spec) | Note |
|---|---|---|---|
| Bow, starboard, up | +Z, +X, +Y | -Z, +X, +Y | |
| Positive yaw (rotation about +Y) | turns the bow to the **right** (left-handed) | turns the bow to the **left** (right-handed) | Every yaw torque sign flips |
| Weight torque for "turn right" | `+lean * K` about `Vector3.up` (`:264-266`) | `-lean * K` about body +Y | Flip |
| Rake torque for "head up" | `+rake * tack * K` about up, `tack = +1` on starboard tack (`AdvancedSail.cs:494, 524`) | `-rake * tack_sign * K` about +Y (section 3 derives it from the CE offset instead) | Flip |
| Screen steering mapping (2a) | `rake = steer * steerDirection` | `rake_cmd = steer_key * tack_sign` | **No flip**: it is about "toward the wind" |
| `tack_sign` | `IsStarboardTack ? +1 : -1` (manual) | `sign(awa_rad)` with hysteresis (recommended) or `-sail_side` | Same value on the same tack |
| `sheet` | 0 = in, 1 = eased | 0 = out, 1 = in | `sheet = 1 - sheet_legacy`; W increases ours |
| Heel angle | `SignedAngle(up, boardUp, forward)`: **negative** for a starboard heel, and it leaks pitch (`:280-282`) | `atan2(-up_local.x, up_local.y)`: positive for a starboard heel, no pitch leak | Flip in sign, and a bug fix |
| Roll axis for the anti-capsize | body +Z = bow | body +Z = tail | Positive torque about body +Z lifts the starboard rail in Godot; combined with the heel sign flip, `torque.z = M * sign(heel_rad)` restores in both frames |
| Weight-shift inversion on port tack | applied (`:164, 169`) | not applied (2c) | Legacy bug: on port tack the weight torque fought the rake |
| Q/E | E = back, both tacks | E = back, both tacks | Same |

Places where Unity's `Vector3.SignedAngle` or `Cross` would flip a sign if copied: the heel angle (`:280`, derived above) and the AWA (`SailingState.cs:113`, `SignedAngle(fwd, -aw, up)` happens to be positive for wind from starboard in Unity; in Godot use `atan2(from_local.x, -from_local.z)` per D4, never `signed_angle_to`). The rake-steering fallback `Cross(vel, apparentWind).y > 0` (`AdvancedSail.cs:482-483`) is not needed in the spec.

### Stabilisers and fudges in this model

| # | What | Added | Why (symptom) | What it probably hides | Recommendation |
|---|---|---|---|---|---|
| 1 | Weight-shift base yaw torque, 80 N m at any speed (`:257, 264`) | Session 22 (`PROGRESS_LOG.md:405, 436`) | "Control at zero speed"; the earlier Session 12 tuning had removed a 50 N m base torque from V2 for twitchiness (`PROGRESS_LOG.md:693-696`) and Session 22 put a bigger one back | Rake steering had no authority when the sail force was small, and the fin's tracking torque (15, `WindsurferSetup.cs:755`) fought every turn | **Drop.** Start with no direct yaw torque. Re-add as a config value only if the Phase 4 low-speed steering test fails, with a note. |
| 2 | Weight-shift speed torque, 30 N m x clamp(v/3) (`:260-261`) | Session 13 (`ca7a7b1` line 257-262) | Original design: "leaning turns the board" | A symmetric model has no mechanism by which a mass shift yaws the board; the torque is invented | **Re-evaluate.** Implement the lean as a real centre-of-mass shift (section 7). Whether it should also yaw the board is a Phase 4 decision. |
| 3 | Anti-capsize proportional counter-heel, `0.5556 * heel_deg^2` N m above 5 deg (`:287-296`) | Session 22 (`5a1857a`; the Session 13 version had only the hard limit, `ca7a7b1` lines 271-287) | "The sailor automatically leans out"; the board rolled over | No sailor balance in the model; in the last build the sail could not heel the board anyway (CE at the origin, horizontal force), so this fought buoyancy roll and the pitch leak | **Re-evaluate, replace.** Model the sailor's balance as an automatic lean (item 2) limited by physics: righting moment `<= m_sailor * g * lean_reach_m` (about 440 N m at 0.6 m). Keep as a beginner-mode toggle in config, off in advanced. |
| 4 | Anti-capsize hard limit above 45 deg, 100 N m/deg (`:299-306`) | Session 13 | Capsizing was possible and there was no way to recover | No recovery mechanic | **Drop** in the sim; provide R (reset) instead. Re-evaluate for beginner mode in Phase 4 once the sail has a real heeling moment. |
| 5 | Steering-torque scale-down above 15 kt and the 200 to 350 N m direct rake torque (`AdvancedSail.cs:498-519`) | Sessions 16, 17, 22 | Spinning at speed, no steering when the sail is unpowered | Belongs to section 3 (rake steering); listed here because the controller's feel depends on it | See section 3; the plan lists both as fudges to start without. |
| 6 | Auto-centre rake, 1 /s (`:231-235`) | Session 7 (`PROGRESS_LOG.md:1088-1090`) | A convenience: the mast returns to neutral when you let go | Nothing physical; a sailor does relax the rig when not steering | **Keep** as a beginner-mode assist and an option elsewhere. Not a physics fudge. |
| 7 | Auto-sheet (T) (`:211-216`) | Session 13 | Beginners cannot trim; the sail stalls or luffs | Nothing; it is a control assist | **Keep** as a beginner option with the 12 deg clamp fix. Also fix the "resume": legacy resumes the auto target the instant the key is released (`|input| < 0.1`), which undoes any manual trim within seconds; the spec should treat W/S in beginner mode as a trim offset (`sheet_auto + trim`, `trim` in [-0.3, 0.3], decaying only slowly or not at all). |
| 8 | Input smoothing 8 /s, dead bands 0.1 (input), 0.5 deg (lean), 5 deg (heel) | Session 13 | Feel: no instant jumps | Nothing | **Keep** (config values). The dead band on the rake input is what lets auto-centre take over after release. |
| 9 | Port-tack steering inversion (`:157-170`) | Session 26 | "A/D worked backwards on port tack" (`KNOWN_ISSUES.md:84`) | Nothing; it is the correct screen-relative mapping (formula 2) | **Keep** for rake; **do not** apply to the weight command (legacy bug). |
| 10 | V2 auto-stabiliser (angular damping x15, 15 % yaw-rate cut per step, corrective rake) and V2 auto-sheet "rotation correction" (`WindsurferControllerV2.cs:291-338, 415`) | Session 12 (`PROGRESS_LOG.md:700-706`) | The V2 board would not sail straight with no input | Fin tracking and yaw damping were wrong at the time | **Drop.** Not in the validated build. If the new board wanders with no input, the fin (section 4) is the place to look. |
| 11 | Controller sheet not initialised from the sail (`:80` vs `AdvancedSail.cs:29`) | Session 13 | Not noticed | A bug, not a fudge | **Fix**: the controller starts from the sim's sheet; recommended start `sheet = 0.35`. |

### What Phase 2 must implement

Phase 2 owns the simulation side; Phase 3 owns the key reading. To keep the mapping testable headless, the key-to-controls logic must be a plain class with no Node dependencies.

- [ ] `SimControls` (RefCounted or a small struct-like class): `sheet` (0 to 1), `rake` (-1 to 1), `lean` (-1 to 1), `tack_switch` (bool). `WindsurferSim.step(dt, controls)` takes it (plan, Phase 2).
- [ ] `ControlMapper` (RefCounted, in `Game/sim/` or `Game/windsurfer/` but with no Node use): input = a `KeyState` (booleans: `sheet_in`, `sheet_out`, `steer_left`, `steer_right`, `rake_forward`, `rake_back`, `tack_pressed`, `autosheet_toggle_pressed`) plus the telemetry it needs (`awa_rad`, `sail_side`); output = `SimControls`. Implements formulas 1 to 6 and 9 to 11 with the values above from a `ControlsConfig` resource.
- [ ] `ControlsConfig` resource (`Game/config/controls.tres`): `mode` (beginner / advanced), `sheet_rate`, `autosheet_enabled`, `autosheet_rate`, `autosheet_target_aoa_deg` (17), `rake_rate`, `auto_centre_rake`, `rake_centre_rate`, `rake_dead_band` (0.1), `lean_rate`, `smoothing_rate`, `tack_sign_source` (awa / sail_side), `tack_hysteresis_deg` (10), `start_sheet` (0.35).
- [ ] Optional sim-side assists, each behind a config flag that defaults to **off**: `weight_yaw_torque` (formula 7, `T_base`, `T_speed`, `speed_scale_ms`), `anticapsize` (formula 8, `heel_dead_zone_deg`, `heel_max_deg`, `gain_soft_nm_per_deg2`, `gain_hard_nm_per_deg`). Applied as couples on the body inside `WindsurferSim`, never from a Node.
- [ ] `heel_rad` and `pitch_rad` helpers on the rigid-body state, with the D4 signs (heel positive to starboard, pitch positive bow up), since the controller, the HUD and the tests all need them.
- [ ] Telemetry fields: `sheet`, `sheet_angle_rad`, `rake`, `lean`, `tack_sign`, `autosheet_enabled`, `control_mode`.

Phase 3 (from the plan's input map) then adds the Godot input actions and the two mode presets:

| Action | Keys | Beginner mode | Advanced mode |
|---|---|---|---|
| `sheet_in` / `sheet_out` | W / S (and Up / Down) | trim offset on top of the auto-sheet (item 7), or manual if `autosheet_enabled = false` | manual, formula 4 |
| `steer_left` / `steer_right` | A / D (and Left / Right) | `rake_cmd = steer_key * tack_sign` **and** `lean_cmd = steer_key` (formulas 2a, 2c) | `lean_cmd = steer_key` only; no rake |
| `rake_forward` / `rake_back` | Q / E | fine rake, overrides the A/D rake (2b), no inversion | the primary steering, `rake_cmd = rake_key`, no inversion |
| `tack` | Space (edge) | `tack_switch` | `tack_switch` |
| `toggle_hud` | F1 | HUD | HUD |
| `camera_1` to `camera_4` | 1 to 4 | follow / orbit / top-down / free | same |
| `reset` | R | put the board back at the start, level, sheet = `start_sheet`, rake 0, lean 0, sail side from the wind | same |
| `pause` | Esc | pause menu | same |
| optional `toggle_control_mode` | Tab | switch preset | switch preset |
| optional `toggle_autosheet` | T | toggles `autosheet_enabled` | no effect |

Preset table (recommended; the plan's open question 4 asks the team whether an Intermediate preset is wanted; it would be Advanced keys with `auto_centre_rake` and `anticapsize` on, exactly the Session 13 definition):

| Setting | Beginner | Advanced |
|---|---|---|
| A/D | screen steering (rake x tack_sign + lean) | lean only |
| Q/E | fine rake | rake |
| `auto_centre_rake` | on (1 /s) | off |
| `autosheet_enabled` | on (Session 13 preset; the last build had it off with T to enable) | off |
| `anticapsize` (if kept after Phase 4) | on | off |
| `weight_yaw_torque` (if kept after Phase 4) | on | on |
| `smoothing_rate` | 8 /s | 8 /s |

In free-camera mode (4) the camera should consume W/A/S/D/Space so the board does not steer while you fly (legacy quirk, `SimpleFollowCamera.cs:327-332`).

### Tests Phase 2 should write

Mapping tests (`ControlMapper`, headless, `dt = 1/60`):

- Starboard tack (`awa_rad = +1.396`, `tack_sign = +1`), hold D from neutral: `rake = 0.875 +/- 0.02` after 0.5 s (smoothing loses 0.0625 s), `rake = 1.0` by 0.6 s. `lean = 1.0` by 0.25 s (rate 4 /s beats the smoothing's 8 /s ramp).
- Port tack (`awa_rad = -1.396`): the same D press gives `rake = -0.875` after 0.5 s and `lean = +1.0` (not inverted). Mirror test: A on starboard tack equals D on port tack for rake, and is the negative for lean.
- E held on port tack: `rake` goes **positive** (no inversion); E held while D is held: rake follows E, lean follows D.
- Release after full rake with `auto_centre_rake = true`: `rake` is back within 0.02 of 0 by 1.2 s; with it false, `rake` stays at 1.0.
- Sheet: from `sheet = 0`, hold W for 1 s: `sheet = 0.75 +/- 0.01` (0.8 x (1 - 0.0625)); it never exceeds 1.0 after 2 s. From 1.0, hold S 1.25 s + 0.07 s: `sheet = 0`.
- `sheet_angle_rad`: `sheet = 1` gives `deg_to_rad(12) = 0.2094`; `sheet = 0` gives `deg_to_rad(85) = 1.4835`; `sheet = 0.5` gives `deg_to_rad(48.5) = 0.8465`.
- Auto-sheet targets (spec clamp 12 to 85): `awa_deg = 90` gives `sail_angle = 73`, `sheet_auto = 0.1644`; `awa_deg = 45` gives 28 deg and `0.7808`; `awa_deg = 150` gives 85 deg and `0.0`; `awa_deg = 20` gives 12 deg (clamped) and `1.0`; `awa_deg = -90` equals `+90` (absolute value).
- Auto-sheet rate: from `sheet = 1.0` with target 0.1644 and no key, `sheet = 0.7 +/- 0.01` after 1 s (0.3 /s); pressing S makes it move at 0.8 /s instead.
- Tack: `tack_pressed` for one step flips `tack_switch` once; holding it for 60 steps emits exactly one switch. After the sail side flips, `tack_sign` (from `awa` with hysteresis) does not change until `awa` crosses zero; with `tack_sign_source = sail_side` it flips immediately.
- Hysteresis: `awa_deg` going 8, 5, -5, -8 keeps `tack_sign = +1` until `|awa_deg| >= 10` on the other side.
- Determinism: the same key sequence twice gives identical `SimControls` every step.

Sim-side assist tests (with the flags on):

- Weight yaw torque: `lean = 1.0`, `speed_ms = 0`: `torque_body.y = -80 N m` (negative = right turn in Godot); `speed_ms = 3`: `-110`; `speed_ms = 6`: `-110` (clamped); `lean = -1.0`: `+80`; `lean = 0.02`: 0 (dead zone).
- Heel angle helper: a basis rotated 20 deg about the bow axis so that the starboard rail is down gives `heel_rad = +0.349`; a basis pitched 10 deg bow-up with no roll gives `heel_rad = 0` (the legacy pitch leak must not reappear).
- Anti-capsize magnitudes: heel 3 deg gives 0; 10 deg gives 55.6 N m; 20 deg gives 222.2 N m; 45 deg gives 1125 N m; 60 deg gives 3000 N m. Sign: for `heel_rad > 0` (starboard down) `torque_body.z > 0`; integrating one step must reduce `|heel_rad|`.
- Symmetry: the mirrored state (heel to port, lean to port, port tack) gives mirrored torques of equal magnitude.

Behaviour tests (with the full sim, Phase 2/3, on flat water, 15 kt wind):

- Beam reach on starboard tack, hold D for 2 s: the compass heading increases (clockwise, turning right) and TWA decreases (heading up). Hold A: heading decreases, TWA increases.
- The same on port tack: D still increases the heading (turning right), which is now bearing away (|TWA| increases).
- Space on a beam reach flips the boom to the other side within one step and the drive force changes sign relative to the wind side as the sail-side section specifies.
- R (Phase 3) restores the start state exactly (position, level attitude, `sheet = start_sheet`, `rake = 0`, `lean = 0`).

### Sources

- `Legacy/WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs`: header 8-18; fields 21-68; state 71-81; accessors 87-88; Update/FixedUpdate 116-130; ReadInput 135-190 (sheet 146-150, tack sign 157-159, A/D 161-170, Q/E 172-176, Space 178-182, T 184-189); SmoothInput 195-201; ApplyControls 206-243 (auto-sheet 211-216, manual sheet 218-222, rake 226-236, weight 239-242); ApplyWeightShift 248-270; ApplyAnticapsize 276-307; GetStateDescription 312-329; gizmos 331-386.
- Git history of that file: `ca7a7b1` (2025-12-27, Session 13; modes at lines 33, 94-99, 123-126, 158-192, 292-319; anti-capsize hard limit only, 271-287; weight torque without base term, 251-266), `5a1857a` (2025-12-28, Session 22; removed the modes and Tab, added Space and T, the 80 N m base torque and the proportional counter-heel), `b5ed2ea` (2026-01-02, Session 26; port-tack inversion).
- `Legacy/WindsurfingGame/Assets/Scripts/Player/WindsurferControllerV2.cs`: 27-69, 86-90, 169-176, 179-185, 192-259, 265-285, 291-338, 344-358, 364-382, 384-438, 444-465 (comparison only).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs`: 29, 32, 42, 45 (values); 65-66, 80-81 (manual tack); 137-153 (rate limits); 199-208 (sail side from the manual tack); 224-230 (boom angle 12 to 85 deg); 283-291 (CE at origin); 363-364 (horizontal force only); 450-525 (rake steering: tack 467-495, scale 498-503, terms 506-524); 532-535, 549-554, 560-564, 586-607, 617-620, 625-628, 633-637 (control API).
- `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs:255-268` (optimal sheet angle); `SailingState.cs:30, 97-119` (SailSide comment, AWA sign); `BoardMassConfiguration.cs:54, 110, 191-200` (mass and inertia handling).
- `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs`: 669 (dialog), 689-693 (rigidbody), 700-701 (collider), 736 (max rake), 755 (fin tracking), 791-801 (controller: only `_antiCapsize`, `_autoCenterRake`).
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity`: 214-217, 230 (rigidbody), 342-347 (sail), 353-381 (controller values), 464-476 (mass config).
- `Legacy/WindsurfingGame/Assets/InputSystem_Actions.inputactions`: 9-90, 103-193, 380, 435 (unused template).
- `Legacy/WindsurfingGame/Assets/Scripts/UI/AdvancedTelemetryHUD.cs:94-99, 200-206, 273-277`; `Camera/SimpleFollowCamera.cs:12-18, 229-236, 327-332`; `ProjectSettings/TimeManager.asset:6`.
- `Legacy/Documentation/KNOWN_ISSUES.md:81-87`; `PROGRESS_LOG.md:24, 65, 71-72, 147-157, 267, 405, 414, 436, 559-571, 611, 660-666, 680-704, 711-713, 747-754, 1056-1096, 1127-1150, 1464, 1548-1560`; `ARCHITECTURE.md:368-396`; `COMPONENT_DEPENDENCIES.md:49-51, 142-151` (its rake table is the pre-Session-19 wrong direction); `QUICK_SETUP_CHECKLIST.md:56`; `README.md:109-121`; `SCENE_CONFIGURATION.md:195-226, 452-463` (V2 history only).
- `Documentation/REBUILD_PLAN.md`: D4 table (lines 57-71, steering keys row 69), Phase 3 input map (186-188), open question 4 (307).
- Literature: the 15 to 20 deg angle of attack for best sail lift-to-drag is standard sail aerodynamics (C. A. Marchaj, *Sail Performance*, Adlard Coles, 1996, chapter on sail lift and drag polars); the sailor righting-moment estimate is `m * g * arm` (statics).

---

## 11. Every tuning value and where it came from

### Purpose

This section is the master list of every number that tunes the simulation: the ones the Unity version exposed in the inspector, the ones it hid inside formulas, and the engine settings it ran under. Phase 2 turns this list into the config resources in `Game/config/` (`BoardConfig`, `SailConfig`, `FinConfig`, `SailorConfig`, `WaterConfig`, `WindConfig`), plus a `SimConfig` for time step and integrator settings and a `ControlConfig` for the controller. Phase 4 tunes the numbers against the validation suite; this table tells it where each number started and how much to trust it.

The other sections of this spec explain the formulas. This section only answers three questions for each number: what was it, where did it come from, and what should Godot start with.

One more rule: where the "Start with" column below differs from the default configuration chosen in section 14 (board 2.40 × 0.72 × 0.12 m and 9 kg; sail luff 4.60 m and boom 1.95 m; fin 0.0365 m² and 0.38 m deep; rig 8 kg; total 92 kg), **section 14 wins**. The "Start with" column records the legacy-faithful starting point for each value so that Phase 4 can see where a number came from.

Units: SI inside the simulation (m, s, kg, N, rad). Degrees appear in the tables only where the name ends in `_deg`, and knots and km/h only in the "Docs" column and in notes.

### How to read the tables

#### The four legacy sources, and why they disagree

Every Unity number can come from up to four places, and they often disagree:

1. **C# field default** (`[SerializeField] private float _x = 800f;`). This is what a component gets when it is first added to a scene. Changing this default later does **not** change a component that already exists in a saved scene: Unity keeps the value that was serialised into the scene file.
2. **`WindsurferSetup.cs`**, the editor wizard. It created the scene's Windsurfer, Water and Wind objects and wrote some (not all) inspector values with `FindProperty(...)`. Values it does not write keep the C# default of the moment the component was created.
3. **`Assets/Scenes/MainScene.unity`**, the scene file. Contrary to the note in the task brief, this file **does** hold every serialised component value (for example `_verticalDamping: 800` at `MainScene.unity:254`). It is the only record of what a Play session actually used, subject to the caveat below.
4. **Docs** (`PHYSICS_DESIGN.md` section 8, `PHYSICS_VALIDATION.md`, `PROGRESS_LOG.md`, `KNOWN_ISSUES.md`, `ARCHITECTURE.md`, `README.md`). These were written by hand and drifted. `scene_config.json` (2025-12-27) describes the old non-Advanced components and is history only; it is not used below.

Godot removes this whole class of problem: one `.tres` file per config, loaded by the game and by the tests.

#### Which values the last validated Unity build most likely ran with

The git history of `MainScene.unity` settles most of this, so it is worth stating plainly:

- **Session 22 (28 Dec 2025, commit `5a1857a`)**: the wizard created the scene. Every physics value in that scene version equals what `WindsurferSetup.cs` writes, or the C# default of that day for fields the wizard does not write. Example: `_planingLiftCoefficient: 0.15`, `_maxLiftFraction: 0.4`, `_submersionDragMultiplier: 3`, `_planingWettedAreaRatio: 0.35`, `_verticalDamping: 800`.
- **Sessions 24 to 26 (1 and 2 Jan 2026, commits `fa79027`, `c62f577`, `b5ed2ea`)**: the C# defaults were changed (vertical damping 800 → 4000 → 8000, water viscosity 0 → 400 → 800, planing lift coefficient 0.15 → 0.8 → 1.0, max lift fraction 0.4 → 0.85 → 1.0, submersion drag multiplier 3 → 12, planing wetted-area ratio 0.35 → 0.20, optimal trim 2 → 3). The wizard was **not** re-run, and the scene kept its Session 22 values. Proof: the scene as committed by Session 26 (`git show b5ed2ea:WindsurfingGame/Assets/Scenes/MainScene.unity`, lines 642-681) still has `_verticalDamping: 800`, `_planingLiftCoefficient: 0.15`, `_maxLiftFraction: 0.4`, `_submersionDragMultiplier: 3`, `_planingWettedAreaRatio: 0.35`, `_optimalTrimAngle: 2`. Fields that were new in Session 24 got the default of the day they were first saved: `_waterViscosity: 400`, `_submersionVerticalDamping: 600`, `_maxPlaningSubmersion: 0.5`. Two values were edited by hand in the inspector, because they match no default: `_liftSmoothingFactor: 0.15` and `_windSpeedKnots: 22`. **This set ("Scene S26" in the tables) is what the Session 24 to 26 play-tests, the ones the docs call "validated", most likely ran with.** It is not what the docs say (they say 4000 / 400 / 0.85) and not the C# defaults.
- **2 Jan 2026, commit `dfbc3a0` ("Fix namespace conflicts")**: the scene was regenerated (1053 lines changed, all object IDs new). Every physics value in the regenerated scene equals the wizard's value or the Session-26 C# default, and the wind went back to 15 kt from 270° (the wizard's 12 kt / 45° never applied, because until Session 27 it wrote to a field name that does not exist; `PROGRESS_LOG.md:119`). This is the scene in the repository today ("Scene now" in the tables). Nothing in the logs says it was played after regeneration, and Session 27 was written without Unity (`PROGRESS_LOG.md:103`).

So: **"Scene S26" = last played; "Scene now" = what the repository ships.** Where the two differ, the tables show both as `S26 → now`. Caveat that cannot be resolved from the files: Unity discards inspector edits made during Play mode, so a value tuned in Play and never re-typed afterwards leaves no trace.

One consequence worth noticing: with Scene S26, the maximum planing lift was `weight × maxLiftFraction × planingLiftCoefficient = weight × 0.4 × 0.15 = 6 % of weight` (`AdvancedHullDrag.cs:452-468`). The "planing" that was play-tested was therefore almost entirely buoyancy, with displacement lift fading out as the planing ratio rose (`AdvancedHullDrag.cs:356`). That probably explains why the board sat deep on a beam reach (Known legacy pitfall 6). Phase 4 must not treat any of the Unity planing numbers as tuned.

#### Unity to Godot: what changes in a value

- Positions and offsets in the body frame: Unity `(x, y, z)` becomes Godot `(x, y, -z)`, because the bow is Unity +Z and Godot −Z. Starboard (+X) and up (+Y) are unchanged. Every position in the tables below is already converted and marked "(Godot)".
- Yaw torques: Unity `AddTorque(Vector3.up * T)` with `T > 0` turns the bow to the **right** (clockwise from above, left-handed frame). In Godot a positive torque about +Y turns the bow to **port** (counter-clockwise from above). Every "+Y turns right" in the legacy steering code becomes a `−Y` torque in Godot. The controller and rake-steering rows say so again.
- Heel and pitch read from Euler angles: Unity `eulerAngles.z` (roll) and `eulerAngles.x` (pitch) have signs that depend on Unity's rotation order and handedness. The spec uses `heel_rad` positive = heeled to starboard and `pitch_rad` positive = bow up, computed from the basis vectors (see the mass and damping sections), never from Euler angles.
- Wind bearing, wave direction and compass headings are the same numbers in both engines (0 = North, 90 = East), because North = −Z in Godot and +Z in Unity, and East = +X in both, and the conversion `(sin θ, cos θ)` in Unity becomes `(sin θ, −cos θ)` in Godot. The wind and wave sections give the formula.
- `Time.fixedDeltaTime` (0.02 s) becomes the simulation's `dt` (a substep of the 60 Hz physics tick). Any legacy number that was "per fixed step" is converted to "per second" below.

#### Column meanings

| Column | Meaning |
|---|---|
| Godot name | GDScript-style name with the unit in it, as the `.tres` should expose it |
| C# default | The field default, with `file:line`. "hard-coded" means a literal inside a formula |
| Wizard | Value written by `WindsurferSetup.cs`, with line; "-" = not written by the wizard |
| Scene | `MainScene.unity` value: one number if S26 and now agree, otherwise `S26 → now`, with the current line |
| Docs | Value stated in the documentation, with file:line |
| Start with | The value Godot should start from |
| Why | One line of reasoning |

Files are under `Legacy/WindsurfingGame/Assets/Scripts/` unless a path starts with `Legacy/`. `Scene` line numbers refer to `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` as it is today.

### Simulation group (engine settings, time step, gravity, mass, damping)

These are not physics coefficients; they are the conditions the Unity physics ran under, and the Godot integrator must reproduce or consciously replace each one.

| Godot name | Unity value and source | Start with | Why |
|---|---|---|---|
| `physics_ticks_per_second` | 50 Hz: `Fixed Timestep: 0.02` (`Legacy/WindsurfingGame/ProjectSettings/TimeManager.asset:6`); docs `PHYSICS_DESIGN.md:512` | 60 (Godot project default, already set in `Game/project.godot`) | Godot's physics tick; the sim gets `dt = 1/60 / substeps` |
| `substeps_per_tick` | none (PhysX did one solver pass per fixed step) | 4 (plan, Phase 2) so `dt_sub = 1/240 s` | Semi-implicit Euler on a 6-DOF body with stiff buoyancy needs small steps; a setting so Phase 4 can test 2 and 8 |
| `max_ticks_per_frame` | `Maximum Allowed Timestep: 0.33333334` s = up to 16 fixed steps per frame (`TimeManager.asset:7`); `scene_config.json:337` says 0.1 (history) | Godot default (`physics/common/max_physics_steps_per_frame` = 8) | Keeps the game from spiralling when a frame is slow |
| `gravity_ms2` | `m_Gravity: {x: 0, y: -9.81, z: 0}` (`DynamicsManager.asset:7`); `PhysicsConstants.cs:18` GRAVITY = 9.81 | 9.81 | Standard; the sim applies it itself (D2), so Godot's physics gravity setting is irrelevant |
| `solver_iterations` | `m_DefaultSolverIterations: 6`, `m_DefaultSolverVelocityIterations: 1` (`DynamicsManager.asset:12-13`) | not applicable | Our integrator has no constraint solver; there are no contacts in Phase 2 |
| `sleep_threshold` | `m_SleepThreshold: 0.005` (`DynamicsManager.asset:10`) | none (never sleep) | A sailing body must keep integrating; sleeping caused nothing in Unity but would break tests that check for tiny drift |
| `max_angular_speed_rad_s` | `m_DefaultMaxAngularSpeed: 50` rad/s (`DynamicsManager.asset:36`) | 50 as a safety clamp, asserted never to be reached in tests | A hidden Unity clamp; keep it only as a "something exploded" guard |
| `total_mass_kg` (Rigidbody) | Wizard `rb.mass = 91f` (`Editor/WindsurferSetup.cs:689`), serialised `m_Mass: 91` (`MainScene.unity:214`). **Overwritten at run time** to 94: `BoardMassConfiguration.Awake()` recomputes `_totalMass = 8 + 6 + 80 = 94` (`Board/BoardMassConfiguration.cs:110`) and `Start()` sets `_rigidbody.mass = _totalMass` (`:191`). Docs: 90 (`PHYSICS_DESIGN.md:554`, `QUICK_SETUP_CHECKLIST.md:49`), 91 (`ARCHITECTURE.md:549`), 95 (wizard comment `:25`, `:849`, and `_totalMass = 95f` at `BoardMassConfiguration.cs:24`, which `Awake()` then replaces) | 91 = 8 (board) + 8 (rig) + 75 (sailor); one number, derived from the three masses in `BoardConfig`, `SailConfig`, `SailorConfig` | The Unity body ran at 94 kg while `AdvancedHullDrag` computed weight-based lift caps with 91 kg (`SailingState.cs:473`): two different masses in one simulation. Godot uses one. |
| `linear_damping_per_s` | `rb.linearDamping = 0f` (`WindsurferSetup.cs:690`), `m_LinearDamping: 0` (`MainScene.unity:215`) | 0 | Hull drag is the only translational damping (correct in Unity too) |
| `angular_damping_per_s` | `rb.angularDamping = 0.3f` (`WindsurferSetup.cs:691`), `m_AngularDamping: 0.3` (`MainScene.unity:216`); docs say 0.5 (`SCENE_CONFIGURATION.md:35`, old setup) or 2.0 (`QUICK_SETUP_CHECKLIST.md:49`) | 0 | A hidden PhysX stabiliser (angular velocity × (1 − 0.3·dt) each step, time constant 3.3 s). All rotational damping must come from the water model where it can be tested. |
| `interpolation` | `RigidbodyInterpolation.Interpolate` (`WindsurferSetup.cs:692`, `m_Interpolate: 1` `MainScene.unity:230`) | Godot physics interpolation on (project setting, already on; CLAUDE.md rule 6) | Visual smoothness only; no effect on the sim |
| `collision_detection` | `ContinuousDynamic` (`WindsurferSetup.cs:694`, `m_CollisionDetection: 2` `MainScene.unity:232`) | not applicable in Phase 2 | No engine collisions in the sim (D2); Phase 7 adds custom checks |
| `collider_size_m` | BoxCollider `(0.6, 0.12, 2.5)` centred at origin (`WindsurferSetup.cs:700-701`, `MainScene.unity:497-498`) | the board box `width_m × thickness_m × length_m` from `BoardConfig` | In Unity this box also defined the **inertia tensor** (`m_ImplicitTensor: 1`, `MainScene.unity:227`; `_useCustomInertia = false`, `BoardMassConfiguration.cs:54`). See the inertia rows in SailorConfig. |
| `centre_of_mass_m` (Godot) | Unity `(0, 0.15, -0.1)` = 0.15 m above the board centre, 0.10 m **aft** (`BoardMassConfiguration.cs:37`, `MainScene.unity:468`) | Godot `(0, 0.15, +0.10)`; see SailorConfig for the composite value and the recommendation | Converted with `z → −z` |

Hidden constants used for unit conversion (`PhysicsConstants.cs:21-24`): `MS_TO_KNOTS = 1.94384`, `KNOTS_TO_MS = 0.514444`. Godot: define once in a `Units` helper; tests use them for readable messages only.

### Physical constants (shared by every config)

| Godot name | Value | Unit | Source | Start with | Why |
|---|---|---|---|---|---|
| `rho_air` | 1.225 | kg/m³ | `Core/PhysicsConstants.cs:12`; `PHYSICS_DESIGN.md:543` | 1.225 | Sea level, 15 °C (ISA) |
| `rho_water` | 1025 | kg/m³ | `PhysicsConstants.cs:13`; `PHYSICS_DESIGN.md:539` | 1025 | Sea water; fresh water would be 1000 (a `WaterConfig` field so a lake can be simulated) |
| `nu_water_m2_s` | 1.19e-6 | m²/s | `PhysicsConstants.cs:14`; `ARCHITECTURE.md:417` says 1.139e-6 (docs conflict, both are "about 15 °C" values) | 1.19e-6 | Used only in the Reynolds number of the ITTC friction line |
| `nu_air_m2_s` | 1.48e-5 | m²/s | `PhysicsConstants.cs:15`; `ARCHITECTURE.md:418` | not needed | Never used by the legacy sail model |
| `g` | 9.81 | m/s² | `PhysicsConstants.cs:18` | 9.81 | |

`PhysicsConstants.Equipment` (`PhysicsConstants.cs:30-50`) lists "typical" equipment numbers (board 2.5 × 0.6 × 0.12 m, 120 L, 8 kg; fin 0.40 m deep, 0.12 m chord, 0.035 m², AR 4.5; sail 6.5 m², luff 4.7 m, boom 2.0 m, mast 4.6 m; sailor 75 kg, 1.75 m). Nothing reads them at run time; they agree with the wizard except `FIN_CHORD = 0.12` (wizard 0.10) and `FIN_ASPECT_RATIO = 4.5` (the real ratio 0.40²/0.035 = 4.57).

### BoardConfig

#### Geometry, volume and buoyancy sampling

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `length_m` | 2.5 (`Buoyancy/AdvancedBuoyancy.cs:36`; `HullConfiguration.Length` `Core/SailingState.cs:449`); **2.4** in `BoardMassConfiguration.cs:44` | 2.5 (`WindsurferSetup.cs:710`, `:764`); 2.4 for the mass component (`:783`) | 2.5 (`MainScene.unity:247`, `:273`); 2.4 (`:470`) | 2.5 (`PHYSICS_DESIGN.md:548`) | 2.50 | One length everywhere. The 2.4 was only used for the unused custom inertia. The old board model measures 2.28 m (plan, Phase 1); the team decides in the open questions, the physics does not care which. |
| `width_m` | 0.6 (`AdvancedBuoyancy.cs:39`; `SailingState.cs:452`; `BoardMassConfiguration.cs:47`) | 0.6 (`:711`, `:765`, `:784`) | 0.6 (`:248`, `:274`, `:471`) | 0.6 (`PHYSICS_DESIGN.md:549`) | 0.60 | Old model is 0.80 m wide (plan); same remark |
| `thickness_m` | 0.12 (`AdvancedBuoyancy.cs:42`; `SailingState.cs:455`; `BoardMassConfiguration.cs:50`) | 0.12 (`:712`, `:766`, `:785`) | 0.12 (`:249`, `:275`, `:472`) | - | 0.12 | Also the depth over which a sample point goes from dry to fully submerged (`AdvancedBuoyancy.cs:244`) |
| `volume_m3` | 120 L = 0.120 m³ (`AdvancedBuoyancy.cs:33`, converted at `:110`; `SailingState.cs:458` `Volume = 120f` is unused by physics) | 120 (`:709`, `:767`) | 120 (`:246`, `:276`) | 120 L (`PHYSICS_DESIGN.md:547`; `PROGRESS_LOG.md:443`) | 0.120 (show as 120 L) | At rest with 91 kg the board sits at 88.8 L = 74 % submerged (Archimedes; plan pitfall 8) |
| `mass_board_kg` | 8 (`HullConfiguration.BoardMass` `SailingState.cs:462`; `BoardMassConfiguration.cs:27`) | 8 (`:768`, `:780`) | 8 (`:277`, `:465`) | **15** (`PHYSICS_DESIGN.md:555`) | 8 | Real freeride boards weigh 7 to 9 kg; the doc's 15 is stale |
| `nose_rocker_m` | 0.08 (`AdvancedBuoyancy.cs:45`) | 0.08 (`:713`) | 0.08 (`:250`) | 0.08 (`PHYSICS_DESIGN.md:550`, `:118`) | 0.08 | Bottom rises 8 cm at the nose, quadratic from the centre (`AdvancedBuoyancy.cs:161-170`) |
| `tail_rocker_m` | 0.02 (`AdvancedBuoyancy.cs:48`) | 0.02 (`:714`) | 0.02 (`:251`) | 0.02 (`PHYSICS_DESIGN.md:551`, `:119`) | 0.02 | |
| `buoyancy_samples_length` | 7 (`AdvancedBuoyancy.cs:52`) | 7 (`:715`) | 7 (`:252`) | 7×3 grid (`PHYSICS_DESIGN.md:89`; `PROGRESS_LOG.md:360`) | 7 | 21 points; tests should check the sum of point volumes equals `volume_m3` |
| `buoyancy_samples_width` | 3 (`AdvancedBuoyancy.cs:55`) | 3 (`:716`) | 3 (`:253`) | 3 | 3 | |
| `width_taper` | 0.3, hard-coded: `widthFactor = 1 − 0.3·d²` (`AdvancedBuoyancy.cs:173`) | - | - | **0.5** ("ends are 50 % as wide", `PHYSICS_DESIGN.md:122`) | 0.3 | Code and doc disagree; the code ran. Ends are 70 % as wide as the centre. |
| `volume_taper` | 0.4, hard-coded: `volumeFactor = 1 − 0.4·d` (`AdvancedBuoyancy.cs:177`) | - | - | a 7-entry weight list `{0.6, 0.8, 1.0, 1.0, 0.9, 0.7, 0.5}` (`PHYSICS_DESIGN.md:125`) | 0.4 | The doc's list was never in the code; the buoyancy section decides whether a real volume distribution replaces both |
| `sample_full_depth_m` | = `thickness_m`, hard-coded (`AdvancedBuoyancy.cs:244`) | - | - | - | = `thickness_m` | Depth at which a sample point counts as fully submerged |
| `floating_threshold_n` | 0.1 N, hard-coded (`AdvancedBuoyancy.cs:269`) | - | - | - | drop | Below 0.1 N of total buoyancy the board counted as "not floating" and the centre of buoyancy fell back to the origin; Godot just uses the computed value |

#### Hull resistance and planing

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `wetted_area_factor` | 0.7 and 0.05, hard-coded: `WettedArea = L·W·0.7 + 2(L+W)·0.05` = 1.36 m² (`SailingState.cs:478`) | - | - | - | 0.7 and 0.05 (gives 1.36 m² at rest) | Rough; the hull section may replace it by the submerged sample area |
| `waterline_length_factor` | 0.8, hard-coded: `WaterlineLength = 0.8·L` = 2.0 m (`SailingState.cs:483`) | - | - | - | 0.8 | Used in the Froude and Reynolds numbers |
| `hull_min_speed_ms` | 0.1, hard-coded (`Core/Hydrodynamics.cs:171`; `Board/AdvancedHullDrag.cs:166`) | - | - | - | 0.1 | Below it resistance is zero (avoids dividing by zero in the Reynolds number) |
| `reynolds_min` | 1e5, hard-coded (`Hydrodynamics.cs:178`) | - | - | - | 1e5 | Keeps the ITTC line valid at crawl speeds |
| `ittc_friction` | `Cf = 0.075 / (log10 Re − 2)²` (`Hydrodynamics.cs:181`) | - | - | - | keep | ITTC 1957 model-ship line (literature) |
| `residuary_coefficient` | `Cr = 0.001·Fn⁴·(1 + 5·Fn)` (`Hydrodynamics.cs:194`), used when not planing or `Fn < 0.4` (`:189`) | - | - | - | keep, re-evaluate in Phase 4 | Labelled "Delft series approximation" but is a made-up fit; harmless at Fn < 0.4 |
| `planing_froude_start` / `_span` | 0.4 and 0.3, hard-coded: `planingFactor = clamp01((Fn − 0.4)/0.3)` (`Hydrodynamics.cs:203`) | - | - | - | keep only if the hull section keeps this resistance blend | Second, Froude-based planing ramp inside the resistance formula, separate from the speed-based `planing_ratio` below |
| `planing_wetted_reduction` | 0.85, hard-coded (`Hydrodynamics.cs:207`) | - | - | - | drop (double counting) | The wetted area passed in was already reduced by `planing_wetted_area_ratio`; the 0.85 reduced it again |
| `spray_drag_coefficient` | 0.01 × planingFactor, hard-coded (`Hydrodynamics.cs:213`) | - | - | `KNOWN_ISSUES.md:98` (Session 25 sign fix) | 0.01 | Grows with planing, as it should |
| `hump_resistance_factor` | 1.5, hard-coded: displacement side of the blend is `1.5·Rf` (`Hydrodynamics.cs:217`) | - | - | - | re-evaluate | Fake "transition hump"; note that it **drops** the residuary term the moment `isPlaning` becomes true |
| `wave_added_resistance` | `50·H²·ω_e` (`Hydrodynamics.cs:229-237`) | - | - | - | drop | `CalculateWaveResistance` is never called |
| `planing_onset_speed_ms` | 4.0 (`AdvancedHullDrag.cs:31`) | - | 4 (`:280`) | 4.0 (`PHYSICS_DESIGN.md:563`, `:391`; `ARCHITECTURE.md:24`; `PROGRESS_LOG.md:388`) | 4.0 (14.4 km/h) | `planing_ratio` is 0 below it. Plan target: planing starts at 15-17 km/h of boat speed, so the ratio-0.5 point (5 m/s = 18 km/h) is what Phase 4 measures |
| `full_planing_speed_ms` | 6.0 (`AdvancedHullDrag.cs:34`) | - | 6 (`:281`) | 6.0 (`PHYSICS_DESIGN.md:564`, `:392`) | 6.0 (21.6 km/h) | `planing_ratio` is 1 above it; `is_planing` when the ratio > 0.5 (`:189`) |
| `planing_wetted_area_ratio` | 0.20 (`AdvancedHullDrag.cs:37`) | - | **0.35 → 0.2** (`:282`) | - | 0.20 | Wetted area at full planing as a fraction of rest (`:198-200`); last played with 0.35 |
| `submersion_drag_multiplier` | 12.0 (`AdvancedHullDrag.cs:41`) | - | **3 → 12** (`:283`) | 12 (`PHYSICS_DESIGN.md:569`; `PHYSICS_VALIDATION.md:386`; `PROGRESS_LOG.md:257` "6x → 12x") | **drop** (fudge) | `R *= 1 + 12·e²` with `e = (sub − 0.35)/0.65` (`:220-228`). Added in Session 23/24 to force a submerged board to slow down. At rest the board is 74 % submerged (Archimedes), so `e = 0.6` and drag is already ×5.3 before moving: it fights the physics of floating. Re-add only if the Phase 4 nose-dive test fails. Note the play-tested value was 3, not 12. |
| `normal_submersion` | 0.35, hard-coded (`AdvancedHullDrag.cs:220`) | - | - | "30-40 %" (`:218`) | drop with the multiplier | Wrong for a 120 L board carrying 91 kg (74 % at rest) |
| `underwater_drag_bonus` | up to ×5 when `sub > 0.5` and `speed > 4 m/s`, ramps `(sub − 0.5)·2 × clamp01((v − 4)/4) × 5` (`AdvancedHullDrag.cs:232-243`) | - | - | `KNOWN_ISSUES.md:125` | **drop** (fudge, Session 23) | Stacks on the ×12 above: a board 60 % under at 8 m/s had drag ×(1+12·0.148)×(1+0.2·1·5) = ×5.5. Cause to fix instead: planing lift that does not depend on depth, and real submerged-hull drag |
| `ride_high_drag_bonus` | `R *= max(0.5, 1 − (0.35 − sub)·0.5)` when planing and `sub < 0.35` (`AdvancedHullDrag.cs:247-250`) | - | - | - | drop | Reduces drag by up to 17 % for riding high; the wetted-area reduction already does this |
| `submersion_vertical_damping_ns_m` | 600 (`AdvancedHullDrag.cs:44`) | - | 600 (`:284`) | - | **drop** | A second vertical damper (`F = −v_y·600·sub`, doubled when `planing_ratio > 0.2` and `sub > 0.4`, `:256-270`) on top of the buoyancy one. The comment at `:492-493` claims there is no duplicate; there is. Only when `abs(v_y) > 0.02` and `sub > 0.1` (`:257`). |
| `lateral_drag_cd` | 1.0, hard-coded, area `L·T` = 0.30 m², `F = Cd·½ρ·v·|v_lat|·A·(1 − 0.5·planing_ratio)` (`AdvancedHullDrag.cs:296-302`) | - | - | - | 1.0, re-evaluate | Flat-plate sideways drag on the rails; only when `|v_lat| > 0.1` (`:293`). Note `q` is `½ρ·speed` (not speed²) at `:288`, multiplied by `lateralSpeed` at `:298`: the force is `½ρ·|v|·|v_lat|·Cd·A`, a mixed product, not `v_lat²`. The hull section should decide on `v_lat·|v_lat|`. |
| `vertical_drag_cd` | 1.2, hard-coded, area `0.5·L·W` = 0.75 m² (`AdvancedHullDrag.cs:309-314`) | - | - | - | 1.2 as the **only** quadratic vertical damping (see damping) | Same mixed product `½ρ·|v|·|v_y|`; only when `|v_y| > 0.1` (`:307`). Applied along world up, not the board normal |
| `resistance_point_aft_m` | `0.1·L` = 0.25 m aft, hard-coded (`AdvancedHullDrag.cs:518`); Unity `(0, 0, −0.25)` | - | - | - | Godot `(0, 0, +0.25)`, re-evaluate | Where the total resistance vector is applied ("centre of lateral resistance"). Also carries the lateral and vertical drag, so lateral drag gives a yaw torque of `0.25 × F_lat` |
| `displacement_lift_enabled` | true (`AdvancedHullDrag.cs:48`) | - | 1 (`:285`) | - | re-evaluate (plan pitfall 8) | Partly added to fight Archimedes; the hull section decides |
| `displacement_lift_coefficient` | 0.12 (`AdvancedHullDrag.cs:51`) | - | 0.12 (`:286`) | 0.12 (`PHYSICS_DESIGN.md:565`, `:195`; `PROGRESS_LOG.md:448`) | 0.12 if kept | `L = 0.12·½ρv²·(0.8·L·W)`: at 3 m/s that is 664 N = 74 % of weight before the cap |
| `displacement_lift_min_speed_ms` | 0.5 (`AdvancedHullDrag.cs:54`) | - | 0.5 (`:287`) | 0.5 (`PHYSICS_DESIGN.md:196`) | 0.5 if kept | |
| `displacement_planform_factor` | 0.8, hard-coded (`AdvancedHullDrag.cs:345`) | - | - | 0.8 (`PHYSICS_DESIGN.md:179`) | 0.8 | Planform area = `0.8·L·W` = 1.2 m² |
| `displacement_lift_cap_fraction` | 0.3 of weight, hard-coded (`AdvancedHullDrag.cs:352`) | - | - | 0.3 (`PHYSICS_DESIGN.md:187`) | 0.3 if kept (plan: fudge) | Was 0.5 before Session 24 (`git show fa79027`) |
| `lift_touch_threshold` | 0.05 submersion, hard-coded (`AdvancedHullDrag.cs:339`, `:394`, `:487`) | - | - | 0.05 (`PHYSICS_DESIGN.md:182`) | 0.05 | "Is the board touching the water" check; binary, not proportional (Session 24 lesson) |
| `planing_lift_enabled` | true (`AdvancedHullDrag.cs:58`) | - | 1 (`:288`) | - | true | |
| `planing_lift_coefficient` | 1.0 (`AdvancedHullDrag.cs:61`) | - | **0.15 → 1** (`:289`) | 0.8 (`PHYSICS_DESIGN.md:566`, `:232` "Savitsky typical 0.5-1.0"); 0.15 (`PROGRESS_LOG.md:449`) | not used by the Savitsky model the plan asks for; if the legacy ramp model is kept as a fallback, 1.0 | Multiplier on the target lift (`:463`). The legacy formula is not Savitsky: `target = weight·max_lift_fraction·planing_ratio·max(cos heel, 0.7)·coef` (`:452-463`). Only the doc quotes Savitsky's `CL = τ^1.1(0.012λ^0.5 + 0.0055λ^2.5/Cv²)` and the deadrise term `0.0065·β·CL0^0.6` (`PHYSICS_VALIDATION.md:314-329`, `PHYSICS_DESIGN.md:204-219`); that code was replaced by the ramp in commit `c62f577`. |
| `max_lift_fraction` | 1.0 (`AdvancedHullDrag.cs:64`) | - | **0.4 → 1** (`:290`) | 0.85 (`PHYSICS_DESIGN.md:567`, `:233`; `PROGRESS_LOG.md:255` "1.2 → 0.85") | drop the cap (plan: fudge); Savitsky lift is self-limiting because the board rises and the wetted length shrinks | Caps planing lift at a fraction of weight (`:467-468`). Last played at 0.4 |
| `optimal_trim_deg` | 3 (`AdvancedHullDrag.cs:67`) | - | **2 → 3** (`:291`) | - | not used | Declared, never read since `c62f577`. Savitsky uses the actual trim `τ = clamp(pitch, 1°, 10°)` (`:431`, computed as `−eulerAngles.x` at `:426-428`, which is Unity's sign; Godot uses `pitch_rad` positive = bow up) |
| `lift_smoothing_factor` | 0.08 per fixed step (`AdvancedHullDrag.cs:70`) | - | **0.15 → 0.08** (`:292`) | 0.08 (`PHYSICS_DESIGN.md:568`, `:234`) | drop (fudge) | `lift = lerp(lift, target, 0.08)` each 0.02 s step = first-order lag with time constant ≈ 0.24 s (0.13 s at 0.15). Per-step smoothing hides a force that jumps; with substeps it would change meaning. If a lag is ever needed, express it as a time constant in seconds. |
| `planing_lift_decay` | 0.95/step when `speed < 3 m/s`, 0.9/step when `sub < 0.05`, 0.8/step when `sub > max_planing_submersion` (`AdvancedHullDrag.cs:385-410`) | - | - | - | drop with the smoothing | Same per-step lag, three different rates |
| `planing_ratio_min` | 0.1, hard-coded (`AdvancedHullDrag.cs:377`) | - | - | - | drop | Below 10 % planing ratio the lift was zero |
| `planing_lift_min_speed_ms` | 3, hard-coded (`AdvancedHullDrag.cs:385`) | - | - | - | drop (redundant with `planing_onset_speed_ms` = 4) | |
| `max_planing_submersion` | 0.50 (`AdvancedHullDrag.cs:73`) | - | 0.5 (`:293`) | 50 % (`KNOWN_ISSUES.md:123,129`) | **drop** (fudge, Session 23) | "Cannot plane when more than 50 % submerged". True physics: a hull that deep at speed has a huge wetted area and drag; model that instead. At rest the board is already at 74 %. |
| `heel_lift_floor` | 0.7, hard-coded: `target *= max(cos heel, 0.7)` (`AdvancedHullDrag.cs:460`) | - | - | "45° heel → 70 %" (`:459`) | Savitsky uses `beam · cos(heel)` directly; no floor | |
| `trim_clamp_deg` | 1 to 10, hard-coded (`AdvancedHullDrag.cs:431`) | - | - | (`PHYSICS_VALIDATION.md:317`) | 1 to 10 (Savitsky's validity range, literature) | |
| `planing_lift_point_m` | `(0, 0, 0)` = centre of mass, hard-coded (`AdvancedHullDrag.cs:500`) | - | - | doc still shows the old "0.3 m aft when planing" (`PHYSICS_DESIGN.md:250`) | at the centre of pressure of the wetted planing area (Savitsky), which the hull section derives; plan lists "planing lift at the centre of mass" as a fudge | Set to zero in Session 26 to stop porpoising (`PROGRESS_LOG.md:166`) |
| `lift_min_apply_n` | 1 N, hard-coded (`AdvancedHullDrag.cs:496`) | - | - | - | drop | |

#### Damping (hull in water)

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `vertical_damping_ns_m` | **8000** (`AdvancedBuoyancy.cs:59`) | **800** (`WindsurferSetup.cs:717`) | 800 (`MainScene.unity:254`) | **4000** (`PHYSICS_DESIGN.md:572`, `:131`; `PHYSICS_VALIDATION.md:361`; `PROGRESS_LOG.md:253`); 8000 (`KNOWN_ISSUES.md:104`) | 800 × submersion, re-evaluate in Phase 4 | Linear heave damping `F = −v_y·C·sub` (`:326`). Three sources, three values; the scene (last played) says 800. At 8000, a 0.5 m/s heave gives 4000 N, 4.5 × weight: that is a fudge against the trampoline, not water. |
| `water_viscosity_damping_ns2_m2` | **800** (`AdvancedBuoyancy.cs:62`) | - | **400 → 800** (`:255`) | **400** (`PHYSICS_DESIGN.md:573`, `:132`; `PHYSICS_VALIDATION.md:362`; `PROGRESS_LOG.md:254`); 800 (`KNOWN_ISSUES.md:104`) | 800 × submersion, or replace by `vertical_drag_cd` above (one quadratic vertical term, not two) | Quadratic heave damping `F = −v_y·|v_y|·C·sub` (`:330`). The name is misleading: it is a drag coefficient, not a viscosity. Vertical only (plan pitfall 5). |
| `vertical_damping_cap_n` | 15000 N, hard-coded (`AdvancedBuoyancy.cs:335`) | - | - | - | keep as a safety clamp, assert never hit | |
| `vertical_damping_min_speed_ms` | 0.01, hard-coded (`AdvancedBuoyancy.cs:323`) | - | - | - | drop (no dead zone) | |
| `damping_min_submersion` | 0.05, hard-coded: no damping at all below 5 % (`AdvancedBuoyancy.cs:314`) | - | - | - | drop | Damping should scale continuously with the wetted area |
| `horizontal_damping_ns_m` | 20 (`AdvancedBuoyancy.cs:68`) | 20 (`:719`) | 20 (`:257`) | 20 (`PHYSICS_DESIGN.md:575`) | drop | Lateral only: `F = −|v_lat|·20·2·sub` (`:353-357`) = 40 N·s/m, a third lateral drag next to the hull's lateral `Cd` and the fin. One model for sideways hull drag is enough. |
| `rotational_damping_nms` | 150 (`AdvancedBuoyancy.cs:65`) | 150 (`:718`) | 150 (`:256`) | 150 (`PHYSICS_DESIGN.md:574`, `:133-134`) | 150 with the multipliers below, re-evaluate | Base coefficient, scaled per axis |
| `rotational_damping_pitch_mult` | 4.0, hard-coded, "increased from 2.0" in Session 26 (`AdvancedBuoyancy.cs:376`) | - | - | - | 4.0 → 600 N·m·s/rad | Local X in Unity is the pitch axis; same in Godot |
| `rotational_damping_yaw_mult` | 0.3, hard-coded (`AdvancedBuoyancy.cs:377`) | - | - | "lower (allows turning)" (`PHYSICS_DESIGN.md:135`) | 0.3 → 45 N·m·s/rad | |
| `rotational_damping_roll_mult` | 3.0, hard-coded, "increased from 1.5" in Session 26 (`AdvancedBuoyancy.cs:378`) | - | - | - | 3.0 → 450 N·m·s/rad | Local Z is roll in both engines |
| `rotational_damping_min_factor` | 0.3, hard-coded: `factor = 0.3 + 0.7·sub` (`AdvancedBuoyancy.cs:369-370`) | - | - | - | keep the idea (some water contact always), re-evaluate the number | |
| `hull_angular_damping_base` | 0.8 planing / 1.5 displacement, × `mass × 0.1` (`AdvancedHullDrag.cs:530`, `:543`) | - | - | - | **drop** | A second rotational damper (7.3 to 13.7 N·m·s/rad on all axes) in a different file. One damping model. |
| `hull_angular_damping_high_speed` | `1 + (kt − 15)/5`, capped at 5, above 15 kt (`AdvancedHullDrag.cs:535-539`); doc says `Lerp(1, 5, (kt − 15)/15)` (`PHYSICS_VALIDATION.md:207-211`) | - | - | - | **drop** (plan: fudge "speed-dependent angular damping up to ×5") | Code and doc differ (×5 reached at 35 kt in code, at 30 kt in the doc). Hides missing hydrodynamic damping at speed; Phase 4's stability test decides. |

### SailConfig

#### Geometry and rig

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `area_m2` | 6.5 (`SailConfiguration.Area` `SailingState.cs:372`) | 6.5 (`WindsurferSetup.cs:729`) | 6.5 (`:334`) | **6.0** (`PHYSICS_DESIGN.md:544`; plan says "the legacy config says 6 m²") | 6.5 | The code ran 6.5; a 6.5 freeride sail matches a 120 L board in 15 kt. Team question 3. |
| `luff_length_m` | 4.7 (`SailingState.cs:375`) | 4.7 (`:730`) | 4.7 (`:335`) | - | 4.7 | |
| `boom_length_m` | 2.0 (`SailingState.cs:378`) | 2.0 (`:731`) | 2 (`:336`) | - | 2.0 | Used only by the debug drawing; the physics CE was at the origin |
| `mast_height_m` | 4.6 (`SailingState.cs:381`) | 4.6 (`:732`) | 4.6 (`:337`) | - | 4.6 | Visual only |
| `aspect_ratio` | `luff² / area` = 3.40, derived (`SailingState.cs:402`) | - | - | - | derive | Passed to the lift slope and induced drag |
| `camber` | 0.10 (`SailingState.cs:386`, range 0.05-0.20) | 0.10 (`:733`) | 0.1 (`:338`) | - | 0.10 | Sets the zero-lift angle: `−camber·60° = −6°` (`Aerodynamics.cs:85`) |
| `twist_deg` | 10 (`SailingState.cs:390`) | - | 10 (`:339`) | - | not used | Never read by the physics; the sail deformer (visual) uses its own |
| `mast_foot_m` (Godot) | Unity `(0, 0.1, −0.1)` (`SailingState.cs:394`) = 0.1 m up, 0.1 m **aft** of the board centre | `_mastBasePosition = (0, 0.1, −0.1)` (`WindsurferSetup.cs:46`, written at `:734`) | `(0, 0.1, −0.1)` (`:340`) | wizard help text says the default is "slightly forward of center" (`:117`), which contradicts the sign | Godot `(0, 0.10, +0.10)` is the literal translation; **OPEN**: the sail section should place the mast foot from real geometry (mast track about 1.3 m from the tail of a 2.5 m board = 0.05 m forward of centre = Godot `(0, 0.10, −0.05)`) | The physics never used it (CE forced to zero), so the sign error was invisible |
| `boom_height_m` | 1.4 (`SailingState.cs:397`) | 1.4 (`:735`) | 1.4 (`:341`) | 1.8 (`PHYSICS_DESIGN.md:355`) | 1.4 | `CenterOfEffortHeight = mast_foot.y + 0.5·boom_height` = 0.8 m is defined (`SailingState.cs:408`) but never used |
| `centre_of_effort_m` | `(0, 0, 0)`, hard-coded (`AdvancedSail.cs:287`) | - | - | doc still describes "60 % along the boom at boom height" (`PHYSICS_DESIGN.md:352-357`) | a real CE (about 0.35 × boom length behind the mast, at boom height plus a fraction of the luff), derived in the sail section; plan lists "CE height set to 0" as a fudge | Set to zero in Session 25/26 against porpoising (`KNOWN_ISSUES.md:100`; `PROGRESS_LOG.md:165`). It removes all heeling moment from the sail, which is why the anti-capsize controller and the low COM were needed |
| `mass_rig_kg` | 8 (`HullConfiguration.RigMass` `SailingState.cs:465`); **6** (`BoardMassConfiguration.cs:30`) | 8 (`:769`); 6 (`:781`) | 8 (`:278`); 6 (`:466`) | - | 8 | A 6.5 m² rig (mast, boom, sail, extension) weighs about 8 to 9 kg; 8 keeps the total at 91 kg with the 75 kg sailor |

#### Sheeting, rake and their limits

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `sheet_default` | 0.65 (`AdvancedSail.cs:29`; note the tooltip at `:27` says "0 = sheeted in, 1 = fully eased", the same as the spec's `sheet` **inverted**) | - | 0.65 (`:342`) | - | spec convention: `sheet = 1` is fully in, so the legacy 0.65 becomes `sheet = 0.35` | **Convention conflict**: legacy `_sheetPosition` 0 = in, 1 = out. The spec's shared notation is 0 = out, 1 = in. Every legacy sheet number below is converted: `sheet = 1 − _sheetPosition` |
| `sheet_angle_min_deg` | 12, hard-coded (`AdvancedSail.cs:224`; also `:601`, `:604`, `:636`) | - | - | (`PROGRESS_LOG.md:404` "12°-85°") | 12 | Boom angle from the centreline when fully sheeted in |
| `sheet_angle_max_deg` | 85, hard-coded (`AdvancedSail.cs:225`) | - | - | | 85 | Fully eased. `sheet_angle = lerp(12°, 85°, 1 − sheet)` |
| `sheet_rate_per_s` | 1.5 /s (`AdvancedSail.cs:32`, applied with `MoveTowards` at `:147-148`) | - | 1.5 (`:343`) | - | 1.5 | The sail follows the commanded sheet at most 1.5 units per second (full range in 0.67 s). A second rate limit sits in the controller (`sheet_control_speed`). |
| `auto_trim` | false (`AdvancedSail.cs:35`) | - | 0 (`:344`) | - | false (Phase 4 autopilot does this) | |
| `optimal_aoa_deg` | 17, hard-coded (`AdvancedSail.cs:599`; `Aerodynamics.cs:314`) | - | - | (`AdvancedSail.cs:584` "15-17°") | 17 for the autopilot | Auto-sheet target; clamps the boom angle to 12-85° (`:601`) or 5-85° in the other copy (`Aerodynamics.cs:318`): two copies of the same function with different clamps |
| `rake_default` | 0 (`AdvancedSail.cs:39`) | - | 0 (`:345`) | - | 0 | |
| `max_rake_deg` | 15 (`AdvancedSail.cs:42`) | 15 (`:736`) | 15 (`:346`) | - | 15 | `rake_rad = rake × 15°`; the physics used `rake` (−1..1) directly, only the visual used the angle |
| `rake_rate_per_s` | 3 /s (`AdvancedSail.cs:45`, `:151-152`) | - | 3 (`:347`) | - | 3 | Full range −1 to +1 in 0.67 s |

#### Aerodynamic coefficients (all hard-coded in `Core/Aerodynamics.cs`)

| Godot name | Value | Source | Start with | Why |
|---|---|---|---|---|
| `zero_lift_angle_per_camber_deg` | 60 (zero-lift angle `= −camber × 60°`, so −6° at camber 0.10) | `Aerodynamics.cs:85` | 60 | Thin-airfoil estimate; **doubtful**: the code takes `alpha = abs(aoa)` first (`:79`) and then adds 6°, so a sail at 0° AoA already has lift and the curve is symmetric about 0 with a jump in sign at `|aoa| = 1°` (`:298-299`). The sail section must define a proper signed curve. |
| `lift_slope_factor` | 0.9 on `2π·AR/(AR+2)` | `Aerodynamics.cs:90-91` | 0.9 | Flexible sail and gaps; with AR 3.4 the slope is 3.56 /rad |
| `cl_linear_limit_deg` | 12 | `Aerodynamics.cs:95` | 12 | End of the linear region |
| `cl_transition_end_deg`, `cl_transition_gain` | 18, +0.3 over 6° | `Aerodynamics.cs:100-105` | keep shape | Cl at 18° = slope·(18°)·... note: the linear part is evaluated at 12° **without** the 6° camber offset (`:103`), so the curve has a kink at 12° |
| `cl_stall_end_deg`, `cl_stall_fraction` | 25, 0.85 | `Aerodynamics.cs:107-112` | keep shape | Peak Cl ≈ 1.42 at 18°, 1.21 at 25° |
| `cl_post_stall_end_deg`, `cl_deep_stall` | 45, 0.5 | `Aerodynamics.cs:114-119` | keep shape | Then `0.5·cos(α − 45°)` (`:124`) |
| `cd0` | 0.015 | `Aerodynamics.cs:137` | 0.015 | Parasitic drag of a clean sail |
| `oswald_efficiency` | 0.75 | `Aerodynamics.cs:141` | 0.75 | Induced drag `Cl²/(π·AR·e)` |
| `separation_drag_start_deg`, `_span_deg`, `_gain` | 15, 30, 0.5: `0.5·((α − 15)/30)²` | `Aerodynamics.cs:146-148` | keep | |
| `form_drag_start_deg`, `form_drag_cd` | 45, 1.2·sin α | `Aerodynamics.cs:153-155` | keep | Flat-plate regime |
| `min_apparent_wind_ms` | 0.5: no sail force below it | `Aerodynamics.cs:184`; `AdvancedSail.cs:303` | 0.5 | Avoids normalising a zero vector; also `0.1` for the AWA (`SailingState.cs:345`) |
| `horizontal_wind_threshold` | 0.01 (squared magnitude) | `Aerodynamics.cs:231` | keep | Vertical-wind edge case |
| `lift_sign_deadzone_deg` | 1: lift sign forced positive below 1° AoA | `Aerodynamics.cs:299` | drop (signed curve instead) | |
| `sail_force_vertical` | removed: `force.y = 0` | `AdvancedSail.cs:364` | keep horizontal-only in v1 | The rig is raked; a real sail lifts a little. Re-evaluate in Phase 4 |

#### Sail-side, in-irons and upwind rules (hard-coded in `AdvancedSail.cs`)

| Godot name | Value | Source | Start with | Why |
|---|---|---|---|---|
| `tack_control` | manual: Space flips `_manualTack`; `sail_side = −_manualTack` (`:206`), `+1 = starboard tack`. Old automatic rule `sailSide = −Sign(AWA)` with a 5° hysteresis is only in the doc (`PHYSICS_VALIDATION.md:64-87`) | `AdvancedSail.cs:200-208`, `:549-564` | automatic `sail_side = −sign(awa)` with hysteresis, per the sail section; the plan's D4 says the tack follows the wind | The manual tack let the sail sit on the windward side without consequence |
| `in_irons_awa_deg`, `in_irons_speed_ms` | 20°, 1 m/s (flag only) | `AdvancedSail.cs:316`; the `SailingState` copy says 30° (`SailingState.cs:331`, overwritten) | telemetry only | No physics effect |
| `upwind_penalty_start_deg`, `_zero_deg` | 30°, 10°: `force *= clamp01((|awa| − 10)/20)` below 30° | `AdvancedSail.cs:320-324`; `PROGRESS_LOG.md:406-407` (Session 22, "dead zone 25° → 10°") | **drop** (fudge) | A correct lift/drag curve gives no drive head-to-wind by itself (the drag pushes backwards); this multiplier hides a sail model that made drive at 0° AWA |
| `high_speed_force_reduction` | above 20 kt, `force *= lerp(1, 0.6, (kt − 20)/15)` (not clamped: continues below 0.6 past 35 kt) | `AdvancedSail.cs:369-374` | **drop** (fudge, "prevent nose-diving and flipping") | Also caps the top speed artificially; the plan's open question 1 asks for the real top speed |

#### Pitch stabilisation (hard-coded in `AdvancedSail.cs:396-445`, plan: fudge)

| Godot name | Value | Source | Start with |
|---|---|---|---|
| `pitch_stab_start_kt`, `_full_kt` | 12 kt, +10 kt ramp: `speedFactor = clamp01((kt − 12)/10)` | `:381`, `:427` | drop |
| `pitch_stab_heel_fade_deg` | 15° to 25°, off above 25° | `:406-416`; `KNOWN_ISSUES.md:36` | drop |
| `pitch_stab_damping_nms` | 20 × pitch rate | `:433` | drop |
| `pitch_stab_spring_nm_per_deg` | 4 × pitch angle (degrees) | `:436` | drop |
| `pitch_stab_clamp_nm` | ±300 | `:441` | drop |
| axis | `−transform.right` in Unity | `:444` | not needed |

Why drop: it is a PD controller on pitch that exists because the CE was at zero (no real pitching moment from the sail) and the planing lift acted at the centre of mass (no real restoring moment from the hull). With a real CE and a Savitsky centre of pressure the hull has its own pitch stiffness. Phase 4's "no porpoising" test decides whether anything comes back.

#### Rake steering (hard-coded in `AdvancedSail.cs:450-525`, plan: fudge)

| Godot name | Value | Source | Docs | Start with |
|---|---|---|---|---|
| `rake_force_steering_gain` | `T1 = rake · tack · |F_sail| · 0.3` (N·m per N) | `:506` | 0.5 (`PHYSICS_VALIDATION.md:169`) | drop; the moment comes from the real CE moving fore and aft (`rake_rad × ce_height` lever), see the rake section |
| `rake_direct_torque_nm` | `T2 = rake · tack · 200` (350 when `|awa| < 40°` or `> 140°`) | `:511-519` | plan quotes "150 × rake" | drop for v1; re-add as an explicit "weight-shift steering" term if Phase 4 shows the board cannot be steered at rest |
| `rake_speed_torque_nm` | `T3 = rake · tack · min(v, 8) · 25` | `:522` | - | drop |
| `steering_scale_high_speed` | above 15 kt `lerp(1, 0.5, (kt − 15)/15)`, floor 0.4 | `:499-503` | `Lerp(1, 0.3, (kt − 15)/10)` (`PHYSICS_VALIDATION.md:189-192`; plan: "to 0.3 between 15 and 25 kt") | drop |
| `tack` for steering | `−sail_side` normally; near 0° or 180° AWA falls back to the last sail side, then to `sign(cross(v, v_apparent).y)`, then +1 | `:468-495` | - | not needed once the moment is geometric |
| torque axis | `Vector3.up × (T1 + T2 + T3)`: positive turns the bow right in Unity | `:524` | - | in Godot the same "head up on starboard tack" is a **negative** +Y torque; derive from the CE lever, do not copy the sign |

Together these three terms are the "rake steering base torque and speed term" in the plan's fudge list. With the Unity yaw inertia of about 52 kg·m² (see SailorConfig) a 350 N·m torque gave 6.7 rad/s²; with a realistic yaw inertia of about 10 kg·m² the same number would be far too twitchy. None of these values transfer.

### FinConfig

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `area_m2` | **0.06** (`FinConfiguration.Area` `SailingState.cs:419`, "increased from 0.035 for more lateral grip") | **0.035** (`WindsurferSetup.cs:749`) | 0.035 (`:310`) | 0.04 (`PHYSICS_DESIGN.md:560`); 0.035 (`PhysicsConstants.cs:39`) | 0.035 | A 40 cm freeride fin has about 350 cm². 0.06 m² would be a 60 cm race fin. The scene (last played) ran 0.035. |
| `depth_m` | **0.45** (`SailingState.cs:422`) | **0.40** (`:750`) | 0.4 (`:311`) | 0.40 (`PhysicsConstants.cs:37`) | 0.40 | |
| `chord_m` | 0.10 (`SailingState.cs:425`) | 0.10 (`:751`) | 0.1 (`:312`) | 0.12 (`PhysicsConstants.cs:38`) | 0.10 | Only used for the debug box |
| `aspect_ratio` | `depth² / area` derived (`SailingState.cs:438`): 3.375 with C# defaults, **4.57** with the wizard values | - | - | 4.5 (`PhysicsConstants.cs:40`; `Hydrodynamics.cs:23` default argument) | derive (4.57) | Lift slope `2π·AR/(AR+2)·1.05` = 4.59 /rad |
| `position_m` (Godot) | Unity `(0, −0.1, −0.9)` (`SailingState.cs:429`) = 0.1 m below the board centre, 0.9 m **aft** | same (`:752`) | same (`:313`) | - | Godot `(0, −0.10, +0.90)` | Fin box is at the tail: 0.9 m aft on a 2.5 m board leaves 0.35 m of tail behind the fin root |
| `cop_depth_fraction` | 0.4: force applied `0.4 × depth` below the root, hard-coded (`Board/AdvancedFin.cs:141-142`) | - | - | (`:139-140` says "25 % chord, 40 % depth"; the chord offset is not applied) | 0.4 → Godot `(0, −0.26, +0.90)` | Centre of pressure; produces the fin's heeling moment |
| `stall_angle_deg` | 14 (`SailingState.cs:433`) | 14 (`:753`) | 14 (`:314`) | - | 14 (flag) | Only sets `is_stalled`; the Cl curve stalls by itself at 12° (below). Used by the tracking fudge (×0.3 when stalled, `AdvancedFin.cs:179`) |
| `min_effective_speed_ms` | 0.5 (`AdvancedFin.cs:31`) | - | 0.5 (`:315`) | - | drop | Zero fin force below 0.5 m/s, then a linear "effectiveness" ramp to `full_effect_speed_ms` (`:105-106`) multiplying a force that already grows with v². A fudge that softens low-speed fin grip; not physical |
| `full_effect_speed_ms` | 2.0 (`AdvancedFin.cs:34`) | - | 2 (`:316`) | - | drop | |
| `hydro_min_speed_ms` | 0.3, and 0.1 for the horizontal part, hard-coded (`Hydrodynamics.cs:110`, `:125`) | - | - | - | 0.1 (one threshold) | Avoids normalising zero |
| `tau_nonelliptic` | 0.05 (`Hydrodynamics.cs:31`) | - | - | - | 0.05 | Lifting-line correction |
| `cl_linear_limit_deg` | 8 | `Hydrodynamics.cs:38` | 8 | keep shape | Cl at 8° = 0.64 |
| `cl_transition_end_deg`, `_gain` | 12, +0.15 | `:43-48` | keep | Peak Cl ≈ 0.79 at 12° |
| `cl_stall_end_deg`, `_fraction` | 16, 0.7 | `:50-55` | keep | 0.55 at 16° |
| `cl_post_stall_end_deg`, `cl_deep_stall`, `cl_floor` | 25, 0.4, min 0.1 with `cos(2(α − 25°))` | `:57-69` | keep | |
| `cd0` | 0.008 (`Hydrodynamics.cs:82`) | - | - | - | 0.008 | NACA 0012-ish |
| `oswald_efficiency` | 0.85 (`Hydrodynamics.cs:85`) | - | - | `KNOWN_ISSUES.md:96` (Session 25 quadratic fix, in the legacy `FinPhysics.cs`) | 0.85 | |
| `viscous_drag_factor` | 0.5: `Cd0·|Cl|·0.5` (`Hydrodynamics.cs:90`) | - | - | - | 0.5 | Tiny |
| `tracking_enabled` | true (`AdvancedFin.cs:37`) | true (`:754`) | 1 (`:317`) | - | **false / drop** (fudge) | "Fin helps the board go straight": a yaw torque `angle_error × strength × speedFactor × stallFactor × effectiveness`, clamped ±300 N·m (`AdvancedFin.cs:155-187`). The real fin already does this through its lift at 0.9 m aft of the centre (weathercock stability). The plan does not list it, but it is one. |
| `tracking_strength_nm_per_deg` | **40** (`AdvancedFin.cs:40`) | **15** (`:755`) | 15 (`:318`) | 2 for the old `FinPhysics` (`SCENE_CONFIGURATION.md:167`, history) | drop | Last played at 15 |
| `tracking_clamp_nm`, `tracking_stall_factor` | 300, 0.3 (`AdvancedFin.cs:184`, `:179`) | - | - | - | drop | |
| `leeway_sign` | `SignedAngle(finForward, velocity, up)` (`Hydrodynamics.cs:136`): positive when the board slides to **starboard** in Unity's left-handed frame; lift = `−finRight × sign(leeway)` (`:151`) | - | - | - | derive in D4: `leeway_rad = atan2(v_local.x, −v_local.z)`, positive = sliding to starboard; lift toward −X | Unity's `SignedAngle` about +Y is clockwise-positive from above; Godot's `signed_angle_to` is counter-clockwise-positive. Do not copy. |

### SailorConfig

#### Mass, centre of mass and inertia

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `mass_sailor_kg` | 75 (`HullConfiguration.SailorMass` `SailingState.cs:468`); **80** (`BoardMassConfiguration.cs:33`) | 75 (`:770`); 80 (`:782`) | 75 (`:279`); 80 (`:467`) | 75 (`PHYSICS_DESIGN.md:556`; `PhysicsConstants.cs:49`) | 75 | Two components, two sailors. The rigid body ran with 80 (see Simulation group). Plan question 3 says 75. |
| `com_height_m` | 0.9 (`BoardMassConfiguration.cs:40`), used as `0.5 × 0.9` = 0.45 m for the sailor's COM and `1.2 × 0.9` = 1.08 m for the rig's (`:117-120`) | - | 0.9 (`:469`) | - | sailor COM 0.90 m above the deck (a standing adult's COM is at about 55 % of height = 0.95 m); the legacy 0.45 m is a crouch | The 0.5 factor makes the sailor's COM sit at knee height, which is half the real heeling lever |
| `com_override_m` (Godot) | Unity `(0, 0.15, −0.1)` (`BoardMassConfiguration.cs:37`); it replaces the computed weighted COM whenever it is not zero (`:127-131`) | - | `(0, 0.15, −0.1)` (`:468`) | "baseCOM = (0, 0.4, 0)" (`PHYSICS_DESIGN.md:421`) | **no override**: compute the COM from the three masses | The computed value with the legacy formula is `(0, 0.457, −0.013)` Unity for masses 8/6/80. The override at 0.15 m is a stability fudge (a lower COM heels less). Godot start: sailor 75 kg at `(0, 0.90, 0)`, rig 8 kg at `(0, 1.08, +0.20)` Godot (0.2 m aft, `:117`), board 8 kg at `(0, 0.06, 0)` → composite COM ≈ `(0, 0.84, +0.018)` Godot. The mass section decides. |
| `planing_com_shift_aft_m` | 0.15 (`BoardMassConfiguration.cs:64`), applied as `z −= 0.15 × planing_ratio` in Unity (aft) (`:222`) | - | 0.15 (`:476`) | **0.3** (`PHYSICS_DESIGN.md:557`, `:424`; `PROGRESS_LOG.md:451`) | 0.15 aft (Godot `+z`) | Sailor steps back into the straps when planing |
| `planing_com_drop_m` | 0.1, hard-coded: `y −= 0.1 × planing_ratio` (`BoardMassConfiguration.cs:225`) | - | - | (`PHYSICS_DESIGN.md:425`) | 0.1 | Crouches in the straps |
| `dynamic_com` | true (`BoardMassConfiguration.cs:61`) | true (`:787`) | 1 (`:475`) | - | true | |
| `use_custom_inertia` | false (`BoardMassConfiguration.cs:54`) | false (`:786`) | 0 (`:473`) | "Disabled custom inertia" (`KNOWN_ISSUES.md:193`) | not applicable: Godot always computes its own | With `false`, Unity computed the tensor from the **BoxCollider** (0.6 × 0.12 × 2.5 m) and mass 94 kg: pitch (X) 49.1, yaw (Y) 51.8, **roll (Z) 2.9** kg·m². The roll inertia of a 0.12 m thick slab ignores the 80 kg sailor standing on it; this is why roll needed 450 N·m·s/rad of damping and an anti-capsize controller. |
| custom tensor (unused) | board slab + sailor cylinder (r 0.2 m, h 1.7 m, `:156-157`) at 0.45 m + rig point mass at 1.08 m: (43.5, 6.2, 47.1) kg·m² for (X, Y, Z) with masses 8/6/80 and length 2.4 (`:141-181`) | - | `_inertiaMultiplier (1,1,1)` (`:474`) | - | compute the same way in Godot from the config masses and positions, with the sailor's COM at 0.90 m: roll ≈ 0.25 + 18.8 + 75·0.9² + 8·1.08² ≈ 88, pitch ≈ 4.2 + 18.8 + 60.8 + 9.7 ≈ 93, yaw ≈ 4.4 + 1.5 + 0.3 ≈ 6 kg·m² | Note the code comment (`:146`) says yaw is the highest; the formula gives yaw the lowest, because sailor and rig sit on the yaw axis. That is physically right for a windsurfer (a long light board, heavy sailor at the centre). The inertia section gives the final numbers; these are hand-computed starting points, not measurements. |
| `sailor_torso_radius_m`, `sailor_height_m` | 0.2, 1.7 (`BoardMassConfiguration.cs:156-157`) | - | - | - | 0.2, 1.75 | Cylinder model for the sailor's own inertia |
| `rig_yaw_radius_m` | 0.3 (`BoardMassConfiguration.cs:172`) | - | - | - | 0.3 | Rig inertia about the mast |

#### Weight shift and anti-capsize (controller-driven torques on the body)

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `max_weight_shift_deg` | 20 (`Player/AdvancedWindsurferController.cs:49`) | - | 20 (`:375`) | - | 20 as the range of the `weight_shift` control (−1..1 → ±20°), if the sailor section models the sailor's lean as a COM offset | The legacy "weight shift" never moved any mass; it only produced a yaw torque |
| `weight_shift_rate` | 4 × 20 = 80 °/s (`:52`, `:240`) | - | 4 (`:376`) | - | 4 /s of full range | |
| `weight_shift_torque_nm` | 30 × `clamp01(v/3)` at full shift (`:55`, `:260-261`) | - | 30 (`:377`) | - | **drop** (fudge) | |
| `base_steering_torque_nm` | 80 at full shift, "works even at zero speed", hard-coded (`:257`, `:264`); Session 22 (`PROGRESS_LOG.md:405`) | - | - | 80 N·m (`PROGRESS_LOG.md:405`) | **drop** (fudge); re-add as an explicit weight-shift model only if Phase 4 shows the board cannot be turned at rest | With the tack inversion (`:158-159`) this torque is the reason A/D "work on both tacks"; in Godot the sign of every +Y torque flips (positive = turn to port) |
| `weight_shift_dead_zone_deg` | 0.5 (`:250`) | - | - | - | drop | |
| `anti_capsize` | true (`:59`) | true (`:799`) | 1 (`:378`) | "antiCapsize" (`scene_config.json:124`, old) | **drop** for the sim (fudge); the sailor's righting moment must come from a real COM offset (hiking / harness) in the sailor section | A PD roll controller: `T = heel_deg × 50 × 0.5 × clamp01(|heel|/45)` beyond a 5° dead zone (`:287-296`), plus `T = (|heel| − 45) × 50 × 2` past 45° (`:299-306`), both about the board's forward axis |
| `max_heel_deg` | 45 (`:62`) | - | 45 (`:379`) | - | drop | |
| `anticapsize_strength` | 50 N·m per degree, ×0.5 soft, ×2 hard (`:65`, `:292`, `:303`) | - | 50 (`:380`) | - | drop | At 20° heel: 20 × 50 × 0.5 × 0.44 = 222 N·m; at 60° heel: 15 × 100 = 1500 N·m extra |
| heel angle used | `SignedAngle(up, projected board up, forward)` (`:280-282`): Unity sign | - | - | - | `heel_rad` positive = to starboard (D4), from the basis vectors | Sign flips between engines; derive |

### WaterConfig

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `rho_water` | 1025 (`PhysicsConstants.cs:13`) | - | - | 1025 (`PHYSICS_DESIGN.md:539`) | 1025 | |
| `base_height_m` | 0, taken from the transform at Awake (`Water/WaterSurface.cs:188`, `:237`) | water object at y = 0 (`WindsurferSetup.cs:399`) | 0 (`:643`) | - | 0 | Water level is world y = 0 |
| `waves_enabled` | true (`WaterSurface.cs:192`) | - | **0 → 1** (`:644`; Session 27 turned waves on, `PROGRESS_LOG.md:106`, `:127`) | "Waves now on by default, re-validate" (`PROGRESS_LOG.md:33`) | false until Phase 5 | Every validated Unity run was on flat water |
| `align_waves_to_wind` | true (`WaterSurface.cs:195`): base travel direction = `wind_from + 180°` (`:280`) | - | 1 (`:645`) | - | true (Phase 5) | Waves travel downwind |
| `wave[i].direction_offset_deg` | 12, −28, 40, −55 (`WaterSurface.cs:407-410`; single-wave default 0 at `GerstnerWave.cs:23`) | - | same (`:647-662`) | - | same (Phase 5) | Offsets from the downwind direction, 0 = North, 90 = East |
| `wave[i].wavelength_m` | 14, 7, 3.5, 1.8 (`:407-410`; default 10) | - | same | - | same | Deep-water speed `c = √(g/k)`, `k = 2π/λ` (`GerstnerWave.cs:48-51`), min λ 0.5 m |
| `wave[i].amplitude_m` | 0.10, 0.06, 0.03, 0.012 (`:407-410`; default 0.1) | - | same | "~0.2 m total" (`PROGRESS_LOG.md:106`) | same | Sum 0.202 m |
| `wave[i].steepness` | 0.20, 0.20, 0.15, 0.15 (`:407-410`; default 0.25) | - | same | "sum 0.7" (`WaterSurface.cs:401`) | same | Horizontal displacement `steepness/k`; the sum over waves must stay below 1 (`:252-256`) |
| `max_waves` | 4 (`GerstnerWave.cs:63`) | - | - | - | 4 (shader limit carried over; make it a constant) | |
| `height_query_iterations` | 3 fixed-point iterations to undo the horizontal displacement (`GerstnerWave.cs:66`, `:112-125`) | - | - | - | 3 | |
| `normal_sample_delta_m` | 0.1 (`WaterSurface.cs:216`) | - | - | - | 0.1 or an analytic normal (wave section) | Finite-difference normal; Unity's `Cross(tangentZ, tangentX)` gives +Y in the left-handed frame, so the Godot cross product order must be re-derived |
| legacy sine wave fields | `_waveHeight 0.5, _waveLength 10, _waveSpeed 1, _waveDirection 0` in the Session 26 scene (`git show b5ed2ea`, removed in Session 27) and `scene_config.json:176-179` | - | - | - | none | History only |
| `water_velocity` | not modelled (buoyancy uses the surface normal only, `AdvancedBuoyancy.cs:255-256`) | - | - | - | flat water: zero; Phase 5 decides | The plan's `WaterSurface` interface has a water velocity query |

### WindConfig

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `speed_kn` (stored as `speed_ms`) | 15 kt = 7.72 m/s (`Environment/WindSystem.cs:26`) | **12 kt** (`WindsurferSetup.cs:62`, written at `:536-538`) but **never applied** before Session 27 because the wizard wrote a field name that does not exist (`PROGRESS_LOG.md:119`; the Session 22 wizard even converted it to m/s, `git diff 5a1857a 757d5cf`) | **22 → 15** (`:822`) | 15 kt (`ARCHITECTURE.md:548`; the plan's targets assume 15 kt) | 15 kt = 7.717 m/s | The Session 24-26 tests ran in 22 kt (inspector edit). The validation targets (28 km/h "in 15 kt", `README.md:215`) were therefore probably measured in 22 kt. **OPEN** for the targets table. |
| `from_bearing_deg` | 270 (from the West) (`WindSystem.cs:22`) | 45 (`:63`), never applied | 270 (`:821`) | "0 = North, 90 = East" (`WindSystem.cs:20`) | 270 | Same compass numbers in Godot; the vector conversion differs (wind section) |
| `gusts_enabled` | true (`WindSystem.cs:30`) | - | 1 (`:823`) | - | false in tests, true in the game | Validation needs steady wind |
| `gust_intensity` | 0.2 (`WindSystem.cs:34`, range 0-0.5) | - | 0.2 (`:824`) | - | 0.2 | `speed × (1 + gust × 0.2)`, gust in about ±1 |
| `gust_period_s` | 8 (`WindSystem.cs:37`) | - | 8 (`:825`) | - | 8 | |
| `gust_harmonics` | sines with weights 0.6, 0.3, 0.1 at 1×, 2.3×, 5.7× the base phase (`WindSystem.cs:119-121`) | - | - | - | same | Deterministic, not random; the phase advanced with `Time.deltaTime` in `Update()` (frame time, `:116`), so it was frame-rate dependent. Godot: advance with the sim's `dt`. |
| `shifts_enabled` | false (`WindSystem.cs:40`) | - | 0 (`:826`) | - | false | |
| `max_shift_deg` | 15 (`WindSystem.cs:44`) | - | 15 (`:827`) | - | 15 | `sin(φ)·15 + sin(0.37φ)·4.5` (`:133-134`), so up to 19.5° |
| `shift_period_s` | 60 (`WindSystem.cs:47`) | - | 60 (`:828`) | - | 60 | |
| `height_gradient_enabled` | true (`WindSystem.cs:51`) | - | 1 (`:829`) | - | **false** in v1 | See the next two rows |
| `reference_height_m` | 1 (`WindSystem.cs:54`) | - | 1 (`:830`) | - | if ever enabled: 10 m, the standard height for a reported wind | |
| `shear_exponent` | 0.14 (`WindSystem.cs:58`, range 0.05-0.4) | - | 0.14 (`:831`) | - | 0.14 (open water, literature) | **Doubtful as run**: the profile `(y/1 m)^0.14` was evaluated at the **board origin** (`AdvancedSail.cs:163` passes `transform.position`), only when `y > 0.1 m` (`WindSystem.cs:152`). So the sail saw 100 % of the wind while the board origin was below 10 cm, and 72 % the moment it rose above it (0.1^0.14 = 0.72), 91 % at 0.5 m. A hidden 28 % wind cut that switched on as the board rose. Godot: sample at the CE height or not at all. |
| `min_sample_height_m` | 0.1 (`WindSystem.cs:152`, `:155`) | - | - | - | drop | |

### Controller group (`ControlConfig`)

| Godot name | C# default | Wizard | Scene | Docs | Start with | Why |
|---|---|---|---|---|---|---|
| `sheet_control_speed_per_s` | 0.8 (`AdvancedWindsurferController.cs:29`, `:220`) | - | 0.8 (`:369`) | - | 0.8 | Holding W or S moves the sheet target by 0.8 per second (full range in 1.25 s); the sail then follows at `sheet_rate_per_s` |
| `sheet_key_sign` | W = `−1` = sheet in, S = `+1` = ease (`:147-150`), in the legacy 0-in/1-out convention | - | - | - | W = sheet in = `sheet` **increases** in the spec convention | Same feel, inverted number |
| `auto_sheet` | false (`:32`); toggled with T (`:185-189`) | - | 0 (`:370`) | true in the old V2 controller (`scene_config.json:123`) | false; Phase 4's autopilot replaces it | |
| `auto_sheet_speed_per_s` | 0.3 (`:35`, `:215`) | - | 0.3 (`:371`) | - | 0.3 for the autopilot's sheet rate | |
| `rake_control_speed_per_s` | 2 (`:39`, `:228`) | - | 2 (`:372`) | - | 2 | A/D or Q/E move rake at 2 per second (−1 to +1 in 1 s) |
| `auto_center_rake` | true (`:42`) | true (`:800`) | 1 (`:373`) | - | true | Rake returns to 0 when no key is held |
| `rake_center_speed_per_s` | 1 (`:45`, `:234`) | - | 1 (`:374`) | - | 1 | |
| `input_smoothing_per_s` | 8 (`:68`), applied with `MoveTowards` in `Update()` using `Time.deltaTime` (`:197-200`) | - | 8 (`:381`) | - | 8, applied in the physics tick with `dt` | Frame-rate dependent in Unity |
| `steer_inverts_on_port_tack` | `steerDirection = −1` when `!IsStarboardTack` (`:158-159`); Session 26 (`PROGRESS_LOG.md:147-158`) | - | - | - | **not needed**: with rake defined as head-up-on-both-tacks (D4), "D turns right" means `rake = +1` on starboard tack and `rake = −1` on port tack, which is exactly this inversion expressed as a rule, not a patch | The inversion existed because the legacy rake torque used `tack` as a sign; D4's rake convention absorbs it |
| `rake_dead_zone` | 0.1 (`:226`) | - | - | - | 0.1 | Below it the auto-centre runs |
| keys | A/D and arrows steer, W/S and arrows sheet, Q/E rake, Space tack, T auto-sheet (`:143-189`) | - | - | wizard dialog (`WindsurferSetup.cs:278-282`) | same map; Space becomes unnecessary with automatic tacking | |
| control modes | one mode only (the three-mode V2 controller is legacy, `scene_config.json:117`) | - | - | plan question 4 | team decides | |

Everything the controller applied as a torque (base steering 80 N·m, weight-shift torque 30 N·m, anti-capsize) is listed under SailorConfig because that is where the physics that should replace it lives.

### Where the force acts

Not applicable to this section; each model's section gives its application point. For reference, the legacy application points, all converted to Godot: sail force at `(0, 0, 0)` (fudge), fin force at `(0, −0.26, +0.90)`, hull resistance at `(0, 0, +0.25)`, hydrodynamic lift at `(0, 0, 0)` (fudge), buoyancy at each of the 21 sample points on the hull bottom (`y = −0.06 + rocker`), damping forces at the centre of mass (`AddForce`), all steering and stabiliser torques as pure torques.

### Signs and the Unity-to-Godot translation

Covered in "How to read the tables". The value-specific sign facts are: positions `z → −z` (mast foot, fin, COM shift, resistance point); `+Y` torque means "turn right" in Unity and "turn to port" in Godot; Unity `SignedAngle(a, b, up)` is clockwise-positive from above, Godot `signed_angle_to` is counter-clockwise-positive, and the spec uses `atan2(x, −z)` for wind angles and leeway instead of either; Unity Euler angles for heel and pitch carry engine-specific signs and are replaced by basis-vector formulas; the legacy `_sheetPosition` runs 0 = in to 1 = out, the spec's `sheet` runs 0 = out to 1 = in.

### Stabilisers and fudges in this model

This section only lists them (with the numbers); the reasoning is in each model's section. Everything marked **drop** in the tables is one of these. The complete list, with the session that added it and the plan's default:

| Fudge | Numbers | Added | Symptom it hid | Recommendation |
|---|---|---|---|---|
| Rigidbody angular damping | 0.3 /s | wizard, Session 20-22 | general wobble | drop |
| Rake steering torques | 0.3 × force, 200/350 N·m direct, 25 × min(v, 8) | Sessions 7, 17, 22 | no real CE, so no real steering moment | drop; derive from the CE lever |
| High-speed steering scale-down | to 0.5 (floor 0.4) between 15 and 30 kt; doc says 0.3 by 25 kt | Session 14-16 | twitchy at speed with I_yaw ≈ 52 kg·m² | drop |
| High-speed sail force reduction | to 0.6 between 20 and 35 kt | Session 14-16 | nose-diving, flipping | drop |
| Pitch stabilisation | 20 N·m·s/rad, 4 N·m/deg, ±300 N·m, above 12 kt, off above 25° heel | Session 14-16, reworked 26 | porpoising with CE at zero and lift at the COM | drop |
| Speed-dependent angular damping | ×(1 + (kt − 15)/5) to ×5 | Session 18 (commit `4c45223`) | oscillation at planing speed | drop |
| Hull angular damping | 0.8 / 1.5 × mass × 0.1 | Session 13 | | drop (one damping model) |
| Planing lift cap | 1.0 now, 0.4 played, 0.85 documented | Session 22-25 | "flying out" | drop; Savitsky is self-limiting |
| Displacement lift cap | 0.3 of weight | Session 22-24 | board sits 74 % deep at rest (Archimedes) | re-evaluate the whole displacement-lift term |
| Planing off above 50 % submersion | 0.5, decay 0.8/step | Session 23 | submarine mode | drop |
| Submersion drag multiplier | 12 (3 played) squared in excess over 0.35 | Session 23-24 | board did not slow down under water | drop |
| Underwater drag bonus | up to ×5 above 0.5 submersion and 4 m/s | Session 23 | same | drop |
| Ride-high drag bonus | −17 % max | Session 23 | | drop |
| Submersion vertical damping | 600 N·s/m, ×2 | Session 24 | bobbing | drop (duplicate) |
| Vertical damping | 800 played, 4000 documented, 8000 in code | Sessions 22, 24, 25 | trampoline | keep 800 + quadratic, re-evaluate |
| Lift smoothing | 0.08/step (0.15 played) | Session 24 | lift jumps | drop |
| Fin effectiveness ramp | 0.5 to 2.0 m/s | Session 13 | | drop |
| Fin tracking torque | 15 played, 40 in code, ±300 | Session 6 | spinning | drop |
| Upwind force penalty | zero at 10° AWA, full at 30° | Session 12, softened 22 | drive head to wind | drop |
| Centre of effort at zero | (0, 0, 0) | Session 25-26 | porpoising, heeling | drop; real CE |
| Planing lift at the centre of mass | (0, 0, 0) | Session 26 | porpoising | drop; Savitsky centre of pressure |
| Low COM override | (0, 0.15, −0.1) Unity | Session 22 | capsizing | drop; composite COM |
| Sailor COM at half height | 0.45 m | Session 22 | | use 0.90 m |
| Base steering torque | 80 N·m at zero speed | Session 22 | cannot turn at rest | drop, re-evaluate |
| Weight-shift torque | 30 N·m × clamp(v/3) | Session 12 | | drop |
| Anti-capsize | 25 N·m/deg soft, 100 N·m/deg past 45° | Session 8-12 | capsizing (roll inertia 2.9 kg·m²) | drop; real sailor righting moment |
| Sail downforce | 25 % of sail force above 35 km/h (`Board/Sail.cs:55`, `:58`, disabled at `:230-233`) | Session 24, removed 26 | flying out | stays removed |
| Height-gradient wind at the board origin | 0.72 to 0.91 of the wind | Session 13 | (not noticed) | off in v1 |

### What Phase 2 must implement

- [ ] Equipment values (board dimensions and mass, sail luff and boom, fin area and depth, the three masses) come from section 14; the bullets below list the legacy-faithful values for every other field.
- [ ] `Game/config/SimConfig` (or project settings): `substeps_per_tick = 4`, `gravity_ms2 = 9.81`, `max_angular_speed_rad_s = 50` as an assert-only guard, no sleeping, no engine damping.
- [ ] `BoardConfig.tres`: 2.50 × 0.60 × 0.12 m, 0.120 m³, 8 kg, rocker 0.08 / 0.02 m, 7 × 3 samples, width taper 0.3, volume taper 0.4; hull drag: ITTC friction with `Re ≥ 1e5`, wetted area 1.36 m² at rest, waterline 2.0 m, residuary `0.001·Fn⁴(1 + 5Fn)`, spray 0.01; planing onset 4.0 m/s, full 6.0 m/s, wetted-area ratio 0.20; lateral `Cd` 1.0 over 0.30 m², vertical `Cd` 1.2 over 0.75 m²; resistance point 0.25 m aft; damping 800 N·s/m linear and 800 N·s²/m² quadratic on heave (or the vertical `Cd`, not both) scaled by submersion; rotational 150 × (4.0 pitch, 0.3 yaw, 3.0 roll) × (0.3 + 0.7·submersion). No submersion multipliers, no lift caps, no smoothing, no per-step decays.
- [ ] `SailConfig.tres`: 6.5 m², luff 4.7, boom 2.0, mast 4.6, camber 0.10, rig 8 kg, mast foot and CE from the sail section, sheet angles 12° to 85°, sheet rate 1.5 /s, rake rate 3 /s, max rake 15°, aerodynamic constants as tabled (Cd0 0.015, e 0.75, slope factor 0.9, curve breakpoints 12/18/25/45°). No upwind penalty, no high-speed reduction, no pitch stabiliser, no rake torque constants.
- [ ] `FinConfig.tres`: 0.035 m², depth 0.40, chord 0.10, AR derived, position (0, −0.10, +0.90) with the centre of pressure 0.4 × depth lower, stall flag 14°, Cd0 0.008, e 0.85, τ 0.05, curve breakpoints 8/12/16/25°. No effectiveness ramp, no tracking torque.
- [ ] `SailorConfig.tres`: 75 kg, COM 0.90 m above the deck, planing shift 0.15 m aft and 0.10 m down, cylinder r 0.2 m and h 1.75 m for inertia, weight-shift range ±20° (as a COM offset, per the sailor section). No anti-capsize, no steering torques.
- [ ] `WaterConfig.tres`: ρ 1025, ν 1.19e-6, level 0, waves off with the four Session 27 wave components stored for Phase 5.
- [ ] `WindConfig.tres`: 15 kt from 270°, gusts (0.2, 8 s, harmonics 0.6/0.3/0.1 at 1/2.3/5.7) off in tests, shifts off (15°, 60 s), height gradient off (0.14, reference 10 m if enabled).
- [ ] `ControlConfig.tres`: sheet 0.8 /s, rake 2 /s, auto-centre 1 /s, input smoothing 8 /s, rake dead zone 0.1, in the spec's sheet convention (1 = in).
- [ ] One mass: `total_mass_kg = board + rig + sailor = 91`, computed, never typed twice.
- [ ] Inertia computed from the composite (board box + sailor cylinder + rig point mass), never from a bounding box of the board alone.
- [ ] Every `.tres` field has a comment with its unit and the row of this table it came from, so Phase 4 can log changes against it.
- [ ] `Documentation/PHYSICS_SPEC.md` gets a "Tuning log" subsection under this section where Phase 4 records each change (old value, new value, test that motivated it).

### Tests Phase 2 should write

- Loading each `.tres` gives the "Start with" values above (a smoke test that also catches a mistyped unit; for example `BoardConfig.volume_m3 == 0.120`, `SailConfig.area_m2 == 6.5`, `FinConfig.position_m == Vector3(0, -0.10, 0.90)`).
- Derived values: `total_mass_kg == 91.0`; sail `aspect_ratio` ≈ 3.398 (4.7²/6.5); fin `aspect_ratio` ≈ 4.571 (0.40²/0.035); hull `wetted_area_m2` ≈ 1.36 and `waterline_length_m == 2.0` if those formulas are kept.
- Buoyancy sampling: the 21 sample volumes sum to `volume_m3` (±1e-6); the nose sample sits 0.08 m higher than the centre sample and the tail sample 0.02 m higher.
- Archimedes at rest: submerged volume = 91 / 1025 = 0.0888 m³ = 74 % of 0.120 m³ (±2 %), pitch and roll level (plan Phase 2 test).
- Unit helpers: `15 kt → 7.717 m/s`, `4.0 m/s → 14.4 km/h`, `6.0 m/s → 21.6 km/h`.
- Inertia: for the composite with sailor COM at 0.90 m, roll and pitch inertia are both larger than yaw inertia, and all three are larger than the board-only slab values (roll ≫ 0.25 kg·m²).
- Wind vector: `WindConfig` 15 kt from 270° gives `v_wind_true = (+7.717, 0, 0)` in Godot (blowing toward East), so `wind_from` is `(−1, 0, 0)`; from 0° (North) gives `v_wind_true = (0, 0, +7.717)`.
- Sheet convention: `sheet = 1` → boom 12° from the centreline; `sheet = 0` → 85°; `sheet = 0.35` → 37.55° (the legacy default 0.65).
- No fudge constant appears in the sim: a test that greps `Game/sim/` for the literal numbers 12.0 (submersion multiplier), 350.0, 200.0, 8000.0 would be silly; instead each model's test asserts the physical behaviour the fudge used to fake (the model sections list them).

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/Scripts/`):
- `Physics/Core/PhysicsConstants.cs:12-50`
- `Physics/Core/Aerodynamics.cs:77-125` (Cl), `:132-158` (Cd), `:184`, `:231`, `:298-299`, `:308-321`
- `Physics/Core/Hydrodynamics.cs:23-72` (fin Cl), `:78-93` (fin Cd), `:110-158` (fin forces), `:164-222` (hull resistance), `:227-240` (unused wave resistance)
- `Physics/Core/SailingState.cs:331-333`, `:345-355`, `:372-397` (SailConfiguration), `:402`, `:408`, `:419-438` (FinConfiguration), `:449-483` (HullConfiguration)
- `Physics/Board/AdvancedSail.cs:29-45`, `:147-152`, `:178`, `:200-208`, `:224-226`, `:287`, `:303-324`, `:330`, `:348`, `:364-374`, `:381`, `:396-445`, `:450-525`, `:549-564`, `:586-607`, `:633-637`
- `Physics/Board/AdvancedFin.cs:31-44`, `:93-106`, `:123`, `:141-142`, `:155-187`, `:193-202`
- `Physics/Board/AdvancedHullDrag.cs:31-73`, `:166-200`, `:220-270`, `:283-316`, `:335-356`, `:377-473`, `:487-507`, `:518`, `:530-543`
- `Physics/Board/BoardMassConfiguration.cs:24-64`, `:110-131`, `:141-181`, `:191-201`, `:222-228`
- `Physics/Board/ApparentWindCalculator.cs` (legacy component, no tuning values used by the Advanced stack; `:413` no-go angle 35° for a UI check)
- `Physics/Board/Sail.cs:55`, `:58`, `:230-233` (removed downforce)
- `Physics/Buoyancy/AdvancedBuoyancy.cs:33-68`, `:110`, `:161-203`, `:244-283`, `:314-384`
- `Physics/Water/GerstnerWave.cs:23-35`, `:48-54`, `:63-66`, `:77-135`
- `Physics/Water/WaterSurface.cs:188-198`, `:216`, `:237`, `:252-256`, `:280`, `:334-364`, `:403-411`
- `Environment/WindSystem.cs:22-58`, `:99-100`, `:110-138`, `:147-182`
- `Player/AdvancedWindsurferController.cs:29-68`, `:143-189`, `:195-243`, `:248-306`
- `Editor/WindsurferSetup.cs:46`, `:62-63`, `:117`, `:278-282`, `:399`, `:536-542`, `:689-701`, `:706-801`, `:1290-1291`

Legacy scene and settings:
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity:214-232` (Rigidbody), `:246-257` (AdvancedBuoyancy), `:272-293` (AdvancedHullDrag), `:309-318` (AdvancedFin), `:333-347` (AdvancedSail), `:369-381` (controller), `:464-476` (BoardMassConfiguration), `:497` (collider), `:643-663` (WaterSurface), `:821-831` (WindSystem)
- Earlier scene versions from git: `git show 5a1857a:WindsurfingGame/Assets/Scenes/MainScene.unity` (Session 22) and `git show b5ed2ea:WindsurfingGame/Assets/Scenes/MainScene.unity` lines 602-620, 634-681, 698-706, 722-735, 757-769, 852-864, 972-982 (Session 26); regeneration in commit `dfbc3a0` (2 Jan 2026); default changes in commits `fa79027` (Session 24), `c62f577` (Session 25 WIP), `b5ed2ea` (Session 26)
- `Legacy/WindsurfingGame/ProjectSettings/DynamicsManager.asset:7`, `:10`, `:12-13`, `:36`; `TimeManager.asset:6-7`; `ProjectVersion.txt` (Unity 6000.3.2f1)

Legacy docs:
- `Legacy/Documentation/PHYSICS_DESIGN.md:89`, `:118-135`, `:179-196`, `:204-234`, `:250`, `:352-357`, `:391-392`, `:421-425`, `:512`, `:533-580`
- `Legacy/Documentation/PHYSICS_VALIDATION.md:64-87`, `:169`, `:189-192`, `:207-211`, `:314-329`, `:361-364`, `:386`
- `Legacy/Documentation/PROGRESS_LOG.md:33`, `:103-127`, `:147-175`, `:251-258`, `:360`, `:388`, `:404-407`, `:441-451`
- `Legacy/Documentation/KNOWN_ISSUES.md:36`, `:96-104`, `:123-129`, `:193`
- `Legacy/Documentation/ARCHITECTURE.md:24`, `:417-418`, `:548-549`; `QUICK_SETUP_CHECKLIST.md:49`; `SCENE_CONFIGURATION.md:33-36`, `:167`; `README.md:214-216`
- `Legacy/Documentation/scene_config.json` (2025-12-27, old components, history only)

Literature referenced by the legacy code and used for the "Start with" judgements: ITTC 1957 friction line; Savitsky, D. (1964) "Hydrodynamic Design of Planing Hulls", Marine Technology 1(1); Larsson and Eliasson, "Principles of Yacht Design"; Marchaj, C.A., "Sail Performance"; Finch, M., "Effective Water Simulation from Physical Models", GPU Gems ch. 1 (Gerstner waves); the 0.14 power-law shear exponent for open water and the 10 m reference height are standard meteorological practice.

---

## 12. Stabilisers and fudges in the legacy code

### Purpose

The Unity version worked, but only with a collection of artificial terms bolted on: torques that do not come from any force, caps and multipliers that fire at chosen thresholds, dampers that were raised until a symptom went away. The plan calls these stabilisers and fudges, and its rule is simple: **start Phase 2 without them, and add one back only when a Phase 4 test shows it is needed, with a note saying why.**

This section is the register. Every fudge has an identifier (`F-01` and so on) so that config comments, test names and the tuning log (section 16) can refer to it in two characters. For each one the register says what it is, what the legacy build actually ran (which is often not what the legacy docs say, see section 11), why it was added, what it probably hid, what the rebuild does instead, which section owns the decision, and which test decides whether it ever comes back.

Rule of thumb used throughout: physics that is merely *simplified* (a linear lift curve, a box inertia) is not a fudge. A term that exists to suppress a symptom, or that has no physical mechanism behind it, is.

### Inputs and outputs

None. This is a register, not a model.

### 12.1 The plan's list, one by one

The plan's Phase 1 task names nine items "known" from the legacy docs. Several of the numbers in that list come from documentation that no longer matched the code. The corrected facts are below; the recommendations follow the plan's default.

| ID | Plan's description | What the last played code actually did | Why it was added | What it hid | Rebuild | Owner | Test that decides |
|---|---|---|---|---|---|---|---|
| F-01 | Rake steering base torque (150 × rake) and the speed term | Three yaw couples, all × rake × tack × a high-speed scale: `0.3 × |F_sail|`, a direct `200 N·m` (`350` when AWA < 40° or > 140°), and `25 × min(speed, 8)` N·m (AdvancedSail.cs:506-524). The "150" is the Session 17 value (PROGRESS_LOG.md:1558); the plan copied it from there. At full rake and 5 m/s the sum is about 440 N·m, four to five times the physical lever (section 3.3). | Sessions 7, 12, 16, 17, 22: the board "couldn't point upwind", then "no steering when the sail is unpowered" | The centre of effort never moved with rake (it was lowered to 0.3 m in Session 16 and zeroed in Session 25), so the real steering lever did not exist | **Drop.** Rake moves the real centre of effort (section 2.13); the yaw moment comes out of `r × F` (section 3.2). Steering from rest only works with a filled sail, which is real. | 3 | Steady turn rate at full rake on a beam reach in 15 kt, both tacks (estimate 21°/s); tack within 4 s from a beam reach |
| F-02 | High-speed steering scale-down (to 0.3 between 15 and 25 kt) | `lerp(1, 0.5, (kt − 15)/15)` with a floor of 0.4 that is never reached: 0.5 at 30 kt (AdvancedSail.cs:498-503). The 0.3 / 25 kt figures are PHYSICS_VALIDATION.md:189-192, an older version. | Session 18 "high-speed stability" | F-01 was far too strong and had no natural limit; the physical lever is limited by the fin | **Drop** with F-01. | 3 | Same as F-01, plus the high-speed stability test |
| F-03 | Speed-dependent angular damping (up to × 5) | Three separate rotational dampers: hull `−ω × (0.8 or 1.5) × (1 + (kt − 15)/5, max 5) × mass × 0.1` (7 to 36 N·m·s/rad, AdvancedHullDrag.cs:524-545); Unity's Rigidbody `angularDamping = 0.3` (3 s time constant, WindsurferSetup.cs:691); buoyancy `150 × (4.0 pitch, 0.3 yaw, 3.0 roll) × (0.3 + 0.7 × submersion)` N·m·s/rad (AdvancedBuoyancy.cs:369-379). The docs' `lerp(1, 5, …)` ramp is not what the code does. | Sessions 18, 24, 26: "violent oscillations at planing speeds", porpoising | Over-strong steering couples (F-01), the wrong lift application point (F-08), a roll inertia ten times too small (F-21) | **Drop** the hull and Rigidbody dampers. **Re-evaluate** the buoyancy rotational damping: section 6.9 gets pitch and roll damping from per-point vertical damping with physical coefficients; no yaw term (the fin does that). | 3, 6 | High-speed stability: pitch peak-to-peak < 2°, heave < 0.05 m above 20 kt |
| F-04 | Pitch stabilisation that fades out with heel | A spring-damper about the starboard axis above 12 kt: `20 × pitch_rate + 4 × pitch_deg`, clamped ± 300 N·m, fading from 15° to 25° of heel, off above (AdvancedSail.cs:396-445). It read the *world* X angular velocity and applied the torque about the *body* X axis, so it was wrong on every heading except North and South; the "spasming at high heel" of Session 26 (KNOWN_ISSUES.md:30-46) was that bug. | Session 22 (porpoising), Session 26 (heel fade) | Planing lift at the wrong point (F-08), centre of effort at zero (F-07), no hydrostatic pitch stiffness check | **Drop.** The hull's own pitch stiffness is about 5 100 N·m/rad (section 6.7), 34 times the spring. | 3 | No porpoising test (section 14) |
| F-05 | Planing lift capped at 85 % and displacement lift capped at 30 % of weight | Displacement lift: `0.12 × q × 1.2 m²`, capped at 30 % of weight, which the cap reaches at 1.9 m/s, so it was a constant 268 N from 7 km/h to planing onset (AdvancedHullDrag.cs:327-357). Planing lift: the docs' 0.85 was the Session 24 default; the code says 1.0; **the scene that was played had `_maxLiftFraction 0.4` and `_planingLiftCoefficient 0.15`, so the planing lift was at most 6 % of the weight** (sections 11, 13). The lift itself was a speed ramp, not Savitsky (F-26). | Session 22 ("board sinks 75 %+", KNOWN_ISSUES.md:190), Session 24 ("flies out at 45+ km/h") | Displacement lift fought Archimedes (a 120 L board with 92 kg on it floats 75 % under, section 6.6, plan pitfall 8). The cap hid that the lift model had no equilibrium of its own. | **Drop** the displacement lift (section 5 F11). **Keep one hard cap at exactly 1.0 × weight** on the Savitsky lift (section 5 F15): a stand-in for the wetted-length shrink we do not model, not a tuning knob. | 5 | Rest submersion = mass ÷ 1025 within 2 %; no flying off at 45 km/h |
| F-06 | Submersion penalties: planing off above 50 % submersion, underwater drag up to × 5, the 12× submersion drag multiplier | `R × (1 + 12 × excess²)` above 35 % submersion (`12` in code and docs, **`3` in the played scene**); a further `× (1 + (sub − 0.5) × 2 × clamp((v − 4)/4) × 5)` above 50 % and 4 m/s; planing lift decayed by 0.8 per tick above 50 %; a ride-high drag reduction below 35 % (AdvancedHullDrag.cs:214-251, :405-412). The "progressive penalty from 35 to 50 %" in KNOWN_ISSUES.md:124 **never existed in any commit**. | Sessions 22 to 24: "submarine mode" on a beam reach | The wetted area did not grow with depth, so a submerged board had almost no extra drag | **Drop** all of them. Section 5 F8 lets the friction area grow to the fully wet hull and adds form drag on the frontal area once the deck goes under: about 2 200 N at 8 m/s, which stops a submerged board for a physical reason. | 5 | Nose-dive recovery: from fully submerged at 8 m/s, speed < 2 m/s within 3 s, back to rest submersion within 8 s |
| F-07 | Centre of effort height set to 0 | Not only the height: the whole centre of effort was `Vector3.zero`, the board origin, since Session 26 (AdvancedSail.cs:283-291). History: 0.8 m (Session 13), 0.3 m and 0.1 m to the side (16), 0.0 m height with 35 % of the boom sideways (25), origin (26). With the force at the origin the sail produced no heeling moment, no weather helm and no geometric rake steering, which is why F-01, F-04 and F-22 were needed. | Session 16 "wild rotations", Sessions 25 and 26 porpoising | No sailor model to carry the heeling moment; the pitch problems of F-08 | **Drop.** Section 2.13 puts the centre of effort on the rig (0.40 × luff up, 0.35 × boom aft). Phase 2 default (Option A): apply the force at the real horizontal position but at deck height, so yaw is exact and heel is left to Phase 4. Option B (full height) together with the sailor's righting moment (section 7.5) is a Phase 4 experiment. | 2, 3, 7 | Weather helm and rake steering tests (section 3); heel balance test in Phase 4 |
| F-08 | Planing lift applied at the centre of mass | Applied at the **board origin** (0, 0, 0), which is 0.10 to 0.25 m ahead of the real centre of mass (section 7), so it gave a small bow-up moment. Sessions 22 to 24 applied it 0.6 to 1.25 m **forward** of the origin because of a sign slip in Unity's +Z (section 5 F15): a 400 to 800 N·m bow-up couple, the most likely cause of the Session 24 porpoising. Session 26's comment that the earlier point was "aft" is wrong. | Session 26 (porpoising) | The sign slip, and the missing trim feedback | **Keep as the Phase 2 default** (zero moment, simplest) with `planing_lift_point_z_m` in the config so Phase 4 can move the lift to the Savitsky centre of pressure, about 0.6 m aft of the centre at 8 m/s (section 5, "Where the force acts"). | 5 | No porpoising test; trim at speed between 2° and 6° bow up |
| F-09 | High-speed sail downforce (added Session 24, removed Session 26) | Written into the old `Sail.cs`, which was **not in the scene** after Session 13, so it never acted on the played board (section 2, S2.7). The flying-out it was meant to cure was handled by the planing-lift cap. | Session 24 | Nothing; dead code | **Stays removed.** A raked rig's vertical force is small and, if anything, upward. | 2 | None needed |

### 12.2 Found in addition

| ID | What | Where (last played code) | Why it was added | What it hid | Rebuild | Owner |
|---|---|---|---|---|---|---|
| F-10 | Upwind force penalty: sail force × `clamp((abs(AWA) − 10°)/20°, 0, 1)` below 30° AWA | AdvancedSail.cs:319-324 (Session 12 as a hard 25° cut-off, softened in 22) | "No-go zone" | The sail model had no luffing rule: an unsigned angle of attack and a 12° minimum boom angle gave lift with the wind 15° off the bow | **Drop.** Luffing on the signed angle of attack (section 2.9); the no-go zone must come out of the force balance | 2 |
| F-11 | High-speed sail force reduction to 60 % between 20 and 35 kt | AdvancedSail.cs:366-374 (Session 22) | "Nose-diving and flipping" | F-07 and F-08; after Session 26 it only capped the top speed | **Drop.** If the top speed is wrong, fix the hull drag | 2 |
| F-12 | Manual tack: the Space key sets the sail side; the wind is not consulted; the sail can sit to windward | AdvancedSail.cs:200-208, :549-554 (Session 22; the docs describe the older `−sign(AWA)` rule) | Not logged; probably the sail flapping at the wrong moment with the old 5° hysteresis | Made "steering inverted on port tack" a controller problem (patched in Session 26) and let a backwinded sail keep producing force | **Re-evaluate.** Physics: `sail_side = −sign(awa)` with 5° hysteresis at 0° and 180° (section 2.14); Space becomes a control action. Arcade flip or steered tack is open question Q5 (section 15) | 2, 10 |
| F-13 | Two steps in the sail lift curve: `cl` drops 33 % at 12° and 29 % at 25° | Aerodynamics.cs:42-72 (camber offset missing in two branches) | Not deliberate; a bug since Session 13 | The validated tuning compensated for a sail 33 % weaker than intended between 12° and 25° | **Fix** (continuous curve, section 2.7). Expect more sail force; retune in Phase 4 | 2 |
| F-14 | Fin lift applied perpendicular to the board axis instead of the flow, which hid 26 N of extra drag at 8 m/s (more than the fin's whole computed drag) | Hydrodynamics.cs:151 | Simplification | Induced drag counted twice; the fin was 2.3 times draggier than its coefficients say | **Fix** (lift perpendicular to the flow, section 4.7). Expect higher speeds | 4 |
| F-15 | Fin curve step of 19 % at 16° | Hydrodynamics.cs:60 | Bug | Possible jitter | **Fix** (section 4.4) | 4 |
| F-16 | Fin tracking torque: a yaw spring toward the velocity, 15 N·m/deg played (40 in code), clamped ± 300 N·m | AdvancedFin.cs:155-187 | Session 6 "the board should follow its velocity", raised in Session 18 | The fin's own lift at 0.9 m aft already does this (five times stronger); the missing angular-velocity term meant no natural yaw damping | **Drop.** Feed the board's angular velocity into the fin's flow (section 4.2) | 4 |
| F-17 | Fin force fade-in from 0.5 to 2.0 m/s, plus three internal speed thresholds | AdvancedFin.cs:93-106; Hydrodynamics.cs:110, :125 | "Minimum speed for significant lift" | Noisy slip angles at tiny velocities | **Drop**; one 0.05 m/s numerical guard (section 4.8) | 4 |
| F-18 | Weight-shift yaw couple: 80 N·m at any speed plus 30 N·m above 3 m/s, from the A/D keys, with a port-tack sign bug that made it fight the rake | AdvancedWindsurferController.cs:248-270 | Session 22 "control at zero speed" | No rail or weight steering model; F-01 had no authority with an unpowered sail | **Drop.** The lean becomes a real sideways shift of the sailor's mass (sections 7.5, 10). Steering a stationary board is not a real capability | 7, 10 |
| F-19 | Anti-capsize roll couple: `0.556 × heel² N·m` above 5°, plus 100 N·m per degree beyond 45° (up to 3 000 N·m) | AdvancedWindsurferController.cs:276-307 | Sessions 13 and 22 | No sailor righting moment; with F-07 the sail could not heel the board anyway, so it fought buoyancy and a pitch leak in the heel formula | **Drop.** Sailor righting moment from the lean (section 7.5); a documented "auto-hike" assist in beginner mode if Phase 3 needs it (section 10) | 7, 10 |
| F-20 | Centre of mass overridden to (0, 0.15, +0.10): 0.15 m above the board centre for a body that is 80 % standing sailor | BoardMassConfiguration.cs:37, :127-131 | Session 22 | That there was no balance model; a low centre of mass heels less | **Drop.** Composite centre of mass from the parts, about 0.96 m up (section 7.3) | 7 |
| F-21 | Inertia tensor from the 0.6 × 0.12 × 2.5 m box collider: roll 2.9 kg·m², yaw 52 kg·m² | `_useCustomInertia = false` (BoardMassConfiguration.cs:54) | Session 22 disabled the custom tensor because the board "turned too easily" | Every steering and damping number was tuned against a yaw inertia eight times too large and a roll inertia fifteen times too small | **Replace** with the composite tensor (section 7.6): pitch about 50, yaw about 6, roll about 46 kg·m² for the default configuration | 7 |
| F-22 | Unity Rigidbody angular damping 0.3 /s (an exponential decay of angular velocity) | WindsurferSetup.cs:691 | Wizard default | Nothing specific; a hidden engine term | **Drop.** Our integrator has no such term | 7 |
| F-23 | Vertical damping raised 800 → 4000 → 8000 N·s/m in the code and docs while **the scene stayed at 800** | AdvancedBuoyancy.cs:59 vs MainScene.unity:254 | Sessions 24 and 25 against the trampoline | The trampoline came from lift tied to submersion (plan pitfall 4); the played build never had the higher values | **Keep** a linear heave term at 800 N·s/m (damping ratio about 0.3) plus the quadratic 800 N·s²/m² (flat-plate physics), applied per sample point (section 6.9) | 6 |
| F-24 | Second and third vertical dampers: hull "submersion vertical damping" 600 N·s/m (× 2 when deep and planing) and a vertical "drag" of `1.2 × ½ρ × speed × |v_y| × 0.75 m²` | AdvancedHullDrag.cs:253-270, :305-315 | Sessions 13 to 24 | Four dampers on one motion in two files, tuned blind against each other | **Drop** both; one heave damping model in section 6 | 5, 6 |
| F-25 | Lateral damping `40 × |v_x|` in buoyancy and a mixed-form lateral drag `½ρ × speed × |v_x| × 0.30 m²` in the hull (8 to 16 times a flat plate) | AdvancedBuoyancy.cs:344-359; AdvancedHullDrag.cs:291-302 | Sessions 13 to 22 | Hid part of the fin's job and made the fin's tuning wrong | **Replace** with one quadratic lateral drag (section 5 F10); drop the buoyancy term | 5, 6 |
| F-26 | "Savitsky" planing lift replaced by a weight-fraction ramp: `weight × max_lift_fraction × planing_ratio × max(cos heel, 0.7) × coefficient` | AdvancedHullDrag.cs:442-473 (commit c62f577, 1 January 2026); the Savitsky code existed only in the Session 24 commit | "Savitsky equations are too complex and produce insufficient lift" | The pitch stabiliser (F-04) held the trim near 0°, where Savitsky lift is tiny: one fudge broke the physics and a second replaced it | **Do not implement.** Section 5 F13 specifies the Savitsky lift with the real trim | 5 |
| F-27 | Per-tick smoothing of the planing lift (`lerp(prev, target, 0.08)`, 0.15 in the played scene) and three per-tick decays (0.95, 0.9, 0.8) | AdvancedHullDrag.cs:385-412, :472 | Sessions 22 to 24 | Lift jumps and the trampoline; frame-rate dependent | **Replace** by a time-based filter (τ = 0.2 s) or nothing (section 5 F15) | 5 |
| F-28 | Resistance cliff and double reduction: wetted area × 0.20 (0.35 played) and again × 0.15 inside the friction formula; a "hump" factor that never acted; resistance dropping by a factor of 7 in one tick when `is_planing` flipped at 5 m/s | AdvancedHullDrag.cs:198-200; Hydrodynamics.cs:199-218 | Session 22 "make planing let go" | Planing drag was never modelled as `lift × tan(trim)` plus friction | **Replace** with the continuous blend of section 5 F7 (friction on `λ b²`, pressure drag, spray, residuary faded by `planing_ratio`) | 5 |
| F-29 | Speed-based `planing_ratio` (0 at 4 m/s, 1 at 6 m/s) instead of a Froude or force criterion | AdvancedHullDrag.cs:181-195 | Session 22 (Froude-based planing started at 8 km/h) | Nothing; it is a simplification | **Keep** as a model input for the Savitsky wetted-length interpolation (section 5 F4); planing onset is *measured* as the speed where dynamic lift carries half the weight (section 14) | 5 |
| F-30 | Wind sampled at the board origin, with the height gradient skipped below 0.1 m and jumping to 0.72 just above it | AdvancedSail.cs:163; WindSystem.cs:152-158 | Session 13 design | The sail saw 72 to 100 % of the configured wind depending on how high the hull floated: less wind when planing | **Drop.** Sample at the centre of effort; continuous floor (sections 1, 8) | 1, 8 |
| F-31 | Apparent wind speed taken in 3D (heave included) while the force's vertical part was discarded | SailingState.cs:101; AdvancedSail.cs:363-364 | Not a decision | A few percent of force jitter on every wave | **Use the horizontal apparent wind** (section 1, Formula 3) | 1 |
| F-32 | Dead bands, gates and caps: ± 15 000 N vertical cap, 0.01 and 0.1 m/s thresholds, the 5 % submersion damping gate, the 1 N and 0.1 N application thresholds | AdvancedBuoyancy.cs:314, :323, :335; AdvancedHullDrag.cs:496; AdvancedFin.cs:135 | Numerical caution | Nothing; small discontinuities | **Drop** all but the division-by-zero guards (sections 4.8, 6, 5 F1) | 4, 5, 6 |
| F-33 | Buoyancy reduced by up to 30 % while planing | Removed in Session 25 (AdvancedBuoyancy.cs:294-297 comment) | Session 22 | Lift added on top of full buoyancy | **Stays removed.** Buoyancy is Archimedes | 6 |
| F-34 | Controller start-up: the controller's sheet started at "fully in" and overrode the sail's 0.65 within half a second; the auto-sheet clamp of 5° is below the 12° boom minimum | AdvancedWindsurferController.cs:80, :223; Aerodynamics.cs:265 | Bugs | Nothing | **Fix** (section 10) | 10 |
| F-35 | Two total masses at once: 94 kg on the body, 91 kg in every weight-based cap | BoardMassConfiguration.cs:110, :191 vs SailingState.cs:231 | Two components written at different times | A 3 % error in every cap, and nobody noticed | **One mass** from one config (sections 7, 14) | 7 |
| F-36 | Gerstner details: a fixed 3-iteration height solve (3 mm error), two different approximate normals on CPU and GPU, steepness 3 to 4.5 times the physical value, wave directions re-aligned to the shifting wind every frame | GerstnerWave.cs:66; WaterSurface.cs:94-103, :188-197; OceanWater.shader:157-161 | Session 27, never run | Nothing yet | **Replace** in Phase 5 as section 9 specifies (tolerance solve, exact normal, directions from the base wind) | 9 |

### 12.3 Lessons, so Phase 2 and 4 do not repeat them

1. **Lift must not depend on how deep the hull sits.** Positive feedback between submersion and lift made the trampoline (plan pitfall 4). Drag may depend on submersion (it is negative feedback); lift may use it only as an on/off gate.
2. **Apply forces at their real points and let the integrator find the torque.** Half the stabilisers (F-01, F-04, F-16, F-18, F-19) replaced torques that a correctly placed force produces for free, and the other half (F-02, F-03) damped the excess those replacements created.
3. **One number, one place.** Mass (F-35), vertical damping (F-23, F-24), lateral drag (F-25) and the planing coefficients each existed in two or three copies, and the copies drifted apart. In Godot each value lives in exactly one `.tres` file, and every section reads it from there.
4. **Check what actually ran before trusting a tuning note.** The documented "validated" values (0.85 cap, 4000 damping, Savitsky) were never in the played scene (sections 11 and 13). Any comparison of the rebuild with "how Unity felt" must use the Session 26 scene values, not the docs.
5. **Three-quarters submerged at rest is Archimedes, not a bug** (plan pitfall 8). The displacement lift (F-05) and the low centre of mass (F-20) were both answers to correct behaviour.
6. **Inertia matters as much as the forces.** With a roll inertia of 2.9 kg·m² (F-21) any sideways force flipped the board instantly, and the anti-capsize controller (F-19) was the answer. With the sailor's mass where it belongs, roll is 15 times harder and most of that controller's job disappears.
7. **Viscous damping belongs on vertical motion only** (plan pitfall 5). Applied horizontally it killed forward speed in Session 24. Horizontal resistance comes from the hull drag and the fin, which have real areas and coefficients.
8. **Fudges hide each other.** F-04 broke Savitsky, F-26 replaced it, F-05 capped it, F-08 moved it, F-03 damped the result. Removing one at a time inside the legacy tuning would have made things worse; removing them all and rebuilding from the forces is the only clean path, which is why Phase 4 re-tunes from scratch instead of carrying legacy numbers over.

### What Phase 2 must implement

- [ ] Nothing from this register goes into `Game/sim/`. Where a legacy fudge would have gone, the config comment or the code comment names the register ID (for example `# No submersion drag multiplier, see PHYSICS_SPEC F-06`) so nobody re-adds it by reflex.
- [ ] The items marked **Fix** (F-13, F-14, F-15, F-34) are implemented in their fixed form from the start; the items marked **Keep** (F-23 as 800 + 800, F-29, the hard cap in F-05) are implemented as the owning section describes.
- [ ] When Phase 4 brings a fudge back, it gets a row in the tuning log (section 16) with the ID, the test that failed without it and the value chosen.

### Tests Phase 2 should write

- **No hidden couples.** With all forces disabled except gravity, the torque about the centre of mass is exactly zero for any rake, lean and sail-side input.
- **No hidden dampers.** With buoyancy and heave damping disabled in a test configuration, a board given a vertical velocity keeps it; with them enabled, a drop from 0.5 m settles within two visible oscillations (section 6).
- **No submersion feedback on lift.** Planing lift at 8 m/s and 4° trim is bit-identical at 10 %, 30 % and 45 % submersion (section 5 F12).
- **One mass.** `total_mass_kg` read from any model equals the sum of the three configured masses.
- Each owning section lists the behavioural tests that replace the fudge; this section adds no others.

### Sources

- The owning sections of this document: 1 to 10 (per-model "Stabilisers and fudges" subsections), 11 (the values and their four legacy sources) and 13 (the contradictions, including the git history of `MainScene.unity`).
- Legacy code (under `Legacy/WindsurfingGame/Assets/Scripts/`): `Physics/Board/AdvancedSail.cs:163, 200-208, 283-291, 319-324, 363-374, 396-445, 450-525, 549-554`; `Physics/Board/AdvancedHullDrag.cs:181-200, 214-270, 291-315, 327-357, 385-412, 442-473, 496-500, 524-545`; `Physics/Board/AdvancedFin.cs:93-106, 135, 155-187`; `Physics/Core/Hydrodynamics.cs:60, 110, 125, 151, 199-218`; `Physics/Core/Aerodynamics.cs:42-72, 265`; `Physics/Board/BoardMassConfiguration.cs:37, 54, 110, 127-131, 191`; `Physics/Buoyancy/AdvancedBuoyancy.cs:59-68, 294-297, 314-384`; `Physics/Core/SailingState.cs:101, 231`; `Environment/WindSystem.cs:152-158`; `Player/AdvancedWindsurferController.cs:80, 223, 248-307`; `Physics/Board/Sail.cs:230-233`; `Physics/Water/GerstnerWave.cs:66`, `WaterSurface.cs:94-103, 188-197`; `Editor/WindsurferSetup.cs:691`.
- Legacy scene history: `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` today and at commit `b5ed2ea` (Session 26, the last played state), see section 11.
- Legacy documents: `Legacy/Documentation/KNOWN_ISSUES.md:30-46, 81-133, 177-193`; `PHYSICS_VALIDATION.md:160-212, 335-341`; `PROGRESS_LOG.md` Sessions 12 to 26 (in particular 215-275 and 337-452) and 1548-1561.
- `Documentation/REBUILD_PLAN.md`, Phase 1 task "List every stabiliser or fudge" and "Known legacy pitfalls" 3 to 8.

---

## 13. Legacy contradictions and their resolution

### Purpose

The Unity version left behind three kinds of sources that do not always agree: the C# code, the editor setup wizard, and the documentation. This section goes through every place where they contradict each other, shows the evidence with file and line numbers, and writes down the answer the rebuild adopts and why. The point is that Phase 2 never has to open `Legacy/` to settle an argument: the answer is here.

Two things to know before reading:

1. **A fourth source exists, and it is the one Unity actually ran.** The task brief assumed that `MainScene.unity` holds no component values. That is not true: the scene stores every serialized inspector value of every component on the Windsurfer object, and in Unity a value saved in the scene overrides the C# field default. So the "last validated Unity build" (Session 26, commit `b5ed2ea`, 2 January 2026, the last session that was actually played) ran with the numbers in the scene file at that commit, not with the C# defaults and not with the numbers in the docs. Where the scene disagrees with the code, this section says so. (Evidence: `git show b5ed2ea:WindsurfingGame/Assets/Scenes/MainScene.unity` lines 602-730 and 846-866; the same object in `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` today at lines 207-340 and 455-480, after the unverified Session 27 edits.)
2. **Session 27 changed physics numbers in the scene without playing them.** The Session 27 commit (`757d5cf`) hand-edited the scene and, besides adding waves and visual components, changed `_waterViscosity` 400 to 800, `_planingWettedAreaRatio` 0.35 to 0.2, `_submersionDragMultiplier` 3 to 12, `_planingLiftCoefficient` 0.15 to 1, `_maxLiftFraction` 0.4 to 1, `_liftSmoothingFactor` 0.15 to 0.08 and turned waves on (`git diff b5ed2ea 757d5cf -- WindsurfingGame/Assets/Scenes/MainScene.unity`). None of that was compiled or played (`Legacy/Documentation/PROGRESS_LOG.md:103`). This section treats the Session 26 scene as the last validated configuration and the Session 27 scene as history only.

Notation follows the shared notation of this spec (`rho_air`, `rho_water`, `g`, `v_boat`, `v_wind_true`, `v_apparent`, `twa_rad`, `awa_rad`, `sail_side`, `sheet`, `rake`, `heel_rad`, `pitch_rad`, `yaw_rate`). Where a legacy field uses a different convention it is converted and the conversion is written out.

### How the evidence was weighed

For every number there are up to four legacy sources. This is the order of trust used below, and the reason:

| Rank | Source | Why |
|---|---|---|
| 1 | The scene file at the last played commit (`b5ed2ea`, Session 26) | It is what the Unity engine loaded. Serialized scene values override C# defaults. |
| 2 | The C# field defaults at that commit | Used only for fields that the scene did not store (Unity then falls back to the C# default). |
| 3 | `WindsurferSetup.cs` (the wizard) | It wrote the scene object once, in Session 22 (`5a1857a`). Fields it does not set fell back to the C# defaults of that day. Later wizard edits never re-ran on the saved scene (the scene still holds Session 22 values such as `_maxLiftFraction: 0.4`). |
| 4 | The docs (`PHYSICS_DESIGN.md`, `PHYSICS_VALIDATION.md`, `KNOWN_ISSUES.md`, `PROGRESS_LOG.md`, `README.md`) | Written by hand at different sessions and rarely updated afterwards. Several describe code that was later replaced (for example the Savitsky lift, see 13.3.3). |

`Legacy/Documentation/scene_config.json` (27 December 2025) and `SCENE_CONFIGURATION.md` describe the old non-Advanced components (`Sail`, `FinPhysics`, `WaterDrag`) and are cited only as history.

### 13.1 The nine known pitfalls from the rebuild plan

#### P1. The sign tables in the legacy docs are wrong (AWA, sail side, rake)

**Contradiction.**
- `Legacy/Documentation/PHYSICS_VALIDATION.md:43-50` says AWA is positive when the wind comes from port. The code comment at `Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs:112` says "positive when wind is from right (starboard)".
- `PHYSICS_VALIDATION.md:63-70` (and `COMPONENT_DEPENDENCIES.md:107-118`) says AWA > 0 means wind from port and the sail goes to starboard.
- `PHYSICS_VALIDATION.md:297-298` (testing checklist) says "Rake back = bear away" and "Rake forward = head up". `COMPONENT_DEPENDENCIES.md:150-151` says "Rake back + starboard tack → turn left (bear away)". `PROGRESS_LOG.md:79` and `ARCHITECTURE.md:22` say `tack = sailSide`. The code at `AdvancedSail.cs:474` and `:494` uses `tack = -sailSide`, and its comment at `:454-455` says rake back = head up. `PHYSICS_VALIDATION.md:166-181` and `PROGRESS_LOG.md:311-316` agree with the code.

**Derivation in D4, not trust.** Take a board heading North (bow = world -Z) at rest, and 8 m/s of wind from the East (bearing 090°). The wind is on the sailor's right, so by definition it comes from starboard.

Godot (D4):
```
from_world      = (sin(90°), 0, -cos(90°)) = (1, 0, 0)        # unit vector pointing to where the wind comes FROM
v_wind_true     = -8 * from_world = (-8, 0, 0)                 # the air moves West
v_apparent      = v_wind_true - v_boat = (-8, 0, 0)            # board at rest
from_local      = -v_apparent / |v_apparent| = (1, 0, 0)       # board frame = world frame here
awa_rad         = atan2(from_local.x, -from_local.z) = atan2(1, 0) = +pi/2   # +90°: wind from starboard  (correct)
sail_side       = -sign(awa_rad) = -1                          # boom on the port side, i.e. starboard tack
```
With Godot's `signed_angle_to` instead: `Vector3.FORWARD.signed_angle_to(Vector3(1,0,0), Vector3.UP)` = angle × sign(cross(FORWARD, RIGHT)·UP); cross((0,0,-1),(1,0,0)) = (0·0-(-1)·0, (-1)·1-0·0, 0·0-0·1) = (0, -1, 0), dot UP = -1, so the result is **-90°**. That is why D4 forbids `signed_angle_to` for wind angles (`Game/tests/unit/test_engine_conventions.gd:25-38` pins this).

Unity, same situation: `Vector3.SignedAngle((0,0,1), (1,0,0), up)`; Unity computes sign(Dot(axis, Cross(from, to))) with Cross((0,0,1),(1,0,0)) = (0·0-1·0, 1·1-0·0, 0·0-0·1) = (0, 1, 0), dot up = +1, so **+90°**: wind from starboard is positive in the Unity code too. The code comment is right; the doc table is wrong.

Rake: the physics. Raking the mast back moves the sail's centre of effort aft of the fin (the centre of lateral resistance). The sail force points mostly to leeward. A leeward push applied behind the pivot swings the tail to leeward and the bow to windward: the board heads up. That is true on both tacks because "leeward" and "aft" both flip together. In Godot numbers, starboard tack (wind from +X, leeward = -X), CE 0.3 m aft of the CLR (aft = +Z): r = (0, 0, +0.3), F = (-500, 0, 0) N gives torque r × F = (0·0-0.3·0, 0.3·(-500)-0·0, 0·0-0·(-500)) = (0, -150, 0) N·m. A negative torque about +Y turns the bow from -Z toward +X, that is to starboard, toward the wind. Head up. Port tack mirrors it: torque +150 N·m, bow to port, toward the wind. So the rule "rake back = head up, on both tacks" follows from the geometry, and it is what the code does (`AdvancedSail.cs:454-455, 506, 519, 522`).

**Resolution.** D4 as written in the plan: AWA and TWA positive = wind from starboard, `atan2(from_local.x, -from_local.z)`; `sail_side = -sign(awa_rad)` (boom to port on starboard tack); rake back heads up on both tacks. In Godot the yaw torque from rake is `torque_y = -rake * sign(awa_rad) * K` (K > 0, the gain defined in the rake-steering section), because a positive torque about +Y turns the bow to port in Godot. The legacy `AddTorque(Vector3.up * rake * tack * ...)` with `tack = sign(AWA)` turned the bow to starboard for positive values, so the sign of the yaw torque flips in the translation; the behaviour does not.

**Reason.** Derived above from the geometry; the code, its comments, `PHYSICS_VALIDATION.md:166-181`, and the Session 19 fix note (`PROGRESS_LOG.md:559-572`) agree; only the tables and checklist written by hand disagree.

Also found while checking P1: the legacy **TWA has the opposite sign of the legacy AWA.** `AdvancedSail.cs:182` computes `SignedAngle(-twHorizontal, fwdHorizontal, up)` (from wind-from to forward) while `SailingState.cs:113` computes `SignedAngle(fwdHorizontal, -awHorizontal, up)` (from forward to wind-from). Swapping the arguments negates the result, so in the legacy HUD (`AdvancedTelemetryHUD.cs:190`) TWA was positive for wind from port and AWA positive for wind from starboard. The fallback at `SailingState.cs:117` (`ApparentWindAngle = TrueWindAngle` when apparent wind < 0.1 m/s) therefore flipped the AWA sign for that one case. Resolution: the spec computes `twa_rad` and `awa_rad` with the same `atan2` formula, from `-v_wind_true` and `-v_apparent` respectively; a test checks that both are +90° for the North/East example above.

#### P2. Unity is left-handed with +Z forward; Godot is right-handed with -Z forward

**Contradiction.** Not a doc-versus-code contradiction but a translation trap: vector formulas copied from `Legacy/` come out mirrored.

**Evidence and derivation.** The rotation matrices are numerically the same in both engines (a positive rotation about +Y takes +Z to +X in both; a positive rotation about +Z takes +X to +Y in both). What differs is which axis is the bow. Consequences, each with numbers:

| Quantity | Unity (bow = +Z) | Godot (bow = -Z) | Flips? |
|---|---|---|---|
| Yaw: positive rotation/torque about +Y | turns the bow to starboard (right): R_y(+90°)·(0,0,1) = (1,0,0) | turns the bow to port (left): R_y(+90°)·(0,0,-1) = (-1,0,0) | **yes** |
| Pitch: positive rotation about +X | bow down: R_x(+90°)·(0,0,1) = (0,-1,0). The code negated it: `_currentTrimAngle = -pitchAngle` (`AdvancedHullDrag.cs:426-428`) | bow up: R_x(+90°)·(0,0,-1) = (0,+1,0). So `pitch_rad` (positive = bow up) is the rotation about local +X with **no** negation | **yes** |
| Roll: positive rotation about +Z | mast top to -X = port: R_z(+90°)·(0,1,0) = (-1,0,0) | same, mast top to port | no, but D4's `heel_rad` (positive = starboard) is the rotation about `Vector3.FORWARD` (= -Z), i.e. minus the rotation about +Z |
| "Aft" in local coordinates | -Z | +Z | yes (every local offset with a z component changes sign: fin at z = -0.9 becomes z = +0.9, CLR at z = -0.25 becomes +0.25, mast foot z = -0.1 becomes +0.1) |
| `Cross(forward, right)` | (0,0,1)×(1,0,0) = (0,1,0) = up | (0,0,-1)×(1,0,0) = (0,-1,0) = down | yes |
| Sail chord at sail angle a (boom aft, positive a = boom to starboard) | `(sin a, 0, -cos a)` (`AdvancedSail.cs:240-244`) | `(sin a, 0, +cos a)` | yes (z) |
| Compass: North | +Z (`SailingState.cs:16`, `WindSystem.cs:20`) | -Z (D4) | yes (z) |
| `Vector3.SignedAngle(a, b, up)` / `a.signed_angle_to(b, UP)` | positive when b is clockwise from a seen from above (toward starboard from the bow) | positive when b is counter-clockwise from a seen from above (toward port from the bow) | **yes** |

Concrete cross-product example from the legacy fallback at `AdvancedSail.cs:482-483` (`tack = Cross(vel, apparentWind).y > 0 ? 1 : -1`): board sailing North, wind from the East so the air moves West. Unity: vel = (0,0,1), AW = (-1,0,0), Cross = (0·0-1·0, 1·(-1)-0·0, 0·0-0·(-1)) = (0,-1,0), y < 0. Godot: vel = (0,0,-1), AW = (-1,0,0), cross = (0·0-(-1)·0, (-1)·(-1)-0·0, 0·0-0·(-1)) = (0,+1,0), y > 0. Same physical situation, opposite sign. (That branch was also unreachable in the legacy code because `SailSide` is never 0 after Session 22, and its sign was wrong even in Unity: wind from starboard should have given tack = +1.)

Wind bearing to vector. Legacy (`WindSystem.cs:160-168`, North = +Z): `windTo = (sin(b+180°), 0, cos(b+180°))`. Godot: `from_world = (sin(b), 0, -cos(b))` and `v_wind_true = -speed * from_world`. Check: b = 0° gives from = (0,0,-1) = North, air moves toward +Z = South; b = 90° gives from = (1,0,0) = East. Heading: `heading_deg = wrapf(rad_to_deg(atan2(bow_world.x, -bow_world.z)), 0, 360)`; bow = -Z gives 0 (North), bow = +X gives 90 (East).

**Resolution.** Never copy a legacy vector expression. Every direction in this spec is written in D4 from scratch, and every model section has a "Signs and the Unity-to-Godot translation" subsection listing where the sign flips. Phase 2 tests: `test_engine_conventions.gd` (already there) plus the numeric cases in this section's test list.

#### P3. The Unity physics collected many stabilisers

**Contradiction.** The docs call the physics "validated" (`README.md:27`, `PHYSICS_VALIDATION.md:3`), but the code needs at least twelve artificial terms to stay upright: rake base and speed torques (`AdvancedSail.cs:511-522`), high-speed steering scale-down (`:498-503`), high-speed sail force reduction to 60 % above 20 kt (`:368-374`), pitch stabilisation (`:396-445`), speed-dependent angular damping up to ×5 (`AdvancedHullDrag.cs:535-543`), the 12× (scene: 3×) submersion drag multiplier (`:41, 221-228`), underwater drag up to ×5 (`:232-243`), the ride-high drag bonus (`:247-251`), the extra vertical damping (`:44, 253-270`), the displacement lift capped at 30 % of weight (`:349-353`), the planing lift as a fraction of weight with a cap (`:452-468`), the fin tracking torque (`AdvancedFin.cs:155-187`), the controller's weight-shift base torque of 80 N·m at zero speed (`AdvancedWindsurferController.cs:257`) and the anti-capsize torque (`:276-307`).

**Resolution.** As the plan says: start Phase 2 without any of them, and add one back only when a Phase 4 validation test fails and the failure is understood. Each one is described, with a keep/drop/re-evaluate recommendation, in the "Stabilisers and fudges" subsections of the model sections and in the stabiliser overview section of this spec. This section only records that the contradiction exists.

**Reason.** Each stabiliser was added to hide a symptom (see the session notes cited in P4 to P6). Several hide each other: for example the pitch stabiliser exists because the planing lift and the hull drag were applied at points that create pitching moments, and the ×5 angular damping exists because the rake torques were made speed-independent and strong. Removing the cause removes the need.

#### P4. Planing lift must not depend on how deep the board sits

**Contradiction.** Session 23 made the planing lift scale with submersion (`KNOWN_ISSUES.md:184-186`). Session 24 called that the root cause of the "trampoline" oscillation and removed it (`KNOWN_ISSUES.md:177-179`, `PROGRESS_LOG.md:219-247`, `PHYSICS_VALIDATION.md:335-341`). The final code is mostly free of it, but not completely: `AdvancedHullDrag.cs:394-399` decays the lift by 0.9 per tick below 5 % submersion, `:405-412` decays it by 0.8 per tick above 50 %, and `:247-251` reduces drag by up to half when planing and shallower than 35 % submersion. Those are steps and ramps in submersion, so a weak version of the feedback loop is still there. The docs also say the lift is Savitsky (see 13.3.3); it is not.

**Why the feedback oscillates (plain language).** If lift grows when the board sinks, then a board that dips gets pushed up harder, overshoots, loses lift above the water, falls, and repeats. Buoyancy already provides a restoring force that is proportional to depth; a second, stronger one on top of it makes the "spring" stiff and the damping relatively weak, so it bounces.

**Resolution.** In the spec, hydrodynamic lift is a function of speed, trim (pitch) and the hull geometry only (the Savitsky-type model in the hull section). The only submersion input is a binary "is the hull touching the water" gate, and even that is smoothed with a fixed time constant, not a per-tick multiplier. Height is set by buoyancy alone. Phase 2 test (from the plan): lift at a fixed speed and trim is the same for 20 % and 60 % submersion.

**Reason.** Sessions 23 and 24 showed the oscillation and its cause directly; the physics agrees (a planing surface's lift depends on speed, trim and wetted length, and wetted length is set by trim and height, which buoyancy balances).

#### P5. Viscous damping belongs on vertical motion only

**Contradiction.** Session 24 found that applying velocity-squared damping horizontally "killed forward speed" (`PROGRESS_LOG.md:258, 273`; `PHYSICS_VALIDATION.md:364`). The final `AdvancedBuoyancy.cs` applies viscous damping only vertically (`:322-338`) and a linear lateral damping of `|v_x| × 20 × 2 × submersion` N (`:344-359`). But `AdvancedHullDrag.cs:283-316` still adds a lateral form drag `1.0 × (0.5 × 1025 × |v|) × |v_x| × (L × T)` and a vertical drag `1.2 × (0.5 × 1025 × |v|) × |v_y| × (0.5 × L × W)`, both proportional to total speed times the component speed, so the "no horizontal v² damping" statement in the docs is only true of one of the two files.

**What the vertical damping added up to in the last played build** (scene values, Session 26): buoyancy linear 800 × submersion N·s/m (`AdvancedBuoyancy.cs:326`, scene line 642), viscous 400 × submersion × |v_y| N·s²/m² (`:330`, scene line 643), hull "submersion vertical damping" 600 × submersion, doubled when planing ratio > 0.2 and submersion > 0.4 (`AdvancedHullDrag.cs:44, 256-270`), and the speed-coupled vertical drag 1.2 × 0.5 × 1025 × |v| × 0.75 × v_y = 461 × |v| × v_y N (`:305-315`). At 8 m/s and 30 % submersion that last term alone is about 3690 N per m/s of heave, more than everything else together. It is not wrong physics (a planing surface's heave damping does grow with forward speed, because vertical velocity changes its angle of attack), but it was hidden in a "directional drag" helper and never mentioned in any doc.

**Resolution.** Horizontal resistance comes from the hull drag model (forward), the hull lateral form drag and the fin (sideways); there is no separate linear horizontal damper. Vertical (heave) damping is one explicit term in the buoyancy section with one coefficient, chosen by a Phase 2 test (a board dropped from 0.1 m settles within about two oscillations). If Phase 4 shows the board still bounces at speed, add the speed-coupled heave term explicitly and document it; do not hide it in a drag helper.

**Reason.** Session 24's finding, plus the fact that the legacy code had four overlapping vertical dampers and two overlapping lateral ones, none of them documented as a whole.

#### P6. Beam-reach submersion at low speed was never solved

**Contradiction.** `README.md:77` and `PROGRESS_LOG.md:32` list "beam reach submersion" as open; Session 24 "reverted half-wind corrections (were unstable)" (`PROGRESS_LOG.md:267`); Session 27 "deliberately not touched" it (`PROGRESS_LOG.md:128`). `KNOWN_ISSUES.md:108-133` says the high-speed version was fixed in Session 23 by disabling planing lift above 50 % submersion and adding up to ×5 underwater drag.

**Evidence of the likely cause.** Two facts from the code, using the Session 26 scene values: (a) the displacement lift `0.12 × 0.5 × 1025 × v² × (2.5 × 0.6 × 0.8)` = 73.8 × v² N reaches its cap of 0.3 × 91 × 9.81 = 268 N at v = sqrt(268 / 73.8) = 1.9 m/s (6.9 km/h) and stays there until planing onset at 4.0 m/s (`AdvancedHullDrag.cs:345-356`); (b) the planing lift at full planing was `weight × _maxLiftFraction × _planingLiftCoefficient` = 893 × 0.4 × 0.15 = 53.6 N, six per cent of the weight (`:452-463`, scene lines 677-678). So as the board accelerated from 14 to 22 km/h its total dynamic lift fell from 268 N to 54 N: in the last played build, "planing" made the board sit deeper, not higher. On a beam reach, where the sail power is greatest, the board reached those speeds soonest, so this is where the sinking was noticed. (If the C# defaults 1.0 × 1.0 had been in effect instead, the lift would have equalled the full weight and the board would have risen out of the water entirely, which is the "flying out at 45+ km/h" symptom of Session 24 (`KNOWN_ISSUES.md:181`). OPEN: which of the two the team actually saw; opening the Session 26 scene in Unity and reading the AdvancedHullDrag inspector settles it.)

**Resolution.** The rebuild does not carry a "beam reach submersion" fix. It carries: Archimedes buoyancy (73 % submerged at rest for 90 kg on 120 L, P8), a Savitsky-type lift that grows with speed² and trim and takes over from buoyancy as the board accelerates, no cap at a fraction of weight, and the Phase 4 test "submersion stays steady at speed" plus the polar sweep, which includes TWA 90°. If a beam-reach problem appears there, it is diagnosed from the force telemetry, not patched.

**Reason.** The symptom never had a documented root-cause analysis; the numbers above are the most likely one.

#### P7. "Beam reach is the fastest point" versus "broad reach should be faster"

**Contradiction.** `README.md:216` ("Beam reach speed | Fastest point | Confirmed"), `TEST_SCENE_SETUP.md:307` and `:532` ("Beam Reach, Fastest!"), and `Debug/PhysicsValidation.cs:13-14` (expects beam reach 12-15 kt, broad reach 10-12 kt) say beam reach. `KNOWN_ISSUES.md:96` (Session 25) says the quadratic fin induced drag "should make broad reach faster" and `:106` says "the velocity polar issue (beam reach faster than broad reach) may still need tuning". The plan's open question 2 asks the team.

**The physics, in plain language.**
1. *Apparent wind.* The sail feels `v_apparent = v_wind_true - v_boat`. Sailing across the wind, the board's own speed adds to the true wind and the apparent wind is strong and comes from ahead of the beam. Sailing away from the wind, the board's speed subtracts, so the apparent wind is weaker; but the faster the board goes, the further forward the apparent wind swings, so a fast board on a broad reach still sees a useful apparent wind from 60° to 90° AWA. Example with 15 kt (7.72 m/s) true wind, board heading North: beam reach (wind from East) at 7 m/s gives `v_apparent` = (-7.72, 0, 7), 10.4 m/s at AWA = atan2(7.72, 7) = 47.8°; broad reach (TWA 135°, wind from the South-East, `from_world` = (0.707, 0, 0.707)) at 8 m/s gives `v_apparent` = (-5.46, 0, 2.54), 6.0 m/s at AWA = atan2(5.46, 2.54) = 65.0°. The beam reach has three times the dynamic pressure (10.4² / 6.0² = 3.0) but a much worse angle.
2. *Drive versus side force.* With sail lift L perpendicular to the apparent wind and drag D along it, the forward drive is `L·sin(awa) - D·cos(awa)` and the side force is `L·cos(awa) + D·sin(awa)`. At AWA 48° most of the lift is side force; at AWA 65° to 90° most of it is drive.
3. *Induced drag.* The fin must cancel the side force with lift of its own, and a lifting fin has induced drag `Cd_i = Cl² / (pi × AR × e)` (`Hydrodynamics.cs:84-86`): twice the side force costs four times the induced drag. The sail pays the same square law (`Aerodynamics.cs:86-89`). Both punish the beam reach, where side force is highest.
4. *Hull drag.* Once planing, hull drag rises roughly with speed² (friction and spray, `Hydrodynamics.cs:199-218`) and does not care about the point of sail. So the top speed is set where drive is largest for the least side force. For planing craft (windsurfers, skiffs, catamarans) real polars put that between about 110° and 135° TWA; speed records are sailed on broad reaches. Dead downwind is slow again because the apparent wind collapses.

**Recommendation (OPEN for the team, plan question 2).** Target a polar whose maximum boat speed lies at TWA 110° to 135° and is about 1.1 to 1.3 times the beam-reach (TWA 90°) speed, with the beam reach still faster than close-hauled. Phase 4's polar sweep at 15 kt is the test. If the team prefers the old README behaviour (beam reach fastest), that is a legitimate gameplay choice but it is not what real polars show, and the spec should then say so explicitly.

**Reason.** Points 1 to 4 above; the Session 25 note already moved in this direction and the README table was never re-measured after Session 25.

#### P8. A 120 L board carrying 90 kg is about 73 % submerged at rest

**Contradiction.** `KNOWN_ISSUES.md:190` (Session 22): "Board sinks 75 %+ at displacement speeds → Added displacement lift system". `PHYSICS_DESIGN.md:164-168` calls 75 % submersion "unrealistic heavy feel" and `:380` expects 30-50 % in displacement mode.

**Evidence: Archimedes.** A floating body displaces its own weight of water: `V_submerged = mass / rho_water`. 90 kg / 1025 kg/m³ = 0.0878 m³ = 87.8 L, which is 73.2 % of 120 L. For the masses the legacy build actually used: 91 kg gives 88.8 L (74.0 %), 94 kg gives 91.7 L (76.4 %), 95 kg gives 92.7 L (77.2 %). To float at 50 % the board would need 180 L. So 73-77 % at rest is correct physics for this equipment, and the legacy buoyancy model does reproduce it (`AdvancedBuoyancy.cs:244-252`, 21 points whose volumes sum to the total, each fully submerged at one board thickness of depth). The "displacement lift" added to fight it (`AdvancedHullDrag.cs:327-357`) is a step of 30 % of the weight from 6.9 km/h up to planing onset (calculation under P6) and has no physical basis at those speeds beyond a small dynamic lift at Froude numbers above about 0.5.

**Resolution.** Keep pure Archimedes; accept about 73 % submersion at rest (a 120 L board with 30 L of reserve does float with its deck barely above the water; real freeride sailors know this "sinky at rest" feel). Drop the displacement lift as a separate model. Dynamic lift below planing speed, if Phase 4 needs it, comes out of the same Savitsky-type lift model at low speed (it is naturally small there) rather than from a second capped term. Phase 2 test (plan): at rest the submerged volume equals `mass / rho_water` within 2 %.

**Reason.** Archimedes; and the displacement lift was tuned to hide correct behaviour.

#### P9. Session 27 code was never compiled or played

**Contradiction.** `README.md:44-48`, `KNOWN_ISSUES.md:9-24` and `PROGRESS_LOG.md:103` say so. Besides the shader, sail deformer, spray and audio, Session 27 changed physics inputs in the scene (list at the top of this section) and turned on four Gerstner waves of 0.1, 0.06, 0.03 and 0.012 m amplitude (0.2 m total).

**Resolution.** Everything in Session 27 is "ideas only". For physics numbers this section uses the Session 26 scene. The wave code (`GerstnerWave.cs`, `WaterSurface.cs`) is a design reference for Phase 5 but every formula there is re-derived and tested in D4.

### 13.2 Numbers whose sources disagree

The table gives every value found, its source, and the resolution. "S26 scene" means `git show b5ed2ea:WindsurfingGame/Assets/Scenes/MainScene.unity` at the line given; "HEAD scene" means `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` today (after Session 27).

#### 13.2.1 Total mass: 90, 91, 94 or 95 kg

| Value | Source |
|---|---|
| 90 kg | `Legacy/Documentation/PHYSICS_DESIGN.md:554`; `PROGRESS_LOG.md:450`; `QUICK_SETUP_CHECKLIST.md:49` (Rigidbody "Mass: 90"); plan line 146 ("75 kg sailor plus 15 kg of equipment") |
| 91 kg | wizard `WindsurferSetup.cs:689` (`rb.mass = 91f`, "8 + 8 + 75"); S26 scene line 602 and HEAD scene line 214 (`m_Mass: 91`); `HullConfiguration.TotalMass` = 8 + 8 + 75 (`SailingState.cs:220-231`, wizard `:768-770`, scene lines 665-667 / 277-279), used by hull drag for the lift caps and angular damping (`AdvancedHullDrag.cs:352, 448, 543`) |
| 94 kg | what the Rigidbody actually had at runtime: `BoardMassConfiguration.cs:110` recomputes `_totalMass = _boardMass + _rigMass + _sailorMass` = 8 + 6 + 80 (fields at `:27, 30, 33`; wizard `:780-782`; scene lines 853-855) and `:191` writes it to `_rigidbody.mass` in `Start()`, overriding the 91 |
| 95 kg | `BoardMassConfiguration.cs:24` default; wizard `:779`; scene line 852 (`_totalMass: 95`, overwritten at runtime by the 94 above) |
| 83 kg | `PhysicsConstants.cs:34, 49` (8 + 75, no rig; constants never used by the Advanced code) |

**Last validated build most likely used:** 94 kg for gravity and inertia (Rigidbody) and 91 kg for the hull-drag caps, at the same time. The two masses came from two components with two sets of fields that nobody reconciled.

**Resolution.** One `total_mass_kg = board_mass_kg + rig_mass_kg + sailor_mass_kg` computed in one place from one config, used everywhere. Section 14 chooses 92 kg = 75 (sailor) + 9 (board) + 8 (rig); the plan's 90 kg (75 + 15) is within 2 % of it. Subject to the team (plan question 3).

#### 13.2.2 Sail area: 6.0, 6.5 or 7.5 m²

| Value | Source |
|---|---|
| 6.0 m² | `PHYSICS_DESIGN.md:544`; `SCENE_CONFIGURATION.md:121` and `scene_config.json:75` (old `Sail` component); plan line 146 |
| 6.5 m² | `SailConfiguration.Area` default `SailingState.cs:130`; `PhysicsConstants.cs:43`; wizard `:729`; S26 scene line 722; HEAD scene line 334 |
| 7.5 m² | legacy `Sail.cs:24` (old component); the disabled "WindsurfBoard" object in the pre-Session-22 scene |

**Last validated build used:** 6.5 m² (scene). **Resolution:** 6.5 m² unless the team chooses otherwise at the Phase 1 stop. Reason: it is the validated value, and 6.5 m² is a normal freeride size for a 75 kg sailor in 15 kt; 6.0 m² would be slightly underpowered for that wind and weight.

#### 13.2.3 Fin area: 0.035, 0.04, 0.06 or 0.08 m²

| Value | Source |
|---|---|
| 0.035 m² | `PhysicsConstants.cs:39` ("typical 35 cm fin"); wizard `:749`; S26 scene line 698; HEAD scene line 310 |
| 0.04 m² | `PHYSICS_DESIGN.md:560`; `PROGRESS_LOG.md:1028` (Session 6); `scene_config.json:97` and `SCENE_CONFIGURATION.md:158` (old `FinPhysics`) |
| 0.06 m² | `FinConfiguration.Area` default `SailingState.cs:177` ("Increased from 0.035 for more lateral grip"), with depth 0.45 (`:180`) |
| 0.08 m² | legacy `FinPhysics.cs:19` |

**Last validated build used:** 0.035 m² with depth 0.40 m and chord 0.10 m (scene lines 698-700), so aspect ratio = depth² / area = 0.16 / 0.035 = 4.57 (`SailingState.cs:196`; `PhysicsConstants.cs:40` says 4.5). **Resolution:** 0.035 m², depth 0.40 m, AR 4.57. Reason: validated value; a 40 cm freeride fin really has about 0.03-0.04 m² of projected area. Note the C# default of 0.06 was a tuning experiment that never reached the scene.

#### 13.2.4 Fin stall angle: 14° or 25°

| Value | Source |
|---|---|
| 14° | `FinConfiguration.StallAngle` default `SailingState.cs:191`; wizard `:753`; scene line 702 / 314 |
| 25° | legacy `FinPhysics.cs:43`; `scene_config.json:104`; `PROGRESS_LOG.md:1019` (Session 6) |
| 15° | `SailingState.cs:91` (`IsFinStalled = |LeewayAngle| > 15°`; dead: `LeewayAngle` in `SailingState` is never assigned, so this flag is always false) |
| 12° peak, 16° post-stall | the actual lift curve `Hydrodynamics.cs:38-69`: linear to 8°, peak at 12°, down to 70 % of the peak by 16°, 0.4 by 25° |

**Evidence.** In the Advanced code `StallAngle` never changes a force. It only sets the `_isStalled` flag (`AdvancedFin.cs:123`), which weakens the tracking torque to 30 % (`:179`) and shows a HUD label. The forces come from the curve, which stalls between 12° and 16° regardless of the field. The 25° belongs to the old exponential model in `FinPhysics.cs:191-204`, which the Advanced stack does not use. With AR 4.57 the curve gives a lift slope of 2·pi·4.57/6.57·1.05 = 4.59 per rad, Cl = 0.64 at 8°, peak 0.79 at 12°, 0.55 at 16°.

**Resolution.** The fin section defines the stall by the curve (peak at 12°, post-stall by 16°) and uses 14° only as the telemetry threshold. 25° is history. Reason: 12-15° is right for a symmetric foil of this aspect ratio; and it is what the validated build's forces did.

#### 13.2.5 Board length: 2.5, 2.4 or 2.28 m

| Value | Source |
|---|---|
| 2.5 m | `HullConfiguration.Length` `SailingState.cs:207`; `PhysicsConstants.cs:30`; `AdvancedBuoyancy.cs:36`; wizard `:700, 710, 764`; scene lines 635/661 and 247/273; docs `PHYSICS_DESIGN.md:339, 548`; `PROGRESS_LOG.md:1262-1264` ("2.5 m board, mast 1.2 m from the tail") |
| 2.4 m | `BoardMassConfiguration.cs:44`; wizard `:783`; scene line 858 / 470. Used only in `CalculateInertiaTensor()` (`:151-181`), which is applied only when `_useCustomInertia` is true; it is false (`:54`, wizard `:786`, scene 861 / 473), so this 2.4 never affected anything |
| 2.28 m × 0.80 m | the `board.fbx` mesh measured in Session 28 (plan lines 241, 146) |
| mast foot | `MastFootPosition` z = -0.1 m in Unity (0.1 m aft of centre, `SailingState.cs:152`, wizard `:46`), i.e. 1.15 m from the tail of a 2.5 m board; the wizard's help text says "(0, 0.1, -0.05)" (`WindsurferSetup.cs:117`) but sets -0.1 (`:46, 734`); the docs say 1.2 m from the tail (`PHYSICS_DESIGN.md:339`) |

**Last validated build used:** 2.5 m × 0.6 m × 0.12 m for all physics (buoyancy, hull drag, collider), with a visual model of 2.28 m × 0.80 m sitting inside it.

**Resolution.** Physics and visuals must be one board, otherwise the model floats too high or too low on screen. Section 14 chooses 2.40 × 0.72 × 0.12 m (a modern 120 L freeride shape) and asks Phase 6 to scale the old model by about +5 % in length and −10 % in width, or to replace it; the alternative is to adopt the model's 2.28 × 0.80 m as the hull (at 55 % fill of its box that is still 120 L). The 2.4 m of `BoardMassConfiguration` is dropped either way. OPEN for the team (plan question 3, section 15).

#### 13.2.6 Vertical damping: 800, 4000 or 8000 N·s/m, and viscosity 400 or 800 N·s²/m²

| Value | Source |
|---|---|
| 800 N·s/m | wizard `WindsurferSetup.cs:717`; scene line 642 at every commit from Session 22 to HEAD (line 254) |
| 4000 N·s/m (+ 400 viscous) | C# default at commit `fa79027` (Session 24); `PHYSICS_VALIDATION.md:361-362`; `PHYSICS_DESIGN.md:131-132, 572-573`; `PROGRESS_LOG.md:253-254` |
| 8000 N·s/m (+ 800 viscous) | C# default since `c62f577` (1 January 2026, "WIP: Physics tuning"): `AdvancedBuoyancy.cs:59, 62`; `KNOWN_ISSUES.md:104` (Session 25) |
| viscosity 400 | S26 scene line 643 (the scene at `fa79027` and `c62f577` has no `_waterViscosity` line at all, so Unity used the C# default then: 400 at Session 24, 800 at the WIP commit) |
| viscosity 800 | HEAD scene line 255 (changed by the unverified Session 27 edit) |

**Last validated build most likely used:** 800 N·s/m linear and 400 N·s²/m² viscous (scene at `b5ed2ea`), not the 4000/8000 of the docs and code, because the wizard wrote 800 into the scene in Session 22 and nothing rewrote it. OPEN: why the scene says 400 when the C# default at the time of the last save was 800 (either the scene was saved before the WIP commit's default change, or someone typed 400 from the doc). Either way 800 is certain and viscosity was 400 or 800.

**Note on the trampoline.** Session 24 credits the end of the trampoline oscillation to "increased damping (4000)" together with the lift change (`PHYSICS_DESIGN.md:597`). The damping in the running scene never went above 800. The more likely explanation is P6's finding: with `_maxLiftFraction` 0.4 × `_planingLiftCoefficient` 0.15 in the scene, the planing lift was six per cent of the weight, too small to oscillate. This is an inference, not a measurement.

**Resolution.** The spec does not adopt any of these numbers. Heave damping is one term with one coefficient in the buoyancy section, sized by a Phase 2 settling test (see P5), starting from a physically reasoned estimate rather than a legacy value. The spec records 800 (+400) as "what ran" for anyone comparing feel later.

#### 13.2.7 Planing onset: 4 m/s (14 km/h) or "about 17 km/h"

| Value | Source |
|---|---|
| onset 4.0 m/s = 14.4 km/h, full 6.0 m/s = 21.6 km/h | `AdvancedHullDrag.cs:31, 34`; scene lines 668-669 / 280-281; `PHYSICS_DESIGN.md:391-392, 563-564`; `PROGRESS_LOG.md:81-82, 388-389, 446-447` |
| "~17 km/h" | `README.md:52, 214`; `PHYSICS_VALIDATION.md:300`; `PROGRESS_LOG.md:16, 391`; tooltip `AdvancedHullDrag.cs:30` ("17 km/h = 4.7 m/s is typical"); comment `:180` |
| 18 km/h | where the `_isPlaning` flag flips: `planingRatio > 0.5` (`AdvancedHullDrag.cs:189`) = 5.0 m/s = 18.0 km/h, which is what the HUD showed as "PLANING" |
| "~8 km/h" | the Session 12 state that Session 22 replaced (`KNOWN_ISSUES.md:191`, `PROGRESS_LOG.md:728` "above 4 m/s (~8 knots)"; 4 m/s is 7.8 kt, so that note confused km/h and knots) |

**Evidence.** There is no real contradiction, only sloppy wording: the ramp started at 14.4 km/h, was half-way (and displayed "PLANING") at 18 km/h, and complete at 21.6 km/h. "About 17 km/h" is the visible middle of that ramp.

**Resolution.** Phase 2 keeps a speed-based `planing_ratio` (section 5 F4, 4.0 to 6.0 m/s by default) because the Savitsky wetted-length interpolation needs it; it is a model input, not a claim about when planing happens. The validation target stays "planing starts between 15 and 17 km/h" (plan, Phase 4), measured as the speed at which dynamic lift carries half the weight in 15 kt of wind on a beam reach (section 14), so the two ramp speeds are tuned in Phase 4, not trusted.

#### 13.2.8 Planing lift coefficient and cap: 0.8/0.85, 1.0/1.0 or 0.15/0.4

| `_planingLiftCoefficient` / `_maxLiftFraction` | Source |
|---|---|
| 0.8 / 0.85 | `PHYSICS_DESIGN.md:232-233, 566-567`; `PROGRESS_LOG.md:255` ("1.2 → 0.85"); C# defaults at `fa79027` (Session 24) |
| 1.0 / 1.0 | `AdvancedHullDrag.cs:61, 64` (since `c62f577`); HEAD scene lines 289-290 (Session 27 edit) |
| 0.15 / 0.4 | S26 scene lines 677-678 (Session 22 values, never updated) |
| 0.15 | `PROGRESS_LOG.md:449` ("Planing Lift Coeff 0.15", Session 22) |

**Last validated build used:** 0.15 and 0.4 (scene), giving a full-planing lift of 0.06 × weight = 54 N (see P6). The plan's "planing lift capped at 85 %" (line 137) describes the docs, not the running build.

**Resolution.** No multiplier, and only one hard cap at exactly the weight (section 5 F15), a stand-in for the wetted-length shrink the model leaves out and never a tuning knob: the lift is what the Savitsky-type formula gives for the speed, trim and beam. If a Phase 4 test shows the board leaving the water, the fix is in trim (moment balance), not a smaller cap. Reason: a tunable cap is exactly the kind of fudge the plan tells us to start without, and the three legacy values differ by a factor of 16.

#### 13.2.9 Submersion drag multiplier: 3, 6 or 12

| Value | Source |
|---|---|
| 12 | `AdvancedHullDrag.cs:41`; `PHYSICS_DESIGN.md:569`; `PHYSICS_VALIDATION.md:386`; `PROGRESS_LOG.md:257` ("6x → 12x"); plan line 138; HEAD scene line 283 (Session 27 edit) |
| 3 | S26 scene line 671 (Session 22 value) |
| 6 | the pre-Session-24 value per `PROGRESS_LOG.md:257` |

**Last validated build used:** 3. **Resolution:** none of them; the spec has no submersion drag multiplier. Extra resistance when the hull is deep comes from the wetted area and the lateral/vertical form drag growing with the submerged geometry, which the hull section defines. Re-evaluate only if the Phase 4 nose-dive recovery test fails.

#### 13.2.10 Smaller disagreements (one line each)

- **Fin tracking torque strength:** 40 (`AdvancedFin.cs:40`) vs 15 (wizard `:755`, scene 706 / 318). Ran with 15. Resolution: no tracking torque; a fin at a leeway angle already produces a restoring yaw moment because its force acts 0.9 m aft of the centre (`AdvancedFin.cs:141-148`). Re-evaluate if the board wanders in Phase 4.
- **Planing wetted-area ratio:** 0.20 (`AdvancedHullDrag.cs:37`, HEAD scene 282) vs 0.35 (S26 scene 670). Ran with 0.35. Resolution: wetted area follows from the Savitsky wetted length in the hull section; no fixed ratio.
- **Lift smoothing factor:** 0.08 (`:70`, docs `PHYSICS_DESIGN.md:234`) vs 0.15 (S26 scene 680). Per-tick lerp factors depend on the tick rate (Unity 50 Hz). Resolution: if smoothing is needed, use a time constant in seconds, never a per-tick factor.
- **Sailor centre-of-mass shift when planing:** 0.3 m aft (`PHYSICS_DESIGN.md:424-425`, `PROGRESS_LOG.md:451`) vs 0.15 m aft and 0.1 m down (`BoardMassConfiguration.cs:64, 222-225`, scene 864 / 476). Ran with 0.15 / 0.1. Resolution: the mass section defines the shift as a function of `planing_ratio`; start from 0.15 m aft, 0.1 m down.
- **Sheet angle range:** 15° to 80° (`PROGRESS_LOG.md:1327`, Session 11) vs 12° to 85° (`AdvancedSail.cs:224-225`; `:601-604`). Ran with 12-85. Resolution: 12° to 85°.
- **Rake steering formula:** docs `rake × tack × force × 0.5` (`PHYSICS_VALIDATION.md:169`), Session 17 `0.5 × force + 150 + 30 × speed` (`PROGRESS_LOG.md:1548-1561`, and the plan's "150 × rake"), Session 16 `0.05 × force` (`PROGRESS_LOG.md:1464, 1479`), final code `0.3 × force + 200 (350 near head-to-wind or dead downwind) + 25 × min(v, 8)`, all × `steeringScale` (`AdvancedSail.cs:506-522`). Ran with the final code. Resolution: the rake section derives the torque from the CE shift (`torque = sail_force_leeward × ce_shift`) and adds nothing speed-independent; see P3.
- **High-speed steering scale:** docs to 0.3 at 25 kt (`PHYSICS_VALIDATION.md:188-193`) vs code to 0.5 at 30 kt with a floor of 0.4 (`AdvancedSail.cs:499-503`). Resolution: dropped (fudge).
- **High-speed angular damping:** docs `Lerp(1, 5, (kt-15)/15)` (`PHYSICS_VALIDATION.md:203-212`) vs code `1 + (kt-15)/5` capped at 5 (`AdvancedHullDrag.cs:535-540`; reaches 5 at 35 kt, the doc formula at 30 kt). Both multiply a base of `(1.5 or 0.8) × TotalMass × 0.1` = 13.7 or 7.3 N·m·s/rad (`:530, 543`), on top of the buoyancy rotational damping 150 × (4.0 pitch, 0.3 yaw, 3.0 roll) × (0.3 + 0.7 × submersion) (`AdvancedBuoyancy.cs:369-379`; the docs say 150 for both roll and pitch, `PHYSICS_DESIGN.md:133-134`) and the Rigidbody's own 0.3 (scene 604 / 216). Resolution: one rotational damping model in the damping section, derived from the hull's wetted geometry; no speed multiplier.
- **Centre of effort height:** 1.8 m boom, CE 60 % along the boom (`PHYSICS_DESIGN.md:355-370`), 0.3 m (Session 16, `PROGRESS_LOG.md:1463, 1477`), `SailConfiguration.CenterOfEffortHeight` = 0.1 + 1.4 × 0.5 = 0.8 m (`SailingState.cs:166`, unused), and finally (0, 0, 0) (`AdvancedSail.cs:283-291`, Session 25/26, `KNOWN_ISSUES.md:83, 100`). Ran with (0,0,0). Resolution: the sail section puts the CE where the sail is (about 40 % of the luff up the mast, along the boom) and lets the heeling moment exist; the sailor's righting moment (mass section) balances it. This is the "proper fix" `KNOWN_ISSUES.md:37-42` asked for.
- **Wind in the validated scene:** the README's numbers are quoted "at 15 kt" (`README.md:215`), but the Session 26 scene's WindSystem was set to 22 kt from 270° (S26 scene lines 972-973); the wizard default is 12 kt from 45° (`WindsurferSetup.cs:62-63`); the component default is 15 kt from 270° (`WindSystem.cs:22, 26`). OPEN: at which wind speed the "~28 km/h" and "~17 km/h" in `README.md:213-216` were observed. The rebuild's targets are defined at 15 kt regardless.
- **Sail sheet direction:** the legacy `_sheetPosition` is 0 = sheeted in, 1 = fully eased (`AdvancedSail.cs:27-29`; HUD "Sheet In %" = (1 - pos) × 100 at `AdvancedWindsurferController.cs:320`). The spec's `sheet` is 0 = fully out, 1 = fully in. Conversion: `sheet = 1 - sheetPosition_legacy`; `sheet_angle_rad = deg_to_rad(lerp(85, 12, sheet))`. Every section must use the spec's direction.

### 13.3 Other contradictions found between docs, code, wizard and scene

#### 13.3.1 Sail side: docs describe `-Sign(AWA)` with hysteresis; the code uses a manual tack

`PHYSICS_VALIDATION.md:57-87`, `COMPONENT_DEPENDENCIES.md:112-118`, `ARCHITECTURE.md:20` and `PROGRESS_LOG.md:72-77, 304-306` say `sailSide = -Sign(AWA)` with a 5° hysteresis band. That was the Session 18 code (`4c45223`). Since Session 22 (`5a1857a`) the sail side is `-_manualTack`, toggled by the Space key (`AdvancedSail.cs:65-66, 197-208, 549-554`; `AdvancedWindsurferController.cs:178-182`), and `_lastSailSide` is written but never read for hysteresis. So in the validated build the sail could be on the windward side if the player forgot to press Space, and the "tacking works (sail switches sides)" checklist item (`PHYSICS_VALIDATION.md:296`) tested a key press, not physics.

**Resolution.** `sail_side = -sign(awa_rad)` as in D4, with a hysteresis band (the sail keeps its side while |awa| is below a small threshold, so it does not flip at head-to-wind), plus a manual "flip" input for the tack/gybe manoeuvre that the sail section defines. Reason: a sail always fills on the leeward side; the manual tack was a control shortcut, not physics.

#### 13.3.2 The AWA fallback and the unset state fields

`SailingState.cs:117` falls back to `TrueWindAngle` when the apparent wind is below 0.1 m/s, but the TWA sign is inverted (P1). `SailingState.LeewayAngle` (`:48`) is never assigned, so `IsFinStalled` (`:91`) is always false; the real leeway lives in `AdvancedFin` (`AdvancedFin.cs:63`). Resolution: one `Telemetry` record filled by the simulation each step, with tests that every field it reports is actually computed.

#### 13.3.3 The docs describe Savitsky planing lift; the code uses a weight-fraction ramp

`PHYSICS_VALIDATION.md:306-341` and `PHYSICS_DESIGN.md:198-235` print the Savitsky formula `CL = tau^1.1 × (0.012 × lambda^0.5 + 0.0055 × lambda^2.5 / Cv²)` with a deadrise correction, and say it is in `CalculatePlaningLift()`. It was, at commit `fa79027` (Session 24, lines 399-402 of that version). The same day, commit `c62f577` replaced it with the comment "The Savitsky equations are too complex and produce insufficient lift. Use a simple speed-based model" and `targetLift = weight × maxLiftFraction × planingRatio × max(cos(heel), 0.7) × planingLiftCoefficient` (`AdvancedHullDrag.cs:442-463` today). The docs were never updated, and `README.md:31` still advertises "Savitsky Planing".

**Why Savitsky gave "insufficient lift" there (likely).** In the Session 24 version `lambda` (wetted length over beam) was interpolated to 1.5 at full planing and `Cv` used the 0.6 m beam; with tau clamped to 1-10° from a pitch that the pitch stabiliser kept near 0°, `tau^1.1` was tiny. Savitsky lift depends strongly on trim; a board held flat by a stabiliser cannot plane in that model. This is a case of one fudge (pitch stabilisation) breaking real physics and a second fudge (the weight-fraction ramp) replacing the physics.

**Resolution.** The hull section specifies the Savitsky-type lift properly: trim comes from the real pitch of the board (which the sailor's aft weight shift and the buoyancy moment set), wetted length from geometry, no clamp of tau below the actual trim, and unit tests on a worked example. The weight-fraction ramp is not carried over.

#### 13.3.4 Rotational damping labels

`AdvancedBuoyancy.cs:372-374` comment "Roll (X) ... Pitch (Z in local = X in world for Unity)" is confused, but the code applies the 4.0 "pitch" multiplier to local X and the 3.0 "roll" multiplier to local Z, which is correct for both Unity and Godot (pitch is about the sideways axis X, roll about the fore-aft axis Z). Resolution: the damping section names axes by what they do (pitch about local X, roll about local Z, yaw about local Y) and tests each one separately.

#### 13.3.5 Wizard help text versus wizard values

`WindsurferSetup.cs:117` tells the user the mast base default is (0, 0.1, -0.05); the field it sets is (0, 0.1, -0.1) (`:46, 734`). `WindsurferSetup.cs:25, 849` says "95 kg total mass" while `:689` sets 91. Resolution: covered by 13.2.1 and 13.2.5.

#### 13.3.6 PhysicsConstants.Equipment is decorative

`PhysicsConstants.cs:24-51` holds a full equipment set (2.5 m board, 8 kg, 0.035 m² fin, AR 4.5, 6.5 m² sail, 75 kg sailor) that no Advanced component reads; the real values are the `SailingState.cs` configuration classes plus the scene. Resolution: in the rebuild every tuning number lives in exactly one `.tres` resource (plan D3) and there is no second copy in code.

### Signs and the Unity-to-Godot translation (summary)

Everything a Phase 2 implementer needs from this section, in one list:

1. `from_world = (sin(bearing), 0, -cos(bearing))`; `v_wind_true = -wind_speed_ms * from_world`. (Unity had `+cos`.)
2. `v_apparent = v_wind_true - v_boat` (same in both engines).
3. `from_local = basis.inverse() * (-v_apparent)` then `awa_rad = atan2(from_local.x, -from_local.z)`; same formula with `-v_wind_true` for `twa_rad`. Never `signed_angle_to`. (Unity's `SignedAngle(forward, from, up)` gave the same sign; Godot's `signed_angle_to` gives the opposite.)
4. `sail_side = -sign(awa_rad)`; boom to port (-X) on starboard tack. Same in both engines.
5. Boom direction at sail angle a (positive = boom to starboard): `(sin a, 0, +cos a)` in Godot (aft is +Z); Unity had `-cos a`.
6. Rake yaw torque: `torque_y = -rake * sign(awa_rad) * K`. Positive torque about +Y turns the bow to port in Godot, to starboard in Unity, so the sign flips relative to `AddTorque(Vector3.up * rake * tack * ...)`.
7. `pitch_rad` (bow up positive) = rotation about local +X in Godot, with no negation (Unity needed `-eulerAngles.x`).
8. `heel_rad` (starboard down positive) = rotation about `Vector3.FORWARD` = minus the rotation about local +Z (the legacy code only used |heel|, so no sign was load-bearing there).
9. Every local z offset changes sign: fin (0, -0.1, -0.9) becomes (0, -0.1, +0.9); CLR z = -0.25 becomes +0.25; mast foot z = -0.1 becomes +0.1; the aft COM shift `-0.15 * planing_ratio` becomes `+0.15 * planing_ratio`.
10. Cross products: derive the meaning each time (see the P2 example), never carry a `.y > 0` rule across.

### Stabilisers and fudges in this section

This section itself adds no model, so there is nothing to keep or drop here; each stabiliser is judged in its model section. The cross-cutting recommendations that come out of the contradictions are:

| Item | Recommendation | Reason |
|---|---|---|
| Displacement lift (30 % of weight step) | drop | fights correct Archimedes behaviour (P8) |
| Weight-fraction planing lift with cap | drop, replace by Savitsky-type lift | it replaced real physics that a stabiliser had broken (13.3.3); ran at 6 % of weight (P6) |
| Submersion drag multiplier (3/12×), underwater ×5, ride-high bonus | drop | hull section's wetted geometry covers it; re-evaluate after the nose-dive test |
| Four overlapping vertical dampers | replace by one explicit heave damping term | P5 |
| Three overlapping angular dampers with a ×5 speed factor | replace by one rotational damping model | 13.2.10 |
| Fixed-speed planing ramp (4 to 6 m/s) | keep as a model input; measure planing onset from the lift fraction | 13.2.7 |
| Manual tack as the only sail-side rule | replace by `-sign(awa)` with hysteresis plus a manual flip input | 13.3.1 |
| CE at (0,0,0) | drop; put the CE on the sail and add the sailor's righting moment | 13.2.10; `KNOWN_ISSUES.md:37-42` |

### What Phase 2 must implement (checklist)

- [ ] One wind field function: bearing + speed to `v_wind_true` in D4, with the North/East example as a test.
- [ ] One apparent-wind function returning `v_apparent`, `awa_rad`, `twa_rad` (same sign rule for both) and `sail_side`, using `atan2`, never `signed_angle_to`.
- [ ] Rake yaw torque with the sign `-rake * sign(awa_rad)`, tested on both tacks.
- [ ] `pitch_rad` and `heel_rad` read from the body basis with the D4 signs above, tested with a known rotation.
- [ ] One mass: `total_mass_kg` from one config; no second copy anywhere (13.2.1).
- [ ] Hull dimensions, sail area, fin area/depth from one `.tres` each; defaults per section 14 (92 kg, 2.40 × 0.72 m, 6.5 m², 0.0365 m² / 0.38 m).
- [ ] No lift multiplier, no tunable lift cap (only the hard cap at the weight), no submersion drag multiplier, no tracking torque, no manual-tack-only sail side, no CE at the origin; the speed-based planing ratio stays as a model input (section 5 F4).
- [ ] `Telemetry` reports TWA and AWA with the same sign convention, and reports the leeway angle from the fin model.
- [ ] Sheet convention 0 = out, 1 = in; sail angle from 85° to 12°.

### Tests Phase 2 should write

- **Wind vector:** bearing 0°, 10 m/s gives `v_wind_true` = (0, 0, +10); bearing 90° gives (-10, 0, 0); bearing 225° (from the South-West) gives (+7.071, 0, -7.071).
- **AWA at rest:** heading North, wind from East, `awa_rad` = +pi/2 (from starboard), `sail_side` = -1. Wind from West gives -pi/2 and +1. Wind from North gives 0; from South gives ±pi.
- **AWA under way:** heading North at 5 m/s, 8 m/s from the East: `v_apparent` = (-8, 0, +5), |v_apparent| = 9.434 m/s, `awa_deg` = atan2(8, 5) = 57.99°; `twa_deg` = 90°. Both positive.
- **TWA/AWA same sign:** for every heading and bearing in a sweep, `sign(twa) == sign(awa)` whenever |twa| is between 5° and 175° and the board moves forward slower than the wind.
- **signed_angle_to trap:** `Vector3.FORWARD.signed_angle_to(Vector3.RIGHT, Vector3.UP)` = -pi/2 while `atan2(1, 0)` = +pi/2 (already in `test_engine_conventions.gd`; keep it).
- **Rake torque sign:** starboard tack (`awa` = +58°), `rake` = +1, K = 200: `torque_y` = -200 N·m, and after one step the yaw rate is negative (bow turning to starboard, i.e. toward the wind). Port tack: +200 N·m, bow to port, toward the wind. Rake -1 reverses both.
- **CE-offset derivation matches the sign rule:** apply F = (-500, 0, 0) N at local (0, 0, +0.3) on a body at identity; the resulting torque is (0, -150, 0) N·m.
- **Pitch sign:** rotate the body +5° about local X; `pitch_rad` reads +0.0873 rad and the bow's world y is above the tail's.
- **Heel sign:** rotate the body so the starboard rail goes down 10°; `heel_rad` reads +0.1745 rad.
- **Archimedes:** 120 L board, 90 kg total, flat water: submerged volume 0.0878 m³ ± 2 % (73.2 % ± 1.5 points); 91 kg gives 74.0 %; 92 kg (section 14) gives 89.8 L, 74.8 %.
- **Lift independent of depth:** at fixed speed and trim, the hydrodynamic lift at 20 % and 60 % submersion differs by less than 1 %.
- **No hidden dampers:** with buoyancy and heave damping disabled in a test config, a board given a vertical velocity keeps it (no other model removes vertical momentum); with them enabled, a 0.1 m drop settles within two oscillations.
- **Fin stall curve:** Cl(8°) = 0.641 ± 0.005, Cl(12°) = 0.791 ± 0.005, Cl(16°) = 0.554 ± 0.005 for AR 4.57 (from `Hydrodynamics.cs:31-55` with tau = 0.05), if the fin section keeps that curve.
- **Polar shape (Phase 4, OPEN target):** in 15 kt the maximum speed of the TWA sweep lies between 110° and 135° and exceeds the 90° speed by 10 % to 30 %.

### Sources

Code (all under `Legacy/WindsurfingGame/Assets/Scripts/`):
- `Physics/Core/SailingState.cs:13-16, 30, 48, 89-91, 97-119, 130, 152, 166, 177-196, 207-241`
- `Physics/Core/PhysicsConstants.cs:12-18, 24-51`
- `Physics/Core/Hydrodynamics.cs:23-93, 98-158, 164-222`
- `Physics/Core/Aerodynamics.cs:24-106, 119-250`
- `Physics/Board/AdvancedSail.cs:27-45, 65-66, 137-153, 178-192, 197-291, 296-352, 357-389, 396-445, 450-525, 549-554, 586-607`
- `Physics/Board/AdvancedHullDrag.cs:30-73, 161-278, 283-316, 327-357, 372-474, 483-508, 513-546`
- `Physics/Board/AdvancedFin.cs:31-44, 87-128, 133-148, 155-187`
- `Physics/Board/BoardMassConfiguration.cs:24-64, 110, 151-181, 191-194, 210-229`
- `Physics/Buoyancy/AdvancedBuoyancy.cs:33-68, 134-204, 219-284, 312-385`
- `Physics/Board/Sail.cs:24, 54-58, 230-233, 281-296` (legacy component, history)
- `Physics/Board/FinPhysics.cs:19, 43, 191-204` (legacy component, history)
- `Physics/Board/ApparentWindCalculator.cs:95, 110` (legacy component, history)
- `Environment/WindSystem.cs:20-26, 147-169, 174-182`
- `Player/AdvancedWindsurferController.cs:143-182, 248-270, 276-307, 320`
- `Editor/WindsurferSetup.cs:25, 46, 62-63, 117, 689-700, 709-719, 729-736, 749-755, 764-770, 779-787, 799-800, 849`
- `Debug/PhysicsValidation.cs:11-20`
- `UI/AdvancedTelemetryHUD.cs:190, 220`

Scene:
- `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` (HEAD, after Session 27): 207-232 (Rigidbody), 242-259 (AdvancedBuoyancy), 269-296 (AdvancedHullDrag), 306-320 (AdvancedFin), 330-340 (AdvancedSail), 461-479 (BoardMassConfiguration)
- The same file at commit `b5ed2ea` (Session 26, last played), via `git show b5ed2ea:WindsurfingGame/Assets/Scenes/MainScene.unity`: 602-620, 630-647, 657-684, 694-708, 718-730, 849-865, 311 (`_enableWaves: 0`), 972-973 (wind 270° / 22 kt)
- `git diff b5ed2ea 757d5cf -- WindsurfingGame/Assets/Scenes/MainScene.unity` (the Session 27 physics edits)
- `git log -S` results: `_verticalDamping = 4000f` introduced at `fa79027`, `8000f` at `c62f577`; `_maxLiftFraction = 0.85f` at `fa79027`; `_manualTack` at `5a1857a`; the Savitsky lines `0.012f`/`0.0055f` present at `fa79027`, gone at `c62f577`

Docs (all under `Legacy/`):
- `README.md:10, 27, 31, 44-48, 52, 77, 213-216`
- `Documentation/PHYSICS_VALIDATION.md:3, 43-50, 57-87, 112-129, 166-181, 188-193, 203-212, 294-303, 306-341, 351-364, 386`
- `Documentation/PHYSICS_DESIGN.md:130-141, 164-168, 176-196, 198-235, 337-348, 355-370, 380, 386-392, 419-434, 537-580, 588-631`
- `Documentation/KNOWN_ISSUES.md:9-24, 30-46, 81-87, 94-106, 108-133, 177-193`
- `Documentation/PROGRESS_LOG.md:16, 32, 72-82, 103, 128, 139-166, 215-274, 277-316, 337-452, 559-572, 674-777, 1005-1030, 1056-1090, 1260-1264, 1318-1340, 1461-1479, 1548-1561`
- `Documentation/COMPONENT_DEPENDENCIES.md:107-118, 145-151`
- `Documentation/ARCHITECTURE.md:17-23`
- `Documentation/TEST_SCENE_SETUP.md:304-309, 530-535`
- `Documentation/QUICK_SETUP_CHECKLIST.md:49`
- `Documentation/SCENE_CONFIGURATION.md:33, 121, 158` and `Documentation/scene_config.json:21, 75, 97, 104` (history only)

Rebuild plan and tests:
- `Documentation/REBUILD_PLAN.md:57-71` (D4), `:130-146` (Phase 1 tasks), `:290-300` (known pitfalls), `:302-307` (open questions)
- `Game/tests/unit/test_engine_conventions.gd:19-38`

Literature used for the physics statements: Savitsky, D., "Hydrodynamic Design of Planing Hulls", Marine Technology 1 (1964); Marchaj, C.A., "Aero-Hydrodynamics of Sailing" (induced drag, drive/side force decomposition); Larsson & Eliasson, "Principles of Yacht Design" (ITTC friction, polar shapes). Archimedes' principle for P8.

---

## 14. Default configuration and real-world plausibility checks

### Purpose

This section fixes two things that every other section depends on:

- **Part A, the default configuration.** One board, one sail, one fin, one sailor and one set of wind and water conditions. These are the numbers that go into the default `.tres` files in `Game/config/` (Phase 2) and that every test uses. Without one agreed setup, no two tests would be comparing the same thing.
- **Part B, the validation targets.** The numbers Phase 4 will test the simulation against: how fast the board should go at each angle to the wind in 15 kt, when it should start planing, how steady it should be at speed, and so on. Each target has a source (legacy code, a document, a real-world reference, or a calculation shown here) and a tolerance.

**Principle (plan decision D8).** Nothing in this section is a target the simulation is tuned to. Part A fixes a real, common freeride setup. Part B lists what real windsurfing kit does, with sources, so that Phase 4 can tell a wrong model from a right one. When the simulation disagrees with Part B, the model is examined and fixed at its physical source; a number is never adjusted to match. Candidate A (the Unity behaviour) is kept only as history.

The legacy numbers come from three places that do not always agree: the C# field defaults, the editor wizard `Legacy/WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs`, and the docs. There is a fourth: `Legacy/WindsurfingGame/Assets/Scenes/MainScene.unity` **does** contain the component values (it was hand-edited in Session 27, see `Legacy/Documentation/PROGRESS_LOG.md:122`). Where the scene file has a value, it is the best evidence of what the last Unity build actually ran with, and this section treats it that way. `Legacy/Documentation/scene_config.json` (2025-12-27) describes the old non-Advanced components and is history only.

Shared notation (same as every section): `rho_air = 1.225 kg/m3`, `rho_water = 1025 kg/m3`, `g = 9.81 m/s2` (`Legacy/WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs:12-18`). `1 kt = 0.514444 m/s = 1.852 km/h` (`PhysicsConstants.cs:21-22`). TWA is positive when the wind comes from starboard (D4).

### Inputs and outputs

This section produces no forces. Its outputs are configuration values and test targets.

| Name | Meaning | Unit |
|---|---|---|
| `board_volume_m3`, `board_length_m`, `board_width_m`, `board_thickness_m`, `nose_rocker_m`, `tail_rocker_m`, `board_mass_kg` | Hull geometry and mass (Section on buoyancy and hull drag use these) | m3, m, kg |
| `sail_area_m2`, `luff_m`, `boom_m`, `mast_height_m`, `camber`, `boom_height_m`, `mast_foot_local` | Sail geometry (sail section) | m2, m, -, m, m |
| `fin_area_m2`, `fin_depth_m`, `fin_chord_m`, `fin_aspect_ratio`, `fin_root_local` | Fin geometry (fin section) | m2, m, m, -, m |
| `sailor_mass_kg`, `rig_mass_kg`, `total_mass_kg` | Masses (mass and inertia section) | kg |
| `wind_speed_ms`, `wind_from_bearing_deg` | Test wind | m/s, deg |
| Validation targets | Numbers with tolerances for Phase 4 | see table |

### Part A: the candidates compared

Three candidate sets exist for the default equipment. The table shows them side by side; the choice and the reason follow.

**Board**

| Property | Legacy config | Old `board.fbx` model | Real 120 L freeride boards | Chosen |
|---|---|---|---|---|
| Volume | 120 L (`PhysicsConstants.cs:33`; `WindsurferSetup.cs:709,767`; `MainScene.unity:246,276`) | not known (a mesh, not a solid) | 117 to 125 L in the 2024 "120 L" test group (windsurf.co.uk) | **120 L** |
| Length | 2.5 m (`PhysicsConstants.cs:30`; `WindsurferSetup.cs:710,764`; scene :247,273); **2.4 m** in `BoardMassConfiguration` (`BoardMassConfiguration.cs:44`; `WindsurferSetup.cs:783`; scene :470) | 2.28 m (REBUILD_PLAN Phase 6 notes) | Starboard Futura 120: 228 cm; JP Super Ride 124: 244 cm | **2.40 m** |
| Width | 0.6 m (`PhysicsConstants.cs:31`; wizard :711,765,784; scene :248,274,471) | 0.80 m (plan Phase 6 notes) | Futura 120: 76 cm; Super Ride 124: 76 cm; task brief: 0.70 to 0.75 m | **0.72 m** |
| Thickness | 0.12 m (`PhysicsConstants.cs:32`; wizard :712,766,785; scene :249,275,472) | not measured | Futura 105: 11.5 cm | **0.12 m** |
| Nose rocker | 0.08 m (`AdvancedBuoyancy.cs:45`; wizard :713; scene :250) | - | - | **0.08 m** |
| Tail rocker | 0.02 m (`AdvancedBuoyancy.cs:48`; wizard :714; scene :251) | - | - | **0.02 m** |
| Board mass | 8 kg (`PhysicsConstants.cs:34`; `HullConfiguration` `SailingState.cs:220`; `BoardMassConfiguration.cs:27`; wizard :768,780; scene :277,465); 15 kg in `PHYSICS_DESIGN.md:555` | - | Super Ride 124: 8.8 kg; task brief: 8 to 10 kg | **9 kg** |

Reasons: 120 L is the classic volume for a 75 kg sailor (the "add about 50 L to your weight" rule quoted in the Mistral Quikslide search result) and matches all legacy sources. The legacy 0.6 m width is too narrow for a modern 120 L freeride board; 0.72 m is in the real range and gives the buoyancy and planing models a realistic beam. 2.40 m is a compromise between the legacy 2.5 m and modern 2.28 to 2.44 m boards; it also removes the legacy 2.4/2.5 disagreement by choosing one number everywhere. The old `board.fbx` (2.28 x 0.80 m) is closer to a 135 L board (Futura 135: 229 x 83 cm); Phase 6 should scale the model to the config (about +5 % in length and -10 % in width, which is visually harmless) or replace it. The physics never reads the model.

**Sail**

| Property | Legacy config | Old `sail.fbx` model | Real 6.5 m2 freeride sails | Chosen |
|---|---|---|---|---|
| Area | 6.5 m2 (`PhysicsConstants.cs:43`; `SailingState.cs:130`; wizard :729; scene :334; `PhysicsValidation.cs:66`); **6.0 m2** in `PHYSICS_DESIGN.md:544` and in the plan's summary | cloth 5.08 m tall, 2.8 m boom (plan Phase 6 notes): a triangle of that size is about 7.1 m2, so with roach about 8 m2 | 6.5 | **6.5 m2** |
| Luff | 4.7 m (`PhysicsConstants.cs:44`; `SailingState.cs:133`; wizard :730; scene :335) | 5.08 m | Mistral Makani 6.5: 443 cm; Loftsails 6.5: 468 cm | **4.60 m** |
| Boom | 2.0 m (`PhysicsConstants.cs:45`; `SailingState.cs:136`; wizard :731; scene :336) | 2.8 m | Makani 6.5: min 190 cm; Loft 6.5: 196 cm | **1.95 m** |
| Mast height | 4.6 m (`PhysicsConstants.cs:46`; `SailingState.cs:139`; wizard :732; scene :337) | - | 430 cm mast + extension (Makani), 460 cm + 8 cm (Loft) | **4.60 m** (top of the luff above the mast foot) |
| Camber (draft depth / chord) | 0.10 (`SailingState.cs:144`; wizard :733; scene :338) | - | freeride sails are moderately full | **0.10** |
| Boom height above the mast foot | 1.4 m (`SailingState.cs:155`; wizard :735; scene :341); 1.8 m and 1.5 m in the old non-Advanced setup (`SCENE_CONFIGURATION.md:133,246`) | - | boom at chest height, about 1.4 to 1.6 m above the deck | **1.40 m** |
| Twist | 10 deg (`SailingState.cs:148`; scene :339) | - | - | **10 deg** (only if the sail section uses it) |

Reasons: 6.5 m2 is what every legacy code path used; 6.0 m2 appears only in one doc. 6.5 m2 with 120 L and 75 kg is a well-powered but not overpowered combination in 15 kt (windup.live: an intermediate on mid-range freeride kit needs "14 to 16 kt to get going"; Wikipedia: 100 to 140 L boards plane from 12 kt with 6 to 8 m2). Luff and boom are moved from the legacy 4.7 / 2.0 m to 4.60 / 1.95 m, inside the real product range. The old `sail.fbx` is about an 8 m2 sail; Phase 6 must scale it (height x 0.906, boom x 0.70, or accept the mismatch and document it).

**Fin**

| Property | Legacy config | Real freeride fins | Chosen |
|---|---|---|---|
| Depth (span) | 0.40 m (`PhysicsConstants.cs:37`; wizard :750; scene :311); 0.45 m C# default (`SailingState.cs:180`) | 36 to 42 cm for a 120 L board (Futura 120 ships a 42 cm fin, range 40 to 44; Super Ride 124 ships a 40 cm; the task brief says 36 to 38 cm) | **0.38 m** |
| Area | 0.035 m2 (`PhysicsConstants.cs:39`; wizard :749; scene :310); 0.06 m2 C# default (`SailingState.cs:177`, "increased for more lateral grip"); 0.04 m2 in `PHYSICS_DESIGN.md:560` | Unifiber Freeride G10 38 cm: 365 cm2 | **0.0365 m2** |
| Chord | 0.10 m (wizard :751; scene :312; `SailingState.cs:183`); 0.12 m (`PhysicsConstants.cs:38`) | mean chord = area / depth | **0.096 m** (mean) |
| Aspect ratio | 4.5 constant in `PhysicsConstants.cs:40` and the default argument of `Hydrodynamics.cs:23,78`; the config computes `Depth^2 / Area` (`SailingState.cs:196`) = 0.40^2/0.035 = 4.57 (scene values) or 0.45^2/0.06 = 3.375 (C# defaults) | - | **3.96** (= 0.38^2 / 0.0365) |
| Stall angle | 14 deg (`SailingState.cs:191`; wizard :753; scene :314) | - | **14 deg** (fin section decides) |
| Position (Unity local) | (0, -0.1, -0.9) (`SailingState.cs:187`; wizard :752; scene :313): 0.9 m aft of the centre, 0.1 m below | fin box about 0.30 m ahead of the tail ("one-foot-off", surf-magazin fin basics) | root at **(0, -0.06, +0.90)** in Godot (see Signs) |

Reasons: a 38 cm G10 freeride fin is the standard fin for a 6.5 m2 sail on a 120 L board and we have a real area for it (365 cm2). The legacy C# default of 0.06 m2 was a tuning fudge ("more lateral grip"), not a real fin; the wizard and scene overrode it back to 0.035 m2, so the last build used 0.035 m2. Use the real number and let the fin model earn its grip.

**Masses**

| Property | Legacy sources | Chosen |
|---|---|---|
| Sailor | 75 kg (`PhysicsConstants.cs:49`; `HullConfiguration` `SailingState.cs:226`; wizard :770; scene :279); **80 kg** (`BoardMassConfiguration.cs:33`; wizard :782; scene :467) | **75 kg** (dressed: wetsuit and harness included) |
| Rig (mast, boom, sail, extension, base) | 8 kg (`SailingState.cs:223`; wizard :769; scene :278); **6 kg** (`BoardMassConfiguration.cs:30`; wizard :781; scene :466) | **8 kg** (a 430 RDM mast about 2 kg, boom about 2.5 kg, 6.5 m2 sail about 3 to 4 kg, extension and base about 0.5 kg) |
| Board | 8 kg (see the board table) | **9 kg** |
| Total | see the conflict below | **92 kg** |

**Which total mass did the last Unity build use?** Three different numbers were in play at once:
1. The wizard set `Rigidbody.mass = 91` (8 + 8 + 75, `WindsurferSetup.cs:689`; scene :214).
2. `BoardMassConfiguration` was set to 95 total / 8 / 6 / 80 (`WindsurferSetup.cs:779-782`; scene :464-467), but at `Awake` it recomputes `_totalMass = 8 + 6 + 80 = 94` (`BoardMassConfiguration.cs:110`) and at `Start` writes that to `Rigidbody.mass` (`BoardMassConfiguration.cs:191`). So the body that PhysX moved weighed **94 kg**.
3. `HullConfiguration.TotalMass = 8 + 8 + 75 = 91` (`SailingState.cs:231`; scene :277-279) is what the hull drag used for its resistance and for the planing-lift target `weight = TotalMass * g` (`AdvancedHullDrag.cs:448`). So planing lift aimed at 91 x 9.81 = 893 N while the real weight was 94 x 9.81 = 922 N, a hidden 3 % shortfall.

The spec removes this by having **one** `total_mass_kg` computed from the three parts and used everywhere. 92 kg (9 + 8 + 75) is within 2 % of both legacy numbers, so legacy tuning values stay roughly valid.

### Values: the chosen default configuration

| Name | Value | Unit | Source / reason |
|---|---|---|---|
| `board_volume_m3` | 0.120 | m3 | legacy 120 L everywhere (`PhysicsConstants.cs:33`, scene :246); classic volume for a 75 kg sailor |
| `board_length_m` | 2.40 | m | between legacy 2.5 (`WindsurferSetup.cs:710`) and 2.4 (`WindsurferSetup.cs:783`); real 2.28 to 2.44 m |
| `board_width_m` | 0.72 | m | real 120 L boards are 0.70 to 0.76 m (Starboard Futura 120, JP Super Ride 124); legacy 0.6 m too narrow |
| `board_thickness_m` | 0.12 | m | legacy (`PhysicsConstants.cs:32`) |
| `nose_rocker_m` | 0.08 | m | legacy (`AdvancedBuoyancy.cs:45`) |
| `tail_rocker_m` | 0.02 | m | legacy (`AdvancedBuoyancy.cs:48`) |
| `board_mass_kg` | 9.0 | kg | JP Super Ride 124: 8.8 kg; legacy 8 kg |
| `sail_area_m2` | 6.5 | m2 | legacy code and scene (`SailingState.cs:130`, scene :334) |
| `luff_m` | 4.60 | m | real 6.5 m2 sails: 4.43 to 4.68 m; legacy 4.7 |
| `boom_m` | 1.95 | m | real: 1.90 to 1.96 m; legacy 2.0 |
| `mast_height_m` | 4.60 | m | head of the sail above the mast foot (legacy 4.6, `SailingState.cs:139`) |
| `camber` | 0.10 | - | legacy (`SailingState.cs:144`) |
| `boom_height_m` | 1.40 | m | legacy (`SailingState.cs:155`) |
| `mast_foot_local` | (0, +0.06, -0.05) | m | on the deck, 0.05 m forward of the board centre = 1.25 m from the tail; `PHYSICS_DESIGN.md:339` says about 1.2 m from the tail on a 2.5 m board. Legacy code had (0, 0.1, -0.1) in Unity = 0.1 m **aft** (`SailingState.cs:152`), while the wizard's help text claims "slightly forward of center" (`WindsurferSetup.cs:117`). OPEN: the sail section may move this. |
| `fin_depth_m` | 0.38 | m | 38 cm freeride fin (task brief; Unifiber Freeride G10 38) |
| `fin_area_m2` | 0.0365 | m2 | Unifiber Freeride G10 38 cm: 365 cm2 |
| `fin_chord_m` | 0.096 | m | mean chord = area / depth |
| `fin_aspect_ratio` | 3.96 | - | depth^2 / area (same definition as `SailingState.cs:196`) |
| `fin_root_local` | (0, -0.06, +0.90) | m | on the hull bottom, 0.90 m aft of the centre = 0.30 m from the tail; legacy z = -0.9 in Unity (`SailingState.cs:187`), sign flipped for Godot |
| `sailor_mass_kg` | 75 | kg | legacy `PhysicsConstants.cs:49`, plan open question 3 |
| `rig_mass_kg` | 8 | kg | legacy `HullConfiguration` (`SailingState.cs:223`) |
| `total_mass_kg` | 92 | kg | 9 + 8 + 75, computed, never typed twice |
| `wind_speed_ms` (tests) | 7.717 | m/s | 15 kt (`WindSystem.cs:26`; scene :822; plan Phase 4) |
| `wind_from_bearing_deg` (tests) | 270 | deg | from the West (`WindSystem.cs:22`; scene :821) |
| Gusts, shifts, height gradient (tests) | off | - | validation needs steady numbers; the game can turn on the legacy 20 % gusts with an 8 s period (`WindSystem.cs:34-37`) |
| `rho_water`, water surface (tests) | 1025 kg/m3, flat, no current | - | `PhysicsConstants.cs:13`; Phase 5 adds waves |

### Derived values

Every number here is computed from the table above; tests can recompute them.

1. **Weight.** `weight_n = total_mass_kg * g = 92 * 9.81 = 902.5 N`.
2. **Rest displacement (Archimedes).** A floating body displaces its own mass of water: `v_rest_m3 = total_mass_kg / rho_water = 92 / 1025 = 0.08976 m3 = 89.8 L`. As a fraction of the hull: `89.8 / 120 = 0.748`, so the board floats **74.8 % submerged** at rest. This is physics, not a bug (plan pitfall 8). Only 30 L of reserve volume is above the water with the sailor standing still, which is why a 120 L board feels tippy at rest and why "beam reach submersion at low speed" (pitfall 6) is largely real.
3. **Bounding box and fill fraction.** `2.40 * 0.72 * 0.12 = 0.2074 m3 = 207 L`. The hull fills `120 / 207 = 0.58` of its box. The buoyancy section's shape (rocker, taper, volume weights) must integrate to 120 L, not to the box.
4. **Sail aspect ratio** as the legacy code defines it (`luff^2 / area`, `SailingState.cs:160`): `4.60^2 / 6.5 = 3.26` (legacy 4.7 gave 3.40). The geometric aspect ratio of a triangle, `2 * luff / boom = 4.7`, is a different number; the sail section must say which one its lift-slope formula wants.
5. **Fin aspect ratio.** `0.38^2 / 0.0365 = 3.96`. Mean chord `0.0365 / 0.38 = 0.096 m`.
6. **Dynamic pressure of the test wind.** `q = 0.5 * rho_air * v^2 = 0.5 * 1.225 * 7.717^2 = 36.5 Pa`. A standing board in 15 kt sees at most `36.5 * 6.5 = 237 N` per unit of force coefficient.
7. **Beam reach at 20 kt of boat speed.** Apparent wind speed `sqrt(7.717^2 + 10.29^2) = 12.86 m/s`, apparent wind angle `atan(7.717 / 10.29) = 36.9 deg` from the bow, `q = 101 Pa`, so `q * area = 658 N` per unit coefficient. The sail force is then of the same order as the sailor's weight, which is what real windsurfing feels like (the sailor hangs in the harness against it).
8. **Planing onset expressed as a beam Froude number.** `sqrt(g * width) = sqrt(9.81 * 0.72) = 2.66 m/s`. Boat speeds of 15 and 17 km/h (4.17 and 4.72 m/s) are `Fn_beam = 1.57` to `1.78`, in the range where planing hulls start to carry most of their weight on dynamic lift. So the 15 to 17 km/h target from the plan is consistent with the chosen beam.

### Wind and water defaults for tests

- Wind: 15 kt = 7.717 m/s, steady, from 270 deg (West). In D4 the "from" unit vector for a bearing `b` is `from_dir = Vector3(sin(b), 0, -cos(b))` (North = -Z, East = +X), so from 270 deg: `from_dir = (-1, 0, 0)` and the wind **velocity** `v_wind_true = -from_dir * 7.717 = (+7.717, 0, 0)`, blowing towards the East.
- The polar sweep sets the board heading so that the requested TWA is obtained on **both** tacks: heading `= 270 - TWA` for wind from starboard (positive TWA, starboard tack) and `270 + TWA` for wind from port. For example TWA +90 deg means heading 180 deg (South) with the wind on the starboard side. (Sanity check in D4: bow -Z rotated to South is +Z; starboard is then -X, which is West, where the wind comes from. Correct.)
- Water: flat, `rho_water = 1025`, no current. Validation runs on flat water so the numbers settle quickly (plan Phase 4: keep the suite under about 2 minutes).
- The last validated Unity build ran with 15 kt from 270 deg **with gusts on (20 %, 8 s)** and the height gradient on (scene :821-831). Before Session 27 the wizard's own 12 kt / 45 deg settings were silently ignored (`KNOWN_ISSUES.md:77`), so the 15 kt default is what the team actually played with. Its "about 28 km/h top speed" therefore includes gust peaks of up to 18 kt. Note that the Session 26 commit itself stored 22 kt (section 11), so the legacy top-speed observation may have been made in 22 kt (section 15, T9).

### Where things sit in the body frame, and the Unity-to-Godot translation

Origin: the geometric centre of the hull at mid-thickness. Deck at y = +0.06 m, hull bottom at y = -0.06 m (before rocker). Bow at z = -1.20 m, tail at z = +1.20 m, rails at x = +/-0.36 m.

| Item | Unity local (left-handed, +Z bow) | Godot local (D4, -Z bow) | Note |
|---|---|---|---|
| Mast foot | (0, 0.1, -0.1) = 0.1 m aft (`SailingState.cs:152`) | chosen (0, 0.06, -0.05) = 0.05 m forward | z sign flips; the value also changed (see Values) |
| Fin | (0, -0.1, -0.9) = 0.9 m aft (`SailingState.cs:187`) | (0, -0.06, +0.90) | z sign flips: aft is +Z in Godot |
| Centre of mass override | (0, 0.15, -0.1) = 0.1 m aft (`BoardMassConfiguration.cs:37`; scene :468) | (0, 0.15, +0.10) if the mass section keeps it | z sign flips |
| Hull drag application point | 0.1 x length aft (`AdvancedHullDrag.cs:518`, `-Length * 0.1` in Unity z) | z = +0.24 m | z sign flips |
| Planing COM shift when planing | -0.15 m in Unity z = aft (`BoardMassConfiguration.cs:64,222`) | +0.15 m in Godot z | z sign flips |
| Wind from 270 deg | `(sin(b+180), 0, cos(b+180))` (`WindSystem.cs:161`), so from 270 deg the velocity is (+1, 0, 0) x speed | velocity (+1, 0, 0) x speed | Same x. North was Unity +Z and is Godot -Z, so a wind from the North blows towards (0,0,-1) in Unity and (0,0,+1) in Godot |
| TWA sign | `Vector3.SignedAngle(fwd, -aw, up)` (`PHYSICS_VALIDATION.md:43`), which in Unity's left-handed frame is positive for wind from **starboard**; the doc's table at :46-49 has this backwards (plan pitfall 1) | `atan2(from_local.x, -from_local.z)`, positive = wind from starboard | Same meaning. Do not use Godot's `signed_angle_to`: it is positive toward port |
| Yaw rate | positive about +Y turns the bow to starboard in Unity (left-handed) | positive about +Y turns the bow to **port** in Godot (right-handed) | every torque that should turn the board "to starboard" flips sign |

### Stabilisers and fudges met in this section

These are configuration-level fudges. The per-model ones are in their own sections.

| Fudge | What it is | Why it was added | What it hides | Recommendation |
|---|---|---|---|---|
| Fin area 0.06 m2 C# default (`SailingState.cs:177`, "increased from 0.035 for more lateral grip") | a fin 70 % bigger than a real one | leeway was too large at some point | too little fin lift slope, or too much sideways hull drag missing; the last build overrode it back to 0.035 anyway (scene :310) | **Drop.** Use the real 0.0365 m2 and tune the fin model, not its size |
| Three total masses (91 / 94 / 91) | see Part A | three components each carried their own copy of the masses | the planing lift target was 3 % below the real weight | **Drop.** One computed `total_mass_kg` |
| Planing lift capped at `_maxLiftFraction` = 1.0 in code and scene (`AdvancedHullDrag.cs:64`; scene :290), 0.85 in `PHYSICS_DESIGN.md:567` and Session 24 (`PROGRESS_LOG.md:254`) | lift may never exceed a fraction of the weight | the board "flew out" at 45+ km/h (`KNOWN_ISSUES.md:181`) | a lift model without a natural equilibrium (lift should fall as the board rises and the wetted length shrinks) | **Drop the tunable fraction.** Section 5 keeps one hard cap at exactly the weight as a stand-in for the wetted-length shrink the model leaves out. The "no flying off at 45 km/h" test below checks that an equilibrium exists |
| Gusts on during validation (scene :823-824) | wind varies +/-20 % | realism in the game | validation numbers that drift by +/-20 % | **Off in tests, on in the game** |
| Wind height gradient on in the validated build (`WindSystem.cs:51-58`, exponent 0.14, reference 1 m; scene :829-831) | wind grows with height | realism | the sail's centre of effort height (which the legacy set to 0, `KNOWN_ISSUES.md:100`) decides which wind speed the sail sees; with CE at 0 the gradient did nothing useful | **Off in tests.** The wind section decides for the game |

### Part B: how the plausibility ranges were built

A polar diagram shows boat speed against true wind angle for one wind speed. We need one for 15 kt of true wind (7.717 m/s, 27.8 km/h). There is no published polar for a 120 L / 6.5 m2 / 75 kg freeride setup, so the table below is built from anchors and physics, and it is explicitly a **range to compare against**, not a target and not a measurement:

1. **Anchor: how fast, relative to the wind?** Recreational planing windsurfers exceed the true wind speed. The rec.windsurfing thread quoted by the search says "in 15-20 knots of wind recreational sailors will go anywhere from 20-38 knots when planing"; the "Maximum Speed" post on The Windsurf Loop reports "when planing, my speed was about 15 to 20 knots" in marginal wind and only "about 4 knots" once off the plane; a windsurf.co.uk speed article reports freeride kit reaching 45 to 48 km/h (24 to 26 kt) on Lake Garda in stronger wind. For a well-sailed freeride setup that is just comfortably powered in 15 kt, a top speed of about **1.45 x wind = 22 kt (40 km/h)** is a fair central value; a cautious sailor would see 18 to 20 kt.
2. **Anchor: which angle is fastest?** "A variety of high-performance sailing craft sail fastest on a broad reach with the sails close-hauled at speeds several times the true windspeed" (Wikipedia, Point of sail). Session 25 of the legacy project reached the same conclusion after fixing the fin's induced drag: beam reach carries more side force, so more induced drag, "which should make broad reach faster" (`KNOWN_ISSUES.md:96`). The old README's "beam reach = fastest point" (`Legacy/README.md:216`) was measured before that fix.
3. **Anchor: upwind.** With a fin, the best upwind course in a real GPS session was "around 30 degrees (60 degrees relative to the wind)" (The Windsurf Loop, polar plots post). Racers on slalom kit point higher. Wikipedia (Point of sail) gives the no-go zone as "typically at an angle between 30 and 50 degrees from the wind" and close-hauled as "approximately 45 deg". So 45 deg TWA is achievable but slow, and 40 deg is marginal for freeride kit.
4. **Physics of the deep angles.** The apparent wind is `v_apparent = v_wind_true - v_boat`. Its magnitude is `sqrt(v_t^2 + v_b^2 + 2 * v_t * v_b * cos(TWA))`. On a broad reach at TWA 120 deg with `v_b = 1.45 v_t` the apparent wind is still `1.29 v_t = 10 m/s`, plenty to keep planing. At TWA 150 deg with `v_b = 0.9 v_t` it drops to `0.52 v_t = 4 m/s`, which is about the least wind a 6.5 m2 sail can plane with, so the speed falls steeply beyond about 140 deg. At 165 deg the board is off the plane in 15 kt and does roughly half the wind speed, like the "about 4 knots ... 4-5 knots in displacement mode" observation above but with a bigger sail. This is why the table has a sharp drop between 135 and 165 deg, and why those two points get a wider tolerance: falling off the plane is bistable and small model changes move the cliff.
5. **The legacy alternative.** `PhysicsValidation.cs:11-15` quotes a polar "at 10 m/s wind: close-hauled 45 deg 8-10 kt, VMG 5-6 kt; beam reach 12-15 kt; broad reach 135 deg 10-12 kt; running 8-10 kt". Those are displacement-yacht numbers (they never exceed the wind), and the README's validation table (`Legacy/README.md:213-216`) says the Unity build made "about 28 km/h" (15 kt) in 15 kt of wind with the beam reach fastest. That is candidate A below.

**What real freeride kit does in 15 kt of true wind (the plausibility range Phase 4 compares against; candidate B).** `v_t = 7.717 m/s`. Speed ratio = boat speed / true wind speed. km/h = kt x 1.852, m/s = kt x 0.5144.

| TWA (deg) | Ratio | Target (kt) | Target (km/h) | Target (m/s) | Tolerance | Note |
|---|---|---|---|---|---|---|
| 40 | 0.55 | 8.3 | 15.4 | 4.27 | 6 to 10 kt | marginal, probably not planing; the test only requires positive VMG |
| 45 | 0.75 | 11.3 | 20.9 | 5.81 | +/-20 % | just planing upwind; VMG = 11.3 x cos 45 = 8.0 kt (4.1 m/s) |
| 60 | 1.00 | 15.0 | 27.8 | 7.72 | +/-15 % | |
| 75 | 1.20 | 18.0 | 33.3 | 9.26 | +/-15 % | |
| 90 | 1.33 | 20.0 | 37.0 | 10.29 | +/-15 % | beam reach |
| 105 | 1.43 | 21.5 | 39.8 | 11.06 | +/-15 % | |
| 120 | 1.47 | 22.0 | 40.7 | 11.32 | +/-15 % | **fastest point of sail** |
| 135 | 1.40 | 21.0 | 38.9 | 10.80 | +/-15 % | |
| 150 | 0.93 | 14.0 | 25.9 | 7.20 | +/-30 % | on the edge of planing |
| 165 | 0.55 | 8.3 | 15.4 | 4.27 | +/-30 % | off the plane |

Shape rules, which are more robust than the absolute numbers and should be tested as well:
- Speed rises monotonically from 40 deg to the fastest angle.
- The fastest angle is between 105 and 135 deg.
- Speed at 90 deg is at least 85 % of the maximum.
- Speed at 165 deg is below speed at 135 deg.
- Port and starboard tack agree within 2 % at every angle.

**Candidate A (legacy Unity behaviour, history only).** Top speed about 28 km/h (15 kt, ratio 1.0) at 90 deg; 45 deg about 8 kt; 135 deg about 12 kt; the polar never exceeds the wind speed. Source: `Legacy/README.md:213-216`, `PhysicsValidation.cs:11-15` scaled from 10 m/s to 7.7 m/s, and the plan's open question 1.

**Decided under plan decision D8:** the simulation decides the top speed and the fastest point of sail; nothing is tuned to candidate B. Candidate B is the plausibility range: real planing windsurfers in 15 kt go faster than the wind, fastest on a broad reach. If the simulation lands near candidate A instead, a force model is wrong (the Unity model had a submersion drag multiplier and a planing lift of 6 % of the weight), and the error is found in the force telemetry and fixed at its physical source. Phase 4 keeps the range table in one place (a dictionary in the test file or a `polar_reference.tres`) so that a better real-world source can replace it in one edit.

### Values: plausibility checks for Phase 4

Boat speed is the horizontal speed of the centre of mass. "Settled" means the last 10 s of a run in which the speed varies by less than 2 %. Tolerances are on the settled value. A failed check means a model error to find, never a number to adjust (D8).

| Check | Expected (real-world range) | Tolerance | Source or reason |
|---|---|---|---|
| Polar sweep, 15 kt, TWA 40 to 165 deg | table above, both tacks | as in the table | built in Part B |
| No-go zone | at TWA 30 deg the settled speed is below 1.5 m/s (3 kt) or the VMG is below 0.5 m/s; at TWA 40 deg the settled speed is at least 2.6 m/s (5 kt) with positive VMG | none (pass/fail) | plan Phase 4 "no lasting progress closer than about 35 to 40 deg"; Wikipedia no-go zone 30 to 50 deg; The Windsurf Loop fin session best about 60 deg |
| Upwind VMG at 45 deg | VMG at least 3.0 m/s (5.8 kt) on both tacks; target 4.1 m/s (8.0 kt) | VMG >= 3.0 m/s hard floor; the two tacks within 2 % | 11.3 kt x cos 45 deg; legacy README "upwind angle about 45 deg" (`Legacy/README.md:213`); `PHYSICS_VALIDATION.md:294-295` |
| Planing onset | on a beam reach accelerating from rest, the boat speed at which hydrodynamic lift first carries 50 % of the weight (`planing_ratio` 0.5) is between 4.17 and 4.72 m/s (15 to 17 km/h) | the window itself | plan Phase 4; `Legacy/README.md:214` "15-17 km/h ... about 17 km/h"; `KNOWN_ISSUES.md:191`; the legacy code ramped `planing_ratio` from 4.0 to 6.0 m/s (`AdvancedHullDrag.cs:31-34,181-195`), 0.5 at 5.0 m/s = 18 km/h, slightly late. Section 5 F4 keeps a speed-based `planing_ratio` as a model input; this target is measured as the lift fraction of weight regardless, so the two ramp speeds are tuned, not trusted |
| Fully planing | at 25 km/h (6.94 m/s) on a beam reach the submersion ratio is below 0.25 | none | `PHYSICS_DESIGN.md:386-392` ("about 5 % submerged" fully planing is optimistic; 25 % is the safe upper bound) |
| Top speed | maximum settled speed over the sweep: 11.3 m/s (22 kt, 40.7 km/h), candidate B | +/-15 % | Part B anchor 1; OPEN Q1 |
| Fastest point of sail | argmax of the sweep between 105 and 135 deg (B) | none | Part B anchor 2; OPEN Q2 |
| High-speed stability, pitch | above 10.3 m/s (20 kt) with fixed controls, over 10 s: pitch peak-to-peak below 2 deg and no dominant oscillation with a period between 0.3 and 3 s (porpoising) | none | plan Phase 4; `PHYSICS_VALIDATION.md:299-302`; `KNOWN_ISSUES.md:83` (porpoising fixed in Session 26 by fudges; we want it absent without them) |
| High-speed stability, heave | vertical position of the centre of mass: peak-to-peak below 0.05 m over the same 10 s | none | same |
| High-speed stability, submersion | submersion ratio stays within a 0.10-wide band over 10 s and never exceeds 0.35 (no trampoline effect, which was 0 to 100 %, `PROGRESS_LOG.md:221`) | none | plan pitfall 4; `KNOWN_ISSUES.md:179` |
| No flying off at 45 km/h | with the speed forced or sailed to 12.5 m/s on flat water, the centre of mass settles: height above the water below 0.25 m, vertical velocity within +/-0.05 m/s, submersion ratio above 0.02 (still touching), and no tunable lift cap in the model (only section 5's hard cap at the weight) | none | `PHYSICS_VALIDATION.md:301`; `KNOWN_ISSUES.md:181` (legacy fixed it with a cap and downforce; the target is an equilibrium instead) |
| Nose-dive recovery | start at 8 m/s with the hull fully submerged (submersion 1.0, top of the deck 0.3 m under), bow 10 deg down, sail sheeted out: speed below 2 m/s within 3 s; submersion back to 0.75 +/- 0.05 within 8 s; the board does not bounce more than 0.10 m above its rest height; pitch within +/-3 deg at 10 s | none | plan Phase 4; `KNOWN_ISSUES.md:108-126` (Session 23). Physics: a fully submerged 0.72 x 0.12 m section at 8 m/s with Cd about 0.8 gives 0.5 x 1025 x 64 x 0.8 x 0.086 = 2260 N of drag, a 25 m/s2 deceleration, so stopping within 3 s is easy; the recovery time is set by buoyancy (30 L reserve = 300 N net up) and vertical damping |
| Port/starboard symmetry | speed, heel magnitude, sail angle magnitude and leeway magnitude at TWA +/-45, +/-90, +/-120 agree within 2 % | 2 % | plan Phase 4; `PHYSICS_VALIDATION.md:294-298` |
| Rest submersion | with no wind, the settled submerged volume is 0.0898 m3 (89.8 L), 74.8 % of 120 L; pitch within +/-2 deg and heel within +/-0.5 deg with the sailor's mass on the centreline | +/-2 % of volume | Archimedes, derived value 2; plan Phase 2 example test and pitfall 8. OPEN: where the sailor stands at rest (the mass section) decides the rest trim; if the combined centre of mass is not above the centre of buoyancy the board trims, and the pitch tolerance should then be checked against the computed lever arm |
| Righting | heeled 20 deg and released at rest, the board returns to within 2 deg of level within 5 s without overshooting more than 10 deg the other way | none | plan Phase 2 "tilted and released, the board rights itself" |
| Acceleration from rest | beam reach, 15 kt, sheeted for best drive: reaches 4.17 m/s (15 km/h) within 10 s and 90 % of its settled speed within 25 s | none | a real windsurfer gets planing in a few seconds once powered; keeps the suite fast |
| Head to wind | at TWA 0 deg from 5 m/s with the sail eased, the speed falls below 1 m/s within 15 s | none | plan Phase 2 "head to wind, it stops making way" |
| Force sanity at speed | beam reach at 20 kt: total sail force between 300 and 800 N; fin side force between 100 and 500 N | none | derived value 7 (658 N per unit coefficient, expected coefficient 0.6 to 1.2); fin at 5 deg leeway: 0.5 x 1025 x 10.3^2 x 0.0365 x 0.38 = 754 N per unit of CL, so CL about 0.3 gives about 230 N |
| Suite run time | `tools/test.sh validation` under about 2 minutes | - | plan Phase 4. With 4 substeps at 60 Hz, 10 angles x 2 tacks x 60 s is 288 000 steps, which GDScript should do in well under a minute |

### What Phase 2 must implement

- [ ] `BoardConfig.tres`, `SailConfig.tres`, `FinConfig.tres`, `SailorConfig.tres`, `WaterConfig.tres`, `WindConfig.tres` with exactly the values in the Values table, each `@export` with a comment naming its unit and source.
- [ ] `total_mass_kg` is computed from `board_mass_kg + rig_mass_kg + sailor_mass_kg` in one place and used by every model (buoyancy equilibrium, hull drag, planing lift, inertia). No model carries its own copy.
- [ ] `fin_aspect_ratio` and the sail aspect ratio are computed from the geometry, not typed in.
- [ ] Positions in the body frame use the origin defined above (hull centre, mid-thickness; bow -Z; tail +Z; deck +0.06). The fin root is at (0, -0.06, +0.90); the mast foot at (0, +0.06, -0.05) unless the sail section changes it.
- [ ] The wind field converts a compass "from" bearing to a velocity vector with `from_dir = Vector3(sin(b), 0, -cos(b))`, `v_wind_true = -from_dir * speed`.
- [ ] `WindConfig` has switches for gusts, shifts and the height gradient; the test configs have them off.
- [ ] A `Telemetry` snapshot exposes everything the targets table measures: speed, VMG, TWA, AWA, sail angle, planing ratio (as lift fraction of weight or as the hull section defines it, but documented), submersion ratio, pitch, heel, vertical position and velocity of the centre of mass, sail force, fin force.
- [ ] The default scene and the tests load the same `.tres` files.

### Tests Phase 2 and Phase 4 should write

Unit tests (Phase 2, fast):
- Loading the six default `.tres` files gives `total_mass_kg == 92.0`, `fin_aspect_ratio == 3.956 +/- 0.01`, `board_volume_m3 == 0.120`.
- At rest, no wind: submerged volume `0.0898 m3 +/- 2 %`; pitch `|pitch_rad| < deg_to_rad(2)`; heel `|heel_rad| < deg_to_rad(0.5)`.
- Wind from 270 deg at 7.717 m/s gives `v_wind_true == Vector3(7.717, 0, 0)`; from 0 deg gives `Vector3(0, 0, 7.717)` (blowing towards South = +Z); from 90 deg gives `Vector3(-7.717, 0, 0)`.
- Heading 180 deg (bow pointing +Z) in wind from 270 deg gives `twa_rad == +PI/2` (wind from starboard); heading 0 deg gives `twa_rad == -PI/2`.
- A board at rest in 15 kt: apparent wind speed 7.717 m/s, AWA equals TWA.
- Beam reach at 10.29 m/s boat speed: apparent wind speed `12.86 +/- 0.01 m/s`, `|awa_deg| == 36.9 +/- 0.1`.

Validation tests (Phase 4, slow, `tests/validation/`):
- `test_polar_sweep.gd`: one run per TWA and tack, 60 s each (shorter if the speed settles sooner), asserts each settled speed against the target table with its tolerance, then asserts the five shape rules, then prints the table (kt, km/h, m/s) for `Documentation/`.
- `test_no_go_zone.gd`: runs at TWA 30 and 40 deg as in the targets table.
- `test_upwind_vmg.gd`: TWA +45 and -45, VMG >= 3.0 m/s and within 2 % of each other.
- `test_planing_onset.gd`: beam reach from rest; records the speed at which `planing_ratio` crosses 0.5; asserts 4.17 <= speed <= 4.72 m/s; asserts submersion < 0.25 at 6.94 m/s.
- `test_top_speed.gd`: reads the maximum of the sweep and its angle; asserts `11.32 m/s +/- 15 %` and an angle between 105 and 135 deg (candidate B; one-line change for A).
- `test_high_speed_stability.gd`: at TWA 120 deg once above 10.3 m/s, records 10 s of pitch, vertical position and submersion; asserts the peak-to-peak limits (2 deg, 0.05 m, 0.10) and that the maximum submersion is below 0.35.
- `test_no_fly_off.gd`: forces the horizontal speed to 12.5 m/s (or sails there in stronger wind) and asserts the equilibrium limits in the table.
- `test_nose_dive_recovery.gd`: sets the initial state of the table and asserts the time limits.
- `test_symmetry.gd`: mirror pairs at +/-45, +/-90, +/-120 deg; every listed quantity within 2 %.
- `test_rest_submersion.gd` (may live in unit tests): the Archimedes check above, plus righting from 20 deg of heel.
- `test_acceleration.gd` and `test_head_to_wind.gd`: the time limits in the table.

### Sources

Legacy code (all under `Legacy/WindsurfingGame/Assets/`):
- `Scripts/Physics/Core/PhysicsConstants.cs:12-24` (densities, g, unit conversions), `:29-50` (equipment constants: board 2.5 x 0.6 x 0.12 m, 120 L, 8 kg; fin 0.40 m, 0.12 m chord, 0.035 m2, AR 4.5; sail 6.5 m2, luff 4.7, boom 2.0, mast 4.6; sailor 75 kg).
- `Scripts/Physics/Core/SailingState.cs:126-167` (`SailConfiguration` defaults and aspect ratio), `:173-197` (`FinConfiguration` defaults 0.06 m2, 0.45 m, chord 0.10, position (0,-0.1,-0.9), stall 14 deg, AR = depth^2/area), `:203-242` (`HullConfiguration` defaults, `TotalMass`, wetted area, waterline length 0.8 x length).
- `Scripts/Physics/Core/Hydrodynamics.cs:23,78` (fin AR default 4.5), `:164-222` (hull resistance).
- `Scripts/Physics/Core/Aerodynamics.cs:255-268` (optimal angle of attack 17 deg, sail angle 5 to 85 deg).
- `Scripts/Physics/Board/AdvancedHullDrag.cs:31-34` (planing 4.0 to 6.0 m/s), `:64` (`_maxLiftFraction` 1.0), `:181-195` (planing ratio ramp), `:220-243` (submersion drag), `:448-468` (lift target from `TotalMass`), `:518` (drag application point).
- `Scripts/Physics/Board/BoardMassConfiguration.cs:24-64` (95 / 8 / 6 / 80 kg, COM override (0,0.15,-0.1), 2.4 x 0.6 x 0.12 m, planing COM shift 0.15), `:110` (recomputes total = 94), `:191` (writes it to the rigidbody), `:221-228` (COM shifts aft and down when planing).
- `Scripts/Physics/Board/AdvancedSail.cs:224-225` (sheet angle 12 to 85 deg).
- `Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs:33-68` (120 L, 2.5 x 0.6 x 0.12, rocker 0.08 / 0.02, 7 x 3 samples, damping 8000 / 800 / 150 / 20).
- `Scripts/Environment/WindSystem.cs:20-58` (270 deg, 15 kt, gusts 20 % / 8 s, shifts off, height gradient exponent 0.14 at 1 m), `:161` (bearing to vector).
- `Scripts/Editor/WindsurferSetup.cs:46` (mast base (0,0.1,-0.1)), `:62-63` (wizard wind 12 kt from 45 deg), `:117` (help text "slightly forward of center"), `:689` (rigidbody 91 kg), `:700` (collider 0.6 x 0.12 x 2.5), `:709-719` (buoyancy), `:729-736` (sail), `:749-755` (fin, tracking 15), `:764-770` (hull 8 / 8 / 75), `:779-787` (mass config 95 / 8 / 6 / 80, length 2.4).
- `Scripts/Debug/PhysicsValidation.cs:11-20` (expected polar at 10 m/s and sail coefficients), `:66` (6.5 m2), `:105-107` (hull Cd 0.05, area 0.3 m2 used for the rough speed estimate).
- `Scenes/MainScene.unity:214` (mass 91), `:246-257` (buoyancy), `:272-293` (hull config and planing settings), `:309-318` (fin), `:333-347` (sail), `:464-476` (mass config), `:644-660` (waves on), `:821-831` (wind).

Legacy docs (under `Legacy/`):
- `README.md:10` (which sign tables are wrong), `:51-56` (working features), `:213-216` (validation table: about 45 deg upwind, planing about 17 km/h, max about 28 km/h in 15 kt, beam reach fastest).
- `Documentation/PHYSICS_VALIDATION.md:290-302` (section 10 checklist; note :297-298 have rake back/forward swapped, see plan pitfall 1), `:306-333` (Savitsky), `:360-362` (damping 4000 / 400).
- `Documentation/KNOWN_ISSUES.md:77` (wizard wind settings were ignored before Session 27), `:83` (Session 26 porpoising fix), `:96` (Session 25: quadratic induced drag "should make broad reach faster"), `:100` (CE height 0), `:104` (damping 8000 / 800), `:108-126` (Session 23 submersion fix), `:179-182` (Session 24: trampoline, 85 % cap, downforce), `:191` (planing 17+ km/h).
- `Documentation/PROGRESS_LOG.md:81-82` (planing 4.0 / 6.0 m/s), `:122` (MainScene hand-edited in Session 27), `:221-258` (Session 24 table: 85 % cap, downforce, 12x submersion drag), `:385-391` (Session 22 planing thresholds), `:768` (Session 12: "top speeds of 15-25 knots achievable").
- `Documentation/PHYSICS_DESIGN.md:339` (mast foot about 1.2 m from the tail), `:384-392` (displacement 30 to 50 % submerged, planing about 5 %, onset 14 km/h, full 22 km/h), `:544` (6.0 m2), `:547-569` (parameter list: 120 L, 2.5 x 0.6, mass 90 = 15 + 75, fin 0.04 m2, max lift 0.85).
- `Documentation/SCENE_CONFIGURATION.md:133,158,160,246` (old non-Advanced boom height 1.8 / 1.5 m, fin 0.04 m2 at (0,-0.1,-0.8)); history only.

Web sources used (all read on 2026-09-28):
- Starboard Futura 2025 specifications (sizes 100 to 135 L: 225 to 229 cm long, 63 to 83 cm wide; 120 L = 228 x 76 cm, 42 cm fin, 5.5 to 8.5 m2): https://star-board.com/products/2025-futura-windsurf-board
- JP Australia Super Ride 124 (244 x 76 cm, 8.8 kg, 40 cm fin), via Windsurf Magazine's 2024 review as returned by search: https://www.windsurf.co.uk/jp-australia-super-ride-124l-test-review-2024/ and the 120 L test overview https://www.windsurf.co.uk/120l-freeridefreerace-board-test-2024/
- Mistral Makani 6.5 (luff 443 cm, mast 430 cm, boom min 190 cm): https://www.mistral.com/makani-6-5-freeride-windsurfing-sail
- Loftsails specification sheet (6.5: luff 468 cm, boom 196 cm, mast 460 + 8 cm): https://pdf.nauticexpo.com/pdf/loftsails/loft-sail-specifications/21956-214.html
- Unifiber Freeride G10 38 cm fin (area 365 cm2): https://www.unifiber.net/products/freeride-g10-38-cm-power-box
- Fin sizing rule (fin length at most the one-foot-off tail width; 4 to 8 cm shorter for strong wind): https://www.surf-magazin.de/en/windsurfing/windsurfing-accessories/finns/fin-basics-how-to-find-the-right-fin-for-freeride-and-freerace/
- "Add about 50 L to your body weight" board-volume rule (Mistral Quikslide 120L page, via search): https://www.mistral.com/quikslide-120l
- Wind needed to plane by kit (intermediate on mid freeride: 14 to 16 kt to get going): https://www.windup.live/blog/wind-speed-for-windsurfing/
- Wikipedia, Windsurfing (100 to 140 L boards plane from 12 kt with 6 to 8 m2; ideal 15 to 25 kt): https://en.wikipedia.org/wiki/Windsurfing
- Wikipedia, Point of sail (fastest on a broad reach; no-go zone 30 to 50 deg; close-hauled about 45 deg): https://en.wikipedia.org/wiki/Point_of_sail
- The Windsurf Loop, "Fun With Polar Plots" (fin session best upwind about 60 deg to the wind): https://boardsurfr.blogspot.com/2021/02/fun-with-polar-plots-fin-freeride-foil.html
- The Windsurf Loop, "Maximum Speed" (planing 15 to 20 kt in marginal wind, about 4 kt off the plane): https://boardsurfr.blogspot.com/2015/08/maximum-speed.html
- rec.windsurfing thread "How Fast (Relative to Wind) do windsurfers go?" (20 to 38 kt in 15 to 20 kt when planing; about twice the wind speed in light wind), quoted from the search summary because the page returned HTTP 429: https://groups.google.com/g/rec.windsurfing/c/FLPpqUSg8XY
- Windsurf Magazine, "Speed sailing: faster faster faster" (freeride kit 45 to 48 km/h on Lake Garda), from the search summary: https://www.windsurf.co.uk/speed-sailing-faster-faster-faster/

Literature named in the legacy code and worth having at hand for Phase 4: Savitsky, "Hydrodynamic Design of Planing Hulls" (1964); Larsson and Eliasson, "Principles of Yacht Design"; Marchaj, "Sail Performance: Theory and Practice". The 2024 windsurfing velocity-prediction paper (Ocean Engineering, "Velocity prediction program for windsurfing: a hierarchical approach integrating biomechanical insights", https://www.sciencedirect.com/science/article/abs/pii/S0029801824024089) would give a measured polar, but it is paywalled and could not be read.

---

## 15. Decisions under the simulation principle, and the checks still to run

### Purpose

The plan asked the team four questions and the first draft of this document raised three more: how fast the board should go, which point of sail should be fastest, which equipment, which control modes, what the Space key does, at which height the wind speed is defined, and how fast the rig should turn the board. Under plan decision D8 (the physics is simulated, not tuned) these are not questions. The simulation answers the first two, real-world equipment answers the third, and the rest are design decisions recorded here so that Phase 2 and Phase 3 can proceed without waiting.

### 15.1 Decisions

| # | Former question | Decision | Reason |
|---|---|---|---|
| Q1 | Top speed in 15 kt | **Not chosen. It is whatever the simulation gives.** Real life says a well-powered freeride board in 15 kt reaches 35 to 45 km/h, faster than the wind (section 14, Part B). If the simulation gives 28 km/h like the Unity build, a force model is wrong and is fixed at its physical source; the number is never adjusted. | D8. The Unity 28 km/h came from a 3× submersion drag multiplier and a planing lift of 6 % of the weight (section 12). |
| Q2 | Fastest point of sail | **Not chosen. It emerges.** Real polars put it on a broad reach, 105° to 135° true wind angle, because the beam reach carries the most side force and side force costs induced drag on the sail and the fin (section 13 P7). | D8. |
| Q3 | Default equipment | **A real, common freeride setup** (section 14): a 120 L board of 2.40 × 0.72 × 0.12 m and 9 kg, a 6.5 m² sail with a 4.60 m luff and a 1.95 m boom, a 38 cm fin of 0.0365 m², a 75 kg sailor and an 8 kg rig, 92 kg in all. | This is the standard combination for a 75 kg sailor on a 15 to 20 kt day; every number has a product source in section 14. The old 3D model is scaled to it in Phase 6. |
| Q4 | Control modes | **Beginner and advanced.** Beginner: A/D steer relative to the screen (rake with the tack sign), the sailor balances the board automatically within real limits, Space is a tack assist. Advanced: Q/E rake, A/D lean the sailor's weight, no automatic balance, no assist. Every assist is documented in section 10 and switchable. | The physics is the same in both modes; the modes only change how key presses become the sailor's actions. An intermediate preset is one row in the controls config if the team ever wants it. |
| Q5 | What the Space key does | **The sail side always follows the wind** (section 2.14, with 5° of hysteresis): that is physics. Space is a manoeuvre assist in beginner mode: it holds the rake to carry the bow through the wind and centres it once the wind has crossed. In advanced mode the player steers through the wind with the rig, as in real life. | Real sails fill on the leeward side; a manual flip that lets the sail sit to windward is not physics (Unity's manual tack, section 12 F-12). |
| Q6 | Height at which the wind speed is defined | **10 m above the water**, the convention of forecasts and anemometers (WMO Guide No. 8), with the power-law profile (exponent 0.11 over open water, section 8) down to the sail. The HUD shows both the 10 m wind and the wind at the sail's centre of effort. A "15 kt" forecast puts about 12.6 kt at a 2 m centre of effort; the default game wind is therefore 18 kt at 10 m, a normal planing day. Tests state which height they mean. | Closest to real life; it also makes "the wind in the game" mean the same as "the wind in the forecast". |
| Q7 | How fast full rake turns the board | **Not chosen. It emerges** from the centre-of-effort lever, the fin's resistance to yaw and the body's inertia (section 3.3 estimates about 20°/s at full rake on a beam reach). There is no steering constant anywhere. | D8. If it feels wrong in Phase 3 the places to look are the rig geometry and the fin model, both of which have real-world values. |

Decisions for Phase 2 that supersede the "spec decision" paragraphs of sections 5 and 6 where they differ (the sections keep their legacy analysis; the implementation follows this list and records what it built in "Phase 2 implementation notes" at the end of each section):

- **Planing lift (section 5).** Savitsky's dynamic term only, `cl_d = 0.012 × tau_deg^1.1 × sqrt(lambda)`, with buoyancy from Archimedes (so the buoyant part of Savitsky's formula is not counted twice). The wetted length comes from the geometry: the transom immersion divided by the sine of the trim, clamped to the board length. The angle of attack includes the vertical velocity of the hull at the centre of pressure, which is the real heave and pitch damping of a planing surface. The force acts normal to the bottom at Savitsky's centre of pressure, so the pressure drag comes out of the geometry. No cap, no speed ramp, no smoothing. `planing_ratio` in the telemetry is the dynamic lift as a fraction of the weight and is a readout, not an input.
- **Residuary drag (section 5).** A hump curve on the buoyantly carried weight, peaking at a Froude number of about 0.55 with a height of about 9 % of that weight, from the typical hump resistance of planing craft. It is the one engineering approximation left in the hull model and is marked as such in section 5 and in the tuning log.
- **Damping (section 6).** Per sample point, from each point's own vertical velocity: linear 800 N·s/m (wave radiation, a stand-in) plus quadratic 800 N·s²/m² (flat-plate drag), scaled by the point's wet share. No lumped rotational damping, no lateral damping in the buoyancy model.
- **Sailor (section 7).** A real part of the body. The stance moves aft with speed (the sailor steps into the footstraps), the lean moves the sailor's mass to windward by up to 0.7 m, and the sailor's weight is the only righting moment. In beginner mode a balance rule chooses the lean to keep the board flat, limited to what a real sailor can do; when the sail overpowers that limit the board heels, and the honest answer is to sheet out.
- **Sail force (section 2).** Applied at the real centre of effort, at its real height (Option B), from the start. Option A is not used.

### 15.2 Model checks for Phase 4

These are not open questions and need no team input. They are the places where the model is most likely to be wrong, with the check that exposes it. A failed check is fixed at its physical source (D8).

| # | What to check | Owner section | Check |
|---|---|---|---|
| T1 | The planing lift acts at Savitsky's centre of pressure; the resulting trim at speed should be 2° to 6° bow up, without porpoising | 5 | No-porpoising check; trim at speed |
| T2 | The board gets onto the plane between 15 and 17 km/h without any built-in trim offset other than the tail rocker angle | 5 | Planing onset |
| T3 | Hull friction and residuary drag give a hump before planing and a planing resistance of the order of `lift × tan(trim)` plus friction | 5 | Polar sweep and the acceleration run |
| T4 | The sail's centre of effort at its real height, balanced by the sailor's lean, gives a steady heel and no capsize in 15 kt | 2, 7 | Heel balance and symmetry |
| T5 | Heave damping of 800 + 800 settles a drop within two oscillations; whether a heave added-mass term is needed | 6 | Drop test and the high-speed heave band |
| T6 | Fin lift slope with the hull end-plate factor of 2 and the stall curve give leeway angles of 3° to 6° when planing | 4 | Polar sweep (leeway readout) |
| T7 | Sheet versus rake authority: the centre of effort moves 0.6 m fore and aft between 12° and 85° of boom angle, more than full rake; the board must still be steerable with the sheet eased | 2, 3 | Steering checks of section 3 |
| T8 | Wind profile: with the 10 m reference the sail sees about 0.84 of the forecast wind; the HUD must show both | 8 | Unit test of the profile |
| T9 | Gerstner steepness: the legacy look (3 to 4.5 times the physical trochoid) versus the physical value once wave-relative drag is on | 9 | Phase 5 validation on waves |
| T10 | Spin-out and ventilation of the fin are not modelled; decide in Phase 4 whether the post-stall curve is enough | 4 | Play-test feel at high speed |

### 15.3 Unknowns that cannot be settled from the files

- Whether anyone tuned values in Unity's Play mode and never typed them back (Play-mode edits leave no trace). Irrelevant under D8, kept for the record.
- Whether the played Session 26 scene had `_waterViscosity` 400 (the scene) or 800 (the code default at the time); section 13.2.6.
- Why the Session 26 commit stored 22 kt of wind (section 8, OPEN 2).

---

## 16. Tuning log

Every change to a coefficient or a formula from Phase 2 onward is recorded here, newest first, with the test that motivated it. A change without a row in this table is a mistake. When a fudge from section 12 is brought back, its ID goes in the last column.

How to add a row: date, session, the config file and field (or the section and formula), the old and new value with units, the test or observation that asked for the change, and a few words on why this value and not another.

| Date | Session | Where | Old | New | Motivated by | Why this value | Fudge ID |
|---|---|---|---|---|---|---|---|
| 2 Oct 2026 | 30 | section 5, `hull_model.gd`: planing lift | Savitsky lift at one point (the centre of pressure), angle of attack from that point's velocity | Strip model: slender-body (2D+t) planing theory over 12 strips of the wet bottom, scaled to Savitsky's lift, root force spread to Savitsky's centre of pressure (17.2) | The frozen-sailor scenario: with the sailor's fore-and-aft reflex held still, the point model's pitch oscillation grew to 20 to 30 degrees in three cycles and the board capsized (`tools/simulate.sh beam_reach --freeze=40`) | A point model has no pitch damping from the water flowing aft under the hull; the strip model has it and the same run is steady | |
| 2 Oct 2026 | 30 | section 5, `hull_model.gd`: planing beam | Full board width 0.72 m | Mean width of the wet part (the tail is 0.50 m wide) | Same investigation | The lift of a short wet length near the tail used a width the tail does not have | |
| 2 Oct 2026 | 30 | section 5, `hull_model.gd`: wet span | Wet length measured from the transom; no lift with a dry transom | Wet span between the first and last wet row, interpolated; the aft wet end acts as the transom | Same investigation: in the bow-down phase of the oscillation the tail was dry and the board had no dynamic lift at all | A nose-down board planes on its middle and its nose rocker | |
| 2 Oct 2026 | 30 | section 5 and 6, `sim_rigid_body.gd`: heave added mass and pitch added inertia | None | rho pi b^2 / 8 per metre of wet bottom (about 200 kg at 1.2 m wet length) along the body's up axis, and its moment about the centre of mass in pitch | Check T5 | Strip theory; the same water whose momentum change is the planing lift | |
| 2 Oct 2026 | 30 | section 5, `hull_model.gd`: spray-root advance | None | Root force times (1 + advance / u), advance = sinking speed / tan(bottom angle), held within 0 to 2 (A-01) | Same investigation | Wagner: a sinking hull engages new water faster; a rising one lets it go | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: legs | Rigid sailor | Damped spring, natural frequency 2.0 Hz, damping ratio 0.4, travel 0.25 m | The bounce of a planing board at 1.6 Hz went straight into a rigid sailor | Measured values for a standing person (Matsumoto and Griffin 1998) | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: pitch reflex | None | 0.5 m of fore-and-aft weight shift per rad/s of pitch rate, within -0.3 to +0.5 m, at the lean rate | Porpoising before the strip model; kept because sailors do it | A person's answer to a bouncing nose; not needed for stability since the strip model | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: hang-back | None | drive_n x 1.0 m / (m g), at most 0.5 m | The board trimmed bow-down at speed with the sailor upright | Torque balance of a body hanging on the boom at 1 m above the feet | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: windage | None | cd x A = 0.5 m2 at the sailor's position | The rig's lift-to-drag ratio came out at 11 | A standing person in a wetsuit (0.6 to 0.8 m2 frontal area, cd about 0.8) | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: lean | Legacy 20 degrees of weight shift | 1.0 m outboard at full lean, centre of mass 0.5 m lower | Capsize at 6 to 9 m/s with less | A hooked-in sailor stretched out has their centre about a metre outboard | |
| 2 Oct 2026 | 30 | section 7, `sailor_config.gd`: stance | One position | 0.15 m aft at rest to 0.60 m aft (the back straps) between 3.5 and 7 m/s | Rounding up from standstill | Where sailors stand | |
| 2 Oct 2026 | 30 | section 2, `sail_config.gd`: rig lean | Rig vertical | Rig leaned to windward with the sailor, 25 degrees at full lean; the lift tilts with it | Rounding up from standstill and the capsizes | Sailors lean the rig to windward; it brings the centre of effort back over the board and gives the lift an upward part | |
| 2 Oct 2026 | 30 | section 2, `sail_config.gd`: `cd_parasitic` | 0.015 | 0.04 | Rig lift-to-drag of 11 | A complete rig with mast, boom and cambered cloth, not a bare sail | |
| 2 Oct 2026 | 30 | section 2, `sail_config.gd`: `mast_foot_local.z` | -0.05 m (section 14) | -0.10 m (0.10 m forward of the centre) | Rounding up from standstill | Within the real mast-track range of 0.05 to 0.15 m forward (section 2, OPEN 2.5) | |
| 2 Oct 2026 | 30 | section 3, `sail_config.gd`: `max_rake_deg` | 15 | 25 | Course holding needed more than 15 degrees at low speed | Sailors swing the rig through about 25 degrees each way | |
| 2 Oct 2026 | 30 | section 2, formula 2.2 | n0 = r (sail_side cos theta) - f sin theta | n0 = r (-sail_side cos theta) - f sin theta | `test_sail.gd::test_mirror_symmetry` | The spec's x-sign was wrong on port tack; the two tacks were not mirror images | |
| 2 Oct 2026 | 30 | section 4, `fin_config.gd`: `cd_plate` | None | 1.2 beyond the stall, blended in with the slip angle | Rounding up from standstill: a sideways-sliding board met no resistance from the fin | A fin at 90 degrees is a flat plate | |
| 2 Oct 2026 | 30 | section 6, `board_config.gd`: rocker line | Quadratic rocker over each half of the board | Flat planing section, 1 cm tail kick over 0.35 m, 8 cm nose rocker over 0.9 m | Bow-down trim at speed with the quadratic line | The rocker line of a freeride board | |
| 2 Oct 2026 | 30 | section 6, `buoyancy_model.gd`: yaw added inertia | None | The immersed hull's added inertia in yaw | Rounding up from standstill was too fast | Water turns with the hull | |
| 2 Oct 2026 | 29 | (none yet) | | | Phase 1 wrote the starting values; see sections 11 and 14 | | |

---

## 17. Phase 2 implementation notes

### Purpose

What the code in `Game/sim/` does where it goes beyond, or differs from, sections 0 to 9, written for whoever reads this document next to the code. Everything here is physics, not tuning (plan decision D8): each change answers a question of the form "what does the real thing do?", and the few places where the code guards a formula are listed in 17.6 with their reasons. The tuning log (section 16) has one row per change.

### 17.1 What was built

- **Rigid body** (`sim_rigid_body.gd`): six degrees of freedom, semi-implicit Euler, four substeps per 1/60 s tick (240 Hz), world-frame angular velocity with the gyroscopic term, orientation advanced by a rotation about the angular velocity axis, centre-of-mass state with the board origin at `com_offset_body`. Two additions for the sailor and the water: an added mass that acts only along the body's up axis (17.2), and an internal velocity of the board structure relative to the centre of mass (17.3).
- **Mass model** (`mass_model.gd`): three lumps as section 7 says (board box, rig rod, sailor cylinder). The sailor's lump moves with stance, lean, hang-back and knee bend.
- **Buoyancy** (`buoyancy_model.gd`): section 6 on a 7 x 3 grid, with a freeride rocker line (flat planing section, 1 cm tail kick over the last 0.35 m, 8 cm nose rocker over the last 0.9 m) instead of the legacy quadratic line, the per-point heave damping of 6.9, and the yaw added inertia of the immersed hull.
- **Hull** (`hull_model.gd`): ITTC friction, the residuary hump (9 % of the carried weight at Froude 0.55, width 0.25), sideways drag row by row, and the planing lift as a strip model (17.2).
- **Fin** (`fin_model.gd`): section 4, plus flat-plate drag (cd 1.2) blended in toward 90 degrees of slip, because a fin at 90 degrees is a plate.
- **Sail** (`sail_model.gd`): section 2 with three corrections. The normal `n0 = r (-sail_side cos theta) - f sin theta` (the spec's 2.2 had the wrong x-sign on port tack; the mirror-symmetry test caught it). `cd_parasitic = 0.04` for a complete rig (the spec's 0.015 is a bare clean sail and gave a lift-to-drag ratio of 11, which rigs do not reach). And the rig is leaned to windward with the sailor (25 degrees at full lean): the lift vector tilts with it, which brings the centre of effort back over the board and gives the lift an upward part. This is what real sailors do, and without it the board rounded up as soon as the sailor hiked.
- **Sailor** (`windsurfer_sim.gd`, `sailor_config.gd`): part of the body, as section 15 decided, and behaving like a person (17.3).
- **Wind** (`wind_field.gd`): section 8 (power law 0.11 to the 10 m reference; gusts and shifts implemented, off by default).
- **Autopilot** (`autopilot.gd`): a sailor for tests and scenarios. It only does what a sailor does with their arms: rake to hold a wind angle (with yaw-rate damping), bear away to 70 degrees until the fin has 5 m/s to work with, trim the sheet to 15 degrees of angle of attack, and ease the sheet when the hike is used up or the board heels more than 5 degrees to leeward.
- **Scenario tool**: `tools/simulate.sh <scenario> [seconds] [--wind_kt= --twa= --heading= --every= --freeze=]` writes `.sim_output/<scenario>.csv` with 48 columns. `--freeze=<s>` holds the sailor's fore-and-aft position from that time on, which is how 17.2 was diagnosed.

### 17.2 Planing lift: why section 5's point model was replaced

Section 5 applies Savitsky's lift at his centre of pressure with the angle of attack taken from the velocity of that one point. Built that way, the board planed at the right speed but **porpoised**. With the sailor's fore-and-aft reflex active it showed as a bounce of about 2 degrees of pitch and 8 cm of heave at 1.6 Hz on a beam reach; with that reflex held still (`--freeze=40`) the pitch oscillation grew from 2 to 11 to 18 to 24 degrees in three cycles of about a second, the board left the water, and it capsized. Adding, one at a time, a Wagner build-up lag, the angle of attack at the spray root, the sailor's leg suspension and the wet bottom's added mass did not cure it; some made it worse. Each was a real effect but none was the missing one.

The missing one is the **pitch damping of a planing surface**. In the slender-body ("2D+t") theory of planing (Wagner; Zarnick 1978), each metre of bottom of width `b` carries an added mass of water `m' = rho pi b^2 / 8`, and the force on a strip is the rate at which the water under it gains downward momentum as it flows aft under the hull at the forward speed `u`:

```
f_strip = -u * m' * dV/dx * dx          along the hull (V = the bottom's velocity into the water)
f_root  =  u * m' * V_root              at the spray root, where still water first meets the bottom
```

A bow-up pitch rate pushes the stern down, so `V` grows toward the stern, `dV/dx` is negative, and every strip pushes up a little more: a nose-down moment that opposes the rate. A point model cannot contain this term. With it, the frozen-sailor run is steady, and so are all three courses.

What the code does (`_apply_planing_lift`):

1. The wet span of the centreline between the first and last wet grid row (both ends interpolated). It usually starts at the transom; when the tail has lifted clear and the nose is down, it is the middle of the hull and the nose rocker, and the aft wet end plays the transom's part (the water leaves the bottom there as it would at a transom).
2. Twelve strips: position on the rocker line, local bottom normal (from the rocker slope), velocity into the water `V` from the body's velocity at that point (which contains the pitch, the heave and the pitch rate) and the water's own velocity, and `m'` from the local width (the planform taper of the buoyancy grid).
3. The convective force per strip `-u m' dV/dx dx`, by finite differences along the hull; plus `-u V dm'/dx dx` where the hull widens going aft (the nose) and nothing where it narrows (the water lets go rather than pulling); times a transom relief that falls linearly to zero over the last half beam before the aft wet end (A-02).
4. The spray-root force `u m' V_root` times the advance factor `1 + (sinking speed / tan(bottom angle)) / u`, held within 0 and 2 (A-01): a sinking hull's root runs forward along the bottom and engages new water faster; a rising hull's root retreats.
5. A three-dimensional correction: slender-body theory is two-dimensional and gives a flat plate `m' u^2 trim`; Savitsky measured real plates. Their ratio at the geometric trim (pitch + chord angle + camber angle of the wet bottom, or 1 degree, whichever is larger) scales all the forces (A-04). For a flat plate at steady trim the total is Savitsky's lift exactly (`test_hull.gd::test_planing_lift_matches_savitsky_at_a_known_state`, within 2 %).
6. The root force is spread over the strips behind the root as a triangle whose centroid is Savitsky's centre of pressure (A-03), so the steady moment is the measured one.
7. No strip may pull (A-05). Each force acts normal to the local bottom, so the pressure drag follows from the angles (`planing_drag_n`), and the centre of pressure is reported from the distribution.

Added water: the same strips give the hull's **heave added mass** (about 200 kg at 1.2 m of wet length, more than twice the windsurfer's own mass) and its **pitch added inertia** about the centre of mass. The body carries the heave added mass along its own up axis only (A-08): `a = F / m - up * (F . up) * added / (m (m + added))`.

Pitch damping check, flat plate at 7 m/s and 4 degrees pitching bow-up at 0.3 rad/s: the lift grows and the moment change is nose-down; nose-down rate: the opposite (`test_bow_up_pitch_rate_is_damped_by_the_water_under_the_hull`).

### 17.3 The sailor is part of the simulation, not of the controller

A windsurfer cannot be balanced by anyone holding still; the sailor's reflexes are part of what makes it a vehicle. They live in the simulation and are always on, in every control mode; the player gives intentions (lean more, move back, sheet in) and the simulated body does the fast part, as a real body does without thinking:

- **Stance**: the weight moves from 0.15 m aft of the centre (by the mast foot) to 0.60 m aft (the back straps) between 3.5 and 7 m/s, at 1 per second.
- **Lean**: up to 1.0 m outboard with the centre of mass 0.5 m lower, at 2 per second. The balance reflex adds `(sail heeling moment / maximum righting moment) - 4.0 x heel - 0.8 x heel rate` to the commanded lean.
- **Hang-back**: the boom pulls the sailor forward at about 1 m above the feet, and the sailor leans back until the weight balances it: `drive x 1.0 m / (m g)`, at most 0.5 m. The pitch reflex moves it forward by 0.5 m per rad/s of nose-up pitch rate (and back for nose-down), within -0.3 m. Not needed for stability since 17.2; kept because sailors do it.
- **Legs**: a standing person on a moving floor is a mass on a damped spring (2.0 Hz, damping ratio 0.4, Matsumoto and Griffin 1998). The knee bend is a state of its own, driven by the acceleration the sailor's position would get if everything were rigid, and the board shifts the other way by the sailor's share of the mass so that the centre of mass of the whole keeps its path. Travel 0.25 m either way (A-10). On flat water it does little; it exists for chop and for landings.
- **Windage**: `cd x A = 0.5 m2` at the sailor's position.
- **Rig lean**: 25 degrees to windward at full lean, as above.

The slow moves (stance, lean, hang-back) shift the mass without the momentum of the move (the board stays where it is and the centre of mass jumps; A-09). The knee flex keeps momentum because it is fast.

### 17.4 What the simulation does now (18 kt at 10 m, 16 kt at the sail; 75 kg sailor, 120 L board, 6.5 m2 sail, 365 cm2 fin)

| Course | Speed | VMG | Pitch | Heel | Planing ratio | Submersion | Leeway (fin slip) |
|---|---|---|---|---|---|---|---|
| Beam reach, TWA 99 degrees | 35.9 km/h, 19.4 kt | | 1.9 degrees | 7.7 degrees to leeward | 0.61 | 16 % | 2.4 degrees |
| Close-hauled, TWA 52 degrees | 22.7 km/h, 12.3 kt | 3.4 m/s = 6.6 kt | 1.5 degrees | 7.4 degrees to leeward | 0.45 | 27 % | 5.5 degrees |
| Broad reach, TWA 136 degrees | 21.6 km/h, 11.7 kt | | 4.4 degrees | 1.7 degrees to leeward | 0.65 | 26 % | 1.4 degrees |

All three are steady after about 20 s (pitch standard deviation below 0.01 degrees over the last 20 s) and identical on both tacks. With nobody steering (`fixed_controls`), the board rounds up and stops, as a real board does. At rest it displaces 89.8 L and floats level. Plausibility: 19 to 20 kt on a beam reach in 16 kt of wind at the sail is on the fast side for a 6.5 m2 freeride rig (real sailors see 18 to 23 kt); 6.6 kt of upwind VMG at 52 degrees is what a freeride board does. The broad reach is slower than the beam reach because the apparent wind drops, which is right.

### 17.5 The checks of section 15 so far

- **T1** passes: trim at speed 1.5 to 4.4 degrees bow up, no porpoising since 17.2 (also with the sailor's fore-and-aft reflex frozen).
- **T2** not measured yet: the planing ratio passes 0.5 about 5 s after the start on a beam reach; the speed at that moment is a Phase 4 measurement.
- **T3** passes in shape: the hump sits at Froude 0.55 (test), and the planing resistance is the pressure drag of the strips plus friction.
- **T4** passes: a steady heel of 7 to 8 degrees to leeward and no capsize in 15 to 18 kt, with the sailor's lean and the sheet doing the work.
- **T5** answered: the drop test settles (test); a heave added-mass term is needed, and it is in (17.2).
- **T6** passes: leeway 2.4 degrees on a reach, 5.5 degrees close-hauled.
- **T7** passes for the rake (the steering test holds on both tacks with the sheet trimmed); steering with the sheet eased is not tested.
- **T8** passes (profile test); the HUD part is Phase 3.
- **T9**, **T10**: Phases 5 and 4.

### 17.6 Approximations and guards in the Phase 2 code

Not fudges in the sense of section 12 (nothing here hides a symptom or lacks a mechanism), but places where the code approximates, and what would replace each.

| ID | Where | What | Why | What would replace it |
|---|---|---|---|---|
| A-01 | `hull_model.gd` | Spray-root advance factor held within 0 and 2; bottom angle floored at 1 degree | The Wagner flux formula is singular as the bottom becomes parallel to the surface (a flat slam); the added mass in the body carries the slam beyond that | A water-entry (Wagner) solution per strip |
| A-02 | `hull_model.gd` | Transom relief: the convective strip force falls linearly to zero over the last half beam before the aft wet end | 2D+t has no pressure relief at a transom; this is the usual near-transom correction (Garme 2005 uses a similar one) | A 3D transom solution |
| A-03 | `hull_model.gd` | The root force spread as a triangle whose centroid is Savitsky's centre of pressure | The theory puts it at the stagnation line; measurements put the centre of pressure at 0.70 to 0.75 of the wet length; a deadrise section would spread it by itself | Sectional added mass that grows with immersion (chines-dry phase) |
| A-04 | `hull_model.gd` | Three-dimensional factor evaluated at max(geometric trim, 1 degree) | Avoids 0/0 at zero trim; the ratio varies slowly (about trim^0.1 x sqrt(lambda)) | Nothing needed |
| A-05 | `hull_model.gd` | No strip may pull | A planing bottom ventilates rather than sucking | Nothing needed |
| A-06 | `hull_model.gd` | The wet bottom's camber as a thin-airfoil arc (2 x sag / length) in the reference trim | No planing-camber data exist for boards | Measurements of rockered planing plates |
| A-07 | `hull_model.gd`, `buoyancy_model.gd` | 12 strips; a 9-point width average; the wet span from 7 grid rows with interpolation | Resolution choices; the 0.4 m row spacing limits how finely the wet length is known | More rows (costs little) |
| A-08 | `sim_rigid_body.gd` | Added mass along the body's up axis and in pitch only; no heave-pitch coupling term, no roll added inertia | Keeps the integrator a rigid body with one correction | A full added-mass matrix |
| A-09 | `windsurfer_sim.gd` | Stance, lean and hang-back shift the mass without the momentum of the move | Slow moves | Treating the sailor as a second body |
| A-10 | `windsurfer_sim.gd` | The knee bend stops at 0.25 m either way without energy accounting | Legs have a range | Nothing needed |
| A-11 | `fin_model.gd` | Flat-plate drag blended in toward 90 degrees of slip | A fin at 90 degrees is a plate; the blend is a shape choice | Measured post-stall data of a fin |
| A-12 | `sail_model.gd`, `windsurfer_sim.gd` | The rig lean tied to the sailor's lean (25 degrees at full lean) | A sailor's habit written as a fixed coupling | A rig-lean control of its own |
| A-13 | `hull_model.gd` | The residuary hump (9 % at Froude 0.55, width 0.25) | The one fitted curve in the hull model, as section 15 says | A wave-resistance calculation |
| A-14 | `buoyancy_model.gd` | Heave damping 800 + 800 (6.9) that fades with the wet share | Stands in for wave radiation at rest | Radiation damping from the wave model (Phase 5) |

