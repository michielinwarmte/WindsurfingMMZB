class_name Hud
extends CanvasLayer
## The telemetry on the screen: a one-line strip that is always there (speed, wind, mode),
## a detail panel with the forces and the controls (F1), a wind rose and the key help.
## On a map (sail_silvaplana.tscn) also a small map of the lake, and a message line for the
## shore ("Aground ..."). With a race course (show_course()) a line with the course's name, and
## the course on the small map (on the open water a small map of the course's water).
## Everything is read from the simulation's Telemetry; nothing is computed here. The pause
## menu (pause_menu.gd) is separate; the sailing scene (main.gd) hides this whole layer
## behind the start menu.

var detail_visible: bool = true
var _strip: Label
var _panel: PanelContainer
var _detail: Label
var _help: Label
var _rose: WindRose
## Only in a map scene (show_mini_map), or with a race course (show_course).
var _mini_map: MiniMap = null
var _message: Label
## The race course's name, above the small map (show_course).
var _course_line: Label = null
## On a map with its own day of wind: the time of day, at the start of the strip ("" = none).
var clock_text: String = ""
## A race is on: the strip is hidden and the help names the racing keys (set_race_mode).
var _race_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])

	_strip = _label(font, 18, Vector2(16.0, 10.0))
	add_child(_strip)

	_panel = PanelContainer.new()
	_panel.position = Vector2(16.0, 44.0)
	add_child(_panel)
	_detail = _label(font, 15, Vector2.ZERO)
	_panel.add_child(_detail)

	# The key help sits at the bottom and the wind rose at the top right of any window size
	# (anchored to those corners), not only at the default 1280 x 720.
	_help = _label(font, 12, Vector2.ZERO)
	_help.text = "W/S sheet  A/D turn (beginner) / weight (advanced)  Q/E rake  Left/Right rig tilt (adv.)  Space tack/gybe  T auto-sheet  Tab mode  1-4 camera  R reset  Esc menu  F1 panel"
	add_child(_help)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_help.offset_left = 16.0

	_rose = WindRose.new()
	add_child(_rose)
	_rose.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rose.offset_left = -150.0
	_rose.offset_right = -20.0
	_rose.offset_top = 20.0
	_rose.offset_bottom = 150.0

	# A message across the middle of the screen, under the panels (set_message).
	_message = _label(font, 22, Vector2.ZERO)
	_message.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -400.0
	_message.offset_right = 400.0
	_message.offset_top = 200.0
	_message.hide()


## A small map of the lake in the bottom right corner, above the key help (map scenes only).
## Before show_course(), which then puts the course on it.
func show_mini_map(area: LakeArea, start: Vector3) -> void:
	_mini_map = MiniMap.new()
	add_child(_mini_map)
	_mini_map.setup(area, start)
	_place_mini_map()


## A race course (RACING_PLAN.md, 9A): its name in a line above the small map, and its marks,
## lines and legs on it. Without a lake's map (the open water) the small map shows the course's
## water instead.
func show_course(course: Course) -> void:
	if _mini_map == null:
		_mini_map = MiniMap.new()
		add_child(_mini_map)
		_mini_map.setup_for_course(course)
		_place_mini_map()
	else:
		_mini_map.show_course(course)
	if _course_line == null:
		_course_line = _label(_strip.get_theme_font("font"), 15, Vector2.ZERO)
		_course_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_course_line)
		_course_line.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_course_line.offset_left = -420.0
		_course_line.offset_right = -20.0
		_course_line.offset_top = -_mini_map.size.y - 66.0
		_course_line.offset_bottom = -_mini_map.size.y - 44.0
	_course_line.text = "Course: " + course.name


func course_text() -> String:
	return _course_line.text if _course_line != null else ""


func _place_mini_map() -> void:
	_mini_map.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini_map.offset_left = -_mini_map.size.x - 20.0
	_mini_map.offset_right = -20.0
	_mini_map.offset_top = -_mini_map.size.y - 40.0
	_mini_map.offset_bottom = -40.0


