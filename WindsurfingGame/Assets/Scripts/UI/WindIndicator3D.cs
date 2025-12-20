using UnityEngine;
using WindsurfingGame.Physics.Wind;
using WindsurfingGame.Physics.Board;

namespace WindsurfingGame.UI
{
    /// <summary>
    /// Displays 3D wind direction indicators attached to the board.
    /// Shows true wind and apparent wind as visible arrows in the game world.
    /// </summary>
    public class WindIndicator3D : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Transform _boardTransform;
        [SerializeField] private WindManager _windManager;
        [SerializeField] private ApparentWindCalculator _apparentWind;

        [Header("True Wind Arrow")]
        [SerializeField] private bool _showTrueWind = true;
        [SerializeField] private Color _trueWindColor = new Color(0, 0.8f, 1f, 0.8f);
        [SerializeField] private float _trueWindScale = 0.3f;

        [Header("Apparent Wind Arrow")]
        [SerializeField] private bool _showApparentWind = true;
        [SerializeField] private Color _apparentWindColor = new Color(1f, 0.9f, 0, 0.8f);
        [SerializeField] private float _apparentWindScale = 0.3f;

        [Header("Position")]
        [SerializeField] private Vector3 _indicatorOffset = new Vector3(0, 3f, 0);

        // Arrow GameObjects
        private GameObject _trueWindArrow;
        private GameObject _apparentWindArrow;

        private void Start()
        {
            FindReferences();
            CreateArrows();
        }

        private void FindReferences()
        {
            if (_boardTransform == null)
            {
                var controller = FindFirstObjectByType<Player.WindsurferController>();
                if (controller != null)
                    _boardTransform = controller.transform;
            }

            if (_windManager == null)
                _windManager = FindFirstObjectByType<WindManager>();

            if (_apparentWind == null && _boardTransform != null)
                _apparentWind = _boardTransform.GetComponent<ApparentWindCalculator>();
        }

        private void CreateArrows()
        {
            if (_showTrueWind)
            {
                _trueWindArrow = CreateArrow("TrueWindArrow", _trueWindColor);
            }

            if (_showApparentWind)
            {
                _apparentWindArrow = CreateArrow("ApparentWindArrow", _apparentWindColor);
            }
        }

        private GameObject CreateArrow(string name, Color color)
        {
            GameObject arrow = new GameObject(name);
            arrow.transform.SetParent(transform);

            // Create arrow shaft (cylinder)
            GameObject shaft = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            shaft.name = "Shaft";
            shaft.transform.SetParent(arrow.transform);
            shaft.transform.localPosition = new Vector3(0, 0, 1.5f);
            shaft.transform.localRotation = Quaternion.Euler(90, 0, 0);
            shaft.transform.localScale = new Vector3(0.1f, 1.5f, 0.1f);
            Destroy(shaft.GetComponent<Collider>());
            SetMaterial(shaft, color);

            // Create arrow head (cone approximation with cylinder)
            GameObject head = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            head.name = "Head";
            head.transform.SetParent(arrow.transform);
            head.transform.localPosition = new Vector3(0, 0, 3.2f);
            head.transform.localRotation = Quaternion.Euler(90, 0, 0);
            head.transform.localScale = new Vector3(0.3f, 0.4f, 0.3f);
            Destroy(head.GetComponent<Collider>());
            SetMaterial(head, color);

            // Create label
            GameObject labelObj = new GameObject("Label");
            labelObj.transform.SetParent(arrow.transform);
            labelObj.transform.localPosition = new Vector3(0, 0.5f, 2f);
            
            TextMesh textMesh = labelObj.AddComponent<TextMesh>();
            textMesh.text = name.Contains("True") ? "TRUE" : "APPARENT";
            textMesh.fontSize = 24;
            textMesh.characterSize = 0.1f;
            textMesh.anchor = TextAnchor.MiddleCenter;
            textMesh.alignment = TextAlignment.Center;
            textMesh.color = color;

            return arrow;
        }

        private void SetMaterial(GameObject obj, Color color)
        {
            Renderer renderer = obj.GetComponent<Renderer>();
            if (renderer != null)
            {
                Material mat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
                mat.color = color;
                
                // Make slightly emissive for visibility
                mat.EnableKeyword("_EMISSION");
                mat.SetColor("_EmissionColor", color * 0.3f);
                
                renderer.material = mat;
            }
        }

        private void LateUpdate()
        {
            if (_boardTransform == null) return;

            Vector3 indicatorPosition = _boardTransform.position + _indicatorOffset;

            // Update true wind arrow
            if (_trueWindArrow != null && _windManager != null)
            {
                Vector3 windDir = _windManager.WindDirection;
                float windSpeed = _windManager.WindSpeed;
                
                _trueWindArrow.transform.position = indicatorPosition;
                _trueWindArrow.transform.rotation = Quaternion.LookRotation(windDir);
                _trueWindArrow.transform.localScale = Vector3.one * _trueWindScale * (0.5f + windSpeed * 0.1f);
            }

            // Update apparent wind arrow
            if (_apparentWindArrow != null && _apparentWind != null)
            {
                Vector3 appWindDir = _apparentWind.ApparentWind.normalized;
                float appWindSpeed = _apparentWind.ApparentWindSpeed;
                
                if (appWindSpeed > 0.5f)
                {
                    _apparentWindArrow.SetActive(true);
                    _apparentWindArrow.transform.position = indicatorPosition + Vector3.up * 0.5f;
                    _apparentWindArrow.transform.rotation = Quaternion.LookRotation(appWindDir);
                    _apparentWindArrow.transform.localScale = Vector3.one * _apparentWindScale * (0.5f + appWindSpeed * 0.1f);
                }
                else
                {
                    _apparentWindArrow.SetActive(false);
                }
            }

            // Make labels face camera
            UnityEngine.Camera cam = UnityEngine.Camera.main;
            if (cam != null)
            {
                FaceLabelToCamera(_trueWindArrow, cam);
                FaceLabelToCamera(_apparentWindArrow, cam);
            }
        }

        private void FaceLabelToCamera(GameObject arrow, UnityEngine.Camera cam)
        {
            if (arrow == null) return;
            
            Transform label = arrow.transform.Find("Label");
            if (label != null)
            {
                label.LookAt(cam.transform);
                label.Rotate(0, 180, 0); // Flip to face camera
            }
        }

        private void OnDestroy()
        {
            if (_trueWindArrow != null) Destroy(_trueWindArrow);
            if (_apparentWindArrow != null) Destroy(_apparentWindArrow);
        }
    }
}
