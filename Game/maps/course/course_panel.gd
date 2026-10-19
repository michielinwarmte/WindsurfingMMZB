class_name CoursePanel
extends PanelContainer
## The course maker's panel (MAP_SILVAPLANA_PLAN.md, W4a): choose a template, set the course's axis,
## size and number of boards, add marks, type the order the marks are sailed in, change the
## selected mark (name, rounding side, delete), undo, clear, save and load the team's courses; it
## lists the legs and the warnings. Fit to water makes the course fit the lake (CourseFitter). It
## only shows and asks: CourseEditor does the work, through the signals.

signal template_chosen(id: String)
signal boards_changed(boards: int)
signal size_changed(percent: float)
signal axis_changed(degrees: float)
signal square_to_wind_pressed
signal fit_to_water_pressed
signal undo_pressed
signal clear_pressed
signal add_mark_pressed
signal order_submitted(text: String)
signal mark_renamed(new_name: String)
signal mark_side_chosen(side: CourseMark.Rounding)
signal delete_mark_pressed
signal save_pressed(course_name: String)
signal load_chosen(course_name: String)

const FONT_SIZE: int = 13
const WIDTH_PX: float = 365.0
const WARNING_COLOR: Color = Color("#ffb74d")
const SELECTED_COLOR: Color = Color("#ffd60a")
const MUTED: Color = Color(1.0, 1.0, 1.0, 0.65)

