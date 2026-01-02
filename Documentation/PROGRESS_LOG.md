# 📊 Progress Log

This document tracks our development progress, decisions made, and lessons learned.

---

## 📌 Quick Status Summary

**Last Session**: January 2, 2026 - Session 26 (Major Cleanup & Bug Fixes)  
**Current Phase**: Core Physics Complete ✅ | Production Ready

### Physics Status: VALIDATED ✅

The core physics are working correctly:
- ✅ Upwind sailing on both tacks
- ✅ Planing at high speeds (~17+ km/h onset)
- ✅ Rake steering works correctly
- ✅ High-speed stability (20+ knots)
- ✅ Tacking/side switching
- ✅ Realistic buoyancy (Archimedes' principle)
- ✅ Displacement lift (pre-planing support)
- ✅ Sailor COM shifts AFT when planing
- ✅ **Savitsky planing equations** (proper hydrodynamic lift)
- ✅ **Port tack steering auto-inverts** (Session 26 fix)
- ✅ **No more porpoising** (CE at zero, planing at center)

### ⚠️ Known Issues (See [KNOWN_ISSUES.md](KNOWN_ISSUES.md))

| Issue | Severity | Workaround |
|-------|----------|------------|
| Camera only works after changing FOV | 🟡 Known Issue | Change FOV in Inspector during play |
| Half-wind submersion at low speeds | 🟡 Medium | Get up to planing speed quickly |

**Critical formulas documented in:** [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md)

### Scripts Completed (35 total - cleaned up!)

| Category | Scripts |
|----------|---------|
| Physics Core | `PhysicsConstants`, `Aerodynamics`, `Hydrodynamics`, `SailingState` |
| Water | `IWaterSurface`, `WaterSurface` |
| Wind | `IWindProvider`, `WindManager` (legacy), `WindSystem` ⭐ |
| Buoyancy | `BuoyancyBody` (legacy), `AdvancedBuoyancy` ⭐, `BoardMassConfiguration` |
| Board | `Sail` (legacy), `ApparentWindCalculator`, `WaterDrag` (legacy), `FinPhysics` (legacy), `AdvancedSail` ⭐, `AdvancedFin` ⭐, `AdvancedHullDrag` ⭐ |
| Player | `WindsurferControllerV2` (legacy), `AdvancedWindsurferController` ⭐ |
| Camera | `ThirdPersonCamera` (legacy), `SimpleFollowCamera` ⭐ |
| UI | `SailPositionIndicator`, `WindIndicator3D`, `AdvancedTelemetryHUD` ⭐ |
| Visual | `SailVisualizer`, `EquipmentVisualizer` ⭐, `ForceVectorVisualizer`, `WindDirectionIndicator` |
| Debug | `PhysicsValidation`, `SailPhysicsDebugger` |
| Utilities | `PhysicsHelpers`, `WaterGridMarkers` |
| Editor | `WindsurferSetup` |

> **Removed in Session 26:** `WindsurferController` (V1), `TelemetryHUD`

### Key Decisions Made
- ✅ Unity 6.3 LTS with URP
- ✅ New Input System (not legacy)
- ✅ Namespace: `WindsurfingGame.*`
- ✅ Simulation drives visualization (not vice versa)
- ✅ Three control modes: Beginner / Intermediate / Advanced
- ✅ Physics based on yacht design literature (Marchaj, Larsson & Eliasson)
- ✅ Low center of effort for gameplay stability
- ✅ Fallback wind support (WindSystem → WindManager)
- ✅ Speed-based planing (not Froude number)
- ✅ Sailor moves AFT (backward) when planing

### ⚠️ Critical Physics Formulas (DO NOT CHANGE)

| Formula | File | Value |
|---------|------|-------|
| AWA | `SailingState.cs` | `SignedAngle(fwd, -AW, up)` |
| Sail Side | `AdvancedSail.cs` | `sailSide = -Sign(AWA)` |
| Lift Direction | `Aerodynamics.cs` | `project(-sailNormal)` onto wind-perp |
| Rake Tack | `AdvancedSail.cs` | `tack = sailSide` |
| Buoyancy | `AdvancedBuoyancy.cs` | `F = ρ × g × V_submerged` |
| Planing Onset | `AdvancedHullDrag.cs` | `4.0 m/s (~14 km/h)` |
| Full Planing | `AdvancedHullDrag.cs` | `6.0 m/s (~22 km/h)` |

### Priority Fixes for Next Session
- [ ] 🔴 Fix camera initialization (FOV workaround)
- [ ] 🔴 Fix inverted steering
- [ ] 🟡 Improve half-wind physics (sailor hiking simulation)
- [ ] Improve sail visual representation
- [ ] Add sound effects (wind, water, sail)

### For New Team Members
1. Read [KNOWN_ISSUES.md](KNOWN_ISSUES.md) first!
2. See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup
3. See [ARCHITECTURE.md](ARCHITECTURE.md) for code overview

---

## January 2, 2026 - Session 26

### Session: Major Cleanup & Bug Fixes

**Preparing for main branch merge with comprehensive cleanup.**

### Bug Fixes ✅

#### 1. Steering on Port Tack
**Problem:** A/D keys worked backwards on port tack (sail on starboard side).

**Solution:** Added port tack detection in `AdvancedWindsurferController.ReadInput()`:
```csharp
// Detect port tack and invert steering
if (_sail != null && !_sail.IsStarboardTack)
{
    steerDirection = -1f;  // Invert for port tack
}
_steerInput = moveAction.x * steerDirection;
```

#### 2. Porpoising at High Speed
**Problem:** Board oscillated in pitch at planing speeds.

**Solution (3 changes):**
1. Removed downforce from `Sail.cs` (legacy)
2. Set `CalculateCenterOfEffort()` to return `Vector3.zero` in `AdvancedSail.cs`
3. Changed planing lift to apply at center of mass in `AdvancedHullDrag.cs` (`liftPointZ = 0f`)

#### 3. Pitch Stabilization Spasming at High Heel
**Problem:** Board spasmed when heeling over 25°.

**Solution:** Modified `ApplyPitchStabilization()` in `AdvancedSail.cs`:
- Disabled completely when heel > 25°
- Smooth fade from 15° to 25°
- Reduced damping multipliers
- Clamped correction torque to ±300

### Code Cleanup 🧹

#### Files Removed
| File | Reason |
|------|--------|
| `TelemetryHUD.cs` | Superseded by `AdvancedTelemetryHUD.cs` |
| `WindsurferController.cs` (V1) | Superseded by V2 and `AdvancedWindsurferController` |

#### Files Consolidated
| Change | Reason |
|--------|--------|
| `Debugging/` → `Debug/` | Merged duplicate folders |
| `SailPhysicsDebugger.cs` | Moved to `Debug/`, updated namespace |

#### Files Updated
| File | Change |
|------|--------|
| `PhysicsHelpers.cs` | Removed duplicate `PhysicsConstants` class |
| `SailPositionIndicator.cs` | Added support for `AdvancedSail` |
| `WindIndicator3D.cs` | Added support for `AdvancedWindsurferController` |
| `SimpleFollowCamera.cs` | Added `ThirdPersonCamera` disabling logic |

### Documentation Updated 📚
- `KNOWN_ISSUES.md` - Added Session 26 fixes
- `ARCHITECTURE.md` - Updated for removed files
- `SCENE_STRUCTURE_VISUAL.md` - Added Advanced setup notes
- `QUICK_SETUP_CHECKLIST.md` - Updated for current state
- `CONFIGURATION_SUMMARY.md` - Updated component list
- `PROGRESS_LOG.md` - This entry

### Final Script Count: 35 Scripts
Cleaned up from 37 after removing deprecated files.

### Camera Issue
Camera initialization remains a known issue. Workaround: change FOV in Inspector during play mode.

---

## January 1, 2026 - Session 24

### Session: Savitsky Planing Equations & Water Physics Overhaul

**Major Problem Solved: "Trampoline Effect"**

The board was oscillating between 0% and 100% submersion at planing speeds, like bouncing on a trampoline.

**Root Cause Analysis:**
The previous implementation made lift proportional to submersion ratio (`submersionRatio * 2f`). This created a positive feedback loop:
1. Board sinks → submersion↑ → lift↑ → board rises
2. Board rises → submersion↓ → lift↓ → board sinks
3. Repeat = oscillation

**Solution: Proper Savitsky Planing Equations**

Implemented the real physics where lift depends on **speed and trim angle only**, not submersion depth:

```csharp
// Savitsky Lift Coefficient
// CL = τ^1.1 × (0.012 × λ^0.5 + 0.0055 × λ^2.5 / Cv²)
//
// Where:
//   τ = trim angle (degrees, bow-up)
//   λ = wetted length / beam ratio  
//   Cv = speed coefficient = V / √(g × beam)
```

**Key Physics Insight:**
- Submersion is now only a binary check: "Is the board touching water?"
- At a given speed/trim, lift is CONSTANT
- Board height is controlled by **buoyancy equilibrium**, not lift changes
- This is how real planing hulls work

**Other Fixes in This Session:**

| Change | Before | After | Reason |
|--------|--------|-------|--------|
| Vertical damping | 800 N·s/m | 4000 N·s/m | Stronger resistance to bouncing |
| Water viscosity | 0 | 400 N·s²/m² | Realistic v² damping |
| Max lift fraction | 1.2 | 0.85 | Prevents flying out at high speed |
| Sail downforce | None | 25% at 35+ km/h | Keeps board in water |
| Submersion drag | 6x | 12x | More penalty for sinking |
| Lateral damping | Had viscosity | No viscosity | Viscosity was killing speed |

**Files Modified:**

| File | Changes |
|------|---------|
| `AdvancedHullDrag.cs` | Savitsky equations, no submersion-based lift |
| `AdvancedBuoyancy.cs` | Increased damping, added viscosity |
| `Sail.cs` | Added high-speed downforce system |
| `AdvancedWindsurferController.cs` | Reverted half-wind corrections (were unstable) |

**Lessons Learned:**
1. **Don't fight physics with corrections** - Fix the root cause instead of adding band-aid fixes
2. **Lift ≠ submersion** - Real hydrodynamic lift depends on speed and trim, not how deep you are
3. **Buoyancy handles height** - Let Archimedes control the board's height; lift just provides forward force transfer
4. **Viscosity kills speed** - Only apply v² damping to vertical motion, not horizontal

---

## December 27, 2025 - Session 18

### Session: Physics Validation & Documentation

**What we did:**
- ✅ Fixed upwind sailing (had been broken by previous sign convention changes)
- ✅ Reverted `sailSide` formula back to `-Sign(AWA)` which was working
- ✅ Documented all critical physics formulas in PHYSICS_VALIDATION.md
- ✅ Updated COMPONENT_DEPENDENCIES.md with Advanced physics stack
- ✅ Updated ARCHITECTURE.md with critical formula reference
- ✅ Updated README.md with current status
- ✅ Updated PROGRESS_LOG.md

**Root Cause of Previous Breakage:**
Multiple sign convention changes were made independently without understanding the full chain. The formulas are interconnected:
1. AWA sign → determines sailSide
2. sailSide → determines sail angle and normal orientation
3. sailNormal → determines lift direction
4. sailSide → also used in rake steering

Changing any one of these without updating the others breaks the physics.

**Working Physics Configuration:**
```
AWA = SignedAngle(forward, -apparentWind, up)
  → Port wind = positive, Starboard wind = negative

sailSide = -Sign(AWA)
  → Port wind (AWA > 0) → sailSide = -1 → sail on starboard
  → Starboard wind (AWA < 0) → sailSide = +1 → sail on port

liftDir = project(-sailNormal) onto wind-perpendicular plane
  → Force from high pressure (windward) to low pressure (leeward)

rakeSteeringTack = -sailSide  (NEGATED for correct behavior)
  → Rake BACK (+) always heads UP (into wind)
  → Rake FORWARD (-) always bears AWAY (downwind)
  → Rake back with sailSide=-1 → tack=+1 → turn right (head up into port wind)
  → Rake back with sailSide=+1 → tack=-1 → turn left (head up into starboard wind)
```

**Key Lessons Learned:**
1. **Document sign conventions clearly** - They're easy to confuse
2. **Don't change formulas independently** - The physics chain is interconnected
3. **Test ALL behaviors after changes** - Upwind, tacking, both tacks, steering
4. **Create a validation checklist** - Use it after every physics change

**Files Modified:**

| File | Changes |
|------|---------|
| `AdvancedSail.cs` | Reverted sailSide to `-Sign(AWA)` |
| `PHYSICS_VALIDATION.md` | Complete rewrite with validated formulas |
| `COMPONENT_DEPENDENCIES.md` | Added Advanced physics stack, data flow |
| `ARCHITECTURE.md` | Added critical formula reference table |
| `README.md` | Updated current status |
| `PROGRESS_LOG.md` | Added this session |

---

## December 28, 2025 - Session 22

### Session: Buoyancy & Physics Complete + Documentation for Handoff

**Major Physics Improvements:**

This session completed the realistic physics system with proper buoyancy and hydrodynamic lift.

#### 1. Buoyancy System Rewrite (`AdvancedBuoyancy.cs`)

Complete rewrite using proper Archimedes' principle:

```csharp
// Proper buoyancy formula
F_buoyancy = ρ × g × V_submerged

Where:
  ρ = 1025 kg/m³ (seawater density)
  g = 9.81 m/s² (gravity)
  V = submerged volume in m³
```

**New Features:**
- 7×3 sample point grid for accurate pitch/roll moments
- Hull shape modeling with rocker (nose/tail curvature)
- Taper factor (less volume at ends)
- Separate damping for roll/pitch/yaw
- Volume-based calculation (liters → displaced volume)

#### 2. Displacement Lift System (`AdvancedHullDrag.cs`)

New hydrodynamic lift for pre-planing speeds:

```csharp
// Displacement lift (only when submerged)
_displacementLift = liftCoeff * dynamicPressure * wettedArea * submersionRatio;
_displacementLift *= (1f - _planingRatio);  // Fades as planing takes over
```

**Key Physics:**
- Lift only applies to SUBMERGED portions
- Creates self-regulating feedback (more submerged = more lift)
- Fades out as planing lift takes over
- Minimum speed threshold (0.5 m/s)

#### 3. Speed-Based Planing Thresholds

Changed from Froude number to direct speed thresholds:

| Parameter | Value | Real-World |
|-----------|-------|------------|
| Planing Onset | 4.0 m/s | ~14 km/h |
| Full Planing | 6.0 m/s | ~22 km/h |

This matches real-world windsurfing where planing starts around 17 km/h.

#### 4. Sailor Center of Mass Shift (`BoardMassConfiguration.cs`)

Fixed sailor COM movement - now moves AFT (backward) when planing:

```csharp
// Sailor moves BACK when planing (foot pressure on tail)
Vector3 planingShift = new Vector3(0f, -0.1f, -_planingCOMShift * planingRatio);
```

#### 5. Other Fixes

- Reverted to simple board-relative sheeting (12°-85° boom angle)
- Added base steering torque (80 N·m) for control at zero speed
- Reduced upwind dead zone from 25° to 10°
- Added progressive force penalty instead of zero at extreme angles

**Known Issues Documented:**

Three critical issues remain for next contributor:
1. 🔴 Camera only works after changing FOV in Inspector
2. 🔴 Board oscillates 0-100% submersion when planing (needs stability fix)
3. 🔴 Steering is inverted

**Documentation Updated:**

| File | Changes |
|------|---------|
| `KNOWN_ISSUES.md` | **NEW** - Complete known issues with workarounds |
| `PROGRESS_LOG.md` | Added Session 22, updated status summary |
| `README.md` | Updated status, added known issues section |
| `CONTRIBUTING.md` | Added handoff info, known issues, priority fixes |
| `PHYSICS_DESIGN.md` | Added displacement lift, planing physics |
| `QUICK_SETUP_CHECKLIST.md` | Added camera workaround, new components |
| `WindsurferSetup.cs` | Added known issues help text |

**Files Modified (Code):**

| File | Changes |
|------|---------|
| `AdvancedBuoyancy.cs` | Complete rewrite with Archimedes' principle |
| `AdvancedHullDrag.cs` | Displacement lift, speed thresholds, submersion resistance |
| `BoardMassConfiguration.cs` | **NEW** - Mass/inertia config, COM shifts AFT |
| `AdvancedSail.cs` | Simple sheeting, extreme angle handling |
| `AdvancedWindsurferController.cs` | Base steering torque |
| `AdvancedTelemetryHUD.cs` | Speed in km/h, submersion % |

**Physics Parameters Reference:**

| Component | Parameter | Default | Description |
|-----------|-----------|---------|-------------|
| AdvancedBuoyancy | Board Volume | 120 L | Determines max buoyancy |
| AdvancedBuoyancy | Board Length | 2.5 m | For sample point placement |
| AdvancedBuoyancy | Nose Rocker | 0.08 m | Bottom curve at nose |
| AdvancedHullDrag | Planing Onset Speed | 4.0 m/s | ~14 km/h |
| AdvancedHullDrag | Full Planing Speed | 6.0 m/s | ~22 km/h |
| AdvancedHullDrag | Displacement Lift Coeff | 0.12 | Pre-planing lift |
| AdvancedHullDrag | Planing Lift Coeff | 0.15 | At planing speeds |
| BoardMassConfiguration | Total Mass | 90 kg | Board + sailor |
| BoardMassConfiguration | Planing COM Shift | 0.3 m | AFT shift when planing |

---

## December 28, 2025 - Session 21

### Session: Camera/Water/Telemetry Fix

**Issues Reported:**
1. Camera doesn't work (tried 4 times without success)
2. Water has no texture
3. Telemetry HUD not created by wizard

**Root Cause Analysis:**

1. **Camera Issue**: The existing MainScene.unity had a broken component reference. The scene was looking for `WindsurfingGame.Camera.ThirdPersonCamera` but the actual namespace is `WindsurfingGame.CameraSystem.ThirdPersonCamera`. The old camera component in the scene was invalid/missing script.

2. **Water Issue**: Material not being properly assigned when water plane created.

3. **Telemetry Issue**: Wizard didn't include telemetry creation.

**Solution: Complete Overhaul of Scene Setup**

1. **Camera Fix - SetupCamera() Method:**
   - Now **removes** any existing ThirdPersonCamera component first (to clear broken references)
   - Creates a **fresh** ThirdPersonCamera with all properties set
   - Uses direct property assignment via SerializedObject for reliability

2. **Water Fix - EnsureWaterMaterial() Method:**
   - Searches multiple material paths (`WaterMaterial.mat`, `Water.mat`, etc.)
   - Falls back to asset database search by GUID pattern
   - Creates new material with proper shader if not found
   - Forces material assignment on existing water surfaces

3. **Telemetry Added - EnsureTelemetryHUD() Method:**
   - Creates AdvancedTelemetryHUD component
   - Auto-wires all references (controller, sail, fin, hull, buoyancy, rigidbody)
   - Press F1 to toggle in-game

**Files Modified:**

| File | Changes |
|------|---------|
| `WindsurferSetup.cs` | Added `SetupCamera()`, `EnsureWaterMaterial()`, `EnsureTelemetryHUD()` |
| `PROGRESS_LOG.md` | Added Session 21 |

**Key Learning:**
Unity scene files store component references by namespace. If a namespace changes (e.g., from `Camera` to `CameraSystem`), existing scenes will have broken "Missing Script" components. The fix is to:
1. Delete the old component
2. Add a fresh component with correct type
3. Re-configure all properties

---

## December 28, 2025 - Session 20

### Session: Complete Scene Setup Wizard

**Issue Fixed:**
- The wizard's "Configure Camera for Selected Windsurfer" button would fail if no windsurfer existed yet
- Users couldn't start from an empty scene - the wizard required WaterSurface and WindSystem to exist first

**Solution: Complete Scene Creation from Scratch**

The setup wizard now has a **"🌟 Create Complete Scene"** button that creates EVERYTHING:
- WaterSurface (100m x 100m water plane with physics)
- WindSystem (configurable speed and direction)
- ThirdPersonCamera (with all settings properly configured)
- Directional Light (sunlight)
- Windsurfer (with all physics components)
- WindDirectionIndicator

**New Methods Added:**
- `EnsureWaterSurface()` - Creates water plane if not exists
- `EnsureWindSystem()` - Creates wind system if not exists
- `EnsureCamera()` - Creates camera with ThirdPersonCamera if not exists
- `EnsureLighting()` - Creates directional light if not exists
- `CreateCompleteScene()` - Orchestrates full scene creation
- `CreateWindsurferObject()` - Refactored windsurfer creation into reusable method

**Improved UX:**
- "Configure Camera" now auto-finds existing windsurfer if nothing selected
- If no windsurfer exists, offers to create complete scene
- Scene settings foldout for configuring wind speed/direction before creation
- Both buttons now offer to create complete scene if missing dependencies

**How to use (from empty scene):**
1. Menu: `Windsurfing → Complete Windsurfer Setup Wizard`
2. Assign Board and Sail FBX models
3. (Optional) Expand Scene Settings to configure wind
4. (Optional) Expand Camera Settings to configure camera
5. Click **"🌟 Create Complete Scene"**
6. Press Play!

**Files Modified:**

| File | Changes |
|------|---------|
| `WindsurferSetup.cs` | Major refactor - complete scene creation from scratch |
| `PROGRESS_LOG.md` | Added this session |

---

## December 28, 2025 - Session 19

### Session: Mast Rake Fix & Setup Wizard Enhancement

**Issues Fixed:**
1. **Mast rake direction was inverted** - The AdvancedSail had rake steering backwards:
   - OLD (wrong): Rake back → bear away (downwind)
   - NEW (correct): Rake back → head up (upwind)
   
2. **Camera settings not applying** - The setup wizard only set the camera target, not all the other settings

**Changes Made:**

**AdvancedSail.cs - ApplyRakeSteering():**
```csharp
// OLD: float tack = _state.SailSide;
// NEW: Negate sailSide so rake back = head up (into wind)
float tack = _state.SailSide != 0 ? -_state.SailSide : 1f;
```

**WindsurferSetup.cs - Complete Enhancement:**
- Added camera settings panel with adjustable:
  - Distance, Pitch, Position/Rotation smoothing
  - Look offset (where camera looks relative to board)
- New `ConfigureCameraForSelected()` method that sets ALL camera properties
- New `ValidateAllComponents()` method that:
  - Checks for WindSystem, WaterSurface, ThirdPersonCamera
  - Validates AdvancedSail, AdvancedBuoyancy, EquipmentVisualizer references
  - Auto-fixes missing references when possible
- Added scrollable UI for the expanded wizard

**Files Modified:**

| File | Changes |
|------|---------|
| `AdvancedSail.cs` | Fixed rake steering direction (negated tack) |
| `WindsurferSetup.cs` | Enhanced wizard with camera config & validation |
| `PHYSICS_VALIDATION.md` | Updated rake steering documentation |
| `PROGRESS_LOG.md` | Added this session |

**How to use the enhanced wizard:**
1. Menu: `Windsurfing → Complete Windsurfer Setup Wizard`
2. Configure camera settings in the foldout panel
3. Create windsurfer or use "Configure Camera for Selected Windsurfer"
4. Use "Validate All Components" to check & auto-fix references

---

## December 27, 2025 - Session 18

### Session: Advanced Physics System Overhaul

**What we did:**
- ✅ Complete overhaul of the physics system with realistic aerodynamic/hydrodynamic modeling
- ✅ Created physics core modules (PhysicsConstants, Aerodynamics, Hydrodynamics, SailingState)
- ✅ Created advanced board components (AdvancedSail, AdvancedFin, AdvancedHullDrag, AdvancedBuoyancy)
- ✅ Created new WindSystem with gusts, shifts, and height gradient
- ✅ Created AdvancedWindsurferController with three control modes
- ✅ Created AdvancedTelemetryHUD for comprehensive physics display
- ✅ Created custom StylizedWater shader for better visual feedback
- ✅ Updated MainScene.unity to use new Advanced* components

**Physics Theory Implemented:**

| Component | Theory/Source |
|-----------|---------------|
| Sail Lift | Thin airfoil theory: Cl = 2π * AR/(AR+2) * α |
| Sail Drag | Induced drag + parasitic: Cd = Cd0 + Cl²/(π*e*AR) |
| Fin Lift | NACA foil characteristics with stall modeling |
| Hull Resistance | ITTC friction + Froude number wave resistance |
| Planing | Savitsky method with wetted area reduction |
| Buoyancy | Multi-point sampling with damping |
| Wind Gradient | Power law: V = V_ref * (z/z_ref)^α |

**New File Structure:**
```
Assets/Scripts/
├── Physics/
│   ├── Core/
│   │   ├── PhysicsConstants.cs    # Air/water density, gravity, conversions
│   │   ├── Aerodynamics.cs        # Sail lift/drag calculations
│   │   ├── Hydrodynamics.cs       # Fin/hull force calculations
│   │   └── SailingState.cs        # State classes, configurations
│   ├── Board/
│   │   ├── AdvancedSail.cs        # Realistic sail aerodynamics
│   │   ├── AdvancedFin.cs         # Hydrodynamic fin with leeway
│   │   └── AdvancedHullDrag.cs    # Displacement/planing hull model
│   └── Buoyancy/
│       └── AdvancedBuoyancy.cs    # Multi-point buoyancy system
├── Environment/
│   └── WindSystem.cs              # Global wind with variability
├── Player/
│   └── AdvancedWindsurferController.cs  # New control system
└── UI/
    └── AdvancedTelemetryHUD.cs    # Physics data display
```

**Key Physics Improvements:**
1. **Proper fin grip** - Fin generates realistic lift force opposing leeway
2. **Leeway angle calculation** - Slip angle from velocity vector, not arbitrary
3. **Center of pressure** - Forces applied at correct positions
4. **Tracking torque** - Fin actively corrects course deviations
5. **Apparent wind** - Proper vector calculation for VMG sailing
6. **Froude number** - Realistic transition from displacement to planing
7. **Multi-point buoyancy** - Natural pitch/roll behavior

**Control Modes:**
| Mode | Sheet | Rake | Weight | Assists |
|------|-------|------|--------|---------|
| Beginner | Auto | A/D combined | A/D combined | Anti-capsize, auto-center |
| Intermediate | Manual W/S | Q/E | A/D | Anti-capsize, auto-center |
| Advanced | Manual W/S | Q/E | A/D | None |

**What's Next:**
- Test the physics in Unity and tune parameters
- Adjust sail area, fin size, hull resistance for good feel
- May need to balance power vs. stability

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

## Session 14-16: December 27, 2025 - FBX Models, Physics Stability & Telemetry

**Goal:** Add real FBX models, fix physics instability, and update telemetry

### Changes Made

**Session 14 - EquipmentVisualizer & Editor Wizard:**
- ✅ Created `EquipmentVisualizer.cs` for loading FBX board/sail models
- ✅ Sail model rotates based on `AdvancedSail.CurrentSailAngle` and `MastRake`
- ✅ Created `WindsurferSetup.cs` editor wizard for complete windsurfer setup
- ✅ Wizard creates all advanced physics components with proper references

**Session 15 - Wind Fallback & Error Logging:**
- ✅ `AdvancedSail` now falls back to `WindManager` if `WindSystem` not found
- ✅ Added error logging: `"NO WIND SOURCE FOUND!"` if no wind in scene
- ✅ Added warnings to `AdvancedHullDrag` and `AdvancedWindsurferController`
- ✅ Updated `AdvancedSail` to use `IWindProvider` interface for legacy support

**Session 16 - Physics Stability & Telemetry:**
- ✅ Changed default sheet position from 0.5 to **0.65** (more eased out)
- ✅ Reduced Center of Effort height to **0.3m** (was ~3m causing wild rotations)
- ✅ Reduced steering torque multiplier from 0.3 to **0.05** (prevents spinning)
- ✅ Minimized lateral CE offset to **0.1m** (reduces heeling moment)
- ✅ Fixed `AdvancedTelemetryHUD` component finding with better fallbacks
- ✅ Updated `SailingState.CenterOfEffortHeight` formula for stability

### Physics Stability Fixes Explained

The original physics had:
1. **Center of Effort ~3+ meters high** → Large moment arm → Wild rotation
2. **Lateral CE offset based on boom length** → More heeling → Instability
3. **Strong steering torque (0.3×)** → Over-correction → Spinning

Fixed by:
1. **CE height = 0.3m** → Small moment arm → Stable forces
2. **Lateral CE offset = 0.1m** → Minimal heeling → Stays upright
3. **Steering torque = 0.05×** → Gentle turns → No spinning

### Files Modified

| File | Changes |
|------|---------|
| `AdvancedSail.cs` | Default sheet 0.65, low CE height, reduced steering |
| `SailingState.cs` | Simplified CenterOfEffortHeight formula |
| `AdvancedTelemetryHUD.cs` | Better component finding with fallbacks |
| `ARCHITECTURE.md` | Added troubleshooting section, updated version history |
| `PROGRESS_LOG.md` | Updated status summary and session log |

### Scripts Status (30 scripts, all compiling)

```
Physics Core (4):  PhysicsConstants, Aerodynamics, Hydrodynamics, SailingState
Water (2):         IWaterSurface, WaterSurface  
Wind (3):          IWindProvider, WindManager, WindSystem
Buoyancy (2):      BuoyancyBody, AdvancedBuoyancy
Board (7):         Sail, ApparentWindCalculator, WaterDrag, FinPhysics,
                   AdvancedSail, AdvancedFin, AdvancedHullDrag
Player (3):        WindsurferController, WindsurferControllerV2, AdvancedWindsurferController
Camera (1):        ThirdPersonCamera
UI (4):            TelemetryHUD, AdvancedTelemetryHUD, SailPositionIndicator, WindIndicator3D
Visual (2):        SailVisualizer, EquipmentVisualizer
Editor (1):        WindsurferSetup
Utilities (2):     PhysicsHelpers, WaterGridMarkers
```

### Testing Checklist

- [ ] Board floats and doesn't sink
- [ ] Board moves forward when wind is from side/behind
- [ ] Board doesn't spin wildly
- [ ] Telemetry shows wind speed, boat speed, sail force
- [ ] Sheet in/out (W/S) affects sail angle
- [ ] Mast rake (A/D) causes gentle turns

---

*End of December 20, 2025 sessions*

---

## Session 17 - Runtime Visualizers (December 27, 2025)

**Goal**: Add visible force vectors and wind direction indicators that work in Game view

**Problem**: Gizmos (OnDrawGizmos) only show in Scene view when object is selected - not useful for runtime debugging.

**Solution**: Created LineRenderer-based visualizers that work in both Scene and Game views.

### New Scripts Created

**1. ForceVectorVisualizer.cs** (`Visual/`)
- Purpose: Runtime force vector display using LineRenderers
- Shows: Sail force (cyan), lift (green), drag (red), wind (blue), velocity (yellow), fin lift (teal)
- Features: Arrow heads, color-coded, auto-scaling, toggle on/off
- Location: Attached to windsurfer automatically by wizard

**2. WindDirectionIndicator.cs** (`Visual/`)
- Purpose: Animated wind direction arrows on water surface
- Shows: 12 arrows in grid around player, moving with wind direction
- Features: Animated movement, follows player, spawns at water height
- Location: Scene singleton (one per scene)

### Other Changes

- **WindsurferSetup.cs**: Updated wizard to add ForceVectorVisualizer and WindDirectionIndicator automatically
- **AdvancedSail.cs**: Increased steering torque formula: `0.5 × force + 150 base + 30 × speed`
- **ARCHITECTURE.md**: Added new visualizers to namespace tree and script table

### Steering Formula (Current)

```csharp
private void ApplyRakeSteering()
{
    float forceMag = _state.SailForce.magnitude;
    float steeringTorque = _mastRake * forceMag * 0.5f;      // 50% of sail force
    float baseSteeringTorque = _mastRake * 150f;             // Base torque
    float speedTorque = _mastRake * _state.BoatSpeed * 30f;  // Speed-dependent
    _rigidbody.AddTorque(Vector3.up * (steeringTorque + baseSteeringTorque + speedTorque), ForceMode.Force);
}
```

### Scripts Status (32 scripts, all compiling)

```
Physics Core (4):  PhysicsConstants, Aerodynamics, Hydrodynamics, SailingState
Water (2):         IWaterSurface, WaterSurface  
Wind (3):          IWindProvider, WindManager, WindSystem
Buoyancy (2):      BuoyancyBody, AdvancedBuoyancy
Board (7):         Sail, ApparentWindCalculator, WaterDrag, FinPhysics,
                   AdvancedSail, AdvancedFin, AdvancedHullDrag
Player (3):        WindsurferController, WindsurferControllerV2, AdvancedWindsurferController
Camera (1):        ThirdPersonCamera
UI (4):            TelemetryHUD, AdvancedTelemetryHUD, SailPositionIndicator, WindIndicator3D
Visual (4):        SailVisualizer, EquipmentVisualizer, ForceVectorVisualizer, WindDirectionIndicator
Editor (1):        WindsurferSetup
Utilities (2):     PhysicsHelpers, WaterGridMarkers
```

---

*End of Session 17*

---

*This log is updated after each development session.*
