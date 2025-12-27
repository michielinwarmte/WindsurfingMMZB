using UnityEngine;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Advanced fin physics with realistic hydrodynamic modeling.
    /// 
    /// The fin is the critical component that converts sail side force into forward motion.
    /// It works like an underwater wing, generating lift perpendicular to the water flow,
    /// which opposes the sideways drift (leeway) caused by the sail.
    /// 
    /// Key physics:
    /// - Lift proportional to velocity squared and angle of attack (leeway angle)
    /// - Induced drag from generating lift
    /// - Stall behavior at high leeway angles
    /// - Force application at fin center of pressure
    /// 
    /// References:
    /// - Abbott & Von Doenhoff "Theory of Wing Sections"
    /// - Marchaj, C.A. "Aero-Hydrodynamics of Sailing"
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedFin : MonoBehaviour
    {
        [Header("Fin Configuration")]
        [SerializeField] private FinConfiguration _finConfig = new FinConfiguration();
        
        [Header("Performance Tuning")]
        [Tooltip("Minimum speed for fin to generate significant lift (m/s)")]
        [SerializeField] private float _minEffectiveSpeed = 0.5f;
        
        [Tooltip("Speed at which fin reaches full effectiveness (m/s)")]
        [SerializeField] private float _fullEffectSpeed = 2.0f;
        
        [Tooltip("Enable course tracking (fin helps board go straight)")]
        [SerializeField] private bool _enableTracking = true;
        
        [Tooltip("Tracking torque strength")]
        [SerializeField] private float _trackingStrength = 15f;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        [SerializeField] private float _forceVectorScale = 0.001f;
        
        // Components
        private Rigidbody _rigidbody;
        
        // State
        private Vector3 _liftForce;
        private Vector3 _dragForce;
        private float _leewayAngle;
        private float _liftCoefficient;
        private float _dragCoefficient;
        private bool _isStalled;
        private float _effectivenessRatio;
        
        // Public accessors
        public FinConfiguration Config => _finConfig;
        public Vector3 LiftForce => _liftForce;
        public Vector3 DragForce => _dragForce;
        public Vector3 TotalForce => _liftForce + _dragForce;
        public float LeewayAngle => _leewayAngle;
        public float LiftCoefficient => _liftCoefficient;
        public bool IsStalled => _isStalled;
        public float Effectiveness => _effectivenessRatio;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
        }
        
        private void FixedUpdate()
        {
            CalculateFinForces();
            ApplyForces();
            
            if (_enableTracking)
            {
                ApplyTrackingTorque();
            }
        }
        
        /// <summary>
        /// Calculate hydrodynamic forces on the fin.
        /// </summary>
        private void CalculateFinForces()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;
            
            // Calculate effectiveness based on speed
            if (speed < _minEffectiveSpeed)
            {
                _effectivenessRatio = 0f;
                _liftForce = Vector3.zero;
                _dragForce = Vector3.zero;
                _leewayAngle = 0f;
                _liftCoefficient = 0f;
                _dragCoefficient = 0f;
                _isStalled = false;
                return;
            }
            
            _effectivenessRatio = Mathf.Clamp01((speed - _minEffectiveSpeed) / 
                                                 (_fullEffectSpeed - _minEffectiveSpeed));
            
            // Use the hydrodynamics module
            Hydrodynamics.CalculateFinForces(
                velocity,
                transform.forward,
                transform.right,
                _finConfig.Area,
                _finConfig.AspectRatio,
                out Vector3 lift,
                out Vector3 drag,
                out float leeway
            );
            
            _leewayAngle = leeway;
            _liftCoefficient = Hydrodynamics.CalculateFinLiftCoefficient(leeway, _finConfig.AspectRatio);
            _dragCoefficient = Hydrodynamics.CalculateFinDragCoefficient(_liftCoefficient, _finConfig.AspectRatio);
            _isStalled = Mathf.Abs(_leewayAngle) > _finConfig.StallAngle;
            
            // Apply effectiveness scaling
            _liftForce = lift * _effectivenessRatio;
            _dragForce = drag * _effectivenessRatio;
        }
        
        /// <summary>
        /// Apply forces at the fin position.
        /// </summary>
        private void ApplyForces()
        {
            if (_liftForce.sqrMagnitude < 0.01f && _dragForce.sqrMagnitude < 0.01f) 
                return;
            
            // Calculate force application point
            // Center of pressure is approximately 25% of chord from leading edge
            // and 40% of depth from root
            Vector3 finCenterOfPressure = _finConfig.Position;
            finCenterOfPressure.y -= _finConfig.Depth * 0.4f;
            
            Vector3 worldFinPos = transform.TransformPoint(finCenterOfPressure);
            
            // Apply both lift and drag at the fin position
            _rigidbody.AddForceAtPosition(_liftForce, worldFinPos, ForceMode.Force);
            _rigidbody.AddForceAtPosition(_dragForce, worldFinPos, ForceMode.Force);
        }
        
        /// <summary>
        /// Apply tracking torque to help the board maintain course.
        /// This simulates how the fin naturally wants to align the board with its velocity.
        /// </summary>
        private void ApplyTrackingTorque()
        {
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < _minEffectiveSpeed) return;
            
            // Get horizontal velocity direction
            Vector3 velocityHorizontal = _rigidbody.linearVelocity;
            velocityHorizontal.y = 0;
            
            if (velocityHorizontal.sqrMagnitude < 0.01f) return;
            
            velocityHorizontal.Normalize();
            
            // Get board forward direction (horizontal)
            Vector3 forwardHorizontal = transform.forward;
            forwardHorizontal.y = 0;
            forwardHorizontal.Normalize();
            
            // Calculate misalignment angle
            float angleError = Vector3.SignedAngle(forwardHorizontal, velocityHorizontal, Vector3.up);
            
            // Apply corrective torque
            // Stronger at higher speeds, weaker when stalled
            float speedFactor = Mathf.Clamp01(speed / _fullEffectSpeed);
            float stallFactor = _isStalled ? 0.3f : 1f;
            
            float torqueMagnitude = angleError * _trackingStrength * speedFactor * stallFactor * _effectivenessRatio;
            
            // Limit torque to prevent over-correction
            torqueMagnitude = Mathf.Clamp(torqueMagnitude, -100f, 100f);
            
            _rigidbody.AddTorque(Vector3.up * torqueMagnitude, ForceMode.Force);
        }
        
        /// <summary>
        /// Get a normalized efficiency value for the fin's current performance.
        /// 0 = not working, 1 = optimal performance.
        /// </summary>
        public float GetEfficiency()
        {
            if (_effectivenessRatio < 0.1f) return 0f;
            
            // Efficiency drops as we approach stall
            float angleFromOptimal = Mathf.Abs(_leewayAngle) - 5f; // Optimal around 3-5°
            float anglePenalty = Mathf.Clamp01(angleFromOptimal / 15f);
            
            return _effectivenessRatio * (1f - anglePenalty * 0.7f);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug) return;
            
            // Draw fin position and shape
            Vector3 finPos = transform.TransformPoint(_finConfig.Position);
            Vector3 finBottom = finPos - transform.up * _finConfig.Depth;
            
            Gizmos.color = Color.blue;
            Gizmos.DrawLine(finPos, finBottom);
            Gizmos.DrawWireCube(finPos - transform.up * _finConfig.Depth * 0.5f,
                new Vector3(_finConfig.Chord, _finConfig.Depth, 0.02f));
            
            if (!Application.isPlaying) return;
            
            // Draw forces
            Gizmos.color = Color.green;
            Gizmos.DrawRay(finPos, _liftForce * _forceVectorScale);
            
            Gizmos.color = Color.red;
            Gizmos.DrawRay(finPos, _dragForce * _forceVectorScale);
            
            // Draw velocity vs heading
            if (_rigidbody != null)
            {
                Vector3 vel = _rigidbody.linearVelocity;
                if (vel.magnitude > 0.1f)
                {
                    Gizmos.color = Color.yellow;
                    Gizmos.DrawRay(finPos, vel.normalized * 2f);
                }
                
                Gizmos.color = Color.cyan;
                Gizmos.DrawRay(finPos, transform.forward * 2f);
            }
            
            // Labels
            UnityEditor.Handles.Label(finPos + Vector3.up * 0.5f,
                $"Leeway: {_leewayAngle:F1}°\n" +
                $"CL: {_liftCoefficient:F2}\n" +
                $"Lift: {_liftForce.magnitude:F0} N\n" +
                $"Eff: {_effectivenessRatio * 100:F0}%\n" +
                $"{(_isStalled ? "⚠ STALLED" : "OK")}");
        }
#endif
    }
}
