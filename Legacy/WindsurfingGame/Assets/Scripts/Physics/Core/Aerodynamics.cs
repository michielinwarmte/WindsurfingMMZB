using UnityEngine;

namespace WindsurfingGame.Physics.Core
{
    /// <summary>
    /// Aerodynamic calculations for sail physics.
    /// Based on thin airfoil theory and experimental sail data.
    /// 
    /// References:
    /// - Marchaj, C.A. "Sail Performance: Theory and Practice"
    /// - Larsson & Eliasson "Principles of Yacht Design"
    /// - Jackson, P.S. "Modelling the Aerodynamics of Upwind Sails"
    /// </summary>
    public static class Aerodynamics
    {
        /// <summary>
        /// Calculates lift coefficient for a sail based on angle of attack.
        /// Uses a realistic sail polar based on experimental data.
        /// </summary>
        /// <param name="angleOfAttack">Angle between apparent wind and sail chord (degrees)</param>
        /// <param name="camber">Sail camber ratio (typically 0.08-0.15)</param>
        /// <param name="aspectRatio">Sail aspect ratio (luff²/area, typically 3-5)</param>
        /// <returns>Lift coefficient (Cl)</returns>
        public static float CalculateSailLiftCoefficient(float angleOfAttack, float camber = 0.10f, float aspectRatio = 4f)
        {
            float alpha = Mathf.Abs(angleOfAttack);
            
            // Sail lift curve based on thin airfoil theory with viscous corrections
            // Cl = 2π * sin(α) for thin airfoil, modified for real sails
            
            // Zero-lift angle (sails have camber, so they generate lift at α=0)
            float zeroLiftAngle = -camber * 60f; // Approximate: αL0 ≈ -camber * 60°
            float effectiveAlpha = alpha - zeroLiftAngle;
            
            // Lift curve slope (reduced from 2π due to viscous effects and finite span)
            // dCl/dα ≈ 2π * AR / (AR + 2) for finite wings
            float liftSlope = 2f * Mathf.PI * aspectRatio / (aspectRatio + 2f);
            liftSlope *= 0.9f; // Reduction for sail flexibility and gaps
            
            float alphaRad = effectiveAlpha * PhysicsConstants.DEG_TO_RAD;
            
            if (alpha < 12f)
            {
                // Linear region
                return liftSlope * alphaRad;
            }
            else if (alpha < 18f)
            {
                // Transition to stall - lift still increasing but slower
                float linearCl = liftSlope * 12f * PhysicsConstants.DEG_TO_RAD;
                float additionalLift = (alpha - 12f) / 6f * 0.3f;
                return linearCl + additionalLift;
            }
            else if (alpha < 25f)
            {
                // Near stall - lift peaks around 18-20°
                float maxCl = liftSlope * 12f * PhysicsConstants.DEG_TO_RAD + 0.3f;
                float stallProgress = (alpha - 18f) / 7f;
                return Mathf.Lerp(maxCl, maxCl * 0.85f, stallProgress);
            }
            else if (alpha < 45f)
            {
                // Post-stall - gradual decrease
                float stallCl = liftSlope * 12f * PhysicsConstants.DEG_TO_RAD * 0.85f;
                float deepStallProgress = (alpha - 25f) / 20f;
                return Mathf.Lerp(stallCl, 0.5f, deepStallProgress);
            }
            else
            {
                // Deep stall / flag behavior
                return 0.5f * Mathf.Cos((alpha - 45f) * PhysicsConstants.DEG_TO_RAD);
            }
        }
        