var _template: OptionButton
var _boards: SpinBox
var _size: SpinBox
var _axis: SpinBox
var _square: Button
var _fit: Button
var _undo: Button
var _clear: Button
var _add: Button
var _order: LineEdit
## The selected mark: its row, name, rounding side and delete button.
var _selected_row: HBoxContainer
var _selected_label: Label
var _selected_name: LineEdit
var _port: Button
var _starboard: Button
var _delete: Button
var _name: LineEdit
var _save: Button
var _load: OptionButton
var _summary: Label
## The table of legs: one label per column, one line per leg.
var _columns: Array[Label] = []
var _warnings: Label
var _message: Label


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	custom_minimum_size = Vector2(WIDTH_PX, 0.0)
	add_theme_stylebox_override("panel", background())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	var title: Label = Label.new()
	title.text = "Course maker"
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	_template = OptionButton.new()
	_template.focus_mode = Control.FOCUS_NONE
	_template.add_item("New course from a template...")
	for id: String in CourseTemplates.ALL:
		_template.add_item(CourseTemplates.title(id))
	_template.item_selected.connect(_on_template_selected)
	box.add_child(_template)

	var turning: HBoxContainer = _row(box)
	_axis = _spin_box(turning, "Axis °", 0.0, 359.0, 1.0, "The wind direction the course is set for: mark 1 lies this way from the start")
	_axis.allow_greater = true
	_axis.allow_lesser = true
	_axis.value_changed.connect(func(value: float) -> void: axis_changed.emit(fposmod(value, 360.0)))
	_square = _button(turning, "Square to wind", "Turn the course to the lake's wind now")
	_square.pressed.connect(func() -> void: square_to_wind_pressed.emit())
	_undo = _button(turning, "Undo", "Ctrl+Z")
	_undo.pressed.connect(func() -> void: undo_pressed.emit())

	var sizes: HBoxContainer = _row(box)
	_size = _spin_box(sizes, "Size %", 20.0, 150.0, 5.0, "100 % is the class's distances for the wind")
	_size.value_changed.connect(func(value: float) -> void: size_changed.emit(value))
	_boards = _spin_box(sizes, "Boards", 2.0, 200.0, 1.0, "Sets the start line's length")
	_boards.value_changed.connect(func(value: float) -> void: boards_changed.emit(int(value)))
	_fit = _button(sizes, "Fit to water", "Make the course fit the lake: every mark 200 m and every leg 50 m from the shore, set to the wind now, as big as it fits (Undo goes back)")
	_fit.pressed.connect(func() -> void: fit_to_water_pressed.emit())
	_clear = _button(sizes, "Clear", "Remove the course from the lake (Undo brings it back)")
	_clear.pressed.connect(func() -> void: clear_pressed.emit())

	var marks: HBoxContainer = _row(box)
	_add = _button(marks, "Add mark", "Then click on the water, near the leg it should go into")
	_add.pressed.connect(func() -> void: add_mark_pressed.emit())
	var order_label: Label = Label.new()
	order_label.text = "Order"
	marks.add_child(order_label)
	_order = _text_field(marks, "Start-1-4S/4P-1-4S-Finish", "The order the marks are sailed in, as in the Notice of Race. Type it and press Enter")
	_order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order.text_submitted.connect(func(text: String) -> void: order_submitted.emit(text))

	_selected_row = _row(box)
	_selected_label = Label.new()
	_selected_label.add_theme_color_override("font_color", SELECTED_COLOR)
	_selected_row.add_child(_selected_label)
	_selected_name = _text_field(_selected_row, "name", "The mark's name, like 5 or 1a. Type it and press Enter")
	_selected_name.custom_minimum_size = Vector2(46.0, 0.0)
	_selected_name.text_submitted.connect(func(text: String) -> void: mark_renamed.emit(text))
	var sides: ButtonGroup = ButtonGroup.new()
	_port = _button(_selected_row, "Port", "Leave the mark to port: round it anticlockwise")
	_starboard = _button(_selected_row, "Starboard", "Leave the mark to starboard: round it clockwise")
	for side_button: Button in [_port, _starboard]:
		side_button.toggle_mode = true
		side_button.button_group = sides
	_port.pressed.connect(func() -> void: mark_side_chosen.emit(CourseMark.Rounding.PORT))
	_starboard.pressed.connect(func() -> void: mark_side_chosen.emit(CourseMark.Rounding.STARBOARD))
	_delete = _button(_selected_row, "Delete", "Take the mark off the course (Undo brings it back). Delete key")
	_delete.pressed.connect(func() -> void: delete_mark_pressed.emit())
	show_selected(null)

	var files: HBoxContainer = _row(box)
	_name = _text_field(files, "Course name", "Save in the project, for the whole team")
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(text: String) -> void: save_pressed.emit(text))
	_save = _button(files, "Save", "Save in the project, for the whole team")
	_save.pressed.connect(func() -> void: save_pressed.emit(_name.text))
	_load = OptionButton.new()
	_load.focus_mode = Control.FOCUS_NONE
	_load.item_selected.connect(_on_load_selected)
	box.add_child(_load)
	set_saved_courses(PackedStringArray())

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	var table: HBoxContainer = HBoxContainer.new()
	table.add_theme_constant_override("separation", 12)
	box.add_child(table)
	for i: int in 4:
		var column: Label = Label.new()
		# The leg names on the left, the numbers right-aligned.
		column.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		table.add_child(column)
		_columns.append(column)
	_warnings = Label.new()
	_warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warnings.add_theme_color_override("font_color", WARNING_COLOR)
	box.add_child(_warnings)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	var help: Label = Label.new()
	help.text = "Drag a mark to move it, Shift+drag the whole course. Click a mark to change it. M hides the course."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", MUTED)
	box.add_child(help)
	var no_legs: Array[PackedStringArray] = []
	show_course(null, "", PackedStringArray(), no_legs, PackedStringArray())


## The viewer's panel look: dark and see-through like the wind chart, rounded, with room inside.
static func background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	return style


