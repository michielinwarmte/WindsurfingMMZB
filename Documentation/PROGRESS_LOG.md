# 📊 Progress Log

This document tracks our development progress, decisions made, and lessons learned.

---

## 📌 Quick Status Summary

**Last Session**: December 26, 2025 - Session 12 (Validation, Controls & Physics Tuning)  
**Current Phase**: Core Physics Complete + Playability Improvements

### Scripts Completed (17 total)

| Category | Scripts |
|----------|---------|
| Water | `IWaterSurface`, `WaterSurface` |
| Wind | `IWindProvider`, `WindManager` |
| Buoyancy | `BuoyancyBody` |
| Board | `Sail`, `ApparentWindCalculator`, `WaterDrag`, `FinPhysics` |
| Player | `WindsurferController`, `WindsurferControllerV2` |
| Camera | `ThirdPersonCamera` |
| UI | `TelemetryHUD`, `SailPositionIndicator`, `WindIndicator3D` |
| Visual | `SailVisualizer` |
| Utilities | `PhysicsHelpers`, `WaterGridMarkers` |

### Key Decisions Made
- ✅ Unity 6.3 LTS with URP
- ✅ New Input System (not legacy)
- ✅ Namespace: `WindsurfingGame.*`
- ✅ Simulation drives visualization (not vice versa)
- ✅ Two control modes: Beginner (context-aware, auto-stabilize) / Advanced (manual)
- ✅ Beginner mode is default with auto-sheet and stabilization
- ✅ No-go zone physics prevents unrealistic backward sailing

### Current Status
- ✅ Core physics validated and working
- ✅ Steering properly tuned (smooth and controllable)
- ✅ Planing behavior implemented with proper drag reduction
- ✅ No-go zone prevents sailing directly into wind
- ✅ Auto-stabilization keeps board going straight
- ✅ Visual sail representation shows mast rake and power

### Ready for Next Session
- [ ] Add water visual improvements (shader, foam, reflections)
- [ ] Add sound effects (wind, water, sail)
- [ ] Create basic environment (skybox, islands, buoys)
- [ ] Improve planing visual feedback
- [ ] Consider adding spray/splash particle effects

### For New Team Members
See [CONTRIBUTING.md](../CONTRIBUTING.md) and [ARCHITECTURE.md](ARCHITECTURE.md)

---

## December 26, 2025 - Session 12

### Session: Validation, Controls & Physics Tuning

**What we did:**
- ✅ Validated core physics simulation in Unity (first full playtest!)
- ✅ Fixed steering sensitivity issues through multiple iterations
- ✅ Implemented context-aware beginner controls (auto-adjusts rake based on wind side)
- ✅ Added prominent control mode display in HUD (cyan text at top)
- ✅ Implemented 5-point auto-stabilization system for straight-line sailing
- ✅ Added intelligent auto-sheet functionality with rotation correction
- ✅ Implemented no-go zone physics (0-45° from wind = stall, no backward motion)
- ✅ Fixed planing drag reduction (85% less drag when planing)
- ✅ Enabled sail visualization for real-time feedback

**Control System Evolution:**

| Iteration | Issue | Fix Applied |
|-----------|-------|-------------|
| Initial | Barely any steering (120-130° range only) | Increased rake torque to 3.5, added base torque |
| Second | Too sensitive, twitchy | Reduced to 2.0, lowered weight shift to 20 |
| Third | Still too sensitive | Reduced to 1.2, lowered weight shift to 12 |
| Final | Smooth control achieved | Reduced to 0.6, removed base torque |

**Beginner Mode Features:**
- **Context-aware steering**: A/D automatically chooses correct rake direction based on wind side
  - Wind from starboard: D rakes back (turn right), A rakes forward (turn left)
  - Wind from port: D rakes forward (turn right), A rakes back (turn left)
  - Result: Intuitive "left/right" controls regardless of tack
