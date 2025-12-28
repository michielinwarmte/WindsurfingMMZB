using UnityEngine;
using UnityEditor;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Buoyancy;
using WindsurfingGame.Physics.Water;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Environment;
using WindsurfingGame.Player;
using WindsurfingGame.Visual;
using WindsurfingGame.CameraSystem;

namespace WindsurfingGame.Editor
{
    /// <summary>
    /// Complete editor utility to set up a Windsurfer from FBX models.
    /// Creates proper hierarchy and configures all ADVANCED physics components.
    /// 
    /// USAGE:
    /// 1. Menu: Windsurfing → Complete Windsurfer Setup Wizard
    /// 2. Drag your board.fbx and sail.fbx into the dialog
    /// 3. Click "Create Complete Scene" (for empty scene) or "Create Windsurfer" (if scene already has water/wind)
    /// 
    /// Components added:
    /// - Rigidbody (95kg total mass)
    /// - BoxCollider  
    /// - AdvancedBuoyancy (Archimedes multi-point buoyancy)
    /// - AdvancedSail (aerodynamic sail physics)
    /// - AdvancedFin (hydrodynamic fin physics)
    /// - AdvancedHullDrag (hull resistance with displacement/planing lift)
    /// - BoardMassConfiguration (mass, COM shift when planing)
    /// - AdvancedWindsurferController (realistic control)
    /// - EquipmentVisualizer (FBX model display)
    /// - ForceVectorVisualizer (debug arrows)
    /// </summary>
    public class WindsurferSetupWizard : EditorWindow
    {
        private GameObject _boardModel;
        private GameObject _sailModel;
        private Vector3 _mastBasePosition = new Vector3(0, 0.1f, -0.1f);
        private float _boardScale = 1f;
        private float _sailScale = 1f;
        private Vector3 _boardRotationOffset = new Vector3(0, 270, 0);
        private Vector3 _sailRotationOffset = new Vector3(0, 90, 0);
        private bool _useAdvancedPhysics = true;
        
        // Camera settings
        private float _cameraDistance = 12f;
        private float _cameraPitch = 25f;
        private float _cameraPositionSmooth = 0.15f;
        private float _cameraRotationSmooth = 0.1f;
        private Vector3 _cameraLookOffset = new Vector3(0, 1.5f, 3f);
        private bool _showCameraSettings = false;
        
        // Scene settings
        private float _windSpeed = 12f;
        private float _windDirection = 45f;
        private bool _showSceneSettings = false;
        
        // Scroll position for UI
        private Vector2 _scrollPosition;
        
        [MenuItem("Windsurfing/Complete Windsurfer Setup Wizard")]
        public static void ShowWindow()
        {
            var window = GetWindow<WindsurferSetupWizard>("Windsurfer Setup");
            window.minSize = new Vector2(400, 750);
            window.Show();
        }

