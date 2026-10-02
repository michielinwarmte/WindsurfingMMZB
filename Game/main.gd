extends Node3D
## The playable prototype on flat water (plan, Phase 3): the windsurfer, the cameras, the
## HUD, and the keys that are not about sailing (pause, reset, camera, panels).
##
## Command line options for screenshots and demos (after "--"): --camera=1..4,
## --autopilot=1 (the test autopilot sails a beam reach), --hud=0 (no panel).

@onready var _windsurfer: WindsurferNode = $Windsurfer
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _hud: Hud = $HUD
@onready var _sun: DirectionalLight3D = $Sun

var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_apply_command_line_options()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not _paused)
	elif event.is_action_pressed("reset"):
		_windsurfer.reset()
		_set_paused(false)
	elif event.is_action_pressed("toggle_hud"):
		_hud.toggle_detail()
	elif event.is_action_pressed("camera_1"):
		_camera_rig.set_mode(CameraRig.Mode.FOLLOW)
	elif event.is_action_pressed("camera_2"):
		_camera_rig.set_mode(CameraRig.Mode.ORBIT)
	elif event.is_action_pressed("camera_3"):
		_camera_rig.set_mode(CameraRig.Mode.TOP_DOWN)
	elif event.is_action_pressed("camera_4"):
		_camera_rig.set_mode(CameraRig.Mode.FREE)


func _process(_delta: float) -> void:
	_hud.update_from(_windsurfer.telemetry(), _windsurfer.controller, _camera_rig.mode_name(), _windsurfer.use_autopilot)


func _set_paused(paused: bool) -> void:
	_paused = paused
	get_tree().paused = paused
	_hud.set_paused(paused)


func _apply_command_line_options() -> void:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	if options.has("camera"):
		var index: int = clampi(options["camera"].to_int() - 1, 0, 3)
		_camera_rig.set_mode(index as CameraRig.Mode)
	if options.get("autopilot", "0") == "1":
		_windsurfer.use_autopilot = true
	if options.get("hud", "1") == "0":
		_hud.toggle_detail()
