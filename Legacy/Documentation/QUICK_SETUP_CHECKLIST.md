# Quick Setup Checklist

## GameObject Setup Quick Reference

Use this checklist when setting up the scene on a new PC. For detailed parameter values, see [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md).

**Last Updated:** September 28, 2026

---

## ⚠️ IMPORTANT: Known Issues

Before starting, be aware of these known issues:

| Issue | Status | Workaround |
|-------|--------|------------|
| 🧪 Session 27 polish (waves, sail cloth, spray, audio, sky) | **Unverified** | Compile and play; checklist in KNOWN_ISSUES.md |
| ✅ Camera doesn't follow | **FIXED** (Session 26) | - |
| ✅ Steering on port tack | **FIXED** | Now auto-inverts correctly |
| ✅ Porpoising at speed | **FIXED** | CE at zero, planing lift at center |

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for full details.

---

## 🌟 RECOMMENDED: Use the Setup Wizard

The easiest way to set up a scene:

1. **Menu:** `Windsurfing → Complete Windsurfer Setup Wizard`
2. Assign your Board and Sail FBX models
3. Click **"🌟 Create Complete Scene"**
4. Press Play

The wizard creates everything automatically, including the Session 27 polish (waves, ocean shader, sail cloth, spray, sound, sky, islands). For an older scene use `Windsurfing → Upgrade Scene: Add Visual and Audio Polish`.

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
- [ ] Scale: `(1, 1, 1)` (WaterMeshBuilder generates a 3 km mesh in metres and resets the scale at play)

#### Components
- [ ] MeshFilter (any mesh - replaced at play time)
- [ ] MeshRenderer (with WaterMaterial → `Windsurfing/OceanWater` shader), Cast Shadows: Off
- [ ] **WaterSurface** - Base Height: 0, Enable Waves: on, Align Waves To Wind: on
- [ ] **WaterMeshBuilder** - Extent 1500, Resolution 160

---

### ☐ 4. Main Camera

#### Components
- [ ] Camera (FOV: 60)
- [ ] **SimpleFollowCamera** (preferred) or **ThirdPersonCamera**

#### Critical Manual Assignment
- [ ] SimpleFollowCamera._target → Drag **WindsurfBoard** Transform here (it also auto-finds the board)

---

### ☐ 5. Directional Light
- [ ] Type: Directional, Intensity: 1, Shadows: Soft

### ☐ 5b. Environment (Session 27)
- [ ] Create empty GameObject named "Environment"
- [ ] Add **SkyEnvironment** - assign the Directional Light as Sun (procedural sky, ambient, fog)
- [ ] Add **DistantIslands** - assign `Materials/IslandTerrain.mat`

### ☐ 5c. Windsurfer polish components (Session 27)
- [ ] **SailDeformer** - sail cloth belly/twist/flutter (needs EquipmentVisualizer with the Sail FBX)
- [ ] **BoardWakeEffects** - spray, wake, splash particles
- [ ] **WindAmbienceAudio**, **HullWaterAudio**, **SailFlapAudio** - procedural sound

All of these auto-find their references. The wizard and the Upgrade Scene menu add them for you.

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
| A/D | Steer | Auto-inverts on port tack |
| Q/E | Fine mast rake | For precise steering |
| Space | Switch tack | Flips sail to other side |
| F1 | Toggle telemetry | Shows all physics values |
| 1-4 | Camera modes | 1=Follow, 2=Orbit, 3=Top, 4=Free |

---

## 🔧 If Something Looks Wrong (Session 27)

| Symptom | Check |
|---------|-------|
| Water is pink | `OceanWater.shader` failed to compile - see Console |
| No foam around the hull | `PC_RPAsset` needs Depth Texture + Opaque Texture, or untick `Use Scene Depth` on WaterMaterial |
| Board clips through waves | WaterSurface `Drive Shader Globals` must be on |
| Sail does not bend | Console should say `SailDeformer: deforming 'Plane'`; assign Cloth Mesh Filter manually if it chose the boom |
| No mast | EquipmentVisualizer → Add Procedural Mast |
| Too loud / too quiet | Volumes on WindAmbienceAudio, HullWaterAudio, SailFlapAudio |

---

## 📋 Legacy Setup (Basic Physics - Deprecated)

