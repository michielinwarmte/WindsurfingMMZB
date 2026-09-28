using UnityEngine;

namespace WindsurfingGame.Utilities
{
    /// <summary>
    /// Creates visual reference points in the water for spatial awareness.
    /// Spawns a grid of buoys or markers to help judge speed and distance.
    /// </summary>
    public class WaterGridMarkers : MonoBehaviour
    {
        [Header("Grid Settings")]
        [Tooltip("Size of the grid in meters")]
        [SerializeField] private float _gridSize = 500f;
        
        [Tooltip("Spacing between markers in meters")]
        [SerializeField] private float _markerSpacing = 100f;
        
        [Tooltip("Height of markers above water")]
        [SerializeField] private float _markerHeight = 2f;

        [Header("Marker Appearance")]
        [SerializeField] private Color _primaryColor = Color.red;
        [SerializeField] private Color _secondaryColor = Color.yellow;
        [SerializeField] private float _markerScale = 1f;

        [Header("Center Marker")]
        [SerializeField] private bool _showCenterMarker = true;
        [SerializeField] private Color _centerColor = Color.green;

        [Header("Distance Rings")]
        [SerializeField] private bool _showDistanceRings = true;
        [SerializeField] private float[] _ringDistances = { 100f, 250f, 500f };

        // Container for spawned objects
        private GameObject _markerContainer;

        private void Start()
        {
            CreateMarkers();
        }

        private void CreateMarkers()
        {
            // Create container
            _markerContainer = new GameObject("WaterMarkers");
            _markerContainer.transform.SetParent(transform);

            // Create grid markers
            int halfCount = Mathf.FloorToInt(_gridSize / (2 * _markerSpacing));
            
            for (int x = -halfCount; x <= halfCount; x++)
            {
                for (int z = -halfCount; z <= halfCount; z++)
                {
                    Vector3 position = new Vector3(
                        x * _markerSpacing,
                        _markerHeight,
                        z * _markerSpacing
                    );

                    bool isPrimary = (x % 2 == 0 && z % 2 == 0);
                    bool isCenter = (x == 0 && z == 0);

                    if (isCenter && _showCenterMarker)
                    {
                        CreateBuoy(position, _centerColor, _markerScale * 2f, "CenterMarker");
                    }
                    else if (isPrimary)
                    {
                        CreateBuoy(position, _primaryColor, _markerScale, $"Buoy_{x}_{z}");
                    }
                    else
                    {
                        CreateSmallMarker(position, _secondaryColor, $"Marker_{x}_{z}");
                    }
                }
            }

            // Create distance rings visualization
            if (_showDistanceRings)
            {
                CreateDistanceRings();
            }

            // Create cardinal direction markers
            CreateCardinalMarkers();
        }

        private void CreateBuoy(Vector3 position, Color color, float scale, string name)
        {
            GameObject buoy = new GameObject(name);
            buoy.transform.SetParent(_markerContainer.transform);
            buoy.transform.position = position;

            // Create base (cylinder)
            GameObject baseObj = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            baseObj.transform.SetParent(buoy.transform);
            baseObj.transform.localPosition = Vector3.zero;
            baseObj.transform.localScale = new Vector3(scale * 0.5f, scale * 1f, scale * 0.5f);
            
            // Remove collider (we don't want to collide with markers)
            Destroy(baseObj.GetComponent<Collider>());
            
            // Set material
            SetColor(baseObj, color);

            // Create top sphere
            GameObject topObj = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            topObj.transform.SetParent(buoy.transform);
            topObj.transform.localPosition = new Vector3(0, scale * 1f, 0);
            topObj.transform.localScale = Vector3.one * scale * 0.6f;
            Destroy(topObj.GetComponent<Collider>());
            SetColor(topObj, color);
        }

        private void CreateSmallMarker(Vector3 position, Color color, string name)
        {
            GameObject marker = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            marker.name = name;
            marker.transform.SetParent(_markerContainer.transform);
            marker.transform.position = position;
            marker.transform.localScale = Vector3.one * _markerScale * 0.3f;
            
            Destroy(marker.GetComponent<Collider>());
            SetColor(marker, color);
        }