        /// <summary>
        /// Calculates drag coefficient for a sail.
        /// Includes induced drag (from lift) and parasitic drag.
        /// </summary>
        public static float CalculateSailDragCoefficient(float liftCoeff, float angleOfAttack, float aspectRatio = 4f)
        {
            float alpha = Mathf.Abs(angleOfAttack);
            
            // Parasitic drag (minimum drag at small angles)
            float Cd0 = 0.015f; // Clean sail
            
            // Induced drag: Cdi = Cl² / (π * AR * e)
            // e = Oswald efficiency factor (0.7-0.9 for sails)
            float oswaldEfficiency = 0.75f;
            float inducedDrag = (liftCoeff * liftCoeff) / (Mathf.PI * aspectRatio * oswaldEfficiency);
            
            // Separation drag (increases past stall)
            float separationDrag = 0f;
            if (alpha > 15f)
            {
                separationDrag = Mathf.Pow((alpha - 15f) / 30f, 2f) * 0.5f;
            }
            
            // Form drag at high angles (sail acts like a plate)
            float formDrag = 0f;
            if (alpha > 45f)
            {
                formDrag = Mathf.Sin(alpha * PhysicsConstants.DEG_TO_RAD) * 1.2f;
            }
            
            return Cd0 + inducedDrag + separationDrag + formDrag;
        }
        
