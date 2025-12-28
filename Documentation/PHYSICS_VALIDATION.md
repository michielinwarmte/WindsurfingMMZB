# 🎯 Physics Validation Document

**Status: ✅ WORKING** (as of December 27, 2025)

This document records the validated physics formulas and sign conventions that make the windsurfing simulation work correctly. **DO NOT CHANGE THESE FORMULAS** without understanding the complete system.

---

## ⚠️ CRITICAL: Working Physics Configuration

The physics system is interconnected. Changing any single formula without understanding the whole chain will break the simulation.

### Validated Behaviors
- ✅ Upwind sailing (can sail ~45° to wind)
- ✅ Planing at high speeds
- ✅ Correct sail side switching when tacking
- ✅ Rake steering works on both tacks
- ✅ Stable at high speeds (20+ knots)

---

## 1. Sign Conventions (Unity Coordinate System)

```
Unity Left-Handed Coordinate System:

        Y (up)
        │
        │    Board heading this way
        │         ↓
        └──────────── X (starboard/right)
       ╱
      ╱
     Z (forward/bow)
```

### Apparent Wind Angle (AWA) Convention

**File:** `SailingState.cs` → `CalculateApparentWind()`

```csharp
ApparentWindAngle = Vector3.SignedAngle(fwdHorizontal, -awHorizontal.normalized, Vector3.up);
```

| Wind Coming From | AWA Sign |
|-----------------|----------|
| Port (left)     | POSITIVE |
| Starboard (right) | NEGATIVE |
| Dead ahead      | ~0°      |
| Dead astern     | ~±180°   |

**IMPORTANT:** The negative sign on `awHorizontal` converts wind velocity direction TO wind source direction.

---

## 2. Sail Side Determination

**File:** `AdvancedSail.cs` → `CalculateSailGeometry()`

The sail always goes to the **LEEWARD** side (away from wind).

```csharp
sailSide = -Mathf.Sign(_state.ApparentWindAngle);
```

| AWA | sailSide | Meaning |
|-----|----------|---------|
| > 0 (wind from port) | -1 | Sail on starboard (right) |
| < 0 (wind from starboard) | +1 | Sail on port (left) |

### Why the Negative Sign?

- `Sign(AWA)` tells us which side the wind is FROM
- Sail goes to OPPOSITE side (leeward)
- Therefore: `sailSide = -Sign(AWA)`

### Hysteresis

When `|AWA| < 5°`, the sail maintains its previous side to prevent oscillation during tacks:

```csharp
if (absAWA < 5f)
{
    sailSide = _lastSailSide;  // Maintain current side
}
```

---

## 3. Sail Normal Direction

**File:** `AdvancedSail.cs` → `CalculateSailGeometry()`

The sail normal points toward the **WINDWARD** side (where wind comes from).

```csharp
// Cross product gives perpendicular to sail chord
Vector3 localSailNormal = Vector3.Cross(localSailChord, Vector3.up).normalized;

// Ensure normal points INTO the wind
if (Vector3.Dot(localSailNormal, -localWindDir) < 0)
{
    localSailNormal = -localSailNormal;
}
```

This is critical because the lift force direction depends on sail normal orientation.

---

## 4. Lift Force Direction (THE KEY FORMULA)

**File:** `Aerodynamics.cs` → `CalculateSailForces()`

Lift force is perpendicular to wind direction. The direction is determined by projecting **-sailNormal** onto the wind-perpendicular plane:

```csharp
// Force direction is OPPOSITE to sail normal (from high to low pressure)
Vector3 forceDir = -sailNormalHoriz;

// Project onto perpendicular-to-wind plane
float forceDotWind = Vector3.Dot(forceDir, windHoriz);
Vector3 liftDir = forceDir - forceDotWind * windHoriz;
liftDir.Normalize();

// Final lift force
liftForce = liftDir * liftMag * liftSign;
```

### Physics Explanation

```
Wind Flow and Pressure:

    High Pressure          Low Pressure
    (windward side)        (leeward side)
         │                      │
         │    ┌─────────┐      │
         │    │         │      │
         └───▶│  SAIL   │◀─────┘
              │         │
              └─────────┘
                  │
                  ▼
            Force Direction
         (from high to low pressure)
         (opposite to sail normal)
```

### Why -sailNormal?

1. `sailNormal` points toward the windward (high pressure) side
2. Pressure difference creates force FROM high TO low pressure
3. Therefore force direction = `-sailNormal`
4. We project this onto the wind-perpendicular plane to get lift direction

---

## 5. Rake Steering

**File:** `AdvancedSail.cs` → `ApplyRakeSteering()`

Mast rake creates steering torque by moving the Center of Effort (CE) fore/aft.

```csharp
// NEGATE sailSide so positive rake (back) turns into wind (away from sail)
float tack = -_state.SailSide;  // = Sign(AWA)
float steeringTorque = _mastRake * tack * forceMag * 0.5f;
```

### Behavior

