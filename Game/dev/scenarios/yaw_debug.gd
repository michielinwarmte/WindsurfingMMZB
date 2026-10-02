extends SimScenario
## Prints the yaw torque (about +Y, positive = bow to port) of each model at a few moments,
## to see what turns the board. Development aid.

var _printed: Dictionary[int, bool] = {}


func _init() -> void:
	super()
	start_heading_deg = 180.0
	pilot.target_twa_deg = 90.0
	seconds = 14.0


func update(sim: WindsurferSim, dt: float) -> void:
	pilot.update(sim.telemetry, controls, dt)
	var tenth: int = int(round(sim.time_s * 10.0))
	if tenth % 10 != 0 or _printed.has(tenth):
		return
	_printed[tenth] = true
	var body: SimRigidBody = sim.body
	var g: float = sim.sim_config.gravity_ms2
	body.clear_forces()
	sim.buoyancy.apply(body, sim.water, sim.time_s, g)
	var tau_b: Vector3 = body._torque_sum
	body.clear_forces()
	sim.hull.compute(body, sim.buoyancy, sim.water, sim.time_s, g, body.mass_kg)
	var tau_h: Vector3 = body._torque_sum
	var f_h: Vector3 = body._force_sum
	body.clear_forces()
	sim.fin.compute(body, sim.water, sim.time_s, sim.water_config.density_kg_m3)
	var tau_f: Vector3 = body._torque_sum
	body.clear_forces()
	sim.sail.compute(body, sim.wind, controls.sheet, controls.rake, WindsurferSim.RHO_AIR, sim.lean * deg_to_rad(sim.sailor_config.max_rig_lean_deg))
	var tau_s: Vector3 = body._torque_sum
	var f_s: Vector3 = body._force_sum
	body.clear_forces()
	var t: Telemetry = sim.telemetry
	var v_body: Vector3 = SimMath.to_body(body.basis, body.velocity)
	print("t=%4.1f twa=%6.1f spd=%5.2f heel=%6.1f yaw=%6.1f | yaw N m: hull %6.1f fin %6.1f sail %6.1f | roll N m: buoy %6.1f hull %6.1f fin %6.1f sail %6.1f | lean %.2f ce=(%.2f, %.2f, %.2f) com=(%.2f, %.2f, %.2f) | rake %.2f sheet %.2f alpha %.1f plan %.0f N trim %.1f sub %.2f" % [
		sim.time_s, t.twa_deg, t.speed_ms, t.heel_deg, t.yaw_rate_dps, tau_h.y, tau_f.y, tau_s.y, tau_b.z, tau_h.z, tau_f.z, tau_s.z, sim.lean,
		sim.sail.ce_local.x, sim.sail.ce_local.y, sim.sail.ce_local.z,
		body.com_offset_body.x, body.com_offset_body.y, body.com_offset_body.z, controls.rake, controls.sheet, t.alpha_deg, t.planing_lift_n, t.trim_deg, t.submersion_ratio])