        private void OnGUI()
        {
            _scrollPosition = EditorGUILayout.BeginScrollView(_scrollPosition);
            
            GUILayout.Label("🏄 Advanced Windsurfer Setup Wizard", EditorStyles.boldLabel);
            EditorGUILayout.Space(10);
            
            // Known issues warning box
            EditorGUILayout.HelpBox(
                "⚠️ KNOWN ISSUES (Dec 28, 2025):\n\n" +
                "1. CAMERA: Won't follow until you change FOV in Inspector during Play\n" +
                "2. PLANING: Board oscillates 0-100% submersion at speed\n" +
                "3. STEERING: A/D keys are inverted\n\n" +
                "See Documentation/KNOWN_ISSUES.md for details and fixes needed.", 
                MessageType.Warning);
            
            EditorGUILayout.Space(10);
            
            EditorGUILayout.HelpBox(
                "Creates a complete Windsurfing scene from scratch!\n\n" +
                "Use 'Create Complete Scene' for empty scenes - it creates:\n" +
                "• Water plane with physics\n" +
                "• Wind system\n" +
                "• Camera with follow behavior\n" +
                "• Lighting\n" +
                "• Windsurfer with all physics", 
                MessageType.Info);
            
            EditorGUILayout.Space(10);
            
            // Model references
            GUILayout.Label("3D Models", EditorStyles.boldLabel);
            _boardModel = (GameObject)EditorGUILayout.ObjectField("Board FBX/Prefab", _boardModel, typeof(GameObject), false);
            _sailModel = (GameObject)EditorGUILayout.ObjectField("Sail FBX/Prefab", _sailModel, typeof(GameObject), false);
            
            EditorGUILayout.Space(10);
            
            // Position settings
            GUILayout.Label("Positioning", EditorStyles.boldLabel);
            _mastBasePosition = EditorGUILayout.Vector3Field("Mast Base Position", _mastBasePosition);
            EditorGUILayout.HelpBox("Mast base is where the sail pivots on the board.\nDefault (0, 0.1, -0.05) = slightly forward of center, just above deck.", MessageType.None);
            
            EditorGUILayout.Space(5);
            
            // Scale settings
            GUILayout.Label("Scale Adjustments", EditorStyles.boldLabel);
            _boardScale = EditorGUILayout.FloatField("Board Scale", _boardScale);
            _sailScale = EditorGUILayout.FloatField("Sail Scale", _sailScale);
            
            EditorGUILayout.Space(5);
            
            // Rotation offsets
            GUILayout.Label("Rotation Offsets (if models aren't aligned)", EditorStyles.boldLabel);
            _boardRotationOffset = EditorGUILayout.Vector3Field("Board Rotation", _boardRotationOffset);
            _sailRotationOffset = EditorGUILayout.Vector3Field("Sail Rotation", _sailRotationOffset);
            
            EditorGUILayout.Space(10);
            
            // Scene settings (foldout)
            _showSceneSettings = EditorGUILayout.Foldout(_showSceneSettings, "🌊 Scene Settings (Wind & Water)", true);
            if (_showSceneSettings)
            {
                EditorGUI.indentLevel++;
                _windSpeed = EditorGUILayout.Slider("Wind Speed (knots)", _windSpeed, 5f, 30f);
                _windDirection = EditorGUILayout.Slider("Wind Direction (°)", _windDirection, 0f, 360f);
                EditorGUILayout.HelpBox("Wind direction: 0° = from North, 90° = from East", MessageType.None);
                EditorGUI.indentLevel--;
            }
            
            // Camera settings (foldout)
            _showCameraSettings = EditorGUILayout.Foldout(_showCameraSettings, "📷 Camera Settings", true);
            if (_showCameraSettings)
            {
                EditorGUI.indentLevel++;
                _cameraDistance = EditorGUILayout.Slider("Distance", _cameraDistance, 5f, 25f);
                _cameraPitch = EditorGUILayout.Slider("Pitch (Angle)", _cameraPitch, 10f, 60f);
                _cameraPositionSmooth = EditorGUILayout.Slider("Position Smoothing", _cameraPositionSmooth, 0.05f, 0.5f);
                _cameraRotationSmooth = EditorGUILayout.Slider("Rotation Smoothing", _cameraRotationSmooth, 0.05f, 0.5f);
                _cameraLookOffset = EditorGUILayout.Vector3Field("Look Offset", _cameraLookOffset);
                EditorGUILayout.HelpBox("Look Offset: Where camera looks relative to board.\n(0, 1.5, 3) = looks at sail area ahead of board.", MessageType.None);
                EditorGUI.indentLevel--;
            }
            
            EditorGUILayout.Space(20);
            
            // Main creation buttons
            bool canCreate = _boardModel != null && _sailModel != null;
            
            // Complete scene button (works even without existing scene elements)
            EditorGUI.BeginDisabledGroup(!canCreate);
            GUI.backgroundColor = new Color(0.4f, 0.8f, 0.4f);
            if (GUILayout.Button("🌟 Create Complete Scene", GUILayout.Height(50)))
            {
                CreateCompleteScene();
            }
            GUI.backgroundColor = Color.white;
            EditorGUILayout.HelpBox("Creates EVERYTHING: Water, Wind, Camera, Lighting, and Windsurfer.\nPerfect for starting from an empty scene!", MessageType.None);
            EditorGUI.EndDisabledGroup();
            
            EditorGUILayout.Space(10);
            
            // Just windsurfer button (requires existing scene elements)
            EditorGUI.BeginDisabledGroup(!canCreate);
            if (GUILayout.Button("Create Windsurfer Only", GUILayout.Height(35)))
            {
                CreateWindsurfer();
            }
            EditorGUI.EndDisabledGroup();
            
            if (!canCreate)
            {
                EditorGUILayout.HelpBox("Please assign both Board and Sail models.", MessageType.Warning);
            }
            
            EditorGUILayout.Space(20);
            
            // Quick actions
            GUILayout.Label("Quick Actions", EditorStyles.boldLabel);
            
            if (GUILayout.Button("Configure Camera for Selected Windsurfer"))
            {
                ConfigureCameraForSelected();
            }
            
            if (GUILayout.Button("Validate All Components"))
            {
                ValidateAllComponents();
            }
            
            EditorGUILayout.Space(10);
            
            if (GUILayout.Button("Disable Old WindsurfBoard"))
            {
                DisableOldBoard();
            }
            
            if (GUILayout.Button("Delete Old WindsurfBoard"))
            {
                DeleteOldBoard();
            }
            
            EditorGUILayout.EndScrollView();
        }

        /// <summary>
        /// Creates a complete scene from scratch: Water, Wind, Camera, Lighting, and Windsurfer.
        /// </summary>
        private void CreateCompleteScene()
        {
            // ==========================================
            // STEP 0: Create scene infrastructure
            // ==========================================
            WaterSurface waterSurface = EnsureWaterSurface();
            WindSystem windSystem = EnsureWindSystem();
            EnsureLighting();
            
            // ==========================================
            // STEP 1: Create the Windsurfer
            // ==========================================
            GameObject windsurfer = CreateWindsurferObject(waterSurface, windSystem);
            
            if (windsurfer == null)
            {
                EditorUtility.DisplayDialog("Error", "Failed to create Windsurfer!", "OK");
                return;
            }
            
            // ==========================================
            // STEP 2: Create and configure camera (AFTER windsurfer exists)
            // ==========================================
            SetupCamera(windsurfer.transform, waterSurface);
            
            // ==========================================
            // STEP 3: Create Telemetry HUD
            // ==========================================
            EnsureTelemetryHUD(windsurfer);
            
            // ==========================================
            // STEP 4: Disable any old boards
            // ==========================================
            DisableOldBoard();
            
            // ==========================================
            // STEP 5: Select the new windsurfer
            // ==========================================
            Selection.activeGameObject = windsurfer;
            
            Debug.Log("✅ COMPLETE SCENE CREATED!\n\n" +
                      "Scene elements:\n" +
                      "  ✓ WaterSurface (100m x 100m water plane)\n" +
                      "  ✓ WindSystem (" + _windSpeed + " knots from " + _windDirection + "°)\n" +
                      "  ✓ SimpleFollowCamera (press 1-4 for modes)\n" +
                      "  ✓ Directional Light (sun)\n" +
                      "  ✓ TelemetryHUD (press F1 to toggle)\n" +
                      "  ✓ Windsurfer with all physics\n\n" +
                      "⚠️ CAMERA WORKAROUND: Change FOV in Inspector during Play!\n" +
                      "⚠️ STEERING BUG: A/D keys are currently inverted\n\n" +
                      "Press PLAY to test!");
            
            EditorUtility.DisplayDialog("Success!", 
                "Complete scene created!\n\n" +
                "⚠️ CAMERA WORKAROUND:\n" +
                "Camera won't follow until you change the FOV\n" +
                "value in Inspector during Play mode.\n\n" +
                "⚠️ KNOWN BUG: Steering (A/D) is inverted!\n\n" +
                "Controls:\n" +
                "• A/D = Steer (inverted!)\n" +
                "• W/S = Sheet in/out\n" +
                "• Q/E = Fine rake\n" +
                "• F1 = Toggle HUD\n\n" +
                "Camera Modes: 1-4", "OK");
        }
        
