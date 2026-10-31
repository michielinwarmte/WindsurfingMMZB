class_name MenuFocus
extends RefCounted
## A helper the menus share for their lists of buttons.


## Makes a list of buttons easy to use with the keyboard, a gamepad and the mouse at once:
## pointing at a button with the mouse moves the focus there too (so only one button is lit
## at a time), and Up on the first button goes round to the last one (Down on the last one
## to the first).
static func setup_buttons(buttons: Array[Button]) -> void:
	for button: Button in buttons:
		button.mouse_entered.connect(button.grab_focus)
	var first: Button = buttons[0]
	var last: Button = buttons[buttons.size() - 1]
	first.focus_neighbor_top = first.get_path_to(last)
	last.focus_neighbor_bottom = last.get_path_to(first)


## Which way a key or button changes a page's tab: +1 for the gamepad's right shoulder button or
## Ctrl+Tab, -1 for the left shoulder button or Ctrl+Shift+Tab, 0 for anything else.
static func tab_step(event: InputEvent) -> int:
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null and button.pressed:
		if button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
		if button.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.ctrl_pressed and key.physical_keycode == KEY_TAB:
		return -1 if key.shift_pressed else 1
	return 0
