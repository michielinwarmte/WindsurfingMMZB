class_name PauseMenu
extends CanvasLayer
## The pause menu of the sailing scene (Esc, or Start on a gamepad): Resume, Restart,
## Settings, Controls, How to sail, Back to the start menu, Quit (pause_menu.tscn). It only
## shows itself and its pages and says what was chosen; the sailing scene (main.gd) pauses
## the game, restarts the run and applies the settings.

signal resume_requested
signal restart_requested
signal settings_closed
signal start_menu_requested

@onready var _root: Control = %Root
@onready var _list: Control = %List
@onready var _conditions: Label = %Conditions
@onready var _note: Label = %Note
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _controls_button: Button = %ControlsButton
@onready var _howto_button: Button = %HowToButton
@onready var _start_menu_button: Button = %StartMenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings: SettingsMenu = %Settings
@onready var _controls: ControlsPage = %Controls
@onready var _howto: HowToPage = %HowTo
@onready var _quit_confirm: ConfirmDialog = %QuitConfirm


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_settings_button.pressed.connect(_open_page.bind(_settings))
	_controls_button.pressed.connect(_open_page.bind(_controls))
	_howto_button.pressed.connect(_open_page.bind(_howto))
	_start_menu_button.pressed.connect(start_menu_requested.emit)
	_quit_button.pressed.connect(_open_page.bind(_quit_confirm))
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	for page: MenuPage in [_settings, _controls, _howto, _quit_confirm]:
		page.closed.connect(_on_page_closed.bind(page))
	MenuFocus.setup_buttons([_resume_button, _restart_button, _settings_button, _controls_button,
		_howto_button, _start_menu_button, _quit_button])


## Shows the menu. note: what waits for a restart (empty for nothing).
func open(note: String) -> void:
	_root.show()
	_show_list(_resume_button)
	set_note(note)


func close() -> void:
	_root.hide()
	for page: MenuPage in [_settings, _controls, _howto, _quit_confirm]:
		page.hide()


func is_open() -> bool:
	return _root.visible


## The line in orange under the title: what changes only after a restart.
func set_note(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


## Opens a page by name, for screenshots: settings/<tab>, controls, howto or quit.
func open_page(page_name: String) -> void:
	var parts: PackedStringArray = page_name.split("/")
	match parts[0]:
		"settings":
			_open_page(_settings)
			if parts.size() > 1:
				_settings.show_tab(parts[1])
		"controls":
			_open_page(_controls)
		"howto":
			_open_page(_howto)
		"quit":
			_open_page(_quit_confirm)


func _unhandled_input(event: InputEvent) -> void:
	# Esc (or Start, or B) on the list resumes; on a page the page goes back first.
	if not _list.is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func _show_list(focus: Button) -> void:
	_conditions.text = GameSettings.values.conditions_text()
	_list.show()
	focus.grab_focus()


func _open_page(page: MenuPage) -> void:
	_list.hide()
	page.open()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_page_closed(page: MenuPage) -> void:
	if page == _settings:
		settings_closed.emit()
	# Back on the list, with the focus on the button that opened the page.
	var buttons: Dictionary[MenuPage, Button] = {
		_settings: _settings_button, _controls: _controls_button, _howto: _howto_button, _quit_confirm: _quit_button}
	_show_list(buttons[page])
