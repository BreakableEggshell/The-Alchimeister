extends Control
## Level select: a grid of the 7 levels. Levels with no unlocked stages show a
## padlock and can't be picked. Picking a level opens its stage panel, where
## each unlocked stage can be played; a level with a single stage just starts.

const CARD_SIZE := Vector2(84, 52)
const GOLD := Color(0.95, 0.85, 0.55)

var _stage_panel: Control
var _stage_title: Label
var _stage_row: HBoxContainer
var _cards: Array[Button] = []


func _ready() -> void:
	_build()
	if not _cards.is_empty():
		_cards[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _stage_panel.visible:
			_close_stages()
		else:
			SaveGame.go_to(SaveGame.START_MENU)
		get_viewport().set_input_as_handled()


func open_level(index: int) -> void:
	if not SaveGame.is_level_unlocked(index):
		return
	var level: Dictionary = SaveGame.LEVELS[index]
	if level.stages.size() == 1:
		SaveGame.play_stage(level.stages[0])
		return
	_stage_title.text = "LEVEL %d  %s" % [index + 1, level.title]
	for child in _stage_row.get_children():
		child.queue_free()
	var first: Button = null
	for stage in level.stages:
		var button := _stage_button(stage)
		_stage_row.add_child(button)
		if not first and not button.disabled:
			first = button
	_stage_panel.show()
	if first:
		first.grab_focus()


func _close_stages() -> void:
	_stage_panel.hide()
	_cards[0].grab_focus()


# --- Layout

func _build() -> void:
	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 12
	title.offset_bottom = 30
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 16
	add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)
	for i in SaveGame.LEVELS.size():
		var card := _level_card(i)
		grid.add_child(card)
		_cards.append(card)

	var back := Button.new()
	back.text = "BACK"
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 8
	back.offset_top = -24
	back.offset_right = 64
	back.offset_bottom = -8
	back.pressed.connect(SaveGame.go_to.bind(SaveGame.START_MENU))
	add_child(back)

	_stage_panel = _build_stage_panel()


func _level_card(index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	var unlocked := SaveGame.is_level_unlocked(index)
	card.disabled = not unlocked
	card.mouse_entered.connect(func() -> void:
		if not card.disabled:
			card.grab_focus())
	card.pressed.connect(open_level.bind(index))
	card.draw.connect(func() -> void:
		var font := card.get_theme_font("font")
		var color := Color.WHITE if unlocked else Color(1, 1, 1, 0.35)
		card.draw_string(font, Vector2(0, 16), "LEVEL %d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 8, color)
		if unlocked:
			var lines := _wrap(font, SaveGame.LEVELS[index].title, CARD_SIZE.x - 4.0)
			for i in lines.size():
				card.draw_string(font, Vector2(0, 30 + i * 10), lines[i], HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 8, GOLD)
		else:
			PotionData.draw_lock_icon(card, Vector2(CARD_SIZE.x / 2.0, 34), Color(1, 1, 1, 0.45)))
	return card


## Splits `text` into lines no wider than `max_width` at size 8, by words.
func _wrap(font: Font, text: String, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var attempt := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > max_width:
			lines.append(line)
			line = word
		else:
			line = attempt
	if line != "":
		lines.append(line)
	return lines


func _stage_button(stage: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(52, 36)
	var unlocked := SaveGame.is_unlocked(stage)
	button.disabled = not unlocked
	if unlocked:
		button.text = stage
		button.pressed.connect(SaveGame.play_stage.bind(stage))
		button.mouse_entered.connect(button.grab_focus)
	else:
		button.draw.connect(func() -> void:
			var font := button.get_theme_font("font")
			button.draw_string(font, Vector2(0, 13), stage, HORIZONTAL_ALIGNMENT_CENTER, 52, 8, Color(1, 1, 1, 0.35))
			PotionData.draw_lock_icon(button, Vector2(26, 24), Color(1, 1, 1, 0.45)))
	return button


func _build_stage_panel() -> Control:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -110
	panel.offset_right = 110
	panel.offset_top = -50
	panel.offset_bottom = 50
	modal.add_child(panel)
	_stage_title = Label.new()
	_stage_title.add_theme_color_override("font_color", GOLD)
	_stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_title.position = Vector2(0, 8)
	_stage_title.size = Vector2(220, 10)
	panel.add_child(_stage_title)
	var row_center := CenterContainer.new()
	row_center.position = Vector2(0, 26)
	row_center.size = Vector2(220, 40)
	panel.add_child(row_center)
	_stage_row = HBoxContainer.new()
	_stage_row.add_theme_constant_override("separation", 8)
	row_center.add_child(_stage_row)
	var close := Button.new()
	close.text = "BACK"
	close.position = Vector2(80, 74)
	close.size = Vector2(60, 16)
	close.pressed.connect(_close_stages)
	panel.add_child(close)
	return modal
