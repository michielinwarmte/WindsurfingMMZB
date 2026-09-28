# Scene Configuration Guide

## Complete Setup Documentation for Windsurfing Game

This document contains **ALL** parameters, settings, and GameObject configurations needed to replicate the project on any PC. Use this as the definitive reference for setting up the MainScene.

---

## Scene Hierarchy

The MainScene contains the following GameObjects:

1. **Main Camera** - Third-person camera following the board
2. **Directional Light** - Scene lighting
3. **WaterSurface** - Water plane
4. **WindsurfBoard** - Main player object with all physics components
5. **WindManager** - Global wind simulation
6. **TelemetryHUD** - UI overlay

---

## 1. WindsurfBoard GameObject

**Transform:**
- Position: `(0, 0.5, 0)`
- Rotation: `(0, 0, 0)`
- Scale: `(0.6, 0.1, 2.5)`

**Components to Add (in this order):**

### A. Rigidbody
```
Mass: 50
Linear Damping: 0
Angular Damping: 0.5
Center of Mass: (0, 0, 0)
Use Gravity: ✓ (checked)
Is Kinematic: ☐ (unchecked)
Interpolate: Interpolate
Constraints: None
Collision Detection: Discrete
```

### B. BoxCollider
```
Is Trigger: ☐ (unchecked)
Material: None
Size: (1, 1, 1)
Center: (0, 0, 0)
```

### C. MeshFilter
```
Mesh: Cube (built-in)
```

### D. MeshRenderer
```
Materials: Size 1
  - Element 0: DefaultMaterial (or any board material)
Cast Shadows: On
Receive Shadows: On
```

### E. BuoyancyBody Script
**Script:** `WindsurfingGame.Physics.Buoyancy.BuoyancyBody`

```
Water Reference:
  _waterSurface: Drag WaterSurface GameObject here

Buoyancy Settings:
  _buoyancyStrength: 1500
  _floatHeight: 0.2
  _waterDamping: 100
  _angularWaterDamping: 1.5

Buoyancy Points:
  _buoyancyPoints: [] (empty array - will auto-generate)
  _autoGeneratePoints: 4

Debug:
  _showDebugGizmos: ✓ (checked)
```

### F. WaterDrag Script
**Script:** `WindsurfingGame.Physics.Board.WaterDrag`

```
Drag Coefficients:
  _forwardDrag: 0.15
  _lateralDrag: 3
  _verticalDrag: 4

Speed Effects:
  _planingSpeed: 4
  _planingDragMultiplier: 0.5

References:
  _buoyancy: None (will auto-find)
```

### G. ApparentWindCalculator Script
**Script:** `WindsurfingGame.Physics.Board.ApparentWindCalculator`

```
References:
  _rigidbody: None (will auto-find)
  _windManager: None (will auto-find)

Debug:
  _showDebugVectors: ✓ (checked)
  _vectorScale: 0.5
```

### H. Sail Script
**Script:** `WindsurfingGame.Physics.Board.Sail`

```
Sail Properties:
  _sailArea: 6
  _maxLiftCoefficient: 1.2
  _baseDragCoefficient: 0.5

Sail Control:
  _sheetPosition: 0.5
  _sheetSpeed: 2

Mast Position (Fixed):
  _mastFootPosition: (0, 0.1, -0.05)
  _mastHeight: 4.5
  _boomLength: 2.0
  _boomHeight: 1.8

Mast Rake (Steering):
  _mastRake: 0
  _maxRakeAngle: 15
  _rakeSpeed: 5
  _rakeTorqueMultiplier: 0.6

References:
  _targetRigidbody: None (will auto-find)

Debug:
  _showForceVectors: ✓ (checked)
```

**Note:** The old Sail script might have `_centerOfEffort` instead of the mast position properties. If so, use:
```
_centerOfEffort: (0, 1.5, 0.3)
```

### I. FinPhysics Script (MISSING - Add This!)
**Script:** `WindsurfingGame.Physics.Board.FinPhysics`

```
Fin Properties:
  _finArea: 0.04
  _liftCoefficient: 4
  _finPosition: (0, -0.1, -0.8)

Speed Effects:
  _minEffectiveSpeed: 0.5
  _fullEffectSpeed: 3

Tracking Force:
  _trackingStrength: 2
  _enableTracking: ✓ (checked)

Stall Behavior:
  _stallAngle: 25
  _stallFalloff: 0.5

Debug:
  _showDebugVectors: ✓ (checked)
```

