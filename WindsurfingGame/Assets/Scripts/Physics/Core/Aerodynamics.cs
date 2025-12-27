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
        /// </summary>
        public static void CalculateSailForces(
            Vector3 apparentWind,
            Vector3 sailNormal,
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
            
            Vector3 windDir = apparentWind.normalized;
            
            // Angle of attack: angle between wind direction and sail plane
            // Sail normal is perpendicular to sail surface
            float dotProduct = Vector3.Dot(-windDir, sailNormal);
            float angleOfAttack = 90f - Mathf.Acos(Mathf.Clamp(dotProduct, -1f, 1f)) * PhysicsConstants.RAD_TO_DEG;
            
            // Calculate coefficients
            float Cl = CalculateSailLiftCoefficient(angleOfAttack, camber, aspectRatio);
            float Cd = CalculateSailDragCoefficient(Cl, angleOfAttack, aspectRatio);
            
            // Dynamic pressure: q = 0.5 * ρ * V²
            float dynamicPressure = 0.5f * PhysicsConstants.AIR_DENSITY * windSpeed * windSpeed;
            
            // Force magnitudes
            float liftMag = dynamicPressure * sailArea * Cl;
            float dragMag = dynamicPressure * sailArea * Cd;
            
            // Lift direction: perpendicular to wind, in horizontal plane
            Vector3 liftDir = Vector3.Cross(Vector3.up, windDir).normalized;
            
            // Determine which side based on sail orientation
            if (Vector3.Dot(liftDir, sailNormal) < 0)
                liftDir = -liftDir;
            
            // Drag direction: along wind direction
            Vector3 dragDir = windDir;
            
            liftForce = liftDir * liftMag;
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
