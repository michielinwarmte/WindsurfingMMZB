using UnityEngine;
using WindsurfingGame.Environment;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Audio
{
    /// <summary>
    /// Wind ambience whose loudness and tone follow the apparent wind at the sailor.
    /// Pink noise through a low-pass filter: light air is a soft, dull murmur; a strong
    /// apparent wind (planing upwind) is loud and bright. Gusts from the WindSystem come
    /// through automatically because they change the apparent wind.
    ///
    /// Played 2D (not positional) because it represents the wind in the sailor's ears.
    /// Reads AdvancedSail.State; falls back to the true wind from WindSystem.
    /// </summary>
    public class WindAmbienceAudio : MonoBehaviour
    {
        [Header("References (auto-found)")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private WindSystem _windSystem;

        [Header("Levels")]
        [Tooltip("Volume at full wind")]
        [Range(0f, 1f)]
        [SerializeField] private float _maxVolume = 0.55f;

        [Tooltip("Apparent wind speed (m/s) that reaches full volume")]
        [SerializeField] private float _fullVolumeWindSpeed = 16f;

        [Header("Tone")]
        [Tooltip("Low-pass cutoff in light air (Hz)")]
        [SerializeField] private float _minCutoff = 250f;

        [Tooltip("Low-pass cutoff at full wind (Hz)")]
        [SerializeField] private float _maxCutoff = 3200f;

        [Tooltip("How quickly the sound follows wind changes (per second)")]
        [SerializeField] private float _smoothing = 3f;

        private AudioSource _source;
        private AudioLowPassFilter _lowPass;
        private AudioClip _clip;
        private float _currentWind;

        private void Awake()
        {
            if (_sail == null) _sail = GetComponent<AdvancedSail>();
        }

        private void Start()
        {
            if (_windSystem == null)
            {
                _windSystem = WindSystem.Instance != null ? WindSystem.Instance : FindFirstObjectByType<WindSystem>();
            }

            _clip = ProceduralAudioClips.CreateNoiseLoop("WindNoise", 6f, 0f, 60f, true, 11);

            // Own child object so the filter only affects this source
            GameObject holder = new GameObject("Audio_Wind");
            holder.transform.SetParent(transform, false);

            _source = holder.AddComponent<AudioSource>();
            _source.clip = _clip;
            _source.loop = true;
            _source.playOnAwake = false;
            _source.spatialBlend = 0f;
            _source.volume = 0f;
            _source.priority = 32;

            _lowPass = holder.AddComponent<AudioLowPassFilter>();
            _lowPass.cutoffFrequency = _minCutoff;

            _source.Play();
        }

        private void Update()
        {
            if (_source == null) return;

            float wind = GetApparentWindSpeed();
            _currentWind = Mathf.Lerp(_currentWind, wind, 1f - Mathf.Exp(-_smoothing * Time.deltaTime));

            float t = Mathf.Clamp01(_currentWind / Mathf.Max(_fullVolumeWindSpeed, 0.1f));
            _source.volume = Mathf.Pow(t, 0.8f) * _maxVolume;
            _source.pitch = 0.85f + 0.3f * t;
            _lowPass.cutoffFrequency = Mathf.Lerp(_minCutoff, _maxCutoff, t * t);
        }

        private void OnDestroy()
        {
            if (_clip != null) Destroy(_clip);
        }

        private float GetApparentWindSpeed()
        {
            if (_sail != null && _sail.State != null)
            {
                return _sail.State.ApparentWindSpeed;
            }
            return _windSystem != null ? _windSystem.WindSpeedMS : 0f;
        }
    }
}