        /// <summary>
        /// Sets up the camera directly with all properties.
        /// </summary>
        private void SetupCamera(Transform target, WaterSurface waterSurface)
        {
            // Find or create camera
            Camera mainCamera = Camera.main;
            if (mainCamera == null)
            {
                GameObject camGO = new GameObject("Main Camera");
                camGO.tag = "MainCamera";
                Undo.RegisterCreatedObjectUndo(camGO, "Create Camera");
                mainCamera = camGO.AddComponent<Camera>();
                camGO.AddComponent<AudioListener>();
            }
            
            // Remove any old camera scripts first (might be broken)
            var oldCam = mainCamera.GetComponent<ThirdPersonCamera>();
            if (oldCam != null)
            {
                Undo.DestroyObjectImmediate(oldCam);
            }
            var oldSimpleCam = mainCamera.GetComponent<SimpleFollowCamera>();
            if (oldSimpleCam != null)
            {
                Undo.DestroyObjectImmediate(oldSimpleCam);
            }
            
            // Add SimpleFollowCamera (more reliable, multiple modes)
            SimpleFollowCamera simpleCam = Undo.AddComponent<SimpleFollowCamera>(mainCamera.gameObject);
            
            // Configure directly via SerializedObject
            SerializedObject camSO = new SerializedObject(simpleCam);
            
            // Set all properties
            camSO.FindProperty("_target").objectReferenceValue = target;
            camSO.FindProperty("_distance").floatValue = _cameraDistance;
            camSO.FindProperty("_height").floatValue = 5f;
            camSO.FindProperty("_smoothSpeed").floatValue = 5f;
            camSO.FindProperty("_mode").enumValueIndex = 0; // FixedFollow mode
            
            camSO.ApplyModifiedProperties();
            EditorUtility.SetDirty(simpleCam);
            
            // Position camera initially
            mainCamera.transform.position = target.position + new Vector3(0, 5, -_cameraDistance);
            mainCamera.transform.LookAt(target.position + Vector3.up);
            
            Debug.Log($"✓ SimpleFollowCamera configured: Distance={_cameraDistance}m, Target={target.name}\n" +
                     $"   Press 1-4 to switch camera modes!");
        }
        
        /// <summary>
        /// Ensures a TelemetryHUD exists in the scene.
        /// </summary>
        private void EnsureTelemetryHUD(GameObject windsurfer)
        {
            // Check if already exists
            var existingHUD = FindFirstObjectByType<UI.AdvancedTelemetryHUD>();
            if (existingHUD != null)
            {
                Debug.Log("✓ Using existing TelemetryHUD");
                return;
            }
            
            // Create HUD GameObject
            GameObject hudGO = new GameObject("TelemetryHUD");
            Undo.RegisterCreatedObjectUndo(hudGO, "Create TelemetryHUD");
            
            UI.AdvancedTelemetryHUD hud = hudGO.AddComponent<UI.AdvancedTelemetryHUD>();
            
            // Configure HUD references
            SerializedObject hudSO = new SerializedObject(hud);
            
            var controller = windsurfer.GetComponent<AdvancedWindsurferController>();
            var sail = windsurfer.GetComponent<AdvancedSail>();
            var fin = windsurfer.GetComponent<AdvancedFin>();
            var hull = windsurfer.GetComponent<AdvancedHullDrag>();
            var buoyancy = windsurfer.GetComponent<AdvancedBuoyancy>();
            var rb = windsurfer.GetComponent<Rigidbody>();
            
            if (controller != null) hudSO.FindProperty("_controller").objectReferenceValue = controller;
            if (sail != null) hudSO.FindProperty("_sail").objectReferenceValue = sail;
            if (fin != null) hudSO.FindProperty("_fin").objectReferenceValue = fin;
            if (hull != null) hudSO.FindProperty("_hull").objectReferenceValue = hull;
            if (buoyancy != null) hudSO.FindProperty("_buoyancy").objectReferenceValue = buoyancy;
            if (rb != null) hudSO.FindProperty("_boardRigidbody").objectReferenceValue = rb;
            
            hudSO.FindProperty("_showDetailed").boolValue = true;
            hudSO.FindProperty("_fontSize").intValue = 12;
            hudSO.ApplyModifiedProperties();
            
            Debug.Log("✓ Created TelemetryHUD");
        }

        /// <summary>
        /// Ensures a WaterSurface exists in the scene, creates one if not.
        /// </summary>
        private WaterSurface EnsureWaterSurface()
        {
            WaterSurface waterSurface = FindFirstObjectByType<WaterSurface>();
            if (waterSurface != null)
            {
                Debug.Log("✓ Using existing WaterSurface");
                // Make sure material is applied
                EnsureWaterMaterial(waterSurface.gameObject);
                return waterSurface;
            }
            
            // Create water plane
            GameObject waterGO = GameObject.CreatePrimitive(PrimitiveType.Plane);
            waterGO.name = "Water";
            waterGO.transform.position = Vector3.zero;
            waterGO.transform.localScale = new Vector3(10f, 1f, 10f); // 100m x 100m
            Undo.RegisterCreatedObjectUndo(waterGO, "Create Water");
            
            // Remove default collider (WaterSurface handles physics)
            var meshCollider = waterGO.GetComponent<MeshCollider>();
            if (meshCollider != null)
                Object.DestroyImmediate(meshCollider);
            
            // Add WaterSurface component
            waterSurface = waterGO.AddComponent<WaterSurface>();
            
            // Apply water material
            EnsureWaterMaterial(waterGO);
            
            Debug.Log("✓ Created WaterSurface (100m x 100m)");
            return waterSurface;
        }
        
