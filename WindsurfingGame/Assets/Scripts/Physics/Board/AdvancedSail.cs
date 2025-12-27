using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Wind;
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
        [SerializeField] private float _sheetPosition = 0.65f;
        
        [Tooltip("Sheet control speed")]
        [SerializeField] private float _sheetSpeed = 1.5f;
        
        [Tooltip("Enable automatic sail trim for optimal angle of attack")]
        [SerializeField] private bool _autoTrim = false;
        
        [Tooltip("Mast rake angle (-1 = forward, +1 = back)")]
        [Range(-1f, 1f)]
        [SerializeField] private float _mastRake = 0f;
        
        [Tooltip("Maximum mast rake angle in degrees")]
        [SerializeField] private float _maxRakeAngle = 15f;
        
        [Tooltip("Mast rake control speed")]
        [SerializeField] private float _rakeSpeed = 3f;
        
        [Header("Wind Reference")]
        [SerializeField] private WindSystem _windSystem;
        [SerializeField] private WindManager _legacyWindManager;
        
        [Header("Debug Visualization")]
        [SerializeField] private bool _showDebug = true;
        [SerializeField] private bool _showForceVectors = true;
        [SerializeField] private float _forceVectorScale = 0.002f;
        
        // Components
        private Rigidbody _rigidbody;
        private IWindProvider _windProvider; // Fallback interface
        
        // State
        private SailingState _state = new SailingState();
        private float _currentSailAngle;
        private Vector3 _sailNormal;
        private Vector3 _centerOfEffort;
        private float _lastSailSide = 1f; // For hysteresis during tacks
        
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
            // Try to find WindSystem (preferred)
            if (_windSystem == null)
            {
                _windSystem = WindSystem.Instance;
                if (_windSystem == null)
                {
                    _windSystem = FindFirstObjectByType<WindSystem>();
                }
            }
            
            // Fallback to legacy WindManager if no WindSystem
            if (_windSystem == null)
            {
                if (_legacyWindManager == null)
                {
                    _legacyWindManager = FindFirstObjectByType<WindManager>();
                }
                
                if (_legacyWindManager != null)
                {
                    _windProvider = _legacyWindManager;
                    Debug.Log($"AdvancedSail on {gameObject.name}: Using legacy WindManager as wind source.");
                }
            }
            
            // Log error if no wind source found
            if (_windSystem == null && _windProvider == null)
            {
                Debug.LogError($"AdvancedSail on {gameObject.name}: NO WIND SOURCE FOUND! " +
                    "Add a WindSystem or WindManager to the scene. Sail forces will be ZERO!");
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
            // Auto-trim: automatically set optimal sheet position for current wind angle
            if (_autoTrim && _state.ApparentWindSpeed > 1f)
            {
                float optimalSheetPosition = CalculateOptimalSheetPosition();
                _targetSheetPosition = optimalSheetPosition;
            }
            
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
            // Get true wind from available source
            if (_windSystem != null)
            {
                _state.TrueWind = _windSystem.GetWindAtPosition(transform.position);
            }
            else if (_windProvider != null)
            {
                // Fallback to legacy IWindProvider
                _state.TrueWind = _windProvider.GetWindAtPosition(transform.position);
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
            // ============================================
            // SAIL SIDE DETERMINATION
            // ============================================
            // The sail always goes to the LEEWARD side (away from wind)
            // 
            // Unity SignedAngle convention:
            // - Wind from port (left) → AWA is POSITIVE
            // - Wind from starboard (right) → AWA is NEGATIVE
            //
            // Sail should go to OPPOSITE side of wind:
            // - Wind from port (AWA > 0) → sail on starboard → sailSide = -1
            // - Wind from starboard (AWA < 0) → sail on port → sailSide = +1
            //
            // Therefore: sailSide = -Sign(AWA) gives the correct side
            
            float absAWA = Mathf.Abs(_state.ApparentWindAngle);
            
            // Determine which side the sail is on
            // sailSide: +1 = sail on starboard (right), -1 = sail on port (left)
            float sailSide;
            
            if (absAWA < 5f)
            {
                // In irons or running dead downwind - maintain current side
                sailSide = _lastSailSide;
            }
            else
            {
                // Sail goes to leeward (opposite of wind direction)
                // -Sign(AWA) because Unity's SignedAngle gives negative for starboard wind
                // so we negate to get sail on opposite side from wind
                sailSide = -Mathf.Sign(_state.ApparentWindAngle);
                _lastSailSide = sailSide;
            }
            
            // ============================================
            // SAIL ANGLE FROM CENTERLINE
            // ============================================
            // Sheet position: 0 = sheeted in (close to centerline), 1 = eased out (far from centerline)
            // Upwind sailing: sheet in tight (~12° from centerline)
            // Downwind sailing: ease out (~85° from centerline)
            float minAngle = 12f;
            float maxAngle = 85f;
            float angleFromCenterline = Mathf.Lerp(minAngle, maxAngle, _sheetPosition);
            
            // Full sail angle (signed)
            _currentSailAngle = angleFromCenterline * sailSide;
            _state.SailAngle = _currentSailAngle;
            _state.SailCamber = _sailConfig.Camber;
            
            // ============================================
            // SAIL CHORD DIRECTION (boom direction in local space)
            // ============================================
            // At 0° angle: boom points BACKWARD along centerline (-Z in local space)
            // Positive angle: boom rotates to starboard (towards +X)
            // Negative angle: boom rotates to port (towards -X)
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            Vector3 localSailChord = new Vector3(
                Mathf.Sin(sailAngleRad),   // X: positive = starboard
                0,
                -Mathf.Cos(sailAngleRad)   // Z: negative = backward (sail trails behind mast)
            ).normalized;
            
            // ============================================
            // SAIL NORMAL (perpendicular to sail surface)
            // ============================================
            // The sail normal should point towards the WINDWARD side (where wind comes from)
            // This is the "pressure" side of the sail where camber faces
            // Cross product of chord and up gives perpendicular direction
            Vector3 localSailNormal = Vector3.Cross(localSailChord, Vector3.up).normalized;
            
            // Ensure normal points towards the wind
            Vector3 localWindDir = transform.InverseTransformDirection(_state.ApparentWind).normalized;
            localWindDir.y = 0;
            
            if (localWindDir.sqrMagnitude > 0.01f)
            {
                localWindDir.Normalize();
                // Normal should point INTO the wind (opposite to wind direction)
                // Wind blows in direction of ApparentWind vector, so we want normal to face -ApparentWind
                if (Vector3.Dot(localSailNormal, -localWindDir) < 0)
                {
                    localSailNormal = -localSailNormal;
                }
            }
            
            _sailNormal = transform.TransformDirection(localSailNormal);
            
            // Store sail side for other calculations
            _state.SailSide = sailSide;
            
            // Calculate center of effort position
            CalculateCenterOfEffort();
        }
        
        /// <summary>
        /// Calculate the Center of Effort position based on sail geometry and mast rake.
        /// For stability, we apply forces at a low point to prevent excessive rotation.
        /// </summary>
        private void CalculateCenterOfEffort()
        {
            // Start at mast foot
            Vector3 localCE = _sailConfig.MastFootPosition;
            
            // Apply mast rake - rotates the whole rig fore/aft around the mast foot
            float rakeAngle = _mastRake * _maxRakeAngle * Mathf.Deg2Rad;
            
            // Keep CE height low for stability (just above deck)
            // Real sails have high CE which causes heeling - we reduce this for gameplay
            float ceHeight = 0.3f; // Low CE for stable gameplay
            
            // With rake, the CE moves slightly fore/aft
            float ceForwardOffset = -Mathf.Sin(rakeAngle) * ceHeight;
            float ceHeightAdjusted = Mathf.Cos(rakeAngle) * ceHeight;
            
            localCE += new Vector3(0, ceHeightAdjusted, ceForwardOffset);
            
            // Minimal lateral offset - don't move CE too far to side
            // This reduces the heeling moment
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            float ceDistance = 0.1f; // Reduced from BoomLength * 0.5
            localCE += new Vector3(
                Mathf.Sin(sailAngleRad) * ceDistance,
                0,
                0 // No fore-aft shift from sail angle
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
                transform.forward,
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
            // Mast rake creates a turning moment because it moves the CE fore/aft relative to CLR
            // In real windsurfing:
            // - Rake BACK (positive _mastRake) = CE moves aft = bow turns DOWNWIND (bear away)
            // - Rake FORWARD (negative _mastRake) = CE moves forward = bow turns UPWIND (head up)
            //
            // The turning direction depends on which tack we're on:
            // - Starboard tack (AWA > 0, wind from right, sail on left): bear away = turn LEFT (negative Y torque)
            // - Port tack (AWA < 0, wind from left, sail on right): bear away = turn RIGHT (positive Y torque)
            //
            // So the torque sign should match the WIND side, not the sail side.
            // Wind side = Sign(AWA): +1 if wind from starboard, -1 if wind from port
            // Bear away = turn TOWARD the sail (away from wind) = OPPOSITE to wind side
            // So: torque = rake * (-Sign(AWA)) = rake * sailSide
            
            float forceMag = _state.SailForce.magnitude;
            
            // SailSide = -Sign(AWA), so sailSide gives us the correct turn direction for bear away
            // When raking back (positive rake), multiply by sailSide to turn toward the sail
            float tack = _state.SailSide != 0 ? _state.SailSide : 1f;
            
            // HIGH-SPEED STABILITY: Reduce steering sensitivity at high speeds
            float speedKnots = _state.BoatSpeed * PhysicsConstants.MS_TO_KNOTS;
            float steeringScale = 1f;
            if (speedKnots > 15f)
            {
                steeringScale = Mathf.Lerp(1f, 0.3f, (speedKnots - 15f) / 10f);
                steeringScale = Mathf.Max(steeringScale, 0.3f);
            }
            
            // Torque proportional to force and rake amount
            float steeringTorque = _mastRake * tack * forceMag * 0.5f * steeringScale;
            
            // Base steering torque that works even without sail force
            float baseSteeringTorque = _mastRake * tack * 150f * steeringScale;
            
            // Additional speed-based steering (faster = more responsive, but capped at high speed)
            float speedTorque = _mastRake * tack * Mathf.Min(_state.BoatSpeed, 10f) * 30f * steeringScale;
            
            _rigidbody.AddTorque(Vector3.up * (steeringTorque + baseSteeringTorque + speedTorque), ForceMode.Force);
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
        /// Enable or disable automatic sail trim.
        /// </summary>
        public void SetAutoTrim(bool enabled)
        {
            _autoTrim = enabled;
        }
        
        /// <summary>
        /// Toggle auto-trim mode.
        /// </summary>
        public void ToggleAutoTrim()
        {
            _autoTrim = !_autoTrim;
        }
        
        /// <summary>
        /// Calculate optimal sheet position for current apparent wind angle.
        /// Goal: Set sail at ~15-17° angle of attack for best L/D ratio.
        /// </summary>
        private float CalculateOptimalSheetPosition()
        {
            float absAWA = Mathf.Abs(_state.ApparentWindAngle);
            
            // Optimal angle of attack is ~15-17° for upwind, increasing for downwind
            float optimalAoA = 17f;
            
            // Sail angle from centerline = AWA - AoA
            // This puts the sail at the correct angle to the wind
            float optimalSailAngle = absAWA - optimalAoA;
            
            // Clamp to physical limits
            optimalSailAngle = Mathf.Clamp(optimalSailAngle, 12f, 85f);
            
            // Convert sail angle to sheet position (inverse of the Lerp in CalculateSailGeometry)
            // Sheet position = (sailAngle - minAngle) / (maxAngle - minAngle)
            float minAngle = 12f;
            float maxAngle = 85f;
            float sheetPosition = (optimalSailAngle - minAngle) / (maxAngle - minAngle);
            
            return Mathf.Clamp01(sheetPosition);
        }
        
        /// <summary>
        /// Get whether auto-trim is enabled.
        /// </summary>
        public bool IsAutoTrimEnabled => _autoTrim;
        
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
        /// <summary>
        /// Always draw force vectors in Scene view (not just when selected)
        /// </summary>
        private void OnDrawGizmos()
        {
            if (!_showDebug || !_showForceVectors) return;
            if (!Application.isPlaying || _state == null) return;
            
            // Draw sail force (cyan - total)
            Gizmos.color = Color.cyan;
            Gizmos.DrawRay(_centerOfEffort, _state.SailForce * _forceVectorScale);
            DrawArrowHead(_centerOfEffort + _state.SailForce * _forceVectorScale, _state.SailForce.normalized, 0.3f);
            
            // Draw lift (green) and drag (red)
            Gizmos.color = Color.green;
            Gizmos.DrawRay(_centerOfEffort, _state.SailLift * _forceVectorScale);
            
            Gizmos.color = Color.red;
            Gizmos.DrawRay(_centerOfEffort, _state.SailDrag * _forceVectorScale);
            
            // Draw apparent wind (blue)
            Gizmos.color = new Color(0.3f, 0.5f, 1f);
            Vector3 windStart = transform.position + Vector3.up * 2f;
            Gizmos.DrawRay(windStart, _state.ApparentWind * 0.5f);
            DrawArrowHead(windStart + _state.ApparentWind * 0.5f, _state.ApparentWind.normalized, 0.2f);
            
            // Draw CE marker
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(_centerOfEffort, 0.1f);
            
            // ========================================
            // SAIL ORIENTATION DEBUG
            // ========================================
            DrawSailDebug();
        }
        
        /// <summary>
        /// Draw detailed sail orientation for debugging camber and flip direction.
        /// </summary>
        private void DrawSailDebug()
        {
            Vector3 mastBase = transform.TransformPoint(_sailConfig.MastFootPosition);
            float boomLen = _sailConfig.BoomLength;
            
            // Calculate sail chord direction in world space
            float sailAngleRad = _currentSailAngle * Mathf.Deg2Rad;
            Vector3 localChord = new Vector3(
                Mathf.Sin(sailAngleRad),
                0,
                -Mathf.Cos(sailAngleRad)
            ).normalized;
            Vector3 worldChord = transform.TransformDirection(localChord);
            
            // Boom end point
            Vector3 boomStart = mastBase + Vector3.up * _sailConfig.BoomHeight;
            Vector3 boomEnd = boomStart + worldChord * boomLen;
            
            // Draw boom (sail chord line) - WHITE
            Gizmos.color = Color.white;
            Gizmos.DrawLine(boomStart, boomEnd);
            
            // Draw sail normal (perpendicular to chord) - MAGENTA
            // This shows which way the "camber" side of the sail faces (towards wind)
            Gizmos.color = Color.magenta;
            Vector3 normalStart = (boomStart + boomEnd) * 0.5f;
            Gizmos.DrawRay(normalStart, _sailNormal * 1.5f);
            DrawArrowHead(normalStart + _sailNormal * 1.5f, _sailNormal, 0.2f);
            
            // CAMBER INDICATOR - Draw curved line to show sail shape
            // Camber faces the wind (convex side towards wind)
            // The sail normal should point towards wind, so camber bulges in normal direction
            Gizmos.color = new Color(1f, 0.5f, 0f); // Orange for camber
            float camberDepth = boomLen * _sailConfig.Camber * 0.5f;
            Vector3 mid = (boomStart + boomEnd) * 0.5f;
            Vector3 camberPeak = mid + _sailNormal * camberDepth;
            
            // Draw simplified sail outline (curved shape: luff -> camber peak -> leech)
            Gizmos.DrawLine(boomStart, camberPeak);
            Gizmos.DrawLine(camberPeak, boomEnd);
            
            // Draw marker at camber peak
            Gizmos.DrawWireSphere(camberPeak, 0.1f);
            
            // Draw apparent wind direction at sail position - BLUE
            Gizmos.color = new Color(0.3f, 0.7f, 1f);
            Vector3 awDir = _state.ApparentWind.normalized;
            Gizmos.DrawRay(normalStart, awDir * 2f);
            DrawArrowHead(normalStart + awDir * 2f, awDir, 0.15f);
            
            // TACK INDICATOR
            // Positive sail angle = sail on starboard side = Port tack (wind from port)
            // Negative sail angle = sail on port side = Starboard tack (wind from starboard)
            bool isStarboardTack = _currentSailAngle < 0;
            string tackName = isStarboardTack ? "STARBOARD TACK" : "PORT TACK";
            Gizmos.color = isStarboardTack ? Color.green : Color.red;
            Vector3 tackIndicatorPos = transform.position + Vector3.up * 0.5f;
            Gizmos.DrawWireCube(tackIndicatorPos + transform.right * (isStarboardTack ? -1f : 1f) * 0.3f, Vector3.one * 0.15f);
            
            // LABEL: Show sail state
            string sheeting = $"Sheet: {_sheetPosition * 100:F0}% (Angle: {_currentSailAngle:F0}°)";
            string aoa = $"AoA: {_state.AngleOfAttack:F1}°";
            string awaInfo = $"AWA: {_state.ApparentWindAngle:F0}°";
            string camberInfo = $"Camber: {_sailConfig.Camber * 100:F0}%";
            string normalCheck = Vector3.Dot(_sailNormal, -awDir) > 0 ? "✓ Normal faces wind" : "✗ Normal WRONG";
            
            UnityEditor.Handles.color = Color.white;
            UnityEditor.Handles.Label(boomEnd + Vector3.up * 0.5f,
                $"{tackName}\n{sheeting}\n{aoa}\n{awaInfo}\n{camberInfo}\n{normalCheck}");
        }
        
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
                    // Draw sail normal
                    Gizmos.color = Color.magenta;
                    Gizmos.DrawRay(_centerOfEffort, _sailNormal * 2f);
                    
                    // Labels
                    UnityEditor.Handles.Label(_centerOfEffort + Vector3.up * 2f,
                        $"AoA: {_state.AngleOfAttack:F1}°\n" +
                        $"AWA: {_state.ApparentWindAngle:F1}°\n" +
                        $"AWS: {_state.ApparentWindSpeed:F1} m/s\n" +
                        $"Drive: {_state.DriveForce:F0} N\n" +
                        $"Side: {_state.SideForce:F0} N\n" +
                        $"Rake: {_mastRake:F2}");
                }
            }
        }
        
        private void DrawArrowHead(Vector3 pos, Vector3 direction, float size)
        {
            if (direction.sqrMagnitude < 0.001f) return;
            Vector3 right = Vector3.Cross(Vector3.up, direction).normalized;
            Vector3 back = -direction.normalized;
            Gizmos.DrawRay(pos, (back + right) * size);
            Gizmos.DrawRay(pos, (back - right) * size);
        }
#endif
    }
}
