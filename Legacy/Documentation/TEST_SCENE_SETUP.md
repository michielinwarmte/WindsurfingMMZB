# 🧪 Test Scene Setup Guide

This guide walks you through setting up a test scene with working buoyancy.

---

## Prerequisites

- Unity project opened
- Scripts compiled without errors (check Console window)
- MainScene open (or create a new scene)

---

## Step 1: Create the Water Surface

### 1.1 Create Water Plane
1. **GameObject → 3D Object → Plane**
2. Rename to `WaterSurface`
3. Set **Position** to `(0, 0, 0)`
4. Set **Scale** to `(100, 1, 100)` - this gives us 1km × 1km of water

### 1.2 Configure Water Plane
1. Select `WaterSurface` in Hierarchy
2. **⚠️ IMPORTANT: Disable or Remove the Mesh Collider!**
   - In Inspector, find `Mesh Collider` component
   - **Uncheck the checkbox** to disable it, OR
   - Right-click the component → Remove Component
   - *The water should NOT have physics collision - BuoyancyBody handles floating!*

### 1.3 Add WaterSurface Script
1. With `WaterSurface` selected, click **Add Component**
2. Search for `WaterSurface` (or navigate: WindsurfingGame → Physics → Water)
3. Add it

### 1.4 (Optional) Add Water Material
1. In Project window: Right-click → Create → Material
2. Name it `WaterMaterial`
3. Set color to blue (e.g., RGB: 0, 100, 200)
4. Set **Surface Type** to `Transparent` (if using URP Lit shader)
5. Lower **Alpha** to ~0.7 for transparency
6. Drag material onto the water plane

---

## Step 2: Create a Floating Test Object

### 2.1 Create the Cube
1. **GameObject → 3D Object → Cube**
2. Rename to `TestFloater`
3. Set **Position** to `(0, 3, 0)` - above the water
4. Keep **Scale** at `(1, 1, 1)`

### 2.2 Add Rigidbody (Physics Body)
1. Select `TestFloater`
2. **Add Component → Physics → Rigidbody**
3. Configure Rigidbody:
   - **Mass**: `50` (heavier = sinks more, lighter = floats higher)
   - **Drag**: `0`
   - **Angular Drag**: `0.05`
   - **Use Gravity**: ✅ Checked
   - **Is Kinematic**: ❌ Unchecked

### 2.3 Add BuoyancyBody Script
1. **Add Component** → search for `BuoyancyBody`
2. Configure BuoyancyBody:
   - **Water Surface**: Drag the `WaterSurface` object here (optional - auto-finds if empty)
   - **Buoyancy Strength**: `500` (start with this, adjust as needed)
   - **Float Height**: `0.3`
   - **Water Damping**: `3`
   - **Angular Water Damping**: `1`
   - **Show Debug Gizmos**: ✅ Checked

### 2.4 Verify Collider
- The cube should have a **Box Collider** by default
- This is fine - the cube needs its collider for other physics, just NOT the water

---

## Step 3: Set Up the Camera

### 3.1 Configure Main Camera
1. Select **Main Camera** in Hierarchy
2. Set **Position** to `(0, 5, -10)`
3. Set **Rotation** to `(20, 0, 0)`

### 3.2 Add ThirdPersonCamera Script
1. **Add Component** → search for `ThirdPersonCamera`
2. Configure:
   - **Target**: Drag `TestFloater` here (or leave empty for auto-find)
   - **Offset**: `(0, 3, -8)`
   - **Follow Speed**: `5`
   - **Rotation Speed**: `3`

---

## Step 4: Test the Scene

### 4.1 Play the Scene
1. Press the **Play** button (▶️) or Ctrl+P
2. Watch the cube fall

### 4.2 Expected Behavior
✅ Cube falls due to gravity  
✅ Cube slows down as it enters water  
✅ Cube bobs up and down  
✅ Cube stabilizes floating at water level  
✅ Camera follows the cube smoothly  

