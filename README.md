# 🏄 Windsurfing Simulator

A physics-based 3D windsurfing game built with Unity 6.3 LTS.

## 🎮 Project Overview

This game simulates realistic windsurfing physics including:
- **Water dynamics** - Wave generation, water resistance, and surface interaction
- **Wind simulation** - Variable wind speed, direction, and gusts
- **Buoyancy physics** - Realistic floating behavior and water displacement
- **Sail mechanics** - Wind catching, angle optimization, and power transfer
- **Board physics** - Planing, edging, and hydrodynamic lift

### Design Vision
- **Perspective**: Third-person camera
- **Goal**: Slalom racing with AI opponents
- **Physics**: Realistic simulation at the core
- **Accessibility**: Advanced controls with assists for casual players
- **Multiplayer**: Planned for future development

## 🛠️ Technology Stack

- **Engine**: Unity 6.3 LTS
- **Language**: C#
- **Physics**: Unity Physics / Custom simulation
- **Rendering**: Universal Render Pipeline (URP)

## 📁 Project Structure

```
WindsurfingMMZB/
├── Assets/
│   ├── Scripts/
│   │   ├── Physics/           # Core physics simulation
│   │   │   ├── Water/         # Water and wave systems
│   │   │   ├── Wind/          # Wind simulation
│   │   │   ├── Buoyancy/      # Buoyancy calculations
│   │   │   └── Board/         # Board and sail physics
│   │   ├── Player/            # Player input and control
│   │   ├── Camera/            # Camera systems
│   │   ├── UI/                # User interface
│   │   └── Utilities/         # Helper classes
│   ├── Prefabs/               # Reusable game objects
│   ├── Materials/             # Shaders and materials
│   ├── Models/                # 3D models
│   ├── Textures/              # Texture files
│   ├── Scenes/                # Game scenes
│   └── Audio/                 # Sound effects and music
├── Packages/                  # Unity packages
├── ProjectSettings/           # Unity project settings
└── Documentation/             # Development documentation
```

## 🚀 Getting Started

### Prerequisites
- Unity 6.3 LTS (Unity Hub recommended)
- Visual Studio 2022 or VS Code with C# extension
- Git for version control

### Setup Instructions
1. Clone this repository
2. Open Unity Hub
3. Click "Add" and navigate to the project folder
4. Open the project with Unity 6.3 LTS
5. Open the main scene from `Assets/Scenes/`

## 📋 Development Phases

See [DEVELOPMENT_PLAN.md](Documentation/DEVELOPMENT_PLAN.md) for detailed development phases.

### Phase Overview:
1. **Phase 1**: Project Setup & Basic Scene
2. **Phase 2**: Water System (Waves & Surface)
3. **Phase 3**: Buoyancy Physics
4. **Phase 4**: Wind System
5. **Phase 5**: Board & Sail Mechanics
6. **Phase 6**: Player Controls
7. **Phase 7**: Polish & Effects

## 📖 Documentation

### Getting Started
- [Quick Setup Checklist](Documentation/QUICK_SETUP_CHECKLIST.md) ⭐ **Use this to set up on a new PC**
- [Scene Configuration Guide](Documentation/SCENE_CONFIGURATION.md) 📋 **Complete parameter reference**
- [Component Dependencies](Documentation/COMPONENT_DEPENDENCIES.md) 🔗 **How components connect**
- [Unity Setup Guide](Documentation/UNITY_SETUP_GUIDE.md)

### Development Reference
- [Architecture & Codebase Reference](Documentation/ARCHITECTURE.md) 📚 **Code overview**
- [Development Plan](Documentation/DEVELOPMENT_PLAN.md)
- [Physics Design](Documentation/PHYSICS_DESIGN.md)
- [Code Style Guide](Documentation/CODE_STYLE.md)
- [Progress Log](Documentation/PROGRESS_LOG.md)
- [Test Scene Setup](Documentation/TEST_SCENE_SETUP.md)
- [Physics Validation](Documentation/PHYSICS_VALIDATION.md)

## 🎯 Current Status

**Phase**: Core Physics Complete ✅  
**Last Updated**: December 27, 2025

### ✅ Working Features
- **Upwind sailing** - Can sail ~45° to wind on both tacks
- **Planing** - Board lifts and accelerates at high speeds
- **Tacking** - Sail switches sides correctly
- **Rake steering** - Works on both tacks (bear away/head up)
- **High-speed stability** - No wobble at 20+ knots
- **Beginner controls** - Context-aware A/D steering
- **Advanced controls** - Manual Q/E rake + A/D weight shift

### 🔧 Needs Work
- Sail visuals (boom rotation, mesh deformation)
- Sheet control feedback
- Sound effects
- Environment polish

### Physics Validation
Core physics formulas are **validated and documented** in [PHYSICS_VALIDATION.md](Documentation/PHYSICS_VALIDATION.md).  
⚠️ Do not modify physics sign conventions without reading that document.

### Next Up
- ⏳ Sail visual improvements
- ⏳ Sound effects (wind, water, sail)
- ⏳ Environment (skybox, islands, course markers)
- ⏳ AI opponents
- ⏳ Racing mode

## 📄 License

[To be determined]

## 👥 Contributors

- MMZB Team
