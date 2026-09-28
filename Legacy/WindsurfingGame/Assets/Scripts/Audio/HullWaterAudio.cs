using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Buoyancy;

namespace WindsurfingGame.Audio
{
    /// <summary>
    /// Hull and water sounds driven by the board physics state:
    /// - Lapping: low, gurgling water noise in displacement mode, fading out when planing
    /// - Hiss: bright spray hiss that grows with planing ratio and speed
    /// - Splash: one-shot bursts when the hull slams down
    ///
    /// Reads Rigidbody velocity, AdvancedHullDrag.PlaningRatio and AdvancedBuoyancy state.
    /// Positional (3D) so the sound sits on the board.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class HullWaterAudio : MonoBehaviour
    {
        [Header("References (auto-found)")]
        [SerializeField] private Rigidbody _rigidbody;
        [SerializeField] private AdvancedHullDrag _hull;
        [SerializeField] private AdvancedBuoyancy _buoyancy;

        [Header("Lapping (displacement)")]
        [Range(0f, 1f)]
        [SerializeField] private float _lappingVolume = 0.5f;

        [Header("Hiss (planing)")]
        [Range(0f, 1f)]
        [SerializeField] private float _hissVolume = 0.7f;

        [Header("Splash")]
        [Range(0f, 1f)]
        [SerializeField] private float _splashVolume = 0.8f;

        [Tooltip("Downward speed (m/s) that counts as a slam")]
        [SerializeField] private float _impactThreshold = 0.8f;

        [SerializeField] private float _splashCooldown = 0.25f;

        [Header("3D Settings")]
        [SerializeField] private float _minDistance = 4f;
        [SerializeField] private float _maxDistance = 80f;

        private const float SMOOTHING = 5f;

        private AudioSource _lapping;
        private AudioSource _hiss;
        private AudioSource _oneShot;
        private AudioHighPassFilter _hissFilter;
        private AudioClip _lappingClip;
        private AudioClip _hissClip;
        private AudioClip[] _splashClips;

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
            _lappingClip = ProceduralAudioClips.CreateNoiseLoop("WaterLapping", 5f, 900f, 40f, true, 21);
            _hissClip = ProceduralAudioClips.CreateNoiseLoop("PlaningHiss", 4f, 0f, 800f, false, 33);
            _splashClips = new AudioClip[3];
            for (int i = 0; i < _splashClips.Length; i++)
            {
                _splashClips[i] = ProceduralAudioClips.CreateBurst($"Splash{i}", 0.7f, 0.01f, 5f, 4000f, 500f, false, 50 + i);
            }

            _lapping = CreateSource("Audio_Lapping", _lappingClip, true);
            AudioLowPassFilter lappingFilter = _lapping.gameObject.AddComponent<AudioLowPassFilter>();
            lappingFilter.cutoffFrequency = 700f;

            _hiss = CreateSource("Audio_Hiss", _hissClip, true);
            _hissFilter = _hiss.gameObject.AddComponent<AudioHighPassFilter>();
            _hissFilter.cutoffFrequency = 1200f;

            _oneShot = CreateSource("Audio_Splash", null, false);

            _lapping.Play();
            _hiss.Play();
        }

        private void Update()
        {
            if (_lapping == null || _rigidbody == null) return;

            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;
            float planing = _hull != null ? _hull.PlaningRatio : Mathf.Clamp01((speed - 4f) / 2f);
            bool floating = _buoyancy == null || _buoyancy.IsFloating;
            float blend = 1f - Mathf.Exp(-SMOOTHING * Time.deltaTime);

            // Lapping: present at rest, grows with speed, fades away when planing, with a slow gurgle
            float gurgle = 0.75f + 0.25f * Mathf.PerlinNoise(Time.time * 1.3f, 0.5f);
            float lappingTarget = floating
                ? _lappingVolume * (0.12f + 0.88f * Mathf.Clamp01(speed / 4f)) * (1f - planing * 0.85f) * gurgle
                : 0f;
            _lapping.volume = Mathf.Lerp(_lapping.volume, lappingTarget, blend);
            _lapping.pitch = 0.9f + 0.2f * Mathf.Clamp01(speed / 5f);

            // Hiss: planing spray
            float hissTarget = floating ? _hissVolume * planing * Mathf.Clamp01((speed - 3f) / 9f) : 0f;
            _hiss.volume = Mathf.Lerp(_hiss.volume, hissTarget, blend);
            _hiss.pitch = 0.9f + 0.35f * Mathf.Clamp01(speed / 14f);
            _hissFilter.cutoffFrequency = Mathf.Lerp(1000f, 2500f, planing);

            // Splash on impact
            _splashTimer -= Time.deltaTime;
            float verticalVelocity = velocity.y;
            bool slammed = _lastVerticalVelocity < -_impactThreshold && verticalVelocity > _lastVerticalVelocity + 0.4f;
            bool landed = !_wasFloating && floating && _lastVerticalVelocity < -0.5f;

            if ((slammed || landed) && floating && _splashTimer <= 0f)
            {
                float strength = Mathf.Clamp01(-_lastVerticalVelocity / 3f);
                _oneShot.pitch = Random.Range(0.9f, 1.15f);
                _oneShot.PlayOneShot(_splashClips[Random.Range(0, _splashClips.Length)], _splashVolume * (0.4f + 0.6f * strength));
                _splashTimer = _splashCooldown;
            }

            _lastVerticalVelocity = verticalVelocity;
            _wasFloating = floating;
        }

        private void OnDestroy()
        {
            if (_lappingClip != null) Destroy(_lappingClip);
            if (_hissClip != null) Destroy(_hissClip);
            if (_splashClips != null)
            {
                foreach (AudioClip clip in _splashClips)
                {
                    if (clip != null) Destroy(clip);
                }
            }
        }

        private AudioSource CreateSource(string name, AudioClip clip, bool loop)
        {
            GameObject holder = new GameObject(name);
            holder.transform.SetParent(transform, false);

            AudioSource source = holder.AddComponent<AudioSource>();
            source.clip = clip;
            source.loop = loop;
            source.playOnAwake = false;
            source.volume = 0f;
            source.spatialBlend = 0.6f;
            source.rolloffMode = AudioRolloffMode.Linear;
            source.minDistance = _minDistance;
            source.maxDistance = _maxDistance;
            source.dopplerLevel = 0f;
            source.priority = 64;

            return source;
        }
    }
}