- **5-Point Stabilization**: Centers mast, neutralizes weight/edge, damps rotation, corrects with rake
- **Auto-sheet**: Optimizes sail angle for point of sail + counters rotation
- **Q/E disabled**: Prevents confusion with automatic rake control

**Physics Improvements:**

| System | Before | After | Impact |
|--------|--------|-------|--------|
| Rake Torque | 0.5 → 3.5 → 2.0 → 1.2 → 0.6 | Final: 0.6 | Smooth, controllable steering |
| Base Torque | 50N constant | Removed | Eliminated twitchiness |
| Weight Shift | 15 → 35 → 20 → 12 | Final: 12 | Gentle turning assistance |
| Forward Drag | 0.15 | 0.08 | Higher top speed |
| Planing Multiplier | 0.4 | 0.15 | 85% drag reduction when planing |
| No-Go Zone | None | < 45° = stall | Realistic sailing constraints |

**Auto-Stabilization System:**
1. **Mast centering**: Returns rake to neutral
2. **Weight neutralization**: Returns body to center
3. **Edge flattening**: Removes board tilt
4. **Angular damping**: 15x counter-torque + 15% velocity reduction
5. **Active rake correction**: Dynamic corrections based on rotation direction

**New Physics Behaviors:**
- **No-go zone** (< 45° from wind): Board stalls, no propulsive force, light backward drag
- **Stall prevention**: Forces that would push backward are zeroed out
- **Planing breakthrough**: Dramatic speed increase above 4 m/s (~8 knots)
- **Realistic sailing**: Can't point directly into wind, must tack at angles

**Files Modified:**

| File | Changes |
|------|---------|
| `Sail.cs` | Rake torque tuning, no-go zone implementation, backward force prevention |
| `WindsurferControllerV2.cs` | Context-aware steering, 5-point stabilization, auto-sheet |
| `TelemetryHUD.cs` | Prominent control mode display |
| `WaterDrag.cs` | Improved planing effectiveness (0.08 drag, 0.15 multiplier) |

**Parameters - Final Tuning:**

**Sail.cs:**
- Rake Speed: 5.0 (fast response)
- Rake Torque Multiplier: 0.6 (gentle steering)
- Max Rake Angle: 15°

**WindsurferControllerV2.cs:**
- Weight Shift Strength: 12
- Max Lean Angle: 30°
- Stabilization Strength: 5.0
- Auto-Sheet: ON (default)
- Auto-Stabilize: ON (default)
- Beginner rake multiplier: 0.25
- Beginner weight multiplier: 0.15

**WaterDrag.cs:**
- Forward Drag: 0.08
- Planing Speed: 4 m/s
- Planing Drag Multiplier: 0.15

**Testing Results:**
- ✅ Board goes straight with no input
- ✅ Smooth, predictable turning with A/D
- ✅ Auto-stabilization returns to course after turns
- ✅ Can sail upwind at 45-60° angles
- ✅ Stalls realistically in no-go zone
- ✅ Planing provides dramatic speed increase
- ✅ Top speeds of 15-25 knots achievable
- ✅ Intuitive controls work on both tacks

**Lessons Learned:**
- ⚠️ Rake-based steering is very powerful - needs careful tuning
- ⚠️ Base torque components add twitchiness - removed for smoother feel
- ⚠️ Context-aware controls make tacking much more intuitive
- ⚠️ Auto-stabilization needs multiple systems working together (not just damping)
- ⚠️ No-go zone is critical for realistic sailing behavior
- ⚠️ Planing needs significant drag reduction to feel impactful (85%+ reduction)

**Next steps:**
- [ ] Add visual polish (water shader, foam, spray effects)
- [ ] Implement sound system (wind, water, sail flapping)
- [ ] Create environment (skybox, islands, course markers)
- [ ] Add planing visual feedback (board angle, spray)
- [ ] Consider AI opponents for racing

---

*End of December 26, 2025 session*

---

## December 19, 2025

### Session: Project Initialization

