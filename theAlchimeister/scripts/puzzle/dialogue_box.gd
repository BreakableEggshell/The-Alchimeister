extends Control
## Conversation box at the bottom of the screen, with a speaker portrait and
## typewriter text. Playing a conversation pauses the game. A tap/click,
## Enter, Space or E finishes the current line, then moves to the next.
## Top-right while playing: fast-forward (asks "SKIP DIALOGUE?") and log.
## The log (chat history for this stage, skipped lines included) can also be
## opened from elsewhere with show_log().

signal started
signal finished

const SPEAKERS := {
	"SHELDON": {"portrait": preload("res://assets/sheldon_talk.png"), "color": Color(0.6, 0.95, 0.85)},
	"ALCHEMIST": {"portrait": preload("res://assets/alchemist_talk.png"), "color": Color(1.0, 0.5, 0.45)},
}
const CHARS_PER_SECOND := 50.0
const PANEL_HEIGHT := 56.0
const BG := Color(0.1, 0.09, 0.14, 0.95)
const BORDER := Color(0.95, 0.85, 0.55)

var is_playing := false
## Every line shown (or skipped) this stage: [{speaker, text}].
var history: Array[Dictionary] = []

var _lines: Array[Dictionary] = []
var _index := 0
var _paused_by_me := false
var _type_tween: Tween
var _blocker: Control
var _box: Panel
var _portrait: TextureRect
var _name: Label
var _text: Label
var _skip_button: Button
var _log_button: Button
var _confirm: Control
var _log: Control
var _log_text: RichTextLabel


func _ready() -> void:
	add_to_group("dialogue")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_set_playing_visible(false)


## Plays "SPEAKER: text" lines. If a conversation is already playing, they're queued after it.
func play(lines: PackedStringArray) -> void:
	var parsed := _parse(lines)
	if parsed.is_empty():
		return
	if is_playing:
		_lines.append_array(parsed)
		return
	_lines = parsed
	_index = 0
	is_playing = true
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	_set_playing_visible(true)
	started.emit()
	_show_line()


func advance() -> void:
	if not is_playing or _confirm.visible or _log.visible:
		return
	if _text.visible_ratio < 1.0:
		if _type_tween:
			_type_tween.kill()
		_text.visible_ratio = 1.0
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


## Ends the conversation now; the remaining lines still go into the log.
func skip_all() -> void:
	for i in range(_index + 1, _lines.size()):
		history.append(_lines[i])
	_confirm.hide()
	_finish()


func show_log() -> void:
	var bbcode := ""
	for line in history:
		var color: Color = SPEAKERS.get(line.speaker, {}).get("color", Color.WHITE)
		bbcode += "[color=#%s]%s:[/color] %s\n\n" % [color.to_html(false), line.speaker, line.text]
	_log_text.text = bbcode if bbcode else "[color=#888888]NOTHING SAID YET.[/color]"
	_log.show()
	move_to_front()
	_log_text.scroll_to_line(maxi(_log_text.get_line_count() - 1, 0))


func _unhandled_input(event: InputEvent) -> void:
	if _log.visible:
		if event.is_action_pressed("ui_cancel"):
			_log.hide()
			get_viewport().set_input_as_handled()
		return
	if not is_playing:
		return
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel"):
			_confirm.hide()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_book"):
		# Swallow these so the book can't open mid-conversation.
		get_viewport().set_input_as_handled()


func _show_line() -> void:
	var line := _lines[_index]
	history.append(line)
	var speaker: Dictionary = SPEAKERS.get(line.speaker, {})
	_portrait.texture = speaker.get("portrait")
	_name.text = line.speaker
	_name.add_theme_color_override("font_color", speaker.get("color", Color.WHITE))
	_text.text = line.text
	_text.visible_ratio = 0.0
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_type_tween.tween_property(_text, "visible_ratio", 1.0, line.text.length() / CHARS_PER_SECOND)


func _finish() -> void:
	is_playing = false
	_lines.clear()
	_set_playing_visible(false)
	if _paused_by_me:
		get_tree().paused = false
	finished.emit()


func _set_playing_visible(playing: bool) -> void:
	_blocker.visible = playing
	_box.visible = playing
	_skip_button.visible = playing
	_log_button.visible = playing
	if not playing:
		_confirm.hide()


