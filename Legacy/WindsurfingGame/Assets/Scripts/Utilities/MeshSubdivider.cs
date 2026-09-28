using System.Collections.Generic;
using UnityEngine;

namespace WindsurfingGame.Utilities
{
    /// <summary>
    /// Linear midpoint subdivision: every triangle becomes four. Vertex positions are not
    /// smoothed, so the shape is preserved; the extra vertices give procedural deformers
    /// (SailDeformer) something to bend.
    /// </summary>
    public static class MeshSubdivider
    {
        /// <summary>
        /// Subdivide a mesh a number of times. Returns a new Mesh; the source is untouched.
        /// </summary>
        public static Mesh Subdivide(Mesh source, int levels)
        {
            Mesh current = source;
            for (int level = 0; level < levels; level++)
            {
                Mesh next = SubdivideOnce(current);
                if (current != source)
                {
                    Object.Destroy(current);
                }
                current = next;
            }
            return current;
        }

        private static Mesh SubdivideOnce(Mesh source)
        {
            Vector3[] sourceVertices = source.vertices;
            Vector2[] sourceUVs = source.uv;
            Vector3[] sourceNormals = source.normals;
            Color[] sourceColors = source.colors;

            int vertexCount = sourceVertices.Length;
            bool hasUVs = sourceUVs != null && sourceUVs.Length == vertexCount;
            bool hasNormals = sourceNormals != null && sourceNormals.Length == vertexCount;
            bool hasColors = sourceColors != null && sourceColors.Length == vertexCount;

            List<Vector3> vertices = new List<Vector3>(sourceVertices);
            List<Vector2> uvs = hasUVs ? new List<Vector2>(sourceUVs) : null;
            List<Vector3> normals = hasNormals ? new List<Vector3>(sourceNormals) : null;
            List<Color> colors = hasColors ? new List<Color>(sourceColors) : null;

            Dictionary<long, int> midpoints = new Dictionary<long, int>();

            int Midpoint(int a, int b)
            {
                int lo = Mathf.Min(a, b);
                int hi = Mathf.Max(a, b);
                long key = ((long)lo << 32) | (uint)hi;

                if (midpoints.TryGetValue(key, out int existing))
                {
                    return existing;
                }

                int index = vertices.Count;
                vertices.Add((vertices[a] + vertices[b]) * 0.5f);
                if (uvs != null) uvs.Add((uvs[a] + uvs[b]) * 0.5f);
                if (normals != null) normals.Add((normals[a] + normals[b]).normalized);
                if (colors != null) colors.Add((colors[a] + colors[b]) * 0.5f);

                midpoints[key] = index;
                return index;
            }

            int subMeshCount = source.subMeshCount;
            List<int[]> newSubMeshes = new List<int[]>(subMeshCount);

            for (int subMesh = 0; subMesh < subMeshCount; subMesh++)
            {
                int[] triangles = source.GetTriangles(subMesh);
                List<int> result = new List<int>(triangles.Length * 4);

                for (int t = 0; t + 2 < triangles.Length; t += 3)
                {
                    int a = triangles[t];
                    int b = triangles[t + 1];
                    int c = triangles[t + 2];
                    int ab = Midpoint(a, b);
                    int bc = Midpoint(b, c);
                    int ca = Midpoint(c, a);

                    result.Add(a);  result.Add(ab); result.Add(ca);
                    result.Add(ab); result.Add(b);  result.Add(bc);
                    result.Add(ca); result.Add(bc); result.Add(c);
                    result.Add(ab); result.Add(bc); result.Add(ca);
                }

                newSubMeshes.Add(result.ToArray());
            }

            Mesh mesh = new Mesh
            {
                name = source.name + "_subdivided",
                indexFormat = vertices.Count > 65000
                    ? UnityEngine.Rendering.IndexFormat.UInt32
                    : UnityEngine.Rendering.IndexFormat.UInt16
            };

            mesh.SetVertices(vertices);
            if (uvs != null) mesh.SetUVs(0, uvs);
            if (normals != null) mesh.SetNormals(normals);
            if (colors != null) mesh.SetColors(colors);

            mesh.subMeshCount = subMeshCount;
            for (int subMesh = 0; subMesh < subMeshCount; subMesh++)
            {
                mesh.SetTriangles(newSubMeshes[subMesh], subMesh);
            }

            if (normals == null)
            {
                mesh.RecalculateNormals();
            }
            mesh.RecalculateBounds();

            return mesh;
        }
    }
}
