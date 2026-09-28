using UnityEngine;
using UnityEngine.Rendering;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Builds a large, camera-following water mesh that is dense near the viewer and coarse
    /// towards the horizon, giving OceanWater.shader enough vertices to displace into waves.
    ///
    /// This replaces the coarse built-in plane. Physics (WaterSurface) does not care which
    /// mesh is rendered - the shader displaces vertices with the same wave field that
    /// WaterSurface uses for height queries.
    ///
    /// Attach to the same GameObject as WaterSurface (needs MeshFilter + MeshRenderer).
    /// </summary>
    [RequireComponent(typeof(MeshFilter))]
    [RequireComponent(typeof(MeshRenderer))]
    public class WaterMeshBuilder : MonoBehaviour
    {
        [Header("Grid")]
        [Tooltip("Half-size of the mesh in metres (distance from centre to edge)")]
        [SerializeField] private float _extent = 1500f;

        [Tooltip("Quads per side. 160 gives ~26k vertices")]
        [Range(16, 250)]
        [SerializeField] private int _resolution = 160;

        [Tooltip("1 = uniform grid, 2-3 = vertices concentrated near the centre where the player is")]
        [Range(1f, 4f)]
        [SerializeField] private float _densityExponent = 2f;

        [Header("Follow")]
        [Tooltip("The mesh re-centres on this transform (XZ only) so the dense area stays under the viewer. Defaults to the main camera.")]
        [SerializeField] private Transform _followTarget;

        [Tooltip("Move the mesh with the follow target every frame")]
        [SerializeField] private bool _followInXZ = true;

        private Mesh _mesh;
        private float _baseY;

        /// <summary>Half-size of the generated mesh in metres.</summary>
        public float Extent => _extent;

        private void Awake()
        {
            // The legacy setup scaled a 10 m built-in plane by 10; the generated mesh is already in metres
            transform.localScale = Vector3.one;
            _baseY = transform.position.y;

            BuildMesh();

            MeshRenderer meshRenderer = GetComponent<MeshRenderer>();
            meshRenderer.shadowCastingMode = ShadowCastingMode.Off;
            meshRenderer.receiveShadows = true;
        }

        private void Start()
        {
            if (_followTarget == null && Camera.main != null)
            {
                _followTarget = Camera.main.transform;
            }
        }

        private void LateUpdate()
        {
            if (!_followInXZ || _followTarget == null) return;

            Vector3 targetPosition = _followTarget.position;
            transform.position = new Vector3(targetPosition.x, _baseY, targetPosition.z);
        }

        private void OnDestroy()
        {
            if (_mesh != null)
            {
                Destroy(_mesh);
            }
        }

        /// <summary>
        /// Generate the radial-density grid. Vertex spacing grows with distance from the
        /// centre: world offset = extent * sign(u) * |u|^densityExponent for u in [-1, 1].
        /// </summary>
        private void BuildMesh()
        {
            int quads = Mathf.Max(2, _resolution);
            int vertsPerSide = quads + 1;

            Vector3[] vertices = new Vector3[vertsPerSide * vertsPerSide];
            Vector3[] normals = new Vector3[vertices.Length];
            Vector2[] uvs = new Vector2[vertices.Length];

            for (int j = 0; j < vertsPerSide; j++)
            {
                float v = (float)j / quads * 2f - 1f;
                float z = WarpCoordinate(v);

                for (int i = 0; i < vertsPerSide; i++)
                {
                    float u = (float)i / quads * 2f - 1f;
                    float x = WarpCoordinate(u);

                    int index = j * vertsPerSide + i;
                    vertices[index] = new Vector3(x, 0f, z);
                    normals[index] = Vector3.up;
                    uvs[index] = new Vector2(x / _extent * 0.5f + 0.5f, z / _extent * 0.5f + 0.5f);
                }
            }

            int[] triangles = new int[quads * quads * 6];
            int t = 0;
            for (int j = 0; j < quads; j++)
            {
                for (int i = 0; i < quads; i++)
                {
                    int a = j * vertsPerSide + i;      // (i, j)
                    int b = a + 1;                     // (i + 1, j)
                    int c = a + vertsPerSide;          // (i, j + 1)
                    int d = c + 1;                     // (i + 1, j + 1)

                    // Clockwise seen from above (+Y) = front face in Unity
                    triangles[t++] = a; triangles[t++] = c; triangles[t++] = d;
                    triangles[t++] = a; triangles[t++] = d; triangles[t++] = b;
                }
            }

            _mesh = new Mesh
            {
                name = "OceanGrid",
                indexFormat = IndexFormat.UInt32
            };
            _mesh.SetVertices(vertices);
            _mesh.SetNormals(normals);
            _mesh.SetUVs(0, uvs);
            _mesh.SetTriangles(triangles, 0);

            // Generous bounds so wave displacement never gets the mesh culled
            _mesh.bounds = new Bounds(Vector3.zero, new Vector3(_extent * 2f, 40f, _extent * 2f));

            GetComponent<MeshFilter>().sharedMesh = _mesh;
        }

        private float WarpCoordinate(float u)
        {
            return _extent * Mathf.Sign(u) * Mathf.Pow(Mathf.Abs(u), _densityExponent);
        }
    }
}
