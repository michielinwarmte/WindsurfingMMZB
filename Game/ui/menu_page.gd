class_name MenuPage
extends Control
## A page of a menu that covers the screen (settings, controls, how to sail, a question):
## open() shows it and puts the keyboard/gamepad focus on its first control; Esc (or the
## gamepad's B button: the "ui_cancel" action) or close() hides it and sends `closed`, so
## the menu that opened it can show itself again. The start menu and the pause menu both
## use the same pages.

signal closed


## Shows the page and focuses its first control.
func open() -> void:
	show()
	var first: Control = first_focus()
	if first != null:
		first.grab_focus()


## Hides the page and tells the menu that opened it.
func close() -> void:
	hide()
	closed.emit()


## The control that gets the focus when the page opens. Each page says which.
func first_focus() -> Control:
	return null


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
