using UnityEngine;

namespace WindsurfingGame.CameraSystem
{
    /// <summary>
    /// Third-person camera that follows a target with smooth movement.
    /// Designed for windsurfing - stays behind the board with adjustable offset.
    /// </summary>
    public class ThirdPersonCamera : MonoBehaviour
    {
        [Header("Target")]
        [Tooltip("The transform to follow (the windsurf board)")]
        [SerializeField] private Transform _target;

        [Header("Position Settings")]
        [Tooltip("Offset from target in target's local space")]
        [SerializeField] private Vector3 _offset = new Vector3(0, 8f, -1.46f);
        
        [Tooltip("How quickly the camera follows position")]
        [SerializeField] private float _followSpeed = 5f;
        
        [Tooltip("How quickly the camera rotates to match target")]
        [SerializeField] private float _rotationSpeed = 3f;

        [Header("Look Settings")]
        [Tooltip("Point to look at relative to target (0 = target center)")]
        [SerializeField] private Vector3 _lookOffset = new Vector3(0, 1f, 2f);

        [Header("Constraints")]
        [Tooltip("Minimum height above water")]
        [SerializeField] private float _minHeight = 1f;
        
        [Tooltip("Reference to water surface for height check")]
        [SerializeField] private MonoBehaviour _waterSurface;
        
        // Interface reference for water
        private Physics.Water.IWaterSurface _water;
        
        // Smoothing
        private Vector3 _currentVelocity;

        private void Start()
        {
            // Get water interface if assigned
            if (_waterSurface != null)
            {
                _water = _waterSurface as Physics.Water.IWaterSurface;
            }
            
            // Find target if not set
            if (_target == null)
            {
                var board = FindFirstObjectByType<Physics.Buoyancy.BuoyancyBody>();
                if (board != null)
                {
                    _target = board.transform;
                }
            }

            // Initialize position
            if (_target != null)
            {
                transform.position = GetDesiredPosition();
                transform.LookAt(GetLookTarget());
            }
        }

        private void LateUpdate()
        {
            if (_target == null) return;

            UpdatePosition();
            UpdateRotation();
        }

        private void UpdatePosition()
        {
            Vector3 desiredPosition = GetDesiredPosition();
            
            // Ensure camera stays above water
            if (_water != null)
            {
                float waterHeight = _water.GetWaterHeight(desiredPosition);
                if (desiredPosition.y < waterHeight + _minHeight)
                {
                    desiredPosition.y = waterHeight + _minHeight;
                }
            }
            else
            {
                // Fallback: use minimum absolute height
                if (desiredPosition.y < _minHeight)
                {
                    desiredPosition.y = _minHeight;
                }
            }

            // Smooth follow
            transform.position = Vector3.SmoothDamp(
                transform.position, 
                desiredPosition, 
                ref _currentVelocity, 
                1f / _followSpeed
            );
        }

        private void UpdateRotation()
        {
            Vector3 lookTarget = GetLookTarget();
            Vector3 lookDirection = lookTarget - transform.position;
            
            if (lookDirection.sqrMagnitude > 0.01f)
            {
                Quaternion targetRotation = Quaternion.LookRotation(lookDirection);
                transform.rotation = Quaternion.Slerp(
                    transform.rotation, 
                    targetRotation, 
                    _rotationSpeed * Time.deltaTime
                );
            }
        }

        private Vector3 GetDesiredPosition()
        {
            // Calculate position behind and above target
            return _target.TransformPoint(_offset);
        }

        private Vector3 GetLookTarget()
        {
            // Point slightly ahead of target
            return _target.TransformPoint(_lookOffset);
        }

        /// <summary>
        /// Set a new target to follow.
        /// </summary>
        public void SetTarget(Transform newTarget)
        {
            _target = newTarget;
        }

        /// <summary>
        /// Set camera offset (useful for zoom).
        /// </summary>
        public void SetOffset(Vector3 newOffset)
        {
            _offset = newOffset;
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
            Gizmos.DrawWireSphere(GetLookTarget(), 0.3f);
            
            // Draw desired position
            Gizmos.color = Color.cyan;
            Gizmos.DrawWireSphere(GetDesiredPosition(), 0.5f);
        }
#endif
    }
}
