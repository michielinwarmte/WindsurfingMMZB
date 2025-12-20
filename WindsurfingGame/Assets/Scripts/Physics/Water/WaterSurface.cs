using UnityEngine;

namespace WindsurfingGame.Physics.Water
{
    /// <summary>
    /// Main water surface component.
    /// Starts as a flat surface, will be extended with wave generation.
    /// Attach this to a plane GameObject representing the water.
    /// </summary>
    public class WaterSurface : MonoBehaviour, IWaterSurface
    {
        [Header("Water Settings")]
        [Tooltip("Base height of the water surface (Y position)")]
        [SerializeField] private float _baseHeight = 0f;

        [Header("Wave Settings (Phase 2)")]
        [Tooltip("Enable wave simulation")]
        [SerializeField] private bool _enableWaves = false;
        
        [Tooltip("Height of the waves")]
        [SerializeField] private float _waveHeight = 0.5f;
        
        [Tooltip("Length of the waves")]
        [SerializeField] private float _waveLength = 10f;
        
        [Tooltip("Speed of wave movement")]
        [SerializeField] private float _waveSpeed = 1f;
        
        [Tooltip("Direction waves travel (degrees from Z axis)")]
        [SerializeField] private float _waveDirection = 0f;

        // Cached calculations
        private float _waveFrequency;
        private Vector2 _waveDirectionVector;

        private void Awake()
        {
            // Set base height from transform position
            _baseHeight = transform.position.y;
            UpdateWaveParameters();
        }

        private void OnValidate()
        {
            // Update when values change in inspector
            UpdateWaveParameters();
        }

        private void UpdateWaveParameters()
        {
            // Precalculate wave frequency (2π / wavelength)
            _waveFrequency = 2f * Mathf.PI / Mathf.Max(0.1f, _waveLength);
            
            // Convert direction to vector
            float radians = _waveDirection * Mathf.Deg2Rad;
            _waveDirectionVector = new Vector2(Mathf.Sin(radians), Mathf.Cos(radians));
        }

        /// <summary>
        /// Gets the water height at a given world position.
        /// </summary>
        public float GetWaterHeight(Vector3 worldPosition)
        {
            if (!_enableWaves)
            {
                return _baseHeight;
            }

            return _baseHeight + CalculateWaveHeight(worldPosition.x, worldPosition.z, Time.time);
        }

        /// <summary>
        /// Gets the surface normal at a given world position.
        /// </summary>
        public Vector3 GetSurfaceNormal(Vector3 worldPosition)
        {
            if (!_enableWaves)
            {
                return Vector3.up;
            }

            // Calculate normal using finite differences
            const float delta = 0.1f;
            float heightCenter = GetWaterHeight(worldPosition);
            float heightX = GetWaterHeight(worldPosition + Vector3.right * delta);
            float heightZ = GetWaterHeight(worldPosition + Vector3.forward * delta);

            // Create tangent vectors and compute normal
            Vector3 tangentX = new Vector3(delta, heightX - heightCenter, 0);
            Vector3 tangentZ = new Vector3(0, heightZ - heightCenter, delta);
            
            return Vector3.Cross(tangentZ, tangentX).normalized;
        }

        /// <summary>
        /// Gets both height and normal in one call.
        /// </summary>
        public void GetWaterData(Vector3 worldPosition, out float height, out Vector3 normal)
        {
            height = GetWaterHeight(worldPosition);
            normal = GetSurfaceNormal(worldPosition);
        }

        /// <summary>
        /// Calculates wave height using simple sine wave.
        /// Will be upgraded to Gerstner waves in Phase 2.
        /// </summary>
        private float CalculateWaveHeight(float x, float z, float time)
        {
            // Project position onto wave direction
            float projectedPosition = x * _waveDirectionVector.x + z * _waveDirectionVector.y;
            
            // Simple sine wave: A * sin(k * x - ω * t)
            // where k = frequency, ω = speed * frequency
            float phase = _waveFrequency * projectedPosition - _waveSpeed * _waveFrequency * time;
            
            return _waveHeight * Mathf.Sin(phase);
        }

        /// <summary>
        /// Check if a point is underwater.
        /// </summary>
        public bool IsUnderwater(Vector3 worldPosition)
        {
            return worldPosition.y < GetWaterHeight(worldPosition);
        }

        /// <summary>
        /// Get how deep a point is underwater (negative if above water).
        /// </summary>
        public float GetDepth(Vector3 worldPosition)
        {
            return GetWaterHeight(worldPosition) - worldPosition.y;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Visualize water level in editor
            Gizmos.color = new Color(0, 0.5f, 1f, 0.3f);
            Vector3 center = transform.position;
            Vector3 size = new Vector3(100, 0.1f, 100);
            Gizmos.DrawCube(center, size);
        }
#endif
    }
}
