class_name TvFraming
extends RefCounted
## The TV director's picture maths (TvCamera, TvStreamDirector). A picture of the real stream is
## written down by what can be seen on it, not in metres (Documentation/reports/broadcast/
## SHOT_NOTES_GUIDE.md): how tall the followed sail is, as a share of the picture's height, and where
## the horizon sits, as a share of the height from the top. The stream's lenses and distances are not
## known; the picture is. So the game works back from the picture:
## - a drone has its lens (its vertical field of view, a number of the config): the distance from the
##   board and the height above the water that give the picture follow (drone_place());
## - a lens camera stands where it can (on the shore, on a camera boat): its lens (the zoom) and its
##   height follow from its distance to the board (lens_place()).
## Both look down by the pitch that puts the horizon where the stream has it (pitch_for_horizon()).
## The shares are of the picture's HEIGHT: the game's camera keeps its vertical field of view in any
## window shape (Camera3D.KEEP_HEIGHT), so a picture holds in a 16:9 window and in Max's 3137 x 1263.
##
## The geometry (heights above the water, metres): the camera at height y, the board at a level
## distance d, its sail from the water (0) to the mast top, which stands top_m above the water and
## leans toward_m towards the camera (a slalom rig at speed is raked back and leaned to windward, so
## its top is lower than the mast is long, and from behind it shows shorter than from ahead: the
## lead's measurement of the stream, drone_position.md). The camera looks down by the pitch p
## (radians, + down) and is level sideways (no roll). A point seen at the elevation e (radians above
## level, from the camera) sits tan(e + p) / tan(fov / 2) of half the picture's height above its
## middle (a pinhole camera); its share from the top is (1 - that) / 2. The horizon is level and far
## away (e = 0): its share from the top is (1 - tan(p) / tan(fov / 2)) / 2. Plain numbers in and out,
## for the tests.

## The normal distribution's quarter point: a quarter of the draws lie below -Q, a quarter above +Q.
const QUARTER_Z: float = 0.6744898


## The pitch (radians, + looking down) that puts the horizon at this share of the picture's height
## from the top (0.5: the middle, the camera level; less: the camera looks down).
static func pitch_for_horizon(fov_deg: float, horizon_share: float) -> float:
	return atan((1.0 - 2.0 * horizon_share) * tan(deg_to_rad(fov_deg) * 0.5))


## The share of the picture's height from the top at which a point seen this far above level
## (radians) sits, the camera looking down by pitch_rad.
static func share_from_top(fov_deg: float, pitch_rad: float, elevation_rad: float) -> float:
	var angle: float = clampf(elevation_rad + pitch_rad, -1.55, 1.55)
	return (1.0 - tan(angle) / tan(deg_to_rad(fov_deg) * 0.5)) * 0.5


## How tall a sail stands in the picture, as a share of its height: the sail from the water to its
## top top_m up, its foot at a level distance distance_m from a camera height_m above the water that
## looks down by pitch_rad, its top toward_m nearer the camera than its foot.
static func sail_share(fov_deg: float, pitch_rad: float, distance_m: float, height_m: float, top_m: float, toward_m: float = 0.0) -> float:
	var top: float = share_from_top(fov_deg, pitch_rad, atan2(top_m - height_m, maxf(distance_m - toward_m, 0.1)))
	var foot: float = share_from_top(fov_deg, pitch_rad, atan2(-height_m, distance_m))
	return foot - top


