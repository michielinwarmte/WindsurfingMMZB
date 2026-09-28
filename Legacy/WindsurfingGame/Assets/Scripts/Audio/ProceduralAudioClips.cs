using UnityEngine;

namespace WindsurfingGame.Audio
{
    /// <summary>
    /// Generates the sound effects at runtime from filtered noise, so the project needs no
    /// audio files. Wind, water lapping and planing hiss are seamless loops; sail flaps and
    /// splashes are short bursts.
    ///
    /// All clips are mono at SAMPLE_RATE. Generation runs once at scene start.
    /// </summary>
    public static class ProceduralAudioClips
    {
        public const int SAMPLE_RATE = 22050;

        private const float LOOP_CROSSFADE_SECONDS = 0.25f;

        /// <summary>
        /// Seamless looping noise.
        /// </summary>
        /// <param name="name">Clip name (shown in the profiler)</param>
        /// <param name="seconds">Loop length</param>
        /// <param name="lowPassHz">One-pole low-pass cutoff, 0 = none. Lower = deeper rumble</param>
        /// <param name="highPassHz">One-pole high-pass cutoff, 0 = none. Removes sub-bass thump</param>
        /// <param name="pink">Pink (1/f) noise sounds like wind; white noise sounds like hiss</param>
        /// <param name="seed">Random seed so different clips do not phase-lock</param>
        public static AudioClip CreateNoiseLoop(string name, float seconds, float lowPassHz, float highPassHz, bool pink, int seed)
        {
            int length = Mathf.Max(SAMPLE_RATE / 4, (int)(seconds * SAMPLE_RATE));
            int fade = (int)(LOOP_CROSSFADE_SECONDS * SAMPLE_RATE);

            // Generate a little extra and crossfade the tail into the head for a seamless loop
            float[] generated = GenerateNoise(length + fade, lowPassHz, highPassHz, pink, seed);
            float[] data = new float[length];
            for (int i = 0; i < length; i++)
            {
                data[i] = generated[i];
            }
            for (int i = 0; i < fade; i++)
            {
                float t = (float)i / fade;
                data[i] = generated[length + i] * (1f - t) + generated[i] * t;
            }

            Normalize(data, 0.8f);

            AudioClip clip = AudioClip.Create(name, length, 1, SAMPLE_RATE, false);
            clip.SetData(data, 0);
            return clip;
        }

        /// <summary>
        /// Short noise burst with a fast attack and exponential decay, whose low-pass cutoff
        /// sweeps from bright to dull. Used for sail flaps and splashes.
        /// </summary>
        /// <param name="seconds">Burst length</param>
        /// <param name="attackSeconds">Linear fade-in time</param>
        /// <param name="decayRate">Exponential decay rate (per second); higher = shorter</param>
        /// <param name="lowPassStartHz">Cutoff at the start of the burst</param>
        /// <param name="lowPassEndHz">Cutoff at the end of the burst</param>
        public static AudioClip CreateBurst(string name, float seconds, float attackSeconds, float decayRate,
            float lowPassStartHz, float lowPassEndHz, bool pink, int seed)
        {
            int length = Mathf.Max(64, (int)(seconds * SAMPLE_RATE));
            float[] data = GenerateNoise(length, 0f, 60f, pink, seed);

            float lowPass = 0f;
            int attackSamples = Mathf.Max(1, (int)(attackSeconds * SAMPLE_RATE));

            for (int i = 0; i < length; i++)
            {
                float t = (float)i / SAMPLE_RATE;
                float progress = (float)i / length;

                float cutoff = Mathf.Lerp(lowPassStartHz, lowPassEndHz, progress);
                float alpha = OnePoleAlpha(cutoff);
                lowPass += alpha * (data[i] - lowPass);

                float envelope = Mathf.Min(1f, (float)i / attackSamples) * Mathf.Exp(-decayRate * t);
                data[i] = lowPass * envelope;
            }

            Normalize(data, 0.9f);

            AudioClip clip = AudioClip.Create(name, length, 1, SAMPLE_RATE, false);
            clip.SetData(data, 0);
            return clip;
        }

        private static float[] GenerateNoise(int length, float lowPassHz, float highPassHz, bool pink, int seed)
        {
            float[] data = new float[length];
            System.Random rng = new System.Random(seed);

            // Pink noise filter state (Paul Kellet's refined method)
            float b0 = 0f, b1 = 0f, b2 = 0f, b3 = 0f, b4 = 0f, b5 = 0f, b6 = 0f;

            float lowAlpha = OnePoleAlpha(lowPassHz);
            float highAlpha = OnePoleAlpha(highPassHz);
            float lowState = 0f;
            float highState = 0f;

            for (int i = 0; i < length; i++)
            {
                float white = (float)(rng.NextDouble() * 2.0 - 1.0);
                float sample = white;

                if (pink)
                {
                    b0 = 0.99886f * b0 + white * 0.0555179f;
                    b1 = 0.99332f * b1 + white * 0.0750759f;
                    b2 = 0.96900f * b2 + white * 0.1538520f;
                    b3 = 0.86650f * b3 + white * 0.3104856f;
                    b4 = 0.55000f * b4 + white * 0.5329522f;
                    b5 = -0.7616f * b5 - white * 0.0168980f;
                    sample = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362f) * 0.11f;
                    b6 = white * 0.115926f;
                }

                if (lowPassHz > 0f)
                {
                    lowState += lowAlpha * (sample - lowState);
                    sample = lowState;
                }

                if (highPassHz > 0f)
                {
                    highState += highAlpha * (sample - highState);
                    sample -= highState;
                }

                data[i] = sample;
            }

            return data;
        }

        /// <summary>Coefficient of a one-pole filter for the given cutoff.</summary>
        private static float OnePoleAlpha(float cutoffHz)
        {
            if (cutoffHz <= 0f) return 1f;
            float dt = 1f / SAMPLE_RATE;
            float rc = 1f / (2f * Mathf.PI * cutoffHz);
            return dt / (rc + dt);
        }

        private static void Normalize(float[] data, float peak)
        {
            float max = 0f;
            for (int i = 0; i < data.Length; i++)
            {
                max = Mathf.Max(max, Mathf.Abs(data[i]));
            }
            if (max < 1e-6f) return;

            float scale = peak / max;
            for (int i = 0; i < data.Length; i++)
            {
                data[i] *= scale;
            }
        }
    }
}