        /// <summary>
        /// Ensures the water object has a proper material assigned.
        /// </summary>
        private void EnsureWaterMaterial(GameObject waterGO)
        {
            var renderer = waterGO.GetComponent<MeshRenderer>();
            if (renderer == null) return;
            
            // Try to find existing water materials - check multiple paths
            string[] materialPaths = new string[]
            {
                "Assets/Materials/WaterMaterial.mat",
                "Assets/Materials/Water.mat",
                "Assets/Materials/StylizedWater.mat",
                "Assets/Materials/Ocean.mat"
            };
            
            Material waterMat = null;
            foreach (var path in materialPaths)
            {
                waterMat = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (waterMat != null)
                {
                    Debug.Log($"✓ Found water material: {path}");
                    break;
                }
            }
            
            // Also search by GUID pattern
            if (waterMat == null)
            {
                var guids = AssetDatabase.FindAssets("Water t:Material");
                foreach (var guid in guids)
                {
                    var path = AssetDatabase.GUIDToAssetPath(guid);
                    waterMat = AssetDatabase.LoadAssetAtPath<Material>(path);
                    if (waterMat != null)
                    {
                        Debug.Log($"✓ Found water material by search: {path}");
                        break;
                    }
                }
            }
            
            if (waterMat != null)
            {
                renderer.sharedMaterial = waterMat;
                EditorUtility.SetDirty(renderer);
            }
            else
            {
                // Create a new water material with the stylized shader
                var shader = Shader.Find("Custom/StylizedWater");
                if (shader == null)
                    shader = Shader.Find("Universal Render Pipeline/Lit");
                    
                Material newMat = new Material(shader);
                newMat.name = "WaterMaterial";
                
                // Set some good defaults if using URP/Lit
                if (shader.name.Contains("Lit"))
                {
                    newMat.color = new Color(0.1f, 0.4f, 0.7f, 0.9f);
                    newMat.SetFloat("_Surface", 1); // Transparent
                    newMat.SetFloat("_Smoothness", 0.95f);
                }
                
                // Save the material
                string matPath = "Assets/Materials/WaterMaterial.mat";
                AssetDatabase.CreateAsset(newMat, matPath);
                AssetDatabase.SaveAssets();
                
                renderer.sharedMaterial = newMat;
                Debug.Log($"✓ Created new water material: {matPath}");
            }
        }
        
        /// <summary>
        /// Ensures a WindSystem exists in the scene, creates one if not.
        /// </summary>
        private WindSystem EnsureWindSystem()
        {
            WindSystem windSystem = FindFirstObjectByType<WindSystem>();
            if (windSystem != null)
            {
                Debug.Log("✓ Using existing WindSystem");
                return windSystem;
            }
            
            // Check for legacy WindManager
            var legacyWind = FindFirstObjectByType<Physics.Wind.WindManager>();
            if (legacyWind != null)
            {
                Debug.Log("✓ Using existing WindManager (legacy)");
                // Create WindSystem alongside legacy for compatibility
            }
            
            // Create WindSystem
            GameObject windGO = new GameObject("WindSystem");
            Undo.RegisterCreatedObjectUndo(windGO, "Create WindSystem");
            
            windSystem = windGO.AddComponent<WindSystem>();
            
            // Configure wind
            SerializedObject windSO = new SerializedObject(windSystem);
            var baseSpeedProp = windSO.FindProperty("_baseWindSpeed");
            if (baseSpeedProp != null)
                baseSpeedProp.floatValue = _windSpeed * 0.514444f; // Convert knots to m/s
            
            var directionProp = windSO.FindProperty("_baseWindDirection");
            if (directionProp != null)
                directionProp.floatValue = _windDirection;
            
            windSO.ApplyModifiedProperties();
            
            Debug.Log($"✓ Created WindSystem ({_windSpeed} knots from {_windDirection}°)");
            return windSystem;
        }
        
        /// <summary>
        /// Ensures a properly configured camera exists, creates one if not.
        /// </summary>
        private Camera EnsureCamera()
        {
            // Check for existing ThirdPersonCamera
            var existingCam = FindFirstObjectByType<ThirdPersonCamera>();
            if (existingCam != null)
            {
                Debug.Log("✓ Using existing ThirdPersonCamera");
                return existingCam.GetComponent<Camera>();
            }
            
            // Check for Main Camera
            Camera mainCamera = Camera.main;
            if (mainCamera == null)
            {
                // Create camera
                GameObject camGO = new GameObject("Main Camera");
                camGO.tag = "MainCamera";
                Undo.RegisterCreatedObjectUndo(camGO, "Create Camera");
                
                mainCamera = camGO.AddComponent<Camera>();
                camGO.AddComponent<AudioListener>();
            }
            
            // Add ThirdPersonCamera if not present
            if (mainCamera.GetComponent<ThirdPersonCamera>() == null)
            {
                mainCamera.gameObject.AddComponent<ThirdPersonCamera>();
            }
            
            // Position camera initially
            mainCamera.transform.position = new Vector3(0, 5, -15);
            mainCamera.transform.LookAt(Vector3.zero);
            
            Debug.Log("✓ Camera configured with ThirdPersonCamera");
            return mainCamera;
        }
        
        /// <summary>
        /// Ensures proper lighting exists in the scene.
        /// </summary>
        private void EnsureLighting()
        {
            // Check for directional light
            Light[] lights = FindObjectsByType<Light>(FindObjectsSortMode.None);
            bool hasDirectional = false;
            foreach (var light in lights)
            {
                if (light.type == LightType.Directional)
                {
                    hasDirectional = true;
                    break;
                }
            }
            
            if (!hasDirectional)
            {
                GameObject lightGO = new GameObject("Directional Light");
                Undo.RegisterCreatedObjectUndo(lightGO, "Create Light");
                
                Light light = lightGO.AddComponent<Light>();
                light.type = LightType.Directional;
                light.intensity = 1f;
                light.color = new Color(1f, 0.95f, 0.85f); // Warm sunlight
                light.shadows = LightShadows.Soft;
                
                lightGO.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
                
                Debug.Log("✓ Created Directional Light");
            }
            else
            {
                Debug.Log("✓ Using existing lighting");
            }
        }

