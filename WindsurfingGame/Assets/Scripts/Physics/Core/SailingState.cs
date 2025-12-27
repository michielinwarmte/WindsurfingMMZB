using UnityEngine;

namespace WindsurfingGame.Physics.Core
{
    /// <summary>
    /// Represents the state of a sailing craft at a point in time.
    /// Used for physics calculations and equilibrium solving.
    /// </summary>
    [System.Serializable]
    public class SailingState
    {
        // Velocities
        public Vector3 BoatVelocity;           // m/s in world space
        public Vector3 AngularVelocity;        // rad/s
        public float BoatSpeed;                 // m/s (magnitude)
        public float HeadingAngle;              // degrees from North (Z+)
        
        // Wind
        public Vector3 TrueWind;                // m/s in world space
        public Vector3 ApparentWind;            // m/s in world space
        public float TrueWindSpeed;             // m/s
        public float TrueWindAngle;             // degrees from bow
        public float ApparentWindSpeed;         // m/s
        public float ApparentWindAngle;         // degrees from bow
        
        // Sail state
        public float SailAngle;                 // degrees from centerline
        public float AngleOfAttack;             // degrees
        public float SailCamber;                // ratio (0-0.2)
        public Vector3 CenterOfEffort;          // world position
        
        // Forces
        public Vector3 SailLift;                // N
        public Vector3 SailDrag;                // N
        public Vector3 SailForce;               // N (total)
        public Vector3 FinLift;                 // N
        public Vector3 FinDrag;                 // N
        public Vector3 HullDrag;                // N
        public Vector3 TotalForce;              // N
        public Vector3 TotalTorque;             // Nm
        
        // Derived values
        public float DriveForce;                // N (forward component)
        public float SideForce;                 // N (lateral component)
        public float TotalDrag;                 // N (magnitude of all drag)
        public float HeelingMoment;             // Nm
        public float LeewayAngle;               // degrees
        public float VMG;                       // Velocity Made Good to wind (m/s)
        
        // State flags
        public bool IsPlaning;
        public bool IsInIrons;                  // Stuck head-to-wind
        public bool IsSailStalled;
        public bool IsFinStalled;
        
        /// <summary>
        /// Calculate derived values from primary state.
        /// </summary>
        public void UpdateDerivedValues(Vector3 boatForward, Vector3 boatRight)
        {
            // Speed
            BoatSpeed = BoatVelocity.magnitude;
            
            // Drive force (forward component of sail force)
            DriveForce = Vector3.Dot(SailForce, boatForward);
            
            // Side force (lateral component)
            SideForce = Vector3.Dot(SailForce, boatRight);
            
            // VMG to windward
            if (TrueWindSpeed > 0.5f)
            {
                Vector3 windwardDir = -TrueWind.normalized;
                VMG = Vector3.Dot(BoatVelocity, windwardDir);
            }
            else
            {
                VMG = 0f;
            }
            
            // Total forces
            TotalForce = SailForce + FinLift + FinDrag + HullDrag;
            
            // Total drag (sum of all resistance forces)
            TotalDrag = SailDrag.magnitude + FinDrag.magnitude + HullDrag.magnitude;
            
            // State flags
            IsInIrons = ApparentWindAngle < 30f && BoatSpeed < 1f;
            IsSailStalled = Mathf.Abs(AngleOfAttack) > 25f;
            IsFinStalled = Mathf.Abs(LeewayAngle) > 15f;
        }
        
        /// <summary>
        /// Calculate apparent wind from true wind and boat velocity.
        /// </summary>
        public void CalculateApparentWind(Vector3 boatForward)
        {
            // Apparent wind = True wind - Boat velocity
            ApparentWind = TrueWind - BoatVelocity;
            ApparentWindSpeed = ApparentWind.magnitude;
            
            if (ApparentWindSpeed > 0.1f)
            {
                // Angle from bow
                Vector3 awHorizontal = new Vector3(ApparentWind.x, 0, ApparentWind.z);
                Vector3 fwdHorizontal = new Vector3(boatForward.x, 0, boatForward.z).normalized;
                ApparentWindAngle = Vector3.SignedAngle(-awHorizontal.normalized, fwdHorizontal, Vector3.up);
            }
            else
            {
                ApparentWindAngle = TrueWindAngle;
            }
        }
    }
    
