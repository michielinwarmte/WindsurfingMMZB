using UnityEngine;
using WindsurfingGame.Environment;
using WindsurfingGame.Physics.Wind;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Creates visual wind direction indicators on the water surface.
    /// Shows wind streaks/arrows on the water to help visualize wind direction.
    /// </summary>
    public class WindDirectionIndicator : MonoBehaviour
    {
        [Header("Wind Source")]
        [SerializeField] private WindSystem _windSystem;
        
        [Header("Indicator Settings")]
        [Tooltip("Number of wind arrows to show")]
        [SerializeField] private int _arrowCount = 12;
        
        [Tooltip("Radius around player to show arrows")]
        [SerializeField] private float _radius = 30f;
        
        [Tooltip("Height above water")]
        [SerializeField] private float _height = 0.1f;
        
        [Tooltip("Arrow size")]
        [SerializeField] private float _arrowSize = 3f;
        
        [Tooltip("Arrow color")]
        [SerializeField] private Color _arrowColor = new Color(0.5f, 0.7f, 1f, 0.6f);
        
        [Header("Animation")]
        [Tooltip("Animate arrows moving with wind")]
        [SerializeField] private bool _animate = true;
        
        [Tooltip("Animation speed multiplier")]
        [SerializeField] private float _animationSpeed = 1f;
        
        [Header("Target")]
        [Tooltip("Follow this transform (player/camera)")]
        [SerializeField] private Transform _followTarget;
        
        // Arrow objects
        private GameObject[] _arrows;
        private float[] _arrowOffsets;
        private Material _arrowMaterial;
        
        private void Start()
        {
            FindWindSystem();
            FindTarget();
            CreateArrows();
        }
        
        private void FindWindSystem()
        {
            if (_windSystem == null)
            {
                _windSystem = WindSystem.Instance;
                if (_windSystem == null)
                {
                    _windSystem = FindAnyObjectByType<WindSystem>();
                }
            }
        }
        
        private void FindTarget()
        {
            if (_followTarget == null)
            {
                // Try to find player/camera
                var cam = Camera.main;
                if (cam != null) _followTarget = cam.transform;
            }
        }
        
        private void CreateArrows()
        {
            _arrows = new GameObject[_arrowCount];
            _arrowOffsets = new float[_arrowCount];
            
            // Create shared material
            _arrowMaterial = new Material(Shader.Find("Sprites/Default"));
            _arrowMaterial.color = _arrowColor;
            
            GameObject container = new GameObject("WindArrows");
            container.transform.SetParent(transform);
            
            for (int i = 0; i < _arrowCount; i++)
            {
                _arrows[i] = CreateArrow(container.transform, i);
                _arrowOffsets[i] = Random.Range(0f, _radius * 2f);
            }
        }
        
        private GameObject CreateArrow(Transform parent, int index)
        {
            GameObject arrow = new GameObject($"WindArrow_{index}");
            arrow.transform.SetParent(parent);
            
            // Create arrow shape using line renderers
            // Main shaft
            LineRenderer shaft = CreateLineChild(arrow, "Shaft", 
                new Vector3[] { Vector3.zero, Vector3.forward * _arrowSize },
                _arrowSize * 0.08f, _arrowSize * 0.04f);
            
            // Left wing
            LineRenderer leftWing = CreateLineChild(arrow, "LeftWing",
                new Vector3[] { Vector3.forward * _arrowSize, 
                               Vector3.forward * (_arrowSize * 0.6f) + Vector3.left * (_arrowSize * 0.3f) },
                _arrowSize * 0.06f, _arrowSize * 0.02f);
            
            // Right wing
            LineRenderer rightWing = CreateLineChild(arrow, "RightWing",
                new Vector3[] { Vector3.forward * _arrowSize,
                               Vector3.forward * (_arrowSize * 0.6f) + Vector3.right * (_arrowSize * 0.3f) },
                _arrowSize * 0.06f, _arrowSize * 0.02f);
            
            return arrow;
        }
        
        private LineRenderer CreateLineChild(GameObject parent, string name, Vector3[] positions, float startWidth, float endWidth)
        {
            GameObject lineObj = new GameObject(name);
            lineObj.transform.SetParent(parent.transform);
            lineObj.transform.localPosition = Vector3.zero;
            lineObj.transform.localRotation = Quaternion.identity;
            
            LineRenderer lr = lineObj.AddComponent<LineRenderer>();
            lr.material = _arrowMaterial;
            lr.startWidth = startWidth;
            lr.endWidth = endWidth;
            lr.positionCount = positions.Length;
            lr.useWorldSpace = false;
            lr.SetPositions(positions);
            
            return lr;
        }
        
        private void Update()
        {
            if (_windSystem == null || _arrows == null) return;
            
            // Get wind direction (direction wind is blowing TO)
            Vector3 windDir = _windSystem.GetWindAtPosition(transform.position).normalized;
            if (windDir.sqrMagnitude < 0.01f) return;
            
            // Flatten to horizontal
            windDir.y = 0;
            windDir.Normalize();
            
            // Get center position
            Vector3 center = _followTarget != null ? _followTarget.position : transform.position;
            center.y = _height;
            
            // Get perpendicular direction for spreading arrows
            Vector3 perpDir = Vector3.Cross(Vector3.up, windDir).normalized;
            
            float windSpeed = _windSystem.WindSpeedMS;
            
            for (int i = 0; i < _arrowCount; i++)
            {
                if (_arrows[i] == null) continue;
                
                // Calculate grid position
                int row = i / 4;
                int col = i % 4;
                
                float lateralOffset = (col - 1.5f) * (_radius * 0.5f);
                float forwardBase = (row - 1f) * (_radius * 0.5f);
                
                // Animate arrows moving with wind
                if (_animate)
                {
                    _arrowOffsets[i] += windSpeed * _animationSpeed * Time.deltaTime;
                    if (_arrowOffsets[i] > _radius) _arrowOffsets[i] -= _radius * 2f;
                }
                
                float forwardOffset = forwardBase + _arrowOffsets[i];
                
                // Position arrow
                Vector3 pos = center + perpDir * lateralOffset + windDir * forwardOffset;
                pos.y = _height;
                
                _arrows[i].transform.position = pos;
                _arrows[i].transform.rotation = Quaternion.LookRotation(windDir, Vector3.up);
                
                // Fade based on distance from center
                float dist = Vector3.Distance(pos, center);
                float alpha = Mathf.Clamp01(1f - (dist / _radius) * 0.5f) * _arrowColor.a;
                
                // Update alpha on line renderers
                foreach (var lr in _arrows[i].GetComponentsInChildren<LineRenderer>())
                {
                    Color c = _arrowColor;
                    c.a = alpha;
                    lr.startColor = c;
                    lr.endColor = c;
                }
            }
        }
        
        private void OnDestroy()
        {
            if (_arrowMaterial != null) Destroy(_arrowMaterial);
        }
        
#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            // Show coverage area
            Gizmos.color = new Color(0.5f, 0.7f, 1f, 0.3f);
            Vector3 center = _followTarget != null ? _followTarget.position : transform.position;
            center.y = _height;
            Gizmos.DrawWireSphere(center, _radius);
        }
#endif
    }
}
