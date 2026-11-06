extends Control
## The recipe book, which is also the game's pause menu. Opening it pauses
## the game (B, Esc or the book icon).
## Left page: a 2x2 crafting table pointing at a result box, the potions you
## hold, the ingredient storage, and MENU / SETTINGS / LOG buttons.
## Right page: every recipe, plus locked ones still to discover.
## Ingredients move by dragging or tapping, one per table box. Recipes are
## shapeless, and a table holding several copies of a recipe brews that many
## potions. Tap the result to brew.

signal opened
signal closed
## The player asked to see the dialogue log.
signal log_requested

const BOOK_SIZE := Vector2(360, 186)
const PAGE_SIZE := Vector2(174, 176)
const LEFT_PAGE := Vector2(5, 5)
const RIGHT_PAGE := Vector2(181, 5)
const SLOT := 22.0
const GAP := 2.0
const STORAGE_COLUMNS := 6
const STORAGE_ROWS := 2
## Positions on the left page.
const TABLE_AT := Vector2(35, 18)
const RESULT_AT := Vector2(113, 28)
const STATUS_Y := 76.0
const COUNTS_Y := 88.0
const STORAGE_AT := Vector2(16, 100)
const BUTTONS_Y := 154.0
const RECIPE_ROW_HEIGHT := 30.0
## Recipes not yet revealed, shown as locked rows.
const LOCKED_RECIPES := 1
const SLIDE_TIME := 0.25
const COVER_COLOR := Color(0.42, 0.2, 0.14)
const PAGE_COLOR := Color(0.94, 0.88, 0.74)
const INK := Color(0.35, 0.22, 0.14)

@export var inventory: Inventory
## False while dialogue plays or once the stage is over.
var enabled := true
var is_open := false

var _table: Array[StringName] = [&"", &"", &"", &""]
var _book: Control
var _table_slots: Array[IngredientSlot] = []
var _storage_slots: Array[IngredientSlot] = []
var _result_slot: IngredientSlot
var _settings: Control
var _dim := 0.0
var _status := ""
var _status_color := INK
var _status_alpha := 0.0
var _tween: Tween
var _status_tween: Tween


func _ready() -> void:
	hide()
	_build()
	inventory.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	# Never leave the tree paused if the scene changes with the book open.
	if visible:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_book") or event.is_action_pressed("ui_cancel"):
		if _settings.visible:
			_settings.hide()
		else:
			toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	show()
	_settings.hide()
	get_tree().paused = true
	_refresh()
	var viewport := get_viewport_rect().size
	_book.position = Vector2(roundf((viewport.x - BOOK_SIZE.x) / 2.0), viewport.y)
	_slide(viewport.y - BOOK_SIZE.y - 2.0, 0.45)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_return_table()
	_slide(get_viewport_rect().size.y, 0.0).tween_callback(func() -> void:
		hide()
		get_tree().paused = false
		closed.emit())


func _slide(to_y: float, to_dim: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_book, "position:y", to_y, SLIDE_TIME)
	_tween.tween_method(func(dim: float) -> void:
		_dim = dim
		queue_redraw(), _dim, to_dim, SLIDE_TIME)
	return _tween.chain()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, _dim))


# --- Crafting

func _on_slot_tapped(slot: IngredientSlot) -> void:
	# Read the kind first: changing the inventory refreshes the slots.
	var kind := slot.kind
	match slot.role:
		IngredientSlot.Role.STORAGE:
			var empty_cell := _table.find(&"")
			if kind != &"" and empty_cell >= 0 and inventory.take_ingredient(kind):
				_table[empty_cell] = kind
		IngredientSlot.Role.TABLE:
			if kind != &"":
				_table[slot.index] = &""
				inventory.return_ingredient(kind)
		IngredientSlot.Role.RESULT:
			_brew()
	_refresh()


func _on_slot_dropped(target: IngredientSlot, source: IngredientSlot) -> void:
	var kind := source.kind
	if source.role == IngredientSlot.Role.STORAGE and target.role == IngredientSlot.Role.TABLE:
		if inventory.take_ingredient(kind):
			if _table[target.index] != &"":
				inventory.return_ingredient(_table[target.index])
			_table[target.index] = kind
	elif source.role == IngredientSlot.Role.TABLE and target.role == IngredientSlot.Role.TABLE:
		_table[source.index] = _table[target.index]
		_table[target.index] = kind
	elif source.role == IngredientSlot.Role.TABLE and target.role == IngredientSlot.Role.STORAGE:
		inventory.return_ingredient(kind)
		_table[source.index] = &""
	_refresh()


func _brew() -> void:
	var result := inventory.match_recipe(_table)
	var potion: StringName = result.potion
	if potion == &"":
		return
	# The ingredients already left storage when they were placed on the table.
	_table.fill(&"")
	inventory.brew(potion, result.amount)
	var plural := "S" if result.amount > 1 else ""
	_flash_status("+%d %s POTION%s" % [result.amount, PotionData.NAMES[potion], plural], PotionData.color_of(potion).darkened(0.35))


