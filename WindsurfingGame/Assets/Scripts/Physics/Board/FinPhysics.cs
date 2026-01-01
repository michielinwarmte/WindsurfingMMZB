using UnityEngine;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Simulates fin hydrodynamics.
    /// The fin generates lateral lift force that:
    /// 1. Prevents sideways drift (leeway)
    /// 2. Converts sail power into forward motion
    /// 3. Enables the board to track (follow its heading)
    /// 
    /// Without a fin, the board would just drift downwind.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class FinPhysics : MonoBehaviour
    {
        [Header("Fin Properties")]
        [Tooltip("Fin area in square meters (typical: 0.02-0.05 m²)")]
        [SerializeField] private float _finArea = 0.08f;
        
        [Tooltip("Fin efficiency/lift coefficient (higher = more grip)")]
        [SerializeField] private float _liftCoefficient = 8f;
        
        [Tooltip("Position of fin relative to board center")]
        [SerializeField] private Vector3 _finPosition = new Vector3(0, -0.1f, -0.8f);

        [Header("Speed Effects")]
        [Tooltip("Minimum speed for fin to generate lift (m/s)")]
        [SerializeField] private float _minEffectiveSpeed = 0.5f;
        
        [Tooltip("Speed at which fin reaches full effectiveness (m/s)")]
        [SerializeField] private float _fullEffectSpeed = 3f;

        [Header("Tracking Force")]
        [Tooltip("How strongly the board tries to align with its velocity")]
        [SerializeField] private float _trackingStrength = 8f;
        
        [Tooltip("Apply tracking torque to straighten the board")]
        [SerializeField] private bool _enableTracking = true;

        [Header("Stall Behavior")]
        [Tooltip("Angle of attack where fin starts losing effectiveness (degrees)")]
        [SerializeField] private float _stallAngle = 25f;
        
        [Tooltip("How quickly lift drops after stall")]
        [SerializeField] private float _stallFalloff = 0.5f;

        [Header("Debug")]
        [SerializeField] private bool _showDebugVectors = true;

        // References
        private Rigidbody _rigidbody;
        
        // Water density constant
        private const float WATER_DENSITY = 1025f; // kg/m³ (seawater)

        // Calculated values for debug display
        private Vector3 _finLiftForce;
        private Vector3 _finDragForce;
        private float _currentSlipAngle;
        private float _lateralSpeed;

        // Properties
        public float SlipAngle => _currentSlipAngle;
        public float LateralSpeed => _lateralSpeed;
        public Vector3 FinLiftForce => _finLiftForce;
        public bool IsStalled => Mathf.Abs(_currentSlipAngle) > _stallAngle;

        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
        }

        private void FixedUpdate()
        {
            CalculateFinForces();
            
            if (_enableTracking)
            {
                ApplyTrackingTorque();
            }
        }

        private void CalculateFinForces()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;

            // Reset forces if too slow
            if (speed < _minEffectiveSpeed)
            {
                _finLiftForce = Vector3.zero;
                _finDragForce = Vector3.zero;
                _currentSlipAngle = 0f;
                _lateralSpeed = 0f;
                return;
            }

            // Get velocity in local space
            Vector3 localVelocity = transform.InverseTransformDirection(velocity);
            
            // Lateral velocity (sideways movement = what the fin resists)
            _lateralSpeed = localVelocity.x;
            
            // Forward velocity
            float forwardSpeed = localVelocity.z;

            // Calculate slip angle (angle between heading and velocity)
            // This is the fin's "angle of attack"
            _currentSlipAngle = Mathf.Atan2(localVelocity.x, Mathf.Max(0.1f, Mathf.Abs(localVelocity.z))) * Mathf.Rad2Deg;

            // Calculate speed effectiveness (ramps up from min to full speed)
            float speedFactor = Mathf.Clamp01((speed - _minEffectiveSpeed) / (_fullEffectSpeed - _minEffectiveSpeed));

            // Calculate lift coefficient based on slip angle
            float effectiveLiftCoeff = CalculateLiftCoefficient(_currentSlipAngle);

            // Hydrodynamic lift formula: L = 0.5 * ρ * V² * A * Cl
            // We use lateral speed for more accurate force direction
            float dynamicPressure = 0.5f * WATER_DENSITY * speed * speed;
            float liftMagnitude = dynamicPressure * _finArea * effectiveLiftCoeff * speedFactor;

            // Lift force is perpendicular to velocity, opposing lateral movement
            // If moving right (positive X), force pushes left (negative X)
            float liftDirection = -Mathf.Sign(_lateralSpeed);
            _finLiftForce = transform.right * liftDirection * liftMagnitude;

            // Induced drag from the fin - increases with lift generated
            // High side force at beam reach = more fin lift = more induced drag
            // This makes broad reach (less side force) more efficient
            float dragCoeff = 0.008f + Mathf.Abs(effectiveLiftCoeff) * 0.04f;
            float dragMagnitude = dynamicPressure * _finArea * dragCoeff * speedFactor;
            _finDragForce = -velocity.normalized * dragMagnitude;

            // Apply forces at fin position
            Vector3 worldFinPosition = transform.TransformPoint(_finPosition);
            _rigidbody.AddForceAtPosition(_finLiftForce, worldFinPosition, ForceMode.Force);
            _rigidbody.AddForceAtPosition(_finDragForce, worldFinPosition, ForceMode.Force);
        }

        /// <summary>
        /// Applies a torque that helps the board align with its velocity direction.
        /// This simulates how a real board naturally wants to track straight.
        /// </summary>
        private void ApplyTrackingTorque()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;

            if (speed < _minEffectiveSpeed) return;

            // Get the angle between forward direction and velocity
            Vector3 velocityFlat = new Vector3(velocity.x, 0, velocity.z).normalized;
            Vector3 forwardFlat = new Vector3(transform.forward.x, 0, transform.forward.z).normalized;

            if (velocityFlat.sqrMagnitude < 0.01f) return;

            // Calculate signed angle
            float angleError = Vector3.SignedAngle(forwardFlat, velocityFlat, Vector3.up);

            // Apply corrective torque (stronger at higher speeds)
            float speedFactor = Mathf.Clamp01(speed / _fullEffectSpeed);
            float torqueMagnitude = angleError * _trackingStrength * speedFactor;

            // Clamp to prevent over-correction
            torqueMagnitude = Mathf.Clamp(torqueMagnitude, -50f, 50f);

            _rigidbody.AddTorque(Vector3.up * torqueMagnitude, ForceMode.Force);
        }

        /// <summary>
        /// Calculates lift coefficient based on slip angle.
        /// Uses a more aggressive curve for better grip at small slip angles.
        /// </summary>
        private float CalculateLiftCoefficient(float slipAngle)
        {
            float absAngle = Mathf.Abs(slipAngle);

            if (absAngle < 1f)
            {
                // Very small slip - still provide strong resistance
                // This prevents initial drift
                return _liftCoefficient * 0.5f * absAngle;
            }
            else if (absAngle < _stallAngle)
            {
                // Aggressive curve - rises quickly then plateaus
                // Using sqrt for faster rise at small angles
                float normalized = absAngle / _stallAngle;
                float curve = Mathf.Sqrt(normalized); // Faster rise at low angles
                return _liftCoefficient * curve;
            }
            else
            {
                // Post-stall: lift drops off
                float overStall = absAngle - _stallAngle;
                float stallFactor = Mathf.Exp(-overStall * _stallFalloff / 10f);
                return _liftCoefficient * stallFactor;
            }
        }

        /// <summary>
        /// Gets the current tracking efficiency (0-1).
        /// Used by other systems to know how well the board is gripping.
        /// </summary>
        public float GetTrackingEfficiency()
        {
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < _minEffectiveSpeed) return 0f;

            float speedFactor = Mathf.Clamp01(speed / _fullEffectSpeed);
            float angleFactor = 1f - Mathf.Clamp01(Mathf.Abs(_currentSlipAngle) / 45f);

            return speedFactor * angleFactor;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Draw fin position
            Vector3 finPos = transform.TransformPoint(_finPosition);
            Gizmos.color = Color.blue;
            Gizmos.DrawWireSphere(finPos, 0.1f);

            if (!_showDebugVectors || !Application.isPlaying) return;

            // Draw lift force (green)
            Gizmos.color = Color.green;
            Gizmos.DrawRay(finPos, _finLiftForce * 0.005f);

            // Draw drag force (red)
            Gizmos.color = Color.red;
            Gizmos.DrawRay(finPos, _finDragForce * 0.01f);

            // Draw velocity direction (yellow)
            if (_rigidbody != null)
            {
                Gizmos.color = Color.yellow;
                Gizmos.DrawRay(finPos, _rigidbody.linearVelocity.normalized * 2f);
            }

            // Draw forward direction (cyan)
            Gizmos.color = Color.cyan;
            Gizmos.DrawRay(finPos, transform.forward * 2f);

            // Labels
            UnityEditor.Handles.Label(finPos + Vector3.up * 0.5f,
                $"Slip: {_currentSlipAngle:F1}°\n" +
                $"Lat Speed: {_lateralSpeed:F2} m/s\n" +
                $"Lift: {_finLiftForce.magnitude:F0} N\n" +
                $"{(IsStalled ? "⚠ STALLED" : "Tracking")}");
        }
#endif
    }
}
