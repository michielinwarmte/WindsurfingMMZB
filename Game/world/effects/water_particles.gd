class_name WaterParticles
extends RefCounted
## The particle emitters for water thrown into the air: the spray sheets off a planing
## board's rails, and the splash of a hard landing or a fall. Both are GPU particles (Godot
## moves them on the graphics card, so hundreds cost almost nothing): small soft white
## droplets that fly out, fall under gravity, slow down in the air and fade within a second.
## The emitters only make the particles; effects.gd decides where, when and how much.

## Droplets in a spray sheet: up to this many alive per rail, each living this long.
const SPRAY_AMOUNT: int = 400
const SPRAY_LIFETIME_S: float = 0.55
## A splash: this many droplets at full strength, living this long.
const SPLASH_AMOUNT: int = 260
const SPLASH_LIFETIME_S: float = 1.3
## Air slows the small droplets down (m/s per second).
const AIR_DAMPING_MS2: float = 1.5


## A spray emitter for one rail (side -1 = port, +1 = starboard). Placed at the spray root in
## the board's axes, it throws a sheet outward over the rail, up and back. Its emission is
## set with amount_ratio (0 = none) and the throw speed with set_spray_speed().
static func make_spray(side: float) -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	# A thin line of water along the rail around the spray root.
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.03, 0.02, 0.22)
	# Out over the rail, up, and a little back (the board's +Z is aft).
	process.direction = Vector3(side * 0.7, 0.6, 0.5).normalized()
	process.spread = 18.0
	process.flatness = 0.6
	process.gravity = Vector3(0.0, -9.81, 0.0)
	process.damping_min = AIR_DAMPING_MS2
	process.damping_max = AIR_DAMPING_MS2 * 2.0
	# The droplets keep part of the board's speed: they leave the hull moving with it.
	process.inherit_velocity_ratio = 0.7
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.scale_curve = _growing_curve()
	process.color_ramp = _fading_ramp(0.85)
	var particles: GPUParticles3D = _make_emitter(process, SPRAY_AMOUNT, SPRAY_LIFETIME_S, 0.07)
	particles.name = "SprayPort" if side < 0.0 else "SprayStarboard"
	set_spray_speed(particles, 0.0)
	particles.amount_ratio = 0.0
	particles.emitting = false
	return particles


## How fast the spray leaves the rail: the sheet is thrown out at a share of the board's
## speed (a planing hull's spray jet runs at about the boat speed; most of that is along the
## hull, a part sideways and up).
static func set_spray_speed(particles: GPUParticles3D, board_speed_ms: float) -> void:
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 0.6 + 0.12 * board_speed_ms
	process.initial_velocity_max = 1.0 + 0.24 * board_speed_ms


## A one-shot splash: a crown of droplets thrown up and out from a ring on the water. Start
## it with splash() after placing it.
static func make_splash() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.5
	process.emission_ring_inner_radius = 0.2
	process.emission_ring_height = 0.05
	process.direction = Vector3.UP
	process.spread = 30.0
	process.gravity = Vector3(0.0, -9.81, 0.0)
	process.damping_min = AIR_DAMPING_MS2
	process.damping_max = AIR_DAMPING_MS2 * 2.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.scale_curve = _growing_curve()
	process.color_ramp = _fading_ramp(0.85)
	var particles: GPUParticles3D = _make_emitter(process, SPLASH_AMOUNT, SPLASH_LIFETIME_S, 0.09)
	particles.name = "Splash"
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = false
	return particles


## Starts a splash at a point on the water, as big as `strength` (0 to 1: how many droplets,
## and how high they fly).
static func splash(particles: GPUParticles3D, at: Vector3, strength: float) -> void:
	var share: float = clampf(strength, 0.15, 1.0)
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 1.5 + 2.0 * share
	process.initial_velocity_max = 3.0 + 4.0 * share
	process.emission_ring_radius = 0.3 + 0.5 * share
	particles.amount_ratio = share
	particles.global_position = at
	particles.reset_physics_interpolation()
	particles.restart()


## The parts every emitter shares: the droplets live in the world (they stay behind when the
## board moves on), drawn as small soft white dots that always face the camera.
static func _make_emitter(process: ParticleProcessMaterial, amount: int, lifetime_s: float, size_m: float) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.process_material = process
	particles.amount = amount
	particles.lifetime = lifetime_s
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Where the droplets can be, around the emitter, so the camera culls them correctly.
	particles.visibility_aabb = AABB(Vector3(-8.0, -3.0, -8.0), Vector3(16.0, 9.0, 16.0))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size_m, size_m)
	quad.material = _droplet_material()
	particles.draw_pass_1 = quad
	return particles


static func _droplet_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.93, 0.96, 1.0)
	material.albedo_texture = _soft_dot()
	return material


## A round white dot that fades out toward its edge.
static func _soft_dot() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.8))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


## The droplets spread into mist as they fly: they grow to twice their size.
static func _growing_curve() -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.max_value = 2.0
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, 2.0))
	var texture: CurveTexture = CurveTexture.new()
	texture.curve = curve
	return texture


## White, starting at `alpha` and fading to nothing over the droplet's life.
static func _fading_ramp(alpha: float) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, alpha))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
