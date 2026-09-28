using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Utilities;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Procedural sail-cloth deformation driven by the AdvancedSail simulation.
    ///
    /// Reads (never calculates) the sail state and bends the cloth mesh that
    /// EquipmentVisualizer instantiates:
    /// - Draft (belly) depth follows the sail force the physics produced, bulging to leeward
    /// - Leech twist opens the top of the sail (SailConfiguration.Twist)
    /// - When the sail is not filled (small angle of attack, in irons) the leech flutters
    ///
    /// Works on any single-skin sail mesh: the mast (luff) is found at the pivot axis and the
    /// leech at the far edge, so no special model setup is required. The mesh is subdivided at
    /// start for smooth bending, which needs Read/Write enabled on the model import settings.
    /// </summary>
    [RequireComponent(typeof(EquipmentVisualizer))]
    public class SailDeformer : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private EquipmentVisualizer _visualizer;

        [Tooltip("Sail cloth mesh to deform. Auto-detected (largest flat mesh in the sail model) when empty.")]
        [SerializeField] private MeshFilter _clothMeshFilter;

        [Header("Shape")]
        [Tooltip("Multiplies the camber from SailConfiguration (draft depth as a fraction of the chord)")]
        [Range(0f, 3f)]
        [SerializeField] private float _camberScale = 1f;

        [Tooltip("Lift coefficient that counts as a fully powered sail. Sets how much sail force fills the cloth completely.")]
        [SerializeField] private float _fullPowerLiftCoefficient = 1.1f;

        [Tooltip("Multiplies the leech twist from SailConfiguration")]
        [Range(0f, 3f)]
        [SerializeField] private float _twistScale = 1f;

        [Tooltip("Subdivision levels applied to the cloth mesh at start (each level = 4x triangles)")]
        [Range(0, 3)]
        [SerializeField] private int _subdivisions = 2;

        [Tooltip("Render the cloth from both sides (sets _Cull = Off on its material)")]
        [SerializeField] private bool _forceDoubleSided = true;

        [Header("Luffing")]
        [Tooltip("Angle of attack (degrees) below which the sail is not filled and starts to flutter")]
        [SerializeField] private float _luffAngleOfAttack = 6f;

        [Tooltip("Flutter amplitude at the leech in metres at 8 m/s apparent wind")]
        [SerializeField] private float _flutterAmplitude = 0.10f;

        [Tooltip("Flutter frequency in Hz at 8 m/s apparent wind")]
        [SerializeField] private float _flutterFrequency = 3.5f;

        [Header("Response")]
        [Tooltip("How quickly the cloth follows power and side changes (per second)")]
        [SerializeField] private float _responseSpeed = 6f;

        private const int HEIGHT_BINS = 16;
        private const float REFERENCE_WIND_SPEED = 8f;

        // Cloth geometry
        private Transform _pivot;
        private Transform _clothTransform;
        private Mesh _mesh;
        private bool _ownsMesh;
        private Vector3[] _restPivot;       // rest vertex positions in pivot space (metres)
        private float[] _chordFraction;     // 0 at the luff (mast), 1 at the leech
        private float[] _heightFraction;    // 0 at the foot, 1 at the head
        private float[] _chordLength;       // chord length at the vertex height (metres)
        private Vector3[] _workVertices;    // mesh-local output buffer
        private Vector3 _planeNormalPivot;  // unit normal of the flat sail, pivot space
        private bool _initialized;
        private bool _gaveUp;

        // Smoothed state
        private float _power;
        private float _side = 1f;
        private float _luff;

        /// <summary>True once the cloth mesh has been found and prepared.</summary>
        public bool IsInitialized => _initialized;

        /// <summary>Smoothed sail power 0-1 (how full the sail is).</summary>
        public float Power => _power;

        /// <summary>Smoothed luffing amount 0-1 (1 = flapping freely).</summary>
        public float LuffAmount => _luff;

        private void Awake()
        {
            if (_sail == null) _sail = GetComponent<AdvancedSail>();
            if (_visualizer == null) _visualizer = GetComponent<EquipmentVisualizer>();
        }

        private void Update()
        {
            if (!_initialized)
            {
                // EquipmentVisualizer builds the sail model in its Start(); order is not guaranteed
                if (_gaveUp) return;
                TryInitialize();
                if (!_initialized) return;
            }

            Deform();
        }

        private void OnDestroy()
        {
            if (_ownsMesh && _mesh != null)
            {
                Destroy(_mesh);
            }
        }

        private void TryInitialize()
        {
            if (_visualizer == null || _sail == null)
            {
                Debug.LogWarning($"SailDeformer on {gameObject.name}: needs AdvancedSail and EquipmentVisualizer.");
                _gaveUp = true;
                return;
            }

            _pivot = _visualizer.SailPivot;
            GameObject sailRoot = _visualizer.SailInstance;
            if (_pivot == null || sailRoot == null)
            {
                return; // visualizer not ready yet (or no sail prefab assigned)
            }

            if (_clothMeshFilter == null)
            {
                _clothMeshFilter = FindClothMesh(sailRoot);
            }

            if (_clothMeshFilter == null || _clothMeshFilter.sharedMesh == null)
            {
                Debug.LogWarning($"SailDeformer on {gameObject.name}: no sail cloth mesh found in the sail model.");
                _gaveUp = true;
                return;
            }

            _clothTransform = _clothMeshFilter.transform;

            // .mesh gives this MeshFilter its own instance (leaves the shared asset untouched)
            Mesh instance = _clothMeshFilter.mesh;
            if (_subdivisions > 0)
            {
                Mesh subdivided = MeshSubdivider.Subdivide(instance, _subdivisions);
                _clothMeshFilter.mesh = subdivided;
                instance = subdivided;
                _ownsMesh = true;
            }

            _mesh = instance;
            _mesh.MarkDynamic();

            Vector3[] restLocal = _mesh.vertices;
            int count = restLocal.Length;
            _restPivot = new Vector3[count];
            _chordFraction = new float[count];
            _heightFraction = new float[count];
            _chordLength = new float[count];
            _workVertices = new Vector3[count];

            for (int i = 0; i < count; i++)
            {
                _restPivot[i] = _pivot.InverseTransformPoint(_clothTransform.TransformPoint(restLocal[i]));
            }

            AnalyseGeometry();

            if (_forceDoubleSided)
            {
                Renderer clothRenderer = _clothMeshFilter.GetComponent<Renderer>();
                if (clothRenderer != null)
                {
                    foreach (Material material in clothRenderer.materials)
                    {
                        if (material.HasProperty("_Cull"))
                        {
                            material.SetFloat("_Cull", 0f);
                        }
                    }
                }
            }

            _initialized = true;
            Debug.Log($"SailDeformer: deforming '{_clothMeshFilter.name}' ({count} vertices after {_subdivisions} subdivision(s))");
        }

        /// <summary>
        /// Pick the sail cloth: the mesh with the largest flat extent (two biggest world-space
        /// bounds dimensions). Skips face-less meshes such as an exported mast curve profile.
        /// </summary>
        private static MeshFilter FindClothMesh(GameObject sailRoot)
        {
            MeshFilter best = null;
            float bestScore = 0f;

            foreach (MeshFilter meshFilter in sailRoot.GetComponentsInChildren<MeshFilter>())
            {
                Mesh mesh = meshFilter.sharedMesh;
                if (mesh == null || mesh.subMeshCount == 0 || mesh.GetIndexCount(0) < 3) continue;

                Renderer meshRenderer = meshFilter.GetComponent<Renderer>();
                if (meshRenderer == null) continue;

                Vector3 size = meshRenderer.bounds.size;
                float largest = Mathf.Max(size.x, size.y, size.z);
                float smallest = Mathf.Min(size.x, size.y, size.z);
                float middle = size.x + size.y + size.z - largest - smallest;
                float score = largest * middle;

                if (meshFilter.name.ToLowerInvariant().Contains("sail"))
                {
                    score *= 4f;
                }

                if (score > bestScore)
                {
                    best = meshFilter;
                    bestScore = score;
                }
            }

            return best;
        }

        /// <summary>
        /// Measure the cloth in pivot space: the luff sits on the pivot Y axis (mast), the chord
        /// direction is the mean horizontal offset of the vertices, and the leech length per
        /// height is the largest offset along the chord in that height band.
        /// </summary>
        private void AnalyseGeometry()
        {
            int count = _restPivot.Length;
            float yMin = float.PositiveInfinity;
            float yMax = float.NegativeInfinity;
            Vector2 chordAccumulator = Vector2.zero;

            for (int i = 0; i < count; i++)
            {
                Vector3 p = _restPivot[i];
                yMin = Mathf.Min(yMin, p.y);
                yMax = Mathf.Max(yMax, p.y);
                Vector2 horizontal = new Vector2(p.x, p.z);
                chordAccumulator += horizontal * horizontal.magnitude;
            }

            Vector2 chordDir = chordAccumulator.sqrMagnitude > 1e-6f ? chordAccumulator.normalized : new Vector2(0f, -1f);
            _planeNormalPivot = Vector3.Cross(Vector3.up, new Vector3(chordDir.x, 0f, chordDir.y)).normalized;

            float span = Mathf.Max(yMax - yMin, 0.01f);

            // Leech distance per height band
            float[] binMax = new float[HEIGHT_BINS];
            for (int i = 0; i < count; i++)
            {
                Vector3 p = _restPivot[i];
                float along = p.x * chordDir.x + p.z * chordDir.y;
                int bin = Mathf.Clamp(Mathf.RoundToInt((p.y - yMin) / span * (HEIGHT_BINS - 1)), 0, HEIGHT_BINS - 1);
                binMax[bin] = Mathf.Max(binMax[bin], along);
            }

            // Fill empty bands from their neighbours
            for (int bin = 1; bin < HEIGHT_BINS; bin++)
            {
                if (binMax[bin] <= 0f) binMax[bin] = binMax[bin - 1];
            }
            for (int bin = HEIGHT_BINS - 2; bin >= 0; bin--)
            {
                if (binMax[bin] <= 0f) binMax[bin] = binMax[bin + 1];
            }

            for (int i = 0; i < count; i++)
            {
                Vector3 p = _restPivot[i];
                float heightFraction = Mathf.Clamp01((p.y - yMin) / span);
                float binPosition = heightFraction * (HEIGHT_BINS - 1);
                int bin0 = Mathf.Clamp(Mathf.FloorToInt(binPosition), 0, HEIGHT_BINS - 1);
                int bin1 = Mathf.Min(bin0 + 1, HEIGHT_BINS - 1);
                float chordLength = Mathf.Max(Mathf.Lerp(binMax[bin0], binMax[bin1], binPosition - bin0), 0.05f);

                float along = p.x * chordDir.x + p.z * chordDir.y;

                _heightFraction[i] = heightFraction;
                _chordLength[i] = chordLength;
                _chordFraction[i] = Mathf.Clamp01(along / chordLength);
            }
        }

        /// <summary>
        /// Bend the cloth from the current simulation state.
        /// </summary>
        private void Deform()
        {
            SailingState state = _sail.State;
            if (state == null) return;

            float deltaTime = Time.deltaTime;
            float apparentWind = state.ApparentWindSpeed;

            // Power 0-1: the force the simulation produced, relative to a fully powered sail
            float dynamicPressure = 0.5f * PhysicsConstants.AIR_DENSITY * apparentWind * apparentWind;
            float fullPowerForce = dynamicPressure * _sail.Config.Area * _fullPowerLiftCoefficient;
            float targetPower = fullPowerForce > 1f ? Mathf.Clamp01(state.SailForce.magnitude / fullPowerForce) : 0f;

            // The belly bulges to leeward: away from the sail normal, which faces the wind
            Vector3 leewardPivot = _pivot.InverseTransformDirection(-_sail.SailNormal);
            float targetSide = Vector3.Dot(leewardPivot, _planeNormalPivot) >= 0f ? 1f : -1f;

            // Luffing: the sail is not filled
            float angleOfAttack = Mathf.Abs(state.AngleOfAttack);
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

            float blend = 1f - Mathf.Exp(-_responseSpeed * deltaTime);
            _power = Mathf.Lerp(_power, targetPower, blend);
            _side = Mathf.Lerp(_side, targetSide, Mathf.Min(1f, blend * 1.5f));
            _luff = Mathf.Lerp(_luff, targetLuff, blend);

            float camber = _sail.Config.Camber * _camberScale;
            float twistDegrees = _sail.Config.Twist * _twistScale;

            float windFactor = Mathf.Clamp(apparentWind / REFERENCE_WIND_SPEED, 0.2f, 2.5f);
            float flutterPhase = Time.time * _flutterFrequency * windFactor * Mathf.PI * 2f;
            float flutterAmplitude = _flutterAmplitude * _luff * windFactor;

            Matrix4x4 pivotToMesh = _clothTransform.worldToLocalMatrix * _pivot.localToWorldMatrix;
            Vector3 normal = _planeNormalPivot;

            for (int i = 0; i < _restPivot.Length; i++)
            {
                Vector3 p = _restPivot[i];
                float t = _chordFraction[i];
                float h = _heightFraction[i];

                // Twist: rotate around the mast, the leech falls off to leeward more towards the head
                float twist = twistDegrees * h * h * _side;
                if (Mathf.Abs(twist) > 0.01f)
                {
                    float radians = twist * Mathf.Deg2Rad;
                    float cos = Mathf.Cos(radians);
                    float sin = Mathf.Sin(radians);
                    float x = p.x * cos + p.z * sin;
                    float z = -p.x * sin + p.z * cos;
                    p.x = x;
                    p.z = z;
                }

                // Draft: deepest around 40% of the chord and in the lower-middle of the sail
                float draft = _chordLength[i] * camber * _power * CamberProfile(t) * HeightProfile(h) * _side;

                // Flutter: travelling wave from luff to leech, growing towards the leech
                float flutter = flutterAmplitude * t * t * (0.6f + 0.4f * h) * Mathf.Sin(flutterPhase - t * 4.5f + h * 2.0f);
                flutter += flutterAmplitude * 0.35f * t * Mathf.Sin(flutterPhase * 1.7f + t * 2.0f - h * 3.0f);

                p += normal * (draft + flutter);
                _workVertices[i] = pivotToMesh.MultiplyPoint3x4(p);
            }

            _mesh.vertices = _workVertices;
            _mesh.RecalculateNormals();
            _mesh.RecalculateBounds();
        }

        /// <summary>Draft profile along the chord: 0 at luff and leech, maximum near 40%.</summary>
        private static float CamberProfile(float t)
        {
            return Mathf.Sin(Mathf.PI * Mathf.Pow(t, 0.75f));
        }

        /// <summary>Draft profile up the sail: strong low-middle, fading to nothing at the head.</summary>
        private static float HeightProfile(float h)
        {
            if (h <= 0f) return 0f;
            return Mathf.Pow(Mathf.Sin(Mathf.PI * Mathf.Pow(h, 0.55f)), 0.8f);
        }
    }
}