    /// <summary>
    /// Sail configuration parameters.
    /// </summary>
    [System.Serializable]
    public class SailConfiguration
    {
        [Header("Sail Dimensions")]
        [Tooltip("Sail area in square meters")]
        public float Area = 6.5f;
        
        [Tooltip("Luff length (leading edge) in meters")]
        public float LuffLength = 4.7f;
        
        [Tooltip("Boom length in meters")]
        public float BoomLength = 2.0f;
        
        [Tooltip("Mast height in meters")]
        public float MastHeight = 4.6f;
        
        [Header("Sail Shape")]
        [Tooltip("Sail camber (curvature) - 0.08 flat, 0.15 full")]
        [Range(0.05f, 0.20f)]
        public float Camber = 0.10f;
        
        [Tooltip("Sail twist in degrees (top relative to bottom)")]
        [Range(0f, 20f)]
        public float Twist = 10f;
        
        [Header("Rigging")]
        [Tooltip("Mast foot position on board (local space)")]
        public Vector3 MastFootPosition = new Vector3(0, 0.1f, -0.1f);
        
        [Tooltip("Boom height on mast")]
        public float BoomHeight = 1.4f;
        
        /// <summary>
        /// Calculate aspect ratio (efficiency indicator).
        /// </summary>
        public float AspectRatio => (LuffLength * LuffLength) / Area;
        
        /// <summary>
        /// Approximate center of effort height above deck.
        /// </summary>
        public float CenterOfEffortHeight => MastFootPosition.y + BoomHeight + (LuffLength - BoomHeight) * 0.4f;
    }
    
    /// <summary>
    /// Fin configuration parameters.
    /// </summary>
    [System.Serializable]
    public class FinConfiguration
    {
        [Header("Fin Dimensions")]
        [Tooltip("Fin projected area in square meters")]
        public float Area = 0.035f;
        
        [Tooltip("Fin depth (span) in meters")]
        public float Depth = 0.40f;
        
        [Tooltip("Average chord length in meters")]
        public float Chord = 0.10f;
        
        [Header("Position")]
        [Tooltip("Fin position relative to board center (local space)")]
        public Vector3 Position = new Vector3(0, -0.1f, -0.9f);
        
        [Header("Performance")]
        [Tooltip("Stall angle in degrees")]
        public float StallAngle = 14f;
        
        /// <summary>
        /// Calculate aspect ratio.
        /// </summary>
        public float AspectRatio => (Depth * Depth) / Area;
    }
    
    /// <summary>
    /// Hull configuration parameters.
    /// </summary>
    [System.Serializable]
    public class HullConfiguration
    {
        [Header("Dimensions")]
        [Tooltip("Board length in meters")]
        public float Length = 2.5f;
        
        [Tooltip("Board width in meters")]
        public float Width = 0.6f;
        
        [Tooltip("Board thickness in meters")]
        public float Thickness = 0.12f;
        
        [Tooltip("Board volume in liters")]
        public float Volume = 120f;
        
        [Header("Mass")]
        [Tooltip("Board mass in kg")]
        public float BoardMass = 8f;
        
        [Tooltip("Rig mass (mast, boom, sail) in kg")]
        public float RigMass = 8f;
        
        [Tooltip("Sailor mass in kg")]
        public float SailorMass = 75f;
        
        /// <summary>
        /// Total system mass.
        /// </summary>
        public float TotalMass => BoardMass + RigMass + SailorMass;
        
        /// <summary>
        /// Approximate wetted surface area at rest.
        /// </summary>
        public float WettedArea => Length * Width * 0.7f + 2f * (Length + Width) * 0.05f;
        
        /// <summary>
        /// Waterline length (board not fully submerged).
        /// </summary>
        public float WaterlineLength => Length * 0.8f;
    }
}
