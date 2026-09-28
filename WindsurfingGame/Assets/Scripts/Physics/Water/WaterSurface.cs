using UnityEngine;
using WindsurfingGame.Environment;

namespace WindsurfingGame.Physics.Water
{
    /// <summary>
    /// Main water surface component: the single source of truth for where the water is.
    ///
    /// - Physics (buoyancy, drag, effects) query GetWaterHeight() / GetSurfaceNormal().
    /// - Rendering reads the same wave parameters through shader globals that this
    ///   component publishes every frame (see Shaders/OceanWater.shader), so the mesh you
    ///   see is exactly the surface the board floats on.
    ///
    /// Waves are Gerstner waves (see GerstnerWave.cs). Disable Enable Waves for a flat sea;
    /// the shader then only renders wind ripples that do not move vertices.
    /// Attach this to the water GameObject (the wizard also adds a WaterMeshBuilder).
    /// </summary>
    public class WaterSurface : MonoBehaviour, IWaterSurface
    {
        [Header("Water Settings")]
        [Tooltip("Base height of the water surface (Y position). Taken from the transform on Awake.")]
        [SerializeField] private float _baseHeight = 0f;

        [Header("Waves")]
        [Tooltip("Enable Gerstner wave displacement. Affects physics AND rendering together.")]
        [SerializeField] private bool _enableWaves = true;

        [Tooltip("Rotate the wave directions so the swell travels with the wind from the WindSystem")]
        [SerializeField] private bool _alignWavesToWind = true;

        [Tooltip("Up to four Gerstner wave components. Keep the sum of Steepness below 1.")]
        [SerializeField] private GerstnerWave[] _waves = CreateDefaultWaves();

        [Header("Rendering")]
        [Tooltip("Publish wave and wind parameters to shader globals every frame (required by OceanWater.shader)")]
        [SerializeField] private bool _driveShaderGlobals = true;

        // Shader global IDs - the contract with OceanWater.shader
        private static readonly int[] WaveIds =
        {
            Shader.PropertyToID("_WaveA"),
            Shader.PropertyToID("_WaveB"),
            Shader.PropertyToID("_WaveC"),
            Shader.PropertyToID("_WaveD")
        };
        private static readonly int WaveAmplitudesId = Shader.PropertyToID("_WaveAmplitudes");
        private static readonly int WaterTimeId = Shader.PropertyToID("_WaterTime");
        private static readonly int WaterWindId = Shader.PropertyToID("_WaterWind");

        private const float NORMAL_SAMPLE_DELTA = 0.1f;

        // Cached per-wave unit directions (updated when the wind shifts)
        private readonly Vector2[] _directions = new Vector2[GerstnerMath.MAX_WAVES];
        private WindSystem _windSystem;

        /// <summary>Base (still water) height in world units.</summary>
        public float BaseHeight => _baseHeight;

        /// <summary>True when Gerstner waves displace the surface.</summary>
        public bool WavesEnabled => _enableWaves;

        /// <summary>The configured wave components.</summary>
        public GerstnerWave[] Waves => _waves;

        /// <summary>Largest possible crest height above the base level (0 when waves are off).</summary>
        public float MaxWaveHeight => _enableWaves ? GerstnerMath.TotalAmplitude(_waves) : 0f;

        private void Awake()
        {
            // Set base height from transform position
            _baseHeight = transform.position.y;
            UpdateWaveDirections();
        }

        private void Start()
        {
            _windSystem = WindSystem.Instance != null ? WindSystem.Instance : FindFirstObjectByType<WindSystem>();
            UpdateWaveDirections();
            PublishShaderGlobals();
        }

        private void OnValidate()
        {
            UpdateWaveDirections();

            float steepness = GerstnerMath.TotalSteepness(_waves);
            if (steepness > 1f)
            {
                Debug.LogWarning($"WaterSurface on {gameObject.name}: total wave steepness is {steepness:F2} (above 1). " +
                    "Crests will fold over themselves - reduce Steepness on one or more waves.");
            }
        }

