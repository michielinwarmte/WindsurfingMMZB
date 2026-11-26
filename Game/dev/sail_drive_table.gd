extends SceneTree
## The default sail's forward drive by angle of attack, at the apparent winds the game sails in:
## where the auto-sheet's best angle lies (Autopilot.best_alpha_deg scans 4 to 24 degrees) and how
## much drive a boom sheeted further in (a higher angle of attack) gives. Changes nothing.
##   tools/godot.sh --path Game --headless -s res://dev/sail_drive_table.gd
## Written 26 November 2026 for the sheet-in question (Documentation/reports/reality_fixes/PROGRESS.md).


func _initialize() -> void:
	var sail: SailModel = SailModel.new(load("res://config/sail_default.tres") as SailConfig)
	for q_pa: float in [60.0, 120.0, 180.0]:
		print("dynamic pressure %.0f Pa (apparent %.1f kt)" % [q_pa, sqrt(2.0 * q_pa / 1.225) / 0.5144])
		var line: String = "  alpha:"
		for a: int in range(8, 31, 2):
			line += "%6d" % a
		print(line)
		for awa_deg: float in [25.0, 30.0, 35.0]:
			var awa: float = deg_to_rad(awa_deg)
			var row: String = "  AWA %2.0f" % awa_deg
			var best_a: float = 0.0
			var best_d: float = -INF
			for a: int in range(8, 31, 2):
				var alpha: float = deg_to_rad(float(a))
				var cl: float = sail.lift_coefficient(alpha, q_pa)
				var cd: float = sail.drag_coefficient(cl, alpha, q_pa)
				var drive: float = cl * sin(awa) - cd * cos(awa)
				row += "%6.3f" % drive
				if drive > best_d:
					best_d = drive
					best_a = float(a)
			print(row + "   best %2.0f deg -> boom %2.0f deg" % [best_a, awa_deg - best_a])
	quit()
