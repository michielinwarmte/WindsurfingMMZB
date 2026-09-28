# Scene Structure Visual Guide

**Last Updated:** January 2, 2026

> **⚠️ NOTE:** This document describes the **legacy physics setup**. For production, use the **Advanced Physics** components:
> - `AdvancedBuoyancy` instead of `BuoyancyBody`
> - `AdvancedSail` instead of `Sail`
> - `AdvancedFin` instead of `FinPhysics`
> - `AdvancedHullDrag` instead of `WaterDrag`
> - `AdvancedWindsurferController` instead of `WindsurferControllerV2`
> - `AdvancedTelemetryHUD` instead of `TelemetryHUD` (removed)
> - `SimpleFollowCamera` instead of `ThirdPersonCamera`
>
> See [ARCHITECTURE.md](ARCHITECTURE.md) for the recommended setup.

## Scene Hierarchy Diagram (Legacy)

```
MainScene
│
├── 📷 Main Camera
│   ├── Camera Component
│   │   ├── Clear Flags: Skybox
│   │   ├── FOV: 60
│   │   └── Clipping: 0.3 - 1000
│   │
│   └── 🎥 ThirdPersonCamera Script
│       ├── Target: → WindsurfBoard ⚠️ ASSIGN MANUALLY
│       ├── Offset: (0, 8, -1.46)
│       ├── Follow Speed: 5
│       └── Rotation Speed: 3
│
├── 💡 Directional Light
│   └── Light Component
│       ├── Type: Directional
│       ├── Intensity: 1
│       └── Shadows: Soft
│
├── 🌊 WaterSurface
│   ├── Transform
│   │   └── Scale: (100, 1, 100)
│   │
│   ├── MeshFilter: Plane
│   ├── MeshRenderer: WaterMaterial
│   │
│   └── 💧 WaterSurface Script
│       ├── Base Height: 0
│       ├── Enable Waves: ☐
│       └── Wave Height: 0.5
│
├── 🏄 WindsurfBoard ⭐ MAIN OBJECT
│   │
│   ├── Transform
│   │   ├── Position: (0, 0.5, 0)
│   │   └── Scale: (0.6, 0.1, 2.5)
│   │
│   ├── 🔲 Rigidbody
│   │   ├── Mass: 50
│   │   ├── Drag: 0
│   │   ├── Angular Drag: 0.5
│   │   └── Interpolate: ✓
│   │
│   ├── BoxCollider
│   │   └── Size: (1, 1, 1)
│   │
│   ├── MeshFilter: Cube
│   ├── MeshRenderer: BoardMaterial
│   │
│   ├── 🎈 BuoyancyBody Script
│   │   ├── Water Surface: → WaterSurface ⚠️ ASSIGN MANUALLY
│   │   ├── Strength: 1500
│   │   ├── Float Height: 0.2
│   │   ├── Water Damping: 100
│   │   └── Auto Points: 4
│   │
│   ├── 💨 WaterDrag Script
│   │   ├── Forward Drag: 0.15
│   │   ├── Lateral Drag: 3
│   │   ├── Planing Speed: 4
│   │   └── Auto-finds: BuoyancyBody
│   │
│   ├── 🌬️ ApparentWindCalculator Script
│   │   ├── Vector Scale: 0.5
│   │   ├── Show Debug: ✓
│   │   └── Auto-finds: WindManager
│   │
│   ├── ⛵ Sail Script
│   │   ├── Sail Area: 6 m²
│   │   ├── Lift Coefficient: 1.2
│   │   ├── Sheet Position: 0.5
│   │   ├── Mast Height: 4.5 m
│   │   ├── Boom Length: 2.0 m
│   │   ├── Rake Angle: 15°
│   │   └── Auto-finds: Rigidbody
│   │
│   ├── 🐟 FinPhysics Script
│   │   ├── Fin Area: 0.04 m²
│   │   ├── Lift Coefficient: 4
│   │   ├── Tracking Strength: 2
│   │   ├── Stall Angle: 25°
│   │   └── Auto-finds: Rigidbody
│   │
│   ├── 🎮 WindsurferControllerV2 Script
│   │   ├── Control Mode: Beginner
│   │   ├── Weight Shift: 12
│   │   ├── Auto Sheet: ✓
│   │   ├── Anti Capsize: ✓
│   │   ├── Auto Stabilize: ✓
│   │   └── Auto-finds: Sail, Fin, ApparentWind
│   │
│   └── 🎨 SailVisualizer Script (Optional)
│       ├── Mast Height: 4.5
│       ├── Boom Length: 2.5
│       └── Auto-finds: Sail
│
├── 💨 WindManager
│   └── 🌪️ WindManager Script
│       ├── Wind Speed: 8 m/s
│       ├── Direction: 45°
│       ├── Variation: ✓
│       ├── Speed Variation: 0.2
│       └── Direction Variation: 10°
│
└── 📊 TelemetryHUD
    ├── 📈 AdvancedTelemetryHUD Script ⭐ (replaces TelemetryHUD)
    │   ├── Show Telemetry: ✓
    │   ├── Show Wind: ✓
    │   ├── Font Size: 18
    │   └── Auto-finds: All components
    │
    └── 🎯 WindIndicator3D Script (Optional)
        ├── Show True Wind: ✓
        ├── Show Apparent Wind: ✓
        └── Auto-finds: WindManager
```

