# Graphics Update Guide - Board, Sail, and Water

## What You'll Do (Simple Overview)

1. **In Blender**: Set pivot points → Export FBX files
2. **In Unity**: Import FBX → Create materials → Build prefab
3. **Test**: Make sure physics still works

**Total Time**: ~30-45 minutes

## What Are Pivot Points? (Important!)

Think of a pivot point like where you'd stick a pin through paper to spin it:
- **Board**: Pin at the bottom-center → board rocks realistically on water
- **Sail**: Pin at the mast base → sail rotates around the mast

**If pivot points are wrong**, the sail will spin around the wrong spot (looks weird!)

## Prerequisites
- Blender models ready (Board.blend and Sail.blend)
- Unity project open
- Models are roughly to real-world scale (typical board = 2.5m long)

## Step 1: Export Models from Blender

### Board Model Export

#### Setting the Board Pivot Point (Easy Method)

**Goal**: Put the pivot at the bottom-center of the board (where it floats on water)

**Steps:**
1. Open `Board.blend` in Blender
2. Press **Tab** to enter Edit Mode
3. Press **A** to select all parts of the board
4. Press **Numpad 3** (or use View menu) to see the side view
5. Now you need to place the 3D cursor (that round target thing):
   
   **Method A - Automatic** (easiest):
   - Press **Shift + S**
   - Choose "Cursor to Selected"
   - Move your mouse to roughly the bottom-center of the board
   - Click
   
   **Method B - Manual**:
   - Hold **Shift** and **Right-click** on the bottom-center of the board
   - The cursor appears there

6. Press **Tab** again to go back to Object Mode
7. **Right-click** on the board → **Set Origin** → **Origin to 3D Cursor**
8. **Check it worked**: Look for the orange/yellow dot - it should be at the bottom-center

**Visual Check**: If you press **R** (rotate), the board should spin around that bottom point. If it spins around the middle or top, redo the steps above.

#### Export the Board

