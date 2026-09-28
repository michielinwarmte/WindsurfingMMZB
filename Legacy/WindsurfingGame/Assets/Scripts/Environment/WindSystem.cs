using UnityEngine;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Environment
{
    /// <summary>
    /// Global wind manager that provides consistent wind data to all physics components.
    /// 
    /// Supports:
    /// - Constant wind direction/speed
    /// - Gusts and lulls (sinusoidal + random variations)
    /// - Wind shifts (gradual direction changes)
    /// - Height gradient (wind increases with height above water)
    /// </summary>
    public class WindSystem : MonoBehaviour
    {
        public static WindSystem Instance { get; private set; }
        
        [Header("Base Wind")]
        [Tooltip("True wind direction (where the wind comes FROM, 0=North, 90=East)")]
        [Range(0f, 360f)]
        [SerializeField] private float _windDirection = 270f;
        
        [Tooltip("True wind speed in knots")]
        [Range(0f, 50f)]
        [SerializeField] private float _windSpeedKnots = 15f;
        
        [Header("Variability")]
        [Tooltip("Enable gusts and lulls")]
        [SerializeField] private bool _enableGusts = true;
        
        [Tooltip("Gust intensity (0-1, proportion of base wind)")]
        [Range(0f, 0.5f)]
        [SerializeField] private float _gustIntensity = 0.2f;
        
        [Tooltip("Average gust cycle period in seconds")]
        [SerializeField] private float _gustPeriod = 8f;
        
        [Tooltip("Enable wind shifts")]
        [SerializeField] private bool _enableShifts = false;
        
        [Tooltip("Maximum shift angle")]
        [Range(0f, 30f)]
        [SerializeField] private float _maxShiftAngle = 15f;
        
        [Tooltip("Shift period in seconds")]
        [SerializeField] private float _shiftPeriod = 60f;
        
        [Header("Height Gradient")]
        [Tooltip("Enable wind speed increase with height")]
        [SerializeField] private bool _enableHeightGradient = true;
        
        [Tooltip("Reference height in meters")]
        [SerializeField] private float _referenceHeight = 1f;
        
        [Tooltip("Wind shear exponent (0.1-0.3 typical over water)")]
        [Range(0.05f, 0.4f)]
        [SerializeField] private float _shearExponent = 0.14f;
        
        [Header("Debug")]
        [SerializeField] private bool _showGizmos = true;
        
        // Current wind state
        private float _currentSpeed;
        private float _currentDirection;
        private float _gustPhase;
        private float _shiftPhase;
        
        /// <summary>
        /// Get the current true wind direction (degrees, where wind comes FROM).
        /// </summary>
        public float WindDirection => _currentDirection;
        
        /// <summary>
        /// Get the current true wind speed in m/s.
        /// </summary>
        public float WindSpeedMS => _currentSpeed;
        
        /// <summary>
        /// Get the current true wind speed in knots.
        /// </summary>
        public float WindSpeedKnots => _currentSpeed * PhysicsConstants.MS_TO_KNOTS;
        
        /// <summary>
        /// Get the base (unvarying) wind speed in m/s.
        /// </summary>
        public float BaseWindSpeedMS => _windSpeedKnots / PhysicsConstants.MS_TO_KNOTS;
        
        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            
            // Initialize current values
            _currentSpeed = _windSpeedKnots / PhysicsConstants.MS_TO_KNOTS;
            _currentDirection = _windDirection;
        }
        
        private void Update()
        {
            UpdateWind();
        }
        
        private void UpdateWind()
        {
            float baseSpeed = _windSpeedKnots / PhysicsConstants.MS_TO_KNOTS;
            
            // Gust calculation
            float gustFactor = 1f;
            if (_enableGusts)
            {
                _gustPhase += Time.deltaTime / _gustPeriod * Mathf.PI * 2f;
                
                // Combine multiple sine waves for natural feel
                float gust = Mathf.Sin(_gustPhase) * 0.6f +
                             Mathf.Sin(_gustPhase * 2.3f) * 0.3f +
                             Mathf.Sin(_gustPhase * 5.7f) * 0.1f;
                
                gustFactor = 1f + gust * _gustIntensity;
            }
            
            // Shift calculation
            float shiftAngle = 0f;
            if (_enableShifts)
            {
                _shiftPhase += Time.deltaTime / _shiftPeriod * Mathf.PI * 2f;
                
                // Slower oscillation for direction
                shiftAngle = Mathf.Sin(_shiftPhase) * _maxShiftAngle +
                             Mathf.Sin(_shiftPhase * 0.37f) * _maxShiftAngle * 0.3f;
            }
            
            _currentSpeed = baseSpeed * gustFactor;
            _currentDirection = _windDirection + shiftAngle;
        }
        
        /// <summary>
        /// Get the wind vector at a specific world position.
        /// Takes into account height gradient.
        /// </summary>
        /// <param name="position">World position to sample wind</param>
        /// <returns>Wind velocity vector (direction wind is blowing TO)</returns>
        public Vector3 GetWindAtPosition(Vector3 position)
        {
            float speed = _currentSpeed;
            
            // Height gradient
            if (_enableHeightGradient && position.y > 0.1f)
            {
                // Wind profile power law: V = V_ref * (z / z_ref)^alpha
                float heightRatio = Mathf.Max(position.y, 0.1f) / _referenceHeight;
                float heightFactor = Mathf.Pow(heightRatio, _shearExponent);
                speed *= heightFactor;
            }
            
            // Convert direction to vector (wind blows TO this direction, so we flip)
            float dirRad = (_currentDirection + 180f) * Mathf.Deg2Rad;
            Vector3 windDir = new Vector3(
                Mathf.Sin(dirRad),
                0f,
                Mathf.Cos(dirRad)
            );
            
            return windDir.normalized * speed;
        }
        
        /// <summary>
        /// Get the direction vector that the wind is coming FROM.
        /// </summary>
        public Vector3 GetWindFromDirection()
        {
            float dirRad = _currentDirection * Mathf.Deg2Rad;
            return new Vector3(
                Mathf.Sin(dirRad),
                0f,
                Mathf.Cos(dirRad)
            ).normalized;
        }
        
        /// <summary>
        /// Set the base wind parameters.
        /// </summary>
        public void SetWind(float directionDegrees, float speedKnots)
        {
            _windDirection = directionDegrees % 360f;
            _windSpeedKnots = speedKnots;
        }
        
        /// <summary>
        /// Increase/decrease wind speed.
        /// </summary>
        public void AdjustWindSpeed(float deltaKnots)
        {
            _windSpeedKnots = Mathf.Clamp(_windSpeedKnots + deltaKnots, 0f, 50f);
        }
        
        /// <summary>
        /// Rotate wind direction.
        /// </summary>
        public void AdjustWindDirection(float deltaDegrees)
        {
            _windDirection = (_windDirection + deltaDegrees) % 360f;
            if (_windDirection < 0) _windDirection += 360f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos()
        {
            if (!_showGizmos) return;
            
            // Draw wind arrow at origin
            Vector3 origin = Vector3.up * 5f;
            Vector3 windDir = GetWindFromDirection() * -1f; // Direction wind blows TO
            
            Gizmos.color = new Color(0.5f, 0.8f, 1f, 0.8f);
            
            // Main arrow
            Gizmos.DrawRay(origin, windDir * 10f);
            
            // Arrow head
            Vector3 tip = origin + windDir * 10f;
            Vector3 right = Vector3.Cross(Vector3.up, windDir).normalized;
            Gizmos.DrawRay(tip, (-windDir + right) * 2f);
            Gizmos.DrawRay(tip, (-windDir - right) * 2f);
            
            // Wind speed text handled by handles in editor script
        }
        
        private void OnDrawGizmosSelected()
        {
            // Draw height gradient visualization
            if (_enableHeightGradient)
            {
                Vector3 windDir = GetWindFromDirection() * -1f;
                
                for (float h = 0f; h <= 5f; h += 0.5f)
                {
                    float heightFactor = Mathf.Pow(h / _referenceHeight, _shearExponent);
                    float arrowLength = 3f * heightFactor;
                    
                    Vector3 pos = Vector3.up * h;
                    Gizmos.color = Color.Lerp(Color.blue, Color.cyan, h / 5f);
                    Gizmos.DrawRay(pos, windDir * arrowLength);
                }
            }
        }
#endif
    }
}
