extends SimScenario
## Broad reach on starboard tack at TWA 135.


func _init() -> void:
	super()
	start_heading_deg = 180.0
	pilot.target_twa_deg = 135.0