### 4.3 Debug Visualization
While playing, select `TestFloater`:
- You should see **colored spheres** at buoyancy sample points
- **Cyan spheres** = underwater (applying buoyancy)
- **Red spheres** = above water (no buoyancy)

---

## Troubleshooting

### ❌ Cube falls through water and keeps falling
**Cause**: BuoyancyBody script not working or not added  
**Fix**: 
- Check Console for errors
- Verify BuoyancyBody component is on the cube
- Verify WaterSurface component is on the water plane

### ❌ Cube stops ON TOP of water plane (doesn't go in)
**Cause**: Water plane still has a collider  
**Fix**: Disable or remove `Mesh Collider` from the water plane

### ❌ Cube sinks completely
**Cause**: Buoyancy too weak for the mass  
**Fix**: Increase `Buoyancy Strength` (try 1000+) or decrease Rigidbody mass

### ❌ Cube floats too high / shoots up
**Cause**: Buoyancy too strong  
**Fix**: Decrease `Buoyancy Strength` or increase Rigidbody mass

### ❌ Cube bobs forever (never settles)
**Cause**: Not enough damping  
**Fix**: Increase `Water Damping` to 5-10

### ❌ Cube spins wildly
**Cause**: Not enough angular damping  
**Fix**: Increase `Angular Water Damping` to 2-5

### ❌ "No WaterSurface found" error
**Cause**: WaterSurface script not in scene  
**Fix**: Add `WaterSurface` component to the water plane

### ❌ Camera doesn't follow
**Cause**: Target not set  
**Fix**: Drag the floating object to the `Target` field in ThirdPersonCamera

---

## Recommended Starting Values

| Component | Property | Value |
|-----------|----------|-------|
| Rigidbody | Mass | 50 |
| Rigidbody | Drag | 0 |
| Rigidbody | Angular Drag | 0.05 |
| BuoyancyBody | Buoyancy Strength | 500 |
| BuoyancyBody | Float Height | 0.3 |
| BuoyancyBody | Water Damping | 3 |
| BuoyancyBody | Angular Water Damping | 1 |

---

## Adding Waves (Optional Test)

Once basic floating works:

1. Select `WaterSurface`
2. In the WaterSurface component:
   - Check **Enable Waves** ✅
   - Set **Wave Height**: `0.5`
   - Set **Wave Length**: `20`
   - Set **Wave Speed**: `2`
3. Play the scene - the cube should now bob with the waves!

Note: The visual plane won't move (that's Phase 2), but the buoyancy will respond to wave heights.

---

## Quick Checklist

Before pressing Play, verify:

- [ ] Water plane has `WaterSurface` script
- [ ] Water plane has collider **DISABLED**
- [ ] Floating object has `Rigidbody`
- [ ] Floating object has `BuoyancyBody`
- [ ] Floating object has a collider (Box Collider)
- [ ] Floating object starts ABOVE the water (Y > 0)
- [ ] No compile errors in Console

---

*Last Updated: December 19, 2025*

---

# 📊 Telemetry & Visual Reference Setup

This section shows how to add visual feedback and reference points to the scene.

---

## Step 1: Add Telemetry HUD

The telemetry HUD shows real-time information: speed, wind, sail position, etc.

### 1.1 Create HUD Object
1. **GameObject → Create Empty**
2. Rename to `TelemetryHUD`
3. Position doesn't matter (it's screen-space UI)

### 1.2 Add TelemetryHUD Script
1. **Add Component** → search `TelemetryHUD`
2. The script auto-finds all references
3. Default settings should work

### 1.3 What You'll See
- **Left panel**: Speed (km/h, knots), wind info, sail force
- **Right corner**: Wind compass showing true wind (cyan) and apparent wind (yellow)
- **Bottom left**: Control reminders

### 1.4 Toggle HUD
Press **H** to show/hide the telemetry display

---

## Step 2: Add 3D Wind Indicators