**What we did:**
- ✅ Created project documentation structure
- ✅ Wrote README.md with project overview
- ✅ Created Development Plan (DEVELOPMENT_PLAN.md)
- ✅ Created Physics Design document (PHYSICS_DESIGN.md)
- ✅ Created Code Style Guide (CODE_STYLE.md)
- ✅ Set up .gitignore for Unity

**Decisions made:**
- Using Unity 6.3 LTS as game engine
- Using Universal Render Pipeline (URP) for graphics
- Physics-based simulation approach
- Iterative development with phases

**Next steps:**
- [ ] Create Unity project
- [ ] Set up URP
- [ ] Create basic test scene
- [ ] Add placeholder objects

**Design Decisions Made:**
- ✅ Camera: Third-person perspective
- ✅ Environment: 1 km² open water for initial testing
- ✅ Game Mode: Free roam first → Slalom racing with AI as end goal
- ✅ Physics: Realistic simulation is essential (core of the project)
- ✅ Controls: Start simple, add advanced controls + assists later
- ✅ Multiplayer: Single-player first, multiplayer later

---

## Template for Future Entries

```markdown
## [Date]

### Session: [Topic]

**What we did:**
- Item 1
- Item 2

**Problems encountered:**
- Problem and how we solved it

**Decisions made:**
- Decision and reasoning

**Next steps:**
- [ ] Task 1
- [ ] Task 2

**Lessons learned:**
- Insight gained
```

---

## December 19, 2025 - Session 2

### Session: Phase 1 - Core Foundation Scripts

**What we did:**
- ✅ Completed Unity project setup with URP
- ✅ Created folder structure in Assets/Scripts
- ✅ Created `IWaterSurface` interface for water height queries
- ✅ Created `WaterSurface` component with basic wave support
- ✅ Created `BuoyancyBody` component with multi-point sampling
- ✅ Created `ThirdPersonCamera` for following the board
- ✅ Created `PhysicsHelpers` utility class with constants

**Scripts Created:**
| Script | Location | Purpose |
|--------|----------|---------|
| `IWaterSurface.cs` | Physics/Water/ | Interface for water height queries |
| `WaterSurface.cs` | Physics/Water/ | Main water component |
| `BuoyancyBody.cs` | Physics/Buoyancy/ | Makes objects float realistically |
| `ThirdPersonCamera.cs` | Camera/ | Follows the windsurfer |
| `PhysicsHelpers.cs` | Utilities/ | Constants and helper methods |

**Next steps:**
- [x] Set up test scene in Unity with WaterSurface
- [x] Add BuoyancyBody to test object
- [x] Test and tune buoyancy parameters
- [ ] Create placeholder windsurf board model

**Issue Encountered:**
- ❌ Cube didn't float - stopped on top of water plane
- **Root Cause**: Water plane's Mesh Collider was blocking the cube
- **Solution**: Disable/remove the Mesh Collider from water plane - buoyancy handles floating, not collision!

**Documentation Added:**
- Created `TEST_SCENE_SETUP.md` with detailed step-by-step instructions

---

## December 19, 2025 - Session 3

### Session: Phase 1 Completion & Physics Discussion

**What we did:**
- ✅ Fixed buoyancy test - disabled water collider
- ✅ Verified floating cube works correctly
- ✅ Discussed future physics improvements

**Physics Evolution Plan:**
The current `BuoyancyStrength` parameter is a **temporary simplification** for quick testing.

Future iterations will replace it with real physics:

| Phase | Approach | Parameters |
|-------|----------|------------|
| Current | Force multiplier | `buoyancyStrength` (arbitrary) |
| Phase 3 | Volume-based | `displacedVolume`, `waterDensity` |
| Advanced | Mesh sampling | Actual hull geometry |

Real buoyancy formula: `F = ρ × V × g`
- ρ = water density (1025 kg/m³ for seawater)
- V = submerged volume (calculated from geometry)
- g = gravity (9.81 m/s²)

**Next steps:**
- [x] Create windsurf board prefab with proper proportions
- [x] Implement wind system (WindManager)
- [x] Add basic sail force calculation