---

## Component Connection Map

```
┌─────────────────────────────────────────────────────────┐
│                      WINDMANAGER                        │
│                   (Global Wind Source)                  │
└───────────────────┬─────────────────────────────────────┘
                    │ provides wind
                    ↓
┌─────────────────────────────────────────────────────────┐
│              APPARENTWINDCALCULATOR                     │
│           (Calculates apparent wind)                    │
└───────────────────┬─────────────────────────────────────┘
                    │ wind + velocity
                    ↓
        ┌───────────┴───────────┐
        ↓                       ↓
┌──────────────┐        ┌──────────────┐
│     SAIL     │        │  VISUALIZER  │
│ (Forces)     │        │  (Display)   │
└──────┬───────┘        └──────────────┘
       │
       ↓
┌──────────────────────────────────────┐
│           RIGIDBODY                  │
│      (Physics Integration)           │
└──────┬───────────────┬───────┬───────┘
       │               │       │
       ↓               ↓       ↓
┌──────────┐   ┌──────────┐  ┌──────────┐
│ BUOYANCY │   │   FIN    │  │  DRAG    │
│ (Float)  │   │ (Grip)   │  │ (Resist) │
└────┬─────┘   └──────────┘  └──────────┘
     │
     ↓
┌──────────────┐
│ WATERSURFACE │
│ (Height)     │
└──────────────┘
```

---

## Data Flow: User Input → Board Movement

```
┌─────────────┐
│  KEYBOARD   │
│   Input     │
└──────┬──────┘
       │
       ↓
┌─────────────────────────┐
│ WINDSURFERCONTROLLERV2  │
│  - Processes input      │
│  - Applies assists      │
└──────┬────────┬─────────┘
       │        │
       ↓        ↓
   ┌───────┐  ┌────────┐
   │ SAIL  │  │  FIN   │
   │Sheet, │  │Weight  │
   │ Rake  │  │ Shift  │
   └───┬───┘  └───┬────┘
       │          │
       └────┬─────┘
            ↓
      ┌──────────┐
      │RIGIDBODY │
      │  Forces  │
      └────┬─────┘
           │
           ↓
    ┌─────────────┐
    │   BOARD     │
    │ MOVEMENT    │
    └─────────────┘
```

---

## Component Execution Timeline

```
FRAME START
│
├─── AWAKE
│    ├─ All components initialize
│    ├─ Auto-find references
│    └─ Create helper objects
│
├─── START
│    ├─ Verify all references
│    ├─ Find WindManager
│    └─ Setup initial state
│
├─── UPDATE (60 Hz)
│    ├─ WindManager: Update gusts
│    ├─ Controller: Gather input
│    ├─ Controller: Smooth input
│    └─ Visualizer: Update sail mesh
│
├─── FIXED UPDATE (50 Hz) ⚡ PHYSICS
│    ├─ ApparentWind: Calculate
│    ├─ Sail: Calculate forces
│    ├─ Fin: Calculate forces
│    ├─ Drag: Calculate resistance
│    ├─ Buoyancy: Calculate float forces
│    ├─ Controller: Apply control forces
│    └─ Rigidbody: Integrate all forces
│
├─── LATE UPDATE
│    ├─ Camera: Update position
│    └─ UI Indicators: Update display
│
└─── FRAME END
```