### J. WindsurferController Script (OPTIONAL - Old Version)
**Script:** `WindsurfingGame.Player.WindsurferController`

```
References:
  _rigidbody: None (will auto-find)
  _sail: None (will auto-find)

Control Parameters:
  _turnSpeed: 50
  _speedTurnMultiplier: 0.5
  _maxEdgeAngle: 20
  _edgeSpeed: 3
  _inputSmoothing: 5
```

### K. WindsurferControllerV2 Script (RECOMMENDED - New Version)
**Script:** `WindsurfingGame.Player.WindsurferControllerV2`

```
References:
  _rigidbody: None (will auto-find)
  _sail: None (will auto-find)
  _finPhysics: None (will auto-find)
  _apparentWind: None (will auto-find)

Control Mode:
  _controlMode: Beginner

Weight Shift (A/D):
  _weightShiftStrength: 12
  _maxLeanAngle: 30
  _weightShiftSpeed: 6

Edge Control:
  _edgeFinBonus: 1.5
  _maxRollAngle: 15

Beginner Assists:
  _autoSheet: ✓ (checked)
  _antiCapsize: ✓ (checked)
  _combinedSteering: ✓ (checked)
  _autoStabilize: ✓ (checked)
  _stabilizationStrength: 5

Input Response:
  _inputResponsiveness: 6
  _autoCenterMast: ✓ (checked)
```

**IMPORTANT:** Only use ONE controller - either WindsurferController OR WindsurferControllerV2. Recommended: Use V2.

### L. SailVisualizer Script (OPTIONAL - Visual Enhancement)
**Script:** `WindsurfingGame.Visual.SailVisualizer`

```
References:
  _sail: None (will auto-find)
  _apparentWind: None (will auto-find)

Mast Settings:
  _mastHeight: 4.5
  _mastRadius: 0.04
  _maxRakeAngle: 15
  _mastBasePosition: (0, 0.1, -0.05)

Boom Settings:
  _boomLength: 2.5
  _boomHeight: 1.5
  _boomRadius: 0.03

Colors:
  _mastColor: RGB(77, 77, 77, 255)
  _boomColor: RGB(102, 102, 102, 255)
  _sailColor: RGB(255, 77, 26, 204)
  _sailPoweredColor: RGB(255, 128, 51, 230)

Animation:
  _smoothSpeed: 8
```

---

## 2. WaterSurface GameObject

**Transform:**
- Position: `(0, 0, 0)`
- Rotation: `(0, 0, 0)`
- Scale: `(100, 1, 100)`

**Components:**

### MeshFilter
```
Mesh: Plane (built-in)
```

### MeshRenderer
```
Materials: Size 1
  - Element 0: WaterMaterial (blue/cyan material)
```

### WaterSurface Script
**Script:** `WindsurfingGame.Physics.Water.WaterSurface`

```
Water Settings:
  _baseHeight: 0

Wave Settings (Phase 2):
  _enableWaves: ☐ (unchecked for now)
  _waveHeight: 0.5
  _waveLength: 10
  _waveSpeed: 1
  _waveDirection: 0
```

---

## 3. WindManager GameObject

**Transform:**
- Position: `(0, 0, 0)`
- Rotation: `(0, 0, 0)`
- Scale: `(1, 1, 1)`

**Components:**

### WindManager Script
**Script:** `WindsurfingGame.Physics.Wind.WindManager`

```
Base Wind Settings:
  _baseWindSpeed: 8
  _windDirectionDegrees: 45

Wind Variation:
  _enableVariation: ✓ (checked)
  _speedVariation: 0.2
  _directionVariation: 10
  _gustFrequency: 0.1

Debug Visualization:
  _showWindGizmo: ✓ (checked)
  _gizmoScale: 5
```

---

## 4. Main Camera GameObject

**Transform:**
- Position: `(0, 5, -10)`
- Rotation: `(20, 0, 0)`
- Scale: `(1, 1, 1)`

**Components:**

### Camera
```
Clear Flags: Skybox
Background: (not used with Skybox)
Culling Mask: Everything
Projection: Perspective
Field of View: 60
Clipping Planes:
  Near: 0.3
  Far: 1000
```

### ThirdPersonCamera Script
**Script:** `WindsurfingGame.CameraSystem.ThirdPersonCamera`