        private void Update()
        {
            // Wind shifts move the swell direction slowly; cheap enough to refresh every frame
            UpdateWaveDirections();

            if (_driveShaderGlobals)
            {
                PublishShaderGlobals();
            }
        }

        /// <summary>
        /// Resolve the unit travel direction of every wave, optionally relative to the wind.
        /// </summary>
        private void UpdateWaveDirections()
        {
            float baseDirection = 0f;
            if (_alignWavesToWind && _windSystem != null)
            {
                // WindSystem.WindDirection is where the wind comes FROM; waves travel with the wind
                baseDirection = _windSystem.WindDirection + 180f;
            }

            for (int i = 0; i < GerstnerMath.MAX_WAVES; i++)
            {
                float degrees = baseDirection;
                if (_waves != null && i < _waves.Length && _waves[i] != null)
                {
                    degrees += _waves[i].DirectionDegrees;
                }
                _directions[i] = GerstnerMath.DirectionVector(degrees);
            }
        }

        /// <summary>
        /// Push wave, time and wind parameters to shader globals so OceanWater.shader
        /// displaces vertices with exactly the physics wave field.
        /// </summary>
        private void PublishShaderGlobals()
        {
            Vector4 amplitudes = Vector4.zero;

            for (int i = 0; i < GerstnerMath.MAX_WAVES; i++)
            {
                GerstnerWave wave = (_waves != null && i < _waves.Length) ? _waves[i] : null;

                if (wave != null)
                {
                    Shader.SetGlobalVector(WaveIds[i], new Vector4(_directions[i].x, _directions[i].y, wave.Steepness, wave.Wavelength));
                    amplitudes[i] = _enableWaves ? wave.Amplitude : 0f;
                }
                else
                {
                    Shader.SetGlobalVector(WaveIds[i], new Vector4(0f, 1f, 0f, 10f));
                }
            }

            Shader.SetGlobalVector(WaveAmplitudesId, amplitudes);
            Shader.SetGlobalFloat(WaterTimeId, Time.time);

            // Wind for ripples and streaks: direction the wind blows TO, and speed in m/s
            Vector3 windTo = Vector3.forward;
            float windSpeed = 5f;
            if (_windSystem != null)
            {
                windTo = -_windSystem.GetWindFromDirection();
                windSpeed = _windSystem.WindSpeedMS;
            }
            Shader.SetGlobalVector(WaterWindId, new Vector4(windTo.x, windTo.z, windSpeed, 0f));
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

            return _baseHeight + GerstnerMath.HeightAt(_waves, _directions, worldPosition.x, worldPosition.z, Time.time);
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
            float heightCenter = GetWaterHeight(worldPosition);
            float heightX = GetWaterHeight(worldPosition + Vector3.right * NORMAL_SAMPLE_DELTA);
            float heightZ = GetWaterHeight(worldPosition + Vector3.forward * NORMAL_SAMPLE_DELTA);

            // Create tangent vectors and compute normal
            Vector3 tangentX = new Vector3(NORMAL_SAMPLE_DELTA, heightX - heightCenter, 0);
            Vector3 tangentZ = new Vector3(0, heightZ - heightCenter, NORMAL_SAMPLE_DELTA);

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

        /// <summary>
        /// Enable or disable waves at runtime (physics and visuals together).
        /// </summary>
        public void SetWavesEnabled(bool enabled)
        {
            _enableWaves = enabled;
        }

        /// <summary>
        /// Gentle 15-knot chop: a long swell plus three shorter wind waves, all travelling
        /// roughly downwind. Total steepness 0.7, total amplitude ~0.2 m.
        /// </summary>
        private static GerstnerWave[] CreateDefaultWaves()
        {
            return new GerstnerWave[]
            {
                new GerstnerWave(  12f, 14f,  0.10f,  0.20f),
                new GerstnerWave( -28f,  7f,  0.06f,  0.20f),
                new GerstnerWave(  40f,  3.5f, 0.03f, 0.15f),
                new GerstnerWave( -55f,  1.8f, 0.012f, 0.15f)
            };
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
