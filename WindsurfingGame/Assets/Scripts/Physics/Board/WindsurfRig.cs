using UnityEngine;
using WindsurfingGame.Physics.Buoyancy;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Main component that ties together the windsurf board and sail as separate parts.
    /// 
    /// Hierarchy Setup:
    ///   WindsurfRig (this script + Rigidbody)
    ///   ├── Board (visual model - pivot at underside, behind mast base)
    ///   └── Sail (visual model + Sail script - pivot at mast base)
    /// 
    /// The Sail is a child but can rotate independently around its pivot (mast base).
    /// Physics forces are applied to the shared Rigidbody on this parent object.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class WindsurfRig : MonoBehaviour
    {
        [Header("Board Visual")]
        [Tooltip("Reference to the board visual model (child object)")]
        [SerializeField] private Transform _boardVisual;
        
        [Header("Sail Reference")]
        [Tooltip("Reference to the sail object (child with Sail script)")]
        [SerializeField] private Sail _sail;
        
        [Header("Sail Attachment")]
        [Tooltip("Local position where the mast base connects to the board")]
        [SerializeField] private Vector3 _mastBasePosition = new Vector3(0.85f, 0.15f, 0f);
        
        [Tooltip("Allow sail to rotate visually based on wind (cosmetic rotation)")]
        [SerializeField] private bool _enableSailVisualRotation = true;
        
        [Tooltip("Maximum visual rotation angle for sail (degrees from centerline)")]
        [SerializeField] private float _maxSailVisualAngle = 80f;

        [Header("Physics")]
        [Tooltip("Rigidbody for the entire rig (auto-assigned if empty)")]
        [SerializeField] private Rigidbody _rigidbody;

        [Header("Debug")]
        [SerializeField] private bool _showDebugGizmos = true;

        // Component references
        private BuoyancyBody _buoyancy;
        private ApparentWindCalculator _apparentWind;

        // Properties
        public Rigidbody Rigidbody => _rigidbody;
        public Sail Sail => _sail;
        public Transform BoardVisual => _boardVisual;
        public Vector3 MastBaseWorldPosition => transform.TransformPoint(_mastBasePosition);

        private void Awake()
        {
            ValidateAndSetupReferences();
        }

        private void Start()
        {
            // Position the sail at the mast base
            if (_sail != null)
            {
                PositionSailAtMastBase();
            }
        }

        private void Update()
        {
            if (_enableSailVisualRotation && _sail != null)
            {
                UpdateSailVisualRotation();
            }
        }

        /// <summary>
        /// Validates and auto-assigns references where possible.
        /// </summary>
        private void ValidateAndSetupReferences()
        {
            // Get Rigidbody
            if (_rigidbody == null)
            {
                _rigidbody = GetComponent<Rigidbody>();
            }

            // Find board visual if not assigned
            if (_boardVisual == null)
            {
                Transform boardChild = transform.Find("Board");
                if (boardChild != null)
                {
                    _boardVisual = boardChild;
                }
            }

            // Find sail if not assigned
            if (_sail == null)
            {
                _sail = GetComponentInChildren<Sail>();
            }

            // Get other components
            _buoyancy = GetComponent<BuoyancyBody>();
            _apparentWind = GetComponentInChildren<ApparentWindCalculator>();

            // Validate
            if (_boardVisual == null)
            {
                Debug.LogWarning($"WindsurfRig on {gameObject.name}: No Board visual assigned. " +
                    "Create a child named 'Board' or assign it manually.");
            }

            if (_sail == null)
            {
                Debug.LogWarning($"WindsurfRig on {gameObject.name}: No Sail found. " +
                    "Add Sail component to a child object.");
            }
        }

        /// <summary>
        /// Positions the sail's transform so its pivot (mast base) aligns with the mast position on the board.
        /// </summary>
        private void PositionSailAtMastBase()
        {
            if (_sail == null) return;

            // The sail's pivot is at the mast base (as set up in Blender)
            // So we just need to position it at the mast base position on the board
            _sail.transform.localPosition = _mastBasePosition;
            _sail.transform.localRotation = Quaternion.identity;
        }

        /// <summary>
        /// Updates the sail's visual rotation based on apparent wind direction.
        /// This is purely cosmetic - the physics are calculated in the Sail script.
        /// </summary>
        private void UpdateSailVisualRotation()
        {
            // Get the sail's calculated angle from the Sail script
            float sailAngle = _sail.CurrentSailAngle;
            
            // Clamp to max visual angle
            sailAngle = Mathf.Clamp(sailAngle, -_maxSailVisualAngle, _maxSailVisualAngle);
            
            // Apply rotation around the Y axis (since sail rotates around mast)
            // The sail's pivot point is already at the mast base
            _sail.transform.localRotation = Quaternion.Euler(0f, sailAngle, 0f);
        }

        /// <summary>
        /// Gets the velocity at a specific world position on the rig.
        /// Useful for calculating apparent wind at the sail position.
        /// </summary>
        public Vector3 GetVelocityAtPoint(Vector3 worldPoint)
        {
            if (_rigidbody == null) return Vector3.zero;
            return _rigidbody.GetPointVelocity(worldPoint);
        }

        /// <summary>
        /// Calculates the center of mass position accounting for sailor weight shift.
        /// </summary>
        public void UpdateCenterOfMass(Vector3 sailorOffset)
        {
            if (_rigidbody == null) return;

            // Base center of mass (board center)
            Vector3 baseCOM = Vector3.zero;
            
            // Adjust based on sailor position (simplified)
            // Sailor weight shifts the COM
            _rigidbody.centerOfMass = baseCOM + sailorOffset * 0.1f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos()
        {
            if (!_showDebugGizmos) return;

            // Draw mast base position
            Vector3 mastPos = transform.TransformPoint(_mastBasePosition);
            Gizmos.color = Color.cyan;
            Gizmos.DrawWireSphere(mastPos, 0.1f);
            Gizmos.DrawLine(mastPos, mastPos + Vector3.up * 4f); // Mast line

            // Draw board bounds (approximate)
            Gizmos.color = new Color(0.5f, 0.3f, 0f, 0.5f);
            Vector3 boardCenter = transform.position;
            Gizmos.DrawWireCube(boardCenter, new Vector3(0.6f, 0.15f, 2.5f));
        }

        private void OnDrawGizmosSelected()
        {
            if (!_showDebugGizmos) return;

            // Draw connection between board and sail
            Vector3 mastPos = transform.TransformPoint(_mastBasePosition);
            
            // Draw sail center of effort connection
            if (_sail != null && Application.isPlaying)
            {
                Gizmos.color = Color.yellow;
                Gizmos.DrawLine(mastPos, _sail.CurrentCenterOfEffort);
            }

            // Draw coordinate axes at mast base
            Gizmos.color = Color.red;
            Gizmos.DrawRay(mastPos, transform.right * 0.5f);
            Gizmos.color = Color.green;
            Gizmos.DrawRay(mastPos, transform.up * 0.5f);
            Gizmos.color = Color.blue;
            Gizmos.DrawRay(mastPos, transform.forward * 0.5f);

            // Label
            UnityEditor.Handles.Label(mastPos + Vector3.up * 0.3f, "Mast Base");
        }
#endif
    }
}