```
Target:
  _target: Drag WindsurfBoard Transform here

Position Settings:
  _offset: (0, 8, -1.46)
  _followSpeed: 5
  _rotationSpeed: 3

Look Settings:
  _lookOffset: (0, 1, 2)

Constraints:
  _minHeight: 1
  _waterSurface: None (optional - can leave empty)
```

---

## 5. Directional Light GameObject

**Transform:**
- Position: `(0, 3, 0)`
- Rotation: `(50, -30, 0)`
- Scale: `(1, 1, 1)`

**Components:**

### Light
```
Type: Directional
Color: White RGB(255, 255, 255)
Mode: Realtime
Intensity: 1
Indirect Multiplier: 1
Shadow Type: Soft Shadows
```

---

## 6. TelemetryHUD GameObject

**Transform:**
- Position: `(0, 0, 0)`
- Rotation: `(0, 0, 0)`
- Scale: `(1, 1, 1)`

**Components:**

### TelemetryHUD Script
**Script:** `WindsurfingGame.UI.TelemetryHUD`

```
References:
  _controller: None (will auto-find)
  _controllerV2: None (will auto-find)
  _boardRigidbody: None (will auto-find)
  _windManager: None (will auto-find)
  _apparentWind: None (will auto-find)
  _sail: None (will auto-find)
  _waterDrag: None (will auto-find)
  _finPhysics: None (will auto-find)

Display Settings:
  _showTelemetry: ✓ (checked)
  _showWindIndicator: ✓ (checked)
  _showControls: ✓ (checked)

Styling:
  _fontSize: 18
  _backgroundColor: RGBA(0, 0, 0, 179)
  _textColor: RGB(255, 255, 255, 255)
  _highlightColor: RGB(0, 255, 255, 255)
```

### WindIndicator3D Script (OPTIONAL)
**Script:** `WindsurfingGame.UI.WindIndicator3D`

```
References:
  _boardTransform: Drag WindsurfBoard Transform here
  _windManager: None (will auto-find)
  _apparentWind: None (will auto-find)

True Wind Arrow:
  _showTrueWind: ✓ (checked)
  _trueWindColor: RGBA(0, 204, 255, 204)
  _trueWindScale: 0.3

Apparent Wind Arrow:
  _showApparentWind: ✓ (checked)
  _apparentWindColor: RGBA(255, 230, 0, 204)
  _apparentWindScale: 0.3

Position:
  _indicatorOffset: (0, 3, 0)
```

---

## Control Scheme

### Beginner Mode (Default):
- **A/D**: Combined steering (turn left/right)
- **W/S**: Sheet control (pull in/let out sail)
- **Tab**: Toggle between Beginner/Advanced mode

### Advanced Mode:
- **Q/E**: Mast rake (tilt mast forward/back)
- **A/D**: Weight shift (lean body left/right)
- **W/S**: Sheet control (pull in/let out sail)
- **Tab**: Toggle between Beginner/Advanced mode

---

## Material Setup

### Board Material
Create a material named "BoardMaterial":
- Shader: Universal Render Pipeline/Lit (or Standard)
- Base Color: Any color (e.g., white, yellow, or board-like color)
- Smoothness: 0.3-0.5

### Water Material
Create a material named "WaterMaterial":
- Shader: Universal Render Pipeline/Lit (or Standard)
- Base Color: Cyan/Blue (e.g., RGB 0, 180, 255)
- Smoothness: 0.8
- Metallic: 0
- Alpha: 0.7-0.8 (if using transparent shader)

---

## Project Settings

### Physics Settings (Edit > Project Settings > Physics)
```
Gravity: (0, -9.81, 0)
Default Material: None
Bounce Threshold: 2
Sleep Threshold: 0.005
Default Contact Offset: 0.01
Default Solver Iterations: 6
Default Solver Velocity Iterations: 1
```

### Time Settings (Edit > Project Settings > Time)
```
Fixed Timestep: 0.02 (50 Hz)
Maximum Allowed Timestep: 0.1
Time Scale: 1
```

---

## Step-by-Step Setup Instructions

### Creating the Scene from Scratch:

1. **Create New Scene**
   - File > New Scene > Basic (Built-in)
   - Delete default objects if needed

