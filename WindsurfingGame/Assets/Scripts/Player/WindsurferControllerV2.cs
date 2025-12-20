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
        [SerializeField] private FinPhysics _finPhysics;

        [Header("Control Mode")]
        [Tooltip("Beginner: Simplified controls with assists\nAdvanced: Full realistic control")]
        [SerializeField] private ControlMode _controlMode = ControlMode.Beginner;

        [Header("Weight Shift (A/D)")]
        [Tooltip("How much weight shift affects turning (body lean)")]
        [SerializeField] private float _weightShiftStrength = 15f;
        
        [Tooltip("Maximum lean angle in degrees")]
        [SerializeField] private float _maxLeanAngle = 20f;
        
        [Tooltip("How quickly body weight shifts")]
        [SerializeField] private float _weightShiftSpeed = 4f;

        [Header("Edge Control")]
        [Tooltip("Edging the board increases fin effectiveness")]
        [SerializeField] private float _edgeFinBonus = 1.5f;
        
        [Tooltip("Visual roll angle when edging")]
        [SerializeField] private float _maxRollAngle = 15f;

        [Header("Beginner Assists")]
        [Tooltip("Auto-sheet to maintain optimal power")]
        [SerializeField] private bool _autoSheet = false;
        
        [Tooltip("Prevent capsizing (keep upright)")]
        [SerializeField] private bool _antiCapsize = true;
        
        [Tooltip("Steering assist - combines rake + weight automatically")]
        [SerializeField] private bool _combinedSteering = true;

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
            if (_finPhysics == null)
                _finPhysics = GetComponent<FinPhysics>();
            
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
        /// Much easier to control - just press A or D to turn!
        /// </summary>
        private void ApplyBeginnerControls()
        {
            if (_sail == null) return;

            float steer = _steerInput;

            if (_combinedSteering && Mathf.Abs(steer) > 0.1f)
            {
                // A/D combines mast rake and weight shift for easier turning
                // Turning right (D): rake mast back + lean right
                // Turning left (A): rake mast forward + lean left
                
                // Apply mast rake (main steering)
                // Right turn = positive rake = upwind tendency
                // But we want D to turn right, so we use the steering input directly
                // to create a turning torque
                float rakeAmount = steer * 0.7f; // 70% rake
                if (steer > 0)
                    _sail.RakeBack(Mathf.Abs(steer));
                else
                    _sail.RakeForward(Mathf.Abs(steer));

                // Apply weight shift for additional turning
                ApplyWeightShift(steer * 0.5f);
                
                // Apply body lean for edge control
                ApplyEdging(steer);
            }
            else if (_autoCenterMast)
            {
                _sail.CenterMast();
                ApplyWeightShift(0);
                ApplyEdging(0);
            }

            // Also allow direct Q/E for mast rake in beginner mode
            if (Mathf.Abs(_rakeInput) > 0.1f)
            {
                if (_rakeInput > 0)
                    _sail.RakeBack(Mathf.Abs(_rakeInput));
                else
                    _sail.RakeForward(Mathf.Abs(_rakeInput));
            }
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

            if (_autoSheet)
            {
                // TODO: Auto-sheet based on apparent wind angle
                // For now, just maintain current sheet
            }
            else
            {
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
                ? _rigidbody.linearVelocity.magnitude * Utilities.PhysicsConstants.MS_TO_KNOTS 
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
