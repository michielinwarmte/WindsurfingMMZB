# Quick Setup Checklist

## GameObject Setup Quick Reference

Use this checklist when setting up the scene on a new PC. For detailed parameter values, see [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md).

**Last Updated:** December 27, 2025

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
- [ ] **AdvancedBuoyancy** - Multi-point flotation
- [ ] **AdvancedHullDrag** - Drag + high-speed stability
- [ ] **AdvancedSail** - Realistic aerodynamics, rake steering
- [ ] **AdvancedFin** - Lateral resistance
- [ ] **AdvancedWindsurferController** - Beginner/Intermediate/Advanced modes

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
- [ ] **ThirdPersonCamera**

#### Critical Manual Assignment
- [ ] ThirdPersonCamera._target → Drag **WindsurfBoard** Transform here

---

### ☐ 5. Directional Light
- [ ] Type: Directional, Intensity: 1, Shadows: Soft

---

### ☐ 6. AdvancedTelemetryHUD (Optional)
- [ ] **AdvancedTelemetryHUD** - Shows physics debug info

---

## Critical Connections Summary

Only **TWO** manual assignments needed:
1. **AdvancedBuoyancy._waterSurface** → WaterSurface GameObject
2. **ThirdPersonCamera._target** → WindsurfBoard Transform

Everything else auto-finds!

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
