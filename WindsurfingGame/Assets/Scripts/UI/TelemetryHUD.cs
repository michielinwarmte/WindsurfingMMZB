using UnityEngine;
using UnityEngine.InputSystem;
using WindsurfingGame.Physics.Wind;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Player;

namespace WindsurfingGame.UI
{
    /// <summary>
    /// Displays real-time telemetry information on screen.
    /// Shows speed, wind, sail position, and other useful data.
    /// </summary>
    public class TelemetryHUD : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private WindsurferController _controller;
        [SerializeField] private WindsurferControllerV2 _controllerV2;
        [SerializeField] private Rigidbody _boardRigidbody;
        [SerializeField] private WindManager _windManager;
        [SerializeField] private ApparentWindCalculator _apparentWind;
        [SerializeField] private Sail _sail;
        [SerializeField] private WaterDrag _waterDrag;
        [SerializeField] private FinPhysics _finPhysics;

        [Header("Display Settings")]
        [SerializeField] private bool _showTelemetry = true;
        [SerializeField] private bool _showWindIndicator = true;
        [SerializeField] private bool _showControls = true;
        
        [Header("Styling")]
        [SerializeField] private int _fontSize = 18;
        [SerializeField] private Color _backgroundColor = new Color(0, 0, 0, 0.7f);
        [SerializeField] private Color _textColor = Color.white;
        [SerializeField] private Color _highlightColor = Color.cyan;

        // GUI styles
        private GUIStyle _boxStyle;
        private GUIStyle _labelStyle;
        private GUIStyle _headerStyle;
        private GUIStyle _valueStyle;
        private Texture2D _backgroundTexture;

        // Wind indicator
        private Texture2D _windArrowTexture;
        private Texture2D _boardIconTexture;

        private void Start()
        {
            // Auto-find references if not set
            FindReferences();
            CreateTextures();
        }

        private void FindReferences()
        {
            if (_windManager == null)
                _windManager = FindFirstObjectByType<WindManager>();
            
            // Try V2 controller first, then fall back to V1
            if (_controllerV2 == null)
                _controllerV2 = FindFirstObjectByType<WindsurferControllerV2>();
            
            if (_controller == null)
                _controller = FindFirstObjectByType<WindsurferController>();
            
            // Get board reference from whichever controller is present
            Transform boardTransform = null;
            if (_controllerV2 != null)
                boardTransform = _controllerV2.transform;
            else if (_controller != null)
                boardTransform = _controller.transform;
            
            if (boardTransform != null)
            {
                if (_boardRigidbody == null)
                    _boardRigidbody = boardTransform.GetComponent<Rigidbody>();
                if (_apparentWind == null)
                    _apparentWind = boardTransform.GetComponent<ApparentWindCalculator>();
                if (_sail == null)
                    _sail = boardTransform.GetComponent<Sail>();
                if (_waterDrag == null)
                    _waterDrag = boardTransform.GetComponent<WaterDrag>();
                if (_finPhysics == null)
                    _finPhysics = boardTransform.GetComponent<FinPhysics>();
            }
        }

        private void CreateTextures()
        {
            // Create background texture
            _backgroundTexture = new Texture2D(1, 1);
            _backgroundTexture.SetPixel(0, 0, _backgroundColor);
            _backgroundTexture.Apply();

            // Create simple arrow texture for wind indicator
            _windArrowTexture = CreateArrowTexture(Color.cyan, 64);
            _boardIconTexture = CreateBoardTexture(Color.white, 32);
        }

        private Texture2D CreateArrowTexture(Color color, int size)
        {
            Texture2D tex = new Texture2D(size, size);
            Color transparent = new Color(0, 0, 0, 0);
            
            // Fill with transparent
            for (int x = 0; x < size; x++)
                for (int y = 0; y < size; y++)
                    tex.SetPixel(x, y, transparent);

            // Draw arrow pointing up
            int centerX = size / 2;
            int tipY = size - 4;
            int baseY = 4;
            int width = size / 4;

            // Arrow shaft
            for (int y = baseY; y < tipY - size/4; y++)
            {
                for (int x = centerX - 2; x <= centerX + 2; x++)
                {
                    tex.SetPixel(x, y, color);
                }
            }

            // Arrow head
            for (int y = tipY - size/4; y <= tipY; y++)
            {
                int headWidth = (tipY - y) * width / (size/4);
                for (int x = centerX - headWidth; x <= centerX + headWidth; x++)
                {
                    tex.SetPixel(x, y, color);
                }
            }

            tex.Apply();
            return tex;
        }

