# Component Dependencies Diagram

## How Components Connect and Reference Each Other

This diagram shows which scripts need references to which GameObjects/Components.

**Last Updated:** December 27, 2025

---

## ⚠️ CRITICAL: Physics Formula Chain

The physics calculations form an interconnected chain. See [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md) for details.

**DO NOT modify these formulas without understanding the full chain:**
- AWA = `SignedAngle(forward, -apparentWind, up)` → SailingState.cs
- sailSide = `-Sign(AWA)` → AdvancedSail.cs
- liftDir = `project(-sailNormal)` onto wind-perpendicular → Aerodynamics.cs
- rakeSteeringTack = `sailSide` → AdvancedSail.cs

---

## Recommended Setup: Advanced Physics Stack

For realistic windsurfing physics, use these components on the board:

```
WindsurfBoard (GameObject)
│
├── Rigidbody                      # Required - Unity physics
│   └── Mass: 90kg, Drag: 0.5, Angular Drag: 2.0
│
├── AdvancedBuoyancy               # Multi-point flotation
│   └── MANUAL: _waterSurface → WaterSurface GameObject
│
├── AdvancedHullDrag               # Drag + high-speed stability
│   └── Auto-finds: Rigidbody
│   └── Provides: Speed-dependent angular damping
│
├── AdvancedSail                   # Sail forces + rake steering
│   └── Auto-finds: Rigidbody, WindSystem
│   └── Calculates: sailSide, sailNormal, lift/drag forces
│   └── KEY FORMULA: sailSide = -Sign(AWA)
│
├── AdvancedFin                    # Lateral resistance
│   └── Auto-finds: Rigidbody
│   └── Provides: Prevents sideslip, enables tracking
│
└── AdvancedWindsurferController   # Player input
    └── Auto-finds: Rigidbody, AdvancedSail
    └── Modes: Beginner / Intermediate / Advanced
```

```
Scene Required Objects
│
├── WindSystem                     # Preferred wind source
│   └── Provides: True wind with gusts, shifts, height gradient
│   └── Auto-finds: Nothing (standalone)
│
├── WaterSurface                   # Water height provider
│   └── Provides: GetWaterHeight(position)
│   └── Auto-finds: Nothing (standalone)
│
└── Main Camera
    └── ThirdPersonCamera
        └── MANUAL: _target → WindsurfBoard Transform
```

---

## Legacy Setup: Basic Physics Stack

For simpler physics (prototyping):

```
WindsurfBoard (GameObject)
│
├── Rigidbody
├── BuoyancyBody                   # Simple buoyancy
│   └── MANUAL: _waterSurface → WaterSurface
├── WaterDrag                      # Basic drag
├── ApparentWindCalculator         # Wind calculation
├── Sail                           # Basic sail forces
├── FinPhysics                     # Basic fin
└── WindsurferControllerV2         # Basic controller
```

```
Scene Required Objects
│
├── WindManager                    # Basic wind source
└── WaterSurface
```

---

## Data Flow: Advanced Physics Chain

### 1. Wind → Apparent Wind → AWA
```
WindSystem (provides true wind)
    ↓
AdvancedSail.UpdateWindState()
    ↓ calculates ApparentWind = TrueWind - BoatVelocity
SailingState.CalculateApparentWind()
    ↓ AWA = SignedAngle(forward, -apparentWind, up)
    ↓ Port wind → AWA > 0
    ↓ Starboard wind → AWA < 0
```

### 2. AWA → Sail Side → Sail Geometry
```
ApparentWindAngle (from step 1)
    ↓
sailSide = -Sign(AWA)      ← KEY FORMULA
    ↓ AWA > 0 → sailSide = -1 (sail on starboard)
    ↓ AWA < 0 → sailSide = +1 (sail on port)
    ↓
sailAngle = sheetPosition × sailSide
    ↓
sailChord = (sin(angle), 0, -cos(angle))
    ↓
sailNormal = Cross(chord, up), oriented toward wind
```

### 3. Sail Normal → Lift Direction → Force
```
sailNormal (points toward windward)
    ↓
Aerodynamics.CalculateSailForces()
    ↓
forceDir = -sailNormal     ← Force from high to low pressure
    ↓
liftDir = project(forceDir) onto wind-perpendicular plane
    ↓
liftForce = liftDir × Cl × 0.5 × ρ × V² × A
    ↓
Apply at Center of Effort → drives board forward!
```

### 4. Rake Steering
```
MastRake input (Q/E or auto from A/D in beginner)
    ↓
tack = sailSide            ← Uses same sailSide from step 2
    ↓
steeringTorque = rake × tack × forceMag
    ↓
Rake back + starboard tack → turn left (bear away)
Rake back + port tack → turn right (bear away)
```

### 5. High-Speed Stability
```
AdvancedHullDrag.ApplyAngularDamping()
    ↓
speedKnots > 15 → increase angular damping
    ↓
dampingMultiplier = Lerp(1, 5, (speed - 15) / 15)
    ↓
Prevents high-speed wobble
```