func _parse(lines: PackedStringArray) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	for raw in lines:
		var split := raw.find(":")
		if split < 0:
			parsed.append({"speaker": "SHELDON", "text": raw.strip_edges()})
		else:
			parsed.append({"speaker": raw.substr(0, split).strip_edges().to_upper(), "text": raw.substr(split + 1).strip_edges()})
	return parsed


func _blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		advance()


# --- Layout

func _build() -> void:
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_blocker_input)
	add_child(_blocker)

	_box = Panel.new()
	_box.add_theme_stylebox_override("panel", _panel_style())
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 6.0
	_box.offset_right = -6.0
	_box.offset_top = -PANEL_HEIGHT - 4.0
	_box.offset_bottom = -4.0
	add_child(_box)

	var frame := Panel.new()
	var frame_style := _panel_style()
	frame_style.bg_color = Color(0.2, 0.18, 0.26)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = Vector2(5, 5)
	frame.size = Vector2(46, 46)
	_box.add_child(frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(2, 2)
	_portrait.size = Vector2(42, 42)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_portrait)

	_name = Label.new()
	_name.position = Vector2(58, 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_name)
	_text = Label.new()
	_text.anchor_right = 1.0
	_text.offset_left = 58.0
	_text.offset_top = 16.0
	_text.offset_right = -8.0
	_text.offset_bottom = 52.0
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)

	_skip_button = _icon_button(_draw_skip_icon, "SKIP", 4.0)
	_skip_button.pressed.connect(func() -> void: _confirm.show())
	_log_button = _icon_button(_draw_log_icon, "LOG", 32.0)
	_log_button.pressed.connect(show_log)

	_confirm = _modal(Vector2(168, 56))
	var question := Label.new()
	question.text = "SKIP DIALOGUE?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 10)
	question.size = Vector2(168, 10)
	_confirm.get_child(1).add_child(question)
	var yes := _text_button("YES", Vector2(28, 30), Vector2(48, 16))
	yes.pressed.connect(skip_all)
	_confirm.get_child(1).add_child(yes)
	var no := _text_button("NO", Vector2(92, 30), Vector2(48, 16))
	no.pressed.connect(_confirm.hide)
	_confirm.get_child(1).add_child(no)

	_log = _modal(Vector2(320, 176))
	var log_panel: Control = _log.get_child(1)
	var title := Label.new()
	title.text = "LOG"
	title.add_theme_color_override("font_color", BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(320, 10)
	log_panel.add_child(title)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_active = true
	_log_text.position = Vector2(10, 20)
	_log_text.size = Vector2(300, 130)
	log_panel.add_child(_log_text)
	var close := _text_button("CLOSE", Vector2(130, 154), Vector2(60, 16))
	close.pressed.connect(_log.hide)
	log_panel.add_child(close)


## A full-screen dimmer holding a centred panel (child 1). Hidden at first.
func _modal(panel_size: Vector2) -> Control:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x / 2.0
	panel.offset_right = panel_size.x / 2.0
	panel.offset_top = -panel_size.y / 2.0
	panel.offset_bottom = panel_size.y / 2.0
	modal.add_child(panel)
	return modal


## A 24x20 button in the top-right corner, `from_right` pixels in from the edge.
func _icon_button(draw_icon: Callable, tip: String, from_right: float) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -from_right - 24.0
	button.offset_right = -from_right
	button.offset_top = 4.0
	button.offset_bottom = 24.0
	button.draw.connect(draw_icon.bind(button))
	add_child(button)
	return button


func _text_button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.size = button_size
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(1)
	return style


func _draw_skip_icon(button: Button) -> void:
	var c := button.size / 2.0
	for dx in [-4.0, 2.0]:
		button.draw_colored_polygon(PackedVector2Array([c + Vector2(dx - 2, -4), c + Vector2(dx + 4, 0), c + Vector2(dx - 2, 4)]), Color.WHITE)


func _draw_log_icon(button: Button) -> void:
	var c := button.size / 2.0
	button.draw_rect(Rect2(c + Vector2(-5, -6), Vector2(10, 12)), Color(0.94, 0.88, 0.74))
	for y in [-3.0, 0.0, 3.0]:
		button.draw_line(c + Vector2(-3, y), c + Vector2(3, y), Color(0.35, 0.22, 0.14))
