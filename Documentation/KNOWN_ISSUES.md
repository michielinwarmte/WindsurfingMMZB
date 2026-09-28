# 🐛 Known Issues

**Last Updated:** September 28, 2026

This document tracks known issues, bugs, and their workarounds. For contributors picking up this project, these are the priority fixes needed.

---

## 🧪 Session 27 Needs Play-Mode Verification

Session 27 (visual and audio polish) was written on a machine without Unity, so none of it has been compiled or played yet. Before anything else:

1. Open the project in Unity 6.3 and fix any compile errors in the new scripts (`Scripts/Audio/*`, `Scripts/Visual/WaterMeshBuilder.cs`, `SailDeformer.cs`, `BoardWakeEffects.cs`, `Scripts/Environment/SkyEnvironment.cs`, `DistantIslands.cs`, `Scripts/Physics/Water/GerstnerWave.cs`, `Scripts/Utilities/MeshSubdivider.cs`) and shaders (`Shaders/OceanWater.shader`, `Shaders/VertexColorTerrain.shader`).
2. Open `MainScene` and press Play. The scene file was edited by hand to add the new components; if Unity reports a broken component, use `Windsurfing → Upgrade Scene: Add Visual and Audio Polish` to re-add it.
3. Check, in this order:
   - **Water renders** (not magenta). If it is flat pink, the shader failed to compile; check the Console. If it shows no depth foam around the hull, confirm `PC_RPAsset` has Depth Texture and Opaque Texture enabled (it does in git) or turn off `Use Scene Depth` on `WaterMaterial`.
   - **Board floats on the visible waves.** Physics and rendering share `GerstnerMath`; if they drift apart, `WaterSurface` is not publishing shader globals (see `_driveShaderGlobals`).
   - **Physics still validated.** Waves are now ON by default (total amplitude ~0.2 m). Re-run the [PHYSICS_VALIDATION.md](PHYSICS_VALIDATION.md) checklist. If planing or upwind behaviour degraded, untick `Enable Waves` on the Water object - this restores the exact flat-water physics of Session 26.
   - **Sail cloth bends** with sheet/power and flutters when eased out fully. Console should log `SailDeformer: deforming 'Plane'`. If it picked the boom instead, assign `Cloth Mesh Filter` manually.
   - **Procedural mast** appears at the mast foot (the FBX mast is a face-less curve profile). Adjust height/radius on `EquipmentVisualizer` if it does not match the sail.
   - **Spray and wake** appear above ~9 km/h; a splash on landing.
   - **Audio**: wind gets louder and brighter with apparent wind; hiss when planing; flaps when luffing and on Space (tack). Levels are guesses - tune the volumes on the three audio components.
   - **Sky and islands**: blue procedural sky with a sun disc, fog at the horizon, six islands 450-900 m out.
4. Rollback: every new feature is one component; removing it (or unticking it) restores Session 26 behaviour. Waves: `WaterSurface → Enable Waves`.

---

## 🔴 Critical Issues (Needs Fix)

### 1. Pitch Stabilization Causes Jittering at High Heel Angles

**Symptom:**  
When the windsurfer is heeled over significantly (high roll angle, close to perpendicular to water like in real high-performance windsurfing), the pitch stabilization can cause spasming/jittering.

**Current Workaround:**  
Pitch stabilization is disabled when heel angle exceeds 25° and fades out progressively from 15° to 25°.

**Potential Proper Fix:**  
In real windsurfing, the sail transfers both rake (steering) AND roll/heel forces to the board. Currently only rake is transferred. Implementing proper sail-to-board roll transfer would:
1. Allow the sailor's lean to naturally counteract heeling moments
2. Make the board more stable at high heel angles without artificial corrections
3. Enable more realistic high-performance sailing positions

**Files:**  
- [WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs) - `ApplyPitchStabilization()` method
- Consider adding roll transfer in `ApplyForces()` method

---

### 2. Camera Only Works When Changing FOV in Inspector (FIXED - Session 26)

**Status:** ✅ FIXED

**Previous Symptom:**  
The camera doesn't follow the windsurfer until you manually change the FOV value in the Inspector during Play mode.

**Root Cause:**  
Two camera controllers (`ThirdPersonCamera` and `SimpleFollowCamera`) were conflicting on the same GameObject.

**Fix Applied:**  
`SimpleFollowCamera.cs` now disables `ThirdPersonCamera` on initialization and forces camera position for first 3 frames.

**Files:**  
- [WindsurfingGame/Assets/Scripts/Camera/SimpleFollowCamera.cs](../WindsurfingGame/Assets/Scripts/Camera/SimpleFollowCamera.cs)

---

## ✅ Recently Fixed Issues

### Addressed in Session 27 (September 28, 2026) - Visual and Audio Polish (unverified)