| Rake | Tack | Effect |
|------|------|--------|
| Back (+) | Starboard (wind from right, sailSide=-1, tack=+1) | Turn right (head up/upwind) |
| Back (+) | Port (wind from left, sailSide=+1, tack=-1) | Turn left (head up/upwind) |
| Forward (-) | Starboard (wind from right, sailSide=-1, tack=+1) | Turn left (bear away/downwind) |
| Forward (-) | Port (wind from left, sailSide=+1, tack=-1) | Turn right (bear away/downwind) |

**Key insight:** Raking BACK always turns you UPWIND (into the wind), regardless of tack.
Raking FORWARD always turns you DOWNWIND (away from wind), regardless of tack.

### High-Speed Damping

Steering sensitivity reduces at high speeds to prevent instability:

```csharp
if (speedKnots > 15f)
{
    steeringScale = Mathf.Lerp(1f, 0.3f, (speedKnots - 15f) / 10f);
}
```

---

## 6. High-Speed Stability

**File:** `AdvancedHullDrag.cs`

Angular damping increases at high speeds:

```csharp
// Speed-dependent angular damping
float speedKnots = boatSpeed * PhysicsConstants.MS_TO_KNOTS;
float dampingMultiplier = 1f;
if (speedKnots > 15f)
{
    dampingMultiplier = Mathf.Lerp(1f, 5f, (speedKnots - 15f) / 15f);
}
Vector3 angularDamping = -angularVelocity * baseAngularDamping * dampingMultiplier;
```

---

## 7. The Complete Force Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHYSICS CALCULATION CHAIN                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. TRUE WIND                                                    │
│     │                                                            │
│     ▼                                                            │
│  2. APPARENT WIND = TrueWind - BoatVelocity                     │
│     │                                                            │
│     ▼                                                            │
│  3. APPARENT WIND ANGLE (AWA)                                    │
│     SignedAngle(forward, -apparentWind, up)                     │
│     │                                                            │
│     ▼                                                            │
│  4. SAIL SIDE = -Sign(AWA)                                      │
│     │                                                            │
│     ▼                                                            │
│  5. SAIL ANGLE = sheetPosition * sailSide                       │
│     │                                                            │
│     ▼                                                            │
│  6. SAIL CHORD = (sin(angle), 0, -cos(angle))                   │
│     │                                                            │
│     ▼                                                            │
│  7. SAIL NORMAL = Cross(chord, up), oriented toward wind        │
│     │                                                            │
│     ▼                                                            │
│  8. LIFT DIRECTION = project(-sailNormal) onto wind-perp plane  │
│     │                                                            │
│     ▼                                                            │
│  9. LIFT FORCE = liftDir * Cl * 0.5 * ρ * V² * A                │
│     │                                                            │
│     ▼                                                            │
│  10. FORWARD DRIVE = Lift · boatForward (positive = go forward) │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Files and Their Responsibilities

| File | Purpose | Key Formulas |
|------|---------|--------------|
| `SailingState.cs` | Wind calculations | AWA = SignedAngle(fwd, -AW, up) |
| `AdvancedSail.cs` | Sail geometry | sailSide = -Sign(AWA) |
| `Aerodynamics.cs` | Force calculation | liftDir = project(-sailNormal) |
| `AdvancedHullDrag.cs` | Stability | Speed-dependent damping |
| `AdvancedFin.cs` | Lateral resistance | Prevents sideslip |

---

## 9. Common Mistakes to Avoid

### ❌ DON'T: Change sign conventions independently

Each sign is carefully coordinated with others. Changing one without updating all related formulas will break physics.

### ❌ DON'T: Use `sailNormal` directly for lift

The lift direction is `-sailNormal` (opposite to normal), not `sailNormal`.

### ❌ DON'T: Flip AWA sign

The AWA sign convention propagates through sailSide, rake steering, and more. Flipping it requires updating many formulas.

### ❌ DON'T: Change sailSide without updating rake steering

`sailSide` is used in rake steering. If you change how sailSide is calculated, you may need to adjust rake steering too.

---

## 10. Testing Checklist

When making physics changes, verify ALL of these:

- [ ] Can sail ~45° upwind on starboard tack
- [ ] Can sail ~45° upwind on port tack  
- [ ] Tacking works (sail switches sides)
- [ ] Rake back = bear away on both tacks
- [ ] Rake forward = head up on both tacks
- [ ] Stable at 20+ knots
- [ ] Planing works
- [ ] No oscillation when switching sides

---

## 11. Legacy Physics Systems (Reference Only)

These systems still exist but the core validated physics is documented above.

### Buoyancy (`BuoyancyBody.cs` / `AdvancedBuoyancy.cs`)
- Multi-point sampling
- Force proportional to submersion depth
- Angular damping to prevent spinning

### Fin Physics (`AdvancedFin.cs`)
- Slip angle calculation
- Hydrodynamic lift generation
- Stall behavior at high slip angles

### Water Drag (`AdvancedHullDrag.cs`)
- Directional drag (forward, lateral, vertical)
- Planing mode reduces forward drag at high speeds
- Speed-dependent angular damping for stability

---

*Last Updated: December 27, 2025*
*Status: VALIDATED AND WORKING*
