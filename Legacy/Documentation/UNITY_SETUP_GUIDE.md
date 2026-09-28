# 🚀 Unity Project Setup Guide

This guide walks you through creating the Unity project for our windsurfing game.

## Step 1: Install Unity 6.3 LTS

1. Download **Unity Hub** from [unity.com/download](https://unity.com/download)
2. Open Unity Hub
3. Go to **Installs** tab
4. Click **Install Editor**
5. Select **Unity 6.3 LTS** (Long Term Support)
6. Check these modules:
   - ✅ Microsoft Visual Studio Community (or use existing)
   - ✅ Windows Build Support (IL2CPP)
   - ❓ WebGL Build Support (optional, for browser games)
7. Click **Install**

## Step 2: Create Unity Project

### Option A: Create from Unity Hub (Recommended)

1. Open Unity Hub
2. Go to **Projects** tab
3. Click **New project**
4. Select **Unity 6.3 LTS** version
5. Choose **3D (URP)** template - Universal Render Pipeline
6. Set Project Name: `WindsurfingGame`
7. Set Location: Navigate to `D:\Github\WindsurfingMMZB\`
8. Click **Create project**

> ⚠️ **Important**: This will create the Unity project inside our repository folder!

### Option B: Initialize in Existing Folder

If you already have the repo cloned:
1. In Unity Hub → Projects → New project
2. Choose **3D (URP)** template
3. Name it exactly the same as the folder or use the folder directly
4. Unity will initialize the project structure

## Step 3: Verify URP Setup

After Unity opens:

1. Go to **Window → Rendering → Render Pipeline Converter**
2. Ensure URP is active (check Project Settings → Graphics)
3. Create a new URP Asset if needed:
   - Right-click in Project → Create → Rendering → URP Asset

## Step 4: Configure Project Settings

### Quality Settings
1. **Edit → Project Settings → Quality**
2. Keep "Balanced" as default
3. Ensure URP Asset is assigned

### Physics Settings
1. **Edit → Project Settings → Physics**
2. Note default gravity: -9.81 (we might adjust this)
3. Default Fixed Timestep: 0.02 (50 updates/second)

### Input System
1. **Edit → Project Settings → Player**
2. Under "Other Settings" find "Active Input Handling"
3. Consider using "Both" for flexibility (old + new input system)

## Step 5: Create Folder Structure

In Unity's Project window, create these folders:

```
Assets/
├── Scenes/
├── Scripts/
│   ├── Physics/
│   │   ├── Water/
│   │   ├── Wind/
│   │   ├── Buoyancy/
│   │   └── Board/
│   ├── Player/
│   ├── Camera/
│   ├── UI/
│   └── Utilities/
├── Prefabs/
├── Materials/
├── Models/
├── Textures/
├── Shaders/
└── Audio/
```

Right-click in Project window → Create → Folder

## Step 6: Create First Scene

1. **File → New Scene** (or Ctrl+N)
2. Choose **Basic (URP)** template
3. Save as `Assets/Scenes/MainScene.unity`
4. This will be our development sandbox

## Step 7: Initial Scene Setup

In your new scene:

### Add Directional Light (if not present)
- Already included in URP template
- Represents the sun

### Create Water Placeholder
1. **GameObject → 3D Object → Plane**
2. Rename to "WaterSurface"
3. Scale to (100, 1, 100) for a large area
4. Position at (0, 0, 0)

### Create Board Placeholder
1. **GameObject → 3D Object → Cube**
2. Rename to "WindsurfBoard"
3. Scale to (0.6, 0.1, 2.5) - roughly board proportions
4. Position at (0, 0.5, 0) - above water
5. Add **Rigidbody** component (Add Component → Physics → Rigidbody)

### Adjust Camera
1. Select "Main Camera"
2. Position it at (0, 5, -10)
3. Rotation (20, 0, 0) to look down at the board

## Step 8: Save and Test

1. **File → Save** (Ctrl+S)
2. Press **Play** button
3. Watch the cube fall (gravity test!)
4. If it falls through the plane, add a **Box Collider** to the plane

## What You Should See

After completing setup:
- ✅ Unity project opens without errors
- ✅ URP is active (check lighting looks correct)
- ✅ Folder structure is in place
- ✅ Basic scene with plane and cube
- ✅ Cube falls and lands on plane when you hit Play

## Troubleshooting

### "Pink/Magenta materials"
→ URP isn't set up correctly. Check Project Settings → Graphics

### "Unity takes forever to open"
→ First launch imports many assets. Normal for new projects.

### "Can't find 3D (URP) template"
→ Install URP package: Window → Package Manager → Universal RP

### "Rigidbody falls through plane"
→ Add Collider components to both objects

---

## Next Steps

Once the Unity project is set up, we'll:
1. Create our first script (WaterSurface.cs)
2. Implement basic wave visualization
3. Start building the buoyancy system

**Ready? Let me know when you've completed the setup!**

---

*Last Updated: December 19, 2025*
