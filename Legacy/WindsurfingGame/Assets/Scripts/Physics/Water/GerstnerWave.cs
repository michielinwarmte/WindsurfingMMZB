using UnityEngine;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Physics.Water
{
    /// <summary>
    /// One Gerstner (trochoidal) wave component.
    /// 
    /// The identical maths runs on the CPU (WaterSurface height queries used by buoyancy)
    /// and on the GPU (Shaders/OceanWater.shader vertex displacement), so the rendered
    /// surface and the physics surface never disagree.
    /// 
    /// IMPORTANT: If you change the formula in GerstnerMath.Displacement(), change
    /// AccumulateGerstner() in OceanWater.shader as well.
    /// 
    /// Reference: Finch, M. "Effective Water Simulation from Physical Models", GPU Gems ch. 1
    /// </summary>
    [System.Serializable]
    public class GerstnerWave
    {
        [Tooltip("Travel direction in degrees (0 = +Z, 90 = +X). When WaterSurface aligns waves to the wind this is an offset from the wind direction.")]
        [Range(-180f, 180f)]
        public float DirectionDegrees = 0f;
        
        [Tooltip("Crest-to-crest distance in metres")]
        [Min(0.5f)]
        public float Wavelength = 10f;
        
        [Tooltip("Amplitude in metres (half of the crest-to-trough height)")]
        [Min(0f)]
        public float Amplitude = 0.1f;
        
        [Tooltip("Crest sharpness 0-1. The SUM over all waves must stay below 1 or crests fold over themselves")]
        [Range(0f, 1f)]
        public float Steepness = 0.25f;
        
        public GerstnerWave() { }
        
        public GerstnerWave(float directionDegrees, float wavelength, float amplitude, float steepness)
        {
            DirectionDegrees = directionDegrees;
            Wavelength = wavelength;
            Amplitude = amplitude;
            Steepness = steepness;
        }
        
        /// <summary>Angular wave number k = 2π / λ.</summary>
        public float WaveNumber => 2f * Mathf.PI / Mathf.Max(0.5f, Wavelength);
        
        /// <summary>Deep-water phase speed from the dispersion relation c = √(g / k).</summary>
        public float PhaseSpeed => Mathf.Sqrt(PhysicsConstants.GRAVITY / WaveNumber);
        
        /// <summary>Wave period in seconds.</summary>
        public float Period => Wavelength / Mathf.Max(0.01f, PhaseSpeed);
    }
    
    /// <summary>
    /// CPU evaluation of a set of Gerstner waves. Mirrors OceanWater.shader exactly.
    /// </summary>
    public static class GerstnerMath
    {
        /// <summary>Maximum number of waves the shader supports (_WaveA .. _WaveD).</summary>
        public const int MAX_WAVES = 4;
        
        /// <summary>Fixed-point iterations used to undo the horizontal displacement in HeightAt().</summary>
        private const int HEIGHT_QUERY_ITERATIONS = 3;
        
        /// <summary>
        /// Displacement of the surface point whose undisplaced (rest) position is (x, z).
        /// Returns (dx, dy, dz) in metres.
        /// </summary>
        /// <param name="waves">Wave parameters (up to MAX_WAVES are used)</param>
        /// <param name="directions">Unit XZ travel direction per wave (see DirectionVector)</param>
        /// <param name="x">Rest X position (world)</param>
        /// <param name="z">Rest Z position (world)</param>
        /// <param name="time">Simulation time in seconds</param>
        public static Vector3 Displacement(GerstnerWave[] waves, Vector2[] directions, float x, float z, float time)
        {
            Vector3 result = Vector3.zero;
            if (waves == null || directions == null) return result;
            
            int count = Mathf.Min(Mathf.Min(waves.Length, MAX_WAVES), directions.Length);
            for (int i = 0; i < count; i++)
            {
                GerstnerWave wave = waves[i];
                if (wave == null || wave.Amplitude <= 0f) continue;
                
                float k = wave.WaveNumber;
                float c = Mathf.Sqrt(PhysicsConstants.GRAVITY / k);
                Vector2 d = directions[i];
                float phase = k * (d.x * x + d.y * z - c * time);
                
                float sinP = Mathf.Sin(phase);
                float cosP = Mathf.Cos(phase);
                
                // Horizontal displacement scales with steepness / k (independent of amplitude),
                // so Steepness = 1 gives a fully sharp crest whatever the wave height.
                float horizontal = wave.Steepness / k * cosP;
                result.x += d.x * horizontal;
                result.z += d.y * horizontal;
                result.y += wave.Amplitude * sinP;
            }
            
            return result;
        }
        
        /// <summary>
        /// Wave height (relative to the base water level) at WORLD position (x, z).
        /// Gerstner waves move surface points sideways, so the rest position that ends up at
        /// (x, z) is found with a short fixed-point iteration before sampling the height.
        /// </summary>
        public static float HeightAt(GerstnerWave[] waves, Vector2[] directions, float x, float z, float time)
        {
            float restX = x;
            float restZ = z;
            
            for (int i = 0; i < HEIGHT_QUERY_ITERATIONS; i++)
            {
                Vector3 disp = Displacement(waves, directions, restX, restZ, time);
                restX = x - disp.x;
                restZ = z - disp.z;
            }
            
            return Displacement(waves, directions, restX, restZ, time).y;
        }
        
        /// <summary>
        /// Convert a compass-style direction (0 = +Z/North, 90 = +X/East) to a unit XZ vector.
        /// Matches WindSystem's direction convention.
        /// </summary>
        public static Vector2 DirectionVector(float degrees)
        {
            float rad = degrees * Mathf.Deg2Rad;
            return new Vector2(Mathf.Sin(rad), Mathf.Cos(rad));
        }
        
        /// <summary>Sum of steepness over active waves. Must stay below 1 to avoid folded crests.</summary>
        public static float TotalSteepness(GerstnerWave[] waves)
        {
            if (waves == null) return 0f;
            float total = 0f;
            int count = Mathf.Min(waves.Length, MAX_WAVES);
            for (int i = 0; i < count; i++)
            {
                if (waves[i] != null && waves[i].Amplitude > 0f)
                {
                    total += waves[i].Steepness;
                }
            }
            return total;
        }
        
        /// <summary>Sum of amplitudes over active waves (maximum possible crest height).</summary>
        public static float TotalAmplitude(GerstnerWave[] waves)
        {
            if (waves == null) return 0f;
            float total = 0f;
            int count = Mathf.Min(waves.Length, MAX_WAVES);
            for (int i = 0; i < count; i++)
            {
                if (waves[i] != null) total += Mathf.Max(0f, waves[i].Amplitude);
            }
            return total;
        }
    }
}
