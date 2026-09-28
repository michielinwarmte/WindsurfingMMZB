using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Core;

namespace WindsurfingGame.Audio
{
    /// <summary>
    /// Sail flapping when the sail is eased too far or the board points into the wind, plus a
    /// flurry of flaps when the rig crosses the board on a tack change.
    ///
    /// Reads AdvancedSail.State (angle of attack, apparent wind, in irons) and CurrentTack.
    /// Positional (3D) so the sound sits on the rig.
    /// </summary>
    public class SailFlapAudio : MonoBehaviour
    {
        [Header("References (auto-found)")]
        [SerializeField] private AdvancedSail _sail;

        [Header("Levels")]
        [Range(0f, 1f)]
        [SerializeField] private float _volume = 0.7f;

        [Tooltip("Apparent wind speed (m/s) at which flaps reach full volume")]
        [SerializeField] private float _fullVolumeWindSpeed = 12f;

        [Header("Luffing")]
        [Tooltip("Angle of attack (degrees) below which the sail is not filled and flaps")]
        [SerializeField] private float _luffAngleOfAttack = 6f;

        [Tooltip("Shortest and longest pause between flaps at 8 m/s (seconds)")]
        [SerializeField] private Vector2 _flapInterval = new Vector2(0.08f, 0.4f);

        [Tooltip("Number of flaps when the sail crosses the board on a tack")]
        [SerializeField] private int _tackFlapCount = 4;

        [Header("3D Settings")]
        [SerializeField] private float _minDistance = 4f;
        [SerializeField] private float _maxDistance = 80f;

        private const int FLAP_VARIANTS = 4;
        private const float REFERENCE_WIND_SPEED = 8f;
        private const float SMOOTHING = 6f;

        private AudioSource _source;
        private AudioClip[] _flapClips;
        private float _luff;
        private float _nextFlapTime;
        private int _lastTack;
        private int _pendingTackFlaps;

        /// <summary>Smoothed luffing amount 0-1.</summary>
        public float LuffAmount => _luff;

        private void Awake()
        {
            if (_sail == null) _sail = GetComponent<AdvancedSail>();
        }

        private void Start()
        {
            if (_sail == null)
            {
                Debug.LogWarning($"SailFlapAudio on {gameObject.name}: no AdvancedSail found.");
                enabled = false;
                return;
            }

            _flapClips = new AudioClip[FLAP_VARIANTS];
            for (int i = 0; i < FLAP_VARIANTS; i++)
            {
                _flapClips[i] = ProceduralAudioClips.CreateBurst($"SailFlap{i}", 0.11f, 0.004f, 28f, 2200f, 600f, false, 100 + i);
            }

            GameObject holder = new GameObject("Audio_SailFlap");
            holder.transform.SetParent(transform, false);
            holder.transform.localPosition = _sail.Config.MastFootPosition + Vector3.up * _sail.Config.BoomHeight;

            _source = holder.AddComponent<AudioSource>();
            _source.playOnAwake = false;
            _source.loop = false;
            _source.spatialBlend = 0.6f;
            _source.rolloffMode = AudioRolloffMode.Linear;
            _source.minDistance = _minDistance;
            _source.maxDistance = _maxDistance;
            _source.dopplerLevel = 0f;
            _source.priority = 48;

            _lastTack = _sail.CurrentTack;
        }

        private void Update()
        {
            if (_source == null) return;

            SailingState state = _sail.State;
            if (state == null) return;

            float apparentWind = state.ApparentWindSpeed;
            float angleOfAttack = Mathf.Abs(state.AngleOfAttack);

            // Luffing amount, same rule as SailDeformer so sound and cloth agree
            float targetLuff = 0f;
            if (apparentWind > 2f)
            {
                if (angleOfAttack < _luffAngleOfAttack || state.IsInIrons)
                {
                    targetLuff = 1f;
                }
                else if (angleOfAttack < _luffAngleOfAttack * 2f)
                {
                    targetLuff = 1f - (angleOfAttack - _luffAngleOfAttack) / _luffAngleOfAttack;
                }
            }
            _luff = Mathf.Lerp(_luff, targetLuff, 1f - Mathf.Exp(-SMOOTHING * Time.deltaTime));

            float windLevel = Mathf.Clamp01(apparentWind / Mathf.Max(_fullVolumeWindSpeed, 0.1f));

            // Tack change: the sail swings across and cracks a few times
            if (_sail.CurrentTack != _lastTack)
            {
                _lastTack = _sail.CurrentTack;
                _pendingTackFlaps = _tackFlapCount;
                _nextFlapTime = Time.time;
            }

            if (_pendingTackFlaps > 0)
            {
                if (Time.time >= _nextFlapTime)
                {
                    PlayFlap(_volume * (0.5f + 0.5f * windLevel));
                    _pendingTackFlaps--;
                    _nextFlapTime = Time.time + Random.Range(0.06f, 0.16f);
                }
                return;
            }

            // Luffing: irregular flaps, faster in more wind
            if (_luff > 0.05f && apparentWind > 2f && Time.time >= _nextFlapTime)
            {
                PlayFlap(_volume * _luff * windLevel);
                float windFactor = Mathf.Clamp(REFERENCE_WIND_SPEED / apparentWind, 0.5f, 2f);
                _nextFlapTime = Time.time + Random.Range(_flapInterval.x, _flapInterval.y) * windFactor;
            }
        }

        private void OnDestroy()
        {
            if (_flapClips == null) return;
            foreach (AudioClip clip in _flapClips)
            {
                if (clip != null) Destroy(clip);
            }
        }

        private void PlayFlap(float volume)
        {
            if (volume < 0.01f) return;
            _source.pitch = Random.Range(0.85f, 1.2f);
            _source.PlayOneShot(_flapClips[Random.Range(0, _flapClips.Length)], volume);
        }
    }
}
