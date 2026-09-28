> [!IMPORTANT]
> **This is the frozen Unity version, kept for reference only.**
> In September 2026 (Session 28) the team restarted the game from scratch in Godot 4.7. Active development is in [`../Game`](../Game), and the plan is [`../Documentation/REBUILD_PLAN.md`](../Documentation/REBUILD_PLAN.md).
>
> Nothing in `Legacy/` is maintained. It is useful for:
> - **Physics:** the force models and tuning values in `WindsurfingGame/Assets/Scripts/Physics/` and the write-ups in `Documentation/PHYSICS_DESIGN.md` and `Documentation/PHYSICS_VALIDATION.md`.
> - **Lessons learned:** `Documentation/KNOWN_ISSUES.md` and `Documentation/PROGRESS_LOG.md` (what broke and why).
> - **Session 27 ideas** (ocean shader, Gerstner waves, sail cloth, spray, procedural audio). Careful: that code was never compiled or played.
>
> Known problem in these docs: some sign-convention tables disagree with the code. In `PHYSICS_VALIDATION.md` the apparent-wind-angle and sail-side tables have port and starboard swapped (the code, and its comments, use positive AWA = wind from starboard), and the testing checklist says "rake back = bear away" where the code correctly does rake back = head up. Where they disagree, the code is right.
>
> The text below is the README as it was on the last Unity commit.

# 🏄 Windsurfing Simulator

A realistic physics-based 3D windsurfing game built with Unity 6.3 LTS.

