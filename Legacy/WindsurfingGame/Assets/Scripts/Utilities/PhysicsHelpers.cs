using UnityEngine;

namespace WindsurfingGame.Utilities
{
    // NOTE: PhysicsConstants has been removed from this file.
    // Use WindsurfingGame.Physics.Core.PhysicsConstants instead.
    // This file now only contains extension methods and helpers.

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
