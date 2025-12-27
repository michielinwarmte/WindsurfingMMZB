using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Environment;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Runtime force vector visualization using LineRenderers.
    /// Shows sail forces, fin forces, and wind direction in Game view.
    /// </summary>
    public class ForceVectorVisualizer : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private AdvancedFin _fin;
        [SerializeField] private Rigidbody _rigidbody;
        
        [Header("Display Settings")]
        [SerializeField] private bool _showSailForces = true;
        [SerializeField] private bool _showFinForces = true;
        [SerializeField] private bool _showWindDirection = true;
        [SerializeField] private bool _showVelocity = true;
        
        [Header("Scale")]
        [SerializeField] private float _forceScale = 0.003f;
        [SerializeField] private float _windScale = 0.5f;
        [SerializeField] private float _velocityScale = 0.5f;
        [SerializeField] private float _lineWidth = 0.05f;
        
        [Header("Colors")]
        [SerializeField] private Color _sailForceColor = Color.cyan;
        [SerializeField] private Color _liftColor = Color.green;
        [SerializeField] private Color _dragColor = Color.red;
        [SerializeField] private Color _windColor = new Color(0.3f, 0.5f, 1f);
        [SerializeField] private Color _velocityColor = Color.yellow;
        [SerializeField] private Color _finLiftColor = new Color(0f, 0.8f, 0.4f);
        
        // LineRenderers
        private LineRenderer _sailForceLine;
        private LineRenderer _liftLine;
        private LineRenderer _dragLine;
        private LineRenderer _windLine;
        private LineRenderer _velocityLine;
        private LineRenderer _finLiftLine;
        
        // Arrow heads
        private GameObject _sailForceArrow;
        private GameObject _windArrow;
        private GameObject _velocityArrow;
        
        private void Start()
        {
            FindComponents();
            CreateLineRenderers();
        }
        
        private void FindComponents()
        {
            if (_sail == null) _sail = GetComponent<AdvancedSail>();
            if (_sail == null) _sail = FindAnyObjectByType<AdvancedSail>();
            
            if (_fin == null) _fin = GetComponent<AdvancedFin>();
            if (_fin == null && _sail != null) _fin = _sail.GetComponent<AdvancedFin>();
            
            if (_rigidbody == null && _sail != null) _rigidbody = _sail.GetComponent<Rigidbody>();
        }
        
        private void CreateLineRenderers()
        {
            // Create container
            GameObject container = new GameObject("ForceVectors");
            container.transform.SetParent(transform);
            
            // Sail force (cyan)
            _sailForceLine = CreateLine("SailForce", _sailForceColor, container.transform);
            _sailForceArrow = CreateArrowHead("SailForceArrow", _sailForceColor, container.transform);
            
            // Lift (green)
            _liftLine = CreateLine("Lift", _liftColor, container.transform);
            
            // Drag (red)
            _dragLine = CreateLine("Drag", _dragColor, container.transform);
            
            // Wind (blue)
            _windLine = CreateLine("Wind", _windColor, container.transform);
            _windArrow = CreateArrowHead("WindArrow", _windColor, container.transform);
            
            // Velocity (yellow)
            _velocityLine = CreateLine("Velocity", _velocityColor, container.transform);
            _velocityArrow = CreateArrowHead("VelocityArrow", _velocityColor, container.transform);
            
            // Fin lift (teal)
            _finLiftLine = CreateLine("FinLift", _finLiftColor, container.transform);
        }
        
        private LineRenderer CreateLine(string name, Color color, Transform parent)
        {
            GameObject lineObj = new GameObject(name);
            lineObj.transform.SetParent(parent);
            
            LineRenderer lr = lineObj.AddComponent<LineRenderer>();
            // Use URP-compatible shader
            Shader shader = Shader.Find("Universal Render Pipeline/Unlit");
            if (shader == null) shader = Shader.Find("Sprites/Default"); // Fallback
            lr.material = new Material(shader);
            lr.material.color = color;
            lr.startColor = color;
            lr.endColor = color;
            lr.startWidth = _lineWidth;
            lr.endWidth = _lineWidth * 0.5f;
            lr.positionCount = 2;
            lr.useWorldSpace = true;
            
            return lr;
        }
        
        private GameObject CreateArrowHead(string name, Color color, Transform parent)
        {
            GameObject arrow = GameObject.CreatePrimitive(PrimitiveType.Cube);
            arrow.name = name;
            arrow.transform.SetParent(parent);
            arrow.transform.localScale = new Vector3(0.15f, 0.15f, 0.3f);
            
            // Remove collider
            Destroy(arrow.GetComponent<Collider>());
            
            // Set material with URP shader
            Renderer rend = arrow.GetComponent<Renderer>();
            Shader shader = Shader.Find("Universal Render Pipeline/Unlit");
            if (shader == null) shader = Shader.Find("Sprites/Default"); // Fallback
            rend.material = new Material(shader);
            rend.material.color = color;
            
            return arrow;
        }
        
        private void LateUpdate()
        {
            if (_sail == null) return;
            
            SailingState state = _sail.State;
            if (state == null) return;
            
            Vector3 cePos = _sail.CenterOfEffort;
            Vector3 boardPos = _sail.transform.position;
            
            // Sail total force
            if (_showSailForces && _sailForceLine != null)
            {
                Vector3 forceEnd = cePos + state.SailForce * _forceScale;
                UpdateLine(_sailForceLine, cePos, forceEnd, state.SailForce.magnitude > 10f);
                UpdateArrow(_sailForceArrow, forceEnd, state.SailForce.normalized, state.SailForce.magnitude > 10f);
                
                // Lift and drag
                UpdateLine(_liftLine, cePos, cePos + state.SailLift * _forceScale, state.SailLift.magnitude > 5f);
                UpdateLine(_dragLine, cePos, cePos + state.SailDrag * _forceScale, state.SailDrag.magnitude > 5f);
            }
            else
            {
                _sailForceLine?.gameObject.SetActive(false);
                _liftLine?.gameObject.SetActive(false);
                _dragLine?.gameObject.SetActive(false);
                _sailForceArrow?.SetActive(false);
            }
            
            // Wind direction
            if (_showWindDirection && _windLine != null)
            {
                Vector3 windStart = boardPos + Vector3.up * 3f;
                Vector3 windEnd = windStart + state.ApparentWind * _windScale;
                UpdateLine(_windLine, windStart, windEnd, state.ApparentWindSpeed > 0.5f);
                UpdateArrow(_windArrow, windEnd, state.ApparentWind.normalized, state.ApparentWindSpeed > 0.5f);
            }
            else
            {
                _windLine?.gameObject.SetActive(false);
                _windArrow?.SetActive(false);
            }
            
            // Velocity
            if (_showVelocity && _velocityLine != null && _rigidbody != null)
            {
                Vector3 vel = _rigidbody.linearVelocity;
                Vector3 velStart = boardPos + Vector3.up * 0.5f;
                Vector3 velEnd = velStart + vel * _velocityScale;
                UpdateLine(_velocityLine, velStart, velEnd, vel.magnitude > 0.5f);
                UpdateArrow(_velocityArrow, velEnd, vel.normalized, vel.magnitude > 0.5f);
            }
            else
            {
                _velocityLine?.gameObject.SetActive(false);
                _velocityArrow?.SetActive(false);
            }
            
            // Fin lift
            if (_showFinForces && _finLiftLine != null && _fin != null)
            {
                Vector3 finPos = _fin.transform.TransformPoint(_fin.Config.Position);
                Vector3 finForceEnd = finPos + _fin.LiftForce * _forceScale;
                UpdateLine(_finLiftLine, finPos, finForceEnd, _fin.LiftForce.magnitude > 5f);
            }
            else
            {
                _finLiftLine?.gameObject.SetActive(false);
            }
        }
        
        private void UpdateLine(LineRenderer lr, Vector3 start, Vector3 end, bool visible)
        {
            if (lr == null) return;
            
            lr.gameObject.SetActive(visible);
            if (visible)
            {
                lr.SetPosition(0, start);
                lr.SetPosition(1, end);
            }
        }
        
        private void UpdateArrow(GameObject arrow, Vector3 position, Vector3 direction, bool visible)
        {
            if (arrow == null) return;
            
            arrow.SetActive(visible);
            if (visible && direction.sqrMagnitude > 0.001f)
            {
                arrow.transform.position = position;
                arrow.transform.rotation = Quaternion.LookRotation(direction);
            }
        }
        
        private void OnDestroy()
        {
            // Clean up created objects
            if (_sailForceLine != null) Destroy(_sailForceLine.gameObject.transform.parent.gameObject);
        }
    }
}
