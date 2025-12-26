using UnityEngine;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Applies water drag forces to slow down the board realistically.
    /// Drag increases with speed (quadratic relationship).
    /// 
    /// Note: Lateral resistance is now primarily handled by FinPhysics.
    /// This component handles hull drag (forward resistance).
    /// </summary>
    public class WaterDrag : MonoBehaviour
    {
        [Header("Drag Coefficients")]
        [Tooltip("Forward/backward drag (lower = faster top speed)")]
        [SerializeField] private float _forwardDrag = 0.15f;
        
        [Tooltip("Sideways drag from hull (fin handles most lateral resistance)")]
        [SerializeField] private float _lateralDrag = 0.5f;
        
        [Tooltip("Vertical drag (affects sinking/rising speed)")]
        [SerializeField] private float _verticalDrag = 1f;

        [Header("Speed Effects")]
        [Tooltip("Speed at which board starts planing (reduces drag)")]
        [SerializeField] private float _planingSpeed = 4f;
        
        [Tooltip("Drag reduction when planing (0.5 = half drag)")]
        [SerializeField] private float _planingDragMultiplier = 0.4f;

        [Header("References")]
        [SerializeField] private Buoyancy.BuoyancyBody _buoyancy;

        private Rigidbody _rigidbody;
        private bool _isPlaning;

        public bool IsPlaning => _isPlaning;

        private void Awake()
        {
            // Try to get Rigidbody from this object first
            _rigidbody = GetComponent<Rigidbody>();
            
            // If not found, check for WindsurfRig parent
            if (_rigidbody == null)
            {
                var rig = GetComponentInParent<WindsurfRig>();
                if (rig != null)
                {
                    _rigidbody = rig.Rigidbody;
                }
                else
                {
                    _rigidbody = GetComponentInParent<Rigidbody>();
                }
            }
            
            if (_buoyancy == null)
            {
                _buoyancy = GetComponent<Buoyancy.BuoyancyBody>();
                if (_buoyancy == null)
                {
                    _buoyancy = GetComponentInParent<Buoyancy.BuoyancyBody>();
                }
            }
        }

        private void FixedUpdate()
        {
            // Only apply drag when in water
            if (_buoyancy != null && !_buoyancy.IsFloating)
            {
                return;
            }

            ApplyDrag();
        }

        private void ApplyDrag()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;

            if (speed < 0.01f) return;

            // Check if planing
            _isPlaning = speed > _planingSpeed;
            float planingFactor = _isPlaning ? _planingDragMultiplier : 1f;

            // Decompose velocity into local directions
            Vector3 localVelocity = transform.InverseTransformDirection(velocity);

            // Calculate drag in each direction (quadratic with speed)
            // Drag = 0.5 * Cd * v²  (simplified, no area/density for tuning ease)
            float forwardDragForce = _forwardDrag * localVelocity.z * Mathf.Abs(localVelocity.z) * planingFactor;
            float lateralDragForce = _lateralDrag * localVelocity.x * Mathf.Abs(localVelocity.x);
            float verticalDragForce = _verticalDrag * localVelocity.y * Mathf.Abs(localVelocity.y);

            // Create drag force vector (opposes motion)
            Vector3 localDragForce = new Vector3(
                -lateralDragForce,
                -verticalDragForce,
                -forwardDragForce
            );

            // Convert to world space and apply
            Vector3 worldDragForce = transform.TransformDirection(localDragForce);
            _rigidbody.AddForce(worldDragForce, ForceMode.Force);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!Application.isPlaying || _rigidbody == null) return;

            // Show planing state
            Vector3 pos = transform.position + Vector3.up * 2;
            UnityEditor.Handles.Label(pos, 
                _isPlaning ? "PLANING" : $"Speed: {_rigidbody.linearVelocity.magnitude:F1} m/s");
        }
#endif
    }
}
