extends SimScenario
## Starboard-tack beam reach: heading South with the wind from the West, held at TWA 90.


func _init() -> void:
	super()
	start_heading_deg = 180.0
	pilot.target_twa_deg = 90.0
