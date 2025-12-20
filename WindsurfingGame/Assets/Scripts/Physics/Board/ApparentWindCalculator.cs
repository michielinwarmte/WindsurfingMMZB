using UnityEngine;
using WindsurfingGame.Physics.Wind;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Calculates apparent wind based on true wind and object velocity.
    /// 
    /// Apparent Wind = True Wind - Object Velocity
    /// 
    /// This is what a sailor actually feels - the combination of 
    /// real wind and the wind created by their own movement.
    /// </summary>
    public class ApparentWindCalculator : MonoBehaviour
    {
        [Header("References")]
        [Tooltip("The rigidbody to calculate apparent wind for")]
        [SerializeField] private Rigidbody _rigidbody;
        
        [Tooltip("Wind manager reference (auto-finds if empty)")]
        [SerializeField] private WindManager _windManager;

        [Header("Debug")]
        [SerializeField] private bool _showDebugVectors = true;
        [SerializeField] private float _vectorScale = 0.5f;

        // Calculated values
        private Vector3 _trueWind;
        private Vector3 _apparentWind;
        private float _apparentWindSpeed;
        private float _apparentWindAngle;

        // Public properties
        public Vector3 TrueWind => _trueWind;
        public Vector3 ApparentWind => _apparentWind;
        public float ApparentWindSpeed => _apparentWindSpeed;
        
        /// <summary>
        /// Angle between apparent wind and forward direction (degrees).
        /// 0° = head to wind, 90° = beam reach, 180° = running downwind
        /// </summary>
        public float ApparentWindAngle => _apparentWindAngle;

        private void Awake()
        {
            if (_rigidbody == null)
            {
                _rigidbody = GetComponent<Rigidbody>();
            }
        }

        private void Start()
        {
            if (_windManager == null)
            {
                _windManager = WindManager.Instance;
                if (_windManager == null)
                {
                    _windManager = FindFirstObjectByType<WindManager>();
                }
            }

            if (_windManager == null)
            {
                Debug.LogWarning($"ApparentWindCalculator on {gameObject.name}: No WindManager found!");
            }
        }

        private void FixedUpdate()
        {
            CalculateApparentWind();
        }

        private void CalculateApparentWind()
        {
            if (_windManager == null || _rigidbody == null) return;

            // Get true wind at our position
            _trueWind = _windManager.GetWindAtPosition(transform.position);

            // Apparent wind = True wind - Our velocity
            // If we're moving forward and wind is behind us, apparent wind is less
            // If we're moving into the wind, apparent wind is more
            Vector3 velocity = _rigidbody.linearVelocity;
            _apparentWind = _trueWind - velocity;

            // Calculate apparent wind speed
            _apparentWindSpeed = _apparentWind.magnitude;

            // Calculate angle to our forward direction
            if (_apparentWindSpeed > 0.1f)
            {
                // Angle between our forward and where apparent wind comes FROM
                Vector3 apparentWindFrom = -_apparentWind.normalized;
                _apparentWindAngle = Vector3.Angle(transform.forward, apparentWindFrom);
            }
            else
            {
                _apparentWindAngle = 0f;
            }
        }

        /// <summary>
        /// Gets the apparent wind direction relative to the board.
        /// Positive = wind from starboard (right), Negative = wind from port (left)
        /// </summary>
        public float GetApparentWindSide()
        {
            Vector3 apparentWindFrom = -_apparentWind.normalized;
            return Vector3.SignedAngle(transform.forward, apparentWindFrom, Vector3.up);
        }

        /// <summary>
        /// Checks if we're pointing too close to the wind (in the "no-go zone").
        /// Real windsurfers can't sail closer than ~30-40° to the wind.
        /// </summary>
        public bool IsInNoGoZone(float noGoAngle = 35f)
        {
            return _apparentWindAngle < noGoAngle;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos()
        {
            if (!_showDebugVectors || !Application.isPlaying) return;

            Vector3 pos = transform.position + Vector3.up * 2f;

            // True wind (blue)
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(pos, _trueWind * _vectorScale);
            
            // Our velocity (green)
            if (_rigidbody != null)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(pos, _rigidbody.linearVelocity * _vectorScale);
            }

            // Apparent wind (cyan)
            Gizmos.color = Color.cyan;
            Gizmos.DrawRay(pos, _apparentWind * _vectorScale);

            // Labels
            UnityEditor.Handles.Label(pos + _trueWind * _vectorScale, 
                $"True: {_trueWind.magnitude:F1} m/s");
            UnityEditor.Handles.Label(pos + _apparentWind * _vectorScale + Vector3.up * 0.5f, 
                $"Apparent: {_apparentWindSpeed:F1} m/s\nAngle: {_apparentWindAngle:F0}°");
        }
#endif
    }
}