func _return_table() -> void:
	for i in _table.size():
		if _table[i] != &"":
			inventory.return_ingredient(_table[i])
			_table[i] = &""


func _refresh() -> void:
	if not _book:
		return
	for i in _table_slots.size():
		_table_slots[i].show_contents(_table[i])
	for i in _storage_slots.size():
		var kind: StringName = inventory.ingredient_order[i] if i < inventory.ingredient_order.size() else &""
		var amount := inventory.ingredient_count(kind) if kind != &"" else 0
		_storage_slots[i].show_contents(kind if amount > 0 else &"", amount)
	var result := inventory.match_recipe(_table)
	var table_used := _table.any(func(kind: StringName) -> bool: return kind != &"")
	_result_slot.show_contents(result.potion, result.amount, table_used and result.potion == &"")
	_book.queue_redraw()


func _flash_status(text: String, color: Color) -> void:
	_status = text
	_status_color = color
	if _status_tween:
		_status_tween.kill()
	_status_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_status_tween.tween_method(_set_status_alpha, 1.0, 1.0, 1.2)
	_status_tween.tween_method(_set_status_alpha, 1.0, 0.0, 0.4)


func _set_status_alpha(alpha: float) -> void:
	_status_alpha = alpha
	_book.queue_redraw()


# --- Layout

func _build() -> void:
	_book = Control.new()
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.draw.connect(_draw_book)
	add_child(_book)

	for i in 4:
		var cell := Vector2(i % 2, floori(i / 2.0)) * (SLOT + GAP)
		_table_slots.append(_add_slot(IngredientSlot.Role.TABLE, i, LEFT_PAGE + TABLE_AT + cell, SLOT))
	_result_slot = _add_slot(IngredientSlot.Role.RESULT, 0, LEFT_PAGE + RESULT_AT, 26.0)
	for row in STORAGE_ROWS:
		for column in STORAGE_COLUMNS:
			var cell := Vector2(column, row) * (SLOT + GAP)
			_storage_slots.append(_add_slot(IngredientSlot.Role.STORAGE, _storage_slots.size(), LEFT_PAGE + STORAGE_AT + cell, SLOT))

	var close_button := Button.new()
	close_button.text = "X"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_color_override("font_color", INK)
	close_button.add_theme_color_override("font_hover_color", Color(0.75, 0.25, 0.2))
	close_button.position = RIGHT_PAGE + Vector2(PAGE_SIZE.x - 16, 1)
	close_button.size = Vector2(14, 14)
	close_button.pressed.connect(close)
	_book.add_child(close_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.position = LEFT_PAGE + Vector2(8, BUTTONS_Y)
	_book.add_child(buttons)
	var menu := _page_button("MENU", buttons)
	menu.pressed.connect(SaveGame.go_to.bind(SaveGame.START_MENU))
	var settings := _page_button("SETTINGS", buttons)
	settings.pressed.connect(func() -> void: _settings.show())
	var log_button := _page_button("LOG", buttons)
	log_button.pressed.connect(log_requested.emit)

	_settings = _build_settings()


func _add_slot(role: IngredientSlot.Role, index: int, at: Vector2, side: float) -> IngredientSlot:
	var slot := IngredientSlot.new(role, index, Vector2(side, side))
	slot.position = at
	slot.tapped.connect(_on_slot_tapped)
	slot.dropped.connect(_on_slot_dropped)
	_book.add_child(slot)
	return slot


func _page_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = " %s " % text
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _build_settings() -> Control:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.border_color = COVER_COLOR
	style.set_border_width_all(5)
	panel.add_theme_stylebox_override("panel", style)
	panel.size = BOOK_SIZE
	panel.hide()
	_book.add_child(panel)
	var title := _ink_label("SETTINGS", Vector2(0, 14), BOOK_SIZE.x)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var rows := [["MUSIC", SaveGame.music_volume, SaveGame.set_music_volume], ["SOUND", SaveGame.sound_volume, SaveGame.set_sound_volume]]
	for i in rows.size():
		var y := 46.0 + i * 30.0
		panel.add_child(_ink_label(rows[i][0], Vector2(70, y), 60))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = rows[i][1]
		slider.focus_mode = Control.FOCUS_NONE
		slider.position = Vector2(140, y - 2)
		slider.size = Vector2(150, 14)
		slider.value_changed.connect(rows[i][2])
		panel.add_child(slider)
	var fullscreen := CheckBox.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.button_pressed = SaveGame.fullscreen
	fullscreen.focus_mode = Control.FOCUS_NONE
	fullscreen.add_theme_color_override("font_color", INK)
	fullscreen.add_theme_color_override("font_hover_color", INK)
	fullscreen.add_theme_color_override("font_pressed_color", INK)
	fullscreen.add_theme_color_override("font_hover_pressed_color", INK)
	# Plain text on the page, not the dark HUD button box.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		fullscreen.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	fullscreen.position = Vector2(66, 104)
	fullscreen.toggled.connect(SaveGame.set_fullscreen)
	panel.add_child(fullscreen)
	var back_row := HBoxContainer.new()
	back_row.position = Vector2(156, 148)
	panel.add_child(back_row)
	var back := _page_button("BACK", back_row)
	back.pressed.connect(panel.hide)
	return panel


func _ink_label(text: String, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	label.position = at
	label.size = Vector2(width, 10)
	return label


func _draw_book() -> void:
	var font := get_theme_font("font", "Label")
	_book.draw_rect(Rect2(Vector2.ZERO, BOOK_SIZE), COVER_COLOR)
	_book.draw_rect(Rect2(Vector2.ZERO, BOOK_SIZE).grow(-1), COVER_COLOR.darkened(0.4), false, 2.0)
	for page in [LEFT_PAGE, RIGHT_PAGE]:
		_book.draw_rect(Rect2(page, PAGE_SIZE), PAGE_COLOR)
	# Shading where the pages meet the spine.
	_book.draw_rect(Rect2(LEFT_PAGE + Vector2(PAGE_SIZE.x - 4, 0), Vector2(4, PAGE_SIZE.y)), PAGE_COLOR.darkened(0.1))
	_book.draw_rect(Rect2(RIGHT_PAGE, Vector2(4, PAGE_SIZE.y)), PAGE_COLOR.darkened(0.1))

	# Left page: crafting.
	_page_text(font, "BREWING", LEFT_PAGE + Vector2(0, 12), INK)
	var arrow_y := LEFT_PAGE.y + TABLE_AT.y + SLOT + GAP / 2.0
	_draw_arrow(LEFT_PAGE.x + TABLE_AT.x + 2.0 * SLOT + GAP + 6.0, LEFT_PAGE.x + RESULT_AT.x - 6.0, arrow_y)
	if _status_alpha > 0.0:
		_page_text(font, _status, LEFT_PAGE + Vector2(0, STATUS_Y), Color(_status_color, _status_alpha))
	_draw_potion_counts(font)

	# Right page: recipes.
	_page_text(font, "RECIPES", RIGHT_PAGE + Vector2(0, 14), INK)
	var row := 0
	for potion in PotionData.KINDS:
		_draw_recipe_row(font, row, inventory.recipes.get(potion, {}), potion)
		row += 1
	for i in LOCKED_RECIPES:
		_draw_recipe_row(font, row, {}, &"")
		row += 1


## "[potion] x N" for each potion held, greyed out at 0.
func _draw_potion_counts(font: Font) -> void:
	var x := LEFT_PAGE.x + 8.0
	var y := LEFT_PAGE.y + COUNTS_Y
	for kind in PotionData.KINDS:
		var amount := inventory.count(kind)
		var faded := 1.0 if amount > 0 else 0.35
		_book.draw_rect(Rect2(x, y - 8, 16, 16), Color(IngredientSlot.FILL, faded))
		var icon_at := Vector2(x + 8, y + 1)
		if amount > 0:
			PotionData.draw_potion(_book, kind, icon_at)
		else:
			_draw_grey_potion(icon_at)
		_book.draw_string(font, Vector2(x + 18, y + 4), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, faded))
		x += 40.0


func _draw_grey_potion(at: Vector2) -> void:
	var grey := Color(0.55, 0.55, 0.55)
	_book.draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 3)), grey)
	_book.draw_circle(at, 3.0, grey)


