using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Player
{
    /// <summary>
    /// Advanced windsurfing controller with realistic physics-based control.
    /// 
    /// Control Model:
    /// In real windsurfing, the sailor controls the rig through:
    /// 1. Sheet tension - controls sail power by changing angle of attack
    /// 2. Mast rake - moves center of effort fore/aft for steering
    /// 3. Body position - shifts weight for balance and fine steering
    /// 
    /// The board responds to the balance of forces:
    /// - Sail generates side force and drive force
    /// - Fin converts side force into forward motion by generating lift
    /// - Board finds equilibrium between these forces
    /// 
    /// This controller provides input handling for the physics components.
    /// </summary>
    public class AdvancedWindsurferController : MonoBehaviour
    {
        [Header("Physics Components")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private AdvancedFin _fin;
        [SerializeField] private AdvancedHullDrag _hull;
        [SerializeField] private Rigidbody _rigidbody;
        
        [Header("Control Mode")]
        [SerializeField] private ControlMode _controlMode = ControlMode.Intermediate;
        
        [Header("Sheet Control (W/S)")]
        [Tooltip("Speed of sheet adjustment")]
        [SerializeField] private float _sheetControlSpeed = 0.8f;
        
        [Tooltip("Enable auto-sheet to optimal angle")]
        [SerializeField] private bool _autoSheet = false;
        
        [Tooltip("Auto-sheet response speed")]
        [SerializeField] private float _autoSheetSpeed = 0.3f;
        
        [Header("Mast Rake Control (Q/E or A/D in beginner)")]
        [Tooltip("Speed of rake adjustment")]
        [SerializeField] private float _rakeControlSpeed = 2f;
        
        [Tooltip("Auto-center rake when no input")]
        [SerializeField] private bool _autoCenterRake = true;
        
        [Tooltip("Rake center speed")]
        [SerializeField] private float _rakeCenterSpeed = 1f;
        
        [Header("Weight Shift (A/D in advanced)")]
        [Tooltip("Maximum weight shift angle")]
        [SerializeField] private float _maxWeightShift = 20f;
        
        [Tooltip("Weight shift response speed")]
        [SerializeField] private float _weightShiftSpeed = 4f;
        
        [Tooltip("Weight shift steering torque")]
        [SerializeField] private float _weightShiftTorque = 30f;
        
        [Header("Stability Assists")]
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
        
        public enum ControlMode
        {
            Beginner,       // A/D for combined steering, W/S for sheet, auto-assists
            Intermediate,   // Q/E for rake, A/D for weight, W/S for sheet, some assists
            Advanced        // Full manual control, no assists
        }
        
        // Public accessors
        public ControlMode CurrentMode => _controlMode;
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
        
        private void Update()
        {
            ReadInput();
            SmoothInput();
            
            // Toggle control mode
            if (_keyboard != null && _keyboard.tabKey.wasPressedThisFrame)
            {
                CycleControlMode();
            }
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
            
            // Sheet control: W/S
            _sheetInput = 0f;
            if (_keyboard.wKey.isPressed || _keyboard.upArrowKey.isPressed)
                _sheetInput = -1f; // Sheet in (reduce angle)
            else if (_keyboard.sKey.isPressed || _keyboard.downArrowKey.isPressed)
                _sheetInput = 1f; // Ease out (increase angle)
            
            // Mode-dependent controls
            switch (_controlMode)
            {
                case ControlMode.Beginner:
                    // A/D controls combined steering (rake + weight)
                    _rakeInput = 0f;
                    _weightInput = 0f;
                    if (_keyboard.dKey.isPressed || _keyboard.rightArrowKey.isPressed)
                    {
                        _rakeInput = 1f;  // Turn right (rake back + weight right)
                        _weightInput = 1f;
                    }
                    else if (_keyboard.aKey.isPressed || _keyboard.leftArrowKey.isPressed)
                    {
                        _rakeInput = -1f; // Turn left (rake forward + weight left)
                        _weightInput = -1f;
                    }
                    break;
                    
                case ControlMode.Intermediate:
                case ControlMode.Advanced:
                    // Q/E for rake
                    _rakeInput = 0f;
                    if (_keyboard.eKey.isPressed)
                        _rakeInput = 1f;  // Rake back (turn upwind)
                    else if (_keyboard.qKey.isPressed)
                        _rakeInput = -1f; // Rake forward (turn downwind)
                    
                    // A/D for weight shift
                    _weightInput = 0f;
                    if (_keyboard.dKey.isPressed || _keyboard.rightArrowKey.isPressed)
                        _weightInput = 1f;  // Weight right
                    else if (_keyboard.aKey.isPressed || _keyboard.leftArrowKey.isPressed)
                        _weightInput = -1f; // Weight left
                    break;
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
            float speedFactor = Mathf.Clamp01(speed / 3f);
            
            // Torque proportional to weight shift and speed
            float torque = _currentWeightShift * _weightShiftTorque * speedFactor / _maxWeightShift;
            
            _rigidbody.AddTorque(Vector3.up * torque, ForceMode.Force);
            
            // Also affects fin efficiency slightly
            // (weight shift changes hull trim and fin loading)
        }
        
        /// <summary>
        /// Prevent the board from capsizing.
        /// </summary>
        private void ApplyAnticapsize()
        {
            // Get current heel angle
            Vector3 right = transform.right;
            float heelAngle = Vector3.SignedAngle(Vector3.up, 
                Vector3.ProjectOnPlane(transform.up, transform.forward).normalized, 
                transform.forward);
            
            if (Mathf.Abs(heelAngle) > _maxHeelAngle)
            {
                // Apply corrective torque
                float excess = Mathf.Abs(heelAngle) - _maxHeelAngle;
                float correctionTorque = excess * _anticapsizeStrength * -Mathf.Sign(heelAngle);
                
                _rigidbody.AddTorque(transform.forward * correctionTorque, ForceMode.Force);
            }
        }
        
        /// <summary>
        /// Cycle through control modes.
        /// </summary>
        private void CycleControlMode()
        {
            _controlMode = (ControlMode)(((int)_controlMode + 1) % 3);
            
            // Update auto-assist settings based on mode
            switch (_controlMode)
            {
                case ControlMode.Beginner:
                    _autoSheet = true;
                    _autoCenterRake = true;
                    _antiCapsize = true;
                    break;
                    
                case ControlMode.Intermediate:
                    _autoSheet = false;
                    _autoCenterRake = true;
                    _antiCapsize = true;
                    break;
                    
                case ControlMode.Advanced:
                    _autoSheet = false;
                    _autoCenterRake = false;
                    _antiCapsize = false;
                    break;
            }
            
            Debug.Log($"Control mode: {_controlMode}");
        }
        
        /// <summary>
        /// Get a summary of the current sailing state for UI.
        /// </summary>
        public string GetStateDescription()
        {
            if (_sail?.State == null) return "No data";
            
            var state = _sail.State;
            string mode = _controlMode.ToString();
            string planing = _hull?.IsPlaning == true ? "PLANING" : "Displacement";
            
            return $"Mode: {mode}\n" +
                   $"Speed: {state.BoatSpeed * PhysicsConstants.MS_TO_KNOTS:F1} kts\n" +
                   $"AWA: {state.ApparentWindAngle:F0}°\n" +
                   $"VMG: {state.VMG * PhysicsConstants.MS_TO_KNOTS:F1} kts\n" +
                   $"Sheet: {_currentSheetPosition * 100:F0}%\n" +
                   $"Rake: {_currentRake:F1}\n" +
                   $"Leeway: {_fin?.LeewayAngle:F1}°\n" +
                   $"{planing}";
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Draw weight shift indicator
            if (Application.isPlaying && Mathf.Abs(_currentWeightShift) > 0.5f)
            {
                Vector3 pos = transform.position + Vector3.up * 1.5f;
                Vector3 shiftDir = transform.right * (_currentWeightShift / _maxWeightShift);
                
                Gizmos.color = Color.yellow;
                Gizmos.DrawRay(pos, shiftDir);
                Gizmos.DrawWireSphere(pos + shiftDir, 0.1f);
            }
        }
#endif
    }
}
