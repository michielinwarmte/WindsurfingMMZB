class_name RaceMoment
extends RefCounted
## Something the race story saw that the commentator may talk about (BANK_FORMAT.md, "The moments"):
## which moment it is, the board it is about and the other board in it, how big it is, and the words
## for the slots that come from the moment itself (which mark, which leg). RaceStory makes them; the
## CommentaryDirector picks a line for one.

## One of CommentaryBank.MOMENTS.
var moment: String = ""
## The race number of the board it is about ({rider}); -1 for none (the gun, the fleet lining up).
var board: int = -1
## The other board in it ({rider2}): the one overtaken, chased, fought, nearly hit; -1 for none.
var board2: int = -1
## How big it is, as the commentator's level: 1 calm, 2 the normal race voice, 3 lifted, 4 shouting.
## The director takes the line whose level is nearest.
var level: int = 2
## The boards in it are close together (the `close` need).
var close: bool = false
## The place it is about ({place}): the board's place, or the place fought for; 0: the board's place now.
var place: int = 0
## {mark}: which mark ("first", "last"), when the moment is at a mark; "" otherwise.
var mark_word: String = ""
## Tactics: the board is to windward (+1) or to leeward (-1) of the other board or of its straight line
## to the mark (0: neither), and it sails in another sail's dirty wind (the `windward`, `leeward` and
## `dirty_air` needs).
var windward: int = 0
var dirty: bool = false
## A quiet moment (identify, speed, leader, rundown, filler, camera, unsure, tactics, tension, form,
## conditions): small talk between events.
var quiet: bool = false
## The race clock when it happened, seconds (negative before the gun).
var race_s: float = 0.0
## The director's clock when it heard it, seconds (its lateness is measured from here).
var heard_s: float = 0.0
## What the story measured, in a few words (for the transcript, never said): "kept 84 % of its speed".
var note: String = ""


static func make(what: String, about: int = -1, size: int = 2, at_race_s: float = 0.0) -> RaceMoment:
	var made: RaceMoment = RaceMoment.new()
	made.moment = what
	made.board = about
	made.level = clampi(size, CommentaryBank.LOWEST_LEVEL, CommentaryBank.HIGHEST_LEVEL)
	made.race_s = at_race_s
	return made


## "fall Mara (2nd)" for the transcript and the tests.
func describe(look: RaceLook = null) -> String:
	var who: String = ""
	if board >= 0:
		who = " " + (look.name_of(board) if look != null else "#%d" % board)
	if board2 >= 0:
		who += " / " + (look.name_of(board2) if look != null else "#%d" % board2)
	return moment + who
