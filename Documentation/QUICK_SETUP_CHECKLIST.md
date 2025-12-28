# Quick Setup Checklist

## GameObject Setup Quick Reference

Use this checklist when setting up the scene on a new PC. For detailed parameter values, see [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md).

**Last Updated:** December 28, 2025

---

## ⚠️ IMPORTANT: Known Issues

Before starting, be aware of these critical bugs:

| Issue | Workaround |
|-------|------------|
| 🔴 Camera doesn't follow | Change FOV in Inspector during Play mode |
| 🔴 Board oscillates at planing speed | None yet - needs stability fix |
| 🔴 Steering is inverted | None yet - A/D keys work backwards |

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for full details.

---

## 🌟 RECOMMENDED: Use the Setup Wizard

The easiest way to set up a scene:

1. **Menu:** `Windsurfing → Complete Windsurfer Setup Wizard`
2. Assign your Board and Sail FBX models
3. Click **"🌟 Create Complete Scene"**
4. Press Play
5. **⚠️ Apply camera workaround:** Select Main Camera → change FOV

The wizard creates everything automatically!

---

## ⚠️ RECOMMENDED: Advanced Physics Stack

For working upwind sailing and realistic physics, use the **Advanced** components:

### ☐ 1. WindsurfBoard GameObject (Advanced)

#### Transform
- [ ] Position: `(0, 0.5, 0)`

#### Components (Add in this order)
- [ ] Rigidbody (Mass: 90, Drag: 0.5, Angular Drag: 2.0, Interpolate: checked)
- [ ] BoxCollider
- [ ] MeshFilter + MeshRenderer
- [ ] **AdvancedBuoyancy** - Multi-point flotation with Archimedes' principle
- [ ] **AdvancedHullDrag** - Drag + hydrodynamic lift (displacement + planing)
- [ ] **AdvancedSail** - Realistic aerodynamics, rake steering
- [ ] **AdvancedFin** - Lateral resistance
- [ ] **AdvancedWindsurferController** - Beginner/Intermediate/Advanced modes
- [ ] **BoardMassConfiguration** - Mass/inertia, sailor COM shift

#### Critical Manual Assignment
- [ ] AdvancedBuoyancy._waterSurface → Drag **WaterSurface** here

---

### ☐ 2. WindSystem GameObject (Preferred)

#### Components
- [ ] **WindSystem** - True wind with gusts, shifts, height gradient

---

### ☐ 3. WaterSurface GameObject

#### Transform
- [ ] Position: `(0, 0, 0)`
- [ ] Scale: `(100, 1, 100)`

#### Components
- [ ] MeshFilter (Plane)
- [ ] MeshRenderer (with WaterMaterial)
- [ ] **WaterSurface** - Base Height: 0

---

### ☐ 4. Main Camera

#### Components
- [ ] Camera (FOV: 60)
- [ ] **SimpleFollowCamera** (preferred) or **ThirdPersonCamera**

#### Critical Manual Assignment
- [ ] SimpleFollowCamera._target → Drag **WindsurfBoard** Transform here

#### ⚠️ Camera Workaround
The camera won't follow until you change the FOV value in Inspector during Play mode.

---

### ☐ 5. Directional Light
- [ ] Type: Directional, Intensity: 1, Shadows: Soft

---

### ☐ 6. TelemetryHUD (Optional but Recommended)
- [ ] Create empty GameObject named "TelemetryHUD"
- [ ] Add **AdvancedTelemetryHUD** - Shows physics debug info
- [ ] Wire up references to windsurfer components
- [ ] Press **F1** during play to toggle

---

## Critical Connections Summary

Only **TWO** manual assignments needed:
1. **AdvancedBuoyancy._waterSurface** → WaterSurface GameObject
2. **SimpleFollowCamera._target** → WindsurfBoard Transform

Everything else auto-finds!

---

## 🎮 Controls Reference

