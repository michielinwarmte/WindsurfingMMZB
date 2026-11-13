class_name FrameBudget
extends Node
## Where the main thread's time goes in a frame, for --measure (E17.S01 T6, 13 November 2026).
##
## Two markers time the physics ticks and the frame's scripts: this node runs first in each
## (the lowest priority number) and its child `_End` runs last. Everything between them is the
## game's own work on the main thread: in a physics tick the boards' physics (the threads' work
## waited for), the skippers, the race's checks and the visuals; in a frame the cameras, the HUD,
## the effects. What is left of a frame is the engine's: drawing on the processor (finding what is
## on the screen, building the graphics card's lists of work) and waiting for the graphics card.
##
## main.gd adds it when a measurement starts and reads it once at the end.

const FIRST: int = -1000000
const LAST: int = 1000000

var physics_us: int = 0  ## the physics ticks' time, all ticks together
var physics_ticks: int = 0
var process_us: int = 0  ## the frames' scripts' time, all frames together

var _physics_start_us: int = 0
var _process_start_us: int = 0


func _ready() -> void:
	process_priority = FIRST
	process_physics_priority = FIRST
	var end: _End = _End.new()
	end.name = "End"
	end.budget = self
	end.process_priority = LAST
	end.process_physics_priority = LAST
	add_child(end)


## Starts the count again (after the warm-up).
func reset() -> void:
	physics_us = 0
	physics_ticks = 0
	process_us = 0


func _physics_process(_delta: float) -> void:
	_physics_start_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	_process_start_us = Time.get_ticks_usec()


func end_of_physics_tick() -> void:
	physics_us += Time.get_ticks_usec() - _physics_start_us
	physics_ticks += 1


func end_of_frame_scripts() -> void:
	process_us += Time.get_ticks_usec() - _process_start_us


## The marker that runs last.
class _End extends Node:
	var budget: FrameBudget

	func _physics_process(_delta: float) -> void:
		budget.end_of_physics_tick()

	func _process(_delta: float) -> void:
		budget.end_of_frame_scripts()
