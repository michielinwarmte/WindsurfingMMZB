using UnityEngine;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Physics.Buoyancy;

namespace WindsurfingGame.Physics.Board
{
    /// <summary>
    /// Advanced hull resistance model for windsurf board.
    /// 
    /// Models the hydrodynamic drag of the board hull including:
    /// - Skin friction (viscous drag)
    /// - Form drag (pressure drag from hull shape)
    /// - Wave-making resistance (at displacement speeds)
    /// - Spray drag (at planing speeds)
    /// 
    /// The model transitions between displacement mode (low speed) 
    /// and planing mode (high speed) based on Froude number.
    /// 
    /// References:
    /// - Larsson & Eliasson "Principles of Yacht Design"
    /// - Savitsky "Hydrodynamic Design of Planing Hulls"
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class AdvancedHullDrag : MonoBehaviour
    {
        [Header("Hull Configuration")]
        [SerializeField] private HullConfiguration _hullConfig = new HullConfiguration();
        
        [Header("Planing Behavior")]
        [Tooltip("Speed at which planing begins (m/s). 17 km/h = 4.7 m/s is typical")]
        [SerializeField] private float _planingOnsetSpeed = 4.0f;
        
        [Tooltip("Speed at which fully planing (m/s). ~22 km/h = 6 m/s is typical")]
        [SerializeField] private float _fullPlaningSpeed = 6.0f;
        
        [Tooltip("Wetted area reduction when fully planing (0.2 = 20% of original)")]
        [SerializeField] private float _planingWettedAreaRatio = 0.20f;
        
        [Header("Submersion Resistance")]
        [Tooltip("Extra drag multiplier when board sinks deeper (higher = stronger penalty for sinking)")]
        [SerializeField] private float _submersionDragMultiplier = 12.0f;
        
        [Tooltip("Additional vertical damping when submerged (resists bobbing)")]
        [SerializeField] private float _submersionVerticalDamping = 600f;
        
        [Header("Displacement Lift")]
        [Tooltip("Enable hydrodynamic lift at displacement speeds (before planing)")]
        [SerializeField] private bool _enableDisplacementLift = true;
        
        [Tooltip("Lift coefficient for displacement mode")]
        [SerializeField] private float _displacementLiftCoefficient = 0.12f;
        
        [Tooltip("Minimum speed for displacement lift to start (m/s)")]
        [SerializeField] private float _displacementLiftMinSpeed = 0.5f;
        
        [Header("Planing Lift")]
        [Tooltip("Enable hydrodynamic lift when planing")]
        [SerializeField] private bool _enablePlaningLift = true;
        
        [Tooltip("Planing lift multiplier - 1.0 means full target lift at planing speed")]
        [SerializeField] private float _planingLiftCoefficient = 1.0f;
        
        [Tooltip("Maximum lift as fraction of weight. At full planing, lift can support most of the weight.")]
        [SerializeField] private float _maxLiftFraction = 1.0f;
        
        [Tooltip("Trim angle for maximum lift (degrees bow-up)")]
        [SerializeField] private float _optimalTrimAngle = 3f;
        
        [Tooltip("How quickly lift changes (lower = smoother, more stable). 0.05-0.15 recommended.")]
        [SerializeField] private float _liftSmoothingFactor = 0.08f;
        
        [Tooltip("Maximum submersion before planing lift is disabled (can't plane underwater)")]
        [SerializeField] private float _maxPlaningSubmersion = 0.50f;
        
        [Header("Buoyancy Reference")]
        [SerializeField] private AdvancedBuoyancy _advancedBuoyancy;
        [SerializeField] private BuoyancyBody _legacyBuoyancy;
        
        [Header("Debug")]
        [SerializeField] private bool _showDebug = true;
        
        // Components
        private Rigidbody _rigidbody;
        
        // Buoyancy interface
        private bool IsFloating => _advancedBuoyancy != null ? _advancedBuoyancy.IsFloating : 
                                   (_legacyBuoyancy != null ? _legacyBuoyancy.IsFloating : true);
        
        // State
        private float _totalResistance;
        private float _froudeNumber;
        private float _planingRatio;
        private float _currentWettedArea;
        private bool _isPlaning;
        private Vector3 _resistanceForce;
        private float _planingLift;
        private float _displacementLift;
        private float _currentTrimAngle;
        private float _currentHeelAngle;
        private float _heelEfficiency;
        
        // Smoothing for stable lift
        private float _smoothedPlaningLift;
        
        // Public accessors
        public HullConfiguration Config => _hullConfig;
        public float Resistance => _totalResistance;
        public float FroudeNumber => _froudeNumber;
        public bool IsPlaning => _isPlaning;
        public float PlaningRatio => _planingRatio;
        public float PlaningLift => _planingLift;
        public float DisplacementLift => _displacementLift;
        public float TotalLift => _planingLift + _displacementLift;
        public float HeelAngle => _currentHeelAngle;
        public float HeelEfficiency => _heelEfficiency;
        
        private void Awake()
        {
            _rigidbody = GetComponent<Rigidbody>();
            
            // Try to find advanced buoyancy first, then fall back to legacy
            if (_advancedBuoyancy == null)
            {
                _advancedBuoyancy = GetComponent<AdvancedBuoyancy>();
            }
            if (_advancedBuoyancy == null && _legacyBuoyancy == null)
            {
                _legacyBuoyancy = GetComponent<BuoyancyBody>();
            }
            
            // Log warning if no buoyancy component found
            if (_advancedBuoyancy == null && _legacyBuoyancy == null)
            {
                Debug.LogWarning($"AdvancedHullDrag on {gameObject.name}: No buoyancy component found. " +
                    "Add AdvancedBuoyancy or BuoyancyBody for proper behavior.");
            }
        }
        
        private void FixedUpdate()
        {
            // Only apply drag when in water
            if (!IsFloating)
            {
                _resistanceForce = Vector3.zero;
                _totalResistance = 0f;
                _planingLift = 0f;
                _displacementLift = 0f;
                return;
            }
            
            CalculateHullResistance();
            CalculateDisplacementLift();
            CalculatePlaningLift();
            ApplyResistance();
            ApplyHydrodynamicLift();
        }
        
        /// <summary>
        /// Calculate hull resistance based on speed and mode (displacement/planing).
        /// </summary>
        private void CalculateHullResistance()
        {
            Vector3 velocity = _rigidbody.linearVelocity;
            float speed = velocity.magnitude;
            
            if (speed < 0.1f)
            {
                _totalResistance = 0f;
                _froudeNumber = 0f;
                _planingRatio = 0f;
                _isPlaning = false;
                _resistanceForce = Vector3.zero;
                return;
            }
            
            // Calculate Froude number (for reference/display)
            _froudeNumber = speed / Mathf.Sqrt(PhysicsConstants.GRAVITY * _hullConfig.WaterlineLength);
            
            // Calculate planing ratio based on SPEED, not Froude number
            // Real windsurfers start planing around 17 km/h (4.7 m/s)
            if (speed < _planingOnsetSpeed)
            {
                _planingRatio = 0f;
                _isPlaning = false;
            }
            else if (speed < _fullPlaningSpeed)
            {
                _planingRatio = (speed - _planingOnsetSpeed) / (_fullPlaningSpeed - _planingOnsetSpeed);
                _isPlaning = _planingRatio > 0.5f;
            }
            else
            {
                _planingRatio = 1f;
                _isPlaning = true;
            }
            
            // Calculate current wetted area (reduces when planing)
            _currentWettedArea = Mathf.Lerp(_hullConfig.WettedArea, 
                                             _hullConfig.WettedArea * _planingWettedAreaRatio,
                                             _planingRatio);
            
            // Base hull resistance from hydrodynamics module
            _totalResistance = Hydrodynamics.CalculateHullResistance(
                speed,
                _hullConfig.TotalMass,
                _currentWettedArea,
                _hullConfig.WaterlineLength,
                _isPlaning
            );
            
            // SUBMERSION-BASED RESISTANCE
            // When board sinks deeper, resistance increases significantly
            // This simulates the board "digging in" to the water
            if (_advancedBuoyancy != null)
            {
                float submersionRatio = _advancedBuoyancy.SubmergedRatio;
                
                // Normal floating is ~30-40% submerged
                // More than that means sinking, which increases drag
                float normalSubmersion = 0.35f;
                if (submersionRatio > normalSubmersion)
                {
                    // Extra drag when too deep in water - NONLINEAR (squared)
                    // This creates strong negative feedback: deeper = MUCH more drag
                    float excessSubmersion = (submersionRatio - normalSubmersion) / (1f - normalSubmersion);
                    // Squared relationship: 50% excess = 25% factor, 100% excess = 100% factor
                    float submersionDragFactor = 1f + (excessSubmersion * excessSubmersion) * _submersionDragMultiplier;
                    _totalResistance *= submersionDragFactor;
                    
                    // CRITICAL: When underwater at planing speed, add MASSIVE drag
                    // A board underwater at 20+ km/h should slow down very quickly
                    if (submersionRatio > 0.5f && speed > 4f)
                    {
                        // Additional underwater drag - proportional to speed squared
                        // This ensures the board MUST slow down when submerged
                        float underwaterDragBonus = (submersionRatio - 0.5f) * 2f; // 0 to 1
                        float speedFactor = (speed - 4f) / 4f; // ramps up from 4 m/s
                        speedFactor = Mathf.Clamp01(speedFactor);
                        
                        // Massive drag increase - up to 5x more resistance
                        float underwaterMultiplier = 1f + underwaterDragBonus * speedFactor * 5f;
                        _totalResistance *= underwaterMultiplier;
                    }
                }
                
                // Conversely, when planing and riding high, less drag
                if (_isPlaning && submersionRatio < normalSubmersion)
                {
                    float rideHighFactor = 1f - (normalSubmersion - submersionRatio) * 0.5f;
                    _totalResistance *= Mathf.Max(0.5f, rideHighFactor);
                }
                
                // SUBMERSION VERTICAL DAMPING
                // Apply extra resistance to vertical motion when submerged
                // This prevents the rapid bobbing/oscillation during planing transition
                float verticalVelocity = _rigidbody.linearVelocity.y;
                if (Mathf.Abs(verticalVelocity) > 0.02f && submersionRatio > 0.1f)
                {
                    // Damping force scales with submersion (more submerged = more damping)
                    // and with vertical velocity (faster motion = more resistance)
                    float dampingForce = -verticalVelocity * _submersionVerticalDamping * submersionRatio;
                    
                    // Extra damping when deeply submerged during planing attempt
                    if (_planingRatio > 0.2f && submersionRatio > 0.4f)
                    {
                        dampingForce *= 2f; // Double damping to fight oscillation
                    }
                    
                    _rigidbody.AddForce(Vector3.up * dampingForce, ForceMode.Force);
                }
            }
            
            // Create resistance force vector (opposes velocity)
            _resistanceForce = -velocity.normalized * _totalResistance;
            
            // Add directional resistance components
            ApplyDirectionalDrag(velocity, speed);
        }
        
        /// <summary>
        /// Apply different drag coefficients for different directions.
        /// </summary>
        private void ApplyDirectionalDrag(Vector3 velocity, float speed)
        {
            // Decompose velocity into local directions
            Vector3 localVelocity = transform.InverseTransformDirection(velocity);
            
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed;
            
            // Forward/backward - already handled by hull resistance
            // Lateral - additional form drag when moving sideways
            float lateralSpeed = Mathf.Abs(localVelocity.x);
            if (lateralSpeed > 0.1f)
            {
                // Hull has poor lateral streamlining
                float lateralCd = 1.0f; // Like a flat plate
                float lateralArea = _hullConfig.Length * _hullConfig.Thickness;
                float lateralDrag = lateralCd * q * lateralSpeed * lateralArea;
                
                // Add to resistance force
                Vector3 lateralDragForce = -transform.right * Mathf.Sign(localVelocity.x) * lateralDrag;
                _resistanceForce += lateralDragForce * (1f - _planingRatio * 0.5f); // Less when planing
            }
            
            // Vertical - resist vertical motion (bobbing)
            float verticalSpeed = Mathf.Abs(localVelocity.y);
            if (verticalSpeed > 0.1f)
            {
                float verticalCd = 1.2f;
                float verticalArea = _hullConfig.Length * _hullConfig.Width * 0.5f;
                float verticalDrag = verticalCd * q * verticalSpeed * verticalArea;
                
                Vector3 verticalDragForce = -Vector3.up * Mathf.Sign(localVelocity.y) * verticalDrag;
                _resistanceForce += verticalDragForce;
            }
        }
        
        /// <summary>
        /// Calculate hydrodynamic lift at displacement speeds.
        /// Even before planing, a moving hull generates dynamic lift.
        /// 
        /// Real Physics:
        /// - Lift = CL × 0.5ρV² × A (standard lift equation)
        /// - Lift requires water contact but does NOT scale with depth
        /// - Speed² is the primary driver of lift magnitude
        /// </summary>
        private void CalculateDisplacementLift()
        {
            _displacementLift = 0f;
            
            if (!_enableDisplacementLift) return;
            if (_advancedBuoyancy == null) return;
            
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < _displacementLiftMinSpeed) return;
            
            // Need to be in the water - but lift doesn't scale with depth
            float submersionRatio = _advancedBuoyancy.SubmergedRatio;
            if (submersionRatio < 0.05f) return; // Not touching water
            
            // Dynamic pressure: q = 0.5 × ρ × V²
            float q = 0.5f * PhysicsConstants.WATER_DENSITY * speed * speed;
            
            // Planform area (hull bottom surface)
            float planformArea = _hullConfig.Length * _hullConfig.Width * 0.8f;
            
            // Calculate lift: L = CL × q × A
            // CL is small at displacement speeds (0.05-0.15)
            _displacementLift = _displacementLiftCoefficient * q * planformArea;
            
            // Cap at a fraction of weight - displacement mode means buoyancy is primary
            float maxDisplacementLift = _hullConfig.TotalMass * PhysicsConstants.GRAVITY * 0.3f;
            _displacementLift = Mathf.Min(_displacementLift, maxDisplacementLift);
            
            // Fade out as planing takes over
            _displacementLift *= (1f - _planingRatio);
        }
        
