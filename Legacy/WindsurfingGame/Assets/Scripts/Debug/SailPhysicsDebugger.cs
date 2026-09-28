using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Debugging
{
    /// <summary>
    /// Deep debugging tool for sail physics.
    /// Add this to the windsurfer to trace all force calculations.
    /// </summary>
    public class SailPhysicsDebugger : MonoBehaviour
    {
        [SerializeField] private AdvancedSail _sail;
        [SerializeField] private bool _logEveryFrame = false;
        [SerializeField] private bool _logOnKeyPress = true;
        [SerializeField] private KeyCode _debugKey = KeyCode.F1;
        
        private SailingState _state;
        
        private void Start()
        {
            if (_sail == null)
                _sail = GetComponent<AdvancedSail>();
        }
        
        private void Update()
        {
            if (_sail == null) return;
            _state = _sail.State;
            
            if (_logOnKeyPress && Input.GetKeyDown(_debugKey))
            {
                LogDetailedPhysics();
            }
            
            if (_logEveryFrame && Time.frameCount % 30 == 0)
            {
                LogDetailedPhysics();
            }
        }
        
        private void LogDetailedPhysics()
        {
            if (_state == null)
            {
                UnityEngine.Debug.Log("SailPhysicsDebugger: No state available");
                return;
            }
            
            UnityEngine.Debug.Log("========== SAIL PHYSICS DEEP DEBUG ==========");
            
            // 1. WIND DATA
            UnityEngine.Debug.Log($"--- WIND ---");
            UnityEngine.Debug.Log($"True Wind Vector: {_state.TrueWind:F2}");
            UnityEngine.Debug.Log($"True Wind Speed: {_state.TrueWindSpeed:F2} m/s");
            UnityEngine.Debug.Log($"True Wind Angle: {_state.TrueWindAngle:F1}°");
            UnityEngine.Debug.Log($"Apparent Wind Vector: {_state.ApparentWind:F2}");
            UnityEngine.Debug.Log($"Apparent Wind Speed: {_state.ApparentWindSpeed:F2} m/s");
            UnityEngine.Debug.Log($"Apparent Wind Angle: {_state.ApparentWindAngle:F1}°");
            
            // 2. BOAT STATE
            UnityEngine.Debug.Log($"--- BOAT ---");
            UnityEngine.Debug.Log($"Boat Forward: {transform.forward:F2}");
            UnityEngine.Debug.Log($"Boat Velocity: {_state.BoatVelocity:F2}");
            UnityEngine.Debug.Log($"Boat Speed: {_state.BoatSpeed:F2} m/s");
            
            // 3. SAIL GEOMETRY
            UnityEngine.Debug.Log($"--- SAIL GEOMETRY ---");
            UnityEngine.Debug.Log($"Sail Angle: {_state.SailAngle:F1}° from centerline");
            UnityEngine.Debug.Log($"Sail Side: {_state.SailSide:F1} (+1=stbd, -1=port)");
            UnityEngine.Debug.Log($"Angle of Attack: {_state.AngleOfAttack:F1}°");
            
            // 4. FORCE VECTORS
            UnityEngine.Debug.Log($"--- FORCES ---");
            UnityEngine.Debug.Log($"Sail Lift: {_state.SailLift:F1} (mag: {_state.SailLift.magnitude:F1} N)");
            UnityEngine.Debug.Log($"Sail Drag: {_state.SailDrag:F1} (mag: {_state.SailDrag.magnitude:F1} N)");
            UnityEngine.Debug.Log($"Total Sail Force: {_state.SailForce:F1} (mag: {_state.SailForce.magnitude:F1} N)");
            
            // 5. DRIVE ANALYSIS
            UnityEngine.Debug.Log($"--- DRIVE ANALYSIS ---");
            UnityEngine.Debug.Log($"Drive Force (forward): {_state.DriveForce:F1} N");
            UnityEngine.Debug.Log($"Side Force (lateral): {_state.SideForce:F1} N");
            
            // Calculate what SHOULD happen
            float liftForwardComponent = Vector3.Dot(_state.SailLift, transform.forward);
            float liftSideComponent = Vector3.Dot(_state.SailLift, transform.right);
            float dragForwardComponent = Vector3.Dot(_state.SailDrag, transform.forward);
            float dragSideComponent = Vector3.Dot(_state.SailDrag, transform.right);
            
            UnityEngine.Debug.Log($"Lift forward component: {liftForwardComponent:F1} N");
            UnityEngine.Debug.Log($"Lift side component: {liftSideComponent:F1} N");
            UnityEngine.Debug.Log($"Drag forward component: {dragForwardComponent:F1} N");
            UnityEngine.Debug.Log($"Drag side component: {dragSideComponent:F1} N");
            
            // 6. EXPECTED VALUES FOR UPWIND
            float absAWA = Mathf.Abs(_state.ApparentWindAngle);
            float awaRad = absAWA * Mathf.Deg2Rad;
            float expectedLiftMag = 0.5f * 1.225f * _state.ApparentWindSpeed * _state.ApparentWindSpeed * 6.5f * 1.0f;
            float expectedDriveFromLift = expectedLiftMag * Mathf.Sin(awaRad);
            
            UnityEngine.Debug.Log($"--- EXPECTED VALUES ---");
            UnityEngine.Debug.Log($"|AWA|: {absAWA:F1}°");
            UnityEngine.Debug.Log($"Expected Lift (~Cl=1.0): {expectedLiftMag:F1} N");
            UnityEngine.Debug.Log($"Expected Drive from Lift: Lift * sin(AWA) = {expectedDriveFromLift:F1} N");
            
            // 7. DIAGNOSIS
            UnityEngine.Debug.Log($"--- DIAGNOSIS ---");
            if (absAWA < 25f)
            {
                UnityEngine.Debug.LogWarning("AWA < 25° - Force is zeroed (in irons check)");
            }
            if (_state.SailForce.magnitude < 1f)
            {
                UnityEngine.Debug.LogWarning("Sail force is nearly zero!");
            }
            if (_state.DriveForce < 0)
            {
                UnityEngine.Debug.LogError("NEGATIVE drive force - sail is pushing BACKWARD!");
                
                // Check lift direction
                Vector3 liftNorm = _state.SailLift.normalized;
                float liftDotFwd = Vector3.Dot(liftNorm, transform.forward);
                UnityEngine.Debug.LogError($"Lift direction dot forward: {liftDotFwd:F2}");
                if (liftDotFwd < 0)
                {
                    UnityEngine.Debug.LogError("Lift is pointing BACKWARD - this is the bug!");
                }
            }
            else if (_state.DriveForce < expectedDriveFromLift * 0.3f && _state.ApparentWindSpeed > 3f)
            {
                UnityEngine.Debug.LogWarning($"Drive force ({_state.DriveForce:F1} N) is much lower than expected ({expectedDriveFromLift:F1} N)");
            }
            else
            {
                UnityEngine.Debug.Log("Physics looks correct");
            }
            
            UnityEngine.Debug.Log("==============================================");
        }
        
        private void OnGUI()
        {
            if (_state == null) return;
            
            GUIStyle style = new GUIStyle(GUI.skin.box);
            style.fontSize = 12;
            
            float x = Screen.width - 320;
            float y = 10;
            float width = 310;
            float height = 200;
            
            GUI.Box(new Rect(x, y, width, height), "");
            
            string text = $"SAIL DEBUG (Press {_debugKey} for full log)\n" +
                $"AWA: {_state.ApparentWindAngle:F1}° | AWS: {_state.ApparentWindSpeed:F1} m/s\n" +
                $"Sail Angle: {_state.SailAngle:F1}° | AoA: {_state.AngleOfAttack:F1}°\n" +
                $"Lift: {_state.SailLift.magnitude:F0} N | Drag: {_state.SailDrag.magnitude:F0} N\n" +
                $"DRIVE: {_state.DriveForce:F0} N | SIDE: {_state.SideForce:F0} N\n" +
                $"Speed: {_state.BoatSpeed:F1} m/s ({_state.BoatSpeed * 1.944f:F1} kts)\n" +
                $"VMG: {_state.VMG:F1} m/s";
            
            // Color code based on drive force
            if (_state.DriveForce < 0)
                GUI.color = Color.red;
            else if (_state.DriveForce < 50)
                GUI.color = Color.yellow;
            else
                GUI.color = Color.green;
                
            GUI.Label(new Rect(x + 5, y + 5, width - 10, height - 10), text);
            GUI.color = Color.white;
        }
    }
}
