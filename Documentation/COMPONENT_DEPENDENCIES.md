# Component Dependencies Diagram

## How Components Connect and Reference Each Other

This diagram shows which scripts need references to which GameObjects/Components.

---

## Auto-Finding Components (No Manual Assignment Needed)

Most components automatically find their dependencies during Awake() or Start(). These work automatically:

```
WindsurfBoard (GameObject)
│
├── BuoyancyBody
│   └── Auto-finds: Rigidbody (on same GameObject)
│   └── MANUAL: _waterSurface → WaterSurface GameObject
│
├── WaterDrag
│   └── Auto-finds: Rigidbody (on same GameObject)
│   └── Auto-finds: BuoyancyBody (on same GameObject)
│
├── ApparentWindCalculator
│   └── Auto-finds: Rigidbody (on same GameObject)
│   └── Auto-finds: WindManager (in scene)
│
├── Sail
│   └── Auto-finds: Rigidbody (on same GameObject)
│   └── Auto-finds: ApparentWindCalculator (on same GameObject)
│
├── FinPhysics
│   └── Auto-finds: Rigidbody (on same GameObject)
│
└── WindsurferControllerV2
    └── Auto-finds: Rigidbody (on same GameObject)
    └── Auto-finds: Sail (on same GameObject)
    └── Auto-finds: FinPhysics (on same GameObject)
    └── Auto-finds: ApparentWindCalculator (on same GameObject)
```

```
Main Camera (GameObject)
│
└── ThirdPersonCamera
    └── MANUAL: _target → WindsurfBoard Transform
    └── Auto-finds: WaterSurface (in scene, optional)
```

```
TelemetryHUD (GameObject)
│
└── TelemetryHUD
    └── Auto-finds: WindsurferController (in scene)
    └── Auto-finds: WindsurferControllerV2 (in scene)
    └── Auto-finds: Rigidbody (from controller)
    └── Auto-finds: WindManager (in scene)
    └── Auto-finds: ApparentWind (from controller)
    └── Auto-finds: Sail (from controller)
    └── Auto-finds: WaterDrag (from controller)
    └── Auto-finds: FinPhysics (from controller)
```

---

## Data Flow: How Physics Works

### 1. Wind System
```
WindManager (Global)
    ↓ provides wind vector
ApparentWindCalculator (on Board)
    ↓ combines with board velocity
Sail (on Board)
    ↓ generates forces
Rigidbody (on Board)
```

### 2. Buoyancy System
```
WaterSurface (Global)
    ↓ provides water height
BuoyancyBody (on Board)
    ↓ applies upward forces
Rigidbody (on Board)
```

### 3. Control System
```
Keyboard Input
    ↓
WindsurferControllerV2 (on Board)
    ├─→ Sail (sheet and rake control)
    └─→ FinPhysics (weight shift affects fin)
    ↓
Rigidbody (on Board)
```

### 4. Drag System
```
Rigidbody velocity
    ↓
WaterDrag (on Board)
    ├─→ checks BuoyancyBody (is floating?)
    └─→ applies resistance
    ↓
Rigidbody (on Board)
```

### 5. Fin System
```
Rigidbody velocity (lateral movement)
    ↓
FinPhysics (on Board)
    ├─→ generates lateral force (prevents drift)
    └─→ applies tracking torque
    ↓
Rigidbody (on Board)
```

---

## Execution Order

Unity executes in this order each frame:

### Awake Phase (Component Initialization)
1. All scripts initialize
2. Auto-find references
3. Create helper objects (if needed)

### Start Phase (Scene Setup)
4. Verify all references found
5. Initialize physics state
6. Set up UI elements

### Update Phase (Every Frame)
7. WindManager updates wind variation
8. Controllers gather input
9. Controllers smooth input
10. Visual updates (SailVisualizer, etc.)

### FixedUpdate Phase (Physics Steps, 50 Hz)
11. ApparentWindCalculator computes apparent wind
12. Sail calculates forces from wind
13. FinPhysics calculates lateral forces
14. WaterDrag calculates resistance
15. BuoyancyBody calculates buoyancy
16. Controllers apply control inputs
17. Rigidbody integrates all forces

### LateUpdate Phase (After Physics)
18. ThirdPersonCamera updates position
19. UI indicators update (WindIndicator3D)

---

## Critical Dependencies

### ✅ Must Be Assigned Manually

