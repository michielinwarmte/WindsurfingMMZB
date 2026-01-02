using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Player
{
    /// <summary>
    /// Simple windsurfing controller for intuitive gameplay.
    /// 
    /// Controls:
    /// - A/D or Left/Right: Steer (combined rake + weight)
    /// - W/S or Up/Down: Sheet in/out (power control)
    /// - Q/E: Fine mast rake control
    /// - T: Toggle auto-sheet
    /// 
    /// All assists are enabled for stable, fun gameplay.
    /// </summary>
    public class AdvancedWindsurferController : MonoBehaviour
    {
        [Header("Physics Components")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private AdvancedFin _fin;
        [SerializeField] private AdvancedHullDrag _hull;
        [SerializeField] private Rigidbody _rigidbody;
        
        [Header("Sheet Control (W/S)")]
        [Tooltip("Speed of sheet adjustment")]
        [SerializeField] private float _sheetControlSpeed = 0.8f;
        
        [Tooltip("Enable auto-sheet to optimal angle")]
        [SerializeField] private bool _autoSheet = false;
        
        [Tooltip("Auto-sheet response speed")]
        [SerializeField] private float _autoSheetSpeed = 0.3f;
        
        [Header("Steering Control (A/D)")]
        [Tooltip("Speed of rake adjustment")]
        [SerializeField] private float _rakeControlSpeed = 2f;
        
        [Tooltip("Auto-center rake when no input")]
        [SerializeField] private bool _autoCenterRake = true;
        
        [Tooltip("Rake center speed")]
        [SerializeField] private float _rakeCenterSpeed = 1f;
        
        [Header("Weight Shift")]
        [Tooltip("Maximum weight shift angle")]
        [SerializeField] private float _maxWeightShift = 20f;
        
        [Tooltip("Weight shift response speed")]
        [SerializeField] private float _weightShiftSpeed = 4f;
        
        [Tooltip("Weight shift steering torque")]
        [SerializeField] private float _weightShiftTorque = 30f;
        
        [Header("Stability")]
        [Tooltip("Prevent capsizing (limits heel angle)")]
        [SerializeField] private bool _antiCapsize = true;
        
        [Tooltip("Maximum heel angle before correction")]
        [SerializeField] private float _maxHeelAngle = 45f;
        
        [Tooltip("Correction strength")]
        [SerializeField] private float _anticapsizeStrength = 50f;
        
        [Header("Input Smoothing")]
        [SerializeField] private float _inputSmoothing = 8f;
        
        // Input state
        private float _sheetInput;
        private float _rakeInput;
        private float _weightInput;
        private float _smoothSheetInput;
        private float _smoothRakeInput;
        private float _smoothWeightInput;
        
        // State
        private float _currentWeightShift;
        private float _currentSheetPosition;
        private float _currentRake;
        
        // Input System
        private Keyboard _keyboard;
        
        // Public accessors
        public float CurrentWeightShift => _currentWeightShift;
        public SailingState SailingState => _sail?.State;
        
        private void Awake()
        {
            // Find components if not assigned
            if (_rigidbody == null) _rigidbody = GetComponent<Rigidbody>();
            if (_sail == null) _sail = GetComponent<AdvancedSail>();
            if (_fin == null) _fin = GetComponent<AdvancedFin>();
            if (_hull == null) _hull = GetComponent<AdvancedHullDrag>();
            
            _keyboard = Keyboard.current;
        }
        
        private void Start()
        {
            // Validate required components
            if (_sail == null)
            {
                Debug.LogError($"AdvancedWindsurferController on {gameObject.name}: No AdvancedSail found! " +
                    "Sail controls will not work.");
            }
            if (_rigidbody == null)
            {
                Debug.LogError($"AdvancedWindsurferController on {gameObject.name}: No Rigidbody found!");
                enabled = false;
            }
        }
        
        private void Update()
        {
            ReadInput();
            SmoothInput();
        }
        
        private void FixedUpdate()
        {
            ApplyControls();
            
            if (_antiCapsize)
            {
                ApplyAnticapsize();
            }
        }
        
        /// <summary>
        /// Read raw input from keyboard.
        /// </summary>
        private void ReadInput()
        {
            if (_keyboard == null)
            {
                _keyboard = Keyboard.current;
                if (_keyboard == null) return;
            }
            
            // Sheet control: W/S - controls sail angle relative to WIND
            // W = sheet in (sail closer to wind direction, less power)
            // S = sheet out (sail further from wind direction, more power)
            _sheetInput = 0f;
            if (_keyboard.wKey.isPressed || _keyboard.upArrowKey.isPressed)
                _sheetInput = -1f; // Sheet in (smaller angle to wind)
            else if (_keyboard.sKey.isPressed || _keyboard.downArrowKey.isPressed)
                _sheetInput = 1f; // Ease out (larger angle to wind)
            
            // Steering: A/D controls combined steering (rake + weight)
            // On port tack (sail on starboard), invert steering so A/D work correctly
            _rakeInput = 0f;
            _weightInput = 0f;
            
            // Check if we're on port tack (CurrentTack == -1 means port tack)
            bool isPortTack = _sail != null && !_sail.IsStarboardTack;
            float steerDirection = isPortTack ? -1f : 1f; // Invert on port tack
            
            if (_keyboard.dKey.isPressed || _keyboard.rightArrowKey.isPressed)
            {
                _rakeInput = 1f * steerDirection;  // Turn right (or inverted on port tack)
                _weightInput = 1f * steerDirection;
            }
            else if (_keyboard.aKey.isPressed || _keyboard.leftArrowKey.isPressed)
            {
                _rakeInput = -1f * steerDirection; // Turn left (or inverted on port tack)
                _weightInput = -1f * steerDirection;
            }
            
            // Q/E for fine rake control (optional)
            if (_keyboard.eKey.isPressed)
                _rakeInput = 1f;
            else if (_keyboard.qKey.isPressed)
                _rakeInput = -1f;
            
            // SPACE key switches tacks (flips sail to other side)
            if (_keyboard.spaceKey.wasPressedThisFrame)
            {
                _sail.SwitchTack();
            }
            
            // T key toggles auto-sheet
            if (_keyboard.tKey.wasPressedThisFrame)
            {
                _autoSheet = !_autoSheet;
                UnityEngine.Debug.Log($"Auto-sheet: {(_autoSheet ? "ENABLED" : "DISABLED")}");
            }
        }
        
        /// <summary>
        /// Smooth input for natural feel.
        /// </summary>
        private void SmoothInput()
        {
            float dt = Time.deltaTime;
            _smoothSheetInput = Mathf.MoveTowards(_smoothSheetInput, _sheetInput, _inputSmoothing * dt);
            _smoothRakeInput = Mathf.MoveTowards(_smoothRakeInput, _rakeInput, _inputSmoothing * dt);
            _smoothWeightInput = Mathf.MoveTowards(_smoothWeightInput, _weightInput, _inputSmoothing * dt);
        }
        
        /// <summary>
        /// Apply control inputs to physics components.
        /// </summary>
        private void ApplyControls()
        {
            float dt = Time.fixedDeltaTime;
            
            // Sheet control
            if (_autoSheet && Mathf.Abs(_smoothSheetInput) < 0.1f)
            {
                // Auto-sheet to optimal angle
                float optimalSheet = _sail.GetOptimalSheetPosition();
                _currentSheetPosition = Mathf.MoveTowards(_currentSheetPosition, optimalSheet, _autoSheetSpeed * dt);
            }
            else
            {
                // Manual sheet control
                _currentSheetPosition += _smoothSheetInput * _sheetControlSpeed * dt;
                _currentSheetPosition = Mathf.Clamp01(_currentSheetPosition);
            }
            _sail.SetSheetPosition(_currentSheetPosition);
            
            // Rake control
            if (Mathf.Abs(_smoothRakeInput) > 0.1f)
            {
                _currentRake += _smoothRakeInput * _rakeControlSpeed * dt;
                _currentRake = Mathf.Clamp(_currentRake, -1f, 1f);
            }
            else if (_autoCenterRake)
            {
                // Auto-center
                _currentRake = Mathf.MoveTowards(_currentRake, 0f, _rakeCenterSpeed * dt);
            }
            _sail.SetMastRake(_currentRake);
            
            // Weight shift
            float targetWeight = _smoothWeightInput * _maxWeightShift;
            _currentWeightShift = Mathf.MoveTowards(_currentWeightShift, targetWeight, _weightShiftSpeed * _maxWeightShift * dt);
            
            ApplyWeightShift();
        }
        
        /// <summary>
        /// Apply weight shift effects.
        /// </summary>
        private void ApplyWeightShift()
        {
            if (Mathf.Abs(_currentWeightShift) < 0.5f) return;
            
            // Weight shift creates a turning moment
            float speed = _rigidbody.linearVelocity.magnitude;
            
            // Base steering that ALWAYS works, even when stopped
            // This simulates shifting the rig/body to turn
            float baseSteeringTorque = 80f; // Works even at zero speed
            
            // Additional speed-based steering (more effective at speed)
            float speedFactor = Mathf.Clamp01(speed / 3f);
            float speedTorque = _currentWeightShift * _weightShiftTorque * speedFactor / _maxWeightShift;
            
            // Combine: always have base steering, plus speed bonus
            float torque = (_currentWeightShift / _maxWeightShift) * baseSteeringTorque + speedTorque;
            
            _rigidbody.AddTorque(Vector3.up * torque, ForceMode.Force);
            
            // Also affects fin efficiency slightly
            // (weight shift changes hull trim and fin loading)
        }
        
        /// <summary>
        /// Prevent the board from capsizing by simulating sailor weight shift.
        /// The sailor automatically leans out to counter heeling moments.
        /// </summary>
        private void ApplyAnticapsize()
        {
            // Get current heel angle (roll around forward axis)
            Vector3 right = transform.right;
            float heelAngle = Vector3.SignedAngle(Vector3.up, 
                Vector3.ProjectOnPlane(transform.up, transform.forward).normalized, 
                transform.forward);
            
            // AUTOMATIC COUNTER-HEELING: Sailor leans out proportionally to heel
            // This simulates the sailor's natural balance response
            // Even before hitting max heel, apply counter-force
            if (Mathf.Abs(heelAngle) > 5f) // Dead zone for small angles
            {
                // Counter-torque proportional to heel angle
                // Stronger as heel increases (sailor leans out more)
                float counterFactor = Mathf.Clamp01(Mathf.Abs(heelAngle) / _maxHeelAngle);
                float counterTorque = heelAngle * _anticapsizeStrength * 0.5f * counterFactor;
                
                // Apply counter-torque (opposite to heel direction)
                _rigidbody.AddTorque(transform.forward * -counterTorque, ForceMode.Force);
            }
            
            // HARD LIMIT: Strong correction if exceeding max heel
            if (Mathf.Abs(heelAngle) > _maxHeelAngle)
            {
                // Apply strong corrective torque
                float excess = Mathf.Abs(heelAngle) - _maxHeelAngle;
                float correctionTorque = excess * _anticapsizeStrength * 2f * -Mathf.Sign(heelAngle);
                
                _rigidbody.AddTorque(transform.forward * correctionTorque, ForceMode.Force);
            }
        }
        
        /// <summary>
        /// Get a summary of the current sailing state for UI.
        /// </summary>
        public string GetStateDescription()
        {
            if (_sail?.State == null) return "No data";
            
            var state = _sail.State;
            string planing = _hull?.IsPlaning == true ? "PLANING" : "Displacement";
            
            // Sheet In % where 100% = fully sheeted in (close), 0% = fully eased out
            float sheetInPercent = (1f - _currentSheetPosition) * 100f;
            
            return $"Speed: {state.BoatSpeed * PhysicsConstants.MS_TO_KNOTS:F1} kts\n" +
                   $"AWA: {state.ApparentWindAngle:F0}°\n" +
                   $"VMG: {state.VMG * PhysicsConstants.MS_TO_KNOTS:F1} kts\n" +
                   $"Sheet In: {sheetInPercent:F0}%\n" +
                   $"Rake: {_currentRake:F1}\n" +
                   $"Leeway: {_fin?.LeewayAngle:F1}°\n" +
                   $"{planing}";
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // ========================================
            // COORDINATE SYSTEM DEBUG
            // ========================================
            Vector3 pos = transform.position;
            
            // Draw board coordinate axes
            // FORWARD (Z) = BLUE - direction board travels
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(pos, transform.forward * 3f);
            UnityEditor.Handles.Label(pos + transform.forward * 3.2f, "FORWARD (Z)");
            
            // RIGHT (X) = RED - starboard side
            Gizmos.color = Color.red;
            Gizmos.DrawRay(pos, transform.right * 1.5f);
            UnityEditor.Handles.Label(pos + transform.right * 1.7f, "RIGHT (X)");
            
            // UP (Y) = GREEN
            Gizmos.color = Color.green;
            Gizmos.DrawRay(pos, transform.up * 1f);
            UnityEditor.Handles.Label(pos + transform.up * 1.2f, "UP (Y)");
            
            // Draw velocity direction
            if (Application.isPlaying && _rigidbody != null)
            {
                Vector3 vel = _rigidbody.linearVelocity;
                if (vel.magnitude > 0.3f)
                {
                    Gizmos.color = Color.yellow;
                    Gizmos.DrawRay(pos + Vector3.up * 0.2f, vel.normalized * 2f);
                    UnityEditor.Handles.Label(pos + Vector3.up * 0.2f + vel.normalized * 2.2f, 
                        $"VEL ({vel.magnitude:F1} m/s)");
                }
            }
            
            // Draw weight shift indicator
            if (Application.isPlaying && Mathf.Abs(_currentWeightShift) > 0.5f)
            {
                Vector3 shiftPos = transform.position + Vector3.up * 1.5f;
                Vector3 shiftDir = transform.right * (_currentWeightShift / _maxWeightShift);
                
                Gizmos.color = Color.magenta;
                Gizmos.DrawRay(shiftPos, shiftDir);
                Gizmos.DrawWireSphere(shiftPos + shiftDir, 0.1f);
            }
            
            // Labels
            UnityEditor.Handles.Label(pos + Vector3.up * 2f,
                $"Board axes check:\n" +
                $"Blue = Forward (+Z) = bow direction\n" +
                $"Red = Right (+X) = starboard\n" +
                $"Yellow = Velocity direction");
        }
#endif
    }
}
