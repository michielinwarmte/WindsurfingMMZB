using UnityEngine;
using UnityEngine.InputSystem;

namespace WindsurfingGame.CameraSystem
{
    /// <summary>
    /// Ultra-simple camera with multiple modes for debugging.
    /// Press 1-4 to switch modes, right-click+drag to orbit in Mode 2.
    /// </summary>
    public class SimpleFollowCamera : MonoBehaviour
    {
        public enum CameraMode
        {
            FixedFollow,        // Mode 1: Fixed position behind target
            OrbitManual,        // Mode 2: Manual orbit with mouse
            TopDown,            // Mode 3: Bird's eye view
            FreeLook            // Mode 4: WASD to move freely
        }

        [Header("Target")]
        [SerializeField] private Transform _target;
        
        [Header("Settings")]
        [SerializeField] private CameraMode _mode = CameraMode.FixedFollow;
        [SerializeField] private float _distance = 12f;
        [SerializeField] private float _height = 5f;
        [SerializeField] private float _smoothSpeed = 5f;
        
        [Header("Orbit Settings (Mode 2)")]
        [SerializeField] private float _orbitSensitivity = 2f;
        [SerializeField] private float _zoomSpeed = 5f;
        
        // Orbit state
        private float _orbitYaw = 0f;
        private float _orbitPitch = 30f;
        
        // Free look state
        private Vector3 _freePosition;
        private float _freeLookSpeed = 10f;
        
        private Mouse _mouse;
        private Keyboard _keyboard;
        
        // Initialization flag
        private bool _initialized = false;
        private int _initFrameCount = 0;
        private Camera _camera;

        private void Awake()
        {
            _camera = GetComponent<Camera>();
            _mouse = Mouse.current;
            _keyboard = Keyboard.current;
            
            // CRITICAL: Disable ThirdPersonCamera if it exists on the same GameObject
            // Having two camera controllers causes conflicts - only one should be active
            var thirdPersonCam = GetComponent<ThirdPersonCamera>();
            if (thirdPersonCam != null)
            {
                thirdPersonCam.enabled = false;
                Debug.Log("[SimpleFollowCamera] Disabled ThirdPersonCamera to prevent conflict");
            }
        }
        
        private void OnEnable()
        {
            // Reset initialization to force camera update when enabled
            _initialized = false;
            _initFrameCount = 0;
            
            // Try to initialize immediately
            _mouse = Mouse.current;
            _keyboard = Keyboard.current;
            
            // Disable ThirdPersonCamera again in case it was re-enabled
            var thirdPersonCam = GetComponent<ThirdPersonCamera>();
            if (thirdPersonCam != null && thirdPersonCam.enabled)
            {
                thirdPersonCam.enabled = false;
            }
            
            FindTarget();
        }

        private void Start()
        {
            // Ensure input devices are available
            if (_mouse == null) _mouse = Mouse.current;
            if (_keyboard == null) _keyboard = Keyboard.current;
            
            // Auto-find target if not set
            FindTarget();
            
            // Force immediate snap on first frame
            if (_target != null)
            {
                SnapToTarget();
            }
            
            Debug.Log($"[SimpleFollowCamera] Started in Mode: {_mode}\n" +
                     $"   Press 1 = Fixed Follow\n" +
                     $"   Press 2 = Orbit (right-click + drag)\n" +
                     $"   Press 3 = Top Down\n" +
                     $"   Press 4 = Free Look (WASD)");
        }
        
        private void FindTarget()
        {
            if (_target == null)
            {
                var buoyancy = FindFirstObjectByType<Physics.Buoyancy.AdvancedBuoyancy>();
                if (buoyancy != null)
                {
                    _target = buoyancy.transform;
                    Debug.Log($"[SimpleFollowCamera] ✓ Found target: {_target.name}");
                }
                else
                {
                    Debug.LogWarning("[SimpleFollowCamera] ⚠️ No target found yet, will retry...");
                    return;
                }
            }
            
            if (_target != null && !_initialized)
            {
                // Initialize orbit angles based on target
                _orbitYaw = _target.eulerAngles.y;
                _freePosition = _target.position + new Vector3(0, _height, -_distance);
                
                // IMMEDIATELY set camera position (don't wait for LateUpdate)
                SnapToTarget();
                _initialized = true;
                Debug.Log($"[SimpleFollowCamera] ✓ Initialized camera position for target: {_target.name}");
            }
        }
        
