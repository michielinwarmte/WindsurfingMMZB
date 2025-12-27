using UnityEngine;

namespace WindsurfingGame.Physics.Core
{
    /// <summary>
    /// Hydrodynamic calculations for underwater appendages (fin) and hull.
    /// Based on lifting-line theory and empirical yacht design data.
    /// 
    /// References:
    /// - Abbott & Von Doenhoff "Theory of Wing Sections"
    /// - Fossati, F. "Aero-Hydrodynamics and the Performance of Sailing Yachts"
    /// - Larsson & Eliasson "Principles of Yacht Design"
    /// </summary>
    public static class Hydrodynamics
    {
        /// <summary>
        /// Calculates lift coefficient for a fin/foil based on angle of attack.
        /// Uses NACA 0012-like symmetric foil characteristics.
        /// </summary>
        /// <param name="angleOfAttack">Leeway angle / slip angle (degrees)</param>
        /// <param name="aspectRatio">Fin aspect ratio (span²/area)</param>
        /// <returns>Lift coefficient (CL)</returns>
        public static float CalculateFinLiftCoefficient(float angleOfAttack, float aspectRatio = 4.5f)
        {
            float alpha = Mathf.Abs(angleOfAttack);
            float sign = Mathf.Sign(angleOfAttack);
            
            // Lift curve slope for finite wing
            // dCL/dα = 2π * AR / (AR + 2) * (1 + τ)
            // τ accounts for non-elliptical loading (~0.05)
            float tau = 0.05f;
            float liftSlope = 2f * Mathf.PI * aspectRatio / (aspectRatio + 2f) * (1f + tau);
            
            // Convert to radians for calculation
            float alphaRad = alpha * PhysicsConstants.DEG_TO_RAD;
            
            float CL;
            if (alpha < 8f)
            {
                // Linear region - attached flow
                CL = liftSlope * alphaRad;
            }
            else if (alpha < 12f)
            {
                // Transition - flow beginning to separate
                float linearCL = liftSlope * 8f * PhysicsConstants.DEG_TO_RAD;
                float additionalCL = (alpha - 8f) / 4f * 0.15f;
                CL = linearCL + additionalCL;
            }
            else if (alpha < 16f)
            {
                // Stall region - lift peaks and drops
                float maxCL = liftSlope * 8f * PhysicsConstants.DEG_TO_RAD + 0.15f;
                float stallProgress = (alpha - 12f) / 4f;
                CL = Mathf.Lerp(maxCL, maxCL * 0.7f, stallProgress);
            }
            else if (alpha < 25f)
            {
                // Post-stall
                float stallCL = liftSlope * 8f * PhysicsConstants.DEG_TO_RAD * 0.7f;
                float deepStallProgress = (alpha - 16f) / 9f;
                CL = Mathf.Lerp(stallCL, 0.4f, deepStallProgress);
            }
            else
            {
                // Deep stall - fin acting as a plate
                CL = 0.4f * Mathf.Cos((alpha - 25f) * 2f * PhysicsConstants.DEG_TO_RAD);
                CL = Mathf.Max(CL, 0.1f);
            }
            
            return CL * sign;
        }
        
        /// <summary>
        /// Calculates drag coefficient for a fin.
        /// Includes profile drag and induced drag.
        /// </summary>
        public static float CalculateFinDragCoefficient(float liftCoeff, float aspectRatio = 4.5f)
        {
            // Profile drag (minimum drag of the foil section)
            // NACA 0012 at Re ~ 10^6: Cd0 ≈ 0.006
            float Cd0 = 0.008f; // Slightly higher for typical fin construction
            
            // Induced drag: CDi = CL² / (π * AR * e)
            float oswaldEfficiency = 0.85f; // Good for well-designed fins
            float inducedDrag = (liftCoeff * liftCoeff) / (Mathf.PI * aspectRatio * oswaldEfficiency);
            
            // Viscous drag increase with angle (boundary layer thickening)
            float absLift = Mathf.Abs(liftCoeff);
            float viscousDrag = Cd0 * absLift * 0.5f;
            
            return Cd0 + inducedDrag + viscousDrag;
        }
        
