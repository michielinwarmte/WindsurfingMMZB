using UnityEngine;

namespace WindsurfingGame.Physics.Wind
{
    /// <summary>
    /// Interface for wind providers.
    /// Allows different wind implementations (constant, variable, zones).
    /// </summary>
    public interface IWindProvider
    {
        /// <summary>
        /// Gets the wind vector at a given world position.
        /// The magnitude is wind speed (m/s), direction is where wind blows TO.
        /// </summary>
        Vector3 GetWindAtPosition(Vector3 worldPosition);

        /// <summary>
        /// Gets the base/global wind direction (normalized).
        /// </summary>
        Vector3 WindDirection { get; }

        /// <summary>
        /// Gets the base/global wind speed in m/s.
        /// </summary>
        float WindSpeed { get; }
    }
}
