using UnityEngine;
using UnityEngine.Rendering;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Buoyancy;
using WindsurfingGame.Physics.Water;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Spray, wake foam and splash particle effects driven by the board physics state.
    ///
    /// Reads only: speed and vertical motion from the Rigidbody, planing ratio from
    /// AdvancedHullDrag, submersion from AdvancedBuoyancy and the water height from
    /// WaterSurface. Everything (particle systems, material, sprite) is created at runtime,
    /// so no assets are needed.
    ///
    /// - Spray: thrown sideways and up from the forward rails, more when planing and heeled
    /// - Wake: flat foam patches left behind the tail that ride on the water surface
    /// - Splash: a burst when the hull slams down after a jump or a wave
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class BoardWakeEffects : MonoBehaviour
    {
        [Header("Physics References (auto-found)")]
        [SerializeField] private Rigidbody _rigidbody;
        [SerializeField] private AdvancedHullDrag _hull;
        [SerializeField] private AdvancedBuoyancy _buoyancy;
        [SerializeField] private WaterSurface _water;

        [Header("Board Geometry")]
        [SerializeField] private float _boardLength = 2.5f;
        [SerializeField] private float _boardWidth = 0.6f;

        [Header("Spray")]
        [SerializeField] private bool _sprayEnabled = true;

        [Tooltip("Speed (m/s) at which spray starts")]
        [SerializeField] private float _sprayStartSpeed = 2.5f;

        [Tooltip("Particles per second at 10 m/s (scales with speed squared)")]
        [SerializeField] private float _sprayRate = 90f;

        [Header("Wake")]
        [SerializeField] private bool _wakeEnabled = true;

        [Tooltip("Foam patches per second at 5 m/s")]
        [SerializeField] private float _wakeRate = 25f;

        [Tooltip("How long a wake patch stays visible (seconds)")]
        [SerializeField] private float _wakeLifetime = 4f;

        [Header("Splash")]
        [SerializeField] private bool _splashEnabled = true;

        [Tooltip("Downward speed (m/s) that counts as a slam")]
        [SerializeField] private float _impactThreshold = 0.8f;

        [Tooltip("Particles in a full-strength splash")]
        [SerializeField] private int _splashParticles = 45;

        [SerializeField] private float _splashCooldown = 0.3f;

        private const int MAX_SPRAY_PARTICLES = 3000;
        private const int MAX_WAKE_PARTICLES = 600;
        private const float RAIL_CLEARANCE = 0.25f; // rail this far above the water throws no spray

        private ParticleSystem _spray;
        private ParticleSystem _wake;
        private ParticleSystem.Particle[] _wakeBuffer;
        private Material _particleMaterial;
        private Texture2D _softCircle;

        private float _sprayAccumulator;
        private float _wakeAccumulator;
        private float _lastVerticalVelocity;
        private bool _wasFloating = true;
        private float _splashTimer;

        private void Awake()
        {
            if (_rigidbody == null) _rigidbody = GetComponent<Rigidbody>();
            if (_hull == null) _hull = GetComponent<AdvancedHullDrag>();
            if (_buoyancy == null) _buoyancy = GetComponent<AdvancedBuoyancy>();
        }

        private void Start()
        {
            if (_water == null) _water = FindFirstObjectByType<WaterSurface>();

            _particleMaterial = CreateParticleMaterial();
            _spray = CreateSystem("SprayParticles", false, MAX_SPRAY_PARTICLES, 1f,
                AnimationCurve.Linear(0f, 0.6f, 1f, 1.6f), new Color(1f, 1f, 1f, 0.85f));
            _wake = CreateSystem("WakeFoam", true, MAX_WAKE_PARTICLES, 0f,
                AnimationCurve.Linear(0f, 1f, 1f, 2.4f), new Color(1f, 1f, 1f, 0.55f));
        }

        private void Update()
        {
            if (_rigidbody == null) return;

            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;
            float planing = _hull != null ? _hull.PlaningRatio : Mathf.Clamp01((speed - 4f) / 2f);
            float submersion = _buoyancy != null ? _buoyancy.SubmergedRatio : 0.3f;
            bool floating = _buoyancy == null || _buoyancy.IsFloating;

            if (_sprayEnabled) EmitSpray(velocity, speed, planing, submersion);
            if (_wakeEnabled) EmitWake(velocity, speed, planing, submersion);
            if (_splashEnabled) DetectSplash(velocity, speed, floating);

            _lastVerticalVelocity = velocity.y;
            _wasFloating = floating;
        }

        private void LateUpdate()
        {
            PinWakeToWater();
        }

        private void OnDestroy()
        {
            if (_particleMaterial != null) Destroy(_particleMaterial);
            if (_softCircle != null) Destroy(_softCircle);
        }

        // ------------------------------------------------------------------
        // Emission
        // ------------------------------------------------------------------

        private void EmitSpray(Vector3 velocity, float speed, float planing, float submersion)
        {
            if (speed < _sprayStartSpeed || submersion < 0.03f) return;

            float speedFactor = (speed / 10f) * (speed / 10f);
            float rate = _sprayRate * speedFactor * (0.35f + 0.65f * planing);
            _sprayAccumulator += rate * Time.deltaTime;
            int count = (int)_sprayAccumulator;
            if (count == 0) return;
            _sprayAccumulator -= count;

            // The lower rail (leeward when heeled) throws most of the spray.
            // Positive roll lifts the starboard rail, so it gets fewer particles.
            float heel = transform.eulerAngles.z;
            if (heel > 180f) heel -= 360f;
            float starboardChance = 0.5f - Mathf.Clamp(heel / 30f, -0.4f, 0.4f);

            ParticleSystem.EmitParams emit = new ParticleSystem.EmitParams();

            for (int i = 0; i < count; i++)
            {
                float side = Random.value < starboardChance ? 1f : -1f;
                float along = Random.Range(-0.1f, 0.45f) * _boardLength;
                Vector3 railPoint = transform.TransformPoint(new Vector3(side * _boardWidth * 0.5f, -0.02f, along));

                if (_water != null)
                {
                    float waterHeight = _water.GetWaterHeight(railPoint);
                    if (railPoint.y - waterHeight > RAIL_CLEARANCE) continue; // rail is clear of the water
                    railPoint.y = Mathf.Max(railPoint.y, waterHeight);
                }

                Vector3 outward = transform.right * side;
                Vector3 particleVelocity = velocity * 0.55f
                    + outward * Random.Range(1.5f, 3.5f) * (0.5f + speed * 0.06f)
                    + Vector3.up * Random.Range(1.0f, 2.8f) * (0.5f + planing * 0.7f);

                emit.position = railPoint;
                emit.velocity = particleVelocity;
                emit.startLifetime = Random.Range(0.45f, 0.9f);
                emit.startSize = Random.Range(0.12f, 0.35f) * (0.7f + planing * 0.5f);
                emit.startColor = new Color(1f, 1f, 1f, Random.Range(0.5f, 0.85f));
                _spray.Emit(emit, 1);
            }

            // Rooster tail behind the fin when planing
            if (planing > 0.5f)
            {
                Vector3 finPoint = transform.TransformPoint(new Vector3(0f, -0.05f, -_boardLength * 0.4f));
                if (_water != null) finPoint.y = _water.GetWaterHeight(finPoint);

                emit.position = finPoint;
                emit.velocity = velocity * 0.3f - transform.forward * speed * 0.15f + Vector3.up * Random.Range(2f, 4f)
                    + transform.right * Random.Range(-0.6f, 0.6f);
                emit.startLifetime = Random.Range(0.5f, 0.9f);
                emit.startSize = Random.Range(0.2f, 0.45f);
                emit.startColor = new Color(1f, 1f, 1f, 0.7f);
                _spray.Emit(emit, Random.Range(1, 3));
            }
        }

        private void EmitWake(Vector3 velocity, float speed, float planing, float submersion)
        {
            if (speed < 1f || submersion < 0.03f) return;

            float rate = _wakeRate * Mathf.Clamp(speed / 5f, 0.3f, 3f);
            _wakeAccumulator += rate * Time.deltaTime;
            int count = (int)_wakeAccumulator;
            if (count == 0) return;
            _wakeAccumulator -= count;

            ParticleSystem.EmitParams emit = new ParticleSystem.EmitParams();

            for (int i = 0; i < count; i++)
            {
                Vector3 local = new Vector3(Random.Range(-0.35f, 0.35f) * _boardWidth, 0f,
                    -_boardLength * 0.5f + Random.Range(-0.2f, 0.1f));
                Vector3 tailPoint = transform.TransformPoint(local);
                tailPoint.y = (_water != null ? _water.GetWaterHeight(tailPoint) : tailPoint.y) + 0.03f;

                Vector3 drift = velocity * 0.1f + transform.right * Random.Range(-0.3f, 0.3f);
                drift.y = 0f;

                emit.position = tailPoint;
                emit.velocity = drift;
                emit.startLifetime = _wakeLifetime * Random.Range(0.7f, 1.2f);
                emit.startSize = Random.Range(0.5f, 0.9f) * (0.8f + planing * 0.6f);
                emit.startColor = new Color(1f, 1f, 1f, Random.Range(0.35f, 0.6f));
                emit.rotation = Random.Range(0f, 360f);
                _wake.Emit(emit, 1);
            }
        }

        private void DetectSplash(Vector3 velocity, float speed, bool floating)
        {
            _splashTimer -= Time.deltaTime;

            float verticalVelocity = velocity.y;
            bool slammed = _lastVerticalVelocity < -_impactThreshold && verticalVelocity > _lastVerticalVelocity + 0.4f;
            bool landed = !_wasFloating && floating && _lastVerticalVelocity < -0.5f;

            if ((slammed || landed) && floating && _splashTimer <= 0f)
            {
                float strength = Mathf.Clamp01(-_lastVerticalVelocity / 3f);
                EmitSplash(velocity, strength);
                _splashTimer = _splashCooldown;
            }
        }

        private void EmitSplash(Vector3 velocity, float strength)
        {
            int count = Mathf.RoundToInt(_splashParticles * (0.4f + 0.6f * strength));
            ParticleSystem.EmitParams emit = new ParticleSystem.EmitParams();

            for (int i = 0; i < count; i++)
            {
                Vector3 local = new Vector3(Random.Range(-0.5f, 0.5f) * _boardWidth, 0f, Random.Range(0.05f, 0.5f) * _boardLength);
                Vector3 point = transform.TransformPoint(local);
                if (_water != null) point.y = _water.GetWaterHeight(point);

                Vector3 horizontal = new Vector3(Random.Range(-1f, 1f), 0f, Random.Range(-1f, 1f)) * 1.5f;
                emit.position = point;
                emit.velocity = velocity * 0.4f + horizontal + Vector3.up * Random.Range(2f, 5f) * (0.5f + strength);
                emit.startLifetime = Random.Range(0.6f, 1.2f);
                emit.startSize = Random.Range(0.25f, 0.6f);
                emit.startColor = new Color(1f, 1f, 1f, Random.Range(0.6f, 0.9f));
                _spray.Emit(emit, 1);
            }
        }

        /// <summary>
        /// Wake patches are flat sprites; keep them on the (moving) water surface.
        /// </summary>
        private void PinWakeToWater()
        {
            if (_wake == null || _water == null || !_water.WavesEnabled) return;

            int alive = _wake.particleCount;
            if (alive == 0) return;

            if (_wakeBuffer == null || _wakeBuffer.Length < _wake.main.maxParticles)
            {
                _wakeBuffer = new ParticleSystem.Particle[_wake.main.maxParticles];
            }

            int count = _wake.GetParticles(_wakeBuffer);
            for (int i = 0; i < count; i++)
            {
                Vector3 position = _wakeBuffer[i].position;
                position.y = _water.GetWaterHeight(position) + 0.03f;
                _wakeBuffer[i].position = position;
            }
            _wake.SetParticles(_wakeBuffer, count);
        }

        // ------------------------------------------------------------------
        // Setup
        // ------------------------------------------------------------------

        private ParticleSystem CreateSystem(string name, bool flatOnWater, int maxParticles, float gravity,
            AnimationCurve sizeOverLife, Color baseColor)
        {
            GameObject holder = new GameObject(name);
            holder.transform.SetParent(transform, false);

            ParticleSystem system = holder.AddComponent<ParticleSystem>();
            system.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);

            ParticleSystem.MainModule main = system.main;
            main.loop = true;
            main.playOnAwake = false;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = maxParticles;
            main.gravityModifier = gravity;
            main.startSpeed = 0f;
            main.startLifetime = 1f;
            main.startSize = 0.3f;
            main.startColor = baseColor;
            main.startRotation3D = false;

            ParticleSystem.EmissionModule emission = system.emission;
            emission.enabled = true;
            emission.rateOverTime = 0f;
            emission.rateOverDistance = 0f;

            ParticleSystem.ShapeModule shape = system.shape;
            shape.enabled = false;

            ParticleSystem.ColorOverLifetimeModule colorOverLifetime = system.colorOverLifetime;
            colorOverLifetime.enabled = true;
            Gradient gradient = new Gradient();
            gradient.SetKeys(
                new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                new[] { new GradientAlphaKey(1f, 0f), new GradientAlphaKey(0.8f, 0.4f), new GradientAlphaKey(0f, 1f) });
            colorOverLifetime.color = gradient;

            ParticleSystem.SizeOverLifetimeModule sizeOverLifetime = system.sizeOverLifetime;
            sizeOverLifetime.enabled = true;
            sizeOverLifetime.size = new ParticleSystem.MinMaxCurve(1f, sizeOverLife);

            ParticleSystemRenderer particleRenderer = holder.GetComponent<ParticleSystemRenderer>();
            particleRenderer.renderMode = flatOnWater ? ParticleSystemRenderMode.HorizontalBillboard : ParticleSystemRenderMode.Billboard;
            particleRenderer.material = _particleMaterial;
            particleRenderer.shadowCastingMode = ShadowCastingMode.Off;
            particleRenderer.receiveShadows = false;
            particleRenderer.sortMode = ParticleSystemSortMode.Distance;

            system.Play();
            return system;
        }

        private Material CreateParticleMaterial()
        {
            _softCircle = CreateSoftCircleTexture(64);

            Shader shader = Shader.Find("Universal Render Pipeline/Particles/Unlit");
            if (shader == null) shader = Shader.Find("Sprites/Default");

            Material material = new Material(shader) { name = "WakeParticles (runtime)" };
            material.mainTexture = _softCircle;

            if (material.HasProperty("_Surface"))
            {
                // URP particle shader: alpha blended, no depth write, soft against the water
                material.SetFloat("_Surface", 1f);
                material.SetFloat("_Blend", 0f);
                material.SetOverrideTag("RenderType", "Transparent");
                material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_ZWrite", 0f);
                material.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");
                material.renderQueue = (int)RenderQueue.Transparent;

                if (material.HasProperty("_SoftParticlesEnabled"))
                {
                    material.SetFloat("_SoftParticlesEnabled", 1f);
                    material.EnableKeyword("SOFTPARTICLES_ON");
                    material.SetVector("_SoftParticleFadeParams", new Vector4(0f, 1f / 0.4f, 0f, 0f));
                }
            }

            return material;
        }

        private static Texture2D CreateSoftCircleTexture(int size)
        {
            Texture2D texture = new Texture2D(size, size, TextureFormat.RGBA32, false)
            {
                name = "SoftCircle",
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };

            float half = size * 0.5f;
            Color32[] pixels = new Color32[size * size];
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float dx = (x + 0.5f - half) / half;
                    float dy = (y + 0.5f - half) / half;
                    float distance = Mathf.Sqrt(dx * dx + dy * dy);
                    float alpha = Mathf.Clamp01(1f - distance);
                    alpha = alpha * alpha * (3f - 2f * alpha);
                    pixels[y * size + x] = new Color32(255, 255, 255, (byte)(alpha * 255f));
                }
            }

            texture.SetPixels32(pixels);
            texture.Apply();
            return texture;
        }
    }
}
