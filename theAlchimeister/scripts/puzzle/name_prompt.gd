extends Control
## The end of a full run: asks for the playtester's name. ask() waits until a
## name is given (it can't be dismissed or left blank) and returns it.

signal _answered(player_name: String)

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const PANEL_SIZE := Vector2(190, 70)
const FIELD_SIZE := Vector2(150, 16)
const GOLD := Color(0.95, 0.85, 0.55)
const BACKGROUND := Color(0.1, 0.09, 0.14)
const MAX_NAME_LENGTH := 16

var _field: LineEdit
var _ok: Button


func ask() -> String:
	_build()
	_focus_field()
	var player_name: String = await _answered
	queue_free()
	return player_name


## See UiFocus.
func focus_first() -> bool:
	_focus_field()
	return true


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)


func _focus_field() -> void:
	_field.grab_focus()
	_field.edit()


func _submit(_text := "") -> void:
	var player_name := _field.text.strip_edges()
	if player_name != "":
		_answered.emit(player_name)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Clicking away never loses the place you're typing in.
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_focus_field.call_deferred())
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = GOLD
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.size = PANEL_SIZE
	panel.position = ((get_viewport_rect().size - PANEL_SIZE) / 2.0).round()
	var title := Label.new()
	title.text = "Input Playtester Name"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	title.position = Vector2(0, 7)
	title.size = Vector2(PANEL_SIZE.x, 10)
	_field = LineEdit.new()
	_field.max_length = MAX_NAME_LENGTH
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.add_theme_font_override("font", FONT)
	_field.add_theme_font_size_override("font_size", 8)
	_field.add_theme_color_override("font_color", Color.WHITE)
	_field.add_theme_color_override("caret_color", GOLD)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.18, 0.28)
	box.border_color = Color(GOLD, 0.6)
	box.set_border_width_all(1)
	box.content_margin_left = 3.0
	box.content_margin_right = 3.0
	for state in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(state, box)
	_field.text_submitted.connect(_submit)
	# Stay in the field after Enter on a blank name.
	_field.keep_editing_on_text_submit = true
	panel.add_child(_field)
	_field.position = Vector2((PANEL_SIZE.x - FIELD_SIZE.x) / 2.0, 22)
	_field.size = FIELD_SIZE
	_ok = Button.new()
	_ok.text = "OK"
	_ok.focus_mode = Control.FOCUS_NONE
	_ok.add_theme_font_override("font", FONT)
	_ok.add_theme_font_size_override("font_size", 8)
	_ok.pressed.connect(_submit)
	panel.add_child(_ok)
	_ok.position = Vector2((PANEL_SIZE.x - 48.0) / 2.0, 44)
	_ok.size = Vector2(48, 16)
	_field.text_changed.connect(_update_ok)
	_update_ok()


func _update_ok(_text := "") -> void:
	_ok.disabled = _field.text.strip_edges() == ""