---

## December 19, 2025 - Session 4

### Session: Wind System & Board Physics

**What we did:**
- ✅ Created `IWindProvider` interface
- ✅ Created `WindManager` with variable wind/gusts
- ✅ Created `ApparentWindCalculator` (true wind - velocity)
- ✅ Created `Sail` component with lift/drag physics
- ✅ Created `WindsurferController` for player input
- ✅ Created `WaterDrag` for realistic deceleration

**Scripts Created:**
| Script | Location | Purpose |
|--------|----------|---------|
| `IWindProvider.cs` | Physics/Wind/ | Interface for wind systems |
| `WindManager.cs` | Physics/Wind/ | Global wind with variation |
| `ApparentWindCalculator.cs` | Physics/Board/ | Calculates felt wind |
| `Sail.cs` | Physics/Board/ | Sail lift/drag forces |
| `WaterDrag.cs` | Physics/Board/ | Speed-dependent drag |
| `WindsurferController.cs` | Player/ | Player input handling |

**Physics Concepts Implemented:**
- **Apparent Wind**: Wind felt = True wind - Your velocity
- **Sail Lift/Drag**: Using airfoil coefficients based on angle of attack
- **Quadratic Drag**: Drag increases with square of speed
- **Planing**: Reduced drag at higher speeds

**Controls:**
| Key | Action |
|-----|--------|
| A/D | Steer left/right |
| W | Sheet in (more power) |
| S | Sheet out (less power) |

**Next steps:**
- [ ] Test wind and sail in Unity
- [ ] Create windsurf board prefab
- [ ] Tune physics parameters
- [ ] Add speed UI display

---

## December 19, 2025 - Session 5

### Session: Telemetry & Visual Feedback

**What we did:**
- ✅ Created `TelemetryHUD` - on-screen speed/wind/sail display
- ✅ Created `WindIndicator3D` - 3D arrows showing wind direction
- ✅ Created `WaterGridMarkers` - buoys and reference points
- ✅ Updated documentation with setup instructions

**Scripts Created:**
| Script | Location | Purpose |
|--------|----------|---------|
| `TelemetryHUD.cs` | UI/ | On-screen telemetry display |
| `WindIndicator3D.cs` | UI/ | 3D wind arrows above board |
| `WaterGridMarkers.cs` | Utilities/ | Buoys and grid markers |

**Features Added:**
- Real-time speed display (km/h and knots)
- True wind and apparent wind indicators
- Point of sail indicator (close-hauled, beam reach, etc.)
- Planing status indicator
- Sail force display
- Wind compass with board heading
- Grid of buoys for spatial reference
- Cardinal direction markers (N/S/E/W)
- Distance rings at 100m, 250m, 500m
- Toggle HUD with H key

**Next steps:**
- [x] Test the telemetry in Unity
- [x] Verify all displays work correctly
- [x] Fine-tune physics based on telemetry feedback
- [ ] Consider adding more visual polish (sail mesh, water shader)

---

## December 19, 2025 - Session 6

### Session: Fin Physics & Tracking

**What we did:**
- ✅ Created `FinPhysics` component with realistic hydrodynamic lift
- ✅ Added slip angle calculation (angle between heading and velocity)
- ✅ Implemented tracking force (board aligns with velocity)
- ✅ Added stall behavior (fin loses grip at high slip angles)
- ✅ Updated `TelemetryHUD` to show fin status
- ✅ Adjusted `WaterDrag` to work with fin (reduced lateral drag)

**Physics Concepts Implemented:**
- **Slip Angle**: Angle between where board points and where it's going
- **Hydrodynamic Lift**: Fin generates force proportional to speed² and slip angle
- **Tracking**: Board naturally wants to follow its velocity
- **Stall**: Fin loses grip above ~25° slip angle

**Key Formulas:**
```
Fin Lift = 0.5 × ρ × V² × A × Cl(slip_angle)

Where:
  ρ = water density (1025 kg/m³)
  V = board speed
  A = fin area (~0.04 m²)
  Cl = lift coefficient (varies with slip angle)
```

