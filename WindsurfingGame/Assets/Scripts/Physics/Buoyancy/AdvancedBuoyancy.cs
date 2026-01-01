using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Water;

namespace WindsurfingGame.Physics.Buoyancy
{
    /// <summary>
    /// Realistic buoyancy system for a windsurf board.
    /// 
    /// Implements proper Archimedes' principle:
    /// - Buoyancy force = ρ × g × V_submerged (density × gravity × displaced volume)
    /// - Multi-point sampling for accurate pitch/roll moments
    /// - Accounts for hull shape and rocker
    /// - Reduces effective buoyancy when planing (hydrodynamic lift takes over)
    /// 
    /// Key physics:
    /// - At rest: Full buoyancy supports board + sailor weight
    /// - At speed: Board rises onto plane, less volume submerged
    /// - Trim matters: Bow-up attitude reduces wetted area when planing
    /// 
    /// References:
    /// - Principles of Naval Architecture (SNAME)
    /// - Savitsky, D. "Hydrodynamic Design of Planing Hulls"
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedBuoyancy : MonoBehaviour
    {
        [Header("Water Reference")]
        [SerializeField] private WaterSurface _waterSurface;
        
        [Header("Board Properties")]
        [Tooltip("Total board volume (liters) - determines max buoyancy")]
        [SerializeField] private float _boardVolumeLiters = 120f;
        
        [Tooltip("Board length (meters)")]
        [SerializeField] private float _boardLength = 2.5f;
        
        [Tooltip("Board width at widest point (meters)")]
        [SerializeField] private float _boardWidth = 0.6f;
        
        [Tooltip("Board thickness at thickest point (meters)")]
        [SerializeField] private float _boardThickness = 0.12f;
        
        [Tooltip("Rocker (bottom curve) at nose (meters)")]
        [SerializeField] private float _noseRocker = 0.08f;
        
        [Tooltip("Rocker at tail (meters)")]
        [SerializeField] private float _tailRocker = 0.02f;
        
        [Header("Buoyancy Points")]
        [Tooltip("Number of sample points along length")]
        [SerializeField] private int _lengthSamples = 7;
        
        [Tooltip("Number of sample points along width")]
        [SerializeField] private int _widthSamples = 3;
        
        [Header("Damping")]
        [Tooltip("Vertical damping coefficient - resists bobbing/bouncing")]
        [SerializeField] private float _verticalDamping = 4000f;
        
        [Tooltip("Water viscosity - adds velocity-squared damping for thick water feel")]
        [SerializeField] private float _waterViscosity = 400f;
        
        [Tooltip("Rotational damping coefficient")]
        [SerializeField] private float _rotationalDamping = 150f;
        
        [Tooltip("Horizontal damping when submerged (drag)")]
        [SerializeField] private float _horizontalDamping = 20f;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        [SerializeField] private bool _showBuoyancyPoints = true;
        
        // Components
        private Rigidbody _rigidbody;
        private WindsurfingGame.Physics.Board.AdvancedHullDrag _hullDrag;
        
        // Buoyancy calculation
        private Vector3[] _samplePoints;      // Local space sample points
        private float[] _sampleVolumes;       // Volume contribution per point
        private float[] _pointDepths;         // Current depth at each point
        private Vector3[] _pointForces;       // Current force at each point
        
        // State
        private float _submergedVolume;       // Current submerged volume (m³)
        private float _submergedRatio;        // 0-1 how much of board is under
        private Vector3 _totalBuoyancyForce;
        private Vector3 _centerOfBuoyancy;    // Where buoyancy acts
        private bool _isFloating;
        private float _waterLevel;
        
        // Constants
        private float _totalVolume;           // Total board volume (m³)
        private float _volumePerPoint;        // Base volume per sample point
        
        // Public accessors
        public bool IsFloating => _isFloating;
        public float SubmergedRatio => _submergedRatio;
        public float SubmergedVolume => _submergedVolume;
        public float WaterLevel => _waterLevel;
        public Vector3 TotalBuoyancyForce => _totalBuoyancyForce;
        public Vector3 CenterOfBuoyancy => _centerOfBuoyancy;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            _hullDrag = GetComponent<WindsurfingGame.Physics.Board.AdvancedHullDrag>();
            
            // Convert liters to cubic meters
            _totalVolume = _boardVolumeLiters * 0.001f;
            
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
        /// Initialize buoyancy sample points with volume distribution.
        /// Creates a grid of points on the hull bottom, each representing
        /// a portion of the total board volume.
        /// </summary>
        private void InitializeBuoyancyPoints()
        {
            int totalPoints = _lengthSamples * _widthSamples;
            _samplePoints = new Vector3[totalPoints];
            _sampleVolumes = new float[totalPoints];
            _pointDepths = new float[totalPoints];
            _pointForces = new Vector3[totalPoints];
            
            float halfLength = _boardLength * 0.5f;
            float halfWidth = _boardWidth * 0.5f;
            
            // Calculate volume distribution
            // More volume in center, less at nose/tail due to tapering
            float totalVolumeWeight = 0f;
            float[] volumeWeights = new float[totalPoints];
            
            int index = 0;
            for (int i = 0; i < _lengthSamples; i++)
            {
                // Position along length (-0.5 to +0.5, where +Z is forward/bow)
                float lengthT = (float)i / (_lengthSamples - 1);
                float z = Mathf.Lerp(-halfLength, halfLength, lengthT);
                
                // Calculate rocker (how much the bottom curves up)
                // Rocker is higher at nose (front) and tail (back)
                float distanceFromCenter = Mathf.Abs(lengthT - 0.5f) * 2f; // 0 at center, 1 at ends
                float rocker;
                if (lengthT > 0.5f)
                {
                    // Forward half - nose rocker
                    rocker = _noseRocker * distanceFromCenter * distanceFromCenter;
                }
                else
                {
                    // Aft half - tail rocker
                    rocker = _tailRocker * distanceFromCenter * distanceFromCenter;
                }
                
                // Width varies along length (narrower at nose/tail)
                float widthFactor = 1f - 0.3f * distanceFromCenter * distanceFromCenter;
                float localHalfWidth = halfWidth * widthFactor;
                
                // Volume factor - boards have more volume in center
                float volumeFactor = 1f - 0.4f * distanceFromCenter;
                
                for (int j = 0; j < _widthSamples; j++)
                {
                    float widthT = (float)j / (_widthSamples - 1);
                    float x = Mathf.Lerp(-localHalfWidth, localHalfWidth, widthT);
                    
                    // Bottom of hull with rocker
                    float y = -_boardThickness * 0.5f + rocker;
                    
                    _samplePoints[index] = new Vector3(x, y, z);
                    
                    // Volume weight for this point
                    volumeWeights[index] = volumeFactor * widthFactor;
                    totalVolumeWeight += volumeWeights[index];
                    
                    index++;
                }
            }
            
            // Distribute total volume proportionally
            for (int i = 0; i < totalPoints; i++)
            {
                _sampleVolumes[i] = _totalVolume * (volumeWeights[i] / totalVolumeWeight);
            }
            
            _volumePerPoint = _totalVolume / totalPoints;
        }
        
        private void FixedUpdate()
        {
            if (_waterSurface == null) return;
            
            CalculateBuoyancy();
            ApplyBuoyancyForces();
            ApplyDamping();
        }
        
        /// <summary>
        /// Calculate buoyancy using Archimedes' principle.
        /// Buoyancy = ρ × g × V_displaced
        /// </summary>
        private void CalculateBuoyancy()
        {
            _totalBuoyancyForce = Vector3.zero;
            _centerOfBuoyancy = Vector3.zero;
            _submergedVolume = 0f;
            int submergedCount = 0;
            
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
                    submergedCount++;
                    
                    // Calculate submerged fraction of this point's volume
                    // Using board thickness as reference for full submersion
                    float submersionFraction = Mathf.Clamp01(depth / _boardThickness);
                    float pointSubmergedVolume = _sampleVolumes[i] * submersionFraction;
                    
                    _submergedVolume += pointSubmergedVolume;
                    
                    // Buoyancy force: F = ρ × g × V
                    float buoyancyMagnitude = PhysicsConstants.WATER_DENSITY * 
                                              PhysicsConstants.GRAVITY * 
                                              pointSubmergedVolume;
                    
                    // Get surface normal for force direction
                    Vector3 surfaceNormal = _waterSurface.GetSurfaceNormal(worldPoint);
                    Vector3 pointForce = surfaceNormal * buoyancyMagnitude;
                    
                    _pointForces[i] = pointForce;
                    _totalBuoyancyForce += pointForce;
                    _centerOfBuoyancy += worldPoint * buoyancyMagnitude;
                }
                else
                {
                    _pointForces[i] = Vector3.zero;
                }
            }
            