        private void CreateDistanceRings()
        {
            foreach (float distance in _ringDistances)
            {
                // Create markers at cardinal and intermediate points on the ring
                int markerCount = Mathf.Max(8, Mathf.FloorToInt(distance / 50f));
                
                for (int i = 0; i < markerCount; i++)
                {
                    float angle = (i / (float)markerCount) * Mathf.PI * 2f;
                    Vector3 position = new Vector3(
                        Mathf.Sin(angle) * distance,
                        _markerHeight * 0.5f,
                        Mathf.Cos(angle) * distance
                    );

                    GameObject marker = GameObject.CreatePrimitive(PrimitiveType.Cube);
                    marker.name = $"Ring_{distance}_{i}";
                    marker.transform.SetParent(_markerContainer.transform);
                    marker.transform.position = position;
                    marker.transform.localScale = new Vector3(0.3f, 0.3f, 0.3f);
                    marker.transform.LookAt(Vector3.zero);
                    
                    Destroy(marker.GetComponent<Collider>());
                    
                    // Fade color based on distance
                    float alpha = 1f - (distance / _gridSize) * 0.5f;
                    SetColor(marker, new Color(1f, 1f, 1f, alpha));
                }
            }
        }

        private void CreateCardinalMarkers()
        {
            float distance = _gridSize * 0.4f;
            
            // North
            CreateDirectionMarker(new Vector3(0, _markerHeight, distance), "N", Color.red);
            // South
            CreateDirectionMarker(new Vector3(0, _markerHeight, -distance), "S", Color.blue);
            // East  
            CreateDirectionMarker(new Vector3(distance, _markerHeight, 0), "E", Color.yellow);
            // West
            CreateDirectionMarker(new Vector3(-distance, _markerHeight, 0), "W", Color.green);
        }

        private void CreateDirectionMarker(Vector3 position, string direction, Color color)
        {
            GameObject marker = new GameObject($"Cardinal_{direction}");
            marker.transform.SetParent(_markerContainer.transform);
            marker.transform.position = position;

            // Create tall pole
            GameObject pole = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            pole.transform.SetParent(marker.transform);
            pole.transform.localPosition = new Vector3(0, 2f, 0);
            pole.transform.localScale = new Vector3(0.3f, 4f, 0.3f);
            Destroy(pole.GetComponent<Collider>());
            SetColor(pole, color);

            // Create flag (stretched cube)
            GameObject flag = GameObject.CreatePrimitive(PrimitiveType.Cube);
            flag.transform.SetParent(marker.transform);
            flag.transform.localPosition = new Vector3(1f, 5f, 0);
            flag.transform.localScale = new Vector3(2f, 1f, 0.1f);
            Destroy(flag.GetComponent<Collider>());
            SetColor(flag, color);
        }

        private void SetColor(GameObject obj, Color color)
        {
            Renderer renderer = obj.GetComponent<Renderer>();
            if (renderer != null)
            {
                // Create a new material instance
                Material mat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                mat.color = color;
                
                // For transparent colors
                if (color.a < 1f)
                {
                    mat.SetFloat("_Surface", 1); // Transparent
                    mat.SetFloat("_Blend", 0);   // Alpha
                    mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    mat.renderQueue = 3000;
                }
                
                renderer.material = mat;
            }
        }

        /// <summary>
        /// Clears and regenerates all markers.
        /// </summary>
        public void RegenerateMarkers()
        {
            if (_markerContainer != null)
            {
                Destroy(_markerContainer);
            }
            CreateMarkers();
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Show grid bounds in editor
            Gizmos.color = new Color(1, 1, 0, 0.3f);
            Gizmos.DrawWireCube(transform.position, new Vector3(_gridSize, 1, _gridSize));

            // Show marker positions
            Gizmos.color = Color.yellow;
            int halfCount = Mathf.FloorToInt(_gridSize / (2 * _markerSpacing));
            for (int x = -halfCount; x <= halfCount; x++)
            {
                for (int z = -halfCount; z <= halfCount; z++)
                {
                    Vector3 pos = new Vector3(x * _markerSpacing, _markerHeight, z * _markerSpacing);
                    Gizmos.DrawWireSphere(pos, 1f);
                }
            }
        }
#endif
    }
}
