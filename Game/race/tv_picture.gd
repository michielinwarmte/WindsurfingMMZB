class_name TvPicture
extends Resource
## One picture of the TV director set to the real stream (TvDirectorConfig, TvStreamDirector): which
## camera, where it stands against the board it films, what it is on, and how the board sits in the
## picture. The framing is the stream's, measured on nine slalom heats (Documentation/reports/
## broadcast/data/stream_profile.json): the sail's height and the horizon's place as shares of the
## picture's height, each as its spread (the first quarter, the middle, the third quarter). Each take
## draws its own framing from that spread (TvFraming.from_spread()); the camera's distance and height
## follow from the lens (TvFraming.drone_place(), lens_place()).

## The camera that makes the picture (TvCamera.Shot: CHASE, TRACK, FRONT_SIDE, GROUP, MARK, COMMITTEE,
## FINISH_LINE, BEACH_WIDE, BEACH_TIGHT, PULL_OUT).
@export var shot: TvCamera.Shot = TvCamera.Shot.CHASE
## What it is on, as the stream's readers counted it: "front" (the leader or the lead group), "pack"
## (the chasers, a duel, one rider behind), "fleet" (most of the heat), "mark", "line" (the start or
## the finish line), "scenery".
@export var on: String = "front"
## Where the camera is against the boards, as the readers wrote it: "behind_side", "side",
## "front_side", "shore" (the long lens on the shore), "na" (above, or no boards).
@export var view: String = "behind_side"
## How it moves: "follows" (it travels with the boards), "pan" (it stands and turns with them),
## "static" (it stands and looks at one place), "pull_out" (it rises and goes back).
@export var move: String = "follows"
## Its share of its phase's time in the stream, percent: the weight the director draws it with.
@export var weight_pct: float = 0.0
## The lens: the vertical field of view, degrees. A drone's own: 47, a camera drone's standard wide
## lens, chosen inside the 47 to 59 degrees the lead measured on the stream (drone_position.md); 0 for
## a lens camera on the shore or a boat, whose zoom is worked out from where it stands.
@export var lens_deg: float = 45.0
## The camera's angle round the board: 0 dead behind, 90 abeam, 180 dead ahead, degrees (a mark's
## camera: round the boards' way into the mark, or their way out of it when it is behind them). The readers agreed on the side for only 58 % of the
## seconds: these are the game's choice in the middle of each view until the side is measured.
@export var angle_deg: float = 45.0
## The followed sail's height, percent of the picture's height: x the first quarter, y the middle,
## z the third quarter (the stream's).
@export var sail_pct: Vector3 = Vector3(10.0, 15.0, 15.0)
## Where the horizon sits, percent of the picture's height from the top (the stream's quartiles).
@export var horizon_pct: Vector3 = Vector3(25.0, 35.0, 40.0)
## A drone's height in sail heights, as the lead measured the stream's drones without knowing their
## lens: how far the sail's foot stands below the horizon in the picture, in sail heights
## (drone_position.md; 2.7, the middle of the measured 2.4 to 3.0, where a picture was not measured).
## With it each take puts the sail where that height puts it in the picture (take_framing()); 0: the
## sail's middle at subject_pct.
@export var height_in_sails: float = 0.0
## Where the sail's middle sits, percent of the picture's height from the top, for a picture without
## height_in_sails (the line drones, the beach cam: the game's choice; a lens camera low on the shore
## puts it where its height allows, TvFraming.lens_place()).
@export var subject_pct: float = 50.0
## How quickly the camera glides after the board, seconds (a cut is instant).
@export var glide_s: float = 0.6


## A take's framing, drawn from the stream's spread: Vector3(the sail's share, the horizon's share from
## the top, the sail middle's share from the top), 0 to 1. `z`: a standard normal number, kept within
## one either way (a quarter's spread or a little more). One number for both: a bigger sail goes with a
## horizon higher in the picture, as when a drone that keeps its height in sail heights comes closer and
## looks down more steeply (the game's choice: the readers wrote each picture's sail and horizon, not
## how they go together). `zoom`: the wheel (2: the sail half as tall; the horizon stays).
func take_framing(z: float, zoom: float = 1.0) -> Vector3:
	var held: float = clampf(z, -1.0, 1.0)
	var sail: float = TvFraming.from_spread(sail_pct, held, false, sail_pct.x * 0.5, sail_pct.z * 1.5) / 100.0 / maxf(zoom, 0.05)
	var horizon: float = clampf(TvFraming.from_spread(horizon_pct, -held, false, horizon_pct.x - 5.0, horizon_pct.z + 5.0), 3.0, 92.0) / 100.0
	return Vector3(sail, horizon, subject_share(sail, horizon))


## Where the sail's middle sits for a sail's and a horizon's share: from the drone's height in sail
## heights (the sail's foot that many sails below the horizon), or subject_pct; kept between 35 and
## 75 % of the picture's height.
func subject_share(sail: float, horizon: float) -> float:
	if height_in_sails <= 0.0:
		return subject_pct / 100.0
	return clampf(horizon + height_in_sails * sail - sail * 0.5, 0.35, 0.75)


## The picture's name in the director's log and the check: camera, view, what it is on.
func key() -> String:
	return "%s %s %s" % [camera_kind(), view, on]


## "drone" or "shore_long_lens" (the readers' camera words).
func camera_kind() -> String:
	return "shore_long_lens" if shot == TvCamera.Shot.BEACH_WIDE or shot == TvCamera.Shot.BEACH_TIGHT else "drone"


## True for a camera with a long lens that stands somewhere (the beach cam).
func is_lens_camera() -> bool:
	return lens_deg <= 0.0