**New Telemetry:**
- Slip Angle: How much the board is sliding sideways
- Grip %: Overall tracking efficiency
- TRACKING/SLIDING status indicator

**Next steps:**
- [ ] Test fin physics in Unity
- [ ] Add FinPhysics component to board
- [ ] Tune fin parameters for realistic feel

**Bug Fixed:**
- ❌ CS0118 error: 'Camera' is a namespace but is used like a type
- **Root Cause**: Our namespace `WindsurfingGame.Camera` conflicted with Unity's `Camera` class
- **Solution**: Renamed namespace to `WindsurfingGame.CameraSystem` and used `UnityEngine.Camera` for explicit references

**Bug Fixed:**
- ❌ InvalidOperationException: Using UnityEngine.Input with Input System package
- **Root Cause**: Project uses Unity's new Input System, but code used old `Input` class
- **Solution**: Updated `WindsurferController.cs` and `TelemetryHUD.cs` to use `UnityEngine.InputSystem` with `Keyboard.current`

---

## December 19, 2025 - Session 7

### Session: Mast Rake Steering (Sail-Based Steering)

**Problem Identified:**
- ❌ Board couldn't point upwind effectively
- User reported: "impossible to steer into the wind and go upwind"
- **Root Cause**: Only had rail-based steering (A/D keys), missing sail position steering

**What we did:**
- ✅ Added mast rake control to `Sail.cs`
- ✅ Added Q/E input for mast rake in `WindsurferController.cs`
- ✅ Updated `TelemetryHUD` to show mast rake status
- ✅ Implemented auto-centering when no input

**How Real Windsurfing Steering Works:**
1. **Railing/Edging** (A/D) - Tilts the board to engage rail and fin
2. **Mast Rake** (Q/E) - Shifts Center of Effort relative to fin
   - Rake BACK (E) → CE moves closer to fin → Board turns UPWIND
   - Rake FORWARD (Q) → CE moves away from fin → Board turns DOWNWIND

**Physics Implementation:**
```
Steering Torque = -mastRake × sailForce × torqueMultiplier

Where:
  mastRake = -1 (forward) to +1 (back)
  sailForce = magnitude of sail force in Newtons
  torqueMultiplier = tuning parameter (default 0.5)
```

**New Controls:**
| Key | Action | Effect |
|-----|--------|--------|
| Q | Rake mast forward | Bear away (turn downwind) |
| E | Rake mast back | Head up (turn upwind) |
| (release) | Auto-center | Mast returns to neutral |

**Files Modified:**
| File | Changes |
|------|---------|
| `Sail.cs` | Added mast rake, rake offset, steering torque |
| `WindsurferController.cs` | Added Q/E input, ApplyMastRake() |
| `TelemetryHUD.cs` | Added mast rake display in sail section |

**New Sail Parameters:**
- `Mast Rake` - Current rake position (-1 to +1)
- `Max Rake Offset` - How far CE shifts (default 1.0m)
- `Rake Speed` - How quickly sailor can rake (default 2.0)
- `Rake Torque Multiplier` - Steering strength (default 0.5)

**Next steps:**
- [x] Test mast rake steering in Unity
- [x] Verify upwind sailing is now possible
- [x] Tune rake parameters for realistic feel
- [ ] Consider adding visual mast tilt feedback

---

## December 20, 2025 - Session 8

### Session: Physics Validation & Improved Controls

**Problem Identified:**
- ❌ Hard to control the board when turning
- **Root Cause**: Three steering systems fighting each other:
  1. `ApplySteering()` - Direct torque from A/D
  2. `ApplyEdging()` - Used MoveRotation (overrides physics!)
  3. `ApplyRakeTorque()` - Torque from mast rake

