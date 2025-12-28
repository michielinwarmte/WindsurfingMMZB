using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Buoyancy;
using WindsurfingGame.Player;

namespace WindsurfingGame.UI
{
    /// <summary>
    /// Advanced telemetry display for windsurfing physics data.
    /// Shows comprehensive real-time information about forces, velocities, and sailing state.
    /// </summary>
    public class AdvancedTelemetryHUD : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private AdvancedWindsurferController _controller;
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private AdvancedFin _fin;
        [SerializeField] private AdvancedHullDrag _hull;
        [SerializeField] private AdvancedBuoyancy _buoyancy;
        [SerializeField] private Rigidbody _boardRigidbody;
        
        [Header("Display Settings")]
        [SerializeField] private bool _showDetailed = true;
        [SerializeField] private bool _showForceVectors = false;
        [SerializeField] private bool _showPolar = false;
        [SerializeField] private int _fontSize = 12;
        
        [Header("Layout")]
        [SerializeField] private float _panelWidth = 250f;
        [SerializeField] private float _panelPadding = 10f;
        
        // GUI styles
        private GUIStyle _boxStyle;
        private GUIStyle _headerStyle;
        private GUIStyle _labelStyle;
        private GUIStyle _valueStyle;
        private GUIStyle _warningStyle;
        
        private bool _stylesInitialized = false;
        
        // Input System
        private Keyboard _keyboard;
        
        private void Start()
        {
            _keyboard = Keyboard.current;
            FindComponents();
        }
        
        private void FindComponents()
        {
            // Try to find controller first
            if (_controller == null)
                _controller = FindAnyObjectByType<AdvancedWindsurferController>();
            
            // Get components from controller's GameObject
            if (_controller != null)
            {
                GameObject target = _controller.gameObject;
                _sail = _sail ?? target.GetComponent<AdvancedSail>();
                _fin = _fin ?? target.GetComponent<AdvancedFin>();
                _hull = _hull ?? target.GetComponent<AdvancedHullDrag>();
                _buoyancy = _buoyancy ?? target.GetComponent<AdvancedBuoyancy>();
                _boardRigidbody = _boardRigidbody ?? target.GetComponent<Rigidbody>();
            }
            
            // Fallback: find components directly if no controller
            if (_sail == null)
                _sail = FindAnyObjectByType<AdvancedSail>();
            if (_fin == null)
                _fin = FindAnyObjectByType<AdvancedFin>();
            if (_hull == null)
                _hull = FindAnyObjectByType<AdvancedHullDrag>();
            if (_buoyancy == null)
                _buoyancy = FindAnyObjectByType<AdvancedBuoyancy>();
            
            // Get rigidbody from sail if found
            if (_boardRigidbody == null && _sail != null)
                _boardRigidbody = _sail.GetComponent<Rigidbody>();
                
            if (_sail == null)
            {
                Debug.LogWarning("AdvancedTelemetryHUD: No AdvancedSail found in scene!");
            }
        }
        
        private void Update()
        {
            if (_keyboard == null) return;
            
            // Toggle displays
            if (_keyboard.f1Key.wasPressedThisFrame)
                _showDetailed = !_showDetailed;
            if (_keyboard.f2Key.wasPressedThisFrame)
                _showForceVectors = !_showForceVectors;
            if (_keyboard.f3Key.wasPressedThisFrame)
                _showPolar = !_showPolar;
        }
        
        private void OnGUI()
        {
            InitStyles();
            
            if (_showDetailed)
            {
                DrawMainPanel();
            }
            else
            {
                DrawCompactPanel();
            }
            
            DrawHelpOverlay();
        }
        
        private void InitStyles()
        {
            if (_stylesInitialized) return;
            
            _boxStyle = new GUIStyle(GUI.skin.box)
            {
                padding = new RectOffset(8, 8, 8, 8)
            };
            
            _headerStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = _fontSize + 2,
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter
            };
            _headerStyle.normal.textColor = new Color(0.9f, 0.9f, 1f);
            