---

## GameObject Checklist with Emoji Indicators

### ✅ Minimal Setup (Will Work)
```
✅ WaterSurface
✅ WindManager
✅ WindsurfBoard
   ├─ ✅ Rigidbody
   ├─ ✅ BuoyancyBody
   ├─ ✅ WaterDrag
   ├─ ✅ ApparentWindCalculator
   ├─ ✅ Sail
   ├─ ✅ FinPhysics
   └─ ✅ WindsurferControllerV2
✅ Main Camera
   └─ ✅ ThirdPersonCamera
```

### 🌟 Recommended Setup (Better Experience)
```
All of above, plus:
🌟 Directional Light
🌟 TelemetryHUD
   └─ 🌟 AdvancedTelemetryHUD Script (replaces legacy TelemetryHUD)
```

### 💎 Full Setup (Best Experience)
```
All of above, plus:
💎 WindsurfBoard
   └─ 💎 SailVisualizer
💎 TelemetryHUD
   └─ 💎 WindIndicator3D
```

---

## Script Dependency Tree

```
WindsurferControllerV2
├── requires → Rigidbody
├── requires → Sail
│   └── requires → ApparentWindCalculator
│       └── requires → WindManager ⚠️ Must exist in scene
├── requires → FinPhysics
└── requires → ApparentWindCalculator

BuoyancyBody
├── requires → Rigidbody
└── requires → WaterSurface ⚠️ Must assign manually

ThirdPersonCamera
└── requires → Target Transform ⚠️ Must assign manually

AdvancedTelemetryHUD (replaces TelemetryHUD)
├── auto-finds → AdvancedWindsurferController
├── auto-finds → WindSystem
└── auto-finds → All board components
```

---

## Critical Path: What Must Be Assigned

```
START
│
├─ Create WindsurfBoard GameObject
│  ├─ Add Rigidbody (mass: 50)
│  ├─ Add all physics scripts
│  └─ ⚠️ BuoyancyBody._waterSurface = ???
│      │
│      └─ Must assign → WaterSurface GameObject
│
├─ Create WaterSurface GameObject
│  └─ Add WaterSurface script
│
├─ Create WindManager GameObject
│  └─ Add WindManager script
│
├─ Setup Main Camera
│  └─ ⚠️ ThirdPersonCamera._target = ???
│      │
│      └─ Must assign → WindsurfBoard Transform
│
└─ ✅ READY TO PLAY
```

---

## Materials Flow

```
Board Material (White/Yellow)
        ↓
WindsurfBoard → MeshRenderer
        ↓
    Visible Board

Water Material (Blue/Cyan)
        ↓
WaterSurface → MeshRenderer
        ↓
    Visible Water
```

---

## Physics Force Contributors

```
         RIGIDBODY
            ↑
    ┌───────┼───────┐
    │       │       │
    ↑       ↑       ↑
┌────────┐ ┌────┐ ┌────┐
│ SAIL   │ │FIN │ │DRAG│
│ +500N  │ │±50N│ │-80N│
└────────┘ └────┘ └────┘
    ↑
┌──────────┐
│ BUOYANCY │
│  +490N   │
└──────────┘
    ↑
┌──────────┐
│ GRAVITY  │
│  -490N   │
└──────────┘
```

Net force → Forward movement + Floating

---

## Scene at a Glance

| Element | Purpose | Critical? |
|---------|---------|-----------|
| 🏄 WindsurfBoard | Player object | ✅ Yes |
| 🌊 WaterSurface | Defines water level | ✅ Yes |
| 💨 WindManager | Provides wind | ✅ Yes |
| 📷 Camera | Follows player | ✅ Yes |
| 💡 Light | Illuminates scene | ⚠️ Recommended |
| 📊 TelemetryHUD | Shows info | 💡 Optional |

---

**Total GameObjects: 6**  
**Total Components: ~25**  
**Manual Assignments: 2**  
**Scripts: 11**

Simple, clean, and well-organized! 🎯