        /// <summary>
        /// Calculate hydrodynamic lift from planing using Savitsky equations.
        /// 
        /// REAL PHYSICS - Savitsky Planing Theory:
        /// Lift = CL × 0.5ρV² × b² (b = beam width)
        /// CL = τ^1.1 × (0.012λ^0.5 + 0.0055λ^2.5/Cv²)
        /// 
        /// CRITICAL FIX (Session 23):
        /// - Board CANNOT plane when submerged > 50% - planing lift is disabled
        /// - Planing lift reduces progressively from 35% to 50% submersion
        /// - Combined with massive underwater drag, this forces the board to slow down
        ///   when it goes underwater, allowing buoyancy to bring it back up
        /// </summary>
        private void CalculatePlaningLift()
        {
            _planingLift = 0f;
            _heelEfficiency = 1f;
            
            if (!_enablePlaningLift || _planingRatio < 0.1f)
            {
                _smoothedPlaningLift = 0f;
                _currentHeelAngle = 0f;
                return;
            }
            
            float speed = _rigidbody.linearVelocity.magnitude;
            if (speed < 3f)
            {
                _smoothedPlaningLift *= 0.95f; // Decay smoothly
                _planingLift = _smoothedPlaningLift;
                return;
            }
            
            // Must be touching water - use 5% threshold (more realistic than 1%)
            float submersionRatio = _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio : 0f;
            if (submersionRatio < 0.05f)
            {
                _smoothedPlaningLift *= 0.9f; // Decay when barely in water
                _planingLift = _smoothedPlaningLift;
                return;
            }
            
            // ===== CRITICAL: CAN'T PLANE WHEN TOO SUBMERGED =====
            // If board is deeply submerged (>50%), it's underwater, NOT planing
            // Planing requires the hull to be riding ON the water surface
            // This prevents "submarine mode" where board goes underwater at speed
            if (submersionRatio > _maxPlaningSubmersion)
            {
                // Board is underwater - rapidly decay planing lift
                _smoothedPlaningLift *= 0.8f; // Quick decay
                _planingLift = _smoothedPlaningLift;
                _heelEfficiency = 0f;
                return;
            }
            
            // NOTE: We do NOT penalize lift based on submersion during normal planing
            // The board needs full lift to GET UP onto the plane in the first place
            // Only disable lift completely when truly underwater (above check)
            
            // ===== HEEL ANGLE CALCULATION =====
            // Get the roll angle (heel) - rotation around forward axis
            float heelAngle = transform.eulerAngles.z;
            if (heelAngle > 180f) heelAngle -= 360f;
            _currentHeelAngle = Mathf.Abs(heelAngle);
            
            // ===== TRIM ANGLE =====
            // Calculate trim in world frame to handle heeled conditions correctly
            float pitchAngle = transform.eulerAngles.x;
            if (pitchAngle > 180f) pitchAngle -= 360f;
            _currentTrimAngle = -pitchAngle;
            
            // Savitsky uses positive trim (bow up). Clamp to 1-10°
            float tau = Mathf.Clamp(_currentTrimAngle, 1f, 10f);
            
            // ===== HEEL EFFECT ON EFFECTIVE BEAM =====
            // When heeled, the effective planing beam is reduced: b_eff = b × cos(heel)
            // This reduces the planing area and thus lift
            float heelRad = _currentHeelAngle * Mathf.Deg2Rad;
            float effectiveBeamFactor = Mathf.Cos(heelRad);
            
            // Track heel efficiency for debugging
            _heelEfficiency = effectiveBeamFactor;
            
            // ===== SIMPLE PLANING LIFT MODEL =====
            // The Savitsky equations are too complex and produce insufficient lift
            // Use a simple speed-based model that achieves the correct result:
            // At full planing speed, lift should support 90%+ of the board's weight
            
            float g = PhysicsConstants.GRAVITY;
            float weight = _hullConfig.TotalMass * g;
            
            // Target lift at full planing: 95% of weight
            // This leaves ~5% for buoyancy (just the tail touching water)
            float targetLiftAtFullPlaning = weight * _maxLiftFraction;
            
            // Lift ramps up from planing onset to full planing
            // planingRatio is 0 at 4 m/s, 1 at 6 m/s
            float targetLift = targetLiftAtFullPlaning * _planingRatio;
            
            // Apply heel penalty - less effective planing when heeled
            // At 45° heel, reduce to 70% effectiveness
            targetLift *= Mathf.Max(effectiveBeamFactor, 0.7f);
            
            // Apply the coefficient for tuning
            targetLift *= _planingLiftCoefficient;
            
            // ===== CAP LIFT =====
            // Cap at maxLiftFraction of weight to prevent flying out
            float maxLift = weight * _maxLiftFraction;
            targetLift = Mathf.Min(targetLift, maxLift);
            
            // ===== SMOOTH LIFT CHANGES =====
            // Use constant smoothing - lift should be stable for given speed/trim
            _smoothedPlaningLift = Mathf.Lerp(_smoothedPlaningLift, targetLift, _liftSmoothingFactor);
            _planingLift = _smoothedPlaningLift;
        }
        