Shows wind direction as 3D arrows floating above the board.

### 2.1 Create Indicator Object
1. **GameObject → Create Empty**
2. Rename to `WindIndicator3D`

### 2.2 Add WindIndicator3D Script
1. **Add Component** → search `WindIndicator3D`
2. Configure:
   - **Show True Wind**: ✅
   - **Show Apparent Wind**: ✅
   - **Indicator Offset**: `(0, 3, 0)` - height above board

### 2.3 What You'll See
- **Cyan arrow**: True wind direction (actual wind)
- **Yellow arrow**: Apparent wind (what you feel while moving)
- Arrow size changes with wind speed

---

## Step 3: Add Water Grid Markers

Creates buoys and markers to give spatial reference on the empty water.

### 3.1 Create Markers Object
1. **GameObject → Create Empty**
2. Rename to `WaterMarkers`
3. Position at `(0, 0, 0)`

### 3.2 Add WaterGridMarkers Script
1. **Add Component** → search `WaterGridMarkers`
2. Configure:
   - **Grid Size**: `500` (500m total area)
   - **Marker Spacing**: `100` (buoy every 100m)
   - **Marker Height**: `2`
   - **Show Center Marker**: ✅
   - **Show Distance Rings**: ✅

### 3.3 What You'll See
- **Green center buoy**: Origin/starting point
- **Red buoys**: Every 200m (primary grid)
- **Yellow markers**: Every 100m (secondary grid)
- **Cardinal markers**: N/S/E/W with colored flags
- **Distance rings**: Small cubes at 100m, 250m, 500m

---

## Telemetry Display Reference

### Speed Panel
| Info | Meaning |
|------|---------|
| Speed (km/h) | Board speed in kilometers per hour |
| Speed (knots) | Board speed in nautical units |
| PLANING | Shows when board is on plane (fast!) |

### Wind Panel
| Info | Meaning |
|------|---------|
| True Wind | Actual wind speed in the world |
| Apparent | Wind you feel (true wind - your speed) |
| Wind Angle | Angle between your heading and wind |
| Point of Sail | Name of your current sailing angle |

### Points of Sail
| Angle | Name | Notes |
|-------|------|-------|
| 0-35° | No-Go Zone | Can't sail here! |
| 35-60° | Close-hauled | Upwind sailing |
| 60-80° | Close Reach | |
| 80-110° | Beam Reach | Fastest! ★ |
| 110-150° | Broad Reach | |
| 150-180° | Running | Downwind |

### Sail Panel
| Info | Meaning |
|------|---------|
| Sheet % | How much sail is released (0=tight, 100=loose) |
| Force (N) | Total force from sail in Newtons |

---

## Compass Indicator (Top Right)

```
        N
        ↑
   W ←──●──→ E
        ↓
        S

  ─── = Cyan arrow: True wind direction
  ─── = Yellow arrow: Apparent wind
  ▮ = White rectangle: Your board heading
```

---

## Quick Setup Checklist

For full visual feedback, create these objects:

- [ ] `TelemetryHUD` with TelemetryHUD script
- [ ] `WindIndicator3D` with WindIndicator3D script
- [ ] `WaterMarkers` with WaterGridMarkers script

All scripts auto-find references, so just add them and play!

---

This guide shows how to create a complete windsurf board with all physics components.

---

## Step 1: Create the WindManager

### 1.1 Create Empty GameObject
1. **GameObject → Create Empty**
2. Rename to `WindManager`
3. Position at `(0, 0, 0)`

### 1.2 Add WindManager Script
1. Select `WindManager` object
2. **Add Component** → search `WindManager`
3. Configure:
   - **Base Wind Speed**: `8` (m/s, about 15 knots - good for learning)
   - **Wind Direction Degrees**: `45` (coming from northeast)
   - **Enable Variation**: ✅ (for realistic gusts)
   - **Speed Variation**: `0.2` (20% variation)
   - **Show Wind Gizmo**: ✅

