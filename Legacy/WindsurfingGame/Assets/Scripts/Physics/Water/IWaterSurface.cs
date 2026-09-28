using UnityEngine;

namespace WindsurfingGame.Physics.Water
{
    /// <summary>
    /// Interface for any water surface that can provide height information.
    /// This allows different water implementations (flat, waves, etc.) to be used interchangeably.
    /// </summary>
    public interface IWaterSurface
    {
        /// <summary>
        /// Gets the water height at a given world position.
        /// </summary>
        /// <param name="worldPosition">The world position to sample.</param>
        /// <returns>The Y coordinate of the water surface at that position.</returns>
        float GetWaterHeight(Vector3 worldPosition);

        /// <summary>
        /// Gets the surface normal at a given world position.
        /// Useful for aligning objects to the water surface.
        /// </summary>
        /// <param name="worldPosition">The world position to sample.</param>
        /// <returns>The normal vector of the water surface.</returns>
        Vector3 GetSurfaceNormal(Vector3 worldPosition);

        /// <summary>
        /// Gets both height and normal in one call (more efficient for some implementations).
        /// </summary>
        /// <param name="worldPosition">The world position to sample.</param>
        /// <param name="height">Output: the water height.</param>
        /// <param name="normal">Output: the surface normal.</param>
        void GetWaterData(Vector3 worldPosition, out float height, out Vector3 normal);
    }
}
