using UnityEngine;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Wind;

namespace WindsurfingGame.UI
{
    /// <summary>
    /// Draws a 2D top-down view of the board and sail position.
    /// Shows mast rake (forward/back tilt) and sheet position (sail angle).
    /// 
    /// Mast base is FIXED at 1.2m from back of board (realistic position).
    /// Rake rotates the mast around this fixed point, not moving the base.
    /// </summary>
    public class SailPositionIndicator : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Sail _sail;
        [SerializeField] private ApparentWindCalculator _apparentWind;
        [SerializeField] private Rigidbody _boardRigidbody;

        [Header("Position")]
        [SerializeField] private Vector2 _position = new Vector2(20, 420);
        [SerializeField] private float _size = 120f;

        [Header("Board Dimensions")]
        [Tooltip("Board length in meters (for scale)")]
        [SerializeField] private float _boardLengthMeters = 2.5f;
        
        [Tooltip("Distance from tail to mast base in meters")]
        [SerializeField] private float _mastFromTail = 1.2f;

        [Header("Colors")]
        [SerializeField] private Color _backgroundColor = new Color(0, 0, 0, 0.7f);
        [SerializeField] private Color _boardColor = new Color(0.6f, 0.4f, 0.2f);
        [SerializeField] private Color _mastColor = Color.gray;
        [SerializeField] private Color _sailColor = new Color(1f, 0.4f, 0.1f);
        [SerializeField] private Color _sailPoweredColor = new Color(1f, 0.6f, 0.2f);
        [SerializeField] private Color _windColor = Color.cyan;
        [SerializeField] private Color _textColor = Color.white;

        // GUI resources
        private Texture2D _backgroundTexture;
        private Texture2D _whiteTexture;
        private GUIStyle _labelStyle;

        // Smoothed values
        private float _displayRake;
        private float _displaySheet;
        private float _displayPower;
        private float _displaySailAngle;

        private void Start()
        {
            FindReferences();
            CreateTextures();
        }

        private void FindReferences()
        {
            if (_sail == null)
                _sail = FindFirstObjectByType<Sail>();
            if (_apparentWind == null)
                _apparentWind = FindFirstObjectByType<ApparentWindCalculator>();
            if (_boardRigidbody == null && _sail != null)
                _boardRigidbody = _sail.GetComponent<Rigidbody>();
        }

        private void CreateTextures()
        {
            _backgroundTexture = new Texture2D(1, 1);
            _backgroundTexture.SetPixel(0, 0, _backgroundColor);
            _backgroundTexture.Apply();

            _whiteTexture = new Texture2D(1, 1);
            _whiteTexture.SetPixel(0, 0, Color.white);
            _whiteTexture.Apply();
        }

        private void OnGUI()
        {
            if (_sail == null) return;

            InitStyles();
            
            // Smooth the display values - read from simulation
            _displayRake = Mathf.Lerp(_displayRake, _sail.MastRake, Time.deltaTime * 8f);
            _displaySheet = Mathf.Lerp(_displaySheet, _sail.SheetPosition, Time.deltaTime * 8f);
            _displayPower = Mathf.Lerp(_displayPower, Mathf.Clamp01(_sail.TotalForce.magnitude / 500f), Time.deltaTime * 5f);
            // Read sail angle directly from simulation
            _displaySailAngle = Mathf.Lerp(_displaySailAngle, _sail.CurrentSailAngle, Time.deltaTime * 8f);

            DrawIndicator();
        }

        private void InitStyles()
        {
            if (_labelStyle != null) return;

            _labelStyle = new GUIStyle(GUI.skin.label);
            _labelStyle.fontSize = 14;
            _labelStyle.normal.textColor = _textColor;
            _labelStyle.alignment = TextAnchor.MiddleCenter;
        }