## A short message in the middle of the screen; an empty text hides it.
func set_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


func message() -> String:
	return _message.text if _message.visible else ""


func toggle_detail() -> void:
	set_detail_visible(not detail_visible)


## Shows or hides the detail panel and the key help line (F1).
func set_detail_visible(shown: bool) -> void:
	detail_visible = shown
	_panel.visible = shown
	_help.visible = shown or _race_mode


func update_from(t: Telemetry, controller: PlayerController, camera_name: String, use_autopilot: bool) -> void:
	var tack: String = "starboard tack" if t.twa_deg >= 0.0 else "port tack"
	var state: String = "planing" if t.is_planing else ("luffing" if t.is_luffing else "displacement")
	if t.sailor_state == 1:
		state = "%s!  waterstart in %d s (R: now)" % [t.fall_kind.to_upper(), ceili(t.waterstart_in_s)]
	var who: String = "autopilot" if use_autopilot else controller.mode_name()
	var manoeuvre: String = controller.manoeuvre_name()
	_strip.text = ("%s   " % clock_text if clock_text != "" else "") + "%5.1f km/h  %4.1f kt    wind %4.1f kt at 10 m, %4.1f kt at the sail, from %03.0f    %s, %s%s    %s    camera: %s" % [
		t.speed_kmh, t.speed_kt, t.tws_10m_kt, t.tws_at_sail_kt, t.wind_from_bearing_deg,
		tack, state, ("  " + manoeuvre) if manoeuvre != "" else "", who, camera_name]
	_rose.heading_deg = t.heading_deg
	_rose.wind_from_deg = t.wind_from_bearing_deg
	_rose.queue_redraw()
	if _mini_map != null:
		_mini_map.board_position = t.position
		_mini_map.heading_deg = t.heading_deg
		_mini_map.wind_from_deg = t.wind_from_bearing_deg
		_mini_map.queue_redraw()
	if not detail_visible:
		return
	_detail.text = (
		"heading %5.1f   TWA %6.1f   AWA %6.1f   AWS %4.1f kt   VMG %5.2f m/s   leeway %4.1f\n" % [t.heading_deg, t.twa_deg, t.awa_deg, t.aws_kt, t.vmg_ms, t.leeway_deg]
		+ "pitch %5.1f   heel %5.1f   yaw rate %5.1f deg/s\n" % [t.pitch_deg, t.heel_deg, t.yaw_rate_dps]
		+ "sheet %3.0f %%  boom %4.0f deg%s   rake %5.2f   rig tilt %5.2f (%4.0f deg)   alpha %5.1f deg%s   helm %5.2f\n" % [t.sheet * 100.0, t.sail_angle_deg, "  across %3.0f %%" % (t.boom_across * 100.0) if t.boom_across > 0.005 else "", t.rake, t.rig_tilt, t.rig_lean_deg, t.alpha_deg, "  BACKWINDED" if t.is_backwinded else "", controller.helm_right]
		+ "lean %5.2f   stance %4.2f   hang-back %4.2f m   knees %5.2f m   sway %4.2f m   hands %4.0f N   feet %4.0f N   feet moment %5.0f Nm\n" % [t.lean, t.stance, t.hang_back_m, t.knee_bend_m, t.leg_sway_m, t.hand_force_n, t.foot_force_n, t.feet_moment_roll_nm]
		+ "sail  lift %5.0f N  drag %4.0f N  drive %5.0f N  side %5.0f N\n" % [t.sail_lift_n, t.sail_drag_n, t.drive_n, t.side_force_n]
		# "of stall" is the fin's lift coefficient as a share of its peak; "bend" is how far
		# its tip has turned under the load (U2); "up" is the upward part of its force, what
		# it lifts the kit by.
		+ "fin   lift %5.0f N  drag %4.0f N  slip %5.1f deg  load %3.0f %% of stall  bend %4.1f deg  up %4.0f N%s\n" % [t.fin_lift_n, t.fin_drag_n, t.fin_slip_deg, t.fin_load_share * 100.0, t.fin_bend_tip_deg, t.fin_up_n, "  STALLED" if t.fin_stalled else ""]
		# "wetted" is the area the friction acts on (the planing wet span times its width),
		# not the buoyancy grid's smaller area: it is the one that costs speed. "front" is how
		# far forward of the tail the wet part reaches.
		+ "hull  planing %3.0f %% (%4.0f N)  buoyancy %4.0f N  submersion %3.0f %%  wetted %4.2f m2 (front %4.2f m)  resistance %4.0f N  trim %4.1f deg\n" % [t.planing_ratio * 100.0, t.planing_lift_n, t.buoyancy_n, t.submersion_ratio * 100.0, t.friction_area_m2, t.wet_front_m, t.hull_resistance_n, t.trim_deg]
		+ "rig   harness %4.0f N   mast foot pushing down %4.0f N\n" % [t.harness_tension_n, -t.mast_foot_force_up_n]
		+ "auto-sheet %s" % ["on" if controller.auto_sheet else "off"])