> **⚠️ Note:** Legacy setup is deprecated. Use Advanced Physics for production.

For simpler physics (prototyping only):

### ☐ 1. WindsurfBoard GameObject (Legacy)
- [ ] Sail.cs
- [ ] FinPhysics.cs
- [ ] ApparentWindCalculator.cs

### Player Script (on WindsurfBoard)
- [ ] WindsurferControllerV2.cs
  ~~OR~~
  ~~WindsurferController.cs~~ **(REMOVED in Session 26)**

### Camera Script (on Main Camera)
- [ ] SimpleFollowCamera.cs (preferred)
  OR
- [ ] ThirdPersonCamera.cs (legacy)

### UI Scripts
- [ ] AdvancedTelemetryHUD.cs (on TelemetryHUD GameObject)
  ~~TelemetryHUD.cs~~ **(REMOVED in Session 26)**
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

### Advanced Setup (Recommended) ⭐
```
MainScene
├── Main Camera
│   └── SimpleFollowCamera
├── Directional Light
├── WaterSurface
│   ├── WaterSurface
│   └── WaterMeshBuilder (Session 27)
├── Environment (Session 27)
│   ├── SkyEnvironment
│   └── DistantIslands
├── WindsurfBoard
│   ├── Rigidbody
│   ├── BoxCollider
│   ├── MeshFilter
│   ├── MeshRenderer
│   ├── AdvancedBuoyancy
│   ├── AdvancedHullDrag
│   ├── AdvancedSail
│   ├── AdvancedFin
│   ├── BoardMassConfiguration
│   ├── AdvancedWindsurferController
│   ├── EquipmentVisualizer
│   ├── SailDeformer (Session 27)
│   ├── BoardWakeEffects (Session 27)
│   └── WindAmbienceAudio, HullWaterAudio, SailFlapAudio (Session 27)
├── WindSystem
│   └── WindSystem
└── TelemetryHUD
    ├── AdvancedTelemetryHUD
    └── (Optional) WindIndicator3D
```

### Legacy Setup
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
    ├── AdvancedTelemetryHUD
    └── (Optional) WindIndicator3D
```

---

## File Locations

All scripts are in:
```
Assets/Scripts/
├── Camera/
│   ├── SimpleFollowCamera.cs ⭐
│   └── ThirdPersonCamera.cs (legacy)
├── Debug/
│   ├── PhysicsValidation.cs
│   └── SailPhysicsDebugger.cs
├── Physics/
│   ├── Board/
│   │   ├── AdvancedSail.cs ⭐
│   │   ├── AdvancedFin.cs ⭐
│   │   ├── AdvancedHullDrag.cs ⭐
│   │   ├── BoardMassConfiguration.cs ⭐
│   │   ├── ApparentWindCalculator.cs (legacy)
│   │   ├── FinPhysics.cs (legacy)
│   │   ├── Sail.cs (legacy)
│   │   └── WaterDrag.cs (legacy)
│   ├── Buoyancy/
│   │   ├── AdvancedBuoyancy.cs ⭐
│   │   └── BuoyancyBody.cs (legacy)
│   ├── Core/
│   │   ├── Aerodynamics.cs
│   │   ├── Hydrodynamics.cs
│   │   ├── PhysicsConstants.cs
│   │   └── SailingState.cs
│   ├── Water/
│   │   └── WaterSurface.cs
│   └── Wind/
│       └── WindManager.cs (legacy)
├── Environment/
│   └── WindSystem.cs ⭐
├── Player/
│   ├── AdvancedWindsurferController.cs ⭐
│   └── WindsurferControllerV2.cs (legacy)
├── UI/
│   ├── AdvancedTelemetryHUD.cs ⭐
│   ├── SailPositionIndicator.cs
│   └── WindIndicator3D.cs
└── Visual/
    ├── EquipmentVisualizer.cs ⭐
    ├── ForceVectorVisualizer.cs
    ├── SailVisualizer.cs (legacy)
    └── WindDirectionIndicator.cs
```

---

## Version Info
- **Unity Version**: 6.3 LTS
- **Render Pipeline**: Universal RP (URP)

---

**Need more details?** See [SCENE_CONFIGURATION.md](SCENE_CONFIGURATION.md) for complete parameter values.

**Physics documentation:** See [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md) for validated formulas.
