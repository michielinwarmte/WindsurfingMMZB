# 📋 Development Plan - Windsurfing Simulator

This document outlines our step-by-step approach to building the windsurfing game.

## Development Philosophy

We follow an **iterative development** approach:
1. Build small, testable pieces
2. Test each component before moving on
3. Integrate components gradually
4. Refine based on playtesting

---

## 👥 Team Collaboration Guidelines

### Getting Started (New Team Members)

1. **Read the documentation** in this order:
   - [README.md](../README.md) - Project overview
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Codebase structure & dependencies
   - [CODE_STYLE.md](CODE_STYLE.md) - Coding standards
   - [PHYSICS_DESIGN.md](PHYSICS_DESIGN.md) - Physics concepts
   - [PROGRESS_LOG.md](PROGRESS_LOG.md) - What's been done

2. **Set up your environment**:
   - Unity 6.3 LTS (exact version!)
   - Follow [UNITY_SETUP_GUIDE.md](UNITY_SETUP_GUIDE.md)

3. **Understand the architecture**:
   - Scripts use namespaces under `WindsurfingGame.*`
   - Physics simulation is separate from visualization
   - See [ARCHITECTURE.md](ARCHITECTURE.md) for component dependencies

### Git Workflow

```
main
  └── develop
        ├── feature/water-improvements
        ├── feature/ai-opponents
        ├── bugfix/sail-force-calculation
        └── ...
```

1. **Never commit directly to `main` or `develop`**
2. Create feature branches: `feature/your-feature-name`
3. Create bugfix branches: `bugfix/issue-description`
4. Make small, focused commits
5. Create Pull Request when ready for review
6. Get at least one review before merging

### Communication

- **Before starting work**: Check PROGRESS_LOG.md for current status
- **After each session**: Update PROGRESS_LOG.md with your changes
- **For major decisions**: Document in PROGRESS_LOG.md with reasoning
- **For physics changes**: Update PHYSICS_DESIGN.md

### File Ownership

To avoid conflicts, coordinate on these areas:

| Area | Primary Files | Notes |
|------|--------------|-------|
| Water Physics | `Physics/Water/*` | Wave systems, water queries |
| Wind Physics | `Physics/Wind/*` | Wind simulation |
| Board Physics | `Physics/Board/*` | Sail, fin, drag |
| Controls | `Player/*` | Input handling |
| UI | `UI/*` | HUD, indicators |
| Visuals | `Visual/*` | 3D representations |

### Unity-Specific Guidelines

- **Don't commit Library/ folder** (it's gitignored)
- **Scene changes**: Coordinate - only one person edits a scene at a time
- **Prefab changes**: Communicate before modifying shared prefabs
- **Meta files**: Always commit .meta files with their assets

---

## 🎯 Phase 1: Project Setup & Basic Scene (Week 1)

### Goals
- [x] Create project documentation structure
- [ ] Create Unity project with proper settings
- [ ] Set up Universal Render Pipeline (URP)
- [ ] Create basic test scene with placeholder objects
- [ ] Set up version control (.gitignore)

### Deliverables
- Unity project configured for 3D physics game
- Basic scene with ground/water plane
- Simple camera setup
- Placeholder board object

### Learning Topics
- Unity Editor basics
- GameObjects, Components, and Transforms
- Unity's coordinate system
- Scene hierarchy

---

## 🌊 Phase 2: Water System (Week 2-3)

### Goals
- [ ] Create water surface mesh
- [ ] Implement basic wave generation (sine waves)
- [ ] Create water shader with URP
- [ ] Add wave height sampling system

### Technical Approach
1. **Simple Start**: Flat plane with wave shader
2. **Wave Math**: Gerstner waves for realistic motion
3. **Height Query**: System to get water height at any point

### Key Scripts
- `WaterSurface.cs` - Main water controller
- `WaveGenerator.cs` - Wave calculation
- `WaterHeightSampler.cs` - Query water height at position

### Learning Topics
- Shader basics in Unity URP
- Mesh manipulation
- Sine wave mathematics
- Gerstner wave theory

---

## ⚓ Phase 3: Buoyancy Physics (Week 4-5)

### Goals
- [ ] Create buoyancy force calculation
- [ ] Implement multi-point buoyancy (for stability)
- [ ] Add water drag and resistance
- [ ] Test with simple floating objects