![Unity](https://img.shields.io/badge/Unity-6.3%20LTS-black?logo=unity)
![C#](https://img.shields.io/badge/C%23-10.0-blue?logo=csharp)
![URP](https://img.shields.io/badge/Render-URP-green)
![Status](https://img.shields.io/badge/Status-Core%20Physics%20Complete-brightgreen)

---

## 🎮 About This Project

This is a **physics-first** windsurfing simulator that accurately models the forces involved in sailing. The core physics engine is complete and validated against real windsurfing polar diagrams.

### What Makes This Special
- **Real Aerodynamics** - Lift/drag coefficients, angle of attack, apparent wind calculations
- **Savitsky Planing** - Proper hydrodynamic lift equations for high-speed planing
- **Archimedes Buoyancy** - 21-point hull sampling with volume displacement
- **Realistic Controls** - Mast rake steering, weight shift, and sheet control like real windsurfing

---

## 📊 Current Status

| Category | Status |
|----------|--------|
| Core Physics | ✅ Complete & Validated |
| Player Controls | ✅ Working |
| Camera System | ✅ Working |
| Visuals | 🧪 Ocean shader with waves, sail cloth deformation, spray and wake (Session 27, verify in Play mode) |
| Audio | 🧪 Procedural wind, water and sail sounds (Session 27, verify in Play mode) |
| Environment | 🧪 Procedural sky, fog and distant islands (Session 27, verify in Play mode) |

> **Session 27 note:** the visual and audio polish was written without a Unity install available, so it has not yet been compiled or played. Open the project, fix any compile errors, and run through the checklist in [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) before relying on it.

### ✅ Working Features
- Upwind sailing at ~45° to wind on both tacks
- Automatic planing at ~17+ km/h with lift transition
- Tacking and gybing with sail side switching
- Rake steering (bear away/head up) on both tacks
- Port/starboard steering auto-inversion
- High-speed stability (20+ knots, no porpoising)
- Beginner mode with context-aware steering
- Advanced mode with full manual control
- Real-time telemetry HUD (F1)

### 🧪 Added in Session 27 (needs Play-mode verification)
- Gerstner waves shared by physics and rendering (the board floats on exactly what you see)
- Ocean shader: depth-based colour, refraction, sky reflection, sun glints, foam at the hull, wave crests and wind streaks
- Sail cloth deformation: belly follows sail force, leech twist, flutter when luffing
- Spray from the rails, foam wake behind the tail, splash on landing
- Procedural sky, horizon fog and distant islands (with colliders)
- Procedural audio: wind ambience, water lapping, planing hiss, splashes, sail flapping

---

## 🎯 Roadmap: Next Steps

### Phase 1: Fix Remaining Issues
| Issue | Status | Notes |
|-------|--------|-------|
| Camera initialization delay | ✅ Believed fixed (Session 26) | Conflicting ThirdPersonCamera is disabled; verify no delay remains |
| Beam reach submersion | 🟡 Open | Needs in-editor physics tuning; see [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) |

### Phase 2: Visual Polish 🎨
| Feature | Description | Status |
|---------|-------------|--------|
| **Water Shader** | Realistic ocean with foam, waves, reflections | 🧪 Done in Session 27 (`OceanWater.shader`, `WaterMeshBuilder`, Gerstner waves) |
| **Sail Deformation** | Procedural cloth shape driven by sail physics | 🧪 Done in Session 27 (`SailDeformer`) |
| **Wake/Spray Effects** | Particle systems for board wake and spray | 🧪 Done in Session 27 (`BoardWakeEffects`) |
| **Boom Rotation** | Visual feedback for sheet position | 🧪 Boom rotates with the sail model; procedural mast added. Verify in Play mode |
| **Sailor Animation** | Rigged character with stance changes | 🟢 Open, needs a rigged character asset |
| **Environment** | Skybox, horizon, distant islands | 🧪 Done in Session 27 (`SkyEnvironment`, `DistantIslands`) |

### Phase 3: Audio 🔊
| Feature | Description | Status |
|---------|-------------|--------|
| Wind ambience | Volume/pitch based on apparent wind | 🧪 Done in Session 27 (`WindAmbienceAudio`) |
| Water splash | Impact-driven splash sounds | 🧪 Done in Session 27 (`HullWaterAudio`) |
| Sail flapping | When sail is eased or luffing, and on tacks | 🧪 Done in Session 27 (`SailFlapAudio`) |
| Hull noise | Planing hiss vs displacement lapping | 🧪 Done in Session 27 (`HullWaterAudio`) |

All audio is generated at runtime from filtered noise (`ProceduralAudioClips`), so no sound files are needed. Replace clips with recordings later by swapping the `AudioClip` assignments.

### Phase 4: Gameplay
| Feature | Description |
|---------|-------------|
| Race course | Buoy markers and course layout |
| Timer system | Lap timing and splits |
| AI opponents | Computer-controlled racers |
| Multiplayer | Network racing support |

---

## 🕹️ Controls

| Key | Action |
|-----|--------|
| **W/S** | Sheet in/out (sail power) |
| **A/D** | Steer left/right |
| **Q/E** | Fine mast rake adjustment |
| **Space** | Switch tack (flip sail) |
| **F1** | Toggle telemetry HUD |
| **1-4** | Camera modes (Follow/Orbit/Top/Free) |

### Control Philosophy
Like real windsurfing, steering is primarily done through **mast rake** (tilting the sail forward/back). The A/D keys provide intuitive left/right steering that auto-inverts on port tack for consistent feel.

---

## 🚀 Quick Start

### Prerequisites
- **Unity 6.3 LTS** (via Unity Hub)
- **Visual Studio 2022** or VS Code with C# extension
- **Git** for version control

### Setup
```bash
git clone https://github.com/michielinwarmte/WindsurfingMMZB.git
```

1. Open **Unity Hub** → Add → Select `WindsurfingGame` folder
2. Open with **Unity 6.3 LTS**
3. Open `Assets/Scenes/MainScene.unity`
4. **Press Play** and enjoy!

### Using the Setup Wizard
Menu: `Windsurfing → Complete Windsurfer Setup Wizard`

This automatically creates a fully configured scene with:
- Water surface with Gerstner waves, ocean shader and a 3 km follow mesh
- Wind system with gusts
- Complete windsurfer with all physics components, sail cloth, spray and audio
- Procedural sky, fog and distant islands
- Camera and HUD

Already have a scene? Menu: `Windsurfing → Upgrade Scene: Add Visual and Audio Polish` adds only the missing pieces.

---

## 🏗️ Architecture

### Physics Stack (Advanced - Recommended)
```
AdvancedWindsurferController  ← Player input
        ↓
AdvancedSail                  ← Aerodynamic lift/drag
AdvancedFin                   ← Hydrodynamic lateral force
AdvancedHullDrag              ← Resistance + planing lift
AdvancedBuoyancy              ← Archimedes flotation
BoardMassConfiguration        ← Mass and COM shifts
        ↓
Rigidbody                     ← Unity physics integration
```

### Key Scripts (46 total)
| Category | Key Scripts |
|----------|-------------|
| Physics Core | `PhysicsConstants`, `Aerodynamics`, `Hydrodynamics`, `SailingState` |
| Board Physics | `AdvancedSail`, `AdvancedFin`, `AdvancedHullDrag`, `AdvancedBuoyancy` |
| Water | `WaterSurface`, `GerstnerWave` (shared CPU/GPU wave maths) |
| Player | `AdvancedWindsurferController` |
| Camera | `SimpleFollowCamera` |
| UI | `AdvancedTelemetryHUD`, `SailPositionIndicator` |
| Environment | `WindSystem`, `SkyEnvironment`, `DistantIslands` |
| Visual polish | `WaterMeshBuilder`, `SailDeformer`, `BoardWakeEffects`, `EquipmentVisualizer` |
| Audio | `ProceduralAudioClips`, `WindAmbienceAudio`, `HullWaterAudio`, `SailFlapAudio` |
| Shaders | `OceanWater.shader`, `VertexColorTerrain.shader` |

See [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for complete reference.

---

## 📖 Documentation

### Essential Reading
| Document | Description |
|----------|-------------|
| [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) | ⚠️ Current bugs and workarounds |
| [QUICK_SETUP_CHECKLIST.md](Documentation/QUICK_SETUP_CHECKLIST.md) | ⭐ Fast setup guide |
| [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) | 📚 Code structure reference |
| [PHYSICS_VALIDATION.md](Documentation/PHYSICS_VALIDATION.md) | 🔬 Physics formulas (DO NOT CHANGE) |

### Additional Docs
- [SCENE_CONFIGURATION.md](Documentation/SCENE_CONFIGURATION.md) - Parameter reference
- [COMPONENT_DEPENDENCIES.md](Documentation/COMPONENT_DEPENDENCIES.md) - How components connect
- [PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) - Development history
- [PHYSICS_DESIGN.md](Documentation/PHYSICS_DESIGN.md) - Physics equations

---

## 🔬 Physics Validation

The physics engine has been validated against real windsurfing data:

| Metric | Expected | Actual |
|--------|----------|--------|
| Upwind angle | ~45° | ✅ ~45° |
| Planing onset | 15-17 km/h | ✅ ~17 km/h |
| Max speed (15kt wind) | 25-30 km/h | ✅ ~28 km/h |
| Beam reach speed | Fastest point | ✅ Confirmed |

**⚠️ Important:** Do not modify physics sign conventions without reading [PHYSICS_VALIDATION.md](Documentation/PHYSICS_VALIDATION.md).

---

## 🤝 Contributing

We welcome contributions! Priority areas:

1. **Visual Polish** - Water shaders, particle effects, environment
2. **Audio System** - Wind, water, and sailing sounds
3. **Gameplay Features** - Race system, course markers
4. **Bug Fixes** - See [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md)

### Getting Started as a Contributor
1. Read [KNOWN_ISSUES.md](Documentation/KNOWN_ISSUES.md) for current state
2. Check [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for code structure
3. Use the **Advanced** physics components (not legacy)
4. Test with telemetry HUD enabled (F1)

---

## 📁 Project Structure

```
WindsurfingMMZB/
├── Documentation/           # Development docs
├── WindsurfingGame/         # Unity project
│   ├── Assets/
│   │   ├── Scripts/
│   │   │   ├── Physics/     # Core simulation
│   │   │   ├── Player/      # Controls
│   │   │   ├── Camera/      # Camera system
│   │   │   ├── UI/          # HUD elements
│   │   │   ├── Visual/      # Visualizers, water mesh, sail cloth, spray
│   │   │   ├── Environment/ # Wind system, sky, islands
│   │   │   ├── Audio/       # Procedural sound
│   │   │   ├── Debug/       # Debug tools
│   │   │   └── Editor/      # Setup wizard
│   │   ├── Scenes/          # Game scenes
│   │   ├── Materials/       # WaterMaterial, IslandTerrain
│   │   ├── Models/          # 3D models
│   │   └── Shaders/         # OceanWater, VertexColorTerrain
│   └── Packages/            # Dependencies
└── README.md
```

---

## 📄 License

[MIT License](LICENSE) - Free to use and modify.

---

## 👥 Team

**MMZB Development Team**

*Last Updated: September 28, 2026 (Session 27)*
