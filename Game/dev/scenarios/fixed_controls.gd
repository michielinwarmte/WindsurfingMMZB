extends SimScenario
## No sailor at all: sheet and rake stay where they are. Shows what the board does on its
## own (it rounds up at low speed, as a real board does).


func _init() -> void:
	super()
	start_heading_deg = 180.0
	controls.sheet = 0.6
	controls.rake = 0.0


func update(_sim: WindsurferSim, _dt: float) -> void:
	pass


func describe() -> String:
	return "fixed sheet %.2f, rake %.2f" % [controls.sheet, controls.rake]