---

---

## Execution Order (Advanced Stack)

### Awake Phase
1. Components initialize
2. Auto-find references (Rigidbody, WindSystem, etc.)

### Start Phase
3. Verify references found
4. Initialize physics state
5. Log warnings if missing dependencies

### FixedUpdate Phase (50 Hz - Physics)
6. **WindSystem** updates wind variation (gusts, shifts)
7. **AdvancedSail.UpdateWindState()** gets true wind, calculates apparent wind
8. **SailingState.CalculateApparentWind()** computes AWA
9. **AdvancedSail.CalculateSailGeometry()** determines sail side, normal, angle
10. **AdvancedSail.CalculateSailForces()** calls Aerodynamics for lift/drag
11. **AdvancedFin** calculates lateral lift, prevents sideslip
12. **AdvancedHullDrag** applies drag + angular damping
13. **AdvancedBuoyancy** calculates flotation forces
14. **AdvancedWindsurferController** processes input, applies controls
15. **Rigidbody** integrates all forces

### LateUpdate Phase
16. **ThirdPersonCamera** follows board
17. UI updates (TelemetryHUD, indicators)

---

## Critical Dependencies

### ✅ Must Be Assigned Manually (Only 2!)

| Component | Field | Assign To | Why Manual? |
|-----------|-------|-----------|-------------|
| AdvancedBuoyancy | _waterSurface | WaterSurface GameObject | Interface lookup needed |
| ThirdPersonCamera | _target | WindsurfBoard Transform | Must know what to follow |

### ⚙️ Auto-Find (No Action Needed)

| Component | Finds | How |
|-----------|-------|-----|
| AdvancedSail | WindSystem, Rigidbody | FindFirstObjectByType, GetComponent |
| AdvancedSail | WindManager (fallback) | FindFirstObjectByType if no WindSystem |
| AdvancedFin | Rigidbody | GetComponent |
| AdvancedHullDrag | Rigidbody | GetComponent |
| AdvancedWindsurferController | AdvancedSail, Rigidbody | GetComponent |
| AdvancedTelemetryHUD | All components | FindFirstObjectByType |

---

## Component Checklist

### WindsurfBoard MUST HAVE:
- ✓ Rigidbody (Mass: 90, Drag: 0.5, Angular Drag: 2.0)
- ✓ Collider (for physics)
- ✓ AdvancedBuoyancy (or BuoyancyBody)
- ✓ AdvancedHullDrag (or WaterDrag)
- ✓ AdvancedSail (or Sail + ApparentWindCalculator)
- ✓ AdvancedFin (or FinPhysics)
- ✓ AdvancedWindsurferController (or WindsurferControllerV2)

### Scene MUST HAVE:
- ✓ WindSystem (or WindManager for legacy)
- ✓ WaterSurface with WaterSurface script
- ✓ Camera with ThirdPersonCamera
- ✓ Directional Light

### Optional:
- AdvancedTelemetryHUD (debug info)
- SailVisualizer (visual feedback)
- ForceVectorVisualizer (debug arrows)
- WindDirectionIndicator (wind visualization)

---

## What Breaks Without Each Component

| Missing Component | Result |
|------------------|---------|
| Rigidbody | Nothing works - no physics |
| AdvancedBuoyancy | Board sinks through water |
| WaterSurface | Buoyancy has nothing to sample |
| WindSystem/WindManager | No wind = no sail force |
| AdvancedSail | No propulsion, no steering |
| AdvancedFin | Board slides sideways, can't track |
| AdvancedHullDrag | No speed limit, no stability |
| Controller | Can't control the board |
| ThirdPersonCamera._target | Camera doesn't follow |

---

## Debugging Quick Reference

### Board won't float:
1. AdvancedBuoyancy attached? ✓
2. _waterSurface assigned? ✓
3. WaterSurface in scene? ✓
4. Rigidbody mass reasonable (~90kg)? ✓

### Board won't move:
1. WindSystem or WindManager in scene? ✓
2. AdvancedSail attached? ✓
3. Wind speed > 0? ✓
4. Not in irons (AWA < 30°)? ✓

### Can't go upwind:
1. Check PHYSICS_VALIDATION.md formulas
2. sailSide = -Sign(AWA)? ✓
3. liftDir uses -sailNormal? ✓
4. Fin providing lateral resistance? ✓

### Board spins at high speed:
1. AdvancedHullDrag attached? ✓
2. Speed-dependent damping working? ✓
3. Rigidbody angular drag > 0? ✓

### Rake steering inverted:
1. Check sailSide formula
2. tack = sailSide in ApplyRakeSteering()? ✓
3. See PHYSICS_VALIDATION.md for correct signs

---

## Summary

**Only 2 manual assignments needed:**
1. AdvancedBuoyancy._waterSurface → WaterSurface
2. ThirdPersonCamera._target → WindsurfBoard

**Everything else auto-finds!**

**Critical formulas documented in:** [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md)
