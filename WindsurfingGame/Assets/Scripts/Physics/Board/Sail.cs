using UnityEngine;
using WindsurfingGame.Physics.Wind;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Simulates sail physics - converts wind into forward thrust.
    /// 
    /// Sail Geometry:
    /// - Leading edge (luff) is attached to the mast - this is the ROTATION POINT
    /// - Trailing edge (leech) extends BACKWARD toward the tail
    /// - Sail rotates around the mast based on sheet position
    /// - Mast foot is FIXED on the board (typically 1.2m from tail)
    /// - Mast rake tilts the mast forward/back around the fixed foot
    /// 
    /// The sail acts like an airfoil, generating lift (perpendicular to wind)
    /// and drag (parallel to wind). The combination propels the board.
    /// </summary>
    [RequireComponent(typeof(ApparentWindCalculator))]
    public class Sail : MonoBehaviour
    {
        [Header("Sail Properties")]
        [Tooltip("Sail area in square meters (typical: 4-10 m²)")]
        [SerializeField] private float _sailArea = 6f;
        
        [Tooltip("Maximum lift coefficient (how efficient the sail is)")]
        [SerializeField] private float _maxLiftCoefficient = 1.2f;
        
        [Tooltip("Drag coefficient at optimal angle")]
        [SerializeField] private float _baseDragCoefficient = 0.1f;

        [Header("Sail Control")]
        [Tooltip("Current sheet angle (0 = sheeted in tight, 1 = fully released)")]
        [Range(0f, 1f)]
        [SerializeField] private float _sheetPosition = 0.5f;
        
        [Tooltip("How quickly the sailor can sheet in/out")]
        [SerializeField] private float _sheetSpeed = 2f;

        [Header("Mast Position (Fixed)")]
        [Tooltip("Fixed mast foot position on board (typically 1.2m from tail)")]
        [SerializeField] private Vector3 _mastFootPosition = new Vector3(0, 0.1f, -0.05f);
        
        [Tooltip("Height of mast")]
        [SerializeField] private float _mastHeight = 4.5f;
        
        [Tooltip("Boom length (how far CE is from mast)")]
        [SerializeField] private float _boomLength = 2.0f;
        
        [Tooltip("Height of boom/CE on mast")]
        [SerializeField] private float _boomHeight = 1.8f;

        [Header("Mast Rake (Steering)")]
        [Tooltip("Current mast rake position (-1 = forward/downwind, +1 = back/upwind)")]
        [Range(-1f, 1f)]
        [SerializeField] private float _mastRake = 0f;
        
        [Tooltip("Maximum mast rake angle in degrees")]
        [SerializeField] private float _maxRakeAngle = 15f;
        
        [Tooltip("How quickly the sailor can rake the mast")]
        [SerializeField] private float _rakeSpeed = 2f;
        
        [Tooltip("Steering torque multiplier from rake")]
        [SerializeField] private float _rakeTorqueMultiplier = 0.5f;

        [Header("References")]
        [Tooltip("Rigidbody to apply forces to")]
        [SerializeField] private Rigidbody _targetRigidbody;

        [Header("Debug")]
        [SerializeField] private bool _showForceVectors = true;

        // Component references
        private ApparentWindCalculator _apparentWind;

        // Calculated forces
        private Vector3 _liftForce;
        private Vector3 _dragForce;
        private Vector3 _totalForce;
        private float _currentAngleOfAttack;

        // Air density constant
        private const float AIR_DENSITY = 1.225f; // kg/m³

        // Properties
        public Vector3 TotalForce => _totalForce;
        public float SheetPosition => _sheetPosition;
        public float AngleOfAttack => _currentAngleOfAttack;
        public float MastRake => _mastRake;
        public float CurrentSailAngle => _currentSailAngle;
        public Vector3 MastFootPosition => _mastFootPosition;
        public Vector3 CurrentCenterOfEffort => _currentCE;

        // Current calculated sail angle (for visualization)
        private float _currentSailAngle;
        // Current center of effort world position
        private Vector3 _currentCE;

        private void Awake()
        {
            _apparentWind = GetComponent<ApparentWindCalculator>();
            
            if (_targetRigidbody == null)
            {
                _targetRigidbody = GetComponentInParent<Rigidbody>();
            }
        }

        private void FixedUpdate()
        {
            CalculateSailForces();
            ApplyForces();
            ApplyRakeTorque();
        }

        private void CalculateSailForces()
        {
            Vector3 apparentWind = _apparentWind.ApparentWind;
            float windSpeed = _apparentWind.ApparentWindSpeed;

            if (windSpeed < 0.1f)
            {
                _liftForce = Vector3.zero;
                _dragForce = Vector3.zero;
                _totalForce = Vector3.zero;
                _currentSailAngle = 0f;
                return;
            }

            // Sail rotates around the mast (leading edge is at mast, trailing edge extends backward)
            // Sheet position controls how far the sail swings out from centerline
            // Sheet in (0) = sail close to centerline (for upwind)
            // Sheet out (1) = sail perpendicular to board (for downwind)
            _currentSailAngle = CalculateSailAngle();
            
            // Calculate the sail normal (perpendicular to sail surface)
            // Sail plane: leading edge at mast, trailing edge at angle behind
            Vector3 sailNormal = CalculateSailNormal(_currentSailAngle);
            
            // Calculate angle of attack (angle between apparent wind and sail plane)
            Vector3 windDirection = apparentWind.normalized;
            _currentAngleOfAttack = 90f - Vector3.Angle(windDirection, sailNormal);

            // Calculate lift and drag coefficients based on angle of attack
            float liftCoeff = CalculateLiftCoefficient(_currentAngleOfAttack);
            float dragCoeff = CalculateDragCoefficient(_currentAngleOfAttack);

            // Aerodynamic force formula: F = 0.5 * ρ * V² * A * C
            float dynamicPressure = 0.5f * AIR_DENSITY * windSpeed * windSpeed;
            float liftMagnitude = dynamicPressure * _sailArea * liftCoeff;
            float dragMagnitude = dynamicPressure * _sailArea * dragCoeff;

            // Lift is perpendicular to apparent wind direction (in horizontal plane)
            // Cross product gives us the perpendicular direction
            Vector3 liftDirection = Vector3.Cross(Vector3.up, windDirection).normalized;
            
            // Determine which side the sail is on based on wind direction
            // Sail goes to leeward (opposite side from where wind comes)
            Vector3 localWind = transform.InverseTransformDirection(apparentWind);
            float windFromSide = Mathf.Sign(localWind.x);
            liftDirection *= -windFromSide; // Lift pushes to windward

            // Drag is parallel to wind direction (wind pushes the sail)
            Vector3 dragDirection = windDirection;

            _liftForce = liftDirection * liftMagnitude;
            _dragForce = dragDirection * dragMagnitude;
            
            // Total force
            _totalForce = _liftForce + _dragForce;
        }

        private void ApplyForces()
        {
            if (_targetRigidbody == null || _totalForce.sqrMagnitude < 0.01f) return;

            // Calculate Center of Effort position:
            // - Start at mast foot (fixed position)
            // - Go up to boom height
            // - Extend backward along the sail at current sail angle
            // - Apply mast rake (tilts the whole mast fore/aft)
            
            // Mast rake tilts the mast around the fixed foot
            float rakeAngle = _mastRake * _maxRakeAngle * Mathf.Deg2Rad;
            float rakeOffsetZ = Mathf.Sin(rakeAngle) * _boomHeight; // How far the boom moves fore/aft
            float rakeOffsetY = Mathf.Cos(rakeAngle) * _boomHeight; // Adjusted height
            
            // Position at boom height on mast (with rake applied)
            Vector3 boomAttachment = _mastFootPosition + new Vector3(0, rakeOffsetY, rakeOffsetZ);
            
            // CE is along the boom, which extends BACKWARD from mast at the current sail angle
            // Sail angle determines how far to the side the boom swings
            // Sail extends backward (-Z local) and to the side (+/- X local)
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            float ceDistance = _boomLength * 0.6f; // CE is about 60% along the boom
            
            // Boom direction: backward and to the side
            // Negative X = port, Positive X = starboard
            Vector3 boomDirection = new Vector3(
                Mathf.Sin(sailAngleRad),  // Side component
                0,
                -Mathf.Cos(sailAngleRad)  // Backward component (negative Z)
            );
            
            Vector3 localCE = boomAttachment + boomDirection * ceDistance;
            _currentCE = transform.TransformPoint(localCE);
            
            _targetRigidbody.AddForceAtPosition(_totalForce, _currentCE, ForceMode.Force);
        }

        /// <summary>
        /// Applies additional steering torque based on mast rake.
        /// Raking back (toward tail) creates upwind turning moment.
        /// Raking forward (toward nose) creates downwind turning moment.
        /// </summary>
        private void ApplyRakeTorque()
        {
            if (_targetRigidbody == null) return;

            // Only apply if we have sail force (need power to steer)
            float forceMagnitude = _totalForce.magnitude;
            if (forceMagnitude < 1f) return;

            // Steering torque proportional to:
            // - Mast rake amount (positive = back = upwind, negative = forward = downwind)
            // - Sail force magnitude (more power = more steering authority)
            // - Rake torque multiplier for tuning
            float steeringTorque = _mastRake * forceMagnitude * _rakeTorqueMultiplier;
            
            _targetRigidbody.AddTorque(Vector3.up * steeringTorque, ForceMode.Force);
        }

        /// <summary>
        /// Calculates the current sail angle based on apparent wind and sheet position.
        /// The sail rotates around the mast (luff). Angle is measured from centerline.
        /// Positive angle = sail to starboard, Negative angle = sail to port.
        /// </summary>
        private float CalculateSailAngle()
        {
            // Determine which side the sail should be on based on apparent wind
            // Wind from starboard (+X local) = sail to port (-angle)
            // Wind from port (-X local) = sail to starboard (+angle)
            Vector3 localWind = transform.InverseTransformDirection(_apparentWind.ApparentWind);
            float windSide = Mathf.Sign(-localWind.x); // Sail goes opposite to wind
            if (Mathf.Abs(localWind.x) < 0.1f)
                windSide = 1f; // Default to starboard if wind is from ahead/behind
            
            // Sheet position controls how far the sail opens from centerline
            // Sheet in (0) = sail close to centerline (small angle) - for upwind
            // Sheet out (1) = sail far from centerline (large angle) - for downwind
            float minAngle = 15f;  // Sail can't go closer than this to centerline
            float maxAngle = 80f;  // Sail fully released
            float sailAngle = Mathf.Lerp(minAngle, maxAngle, _sheetPosition);
            
            return sailAngle * windSide;
        }

        /// <summary>
        /// Calculates the sail normal vector based on sail angle.
        /// The sail plane has its leading edge (luff) at the mast,
        /// and extends backward at the given angle from centerline.
        /// </summary>
        private Vector3 CalculateSailNormal(float sailAngle)
        {
            // Sail extends backward from mast at sailAngle degrees from centerline
            // The sail normal is perpendicular to this sail plane
            // If sail angle is 0, sail is along centerline (pointing back), normal points sideways
            // If sail angle is 90, sail is perpendicular to centerline, normal points forward/back
            
            float angleRad = sailAngle * Mathf.Deg2Rad;
            
            // Sail chord direction (from luff to leech): backward and to the side
            Vector3 sailChord = new Vector3(
                Mathf.Sin(angleRad),
                0,
                -Mathf.Cos(angleRad)
            ).normalized;
            
            // Normal is perpendicular to sail chord (horizontal plane)
            // Cross with up vector to get horizontal normal
            Vector3 localNormal = Vector3.Cross(Vector3.up, sailChord).normalized;
            
            return transform.TransformDirection(localNormal);
        }

        /// <summary>
        /// Lift coefficient curve - peaks around 15-20° angle of attack.
        /// </summary>
        private float CalculateLiftCoefficient(float angleOfAttack)
        {
            float absAngle = Mathf.Abs(angleOfAttack);
            
            // Simplified lift curve
            // Increases up to optimal angle (~15°), then decreases (stall)
            if (absAngle < 15f)
            {
                return Mathf.Lerp(0, _maxLiftCoefficient, absAngle / 15f);
            }
            else if (absAngle < 25f)
            {
                return _maxLiftCoefficient;
            }
            else if (absAngle < 45f)
            {
                // Stall region - lift drops
                return Mathf.Lerp(_maxLiftCoefficient, 0.3f, (absAngle - 25f) / 20f);
            }
            else
            {
                return 0.3f;
            }
        }

        /// <summary>
        /// Drag coefficient - increases with angle of attack.
        /// </summary>
        private float CalculateDragCoefficient(float angleOfAttack)
        {
            float absAngle = Mathf.Abs(angleOfAttack);
            
            // Drag increases with angle
            return _baseDragCoefficient + Mathf.Pow(absAngle / 90f, 2) * 0.8f;
        }

        /// <summary>
        /// Sheet in the sail (pull it tighter).
        /// </summary>
        public void SheetIn(float amount)
        {
            _sheetPosition = Mathf.Clamp01(_sheetPosition - amount * _sheetSpeed * Time.deltaTime);
        }

        /// <summary>
        /// Sheet out the sail (let it out).
        /// </summary>
        public void SheetOut(float amount)
        {
            _sheetPosition = Mathf.Clamp01(_sheetPosition + amount * _sheetSpeed * Time.deltaTime);
        }

        /// <summary>
        /// Set sheet position directly (0-1).
        /// </summary>
        public void SetSheetPosition(float position)
        {
            _sheetPosition = Mathf.Clamp01(position);
        }

        /// <summary>
        /// Rake mast forward (turn downwind / bear away).
        /// </summary>
        public void RakeForward(float amount)
        {
            _mastRake = Mathf.Clamp(_mastRake - amount * _rakeSpeed * Time.deltaTime, -1f, 1f);
        }

        /// <summary>
        /// Rake mast back (turn upwind / head up).
        /// </summary>
        public void RakeBack(float amount)
        {
            _mastRake = Mathf.Clamp(_mastRake + amount * _rakeSpeed * Time.deltaTime, -1f, 1f);
        }

        /// <summary>
        /// Set mast rake directly (-1 to 1).
        /// </summary>
        public void SetMastRake(float rake)
        {
            _mastRake = Mathf.Clamp(rake, -1f, 1f);
        }

        /// <summary>
        /// Returns the mast to neutral position over time.
        /// </summary>
        public void CenterMast()
        {
            _mastRake = Mathf.MoveTowards(_mastRake, 0f, _rakeSpeed * Time.deltaTime);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showForceVectors || !Application.isPlaying) return;

            Vector3 pos = _currentCE;

            // Lift force (green)
            Gizmos.color = Color.green;
            Gizmos.DrawRay(pos, _liftForce * 0.01f);

            // Drag force (red)
            Gizmos.color = Color.red;
            Gizmos.DrawRay(pos, _dragForce * 0.01f);

            // Total force (yellow)
            Gizmos.color = Color.yellow;
            Gizmos.DrawRay(pos, _totalForce * 0.01f);

            // Center of effort
            Gizmos.color = Color.magenta;
            Gizmos.DrawWireSphere(pos, 0.2f);

            // Labels
            UnityEditor.Handles.Label(pos + Vector3.up, 
                $"Lift: {_liftForce.magnitude:F0}N\n" +
                $"Drag: {_dragForce.magnitude:F0}N\n" +
                $"AoA: {_currentAngleOfAttack:F1}°");
        }
#endif
    }
}