## Shows a course (null for none): its numbers, its order, a summary line, the legs (one row per
## leg, four columns: the leg, its length, its compass course, its angle to the wind) and the
## warnings. A field being typed in keeps what is typed.
func show_course(course: Course, summary: String, legs_header: PackedStringArray, legs: Array[PackedStringArray],
		warnings: PackedStringArray) -> void:
	for control: Control in [_axis, _size, _boards, _square, _fit, _clear, _add, _save, _name, _order]:
		if control is BaseButton:
			(control as BaseButton).disabled = course == null
		elif control is SpinBox:
			(control as SpinBox).editable = course != null
		elif control is LineEdit:
			(control as LineEdit).editable = course != null
	if course != null:
		_axis.set_value_no_signal(roundf(course.axis_deg))
		_size.set_value_no_signal(course.size_percent)
		_boards.set_value_no_signal(course.boards)
	if not _order.has_focus():
		_order.text = course.sequence if course != null else ""
	_summary.text = summary if course != null else "No course on the lake: choose a template, or load a team course."
	for i: int in _columns.size():
		var lines: PackedStringArray = PackedStringArray()
		if not legs.is_empty():
			lines.append(legs_header[i])
		for row: PackedStringArray in legs:
			lines.append(row[i])
		_columns[i].text = "\n".join(lines)
	_warnings.text = "\n".join(warnings)
	_warnings.visible = not warnings.is_empty()


## Shows the selected mark (null: none, the row is hidden). The lines' ends and the gates' marks
## keep their names and sides; the lines' ends can't be deleted.
func show_selected(mark: CourseMark) -> void:
	_selected_row.visible = mark != null
	if mark == null:
		return
	_selected_label.text = ("Mark " if not mark.is_line_end() else "") + mark.id + ":"
	if not _selected_name.has_focus():
		_selected_name.text = mark.id
	var fixed: bool = mark.is_line_end() or mark.is_gate_mark()
	_selected_name.visible = not mark.is_line_end()
	_selected_name.editable = not fixed
	_port.disabled = fixed
	_starboard.disabled = fixed
	_port.visible = not mark.is_line_end()
	_starboard.visible = not mark.is_line_end()
	_port.set_pressed_no_signal(mark.side == CourseMark.Rounding.PORT)
	_starboard.set_pressed_no_signal(mark.side == CourseMark.Rounding.STARBOARD)
	_delete.disabled = mark.is_line_end()


## While a mark is being added, the Add mark button stays pressed.
func set_adding(on: bool) -> void:
	_add.toggle_mode = true
	_add.set_pressed_no_signal(on)
	_add.text = "Click the water..." if on else "Add mark"


## After the order or a mark's name was refused: the field keeps what was typed and the keyboard,
## so it can be put right (the message says what is wrong).
func keep_typing_order() -> void:
	_order.grab_focus()


func keep_typing_name() -> void:
	_selected_name.grab_focus()


## The team's saved courses, by name, for the Load list.
func set_saved_courses(names: PackedStringArray) -> void:
	_load.clear()
	_load.add_item("Load a team course..." if not names.is_empty() else "No team courses saved yet")
	for course_name: String in names:
		_load.add_item(course_name)


func set_course_name(course_name: String) -> void:
	_name.text = course_name


## A short message under the table, for example after saving.
func show_message(text: String) -> void:
	_message.text = text


func _on_template_selected(index: int) -> void:
	# Back to the first line, so the same template can be chosen again.
	_template.select(0)
	if index > 0:
		_name.text = ""
		template_chosen.emit(CourseTemplates.ALL[index - 1])


func _on_load_selected(index: int) -> void:
	var course_name: String = _load.get_item_text(index)
	_load.select(0)
	if index > 0:
		_name.text = course_name
		load_chosen.emit(course_name)


func _row(parent: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	return row


func _spin_box(parent: Control, label_text: String, low: float, high: float, step: float, tip: String) -> SpinBox:
	var label: Label = Label.new()
	label.text = label_text
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.tooltip_text = tip
	spin.custom_minimum_size = Vector2(58.0, 0.0)
	spin.select_all_on_focus = true
	# After typing a number and Enter, the keys go back to the viewer.
	spin.get_line_edit().text_submitted.connect(func(_text: String) -> void: spin.get_line_edit().release_focus())
	parent.add_child(spin)
	return spin


## A text field. After Enter, the keys go back to the viewer (unless the editor refuses the text).
func _text_field(parent: Control, placeholder: String, tip: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.tooltip_text = tip
	field.text_submitted.connect(func(_text: String) -> void: field.release_focus())
	parent.add_child(field)
	return field


func _button(parent: Control, text: String, tip: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	# The keyboard stays with the viewer (Space pauses, it doesn't press the last clicked button).
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button
