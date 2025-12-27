using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Water;

namespace WindsurfingGame.Physics.Buoyancy
{
    /// <summary>
    /// Advanced multi-point buoyancy system for realistic flotation physics.
    /// 
    /// Uses multiple sample points distributed across the hull to calculate:
    /// - Buoyancy force at each point based on submersion depth
    /// - Resulting pitch and roll moments from uneven submersion
    /// - Damping forces to reduce oscillation
    /// 
    /// This creates realistic bobbing, tilting, and response to waves.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedBuoyancy : MonoBehaviour
    {
        [Header("Water Reference")]
        [SerializeField] private WaterSurface _waterSurface;
        
        [Header("Buoyancy Configuration")]
        [Tooltip("Total displaced volume at rest (liters)")]
        [SerializeField] private float _displacedVolume = 120f;
        
        [Tooltip("Target floating height above water (meters)")]
        [SerializeField] private float _floatHeight = 0.05f;
        
        [Header("Buoyancy Points")]
        [Tooltip("Use automatically generated points based on collider bounds")]
        [SerializeField] private bool _autoGeneratePoints = true;
        
        [Tooltip("Number of points along length (X)")]
        [SerializeField] private int _pointsAlongLength = 5;
        
        [Tooltip("Number of points along width (Y)")]  
        [SerializeField] private int _pointsAlongWidth = 3;
        
        [Tooltip("Custom buoyancy sample points (local space)")]
        [SerializeField] private Vector3[] _customPoints;
        
        [Header("Damping")]
        [Tooltip("Linear damping when in water")]
        [SerializeField] private float _waterDamping = 50f;
        
        [Tooltip("Angular damping when in water")]
        [SerializeField] private float _angularDamping = 20f;
        
        [Tooltip("Velocity threshold for damping (reduces damping at low speed for stability)")]
        [SerializeField] private float _dampingVelocityThreshold = 0.5f;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        [SerializeField] private bool _showBuoyancyPoints = true;
        
        // Components
        private Rigidbody _rigidbody;
        
        // Buoyancy calculation
        private Vector3[] _samplePoints;
        private float[] _pointDepths;
        private Vector3[] _pointForces;
        
        // State
        private float _submergedRatio;
        private Vector3 _totalBuoyancyForce;
        private Vector3 _averageSubmergedPoint;
        private bool _isFloating;
        private float _waterLevel;
        
        // Public accessors
        public bool IsFloating => _isFloating;
        public float SubmergedRatio => _submergedRatio;
        public float WaterLevel => _waterLevel;
        public Vector3 TotalBuoyancyForce => _totalBuoyancyForce;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            InitializeBuoyancyPoints();
        }
        
        private void Start()
        {
            if (_waterSurface == null)
            {
                _waterSurface = FindFirstObjectByType<WaterSurface>();
                if (_waterSurface == null)
                {
                    Debug.LogError($"AdvancedBuoyancy on {gameObject.name}: No WaterSurface found!");
                    enabled = false;
                    return;
                }
            }
        }
        
        /// <summary>
        /// Initialize buoyancy sample points.
        /// </summary>
        private void InitializeBuoyancyPoints()
        {
            if (_autoGeneratePoints)
            {
                GeneratePointsFromBounds();
            }
            else if (_customPoints != null && _customPoints.Length > 0)
            {
                _samplePoints = _customPoints;
            }
            else
            {
                // Default: single point at center
                _samplePoints = new Vector3[] { Vector3.zero };
            }
            
            _pointDepths = new float[_samplePoints.Length];
            _pointForces = new Vector3[_samplePoints.Length];
        }
        
