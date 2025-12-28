# 🤝 Contributing to Windsurfing Simulator

Welcome to the team! This guide will help you get started and contribute effectively.

---

## ⚠️ IMPORTANT: Read First!

**Before doing anything else, read [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md)!**

There are 3 critical bugs that need fixing:
1. 🔴 **Camera initialization** - Workaround: change FOV in Inspector during Play
2. 🔴 **Planing oscillation** - Board bounces 0-100% submersion at speed
3. 🔴 **Inverted steering** - A/D keys work backwards

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/[your-org]/WindsurfingMMZB.git
cd WindsurfingMMZB
```

### 2. Open in Unity
- Open Unity Hub
- Click "Add" → Navigate to `WindsurfingMMZB/WindsurfingGame`
- Open with **Unity 6.3 LTS** (exact version required!)

### 3. Create a Test Scene
- Menu: `Windsurfing → Complete Windsurfer Setup Wizard`
- Assign your Board and Sail FBX models
- Click "🌟 Create Complete Scene"
- Press Play

### 4. Camera Workaround
⚠️ **Camera won't follow until you do this:**
1. With game running, select "Main Camera" in Hierarchy
2. In Inspector, change FOV from 60 to 61 (or any value)
3. Camera starts working

### 5. Read the Documentation
**Required reading** (in order):
1. [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) - **Current bugs**
2. [README.md](README.md) - Project overview
3. [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) - Codebase structure
4. [PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) - Current status

---

## 🎯 Priority Fixes Needed

If you're continuing development, these are the top priorities:

### 1. Camera Initialization Bug
**File:** `Assets/Scripts/Camera/SimpleFollowCamera.cs`

The camera doesn't activate until FOV is changed. Likely issue in `Start()` or `OnEnable()`.

### 2. Planing Stability
**Files:** 
- `Assets/Scripts/Physics/Board/AdvancedHullDrag.cs`
- `Assets/Scripts/Physics/Buoyancy/AdvancedBuoyancy.cs`

Board oscillates between 0-100% submersion when planing. Need to add:
- Smoothing/hysteresis to lift calculations
- Possibly a PID controller for height stability
- Separate equilibrium targets for displacement vs planing

### 3. Inverted Steering
**Files:**
- `Assets/Scripts/Player/AdvancedWindsurferController.cs`
- `Assets/Scripts/Physics/Board/AdvancedSail.cs`

Check the steering input sign or rake steering torque direction.

---

## 📝 Before You Start Working

1. **Check the Progress Log** - See what's currently being worked on
2. **Communicate** - Let the team know what you're working on
3. **Create a branch** - Never work directly on `main` or `develop`

---

## 🌿 Git Workflow

### Branch Naming
```
feature/description    → New features
bugfix/description     → Bug fixes
refactor/description   → Code refactoring
docs/description       → Documentation only
```

### Example Workflow
```bash
# Update your local develop branch
git checkout develop
git pull origin develop

# Create a feature branch
git checkout -b feature/improved-wave-physics

# Make your changes...
# Commit often with clear messages
git add .
git commit -m "Add Gerstner wave implementation"

# Push and create PR
git push origin feature/improved-wave-physics
```

### Commit Message Format
```
<type>: <short description>

[optional longer description]
```

**Types**: `feat`, `fix`, `refactor`, `docs`, `style`, `test`

**Examples**:
- `feat: Add planing mode detection to board`
- `fix: Correct sail force calculation at low wind`
- `docs: Update PHYSICS_DESIGN with planing formulas`

---

## 📁 File Organization

### Adding New Scripts

1. **Choose the right folder**:
   ```
   Physics/Water/    → Water/wave related
   Physics/Wind/     → Wind simulation
   Physics/Buoyancy/ → Buoyancy/floating
   Physics/Board/    → Sail, fin, drag, board behavior
   Player/           → Input, controls
   UI/               → HUD, 2D interfaces
   Visual/           → 3D visualizations
   Utilities/        → Helpers, debug tools
   Camera/           → Camera systems
   ```

2. **Use correct namespace**:
   ```csharp
   namespace WindsurfingGame.Physics.Board
   {
       public class MyNewScript : MonoBehaviour
       {
           // ...
       }
   }
   ```

3. **Add XML documentation**:
   ```csharp
   /// <summary>
   /// Brief description of what this component does.
   /// </summary>
   public class MyNewScript : MonoBehaviour
   ```

---

## ⚠️ Important Rules

### DO ✅
- Read [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) before starting
- Follow the [CODE_STYLE.md](Documentation/CODE_STYLE.md) guidelines
- Write XML documentation comments
- Update PROGRESS_LOG.md after each session
- Test your changes in the TestScene
- Commit .meta files with their assets
- **Read [PHYSICS_VALIDATION.md](Documentation/PHYSICS_VALIDATION.md) before changing physics**
- Move fixed issues to "Recently Fixed" in KNOWN_ISSUES.md

### DON'T ❌
- Commit the `Library/` folder (it's gitignored)
- Edit scenes without coordinating with the team
- Calculate physics values in visualization scripts
- Use magic numbers (use constants in PhysicsHelpers)
- Push directly to `main` or `develop`
- **Change physics sign conventions without understanding the full chain**

---

## 🎯 CRITICAL: Physics Sign Conventions

The physics formulas are **interconnected**. Changing one without updating others will break the simulation.

**Before modifying ANY of these files:**
- `SailingState.cs` (AWA calculation)
- `AdvancedSail.cs` (sailSide, sail geometry)
- `Aerodynamics.cs` (lift direction)

**You MUST read:** [PHYSICS_VALIDATION.md](Documentation/PHYSICS_VALIDATION.md)

**Key formulas that work together:**
```
AWA = SignedAngle(forward, -apparentWind, up)
sailSide = -Sign(AWA)
liftDir = project(-sailNormal) onto wind-perpendicular
```

Changing ANY of these independently will break upwind sailing, tacking, or steering!

---

## 🔧 Development Principles

### Simulation vs Visualization
```
CORRECT:
  Sail.cs (simulation) → calculates sail angle
  SailVisualizer.cs    → READS sail angle from Sail.cs

