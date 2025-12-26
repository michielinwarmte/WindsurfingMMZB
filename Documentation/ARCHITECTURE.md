# 🏗️ Architecture & Codebase Reference

This document provides a complete overview of the codebase for team collaboration.

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
│   ├── Wind       → IWindProvider, WindManager
│   ├── Buoyancy   → BuoyancyBody
│   └── Board      → Sail, FinPhysics, WaterDrag, ApparentWindCalculator
├── Player         → WindsurferController, WindsurferControllerV2
├── CameraSystem   → ThirdPersonCamera
├── UI             → TelemetryHUD, SailPositionIndicator, WindIndicator3D
├── Visual         → SailVisualizer
└── Utilities      → PhysicsHelpers, WaterGridMarkers
```

---

## Script Inventory

### Physics Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [IWaterSurface.cs](../WindsurfingGame/Assets/Scripts/Physics/Water/IWaterSurface.cs) | Physics.Water | Interface for water height queries | - |
| [WaterSurface.cs](../WindsurfingGame/Assets/Scripts/Physics/Water/WaterSurface.cs) | Physics.Water | Implements water surface with waves | IWaterSurface |
| [IWindProvider.cs](../WindsurfingGame/Assets/Scripts/Physics/Wind/IWindProvider.cs) | Physics.Wind | Interface for wind queries | - |
| [WindManager.cs](../WindsurfingGame/Assets/Scripts/Physics/Wind/WindManager.cs) | Physics.Wind | Global wind control | IWindProvider |
| [BuoyancyBody.cs](../WindsurfingGame/Assets/Scripts/Physics/Buoyancy/BuoyancyBody.cs) | Physics.Buoyancy | Multi-point buoyancy | IWaterSurface, Rigidbody |
| [Sail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/Sail.cs) | Physics.Board | Sail aerodynamics & forces | ApparentWindCalculator, Rigidbody |
| [ApparentWindCalculator.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/ApparentWindCalculator.cs) | Physics.Board | True wind → apparent wind | IWindProvider, Rigidbody |
| [WaterDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/WaterDrag.cs) | Physics.Board | Hydrodynamic resistance | IWaterSurface, Rigidbody |
| [FinPhysics.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/FinPhysics.cs) | Physics.Board | Fin grip & lateral resistance | Rigidbody |

### Player Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [WindsurferController.cs](../WindsurfingGame/Assets/Scripts/Player/WindsurferController.cs) | Player | Original basic controls | Sail, Unity Input System |
| [WindsurferControllerV2.cs](../WindsurfingGame/Assets/Scripts/Player/WindsurferControllerV2.cs) | Player | Advanced controls (Beginner/Advanced modes) | Sail, Unity Input System |

### UI Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [TelemetryHUD.cs](../WindsurfingGame/Assets/Scripts/UI/TelemetryHUD.cs) | UI | On-screen telemetry display | Rigidbody, Sail, ApparentWindCalculator, WindManager |
| [SailPositionIndicator.cs](../WindsurfingGame/Assets/Scripts/UI/SailPositionIndicator.cs) | UI | 2D top-down sail position | Sail, ApparentWindCalculator |
| [WindIndicator3D.cs](../WindsurfingGame/Assets/Scripts/UI/WindIndicator3D.cs) | UI | 3D wind arrow display | WindManager, ApparentWindCalculator |

### Visual Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [SailVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/SailVisualizer.cs) | Visual | 3D sail mesh visualization | Sail, ApparentWindCalculator |

### Camera Layer

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [ThirdPersonCamera.cs](../WindsurfingGame/Assets/Scripts/CameraSystem/ThirdPersonCamera.cs) | CameraSystem | Follow camera for board | Transform target |

### Utilities

| Script | Namespace | Purpose | Key Dependencies |
|--------|-----------|---------|------------------|
| [PhysicsHelpers.cs](../WindsurfingGame/Assets/Scripts/Utilities/PhysicsHelpers.cs) | Utilities | Constants & helper methods | - |
| [WaterGridMarkers.cs](../WindsurfingGame/Assets/Scripts/Utilities/WaterGridMarkers.cs) | Utilities | Debug grid visualization | IWaterSurface |

---

## Component Dependencies

### Windsurfer GameObject Setup

The main windsurfer requires these components:

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
└── WindsurferControllerV2 (or WindsurferController)
    └── Requires: Sail
```

### Scene Singletons

```
Scene
├── WindManager (implements IWindProvider)
│   └── Found via: FindFirstObjectByType<IWindProvider>()
└── WaterSurface (implements IWaterSurface)
    └── Found via: FindFirstObjectByType<IWaterSurface>()
```

---

## Key Data Flow

### Wind → Board Movement

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

### Water → Buoyancy

```
WaterSurface (wave heights)
    ↓
BuoyancyBody (samples at multiple points)
    ↓
Rigidbody.AddForceAtPosition (buoyancy forces)
    ↓
Board floats
```

### Simulation → Visualization

```
Sail.CurrentSailAngle (simulation output)
    ↓
SailVisualizer (reads value, renders 3D sail)
SailPositionIndicator (reads value, renders 2D HUD)

IMPORTANT: Visualizers NEVER calculate physics values independently.
           They only READ from simulation components.
```

---

## Control Modes

### WindsurferControllerV2

| Mode | Sheet Control | Rake Control | Best For |
|------|---------------|--------------|----------|
| Beginner | Auto-trims to optimal | A/D keys | New players |
| Advanced | W/S (sheet in/out) | A/D keys | Experienced |

### Default Controls

| Key | Action |
|-----|--------|
| W | Sheet in (closer to wind) |
| S | Sheet out (away from wind) |
| A | Rake mast forward (bear off) |
| D | Rake mast back (head up) |
| Tab | Toggle control mode |

---

## Physics Constants

Located in `PhysicsHelpers.cs`:

| Constant | Value | Description |
|----------|-------|-------------|
| WATER_DENSITY | 1025 kg/m³ | Seawater density |
| AIR_DENSITY | 1.225 kg/m³ | Air density at sea level |
| GRAVITY | 9.81 m/s² | Gravitational acceleration |

---

## File Locations

### Scripts
```
Assets/Scripts/Physics/Water/         → Water surface, interfaces
Assets/Scripts/Physics/Wind/          → Wind system
Assets/Scripts/Physics/Buoyancy/      → Buoyancy simulation
Assets/Scripts/Physics/Board/         → Sail, fin, drag physics
Assets/Scripts/Player/                → Player controllers
Assets/Scripts/Camera/                → Camera systems (namespace: CameraSystem)
Assets/Scripts/UI/                    → HUD and indicators
Assets/Scripts/Visual/                → 3D visualizers
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
| No wind force | Ensure WindManager exists in scene |

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

---

*Last Updated: December 26, 2025*
