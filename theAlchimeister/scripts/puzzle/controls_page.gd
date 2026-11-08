extends Panel
## The notebook's CONTROLS page: every remappable action with its key. Pressing
## a key's button waits for the new key (Esc or a click cancels). A key already
## used elsewhere moves here, and the two actions swap if needed (see Controls).

## The player asked to go back to SETTINGS.
signal back_requested

const INK := Color(0.35, 0.22, 0.14)
const WAITING_INK := Color(0.75, 0.25, 0.2)
const TITLE := "CONTROLS"
const WAITING_TITLE := "PRESS A KEY (ESC CANCELS)"
const LEFT_ROWS := 7
const ROWS_TOP := 26.0
const ROW_STEP := 19.0
const LABEL_WIDTH := 70.0
const KEY_SIZE := Vector2(76, 16)
const LEFT_COLUMN := 16.0
const RIGHT_COLUMN := 190.0
const BUTTON_WIDTH := LABEL_WIDTH + KEY_SIZE.x

var _title: Label
## Action -> the button showing its key.
var _key_buttons := {}
var _first_button: Button
## The action waiting for a new key, if any.
var _waiting := &""


func build(book_size: Vector2, style: StyleBox) -> void:
	add_theme_stylebox_override("panel", style)
	size = book_size
	hide()
	_title = _ink_label(TITLE, Vector2(0, 10), book_size.x)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in Controls.REMAPPABLE.size():
		var entry: Array = Controls.REMAPPABLE[i]
		var column := LEFT_COLUMN if i < LEFT_ROWS else RIGHT_COLUMN
		var row := i if i < LEFT_ROWS else i - LEFT_ROWS
		var y := ROWS_TOP + row * ROW_STEP
		_ink_label(entry[0], Vector2(column, y + 3.0), LABEL_WIDTH)
		var button := _button(Rect2(column + LABEL_WIDTH, y, KEY_SIZE.x, KEY_SIZE.y))
		button.pressed.connect(_wait_for_key.bind(entry[1]))
		_key_buttons[entry[1]] = button
		if not _first_button:
			_first_button = button
	# Under the shorter column.
	var below := ROWS_TOP + (Controls.REMAPPABLE.size() - LEFT_ROWS) * ROW_STEP + 8.0
	var reset := _button(Rect2(RIGHT_COLUMN, below, BUTTON_WIDTH, KEY_SIZE.y))
	reset.text = "RESET KEYS"
	reset.pressed.connect(func() -> void:
		_stop_waiting()
		SaveGame.reset_controls())
	var back := _button(Rect2(RIGHT_COLUMN, below + ROW_STEP, BUTTON_WIDTH, KEY_SIZE.y))
	back.text = "BACK"
	back.pressed.connect(back_requested.emit)
	SaveGame.controls_changed.connect(_refresh)
	visibility_changed.connect(_stop_waiting)
	_refresh()


func focus_first() -> void:
	_first_button.grab_focus()


## Runs before the buttons and the book's keys, so nothing else sees the key.
func _input(event: InputEvent) -> void:
	if _waiting == &"":
		return
	if event is InputEventMouseButton and event.pressed:
		_stop_waiting()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := int(event.physical_keycode)
		if key == 0:
			key = int(event.keycode)
		var action := _waiting
		_stop_waiting()
		if key != KEY_ESCAPE and key != 0:
			SaveGame.rebind(action, key)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()


func _wait_for_key(action: StringName) -> void:
	_stop_waiting()
	_waiting = action
	_key_buttons[action].text = "..."
	_title.text = WAITING_TITLE
	_title.add_theme_color_override("font_color", WAITING_INK)


func _stop_waiting() -> void:
	if _waiting == &"":
		return
	_waiting = &""
	_title.text = TITLE
	_title.add_theme_color_override("font_color", INK)
	_refresh()


func _refresh() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = Controls.all_key_names(action)


func _ink_label(text: String, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	add_child(label)
	label.position = at
	label.size = Vector2(width, 10)
	return label


func _button(rect: Rect2) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button
