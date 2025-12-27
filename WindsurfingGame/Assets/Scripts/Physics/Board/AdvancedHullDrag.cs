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
        [Tooltip("Froude number at which planing begins (typically 0.4-0.5)")]
        [SerializeField] private float _planingOnsetFn = 0.4f;
        
        [Tooltip("Froude number at which fully planing (typically 0.7-0.8)")]
        [SerializeField] private float _fullPlaningFn = 0.7f;
        
        [Tooltip("Wetted area reduction when fully planing (0.3 = 30% of original)")]
        [SerializeField] private float _planingWettedAreaRatio = 0.35f;
        
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
        
        // Public accessors
        public HullConfiguration Config => _hullConfig;
        public float Resistance => _totalResistance;
        public float FroudeNumber => _froudeNumber;
        public bool IsPlaning => _isPlaning;
        public float PlaningRatio => _planingRatio;
        
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
                return;
            }
            
            CalculateHullResistance();
            ApplyResistance();
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
            
            // Calculate Froude number
            _froudeNumber = speed / Mathf.Sqrt(PhysicsConstants.GRAVITY * _hullConfig.WaterlineLength);
            
            // Calculate planing ratio
            if (_froudeNumber < _planingOnsetFn)
            {
                _planingRatio = 0f;
                _isPlaning = false;
            }
            else if (_froudeNumber < _fullPlaningFn)
            {
                _planingRatio = (_froudeNumber - _planingOnsetFn) / (_fullPlaningFn - _planingOnsetFn);
                _isPlaning = _planingRatio > 0.5f;
            }
            else
            {
                _planingRatio = 1f;
                _isPlaning = true;
            }
            
            // Calculate current wetted area
            _currentWettedArea = Mathf.Lerp(_hullConfig.WettedArea, 
                                             _hullConfig.WettedArea * _planingWettedAreaRatio,
                                             _planingRatio);
            
            // Use the hydrodynamics module
            _totalResistance = Hydrodynamics.CalculateHullResistance(
                speed,
                _hullConfig.TotalMass,
                _currentWettedArea,
                _hullConfig.WaterlineLength,
                _isPlaning
            );
            
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

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug || !Application.isPlaying) return;
            
            Vector3 pos = transform.position;
            
            // Draw resistance force
            Gizmos.color = Color.red;
            Gizmos.DrawRay(pos, _resistanceForce * 0.005f);
            
            // Draw velocity
            if (_rigidbody != null)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(pos, _rigidbody.linearVelocity);
            }
            
            // Labels
            UnityEditor.Handles.Label(pos + Vector3.up * 1.5f,
                $"Speed: {GetSpeedKnots():F1} kts\n" +
                $"Fn: {_froudeNumber:F2}\n" +
                $"Resistance: {_totalResistance:F0} N\n" +
                $"Wetted: {_currentWettedArea:F2} m²\n" +
                $"{(_isPlaning ? "PLANING" : "Displacement")} ({_planingRatio * 100:F0}%)");
        }
#endif
    }
}