        /// <summary>
        /// Calculates the hydrodynamic forces on a fin.
        /// </summary>
        public static void CalculateFinForces(
            Vector3 velocity,
            Vector3 finForward,
            Vector3 finRight,
            float finArea,
            float aspectRatio,
            out Vector3 liftForce,
            out Vector3 dragForce,
            out float leewayAngle)
        {
            float speed = velocity.magnitude;
            
            if (speed < 0.3f)
            {
                liftForce = Vector3.zero;
                dragForce = Vector3.zero;
                leewayAngle = 0f;
                return;
            }
            
            Vector3 velocityDir = velocity.normalized;
            
            // Leeway angle: angle between velocity and fin forward direction
            // This is the "angle of attack" for the fin
            Vector3 velocityHorizontal = new Vector3(velocity.x, 0, velocity.z);
            Vector3 finForwardHorizontal = new Vector3(finForward.x, 0, finForward.z).normalized;
            
            if (velocityHorizontal.magnitude < 0.1f)
            {
                liftForce = Vector3.zero;
                dragForce = Vector3.zero;
                leewayAngle = 0f;
                return;
            }
            
            velocityHorizontal.Normalize();
            
            // Calculate signed leeway angle
            leewayAngle = Vector3.SignedAngle(finForwardHorizontal, velocityHorizontal, Vector3.up);
            
            // Calculate coefficients
            float CL = CalculateFinLiftCoefficient(leewayAngle, aspectRatio);
            float CD = CalculateFinDragCoefficient(CL, aspectRatio);
            
            // Dynamic pressure: q = 0.5 * ρ * V²
            float dynamicPressure = 0.5f * PhysicsConstants.WATER_DENSITY * speed * speed;
            
            // Force magnitudes
            float liftMag = dynamicPressure * finArea * Mathf.Abs(CL);
            float dragMag = dynamicPressure * finArea * CD;
            
            // Lift direction: perpendicular to velocity, horizontal
            // Points to oppose the sideways drift
            Vector3 liftDir = -finRight * Mathf.Sign(leewayAngle);
            
            // Drag direction: opposite to velocity
            Vector3 dragDir = -velocityDir;
            
            liftForce = liftDir * liftMag;
            dragForce = dragDir * dragMag;
        }
        
        /// <summary>
        /// Calculates hull resistance using Delft Systematic Yacht Hull Series data.
        /// Simplified model for windsurf board hull.
        /// </summary>
        public static float CalculateHullResistance(
            float speed,
            float displacement,
            float wettedArea,
            float waterlineLength,
            bool isPlaning)
        {
            if (speed < 0.1f) return 0f;
            
            // Froude number: Fn = V / √(g * L)
            float froudeNumber = speed / Mathf.Sqrt(PhysicsConstants.GRAVITY * waterlineLength);
            
            // Reynolds number for friction calculation
            float Re = speed * waterlineLength / PhysicsConstants.WATER_KINEMATIC_VISCOSITY;
            Re = Mathf.Max(Re, 1e5f); // Minimum for valid friction formula
            
            // Frictional resistance coefficient (ITTC 1957)
            float Cf = 0.075f / Mathf.Pow(Mathf.Log10(Re) - 2f, 2f);
            
            // Frictional resistance
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed * speed;
            float Rf = Cf * q * wettedArea;
            
            float totalResistance;
            
            if (!isPlaning || froudeNumber < 0.4f)
            {
                // Displacement mode
                // Residuary resistance (wave-making + form drag)
                // Approximation based on Delft series
                float Cr = 0.001f * Mathf.Pow(froudeNumber, 4f) * (1f + 5f * froudeNumber);
                float Rr = Cr * q * wettedArea;
                
                totalResistance = Rf + Rr;
            }
            else
            {
                // Planing mode - resistance drops as board lifts
                float planingFactor = Mathf.Clamp01((froudeNumber - 0.4f) / 0.3f);
                
                // Planing resistance is primarily skin friction on reduced wetted area
                float reducedWettedArea = wettedArea * (1f - 0.5f * planingFactor);
                float planingRf = Cf * q * reducedWettedArea;
                
                // Small residual spray drag
                float sprayDrag = 0.002f * q * wettedArea * (1f - planingFactor);
                
                // Transition blend
                float displacementR = Rf * 1.5f; // Higher resistance at transition
                totalResistance = Mathf.Lerp(displacementR, planingRf + sprayDrag, planingFactor);
            }
            
            return totalResistance;
        }
        
        /// <summary>
        /// Calculates added resistance due to waves (simplified).
        /// </summary>
        public static float CalculateWaveResistance(float speed, float waveHeight, float waveLength)
        {
            if (speed < 0.5f || waveHeight < 0.05f) return 0f;
            
            // Simplified added resistance in waves
            // Based on Gerritsma & Beukelman
            float waveFreq = Mathf.Sqrt(PhysicsConstants.GRAVITY / waveLength);
            float encounterFreq = waveFreq + speed * 2f * Mathf.PI / waveLength;
            
            // Added resistance proportional to wave height squared
            float rawAddedResistance = 50f * waveHeight * waveHeight * encounterFreq;
            
            return rawAddedResistance;
        }
    }
}