| Key | Action | Notes |
|-----|--------|-------|
| W/S | Sheet in/out | Controls sail power |
| A/D | Steer | ⚠️ Currently inverted! |
| Q/E | Fine mast rake | For precise steering |
| F1 | Toggle telemetry | Shows all physics values |
| 1-4 | Camera modes | 1=Follow, 2=Orbit, 3=Top, 4=Free |

---

## 🔧 Camera Workaround (Required!)

The camera has an initialization bug. To make it work:

1. Press Play
2. Select "Main Camera" in Hierarchy
3. In Inspector, find Camera component
4. Change FOV from 60 to 61 (any change works)
5. Camera now follows correctly

This needs to be done every time you enter Play mode.

---

## 📋 Legacy Setup (Basic Physics)

For simpler physics (prototyping only):

### ☐ 1. WindsurfBoard GameObject (Legacy)
- [ ] Sail.cs
- [ ] FinPhysics.cs
- [ ] ApparentWindCalculator.cs

### Player Script (on WindsurfBoard)
- [ ] WindsurferControllerV2.cs (recommended)
  OR
- [ ] WindsurferController.cs (old version)

### Camera Script (on Main Camera)
- [ ] ThirdPersonCamera.cs

### UI Scripts
- [ ] TelemetryHUD.cs (on TelemetryHUD GameObject)
- [ ] WindIndicator3D.cs (optional)

### Environment Scripts
- [ ] WindManager.cs (on WindManager GameObject)
- [ ] WaterSurface.cs (on WaterSurface GameObject)

### Visual Scripts (Optional)
- [ ] SailVisualizer.cs (on WindsurfBoard)

---

## Testing After Setup

Press Play and verify:
- [ ] Board floats on water
- [ ] Board moves when pressing W
- [ ] Board turns with A/D
- [ ] Camera follows smoothly
- [ ] Telemetry shows in top-left
- [ ] No console errors

---

## Common Mistakes

❌ **Don't:**
- Forget to assign WaterSurface to BuoyancyBody
- Forget to assign WindsurfBoard to Camera target
- Add both WindsurferController AND WindsurferControllerV2 (use only one!)
- Set wrong Transform values (especially Scale on board)

✅ **Do:**
- Use FinPhysics script (critical for steering)
- Set Rigidbody mass to 50
- Set buoyancy strength to 1500
- Enable Rigidbody interpolation
- Save scene after setup

---

## Scene Hierarchy Should Look Like:

```
MainScene
├── Main Camera
│   └── ThirdPersonCamera
├── Directional Light
├── WaterSurface
│   └── WaterSurface
├── WindsurfBoard
│   ├── Rigidbody
│   ├── BoxCollider
│   ├── MeshFilter
│   ├── MeshRenderer
│   ├── BuoyancyBody
│   ├── WaterDrag
│   ├── ApparentWindCalculator
│   ├── Sail
│   ├── FinPhysics
│   ├── WindsurferControllerV2
│   └── (Optional) SailVisualizer
├── WindManager
│   └── WindManager
└── TelemetryHUD
    ├── TelemetryHUD
    └── (Optional) WindIndicator3D
```

---

## File Locations

All scripts are in:
```
Assets/Scripts/
├── Camera/
│   └── ThirdPersonCamera.cs
├── Physics/
│   ├── Board/
│   │   ├── ApparentWindCalculator.cs
│   │   ├── FinPhysics.cs
│   │   ├── Sail.cs
│   │   └── WaterDrag.cs
│   ├── Buoyancy/
│   │   └── BuoyancyBody.cs
│   ├── Water/
│   │   └── WaterSurface.cs
│   └── Wind/
│       └── WindManager.cs
├── Player/
│   ├── WindsurferController.cs
│   └── WindsurferControllerV2.cs
├── UI/
│   ├── TelemetryHUD.cs
│   └── WindIndicator3D.cs
└── Visual/
    └── SailVisualizer.cs
```

---

## Version Info
- **Unity Version**: 6.3 LTS
- **Render Pipeline**: Universal RP (URP)

---

**Need more details?** See [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md) for complete parameter values.

**Physics documentation:** See [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md) for validated formulas.
