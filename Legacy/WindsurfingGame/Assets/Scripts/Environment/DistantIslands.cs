using System.Collections.Generic;
using UnityEngine;
using WindsurfingGame.Physics.Water;

namespace WindsurfingGame.Environment
{
    /// <summary>
    /// Procedurally generated low-poly islands placed in a ring around the start area.
    /// Gives the horizon some landmarks so speed and heading are readable, and the water
    /// shader draws foam where the beaches meet the sea.
    ///
    /// Each island is a noise-displaced hill with vertex colours (sand, grass, rock) and a
    /// MeshCollider so the board cannot sail through it. Scene singleton.
    /// </summary>
    public class DistantIslands : MonoBehaviour
    {
        [Header("Layout")]
        [Tooltip("Number of islands placed around the origin")]
        [Range(0, 16)]
        [SerializeField] private int _islandCount = 6;

        [Tooltip("Random seed - change for a different archipelago")]
        [SerializeField] private int _seed = 1234;

        [Tooltip("Closest island distance from the origin (m)")]
        [SerializeField] private float _minDistance = 450f;

        [Tooltip("Farthest island distance from the origin (m)")]
        [SerializeField] private float _maxDistance = 900f;

        [Header("Shape")]
        [Tooltip("Island radius range in metres (min, max)")]
        [SerializeField] private Vector2 _radiusRange = new Vector2(60f, 180f);

        [Tooltip("Island peak height range in metres (min, max)")]
        [SerializeField] private Vector2 _heightRange = new Vector2(12f, 55f);

        [Tooltip("Mesh rings from centre to shore")]
        [Range(8, 64)]
        [SerializeField] private int _rings = 24;

        [Tooltip("Mesh segments around the island")]
        [Range(12, 96)]
        [SerializeField] private int _segments = 48;

        [Tooltip("Add MeshColliders so the board bumps into islands")]
        [SerializeField] private bool _addColliders = true;

        [Header("Appearance")]
        [Tooltip("Material for the islands. Falls back to the VertexColorTerrain shader when empty.")]
        [SerializeField] private Material _material;

        [SerializeField] private Color _sandColor = new Color(0.86f, 0.80f, 0.62f);
        [SerializeField] private Color _grassColor = new Color(0.30f, 0.52f, 0.24f);
        [SerializeField] private Color _rockColor = new Color(0.45f, 0.42f, 0.38f);

        private const float SHORE_DEPTH = 2f;   // how far below the water the island rim sits (m)
        private const float BEACH_HEIGHT = 1.2f; // sand up to this height above water (m)

        private readonly List<Mesh> _meshes = new List<Mesh>();
        private Material _runtimeMaterial;

        private void Start()
        {
            Generate();
        }

        private void OnDestroy()
        {
            foreach (Mesh mesh in _meshes)
            {
                if (mesh != null) Destroy(mesh);
            }
            _meshes.Clear();

            if (_runtimeMaterial != null)
            {
                Destroy(_runtimeMaterial);
            }
        }

        /// <summary>
        /// Build all islands as children of this GameObject.
        /// </summary>
        private void Generate()
        {
            if (_islandCount <= 0) return;

            System.Random rng = new System.Random(_seed);

            WaterSurface water = FindFirstObjectByType<WaterSurface>();
            float waterLevel = water != null ? water.BaseHeight : 0f;

            Material material = ResolveMaterial();

            for (int i = 0; i < _islandCount; i++)
            {
                // Spread around the compass with some jitter so the ring does not look regular
                float angle = (i + 0.5f) / _islandCount * 360f + NextRange(rng, -20f, 20f);
                float distance = NextRange(rng, _minDistance, _maxDistance);
                float radius = NextRange(rng, _radiusRange.x, _radiusRange.y);
                float height = NextRange(rng, _heightRange.x, _heightRange.y);
                Vector2 noiseOffset = new Vector2(NextRange(rng, 0f, 1000f), NextRange(rng, 0f, 1000f));

                float rad = angle * Mathf.Deg2Rad;
                Vector3 position = new Vector3(Mathf.Sin(rad) * distance, waterLevel, Mathf.Cos(rad) * distance);

                GameObject island = new GameObject($"Island_{i}");
                island.transform.SetParent(transform, false);
                island.transform.position = position;

                Mesh mesh = BuildIslandMesh(radius, height, noiseOffset);
                _meshes.Add(mesh);

                island.AddComponent<MeshFilter>().sharedMesh = mesh;
                MeshRenderer meshRenderer = island.AddComponent<MeshRenderer>();
                meshRenderer.sharedMaterial = material;
                meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

                if (_addColliders)
                {
                    island.AddComponent<MeshCollider>().sharedMesh = mesh;
                }
            }
        }

