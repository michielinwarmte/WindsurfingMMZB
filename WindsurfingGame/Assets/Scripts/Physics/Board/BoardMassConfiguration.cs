using UnityEngine;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Configures realistic mass properties for a windsurfing board.
    /// 
    /// Sets up:
    /// - Total mass (board + rig + sailor)
    /// - Center of mass position
    /// - Moment of inertia tensor for realistic rotation behavior
    /// 
    /// A windsurf board has very different rotational characteristics
    /// around different axes:
    /// - Roll (X axis): Easy to roll, low inertia
    /// - Pitch (Z axis): Medium inertia
    /// - Yaw (Y axis): Highest inertia due to length
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class BoardMassConfiguration : MonoBehaviour
    {
        [Header("Mass Properties")]
        [Tooltip("Total mass including board, rig, and sailor (kg)")]
        [SerializeField] private float _totalMass = 95f;
        
        [Tooltip("Board mass only (kg) - typical modern board is 6-12kg")]
        [SerializeField] private float _boardMass = 8f;
        
        [Tooltip("Rig mass (mast + boom + sail) (kg) - typically 5-8kg")]
        [SerializeField] private float _rigMass = 6f;
        
        [Tooltip("Sailor mass (kg)")]
        [SerializeField] private float _sailorMass = 80f;
        
        [Header("Center of Mass")]
        [Tooltip("Center of mass position in local space")]
        [SerializeField] private Vector3 _centerOfMass = new Vector3(0f, 0.15f, -0.1f);
        
        [Tooltip("Height of sailor's center of mass above board (m)")]
        [SerializeField] private float _sailorCOMHeight = 0.9f;
        
        [Header("Board Dimensions")]
        [Tooltip("Board length (m)")]
        [SerializeField] private float _boardLength = 2.4f;
        
        [Tooltip("Board width (m)")]
        [SerializeField] private float _boardWidth = 0.6f;
        
        [Tooltip("Board thickness (m)")]
        [SerializeField] private float _boardThickness = 0.12f;
        
        [Header("Inertia Tensor")]
        [Tooltip("Use custom inertia tensor instead of Unity's auto-calculation. WARNING: May cause instability if values are wrong.")]
        [SerializeField] private bool _useCustomInertia = false;
        
        [Tooltip("Inertia tensor multiplier for fine-tuning (only when using custom inertia)")]
        [SerializeField] private Vector3 _inertiaMultiplier = Vector3.one;
        
        [Header("Dynamic Center of Mass")]
        [Tooltip("Enable dynamic COM that shifts based on speed and heel")]
        [SerializeField] private bool _dynamicCOM = true;
        
        [Tooltip("How much COM shifts forward when planing")]
        [SerializeField] private float _planingCOMShift = 0.15f;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        
        // Components
        private Rigidbody _rigidbody;
        private AdvancedHullDrag _hullDrag;
        
        // Calculated values
        private Vector3 _baseInertiaTensor;
        private Vector3 _baseCOM;
        private Vector3 _currentCOM;
        
        // Public accessors
        public float TotalMass => _totalMass;
        public Vector3 CenterOfMass => _currentCOM;
        public Vector3 InertiaTensor => _rigidbody != null ? _rigidbody.inertiaTensor : Vector3.zero;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            _hullDrag = GetComponent<AdvancedHullDrag>();
            
            CalculateMassProperties();
        }
        
        private void Start()
        {
            ApplyMassProperties();
        }
        
        private void FixedUpdate()
        {
            if (_dynamicCOM)
            {
                UpdateDynamicCOM();
            }
        }
        
        /// <summary>
        /// Calculate realistic mass properties for a windsurfer.
        /// </summary>
        private void CalculateMassProperties()
        {
            // Update total mass from components
            _totalMass = _boardMass + _rigMass + _sailorMass;
            
            // Calculate center of mass as weighted average of components
            // Board COM: roughly at center of board
            Vector3 boardCOM = new Vector3(0f, _boardThickness * 0.5f, 0f);
            
            // Rig COM: above and slightly behind sailor's hands
            Vector3 rigCOM = new Vector3(0f, _sailorCOMHeight * 1.2f, -0.2f);
            
            // Sailor COM: standing on board
            Vector3 sailorCOM = new Vector3(0f, _sailorCOMHeight * 0.5f, 0f);
            
            // Weighted average
            _baseCOM = (boardCOM * _boardMass + rigCOM * _rigMass + sailorCOM * _sailorMass) / _totalMass;
            _currentCOM = _baseCOM;
            
            // Override with configured value if explicitly set
            if (_centerOfMass != Vector3.zero)
            {
                _baseCOM = _centerOfMass;
                _currentCOM = _baseCOM;
            }
            
            // Calculate moment of inertia tensor
            // Using parallel axis theorem for composite body
            CalculateInertiaTensor();
        }
        
        /// <summary>
        /// Calculate the inertia tensor for the windsurfer system.
        /// </summary>
        private void CalculateInertiaTensor()
        {
            // The inertia tensor defines how easy/hard it is to rotate around each axis
            // For a windsurfer:
            // - Ixx (roll): Fairly low - board is narrow, sailor can lean
            // - Iyy (yaw): Highest - board is long, resists turning
            // - Izz (pitch): Medium - depends on weight distribution fore/aft
            
            // Board contribution (approximate as rectangular plate)
            float boardIxx = (1f / 12f) * _boardMass * (_boardWidth * _boardWidth + _boardThickness * _boardThickness);
            float boardIyy = (1f / 12f) * _boardMass * (_boardLength * _boardLength + _boardWidth * _boardWidth);
            float boardIzz = (1f / 12f) * _boardMass * (_boardLength * _boardLength + _boardThickness * _boardThickness);
            
            // Sailor contribution (approximate as cylinder standing on board)
            // Plus parallel axis theorem for offset from board's COM
            float sailorRadius = 0.2f; // approximate torso radius
            float sailorHeight = 1.7f;
            
            // Cylinder moment of inertia
            float sailorIxx = (1f / 12f) * _sailorMass * (3f * sailorRadius * sailorRadius + sailorHeight * sailorHeight);
            float sailorIyy = 0.5f * _sailorMass * sailorRadius * sailorRadius;
            float sailorIzz = sailorIxx;
            
            // Add parallel axis offset for sailor standing on board
            float sailorHeightOffset = _sailorCOMHeight * 0.5f;
            sailorIxx += _sailorMass * sailorHeightOffset * sailorHeightOffset;
            sailorIzz += _sailorMass * sailorHeightOffset * sailorHeightOffset;
            
            // Rig contribution (approximate as point mass at height)
            float rigHeight = _sailorCOMHeight * 1.2f;
            float rigIxx = _rigMass * rigHeight * rigHeight;
            float rigIyy = _rigMass * 0.3f * 0.3f; // Small radius around mast axis
            float rigIzz = _rigMass * rigHeight * rigHeight;
            
            // Sum all contributions
            _baseInertiaTensor = new Vector3(
                (boardIxx + sailorIxx + rigIxx) * _inertiaMultiplier.x,
                (boardIyy + sailorIyy + rigIyy) * _inertiaMultiplier.y,
                (boardIzz + sailorIzz + rigIzz) * _inertiaMultiplier.z
            );
        }
        
        /// <summary>
        /// Apply calculated mass properties to the rigidbody.
        /// </summary>
        private void ApplyMassProperties()
        {
            if (_rigidbody == null) return;
            
            // Set mass
            _rigidbody.mass = _totalMass;
            
            // Set center of mass
            _rigidbody.centerOfMass = _baseCOM;
            
            // Set inertia tensor
            if (_useCustomInertia)
            {
                _rigidbody.inertiaTensor = _baseInertiaTensor;
                _rigidbody.inertiaTensorRotation = Quaternion.identity;
            }
            
            Debug.Log($"BoardMassConfiguration: Mass={_totalMass:F1}kg, " +
                $"COM={_baseCOM}, Inertia={_baseInertiaTensor}");
        }
        
        /// <summary>
        /// Update center of mass dynamically based on sailing state.
        /// </summary>
        private void UpdateDynamicCOM()
        {
            // When planing, sailor moves AFT (backward) into the back foot straps
            // This shifts weight to the tail, helping keep the nose up
            // Real windsurfers hook into harness and lean back at speed
            float planingRatio = 0f;
            if (_hullDrag != null)
            {
                planingRatio = _hullDrag.PlaningRatio;
            }
            
            // Shift COM BACKWARD when planing (negative Z = aft)
            Vector3 planingShift = new Vector3(0f, 0f, -_planingCOMShift * planingRatio);
            
            // Lower COM when planing (sailor crouches in straps, leaning out)
            planingShift.y = -0.1f * planingRatio;
            
            _currentCOM = _baseCOM + planingShift;
            _rigidbody.centerOfMass = _currentCOM;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug) return;
            
            // Draw center of mass
            Vector3 comWorld = transform.TransformPoint(_centerOfMass);
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(comWorld, 0.1f);
            
            // Draw board outline
            Gizmos.color = Color.cyan;
            Vector3 halfExtents = new Vector3(_boardWidth * 0.5f, _boardThickness * 0.5f, _boardLength * 0.5f);
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.DrawWireCube(Vector3.zero, halfExtents * 2f);
            Gizmos.matrix = Matrix4x4.identity;
            
            // Labels
            if (Application.isPlaying && _rigidbody != null)
            {
                UnityEditor.Handles.Label(comWorld + Vector3.up * 0.2f,
                    $"Mass: {_totalMass:F1} kg\n" +
                    $"COM: {_currentCOM}\n" +
                    $"Inertia: {_rigidbody.inertiaTensor}");
            }
        }
#endif
    }
}
