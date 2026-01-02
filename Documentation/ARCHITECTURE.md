# 🏗️ Architecture & Codebase Reference

This document provides a complete overview of the codebase for team collaboration.

**Last Updated:** January 2, 2026

---

## ⚠️ CRITICAL: Read First!

1. **Known Issues:** See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for current bugs
2. **Physics Formulas:** See [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md) - DO NOT CHANGE without understanding

### Key Formulas (DO NOT CHANGE)

| Formula | Location | Value |
|---------|----------|-------|
| AWA | `SailingState.cs` | `SignedAngle(fwd, -AW, up)` |
| Sail Side | `AdvancedSail.cs` | `sailSide = -Sign(AWA)` |
| Lift Dir | `Aerodynamics.cs` | `project(-sailNormal) onto wind-perp` |
| Rake Tack | `AdvancedSail.cs` | `tack = sailSide` |
| Buoyancy | `AdvancedBuoyancy.cs` | `F = ρ × g × V_submerged` |
| Planing | `AdvancedHullDrag.cs` | `onset: 4.0 m/s, full: 6.0 m/s` |

---

## Quick Reference

### Project Location
```
d:\Github\WindsurfingMMZB\WindsurfingGame\
```

### Unity Version
**Unity 6.3 LTS** with Universal Render Pipeline (URP)

### Input System
**Unity New Input System** (`UnityEngine.InputSystem`)

---

## Namespace Structure

All scripts use the `WindsurfingGame` root namespace:

```
WindsurfingGame
├── Physics
│   ├── Water      → IWaterSurface, WaterSurface
│   ├── Wind       → IWindProvider, WindManager (legacy)
│   ├── Core       → PhysicsConstants, Aerodynamics, Hydrodynamics, SailingState
│   ├── Buoyancy   → BuoyancyBody (legacy), AdvancedBuoyancy
│   └── Board      → Sail (legacy), AdvancedSail, FinPhysics (legacy), AdvancedFin,
│                    WaterDrag (legacy), AdvancedHullDrag, ApparentWindCalculator,
│                    BoardMassConfiguration
├── Environment    → WindSystem ⭐
├── Player         → WindsurferControllerV2 (legacy), AdvancedWindsurferController ⭐
├── CameraSystem   → ThirdPersonCamera (legacy), SimpleFollowCamera ⭐
├── UI             → AdvancedTelemetryHUD ⭐, SailPositionIndicator, WindIndicator3D
├── Visual         → SailVisualizer, EquipmentVisualizer, ForceVectorVisualizer, WindDirectionIndicator
├── Debug          → PhysicsValidation, SailPhysicsDebugger
├── Editor         → WindsurferSetup (Setup Wizard)
└── Utilities      → PhysicsHelpers (extensions only), WaterGridMarkers
```

---

## Physics Systems

### Advanced Physics (Recommended) ⭐
**Use these for production** - Realistic physics based on sailing research.

### Legacy Physics (Deprecated)
Simple physics suitable for quick prototyping - **not recommended for new development**:
- `BuoyancyBody`, `Sail`, `FinPhysics`, `WaterDrag`, `WindsurferControllerV2`

### Advanced Physics Components ⭐
Realistic physics based on sailing research:
- `AdvancedBuoyancy` - Archimedes' principle with 21-point sampling, hull shape
- `AdvancedSail` - Aerodynamic lift/drag with camber and aspect ratio
- `AdvancedFin` - Hydrodynamic lift/drag with stall behavior
- `AdvancedHullDrag` - Displacement lift + planing lift, speed-based thresholds
- `AdvancedWindsurferController` - Realistic control with weight shift
- `BoardMassConfiguration` - Mass/inertia config, sailor COM shifts AFT when planing
- `WindSystem` - Advanced wind with gusts, shifts, and height gradient

---

## Script Inventory

### Physics Layer - Basic

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [IWaterSurface.cs](../WindsurfingGame/Assets/Scripts/Physics/Water/IWaterSurface.cs) | Physics.Water | Interface for water height queries | - |
| [WaterSurface.cs](../WindsurfingGame/Assets/Scripts/Physics/Water/WaterSurface.cs) | Physics.Water | Implements water surface with waves | IWaterSurface |
| [IWindProvider.cs](../WindsurfingGame/Assets/Scripts/Physics/Wind/IWindProvider.cs) | Physics.Wind | Interface for wind queries | - |
| [WindManager.cs](../WindsurfingGame/Assets/Scripts/Physics/Wind/WindManager.cs) | Physics.Wind | Global wind control | IWindProvider |
| [BuoyancyBody.cs](../WindsurfingGame/Assets/Scripts/Physics/Buoyancy/BuoyancyBody.cs) | Physics.Buoyancy | Multi-point buoyancy | IWaterSurface, Rigidbody |
| [Sail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/Sail.cs) | Physics.Board | Basic sail aerodynamics | ApparentWindCalculator, Rigidbody |
| [ApparentWindCalculator.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/ApparentWindCalculator.cs) | Physics.Board | True wind → apparent wind | IWindProvider, Rigidbody |
| [WaterDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/WaterDrag.cs) | Physics.Board | Hydrodynamic resistance | IWaterSurface, Rigidbody |
| [FinPhysics.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/FinPhysics.cs) | Physics.Board | Fin grip & lateral resistance | Rigidbody |