2. **Create WindsurfBoard**
   - GameObject > 3D Object > Cube
   - Rename to "WindsurfBoard"
   - Set Transform as specified above
   - Add Rigidbody component
   - Add all scripts in order: BuoyancyBody, WaterDrag, ApparentWindCalculator, Sail, FinPhysics, WindsurferControllerV2
   - Configure each script's parameters as listed above

3. **Create WaterSurface**
   - GameObject > 3D Object > Plane
   - Rename to "WaterSurface"
   - Set Transform as specified above
   - Add WaterSurface script
   - Configure parameters

4. **Create WindManager**
   - GameObject > Create Empty
   - Rename to "WindManager"
   - Add WindManager script
   - Configure parameters

5. **Setup Camera**
   - Select Main Camera
   - Set Transform as specified above
   - Add ThirdPersonCamera script
   - Drag WindsurfBoard to _target field
   - Configure parameters

6. **Setup Lighting**
   - Select Directional Light (should exist by default)
   - Set Transform as specified above

7. **Create UI**
   - GameObject > Create Empty
   - Rename to "TelemetryHUD"
   - Add TelemetryHUD script
   - Optionally add WindIndicator3D script

8. **Link References**
   - WindsurfBoard > BuoyancyBody > Drag WaterSurface GameObject to _waterSurface field
   - Main Camera > ThirdPersonCamera > Drag WindsurfBoard to _target field
   - All other references should auto-find on Play

9. **Create Materials**
   - Create BoardMaterial and WaterMaterial as described above
   - Assign BoardMaterial to WindsurfBoard
   - Assign WaterMaterial to WaterSurface

10. **Save Scene**
    - File > Save As > "MainScene"

---

## Common Issues and Solutions

### Issue: Board sinks immediately
**Solution:** 
- Check BuoyancyBody _buoyancyStrength is set to 1500
- Ensure WaterSurface GameObject is assigned in BuoyancyBody
- Check Rigidbody mass is 50

### Issue: Board doesn't move
**Solution:**
- Verify WindManager exists in scene
- Check Sail script has _sailArea = 6
- Ensure Rigidbody "Use Gravity" is checked
- Verify controller script is attached

### Issue: Board spins out of control
**Solution:**
- Check FinPhysics is attached and enabled
- Verify FinPhysics _trackingStrength is 2
- Check Rigidbody Angular Damping is 0.5

### Issue: Scripts show "Missing Reference" errors
**Solution:**
- Most scripts auto-find references - press Play to let them initialize
- Only BuoyancyBody and ThirdPersonCamera need manual assignment

### Issue: No wind forces
**Solution:**
- Verify WindManager is in scene
- Check WindManager _baseWindSpeed is 8
- Ensure ApparentWindCalculator is on board

---

## Version Control Notes

### Files to Commit:
- All .cs script files in Assets/Scripts/
- Assets/Scenes/MainScene.unity
- Assets/Materials/ (board and water materials)
- This documentation file

### Files to Ignore (.gitignore):
- Library/
- Temp/
- Logs/
- UserSettings/
- *.csproj
- *.sln (except if you want to share)

---

## Testing Checklist

After setup, verify:
- [ ] Board floats on water surface
- [ ] Board responds to WASD/Arrow keys
- [ ] Board moves forward when wind is applied
- [ ] Camera follows board smoothly
- [ ] Telemetry HUD displays speed, wind, etc.
- [ ] Board can turn left/right
- [ ] Sail visualizer shows (if added)
- [ ] Wind indicators show (if added)
- [ ] No console errors on Play

---

## Additional Scripts (Optional Enhancements)

### SailPositionIndicator
**Script:** `WindsurfingGame.UI.SailPositionIndicator`
- Visual UI indicator for sail position
- Auto-finds references

### WaterGridMarkers
**Script:** `WindsurfingGame.Utilities.WaterGridMarkers`
- Draws grid on water for spatial reference
- Helps with speed perception

### PhysicsHelpers
**Script:** `WindsurfingGame.Utilities.PhysicsHelpers`
- Utility functions for physics calculations
- Static class, no GameObject needed

---

## Performance Notes

Recommended settings for smooth gameplay:
- Target frame rate: 60 FPS
- Fixed Timestep: 0.02 (50 Hz physics updates)
- V-Sync: On (to prevent screen tearing)
- Quality Settings: Medium to High

---

## Last Updated
December 27, 2025

This configuration represents the complete working setup of the Windsurfing Game. All parameters have been documented from the actual scene file and script source code.
