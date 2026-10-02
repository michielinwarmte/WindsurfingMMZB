extends SimScenario
## Upwind on starboard tack at TWA 45.


func _init() -> void:
	super()
	start_heading_deg = 180.0
	pilot.target_twa_deg = 45.0
