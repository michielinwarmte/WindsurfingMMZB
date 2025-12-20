using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Player
{
    /// <summary>
    /// Handles player input and applies it to the windsurf board.
    /// Designed for simplicity first, with room for advanced controls later.
    /// Uses Unity's new Input System.
    /// </summary>
    public class WindsurferController : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Rigidbody _rigidbody;
        [SerializeField] private Sail _sail;

        [Header("Steering")]
        [Tooltip("How quickly the board turns")]
        [SerializeField] private float _turnSpeed = 30f;
        
        [Tooltip("Turn speed multiplier at high speeds")]
        [SerializeField] private float _speedTurnMultiplier = 0.5f;

        [Header("Board Edge Control")]
        [Tooltip("Maximum edge angle in degrees")]
        [SerializeField] private float _maxEdgeAngle = 25f;
        
        [Tooltip("How quickly the board edges")]
        [SerializeField] private float _edgeSpeed = 3f;

        [Header("Input Smoothing")]
        [Tooltip("How quickly input responds (higher = snappier)")]
        [SerializeField] private float _inputSmoothing = 5f;

        [Header("Mast Rake Control")]
        [Tooltip("Auto-center mast when no input")]
        [SerializeField] private bool _autoCenterMast = true;

        // Current input values (smoothed)
        private float _steerInput;
        private float _sheetInput;
        private float _rakeInput;
        private float _currentEdgeAngle;

        // Raw input
        private float _rawSteerInput;
        private float _rawSheetInput;
        private float _rawRakeInput;

        // Input System
        private Keyboard _keyboard;

        private void Awake()
        {
            if (_rigidbody == null)
            {
                _rigidbody = GetComponent<Rigidbody>();
            }
            if (_sail == null)
            {
                _sail = GetComponentInChildren<Sail>();
            }
            
            _keyboard = Keyboard.current;
        }

        private void Update()
        {
            // Gather input every frame
            GatherInput();
            
            // Smooth the input
            SmoothInput();
        }

        private void FixedUpdate()
        {
            // Apply physics-based controls in FixedUpdate
            ApplySteering();
            ApplyEdging();
            ApplySailControl();
            ApplyMastRake();
        }

        private void GatherInput()
        {
            if (_keyboard == null)
            {
                _keyboard = Keyboard.current;
                if (_keyboard == null) return;
            }

            // Steering: A/D or Left/Right arrows
            _rawSteerInput = 0f;
            if (_keyboard.dKey.isPressed || _keyboard.rightArrowKey.isPressed)
                _rawSteerInput = 1f;
            else if (_keyboard.aKey.isPressed || _keyboard.leftArrowKey.isPressed)
                _rawSteerInput = -1f;

            // Sail sheeting: W/S or Up/Down arrows
            // W = sheet in (more power, pointing higher)
            // S = sheet out (less power, pointing lower)
            _rawSheetInput = 0f;
            if (_keyboard.wKey.isPressed || _keyboard.upArrowKey.isPressed)
                _rawSheetInput = 1f;
            else if (_keyboard.sKey.isPressed || _keyboard.downArrowKey.isPressed)
                _rawSheetInput = -1f;

            // Mast rake: Q/E
            // Q = rake forward (turn downwind / bear away)
            // E = rake back (turn upwind / head up)
            _rawRakeInput = 0f;
            if (_keyboard.qKey.isPressed)
                _rawRakeInput = -1f; // Forward = negative rake = downwind
            else if (_keyboard.eKey.isPressed)
                _rawRakeInput = 1f;  // Back = positive rake = upwind
        }

        private void SmoothInput()
        {
            // Smooth steering input for more natural feel
            _steerInput = Mathf.Lerp(_steerInput, _rawSteerInput, Time.deltaTime * _inputSmoothing);
            _sheetInput = Mathf.Lerp(_sheetInput, _rawSheetInput, Time.deltaTime * _inputSmoothing);
            _rakeInput = Mathf.Lerp(_rakeInput, _rawRakeInput, Time.deltaTime * _inputSmoothing);
        }

        private void ApplySteering()
        {
            if (Mathf.Abs(_steerInput) < 0.01f) return;

            // Calculate speed factor (turn less at high speed for realism)
            float speed = _rigidbody.linearVelocity.magnitude;
            float speedFactor = 1f / (1f + speed * _speedTurnMultiplier);

            // Apply rotation torque
            float turnAmount = _steerInput * _turnSpeed * speedFactor;
            _rigidbody.AddTorque(Vector3.up * turnAmount, ForceMode.Force);
        }

        private void ApplyEdging()
        {
            // Edge the board based on steering input
            // Edging helps with turning and generates lateral resistance
            float targetEdge = -_steerInput * _maxEdgeAngle;
            _currentEdgeAngle = Mathf.Lerp(_currentEdgeAngle, targetEdge, Time.fixedDeltaTime * _edgeSpeed);

            // Apply edge rotation (around forward axis)
            // This is visual for now - will add physics effect later
            Quaternion currentRotation = transform.rotation;
            Vector3 euler = currentRotation.eulerAngles;
            euler.z = _currentEdgeAngle;
            
            // Smoothly blend toward target edge
            Quaternion targetRotation = Quaternion.Euler(euler.x, euler.y, _currentEdgeAngle);
            _rigidbody.MoveRotation(Quaternion.Slerp(currentRotation, targetRotation, Time.fixedDeltaTime * _edgeSpeed));
        }

        private void ApplySailControl()
        {
            if (_sail == null) return;

            // W = sheet in (tighter, less sheet position)
            // S = sheet out (looser, more sheet position)
            if (_sheetInput > 0.1f)
            {
                _sail.SheetIn(_sheetInput);
            }
            else if (_sheetInput < -0.1f)
            {
                _sail.SheetOut(-_sheetInput);
            }
        }

        private void ApplyMastRake()
        {
            if (_sail == null) return;

            // Q = rake forward (downwind)
            // E = rake back (upwind)
            if (_rakeInput < -0.1f)
            {
                _sail.RakeForward(-_rakeInput);
            }
            else if (_rakeInput > 0.1f)
            {
                _sail.RakeBack(_rakeInput);
            }
            else if (_autoCenterMast)
            {
                // Auto-center mast when no input
                _sail.CenterMast();
            }
        }

        /// <summary>
        /// Get current speed in m/s.
        /// </summary>
        public float GetSpeed()
        {
            return _rigidbody != null ? _rigidbody.linearVelocity.magnitude : 0f;
        }

        /// <summary>
        /// Get current speed in knots.
        /// </summary>
        public float GetSpeedKnots()
        {
            return GetSpeed() * Utilities.PhysicsConstants.MS_TO_KNOTS;
        }

        /// <summary>
        /// Get current speed in km/h.
        /// </summary>
        public float GetSpeedKmh()
        {
            return GetSpeed() * Utilities.PhysicsConstants.MS_TO_KMH;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Draw forward direction
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(transform.position, transform.forward * 3f);

            // Draw velocity
            if (_rigidbody != null && Application.isPlaying)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(transform.position, _rigidbody.linearVelocity);
            }
        }
#endif
    }
}
