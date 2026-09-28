# 📝 Code Style Guide

Consistent code style makes collaboration easier. Follow these guidelines for our Unity project.

## C# Naming Conventions

### General Rules

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `WindsurfBoard` |
| Methods | PascalCase | `CalculateBuoyancy()` |
| Properties | PascalCase | `WaterHeight` |
| Private Fields | camelCase with _ prefix | `_waterDensity` |
| Public Fields | camelCase | `maxSpeed` |
| Constants | UPPER_SNAKE_CASE | `MAX_WAVE_HEIGHT` |
| Parameters | camelCase | `windSpeed` |
| Local Variables | camelCase | `currentForce` |

### Examples

```csharp
public class BuoyancyBody : MonoBehaviour
{
    // Constants
    private const float WATER_DENSITY = 1025f;
    
    // Serialized fields (shown in Inspector)
    [SerializeField] private float _buoyancyStrength = 1.0f;
    [SerializeField] private Transform[] _buoyancyPoints;
    
    // Private fields
    private Rigidbody _rigidbody;
    private float _submergedVolume;
    
    // Public properties
    public float SubmergedDepth { get; private set; }
    public bool IsFloating => SubmergedDepth < 0;
    
    // Unity lifecycle methods
    private void Awake()
    {
        _rigidbody = GetComponent<Rigidbody>();
    }
    
    private void FixedUpdate()
    {
        ApplyBuoyancyForces();
    }
    
    // Public methods
    public float GetBuoyancyForce()
    {
        return CalculateBuoyancy();
    }
    
    // Private methods
    private float CalculateBuoyancy()
    {
        float force = WATER_DENSITY * _submergedVolume * Physics.gravity.magnitude;
        return force * _buoyancyStrength;
    }
}
```

## File Organization

### Script Structure Order

1. Constants
2. Serialized Fields (Inspector)
3. Private Fields
4. Public Properties
5. Unity Lifecycle Methods (Awake, Start, Update, etc.)
6. Public Methods
7. Private Methods
8. Nested Classes/Structs

### Folder Structure

```
Scripts/
├── Physics/
│   ├── Water/
│   │   ├── WaterSurface.cs
│   │   ├── WaveGenerator.cs
│   │   └── Interfaces/
│   │       └── IWaterHeightProvider.cs
│   ├── Wind/
│   │   ├── WindManager.cs
│   │   └── WindZone.cs
│   └── Buoyancy/
│       ├── BuoyancyBody.cs
│       └── BuoyancyPoint.cs
├── Player/
│   ├── PlayerInput.cs
│   └── WindsurferController.cs
└── Utilities/
    └── MathHelpers.cs
```

## Unity-Specific Guidelines

### SerializeField vs Public

```csharp
// PREFERRED: Private with SerializeField
[SerializeField] private float _speed = 10f;

// AVOID: Public fields (unless intentionally part of API)
public float speed = 10f;
```

### Component References

```csharp
// Get components in Awake, not Start
private void Awake()
{
    _rigidbody = GetComponent<Rigidbody>();
}

// Cache GetComponent results, don't call every frame
// BAD:
void Update()
{
    GetComponent<Rigidbody>().AddForce(force); // Slow!
}

// GOOD:
void Update()
{
    _rigidbody.AddForce(force); // Fast!
}
```

### Null Checks

```csharp
// Use TryGetComponent when component might not exist
if (TryGetComponent<Rigidbody>(out var rb))
{
    rb.AddForce(force);
}

// Use null-conditional for optional references
_audioSource?.Play();
```

## Comments

### When to Comment

```csharp
// Comment complex physics calculations
// Gerstner wave: circular motion creates realistic wave shape
float x = originalX - (steepness * amplitude) * Mathf.Sin(phase);
float y = amplitude * Mathf.Cos(phase);

// Comment magic numbers
private const float PLANING_THRESHOLD = 4.0f; // m/s - speed where board starts planing

// Don't comment obvious code
// BAD: Increment the counter
counter++;
```

### XML Documentation for Public APIs

```csharp
/// <summary>
/// Calculates the water height at the given world position.
/// </summary>
/// <param name="worldPosition">The position to sample.</param>
/// <returns>The height of the water surface in world units.</returns>
public float GetWaterHeight(Vector3 worldPosition)
{
    // Implementation
}
```

## Best Practices

### Avoid Magic Numbers

```csharp
// BAD
float force = velocity * 1025 * 0.5f;

// GOOD
private const float WATER_DENSITY = 1025f;
private const float DRAG_COEFFICIENT = 0.5f;
float force = velocity * WATER_DENSITY * DRAG_COEFFICIENT;
```

### Use Meaningful Names

```csharp
// BAD
float f = m * a;
Vector3 v = new Vector3(x, y, z);

// GOOD
float force = mass * acceleration;
Vector3 windDirection = new Vector3(windX, windY, windZ);
```

### Single Responsibility

Each class should do one thing well:

```csharp
// GOOD: Separate concerns
public class WaterSurface { }      // Manages water mesh
public class WaveGenerator { }      // Calculates wave heights
public class WaterHeightSampler { } // Provides height queries

// BAD: One class doing everything
public class WaterEverything { }    // Too many responsibilities
```

### Use Interfaces for Flexibility

```csharp
public interface IWaterHeightProvider
{
    float GetHeight(Vector3 position);
    Vector3 GetNormal(Vector3 position);
}

// Now buoyancy can work with any water system
public class BuoyancyBody : MonoBehaviour
{
    [SerializeField] private MonoBehaviour _waterProvider;
    private IWaterHeightProvider _water;
    
    private void Awake()
    {
        _water = _waterProvider as IWaterHeightProvider;
    }
}
```

## Version Control

### Commit Messages

```
Format: [Type] Brief description

Types:
- [Feature] New functionality
- [Fix] Bug fixes
- [Refactor] Code restructuring
- [Docs] Documentation updates
- [Physics] Physics system changes

Examples:
[Feature] Add basic wave generation
[Fix] Correct buoyancy force direction
[Physics] Implement Gerstner waves
```

### What to Commit

✅ Commit:
- C# scripts
- Scene files (.unity)
- Prefabs (.prefab)
- Project settings

❌ Don't Commit:
- Library folder
- Temp folder
- .vs folder
- *.csproj files (generated)

---

*Last Updated: December 19, 2025*
