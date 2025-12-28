using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Buoyancy;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Advanced hull resistance model for windsurf board.
    /// 
    /// Models the hydrodynamic drag of the board hull including:
    /// - Skin friction (viscous drag)
    /// - Form drag (pressure drag from hull shape)
    /// - Wave-making resistance (at displacement speeds)
    /// - Spray drag (at planing speeds)
    /// 
    /// The model transitions between displacement mode (low speed) 
    /// and planing mode (high speed) based on Froude number.
    /// 
    /// References:
    /// - Larsson & Eliasson "Principles of Yacht Design"
    /// - Savitsky "Hydrodynamic Design of Planing Hulls"
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedHullDrag : MonoBehaviour
    {
        [Header("Hull Configuration")]
        [SerializeField] private HullConfiguration _hullConfig = new HullConfiguration();
        
        [Header("Planing Behavior")]
        [Tooltip("Speed at which planing begins (m/s). 17 km/h = 4.7 m/s is typical")]
        [SerializeField] private float _planingOnsetSpeed = 4.0f;
        
        [Tooltip("Speed at which fully planing (m/s). ~22 km/h = 6 m/s is typical")]
        [SerializeField] private float _fullPlaningSpeed = 6.0f;
        
        [Tooltip("Wetted area reduction when fully planing (0.3 = 30% of original)")]
        [SerializeField] private float _planingWettedAreaRatio = 0.35f;
        
        [Header("Submersion Resistance")]
        [Tooltip("Extra drag multiplier when board sinks deeper")]
        [SerializeField] private float _submersionDragMultiplier = 3.0f;
        
        [Header("Displacement Lift")]
        [Tooltip("Enable hydrodynamic lift at displacement speeds (before planing)")]
        [SerializeField] private bool _enableDisplacementLift = true;
        
        [Tooltip("Lift coefficient for displacement mode")]
        [SerializeField] private float _displacementLiftCoefficient = 0.12f;
        
        [Tooltip("Minimum speed for displacement lift to start (m/s)")]
        [SerializeField] private float _displacementLiftMinSpeed = 0.5f;
        
        [Header("Planing Lift")]
        [Tooltip("Enable hydrodynamic lift when planing")]
        [SerializeField] private bool _enablePlaningLift = true;
        
        [Tooltip("Planing lift coefficient (higher = more lift)")]
        [SerializeField] private float _planingLiftCoefficient = 0.15f;
        
        [Tooltip("Maximum lift as fraction of weight (prevents flying)")]
        [SerializeField] private float _maxLiftFraction = 0.4f;
        
        [Tooltip("Trim angle for maximum lift (degrees bow-up)")]
        [SerializeField] private float _optimalTrimAngle = 2f;
        
        [Header("Buoyancy Reference")]
        [SerializeField] private AdvancedBuoyancy _advancedBuoyancy;
        [SerializeField] private BuoyancyBody _legacyBuoyancy;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        
        // Components
        private Rigidbody _rigidbody;
        
        // Buoyancy interface
        private bool IsFloating => _advancedBuoyancy != null ? _advancedBuoyancy.IsFloating : 
                                   (_legacyBuoyancy != null ? _legacyBuoyancy.IsFloating : true);
        
        // State
        private float _totalResistance;
        private float _froudeNumber;
        private float _planingRatio;
        private float _currentWettedArea;
        private bool _isPlaning;
        private Vector3 _resistanceForce;
        private float _planingLift;
        private float _displacementLift;
        private float _currentTrimAngle;
        
        // Public accessors
        public HullConfiguration Config => _hullConfig;
        public float Resistance => _totalResistance;
        public float FroudeNumber => _froudeNumber;
        public bool IsPlaning => _isPlaning;
        public float PlaningRatio => _planingRatio;
        public float PlaningLift => _planingLift;
        public float DisplacementLift => _displacementLift;
        public float TotalLift => _planingLift + _displacementLift;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            
            // Try to find advanced buoyancy first, then fall back to legacy
            if (_advancedBuoyancy == null)
            {
                _advancedBuoyancy = GetComponent<AdvancedBuoyancy>();
            }
            if (_advancedBuoyancy == null && _legacyBuoyancy == null)
            {
                _legacyBuoyancy = GetComponent<BuoyancyBody>();
            }
            
            // Log warning if no buoyancy component found
            if (_advancedBuoyancy == null && _legacyBuoyancy == null)
            {
                Debug.LogWarning($"AdvancedHullDrag on {gameObject.name}: No buoyancy component found. " +
                    "Add AdvancedBuoyancy or BuoyancyBody for proper behavior.");
            }
        }
        
        private void FixedUpdate()
        {
            // Only apply drag when in water
            if (!IsFloating)
            {
                _resistanceForce = Vector3.zero;
                _totalResistance = 0f;
                _planingLift = 0f;
                _displacementLift = 0f;
                return;
            }
            
            CalculateHullResistance();
            CalculateDisplacementLift();
            CalculatePlaningLift();
            ApplyResistance();
            ApplyHydrodynamicLift();
        }
        
        /// <summary>
        /// Calculate hull resistance based on speed and mode (displacement/planing).
        /// </summary>
        private void CalculateHullResistance()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;
            
            if (speed < 0.1f)
            {
                _totalResistance = 0f;
                _froudeNumber = 0f;
                _planingRatio = 0f;
                _isPlaning = false;
                _resistanceForce = Vector3.zero;
                return;
            }
            
            // Calculate Froude number (for reference/display)
            _froudeNumber = speed / Mathf.Sqrt(PhysicsConstants.GRAVITY * _hullConfig.WaterlineLength);
            
            // Calculate planing ratio based on SPEED, not Froude number
            // Real windsurfers start planing around 17 km/h (4.7 m/s)
            if (speed < _planingOnsetSpeed)
            {
                _planingRatio = 0f;
                _isPlaning = false;
            }
            else if (speed < _fullPlaningSpeed)
            {
                _planingRatio = (speed - _planingOnsetSpeed) / (_fullPlaningSpeed - _planingOnsetSpeed);
                _isPlaning = _planingRatio > 0.5f;
            }
            else
            {
                _planingRatio = 1f;
                _isPlaning = true;
            }
            
            // Calculate current wetted area (reduces when planing)
            _currentWettedArea = Mathf.Lerp(_hullConfig.WettedArea, 
                                             _hullConfig.WettedArea * _planingWettedAreaRatio,
                                             _planingRatio);
            
            // Base hull resistance from hydrodynamics module
            _totalResistance = Hydrodynamics.CalculateHullResistance(
                speed,
                _hullConfig.TotalMass,
                _currentWettedArea,
                _hullConfig.WaterlineLength,
                _isPlaning
            );
            
            // SUBMERSION-BASED RESISTANCE
            // When board sinks deeper, resistance increases significantly
            // This simulates the board "digging in" to the water
            if (_advancedBuoyancy != null)
            {
                float submersionRatio = _advancedBuoyancy.SubmergedRatio;
                
                // Normal floating is ~30-40% submerged
                // More than that means sinking, which increases drag
                float normalSubmersion = 0.35f;
                if (submersionRatio > normalSubmersion)
                {
                    // Extra drag when too deep in water
                    float excessSubmersion = (submersionRatio - normalSubmersion) / (1f - normalSubmersion);
                    float submersionDragFactor = 1f + excessSubmersion * _submersionDragMultiplier;
                    _totalResistance *= submersionDragFactor;
                }
                
                // Conversely, when planing and riding high, less drag
                if (_isPlaning && submersionRatio < normalSubmersion)
                {
                    float rideHighFactor = 1f - (normalSubmersion - submersionRatio) * 0.5f;
                    _totalResistance *= Mathf.Max(0.5f, rideHighFactor);
                }
            }
            
            // Create resistance force vector (opposes velocity)
            _resistanceForce = -velocity.normalized * _totalResistance;
            
            // Add directional resistance components
            ApplyDirectionalDrag(velocity, speed);
        }
        
        /// <summary>
        /// Apply different drag coefficients for different directions.
        /// </summary>
        private void ApplyDirectionalDrag(Vector3 velocity, float speed)
        {
            // Decompose velocity into local directions
            Vector3 localVelocity = transform.InverseTransformDirection(velocity);
            
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed;
            
            // Forward/backward - already handled by hull resistance
            // Lateral - additional form drag when moving sideways
            float lateralSpeed = Mathf.Abs(localVelocity.x);
            if (lateralSpeed > 0.1f)
            {
                // Hull has poor lateral streamlining
                float lateralCd = 1.0f; // Like a flat plate
                float lateralArea = _hullConfig.Length * _hullConfig.Thickness;
                float lateralDrag = lateralCd * q * lateralSpeed * lateralArea;
                
                // Add to resistance force
                Vector3 lateralDragForce = -transform.right * Mathf.Sign(localVelocity.x) * lateralDrag;
                _resistanceForce += lateralDragForce * (1f - _planingRatio * 0.5f); // Less when planing
            }
            
            // Vertical - resist vertical motion (bobbing)
            float verticalSpeed = Mathf.Abs(localVelocity.y);
            if (verticalSpeed > 0.1f)
            {
                float verticalCd = 1.2f;
                float verticalArea = _hullConfig.Length * _hullConfig.Width * 0.5f;
                float verticalDrag = verticalCd * q * verticalSpeed * verticalArea;
                
                Vector3 verticalDragForce = -Vector3.up * Mathf.Sign(localVelocity.y) * verticalDrag;
                _resistanceForce += verticalDragForce;
            }
        }
        
        /// <summary>
        /// Calculate hydrodynamic lift at displacement speeds.
        /// Even before planing, a moving hull generates dynamic lift as water
        /// flows under it. This lift ONLY applies to submerged portions.
        /// 
        /// Key physics:
        /// - Lift proportional to speed squared (dynamic pressure)
        /// - Only acts on submerged hull area
        /// - Reduces as board rises out of water (self-limiting)
        /// </summary>
        private void CalculateDisplacementLift()
        {
            _displacementLift = 0f;
            
            if (!_enableDisplacementLift) return;
            if (_advancedBuoyancy == null) return;
            
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < _displacementLiftMinSpeed) return;
            
            // Get submersion ratio - lift only on submerged parts
            float submersionRatio = _advancedBuoyancy.SubmergedRatio;
            if (submersionRatio < 0.1f) return; // Not enough in water
            
            // Dynamic pressure: q = 0.5 * rho * V^2
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed * speed;
            
            // Wetted area that generates lift
            // Only the submerged bottom surface creates lift
            float wettedArea = _hullConfig.Length * _hullConfig.Width * submersionRatio;
            
            // Calculate lift force
            // The key insight: lift coefficient scales with submersion
            // More submerged = more surface pushing water = more lift
            // This creates negative feedback: sinking generates more lift
            float liftCoeff = _displacementLiftCoefficient * submersionRatio;
            _displacementLift = liftCoeff * q * wettedArea;
            
            // Cap displacement lift - it shouldn't exceed a fraction of weight
            // At displacement speeds, buoyancy should still be the primary support
            float maxDisplacementLift = _hullConfig.TotalMass * PhysicsConstants.GRAVITY * 0.5f;
            _displacementLift = Mathf.Min(_displacementLift, maxDisplacementLift);
            
            // Reduce displacement lift as we transition to planing
            // (planing lift takes over)
            _displacementLift *= (1f - _planingRatio);
        }
        
        /// <summary>
        /// Calculate hydrodynamic lift from planing.
        /// At speed, the board acts like a hydrofoil, generating lift that
        /// raises it out of the water, reducing wetted area and drag.
        /// Based on Savitsky planing equations (simplified).
        /// </summary>
        private void CalculatePlaningLift()
        {
            if (!_enablePlaningLift || _planingRatio < 0.1f)
            {
                _planingLift = 0f;
                return;
            }
            
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < 3f) // Require more speed before lift kicks in
            {
                _planingLift = 0f;
                return;
            }
            
            // Calculate current trim angle (pitch)
            // Positive = bow up, which is good for planing
            float pitchAngle = transform.eulerAngles.x;
            if (pitchAngle > 180f) pitchAngle -= 360f;
            _currentTrimAngle = -pitchAngle; // Convert Unity's convention
            
            // STABILITY: Kill lift if pitch is too extreme (prevents runaway)
            if (Mathf.Abs(_currentTrimAngle) > 15f)
            {
                _planingLift = 0f;
                return;
            }
            
            // Dynamic pressure
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed * speed;
            
            // Planing area - the wetted bottom surface
            float planingArea = _hullConfig.Length * _hullConfig.Width * _planingWettedAreaRatio;
            
            // Lift coefficient based on trim angle
            // VERY conservative: only small lift at small positive trim angles
            float trimFactor;
            if (_currentTrimAngle < -2f)
            {
                // Bow down - no lift
                trimFactor = 0f;
            }
            else if (_currentTrimAngle < 0f)
            {
                // Slightly bow down - minimal lift
                trimFactor = 0.1f * (1f + _currentTrimAngle / 2f);
            }
            else if (_currentTrimAngle < _optimalTrimAngle)
            {
                // Below optimal - lift increases gently with trim
                trimFactor = 0.1f + 0.9f * (_currentTrimAngle / _optimalTrimAngle);
            }
            else if (_currentTrimAngle < _optimalTrimAngle * 3f)
            {
                // Above optimal - lift DECREASES sharply (negative feedback for stability)
                float excess = (_currentTrimAngle - _optimalTrimAngle) / (_optimalTrimAngle * 2f);
                trimFactor = Mathf.Lerp(1f, 0f, excess);
            }
            else
            {
                // Way too much trim - no lift (let gravity bring nose down)
                trimFactor = 0f;
            }
            
            // Calculate lift force - very gentle
            float liftCoeff = _planingLiftCoefficient * trimFactor * _planingRatio;
            _planingLift = liftCoeff * q * planingArea;
            
            // Cap lift to prevent the board from flying
            float maxLift = _hullConfig.TotalMass * PhysicsConstants.GRAVITY * _maxLiftFraction;
            _planingLift = Mathf.Min(_planingLift, maxLift);
        }
        
        /// <summary>
        /// Apply all hydrodynamic lift forces (displacement + planing).
        /// Both lift types ONLY apply when hull is in the water.
        /// </summary>
        private void ApplyHydrodynamicLift()
        {
            // Check we're actually in the water
            if (_advancedBuoyancy != null && _advancedBuoyancy.SubmergedRatio < 0.05f)
            {
                // Board is barely in water - no lift
                return;
            }
            
            float totalLift = _displacementLift + _planingLift;
            if (totalLift < 1f) return;
            
            // Determine lift application point based on mode
            float liftPointZ;
            if (_isPlaning)
            {
                // Planing: lift applied further aft (tail rides on water)
                liftPointZ = _hullConfig.Length * (0.5f - _planingRatio * 0.25f);
            }
            else
            {
                // Displacement: lift more centered
                liftPointZ = 0f;
            }
            
            Vector3 liftPoint = transform.TransformPoint(new Vector3(0f, 0f, liftPointZ));
            
            // Lift acts upward (perpendicular to water surface)
            Vector3 liftForce = Vector3.up * totalLift;
            
            _rigidbody.AddForceAtPosition(liftForce, liftPoint, ForceMode.Force);
        }
        
        /// <summary>
        /// Apply resistance force to rigidbody.
        /// </summary>
        private void ApplyResistance()
        {
            if (_resistanceForce.sqrMagnitude < 0.01f) return;
            
            // Apply at center of lateral resistance (approximately mid-hull, slightly aft)
            Vector3 clrPosition = transform.TransformPoint(new Vector3(0, 0, -_hullConfig.Length * 0.1f));
            
            _rigidbody.AddForceAtPosition(_resistanceForce, clrPosition, ForceMode.Force);
            
            // Apply angular damping to resist rotation
            // CRITICAL: Increase damping at high speeds to prevent instability
            Vector3 angularVelocity = _rigidbody.angularVelocity;
            float speedKnots = _rigidbody.linearVelocity.magnitude * PhysicsConstants.MS_TO_KNOTS;
            
            if (angularVelocity.sqrMagnitude > 0.001f)
            {
                // Base damping - higher when not planing (displacement mode)
                float baseDampingCoeff = _isPlaning ? 0.8f : 1.5f;
                
                // HIGH-SPEED STABILITY: Dramatically increase damping above 15 knots
                // This prevents the violent oscillations at planing speeds
                float highSpeedFactor = 1f;
                if (speedKnots > 15f)
                {
                    // Ramps from 1.0 at 15kn to 4.0 at 30kn
                    highSpeedFactor = 1f + (speedKnots - 15f) / 5f;
                    highSpeedFactor = Mathf.Min(highSpeedFactor, 5f); // Cap at 5x
                }
                
                float dampingCoeff = baseDampingCoeff * highSpeedFactor;
                Vector3 angularDamping = -angularVelocity * dampingCoeff * _hullConfig.TotalMass * 0.1f;
                _rigidbody.AddTorque(angularDamping, ForceMode.Force);
            }
        }
        
        /// <summary>
        /// Get the current speed in knots.
        /// </summary>
        public float GetSpeedKnots()
        {
            return _rigidbody.linearVelocity.magnitude * PhysicsConstants.MS_TO_KNOTS;
        }
        
        /// <summary>
        /// Get the current speed in km/h.
        /// </summary>
        public float GetSpeedKmh()
        {
            return _rigidbody.linearVelocity.magnitude * 3.6f;
        }
        
        /// <summary>
        /// Get submersion ratio from buoyancy (0-1).
        /// </summary>
        public float GetSubmersionRatio()
        {
            return _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio : 0f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug || !Application.isPlaying) return;
            
            Vector3 pos = transform.position;
            
            // Draw resistance force
            Gizmos.color = Color.red;
            Gizmos.DrawRay(pos, _resistanceForce * 0.005f);
            
            // Draw total lift
            float totalLift = _displacementLift + _planingLift;
            if (totalLift > 1f)
            {
                Gizmos.color = Color.cyan;
                Gizmos.DrawRay(pos, Vector3.up * totalLift * 0.001f);
            }
            
            // Draw velocity
            if (_rigidbody != null)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(pos, _rigidbody.linearVelocity);
            }
            
            // Labels
            float speedKmh = _rigidbody.linearVelocity.magnitude * 3.6f;
            float submersion = _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio * 100f : 0f;
            UnityEditor.Handles.Label(pos + Vector3.up * 1.5f,
                $"Speed: {speedKmh:F1} km/h ({GetSpeedKnots():F1} kts)\n" +
                $"Submerged: {submersion:F0}%\n" +
                $"Resistance: {_totalResistance:F0} N\n" +
                $"Lift: {_displacementLift:F0} + {_planingLift:F0} = {totalLift:F0} N\n" +
                $"{(_isPlaning ? "PLANING" : "Displacement")} ({_planingRatio * 100:F0}%)");
        }
#endif
    }
}