        /// <summary>
        /// Immediately snap camera to correct position without smoothing
        /// </summary>
        private void SnapToTarget()
        {
            if (_target == null) return;
            
            Vector3 targetPos = _target.position;
            
            switch (_mode)
            {
                case CameraMode.FixedFollow:
                    transform.position = targetPos - _target.forward * _distance + Vector3.up * _height;
                    transform.LookAt(targetPos + Vector3.up);
                    break;
                    
                case CameraMode.OrbitManual:
                    float yawRad = _orbitYaw * Mathf.Deg2Rad;
                    float pitchRad = _orbitPitch * Mathf.Deg2Rad;
                    Vector3 offset = new Vector3(
                        Mathf.Sin(yawRad) * Mathf.Cos(pitchRad),
                        Mathf.Sin(pitchRad),
                        Mathf.Cos(yawRad) * Mathf.Cos(pitchRad)
                    ) * _distance;
                    transform.position = targetPos + offset;
                    transform.LookAt(targetPos + Vector3.up);
                    break;
                    
                case CameraMode.TopDown:
                    transform.position = targetPos + Vector3.up * (_distance * 2f);
                    transform.rotation = Quaternion.Euler(90f, 0f, 0f);
                    break;
                    
                case CameraMode.FreeLook:
                    transform.position = _freePosition;
                    transform.LookAt(targetPos);
                    break;
            }
        }

        private void LateUpdate()
        {
            // Keep trying to find target if we don't have one
            if (_target == null)
            {
                FindTarget();
                if (_target == null) return;
            }
            
            // Force snap for first few frames to guarantee camera is positioned correctly
            // This fixes the issue where camera only works after changing FOV in inspector
            if (_initFrameCount < 3)
            {
                _initFrameCount++;
                SnapToTarget();
                return;
            }
            
            // Normal initialization check
            if (!_initialized)
            {
                FindTarget();
                SnapToTarget();
                _initialized = true;
            }
            
            HandleModeSwitch();
            HandleZoom();
            
            switch (_mode)
            {
                case CameraMode.FixedFollow:
                    UpdateFixedFollow();
                    break;
                case CameraMode.OrbitManual:
                    UpdateOrbitManual();
                    break;
                case CameraMode.TopDown:
                    UpdateTopDown();
                    break;
                case CameraMode.FreeLook:
                    UpdateFreeLook();
                    break;
            }
        }

        private void HandleModeSwitch()
        {
            if (_keyboard == null) return;
            
            CameraMode? newMode = null;
            
            if (_keyboard.digit1Key.wasPressedThisFrame || _keyboard.numpad1Key.wasPressedThisFrame)
                newMode = CameraMode.FixedFollow;
            else if (_keyboard.digit2Key.wasPressedThisFrame || _keyboard.numpad2Key.wasPressedThisFrame)
                newMode = CameraMode.OrbitManual;
            else if (_keyboard.digit3Key.wasPressedThisFrame || _keyboard.numpad3Key.wasPressedThisFrame)
                newMode = CameraMode.TopDown;
            else if (_keyboard.digit4Key.wasPressedThisFrame || _keyboard.numpad4Key.wasPressedThisFrame)
                newMode = CameraMode.FreeLook;
            
            if (newMode.HasValue && newMode.Value != _mode)
            {
                _mode = newMode.Value;
                Debug.Log($"[SimpleFollowCamera] Mode changed to: {_mode}");
                
                if (_mode == CameraMode.FreeLook)
                    _freePosition = transform.position;
            }
        }

        private void HandleZoom()
        {
            if (_mouse == null) return;
            
            float scroll = _mouse.scroll.ReadValue().y;
            if (Mathf.Abs(scroll) > 0.01f)
            {
                _distance = Mathf.Clamp(_distance - scroll * _zoomSpeed * Time.deltaTime, 3f, 50f);
            }
        }

        /// <summary>
        /// Mode 1: Simple fixed position behind target
        /// </summary>
        private void UpdateFixedFollow()
        {
            // Position directly behind target
            Vector3 targetPos = _target.position;
            Vector3 behindOffset = -_target.forward * _distance + Vector3.up * _height;
            Vector3 desiredPos = targetPos + behindOffset;
            
            // Smooth follow
            transform.position = Vector3.Lerp(transform.position, desiredPos, _smoothSpeed * Time.deltaTime);
            
            // Look at target
            transform.LookAt(targetPos + Vector3.up * 1f);
        }

