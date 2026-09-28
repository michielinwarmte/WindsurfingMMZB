using UnityEngine;

namespace WindsurfingGame.Physics.Core
{
    /// <summary>
    /// Physical constants used throughout the simulation.
    /// Based on real-world values for accurate physics.
    /// </summary>
    public static class PhysicsConstants
    {
        // Fluid Properties
        public const float AIR_DENSITY = 1.225f;           // kg/m³ at sea level, 15°C
        public const float WATER_DENSITY = 1025f;          // kg/m³ seawater
        public const float WATER_KINEMATIC_VISCOSITY = 1.19e-6f; // m²/s at 15°C
        public const float AIR_KINEMATIC_VISCOSITY = 1.48e-5f;   // m²/s at 15°C
        
        // Gravity
        public const float GRAVITY = 9.81f;                // m/s²
        
        // Unit Conversions
        public const float MS_TO_KNOTS = 1.94384f;
        public const float KNOTS_TO_MS = 0.514444f;
        public const float DEG_TO_RAD = Mathf.PI / 180f;
        public const float RAD_TO_DEG = 180f / Mathf.PI;
        
        // Typical Windsurf Equipment
        public static class Equipment
        {
            // Board dimensions (typical freeride board)
            public const float BOARD_LENGTH = 2.5f;        // meters
            public const float BOARD_WIDTH = 0.6f;         // meters  
            public const float BOARD_THICKNESS = 0.12f;    // meters
            public const float BOARD_VOLUME = 120f;        // liters
            public const float BOARD_MASS = 8f;            // kg (board only)
            
            // Fin
            public const float FIN_DEPTH = 0.40f;          // meters
            public const float FIN_CHORD = 0.12f;          // meters (average)
            public const float FIN_AREA = 0.035f;          // m² (typical 35cm fin)
            public const float FIN_ASPECT_RATIO = 4.5f;    // depth²/area
            
            // Sail (6.5m² freeride)
            public const float SAIL_AREA = 6.5f;           // m²
            public const float SAIL_LUFF_LENGTH = 4.7f;    // meters
            public const float SAIL_BOOM_LENGTH = 2.0f;    // meters
            public const float SAIL_MAST_HEIGHT = 4.6f;    // meters
            
            // Sailor
            public const float SAILOR_MASS = 75f;          // kg
            public const float SAILOR_HEIGHT = 1.75f;      // meters
        }
    }
}
