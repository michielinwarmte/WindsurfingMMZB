using UnityEngine;

namespace WindsurfingGame.Utilities
{
    /// <summary>
    /// Utility class for common physics calculations used throughout the game.
    /// </summary>
    public static class PhysicsConstants
    {
        // Water properties
        public const float WATER_DENSITY_FRESH = 1000f;    // kg/m³
        public const float WATER_DENSITY_SALT = 1025f;     // kg/m³
        
        // Air properties  
        public const float AIR_DENSITY = 1.225f;           // kg/m³ at sea level
        
        // Common conversions
        public const float KNOTS_TO_MS = 0.514444f;        // 1 knot = 0.514 m/s
        public const float MS_TO_KNOTS = 1.94384f;         // 1 m/s = 1.944 knots
        public const float MS_TO_KMH = 3.6f;               // 1 m/s = 3.6 km/h
        public const float KMH_TO_MS = 0.277778f;          // 1 km/h = 0.278 m/s
    }

    /// <summary>
    /// Extension methods for common Unity operations.
    /// </summary>
    public static class VectorExtensions
    {
        /// <summary>
        /// Returns the vector with Y component set to zero (horizontal only).
        /// </summary>
        public static Vector3 Horizontal(this Vector3 v)
        {
            return new Vector3(v.x, 0, v.z);
        }

        /// <summary>
        /// Returns the horizontal magnitude (ignoring Y).
        /// </summary>
        public static float HorizontalMagnitude(this Vector3 v)
        {
            return Mathf.Sqrt(v.x * v.x + v.z * v.z);
        }

        /// <summary>
        /// Converts a 2D direction (XZ plane) to a 3D vector.
        /// </summary>
        public static Vector3 ToVector3XZ(this Vector2 v)
        {
            return new Vector3(v.x, 0, v.y);
        }
    }

    /// <summary>
    /// Helper for working with angles and directions.
    /// </summary>
    public static class AngleHelper
    {
        /// <summary>
        /// Converts a direction vector to an angle in degrees (from forward/Z axis).
        /// </summary>
        public static float DirectionToAngle(Vector3 direction)
        {
            return Mathf.Atan2(direction.x, direction.z) * Mathf.Rad2Deg;
        }

        /// <summary>
        /// Converts an angle in degrees to a direction vector.
        /// </summary>
        public static Vector3 AngleToDirection(float angleDegrees)
        {
            float radians = angleDegrees * Mathf.Deg2Rad;
            return new Vector3(Mathf.Sin(radians), 0, Mathf.Cos(radians));
        }

        /// <summary>
        /// Returns the signed angle between two directions (in degrees).
        /// Positive = clockwise, Negative = counter-clockwise.
        /// </summary>
        public static float SignedAngleBetween(Vector3 from, Vector3 to)
        {
            return Vector3.SignedAngle(from, to, Vector3.up);
        }
    }
}