        /// <summary>
        /// Mode 2: Manual orbit with right mouse button
        /// </summary>
        private void UpdateOrbitManual()
        {
            // Handle orbit input
            if (_mouse != null && _mouse.rightButton.isPressed)
            {
                Vector2 delta = _mouse.delta.ReadValue();
                _orbitYaw += delta.x * _orbitSensitivity;
                _orbitPitch = Mathf.Clamp(_orbitPitch - delta.y * _orbitSensitivity, 5f, 85f);
            }
            
            // Calculate position using spherical coordinates
            float yawRad = _orbitYaw * Mathf.Deg2Rad;
            float pitchRad = _orbitPitch * Mathf.Deg2Rad;
            
            Vector3 offset = new Vector3(
                Mathf.Sin(yawRad) * Mathf.Cos(pitchRad),
                Mathf.Sin(pitchRad),
                Mathf.Cos(yawRad) * Mathf.Cos(pitchRad)
            ) * _distance;
            
            Vector3 desiredPos = _target.position + offset;
            
            // Smooth
            transform.position = Vector3.Lerp(transform.position, desiredPos, _smoothSpeed * Time.deltaTime);
            transform.LookAt(_target.position + Vector3.up * 1f);
        }

        /// <summary>
        /// Mode 3: Top-down bird's eye view
        /// </summary>
        private void UpdateTopDown()
        {
            Vector3 targetPos = _target.position;
            Vector3 desiredPos = targetPos + Vector3.up * (_distance * 2f);
            
            transform.position = Vector3.Lerp(transform.position, desiredPos, _smoothSpeed * Time.deltaTime);
            transform.rotation = Quaternion.Euler(90f, 0f, 0f);
        }

        /// <summary>
        /// Mode 4: Free camera with WASD controls
        /// </summary>
        private void UpdateFreeLook()
        {
            if (_keyboard == null) return;
            
            Vector3 move = Vector3.zero;
            
            if (_keyboard.wKey.isPressed) move += transform.forward;
            if (_keyboard.sKey.isPressed) move -= transform.forward;
            if (_keyboard.aKey.isPressed) move -= transform.right;
            if (_keyboard.dKey.isPressed) move += transform.right;
            if (_keyboard.spaceKey.isPressed) move += Vector3.up;
            if (_keyboard.leftCtrlKey.isPressed) move -= Vector3.up;
            
            _freePosition += move.normalized * _freeLookSpeed * Time.deltaTime;
            transform.position = _freePosition;
            
            // Right-click to look around
            if (_mouse != null && _mouse.rightButton.isPressed)
            {
                Vector2 delta = _mouse.delta.ReadValue();
                transform.Rotate(Vector3.up, delta.x * 0.5f, Space.World);
                transform.Rotate(Vector3.right, -delta.y * 0.5f, Space.Self);
            }
        }

        private void OnGUI()
        {
            // Show current mode on screen
            GUIStyle style = new GUIStyle(GUI.skin.label);
            style.fontSize = 16;
            style.normal.textColor = Color.yellow;
            
            string modeText = $"Camera Mode: {_mode}\n";
            modeText += "Press 1-4 to switch modes\n";
            
            switch (_mode)
            {
                case CameraMode.FixedFollow:
                    modeText += "Following behind target";
                    break;
                case CameraMode.OrbitManual:
                    modeText += "Right-click + drag to orbit\nScroll to zoom";
                    break;
                case CameraMode.TopDown:
                    modeText += "Bird's eye view";
                    break;
                case CameraMode.FreeLook:
                    modeText += "WASD to move, Space/Ctrl up/down\nRight-click to look";
                    break;
            }
            
            GUI.Label(new Rect(10, 10, 300, 80), modeText, style);
            
            // Debug info
            if (_target != null)
            {
                string debug = $"Target: {_target.name}\n" +
                              $"Distance: {_distance:F1}m\n" +
                              $"Cam Pos: {transform.position}";
                GUI.Label(new Rect(10, 100, 300, 60), debug, style);
            }
        }
    }
}
