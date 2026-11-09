extends Control
## Conversations, visual-novel style: the screen dims, the characters stand
## at either side (whoever is talking lit up, the listener darkened and
## pushed back into their corner) and a text box at the bottom centre types
## out the line. Characters are DialogueSpeaker resources in `speakers`;
## lines are "SPEAKER: text", or "SPEAKER (expression): text" to show one of
## their expressions (see DialogueSpeaker). Playing a conversation pauses the game. A tap/click,
## Enter, Space or E finishes the current line, then moves to the next.
## Top-right while playing: fast-forward (asks "SKIP DIALOGUE?", also on Esc)
## and log (also on L), with their keys shown underneath. Conversations can be
## marked as teaching something (HINT or TUTORIAL); if any of the lines still to
## come do, the skip question warns about it in red.
## The log (chat history for this stage, skipped lines included) can also be
## opened from elsewhere with show_log().
## Mid-gameplay conversations go through interrupt(): the game pauses, a speech
## bubble pops up over the talker, then the conversation starts.

signal started
signal finished

const CHARS_PER_SECOND := 50.0
## Seconds the speech bubble shows before a mid-gameplay conversation starts.
const BUBBLE_TIME := 0.6
const KEY_COLOR := Color(1, 1, 1, 0.75)
const BG := Color(0.1, 0.09, 0.14, 0.95)
const BORDER := Color(0.95, 0.85, 0.55)
const BOX_WIDTH := 240.0
## The box grows upwards past this when a line needs more room.
const BOX_MIN_HEIGHT := 60.0
## Gap between the box and the bottom of the screen.
const BOX_MARGIN := 4.0
const TEXT_TOP := 16.0
const TEXT_PADDING := 6.0
const DIM_COLOR := Color(0, 0, 0, 0.5)
## How the character who isn't talking looks: darker, and pushed this far
## towards their bottom corner.
const LISTENER_TINT := Color(0.45, 0.45, 0.5)
const LISTENER_PUSH := Vector2(16, 28)
## Seconds to swap who's lit up, and to bring everyone in at the start.
const SHIFT_TIME := 0.15
const ENTER_TIME := 0.2
## Characters slide up from this far below as a conversation starts.
const ENTER_DROP := 24.0
## What a conversation teaches, for the skip warning (see play()).
const HINT := &"hint"
const TUTORIAL := &"tutorial"
const WARNING_COLOR := Color(1, 0.4, 0.4)
const CONFIRM_WIDTH := 168.0
const CONFIRM_BUTTON_SIZE := Vector2(48, 16)

## Everyone who can talk. Lines naming someone not in here still play, with
## a white name and no portrait.
@export var speakers: Array[DialogueSpeaker] = []

var is_playing := false
## True while interrupt() shows the speech bubble, before the lines start.
var is_waiting := false
## Every line shown (or skipped) this stage: [{speaker, text}].
var history: Array[Dictionary] = []

var _lines: Array[Dictionary] = []
## Lines asked for while the speech bubble was up; played right after it.
var _queued: Array[Dictionary] = []
var _index := 0
var _paused_by_me := false
var _type_tween: Tween
var _blocker: Control
var _dim: ColorRect
var _box: Panel
## DialogueSpeaker.Side -> its portrait, and who is standing there.
var _portraits := {}
var _standing := {}
var _portrait_tweens := {}
var _dim_tween: Tween
var _name: Label
var _text: Label
var _skip_button: Button
var _log_button: Button
## The level being played, top left while talking.
var _level_label: Label
var _confirm: Control
var _confirm_warning: Label
var _confirm_buttons: Array[Button] = []
var _log: Control
var _log_text: RichTextLabel
var _log_close: Button
## Whatever had keyboard focus when the conversation began (given back after).
var _focus_before: Control


