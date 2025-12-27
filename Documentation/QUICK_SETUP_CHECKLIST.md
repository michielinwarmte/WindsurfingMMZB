# Quick Setup Checklist

## GameObject Setup Quick Reference

Use this checklist when setting up the scene on a new PC. For detailed parameter values, see [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md).

---

## ☐ 1. WindsurfBoard GameObject

### Transform
- [ ] Position: `(0, 0.5, 0)`
- [ ] Scale: `(0.6, 0.1, 2.5)`

### Components (Add in this order)
- [ ] Rigidbody (Mass: 50, Angular Damping: 0.5, Interpolate: checked)
- [ ] BoxCollider
- [ ] MeshFilter (Cube)
- [ ] MeshRenderer (with BoardMaterial)
- [ ] **BuoyancyBody** - Strength: 1500, Float Height: 0.2
- [ ] **WaterDrag** - Forward: 0.15, Lateral: 3, Vertical: 4
- [ ] **ApparentWindCalculator** - Vector Scale: 0.5
- [ ] **Sail** - Area: 6, Lift: 1.2, Sheet: 0.5
- [ ] **FinPhysics** - Area: 0.04, Lift Coeff: 4, Tracking: 2
- [ ] **WindsurferControllerV2** - Mode: Beginner, Weight Shift: 12

### Critical Manual Assignments
- [ ] BuoyancyBody._waterSurface → Drag **WaterSurface** GameObject here

---

## ☐ 2. WaterSurface GameObject

### Transform
- [ ] Position: `(0, 0, 0)`
- [ ] Scale: `(100, 1, 100)`

### Components
- [ ] MeshFilter (Plane)
- [ ] MeshRenderer (with WaterMaterial)
- [ ] **WaterSurface** - Base Height: 0, Waves: unchecked

---

## ☐ 3. WindManager GameObject

### Transform
- [ ] Position: `(0, 0, 0)`

### Components
- [ ] **WindManager** - Speed: 8, Direction: 45°, Variation: checked

---

## ☐ 4. Main Camera

### Transform
- [ ] Position: `(0, 5, -10)`
- [ ] Rotation: `(20, 0, 0)`

### Components
- [ ] Camera (FOV: 60)
- [ ] **ThirdPersonCamera** - Offset: (0, 8, -1.46), Follow Speed: 5

### Critical Manual Assignments
- [ ] ThirdPersonCamera._target → Drag **WindsurfBoard** Transform here

---

## ☐ 5. Directional Light

### Transform
- [ ] Position: `(0, 3, 0)`
- [ ] Rotation: `(50, -30, 0)`

### Components
- [ ] Light (Type: Directional, Intensity: 1, Shadows: Soft)

---

## ☐ 6. TelemetryHUD GameObject

### Transform
- [ ] Position: `(0, 0, 0)`

### Components
- [ ] **TelemetryHUD** - Show Telemetry: checked, Font Size: 18

---

## Critical Connections Summary

Only TWO manual assignments needed:
1. **WindsurfBoard.BuoyancyBody._waterSurface** → WaterSurface GameObject
2. **Main Camera.ThirdPersonCamera._target** → WindsurfBoard Transform

Everything else auto-finds!

---

## Materials Needed

### BoardMaterial
- [ ] Shader: URP/Lit or Standard
- [ ] Color: Any (white, yellow, etc.)
- [ ] Assign to WindsurfBoard MeshRenderer

### WaterMaterial
- [ ] Shader: URP/Lit or Standard
- [ ] Color: Cyan/Blue (0, 180, 255)
- [ ] Smoothness: 0.8
- [ ] Assign to WaterSurface MeshRenderer

---

## Scripts Checklist

### Physics Scripts (on WindsurfBoard)
- [ ] BuoyancyBody.cs
- [ ] WaterDrag.cs
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
Unity Version: 2022.3 LTS or higher
Render Pipeline: Universal RP (recommended) or Built-in

---

**Need more details?** See [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md) for complete parameter values.
