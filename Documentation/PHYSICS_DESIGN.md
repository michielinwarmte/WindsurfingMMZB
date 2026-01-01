# 🔬 Physics Design Document

This document explains the physics systems in our windsurfing simulator.

**Last Updated:** January 1, 2026

## Overview

Our simulation combines several physics systems:

```
┌─────────────────────────────────────────────────────────────┐
│                    WINDSURFING PHYSICS                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────┐     ┌─────────┐     ┌──────────────┐         │
│   │  WIND   │────▶│  SAIL   │────▶│    BOARD     │         │
│   │ SYSTEM  │     │ FORCES  │     │   PHYSICS    │         │
│   └─────────┘     └─────────┘     └──────┬───────┘         │
│                                          │                  │
│   ┌─────────┐     ┌─────────┐     ┌──────┴───────┐         │
│   │  WAVE   │────▶│BUOYANCY │◀───▶│ HYDRODYNAMIC │         │
│   │ SYSTEM  │     │ FORCES  │     │    LIFT      │         │
│   └─────────┘     └─────────┘     └──────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Water & Wave System

### Wave Types

#### Sine Waves (Basic)
Simple wave for initial development:
```
y = A × sin(k × x - ω × t)

Where:
  A = amplitude (wave height)
  k = wave number (2π / wavelength)
  ω = angular frequency (2π / period)
  t = time
```

#### Gerstner Waves (Realistic)
Circular motion creates realistic wave shapes:
```
x' = x - (Q × A) × sin(k × x - ω × t)
y' = A × cos(k × x - ω × t)

Where:
  Q = steepness parameter (0 to 1)
```

Multiple Gerstner waves are combined for complex seas.

### Wave Parameters

| Parameter | Calm | Moderate | Rough |
|-----------|------|----------|-------|
| Wave Height | 0.1-0.3m | 0.5-1.0m | 1.5-3.0m |
| Wavelength | 10-20m | 30-50m | 50-100m |
| Period | 3-5s | 5-8s | 8-12s |

---

## 2. Buoyancy System

### Archimedes' Principle

An object in water experiences an upward force equal to the weight of water displaced.

```
F_buoyancy = ρ_water × V_submerged × g

Where:
  ρ_water = 1025 kg/m³ (seawater)
  V_submerged = volume below waterline
  g = 9.81 m/s²
```

### Multi-Point Buoyancy

For realistic behavior, we sample buoyancy at multiple points:

```
Board Top View (7x3 = 21 sample points):
    ┌───────────────────┐
    │ ●       ●       ● │  ← Front points (less volume due to taper)
    │                   │
    │ ●       ●       ● │  ← Front-mid points
    │                   │
    │ ●       ●       ● │  ← Center points (most volume)
    │                   │
    │ ●       ●       ● │  ← Rear-mid points
    │                   │
    │ ●       ●       ● │  ← Rear points
    │                   │
    │ ●       ●       ● │  ← Tail points (less volume, tail rocker)
    │                   │
    │ ●               ● │  ← Tail tip
    └───────────────────┘
```

Each point:
1. Samples water height at its position
2. Calculates depth below/above water
3. Applies proportional force based on local volume

### Hull Shape Modeling

The buoyancy system accounts for realistic hull geometry:

```csharp
// Rocker (bottom curvature)
noseRocker = 0.08m;   // 8cm rise at nose
tailRocker = 0.02m;   // 2cm rise at tail

// Taper (width reduction at ends)
taperFactor = 0.5;    // Ends are 50% as wide as center

// Volume distribution
volumeWeights = {0.6, 0.8, 1.0, 1.0, 0.9, 0.7, 0.5}  // Nose to tail
```

### Damping

Separate damping coefficients for stable behavior:
- **Vertical damping**: 4000 N·s/m (prevents vertical oscillation)
- **Water viscosity**: 400 N·s²/m² (velocity-squared damping for realistic water feel)
- **Roll damping**: 150 N·m·s/rad (prevents tipping)
- **Pitch damping**: 150 N·m·s/rad (prevents porpoising)
- **Yaw damping**: Lower (allows turning)

The vertical damping uses a hybrid formula:
```
F_damping = -v × linearDamping × submersion - v × |v| × viscosity × submersion
```
This combines linear damping (stability) with viscous v² damping (realism).

### Water Resistance

Objects moving through water experience drag:

```
F_drag = 0.5 × ρ × v² × Cd × A

Where:
  ρ = water density
  v = velocity through water
  Cd = drag coefficient
  A = cross-sectional area
