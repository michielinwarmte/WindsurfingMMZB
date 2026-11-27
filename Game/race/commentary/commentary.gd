class_name Commentary
extends Node
## The race commentator in a sailing scene (Documentation/reports/broadcast/PLAN.md, P6): the race
## story (RaceStory) looks at the race every look_every_s of race time and tells the commentary
## director (CommentaryDirector) what happened; the director picks the line and the moment to say it,
## about the board the camera shows; the line goes on the screen as a subtitle (CommentarySubtitles)
## and out through line_started, where a sound player can be attached later (each line a sound file,
## after the commentator's yes: P7).
##
## Watch mode makes one now (WatchMode, the key V); it is made to work in the player's own race too:
## without a TV camera the board on the screen is the board the camera follows, and the player's own
## board is named by player_name (empty: its name is not said; "You" would read badly).
## The director runs on real seconds (watching at 4x he does not talk four times as fast: he says less
## of the race); the story on the race's clock. Frozen (the tree paused), both stop and the subtitle
## stays. Nothing here touches the race or the physics.
## For screenshots of the subtitles' place: --subtitle_test=<words> keeps those words on the screen.

signal line_started(id: String, text: String, seconds: float, level: int)

const CONFIG_PATH: String = "res://config/commentary_default.tres"

var runner: RaceRunner = null
## The TV camera, when there is one (its shot and the board it is on); null: the board followed.
var tv: TvCamera = null
var config: CommentaryConfig = null
var bank: CommentaryBank = null
var director: CommentaryDirector = null
var story: RaceStory = null
var subtitles: CommentarySubtitles = null
## The commentary talks (on) or is quiet (off); the subtitles are shown on this screen level (shown).
var on: bool = false
var shown: bool = true
## The name said for the player's own board ("" says no name for it).
var player_name: String = ""

var _look: RaceLook = null
var _look_left_s: float = 0.0
var _last_real_us: int = 0
var _race: RaceSim = null
## Per board of the race: the name to say, its sail's brand and colour (the same all race).
var _names: PackedStringArray = PackedStringArray()
var _brands: PackedStringArray = PackedStringArray()
var _colours: PackedColorArray = PackedColorArray()
## --subtitle_test=<words>: these words always on the screen (for screenshots).
var _test_words: String = ""


func _init() -> void:
	name = "Commentary"
	# Frozen (P), the story and the director stop with the race and the subtitle stays.
	process_mode = Node.PROCESS_MODE_PAUSABLE


## The race to talk about, the TV camera (or null) and the HUD the subtitles go on (or null: none).
func setup(race_runner: RaceRunner, tv_camera: TvCamera, hud: Hud) -> void:
	runner = race_runner
	tv = tv_camera
	config = load(CONFIG_PATH) as CommentaryConfig
	bank = CommentaryBank.load_file()
	bank.warn_problems()
	director = CommentaryDirector.new(bank, config)
	director.line_started.connect(_on_line_started)
	if hud != null:
		subtitles = CommentarySubtitles.new()
		subtitles.put_on(hud)
	runner.restarted.connect(new_race)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--subtitle_test="):
			_test_words = arg.trim_prefix("--subtitle_test=")
	_last_real_us = Time.get_ticks_usec()
	new_race()


## The commentary on (it talks) or off (quiet, the subtitle goes).
func set_on(talking: bool) -> void:
	if talking == on:
		return
	on = talking
	if not on:
		director.stop()
		director.new_race()
		if subtitles != null:
			subtitles.clear()
	_show()


## The subtitles shown on this screen (watch mode's clean screen has none); the commentary goes on.
func set_shown(on_screen: bool) -> void:
	shown = on_screen
	_show()


## A new race (R, Shift+R, a race after a race): a new story; what was waiting is forgotten.
func new_race() -> void:
	story = RaceStory.new(config)
	_look = null
	_look_left_s = 0.0
	_race = null
	director.new_race()
	if subtitles != null:
		subtitles.clear()


func _show() -> void:
	if subtitles != null:
		subtitles.modulate.a = 1.0 if shown else 0.0


# ---------------------------------------------------------------- every tick and every frame