- 🧪 **No sound effects** → Procedural wind, water and sail audio (`Scripts/Audio/`). No audio files needed.
- 🧪 **Basic water** → Gerstner waves shared by physics and rendering, `OceanWater.shader`, dense follow mesh.
- 🧪 **Static sail** → `SailDeformer` bends the cloth from the simulated sail force, twist and luffing.
- 🧪 **No mast visible** → `Sail.fbx` exports the mast as a face-less curve profile; `EquipmentVisualizer` now adds a procedural mast.
- 🧪 **Empty horizon** → Procedural sky, fog and islands (`SkyEnvironment`, `DistantIslands`).
- ✅ **Setup wizard wind settings silently ignored** → The wizard wrote `_baseWindSpeed`/`_baseWindDirection`, which `WindSystem` does not have. Now writes `_windSpeedKnots`/`_windDirection`.
- ✅ **Camera mode overlay drawn on top of the telemetry HUD** → `SimpleFollowCamera` overlay moved to the top-right corner.
- ✅ **Wizard validation looked for the legacy ThirdPersonCamera** → Now checks `SimpleFollowCamera`.

### Fixed in Session 26 (January 2, 2026) - Porpoising, Steering, Camera, Cleanup

- ✅ **Porpoising at high speed** → Removed sail downforce, set center of effort to (0,0,0), applied planing lift at center of mass
- ✅ **Steering inverted on port tack** → Added tack detection in AdvancedWindsurferController to flip A/D inputs
- ✅ **Camera not working until FOV change** → SimpleFollowCamera now disables conflicting ThirdPersonCamera
- ✅ **Pitch stabilization spasming at high heel** → Disabled pitch correction when heel > 25°

**Code Cleanup:**
- 🗑️ Removed `TelemetryHUD.cs` (superseded by AdvancedTelemetryHUD)
- 🗑️ Removed `WindsurferController.cs` V1 (superseded by AdvancedWindsurferController)
- 🗑️ Removed duplicate `PhysicsConstants` from PhysicsHelpers.cs
- 📁 Merged `Debugging/` folder into `Debug/` folder

### Fixed in Session 25 (January 1, 2026) - Physics Corrections

- ✅ **Fin induced drag was LINEAR instead of QUADRATIC** → Fixed `FinPhysics.cs` to use correct formula: `Cdi = Cl² / (π × AR × e)`. This makes beam reach (high side force) have proportionally MORE induced drag than broad reach, which should make broad reach faster.

- ✅ **Spray drag was DECREASING with planing** → Fixed `Hydrodynamics.cs` so spray drag INCREASES with planing (coefficient 0.01 × planingFactor). Spray generation increases at higher planing speeds.

- ✅ **CE height caused porpoising** → Set Center of Effort height to 0.0m in `AdvancedSail.cs` to eliminate heeling moment from sail force.

- ✅ **Artificial buoyancy reduction removed** → `AdvancedBuoyancy.cs` now uses pure Archimedes principle with no artificial scaling during planing.

- ✅ **Increased vertical damping** → `_verticalDamping` increased to 8000 N·s/m and `_waterViscosity` to 800 for more stable water contact.

**Note:** The velocity polar issue (beam reach faster than broad reach) may still need tuning. The physics corrections are in place but real-world testing is needed.

### 3. Half-Wind Submersion at Planing Speeds (FIXED - Session 23)

**Symptom:**  
When sailing beam reach (half wind) at high speed (planing), the board would go underwater and NOT slow down, continuing to sail submerged.

**Root Cause (ACTUAL):**  
The planing physics had two fundamental bugs:

1. **Planing Lift Not Disabled When Underwater**: The planing lift calculation only checked if the board was in the water (>5% submerged), but didn't check if it was TOO submerged (>50%). You can't plane underwater - the hull must be riding ON the surface.

2. **Insufficient Underwater Drag**: When the board went underwater at planing speed, drag didn't increase enough to slow it down. The sail kept pushing it forward underwater.

**Fix Applied:**  
Modified [AdvancedHullDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs):

1. **Disable Planing When Submerged**: If submersion > 50%, planing lift is completely disabled and decays rapidly
2. **Progressive Lift Penalty**: From 35% to 50% submersion, planing lift progressively reduces to 20%
3. **Massive Underwater Drag**: When submerged >50% at speed >4 m/s, additional drag multiplier (up to 5x) is applied
4. **Combined Effect**: Board goes underwater → loses planing lift → massive drag → slows down → buoyancy floats it back up

**New Inspector Parameter:**
- `Max Planing Submersion`: Submersion level at which planing is disabled (default: 50%)

**Files:**  
- [WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs)

---

## 🟡 Minor Issues

### 4. Sail Boom Visual Not Rotating (investigated in Session 27 - verify)