        private Texture2D CreateBoardTexture(Color color, int size)
        {
            Texture2D tex = new Texture2D(size, size);
            Color transparent = new Color(0, 0, 0, 0);
            
            for (int x = 0; x < size; x++)
                for (int y = 0; y < size; y++)
                    tex.SetPixel(x, y, transparent);

            // Draw simple board shape (rectangle)
            int centerX = size / 2;
            int centerY = size / 2;
            int halfWidth = 3;
            int halfHeight = size / 2 - 4;

            for (int y = centerY - halfHeight; y <= centerY + halfHeight; y++)
            {
                for (int x = centerX - halfWidth; x <= centerX + halfWidth; x++)
                {
                    tex.SetPixel(x, y, color);
                }
            }

            // Pointed bow
            tex.SetPixel(centerX, centerY + halfHeight + 1, color);
            tex.SetPixel(centerX, centerY + halfHeight + 2, color);

            tex.Apply();
            return tex;
        }

        private void InitStyles()
        {
            if (_boxStyle != null) return;

            _boxStyle = new GUIStyle(GUI.skin.box);
            _boxStyle.normal.background = _backgroundTexture;

            _labelStyle = new GUIStyle(GUI.skin.label);
            _labelStyle.fontSize = _fontSize;
            _labelStyle.normal.textColor = _textColor;

            _headerStyle = new GUIStyle(_labelStyle);
            _headerStyle.fontStyle = FontStyle.Bold;
            _headerStyle.normal.textColor = _highlightColor;

            _valueStyle = new GUIStyle(_labelStyle);
            _valueStyle.alignment = TextAnchor.MiddleRight;
        }

        private void OnGUI()
        {
            InitStyles();

            if (_showTelemetry)
            {
                DrawTelemetryPanel();
            }

            if (_showWindIndicator)
            {
                DrawWindIndicator();
            }

            if (_showControls)
            {
                DrawControlsHelp();
            }
        }

        private void DrawTelemetryPanel()
        {
            float panelWidth = 220;
            float panelHeight = 410;
            float x = 10;
            float y = 10;
            float lineHeight = 24;

            GUI.Box(new Rect(x, y, panelWidth, panelHeight), "", _boxStyle);
            
            x += 10;
            y += 10;

            // Header
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "⛵ TELEMETRY", _headerStyle);
            y += lineHeight;
            
