using UnityEngine;

namespace WindsurfingGame.Physics.Wind
{
    /// <summary>
    /// Manages the global wind in the scene.
    /// Provides wind speed and direction with optional variation.
    /// </summary>
    public class WindManager : MonoBehaviour, IWindProvider
    {
        [Header("Base Wind Settings")]
        [Tooltip("Base wind speed in meters per second")]
        [SerializeField] private float _baseWindSpeed = 8f;
        
        [Tooltip("Wind direction in degrees (0 = North/+Z, 90 = East/+X)")]
        [SerializeField] private float _windDirectionDegrees = 45f;

        [Header("Wind Variation")]
        [Tooltip("Enable natural wind variation (gusts)")]
        [SerializeField] private bool _enableVariation = true;
        
        [Tooltip("How much wind speed can vary (±percentage)")]
        [Range(0f, 0.5f)]
        [SerializeField] private float _speedVariation = 0.2f;
        
        [Tooltip("How much wind direction can vary (±degrees)")]
        [Range(0f, 30f)]
        [SerializeField] private float _directionVariation = 10f;
        
        [Tooltip("How quickly gusts change (lower = smoother)")]
        [SerializeField] private float _gustFrequency = 0.1f;

        [Header("Debug Visualization")]
        [SerializeField] private bool _showWindGizmo = true;
        [SerializeField] private float _gizmoScale = 5f;

        // Cached values
        private Vector3 _windDirection;
        private float _noiseOffsetSpeed;
        private float _noiseOffsetDirection;

        // Properties
        public Vector3 WindDirection => _windDirection;
        public float WindSpeed => _baseWindSpeed;
        public float WindSpeedKnots => _baseWindSpeed * Core.PhysicsConstants.MS_TO_KNOTS;

        // Singleton for easy access (optional pattern)
        public static WindManager Instance { get; private set; }

        private void Awake()
        {
            // Simple singleton
            if (Instance == null)
            {
                Instance = this;
            }
            else if (Instance != this)
            {
                Debug.LogWarning("Multiple WindManagers in scene. Using first one.");
            }

            // Initialize noise offsets randomly for variation
            _noiseOffsetSpeed = Random.Range(0f, 1000f);
            _noiseOffsetDirection = Random.Range(0f, 1000f);

            UpdateWindDirection();
        }

        private void OnValidate()
        {
            UpdateWindDirection();
        }

        private void Update()
        {
            // Update noise offsets for continuous variation
            if (_enableVariation)
            {
                _noiseOffsetSpeed += Time.deltaTime * _gustFrequency;
                _noiseOffsetDirection += Time.deltaTime * _gustFrequency * 0.5f;
            }
        }

        private void UpdateWindDirection()
        {
            // Convert degrees to direction vector
            float radians = _windDirectionDegrees * Mathf.Deg2Rad;
            _windDirection = new Vector3(Mathf.Sin(radians), 0, Mathf.Cos(radians)).normalized;
        }

        /// <summary>
        /// Gets the wind vector at a given position.
        /// Includes variation if enabled.
        /// </summary>
        public Vector3 GetWindAtPosition(Vector3 worldPosition)
        {
            float speed = _baseWindSpeed;
            Vector3 direction = _windDirection;

            if (_enableVariation)
            {
                // Use Perlin noise for smooth, natural variation
                // Position-based noise creates spatial variation
                float posNoise = Mathf.PerlinNoise(
                    worldPosition.x * 0.01f + _noiseOffsetSpeed,
                    worldPosition.z * 0.01f
                );

                // Time-based noise creates temporal variation (gusts)
                float timeNoise = Mathf.PerlinNoise(_noiseOffsetSpeed, 0);

                // Combine noises (0.5 is the "neutral" point of Perlin noise)
                float combinedNoise = (posNoise + timeNoise) * 0.5f;
                
                // Apply speed variation (-variation to +variation)
                float speedFactor = 1f + (combinedNoise - 0.5f) * 2f * _speedVariation;
                speed *= speedFactor;

                // Apply direction variation
                float dirNoise = Mathf.PerlinNoise(_noiseOffsetDirection, worldPosition.x * 0.01f);
                float dirOffset = (dirNoise - 0.5f) * 2f * _directionVariation;
                float adjustedAngle = _windDirectionDegrees + dirOffset;
                float radians = adjustedAngle * Mathf.Deg2Rad;
                direction = new Vector3(Mathf.Sin(radians), 0, Mathf.Cos(radians)).normalized;
            }

            return direction * speed;
        }

        /// <summary>
        /// Gets the current wind speed at origin (convenience method).
        /// </summary>
        public float GetCurrentWindSpeed()
        {
            return GetWindAtPosition(Vector3.zero).magnitude;
        }

        /// <summary>
        /// Sets the base wind parameters.
        /// </summary>
        public void SetWind(float speedMs, float directionDegrees)
        {
            _baseWindSpeed = speedMs;
            _windDirectionDegrees = directionDegrees;
            UpdateWindDirection();
        }

        /// <summary>
        /// Converts wind speed from knots to m/s and sets it.
        /// </summary>
        public void SetWindSpeedKnots(float knots)
        {
            _baseWindSpeed = knots * Core.PhysicsConstants.KNOTS_TO_MS;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos()
        {
            if (!_showWindGizmo) return;

            // Draw wind arrow at origin
            Vector3 start = transform.position;
            Vector3 windDir = _windDirection;
            
            if (!Application.isPlaying)
            {
                // Calculate direction in editor
                float radians = _windDirectionDegrees * Mathf.Deg2Rad;
                windDir = new Vector3(Mathf.Sin(radians), 0, Mathf.Cos(radians));
            }

            Vector3 end = start + windDir * _gizmoScale;

            // Arrow shaft
            Gizmos.color = new Color(0.5f, 0.8f, 1f, 0.8f);
            Gizmos.DrawLine(start, end);

            // Arrow head
            Vector3 right = Vector3.Cross(Vector3.up, windDir).normalized;
            Vector3 arrowHead1 = end - windDir * 0.5f + right * 0.3f;
            Vector3 arrowHead2 = end - windDir * 0.5f - right * 0.3f;
            Gizmos.DrawLine(end, arrowHead1);
            Gizmos.DrawLine(end, arrowHead2);

            // Label
            UnityEditor.Handles.Label(start + Vector3.up * 2, 
                $"Wind: {_baseWindSpeed:F1} m/s ({_baseWindSpeed * Core.PhysicsConstants.MS_TO_KNOTS:F1} kts)\n" +
                $"Direction: {_windDirectionDegrees:F0}°");
        }
#endif
    }
}