### Technical Approach
1. **Archimedes' Principle**: Upward force = weight of displaced water
2. **Multi-Point Sampling**: Check buoyancy at multiple points on hull
3. **Damping**: Add realistic water resistance

### Key Scripts
- `BuoyancyBody.cs` - Main buoyancy component
- `BuoyancyPoint.cs` - Individual sample point
- `WaterDrag.cs` - Water resistance calculation

### Physics Concepts
```
Buoyancy Force = ρ × V × g
Where:
  ρ = water density (1000 kg/m³)
  V = submerged volume
  g = gravity (9.81 m/s²)
```

---

## 💨 Phase 4: Wind System (Week 6-7)

### Goals
- [ ] Create wind zone/field system
- [ ] Implement wind direction and speed
- [ ] Add wind gusts and variation
- [ ] Visualize wind with particles

### Technical Approach
1. **Global Wind**: Base wind direction and speed
2. **Wind Zones**: Local variations (near land, obstacles)
3. **Turbulence**: Random variations for realism
4. **Visual Feedback**: Particles, flags, water ripples

### Key Scripts
- `WindManager.cs` - Global wind control
- `WindZone.cs` - Local wind modification
- `WindVisualizer.cs` - Debug/display wind

---

## 🏄 Phase 5: Board & Sail Mechanics (Week 8-10)

### Goals
- [ ] Create windsurf board physics model
- [ ] Implement sail force calculation
- [ ] Add board planing behavior
- [ ] Create fin and rail physics

### Technical Approach

#### Sail Forces
```
Lift Force = 0.5 × ρ × V² × A × Cl
Drag Force = 0.5 × ρ × V² × A × Cd

Where:
  ρ = air density
  V = apparent wind speed
  A = sail area
  Cl/Cd = lift/drag coefficients (angle dependent)
```

#### Board States
1. **Displacement Mode**: Low speed, hull in water
2. **Planing Mode**: High speed, board rides on surface
3. **Transition**: Speed-dependent switch between modes

### Key Scripts
- `WindsurfBoard.cs` - Main board controller
- `Sail.cs` - Sail physics and forces
- `ApparentWind.cs` - Calculate apparent wind
- `BoardHydrodynamics.cs` - Water interaction

---

## 🎮 Phase 6: Player Controls (Week 11-12)

### Goals
- [ ] Implement player input system
- [ ] Create sail sheeting controls
- [ ] Add board steering/edging
- [ ] Balance controls for fun vs realism

### Control Scheme (Initial)
| Input | Action |
|-------|--------|
| W/S | Sheet in/out (sail angle) |
| A/D | Edge board left/right |
| Mouse | Look around |
| Shift | Pump (for acceleration) |

### Key Scripts
- `PlayerInput.cs` - Input handling
- `WindsurferController.cs` - Apply controls to physics

---

## ✨ Phase 7: Polish & Effects (Week 13+)

### Goals
- [ ] Add spray and splash effects
- [ ] Improve water visuals
- [ ] Add sound effects
- [ ] Create UI (speed, wind indicator)
- [ ] Add environment (islands, buoys)

---

## 🔄 Development Iterations

After each phase, we will:
1. **Test** - Does it work as expected?
2. **Evaluate** - Is it fun? Does it feel right?
3. **Adjust** - Tweak parameters, fix issues
4. **Document** - Update progress log

---

## 📊 Complexity Management

We start simple and add complexity:

| Feature | Simple | Medium | Complex |
|---------|--------|--------|---------|
| Water | Flat plane | Sine waves | Gerstner + FFT |
| Wind | Constant | Variable + gusts | Full simulation |
| Buoyancy | Single point | Multi-point | Volume-based |
| Sail | Basic force | Lift/drag model | Full aero |

---

## ✅ Design Decisions

These decisions guide our development:

1. **Realism vs Fun**: Realistic physics is essential. Advanced controls for experienced players, with assists for casual/new players. Start simple, add complexity.
2. **Camera**: Third-person perspective
3. **Game Mode**: Start with free roam → End goal is slalom racing with AI opponents
4. **Environment**: Start with 1 km² open water for testing fundamentals. Environment details decided later.
5. **Multiplayer**: Single-player first, multiplayer planned for later

---

*Last Updated: December 19, 2025*
