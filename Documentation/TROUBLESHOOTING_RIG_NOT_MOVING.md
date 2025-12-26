# Troubleshooting: Rig Stays in Place / Won't Move

## Symptoms
- Press Play and the WindsurfRig doesn't fall
- It just floats in mid-air at the starting position
- No response to keyboard controls
- Board doesn't react to physics

---

## Checklist (Fix in Order)

### ✅ 1. Check Rigidbody Settings

**Click on WindsurfRig in Hierarchy → Look at Rigidbody component:**

| Setting | Should Be | Why |
|---------|-----------|-----|
| **Is Kinematic** | ❌ UNCHECKED | If checked, physics won't affect it |
| **Use Gravity** | ✅ CHECKED | Needs gravity to fall |
| **Mass** | 10-15 | Should have weight |
| **Constraints** | All UNLOCKED | Check Position/Rotation constraints |

**Common Problem:** Is Kinematic is checked
**Fix:** Uncheck "Is Kinematic"

---

### ✅ 2. Check Position Constraints

**In Rigidbody component, expand "Constraints":**

All checkboxes should be **UNCHECKED**:
- [ ] Freeze Position X
- [ ] Freeze Position Y  ← **Most common mistake!**
- [ ] Freeze Position Z
- [ ] Freeze Rotation X
- [ ] Freeze Rotation Y
- [ ] Freeze Rotation Z

**If Freeze Position Y is checked**, the rig can't move up/down (stuck in air)!

---

### ✅ 3. Verify Scene is Playing

**Look at the top toolbar:**
- The Play button (▶) should be **blue/highlighted**
- You should see "Entering Play Mode" in the status bar
- Time should be advancing in bottom-left corner

**Not in Play Mode?**
- Click the Play button (▶)
- Check Console for errors preventing Play mode

---

### ✅ 4. Check for Script Errors

**Open Console (Window → General → Console):**

**RED errors** will prevent scripts from running!

Common errors:
- "NullReferenceException" → A script reference is missing
- "The referenced script on this Behaviour is missing!" → Script not attached properly

**Fix:**
- Read the error message
- Double-click error to go to the problem
- Fill in missing script references in Inspector

---

### ✅ 5. Verify BuoyancyBody Setup

**Click WindsurfRig → Find BuoyancyBody component:**

| Field | Should Be |
|-------|-----------|
| Water Surface | **Filled** (drag WaterSurface here) or leave empty for auto-find |
| Buoyancy Strength | 10-20 |
| Buoyancy Points | Array with 4 elements (or leave empty to auto-generate) |

**If Water Surface field is empty:**
- Make sure WaterSurface exists in scene
- Try manually dragging it from Hierarchy

---

### ✅ 6. Check Starting Height

**Select WindsurfRig → Look at Transform → Position:**

**Y value should be ABOVE the water:**
- Water is at Y = 0
- Set WindsurfRig Y to **0.5** or **1.0**
- If Y is already 0 or negative, it might be stuck in water

**Fix:**
- Stop Play mode
- Set Position Y to 1.0
- Press Play again

---

### ✅ 7. Verify WaterSurface Exists

**Look in Hierarchy for "WaterSurface":**

**Should have:**
- Transform Position Y = **0**
- **WaterSurface** script attached
- Scale (10, 1, 10) or larger

**If missing:**
- See GRAPHICS_UPDATE_GUIDE.md - Step 6
- Create Plane → rename to WaterSurface
- Add WaterSurface script
- Position at (0, 0, 0)

---

### ✅ 8. Test with Simple Cube

**Make sure physics works at all:**

1. Create → 3D Object → Cube
2. Position it at (0, 2, 0) - above water
3. Add Rigidbody to it
4. Press Play

**If cube falls:**
- Physics works! Problem is with WindsurfRig setup

**If cube doesn't fall:**
- Gravity might be disabled globally
- Edit → Project Settings → Physics → Gravity Y should be **-9.81**

---

### ✅ 9. Check Time Scale

**Bottom-left of Unity window:**

Should show: **`>` Time: 0.0** (advancing when in Play mode)

**If time is stuck at 0:**
- Time scale might be 0
- Click on dropdown next to time → set to **1x**

---

### ✅ 10. Verify Components Exist

**Click WindsurfRig → Inspector should show:**

Required components:
- ✅ Transform
- ✅ Rigidbody
- ✅ WindsurfRig
- ✅ BuoyancyBody
- ✅ WindsurferController (or V2)

**Missing components?**
- Add them back (see GRAPHICS_UPDATE_GUIDE.md - Step 5)

---

## Quick Test Script

If still stuck, try this to test if Rigidbody responds:

1. Click WindsurfRig
2. Add Component → New Script → name it "TestMove"
3. Paste this code:

```csharp
using UnityEngine;

public class TestMove : MonoBehaviour
{
    private void FixedUpdate()
    {
        GetComponent<Rigidbody>().AddForce(Vector3.up * 10f);
        Debug.Log("Applying force!");
    }
}
```

4. Press Play
5. Check Console - should see "Applying force!" repeating
6. Rig should bounce up and down

**If it moves:** Problem is with buoyancy/water setup
**If it doesn't move:** Problem is with Rigidbody setup

---

## Still Stuck?

### Check These Files in Console:

1. Open Console (Ctrl+Shift+C)
2. Look for warnings (yellow) and errors (red)
3. Share the error messages - they tell you exactly what's wrong!

### Common Error Messages:

| Error | Meaning | Fix |
|-------|---------|-----|
| "No WaterSurface found in scene" | BuoyancyBody can't find water | Add WaterSurface GameObject |
| "Object reference not set to an instance" | Missing script reference | Fill in Inspector fields |
| "The type or namespace name could not be found" | Compilation error | Check script syntax |

---

## Working Checklist

When everything is correct, you should see:

1. ✅ Press Play
2. ✅ Rig falls for ~0.5 seconds
3. ✅ Hits water (Y=0)
4. ✅ Bobs up and down
5. ✅ Settles at waterline (partially submerged)
6. ✅ Responds to WASD/QE keys
7. ✅ Telemetry shows data

If ANY step fails, stop and fix that step first!
