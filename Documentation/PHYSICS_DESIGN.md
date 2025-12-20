# 🔬 Physics Design Document

This document explains the physics systems in our windsurfing simulator.

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
│   ┌─────────┐     ┌─────────┐            ▼                  │
│   │  WAVE   │────▶│BUOYANCY │◀───────────┘                  │
│   │ SYSTEM  │     │ FORCES  │                               │
│   └─────────┘     └─────────┘                               │
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
Board Top View:
    ┌───────────────────┐
    │ ●               ● │  ← Front buoyancy points
    │                   │
    │ ●       ●       ● │  ← Middle points
    │                   │
    │ ●               ● │  ← Rear points
    └───────────────────┘
```

Each point:
1. Samples water height at its position
2. Calculates depth below/above water
3. Applies proportional force

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
- Board sits in water
- High drag from hull
- Limited speed potential

#### Planing Mode (High Speed)
- Board rises onto surface
- Much lower drag
- Higher speed potential
- Occurs above ~10-15 km/h

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
float waterDensity = 1025f;      // kg/m³
float waterDrag = 0.5f;          // coefficient

// Air
float airDensity = 1.225f;       // kg/m³
float sailArea = 6.0f;           // m²

// Board
float boardMass = 15f;           // kg
float riderMass = 75f;           // kg
float finArea = 0.04f;           // m²

// Buoyancy
float buoyancyMultiplier = 1.0f; // tweak for feel
int buoyancyPoints = 8;          // sample count
```

---

*Last Updated: December 19, 2025*