---

## Step 2: Create the Windsurf Board

### 2.1 Create Board Base
1. **GameObject → 3D Object → Cube**
2. Rename to `WindsurfBoard`
3. Set **Position**: `(0, 0.5, 0)`
4. Set **Scale**: `(0.6, 0.1, 2.5)` - board proportions
5. Set **Rotation**: `(0, 0, 0)`

### 2.2 Add Physics Components

#### Rigidbody
1. **Add Component → Physics → Rigidbody**
2. Configure:
   - **Mass**: `85` (board ~10kg + rider ~75kg)
   - **Drag**: `0`
   - **Angular Drag**: `0.5`
   - **Use Gravity**: ✅
   - **Interpolate**: `Interpolate` (smoother visuals)

#### BuoyancyBody
1. **Add Component** → search `BuoyancyBody`
2. Configure:
   - **Buoyancy Strength**: `1500`
   - **Float Height**: `0.2`
   - **Water Damping**: `4`
   - **Angular Water Damping**: `1.5`

#### WaterDrag
1. **Add Component** → search `WaterDrag`
2. Configure:
   - **Forward Drag**: `0.15`
   - **Lateral Drag**: `0.5` (low - fin handles lateral resistance)
   - **Planing Speed**: `4`

#### FinPhysics (NEW - Essential for tracking!)
1. **Add Component** → search `FinPhysics`
2. Configure:
   - **Fin Area**: `0.04` (4 cm² - typical slalom fin)
   - **Lift Coefficient**: `4`
   - **Fin Position**: `(0, -0.1, -0.8)` - at rear of board
   - **Min Effective Speed**: `0.5`
   - **Tracking Strength**: `2`
   - **Stall Angle**: `25`
3. This makes the board track properly when turning!

#### ApparentWindCalculator
1. **Add Component** → search `ApparentWindCalculator`
2. Leave defaults (auto-finds WindManager)

#### Sail
1. **Add Component** → search `Sail`
2. Configure:
   - **Sail Area**: `6` (6 m² - medium sail)
   - **Max Lift Coefficient**: `1.2`
   - **Sheet Position**: `0.5` (middle setting)
   - **Center of Effort**: `(0, 1.5, 0.3)`
   - **Rake Torque Multiplier**: `0.8` (for responsive steering)

#### WindsurferControllerV2 (RECOMMENDED)
1. **Add Component** → search `WindsurferControllerV2`
2. Configure:
   - **Control Mode**: `Beginner` (easier) or `Advanced` (realistic)
   - **Weight Shift Strength**: `15`
   - **Max Lean Angle**: `20`
   - **Anti Capsize**: ✅ Checked
   - **Combined Steering**: ✅ Checked (Beginner mode)

> **Note**: You can also use the original `WindsurferController` if you prefer, but V2 has improved physics and two control modes.

### 2.3 Component Checklist
Your WindsurfBoard should have these components:
- [ ] Transform
- [ ] Cube (Mesh Filter)
- [ ] Mesh Renderer
- [ ] Box Collider
- [ ] Rigidbody
- [ ] BuoyancyBody
- [ ] WaterDrag
- [ ] FinPhysics
- [ ] ApparentWindCalculator
- [ ] Sail
- [ ] WindsurferControllerV2 (or WindsurferController)
- [ ] SailVisualizer (optional - 3D sail visual)

### 2.4 Add Sail Visual (Optional)
1. **Add Component** → search `SailVisualizer`
2. Configure (defaults work well):
   - **Mast Height**: `4.5`
   - **Boom Length**: `2.5`
   - **Max Rake Angle**: `15`
   - **Sail Color**: Orange (default)

This creates a 3D visual representation of the sail that moves with your input!

### 2.5 Add Sail Position HUD (Optional)
1. Select your **Canvas** (or any GameObject)
2. **Add Component** → search `SailPositionIndicator`
3. Default position is bottom-left, showing top-down view of sail

