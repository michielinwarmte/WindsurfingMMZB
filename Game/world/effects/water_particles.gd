class_name WaterParticles
extends RefCounted
## The particle emitters for water thrown into the air: the spray sheets off a planing board's
## rails, the plume behind its tail, the splash of a hard landing or a fall, and the spray the wind
## tears off the crests in a strong wind. All are GPU particles (Godot moves them on the graphics
## card): soft blobs of water drawn by res://world/effects/spray.gdshader (lit by the sun, never a
## big flat card near the camera), that fly out, fall under gravity, slow down in the air and fade.
## The emitters only make the particles; effects.gd decides where, when and how much.
##
## What they are tuned to (Documentation/reports/waves/board_fx.md): the photos of slalom boards in
## Documentation/images/Real life photos/: a planing board throws a low, flat, very white fan off the
## leeward rail from about the middle of the board back past the tail, below knee height, trailing
## several board lengths behind; the water leaves the hull nearly where it is (a planing hull's spray
## jet is thrown sideways and up, it does not keep the board's speed), so the fan stays behind as the
## board moves on. The sheet breaks straight into fine drops on a planing hull (Savitsky's whisker
## spray; Ai, Acosta and Harrison 1964), drawn as blobs of many drops.

## The spray sheet off a rail: up to this many blobs alive, each living this long (about the time a
## drop thrown 0.3 m up takes to fall back: 2 x sqrt(2 x 0.3 / 9.81) = 0.5 s).
const SPRAY_AMOUNT: int = 450
const SPRAY_LIFETIME_S: float = 0.55
## The plume behind the tail and the fin at speed.
const PLUME_AMOUNT: int = 160
const PLUME_LIFETIME_S: float = 0.8
## A splash: this many blobs at full strength, living this long.
const SPLASH_AMOUNT: int = 220
const SPLASH_LIFETIME_S: float = 1.3
## A burst of spray torn off a breaking crest by the wind: a streak a few metres long downwind
## (Beaufort 7 and 8: foam and spray blown in streaks along the wind).
const CREST_AMOUNT: int = 70
const CREST_LIFETIME_S: float = 1.2
## Air slows the drops down (m/s per second).
const AIR_DAMPING_MS2: float = 1.5
## The spray sheet is thrown out at this share of the board's speed (the slowest and the fastest
## drops; plus a little at any speed). A planing hull's spray jet leaves at about the boat's speed
## relative to the hull, mostly along it; the part across and up that we see is a fraction of it.
## Chosen so that at 12 m/s the fastest drops rise about 0.35 m (knee height, as in the photos).
const SPRAY_THROW_MIN_SHARE: float = 0.14
const SPRAY_THROW_MAX_SHARE: float = 0.30
## The drops keep this share of the hull's own velocity (water pushed aside, mostly not carried
## along): the fan trails (1 - 0.35) x 11 m/s x 0.55 s = about 4 m behind the root at 21 knots, one to two
## board lengths as in the photos.
const SPRAY_INHERIT: float = 0.35

## A spray emitter for one rail (side -1 = port, +1 = starboard). Placed at the spray root in
## the board's axes, it throws a sheet outward over the rail and up, from a stretch of the rail.
## Its emission is set with amount_ratio (0 = none) and the throw speed with set_spray_speed().
static func make_spray(side: float) -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	# A stretch of the rail around the spray root, 0.8 m long (the wet rail of a planing board).
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.03, 0.02, 0.4)
	# Out over the rail and up, a little aft (the board's +Z is aft): a low fan.
	process.direction = Vector3(side * 0.8, 0.55, 0.25).normalized()
	process.spread = 22.0
	process.flatness = 0.4
	process.gravity = Vector3(0.0, -9.81, 0.0)
	process.damping_min = AIR_DAMPING_MS2
	process.damping_max = AIR_DAMPING_MS2 * 2.0
	process.inherit_velocity_ratio = SPRAY_INHERIT
	process.particle_flag_align_y = true
	# Blobs of 14 to 34 cm (each a cloud of drops), spreading into mist as they fly; many, big and
	# faint, so they overlap into a sheet instead of reading as single dots.
	process.scale_min = 0.14
	process.scale_max = 0.34
	process.scale_curve = _growing_curve(0.7, 2.0)
	process.color_ramp = _fading_ramp(0.32)
	var particles: GPUParticles3D = _make_emitter(process, SPRAY_AMOUNT, SPRAY_LIFETIME_S)
	particles.name = "SprayPort" if side < 0.0 else "SprayStarboard"
	set_spray_speed(particles, 0.0)
	particles.amount_ratio = 0.0
	particles.emitting = false
	return particles