func _label(font: Font, size: int, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	return label


## A compass rose: North up, the board's heading as a triangle, the wind as an arrow that
## points the way the wind blows (it comes FROM the tail of the arrow).
class WindRose:
	extends Control
	var heading_deg: float = 0.0
	var wind_from_deg: float = 270.0
	## The bearing of a race's next mark; NAN for none.
	var mark_bearing_deg: float = NAN

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.45
		draw_circle(centre, radius, Color(0.0, 0.0, 0.0, 0.35))
		draw_arc(centre, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8), 2.0)
		draw_string(ThemeDB.fallback_font, centre + Vector2(-5.0, -radius + 14.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		# Bearings are clockwise from North, screen y points down: bearing b is at (sin b, -cos b).
		var heading: Vector2 = Vector2(sin(deg_to_rad(heading_deg)), -cos(deg_to_rad(heading_deg)))
		var bow: Vector2 = centre + heading * radius * 0.8
		var side: Vector2 = Vector2(-heading.y, heading.x) * radius * 0.18
		draw_colored_polygon(PackedVector2Array([bow, centre - heading * radius * 0.3 + side, centre - heading * radius * 0.3 - side]), Color(1.0, 0.6, 0.1, 0.95))
		var from: Vector2 = Vector2(sin(deg_to_rad(wind_from_deg)), -cos(deg_to_rad(wind_from_deg)))
		var tail: Vector2 = centre + from * radius * 0.95
		var head: Vector2 = centre + from * radius * 0.35
		draw_line(tail, head, Color(0.5, 0.85, 1.0), 3.0)
		var dir: Vector2 = (head - tail).normalized()
		var wing: Vector2 = Vector2(-dir.y, dir.x) * 6.0
		draw_colored_polygon(PackedVector2Array([head, head - dir * 10.0 + wing, head - dir * 10.0 - wing]), Color(0.5, 0.85, 1.0))
		# The next mark of a race: an orange dot on the rim at its bearing.
		if not is_nan(mark_bearing_deg):
			var to_mark: Vector2 = Vector2(sin(deg_to_rad(mark_bearing_deg)), -cos(deg_to_rad(mark_bearing_deg)))
			draw_circle(centre + to_mark * radius * 0.88, 5.0, Color(1.0, 0.45, 0.1))


## The other boards of a race on the small map (RaceRunner).
func set_other_boards(positions: PackedVector3Array) -> void:
	if _mini_map != null:
		_mini_map.other_boards = positions


## A race (RaceRunner): the telemetry strip and the panel make way for the race's own block
## (RaceHud); F1 still brings the panel back. The key help names the racing keys.
func set_race_mode(on: bool) -> void:
	_race_mode = on
	_strip.visible = not on
	if on:
		set_detail_visible(false)
		_help.text = "A/D turn   W/S sheet   Space tack/gybe   1-4 camera   R race again   Esc menu   F1 telemetry"


## The bearing of a race's next mark, as a dot on the compass rose (NAN clears it).
func set_next_mark_bearing(bearing_deg: float) -> void:
	_rose.mark_bearing_deg = bearing_deg
