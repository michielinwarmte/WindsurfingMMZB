using UnityEngine;
using UnityEngine.Rendering;

namespace WindsurfingGame.Environment
{
    /// <summary>
    /// Sets up the sky, sun, ambient light and distance fog for an open-water scene.
    ///
    /// Builds a procedural skybox at runtime (Unity's built-in Skybox/Procedural shader) so no
    /// texture assets are needed, links the directional light as the skybox sun, and applies
    /// exponential fog that fades the far water into the horizon.
    ///
    /// Scene singleton: add one to an "Environment" GameObject (the setup wizard does this).
    /// </summary>
    public class SkyEnvironment : MonoBehaviour
    {
        [Header("Sun")]
        [Tooltip("Directional light used as the sun. Auto-found when empty.")]
        [SerializeField] private Light _sun;

        [Tooltip("Rotate the sun light to the elevation/azimuth below on start")]
        [SerializeField] private bool _controlSunRotation = false;

        [Tooltip("Sun height above the horizon in degrees")]
        [Range(2f, 89f)]
        [SerializeField] private float _sunElevation = 48f;

        [Tooltip("Compass direction the sunlight comes from (0 = North)")]
        [Range(0f, 360f)]
        [SerializeField] private float _sunAzimuth = 330f;

        [SerializeField] private Color _sunColor = new Color(1f, 0.96f, 0.88f);

        [SerializeField] private float _sunIntensity = 1.3f;

        [Header("Sky (Skybox/Procedural)")]
        [Tooltip("Haze amount. 1 = Earth-like, lower = clearer, bluer sky")]
        [Range(0f, 5f)]
        [SerializeField] private float _atmosphereThickness = 0.85f;

        [SerializeField] private Color _skyTint = new Color(0.45f, 0.62f, 0.85f);

        [Tooltip("Colour of the lower hemisphere (mostly hidden by the sea)")]
        [SerializeField] private Color _groundColor = new Color(0.30f, 0.40f, 0.50f);

        [Range(0f, 8f)]
        [SerializeField] private float _exposure = 1.25f;

        [Range(0f, 1f)]
        [SerializeField] private float _sunSize = 0.035f;

        [Range(1f, 10f)]
        [SerializeField] private float _sunSizeConvergence = 5f;

        [Header("Fog")]
        [SerializeField] private bool _enableFog = true;

        [Tooltip("Fog colour - keep close to the horizon colour")]
        [SerializeField] private Color _fogColor = new Color(0.70f, 0.80f, 0.90f);

        [Tooltip("Exponential-squared fog density. 0.0012 hides the water mesh edge at ~1.5 km")]
        [Range(0f, 0.01f)]
        [SerializeField] private float _fogDensity = 0.0012f;

        // Skybox/Procedural property IDs
        private static readonly int SunDiskId = Shader.PropertyToID("_SunDisk");
        private static readonly int SunSizeId = Shader.PropertyToID("_SunSize");
        private static readonly int SunSizeConvergenceId = Shader.PropertyToID("_SunSizeConvergence");
        private static readonly int AtmosphereThicknessId = Shader.PropertyToID("_AtmosphereThickness");
        private static readonly int SkyTintId = Shader.PropertyToID("_SkyTint");
        private static readonly int GroundColorId = Shader.PropertyToID("_GroundColor");
        private static readonly int ExposureId = Shader.PropertyToID("_Exposure");

        private Material _skyMaterial;

        /// <summary>The directional light acting as the sun.</summary>
        public Light Sun => _sun;

        private void Awake()
        {
            FindSun();
            Apply();
        }

        private void OnDestroy()
        {
            if (_skyMaterial != null)
            {
                if (RenderSettings.skybox == _skyMaterial)
                {
                    RenderSettings.skybox = null;
                }
                Destroy(_skyMaterial);
            }
        }

        private void FindSun()
        {
            if (_sun != null) return;

            Light[] lights = FindObjectsByType<Light>(FindObjectsSortMode.None);
            foreach (Light light in lights)
            {
                if (light.type == LightType.Directional)
                {
                    _sun = light;
                    break;
                }
            }
        }

        /// <summary>
        /// Apply sun, skybox, ambient and fog settings. Safe to call again after changing values.
        /// </summary>
        [ContextMenu("Apply Now")]
        public void Apply()
        {
            if (_sun != null)
            {
                if (_controlSunRotation)
                {
                    _sun.transform.rotation = Quaternion.Euler(_sunElevation, _sunAzimuth, 0f);
                }
                _sun.color = _sunColor;
                _sun.intensity = _sunIntensity;
                RenderSettings.sun = _sun;
            }

            Shader skyShader = Shader.Find("Skybox/Procedural");
            if (skyShader != null)
            {
                if (_skyMaterial == null)
                {
                    _skyMaterial = new Material(skyShader) { name = "ProceduralSky (runtime)" };
                }

                _skyMaterial.SetFloat(SunDiskId, 2f); // High quality sun disc
                _skyMaterial.DisableKeyword("_SUNDISK_NONE");
                _skyMaterial.DisableKeyword("_SUNDISK_SIMPLE");
                _skyMaterial.EnableKeyword("_SUNDISK_HIGH_QUALITY");
                _skyMaterial.SetFloat(SunSizeId, _sunSize);
                _skyMaterial.SetFloat(SunSizeConvergenceId, _sunSizeConvergence);
                _skyMaterial.SetFloat(AtmosphereThicknessId, _atmosphereThickness);
                _skyMaterial.SetColor(SkyTintId, _skyTint);
                _skyMaterial.SetColor(GroundColorId, _groundColor);
                _skyMaterial.SetFloat(ExposureId, _exposure);

                RenderSettings.skybox = _skyMaterial;
            }
            else
            {
                Debug.LogWarning("SkyEnvironment: Skybox/Procedural shader not found - keeping the scene skybox.");
            }

            RenderSettings.ambientMode = AmbientMode.Skybox;

            RenderSettings.fog = _enableFog;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = _fogColor;
            RenderSettings.fogDensity = _fogDensity;

            // Refresh ambient light and the default reflection probe from the new sky
            DynamicGI.UpdateEnvironment();
        }
    }
}