## How fast the spray leaves the rail, from the board's speed (see SPRAY_THROW_MIN_SHARE).
static func set_spray_speed(particles: GPUParticles3D, board_speed_ms: float) -> void:
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 0.4 + SPRAY_THROW_MIN_SHARE * board_speed_ms
	process.initial_velocity_max = 0.8 + SPRAY_THROW_MAX_SHARE * board_speed_ms


## The plume behind the tail and the fin of a board at speed (the "rooster tail"): white water
## thrown up and back from the transom, mistier and slower than the rail's sheet. Placed at the
## middle of the transom in the board's axes; set with amount_ratio and set_plume_speed().
static func make_plume() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.12, 0.02, 0.05)
	# Up and aft.
	process.direction = Vector3(0.0, 0.75, 0.65).normalized()
	process.spread = 22.0
	process.gravity = Vector3(0.0, -9.81, 0.0)
	process.damping_min = AIR_DAMPING_MS2 * 2.0
	process.damping_max = AIR_DAMPING_MS2 * 3.0
	process.inherit_velocity_ratio = SPRAY_INHERIT
	process.particle_flag_align_y = true
	process.scale_min = 0.16
	process.scale_max = 0.36
	process.scale_curve = _growing_curve(0.6, 2.2)
	process.color_ramp = _fading_ramp(0.3)
	var particles: GPUParticles3D = _make_emitter(process, PLUME_AMOUNT, PLUME_LIFETIME_S)
	particles.name = "TailPlume"
	set_plume_speed(particles, 0.0)
	particles.amount_ratio = 0.0
	particles.emitting = false
	return particles


## The plume rises at a share of the board's speed: about 0.4 m high at 14 m/s (by eye, the photos).
static func set_plume_speed(particles: GPUParticles3D, board_speed_ms: float) -> void:
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 0.3 + 0.10 * board_speed_ms
	process.initial_velocity_max = 0.6 + 0.22 * board_speed_ms


## A one-shot splash: a crown of water thrown up and out from a ring on the water. Start it with
## splash() after placing it.
static func make_splash() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.5
	process.emission_ring_inner_radius = 0.2
	process.emission_ring_height = 0.05
	process.direction = Vector3.UP
	process.spread = 35.0
	process.gravity = Vector3(0.0, -9.81, 0.0)
	process.damping_min = AIR_DAMPING_MS2
	process.damping_max = AIR_DAMPING_MS2 * 2.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.particle_flag_align_y = true
	process.scale_min = 0.12
	process.scale_max = 0.32
	process.scale_curve = _growing_curve(0.7, 1.8)
	process.color_ramp = _fading_ramp(0.5)
	var particles: GPUParticles3D = _make_emitter(process, SPLASH_AMOUNT, SPLASH_LIFETIME_S)
	particles.name = "Splash"
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.emitting = false
	return particles


## How a splash of this strength (0 to 1) throws its water: (the fastest drops' speed m/s, the
## ring's radius m, the share of the drops, the spread in degrees from straight up). A weak slap
## throws a low, wide fan (the hull slapping flat water sideways), a strong one a tall crown: the
## fastest drops at 2.5 m/s rise 0.3 m, at 6 m/s 1.8 m (v^2 / 2g; a body falling 2 m hits the water at
## 6.3 m/s and a splash rises about as high as the fall: an estimate, no measured source found).
static func splash_shape(strength: float) -> Vector4:
	var share: float = clampf(strength, 0.15, 1.0)
	return Vector4(2.5 + 3.5 * share, 0.3 + 0.5 * share, share, lerpf(70.0, 30.0, share))


