using UnityEngine;
using WindsurfingGame.Physics.Water;

namespace WindsurfingGame.Physics.Buoyancy
{
    /// <summary>
    /// Applies buoyancy forces to a Rigidbody based on water surface height.
    /// Uses multiple sample points for realistic tilting and stability.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class BuoyancyBody : MonoBehaviour
    {
        [Header("Water Reference")]
        [Tooltip("Reference to the water surface. Will search scene if not set.")]
        [SerializeField] private WaterSurface _waterSurface;

        [Header("Buoyancy Settings")]
        [Tooltip("Strength of the buoyancy force")]
        [SerializeField] private float _buoyancyStrength = 10f;
        
        [Tooltip("How deep the object sinks before reaching equilibrium (meters)")]
        [SerializeField] private float _floatHeight = 0.1f;
        
        [Tooltip("Damping applied when underwater (reduces bobbing)")]
        [SerializeField] private float _waterDamping = 1f;
        
        [Tooltip("Angular damping when in water (reduces spinning)")]
        [SerializeField] private float _angularWaterDamping = 0.5f;

        [Header("Buoyancy Points")]
        [Tooltip("Points where buoyancy is sampled. If empty, uses object center.")]
        [SerializeField] private Transform[] _buoyancyPoints;
        
        [Tooltip("If no points assigned, auto-generate this many points")]
        [SerializeField] private int _autoGeneratePoints = 4;

        [Header("Debug")]
        [SerializeField] private bool _showDebugGizmos = true;

        // Component references
        private Rigidbody _rigidbody;
        
        // Runtime state
        private Vector3[] _samplePositions;
        private float[] _sampleDepths;
        private bool _isInitialized;

        // Public properties
        public float SubmergedPercentage { get; private set; }
        public bool IsFloating => SubmergedPercentage > 0;
        public Vector3 AverageSubmergedPoint { get; private set; }

        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            InitializeBuoyancyPoints();
        }

        private void Start()
        {
            // Find water surface if not assigned
            if (_waterSurface == null)
            {
                _waterSurface = FindFirstObjectByType<WaterSurface>();
                if (_waterSurface == null)
                {
                    Debug.LogError($"BuoyancyBody on {gameObject.name}: No WaterSurface found in scene!");
                    enabled = false;
                    return;
                }
            }
            
            _isInitialized = true;
        }

        private void InitializeBuoyancyPoints()
        {
            if (_buoyancyPoints != null && _buoyancyPoints.Length > 0)
            {
                // Use assigned points
                _samplePositions = new Vector3[_buoyancyPoints.Length];
                _sampleDepths = new float[_buoyancyPoints.Length];
            }
            else
            {
                // Auto-generate points based on collider bounds
                GenerateDefaultBuoyancyPoints();
            }
        }

        private void GenerateDefaultBuoyancyPoints()
        {
            // Get bounds from collider
            Collider col = GetComponent<Collider>();
            Bounds bounds;
            
            if (col != null)
            {
                bounds = col.bounds;
                // Convert to local space
                Vector3 localCenter = transform.InverseTransformPoint(bounds.center);
                Vector3 localSize = bounds.size;
                
                // Generate points at corners (bottom half only for buoyancy)
                _samplePositions = new Vector3[_autoGeneratePoints];
                _sampleDepths = new float[_autoGeneratePoints];

                if (_autoGeneratePoints >= 4)
                {
                    float halfX = localSize.x * 0.4f;
                    float halfZ = localSize.z * 0.4f;
                    float bottomY = localCenter.y - localSize.y * 0.3f;
                    
                    _samplePositions[0] = new Vector3(-halfX, bottomY, halfZ);   // Front-left
                    _samplePositions[1] = new Vector3(halfX, bottomY, halfZ);    // Front-right
                    _samplePositions[2] = new Vector3(-halfX, bottomY, -halfZ);  // Back-left
                    _samplePositions[3] = new Vector3(halfX, bottomY, -halfZ);   // Back-right
                    
                    // Add center points if more requested
                    for (int i = 4; i < _autoGeneratePoints; i++)
                    {
                        _samplePositions[i] = new Vector3(0, bottomY, 0);
                    }
                }
                else
                {
                    // Just use center
                    _samplePositions[0] = Vector3.zero;
                }
            }
            else
            {
                // No collider, use single point at center
                _samplePositions = new Vector3[] { Vector3.zero };
                _sampleDepths = new float[1];
            }
        }