**What we did:**
- ✅ Reviewed ALL physics systems for validation
- ✅ Created comprehensive Physics Validation document
- ✅ Created new `WindsurferControllerV2.cs` with improved controls
- ✅ Added two control modes: Beginner and Advanced
- ✅ Fixed edging to use AddTorque instead of MoveRotation
- ✅ Updated TelemetryHUD for new controller

**Physics Systems Validated:**
| System | Status | Notes |
|--------|--------|-------|
| Buoyancy | ✅ | Multi-point, damped |
| Wind | ✅ | True + apparent + gusts |
| Sail | ✅ | Lift/drag, mast rake |
| Water Drag | ✅ | Directional, planing |
| Fin | ✅ | Slip angle, stall, tracking |

**New Controller V2 Features:**

| Feature | Beginner Mode | Advanced Mode |
|---------|---------------|---------------|
| Primary Steer | A/D (combined) | Q/E (mast rake) |
| Secondary Steer | Q/E (optional) | A/D (weight shift) |
| Sheet | W/S | W/S |
| Switch Mode | Tab | Tab |
| Anti-Capsize | ON | Configurable |
| Combined Input | ON | OFF |

**Key Technical Fixes:**
```csharp
// OLD (fights physics):
_rigidbody.MoveRotation(...);

// NEW (works WITH physics):
_rigidbody.AddTorque(transform.forward * rollTorque, ForceMode.Force);
```

**Files Created:**
| File | Purpose |
|------|---------|
| `WindsurferControllerV2.cs` | New unified control system |
| `PHYSICS_VALIDATION.md` | Complete physics review document |

**Files Modified:**
| File | Changes |
|------|---------|
| `TelemetryHUD.cs` | Added V2 controller support, mode display |

**To Use New Controller:**
1. Select WindsurfBoard in Hierarchy
2. Remove or disable `WindsurferController` (V1)
3. Add Component → `WindsurferControllerV2`
4. Press Tab in game to toggle Beginner/Advanced mode

**Recommended Settings for Easy Control:**
- Control Mode: Beginner
- Anti-Capsize: ON
- Combined Steering: ON
- Weight Shift Strength: 15-20

**Next steps:**
- [x] Test new controller in Unity
- [ ] Compare Beginner vs Advanced mode
- [ ] Tune parameters for best feel
- [ ] Consider gamepad support

---

## December 20, 2025 - Session 9

### Session: Sail Visual Representation

**What we did:**
- ✅ Created `SailVisualizer.cs` - 3D visual sail with mast, boom, and sail mesh
- ✅ Created `SailPositionIndicator.cs` - 2D HUD showing top-down sail view

**SailVisualizer Features (3D):**
- Dynamic mast that tilts with rake input
- Boom that rotates with sheet position
- Triangular sail mesh that follows boom angle
- Sail color changes based on power (force generated)
- Billowing effect when powered up
- Auto-detects which side sail should be on (based on wind)

**SailPositionIndicator Features (2D HUD):**
- Top-down view of board and sail
- Shows mast position (forward/center/back)
- Shows sail angle based on sheet position
- Color intensity shows power
- Small wind direction arrow
- Labels for rake and sheet percentage

**Visual Elements Created:**

| Element | Description |
|---------|-------------|
| Mast | Gray cylinder, tilts with rake (Q/E) |
| Boom | Dark gray cylinder, rotates with sheet (W/S) |
| Sail | Orange triangle mesh, billows with power |
| HUD | Top-down view in bottom-left corner |

**To Add These Visuals:**

1. **3D Sail on Board:**
   - Select WindsurfBoard
   - Add Component → `SailVisualizer`
   - Adjust colors if desired

2. **2D HUD Indicator:**
   - Select Canvas (or any GameObject)
   - Add Component → `SailPositionIndicator`
   - Position defaults to bottom-left

**Files Created:**
| File | Purpose |
|------|---------|
| `SailVisualizer.cs` | 3D sail mesh visualization |
| `SailPositionIndicator.cs` | 2D HUD sail position display |

**Next steps:**
- [x] Test visuals in Unity
- [x] Fix sail direction and mast rake behavior
- [ ] Tune sail colors and sizes
- [ ] Consider adding sailor model
- [ ] Add water splash effects

