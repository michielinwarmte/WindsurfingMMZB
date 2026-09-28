using UnityEngine;
using UnityEngine.InputSystem;

namespace WindsurfingGame.CameraSystem
{
    /// <summary>
    /// Third-person camera that follows a target with smooth movement.
    /// Designed for windsurfing - stays behind the board with adjustable offset.
    /// Uses Unity's New Input System.
    /// </summary>
    public class ThirdPersonCamera : MonoBehaviour
    {
        [Header("Target")]
        [Tooltip("The transform to follow (the windsurf board)")]
        [SerializeField] private Transform _target;

        [Header("Orbit Settings")]
        [Tooltip("Distance from target")]
        [SerializeField] private float _distance = 10f;
        
        [Tooltip("Vertical angle (pitch) in degrees")]
        [SerializeField] private float _pitch = 30f;
        
        [Tooltip("Horizontal angle (yaw) offset from target forward")]
        [SerializeField] private float _yawOffset = 0f;
        
        [Tooltip("Follow the target's rotation (stay behind)")]
        [SerializeField] private bool _followTargetRotation = true;

        [Header("Smoothing")]
        [Tooltip("How quickly the camera follows position")]
        [SerializeField] private float _positionSmoothTime = 0.1f;
        
        [Tooltip("How quickly the camera rotates")]
        [SerializeField] private float _rotationSmoothTime = 0.1f;

        [Header("Input Settings")]
        [Tooltip("Enable camera control with mouse")]
        [SerializeField] private bool _enableInput = true;
        
        [Tooltip("Mouse sensitivity")]
        [SerializeField] private float _lookSensitivity = 0.3f;
        
        [Tooltip("Zoom sensitivity")]
        [SerializeField] private float _zoomSensitivity = 2f;
        
        [Tooltip("Invert Y axis")]
        [SerializeField] private bool _invertY = false;

        [Header("Limits")]
        [Tooltip("Pitch limits (min, max)")]
        [SerializeField] private Vector2 _pitchLimits = new Vector2(5f, 80f);
        
        [Tooltip("Distance limits (min, max)")]
        [SerializeField] private Vector2 _distanceLimits = new Vector2(3f, 20f);
        
        [Tooltip("Minimum height above water")]
        [SerializeField] private float _minHeight = 1f;

        [Header("Look Target")]
        [Tooltip("Offset for where camera looks relative to target")]
        [SerializeField] private Vector3 _lookOffset = new Vector3(0, 1f, 2f);

        [Header("Water Reference")]
        [Tooltip("Reference to water surface for height check")]
        [SerializeField] private MonoBehaviour _waterSurface;

        // Input System
        private Mouse _mouse;
        private Keyboard _keyboard;
        
        // State
        private Vector3 _currentVelocity;
        private float _currentYaw;
        private float _smoothYaw;
        private float _smoothPitch;
        private float _yawVelocity;
        private float _pitchVelocity;
        
        // Water interface
        private Physics.Water.IWaterSurface _water;

        private void Start()
        {
            _mouse = Mouse.current;
            _keyboard = Keyboard.current;
            
            // Get water interface
            if (_waterSurface != null)
            {
                _water = _waterSurface as Physics.Water.IWaterSurface;
            }
            
            // Find target if not set
            if (_target == null)
            {
                Debug.Log("[ThirdPersonCamera] No target assigned, searching for windsurfer...");
                var board = FindFirstObjectByType<Physics.Buoyancy.BuoyancyBody>();
                if (board == null)
                {
                    var advBoard = FindFirstObjectByType<Physics.Buoyancy.AdvancedBuoyancy>();
                    if (advBoard != null)
                    {
                        _target = advBoard.transform;
                        Debug.Log($"[ThirdPersonCamera] Found AdvancedBuoyancy target: {_target.name}");
                    }
                    else
                    {
                        Debug.LogWarning("[ThirdPersonCamera] ❌ No target found! Camera will not work. " +
                                        "Assign a target in the Inspector or ensure a windsurfer with AdvancedBuoyancy exists.");
                    }
                }
                else
                {
                    _target = board.transform;
                    Debug.Log($"[ThirdPersonCamera] Found BuoyancyBody target: {_target.name}");
                }
            }
            else
            {
                Debug.Log($"[ThirdPersonCamera] ✓ Target assigned: {_target.name}");
            }

            // Initialize angles
            if (_target != null)
            {
                _currentYaw = _target.eulerAngles.y + _yawOffset;
                _smoothYaw = _currentYaw;
                _smoothPitch = _pitch;
                
                // Set initial position
                UpdateCameraPosition(true);
                
                Debug.Log($"[ThirdPersonCamera] ✓ Camera initialized - Distance: {_distance}m, Pitch: {_pitch}°\n" +
                         $"   Controls: Right-click + drag = Orbit, Scroll = Zoom, Middle-click = Reset");
            }
        }

