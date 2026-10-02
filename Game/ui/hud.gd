class_name Hud
extends CanvasLayer
## The telemetry on the screen: a one-line strip that is always there (speed, wind, mode),
## a detail panel with the forces and the controls (F1), a wind rose and the key help.
## Everything is read from the simulation's Telemetry; nothing is computed here.

var detail_visible: bool = true
var _strip: Label
var _panel: PanelContainer
var _detail: Label
var _help: Label
var _rose: WindRose
var _pause_label: Label


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

	_help = _label(font, 12, Vector2(16.0, 692.0))
	_help.text = "W/S sheet  A/D turn (beginner) / weight (advanced)  Q/E rake  Left/Right rig tilt (adv.)  Space tack/gybe  T auto-sheet  Tab mode  1-4 camera  R reset  Esc pause  F1 panel"
	add_child(_help)

	_rose = WindRose.new()
	_rose.position = Vector2(1130.0, 20.0)
	_rose.size = Vector2(130.0, 130.0)
	add_child(_rose)

	_pause_label = _label(font, 40, Vector2(540.0, 320.0))
	_pause_label.text = "PAUSED"
	_pause_label.visible = false
	add_child(_pause_label)


func set_paused(paused: bool) -> void:
	_pause_label.visible = paused


func toggle_detail() -> void:
	detail_visible = not detail_visible
	_panel.visible = detail_visible
	_help.visible = detail_visible


func update_from(t: Telemetry, controller: PlayerController, camera_name: String, use_autopilot: bool) -> void:
	var tack: String = "starboard tack" if t.twa_deg >= 0.0 else "port tack"
	var state: String = "planing" if t.is_planing else ("luffing" if t.is_luffing else "displacement")
	if t.sailor_state == 1:
		state = "%s!  waterstart in %d s (R: now)" % [t.fall_kind.to_upper(), ceili(t.waterstart_in_s)]
	var who: String = "autopilot" if use_autopilot else controller.mode_name()
	var manoeuvre: String = controller.manoeuvre_name()
	_strip.text = "%5.1f km/h  %4.1f kt    wind %4.1f kt at 10 m, %4.1f kt at the sail, from %03.0f    %s, %s%s    %s    camera: %s" % [
		t.speed_kmh, t.speed_kt, t.tws_10m_kt, t.tws_at_sail_kt, t.wind_from_bearing_deg,
		tack, state, ("  " + manoeuvre) if manoeuvre != "" else "", who, camera_name]
	_rose.heading_deg = t.heading_deg
	_rose.wind_from_deg = t.wind_from_bearing_deg
	_rose.queue_redraw()
	if not detail_visible:
		return
	_detail.text = (
		"heading %5.1f   TWA %6.1f   AWA %6.1f   AWS %4.1f kt   VMG %5.2f m/s   leeway %4.1f\n" % [t.heading_deg, t.twa_deg, t.awa_deg, t.aws_kt, t.vmg_ms, t.leeway_deg]
		+ "pitch %5.1f   heel %5.1f   yaw rate %5.1f deg/s\n" % [t.pitch_deg, t.heel_deg, t.yaw_rate_dps]
		+ "sheet %3.0f %%  boom %4.0f deg%s   rake %5.2f   rig tilt %5.2f (%4.0f deg)   alpha %5.1f deg%s   helm %5.2f\n" % [t.sheet * 100.0, t.sail_angle_deg, "  across %3.0f %%" % (t.boom_across * 100.0) if t.boom_across > 0.005 else "", t.rake, t.rig_tilt, t.rig_lean_deg, t.alpha_deg, "  BACKWINDED" if t.is_backwinded else "", controller.helm_right]
		+ "lean %5.2f   stance %4.2f   hang-back %4.2f m   knees %5.2f m\n" % [t.lean, t.stance, t.hang_back_m, t.knee_bend_m]
		+ "sail  lift %5.0f N  drag %4.0f N  drive %5.0f N  side %5.0f N\n" % [t.sail_lift_n, t.sail_drag_n, t.drive_n, t.side_force_n]
		+ "fin   lift %5.0f N  drag %4.0f N  slip %5.1f deg%s\n" % [t.fin_lift_n, t.fin_drag_n, t.fin_slip_deg, "  STALLED" if t.fin_stalled else ""]
		+ "hull  planing %3.0f %% (%4.0f N)  buoyancy %4.0f N  submersion %3.0f %%  wetted %4.2f m2  resistance %4.0f N  trim %4.1f deg\n" % [t.planing_ratio * 100.0, t.planing_lift_n, t.buoyancy_n, t.submersion_ratio * 100.0, t.wetted_area_m2, t.hull_resistance_n, t.trim_deg]
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
