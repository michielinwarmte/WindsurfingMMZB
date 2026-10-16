class_name FlatWater
extends WaterSurface
## Flat, still water at a fixed level. The Phase 2 and 3 water.

var base_height_m: float = 0.0


func _init(water_config: WaterConfig = null) -> void:
	if water_config != null:
		base_height_m = water_config.base_height_m


func height_at(_x: float, _z: float, _time_s: float) -> float:
	return base_height_m