```

---

## 3. Hydrodynamic Lift System

⚠️ **NEW in Session 22** - Two-stage lift system for realistic behavior.

### The Problem

Without hydrodynamic lift:
- Board sinks 75%+ even when moving
- No transition to planing mode
- Unrealistic heavy feel

### Two-Stage Solution

#### Stage 1: Displacement Lift (Pre-Planing)

At low speeds, forward motion creates dynamic pressure that provides lift:

```csharp
// Displacement lift formula - does NOT scale with submersion depth
q = 0.5 × ρ_water × v²;           // Dynamic pressure
planformArea = boardLength × boardWidth × 0.8;

// Binary check: must be touching water, but lift doesn't scale with depth
if (submersionRatio < 0.05f) return;  // Not in water

displacementLift = liftCoeff × q × planformArea;

// Cap at fraction of weight - buoyancy is still primary support
maxLift = totalMass × gravity × 0.3;
displacementLift = Mathf.Min(displacementLift, maxLift);

// Fades out as planing takes over
displacementLift *= (1 - planingRatio);
```

**Parameters:**
- `displacementLiftCoefficient`: 0.12
- `displacementLiftMinSpeed`: 0.5 m/s (~2 km/h)

#### Stage 2: Planing Lift (High Speed) - Savitsky Equations

At planing speeds, the board rides on hydrodynamic lift using the Savitsky planing theory:

```csharp
// Savitsky Lift Coefficient
// CL = τ^1.1 × (0.012 × λ^0.5 + 0.0055 × λ^2.5 / Cv²)
//
// Where:
//   τ = trim angle (degrees, bow-up)
//   λ = wetted length / beam ratio
//   Cv = speed coefficient = V / √(g × beam)

float Cv = speed / Mathf.Sqrt(g * beam);
float lambda = Mathf.Lerp(lambdaMax, 1.5f, planingRatio);

float dynamicTerm = 0.012f * Mathf.Sqrt(lambda);
float hydrostaticTerm = 0.0055f * Mathf.Pow(lambda, 2.5f) / (Cv * Cv);
float CL0 = Mathf.Pow(tau, 1.1f) * (dynamicTerm + hydrostaticTerm);

// Deadrise correction: CL = CL0 - 0.0065 × β × CL0^0.6
float CL = CL0 - 0.0065f * deadrise * Mathf.Pow(CL0, 0.6f);

// Lift force: L = CL × 0.5ρV² × beam²
float lift = CL * 0.5f * waterDensity * speed * speed * beam * beam;
```

**Key Physics Insight - No Submersion Feedback:**
Unlike the previous implementation, lift depends on **speed and trim angle only**, not submersion depth. This prevents the trampoline/oscillation problem:
- Submersion is only a binary check: is the board touching water?
- At a given speed/trim, lift is constant
- Board height is controlled by buoyancy equilibrium, not lift equilibrium

**Parameters:**
- `planingLiftCoefficient`: 0.8 (Savitsky typical: 0.5-1.0)
- `maxLiftFraction`: 0.85 (prevents flying out - lift capped at 85% of weight)
- `liftSmoothingFactor`: 0.08 (smooth transitions)

### Combined Lift Application

```csharp
void ApplyHydrodynamicLift()
{
    float totalLift = _displacementLift + _planingLift;
    
    if (submersionRatio < 0.05f)
        return;  // Don't apply when above water
    
    // Different application points
    if (_planingRatio > 0.5f)
    {
        // Planing: apply at center + rear (trim control)
        Vector3 liftPoint = transform.position - transform.forward * 0.3f;
        _rigidbody.AddForceAtPosition(Vector3.up * totalLift, liftPoint);
    }
    else
    {
        // Displacement: apply at center
        _rigidbody.AddForce(Vector3.up * totalLift);
    }
}
```

---

## 3. Wind System

### True Wind vs Apparent Wind

**True Wind**: Actual wind in the environment
**Apparent Wind**: Wind experienced by moving sailor

```
Apparent Wind = True Wind - Sailor Velocity

       True Wind (10 m/s)
            ↓
    ←───────●
    Board moving (5 m/s)
            
    Apparent wind comes from
    forward-right diagonal
```

### Wind Force on Sail

The sail acts like an airfoil, generating lift and drag:

```
F_lift = 0.5 × ρ_air × V² × A × Cl(α)
F_drag = 0.5 × ρ_air × V² × A × Cd(α)

Where:
  ρ_air = 1.225 kg/m³
  V = apparent wind speed
  A = sail area (typically 4-10 m²)
  α = angle of attack
  Cl, Cd = coefficients (vary with angle)