        private void CreateWindsurfer()
        {
            // Find scene references
            WaterSurface waterSurface = FindFirstObjectByType<WaterSurface>();
            if (waterSurface == null)
            {
                if (EditorUtility.DisplayDialog("No Water Found", 
                    "No WaterSurface found in scene.\n\nWould you like to create a complete scene instead?", 
                    "Create Complete Scene", "Cancel"))
                {
                    CreateCompleteScene();
                }
                return;
            }
            
            WindSystem windSystem = FindFirstObjectByType<WindSystem>();
            if (windSystem == null)
            {
                // Check for legacy WindManager
                var legacyWind = FindFirstObjectByType<Physics.Wind.WindManager>();
                if (legacyWind == null)
                {
                    if (EditorUtility.DisplayDialog("No Wind Found", 
                        "No WindSystem found in scene.\n\nWould you like to create a complete scene instead?", 
                        "Create Complete Scene", "Cancel"))
                    {
                        CreateCompleteScene();
                    }
                    return;
                }
            }
            
            GameObject windsurfer = CreateWindsurferObject(waterSurface, windSystem);
            if (windsurfer != null)
            {
                Selection.activeGameObject = windsurfer;
                ConfigureCameraForTarget(windsurfer.transform, waterSurface);
                DisableOldBoard();
                
                EditorUtility.DisplayDialog("Success!", 
                    "Windsurfer created!\n\nPress Play to test.\n\n" +
                    "Controls:\n• A/D = Steer\n• Q/E = Rake\n• W/S = Sheet\n• Tab = Cycle mode", "OK");
            }
        }
        
