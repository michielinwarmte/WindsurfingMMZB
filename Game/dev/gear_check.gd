extends SceneTree
## Prints the gear the game sails: the same call as the player's windsurfer
## (Game/windsurfer/windsurfer.gd: WindsurferSim.create_for(EnvironmentConfig.new(), true, ...)).
## Run: tools/godot.sh --path Game --headless -s res://dev/gear_check.gd


func _initialize() -> void:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, false)
	print("board: %.2f x %.2f m, %.0f l, %.1f kg, nose rocker %.3f m over %.2f m" % [sim.board_config.length_m, sim.board_config.width_m, sim.board_config.volume_m3 * 1000.0, sim.board_config.mass_kg, sim.board_config.nose_rocker_m, sim.board_config.nose_rocker_length_m])
	print("sail: %.1f m2, luff %.1f m, boom %.2f m, rig %.1f kg" % [sim.sail_config.area_m2, sim.sail_config.luff_m, sim.sail_config.boom_m, sim.sail_config.rig_mass_kg])
	print("sailor: trim by feel %.1f s, press reach %.2f m, rig pitch lag %.1f s" % [sim.sailor_config.trim_feel_time_s, sim.sailor_config.trim_press_max_m, sim.sailor_config.rig_pitch_follow_s])
	quit(0)