## Starts a splash at a point on the water, as big as `strength` (splash_shape()).
static func splash(particles: GPUParticles3D, at: Vector3, strength: float) -> void:
	var shape: Vector4 = splash_shape(strength)
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	process.initial_velocity_min = 0.35 * shape.x
	process.initial_velocity_max = shape.x
	process.emission_ring_radius = shape.y
	process.emission_ring_inner_radius = 0.4 * shape.y
	process.spread = shape.w
	particles.amount_ratio = shape.z
	particles.global_position = at
	particles.reset_physics_interpolation()
	particles.restart()


## A one-shot burst of spray torn off a breaking crest and blown downwind (crest_spray()).
static func make_crest_spray() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	# Along a stretch of crest 1.6 m long (the burst is turned across the wind when it starts).
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(1.0, 0.05, 0.3)
	# Downwind (the emitter's +Z, turned along the wind when a burst starts) and up.
	process.direction = Vector3(0.0, 0.5, 1.0).normalized()
	process.spread = 20.0
	process.damping_min = AIR_DAMPING_MS2
	process.damping_max = AIR_DAMPING_MS2 * 2.0
	process.particle_flag_align_y = true
	process.scale_min = 0.15
	process.scale_max = 0.35
	process.scale_curve = _growing_curve(0.6, 3.0)
	process.color_ramp = _fading_ramp(0.5)
	var particles: GPUParticles3D = _make_emitter(process, CREST_AMOUNT, CREST_LIFETIME_S)
	particles.name = "CrestSpray"
	particles.local_coords = false
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.emitting = false
	return particles


## Starts a burst on a crest at `at`, blown along `downwind_xz` (unit) by a wind of `wind_ms` at
## 10 m: the drops leave at about a third of the wind (the surface's drops start slow and are blown
## on) and the wind keeps pushing them (a drag of about 3 m/s^2 downwind on a 1 mm drop at 15 m/s: an
## estimate), so they fly a few metres downwind and fall back within a second.
static func crest_spray(particles: GPUParticles3D, at: Vector3, downwind_xz: Vector2, wind_ms: float) -> void:
	var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	var downwind: Vector3 = Vector3(downwind_xz.x, 0.0, downwind_xz.y)
	process.initial_velocity_min = 0.2 * wind_ms
	process.initial_velocity_max = 0.4 * wind_ms
	process.gravity = Vector3(0.0, -9.81, 0.0) + downwind * 3.0
	particles.global_transform = Transform3D(Basis(Vector3.UP, atan2(downwind_xz.x, downwind_xz.y)), at)
	particles.reset_physics_interpolation()
	particles.restart()


## The parts every emitter shares: the drops live in the world (they stay behind when the board
## moves on), drawn by the spray shader; one blob is a unit quad scaled by the particle's scale.
static func _make_emitter(process: ParticleProcessMaterial, amount: int, lifetime_s: float) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.process_material = process
	particles.amount = amount
	particles.lifetime = lifetime_s
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Where the drops can be, around the emitter, so the camera culls them correctly.
	particles.visibility_aabb = AABB(Vector3(-8.0, -3.0, -8.0), Vector3(16.0, 9.0, 16.0))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = droplet_material()
	particles.draw_pass_1 = quad
	return particles


## The one material every emitter draws with (res://world/effects/spray.gdshader; loaded once and
## shared, Godot keeps loaded resources).
static func droplet_material() -> ShaderMaterial:
	return load("res://world/effects/spray_material.tres") as ShaderMaterial


## The blobs spread into mist as they fly: from `start` to `end` times their size.
static func _growing_curve(start: float, end: float) -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.max_value = maxf(end, start)
	curve.add_point(Vector2(0.0, start))
	curve.add_point(Vector2(1.0, end))
	var texture: CurveTexture = CurveTexture.new()
	texture.curve = curve
	return texture


## White, rising to `alpha` at once and fading to nothing over the drop's life.
static func _fading_ramp(alpha: float) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.08, Color(1.0, 1.0, 1.0, alpha))
	gradient.add_point(0.5, Color(1.0, 1.0, 1.0, alpha * 0.6))
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