        /// <summary>
        /// Generate sample points based on collider bounds.
        /// </summary>
        private void GeneratePointsFromBounds()
        {
            Bounds bounds;
            
            Collider col = GetComponent<Collider>();
            if (col != null)
            {
                // Get local bounds
                bounds = col.bounds;
                bounds.center = transform.InverseTransformPoint(bounds.center);
                bounds.size = new Vector3(
                    bounds.size.x / transform.lossyScale.x,
                    bounds.size.y / transform.lossyScale.y,
                    bounds.size.z / transform.lossyScale.z
                );
            }
            else
            {
                // Default bounds
                bounds = new Bounds(Vector3.zero, new Vector3(0.6f, 0.1f, 2.5f));
            }
            
            // Generate grid of points on bottom of hull
            int totalPoints = _pointsAlongLength * _pointsAlongWidth;
            _samplePoints = new Vector3[totalPoints];
            
            float halfWidth = bounds.extents.x * 0.8f;
            float halfLength = bounds.extents.z * 0.9f;
            float bottom = bounds.min.y;
            
            int index = 0;
            for (int i = 0; i < _pointsAlongLength; i++)
            {
                float z = Mathf.Lerp(-halfLength, halfLength, (float)i / (_pointsAlongLength - 1));
                
                for (int j = 0; j < _pointsAlongWidth; j++)
                {
                    float x = Mathf.Lerp(-halfWidth, halfWidth, (float)j / (_pointsAlongWidth - 1));
                    
                    _samplePoints[index] = new Vector3(x, bottom, z);
                    index++;
                }
            }
        }
        
        private void FixedUpdate()
        {
            if (_waterSurface == null) return;
            
            CalculateBuoyancy();
            ApplyBuoyancyForces();
            ApplyDamping();
        }
        
        /// <summary>
        /// Calculate buoyancy forces at each sample point.
        /// </summary>
        private void CalculateBuoyancy()
        {
            _totalBuoyancyForce = Vector3.zero;
            _averageSubmergedPoint = Vector3.zero;
            int submergedCount = 0;
            
            // Force per point (assuming equal distribution)
            float displacementForce = _displacedVolume * 0.001f * PhysicsConstants.WATER_DENSITY * PhysicsConstants.GRAVITY;
            float forcePerPoint = displacementForce / _samplePoints.Length;
            
            for (int i = 0; i < _samplePoints.Length; i++)
            {
                // Transform point to world space
                Vector3 worldPoint = transform.TransformPoint(_samplePoints[i]);
                
                // Get water height at this point
                float waterHeight = _waterSurface.GetWaterHeight(worldPoint);
                
                // Calculate depth (positive = underwater)
                float depth = waterHeight - worldPoint.y;
                _pointDepths[i] = depth;
                
                if (depth > 0)
                {
                    // Point is underwater - apply buoyancy
                    submergedCount++;
                    
                    // Force scales with depth, but caps at full submersion
                    // Using a soft cap for smoother behavior
                    float submersionRatio = Mathf.Clamp01(depth / 0.3f);
                    float pointForceMagnitude = forcePerPoint * submersionRatio;
                    
                    // Additional force to maintain float height
                    float heightError = (waterHeight + _floatHeight) - transform.position.y;
                    float stabilizationForce = heightError * forcePerPoint * 0.5f;
                    pointForceMagnitude += Mathf.Max(0, stabilizationForce);
                    
                    // Buoyancy acts upward (along water surface normal)
                    Vector3 surfaceNormal = _waterSurface.GetSurfaceNormal(worldPoint);
                    Vector3 pointForce = surfaceNormal * pointForceMagnitude;
                    
                    _pointForces[i] = pointForce;
                    _totalBuoyancyForce += pointForce;
                    _averageSubmergedPoint += worldPoint;
                }
                else
                {
                    _pointForces[i] = Vector3.zero;
                }
            }
            
            // Calculate average position and submersion ratio
            if (submergedCount > 0)
            {
                _averageSubmergedPoint /= submergedCount;
                _submergedRatio = (float)submergedCount / _samplePoints.Length;
                _isFloating = true;
            }
            else
            {
                _submergedRatio = 0f;
                _isFloating = false;
            }
            
            // Store water level at center
            _waterLevel = _waterSurface.GetWaterHeight(transform.position);
        }
        