            // Control Mode Display - PROMINENT
            if (_controllerV2 != null)
            {
                string mode = _controllerV2.CurrentControlMode.ToString().ToUpper();
                GUIStyle modeStyle = new GUIStyle(_headerStyle);
                modeStyle.fontSize = _fontSize + 4;
                modeStyle.normal.textColor = Color.cyan;
                GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), $"[{mode} MODE]", modeStyle);
                y += lineHeight;
            }
            y += 5;

            // Speed section
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "── SPEED ──", _headerStyle);
            y += lineHeight;

            float speed = _boardRigidbody != null ? _boardRigidbody.linearVelocity.magnitude : 0;
            float speedKnots = speed * Utilities.PhysicsConstants.MS_TO_KNOTS;
            float speedKmh = speed * Utilities.PhysicsConstants.MS_TO_KMH;

            DrawLabelValue(x, y, panelWidth - 20, "Speed:", $"{speedKmh:F1} km/h");
            y += lineHeight;
            DrawLabelValue(x, y, panelWidth - 20, "Speed:", $"{speedKnots:F1} knots");
            y += lineHeight;

            // Planing indicator
            string planingStatus = _waterDrag != null && _waterDrag.IsPlaning ? "✓ PLANING" : "Displacement";
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), planingStatus, 
                _waterDrag != null && _waterDrag.IsPlaning ? _headerStyle : _labelStyle);
            y += lineHeight + 5;

            // Wind section
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "── WIND ──", _headerStyle);
            y += lineHeight;

            if (_windManager != null)
            {
                float windSpeed = _windManager.WindSpeed;
                float windKnots = windSpeed * Utilities.PhysicsConstants.MS_TO_KNOTS;
                DrawLabelValue(x, y, panelWidth - 20, "True Wind:", $"{windKnots:F1} kts");
                y += lineHeight;
            }

            if (_apparentWind != null)
            {
                float appWindKnots = _apparentWind.ApparentWindSpeed * Utilities.PhysicsConstants.MS_TO_KNOTS;
                DrawLabelValue(x, y, panelWidth - 20, "Apparent:", $"{appWindKnots:F1} kts");
                y += lineHeight;
                DrawLabelValue(x, y, panelWidth - 20, "Wind Angle:", $"{_apparentWind.ApparentWindAngle:F0}°");
                y += lineHeight;

                // Point of sail
                string pointOfSail = GetPointOfSail(_apparentWind.ApparentWindAngle);
                GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), pointOfSail, _labelStyle);
                y += lineHeight + 5;
            }

            // Sail section
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "── SAIL ──", _headerStyle);
            y += lineHeight;

            if (_sail != null)
            {
                int sheetPercent = Mathf.RoundToInt(_sail.SheetPosition * 100);
                DrawLabelValue(x, y, panelWidth - 20, "Sheet:", $"{sheetPercent}%");
                y += lineHeight;
                
                // Mast rake indicator
                string rakeDirection = _sail.MastRake < -0.1f ? "↑ UP" : (_sail.MastRake > 0.1f ? "↓ DOWN" : "CENTER");
                DrawLabelValue(x, y, panelWidth - 20, "Mast:", rakeDirection);
                y += lineHeight;
                
                DrawLabelValue(x, y, panelWidth - 20, "Force:", $"{_sail.TotalForce.magnitude:F0} N");
                y += lineHeight + 5;
            }

            // Fin section
            GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "── FIN ──", _headerStyle);
            y += lineHeight;

            if (_finPhysics != null)
            {
                DrawLabelValue(x, y, panelWidth - 20, "Slip Angle:", $"{_finPhysics.SlipAngle:F1}°");
                y += lineHeight;
                DrawLabelValue(x, y, panelWidth - 20, "Grip:", $"{_finPhysics.GetTrackingEfficiency() * 100:F0}%");
                y += lineHeight;
                
                // Tracking status
                string finStatus = _finPhysics.IsStalled ? "⚠ SLIDING" : "✓ TRACKING";
                GUIStyle statusStyle = _finPhysics.IsStalled ? _labelStyle : _headerStyle;
                GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), finStatus, statusStyle);
            }
            else
            {
                GUI.Label(new Rect(x, y, panelWidth - 20, lineHeight), "No fin", _labelStyle);
            }
        }

        private void DrawLabelValue(float x, float y, float width, string label, string value)
        {
            GUI.Label(new Rect(x, y, width * 0.5f, 24), label, _labelStyle);
            GUI.Label(new Rect(x + width * 0.5f, y, width * 0.5f, 24), value, _valueStyle);
        }

        private void DrawWindIndicator()
        {
            float size = 150;
            float x = Screen.width - size - 20;
            float y = 20;

            // Background circle
            GUI.Box(new Rect(x, y, size, size), "", _boxStyle);

            float centerX = x + size / 2;
            float centerY = y + size / 2;

            // Draw compass points
            GUI.Label(new Rect(centerX - 10, y + 5, 20, 20), "N", _labelStyle);
            GUI.Label(new Rect(x + size - 20, centerY - 10, 20, 20), "E", _labelStyle);
            GUI.Label(new Rect(centerX - 10, y + size - 25, 20, 20), "S", _labelStyle);
            GUI.Label(new Rect(x + 5, centerY - 10, 20, 20), "W", _labelStyle);

            // Draw board icon (rotated to match board heading)
            if (_boardRigidbody != null)
            {
                float boardHeading = _boardRigidbody.transform.eulerAngles.y;
                Matrix4x4 matrixBackup = GUI.matrix;
                GUIUtility.RotateAroundPivot(boardHeading, new Vector2(centerX, centerY));
                GUI.DrawTexture(new Rect(centerX - 16, centerY - 16, 32, 32), _boardIconTexture);
                GUI.matrix = matrixBackup;
            }

            // Draw wind arrow (rotated to show wind direction)
            if (_windManager != null)
            {
                // Wind direction is where it comes FROM, we show where it goes TO
                float windAngle = Mathf.Atan2(_windManager.WindDirection.x, _windManager.WindDirection.z) * Mathf.Rad2Deg;
                Matrix4x4 matrixBackup = GUI.matrix;
                GUIUtility.RotateAroundPivot(windAngle + 180, new Vector2(centerX, centerY));
                GUI.DrawTexture(new Rect(centerX - 32, centerY - 50, 64, 64), _windArrowTexture);
                GUI.matrix = matrixBackup;
            }

            // Draw apparent wind arrow (smaller, different color)
            if (_apparentWind != null && _apparentWind.ApparentWindSpeed > 0.5f)
            {
                Vector3 appWind = _apparentWind.ApparentWind;
                float appWindAngle = Mathf.Atan2(appWind.x, appWind.z) * Mathf.Rad2Deg;
                
                // Draw as line
                Matrix4x4 matrixBackup = GUI.matrix;
                GUIUtility.RotateAroundPivot(appWindAngle + 180, new Vector2(centerX, centerY));
                
                // Yellow line for apparent wind
                GUI.color = Color.yellow;
                GUI.DrawTexture(new Rect(centerX - 2, centerY - 40, 4, 35), Texture2D.whiteTexture);
                GUI.color = Color.white;
                
                GUI.matrix = matrixBackup;
            }

            // Legend
            GUI.Label(new Rect(x, y + size + 5, size, 20), "Cyan=True  Yellow=Apparent", _labelStyle);
        }

        private void DrawControlsHelp()
        {
            float panelWidth = 220;
            float panelHeight = 175;
            float x = 10;
            float y = Screen.height - panelHeight - 10;

            GUI.Box(new Rect(x, y, panelWidth, panelHeight), "", _boxStyle);

            x += 10;
            y += 10;

            // Show control mode if V2 controller is active
            if (_controllerV2 != null)
            {
                string mode = _controllerV2.CurrentControlMode.ToString().ToUpper();
                GUI.Label(new Rect(x, y, panelWidth - 20, 24), $"⌨ {mode} MODE", _headerStyle);
                y += 26;
                
                if (_controllerV2.CurrentControlMode == WindsurferControllerV2.ControlMode.Beginner)
                {
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "A/D - Steer Left/Right", _labelStyle);
                    y += 20;
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "W/S - Sheet In/Out", _labelStyle);
                    y += 20;
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "Q/E - Fine Mast Rake", _labelStyle);
                }
                else
                {
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "Q/E - Mast Rake (Steer)", _labelStyle);
                    y += 20;
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "A/D - Weight Shift", _labelStyle);
                    y += 20;
                    GUI.Label(new Rect(x, y, panelWidth - 20, 20), "W/S - Sheet In/Out", _labelStyle);
                }
                y += 24;
                GUI.Label(new Rect(x, y, panelWidth - 20, 20), "Tab - Switch Mode", _headerStyle);
            }
            else
            {
                GUI.Label(new Rect(x, y, panelWidth - 20, 24), "⌨ CONTROLS", _headerStyle);
                y += 28;
                GUI.Label(new Rect(x, y, panelWidth - 20, 20), "W/S - Sheet In/Out", _labelStyle);
                y += 22;
                GUI.Label(new Rect(x, y, panelWidth - 20, 20), "A/D - Edge/Rail Board", _labelStyle);
                y += 22;
                GUI.Label(new Rect(x, y, panelWidth - 20, 20), "Q/E - Mast Back/Forward", _labelStyle);
            }
            y += 24;
            GUI.Label(new Rect(x, y, panelWidth - 20, 20), "H - Toggle HUD", _labelStyle);
        }

        private string GetPointOfSail(float angle)
        {
            if (angle < 35) return "⚠ NO-GO ZONE";
            if (angle < 60) return "Close-hauled";
            if (angle < 80) return "Close Reach";
            if (angle < 110) return "Beam Reach ★";
            if (angle < 150) return "Broad Reach";
            return "Running";
        }

        private void Update()
        {
            // Toggle HUD with H key (using new Input System)
            var keyboard = Keyboard.current;
            if (keyboard != null && keyboard.hKey.wasPressedThisFrame)
            {
                _showTelemetry = !_showTelemetry;
                _showWindIndicator = !_showWindIndicator;
            }
        }

        private void OnDestroy()
        {
            // Clean up textures
            if (_backgroundTexture != null) Destroy(_backgroundTexture);
            if (_windArrowTexture != null) Destroy(_windArrowTexture);
            if (_boardIconTexture != null) Destroy(_boardIconTexture);
        }
    }
}