        /// <summary>
        /// Calculates the aerodynamic forces on a sail.
        /// Returns lift and drag in the wind reference frame.
        /// 
        /// Based on real sailing physics:
        /// - Lift acts perpendicular to the apparent wind direction
        /// - Drag acts along the apparent wind direction (with the wind)
        /// - Lift must have a forward component for drive
        /// 
        /// Reference: Wikipedia "Forces on sails"
        /// </summary>
        public static void CalculateSailForces(
            Vector3 apparentWind,
            Vector3 sailNormal,
            Vector3 boatForward,
            float sailArea,
            float camber,
            float aspectRatio,
            out Vector3 liftForce,
            out Vector3 dragForce)
        {
            float windSpeed = apparentWind.magnitude;
            
            if (windSpeed < 0.5f)
            {
                liftForce = Vector3.zero;
                dragForce = Vector3.zero;
                return;
            }
            
            // Wind direction: the direction the wind is BLOWING TO (not from)
            Vector3 windDir = apparentWind.normalized;
            
            // The direction wind is coming FROM (opposite of wind velocity vector)
            Vector3 windFromDir = -windDir;
            
            // Angle of attack: angle between the wind direction and the sail plane
            // The sail plane is perpendicular to the sail normal
            // AoA = angle between (wind from direction) and (sail plane)
            // If normal is perpendicular to sail, then:
            // cos(90° - AoA) = dot(windFromDir, sailNormal)
            // sin(AoA) = dot(windFromDir, sailNormal)
            float sinAoA = Vector3.Dot(windFromDir, sailNormal);
            float angleOfAttack = Mathf.Asin(Mathf.Clamp(sinAoA, -1f, 1f)) * PhysicsConstants.RAD_TO_DEG;
            
            // Calculate coefficients (use absolute AoA for coefficient lookup)
            float Cl = CalculateSailLiftCoefficient(Mathf.Abs(angleOfAttack), camber, aspectRatio);
            float Cd = CalculateSailDragCoefficient(Cl, Mathf.Abs(angleOfAttack), aspectRatio);
            
            // Dynamic pressure: q = 0.5 * ρ * V²
            float dynamicPressure = 0.5f * PhysicsConstants.AIR_DENSITY * windSpeed * windSpeed;
            
            // Force magnitudes
            float liftMag = dynamicPressure * sailArea * Cl;
            float dragMag = dynamicPressure * sailArea * Cd;
            
            // LIFT DIRECTION: Perpendicular to the apparent wind, in the horizontal plane
            // 
            // Key physics:
            // - Lift is ALWAYS perpendicular to the apparent wind direction
            // - Lift points from the windward side (high pressure) to leeward side (low pressure)
            // - This means lift opposes the sail normal (which points toward windward)
            //
            // For upwind sailing to work:
            // - Wind comes from ahead-and-to-the-side
            // - Lift must have a forward component to create drive
            // - The perpendicular to wind that points forward is the correct lift direction
            
            // Get horizontal component of wind direction (wind is BLOWING in this direction)
            Vector3 windHoriz = new Vector3(windDir.x, 0, windDir.z);
            if (windHoriz.sqrMagnitude < 0.01f)
            {
                liftForce = Vector3.zero;
                dragForce = windDir * dragMag;
                return;
            }
            windHoriz.Normalize();
            
            // Two perpendicular options to wind in horizontal plane
            // Using right-hand rule: perpA = Cross(up, windDir) points 90° left of wind
            Vector3 perpA = Vector3.Cross(Vector3.up, windHoriz).normalized;
            Vector3 perpB = -perpA; // 90° right of wind
            
            // LIFT DIRECTION PHYSICS:
            // 
            // The aerodynamic force on a sail comes from pressure difference:
            // - High pressure on windward side (where sail normal points)
            // - Low pressure on leeward side (opposite to sail normal)
            // 
            // This creates a force PERPENDICULAR to the sail, pointing from windward to leeward.
            // In other words: the force direction is -sailNormal (opposite to sail normal).
            //
            // However, we decompose this into:
            // - LIFT: component perpendicular to wind (what we're calculating)
            // - DRAG: component parallel to wind (handled separately)
            //
            // The lift direction is the component of (-sailNormal) that is perpendicular to wind.
            // This is equivalent to: the wind-perpendicular that best aligns with (-sailNormal).
            
            Vector3 sailNormalHoriz = new Vector3(sailNormal.x, 0, sailNormal.z);
            if (sailNormalHoriz.sqrMagnitude > 0.01f)
            {
                sailNormalHoriz.Normalize();
            }
            else
            {
                // Fallback if sail normal is vertical
                sailNormalHoriz = new Vector3(boatForward.x, 0, boatForward.z).normalized;
            }
            
            // The desired force direction is OPPOSITE to sail normal (from windward to leeward)
            Vector3 forceDir = -sailNormalHoriz;
            
            // Project this onto the perpendicular-to-wind plane
            // liftDir = forceDir - (forceDir · windDir) * windDir
            float forceDotWind = Vector3.Dot(forceDir, windHoriz);
            Vector3 liftDir = forceDir - forceDotWind * windHoriz;
            
            if (liftDir.sqrMagnitude > 0.01f)
            {
                liftDir.Normalize();
            }
            else
            {
                // Edge case: sail is edge-on to wind, use boat forward perpendicular
                Vector3 boatForwardHoriz = new Vector3(boatForward.x, 0, boatForward.z).normalized;
                float fwdDotWind = Vector3.Dot(boatForwardHoriz, windHoriz);
                liftDir = (boatForwardHoriz - fwdDotWind * windHoriz);
                if (liftDir.sqrMagnitude > 0.01f) liftDir.Normalize();
                else liftDir = perpA; // Ultimate fallback
            }
            
            // Drag direction: along the wind direction (wind pushes the sail)
            Vector3 dragDir = windDir;
            
            // Apply sign of AoA to lift magnitude (negative AoA = negative lift)
            // This handles both tacks correctly
            float liftSign = Mathf.Sign(angleOfAttack);
            if (Mathf.Abs(angleOfAttack) < 1f) liftSign = 1f; // Avoid sign flip at zero
            
            liftForce = liftDir * liftMag * liftSign;
            dragForce = dragDir * dragMag;
        }
        
        /// <summary>
        /// Calculates the optimal sheet angle for maximum drive force.
        /// </summary>
        public static float CalculateOptimalSheetAngle(float apparentWindAngle)
        {
            // The optimal sheet angle puts the sail at the best L/D ratio
            // This is typically around 15-20° angle of attack
            // Sheet angle = Apparent wind angle - Angle of attack - Sail trim offset
            
            float optimalAoA = 17f; // degrees
            float sailAngle = Mathf.Abs(apparentWindAngle) - optimalAoA;
            
            // Clamp to physical limits
            sailAngle = Mathf.Clamp(sailAngle, 5f, 85f);
            
            return sailAngle;
        }
    }
}