---

## December 20, 2025 - Session 10

### Session: Sail Visual Fixes

**Problems Identified:**
1. ❌ Sail was pointing the WRONG WAY (forward instead of backward)
2. ❌ Mast rake was moving the mast base position instead of rotating around it

**Real Windsurfing Physics:**
- Mast foot is FIXED to the board (via universal joint)
- Standard mast position: ~1.2m from the back of the board
- Rake tilts the mast forward/back around this fixed pivot point
- Sail/boom extends BACKWARD from the mast, angled to the side

**Fixes Applied:**

| Issue | Before | After |
|-------|--------|-------|
| Mast base | Moved with rake | Fixed at 1.2m from tail |
| Rake effect | Base moved fore/aft | Mast tilts around fixed base |
| Sail direction | Forward (+Z) | Backward (-Z) |
| Sail side | Inverted | Correct (leeward of wind) |

**SailPositionIndicator (2D HUD) Changes:**
- Added `_boardLengthMeters` (2.5m) and `_mastFromTail` (1.2m) settings
- Mast base now draws at fixed position relative to tail
- Rake shows as boom attachment point moving fore/aft (mast tilt)
- Sail now correctly extends backward toward tail

**SailVisualizer (3D) Changes:**
- Mast base position fixed at (0, 0.1, -0.05) - realistic for 2.5m board
- Sail mesh vertices now use negative Z (backward direction)
- Boom extends backward then rotates to the side
- Billow effect correctly goes to leeward side

**Files Modified:**
| File | Changes |
|------|---------|
| `SailPositionIndicator.cs` | Fixed sail direction, fixed mast base, added board dimensions |
| `SailVisualizer.cs` | Fixed sail mesh vertices, fixed boom direction, realistic mast position |

**Visual Representation Now Shows:**
- Nose at top (2D) / front (+Z in 3D)
- Tail at bottom (2D) / back (-Z in 3D)
- Mast fixed near center, slightly back from middle
- Sail extending backward from mast, angled to leeward
- Rake tilts mast (boom attachment moves), base stays fixed

---

## December 20, 2025 - Session 11

### Session: Sail Physics Simulation Fix

**Problem Identified:**
- ❌ Previous session only fixed the VISUALIZATION, not the simulation
- ❌ Indicators should represent the simulated situation, not calculate independently
- Principle: Visualization reflects simulation, never calculates its own values

**Core Issue:**
The sail physics in `Sail.cs` needed to properly model sail geometry:
- Leading edge (luff) is at the mast - this is the ROTATION POINT
- Trailing edge (leech) extends BACKWARD toward the tail
- Sheet position controls sail angle around the mast
- Center of Effort is on the sail, behind the mast

**Simulation Fixes (Sail.cs):**

1. **Sail Geometry Model:**
   - Mast foot position is now explicit and fixed
   - Boom length and height are configurable
   - Sail rotates around mast (not an arbitrary point)

2. **Sail Angle Calculation:**
   - Wind direction determines which side the sail goes (leeward)
   - Sheet position controls how far from centerline (15° to 80°)
   - `CurrentSailAngle` property exposed for visualization to read

3. **Center of Effort Calculation:**
   - Starts at mast foot (fixed)
   - Goes up to boom height with rake applied
   - Extends backward along sail at current angle
   - CE is 60% along boom length
   - Rake tilts entire mast around fixed foot

4. **Sail Normal Calculation:**
   - Based on sail chord (luff to leech)
   - Normal is perpendicular to sail plane in horizontal plane

**Visualization Updates:**
- `SailVisualizer.cs`: Now reads `_sail.CurrentSailAngle` from simulation
- `SailPositionIndicator.cs`: Now reads `_sail.CurrentSailAngle` from simulation
- Both visualizers no longer calculate sail angle independently