        private void DrawIndicator()
        {
            float x = _position.x;
            float y = _position.y;
            float size = _size;

            // Background
            GUI.DrawTexture(new Rect(x, y, size, size + 40), _backgroundTexture);

            // Title
            GUI.Label(new Rect(x, y + 5, size, 20), "SAIL POSITION", _labelStyle);
            y += 25;

            float centerX = x + size / 2;
            float centerY = y + size / 2;
            float boardLength = size * 0.65f;
            float boardWidth = size * 0.12f;
            float sailLength = size * 0.4f;

            // Scale: pixels per meter
            float scale = boardLength / _boardLengthMeters;

            // Draw wind direction arrow (if available)
            if (_apparentWind != null && _apparentWind.ApparentWindSpeed > 0.5f)
            {
                DrawWindArrow(x + size - 20, y + 10, _apparentWind.ApparentWindAngle);
            }

            // Draw board (rectangle) - nose at top, tail at bottom
            DrawRotatedRect(centerX, centerY, boardWidth, boardLength, 0, _boardColor);

            // Draw nose indicator (pointed) at top
            float noseY = centerY - boardLength / 2;
            DrawTriangle(centerX, noseY - 5, 8, _boardColor);

            // Draw tail indicator at bottom
            float tailY = centerY + boardLength / 2;
            GUI.color = _boardColor;
            GUI.DrawTexture(new Rect(centerX - boardWidth / 2 - 2, tailY - 2, boardWidth + 4, 4), _whiteTexture);
            GUI.color = Color.white;

            // FIXED mast base position: 1.2m from tail (does NOT move with rake!)
            // Screen Y: tail is at bottom (higher Y value), nose at top (lower Y value)
            float mastBaseX = centerX;
            float mastBaseY = tailY - (_mastFromTail * scale);

            // Draw mast base (fixed position - small square)
            GUI.color = _mastColor;
            GUI.DrawTexture(new Rect(mastBaseX - 4, mastBaseY - 4, 8, 8), _whiteTexture);
            GUI.color = Color.white;

            // Rake tilts the mast forward or back FROM THE FIXED BASE
            // In top-down view, this shows as the boom/sail attachment point moving fore/aft
            // Positive rake = mast tilts back = boom attachment moves toward tail
            // Negative rake = mast tilts forward = boom attachment moves toward nose
            float maxRakeOffset = 12f; // pixels of visual movement
            float rakeOffsetY = _displayRake * maxRakeOffset;
            float boomAttachY = mastBaseY + rakeOffsetY;

            // Draw line showing mast tilt (from base to boom attachment)
            if (Mathf.Abs(_displayRake) > 0.05f)
            {
                GUI.color = new Color(_mastColor.r, _mastColor.g, _mastColor.b, 0.5f);
                DrawLine(mastBaseX, mastBaseY, mastBaseX, boomAttachY, 2);
                GUI.color = Color.white;
            }

            // Use sail angle from simulation - this represents the actual simulated sail position
            // The simulation calculates the sail angle based on wind and sheet position
            float sailAngle = _displaySailAngle;

            // Draw sail - pointing BACKWARD from mast
            Color sailColor = Color.Lerp(_sailColor, _sailPoweredColor, _displayPower);
            DrawSailBackward(mastBaseX, boomAttachY, sailLength, sailAngle, sailColor);

            // Draw labels
            y = _position.y + size + 5;
            
            // Rake indicator
            string rakeText = _displayRake < -0.1f ? "◄ FWD" : (_displayRake > 0.1f ? "BACK ►" : "CENTER");
            GUI.Label(new Rect(x, y, size / 2, 18), $"Rake: {rakeText}", _labelStyle);
            
            // Sheet indicator  
            int sheetPercent = Mathf.RoundToInt(_displaySheet * 100);
            GUI.Label(new Rect(x + size / 2, y, size / 2, 18), $"Sheet: {sheetPercent}%", _labelStyle);
        }