## The race is looked at every look_every_s of its clock (the story always follows it, so the
## commentary switched on mid-race knows the race).
func _physics_process(delta: float) -> void:
	if runner == null or runner.race == null:
		return
	if runner.race != _race:
		_race = runner.race
		_learn_the_boards()
	_look_left_s -= delta
	if _look_left_s > 0.0:
		return
	_look_left_s = config.look_every_s
	_look = look_now()
	var moments: Array[RaceMoment] = story.look(_look)
	if on:
		director.hear(moments)


func _process(_delta: float) -> void:
	var now_us: int = Time.get_ticks_usec()
	var real_dt: float = clampf((now_us - _last_real_us) / 1e6, 0.0, 0.25)
	_last_real_us = now_us
	if _test_words != "" and subtitles != null:
		subtitles.show_line(_test_words, 1.0)
		return
	if not on or director == null:
		return
	_tell_the_camera()
	director.step(real_dt, _look, story)
	if subtitles != null:
		subtitles.step(real_dt)


## The board on the screen and the kind of picture, for the director.
func _tell_the_camera() -> void:
	if tv != null and tv.is_on():
		director.focus = tv.focus if tv.focus >= 0 else runner.followed_index()
		director.camera_wide = is_wide(tv.shot)
		director.camera_close = is_close(tv.shot)
	else:
		director.focus = runner.followed_index()
		director.camera_wide = false
		director.camera_close = false


## A wide shot (the boards small: the helicopter, the drone overhead, the start's wide drone, the
## committee boat and the finish line down their lines).
static func is_wide(shot: TvCamera.Shot) -> bool:
	return shot in [TvCamera.Shot.ORBIT, TvCamera.Shot.OVERHEAD, TvCamera.Shot.START_WIDE, TvCamera.Shot.COMMITTEE, TvCamera.Shot.FINISH_LINE]


## A close shot (the board big: the chase drone, the drone beside it, the group of a fight).
static func is_close(shot: TvCamera.Shot) -> bool:
	return shot in [TvCamera.Shot.CHASE, TvCamera.Shot.TRACK, TvCamera.Shot.GROUP]


func _on_line_started(id: String, text: String, seconds: float, level: int) -> void:
	if subtitles != null:
		subtitles.show_line(text, maxf(seconds + config.subtitle_linger_s, config.subtitle_min_s))
	line_started.emit(id, text, seconds, level)


# ---------------------------------------------------------------- the race as the commentator sees it

## The race now (RaceLook): the race's facts and every board on the water.
func look_now() -> RaceLook:
	var race: RaceSim = runner.race
	var telemetry: Array[Telemetry] = []
	var dirty: PackedFloat32Array = PackedFloat32Array()
	for i: int in race.board_count():
		var node: WindsurferNode = runner.board_node(i)
		var on_water: bool = node != null and node.visible and node.sim != null
		telemetry.append(node.telemetry() if on_water else null)
		dirty.append(runner.shadow_deficit(node) if on_water else 0.0)
	return RaceLook.of_race(race, telemetry, _names, _brands, _colours, dirty)


## Each board's name to say, its sail's brand and its sail's colour, as the game shows them.
func _learn_the_boards() -> void:
	_names.clear()
	_brands.clear()
	_colours.clear()
	for i: int in _race.board_count():
		var node: WindsurferNode = runner.board_node(i)
		_names.append(player_name if i == runner.player_index() else _race.board_name(i))
		_brands.append(sail_brand_of(node))
		_colours.append(sail_colour_of(node))


## The brand on a board's sail as the game names it ("" for a board on the default rig, which shows no
## brand).
static func sail_brand_of(node: WindsurferNode) -> String:
	if node == null or node.gear == null or node.gear.sail == null or node.gear.sail.brand == null:
		return ""
	return node.gear.sail.brand.name


## The colour a board's sail shows: an AI skipper's own colour (the race tints the sail's cloth with
## it), else the sail's own cloth; TRANSPARENT when it is not known.
static func sail_colour_of(node: WindsurferNode) -> Color:
	if node == null:
		return Color.TRANSPARENT
	if node.skipper != null:
		var colour: Color = node.skipper.sail_colour()
		if colour.r + colour.g + colour.b < 2.999:
			return colour
	if node.gear != null and node.gear.sail != null:
		return node.gear.sail.cloth_colour()
	return Color.TRANSPARENT