## A drone with its lens: where it must be for a picture. Vector3(the level distance to the board m,
## the height above the water m, the pitch rad). The sail's middle sits at subject_share of the
## picture's height from the top; when that would put the drone lower than lowest_m it stays at
## lowest_m and the board sits where the sail's share and the horizon put it. top_m and toward_m: the
## sail's top, its height above the water and its lean towards the camera (sail_share()).
static func drone_place(fov_deg: float, top_m: float, sail_share_wanted: float, horizon_share: float, subject_share: float, lowest_m: float, toward_m: float = 0.0) -> Vector3:
	var pitch: float = pitch_for_horizon(fov_deg, horizon_share)
	var half_tan: float = tan(deg_to_rad(fov_deg) * 0.5)
	# The sail's middle is seen this far above level: its angle above the picture's middle less the pitch.
	var middle_rad: float = atan((1.0 - 2.0 * subject_share) * half_tan) - pitch
	var wanted: float = clampf(sail_share_wanted, 0.002, 0.95)
	# Halving the range of distances (on a log scale): the sail gets smaller as the drone goes farther.
	var near_m: float = 0.3
	var far_m: float = 30000.0
	for i: int in 60:
		var distance_m: float = sqrt(near_m * far_m)
		var height_m: float = maxf(top_m * 0.5 - (distance_m - toward_m * 0.5) * tan(middle_rad), lowest_m)
		if sail_share(fov_deg, pitch, distance_m, height_m, top_m, toward_m) > wanted:
			near_m = distance_m
		else:
			far_m = distance_m
	var found_m: float = sqrt(near_m * far_m)
	return Vector3(found_m, maxf(top_m * 0.5 - (found_m - toward_m * 0.5) * tan(middle_rad), lowest_m), pitch)


## A lens camera that stands a level distance from the board (on the shore, on a camera boat): the
## lens and the height for a picture. Vector3(the vertical field of view in degrees, the height above
## the water m, the pitch rad). Its height puts the sail's middle at subject_share, kept between
## lowest_m and highest_m (past them the board sits where it may). Between the longest lens
## (fov_min_deg) and the widest (fov_max_deg): a board too far or too near for them comes out smaller
## or bigger than asked.
static func lens_place(distance_m: float, top_m: float, sail_share_wanted: float, horizon_share: float, subject_share: float,
		lowest_m: float, highest_m: float, fov_min_deg: float, fov_max_deg: float) -> Vector3:
	var wanted: float = clampf(sail_share_wanted, 0.002, 0.95)
	var narrow: float = fov_min_deg
	var wide: float = fov_max_deg
	for i: int in 50:
		var fov: float = sqrt(narrow * wide)
		var pitch: float = pitch_for_horizon(fov, horizon_share)
		var height_m: float = _lens_height(fov, pitch, distance_m, top_m, subject_share, lowest_m, highest_m)
		# A wider lens makes the sail smaller.
		if sail_share(fov, pitch, distance_m, height_m, top_m) > wanted:
			narrow = fov
		else:
			wide = fov
	var found: float = sqrt(narrow * wide)
	var found_pitch: float = pitch_for_horizon(found, horizon_share)
	return Vector3(found, _lens_height(found, found_pitch, distance_m, top_m, subject_share, lowest_m, highest_m), found_pitch)


static func _lens_height(fov_deg: float, pitch_rad: float, distance_m: float, top_m: float, subject_share: float, lowest_m: float, highest_m: float) -> float:
	var middle_rad: float = atan((1.0 - 2.0 * subject_share) * tan(deg_to_rad(fov_deg) * 0.5)) - pitch_rad
	return clampf(top_m * 0.5 - distance_m * tan(middle_rad), lowest_m, highest_m)


## What a camera really shows of a sail: Vector3(the sail's share of the picture's height, the
## horizon's share from the top, the sail foot's share from the top). `camera`: the camera's transform
## (it looks down its -Z), `fov_deg` its vertical field of view; `foot` and `top`: the mast's foot and
## top in the world. The sail's and the foot's shares are NAN when the sail is behind the camera; the
## horizon's share is under 0 or over 1 when the horizon is out of the picture (above or below it).
## (foot - horizon) / sail is the camera's height in sail heights, as the lead measured the stream's
## drones without knowing their lens (drone_position.md).
static func measure(camera: Transform3D, fov_deg: float, foot: Vector3, top: Vector3) -> Vector3:
	var half_tan: float = tan(deg_to_rad(fov_deg) * 0.5)
	var forward: Vector3 = -camera.basis.z.normalized()
	var pitch: float = asin(clampf(-forward.y, -1.0, 1.0))
	var horizon: float = (1.0 - tan(pitch) / half_tan) * 0.5
	var to_camera: Transform3D = Transform3D(camera.basis.orthonormalized(), camera.origin).affine_inverse()
	var near_foot: Vector3 = to_camera * foot
	var near_top: Vector3 = to_camera * top
	if near_foot.z > -0.05 or near_top.z > -0.05:
		return Vector3(NAN, horizon, NAN)
	var foot_up: float = near_foot.y / -near_foot.z / half_tan
	var top_up: float = near_top.y / -near_top.z / half_tan
	return Vector3((top_up - foot_up) * 0.5, horizon, (1.0 - foot_up) * 0.5)