```

### Lift/Drag Coefficients

```
     Cl
    1.5│      ╱╲
       │     ╱  ╲
    1.0│    ╱    ╲
       │   ╱      ╲
    0.5│  ╱        ╲
       │ ╱          ╲
    0.0├───────────────── α
       0   15   30   45°
       
    Peak lift around 15-20° angle of attack
    Stall (lift drops) above ~25°
```

### Sail Geometry

The sail is mounted on a mast with a **fixed base position** (mast foot). The key geometry:

```
Top-Down View (board heading UP = +Z, starboard = +X):

              Nose (+Z)
                ↑
                │
        ╔═══════╬═══════╗
        ║       │       ║
        ║       ●───────╲  Sail extends BACKWARD from mast
        ║      Mast      ╲   and swings to leeward side
        ║       │         ╲
        ║       │          ▶ Clew (boom end)
        ╚═══════╬═══════╝
                │
              Tail (-Z)

Key Points:
- Leading edge (LUFF) is at mast - this is the ROTATION POINT
- Trailing edge (LEECH) extends BACKWARD toward tail
- Sail rotates around the mast based on sheet position
- Mast foot is FIXED (typically 1.2m from tail on 2.5m board)
```

**Sail Angle**: Controlled by sheet position
- Sheet in (tight): Sail close to centerline (for upwind sailing)
- Sheet out (loose): Sail far from centerline (for downwind)

**Mast Rake**: Tilts the entire mast fore/aft around the fixed foot
- Rake back (+): Center of Effort shifts back → board turns upwind
- Rake forward (-): Center of Effort shifts forward → board turns downwind

### Center of Effort (CE)

The CE is where the net sail force is applied. Its position is:

1. Start at mast foot (fixed)
2. Go up to boom height (~1.8m)
3. Extend along boom direction at current sail angle
4. CE is approximately 60% along the boom length

```
Side View:
                  Head
                   /
                  /
    ━━━━━━━━━●━━/━━ Boom ──● CE (force applied here)
             |  /
             | /
             |/
    ─────────●──────── Board
         Mast Foot
           (fixed)
```

---

## 4. Board Dynamics

### States of Sailing

#### Displacement Mode (Low Speed)
- Board sits in water (30-50% submerged)
- Buoyancy dominates
- Displacement lift helps support weight
- High drag from hull wetted area
- Limited speed potential (~5-15 km/h)

#### Planing Mode (High Speed)
- Board rises onto surface (~5% submerged)
- Hydrodynamic lift dominates
- Much lower drag (reduced wetted area)
- Higher speed potential (20+ km/h)
- **Onset speed**: ~14 km/h (4 m/s)
- **Full planing**: ~22 km/h (6 m/s)

### Planing Transition

```
Submersion vs Speed:

100% ──┬────────╮
       │        │╲
 75% ──┼────────┼─╲───────────────
       │        │  ╲
 50% ──┼────────┼───╲─────────────
       │        │    ╲
 25% ──┼────────┼─────╲───────────
       │        │      ╲
  5% ──┼────────┼───────╲─────────  ← Target when planing
       │        │        ╲________
  0% ──┴────────┴─────────────────
       0   5   10   15   20   25 km/h
              ↑         ↑
          Onset     Full Planing
```

### Sailor Center of Mass

The sailor's position affects trim and balance:

```csharp
// At rest: sailor centered
baseCOM = (0, 0.4, 0);  // Above center of board

// When planing: sailor moves AFT (backward)
planingCOMShift = 0.3m;  // Shifts toward tail
planingShift = new Vector3(0, -0.1, -0.3 * planingRatio);

// Total effect: Lower and further back when planing
// This matches real windsurfing technique
```

**Why AFT?** Real windsurfers move their feet back onto the tail when planing. This:
- Lifts the nose for better trim
- Reduces wetted area (less drag)
- Provides control at high speed

### Board Forces

```
        Wind Force (from sail)
              ↓
    ┌─────────●─────────┐
    │                   │ → Side Force (from fin)
    │     BOARD         │
    │                   │
    └───────────────────┘
              ↑
        Buoyancy Force
```

### Fin Physics

The fin provides lateral resistance:
- Prevents sideways drift
- Enables upwind sailing
- Creates lift for speed

```
F_fin = 0.5 × ρ × v² × A_fin × Cl_fin
```

---

## 5. Coordinate System

Unity uses left-handed Y-up coordinate system:

```
        Y (up)
        │
        │
        │
        └──────── X (right)
       ╱
      ╱
     Z (forward)
