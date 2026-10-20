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
func sample_at(x: float, z: float, time_s: float, samples: PackedFloat64Array, index: int) -> void:
	write_sample(samples, index, x, z, time_s, Vector2(x, z), base_height_m, Vector3.UP, Vector3.ZERO)
