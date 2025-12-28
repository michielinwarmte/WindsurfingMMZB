using UnityEngine;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.Visual
{
    /// <summary>
    /// Loads and positions real 3D models (FBX) for the board and sail.
    /// 
    /// Board: Static, positioned at board origin
    /// Sail: Pivots at mast base, rotates based on physics simulation
    /// 
    /// Supports both basic Sail and AdvancedSail physics components.
    /// 
    /// The FBX models should have their pivot points at:
    /// - Board: Center/origin of the board
    /// - Sail: Mast base (where mast meets board)
    /// </summary>
    public class EquipmentVisualizer : MonoBehaviour
    {
        [Header("Model References")]
        [Tooltip("The board 3D model (instantiated as child)")]
        [SerializeField] private GameObject _boardPrefab;
        
        [Tooltip("The sail/rig 3D model (instantiated as child, pivots at mast base)")]
        [SerializeField] private GameObject _sailPrefab;

        [Header("Physics Reference")]
        [Tooltip("Reference to the Sail physics component (basic)")]
        [SerializeField] private Sail _sail;
        
        [Tooltip("Reference to the AdvancedSail physics component")]
        [SerializeField] private AdvancedSail _advancedSail;

        [Header("Board Settings")]
        [Tooltip("Position offset for board model")]
        [SerializeField] private Vector3 _boardOffset = Vector3.zero;
        
        [Tooltip("Rotation offset for board model (Euler angles)")]
        [SerializeField] private Vector3 _boardRotationOffset = Vector3.zero;
        
        [Tooltip("Scale multiplier for board model")]
        [SerializeField] private float _boardScale = 1f;

        [Header("Sail Settings")]
        [Tooltip("Position of mast base (where sail pivots). Should match Sail._mastFootPosition")]
        [SerializeField] private Vector3 _mastBasePosition = new Vector3(0, 0.1f, -0.05f);
        
        [Tooltip("Rotation offset for sail model (Euler angles)")]
        [SerializeField] private Vector3 _sailRotationOffset = Vector3.zero;
        
        [Tooltip("Scale multiplier for sail model")]
        [SerializeField] private float _sailScale = 1f;
        
        [Tooltip("Maximum mast rake angle in degrees")]
        [SerializeField] private float _maxRakeAngle = 15f;
        
        [Header("Physics-to-Visual Mapping")]
        [Tooltip("Rotation offset between physics sail angle (0°=aft) and visual model orientation. " +
                 "Physics: 0° = sail pointing aft along board centerline. " +
                 "Adjust this if your model's 'forward' direction differs.")]
        [SerializeField] private float _sailAngleOffset = 0f;
        
        [Tooltip("Invert the sail rotation direction. Enable if sail rotates INTO the wind instead of away from it.")]
        [SerializeField] private bool _invertSailRotation = true;

        [Header("Animation")]
        [Tooltip("How quickly the visual responds to physics changes")]
        [SerializeField] private float _smoothSpeed = 8f;

        // Instantiated model instances
        private GameObject _boardInstance;
        private GameObject _sailInstance;
        private GameObject _sailPivot;

        // Smoothed values
        private float _currentRake;
        private float _currentSailAngle;
        
        // Unified sail interface properties
        private float TargetSailAngle => _advancedSail != null ? _advancedSail.CurrentSailAngle : 
                                          (_sail != null ? _sail.CurrentSailAngle : 0f);
        private float TargetMastRake => _advancedSail != null ? _advancedSail.MastRake : 
                                         (_sail != null ? _sail.MastRake : 0f);
        private bool HasSailReference => _advancedSail != null || _sail != null;

        private void Awake()
        {
            // Try to find AdvancedSail first, then fall back to basic Sail
            if (_advancedSail == null)
                _advancedSail = GetComponent<AdvancedSail>();
            if (_advancedSail == null && _sail == null)
                _sail = GetComponent<Sail>();
        }

        private void Start()
        {
            SetupModels();
        }

        private void Update()
        {
            UpdateSailRotation();
        }

        private void SetupModels()
        {
            // Setup board model (static)
            if (_boardPrefab != null)
            {
                _boardInstance = Instantiate(_boardPrefab, transform);
                _boardInstance.name = "BoardModel";
                _boardInstance.transform.localPosition = _boardOffset;
                _boardInstance.transform.localRotation = Quaternion.Euler(_boardRotationOffset);
                _boardInstance.transform.localScale = Vector3.one * _boardScale;
            }
            else
            {
                Debug.LogWarning("EquipmentVisualizer: No board prefab assigned!");
            }

            // Setup sail pivot (empty GameObject at mast base)
            _sailPivot = new GameObject("SailPivot");
            _sailPivot.transform.SetParent(transform);
            _sailPivot.transform.localPosition = _mastBasePosition;
            _sailPivot.transform.localRotation = Quaternion.identity;

            // Setup sail model (rotates based on physics)
            if (_sailPrefab != null)
            {
                _sailInstance = Instantiate(_sailPrefab, _sailPivot.transform);
                _sailInstance.name = "SailModel";
                _sailInstance.transform.localPosition = Vector3.zero; // Pivot is at mast base
                _sailInstance.transform.localRotation = Quaternion.Euler(_sailRotationOffset);
                _sailInstance.transform.localScale = Vector3.one * _sailScale;
            }
            else
            {
                Debug.LogWarning("EquipmentVisualizer: No sail prefab assigned!");
            }
        }

        private void UpdateSailRotation()
        {
            if (!HasSailReference || _sailPivot == null) return;

            // Get target values from sail physics (works with both Sail and AdvancedSail)
            float targetRake = TargetMastRake * _maxRakeAngle;
            float targetSailAngle = TargetSailAngle;

            // Smooth the values for visual appeal
            _currentRake = Mathf.Lerp(_currentRake, targetRake, Time.deltaTime * _smoothSpeed);
            _currentSailAngle = Mathf.Lerp(_currentSailAngle, targetSailAngle, Time.deltaTime * _smoothSpeed);

            // Apply rotation to sail pivot
            // Rake: rotates forward/back around X axis (negative rake = forward tilt)
            // Sail angle: rotates left/right around Y axis
            // Add the sail angle offset to align physics with visual model orientation
            // Physics: 0° = sail pointing AFT (backward along centerline)
            // Your model may have a different "zero" orientation
            // Invert if model rotates opposite to physics convention
            float visualSailAngle = (_invertSailRotation ? -_currentSailAngle : _currentSailAngle) + _sailAngleOffset;
            _sailPivot.transform.localRotation = Quaternion.Euler(-_currentRake, visualSailAngle, 0);
        }

        /// <summary>
        /// Allows runtime swapping of models
        /// </summary>
        public void SetBoardModel(GameObject newBoardPrefab)
        {
            if (_boardInstance != null)
                Destroy(_boardInstance);

            _boardPrefab = newBoardPrefab;
            
            if (_boardPrefab != null)
            {
                _boardInstance = Instantiate(_boardPrefab, transform);
                _boardInstance.name = "BoardModel";
                _boardInstance.transform.localPosition = _boardOffset;
                _boardInstance.transform.localRotation = Quaternion.Euler(_boardRotationOffset);
                _boardInstance.transform.localScale = Vector3.one * _boardScale;
            }
        }

        /// <summary>
        /// Allows runtime swapping of sail model
        /// </summary>
        public void SetSailModel(GameObject newSailPrefab)
        {
            if (_sailInstance != null)
                Destroy(_sailInstance);

            _sailPrefab = newSailPrefab;
            
            if (_sailPrefab != null && _sailPivot != null)
            {
                _sailInstance = Instantiate(_sailPrefab, _sailPivot.transform);
                _sailInstance.name = "SailModel";
                _sailInstance.transform.localPosition = Vector3.zero;
                _sailInstance.transform.localRotation = Quaternion.Euler(_sailRotationOffset);
                _sailInstance.transform.localScale = Vector3.one * _sailScale;
            }
        }

        /// <summary>
        /// Syncs mast base position with Sail component (works with both Sail and AdvancedSail)
        /// </summary>
        public void SyncWithSailComponent()
        {
            Vector3 mastPos = Vector3.zero;
            bool found = false;
            
            if (_advancedSail != null)
            {
                mastPos = _advancedSail.Config.MastFootPosition;
                found = true;
            }
            else if (_sail != null)
            {
                mastPos = _sail.MastFootPosition;
                found = true;
            }
            
            if (found)
            {
                _mastBasePosition = mastPos;
                if (_sailPivot != null)
                {
                    _sailPivot.transform.localPosition = _mastBasePosition;
                }
            }
        }

#if UNITY_EDITOR
        private void OnValidate()
        {
            // Update positions in editor when values change
            if (_boardInstance != null)
            {
                _boardInstance.transform.localPosition = _boardOffset;
                _boardInstance.transform.localRotation = Quaternion.Euler(_boardRotationOffset);
                _boardInstance.transform.localScale = Vector3.one * _boardScale;
            }

            if (_sailPivot != null)
            {
                _sailPivot.transform.localPosition = _mastBasePosition;
            }

            if (_sailInstance != null)
            {
                _sailInstance.transform.localRotation = Quaternion.Euler(_sailRotationOffset);
                _sailInstance.transform.localScale = Vector3.one * _sailScale;
            }
        }

        private void OnDrawGizmosSelected()
        {
            // Draw mast base position
            Gizmos.color = Color.cyan;
            Vector3 mastBaseWorld = transform.TransformPoint(_mastBasePosition);
            Gizmos.DrawWireSphere(mastBaseWorld, 0.1f);
            Gizmos.DrawLine(mastBaseWorld, mastBaseWorld + transform.up * 4.5f);

            // Draw board offset
            if (_boardOffset != Vector3.zero)
            {
                Gizmos.color = Color.green;
                Vector3 boardOffsetWorld = transform.TransformPoint(_boardOffset);
                Gizmos.DrawWireCube(boardOffsetWorld, new Vector3(0.5f, 0.1f, 2.5f));
            }

            // Label
            UnityEditor.Handles.Label(mastBaseWorld + Vector3.up * 0.3f, "Mast Base (Sail Pivot)");
            
            // In play mode, show physics vs visual sail angle comparison
            if (Application.isPlaying && HasSailReference)
            {
                float physicsSailAngle = TargetSailAngle;
                float visualAngle = physicsSailAngle + _sailAngleOffset;
                
                Vector3 boomPos = mastBaseWorld + Vector3.up * 1.2f;
                float boomLen = 2.0f;
                
                // Draw PHYSICS expected boom direction (GREEN)
                float physAngleRad = physicsSailAngle * Mathf.Deg2Rad;
                Vector3 physBoomDir = transform.TransformDirection(new Vector3(
                    Mathf.Sin(physAngleRad),
                    0,
                    -Mathf.Cos(physAngleRad)
                ));
                Gizmos.color = Color.green;
                Gizmos.DrawRay(boomPos, physBoomDir * boomLen);
                Gizmos.DrawWireSphere(boomPos + physBoomDir * boomLen, 0.08f);
                
                // Draw VISUAL model boom direction (YELLOW) - after offset applied
                float visAngleRad = visualAngle * Mathf.Deg2Rad;
                Vector3 visBoomDir = transform.TransformDirection(new Vector3(
                    Mathf.Sin(visAngleRad),
                    0,
                    -Mathf.Cos(visAngleRad)
                ));
                Gizmos.color = Color.yellow;
                Gizmos.DrawRay(boomPos + Vector3.up * 0.1f, visBoomDir * boomLen);
                Gizmos.DrawWireSphere(boomPos + Vector3.up * 0.1f + visBoomDir * boomLen, 0.08f);
                
                // Label showing angles
                UnityEditor.Handles.Label(boomPos + Vector3.up * 0.5f,
                    $"Physics Sail Angle: {physicsSailAngle:F1}°\n" +
                    $"Sail Angle Offset: {_sailAngleOffset:F1}°\n" +
                    $"Visual Angle: {visualAngle:F1}°\n" +
                    $"(Green = Physics, Yellow = Visual)");
            }
        }
#endif
    }
}