        private void FixedUpdate()
        {
            if (!_isInitialized) return;
            
            ApplyBuoyancy();
        }

        private void ApplyBuoyancy()
        {
            int submergedCount = 0;
            Vector3 totalSubmergedPosition = Vector3.zero;
            
            for (int i = 0; i < _samplePositions.Length; i++)
            {
                // Convert local point to world position
                Vector3 worldPoint = transform.TransformPoint(_samplePositions[i]);
                
                // Get water height at this position
                float waterHeight = _waterSurface.GetWaterHeight(worldPoint);
                
                // Calculate depth (positive = underwater)
                float depth = waterHeight - worldPoint.y;
                _sampleDepths[i] = depth;
                
                if (depth > 0)
                {
                    // Point is underwater - apply buoyancy force
                    submergedCount++;
                    totalSubmergedPosition += worldPoint;
                    
                    // Force increases with depth, capped at floatHeight
                    float normalizedDepth = Mathf.Clamp01(depth / _floatHeight);
                    float forceMagnitude = _buoyancyStrength * normalizedDepth / _samplePositions.Length;
                    
                    // Apply upward force at this point
                    Vector3 buoyancyForce = Vector3.up * forceMagnitude;
                    _rigidbody.AddForceAtPosition(buoyancyForce, worldPoint, ForceMode.Force);
                    
                    // Apply damping to reduce bobbing
                    Vector3 pointVelocity = _rigidbody.GetPointVelocity(worldPoint);
                    Vector3 dampingForce = -pointVelocity * _waterDamping * normalizedDepth / _samplePositions.Length;
                    _rigidbody.AddForceAtPosition(dampingForce, worldPoint, ForceMode.Force);
                }
            }
            
            // Calculate submerged percentage
            SubmergedPercentage = (float)submergedCount / _samplePositions.Length;
            
            if (submergedCount > 0)
            {
                AverageSubmergedPoint = totalSubmergedPosition / submergedCount;
                
                // Apply angular damping when in water
                _rigidbody.angularVelocity *= (1f - _angularWaterDamping * Time.fixedDeltaTime);
            }
        }

        /// <summary>
        /// Manually set the water surface reference.
        /// </summary>
        public void SetWaterSurface(WaterSurface water)
        {
            _waterSurface = water;
            _isInitialized = water != null;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebugGizmos) return;
            
            // Draw buoyancy sample points
            if (_samplePositions != null)
            {
                for (int i = 0; i < _samplePositions.Length; i++)
                {
                    Vector3 worldPoint = transform.TransformPoint(_samplePositions[i]);
                    
                    // Color based on depth (blue = underwater, red = above)
                    if (Application.isPlaying && _sampleDepths != null && i < _sampleDepths.Length)
                    {
                        Gizmos.color = _sampleDepths[i] > 0 ? Color.cyan : Color.red;
                    }
                    else
                    {
                        Gizmos.color = Color.yellow;
                    }
                    
                    Gizmos.DrawSphere(worldPoint, 0.1f);
                }
            }
            else if (_buoyancyPoints != null)
            {
                Gizmos.color = Color.yellow;
                foreach (var point in _buoyancyPoints)
                {
                    if (point != null)
                    {
                        Gizmos.DrawSphere(point.position, 0.1f);
                    }
                }
            }
        }
#endif
    }
}
