class_name FlatWater
extends WaterSurface
## Flat, still water at a fixed level. The Phase 2 and 3 water.

var base_height_m: float = 0.0


func _init(water_config: WaterConfig = null) -> void:
	if water_config != null:
		base_height_m = water_config.base_height_m


func height_at(_x: float, _z: float, _time_s: float) -> float:
	return base_height_m


## The three answers at once: the still level, level, not moving (9.9). Nothing is displaced,
## so the rest point is the point itself.
func sample_at(x: float, z: float, time_s: float, sample: WaterSurface.Sample) -> void:
	sample.x = x
	sample.z = z
	sample.time_s = time_s
	sample.height_m = base_height_m
	sample.normal = Vector3.UP
	sample.velocity_ms = Vector3.ZERO
	sample.rest_x = x
	sample.rest_z = z
	sample.is_set = true