        /// <summary>
        /// Creates the windsurfer GameObject with all components.
        /// </summary>
        private GameObject CreateWindsurferObject(WaterSurface waterSurface, WindSystem windSystem)
        {
            // Create root GameObject
            GameObject windsurfer = new GameObject("Windsurfer");
            Undo.RegisterCreatedObjectUndo(windsurfer, "Create Windsurfer");
            
            // Position above water
            windsurfer.transform.position = new Vector3(0, 0.5f, 0);
            
            // ==========================================
            // STEP 1: Add Rigidbody (MUST BE FIRST)
            // ==========================================
            Rigidbody rb = windsurfer.AddComponent<Rigidbody>();
            rb.mass = 91f;  // Board (8kg) + Rig (8kg) + Sailor (75kg) = 91kg
            rb.linearDamping = 0f;            // Hull drag handles this
            rb.angularDamping = 0.3f;         // Minimal angular damping
            rb.interpolation = RigidbodyInterpolation.Interpolate;
            rb.useGravity = true;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            
            // ==========================================
            // STEP 2: Add Collider for physics
            // ==========================================
            BoxCollider collider = windsurfer.AddComponent<BoxCollider>();
            collider.size = new Vector3(0.6f, 0.12f, 2.5f);  // Board dimensions
            collider.center = new Vector3(0, 0, 0);
            
            // ==========================================
            // STEP 3: Add AdvancedBuoyancy (multi-point flotation)
            // ==========================================
            AdvancedBuoyancy buoyancy = windsurfer.AddComponent<AdvancedBuoyancy>();
            SerializedObject buoyancySO = new SerializedObject(buoyancy);
            buoyancySO.FindProperty("_waterSurface").objectReferenceValue = waterSurface;
            buoyancySO.FindProperty("_boardVolumeLiters").floatValue = 120f;  // 120 liters
            buoyancySO.FindProperty("_boardLength").floatValue = 2.5f;
            buoyancySO.FindProperty("_boardWidth").floatValue = 0.6f;
            buoyancySO.FindProperty("_boardThickness").floatValue = 0.12f;
            buoyancySO.FindProperty("_noseRocker").floatValue = 0.08f;
            buoyancySO.FindProperty("_tailRocker").floatValue = 0.02f;
            buoyancySO.FindProperty("_lengthSamples").intValue = 7;
            buoyancySO.FindProperty("_widthSamples").intValue = 3;
            buoyancySO.FindProperty("_verticalDamping").floatValue = 800f;
            buoyancySO.FindProperty("_rotationalDamping").floatValue = 150f;
            buoyancySO.FindProperty("_horizontalDamping").floatValue = 20f;
            buoyancySO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 4: Add AdvancedSail (aerodynamic propulsion)
            // ==========================================
            AdvancedSail sail = windsurfer.AddComponent<AdvancedSail>();
            SerializedObject sailSO = new SerializedObject(sail);
            // Configure sail via _sailConfig
            var sailConfigProp = sailSO.FindProperty("_sailConfig");
            sailConfigProp.FindPropertyRelative("Area").floatValue = 6.5f;
            sailConfigProp.FindPropertyRelative("LuffLength").floatValue = 4.7f;
            sailConfigProp.FindPropertyRelative("BoomLength").floatValue = 2.0f;
            sailConfigProp.FindPropertyRelative("MastHeight").floatValue = 4.6f;
            sailConfigProp.FindPropertyRelative("Camber").floatValue = 0.10f;
            sailConfigProp.FindPropertyRelative("MastFootPosition").vector3Value = _mastBasePosition;
            sailConfigProp.FindPropertyRelative("BoomHeight").floatValue = 1.4f;
            sailSO.FindProperty("_maxRakeAngle").floatValue = 15f;
            if (windSystem != null)
            {
                sailSO.FindProperty("_windSystem").objectReferenceValue = windSystem;
            }
            sailSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 5: Add AdvancedFin (hydrodynamic lateral resistance)
            // ==========================================
            AdvancedFin fin = windsurfer.AddComponent<AdvancedFin>();
            SerializedObject finSO = new SerializedObject(fin);
            var finConfigProp = finSO.FindProperty("_finConfig");
            finConfigProp.FindPropertyRelative("Area").floatValue = 0.035f;
            finConfigProp.FindPropertyRelative("Depth").floatValue = 0.40f;
            finConfigProp.FindPropertyRelative("Chord").floatValue = 0.10f;
            finConfigProp.FindPropertyRelative("Position").vector3Value = new Vector3(0, -0.1f, -0.9f);
            finConfigProp.FindPropertyRelative("StallAngle").floatValue = 14f;
            finSO.FindProperty("_enableTracking").boolValue = true;
            finSO.FindProperty("_trackingStrength").floatValue = 15f;
            finSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 6: Add AdvancedHullDrag (displacement/planing resistance)
            // ==========================================
            AdvancedHullDrag hull = windsurfer.AddComponent<AdvancedHullDrag>();
            SerializedObject hullSO = new SerializedObject(hull);
            var hullConfigProp = hullSO.FindProperty("_hullConfig");
            hullConfigProp.FindPropertyRelative("Length").floatValue = 2.5f;
            hullConfigProp.FindPropertyRelative("Width").floatValue = 0.6f;
            hullConfigProp.FindPropertyRelative("Thickness").floatValue = 0.12f;
            hullConfigProp.FindPropertyRelative("Volume").floatValue = 120f;
            hullConfigProp.FindPropertyRelative("BoardMass").floatValue = 8f;
            hullConfigProp.FindPropertyRelative("RigMass").floatValue = 8f;
            hullConfigProp.FindPropertyRelative("SailorMass").floatValue = 75f;
            hullSO.FindProperty("_advancedBuoyancy").objectReferenceValue = buoyancy;
            hullSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 7: Add BoardMassConfiguration (mass and inertia)
            // ==========================================
            BoardMassConfiguration massConfig = windsurfer.AddComponent<BoardMassConfiguration>();
            SerializedObject massSO = new SerializedObject(massConfig);
            massSO.FindProperty("_totalMass").floatValue = 95f;
            massSO.FindProperty("_boardMass").floatValue = 8f;
            massSO.FindProperty("_rigMass").floatValue = 6f;
            massSO.FindProperty("_sailorMass").floatValue = 80f;
            massSO.FindProperty("_boardLength").floatValue = 2.4f;
            massSO.FindProperty("_boardWidth").floatValue = 0.6f;
            massSO.FindProperty("_boardThickness").floatValue = 0.12f;
            massSO.FindProperty("_useCustomInertia").boolValue = false;
            massSO.FindProperty("_dynamicCOM").boolValue = true;
            massSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 8: Add AdvancedWindsurferController (realistic control)
            // ==========================================
            AdvancedWindsurferController controller = windsurfer.AddComponent<AdvancedWindsurferController>();
            SerializedObject ctrlSO = new SerializedObject(controller);
            ctrlSO.FindProperty("_sail").objectReferenceValue = sail;
            ctrlSO.FindProperty("_fin").objectReferenceValue = fin;
            ctrlSO.FindProperty("_hull").objectReferenceValue = hull;
            ctrlSO.FindProperty("_rigidbody").objectReferenceValue = rb;
            ctrlSO.FindProperty("_antiCapsize").boolValue = true;
            ctrlSO.FindProperty("_autoCenterRake").boolValue = true;
            ctrlSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 9: Add EquipmentVisualizer (FBX models)
            // ==========================================
            EquipmentVisualizer equipVis = windsurfer.AddComponent<EquipmentVisualizer>();
            SerializedObject equipSO = new SerializedObject(equipVis);
            equipSO.FindProperty("_boardPrefab").objectReferenceValue = _boardModel;
            equipSO.FindProperty("_sailPrefab").objectReferenceValue = _sailModel;
            equipSO.FindProperty("_advancedSail").objectReferenceValue = sail;
            equipSO.FindProperty("_mastBasePosition").vector3Value = _mastBasePosition;
            equipSO.FindProperty("_boardScale").floatValue = _boardScale;
            equipSO.FindProperty("_sailScale").floatValue = _sailScale;
            equipSO.FindProperty("_boardRotationOffset").vector3Value = _boardRotationOffset;
            equipSO.FindProperty("_sailRotationOffset").vector3Value = _sailRotationOffset;
            equipSO.FindProperty("_sailAngleOffset").floatValue = 0f;
            equipSO.FindProperty("_invertSailRotation").boolValue = true; // Invert so sail rotates away from wind
            equipSO.FindProperty("_maxRakeAngle").floatValue = 15f;
            equipSO.FindProperty("_smoothSpeed").floatValue = 8f;
            equipSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 10: Add ForceVectorVisualizer (debug arrows)
            // ==========================================
            ForceVectorVisualizer forceVis = windsurfer.AddComponent<ForceVectorVisualizer>();
            SerializedObject forceVisSO = new SerializedObject(forceVis);
            forceVisSO.FindProperty("_sail").objectReferenceValue = sail;
            forceVisSO.FindProperty("_fin").objectReferenceValue = fin;
            forceVisSO.FindProperty("_rigidbody").objectReferenceValue = rb;
            forceVisSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 11: Add WindDirectionIndicator to scene (if not exists)
            // ==========================================
            if (FindFirstObjectByType<WindDirectionIndicator>() == null)
            {
                GameObject windIndicator = new GameObject("WindDirectionIndicator");
                WindDirectionIndicator windInd = windIndicator.AddComponent<WindDirectionIndicator>();
                Undo.RegisterCreatedObjectUndo(windIndicator, "Create WindDirectionIndicator");
            }
            
            Debug.Log("✅ WINDSURFER CREATED!\n\n" +
                      "Components added:\n" +
                      "  ✓ Rigidbody (95kg total mass)\n" +
                      "  ✓ BoxCollider (2.5m x 0.6m x 0.12m)\n" +
                      "  ✓ AdvancedBuoyancy (21-point Archimedes flotation)\n" +
                      "  ✓ AdvancedSail (6.5m² area, aerodynamic model)\n" +
                      "  ✓ AdvancedFin (40cm depth, hydrodynamic model)\n" +
                      "  ✓ AdvancedHullDrag (displacement/planing lift)\n" +
                      "  ✓ BoardMassConfiguration (mass & COM shift)\n" +
                      "  ✓ AdvancedWindsurferController\n" +
                      "  ✓ EquipmentVisualizer (with your models)\n" +
                      "  ✓ ForceVectorVisualizer (debug arrows)\n" +
                      "  ✓ WindDirectionIndicator (water arrows)");
            
            return windsurfer;
        }