        /// <summary>
        /// Apply all hydrodynamic lift forces (displacement + planing).
        /// Both lift types ONLY apply when hull is in the water.
        /// 
        /// When heeled, the lift application point shifts laterally to the
        /// submerged side, which helps create a stabilizing righting moment.
        /// </summary>
        private void ApplyHydrodynamicLift()
        {
            // Check we're actually in the water
            float submersionRatio = _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio : 0.3f;
            if (submersionRatio < 0.05f)
            {
                return;
            }
            
            // NOTE: Vertical damping is handled by AdvancedBuoyancy, not here.
            // This prevents duplicate damping forces that cause instability.
            
            float totalLift = _displacementLift + _planingLift;
            if (totalLift < 1f) return;
            
            // Apply lift at center of mass to prevent pitching moments (porpoising)
            // Previously applied aft which caused nose-up moment and oscillation
            float liftPointZ = 0f; // Center of mass
            
            Vector3 liftPoint = transform.TransformPoint(new Vector3(0f, 0f, liftPointZ));
            
            // Lift acts upward (perpendicular to water surface)
            Vector3 liftForce = Vector3.up * totalLift;
            
            _rigidbody.AddForceAtPosition(liftForce, liftPoint, ForceMode.Force);
        }
        
        /// <summary>
        /// Apply resistance force to rigidbody.
        /// </summary>
        private void ApplyResistance()
        {
            if (_resistanceForce.sqrMagnitude < 0.01f) return;
            
            // Apply at center of lateral resistance (approximately mid-hull, slightly aft)
            Vector3 clrPosition = transform.TransformPoint(new Vector3(0, 0, -_hullConfig.Length * 0.1f));
            
            _rigidbody.AddForceAtPosition(_resistanceForce, clrPosition, ForceMode.Force);
            
            // Apply angular damping to resist rotation
            // CRITICAL: Increase damping at high speeds to prevent instability
            Vector3 angularVelocity = _rigidbody.angularVelocity;
            float speedKnots = _rigidbody.linearVelocity.magnitude * PhysicsConstants.MS_TO_KNOTS;
            
            if (angularVelocity.sqrMagnitude > 0.001f)
            {
                // Base damping - higher when not planing (displacement mode)
                float baseDampingCoeff = _isPlaning ? 0.8f : 1.5f;
                
                // HIGH-SPEED STABILITY: Dramatically increase damping above 15 knots
                // This prevents the violent oscillations at planing speeds
                float highSpeedFactor = 1f;
                if (speedKnots > 15f)
                {
                    // Ramps from 1.0 at 15kn to 4.0 at 30kn
                    highSpeedFactor = 1f + (speedKnots - 15f) / 5f;
                    highSpeedFactor = Mathf.Min(highSpeedFactor, 5f); // Cap at 5x
                }
                
                float dampingCoeff = baseDampingCoeff * highSpeedFactor;
                Vector3 angularDamping = -angularVelocity * dampingCoeff * _hullConfig.TotalMass * 0.1f;
                _rigidbody.AddTorque(angularDamping, ForceMode.Force);
            }
        }
        