            // Calculate weighted center of buoyancy
            if (_totalBuoyancyForce.magnitude > 0.1f)
            {
                _centerOfBuoyancy /= _totalBuoyancyForce.magnitude;
                _submergedRatio = _submergedVolume / _totalVolume;
                _isFloating = true;
            }
            else
            {
                _centerOfBuoyancy = transform.position;
                _submergedRatio = 0f;
                _isFloating = submergedCount > 0;
            }
            
            // Store water level at center
            _waterLevel = _waterSurface.GetWaterHeight(transform.position);
        }
        
        /// <summary>
        /// Apply buoyancy forces at each sample point.
        /// This naturally creates stabilizing pitch/roll moments.
        /// </summary>
        private void ApplyBuoyancyForces()
        {
            if (!_isFloating) return;
            
            // When planing, hydrodynamic lift supplements buoyancy
            // Board rides higher, less volume submerged
            float buoyancyScale = 1f;
            if (_hullDrag != null && _hullDrag.PlaningRatio > 0.1f)
            {
                // At full planing, hydrodynamic lift provides significant support
                // Reduce buoyancy contribution to avoid excessive height
                buoyancyScale = 1f - _hullDrag.PlaningRatio * 0.3f;
            }
            
            for (int i = 0; i < _samplePoints.Length; i++)
            {
                if (_pointForces[i].sqrMagnitude > 0.01f)
                {
                    Vector3 worldPoint = transform.TransformPoint(_samplePoints[i]);
                    Vector3 scaledForce = _pointForces[i] * buoyancyScale;
                    _rigidbody.AddForceAtPosition(scaledForce, worldPoint, ForceMode.Force);
                }
            }
        }
        
        /// <summary>
        /// Apply damping to reduce oscillation and simulate water resistance.
        /// Uses both linear damping (stability) and viscous damping (realism).
        /// </summary>
        private void ApplyDamping()
        {
            if (!_isFloating || _submergedRatio < 0.05f) return;
            
            Vector3 velocity = _rigidbody.linearVelocity;
            Vector3 angularVelocity = _rigidbody.angularVelocity;
            
            // ===== VERTICAL DAMPING =====
            // Combines linear damping (stability) with viscous v² damping (realism)
            // Real water has viscosity - resistance increases with speed squared
            float verticalVelocity = velocity.y;
            if (Mathf.Abs(verticalVelocity) > 0.01f)
            {
                // Linear damping: F = -C₁ × v (stable, prevents oscillation)
                float linearDamping = -verticalVelocity * _verticalDamping * _submergedRatio;
                
                // Viscous damping: F = -C₂ × v × |v| (realistic, water feels thick)
                // Sign preserved so it opposes motion in correct direction
                float viscousDamping = -verticalVelocity * Mathf.Abs(verticalVelocity) * _waterViscosity * _submergedRatio;
                
                float totalVerticalDamping = linearDamping + viscousDamping;
                
                // Cap to prevent extreme forces
                totalVerticalDamping = Mathf.Clamp(totalVerticalDamping, -15000f, 15000f);
                
                _rigidbody.AddForce(Vector3.up * totalVerticalDamping, ForceMode.Force);
            }
            
            // ===== HORIZONTAL DAMPING =====
            // Water drag when moving sideways - NOT forward motion
            // Hull drag handles forward resistance, this is only for lateral drift
            // NO viscosity here - it would kill speed and prevent planing
            Vector3 horizontalVelocity = new Vector3(velocity.x, 0, velocity.z);
            if (horizontalVelocity.sqrMagnitude > 0.01f)
            {
                // Only lateral (sideways) damping - forward is handled by hull drag
                Vector3 localVelocity = transform.InverseTransformDirection(horizontalVelocity);
                
                // Strong lateral damping (resists sideslip)
                // Minimal forward damping (hull drag does this properly)
                float lateralSpeed = Mathf.Abs(localVelocity.x);
                float lateralDamping = lateralSpeed * _horizontalDamping * 2f;
                
                // Apply only in lateral direction, not forward
                Vector3 lateralDir = transform.right * Mathf.Sign(localVelocity.x);
                Vector3 dampingForce = -lateralDir * lateralDamping * _submergedRatio;
                _rigidbody.AddForce(dampingForce, ForceMode.Force);
            }
            
            // Rotational damping - resists roll, pitch, yaw oscillations
            if (angularVelocity.sqrMagnitude > 0.001f)
            {
                // Different damping for different axes
                Vector3 localAngVel = transform.InverseTransformDirection(angularVelocity);
                
                // Base damping applies even at low submersion (hull is still touching water)
                // Only scale slightly with submersion - a windsurfing board always has some water contact
                float minDampingFactor = 0.3f; // Always have at least 30% damping
                float submersionFactor = minDampingFactor + (1f - minDampingFactor) * _submergedRatio;
                
                // Roll (X) - water resists rolling strongly (wide hull)
                // Pitch (Z) - water resists pitching (long hull)
                // Yaw (Y) - less resistance (fin handles this)
                Vector3 dampingTorque = new Vector3(
                    -localAngVel.x * _rotationalDamping * 2.0f * submersionFactor,
                    -localAngVel.y * _rotationalDamping * 0.3f * submersionFactor,
                    -localAngVel.z * _rotationalDamping * 1.5f * submersionFactor
                );
                
                // Don't multiply by submersion again - that was causing near-zero damping when planing
                dampingTorque = transform.TransformDirection(dampingTorque);
                _rigidbody.AddTorque(dampingTorque, ForceMode.Force);
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
                    
                    // Size based on volume contribution
                    float size = 0.02f + (_sampleVolumes != null && i < _sampleVolumes.Length ? 
                                 _sampleVolumes[i] / _volumePerPoint * 0.02f : 0f);
                    
                    if (Application.isPlaying && _pointDepths != null && i < _pointDepths.Length)
                    {
                        float depth = _pointDepths[i];
                        if (depth > 0)
                        {
                            // Underwater - blue intensity based on depth
                            Gizmos.color = Color.Lerp(Color.cyan, Color.blue, 
                                                      Mathf.Clamp01(depth / _boardThickness));
                            
                            // Draw force vector
                            if (_pointForces != null && i < _pointForces.Length)
                            {
                                Gizmos.DrawRay(worldPoint, _pointForces[i] * 0.001f);
                            }
                        }
                        else
                        {
                            // Above water - red
                            Gizmos.color = Color.red;
                        }
                    }
                    else
                    {
                        Gizmos.color = Color.cyan;
                    }
                    
                    Gizmos.DrawWireSphere(worldPoint, size);
                }
                
                // Draw center of buoyancy
                if (Application.isPlaying && _isFloating)
                {
                    Gizmos.color = Color.yellow;
                    Gizmos.DrawWireSphere(_centerOfBuoyancy, 0.1f);
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
                    $"Submerged: {_submergedRatio * 100:F0}% ({_submergedVolume * 1000:F0}L)\n" +
                    $"Buoyancy: {_totalBuoyancyForce.magnitude:F0} N\n" +
                    $"Height: {GetHeightAboveWater():F3} m");
            }
        }
#endif
    }
}