---

## Step 3: Update Camera

1. Select **Main Camera**
2. Ensure **ThirdPersonCamera** component is added
3. Set **Target**: Drag `WindsurfBoard` here
4. Adjust **Offset**: `(0, 4, -10)` for better view

---

## Step 4: Test the Simulation

### 4.1 Play the Scene
1. Press **Play** (▶️)
2. Board should float on water
3. You should see wind arrow gizmo in Scene view

### 4.2 Controls

#### Beginner Mode (Default)
| Key | Action |
|-----|--------|
| **A/D** | Steer left/right (combined) |
| **W** | Sheet in - more power |
| **S** | Sheet out - less power |
| **Q/E** | Fine mast rake control |
| **Tab** | Switch to Advanced mode |
| **H** | Toggle HUD |

#### Advanced Mode
| Key | Action |
|-----|--------|
| **Q** | Rake mast forward (bear away) |
| **E** | Rake mast back (head up) |
| **A/D** | Weight shift / lean |
| **W/S** | Sheet in/out |
| **Tab** | Switch to Beginner mode |

### 4.3 Expected Behavior
- ✅ Board floats at water level
- ✅ Wind pushes the board forward
- ✅ Steering turns the board smoothly
- ✅ Speed increases with proper sail trim
- ✅ Board slows when sailing into wind (no-go zone)
- ✅ Can sail upwind by raking mast back (E key)
- ✅ Can bear away by raking mast forward (Q key)

---

## Step 5: Understanding the Physics

### Wind Angles

```
            WIND (from here)
                 ↓
         No-Go Zone (can't sail)
         ╱    45°    ╲
        ╱             ╲
   Close-hauled    Close-hauled
       ╱               ╲
      ╱     90° = Beam Reach (fastest!)
     ╱                   ╲
Broad Reach         Broad Reach
     ╲                   ╱
      ╲    135°        ╱
       ╲             ╱
         Running (downwind)
              180°
```

### Why Sheet In/Out?
- **Upwind (close-hauled)**: Sheet IN tight - sail acts like a wing
- **Across wind (beam reach)**: Medium sheet - maximum power
- **Downwind (running)**: Sheet OUT - catch wind like a parachute

---

## Troubleshooting

### ❌ Board doesn't move
- Check WindManager exists and has wind speed > 0
- Check Sail component is attached and has area > 0
- Look at Scene view for force debug vectors

### ❌ Board flips over
- Reduce Sail force by lowering sail area
- Increase Angular Water Damping in BuoyancyBody
- Lower Center of Effort Y value

### ❌ Board moves too slow
- Increase wind speed in WindManager
- Increase sail area
- Reduce forward drag in WaterDrag

### ❌ Board won't turn
- Check WindsurferController is attached
- Press A/D keys (not arrow keys, unless configured)
- Increase Turn Speed value

### ❌ Too much sideways drift
- Increase Lateral Drag in WaterDrag (simulates fin)

---

## Recommended Starting Values (Summary)

| Component | Property | Value |
|-----------|----------|-------|
| **WindManager** | Wind Speed | 8 m/s |
| **WindManager** | Direction | 45° |
| **Rigidbody** | Mass | 85 kg |
| **BuoyancyBody** | Strength | 1500 |
| **BuoyancyBody** | Float Height | 0.2 |
| **BuoyancyBody** | Water Damping | 4 |
| **WaterDrag** | Forward Drag | 0.15 |
| **WaterDrag** | Lateral Drag | 3 |
| **Sail** | Sail Area | 6 m² |
| **WindsurferController** | Turn Speed | 50 |

---

## Optional: Save as Prefab

Once everything works:
1. Drag `WindsurfBoard` from Hierarchy into `Assets/Prefabs` folder
2. This creates a reusable prefab
3. You can now spawn multiple boards from this prefab

---

*Last Updated: December 19, 2025*
