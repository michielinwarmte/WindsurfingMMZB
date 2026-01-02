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
| Visuals | 🔨 Basic (needs polish) |
| Audio | ❌ Not implemented |
| Environment | 🔨 Basic water shader |

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

---

## 🎯 Roadmap: Next Steps

### Phase 1: Fix Remaining Issues
| Issue | Priority | Estimated Effort |
|-------|----------|------------------|
| Camera initialization delay | 🟡 Medium | 2-4 hours |
| Beam reach submersion | 🟡 Medium | 4-8 hours |

### Phase 2: Visual Polish 🎨
| Feature | Description | Priority |
|---------|-------------|----------|
| **Water Shader** | Realistic ocean with foam, waves, reflections | 🔴 High |
| **Sail Deformation** | Cloth simulation or blend shapes for sail shape | 🔴 High |
| **Wake/Spray Effects** | Particle systems for board wake and spray | 🟡 Medium |
| **Boom Rotation** | Visual feedback for sheet position | 🟡 Medium |
| **Sailor Animation** | Rigged character with stance changes | 🟢 Nice to have |
| **Environment** | Skybox, horizon, distant islands | 🟢 Nice to have |

### Phase 3: Audio 🔊
| Feature | Description |
|---------|-------------|
| Wind ambience | Volume/pitch based on wind speed |
| Water splash | Speed-dependent splash sounds |
| Sail flapping | When sail is eased or luffing |
| Hull noise | Planing vs displacement sound |

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
- Water surface with shader
- Wind system with gusts
- Complete windsurfer with all physics components
- Camera and HUD

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

### Key Scripts (35 total)
| Category | Key Scripts |
|----------|-------------|
| Physics Core | `PhysicsConstants`, `Aerodynamics`, `Hydrodynamics`, `SailingState` |
| Board Physics | `AdvancedSail`, `AdvancedFin`, `AdvancedHullDrag`, `AdvancedBuoyancy` |
| Player | `AdvancedWindsurferController` |
| Camera | `SimpleFollowCamera` |
| UI | `AdvancedTelemetryHUD`, `SailPositionIndicator` |
| Environment | `WindSystem`, `WaterSurface` |

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
│   │   │   ├── Visual/      # Visualizers
│   │   │   ├── Environment/ # Wind system
│   │   │   ├── Debug/       # Debug tools
│   │   │   └── Editor/      # Setup wizard
│   │   ├── Scenes/          # Game scenes
│   │   ├── Materials/       # Shaders
│   │   ├── Models/          # 3D models
│   │   └── Shaders/         # Custom shaders
│   └── Packages/            # Dependencies
└── README.md
```

---

## 📄 License

[MIT License](LICENSE) - Free to use and modify.

---

## 👥 Team

**MMZB Development Team**

*Last Updated: January 2, 2026*