| Component | Field | Assign To | Why Manual? |
|-----------|-------|-----------|-------------|
| BuoyancyBody | _waterSurface | WaterSurface GameObject | Can't auto-find interface |
| ThirdPersonCamera | _target | WindsurfBoard Transform | Needs to know what to follow |

### ⚙️ Auto-Find (No Action Needed)

| Component | Finds | How |
|-----------|-------|-----|
| All board scripts | Rigidbody | GetComponent on same GameObject |
| ApparentWindCalculator | WindManager | FindFirstObjectByType in scene |
| BuoyancyBody | Rigidbody | GetComponent |
| TelemetryHUD | Everything | FindFirstObjectByType for each |
| ThirdPersonCamera | BuoyancyBody | FindFirstObjectByType (optional) |
| WindsurferControllerV2 | All physics components | GetComponent on same GameObject |

---

## Component Checklist by GameObject

### WindsurfBoard MUST HAVE:
- ✓ Rigidbody (Mass: 50)
- ✓ Collider (for physics)
- ✓ BuoyancyBody (makes it float)
- ✓ WaterDrag (slows it down)
- ✓ ApparentWindCalculator (calculates wind)
- ✓ Sail (generates propulsion)
- ✓ FinPhysics (prevents sideways drift)
- ✓ One controller (V2 recommended)

### Optional on WindsurfBoard:
- SailVisualizer (shows sail movement)

### Scene MUST HAVE:
- ✓ WaterSurface GameObject with WaterSurface script
- ✓ WindManager GameObject with WindManager script
- ✓ Camera with ThirdPersonCamera script
- ✓ Light source

### Optional in Scene:
- TelemetryHUD with TelemetryHUD script
- WindIndicator3D on TelemetryHUD

---

## Script Interdependencies

### Scripts That Work Together:

```
Sail ←→ ApparentWindCalculator
  (Sail needs apparent wind to calculate forces)

WaterDrag → BuoyancyBody
  (Checks if board is floating before applying drag)

WindsurferControllerV2 → Sail, FinPhysics, ApparentWindCalculator
  (Controller modifies their parameters)

ThirdPersonCamera → WindsurfBoard Transform
  (Camera follows board position)

TelemetryHUD → All board components
  (Displays their state)
```

### Independent Scripts:

```
WindManager (standalone - provides wind to anyone who asks)
WaterSurface (standalone - provides water height to anyone who asks)
BuoyancyBody (only depends on WaterSurface and Rigidbody)
FinPhysics (only depends on Rigidbody)
```

---

## What Breaks Without Each Component

| Missing Component | Result |
|------------------|---------|
| Rigidbody | Nothing works - no physics |
| BuoyancyBody | Board sinks through water |
| WaterSurface | Board has nothing to float on |
| WindManager | No wind = no movement |
| ApparentWindCalculator | Sail can't calculate forces |
| Sail | No propulsion forces |
| FinPhysics | Board drifts sideways uncontrollably |
| WaterDrag | Board accelerates forever |
| Controller | Can't control the board |
| ThirdPersonCamera | Camera doesn't follow |

---

## Debugging: Check These First

### Board won't float:
1. Is BuoyancyBody attached? ✓
2. Is _waterSurface assigned? ✓
3. Is WaterSurface in scene? ✓
4. Is _buoyancyStrength = 1500? ✓

### Board won't move:
1. Is WindManager in scene? ✓
2. Is Sail attached? ✓
3. Is ApparentWindCalculator attached? ✓
4. Is _baseWindSpeed > 0? ✓
5. Is _sailArea > 0? ✓

### Board spins out:
1. Is FinPhysics attached? ✓
2. Is _trackingStrength > 0? ✓
3. Is Rigidbody angular damping > 0? ✓

### Camera doesn't follow:
1. Is ThirdPersonCamera attached? ✓
2. Is _target assigned to board? ✓
3. Is _followSpeed > 0? ✓

### No UI showing:
1. Is TelemetryHUD in scene? ✓
2. Is _showTelemetry checked? ✓
3. Did you press Play? (auto-finds on Start)

---

## Summary

**Only 2 manual assignments needed:**
1. BuoyancyBody._waterSurface → WaterSurface
2. ThirdPersonCamera._target → WindsurfBoard

**Everything else auto-finds on Play!**

The system is designed to be robust - most scripts will find what they need automatically. If something is missing, they log warnings to console but don't break the game.