        /// <summary>
        /// Configure camera with all settings for a target transform.
        /// Uses the new SetupCamera approach - removes and re-adds camera component for clean setup.
        /// </summary>
        private void ConfigureCameraForTarget(Transform target, WaterSurface waterSurface)
        {
            if (target == null)
            {
                Debug.LogWarning("⚠️ Cannot configure camera: No target provided!");
                return;
            }

            // Use the new SetupCamera method which creates a fresh ThirdPersonCamera
            SetupCamera(target, waterSurface);
        }
        
        /// <summary>
        /// Configure camera for the currently selected windsurfer.
        /// </summary>
        private void ConfigureCameraForSelected()
        {
            GameObject selected = Selection.activeGameObject;
            
            // If nothing selected, try to find a windsurfer in the scene
            if (selected == null)
            {
                // Try to find an existing windsurfer
                var advSail = FindFirstObjectByType<AdvancedSail>();
                if (advSail != null)
                {
                    selected = advSail.gameObject;
                    Selection.activeGameObject = selected;
                    Debug.Log($"✓ Auto-selected windsurfer: {selected.name}");
                }
                else
                {
                    // No windsurfer exists - offer to create complete scene
                    bool canCreate = _boardModel != null && _sailModel != null;
                    if (canCreate)
                    {
                        if (EditorUtility.DisplayDialog("No Windsurfer Found", 
                            "No windsurfer found in scene.\n\nWould you like to create a complete scene with windsurfer?", 
                            "Create Complete Scene", "Cancel"))
                        {
                            CreateCompleteScene();
                        }
                    }
                    else
                    {
                        EditorUtility.DisplayDialog("No Windsurfer Found", 
                            "No windsurfer found in scene.\n\nPlease assign Board and Sail models first, then use 'Create Complete Scene'.", "OK");
                    }
                    return;
                }
            }
            
            WaterSurface waterSurface = FindFirstObjectByType<WaterSurface>();
            ConfigureCameraForTarget(selected.transform, waterSurface);
        }
        
        /// <summary>
        /// Validates all windsurfing components in the scene are properly configured.
        /// </summary>
        private void ValidateAllComponents()
        {
            System.Text.StringBuilder report = new System.Text.StringBuilder();
            report.AppendLine("🔍 COMPONENT VALIDATION REPORT\n");
            
            int errors = 0;
            int warnings = 0;
            
            // Check for WindSystem
            WindSystem windSystem = FindFirstObjectByType<WindSystem>();
            if (windSystem == null)
            {
                report.AppendLine("❌ ERROR: No WindSystem found!");
                errors++;
            }
            else
            {
                report.AppendLine("✅ WindSystem found");
            }
            
            // Check for WaterSurface
            WaterSurface waterSurface = FindFirstObjectByType<WaterSurface>();
            if (waterSurface == null)
            {
                report.AppendLine("❌ ERROR: No WaterSurface found!");
                errors++;
            }
            else
            {
                report.AppendLine("✅ WaterSurface found");
            }
            
            // Check for ThirdPersonCamera
            bool cameraFound = false;
            var cameras = FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None);
            foreach (var cam in cameras)
            {
                if (cam.GetType().Name == "ThirdPersonCamera")
                {
                    cameraFound = true;
                    SerializedObject camSO = new SerializedObject(cam);
                    var targetProp = camSO.FindProperty("_target");
                    if (targetProp == null || targetProp.objectReferenceValue == null)
                    {
                        report.AppendLine("⚠️ WARNING: ThirdPersonCamera has no target!");
                        warnings++;
                    }
                    else
                    {
                        report.AppendLine($"✅ ThirdPersonCamera targeting '{((Transform)targetProp.objectReferenceValue).name}'");
                    }
                    break;
                }
            }
            if (!cameraFound)
            {
                report.AppendLine("❌ ERROR: No ThirdPersonCamera found!");
                errors++;
            }
            
            // Check AdvancedSail components
            var sails = FindObjectsByType<AdvancedSail>(FindObjectsSortMode.None);
            if (sails.Length == 0)
            {
                report.AppendLine("⚠️ WARNING: No AdvancedSail found");
                warnings++;
            }
            else
            {
                foreach (var sail in sails)
                {
                    SerializedObject sailSO = new SerializedObject(sail);
                    var windSysProp = sailSO.FindProperty("_windSystem");
                    if (windSysProp == null || windSysProp.objectReferenceValue == null)
                    {
                        if (windSystem != null)
                        {
                            report.AppendLine($"🔧 AUTO-FIX: Linking WindSystem to {sail.gameObject.name}");
                            windSysProp.objectReferenceValue = windSystem;
                            sailSO.ApplyModifiedProperties();
                        }
                        else
                        {
                            report.AppendLine($"⚠️ WARNING: {sail.gameObject.name} AdvancedSail has no WindSystem!");
                            warnings++;
                        }
                    }
                    else
                    {
                        report.AppendLine($"✅ AdvancedSail on '{sail.gameObject.name}' configured");
                    }
                }
            }
            
            // Check AdvancedBuoyancy components
            var buoyancies = FindObjectsByType<AdvancedBuoyancy>(FindObjectsSortMode.None);
            foreach (var buoy in buoyancies)
            {
                SerializedObject buoySO = new SerializedObject(buoy);
                var waterProp = buoySO.FindProperty("_waterSurface");
                if (waterProp == null || waterProp.objectReferenceValue == null)
                {
                    if (waterSurface != null)
                    {
                        report.AppendLine($"🔧 AUTO-FIX: Linking WaterSurface to {buoy.gameObject.name}");
                        waterProp.objectReferenceValue = waterSurface;
                        buoySO.ApplyModifiedProperties();
                    }
                    else
                    {
                        report.AppendLine($"⚠️ WARNING: {buoy.gameObject.name} AdvancedBuoyancy has no WaterSurface!");
                        warnings++;
                    }
                }
                else
                {
                    report.AppendLine($"✅ AdvancedBuoyancy on '{buoy.gameObject.name}' configured");
                }
            }
            