func _ready() -> void:
	add_to_group("dialogue")
	add_to_group(UiFocus.SCREENS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_set_playing_visible(false)


func set_level_label(text: String) -> void:
	_level_label.text = text


## Plays "SPEAKER: text" lines. If a conversation is already playing, they're
## queued after it. `teaches` (HINT, TUTORIAL or none) marks what they teach,
## so skipping them warns the player.
func play(lines: PackedStringArray, teaches := &"") -> void:
	_play_parsed(_parse(lines, teaches))


func _play_parsed(parsed: Array[Dictionary]) -> void:
	if parsed.is_empty():
		return
	if is_playing:
		_lines.append_array(parsed)
		return
	_lines = parsed
	_index = 0
	is_playing = true
	# Enter advances the dialogue, so it mustn't also press a focused button
	# underneath (the notebook's GIVE HINT, say).
	_focus_before = get_viewport().gui_get_focus_owner()
	if _focus_before:
		_focus_before.release_focus()
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	_set_playing_visible(true)
	_set_stage()
	started.emit()
	_show_line(ENTER_TIME)


## For conversations in the middle of gameplay: pauses the game, shows a
## speech bubble over `talker` (anything with set_talking()), then plays the
## lines. Returns once the conversation is over. `teaches` as for play().
func interrupt(lines: PackedStringArray, talker: Node = null, teaches := &"") -> void:
	if lines.is_empty():
		return
	if is_playing or is_waiting:
		_queue_after_bubble(lines, teaches)
		return
	var paused_here := not get_tree().paused
	get_tree().paused = true
	is_waiting = true
	started.emit()
	if talker:
		talker.set_talking(true)
	await get_tree().create_timer(BUBBLE_TIME, true).timeout
	is_waiting = false
	var parsed := _parse(lines, teaches)
	parsed.append_array(_queued)
	_queued.clear()
	_play_parsed(parsed)
	if is_playing:
		await finished
	if is_instance_valid(talker):
		talker.set_talking(false)
	if paused_here:
		get_tree().paused = false


func _queue_after_bubble(lines: PackedStringArray, teaches: StringName) -> void:
	if is_playing:
		play(lines, teaches)
	else:
		_queued.append_array(_parse(lines, teaches))


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
		var speaker := _speaker(line.speaker)
		var color := speaker.name_color if speaker else Color.WHITE
		var shown := speaker.shown_name() if speaker else String(line.speaker)
		bbcode += "[color=#%s]%s:[/color] %s\n\n" % [color.to_html(false), shown, line.text]
	_log_text.text = bbcode if bbcode else "[color=#888888]NOTHING SAID YET.[/color]"
	_log.show()
	move_to_front()
	_log_text.grab_focus()
	_log_text.scroll_to_line(maxi(_log_text.get_line_count() - 1, 0))


func _unhandled_input(event: InputEvent) -> void:
	if _log.visible:
		if event.is_action_pressed("ui_cancel") or (is_playing and _is_log_key(event)):
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
	elif event.is_action_pressed("ui_cancel"):
		_show_confirm()
		get_viewport().set_input_as_handled()
	elif _is_log_key(event):
		show_log()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_book"):
		# Swallow these so the book can't open mid-conversation.
		get_viewport().set_input_as_handled()


## See UiFocus.
func focus_first() -> bool:
	if _confirm.visible:
		_confirm_buttons[1 if _confirm_warning.visible else 0].grab_focus()
	elif _log.visible:
		_log_text.grab_focus()
	else:
		return false
	return true


func _is_log_key(event: InputEvent) -> bool:
	return event.is_action_pressed("open_log")


func _show_line(shift_time := SHIFT_TIME) -> void:
	var line := _lines[_index]
	history.append(line)
	var speaker := _speaker(line.speaker)
	_name.text = speaker.shown_name() if speaker else String(line.speaker)
	_name.add_theme_color_override("font_color", speaker.name_color if speaker else Color.WHITE)
	_text.text = line.text
	_fit_box()
	_spotlight(speaker, shift_time, line.get("expression", ""))
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
	var restore := _focus_before
	_focus_before = null
	finished.emit()
	# After `finished`, so whatever was hidden for the talk is back first.
	if is_instance_valid(restore) and restore.is_visible_in_tree():
		restore.grab_focus()


func _set_playing_visible(playing: bool) -> void:
	_blocker.visible = playing
	_dim.visible = playing
	_box.visible = playing
	if not playing:
		for side in _portraits:
			_portraits[side].hide()
	_skip_button.visible = playing
	_log_button.visible = playing
	_level_label.visible = playing
	if not playing:
		_confirm.hide()


# --- Characters on stage

## A speaker's name colour (white for anyone not in `speakers`).
func color_of(id: String) -> Color:
	var speaker := _speaker(id.to_upper())
	return speaker.name_color if speaker else Color.WHITE


func _speaker(id: String) -> DialogueSpeaker:
	for speaker in speakers:
		if speaker and speaker.id.to_upper() == id:
			return speaker
	return null


## Picks who stands where for a new conversation and starts them low and dark,
## ready to slide in: anyone always on stage, then the first to talk on each
## empty side.
func _set_stage() -> void:
	_standing.clear()
	for speaker in speakers:
		if speaker and speaker.always_on_stage and speaker.portrait and not _standing.has(speaker.side):
			_standing[speaker.side] = speaker
	# Each starts with the face of their first line.
	var first_faces := {}
	for line in _lines:
		var speaker := _speaker(line.speaker)
		if speaker and speaker.portrait and not _standing.has(speaker.side):
			_standing[speaker.side] = speaker
		if speaker and not first_faces.has(speaker):
			first_faces[speaker] = line.get("expression", "")
	for side in _portraits:
		var portrait: TextureRect = _portraits[side]
		portrait.visible = _standing.has(side)
		if portrait.visible:
			_dress(portrait, _standing[side], first_faces.get(_standing[side], ""))
			portrait.position = _portrait_position(_standing[side], false) + Vector2(0, ENTER_DROP)
			portrait.modulate = LISTENER_TINT
	_dim.modulate.a = 0.0
	if _dim_tween:
		_dim_tween.kill()
	_dim_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_dim_tween.tween_property(_dim, "modulate:a", 1.0, ENTER_TIME)


## Lights up `speaker` (stepping them in if someone else stood on their side)
## and darkens and pushes back everyone else.
## The listener keeps whatever face they last had; the talker shows
## `expression`.
func _spotlight(speaker: DialogueSpeaker, time: float, expression := "") -> void:
	if speaker and speaker.portrait and _standing.get(speaker.side) == speaker:
		_dress(_portraits[speaker.side], speaker, expression)
	elif speaker and speaker.portrait:
		_standing[speaker.side] = speaker
		var portrait: TextureRect = _portraits[speaker.side]
		_dress(portrait, speaker, expression)
		portrait.position = _portrait_position(speaker, false) + Vector2(0, ENTER_DROP)
		portrait.modulate = LISTENER_TINT
		portrait.show()
	for side in _standing:
		var standing: DialogueSpeaker = _standing[side]
		var talking := standing == speaker
		var portrait: TextureRect = _portraits[side]
		if _portrait_tweens.get(side):
			_portrait_tweens[side].kill()
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(portrait, "position", _portrait_position(standing, talking), time)
		tween.tween_property(portrait, "modulate", Color.WHITE if talking else LISTENER_TINT, time)
		_portrait_tweens[side] = tween


func _dress(portrait: TextureRect, speaker: DialogueSpeaker, expression := "") -> void:
	portrait.texture = speaker.portrait_for(expression)
	portrait.flip_h = speaker.flip_h
	portrait.size = speaker.portrait.get_size() * speaker.portrait_scale


## Top-left corner of a speaker's portrait, talking or listening.
func _portrait_position(speaker: DialogueSpeaker, talking: bool) -> Vector2:
	var portrait_size := speaker.portrait.get_size() * speaker.portrait_scale
	var right := speaker.side == DialogueSpeaker.Side.RIGHT
	var center := Vector2(speaker.portrait_center.x, size.y - speaker.portrait_center.y)
	if right:
		center.x = size.x - center.x
	if not talking:
		center += Vector2(LISTENER_PUSH.x * (1.0 if right else -1.0), LISTENER_PUSH.y)
	return (center - portrait_size / 2.0).round()


## Grows the box upwards when the current line needs more than the minimum.
func _fit_box() -> void:
	var text_height := _text.get_line_count() * _text.get_line_height()
	var height := maxf(BOX_MIN_HEIGHT, TEXT_TOP + text_height + TEXT_PADDING)
	_box.offset_top = -BOX_MARGIN - height


func _parse(lines: PackedStringArray, teaches := &"") -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	for line in lines:
		# Key names follow the player's bindings: "Press {toggle_book}".
		var raw := Controls.fill(line)
		var split := raw.find(":")
		if split < 0:
			parsed.append({"speaker": "SHELDON", "expression": "", "text": raw.strip_edges(), "teaches": teaches})
			continue
		# "SHELDON (happy)" -> speaker SHELDON, expression happy.
		var who := raw.substr(0, split).strip_edges()
		var expression := ""
		var open := who.find("(")
		if open >= 0 and who.ends_with(")"):
			expression = who.substr(open + 1, who.length() - open - 2).strip_edges().to_lower()
			who = who.substr(0, open).strip_edges()
		parsed.append({"speaker": who.to_upper(), "expression": expression, "text": raw.substr(split + 1).strip_edges(), "teaches": teaches})
	return parsed


## What the lines from the current one on teach (HINT first, then TUTORIAL),
## or nothing.
func teaches_ahead() -> Array[StringName]:
	var found: Array[StringName] = []
	for kind in [HINT, TUTORIAL]:
		for i in range(_index, _lines.size()):
			if _lines[i].get("teaches", &"") == kind:
				found.append(kind)
				break
	return found


## "SKIP DIALOGUE?", with a red warning when a hint or tutorial is still to come.
func _show_confirm() -> void:
	var names := {HINT: "A HINT", TUTORIAL: "A TUTORIAL"}
	var parts: PackedStringArray = []
	for teaches in teaches_ahead():
		parts.append(names[teaches])
	_confirm_warning.visible = not parts.is_empty()
	_confirm_warning.text = "IT HAS %s!" % " AND ".join(parts) if _confirm_warning.visible else ""
	var warning_lines := 0
	if _confirm_warning.visible:
		var font := _confirm_warning.get_theme_font("font")
		var width := font.get_string_size(_confirm_warning.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		warning_lines = ceili(width / (CONFIRM_WIDTH - 16.0))
	var warning_height := warning_lines * 10.0 + (4.0 if warning_lines > 0 else 0.0)
	_confirm_warning.size = Vector2(CONFIRM_WIDTH - 16.0, warning_lines * 10.0)
	# Sized here, in the tree: a size set before then doesn't stick.
	for button in _confirm_buttons:
		button.size = CONFIRM_BUTTON_SIZE
		button.position.y = 30.0 + warning_height
	var panel: Control = _confirm.get_child(1)
	var height := 30.0 + warning_height + CONFIRM_BUTTON_SIZE.y + 10.0
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
	_confirm.show()
	# With a hint or tutorial at stake, NO is the safe default.
	_confirm_buttons[1 if _confirm_warning.visible else 0].grab_focus()


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

	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	for side in [DialogueSpeaker.Side.LEFT, DialogueSpeaker.Side.RIGHT]:
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.hide()
		add_child(portrait)
		_portraits[side] = portrait

	_box = Panel.new()
	_box.add_theme_stylebox_override("panel", _panel_style())
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -BOX_WIDTH / 2.0
	_box.offset_right = BOX_WIDTH / 2.0
	_box.offset_top = -BOX_MARGIN - BOX_MIN_HEIGHT
	_box.offset_bottom = -BOX_MARGIN
	add_child(_box)

	_name = Label.new()
	_name.position = Vector2(TEXT_PADDING, 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_name)
	_text = Label.new()
	_text.anchor_right = 1.0
	_text.anchor_bottom = 1.0
	_text.offset_left = TEXT_PADDING
	_text.offset_top = TEXT_TOP
	_text.offset_right = -TEXT_PADDING
	_text.offset_bottom = -TEXT_PADDING
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Lay out the whole line up front, so the box can size itself and words
	# don't jump to the next line as they type out.
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)

	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", Color.WHITE)
	_level_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_level_label.add_theme_constant_override("outline_size", 3)
	_level_label.position = Vector2(6, 6)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)

	_skip_button = _icon_button(_draw_skip_icon, "SKIP", 4.0, "ESC")
	_skip_button.pressed.connect(_show_confirm)
	_log_button = _icon_button(_draw_log_icon, "LOG", 32.0, "", &"open_log")
	_log_button.pressed.connect(show_log)

	_confirm = _modal(Vector2(CONFIRM_WIDTH, 56))
	var question := Label.new()
	question.text = "SKIP DIALOGUE?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 10)
	question.size = Vector2(CONFIRM_WIDTH, 10)
	_confirm.get_child(1).add_child(question)
	_confirm_warning = Label.new()
	_confirm_warning.add_theme_color_override("font_color", WARNING_COLOR)
	_confirm_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_warning.position = Vector2(8, 24)
	_confirm_warning.hide()
	_confirm.get_child(1).add_child(_confirm_warning)
	var yes := _text_button("YES", Vector2(28, 30), Vector2(48, 16))
	yes.pressed.connect(skip_all)
	_confirm.get_child(1).add_child(yes)
	var no := _text_button("NO", Vector2(92, 30), Vector2(48, 16))
	no.pressed.connect(_confirm.hide)
	_confirm.get_child(1).add_child(no)
	_confirm_buttons.assign([yes, no])
	UiFocus.link_row.call_deferred([yes, no])

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
	# Focused while open, so Up/Down scroll it.
	_log_text.focus_mode = Control.FOCUS_ALL
	_log_text.position = Vector2(10, 20)
	_log_text.size = Vector2(300, 130)
	log_panel.add_child(_log_text)
	_log_close = _text_button("CLOSE", Vector2(130, 154), Vector2(60, 16))
	_log_close.pressed.connect(_log.hide)
	log_panel.add_child(_log_close)


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


## A 24x20 button in the top-right corner, `from_right` pixels in from the
## edge, with its keyboard key written underneath.
## Under the icon: `key`, or the key bound to `action` if there is one.
func _icon_button(draw_icon: Callable, tip: String, from_right: float, key: String, action := &"") -> Button:
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
	button.draw.connect(func() -> void:
		var shown := Controls.key_name(action) if action != &"" else key
		button.draw_string(button.get_theme_font("font"), Vector2(0, button.size.y + 9), shown, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 8, KEY_COLOR))
	SaveGame.controls_changed.connect(button.queue_redraw)
	add_child(button)
	return button


func _text_button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
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