        private void DrawRotatedRect(float cx, float cy, float width, float height, float angle, Color color)
        {
            Matrix4x4 matrixBackup = GUI.matrix;
            GUIUtility.RotateAroundPivot(angle, new Vector2(cx, cy));
            
            GUI.color = color;
            GUI.DrawTexture(new Rect(cx - width / 2, cy - height / 2, width, height), _whiteTexture);
            GUI.color = Color.white;
            
            GUI.matrix = matrixBackup;
        }

        private void DrawTriangle(float cx, float cy, float size, Color color)
        {
            GUI.color = color;
            // Simple triangle approximation with rotated square
            Matrix4x4 matrixBackup = GUI.matrix;
            GUIUtility.RotateAroundPivot(45, new Vector2(cx, cy));
            GUI.DrawTexture(new Rect(cx - size / 2, cy - size / 2, size, size), _whiteTexture);
            GUI.matrix = matrixBackup;
            GUI.color = Color.white;
        }

        /// <summary>
        /// Draws sail pointing BACKWARD (toward tail) and angled to the side.
        /// In top-down view: tail is at bottom (+Y), nose at top (-Y).
        /// </summary>
        private void DrawSailBackward(float mastX, float mastY, float length, float angle, Color color)
        {
            // Sail points backward (toward tail = +Y direction in screen coords)
            // Then angled to the side by the sail angle
            // angle > 0 = sail angled to right, angle < 0 = sail angled to left
            
            // Base direction: straight back toward tail (90 degrees = pointing down/+Y)
            // Add sail angle to rotate it to the side
            float baseAngle = 90f; // Points toward tail (down on screen)
            float totalAngle = baseAngle + angle;
            
            float radians = totalAngle * Mathf.Deg2Rad;
            float endX = mastX + Mathf.Cos(radians) * length;
            float endY = mastY + Mathf.Sin(radians) * length;

            // Draw thick sail line
            GUI.color = color;
            DrawLine(mastX, mastY, endX, endY, 6);
            
            // Draw sail outline/highlight
            GUI.color = Color.Lerp(color, Color.white, 0.4f);
            DrawLine(mastX, mastY, endX, endY, 2);
            
            // Draw boom end indicator
            GUI.color = _mastColor;
            GUI.DrawTexture(new Rect(endX - 2, endY - 2, 4, 4), _whiteTexture);
            GUI.color = Color.white;
        }

        private void DrawLine(float x1, float y1, float x2, float y2, float width)
        {
            float angle = Mathf.Atan2(y2 - y1, x2 - x1) * Mathf.Rad2Deg;
            float length = Vector2.Distance(new Vector2(x1, y1), new Vector2(x2, y2));

            Matrix4x4 matrixBackup = GUI.matrix;
            GUIUtility.RotateAroundPivot(angle, new Vector2(x1, y1));
            GUI.DrawTexture(new Rect(x1, y1 - width / 2, length, width), _whiteTexture);
            GUI.matrix = matrixBackup;
        }

        private void DrawWindArrow(float x, float y, float angle)
        {
            // Draw small wind direction indicator
            GUI.color = _windColor;
            
            Matrix4x4 matrixBackup = GUI.matrix;
            GUIUtility.RotateAroundPivot(angle + 180, new Vector2(x, y));
            
            // Arrow shaft
            GUI.DrawTexture(new Rect(x - 1.5f, y - 15, 3, 20), _whiteTexture);
            
            // Arrow head (simple triangle approximation)
            GUIUtility.RotateAroundPivot(45, new Vector2(x, y - 15));
            GUI.DrawTexture(new Rect(x - 4, y - 19, 8, 8), _whiteTexture);
            
            GUI.matrix = matrixBackup;
            GUI.color = Color.white;
        }

        private void OnDestroy()
        {
            if (_backgroundTexture != null) Destroy(_backgroundTexture);
            if (_whiteTexture != null) Destroy(_whiteTexture);
        }
    }
}