```

### Our Conventions
- **Forward**: Bow of board (positive Z)
- **Up**: Sky (positive Y)
- **Right**: Starboard side (positive X)
- **Wind Direction**: Where wind comes FROM

---

## 6. Physics Integration

### Update Loop

```csharp
void FixedUpdate()
{
    // 1. Sample environment
    float waterHeight = waterSurface.GetHeight(position);
    Vector3 windAtPosition = windManager.GetWind(position);
    
    // 2. Calculate apparent wind
    Vector3 apparentWind = windAtPosition - rigidbody.velocity;
    
    // 3. Calculate forces
    Vector3 buoyancyForce = CalculateBuoyancy(waterHeight);
    Vector3 sailForce = CalculateSailForce(apparentWind);
    Vector3 dragForce = CalculateWaterDrag();
    
    // 4. Apply forces
    rigidbody.AddForce(buoyancyForce + sailForce + dragForce);
}
```

### Time Step

Unity's `FixedUpdate` runs at fixed intervals (default 0.02s = 50Hz).
This ensures consistent physics regardless of frame rate.

---

## 7. Simplifications

To keep development manageable, we make these simplifications:

| Real Physics | Our Simplification |
|--------------|-------------------|
| 3D wave simulation | 2D height field |
| Volume buoyancy | Point-based sampling |
| Turbulent flow | Laminar approximation |
| Flexible sail | Rigid sail model |
| Deformable water | Static water density |

We can add complexity later if needed.

---

## 8. Tuning Parameters

These values will need adjustment through playtesting:

```csharp
// Water
float waterDensity = 1025f;      // kg/m³ (seawater)
float waterDrag = 0.5f;          // coefficient

// Air
float airDensity = 1.225f;       // kg/m³
float sailArea = 6.0f;           // m²

// Board (AdvancedBuoyancy)
float boardVolume = 120f;        // liters
float boardLength = 2.5f;        // m
float boardWidth = 0.6f;         // m
float noseRocker = 0.08f;        // m
float tailRocker = 0.02f;        // m

// Mass (BoardMassConfiguration)
float totalMass = 90f;           // kg (board + sailor)
float boardMass = 15f;           // kg
float sailorMass = 75f;          // kg
float planingCOMShift = 0.3f;    // m (AFT when planing)

// Fin
float finArea = 0.04f;           // m²

// Planing (AdvancedHullDrag)
float planingOnsetSpeed = 4.0f;  // m/s (~14 km/h)
float fullPlaningSpeed = 6.0f;   // m/s (~22 km/h)
float displacementLiftCoeff = 0.12f;
float planingLiftCoeff = 0.8f;   // Savitsky: 0.5-1.0 typical
float maxLiftFraction = 0.85f;   // Prevents flying out
float liftSmoothingFactor = 0.08f;
float submersionDragMultiplier = 12.0f;  // Penalty for sinking

// Damping (AdvancedBuoyancy)
float verticalDamping = 4000f;   // N·s/m (linear)
float waterViscosity = 400f;     // N·s²/m² (v² damping)
float rotationalDamping = 150f;  // N·m·s/rad
float horizontalDamping = 20f;   // N·s/m (lateral only)

// Sail High-Speed Stability (Sail.cs)
float downforceOnsetSpeedKmh = 35f;  // When downforce starts
float maxDownforceFraction = 0.25f;  // Max 25% of sail force
```

---

## 9. Known Physics Issues

⚠️ See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for current bugs.

### ✅ Planing Oscillation Problem - FIXED

**Symptom:** Board oscillated between 0% and 100% submersion at planing speeds ("trampoline effect").

**Root Cause:** Lift was scaling with submersion ratio, creating a positive feedback loop:
1. Board sinks → submersion↑ → lift↑ → board rises
2. Board rises → submersion↓ → lift↓ → board sinks
3. Repeat = trampoline

**Solution:** Implemented proper Savitsky planing equations where lift depends on **speed and trim only**, not submersion depth. Combined with increased water damping (4000 N·s/m) and viscosity (400 N·s²/m²).

### Half-Wind Submersion Issue - UNDER INVESTIGATION

**Symptom:** When sailing beam reach (half wind) with full sheet, the board may sink progressively.

**Suspected Cause:** The heeling moment from sail force applied at height causes the leeward rail to submerge, creating asymmetric forces. This is a physics limitation, not a bug - in real windsurfing, sailors actively counter this by hiking out.

**Current Status:** The physics correctly simulate the challenge. Future work may add sailor hiking simulation.

---

*Last Updated: January 1, 2026*
