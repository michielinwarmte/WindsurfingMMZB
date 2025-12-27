using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Environment;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Advanced sail physics with realistic aerodynamic modeling.
    /// 
    /// This implements proper sail aerodynamics including:
    /// - Lift and drag based on angle of attack and sail shape
    /// - Realistic force decomposition into drive and side force
    /// - Center of effort calculation based on sail geometry
    /// - Proper apparent wind handling
    /// - Sail trim optimization
    /// 
    /// Based on sail aerodynamics research and yacht design principles.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedSail : MonoBehaviour
    {
        [Header("Sail Configuration")]
        [SerializeField] private SailConfiguration _sailConfig = new SailConfiguration();
        
        [Header("Sail Control")]
        [Tooltip("Current sheet position (0 = sheeted in, 1 = fully eased)")]
        [Range(0f, 1f)]
        [SerializeField] private float _sheetPosition = 0.5f;
        
        [Tooltip("Sheet control speed")]
        [SerializeField] private float _sheetSpeed = 1.5f;
        
        [Tooltip("Mast rake angle (-1 = forward, +1 = back)")]
        [Range(-1f, 1f)]
        [SerializeField] private float _mastRake = 0f;
        
        [Tooltip("Maximum mast rake angle in degrees")]
        [SerializeField] private float _maxRakeAngle = 15f;
        
        [Tooltip("Mast rake control speed")]
        [SerializeField] private float _rakeSpeed = 3f;
        
        [Header("Wind Reference")]
        [SerializeField] private WindSystem _windSystem;
        
        [Header("Debug Visualization")]
        [SerializeField] private bool _showDebug = true;
        [SerializeField] private bool _showForceVectors = true;
        [SerializeField] private float _forceVectorScale = 0.002f;
        
        // Components
        private Rigidbody _rigidbody;
        
        // State
        private SailingState _state = new SailingState();
        private float _currentSailAngle;
        private Vector3 _sailNormal;
        private Vector3 _centerOfEffort;
        
        // Cached values
        private float _targetSheetPosition;
        private float _targetMastRake;
        
        // Public accessors
        public SailingState State => _state;
        public SailConfiguration Config => _sailConfig;
        public float SheetPosition => _sheetPosition;
        public float MastRake => _mastRake;
        public float CurrentSailAngle => _currentSailAngle;
        public Vector3 CenterOfEffort => _centerOfEffort;
        public Vector3 SailNormal => _sailNormal;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            _targetSheetPosition = _sheetPosition;
            _targetMastRake = _mastRake;
        }
        
        private void Start()
        {
            if (_windSystem == null)
            {
                _windSystem = WindSystem.Instance;
                if (_windSystem == null)
                {
                    _windSystem = FindFirstObjectByType<WindSystem>();
                }
            }
        }
        
        private void FixedUpdate()
        {
            UpdateSailControls();
            UpdateWindState();
            CalculateSailGeometry();
            CalculateSailForces();
            ApplyForces();
        }
        
        /// <summary>
        /// Smoothly update sail controls toward target values.
        /// </summary>
        private void UpdateSailControls()
        {
            // Smooth sheet position changes
            _sheetPosition = Mathf.MoveTowards(_sheetPosition, _targetSheetPosition, 
                _sheetSpeed * Time.fixedDeltaTime);
            
            // Smooth mast rake changes
            _mastRake = Mathf.MoveTowards(_mastRake, _targetMastRake, 
                _rakeSpeed * Time.fixedDeltaTime);
        }
        
        /// <summary>
        /// Update wind state - true and apparent wind.
        /// </summary>
        private void UpdateWindState()
        {
            // Get true wind
            if (_windSystem != null)
            {
                _state.TrueWind = _windSystem.GetWindAtPosition(transform.position);
            }
            else
            {
                _state.TrueWind = Vector3.zero;
            }
            
            _state.TrueWindSpeed = _state.TrueWind.magnitude;
            
            // Calculate true wind angle from bow
            if (_state.TrueWindSpeed > 0.1f)
            {
                Vector3 twHorizontal = new Vector3(_state.TrueWind.x, 0, _state.TrueWind.z).normalized;
                Vector3 fwdHorizontal = new Vector3(transform.forward.x, 0, transform.forward.z).normalized;
                _state.TrueWindAngle = Vector3.SignedAngle(-twHorizontal, fwdHorizontal, Vector3.up);
            }
            
            // Get boat velocity
            _state.BoatVelocity = _rigidbody.linearVelocity;
            _state.AngularVelocity = _rigidbody.angularVelocity;
            _state.BoatSpeed = _state.BoatVelocity.magnitude;
            
            // Calculate apparent wind
            _state.CalculateApparentWind(transform.forward);
        }
        
        /// <summary>
        /// Calculate sail geometry based on controls and wind.
        /// </summary>
        private void CalculateSailGeometry()
        {
            // Determine which side the sail should be on
            // Sail goes to leeward (opposite side from wind)
            float windSide = Mathf.Sign(_state.ApparentWindAngle);
            if (Mathf.Abs(_state.ApparentWindAngle) < 5f)
                windSide = 1f; // Default to starboard if wind is dead ahead/astern
            
            // Sheet position determines how far the sail opens from centerline
            // Sheeted in (0) = sail close to centerline (~15°) for upwind
            // Eased out (1) = sail far from centerline (~85°) for downwind
            float minAngle = 12f;
            float maxAngle = 85f;
            _currentSailAngle = Mathf.Lerp(minAngle, maxAngle, _sheetPosition) * windSide;
            
            // Store in state
            _state.SailAngle = _currentSailAngle;
            _state.SailCamber = _sailConfig.Camber;
            
            // Calculate sail normal
            // Sail extends backward from mast at the sail angle
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            Vector3 sailChord = new Vector3(
                Mathf.Sin(sailAngleRad),
                0,
                -Mathf.Cos(sailAngleRad)
            ).normalized;
            
            // Normal is perpendicular to sail chord (in horizontal plane)
            Vector3 localNormal = Vector3.Cross(Vector3.up, sailChord).normalized;
            _sailNormal = transform.TransformDirection(localNormal);
            
            // Calculate center of effort position
            CalculateCenterOfEffort();
        }
        
        /// <summary>
        /// Calculate the Center of Effort position based on sail geometry and mast rake.
        /// </summary>
        private void CalculateCenterOfEffort()
        {
            // Start at mast foot
            Vector3 localCE = _sailConfig.MastFootPosition;
            
            // Apply mast rake - rotates the whole rig fore/aft around the mast foot
            float rakeAngle = _mastRake * _maxRakeAngle * Mathf.Deg2Rad;
            
            // CE height on the mast (approximately 40% up from boom)
            float ceHeight = _sailConfig.CenterOfEffortHeight;
            
            // With rake, the CE moves fore/aft
            float ceForwardOffset = -Mathf.Sin(rakeAngle) * ceHeight;
            float ceHeightAdjusted = Mathf.Cos(rakeAngle) * ceHeight;
            
            localCE += new Vector3(0, ceHeightAdjusted, ceForwardOffset);
            
            // Add lateral offset based on sail angle
            // CE moves to leeward as sail opens
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            float ceDistance = _sailConfig.BoomLength * 0.5f;
            localCE += new Vector3(
                Mathf.Sin(sailAngleRad) * ceDistance,
                0,
                -Mathf.Cos(sailAngleRad) * ceDistance
            );
            
            _centerOfEffort = transform.TransformPoint(localCE);
            _state.CenterOfEffort = _centerOfEffort;
        }
        
        /// <summary>
        /// Calculate sail aerodynamic forces.
        /// </summary>
        private void CalculateSailForces()
        {
            // Check for no-sail zone (in irons)
            float absAWA = Mathf.Abs(_state.ApparentWindAngle);
            
            if (_state.ApparentWindSpeed < 0.5f || absAWA < 25f)
            {
                // No effective sail force - in irons or no wind
                _state.SailLift = Vector3.zero;
                _state.SailDrag = Vector3.zero;
                _state.SailForce = Vector3.zero;
                _state.AngleOfAttack = 0f;
                _state.IsInIrons = absAWA < 25f && _state.BoatSpeed < 1f;
                return;
            }
            
            // Calculate angle of attack
            // AoA = angle between apparent wind direction and sail plane
            Vector3 awDir = _state.ApparentWind.normalized;
            float dotProduct = Vector3.Dot(-awDir, _sailNormal);
            _state.AngleOfAttack = 90f - Mathf.Acos(Mathf.Clamp(dotProduct, -1f, 1f)) * PhysicsConstants.RAD_TO_DEG;
            
            // Use the aerodynamics module to calculate forces
            Aerodynamics.CalculateSailForces(
                _state.ApparentWind,
                _sailNormal,
                _sailConfig.Area,
                _sailConfig.Camber,
                _sailConfig.AspectRatio,
                out Vector3 liftForce,
                out Vector3 dragForce
            );
            
            _state.SailLift = liftForce;
            _state.SailDrag = dragForce;
            _state.SailForce = liftForce + dragForce;
            
            // Update derived state values
            _state.UpdateDerivedValues(transform.forward, transform.right);
        }
        
        /// <summary>
        /// Apply calculated forces to the rigidbody.
        /// </summary>
        private void ApplyForces()
        {
            if (_state.SailForce.sqrMagnitude < 0.01f) return;
            
            // Apply force at center of effort
            _rigidbody.AddForceAtPosition(_state.SailForce, _centerOfEffort, ForceMode.Force);
            
            // Apply additional steering torque from mast rake
            // Raking the mast moves the CE fore/aft, creating turning moment
            ApplyRakeSteering();
        }
        
        /// <summary>
        /// Apply steering torque from mast rake.
        /// </summary>
        private void ApplyRakeSteering()
        {
            // Mast rake creates a turning moment because it moves the CE
            // Rake back (positive) = CE moves aft = bow turns upwind
            // Rake forward (negative) = CE moves forward = bow turns downwind
            
            float forceMag = _state.SailForce.magnitude;
            if (forceMag < 1f) return;
            
            // Torque proportional to force and rake amount
            float steeringTorque = _mastRake * forceMag * 0.3f;
            
            _rigidbody.AddTorque(Vector3.up * steeringTorque, ForceMode.Force);
        }
        
        // Public control methods
        
        /// <summary>
        /// Set target sheet position (will smoothly transition).
        /// </summary>
        public void SetSheetPosition(float position)
        {
            _targetSheetPosition = Mathf.Clamp01(position);
        }
        
        /// <summary>
        /// Adjust sheet position incrementally.
        /// </summary>
        public void AdjustSheet(float delta)
        {
            _targetSheetPosition = Mathf.Clamp01(_targetSheetPosition + delta);
        }
        
        /// <summary>
        /// Set target mast rake (-1 to +1).
        /// </summary>
        public void SetMastRake(float rake)
        {
            _targetMastRake = Mathf.Clamp(rake, -1f, 1f);
        }
        
        /// <summary>
        /// Adjust mast rake incrementally.
        /// </summary>
        public void AdjustRake(float delta)
        {
            _targetMastRake = Mathf.Clamp(_targetMastRake + delta, -1f, 1f);
        }
        
        /// <summary>
        /// Get the optimal sheet position for current wind angle.
        /// </summary>
        public float GetOptimalSheetPosition()
        {
            float optimalAngle = Aerodynamics.CalculateOptimalSheetAngle(_state.ApparentWindAngle);
            return (optimalAngle - 12f) / (85f - 12f);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug) return;
            
            // Draw mast
            Vector3 mastFoot = transform.TransformPoint(_sailConfig.MastFootPosition);
            Vector3 mastTop = mastFoot + Vector3.up * _sailConfig.MastHeight;
            Gizmos.color = Color.gray;
            Gizmos.DrawLine(mastFoot, mastTop);
            
            // Draw CE
            if (Application.isPlaying)
            {
                Gizmos.color = Color.yellow;
                Gizmos.DrawWireSphere(_centerOfEffort, 0.15f);
                
                if (_showForceVectors && _state != null)
                {
                    // Draw sail force
                    Gizmos.color = Color.cyan;
                    Gizmos.DrawRay(_centerOfEffort, _state.SailForce * _forceVectorScale);
                    
                    // Draw lift (green) and drag (red)
                    Gizmos.color = Color.green;
                    Gizmos.DrawRay(_centerOfEffort, _state.SailLift * _forceVectorScale);
                    
                    Gizmos.color = Color.red;
                    Gizmos.DrawRay(_centerOfEffort, _state.SailDrag * _forceVectorScale);
                    
                    // Draw apparent wind
                    Gizmos.color = Color.blue;
                    Gizmos.DrawRay(_centerOfEffort + Vector3.up, _state.ApparentWind * 0.3f);
                    
                    // Draw sail normal
                    Gizmos.color = Color.magenta;
                    Gizmos.DrawRay(_centerOfEffort, _sailNormal * 2f);
                    
                    // Labels
                    UnityEditor.Handles.Label(_centerOfEffort + Vector3.up * 2f,
                        $"AoA: {_state.AngleOfAttack:F1}°\n" +
                        $"AWA: {_state.ApparentWindAngle:F1}°\n" +
                        $"AWS: {_state.ApparentWindSpeed:F1} m/s\n" +
                        $"Drive: {_state.DriveForce:F0} N\n" +
                        $"Side: {_state.SideForce:F0} N");
                }
            }
        }
#endif
    }
}