WRONG:
  SailVisualizer.cs    → calculates its own sail angle
```

**Visualization scripts must READ from simulation, never calculate physics independently.**

### Component Dependencies
- Use `[RequireComponent]` to enforce dependencies
- Find scene singletons in `Start()` not `Awake()`
- Use interfaces (`IWaterSurface`, `IWindProvider`) for flexibility

### Physics Updates
- Physics in `FixedUpdate()` (consistent timestep)
- Visuals in `Update()` (smooth rendering)
- Use `ForceMode.Force` for continuous forces
- Use `ForceMode.Impulse` for instant changes

---

## 🧪 Testing Your Changes

1. **Open TestScene** in Unity
2. **Check Console** for errors/warnings
3. **Enable Gizmos** in Scene view to see debug visualization
4. **Watch TelemetryHUD** for runtime values
5. **Test edge cases**:
   - No wind
   - Very high wind
   - Board at extreme angles
   - Board underwater

---

## 📚 Updating Documentation

When you make changes, update:

| Change Type | Update These Docs |
|-------------|-------------------|
| Bug fix | KNOWN_ISSUES.md (move to "Fixed"), PROGRESS_LOG.md |
| New script | ARCHITECTURE.md, PROGRESS_LOG.md |
| Physics change | PHYSICS_DESIGN.md, PROGRESS_LOG.md |
| New feature | PROGRESS_LOG.md, README.md (if major) |
| API change | ARCHITECTURE.md |

### Progress Log Format
```markdown
## [Date] - Session [N]

### Session: [Brief Topic]

**What we did:**
- ✅ Item 1
- ✅ Item 2

**Problems encountered:**
- Issue and solution

**Decisions made:**
- Decision and reasoning

**Next steps:**
- [ ] Task 1
- [ ] Task 2
```

---

## 🔧 Windsurfer Setup Wizard

The wizard creates everything you need from an empty scene:

**Menu:** `Windsurfing → Complete Windsurfer Setup Wizard`

### What it creates:
- **WaterSurface** (100m x 100m water plane)
- **WindSystem** (configurable wind speed/direction)
- **Camera** with SimpleFollowCamera
- **Lighting**
- **Windsurfer** with all physics components:
  - Rigidbody
  - BoxCollider
  - AdvancedBuoyancy
  - AdvancedHullDrag
  - AdvancedSail
  - AdvancedFin
  - AdvancedWindsurferController
  - BoardMassConfiguration
- **TelemetryHUD** (press F1 to toggle)

### Wizard Tips:
- Expand "Camera Settings" to configure distance/pitch
- Expand "Scene Settings" to configure wind
- Use "Validate All Components" to check references
- The wizard auto-finds missing references when possible

---

## 🧪 Testing Your Changes

1. **Open TestScene** in Unity
2. **Apply camera workaround** (change FOV in Inspector)
3. **Check Console** for errors/warnings
4. **Enable Gizmos** in Scene view to see debug visualization
5. **Watch TelemetryHUD** (F1) for runtime values
6. **Test edge cases**:
   - No wind
   - Very high wind
   - Board at extreme angles
   - Board underwater
   - Both tacks (port and starboard wind)
   - Upwind and downwind sailing

---

## ❓ Questions?

- Check the documentation first
- Look at [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) for current bugs
- Look at existing code for patterns
- Check the [PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) for history
- Document the answer for others!

---

## 📋 Handoff Checklist

When you finish working on this project:

1. ✅ Update [PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) with your session
2. ✅ Move any fixed issues to "Recently Fixed" in [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md)
3. ✅ Add any new issues you discovered to [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md)
4. ✅ Update the "Last Updated" dates in docs
5. ✅ Commit all changes with clear messages
6. ✅ Push to your branch and create PR (or push to develop)

---

*Last Updated: December 28, 2025*