### Physics Layer - Advanced ⭐

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [WindSystem.cs](../WindsurfingGame/Assets/Scripts/Environment/WindSystem.cs) | Environment | Advanced wind with gusts/shifts | IWindProvider |
| [PhysicsConstants.cs](../WindsurfingGame/Assets/Scripts/Physics/Core/PhysicsConstants.cs) | Physics.Core | Physical constants (air/water density) | - |
| [Aerodynamics.cs](../WindsurfingGame/Assets/Scripts/Physics/Core/Aerodynamics.cs) | Physics.Core | Lift/drag calculations for air | PhysicsConstants |
| [Hydrodynamics.cs](../WindsurfingGame/Assets/Scripts/Physics/Core/Hydrodynamics.cs) | Physics.Core | Lift/drag calculations for water | PhysicsConstants |
| [SailingState.cs](../WindsurfingGame/Assets/Scripts/Physics/Core/SailingState.cs) | Physics.Core | State tracking & config classes | - |
| [AdvancedBuoyancy.cs](../WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs) | Physics.Buoyancy | Multi-point (5x3) flotation | IWaterSurface, Rigidbody |
| [AdvancedSail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs) | Physics.Board | Aerodynamic sail with camber | WindSystem, Aerodynamics, Rigidbody |
| [AdvancedFin.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedFin.cs) | Physics.Board | Hydrodynamic fin with stall | Hydrodynamics, Rigidbody |
| [AdvancedHullDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs) | Physics.Board | Displacement/planing drag | AdvancedBuoyancy, Rigidbody |
| [BoardMassConfiguration.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/BoardMassConfiguration.cs) | Physics.Board | Mass/inertia, sailor COM shift | Rigidbody |

### Player Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [AdvancedWindsurferController.cs](../WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs) | Player | Realistic controls ⭐ | AdvancedSail, AdvancedFin, Input System |
| [WindsurferControllerV2.cs](../WindsurfingGame/Assets/Scripts/Player/WindsurferControllerV2.cs) | Player | Legacy controls | Sail, Unity Input System |

> **Note:** `WindsurferController.cs` (V1) was removed in Session 26 cleanup.

### UI Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [AdvancedTelemetryHUD.cs](../WindsurfingGame/Assets/Scripts/UI/AdvancedTelemetryHUD.cs) | UI | Telemetry display (F1 toggle) ⭐ | AdvancedSail, WindSystem, SailingState |
| [SailPositionIndicator.cs](../WindsurfingGame/Assets/Scripts/UI/SailPositionIndicator.cs) | UI | 2D top-down sail position | AdvancedSail or Sail |
| [WindIndicator3D.cs](../WindsurfingGame/Assets/Scripts/UI/WindIndicator3D.cs) | UI | 3D wind arrow display | WindManager, ApparentWindCalculator |

> **Note:** `TelemetryHUD.cs` was removed in Session 26 cleanup. Use `AdvancedTelemetryHUD.cs` instead.

### Visual Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [SailVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/SailVisualizer.cs) | Visual | Procedural 3D sail mesh (debug) | Sail, ApparentWindCalculator |
| [EquipmentVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs) | Visual | FBX model loader for board & sail | Sail or AdvancedSail |
| [ForceVectorVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/ForceVectorVisualizer.cs) | Visual | Runtime force arrows (Game view) | AdvancedSail, AdvancedFin, Rigidbody |
| [WindDirectionIndicator.cs](../WindsurfingGame/Assets/Scripts/Visual/WindDirectionIndicator.cs) | Visual | Animated wind arrows on water | WindManager or WindSystem |

### Camera Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [SimpleFollowCamera.cs](../WindsurfingGame/Assets/Scripts/Camera/SimpleFollowCamera.cs) | CameraSystem | Multi-mode follow camera ⭐ | Transform target |
| [ThirdPersonCamera.cs](../WindsurfingGame/Assets/Scripts/Camera/ThirdPersonCamera.cs) | CameraSystem | Legacy orbit camera | Transform target |