        /// <summary>
        /// Apply buoyancy forces at each sample point.
        /// </summary>
        private void ApplyBuoyancyForces()
        {
            if (!_isFloating) return;
            
            for (int i = 0; i < _samplePoints.Length; i++)
            {
                if (_pointForces[i].sqrMagnitude > 0.01f)
                {
                    Vector3 worldPoint = transform.TransformPoint(_samplePoints[i]);
                    _rigidbody.AddForceAtPosition(_pointForces[i], worldPoint, ForceMode.Force);
                }
            }
        }
        
        /// <summary>
        /// Apply water damping to reduce oscillation.
        /// </summary>
        private void ApplyDamping()
        {
            if (!_isFloating || _submergedRatio < 0.1f) return;
            
            Vector3 velocity = _rigidbody.linearVelocity;
            Vector3 angularVelocity = _rigidbody.angularVelocity;
            
            // Linear damping (mostly vertical)
            if (velocity.sqrMagnitude > 0.01f)
            {
                // Stronger damping for vertical motion
                Vector3 verticalVelocity = Vector3.up * velocity.y;
                Vector3 horizontalVelocity = new Vector3(velocity.x, 0, velocity.z);
                
                float velocityMagnitude = velocity.magnitude;
                float dampingScale = Mathf.Clamp01(velocityMagnitude / _dampingVelocityThreshold);
                
                Vector3 verticalDamping = -verticalVelocity * _waterDamping * _submergedRatio * dampingScale;
                Vector3 horizontalDamping = -horizontalVelocity * _waterDamping * 0.1f * _submergedRatio;
                
                _rigidbody.AddForce(verticalDamping + horizontalDamping, ForceMode.Force);
            }
            
            // Angular damping
            if (angularVelocity.sqrMagnitude > 0.01f)
            {
                Vector3 angDamping = -angularVelocity * _angularDamping * _submergedRatio;
                _rigidbody.AddTorque(angDamping, ForceMode.Force);
            }
        }
        
        /// <summary>
        /// Get the current height above water surface.
        /// </summary>
        public float GetHeightAboveWater()
        {
            if (_waterSurface == null) return 0f;
            return transform.position.y - _waterSurface.GetWaterHeight(transform.position);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug) return;
            
            // Ensure points are initialized for editor visualization
            if (_samplePoints == null || _samplePoints.Length == 0)
            {
                InitializeBuoyancyPoints();
            }
            
            if (_showBuoyancyPoints && _samplePoints != null)
            {
                for (int i = 0; i < _samplePoints.Length; i++)
                {
                    Vector3 worldPoint = transform.TransformPoint(_samplePoints[i]);
                    
                    if (Application.isPlaying && _pointDepths != null && i < _pointDepths.Length)
                    {
                        // Color based on depth
                        float depth = _pointDepths[i];
                        if (depth > 0)
                        {
                            Gizmos.color = Color.Lerp(Color.yellow, Color.blue, Mathf.Clamp01(depth / 0.3f));
                            
                            // Draw force
                            if (_pointForces != null && i < _pointForces.Length)
                            {
                                Gizmos.DrawRay(worldPoint, _pointForces[i] * 0.001f);
                            }
                        }
                        else
                        {
                            Gizmos.color = Color.red;
                        }
                    }
                    else
                    {
                        Gizmos.color = Color.cyan;
                    }
                    
                    Gizmos.DrawWireSphere(worldPoint, 0.03f);
                }
            }
            
            if (Application.isPlaying)
            {
                // Draw water level
                Gizmos.color = new Color(0, 0.5f, 1f, 0.3f);
                Vector3 waterPos = new Vector3(transform.position.x, _waterLevel, transform.position.z);
                Gizmos.DrawWireCube(waterPos, new Vector3(3f, 0.01f, 3f));
                
                // Labels
                UnityEditor.Handles.Label(transform.position + Vector3.up * 0.5f,
                    $"Submerged: {_submergedRatio * 100:F0}%\n" +
                    $"Buoyancy: {_totalBuoyancyForce.magnitude:F0} N\n" +
                    $"Height: {GetHeightAboveWater():F2} m");
            }
        }
#endif
    }
}