        private Material ResolveMaterial()
        {
            if (_material != null) return _material;

            Shader shader = Shader.Find("Windsurfing/VertexColorTerrain");
            if (shader == null)
            {
                shader = Shader.Find("Universal Render Pipeline/Lit");
                Debug.LogWarning("DistantIslands: VertexColorTerrain shader not found, using URP/Lit (no vertex colours).");
            }

            _runtimeMaterial = new Material(shader) { name = "IslandTerrain (runtime)" };
            if (!_runtimeMaterial.HasProperty("_Tint"))
            {
                _runtimeMaterial.color = _grassColor;
            }
            return _runtimeMaterial;
        }

        /// <summary>
        /// Radial hill mesh: centre vertex plus rings x segments. The rim sits below the water
        /// so the shoreline intersects the surface (edge foam in the water shader).
        /// </summary>
        private Mesh BuildIslandMesh(float radius, float height, Vector2 noiseOffset)
        {
            int rings = Mathf.Max(2, _rings);
            int segments = Mathf.Max(3, _segments);
            int vertexCount = 1 + rings * segments;

            Vector3[] vertices = new Vector3[vertexCount];
            Vector2[] uvs = new Vector2[vertexCount];

            vertices[0] = new Vector3(0f, SampleHeight(0f, 0f, radius, height, noiseOffset), 0f);
            uvs[0] = new Vector2(0.5f, 0.5f);

            for (int ring = 1; ring <= rings; ring++)
            {
                float r = radius * ring / rings;
                for (int seg = 0; seg < segments; seg++)
                {
                    float theta = (float)seg / segments * Mathf.PI * 2f;
                    float x = Mathf.Sin(theta) * r;
                    float z = Mathf.Cos(theta) * r;
                    int index = 1 + (ring - 1) * segments + seg;

                    vertices[index] = new Vector3(x, SampleHeight(x, z, radius, height, noiseOffset), z);
                    uvs[index] = new Vector2(x / radius * 0.5f + 0.5f, z / radius * 0.5f + 0.5f);
                }
            }

            // Triangles: fan around the centre, then quads between rings. Clockwise from above.
            List<int> triangles = new List<int>(rings * segments * 6);
            for (int seg = 0; seg < segments; seg++)
            {
                int next = (seg + 1) % segments;
                triangles.Add(0);
                triangles.Add(1 + seg);
                triangles.Add(1 + next);
            }
            for (int ring = 1; ring < rings; ring++)
            {
                int inner = 1 + (ring - 1) * segments;
                int outer = 1 + ring * segments;
                for (int seg = 0; seg < segments; seg++)
                {
                    int next = (seg + 1) % segments;
                    triangles.Add(inner + seg);
                    triangles.Add(outer + seg);
                    triangles.Add(outer + next);

                    triangles.Add(inner + seg);
                    triangles.Add(outer + next);
                    triangles.Add(inner + next);
                }
            }

            Mesh mesh = new Mesh { name = "IslandMesh" };
            mesh.SetVertices(vertices);
            mesh.SetUVs(0, uvs);
            mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();

            // Vertex colours from height and slope
            Vector3[] normals = mesh.normals;
            Color[] colors = new Color[vertexCount];
            for (int i = 0; i < vertexCount; i++)
            {
                float y = vertices[i].y;
                float slope = 1f - Mathf.Clamp01(normals[i].y);

                Color color;
                if (y < BEACH_HEIGHT)
                {
                    color = _sandColor;
                }
                else
                {
                    float grassToRock = Mathf.Clamp01((slope - 0.35f) / 0.3f) + Mathf.Clamp01((y / Mathf.Max(height, 1f) - 0.7f) / 0.3f);
                    color = Color.Lerp(_grassColor, _rockColor, Mathf.Clamp01(grassToRock));

                    // Blend the beach into the grass over the first metre
                    float beachBlend = Mathf.Clamp01((y - BEACH_HEIGHT) / 1.0f);
                    color = Color.Lerp(_sandColor, color, beachBlend);
                }
                colors[i] = color;
            }
            mesh.SetColors(colors);

            return mesh;
        }

        /// <summary>
        /// Height of the island surface at local (x, z): smooth dome shaped by two octaves of
        /// Perlin noise, dropping to SHORE_DEPTH below the water at the rim.
        /// </summary>
        private float SampleHeight(float x, float z, float radius, float height, Vector2 noiseOffset)
        {
            float t = Mathf.Clamp01(Mathf.Sqrt(x * x + z * z) / radius);
            float falloff = (1f - t * t) * (1f - t * t);

            float frequency = 2.5f / radius;
            float noise = Mathf.PerlinNoise(x * frequency + noiseOffset.x, z * frequency + noiseOffset.y) * 0.7f
                        + Mathf.PerlinNoise(x * frequency * 2.3f + noiseOffset.y, z * frequency * 2.3f + noiseOffset.x) * 0.3f;
            float noiseFactor = 0.45f + 0.7f * noise;

            return height * falloff * noiseFactor - SHORE_DEPTH;
        }

        private static float NextRange(System.Random rng, float min, float max)
        {
            return min + (float)rng.NextDouble() * (max - min);
        }
    }
}