**Key Principle Reinforced:**
```
Simulation → Visualization (one-way data flow)

✗ WRONG:  Visualizer calculates sail angle based on wind
✓ RIGHT:  Visualizer reads sail angle from Sail.cs simulation
```

**New Properties in Sail.cs:**
| Property | Type | Purpose |
|----------|------|---------|
| `CurrentSailAngle` | float | The simulated sail angle for visualization |
| `MastFootPosition` | Vector3 | Fixed mast foot position on board |
| `CurrentCenterOfEffort` | Vector3 | World position of CE (for debugging) |

**Files Modified:**
| File | Changes |
|------|---------|
| `Sail.cs` | Major refactor: sail geometry, CE calculation, exposed CurrentSailAngle |
| `SailVisualizer.cs` | Now reads from simulation instead of calculating |
| `SailPositionIndicator.cs` | Now reads from simulation instead of calculating |
| `PHYSICS_DESIGN.md` | Added Sail Geometry and Center of Effort sections |

**Lessons Learned:**
- ⚠️ Visualization must always reflect simulation state
- ⚠️ Never duplicate physics calculations in visualization code
- ⚠️ Fix the source (simulation) first, not the output (visualization)

**Next steps:**
- [ ] Test simulation in Unity
- [ ] Verify forces are applied correctly at CE
- [ ] Check steering behavior with corrected CE
- [ ] Fine-tune sail physics parameters

---

## December 20, 2025 - Session 11 (Continued)

### Session: Documentation & Team Prep

**What we did:**
- ✅ Fixed Sail.cs gizmo error (`_CenterOfEffort` → `_currentCE`)
- ✅ Created comprehensive ARCHITECTURE.md with codebase reference
- ✅ Updated DEVELOPMENT_PLAN.md with team collaboration guidelines
- ✅ Created CONTRIBUTING.md for new team members
- ✅ Updated README.md with current status and all documentation links
- ✅ Added Quick Status Summary to PROGRESS_LOG.md
- ✅ Verified all scripts compile without errors

**Documentation Structure:**

| Document | Purpose |
|----------|---------|
| README.md | Project overview, getting started |
| CONTRIBUTING.md | Team workflow, how to contribute |
| Documentation/ARCHITECTURE.md | **Codebase reference** - namespaces, dependencies, data flow |
| Documentation/DEVELOPMENT_PLAN.md | Phased roadmap + team guidelines |
| Documentation/PHYSICS_DESIGN.md | Physics equations and concepts |
| Documentation/CODE_STYLE.md | Coding standards |
| Documentation/PROGRESS_LOG.md | Session-by-session log |
| Documentation/UNITY_SETUP_GUIDE.md | Unity project setup |
| Documentation/TEST_SCENE_SETUP.md | Test scene configuration |
| Documentation/PHYSICS_VALIDATION.md | Physics testing checklist |

**Team Collaboration Features Added:**
- Git workflow with feature/bugfix branches
- File ownership areas to avoid conflicts
- Commit message format guidelines
- Checklist for new team members
- Unity-specific collaboration guidelines

**Scripts Status (17 scripts, all compiling):**
```
Physics (9):     IWaterSurface, WaterSurface, IWindProvider, WindManager,
                 BuoyancyBody, Sail, ApparentWindCalculator, WaterDrag, FinPhysics
Player (2):      WindsurferController, WindsurferControllerV2
Camera (1):      ThirdPersonCamera
UI (3):          TelemetryHUD, SailPositionIndicator, WindIndicator3D
Visual (1):      SailVisualizer
Utilities (2):   PhysicsHelpers, WaterGridMarkers
```

**For Next Session:**
1. Open Unity and test the simulation
2. Verify sail forces feel correct
3. Test steering with mast rake
4. Begin work on board planing behavior
5. Consider water visual improvements

**For New Team Members:**
1. Start with CONTRIBUTING.md
2. Read ARCHITECTURE.md for codebase overview
3. Check this Progress Log for context
4. Create feature branches for all work

---

*End of December 20, 2025 sessions*

---

*This log is updated after each development session.*