        /// <summary>
        /// Get the current speed in knots.
        /// </summary>
        public float GetSpeedKnots()
        {
            return _rigidbody.linearVelocity.magnitude * PhysicsConstants.MS_TO_KNOTS;
        }
        
        /// <summary>
        /// Get the current speed in km/h.
        /// </summary>
        public float GetSpeedKmh()
        {
            return _rigidbody.linearVelocity.magnitude * 3.6f;
        }
        
        /// <summary>
        /// Get submersion ratio from buoyancy (0-1).
        /// </summary>
        public float GetSubmersionRatio()
        {
            return _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio : 0f;
        }

#if UNITY_EDITOR
        private void OnDrawGizmosSelected()
        {
            if (!_showDebug || !Application.isPlaying) return;
            
            Vector3 pos = transform.position;
            
            // Draw resistance force
            Gizmos.color = Color.red;
            Gizmos.DrawRay(pos, _resistanceForce * 0.005f);
            
            // Draw total lift
            float totalLift = _displacementLift + _planingLift;
            if (totalLift > 1f)
            {
                Gizmos.color = Color.cyan;
                Gizmos.DrawRay(pos, Vector3.up * totalLift * 0.001f);
            }
            
            // Draw velocity
            if (_rigidbody != null)
            {
                Gizmos.color = Color.green;
                Gizmos.DrawRay(pos, _rigidbody.linearVelocity);
            }
            
            // Labels
            float speedKmh = _rigidbody.linearVelocity.magnitude * 3.6f;
            float submersion = _advancedBuoyancy != null ? _advancedBuoyancy.SubmergedRatio * 100f : 0f;
            UnityEditor.Handles.Label(pos + Vector3.up * 1.5f,
                $"Speed: {speedKmh:F1} km/h ({GetSpeedKnots():F1} kts)\n" +
                $"Submerged: {submersion:F0}%\n" +
                $"Heel: {_currentHeelAngle:F1}° (eff: {_heelEfficiency * 100:F0}%)\n" +
                $"Resistance: {_totalResistance:F0} N\n" +
                $"Lift: {_displacementLift:F0} + {_planingLift:F0} = {totalLift:F0} N\n" +
                $"{(_isPlaning ? "PLANING" : "Displacement")} ({_planingRatio * 100:F0}%)");
        }
#endif
    }
}