## The camera's angle round a board: 0 dead behind it, 90 abeam, 180 dead ahead (degrees, either
## side). `forward`: the board's heading.
static func angle_round(forward: Vector3, board_at: Vector3, eye: Vector3) -> float:
	var to_eye: Vector3 = Vector3(eye.x - board_at.x, 0.0, eye.z - board_at.z)
	var back: Vector3 = Vector3(-forward.x, 0.0, -forward.z)
	if to_eye.length() < 0.01 or back.length() < 0.01:
		return 0.0
	return rad_to_deg(acos(clampf(back.normalized().dot(to_eye.normalized()), -1.0, 1.0)))


## Where a camera stands round a board, as an offset from it: at an angle round it (0 behind, 90
## abeam, 180 ahead), on its starboard (side +1) or port (-1) side, a level distance away, a height up.
## `forward`: the board's heading, level.
static func offset_round(forward: Vector3, angle_deg: float, side: float, distance_m: float, height_m: float) -> Vector3:
	var level: Vector3 = Vector3(forward.x, 0.0, forward.z)
	level = level.normalized() if level.length() > 0.001 else Vector3.FORWARD
	# Starboard is the board's local +X: its heading crossed with up.
	var starboard: Vector3 = level.cross(Vector3.UP)
	var angle_rad: float = deg_to_rad(angle_deg)
	var away: Vector3 = -level * cos(angle_rad) + starboard * side * sin(angle_rad)
	return away * distance_m + Vector3.UP * height_m


## The point a camera at `eye` looks at to face `toward` sideways (level) and look down by pitch_rad:
## a point on that line as far away as `toward` is.
static func aim_point(eye: Vector3, toward: Vector3, pitch_rad: float) -> Vector3:
	var level: Vector3 = Vector3(toward.x - eye.x, 0.0, toward.z - eye.z)
	var reach_m: float = maxf(level.length(), 1.0)
	level = level.normalized() if level.length() > 0.001 else Vector3.FORWARD
	return eye + (level * cos(pitch_rad) + Vector3.DOWN * sin(pitch_rad)) * reach_m / maxf(cos(pitch_rad), 0.1)


## A number drawn from a measured spread, its quartiles (x: the first quarter p25, y: the median,
## z: the third quarter p75): below the median a normal curve whose quarter point is p25, above it one
## whose three-quarter point is p75, so a quarter of the draws come out under p25, half under the
## median and a quarter over p75, as measured. With on_log the curves are on a log scale (take
## lengths: a few long takes, none under zero). `z`: a standard normal number
## (RandomNumberGenerator.randfn()). Kept between lowest and highest.
static func from_spread(quartiles: Vector3, z: float, on_log: bool, lowest: float, highest: float) -> float:
	var value: float = quartiles.y
	if on_log and quartiles.x > 0.0 and quartiles.y > 0.0 and quartiles.z > 0.0:
		var spread: float = log(quartiles.y / quartiles.x) if z < 0.0 else log(quartiles.z / quartiles.y)
		value = quartiles.y * exp(z * spread / QUARTER_Z)
	else:
		var spread_lin: float = (quartiles.y - quartiles.x) if z < 0.0 else (quartiles.z - quartiles.y)
		value = quartiles.y + z * spread_lin / QUARTER_Z
	return clampf(value, lowest, highest)
