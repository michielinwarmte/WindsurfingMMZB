# Quick Fix: WindsurfRig Falls Through Water

## The Problem
Your WindsurfRig falls to the ground instead of floating on water.

## Quick Diagnosis

**Press Play and watch:**
- Does it fall slowly or instantly?
- Does it stop at Y=0 or keep falling?
- Do you see any errors in the Console? (Window → General → Console)

---

## Solution Checklist (Do in Order)

### ✅ Step 1: Check Water Surface Exists

**Look in Hierarchy:**
- [ ] Is there a GameObject called "WaterSurface" or "Water"?

**If NO:**
1. Right-click in Hierarchy → 3D Object → Plane
2. Rename to "WaterSurface"
3. Position: (0, 0, 0)
4. Scale: (10, 1, 10)

**If YES, continue:**

---

### ✅ Step 2: Check WaterSurface Has Script

**Click on WaterSurface in Hierarchy:**
- [ ] Does it have a component called "WaterSurface" in Inspector?

**If NO:**
1. Click "Add Component"
2. Type "WaterSurface"
3. Select it
4. Set Wave Height: 0.5

---

### ✅ Step 3: Check BuoyancyBody Can Find Water

**Click on WindsurfRig in Hierarchy:**

1. Find the "BuoyancyBody" component in Inspector
2. Look for a field called "Water Surface"
3. Is it empty or does it say "None"?

**If empty:**
- Drag the WaterSurface GameObject from Hierarchy into this field
- OR click the little circle icon → select WaterSurface from the list

---

### ✅ Step 4: Check WindsurfRig Position

**With WindsurfRig selected:**

In Transform component:
- **Position Y should be ABOVE 0** (try 0.5 or 1.0)
- Water is at Y=0
- If WindsurfRig starts at Y=-5, it's already below water!

**Fix:**
- Set Position to: (0, 0.5, 0)

---

### ✅ Step 5: Check Rigidbody Settings

**With WindsurfRig selected:**

Find Rigidbody component and check:
- [ ] Use Gravity is CHECKED ✓
- [ ] Is Kinematic is UNCHECKED
- [ ] Mass is around 10-15

**If wrong, fix them!**

---

### ✅ Step 6: Check Buoyancy Strength

**With WindsurfRig selected:**

In BuoyancyBody component:
- [ ] Buoyancy Strength should be 10-20 (try 15)
- [ ] If it's 0 or very small, increase it

---

### ✅ Step 7: Verify Buoyancy Points

**Expand WindsurfRig in Hierarchy:**

You should see 4 children called BuoyancyPoint_Nose, Tail, Left, Right

**If you DON'T see them:**
1. You skipped that step - go back to the main guide
2. Add 4 empty GameObjects as children
3. Position them at corners of the board

**If you DO see them:**
1. Click WindsurfRig
2. Find BuoyancyBody component
3. Look for "Buoyancy Points" array
4. Should show "Size: 4" with 4 elements filled
5. If empty, drag the 4 point objects into Element 0-3

---

## Still Not Working?

### Check the Console for Errors

1. **Window → General → Console**
2. Look for RED error messages
3. Common errors:

**"No WaterSurface found in scene"**
- Solution: Add WaterSurface script to your water plane

**"NullReferenceException: Object reference not set"**
- Solution: A script reference is missing - check all script fields are filled

**"MissingComponentException"**
- Solution: A required component is missing - add it

---

## Test Again

1. Stop Play mode (press ▶ button again)
2. Fix the issues above
3. Press Play
4. Watch it drop onto the water and float!

**Should see:**
- WindsurfRig falls
- Hits water (Y=0)
- Bobs up and down
- Settles at waterline (half in, half out)

---

## Emergency Simple Test

Want to test if buoyancy works at all?

1. Create a simple cube: Right-click → 3D Object → Cube
2. Add Rigidbody to it
3. Add BuoyancyBody to it
4. Set its Y position to 2
5. Press Play
6. If the CUBE floats, your water works - problem is with WindsurfRig setup
7. If the CUBE falls through, your water setup is broken

---

## Contact Points

If still stuck:
- Check GRAPHICS_UPDATE_GUIDE.md - Step 6 (Water Setup)
- Check ARCHITECTURE.md for component dependencies
- Look at Console errors (they tell you exactly what's wrong!)
