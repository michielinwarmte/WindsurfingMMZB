using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Debugging
{
    /// <summary>
    /// Physics validation debug tool.
    /// Compares simulation output against expected polar diagram values.
    /// 
    /// Expected windsurfing polar diagram values (at 10 m/s wind):
    /// - Close-hauled (45° TWA): 8-10 knots boat speed, VMG 5-6 knots
    /// - Beam reach (90° TWA): 12-15 knots boat speed
    /// - Broad reach (135° TWA): 10-12 knots boat speed
    /// - Running (180° TWA): 8-10 knots boat speed
    /// 
    /// Sail coefficients (properly trimmed):
    /// - Upwind (45° AWA): Cl ~1.0-1.2, Cd ~0.05-0.1, L/D ~10-15
    /// - Beam reach (90° AWA): Cl ~0.8-1.0, Cd ~0.1-0.15
    /// - Downwind (>135° AWA): Stalled, mostly drag
    /// </summary>
    public class PhysicsValidation : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private Rigidbody _rigidbody;
        
        [Header("Display")]
        [SerializeField] private bool _showGUI = true;
        [SerializeField] private bool _logToConsole = false;
        
        private SailingState _state;
        private float _expectedBoatSpeed;
        private float _expectedDriveForce;
        private string _diagnosis = "";
        
        private void Start()
        {
            if (_sail == null)
                _sail = GetComponentInParent<AdvancedSail>();
            if (_rigidbody == null)
                _rigidbody = GetComponentInParent<Rigidbody>();
        }
        
        private void Update()
        {
            if (_sail == null) return;
            
            _state = _sail.State;
            CalculateExpectedValues();
            DiagnoseIssues();
            
            if (_logToConsole && Time.frameCount % 60 == 0)
            {
                LogPhysicsState();
            }
        }
        
        private void CalculateExpectedValues()
        {
            if (_state == null || _state.ApparentWindSpeed < 0.5f) return;
            
            // Expected values based on real windsurfing physics
            float absAWA = Mathf.Abs(_state.ApparentWindAngle);
            float windSpeed = _state.ApparentWindSpeed;
            float sailArea = 6.5f; // m²
            float airDensity = 1.225f;
            
            // Dynamic pressure
            float q = 0.5f * airDensity * windSpeed * windSpeed;
            
            // Expected Cl based on optimal trim
            float expectedCl;
            float expectedCd;
            if (absAWA < 60f)
            {
                // Upwind - attached flow
                expectedCl = 1.2f;
                expectedCd = 0.08f;
            }
            else if (absAWA < 120f)
            {
                // Reaching - good lift
                expectedCl = 1.0f;
                expectedCd = 0.1f;
            }
            else
            {
                // Downwind - stalled
                expectedCl = 0.5f;
                expectedCd = 0.8f;
            }
            
            float liftMag = q * sailArea * expectedCl;
            float dragMag = q * sailArea * expectedCd;
            
            // Drive force from Wikipedia formula: FR = L*sin(α) - D*cos(α)
            float awaRad = absAWA * Mathf.Deg2Rad;
            _expectedDriveForce = liftMag * Mathf.Sin(awaRad) - dragMag * Mathf.Cos(awaRad);
            
            // Expected boat speed (rough estimate based on balance with hull drag)
            // At equilibrium: Drive = Hull Drag
            // Hull drag ≈ 0.5 * ρwater * V² * Cd * A
            // Simplified: V ≈ sqrt(2 * Drive / (ρwater * Cd * A))
            float hullDragCoeff = 0.05f;
            float hullArea = 0.3f; // m²
            float waterDensity = 1025f;
            _expectedBoatSpeed = Mathf.Sqrt(2f * Mathf.Max(_expectedDriveForce, 1f) / 
                                            (waterDensity * hullDragCoeff * hullArea));
        }
        
        private void DiagnoseIssues()
        {
            if (_state == null) return;
            
            _diagnosis = "";
            
            // Check if forces are being generated
            if (_state.SailForce.magnitude < 10f && _state.ApparentWindSpeed > 3f)
            {
                _diagnosis += "⚠ Very low sail force!\n";
            }
            
            // Check drive force
            if (_state.DriveForce < 0 && Mathf.Abs(_state.ApparentWindAngle) < 120f)
            {
                _diagnosis += "❌ NEGATIVE drive force when sailing upwind/reaching!\n";
                _diagnosis += "   Lift direction may be inverted.\n";
            }
            
            // Check if lift is reasonable
            float expectedLiftMag = 0.5f * 1.225f * _state.ApparentWindSpeed * _state.ApparentWindSpeed * 6.5f * 1.0f;
            if (_state.SailLift.magnitude < expectedLiftMag * 0.3f)
            {
                _diagnosis += "⚠ Lift force much lower than expected\n";
                _diagnosis += $"   Expected: ~{expectedLiftMag:F0}N, Got: {_state.SailLift.magnitude:F0}N\n";
            }
            
            // Check angle of attack
            if (Mathf.Abs(_state.AngleOfAttack) > 25f && Mathf.Abs(_state.ApparentWindAngle) < 90f)
            {
                _diagnosis += "⚠ Sail is stalled (AoA > 25°)\n";
                _diagnosis += "   Try sheeting in or pointing higher.\n";
            }
            
            // Check if lift is pointing forward
            float liftForwardComponent = Vector3.Dot(_state.SailLift, transform.forward);
            if (liftForwardComponent < -50f && Mathf.Abs(_state.ApparentWindAngle) < 90f)
            {
                _diagnosis += "❌ Lift is pushing BACKWARD!\n";
                _diagnosis += "   This indicates lift direction calculation is wrong.\n";
            }
            
            if (string.IsNullOrEmpty(_diagnosis))
            {
                _diagnosis = "✓ Physics looks reasonable";
            }
        }
        
        private void LogPhysicsState()
        {
            UnityEngine.Debug.Log($"=== Physics Validation ===\n" +
                $"AWA: {_state.ApparentWindAngle:F1}° | AWS: {_state.ApparentWindSpeed:F1} m/s\n" +
                $"Sail Angle: {_state.SailAngle:F1}° | AoA: {_state.AngleOfAttack:F1}°\n" +
                $"Lift: {_state.SailLift.magnitude:F0}N | Drag: {_state.SailDrag.magnitude:F0}N\n" +
                $"Drive: {_state.DriveForce:F0}N | Side: {_state.SideForce:F0}N\n" +
                $"Boat Speed: {_state.BoatSpeed:F1} m/s ({_state.BoatSpeed * 1.944f:F1} kts)\n" +
                $"Expected Drive: {_expectedDriveForce:F0}N | Expected Speed: {_expectedBoatSpeed:F1} m/s\n" +
                $"Diagnosis: {_diagnosis}");
        }
        
        private void OnGUI()
        {
            if (!_showGUI || _state == null) return;
            
            GUIStyle style = new GUIStyle(GUI.skin.box);
            style.fontSize = 14;
            style.normal.textColor = Color.white;
            
            float x = 10;
            float y = Screen.height - 350;
            float width = 350;
            float height = 340;
            
            GUI.Box(new Rect(x, y, width, height), "");
            
            string text = $"=== PHYSICS VALIDATION ===\n\n" +
                $"Apparent Wind: {_state.ApparentWindAngle:F1}° @ {_state.ApparentWindSpeed:F1} m/s\n" +
                $"Sail Angle: {_state.SailAngle:F1}° | AoA: {_state.AngleOfAttack:F1}°\n" +
                $"Sail Side: {(_state.SailSide > 0 ? "Starboard" : "Port")}\n\n" +
                $"--- FORCES ---\n" +
                $"Lift: {_state.SailLift.magnitude:F0}N\n" +
                $"Drag: {_state.SailDrag.magnitude:F0}N\n" +
                $"L/D Ratio: {(_state.SailDrag.magnitude > 0.1f ? _state.SailLift.magnitude / _state.SailDrag.magnitude : 0):F1}\n\n" +
                $"Drive Force: {_state.DriveForce:F0}N (expected: {_expectedDriveForce:F0}N)\n" +
                $"Side Force: {_state.SideForce:F0}N\n\n" +
                $"--- PERFORMANCE ---\n" +
                $"Speed: {_state.BoatSpeed:F1} m/s ({_state.BoatSpeed * 1.944f:F1} kts)\n" +
                $"VMG: {_state.VMG:F1} m/s\n\n" +
                $"--- DIAGNOSIS ---\n{_diagnosis}";
            
            GUI.Label(new Rect(x + 10, y + 5, width - 20, height - 10), text);
        }
    }
}