            _labelStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = _fontSize
            };
            _labelStyle.normal.textColor = new Color(0.8f, 0.8f, 0.8f);
            
            _valueStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = _fontSize,
                alignment = TextAnchor.MiddleRight
            };
            _valueStyle.normal.textColor = Color.white;
            
            _warningStyle = new GUIStyle(_valueStyle);
            _warningStyle.normal.textColor = new Color(1f, 0.6f, 0.2f);
            
            _stylesInitialized = true;
        }
        
        private void DrawMainPanel()
        {
            SailingState state = _sail?.State;
            if (state == null) return;
            
            float y = _panelPadding;
            Rect panelRect = new Rect(_panelPadding, y, _panelWidth, 500);
            
            GUILayout.BeginArea(panelRect, _boxStyle);
            
            // Header
            GUILayout.Label("WINDSURFING TELEMETRY", _headerStyle);
            GUILayout.Space(5);
            
            GUILayout.Space(10);
            
            // Speed Section
            GUILayout.Label("─── SPEED ───", _headerStyle);
            float speedKts = state.BoatSpeed * PhysicsConstants.MS_TO_KNOTS;
            float speedKmh = state.BoatSpeed * 3.6f;
            DrawRow("Boat Speed", $"{speedKmh:F1} km/h ({speedKts:F1} kts)", speedKmh > 25 ? _warningStyle : _valueStyle);
            DrawRow("VMG", $"{state.VMG * 3.6f:F1} km/h");
            
            if (_hull != null)
            {
                string hullMode = _hull.IsPlaning ? "PLANING" : "Displacement";
                DrawRow("Hull Mode", hullMode, _hull.IsPlaning ? _warningStyle : _valueStyle);
                DrawRow("Submerged", $"{_hull.GetSubmersionRatio() * 100f:F0}%");
            }
            
            GUILayout.Space(10);
            
            // Wind Section
            GUILayout.Label("─── WIND ───", _headerStyle);
            DrawRow("True Wind", $"{state.TrueWindSpeed * PhysicsConstants.MS_TO_KNOTS:F1} kts");
            DrawRow("Apparent Wind", $"{state.ApparentWindSpeed * PhysicsConstants.MS_TO_KNOTS:F1} kts");
            DrawRow("TWA", $"{state.TrueWindAngle:F0}°");
            DrawRow("AWA", $"{state.ApparentWindAngle:F0}°");
            
            GUILayout.Space(10);
            
            // Sail Section
            GUILayout.Label("─── SAIL ───", _headerStyle);
            if (_sail != null)
            {
                // Show current tack
                string tackStr = _sail.IsStarboardTack ? "STARBOARD" : "PORT";
                DrawRow("Tack", tackStr, _sail.IsStarboardTack ? _valueStyle : _warningStyle);
                
                // Display as "Sheet In %" where 100% = fully sheeted in (close to wind)
                float sheetInPercent = (1f - _sail.SheetPosition) * 100f;
                DrawRow("Sheet In", $"{sheetInPercent:F0}%");
                DrawRow("Sail Angle", $"{Mathf.Abs(_sail.CurrentSailAngle):F0}°");
                DrawRow("AoA", $"{state.AngleOfAttack:F1}°");
                DrawRow("Lift Force", $"{state.SailForce.magnitude:F0} N");
                
                bool stalled = Mathf.Abs(state.AngleOfAttack) > 25f;
                DrawRow("Status", stalled ? "STALLED!" : "OK", stalled ? _warningStyle : _valueStyle);
            }
            
            GUILayout.Space(10);;
            
            // Fin Section  
            GUILayout.Label("─── FIN ───", _headerStyle);
            if (_fin != null)
            {
                DrawRow("Leeway", $"{_fin.LeewayAngle:F1}°");
                DrawRow("Lift Force", $"{_fin.LiftForce.magnitude:F0} N");
                
                bool finStalled = _fin.IsStalled;
                DrawRow("Status", finStalled ? "STALLING!" : "OK", finStalled ? _warningStyle : _valueStyle);
            }
            
            GUILayout.Space(10);
            
            // Forces Section
            GUILayout.Label("─── FORCES ───", _headerStyle);
            DrawRow("Drive", $"{state.DriveForce:F0} N");
            DrawRow("Side", $"{state.SideForce:F0} N");
            DrawRow("Total Drag", $"{state.TotalDrag:F0} N");
            
            if (_buoyancy != null)
            {
                DrawRow("Buoyancy", $"{_buoyancy.TotalBuoyancyForce.magnitude:F0} N");
            }
            
            GUILayout.EndArea();
        }
        
        private void DrawCompactPanel()
        {
            SailingState state = _sail?.State;
            if (state == null) return;
            
            float speedKts = state.BoatSpeed * PhysicsConstants.MS_TO_KNOTS;
            float vmgKts = state.VMG * PhysicsConstants.MS_TO_KNOTS;
            
            Rect panelRect = new Rect(_panelPadding, _panelPadding, 150, 80);
            GUILayout.BeginArea(panelRect, _boxStyle);
            
            GUILayout.Label($"Speed: {speedKts:F1} kts", _valueStyle);
            GUILayout.Label($"VMG: {vmgKts:F1} kts", _valueStyle);
            GUILayout.Label($"AWA: {state.ApparentWindAngle:F0}°", _valueStyle);
            
            if (_hull != null && _hull.IsPlaning)
            {
                GUILayout.Label("PLANING", _warningStyle);
            }
            
            GUILayout.EndArea();
        }
        
        private void DrawHelpOverlay()
        {
            float y = Screen.height - 120;
            Rect helpRect = new Rect(_panelPadding, y, 320, 110);
            
            GUILayout.BeginArea(helpRect, _boxStyle);
            
            GUILayout.Label("Controls:", _labelStyle);
            GUILayout.Label("A/D: Steer | W/S: Sheet In/Out", _labelStyle);
            GUILayout.Label("SPACE: Switch Tack | T: Auto-sheet", _labelStyle);
            GUILayout.Label("Q/E: Fine Rake", _labelStyle);
            GUILayout.Label("F1: Toggle HUD | 1-4: Camera modes", _labelStyle);
            
            GUILayout.EndArea();
        }
        
        private void DrawRow(string label, string value, GUIStyle style = null)
        {
            GUILayout.BeginHorizontal();
            GUILayout.Label(label + ":", _labelStyle, GUILayout.Width(100));
            GUILayout.Label(value, style ?? _valueStyle);
            GUILayout.EndHorizontal();
        }
        
        private void OnDrawGizmos()
        {
            if (!_showForceVectors || !Application.isPlaying) return;
            
            SailingState state = _sail?.State;
            if (state == null) return;
            
            Vector3 pos = _sail.transform.position;
            
            // Sail force (blue)
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(pos + Vector3.up * 2f, state.SailForce * 0.01f);
            
            // Fin force (green)
            if (_fin != null)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(_fin.transform.position, _fin.LiftForce * 0.01f);
            }
            
            // Apparent wind (cyan)
            Gizmos.color = Color.cyan;
            Gizmos.DrawRay(pos + Vector3.up * 3f, state.ApparentWind.normalized * 2f);
            
            // Velocity (yellow)
            if (_boardRigidbody != null)
            {
                Gizmos.color = Color.yellow;
                Gizmos.DrawRay(pos, _boardRigidbody.linearVelocity);
            }
        }
    }
}