        private void LateUpdate()
        {
            if (_target == null)
            {
                // Try to find target again if lost
                if (Time.frameCount % 60 == 0) // Check every second
                {
                    var advBoard = FindFirstObjectByType<Physics.Buoyancy.AdvancedBuoyancy>();
                    if (advBoard != null)
                    {
                        _target = advBoard.transform;
                        Debug.Log($"[ThirdPersonCamera] Re-acquired target: {_target.name}");
                    }
                }
                return;
            }

            HandleInput();
            UpdateCameraPosition(false);
        }

        private void HandleInput()
        {
            if (!_enableInput || _mouse == null) return;

            // Right mouse button to rotate camera
            if (_mouse.rightButton.isPressed)
            {
                Vector2 mouseDelta = _mouse.delta.ReadValue();
                
                // Horizontal rotation
                _yawOffset += mouseDelta.x * _lookSensitivity;
                
                // Vertical rotation (pitch)
                float pitchDelta = mouseDelta.y * _lookSensitivity;
                if (_invertY) pitchDelta = -pitchDelta;
                _pitch = Mathf.Clamp(_pitch - pitchDelta, _pitchLimits.x, _pitchLimits.y);
            }
            
            // Scroll to zoom
            float scrollDelta = _mouse.scroll.ReadValue().y;
            if (Mathf.Abs(scrollDelta) > 0.01f)
            {
                _distance = Mathf.Clamp(
                    _distance - scrollDelta * _zoomSensitivity * 0.01f,
                    _distanceLimits.x,
                    _distanceLimits.y
                );
            }
            
            // Reset camera with middle mouse
            if (_mouse.middleButton.wasPressedThisFrame)
            {
                _yawOffset = 0f;
                _pitch = 30f;
                _distance = 10f;
            }
        }

        private void UpdateCameraPosition(bool immediate)
        {
            // Calculate target yaw (follow target rotation if enabled)
            float targetYaw = _followTargetRotation ? _target.eulerAngles.y + _yawOffset : _yawOffset;
            
            // Smooth yaw and pitch
            if (immediate)
            {
                _smoothYaw = targetYaw;
                _smoothPitch = _pitch;
            }
            else
            {
                _smoothYaw = Mathf.SmoothDampAngle(_smoothYaw, targetYaw, ref _yawVelocity, _rotationSmoothTime);
                _smoothPitch = Mathf.SmoothDamp(_smoothPitch, _pitch, ref _pitchVelocity, _rotationSmoothTime);
            }
            
            // Calculate camera position in spherical coordinates
            float pitchRad = _smoothPitch * Mathf.Deg2Rad;
            float yawRad = _smoothYaw * Mathf.Deg2Rad;
            
            Vector3 offset = new Vector3(
                Mathf.Sin(yawRad) * Mathf.Cos(pitchRad),
                Mathf.Sin(pitchRad),
                Mathf.Cos(yawRad) * Mathf.Cos(pitchRad)
            ) * _distance;
            
            // Invert to position camera behind
            offset = -offset;
            
            Vector3 desiredPosition = _target.position + offset;
            
            // Ensure camera stays above water
            float minY = _minHeight;
            if (_water != null)
            {
                minY = _water.GetWaterHeight(desiredPosition) + _minHeight;
            }
            if (desiredPosition.y < minY)
            {
                desiredPosition.y = minY;
            }
            
            // Apply position
            if (immediate)
            {
                transform.position = desiredPosition;
            }
            else
            {
                transform.position = Vector3.SmoothDamp(
                    transform.position,
                    desiredPosition,
                    ref _currentVelocity,
                    _positionSmoothTime
                );
            }
            
            // Look at target
            Vector3 lookTarget = _target.TransformPoint(_lookOffset);
            transform.LookAt(lookTarget);
        }

        /// <summary>
        /// Set a new target to follow.
        /// </summary>
        public void SetTarget(Transform newTarget)
        {
            _target = newTarget;
            if (_target != null)
            {
                _currentYaw = _target.eulerAngles.y + _yawOffset;
                UpdateCameraPosition(true);
            }
        }

        /// <summary>
        /// Set camera distance (zoom level).
        /// </summary>
        public void SetDistance(float distance)
        {
            _distance = Mathf.Clamp(distance, _distanceLimits.x, _distanceLimits.y);
        }

        /// <summary>
        /// Reset camera to default position behind target.
        /// </summary>
        public void ResetCamera()
        {
            _yawOffset = 0f;
            _pitch = 30f;
            _distance = 10f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (_target == null) return;
            
            // Draw line to target
            Gizmos.color = Color.green;
            Gizmos.DrawLine(transform.position, _target.position);
            
            // Draw look target
            Gizmos.color = Color.yellow;
            Vector3 lookTarget = _target.TransformPoint(_lookOffset);
            Gizmos.DrawWireSphere(lookTarget, 0.3f);
            
            // Draw orbit sphere
            Gizmos.color = new Color(0, 1, 1, 0.2f);
            Gizmos.DrawWireSphere(_target.position, _distance);
        }
#endif
    }
}
