using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Wind;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Creates a visual representation of the sail showing:
    /// - Mast rake (tilts forward/back around fixed base)
    /// - Boom/sail angle (sheet position)
    /// - Sail power (billowing based on wind force)
    /// 
    /// NEW: Can work with either:
    /// 1. Real 3D sail model (reads transform from actual Sail GameObject)
    /// 2. Generated visual (creates simple geometry if no model exists)
    /// </summary>
    public class SailVisualizer : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Sail _sail;
        [SerializeField] private ApparentWindCalculator _apparentWind;
        [SerializeField] private Transform _sailTransform; // NEW: Reference to actual sail model

        [Header("Visualization Mode")]
        [Tooltip("Use the real 3D sail model transform (recommended) or generate simple geometry")]
        [SerializeField] private bool _useRealSailModel = true;

        [Header("Mast Settings")]
        [Tooltip("Height of the mast")]
        [SerializeField] private float _mastHeight = 4.5f;
        
        [Tooltip("Mast thickness")]
        [SerializeField] private float _mastRadius = 0.04f;
        
        [Tooltip("Maximum rake angle in degrees")]
        [SerializeField] private float _maxRakeAngle = 15f;
        
        [Tooltip("FIXED base position of mast foot (1.2m from tail on 2.5m board = Z: -0.05)")]
        [SerializeField] private Vector3 _mastBasePosition = new Vector3(0, 0.1f, -0.05f);

        [Header("Boom Settings")]
        [Tooltip("Length of the boom")]
        [SerializeField] private float _boomLength = 2.5f;
        
        [Tooltip("Height of boom attachment on mast")]
        [SerializeField] private float _boomHeight = 1.5f;
        
        [Tooltip("Boom thickness")]
        [SerializeField] private float _boomRadius = 0.03f;

        [Header("Colors")]
        [SerializeField] private Color _mastColor = new Color(0.3f, 0.3f, 0.3f);
        [SerializeField] private Color _boomColor = new Color(0.4f, 0.4f, 0.4f);
        [SerializeField] private Color _sailColor = new Color(1f, 0.3f, 0.1f, 0.8f);
        [SerializeField] private Color _sailPoweredColor = new Color(1f, 0.5f, 0.2f, 0.9f);

        [Header("Animation")]
        [Tooltip("How quickly the visual responds to changes")]
        [SerializeField] private float _smoothSpeed = 8f;

        // Created GameObjects
        private GameObject _mastObject;
        private GameObject _boomObject;
        private GameObject _sailObject;
        private GameObject _rigPivot; // Parent for all rig parts

        // Materials
        private Material _mastMaterial;
        private Material _boomMaterial;
        private Material _sailMaterial;

        // Current state (smoothed)
        private float _currentRake;
        private float _currentSailAngle;
        private float _currentPower;

        private void Awake()
        {
            // Try to find Sail - check this object, children, and parent hierarchy
            if (_sail == null)
                _sail = GetComponent<Sail>();
            if (_sail == null)
                _sail = GetComponentInChildren<Sail>();
            if (_sail == null)
            {
                var rig = GetComponentInParent<WindsurfRig>();
                if (rig != null)
                    _sail = rig.Sail;
            }
            
            // Find ApparentWindCalculator on same object as Sail
            if (_apparentWind == null && _sail != null)
                _apparentWind = _sail.GetComponent<ApparentWindCalculator>();
            if (_apparentWind == null)
                _apparentWind = GetComponent<ApparentWindCalculator>();
            if (_apparentWind == null)
                _apparentWind = GetComponentInChildren<ApparentWindCalculator>();
            
            // Find the real sail transform (if using real model)
            if (_useRealSailModel && _sailTransform == null && _sail != null)
            {
                _sailTransform = _sail.transform;
            }
        }

        private void Start()
        {
            // Only create visual geometry if we're not using the real sail model
            if (!_useRealSailModel)
            {
                CreateRig();
            }
        }

        private void Update()
        {
            UpdateRigPosition();
        }

        private void CreateRig()
        {
            // Create parent pivot for the entire rig
            _rigPivot = new GameObject("RigPivot");
            _rigPivot.transform.SetParent(transform);
            _rigPivot.transform.localPosition = _mastBasePosition;
            _rigPivot.transform.localRotation = Quaternion.identity;

            // Create materials
            _mastMaterial = CreateMaterial(_mastColor);
            _boomMaterial = CreateMaterial(_boomColor);
            _sailMaterial = CreateSailMaterial(_sailColor);

            // Create mast (cylinder)
            _mastObject = CreateCylinder("Mast", _mastRadius, _mastHeight, _mastMaterial);
            _mastObject.transform.SetParent(_rigPivot.transform);
            _mastObject.transform.localPosition = new Vector3(0, _mastHeight / 2, 0);
            _mastObject.transform.localRotation = Quaternion.identity;

            // Create boom (cylinder, rotated)
            _boomObject = CreateCylinder("Boom", _boomRadius, _boomLength, _boomMaterial);
            _boomObject.transform.SetParent(_rigPivot.transform);
            _boomObject.transform.localPosition = new Vector3(0, _boomHeight, 0);
            // Will be rotated in UpdateRigPosition

            // Create sail (quad mesh)
            _sailObject = CreateSailMesh();
            _sailObject.transform.SetParent(_rigPivot.transform);
        }

        private Material CreateMaterial(Color color)
        {
            // Try to use URP Lit shader, fall back to Standard
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null)
                shader = Shader.Find("Standard");
            
            Material mat = new Material(shader);
            mat.color = color;
            return mat;
        }

        private Material CreateSailMaterial(Color color)
        {
            // Use transparent shader for sail
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null)
                shader = Shader.Find("Standard");
            
            Material mat = new Material(shader);
            mat.color = color;
            
            // Enable transparency
            mat.SetFloat("_Surface", 1); // 0 = Opaque, 1 = Transparent (URP)
            mat.SetFloat("_Blend", 0); // Alpha blend
            mat.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            mat.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            mat.SetInt("_ZWrite", 0);
            mat.EnableKeyword("_ALPHABLEND_ON");
            mat.renderQueue = 3000;
            
            return mat;
        }

        private GameObject CreateCylinder(string name, float radius, float height, Material material)
        {
            GameObject cylinder = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            cylinder.name = name;
            
            // Remove collider
            Collider col = cylinder.GetComponent<Collider>();
            if (col != null) Destroy(col);

            // Scale cylinder (default is 2 units high, 1 unit diameter)
            cylinder.transform.localScale = new Vector3(radius * 2, height / 2, radius * 2);
            
            // Apply material
            cylinder.GetComponent<Renderer>().material = material;
            
            return cylinder;
        }

        private GameObject CreateSailMesh()
        {
            GameObject sail = new GameObject("Sail");
            
            MeshFilter meshFilter = sail.AddComponent<MeshFilter>();
            MeshRenderer meshRenderer = sail.AddComponent<MeshRenderer>();
            
            // Create a triangular sail mesh
            Mesh mesh = new Mesh();
            mesh.name = "SailMesh";

            // Sail vertices - sail extends BACKWARD (negative Z) from mast
            // Mast is at origin, sail goes back toward the tail
            Vector3[] vertices = new Vector3[]
            {
                // Luff edge (along mast) - at mast position
                new Vector3(0, 0.3f, 0),                    // Tack (bottom of sail on mast)
                new Vector3(0, _mastHeight * 0.95f, 0),     // Head (top of sail)
                
                // Leech edge (back of sail) - extends BACKWARD (negative Z)
                new Vector3(0, _boomHeight, -_boomLength * 0.85f),      // Clew (boom end)
                new Vector3(0, _mastHeight * 0.55f, -_boomLength * 0.5f), // Mid leech
            };

            // Two triangles to make a quad-ish sail (double-sided)
            int[] triangles = new int[]
            {
                0, 1, 3,  // Upper triangle (front face)
                0, 3, 2,  // Lower triangle (front face)
                // Back faces (so sail is visible from both sides)
                0, 3, 1,
                0, 2, 3
            };

            Vector2[] uvs = new Vector2[]
            {
                new Vector2(0, 0),
                new Vector2(0, 1),
                new Vector2(1, 0.4f),
                new Vector2(0.6f, 0.75f)
            };

            mesh.vertices = vertices;
            mesh.triangles = triangles;
            mesh.uv = uvs;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();

            meshFilter.mesh = mesh;
            meshRenderer.material = _sailMaterial;
            
            // Disable shadow casting for transparent sail
            meshRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;

            return sail;
        }

        private void UpdateRigPosition()
        {
            if (_sail == null) return;

            // If using real sail model, the rotation is handled by WindsurfRig script
            // We just need to visualize power/state if needed
            if (_useRealSailModel && _sailTransform != null)
            {
                // The real sail is already being rotated by WindsurfRig.UpdateSailVisualRotation()
                // We can add visual effects here later (like changing material based on power)
                return;
            }

            // Original visualization code for generated geometry
            if (_rigPivot == null) return;

            // Get target values from sail simulation
            float targetRake = _sail.MastRake * _maxRakeAngle;
            // READ sail angle directly from simulation - this is the key change!
            // The simulation calculates the sail angle based on wind and sheet position
            float targetSailAngle = _sail.CurrentSailAngle;
            float targetPower = _sail.TotalForce.magnitude / 500f; // Normalize power

            // Smooth the values for visual appeal
            _currentRake = Mathf.Lerp(_currentRake, targetRake, Time.deltaTime * _smoothSpeed);
            _currentSailAngle = Mathf.Lerp(_currentSailAngle, targetSailAngle, Time.deltaTime * _smoothSpeed);
            _currentPower = Mathf.Lerp(_currentPower, Mathf.Clamp01(targetPower), Time.deltaTime * _smoothSpeed);

            // Apply mast rake (rotate entire rig forward/back)
            // Negative rake = forward = rotate around X axis
            _rigPivot.transform.localRotation = Quaternion.Euler(-_currentRake, 0, 0);

            // Apply sail angle from simulation
            // The simulation already handles which side the sail is on based on wind
            float boomAngle = _currentSailAngle;
            
            // Boom extends BACKWARD from mast, then rotated by boomAngle
            // Boom center is halfway along its length, going backward
            Vector3 boomDirection = Quaternion.Euler(0, boomAngle, 0) * new Vector3(0, 0, -_boomLength / 2);
            _boomObject.transform.localPosition = new Vector3(0, _boomHeight, 0) + boomDirection;
            _boomObject.transform.localRotation = Quaternion.Euler(0, boomAngle, 90); // 90 to make horizontal

            // Update sail mesh to follow boom angle
            UpdateSailMesh(boomAngle);

            // Update sail color based on power
            Color sailColor = Color.Lerp(_sailColor, _sailPoweredColor, _currentPower);
            _sailMaterial.color = sailColor;
        }

        private void UpdateSailMesh(float angle)
        {
            if (_sailObject == null) return;

            MeshFilter meshFilter = _sailObject.GetComponent<MeshFilter>();
            if (meshFilter == null || meshFilter.mesh == null) return;

            Mesh mesh = meshFilter.mesh;
            
            // Rotate sail vertices based on boom angle
            float radians = angle * Mathf.Deg2Rad;
            float sin = Mathf.Sin(radians);
            float cos = Mathf.Cos(radians);

            // Base vertices point BACKWARD (negative Z), then rotated around Y
            Vector3[] vertices = new Vector3[]
            {
                new Vector3(0, 0.3f, 0),  // Tack (stays at mast)
                new Vector3(0, _mastHeight * 0.95f, 0),  // Head (stays at mast top)
                RotateY(new Vector3(0, _boomHeight, -_boomLength * 0.85f), sin, cos),  // Clew
                RotateY(new Vector3(0, _mastHeight * 0.55f, -_boomLength * 0.5f), sin, cos),  // Mid leech
            };

            // Add some billow based on power (pushes sail to leeward side)
            float billow = _currentPower * 0.25f;
            float billowSide = Mathf.Sign(angle);
            vertices[2] += new Vector3(billow * billowSide, 0, 0);
            vertices[3] += new Vector3(billow * 0.6f * billowSide, 0, 0);

            mesh.vertices = vertices;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
        }

        private Vector3 RotateY(Vector3 point, float sin, float cos)
        {
            return new Vector3(
                point.x * cos + point.z * sin,
                point.y,
                -point.x * sin + point.z * cos
            );
        }

        private void OnDestroy()
        {
            // Clean up created materials
            if (_mastMaterial != null) Destroy(_mastMaterial);
            if (_boomMaterial != null) Destroy(_boomMaterial);
            if (_sailMaterial != null) Destroy(_sailMaterial);
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Draw mast base position
            Gizmos.color = Color.yellow;
            Vector3 basePos = transform.TransformPoint(_mastBasePosition);
            Gizmos.DrawWireSphere(basePos, 0.1f);

            // Draw mast line
            Gizmos.color = Color.gray;
            Gizmos.DrawLine(basePos, basePos + transform.up * _mastHeight);

            // Draw rake range
            Gizmos.color = new Color(1, 1, 0, 0.3f);
            Vector3 forwardRake = Quaternion.AngleAxis(-_maxRakeAngle, transform.right) * (transform.up * _mastHeight);
            Vector3 backRake = Quaternion.AngleAxis(_maxRakeAngle, transform.right) * (transform.up * _mastHeight);
            Gizmos.DrawLine(basePos, basePos + forwardRake);
            Gizmos.DrawLine(basePos, basePos + backRake);
        }
#endif
    }
}
