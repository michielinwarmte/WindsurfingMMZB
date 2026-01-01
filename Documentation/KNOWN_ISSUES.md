# 🐛 Known Issues

**Last Updated:** January 1, 2026

This document tracks known issues, bugs, and their workarounds. For contributors picking up this project, these are the priority fixes needed.

---

## 🔴 Critical Issues (Needs Fix)

### 1. Camera Only Works When Changing FOV in Inspector

**Symptom:**  
The camera doesn't follow the windsurfer until you manually change the FOV value in the Inspector during Play mode.

**Root Cause:**  
The `SimpleFollowCamera` component isn't initializing properly on first frame. The camera target reference exists but the follow logic isn't activating.

**Workaround:**  
1. Enter Play mode
2. Select Main Camera in Hierarchy
3. In Inspector, change FOV from 60 to 61 (or any value)
4. Camera will start following

**Fix Needed:**  
Investigate `SimpleFollowCamera.cs` initialization in `Start()` or `OnEnable()`. May need to force position update on first frame.

**Files:**  
- [WindsurfingGame/Assets/Scripts/Camera/SimpleFollowCamera.cs](../WindsurfingGame/Assets/Scripts/Camera/SimpleFollowCamera.cs)

---

### 2. Steering is Inverted

**Symptom:**  
A/D keys steer in the wrong direction (left turns right, right turns left).

**Root Cause:**  
Sign error in the steering torque calculation or rake steering formula.

**Fix Needed:**  
1. Check `AdvancedWindsurferController.cs` for steering input handling
2. Check `AdvancedSail.cs` → `ApplyRakeSteering()` for sign conventions
3. May need to negate the steering input or torque direction

**Files:**  
- [WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs](../WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs)
- [WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs)

---

### 3. Half-Wind Submersion (Under Investigation)

**Symptom:**  
When sailing beam reach (half wind) with full sheet, the board may sink progressively, especially at lower speeds before planing.

**Root Cause:**  
The heeling moment from sail force (applied high on the mast) causes the leeward rail to submerge. This creates asymmetric buoyancy and drag forces. This is realistic physics - real windsurfers must actively counter this by hiking out.

**Current Status:**  
This is a physics limitation, not a bug. The current anti-capsize system (sailor weight shift) helps but may need tuning. When planing, hydrodynamic forces naturally prevent full submersion.

**Potential Improvements:**
- Add stronger automatic sailor hiking simulation
- Reduce sail power at high angles of attack (stall earlier)
- Increase the anti-capsize strength for beam reach specifically

**Files:**  
- [WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs](../WindsurfingGame/Assets/Scripts/Player/AdvancedWindsurferController.cs)
- [WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedSail.cs)

---

## 🟡 Minor Issues

### 4. Sail Boom Visual Not Rotating

**Symptom:**  
The sail mesh doesn't visually rotate with sheet adjustments.

**Status:**  
Low priority - physics work correctly, just visual feedback missing.

**Files:**  
- [WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs](../WindsurfingGame/Assets/Scripts/Visual/EquipmentVisualizer.cs)

---

### 5. No Sound Effects

**Symptom:**  
No audio feedback for wind, water splash, or sail flapping.

**Status:**  
Feature not implemented yet. Audio folder exists but is empty.

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
