class_name ConfirmDialog
extends MenuPage
## A yes-or-no question over a dimmed screen ("Quit the game?"). Yes sends `confirmed`;
## No, Esc or the gamepad's B close it (`closed`). The focus starts on No, so a stray Enter
## does not quit.

signal confirmed

@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton


func _ready() -> void:
	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(close)


func first_focus() -> Control:
	return _no_button


func _on_yes_pressed() -> void:
	hide()
	confirmed.emit()
