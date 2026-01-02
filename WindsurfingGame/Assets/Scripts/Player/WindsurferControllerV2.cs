using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Player
{
    /// <summary>
    /// Improved windsurfer controller with unified, physics-based steering.
    /// 
    /// Control Philosophy:
    /// - Primary steering: Mast Rake (Q/E) - like real windsurfing
    /// - Fine-tuning: Weight shift / Edge (A/D) - body position
    /// - Power control: Sheet (W/S) - sail power
    /// 
    /// Key insight: In real windsurfing, you mostly steer with the SAIL position,
    /// not by forcing the board to turn. The board follows the sail.
    /// </summary>
    public class WindsurferControllerV2 : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Rigidbody _rigidbody;
        [SerializeField] private Sail _sail;
        [SerializeField] private AdvancedSail _advancedSail;
        [SerializeField] private FinPhysics _finPhysics;
        [SerializeField] private ApparentWindCalculator _apparentWind;

        [Header("Control Mode")]
        [Tooltip("Beginner: Simplified controls with assists\nAdvanced: Full realistic control")]
        [SerializeField] private ControlMode _controlMode = ControlMode.Beginner;

        [Header("Weight Shift (A/D)")]
        [Tooltip("How much weight shift affects turning (body lean)")]
        [SerializeField] private float _weightShiftStrength = 12f;
        
        [Tooltip("Maximum lean angle in degrees")]
        [SerializeField] private float _maxLeanAngle = 30f;
        
        [Tooltip("How quickly body weight shifts")]
        [SerializeField] private float _weightShiftSpeed = 6f;

        [Header("Edge Control")]
        [Tooltip("Edging the board increases fin effectiveness")]
        [SerializeField] private float _edgeFinBonus = 1.5f;
        
        [Tooltip("Visual roll angle when edging")]
        [SerializeField] private float _maxRollAngle = 15f;

        [Header("Beginner Assists")]
        [Tooltip("Auto-sheet to maintain optimal power and straight course")]
        [SerializeField] private bool _autoSheet = true;
        
        [Tooltip("Prevent capsizing (keep upright)")]
        [SerializeField] private bool _antiCapsize = true;
        
        [Tooltip("Steering assist - combines rake + weight automatically")]
        [SerializeField] private bool _combinedSteering = true;
        
        [Tooltip("Auto-stabilization - keeps board going straight when no input")]
        [SerializeField] private bool _autoStabilize = true;
        
        [Tooltip("Strength of auto-stabilization (higher = straighter)")]
        [SerializeField] private float _stabilizationStrength = 5f;

        [Header("Input Response")]
        [Tooltip("Input smoothing (higher = snappier, lower = smoother)")]
        [SerializeField] private float _inputResponsiveness = 6f;
        
        [Tooltip("Auto-center mast when no steering input")]
        [SerializeField] private bool _autoCenterMast = true;

        // Input state
        private float _steerInput;      // Combined steering (Beginner) or weight shift (Advanced)
        private float _rakeInput;       // Mast rake (Q/E in Advanced)
        private float _sheetInput;      // Sheet control (W/S)
        private float _rawSteerInput;
        private float _rawRakeInput;
        private float _rawSheetInput;

        // Physical state
        private float _currentLean;
        private float _currentRoll;

        // Input System
        private Keyboard _keyboard;

        public enum ControlMode
        {
            Beginner,   // A/D = combined steering, W/S = sheet
            Advanced    // Q/E = mast rake, A/D = weight shift, W/S = sheet
        }

        // Properties for UI/telemetry
        public float CurrentLean => _currentLean;
        public float CurrentRoll => _currentRoll;
        public ControlMode CurrentControlMode => _controlMode;

        private void Awake()
        {
            if (_rigidbody == null)
                _rigidbody = GetComponent<Rigidbody>();
            if (_sail == null)
                _sail = GetComponent<Sail>();
            if (_advancedSail == null)
                _advancedSail = GetComponent<AdvancedSail>();
            if (_finPhysics == null)
                _finPhysics = GetComponent<FinPhysics>();
            if (_apparentWind == null)
                _apparentWind = GetComponent<ApparentWindCalculator>();
            
            _keyboard = Keyboard.current;
        }

        private void Update()
        {
            GatherInput();
            SmoothInput();
        }

        private void FixedUpdate()
        {
            if (_controlMode == ControlMode.Beginner)
            {
                ApplyBeginnerControls();
                // Auto-stabilization in beginner mode - keeps board going straight
                ApplyBeginnerStabilization();
            }
            else
            {
                ApplyAdvancedControls();
            }

            ApplySheetControl();
            
            if (_antiCapsize)
            {
                ApplyAntiCapsize();
            }
        }

        private void GatherInput()
        {
            if (_keyboard == null)
            {
                _keyboard = Keyboard.current;
                if (_keyboard == null) return;
            }

            // Steering / Weight shift: A/D
            _rawSteerInput = 0f;
            if (_keyboard.dKey.isPressed || _keyboard.rightArrowKey.isPressed)
                _rawSteerInput = 1f;
            else if (_keyboard.aKey.isPressed || _keyboard.leftArrowKey.isPressed)
                _rawSteerInput = -1f;

            // Mast rake: Q/E (Advanced mode) or auto-derived (Beginner mode)
            _rawRakeInput = 0f;
            if (_keyboard.qKey.isPressed)
                _rawRakeInput = -1f;
            else if (_keyboard.eKey.isPressed)
                _rawRakeInput = 1f;

            // Sheet control: W/S
            _rawSheetInput = 0f;
            if (_keyboard.wKey.isPressed || _keyboard.upArrowKey.isPressed)
                _rawSheetInput = 1f;
            else if (_keyboard.sKey.isPressed || _keyboard.downArrowKey.isPressed)
                _rawSheetInput = -1f;

            // Toggle control mode with Tab
            if (_keyboard.tabKey.wasPressedThisFrame)
            {
                _controlMode = _controlMode == ControlMode.Beginner 
                    ? ControlMode.Advanced 
                    : ControlMode.Beginner;
                Debug.Log($"Control Mode: {_controlMode}");
            }
        }

        private void SmoothInput()
        {
            float dt = Time.deltaTime * _inputResponsiveness;
            _steerInput = Mathf.Lerp(_steerInput, _rawSteerInput, dt);
            _rakeInput = Mathf.Lerp(_rakeInput, _rawRakeInput, dt);
            _sheetInput = Mathf.Lerp(_sheetInput, _rawSheetInput, dt);
        }

        /// <summary>
        /// Beginner mode: A/D does combined steering (auto rake + weight shift).
        /// Rake direction automatically adjusts based on wind side for intuitive control.
        /// A = turn left, D = turn right, regardless of tack.
        /// </summary>
        private void ApplyBeginnerControls()
        {
            if (_sail == null) return;

            float steer = _steerInput;

            if (_combinedSteering && Mathf.Abs(steer) > 0.1f)
            {
                // Use AdvancedSail's rake control since it handles steering with tack compensation
                // AdvancedSail.ApplyRakeSteering applies: torque = _mastRake * tack * force
                // where tack = -SailSide
                //
                // On starboard (SailSide=+1, tack=-1): positive rake → negative torque → turn LEFT
                // On port (SailSide=-1, tack=+1): positive rake → positive torque → turn RIGHT
                //
                // So to turn RIGHT (D key), we need:
                //   - On starboard: NEGATIVE rake (rake forward)
                //   - On port: POSITIVE rake (rake back)
                //
                // This means we must FLIP the rake based on tack!
                float sailSide = 1f;
                if (_advancedSail != null)
                {
                    sailSide = _advancedSail.State.SailSide;
                    if (sailSide == 0) sailSide = 1f;
                }
                
                // Flip rake direction so D always turns right:
                // effectiveRake = steer * -sailSide
                // D (steer=+1): on starboard (sailSide=+1) → rake = -1 (forward)
                // D (steer=+1): on port (sailSide=-1) → rake = +1 (back)  
                float effectiveRake = steer * -sailSide;
                
                // Apply rake to AdvancedSail (the one that actually steers)
                if (_advancedSail != null)
                {
                    _advancedSail.AdjustRake(effectiveRake * 0.25f * Time.deltaTime * 5f);
                }
                // Also apply to Sail for visual consistency
                if (_sail != null)
                {
                    if (effectiveRake > 0)
                        _sail.RakeBack(Mathf.Abs(steer) * 0.25f);
                    else
                        _sail.RakeForward(Mathf.Abs(steer) * 0.25f);
                }

                // Apply weight shift for additional turning (use raw steer for visual consistency)
                ApplyWeightShift(steer * 0.15f);  // Further reduced for gentler turns
                
                // Apply body lean for edge control (use raw steer for visual consistency)
                ApplyEdging(steer);
            }
            else if (_autoCenterMast)
            {
                _sail.CenterMast();
                // Also center AdvancedSail's rake
                if (_advancedSail != null)
                {
                    _advancedSail.SetMastRake(Mathf.MoveTowards(_advancedSail.MastRake, 0f, Time.deltaTime * 2f));
                }
                ApplyWeightShift(0);
                ApplyEdging(0);
            }

            // Q/E disabled in beginner mode - use A/D to steer!
            // (Beginner mode auto-determines rake direction based on wind)
        }

        /// <summary>
        /// Advanced mode: Separate controls for mast rake and weight shift.
        /// More realistic but harder to master.
        /// </summary>
        private void ApplyAdvancedControls()
        {
            if (_sail == null) return;

            // Q/E = Mast rake (primary steering)
            if (Mathf.Abs(_rakeInput) > 0.1f)
            {
                if (_rakeInput > 0)
                    _sail.RakeBack(Mathf.Abs(_rakeInput));
                else
                    _sail.RakeForward(Mathf.Abs(_rakeInput));
            }
            else if (_autoCenterMast)
            {
                _sail.CenterMast();
            }

            // A/D = Weight shift and edge control (secondary steering)
            ApplyWeightShift(_steerInput);
            ApplyEdging(_steerInput);
        }

        /// <summary>
        /// Beginner mode stabilization - keeps the board going straight when no input.
        /// Uses rake, weight shift, and angular damping to maintain course.
        /// </summary>
        private void ApplyBeginnerStabilization()
        {
            if (!_autoStabilize) return;
            
            // Only stabilize when there's no steering input
            bool noInput = Mathf.Abs(_steerInput) < 0.05f && Mathf.Abs(_rakeInput) < 0.05f;
            
            if (noInput)
            {
                // 1. CENTER THE MAST - critical for straight sailing
                if (_sail != null)
                {
                    _sail.CenterMast();
                }
                
                // 2. NEUTRALIZE WEIGHT SHIFT - return to center
                ApplyWeightShift(0);
                ApplyEdging(0);
                
                // 3. STRONG ANGULAR DAMPING - stop any rotation
                Vector3 angularVel = _rigidbody.angularVelocity;
                float yawVelocity = angularVel.y;
                
                // Apply counter-torque to stop rotation
                float dampingTorque = -yawVelocity * _stabilizationStrength * 15f;  // Increased from 10
                _rigidbody.AddTorque(Vector3.up * dampingTorque, ForceMode.Force);
                
                // 4. DIRECT ANGULAR VELOCITY REDUCTION for immediate effect
                _rigidbody.angularVelocity = new Vector3(
                    angularVel.x,
                    angularVel.y * 0.85f,  // 15% reduction per frame (increased from 10%)
                    angularVel.z
                );
                
                // 5. RAKE-BASED STABILIZATION - use rake to counter rotation
                if (_sail != null && Mathf.Abs(yawVelocity) > 0.01f)
                {
                    // If rotating right (positive), rake forward slightly to counter
                    // If rotating left (negative), rake back slightly to counter
                    float correctionRake = -yawVelocity * 0.3f;
                    
                    if (correctionRake > 0.05f)
                        _sail.RakeBack(correctionRake);
                    else if (correctionRake < -0.05f)
                        _sail.RakeForward(-correctionRake);
                }
            }
        }

        /// <summary>
        /// Applies weight shift torque - like leaning your body.
        /// This creates a gentle turning moment.
        /// </summary>
        private void ApplyWeightShift(float input)
        {
            float targetLean = input * _maxLeanAngle;
            _currentLean = Mathf.Lerp(_currentLean, targetLean, Time.fixedDeltaTime * _weightShiftSpeed);

            if (Mathf.Abs(_currentLean) < 0.5f) return;

            // Weight shift creates a turning moment
            // Leaning right makes the board want to turn right
            float speed = _rigidbody.linearVelocity.magnitude;
            float speedFactor = Mathf.Clamp01(speed / 5f); // More effective at speed
            
            float torque = _currentLean * _weightShiftStrength * speedFactor;
            _rigidbody.AddTorque(Vector3.up * torque * Time.fixedDeltaTime, ForceMode.VelocityChange);
        }

        /// <summary>
        /// Applies visual roll/edge to the board.
        /// Edging increases fin grip and helps with turns.
        /// </summary>
        private void ApplyEdging(float input)
        {
            float targetRoll = -input * _maxRollAngle;
            _currentRoll = Mathf.Lerp(_currentRoll, targetRoll, Time.fixedDeltaTime * _weightShiftSpeed);

            // Apply roll to the rigidbody
            Vector3 euler = transform.eulerAngles;
            float targetRollAngle = _currentRoll;
            
            // Smooth roll application using AddTorque instead of MoveRotation
            // This works WITH physics instead of fighting it
            float currentZ = transform.eulerAngles.z;
            if (currentZ > 180) currentZ -= 360;
            
            float rollDiff = targetRollAngle - currentZ;
            float rollTorque = rollDiff * 2f; // Strength of roll correction
            
            _rigidbody.AddTorque(transform.forward * rollTorque, ForceMode.Force);
        }

        private void ApplySheetControl()
        {
            if (_sail == null) return;

            if (_autoSheet && _controlMode == ControlMode.Beginner)
            {
                // Intelligent auto-sheet for beginner mode
                // Adjusts sail angle to help maintain straight course
                
                // Get optimal sheet position based on apparent wind angle
                float optimalSheet = 0.5f; // Default mid position
                
                if (_apparentWind != null)
                {
                    float windAngle = _apparentWind.ApparentWindAngle;
                    
                    // Sheet in more when close to wind, out more when running
                    if (windAngle < 60)
                        optimalSheet = 0.2f;  // Close-hauled: sheet in tight
                    else if (windAngle < 90)
                        optimalSheet = 0.35f; // Close reach: partly sheeted
                    else if (windAngle < 120)
                        optimalSheet = 0.5f;  // Beam reach: mid position
                    else if (windAngle < 150)
                        optimalSheet = 0.65f; // Broad reach: let out
                    else
                        optimalSheet = 0.75f; // Running: sheet out
                }
                
                // Adjust sheet to help counter unwanted rotation
                float angularVel = _rigidbody.angularVelocity.y;
                float rotationCorrection = -angularVel * 0.05f; // Small adjustment
                optimalSheet = Mathf.Clamp01(optimalSheet + rotationCorrection);
                
                // Smoothly adjust to optimal position
                float currentSheet = _sail.SheetPosition;
                float sheetDiff = optimalSheet - currentSheet;
                
                if (Mathf.Abs(sheetDiff) > 0.02f)
                {
                    if (sheetDiff > 0)
                        _sail.SheetOut(Mathf.Abs(sheetDiff) * 2f);
                    else
                        _sail.SheetIn(Mathf.Abs(sheetDiff) * 2f);
                }
            }
            else
            {
                // Manual sheet control
                if (_sheetInput > 0.1f)
                    _sail.SheetIn(_sheetInput);
                else if (_sheetInput < -0.1f)
                    _sail.SheetOut(-_sheetInput);
            }
        }

        /// <summary>
        /// Prevents the board from capsizing by applying corrective torque
        /// when it tilts too far.
        /// </summary>
        private void ApplyAntiCapsize()
        {
            float roll = transform.eulerAngles.z;
            if (roll > 180) roll -= 360;

            // If tilted more than 30 degrees, apply corrective force
            float maxTilt = 30f;
            if (Mathf.Abs(roll) > maxTilt)
            {
                float correction = (Mathf.Abs(roll) - maxTilt) * Mathf.Sign(-roll) * 10f;
                _rigidbody.AddTorque(transform.forward * correction, ForceMode.Force);
            }

            // Also limit pitch
            float pitch = transform.eulerAngles.x;
            if (pitch > 180) pitch -= 360;
            if (Mathf.Abs(pitch) > maxTilt)
            {
                float correction = (Mathf.Abs(pitch) - maxTilt) * Mathf.Sign(-pitch) * 10f;
                _rigidbody.AddTorque(transform.right * correction, ForceMode.Force);
            }
        }

        /// <summary>
        /// Get current speed in knots.
        /// </summary>
        public float GetSpeedKnots()
        {
            return _rigidbody != null 
                ? _rigidbody.linearVelocity.magnitude * Physics.Core.PhysicsConstants.MS_TO_KNOTS 
                : 0f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (_rigidbody == null || !Application.isPlaying) return;

            Vector3 pos = transform.position;

            // Draw velocity
            Gizmos.color = Color.green;
            Gizmos.DrawRay(pos, _rigidbody.linearVelocity);

            // Draw forward
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(pos, transform.forward * 3f);

            // Draw lean direction
            Gizmos.color = Color.yellow;
            Gizmos.DrawRay(pos + Vector3.up, transform.right * _currentLean * 0.1f);
        }
#endif
    }
}
