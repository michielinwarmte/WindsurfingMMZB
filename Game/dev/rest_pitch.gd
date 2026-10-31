extends SceneTree
## The board's attitude at rest by the sailor's rest stance (Session 61): the default windsurfer
## floating in no wind for 8 s, as test_windsurfer_sim.gd's rest test has it, for each stance
## asked. Prints the pitch (bow up positive), the heel, the submerged share and the hands' force,
## so the stance where the board floats level can be read off instead of guessed.
##
##   tools/godot.sh --path Game --headless -s res://dev/rest_pitch.gd -- --stances=0.09,0.05,0.02,0,-0.02

const DT: float = 1.0 / 60.0


func _initialize() -> void:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	var stances: PackedStringArray = options.get("stances", "0.09,0.05,0.02,0,-0.02").split(",")
	print("stance_rest_z_m  from tail  pitch deg  heel deg  submerged  hands N  speed m/s")
	for text: String in stances:
		var stance: float = text.to_float()
		var base: WindsurferSim = WindsurferSim.create_default()
		var sailor: SailorConfig = base.sailor_config.duplicate() as SailorConfig
		sailor.stance_rest_z_m = stance
		var wind_config: WindConfig = base.wind_config.duplicate() as WindConfig
		wind_config.speed_kt = 0.0
		# Built again with the changed sailor (the mass model copies the stance when it is built).
		var sim: WindsurferSim = WindsurferSim.new(base.board_config, base.sail_config, base.fin_config, sailor,
			base.water_config, wind_config, base.sim_config, base.wave_set_config)
		sim.reset(Vector3.ZERO, 0.0)
		var controls: SimControls = SimControls.new()
		controls.sheet = 0.0
		for i: int in int(8.0 / DT):
			sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		print("%14.2f  %8.2f  %8.2f  %8.2f  %9.3f  %7.1f  %9.3f" % [
			stance, 0.5 * sim.board_config.length_m - stance, t.pitch_deg, t.heel_deg,
			sim.buoyancy.submerged_volume_m3 / sim.board_config.volume_m3, sim.hand_force_world.length(), t.speed_ms])
	quit(0)
