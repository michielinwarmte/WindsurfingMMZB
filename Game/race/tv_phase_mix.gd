class_name TvPhaseMix
extends Resource
## One phase of a heat in the TV director set to the real stream (TvDirectorConfig): how long its
## takes last and the pictures it cuts between, each with its share of the phase's time in the stream.

## How long a take lasts, seconds of the picture: x the first quarter, y the middle, z the third
## quarter. Drawn per take from that spread (TvFraming.from_spread(), on a log scale), between
## shortest_s and longest_s.
@export var take_s: Vector3 = Vector3(5.0, 8.1, 12.2)
@export var shortest_s: float = 2.0
@export var longest_s: float = 56.0
## The pictures the director draws from (by their weight_pct), never the same one twice in a row.
@export var pictures: Array[TvPicture] = []


## The pictures that are on this kind of subject ("front", "pack", ...); all of them for "".
func pictures_on(subject: String) -> Array[TvPicture]:
	var found: Array[TvPicture] = []
	for picture: TvPicture in pictures:
		if subject == "" or picture.on == subject:
			found.append(picture)
	return found


## The first picture made by this camera on this subject (any subject for ""), or null.
func picture_of(shot: TvCamera.Shot, subject: String = "") -> TvPicture:
	for picture: TvPicture in pictures:
		if picture.shot == shot and (subject == "" or picture.on == subject):
			return picture
	return null