func _draw_recipe_row(font: Font, row: int, recipe: Dictionary, potion: StringName) -> void:
	var top := RIGHT_PAGE + Vector2(10, 22 + row * RECIPE_ROW_HEIGHT)
	var mid_y := top.y + 13.0
	var locked := potion == &""
	_book.draw_rect(Rect2(top, Vector2(PAGE_SIZE.x - 18, 26)), PAGE_COLOR.darkened(0.16 if locked else 0.06))
	if locked:
		PotionData.draw_lock_icon(_book, Vector2(top.x + 14, mid_y + 1), INK)
		_book.draw_string(font, Vector2(top.x + 66, mid_y + 4), "???", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.6))
		return
	var x := top.x + 4.0
	for ingredient in recipe:
		for n in recipe[ingredient]:
			_book.draw_rect(Rect2(x, mid_y - 8, 16, 16), IngredientSlot.FILL)
			PotionData.draw_ingredient(_book, ingredient, Vector2(x + 8, mid_y))
			x += 18.0
	_draw_arrow(x + 3.0, x + 15.0, mid_y)
	_book.draw_rect(Rect2(x + 19, mid_y - 8, 16, 16), IngredientSlot.FILL)
	PotionData.draw_potion(_book, potion, Vector2(x + 27, mid_y + 1))
	_book.draw_string(font, Vector2(top.x + 66, mid_y + 4), PotionData.NAMES[potion], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)


func _draw_arrow(from_x: float, to_x: float, y: float) -> void:
	_book.draw_line(Vector2(from_x, y), Vector2(to_x - 3, y), INK, 2.0)
	_book.draw_colored_polygon(PackedVector2Array([Vector2(to_x, y), Vector2(to_x - 5, y - 4), Vector2(to_x - 5, y + 4)]), INK)


func _page_text(font: Font, text: String, at: Vector2, color: Color) -> void:
	_book.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, PAGE_SIZE.x, 8, color)
