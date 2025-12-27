using UnityEngine;
using UnityEditor;
using WindsurfingGame.Physics.Board;
using WindsurfingGame.Physics.Buoyancy;
using WindsurfingGame.Physics.Water;
using WindsurfingGame.Physics.Core;
using WindsurfingGame.Environment;
using WindsurfingGame.Player;
using WindsurfingGame.Visual;

namespace WindsurfingGame.Editor
{
    /// <summary>
    /// Complete editor utility to set up a Windsurfer from FBX models.
    /// Creates proper hierarchy and configures all ADVANCED physics components.
    /// 
    /// USAGE:
    /// 1. Menu: Windsurfing → Complete Windsurfer Setup Wizard
    /// 2. Drag your board.fbx and sail.fbx into the dialog
    /// 3. Click "Create Windsurfer"
    /// 
    /// Components added:
    /// - Rigidbody
    /// - BoxCollider  
    /// - AdvancedBuoyancy (realistic multi-point buoyancy)
    /// - AdvancedSail (aerodynamic sail physics)
    /// - AdvancedFin (hydrodynamic fin physics)
    /// - AdvancedHullDrag (hull resistance with planing)
    /// - AdvancedWindsurferController (realistic control)
    /// - EquipmentVisualizer (FBX model display)
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
        
        [MenuItem("Windsurfing/Complete Windsurfer Setup Wizard")]
        public static void ShowWindow()
        {
            var window = GetWindow<WindsurferSetupWizard>("Windsurfer Setup");
            window.minSize = new Vector2(400, 550);
            window.Show();
        }