> **Note:** SimpleFollowCamera automatically disables ThirdPersonCamera when both are present.

### Debug Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [PhysicsValidation.cs](../WindsurfingGame/Assets/Scripts/Debug/PhysicsValidation.cs) | Debug | Physics debugging tool | AdvancedSail |
| [SailPhysicsDebugger.cs](../WindsurfingGame/Assets/Scripts/Debug/SailPhysicsDebugger.cs) | Debug | Sail force logging | AdvancedSail |

### Utilities & Editor

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [PhysicsHelpers.cs](../WindsurfingGame/Assets/Scripts/Utilities/PhysicsHelpers.cs) | Utilities | Vector extensions (no constants) | - |
| [WaterGridMarkers.cs](../WindsurfingGame/Assets/Scripts/Utilities/WaterGridMarkers.cs) | Utilities | Debug grid visualization | IWaterSurface |
| [WindsurferSetup.cs](../WindsurfingGame/Assets/Scripts/Editor/WindsurferSetup.cs) | Editor | Editor wizard for complete setup | - |

> **Note:** PhysicsConstants is in `Physics.Core` namespace. PhysicsHelpers only contains extension methods.

---

## Component Dependencies

### Windsurfer GameObject Setup (Legacy)

The legacy setup (for prototyping only):

```
Windsurfer (GameObject)
├── Rigidbody (Required)
│   └── Used by: All physics scripts
├── BuoyancyBody
│   └── Requires: IWaterSurface in scene
├── ApparentWindCalculator
│   └── Requires: IWindProvider (WindManager) in scene
├── Sail
│   └── Requires: ApparentWindCalculator, Rigidbody
├── WaterDrag
│   └── Requires: IWaterSurface, Rigidbody
├── FinPhysics
│   └── Requires: Rigidbody
└── WindsurferControllerV2
    └── Requires: Sail
```

> **Note:** `WindsurferController` (V1) was removed in Session 26.

### Windsurfer GameObject Setup (Advanced) ⭐

The advanced windsurfer uses realistic physics:

```
Windsurfer (GameObject)
├── Rigidbody (Required - 91kg, Continuous collision)
│   └── Used by: All physics scripts
├── BoxCollider (2.8m x 0.2m x 0.7m)
│   └── Board collision
├── AdvancedBuoyancy
│   └── Requires: IWaterSurface in scene, Rigidbody
├── AdvancedSail
│   └── Requires: WindSystem in scene, Rigidbody
├── AdvancedFin
│   └── Requires: Rigidbody
├── AdvancedHullDrag
│   └── Requires: AdvancedBuoyancy (or BuoyancyBody), Rigidbody
├── AdvancedWindsurferController
│   └── Requires: AdvancedSail, AdvancedFin
└── EquipmentVisualizer (Optional)
    └── Requires: AdvancedSail (or Sail), FBX prefabs
```

**Use the wizard**: `Windsurfing → Complete Windsurfer Setup Wizard` to auto-create all components.

### Scene Singletons

```
Scene
├── WindManager (implements IWindProvider) - Basic wind
├── WindSystem (Environment) - Advanced wind with gusts/shifts ⭐
└── WaterSurface (implements IWaterSurface)
    └── Found via: FindFirstObjectByType<IWaterSurface>()
```

---

## Key Data Flow

### Wind → Board Movement (Basic)

```
WindManager (true wind)
    ↓
ApparentWindCalculator (combines with board velocity)
    ↓
Sail (calculates lift/drag forces)
    ↓
Rigidbody.AddForceAtPosition (at Center of Effort)
    ↓
Board moves
```

### Wind → Board Movement (Advanced) ⭐

```
WindSystem (true wind + gusts + shifts + height gradient)
    ↓
AdvancedSail (apparent wind, lift/drag via Aerodynamics module)
    ├── Lift force perpendicular to apparent wind
    └── Drag force parallel to apparent wind
    ↓
Rigidbody.AddForceAtPosition (at Center of Effort)
    +
AdvancedFin (hydrodynamic lift/drag via Hydrodynamics module)
    ├── Prevents sideslip
    └── Applies lateral force
    +
AdvancedHullDrag (displacement or planing based on Froude number)
    └── Speed-dependent resistance
    ↓
Board moves realistically
```

### Water → Buoyancy

```
WaterSurface (wave heights)
    ↓
BuoyancyBody or AdvancedBuoyancy (samples at multiple points)
    ↓
Rigidbody.AddForceAtPosition (buoyancy forces)
    ↓
Board floats
```

### Simulation → Visualization