            // Check EquipmentVisualizer components
            var visualizers = FindObjectsByType<EquipmentVisualizer>(FindObjectsSortMode.None);
            foreach (var vis in visualizers)
            {
                SerializedObject visSO = new SerializedObject(vis);
                var sailProp = visSO.FindProperty("_advancedSail");
                var boardProp = visSO.FindProperty("_boardPrefab");
                var sailPrefabProp = visSO.FindProperty("_sailPrefab");
                
                if ((sailProp == null || sailProp.objectReferenceValue == null))
                {
                    // Try to find and link AdvancedSail on same object
                    var localSail = vis.GetComponent<AdvancedSail>();
                    if (localSail != null)
                    {
                        report.AppendLine($"🔧 AUTO-FIX: Linking AdvancedSail to EquipmentVisualizer on {vis.gameObject.name}");
                        sailProp.objectReferenceValue = localSail;
                        visSO.ApplyModifiedProperties();
                    }
                    else
                    {
                        report.AppendLine($"⚠️ WARNING: {vis.gameObject.name} EquipmentVisualizer has no AdvancedSail reference!");
                        warnings++;
                    }
                }
                
                if (boardProp == null || boardProp.objectReferenceValue == null)
                {
                    report.AppendLine($"⚠️ WARNING: {vis.gameObject.name} EquipmentVisualizer has no Board model!");
                    warnings++;
                }
                
                if (sailPrefabProp == null || sailPrefabProp.objectReferenceValue == null)
                {
                    report.AppendLine($"⚠️ WARNING: {vis.gameObject.name} EquipmentVisualizer has no Sail model!");
                    warnings++;
                }
            }
            
            // Summary
            report.AppendLine($"\n=============================");
            report.AppendLine($"SUMMARY: {errors} errors, {warnings} warnings");
            if (errors == 0 && warnings == 0)
            {
                report.AppendLine("🎉 All components properly configured!");
            }
            else if (errors == 0)
            {
                report.AppendLine("✅ No critical errors. Review warnings above.");
            }
            else
            {
                report.AppendLine("❌ Fix errors before playing!");
            }
            
            Debug.Log(report.ToString());
            EditorUtility.DisplayDialog("Validation Complete", 
                $"Found {errors} errors, {warnings} warnings.\n\nCheck Console for details.", "OK");
        }

        private static void DisableOldBoard()
        {
            GameObject oldBoard = GameObject.Find("WindsurfBoard");
            if (oldBoard != null)
            {
                Undo.RecordObject(oldBoard, "Disable Old WindsurfBoard");
                oldBoard.SetActive(false);
                Debug.Log("✅ Disabled old WindsurfBoard");
            }
        }
        
        private static void DeleteOldBoard()
        {
            GameObject oldBoard = GameObject.Find("WindsurfBoard");
            if (oldBoard != null)
            {
                if (EditorUtility.DisplayDialog("Delete WindsurfBoard?", 
                    "Are you sure you want to delete the old WindsurfBoard?", "Delete", "Cancel"))
                {
                    Undo.DestroyObjectImmediate(oldBoard);
                    Debug.Log("✅ Deleted old WindsurfBoard");
                }
            }
            else
            {
                EditorUtility.DisplayDialog("Not Found", 
                    "No 'WindsurfBoard' found in scene.", "OK");
            }
        }
    }
    
    /// <summary>
    /// Quick menu items for common actions
    /// </summary>
    public static class WindsurferQuickActions
    {
        [MenuItem("Windsurfing/Quick: Add Components to Selected")]
        public static void QuickAddComponents()
        {
            GameObject selected = Selection.activeGameObject;
            if (selected == null)
            {
                EditorUtility.DisplayDialog("No Selection", 
                    "Please select a GameObject first.", "OK");
                return;
            }

            WaterSurface waterSurface = Object.FindFirstObjectByType<WaterSurface>();

            Undo.RegisterCompleteObjectUndo(selected, "Add Windsurfer Components");

            // Add components in correct order
            if (!selected.GetComponent<Rigidbody>())
            {
                var rb = Undo.AddComponent<Rigidbody>(selected);
                rb.mass = 50f;
                rb.angularDamping = 0.5f;
                rb.interpolation = RigidbodyInterpolation.Interpolate;
            }
            
            if (!selected.GetComponent<BoxCollider>())
            {
                var col = Undo.AddComponent<BoxCollider>(selected);
                col.size = new Vector3(0.6f, 0.15f, 2.5f);
            }
            
            if (!selected.GetComponent<BuoyancyBody>())
            {
                var buoy = Undo.AddComponent<BuoyancyBody>(selected);
                if (waterSurface != null)
                {
                    var so = new SerializedObject(buoy);
                    so.FindProperty("_waterSurface").objectReferenceValue = waterSurface;
                    so.ApplyModifiedProperties();
                }
            }
            
            if (!selected.GetComponent<ApparentWindCalculator>())
                Undo.AddComponent<ApparentWindCalculator>(selected);
            
            if (!selected.GetComponent<Sail>())
                Undo.AddComponent<Sail>(selected);
            
            if (!selected.GetComponent<WaterDrag>())
                Undo.AddComponent<WaterDrag>(selected);
            
            if (!selected.GetComponent<FinPhysics>())
                Undo.AddComponent<FinPhysics>(selected);
            
            if (!selected.GetComponent<WindsurferControllerV2>())
                Undo.AddComponent<WindsurferControllerV2>(selected);
            
            if (!selected.GetComponent<EquipmentVisualizer>())
                Undo.AddComponent<EquipmentVisualizer>(selected);

            EditorUtility.SetDirty(selected);
            Debug.Log($"✅ Components added to '{selected.name}'! Assign FBX models in EquipmentVisualizer.");
        }

        [MenuItem("Windsurfing/Quick: Add Components to Selected", true)]
        public static bool QuickAddComponentsValidate()
        {
            return Selection.activeGameObject != null;
        }
    }
}
