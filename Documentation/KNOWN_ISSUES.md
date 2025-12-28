# 🐛 Known Issues

**Last Updated:** December 28, 2025

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

### 2. Board Submersion Oscillates During Planing

**Symptom:**  
When planing (at speed), the board oscillates between 0% and 100% submerged instead of riding stable at ~5% submersion. Speed is maintained but visual appearance is erratic.

**Root Cause:**  
The displacement lift and planing lift forces are fighting with buoyancy. When the board rises (lift working), it loses submersion, which reduces lift, causing it to fall, which increases submersion and lift again.

**Expected Behavior:**  
Board should ride at 3-5% submersion when planing, skimming the surface with minimal bobbing.

**Fix Needed:**  
1. Add hysteresis/smoothing to the lift calculations
2. Use a PID controller or similar feedback loop to stabilize height
3. Consider separate equilibrium targets for displacement vs planing modes

**Files:**  
- [WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs](../WindsurfingGame/Assets/Scripts/Physics/Board/AdvancedHullDrag.cs) (displacement lift, planing lift)
- [WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs](../WindsurfingGame/Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs) (buoyancy forces)

---

### 3. Steering is Inverted

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