```
AdvancedSail.CurrentSailAngle / MastRake (simulation output)
    ↓
EquipmentVisualizer (reads value, rotates FBX sail model)
SailPositionIndicator (reads value, renders 2D HUD)

Sail.CurrentSailAngle (basic simulation output)
    ↓
SailVisualizer (reads value, renders procedural 3D sail)

IMPORTANT: Visualizers NEVER calculate physics values independently.
           They only READ from simulation components.
```

---

## Control Modes

### WindsurferControllerV2 (Basic)

| Mode | Sheet Control | Rake Control | Best For |
|------|---------------|--------------|----------|
| Beginner | Auto-trims to optimal | A/D keys | New players |
| Advanced | W/S (sheet in/out) | A/D keys | Experienced |

### AdvancedWindsurferController ⭐

| Mode | Description | Best For |
|------|-------------|----------|
| Beginner | Auto-trimming, weight assist | Learning |
| Intermediate | Manual sheeting, some assist | Practice |
| Advanced | Full manual control, weight shift | Realism |

### Default Controls

| Key | Action |
|-----|--------|
| W | Sheet in (closer to wind) |
| S | Sheet out (away from wind) |
| A | Rake mast forward (bear off) |
| D | Rake mast back (head up) |
| Tab | Toggle control mode |
| F1 | Toggle detailed telemetry |
| F2 | Toggle force vectors |
| F3 | Toggle polar diagram |

---

## Physics Constants

### Basic (PhysicsHelpers.cs)

| Constant | Value | Description |
|----------|-------|-------------|
| WATER_DENSITY | 1025 kg/m³ | Seawater density |
| AIR_DENSITY | 1.225 kg/m³ | Air density at sea level |
| GRAVITY | 9.81 m/s² | Gravitational acceleration |

### Advanced (PhysicsConstants.cs) ⭐

| Constant | Value | Description |
|----------|-------|-------------|
| WaterDensity | 1025 kg/m³ | Seawater density |
| AirDensity | 1.225 kg/m³ | Air at sea level |
| Gravity | 9.81 m/s² | Gravitational acceleration |
| KinematicViscosityWater | 1.139e-6 m²/s | Water viscosity |
| KinematicViscosityAir | 1.48e-5 m²/s | Air viscosity |

### Configuration Classes (SailingState.cs) ⭐

```csharp
SailConfiguration  → Area, AspectRatio, Camber, MastHeight, etc.
FinConfiguration   → Area, AspectRatio, Span, Chord, etc.
HullConfiguration  → Length, Beam, WettedArea, DisplacementMass, etc.
```

---

## File Locations

### Scripts
```
Assets/Scripts/Physics/Water/         → Water surface, interfaces
Assets/Scripts/Physics/Wind/          → Wind system
Assets/Scripts/Physics/Core/          → PhysicsConstants, Aerodynamics, Hydrodynamics ⭐
Assets/Scripts/Physics/Buoyancy/      → Buoyancy simulation
Assets/Scripts/Physics/Board/         → Sail, fin, drag physics
Assets/Scripts/Environment/           → WindSystem (advanced) ⭐
Assets/Scripts/Player/                → Player controllers
Assets/Scripts/Camera/                → Camera systems (namespace: CameraSystem)
Assets/Scripts/UI/                    → HUD and indicators
Assets/Scripts/Visual/                → 3D visualizers, EquipmentVisualizer ⭐
Assets/Scripts/Editor/                → Editor wizards ⭐
Assets/Scripts/Utilities/             → Helpers and debug tools
```

### Documentation
```
Documentation/README.md               → Project overview
Documentation/DEVELOPMENT_PLAN.md     → Phased development roadmap
Documentation/PHYSICS_DESIGN.md       → Physics equations and design
Documentation/CODE_STYLE.md           → Coding standards
Documentation/PROGRESS_LOG.md         → Session-by-session log
Documentation/ARCHITECTURE.md         → This file
Documentation/TEST_SCENE_SETUP.md     → How to set up test scenes
Documentation/UNITY_SETUP_GUIDE.md    → Unity project setup
Documentation/PHYSICS_VALIDATION.md   → Physics testing checklist
```

---

## Common Tasks

### Adding a New Physics Component

1. Create script in appropriate `Physics/` subfolder
2. Use correct namespace: `WindsurfingGame.Physics.[Subfolder]`
3. Add `[RequireComponent]` for dependencies
4. Find singletons in `Start()` using `FindFirstObjectByType<T>()`
5. Apply forces in `FixedUpdate()`
6. Add gizmos in `OnDrawGizmosSelected()` for debugging

### Adding UI Visualization

