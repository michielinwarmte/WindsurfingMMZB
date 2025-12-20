# ⚖️ Physics Validation Report

This document reviews all physics systems implemented so far.

---

## 1. Physics Systems Overview

### 1.1 Buoyancy (`BuoyancyBody.cs`) ✅ VALIDATED
**Purpose**: Makes objects float realistically on water.

**Implementation**:
- Multi-point sampling (4 points at hull corners)
- Force proportional to submersion depth
- Damping to reduce oscillation
- Angular damping to prevent spinning

**Formula**:
```
Buoyancy Force = ρ × g × V_submerged × strength_multiplier
```

**Status**: Working correctly. Board floats and responds to waves.

---

### 1.2 Wind System (`WindManager.cs` + `ApparentWindCalculator.cs`) ✅ VALIDATED
**Purpose**: Provides realistic wind with gusts.

**Implementation**:
- Base wind speed + direction
- Perlin noise for natural variation
- Apparent wind calculation: `Apparent = True Wind - Velocity`
- Wind angle calculation for point of sail

**Key Physics**:
```
Apparent Wind = True Wind Vector - Board Velocity Vector
Apparent Angle = angle between forward direction and apparent wind
```

**Status**: Working correctly. Apparent wind shifts as expected.

---

### 1.3 Sail Physics (`Sail.cs`) ✅ VALIDATED
**Purpose**: Converts wind into propulsion.

**Implementation**:
- Lift and drag forces based on airfoil physics
- Sheet position affects sail angle of attack
- Mast rake shifts center of effort for steering
- Force applied at center of effort

**Formulas**:
```
Lift = 0.5 × ρ_air × V² × A × Cl(angle)
Drag = 0.5 × ρ_air × V² × A × Cd(angle)

Where:
  ρ_air = 1.225 kg/m³
  V = apparent wind speed
  A = sail area (default 6 m²)
  Cl = lift coefficient (varies with angle of attack)
  Cd = drag coefficient
```

**Lift Coefficient Curve**:
- 0-15°: Linear increase
- 15-25°: Maximum (~1.2)
- 25-45°: Stall (decreases)
- 45°+: Minimal lift

**Mast Rake Steering**:
```
Steering Torque = mastRake × sailForce × multiplier

Rake back (+1) → Upwind turn
Rake forward (-1) → Downwind turn
```

**Status**: Working correctly. Confirmed physics direction.

---

### 1.4 Water Drag (`WaterDrag.cs`) ✅ VALIDATED
**Purpose**: Slows the board through water resistance.

**Implementation**:
- Directional drag (forward, lateral, vertical)
- Quadratic relationship with speed
- Planing mode reduces forward drag at high speeds

**Formula**:
```
Drag Force = Cd × V × |V|  (quadratic)

Planing threshold: 4 m/s (default)
Planing reduction: 40% of normal drag
```

**Status**: Working correctly. Board accelerates to terminal velocity.

---

### 1.5 Fin Physics (`FinPhysics.cs`) ✅ VALIDATED
**Purpose**: Prevents sideways drift, enables tracking.

**Implementation**:
- Slip angle calculation (heading vs velocity)
- Hydrodynamic lift generation
- Tracking torque to align with velocity
- Stall behavior at high slip angles

**Formulas**:
```
Slip Angle = atan2(lateral_velocity, forward_velocity)

Fin Lift = 0.5 × ρ_water × V² × A_fin × Cl(slip_angle)

Where:
  ρ_water = 1025 kg/m³
  A_fin = 0.04 m² (default)
  Cl = varies with slip angle, stalls above 25°
```

**Status**: Working correctly. Board tracks when moving.

---

## 2. Control System Issues (FIXED)

### 2.1 Original Problem
The original `WindsurferController.cs` had conflicting systems:

| System | Method | Issue |
|--------|--------|-------|
| Direct torque | `ApplySteering()` | Adds raw torque from A/D |
| MoveRotation | `ApplyEdging()` | Overrides physics rotation |
| Rake torque | Sail `ApplyRakeTorque()` | Additional torque from Q/E |

**Result**: Unpredictable, fighting forces, hard to control.

### 2.2 New Controller (`WindsurferControllerV2.cs`)

**Two Control Modes**:

#### Beginner Mode (Default)
- **A/D**: Combined steering (auto mast rake + weight shift)
- **W/S**: Sheet in/out
- **Tab**: Toggle to Advanced mode
- **Assists**: Anti-capsize, smooth response

#### Advanced Mode
- **Q/E**: Mast rake (primary steering)
- **A/D**: Weight shift (secondary steering)
- **W/S**: Sheet in/out
- **Tab**: Toggle to Beginner mode

**Key Improvements**:
1. Uses `AddTorque` instead of `MoveRotation` (works WITH physics)
2. Weight shift creates gentle turning moment
3. Edging uses torque, not direct rotation
4. Anti-capsize prevents flipping
5. All forces work together, not against each other

---

## 3. Physics Realism Checklist

### What We Have ✅
- [x] Buoyancy with multi-point sampling
- [x] True wind with gusts
- [x] Apparent wind calculation
- [x] Sail lift/drag aerodynamics
- [x] Mast rake steering
- [x] Water drag with planing
- [x] Fin hydrodynamics with slip/stall
- [x] Anti-capsize stabilization

### What We Could Add 📋
- [ ] Wave forces on hull (currently just height)
- [ ] Board pitch from sail force (nose up/down)
- [ ] Sailor weight position (more detailed)
- [ ] Catapult / nosedive physics
- [ ] Harness line mechanics
- [ ] Footstrap engagement

---

## 4. Recommended Parameter Tuning

### For Easy Control (Beginner-Friendly)
```
Sail:
  - Rake Torque Multiplier: 0.8-1.0 (stronger steering)
  - Rake Speed: 3.0 (quicker response)

Fin:
  - Lift Coefficient: 5-6 (more grip)
  - Stall Angle: 30° (more forgiving)
  - Tracking Strength: 3.0 (more stable)

Controller V2:
  - Weight Shift Strength: 20-25
  - Anti-Capsize: ON
  - Combined Steering: ON
```

### For Realistic Feel (Advanced)
```
Sail:
  - Rake Torque Multiplier: 0.3-0.5
  - Rake Speed: 2.0

Fin:
  - Lift Coefficient: 4
  - Stall Angle: 25°
  - Tracking Strength: 2.0

Controller V2:
  - Weight Shift Strength: 10-15
  - Anti-Capsize: OFF (realistic capsizing)
  - Combined Steering: OFF
```

---

## 5. Testing Procedures

### Test 1: Basic Floating
1. Place board on water
2. Should float at equilibrium
3. Should stabilize after disturbance

### Test 2: Sailing Straight
1. Position board perpendicular to wind
2. Sheet in (W)
3. Should accelerate forward
4. Should reach terminal velocity (~15-20 knots in 15 knot wind)

### Test 3: Upwind Sailing
1. Point ~45° to wind
2. Rake mast back (E) or steer with A/D
3. Should be able to sail upwind
4. Board should track, not slide sideways

### Test 4: Downwind Sailing
1. Point away from wind
2. Rake mast forward (Q) or steer with A/D
3. Should be able to bear away
4. Speed should increase (true wind + boat speed)

### Test 5: Tacking/Gybing
1. Execute a turn through the wind
2. Board should maintain momentum
3. Sail force should reverse sides
4. Should complete turn smoothly

---

*Last Updated: December 20, 2025*