        private void OnGUI()
        {
            GUILayout.Label("🏄 Advanced Windsurfer Setup Wizard", EditorStyles.boldLabel);
            EditorGUILayout.Space(10);
            
            EditorGUILayout.HelpBox(
                "Creates a complete Windsurfer with ADVANCED physics:\n\n" +
                "• AdvancedSail - realistic aerodynamics\n" +
                "• AdvancedFin - hydrodynamic lift/drag\n" +
                "• AdvancedHullDrag - displacement/planing modes\n" +
                "• AdvancedBuoyancy - multi-point flotation\n\n" +
                "Your FBX models should have:\n" +
                "• Board: Pivot at board center\n" +
                "• Sail: Pivot at mast base", 
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
            
            EditorGUILayout.Space(20);
            
            // Validation
            bool canCreate = _boardModel != null && _sailModel != null;
            
            EditorGUI.BeginDisabledGroup(!canCreate);
            if (GUILayout.Button("Create Windsurfer", GUILayout.Height(40)))
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
            
            if (GUILayout.Button("Point Camera to Selected Windsurfer"))
            {
                PointCameraToSelected();
            }
            
            if (GUILayout.Button("Disable Old WindsurfBoard"))
            {
                DisableOldBoard();
            }
            
            if (GUILayout.Button("Delete Old WindsurfBoard"))
            {
                DeleteOldBoard();
            }
        }

        private void CreateWindsurfer()
        {
            // Find scene references
            WaterSurface waterSurface = FindFirstObjectByType<WaterSurface>();
            if (waterSurface == null)
            {
                EditorUtility.DisplayDialog("Error", "No WaterSurface found in scene! Add one first.", "OK");
                return;
            }
            
            WindSystem windSystem = FindFirstObjectByType<WindSystem>();
            if (windSystem == null)
            {
                // Check for legacy WindManager
                var legacyWind = FindFirstObjectByType<Physics.Wind.WindManager>();
                if (legacyWind == null)
                {
                    EditorUtility.DisplayDialog("Error", 
                        "No WindSystem found in scene!\n\n" +
                        "The Advanced physics requires a WindSystem component.\n" +
                        "Please add a GameObject with WindSystem to the scene.", "OK");
                    return;
                }
                else
                {
                    EditorUtility.DisplayDialog("Warning", 
                        "Found legacy WindManager but no WindSystem.\n\n" +
                        "The Advanced physics works best with WindSystem.\n" +
                        "Consider adding a WindSystem component.", "OK");
                }
            }

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
            buoyancySO.FindProperty("_displacedVolume").floatValue = 120f;  // 120 liters
            buoyancySO.FindProperty("_floatHeight").floatValue = 0.05f;
            buoyancySO.FindProperty("_autoGeneratePoints").boolValue = true;
            buoyancySO.FindProperty("_pointsAlongLength").intValue = 5;
            buoyancySO.FindProperty("_pointsAlongWidth").intValue = 3;
            buoyancySO.FindProperty("_waterDamping").floatValue = 50f;
            buoyancySO.FindProperty("_angularDamping").floatValue = 20f;
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
            // STEP 7: Add AdvancedWindsurferController (realistic control)
            // ==========================================
            AdvancedWindsurferController controller = windsurfer.AddComponent<AdvancedWindsurferController>();
            SerializedObject ctrlSO = new SerializedObject(controller);
            ctrlSO.FindProperty("_sail").objectReferenceValue = sail;
            ctrlSO.FindProperty("_fin").objectReferenceValue = fin;
            ctrlSO.FindProperty("_hull").objectReferenceValue = hull;
            ctrlSO.FindProperty("_rigidbody").objectReferenceValue = rb;
            ctrlSO.FindProperty("_controlMode").enumValueIndex = 1; // Intermediate mode
            ctrlSO.FindProperty("_antiCapsize").boolValue = true;
            ctrlSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 8: Add EquipmentVisualizer (FBX models)
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
            equipSO.FindProperty("_sailAngleOffset").floatValue = 0f; // Adjust if model's "forward" differs from physics
            equipSO.FindProperty("_maxRakeAngle").floatValue = 15f;
            equipSO.FindProperty("_smoothSpeed").floatValue = 8f;
            equipSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 9: Add ForceVectorVisualizer (debug arrows)
            // ==========================================
            ForceVectorVisualizer forceVis = windsurfer.AddComponent<ForceVectorVisualizer>();
            SerializedObject forceVisSO = new SerializedObject(forceVis);
            forceVisSO.FindProperty("_sail").objectReferenceValue = sail;
            forceVisSO.FindProperty("_fin").objectReferenceValue = fin;
            forceVisSO.FindProperty("_rigidbody").objectReferenceValue = rb;
            forceVisSO.ApplyModifiedProperties();
            
            // ==========================================
            // STEP 10: Add WindDirectionIndicator to scene (if not exists)
            // ==========================================
            if (FindFirstObjectByType<WindDirectionIndicator>() == null)
            {
                GameObject windIndicator = new GameObject("WindDirectionIndicator");
                WindDirectionIndicator windInd = windIndicator.AddComponent<WindDirectionIndicator>();
                Undo.RegisterCreatedObjectUndo(windIndicator, "Create WindDirectionIndicator");
            }
            
            // ==========================================
            // STEP 11: Point camera to new windsurfer
            // ==========================================
            Selection.activeGameObject = windsurfer;
            PointCameraToSelected();
            
            // ==========================================
            // STEP 12: Disable old board
            // ==========================================
            DisableOldBoard();
            
            Debug.Log("✅ ADVANCED WINDSURFER CREATED SUCCESSFULLY!\n\n" +
                      "Components added:\n" +
                      "  ✓ Rigidbody (91kg total mass)\n" +
                      "  ✓ BoxCollider (2.5m x 0.6m x 0.12m)\n" +
                      "  ✓ AdvancedBuoyancy (15-point flotation)\n" +
                      "  ✓ AdvancedSail (6.5m² area, aerodynamic model)\n" +
                      "  ✓ AdvancedFin (40cm depth, hydrodynamic model)\n" +
                      "  ✓ AdvancedHullDrag (displacement/planing)\n" +
                      "  ✓ AdvancedWindsurferController\n" +
                      "  ✓ EquipmentVisualizer (with your models)\n" +
                      "  ✓ ForceVectorVisualizer (debug arrows)\n" +
                      "  ✓ WindDirectionIndicator (water arrows)\n\n" +
                      "Press PLAY to test! Controls:\n" +
                      "  A/D = Steer (combined in Beginner, weight shift in Advanced)\n" +
                      "  Q/E = Mast rake (Intermediate/Advanced modes)\n" +
                      "  W/S = Sheet in/out (power control)\n" +
                      "  Tab = Cycle control mode (Beginner → Intermediate → Advanced)");
            
            EditorUtility.DisplayDialog("Success!", 
                "Advanced Windsurfer created!\n\nPress Play to test.\n\n" +
                "Controls:\n• A/D = Steer\n• Q/E = Rake (Adv)\n• W/S = Sheet\n• Tab = Cycle mode", "OK");
        }

        private static void PointCameraToSelected()
        {
            GameObject selected = Selection.activeGameObject;
            if (selected == null) return;

            var cameras = FindObjectsByType<MonoBehaviour>(FindObjectsSortMode.None);
            foreach (var cam in cameras)
            {
                if (cam.GetType().Name == "ThirdPersonCamera")
                {
                    SerializedObject camSO = new SerializedObject(cam);
                    SerializedProperty targetProp = camSO.FindProperty("_target");
                    if (targetProp != null)
                    {
                        Undo.RecordObject(cam, "Point Camera to Windsurfer");
                        targetProp.objectReferenceValue = selected.transform;
                        camSO.ApplyModifiedProperties();
                        Debug.Log($"✅ Camera now following '{selected.name}'");
                        return;
                    }
                }
            }
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