1. Create script in `UI/` or `Visual/` folder
2. Reference the simulation component (e.g., `Sail`)
3. **READ values from simulation** - never calculate physics independently
4. For OnGUI: use `OnGUI()` method
5. For 3D: use `Update()` to position/rotate objects

### Testing Changes

1. Open `TestScene` in Unity
2. Ensure `WindManager` and `WaterSurface` exist in scene
3. Check Console for errors
4. Use Scene view gizmos to debug physics
5. Use TelemetryHUD for runtime values

---

## Known Issues & Workarounds

| Issue | Workaround |
|-------|------------|
| Camera namespace conflict | Use `WindsurfingGame.CameraSystem` not `Camera` |
| Input System errors | Ensure New Input System package is installed |
| Board sinks through water | Check WaterSurface doesn't have MeshCollider |
| No wind force | Ensure WindSystem (or WindManager) exists in scene |
| Weird rotational movements | Center of Effort is kept low - check force scale |
| Telemetry not updating | AdvancedTelemetryHUD finds components via FindAnyObjectByType |
| Board spins wildly | Steering torque reduced to 0.05 multiplier |
| Sail not responding | Check Console for "NO WIND SOURCE FOUND!" error |

---

## Troubleshooting

### Physics Not Working

1. **Check Console** for these error messages:
   - `"NO WIND SOURCE FOUND!"` → Add WindSystem to scene
   - `"No WaterSurface found!"` → Add WaterSurface to scene
   - `"No AdvancedSail found!"` → Missing sail component

2. **Verify Scene Requirements**:
   - WindSystem or WindManager exists
   - WaterSurface exists (no MeshCollider!)
   - Windsurfer has Rigidbody, AdvancedBuoyancy, AdvancedSail, AdvancedFin, AdvancedHullDrag

3. **Check Component References**:
   - AdvancedSail._windSystem should be assigned (or auto-found)
   - AdvancedBuoyancy._waterSurface should be assigned
   - AdvancedHullDrag._advancedBuoyancy should be assigned

### Weird Movements

1. **Forces too strong**: Reduce sail area in SailConfiguration
2. **Spinning**: Check that AdvancedFin tracking is enabled
3. **Flipping over**: Anti-capsize should be enabled in controller
4. **No forward motion**: Check apparent wind angle - may be in "irons" (too close to wind)

### Telemetry Not Showing

1. AdvancedTelemetryHUD must exist in scene
2. Press F1 to toggle detailed view
3. Check that AdvancedSail component exists on windsurfer

### Default Values

| Property | Default | Description |
|----------|---------|-------------|
| Sheet Position | 0.65 (65%) | More eased for reasonable start |
| Mast Rake | 0 | Neutral position |
| Wind Speed | 15 knots | Moderate sailing conditions |
| Board Mass | 91 kg | Board + rig + sailor |

---

## Version History

| Date | Session | Major Changes |
|------|---------|---------------|
| Dec 19 | 1 | Project structure, documentation |
| Dec 19 | 2 | Phase 1 scripts: water, buoyancy, camera |
| Dec 19 | 3 | Buoyancy testing, collision fix |
| Dec 19 | 4 | Wind system, apparent wind, sail |
| Dec 19 | 5 | Water drag, controller, telemetry |
| Dec 19 | 6 | WindIndicator3D, WaterGridMarkers |
| Dec 19 | 7 | Camera namespace fix, Input System fix |
| Dec 19 | 8 | FinPhysics component |
| Dec 19 | 9 | Mast rake direction fix, SailVisualizer, SailPositionIndicator |
| Dec 20 | 10 | Physics validation, WindsurferControllerV2 |
| Dec 20 | 11 | Sail simulation fix (geometry, CE, visualizer sync) |
| Dec 26 | 12 | Full validation, control tuning, stabilization, no-go zone, planing fix |
| Dec 27 | 13 | Advanced physics: AdvancedSail, AdvancedFin, AdvancedHullDrag, AdvancedBuoyancy |
| Dec 27 | 14 | EquipmentVisualizer for FBX models, WindsurferSetup wizard |
| Dec 27 | 15 | Fixed wind fallback (WindSystem→WindManager), improved error logging |
| Dec 27 | 16 | Physics stability: reduced CE height, steering torque, default sheet position |
| Dec 28 | 22 | Advanced physics improvements |
| Dec 31 | 23 | Planing fixes, underwater detection |
| Jan 1 | 24-25 | Savitsky planing, damping improvements |
| Jan 2 | 26 | **Cleanup:** Removed V1 controller, TelemetryHUD; merged Debug folders; fixed camera/steering |

---

*Last Updated: January 2, 2026*