**Symptom:**  
The sail mesh doesn't visually rotate with sheet adjustments.

**Findings (Session 27):**  
`Sail.fbx` contains three objects: the sail cloth (`Plane`, 140 vertices), the wishbone boom (`Plane.001`, 3456 vertices) and a face-less mast profile (`BezierCircle.001`, no triangles). Cloth and boom are children of the same `SailPivot`, which `EquipmentVisualizer.UpdateSailRotation()` rotates by the physics sail angle, so the boom should turn with the sheet. The mast never rendered because it has no faces; a procedural mast is now added.

**Status:**  
Verify in Play mode. If the boom still does not follow W/S, check `_invertSailRotation` and `_sailRotationOffset` on `EquipmentVisualizer`, and confirm the Console shows the sail angle changing (F1 telemetry, "Sail Angle").

**Files:**  
- [WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs)
- [WindsurfingGame/Assets/Scripts/Visual/SailDeformer.cs](../WindsurfingGame/Assets/Scripts/Visual/SailDeformer.cs)

---

### 5. No Sound Effects (addressed in Session 27 - verify)

**Symptom:**  
No audio feedback for wind, water splash, or sail flapping.

**Status:**  
Procedural audio added (`Scripts/Audio/`). Volumes and filter cutoffs are untested guesses; tune them in the Inspector. Recorded samples can replace the generated clips later.

---

### 6. Session 27 Content Not Included in Builds Without Material References

**Symptom:**  
In a standalone build the islands or particles could render pink if their shaders were stripped.

**Status:**  
`OceanWater` and `VertexColorTerrain` are referenced by material assets (`WaterMaterial.mat`, `IslandTerrain.mat`) that the scene uses, so they are included. The particle material uses `Universal Render Pipeline/Particles/Unlit` (a URP built-in) and falls back to `Sprites/Default`. If a build shows pink particles, add the particle shader to *Project Settings → Graphics → Always Included Shaders*.

---

## ✅ Recently Fixed Issues

### Fixed in Session 24 (January 1, 2026) - Savitsky Planing & Water Damping

- ✅ **Board oscillates 0-100% submersion ("trampoline effect")** → Implemented Savitsky planing equations where lift depends on speed/trim only, not submersion depth. This eliminates the feedback loop that caused oscillation.
- ✅ **Water feels too bouncy** → Added water viscosity (v² damping) and increased vertical damping to 4000 N·s/m
- ✅ **Board flies out at high speed (45+ km/h)** → Added sail downforce at high speeds (starts at 35 km/h) and capped max lift to 85% of weight
- ✅ **Lateral damping killed forward speed** → Removed viscosity from horizontal damping, now only applies to vertical motion

### Fixed in Session 23 (Physics-Based Planing Fix)

- ✅ **Board submersion oscillates during planing** → Made planing lift scale with actual submersion ratio instead of fixed value, implementing natural self-stabilization based on real hydrodynamics (Savitsky planing principles)

### Fixed in Session 22 (December 28, 2025)

- ✅ **Board sinks 75%+ at displacement speeds** → Added displacement lift system
- ✅ **Planing starts too early (~8 km/h)** → Changed to speed-based thresholds (17+ km/h)
- ✅ **Sailor moves forward at speed** → Fixed COM shift to move AFT (backward)
- ✅ **Board turns too easily, pitches up** → Disabled custom inertia, reduced planing lift

### Fixed in Session 21 (December 28, 2025)

- ✅ **Camera missing script** → Changed namespace from `Camera` to `CameraSystem`
- ✅ **Water has no texture** → Wizard now ensures material is applied
- ✅ **Telemetry HUD not created** → Wizard now creates TelemetryHUD automatically

---

## 📝 How to Report New Issues

When you find a new issue:

1. **Describe the symptom** - What exactly happens?
2. **Steps to reproduce** - How can someone else see this?
3. **Expected behavior** - What should happen instead?
4. **Relevant files** - Which scripts are likely involved?

Add to this document under the appropriate section.

---

## 🔧 Debugging Tips

### Enable Debug Gizmos
1. In Scene view, click "Gizmos" button (top right)
2. Enable gizmos for specific components in Inspector
3. `AdvancedBuoyancy`, `AdvancedHullDrag`, `AdvancedSail` all have debug visualization

### Check Telemetry HUD
1. Press **F1** during play to toggle telemetry
2. Shows: speed, submersion %, planing ratio, forces, wind angle
3. If HUD not visible, check TelemetryHUD GameObject exists

### Console Logging
Most physics components log debug info. Check Console window for:
- Initialization messages (green checkmarks ✓)
- Warnings (yellow) for missing references
- Errors (red) for critical problems

---

*If you fix an issue, move it to the "Recently Fixed" section with the date and session number.*