1. Select all parts of your board (click the board, or press **A** in Object Mode)
2. **File** → **Export** → **FBX (.fbx)**
3. A big export window opens. Change these settings:

   **In the right panel, find these options:**
   - **Scale**: Type `1.0` (this makes 1 meter in Blender = 1 meter in Unity)
   - **Forward**: Change to **X Forward** (dropdown)
   - **Up**: Change to **Z Up** (dropdown)
   - **Apply Scalings**: Choose **FBX All** (dropdown)
   
   **Checkboxes to ENABLE (✓):**
   - Apply Transform ✓
   - Mesh ✓
   
   **Checkboxes to DISABLE:**
   - Bake Animation (uncheck - we don't need it)

4. At the top, name the file: **Board.fbx**
5. Click **Export FBX** button

**Where to save**: Create a folder like `Unity_Export` to keep things organized

### Sail Model Export

#### Setting the Sail Pivot Point (CRITICAL!)

**Goal**: Put the pivot at the very bottom of the mast (where it touches the board)

**Why this matters**: The sail needs to rotate around the mast, just like in real life. Wrong pivot = sail rotates from the wrong spot = looks broken!

**Steps:**
1. Open `Sail.blend` in Blender
2. Look at your mast - find the **very bottom** where it would touch the board deck
3. Press **Tab** to enter Edit Mode
4. Click on ONE vertex (corner point) at the very base of the mast
   - Zoom in if you need to see it clearly
   - You should see one little dot highlighted
5. Press **Shift + S** → choose "Cursor to Selected"
   - The 3D cursor jumps to that point
6. Press **Tab** to go back to Object Mode
7. **Right-click** on the sail → **Set Origin** → **Origin to 3D Cursor**
8. **Check it worked**:
   - Orange dot should be at the mast bottom
   - Press **R** to rotate - sail should spin around the mast base
   - If it spins from the middle of the sail, you need to redo it

**Common Mistake**: Putting the pivot in the middle of the mast or at the boom. It MUST be at the very bottom where the mast meets the board!

#### Export the Sail
1. Select all sail components (sail fabric, mast, boom)
2. **File → Export → FBX (.fbx)**
3. Export settings (same as board - Z+ up, X+ forward):
   - Scale: 1.0
   - Forward: **X Forward**
   - Up: **Z Up**
   - Apply Scalings: FBX All
   - Apply Transform: Check ✓
   - Mesh: Check ✓
   - Bake Animation: Uncheck
4. Save as: `Sail.fbx`

### Alternative: Combined Windsurf Rig
If you prefer one model with separate parts:
1. Create hierarchy in Blender:
   - Root: WindsurfRig (empty)
   - Children: Board, Mast, Boom, Sail
2. Export entire hierarchy
3. Save as: `WindsurfRig.fbx`

### Pivot Point Visual Reference

```
BOARD (Side View - looking from right side):
     Mast
      |
      |     <-- Sail
    __|\_________
   /   |         \
  |    |          |  <-- Board hull
  |____|__________|
       ^
       | PIVOT HERE (center bottom, at waterline)
       

SAIL (Front View):
         /|\
        / | \
       /  |  \   <-- Sail fabric
      /   |   \
     /____|____\
         |
         |  <-- Mast
         |
         * <-- PIVOT HERE (base of mast, at board connection)
```

**In Blender Coordinates (Z up, X forward):**
- Board pivot: Center of board, Z = bottom of hull (waterline)
- Sail pivot: Base of mast, Z = where mast meets board
- Both should be centered on X and Y axes

## Step 2: Prepare Materials in Blender (Optional)

If you've created materials in Blender:
1. Ensure materials use Principled BSDF shader
2. Texture files should be packed or in a textures folder
3. Unity will attempt to import these, but you may need to recreate them

## Step 3: Import Models into Unity

### Create Folder Structure
1. In Unity Project window, navigate to `Assets/Models/`
2. Create subfolders:
   - `Board/`
   - `Sail/`
   - `Windsurf/` (if using combined model)

### Import FBX Files
1. Copy your .fbx files to the appropriate folders (you can drag from Windows Explorer)
2. Select the imported FBX in Unity
3. In Inspector, configure import settings:

#### Board.fbx Settings:
- **Model Tab**:
  - Scale Factor: 1
  - Convert Units: Check
  - Bake Axis Conversion: Check
  - Import BlendShapes: Uncheck
  - Import Visibility: Uncheck
  - Import Cameras/Lights: Uncheck
  - Preserve Hierarchy: Check
  - Generate Colliders: Uncheck (we'll use custom physics colliders)
- **Materials Tab**:
  - Location: Use Embedded Materials
  - Naming: By Base Texture Name
  - Click "Extract Textures" if you have textures
  - Click "Extract Materials" to create Unity materials
- Click **Apply**

#### Sail.fbx Settings:
- Same as Board settings
- **Important**: Verify pivot point in Scene view
  - The model should rotate around the mast position
  - If incorrect, fix in Blender and re-export

## Step 4: Create/Update Materials

### Board Materials
1. Create folder: `Assets/Materials/Board/`
2. Right-click → **Create → Material**
3. Name materials appropriately:
   - `BoardDeck_Material`
   - `BoardBottom_Material`
   - `Fin_Material`

#### Material Settings (URP Standard):
- **Surface Type**: Opaque
- **Rendering Mode**: Opaque
- **Base Map**: Assign texture if you have one
- **Metallic**: 0.1-0.3 (slight glossiness)
- **Smoothness**: 0.4-0.6
- **Normal Map**: Optional, for detail

### Sail Materials
1. Create folder: `Assets/Materials/Sail/`
2. Create materials:
   - `SailFabric_Material`
   - `Mast_Material`
   - `Boom_Material`

#### Sail Fabric Settings:
- **Surface Type**: Opaque (or Transparent if you want see-through)
- **Base Map**: Sail texture/pattern
- **Metallic**: 0
- **Smoothness**: 0.3-0.5
- **Optional**: Add slight emission for bright conditions

#### Mast/Boom Settings:
- **Surface Type**: Opaque
- **Base Map**: Carbon fiber or aluminum texture
- **Metallic**: 0.6-0.8
- **Smoothness**: 0.7-0.9

### Apply Materials to Models
1. Expand the model in Project window
2. Drag materials onto the sub-meshes
3. Or select model → Inspector → Materials section → assign materials

## Step 5: Create the WindsurfRig Prefab (Board + Sail as Separate Parts)

The physics system now uses a **WindsurfRig** parent that holds both the board and sail as separate child objects. This matches how you've set up your Blender models!

### Understanding the Hierarchy

```
WindsurfRig (Parent - Empty GameObject)
│   Components: Rigidbody, WindsurfRig, BuoyancyBody, WindsurferController
│
├── Board (Your Board.fbx model)
│   │   - Visual only, no physics components
│   │   - Pivot: underside of board, behind mast base (as you set up)
│   │
│   └── Colliders (child empty for organization)
│       ├── BoardCollider (Box Collider)
│       └── FinCollider (Box or Mesh Collider)
│
└── Sail (Your Sail.fbx model)
        Components: Sail, ApparentWindCalculator
        - Pivot: base of mast (as you set up in Blender)
        - Position: at mast base location on the board
```

### Step-by-Step Prefab Setup (Follow Exactly)

#### 1. Create the Parent (Empty Container)

1. In Unity, look at the **Hierarchy** panel (left side)
2. **Right-click** in empty space → **Create Empty**
3. A new GameObject appears - **rename it to**: `WindsurfRig`
4. With `WindsurfRig` selected, look at **Inspector** panel (right side)
5. In the Transform section, click the **gear icon** → **Reset**
   - This sets Position, Rotation, Scale all to correct values

#### 2. Add Your Board Model

1. In the **Project** panel (bottom), navigate to `Assets/Models/Board/`
2. You should see your `Board.fbx` file there
3. **Drag** `Board.fbx` and **drop it onto** `WindsurfRig` in the Hierarchy
   - It should now be indented under WindsurfRig (that's good!)
4. **Rename** it from "Board.fbx" to just `Board`
5. In Inspector, check Transform:
   - Position: **(0, 0, 0)**
   - Rotation: **(0, 0, 0)**
   - If not, click gear → Reset

#### 3. Add Your Sail Model

1. In **Project** panel, go to `Assets/Models/Sail/`
2. **Drag** `Sail.fbx` onto `WindsurfRig` in Hierarchy (same as board)
3. **Rename** to just `Sail`
4. **This is the tricky part** - positioning the sail:

   In Inspector, set **Position** to where the mast sits on the board:
   - **X**: `0.85` (this is FORWARD - how far from tail to mast)
   - **Y**: `0.15` (this is UP - height of board deck)
   - **Z**: `0` (this is SIDEWAYS - keep centered)
   
   **How to find the right values:**
   - Start with X=0.85, Y=0.15, Z=0
   - Switch to **Scene** view (tab at top)
   - Look at your model - does the mast base touch the board deck?
   - If mast is too far forward/back, adjust X
   - If mast is floating/sunken, adjust Y
   
5. Set Rotation: **(0, 0, 0)**

**Visual Check**: In Scene view, zoom in. The mast base should be sitting ON the board deck, not floating above or sunk below.

#### 4. Add Physics and Scripts to WindsurfRig

**Click on `WindsurfRig`** in Hierarchy. Now we'll add components one at a time:

**Component 1: Rigidbody** (makes it react to physics)
1. In Inspector, click **Add Component**
2. Type "Rigidbody" and select it
3. Change these values:
   - Mass: `12` (weight in kg)
   - Drag: `0.5` (water resistance)
   - Angular Drag: `1.0` (rotation resistance)
   - Use Gravity: **CHECK the box** ✓
   - Interpolate: Choose **Interpolate** from dropdown
   - Collision Detection: Choose **Continuous** from dropdown

**Component 2: WindsurfRig Script** (connects board + sail)
1. Click **Add Component**
2. Type "WindsurfRig" and select it
3. You'll see fields appear:
   - **Board Visual**: Drag the `Board` child from Hierarchy into this slot
   - **Sail**: Drag the `Sail` child from Hierarchy into this slot
   - **Mast Base Position**: Type `0.85, 0.15, 0` (must match sail position!)
   - **Rigidbody**: Leave empty (finds it automatically)

**Component 3: BuoyancyBody** (makes it float)
1. Click **Add Component**
2. Type "BuoyancyBody" and select it
3. Set:
   - Buoyancy Strength: `15`
   - Float Height: `0.1`
   - Water Damping: `1.5`
   - Leave other fields as default for now

**Component 4: WindsurferController** (keyboard controls)
1. Click **Add Component**
2. Type "WindsurferController" and select it
3. Most fields auto-fill, but check:
   - Turn Speed: `30`
   - Max Edge Angle: `25`
   - Everything else can stay default

**Component 5: WaterDrag** (resistance when moving through water)
1. Click **Add Component**
2. Type "WaterDrag" and select it
3. Leave all values as default (it finds what it needs automatically)

**Component 6: FinPhysics** (prevents sideways drift, helps steering)
1. Click **Add Component**
2. Type "FinPhysics" and select it
3. Set:
   - Fin Area: `0.04`
   - Lift Coefficient: `4`
   - Enable Tracking: **CHECK** ✓

#### 5. Add Scripts to the Sail

**Click on the `Sail` child** in Hierarchy. Now add components:

**Component 1: Sail Script** (calculates wind forces)
1. Click **Add Component**
2. Type "Sail" and select it
3. You'll see many fields - set these:
   - **Sail Area**: `6` (square meters - typical sail size)
   - **Max Lift Coefficient**: `1.2` (how efficient the sail is)
   - **Mast Height**: `4.5` (measure your model if unsure)
   - **Boom Length**: `2.0`
   - **Boom Height**: `1.8`
   - **Target Rigidbody**: Leave empty (finds it automatically)
   - Leave other values as default

**Component 2: ApparentWindCalculator** (figures out wind + movement)
1. Click **Add Component**
2. Type "ApparentWindCalculator" and select it
3. **Leave all fields empty** - it auto-finds what it needs

**That's it for the Sail!**

#### 6. Add Colliders (So It Can Bump Into Things)

**Click on `Board`** child in Hierarchy:

1. Click **Add Component** → type "Box Collider" → select it
2. A green box outline appears around your board
3. Adjust the box to match your board shape:
   - **Size X**: `2.5` (length of board)
   - **Size Y**: `0.15` (thickness)
   - **Size Z**: `0.6` (width)
   - **Center**: Usually `0, 0, 0` but adjust if the green box doesn't cover the board

**Test it:** In Scene view, the green wireframe box should wrap around your board model. Adjust Size values until it fits.

**Optional - Add Fin Collider:**
1. Right-click on `Board` → Create Empty
2. Name it `FinCollider`
3. Position it where the fin is (under the board, toward the tail)
4. Add Component → Box Collider
5. Make it small and thin to match the fin shape

#### 7. Set Up Buoyancy Points (Makes It Rock Realistically)

**What are these?** Points where the game checks water height. More points = more realistic rocking.

**Quick Setup (4 points):**

1. Right-click on `WindsurfRig` → **Create Empty** → name it `BuoyancyPoint_Nose`
   - Set Position: `1.2, 0, 0` (front of board)
   
2. Right-click on `WindsurfRig` → **Create Empty** → name it `BuoyancyPoint_Tail`
   - Set Position: `-1.0, 0, 0` (back of board)
   
3. Right-click on `WindsurfRig` → **Create Empty** → name it `BuoyancyPoint_Left`
   - Set Position: `0, 0, -0.25` (left side)
   
4. Right-click on `WindsurfRig` → **Create Empty** → name it `BuoyancyPoint_Right`
   - Set Position: `0, 0, 0.25` (right side)

5. Now click on `WindsurfRig` and find the **BuoyancyBody** component
6. Find the field called **Buoyancy Points** - it should say "Array" with a size
7. Change size to `4`
8. **Drag each buoyancy point** into the Element 0, 1, 2, 3 slots

**Can't find the points?** In Hierarchy, they should be indented under WindsurfRig. Look for the small arrows to expand/collapse.

#### 8. Configure Sail Visualization (Optional but Recommended)

The SailVisualizer creates a simple visual sail in the telemetry. Now that you have a real 3D sail model, you can disable the generated geometry:

**If you want to use your real sail model (recommended):**
1. Find any GameObject with **SailVisualizer** script attached
   - Might be on WindsurfRig or separate "UI" object
2. In the SailVisualizer component:
   - Check "Use Real Sail Model" ✓
   - Drag your **Sail** child into the "Sail Transform" field
3. The visualizer will now read from your actual sail's rotation

**If you want the old simple geometry:**
- Uncheck "Use Real Sail Model"
- The script will create basic mast/boom/sail shapes

#### 9. Add Optional Physics Components (For Better Physics)

These aren't required but make it feel more realistic:

**Click on `WindsurfRig`** and add:

**WaterDrag Component** (resistance when moving through water):
1. **Add Component** → type "WaterDrag" → select it
2. Leave all values as default (auto-configures)

**FinPhysics Component** (helps with steering):
1. **Add Component** → type "FinPhysics" → select it  
2. Leave all values as default

#### 10. Create the Prefab (Save It!)
1. **Drag** `WindsurfRig` from Hierarchy into `Assets/Prefabs/` folder in Project panel
2. A prefab asset is created - it turns blue in Hierarchy!
3. **Rename** it if needed: `WindsurfRig`

**What's a prefab?** It's a saved template you can reuse. Now you can drag this into any scene!

---

## Step 6: Set Up the Water Surface (CRITICAL!)

**THIS IS WHY IT'S FALLING!** You need a water surface in the scene for the board to float on.

### Quick Water Setup

#### 1. Create the Water Plane

1. In Hierarchy, **right-click** → **3D Object** → **Plane**
2. **Rename** it to: `WaterSurface`
3. In Inspector, set Transform:
   - **Position**: `0, 0, 0` (at world origin)
   - **Rotation**: `0, 0, 0`
   - **Scale**: `10, 1, 10` (makes it 100x100 meters - plenty of space!)

#### 2. Add the WaterSurface Script

1. With `WaterSurface` selected, click **Add Component**
2. Type "WaterSurface" and select it
3. Configure:
   - **Wave Height**: `0.5` (half meter waves)
   - **Wave Frequency**: `1.0` (how fast waves move)
   - **Wave Speed**: `2.0`
   - Leave other settings as default

#### 3. Make It Look Like Water (Basic)

1. Find the existing water material at `Assets/Materials/WaterMaterial.mat`
2. **Drag** `WaterMaterial.mat` onto the WaterSurface in Scene view
3. It should turn blue/water colored

**OR create a new material:**
1. Right-click in `Assets/Materials/` → **Create** → **Material**
2. Name it: `WaterMaterial_Updated`
3. Set **Base Color** to blue (click the color box, pick a water blue)
4. Set **Metallic**: `0.8`
5. Set **Smoothness**: `0.9` (makes it shiny)
6. Drag this material onto WaterSurface

---

## Step 7: Put It All Together in the Scene

### 1. Position the WindsurfRig

1. In Hierarchy, select your `WindsurfRig`
2. In Inspector, set Position:
   - **X**: `0`
   - **Y**: `0.5` ← **IMPORTANT! This puts it ABOVE water so it drops onto it**
   - **Z**: `0`

**Why Y=0.5?** The water is at Y=0. Starting at Y=0.5 means the board drops and then floats. This tests that buoyancy works!

### 2. Check for Wind Manager

The sail needs wind to work! Check if you have a WindManager:

1. Look in Hierarchy for an object called `WindManager`
2. **If you DON'T have one:**
   - Right-click in Hierarchy → **Create Empty**
   - Name it: `WindManager`
   - **Add Component** → type "WindManager" → select it
   - Set **Wind Speed**: `5` (meters/sec - moderate wind)
   - Set **Wind Direction**: `0, 0, 1` (blowing in +Z direction)

### Final Checklist (Do This Before Testing!)

**In Hierarchy, you should see:**
```
WaterSurface ← Has WaterSurface script, blue material
WindManager ← Has WindManager script
WindsurfRig ← Position Y = 0.5 (above water)
```

**Expand `WindsurfRig` in Hierarchy. You should see:**

```
WindsurfRig ← Has Rigidbody, WindsurfRig, BuoyancyBody, WindsurferController
├── Board ← Position (0,0,0), has Box Collider
├── Sail ← Position (0.85, 0.15, 0), has Sail + ApparentWindCalculator scripts
├── BuoyancyPoint_Nose
├── BuoyancyPoint_Tail
├── BuoyancyPoint_Left
└── BuoyancyPoint_Right
```

**Check These:**
- [ ] WaterSurface exists at Y=0 with WaterSurface script
- [ ] WindManager exists with wind speed set
- [ ] WindsurfRig Y position is ABOVE 0 (like 0.5)
- [ ] Sail's mast base visually touches the board deck (not floating)
- [ ] All scripts show "None (Missing)" errors = BAD (go back and fix)
- [ ] Green collider box wraps around board in Scene view
- [ ] WindsurfRig → WindsurfRig script → Board Visual slot is filled
- [ ] WindsurfRig → WindsurfRig script → Sail slot is filled

---

## Step 8: TEST IT!

### First Test - Does It Float?

1. Click the **Play** button (▶) at the top of Unity
2. **Watch what happens:**

**✅ GOOD - It should:**
- Fall for a split second
- Hit the water
- Bob up and down
- Settle at the waterline (half submerged)

**❌ BAD - If it:**
- Falls straight through water = BuoyancyBody can't find WaterSurface
- Doesn't move at all = Rigidbody might not have gravity
- Spins wildly = Buoyancy points might be wrong

### Second Test - Can You Control It?

With Play mode active:

1. Press **W** - Sail should sheet in (tighten)
2. Press **S** - Sail should sheet out (loosen)
3. Press **A** - Should turn left
4. Press **D** - Should turn right
5. Press **Q** - Rake mast forward
6. Press **E** - Rake mast back

**If nothing happens when you press keys:**
- Check that WindsurferController is attached to WindsurfRig
- Make sure the scene view is NOT selected (click on Game view first)

---

## Troubleshooting Common Issues

### Problem: Falls Through Water

**Cause:** BuoyancyBody can't find the WaterSurface

**Fix:**
1. Click on WindsurfRig
2. Find BuoyancyBody component
3. Look for the **Water Surface** field
4. If it says "None", drag WaterSurface from Hierarchy into that field

**Still not working?**
- Make sure WaterSurface has the WaterSurface script attached
- Check Console (Window → General → Console) for error messages

### Problem: Floats But Doesn't Move

**Cause:** No wind, or Sail script not working

**Fix:**
1. Check WindManager exists and has wind speed > 0
2. Click on Sail child object
3. Verify it has both Sail and ApparentWindCalculator components
4. In Sail component, check "Target Rigidbody" - drag WindsurfRig there if empty

### Problem: Spins Wildly or Flips Over

**Cause:** Buoyancy points positioned wrong

**Fix:**
1. Stop Play mode
2. Check the 4 BuoyancyPoint positions:
   - Nose should be FORWARD (positive X)
   - Tail should be BACK (negative X)
   - Left/Right should be on the sides (positive/negative Z)
3. Make sure all points have Y=0

### Problem: Rig Stays in Same Place / Won't Move

**Cause:** Rigidbody is kinematic or constraints are enabled

**Fix:**
1. Click on WindsurfRig
2. Find Rigidbody component
3. **CRITICAL CHECKS:**
   - **Is Kinematic**: Must be **UNCHECKED** ❌
   - **Use Gravity**: Must be **CHECKED** ✓
   - **Constraints**: Expand this section
     - ALL position/rotation constraints must be **UNCHECKED**
     - Especially "Freeze Position Y" - if checked, rig can't move up/down!
4. Press Play again

**Still not moving?** See [TROUBLESHOOTING_RIG_NOT_MOVING.md](TROUBLESHOOTING_RIG_NOT_MOVING.md)

### Problem: Sail Visualizer Doesn't Match Real Sail

**Cause:** SailVisualizer creating its own geometry instead of reading real sail transform

**Fix:**
1. Find GameObject with **SailVisualizer** script (check WindsurfRig or UI objects)
2. In SailVisualizer component:
   - **Check** "Use Real Sail Model" ✓
   - **Drag** your Sail child GameObject into "Sail Transform" field
3. Now the telemetry visualizer reads directly from your actual sail's rotation
4. Sail orientation will match perfectly!

### Problem: Sail Doesn't Rotate Visually (Real Model)

**Cause:** WindsurfRig script visual rotation disabled

**Fix:**
1. Click WindsurfRig
2. Find WindsurfRig script component
3. Check "Enable Sail Visual Rotation" is CHECKED ✓
4. Make sure "Sail" field has the Sail child assigned
5. The sail should now rotate based on wind direction

### Problem: No Physics At All

**Cause:** Rigidbody settings wrong

**Fix:**
1. Click WindsurfRig
2. Find Rigidbody component
3. Make sure:
   - Use Gravity is CHECKED ✓
   - Mass > 0 (should be ~12)
   - Is Kinematic is UNCHECKED

## Step 6: Update Water Graphics

### Option A: Stylized Water Shader
1. Create new material: `Assets/Materials/WaterMaterial_Updated.mat`
2. Create custom shader or use Unity's water shader:
   - **Shader**: Universal Render Pipeline/Lit
   - **Base Color**: Blue-green tint (RGB: 0.2, 0.5, 0.6)
   - **Metallic**: 0.8
   - **Smoothness**: 0.95
   - **Normal Map**: Create or use tiling water normal map

#### Creating Animated Water Normal Map:
1. Find/create 2 water normal map textures
2. Create shader graph or script to pan/blend them
3. Or use Unity's Water package (URP)

### Option B: Unity Water Package (Recommended)
1. **Window → Package Manager**
2. Search for "Water System" (if available in your Unity version)
3. Install package
4. Create new water surface following package docs

### Option C: Custom Water Mesh with Animation
1. In Blender, create water plane with subdivisions
2. Export as `WaterSurface.fbx`
3. Import to Unity
4. Apply material with:
   - Transparent surface type
   - Animated normal maps
   - Fresnel effect for shore/depth
5. Attach `WaterSurface.cs` script for physics

#### Update WaterSurface Script (if using custom mesh):
The water mesh should be scaled appropriately in the scene.
See current script at: `Assets/Scripts/Physics/Water/WaterSurface.cs`

## Step 7: Update Scene

### Place Models in Scene
1. Open `Assets/Scenes/MainScene.unity`
2. Delete old placeholder objects (if any)
3. Drag `WindsurfRig_Complete` prefab into scene
4. Position at starting point (Y should be at water level ~0.0)

### Update Water
1. Select existing Water plane GameObject
2. Replace material with new `WaterMaterial_Updated`
3. Or delete and create new water surface
4. Ensure WaterSurface script is attached
5. Configure in Inspector:
   - Wave Height: 0.5
   - Wave Frequency: 1.0
   - (other parameters as needed)

### Lighting Adjustments
1. Select Directional Light
2. Adjust for ocean scene:
   - Intensity: 1.0-1.5
   - Color: Slight warm tint for sunset, or cool for daytime
3. Add Skybox if desired:
   - **Window → Rendering → Lighting**
   - Skybox Material: Create or use procedural sky

## Step 8: Test in Play Mode

### Visual Checks
1. Click **Play**
2. Verify:
   - ✅ Board model displays correctly
   - ✅ Sail model displays correctly
   - ✅ Materials look good
   - ✅ Water surface is visible
   - ✅ No missing textures (pink materials)

### Physics Checks
1. Board should float on water
2. Sail should respond to controls
3. No collider issues or interpenetration

### Common Issues:
- **Pink materials**: Textures not found → reassign in material
- **Model too small/large**: Check scale in Blender export (should be 1.0)
- **Sail pivot wrong**: Re-export from Blender with correct origin
- **Physics broken**: Ensure Rigidbody and colliders are properly set

## Step 9: Optimize (Optional)

### LOD (Level of Detail)
1. Create lower-poly versions of models in Blender
2. Import as separate FBX files
3. Add LOD Group component to prefab
4. Assign LOD levels:
   - LOD 0: Full detail (100% - 50%)
   - LOD 1: Medium detail (50% - 20%)
   - LOD 2: Low detail (20% - 5%)

### Texture Optimization
1. Select textures in Project
2. Inspector → Platform Settings
3. Reduce Max Size if too large (512 or 1024 for most)
4. Use compression (DXT5 for normal maps, DXT1 for diffuse)

### Mesh Optimization
1. Select model in Project
2. Inspector → Model tab
3. Check "Optimize Mesh"
4. Apply

## Step 10: Documentation Update

### Update Files:
1. `PROGRESS_LOG.md` - Add entry about graphics update
2. `DEVELOPMENT_PLAN.md` - Check off graphics milestones
3. Take screenshots of new models for documentation
4. Update README.md with new screenshots if applicable

### Git Commit
```bash
git add Assets/Models/ Assets/Materials/ Assets/Prefabs/
git add Documentation/GRAPHICS_UPDATE_GUIDE.md
git commit -m "Update graphics: new board, sail, and water models from Blender"
```

## Quick Reference Checklist

- [ ] Export models from Blender (FBX format, correct scale and orientation)
- [ ] Import FBX files to Unity Models folder
- [ ] Configure import settings (scale, materials)
- [ ] Create/extract materials
- [ ] Apply textures to materials
- [ ] Adjust material properties (metallic, smoothness)
- [ ] Create prefabs with physics components
- [ ] Update water material/mesh
- [ ] Place in scene and test
- [ ] Adjust lighting
- [ ] Verify physics still works
- [ ] Optimize if needed
- [ ] Update documentation
- [ ] Commit to git

## Additional Resources

- [Unity FBX Import Documentation](https://docs.unity3d.com/Manual/HOWTO-importObject.html)
- [Unity Materials and Shaders](https://docs.unity3d.com/Manual/Materials.html)
- [URP Lit Shader](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@latest)

---

**Next Steps After Graphics Update:**
- Fine-tune physics parameters to match new model scale
- Add visual effects (spray, wake, splash)
- Implement sail animation (billowing in wind)
- Add detail: rope rigging, board graphics/decals
