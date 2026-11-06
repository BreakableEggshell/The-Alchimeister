extends Control
## The recipe book, which is also the game's pause menu. Opening it pauses
## the game (B, Esc or the book icon).
## MENU / SETTINGS / LOG buttons sit just above the book's top-right corner.
## Left page: a 2x2 crafting table pointing at a result box, the potions you
## hold, and the ingredient storage.
## Right page: a scrolling list of every recipe. Hovering (or tapping) an
## ingredient shows its name; hovering (or tapping) the potion shows its
## description. A tapped tip stays until you tap somewhere else. Potions not
## yet discovered show a lock and "???"; the Death recipe (any mix that isn't
## a recipe) cycles through random mixes.
## Ingredients move by dragging or tapping, one per table box. Recipes are
## shapeless, and a table holding several copies of a recipe brews that many
## potions. Any other mix brews a Death potion. Tap the result to brew.
## Arrows at the bottom corners turn the pages. Spread 2 lists what every
## potion (and cleansing water) does, with a SPECIAL section for the Death
## and secret potions (locked until discovered). Spread 3 is a checklist of
## the story's goals (flavour only for now).

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
## Gap between the top buttons and the book.
const BUTTONS_GAP := 2.0
const PAGE_ARROW_SIZE := Vector2(20, 12)
const CHECKLIST := ["Meet the Demon Lord", "Use ??? potion on the Demon Lord", "Remove the curse"]
const CHECKLIST_TOP := 26.0
const CHECKLIST_SPACING := 30.0
const CHECKBOX := 7.0
const LAST_PAGE := 2
## The effects spread: first entry's top, and each entry's height.
const EFFECTS_TOP := 22.0
const EFFECT_HEIGHT := 27.0
const CLEANSING_WATER := &"cleansing_water"
const CLEANSING_WATER_TEXT := "WASHES OFF ANY EFFECT"
## Top of the recipe list on the right page.
const RECIPES_TOP := 22.0
const RECIPE_ROW_HEIGHT := 18.0
const RECIPE_BOX := 14.0
## Baseline of the page titles.
const TITLE_BASELINE := 14.0
const TIP_COLOR := Color(0.16, 0.15, 0.22)
## Seconds between mixes shown on the Death recipe.
const CYCLE_TIME := 1.0
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
## The mix currently shown on the Death recipe row.
var _death_preview: Array[StringName] = []
var _recipe_scroll: ScrollContainer
var _recipe_list: Control
## Draws the tooltip above everything else in the book.
var _tip_layer: Control
## What the tooltip points at: {row, part}; part is an ingredient box index,
## or -1 for the potion. Empty for no tooltip.
var _tip := {}
## A tapped tooltip stays until the next tap elsewhere.
var _tip_pinned := false
## 0: brewing and recipes. 1: what everything does. 2: the checklist.
var _page := 0
## Everything on the brewing/recipes spread, hidden on the other one.
var _crafting_nodes: Array[Control] = []
var _checklist: Control
var _next_page: Button
var _previous_page: Button


func _ready() -> void:
	hide()
	_build()
	_roll_death_preview()
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


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		var part := _recipe_part_at(event.position)
		if not part.is_empty() or not _tip_pinned:
			_tip_pinned = false
			_set_tip(part)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var part := _recipe_part_at(event.position)
		_tip_pinned = not part.is_empty()
		_set_tip(part)


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
	_set_page(0)
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
	_tip_pinned = false
	_set_tip({})
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
	if potion == PotionData.SECRET:
		_flash_status("THE MIX WON'T SETTLE...", Color(INK, 0.8))
		return
	if potion == &"":
		return
	# The ingredients already left storage when they were placed on the table.
	_table.fill(&"")
	var discovered := PotionData.DISCOVERABLE.has(potion) and SaveGame.discover_potion(potion)
	inventory.brew(potion, result.amount)
	var text := "NEW: %s POTION!" % PotionData.NAMES[potion]
	if not discovered:
		var plural := "S" if result.amount > 1 else ""
		text = "+%d %s POTION%s" % [result.amount, PotionData.NAMES[potion], plural]
	_flash_status(text, PotionData.color_of(potion).darkened(0.35))


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
	var potion: StringName = result.potion
	var locked := potion == PotionData.SECRET or (potion != &"" and not SaveGame.is_potion_known(potion))
	_result_slot.show_contents(potion, result.amount, locked)
	_book.queue_redraw()
	_recipe_list.custom_minimum_size.y = _recipe_entries().size() * RECIPE_ROW_HEIGHT
	_recipe_list.queue_redraw()
	_tip_layer.queue_redraw()


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

	# The X is drawn by hand so it sits on the same baseline as "RECIPES".
	var close_button := Button.new()
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.position = RIGHT_PAGE + Vector2(PAGE_SIZE.x - 18, TITLE_BASELINE - 10)
	close_button.size = Vector2(14, 13)
	close_button.pressed.connect(close)
	close_button.draw.connect(func() -> void:
		var color := Color(0.75, 0.25, 0.2) if close_button.is_hovered() else INK
		close_button.draw_string(get_theme_font("font", "Label"), Vector2(0, 10), "X", HORIZONTAL_ALIGNMENT_CENTER, close_button.size.x, 8, color))
	_book.add_child(close_button)

	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.position = RIGHT_PAGE + Vector2(8, RECIPES_TOP)
	# Room at the bottom for the page arrow.
	_recipe_scroll.size = Vector2(PAGE_SIZE.x - 12, PAGE_SIZE.y - RECIPES_TOP - PAGE_ARROW_SIZE.y - 6)
	_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bar := _recipe_scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = PAGE_COLOR.darkened(0.12)
	track.content_margin_left = 2
	track.content_margin_right = 2
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(INK, 0.55 if state == "grabber" else 0.8)
		bar.add_theme_stylebox_override(state, grabber)
	_recipe_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		_tip_pinned = false
		_set_tip({}))
	_book.add_child(_recipe_scroll)
	_recipe_list = Control.new()
	_recipe_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.draw.connect(_draw_recipes)
	_recipe_scroll.add_child(_recipe_list)

	_crafting_nodes.append_array(_table_slots)
	_crafting_nodes.append_array(_storage_slots)
	_crafting_nodes.append(_result_slot)
	_crafting_nodes.append(_recipe_scroll)

	_next_page = _page_arrow(1, RIGHT_PAGE + PAGE_SIZE - PAGE_ARROW_SIZE - Vector2(6, 3))
	_previous_page = _page_arrow(-1, LEFT_PAGE + Vector2(6, PAGE_SIZE.y - PAGE_ARROW_SIZE.y - 3))
	_checklist = _build_checklist()

	# Above the book, lined up with its right edge; they slide with it.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	_book.add_child(buttons)
	var menu := _page_button("MENU", buttons)
	menu.pressed.connect(SaveGame.go_to.bind(SaveGame.START_MENU))
	var settings := _page_button("SETTINGS", buttons)
	settings.pressed.connect(func() -> void: _settings.show())
	var log_button := _page_button("LOG", buttons)
	log_button.pressed.connect(log_requested.emit)
	buttons.reset_size()
	buttons.position = Vector2(BOOK_SIZE.x - buttons.size.x, -buttons.size.y - BUTTONS_GAP)

	_settings = _build_settings()
	_settings.visibility_changed.connect(func() -> void:
		_tip_pinned = false
		_set_tip({}))

	_tip_layer = Control.new()
	_tip_layer.size = BOOK_SIZE
	_tip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_layer.draw.connect(_draw_tip)
	_book.add_child(_tip_layer)

	var cycle := Timer.new()
	cycle.wait_time = CYCLE_TIME
	cycle.autostart = true
	# The book pauses the game, but the Death recipe keeps cycling.
	cycle.process_mode = Node.PROCESS_MODE_ALWAYS
	cycle.timeout.connect(func() -> void:
		_roll_death_preview()
		_recipe_list.queue_redraw()
		_tip_layer.queue_redraw())
	add_child(cycle)


func _add_slot(role: IngredientSlot.Role, index: int, at: Vector2, side: float) -> IngredientSlot:
	var slot := IngredientSlot.new(role, index, Vector2(side, side))
	slot.position = at
	slot.tapped.connect(_on_slot_tapped)
	slot.dropped.connect(_on_slot_dropped)
	_book.add_child(slot)
	return slot


## A hand-drawn page-turn arrow; `direction` 1 points right, -1 left.
func _page_arrow(direction: int, at: Vector2) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "NEXT PAGE" if direction > 0 else "PREVIOUS PAGE"
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.position = at
	button.size = PAGE_ARROW_SIZE
	button.pressed.connect(func() -> void: _set_page(_page + direction))
	button.draw.connect(func() -> void:
		var color := Color(0.75, 0.25, 0.2) if button.is_hovered() else INK
		var y := button.size.y / 2.0
		var tip := button.size.x - 2.0 if direction > 0 else 2.0
		var tail := 2.0 if direction > 0 else button.size.x - 2.0
		button.draw_line(Vector2(tail, y), Vector2(tip - 3.0 * direction, y), color, 2.0)
		button.draw_colored_polygon(PackedVector2Array([Vector2(tip, y), Vector2(tip - 5.0 * direction, y - 4), Vector2(tip - 5.0 * direction, y + 4)]), color))
	_book.add_child(button)
	return button


## The second spread: the story's goals as an unticked checklist on the left
## page. Flavour only for now.
func _build_checklist() -> Control:
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.position = LEFT_PAGE
	page.size = PAGE_SIZE
	page.hide()
	_book.add_child(page)
	for i in CHECKLIST.size():
		var y := CHECKLIST_TOP + i * CHECKLIST_SPACING
		var label := _ink_label(CHECKLIST[i], Vector2(24, y), PAGE_SIZE.x - 34)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(label)
		# Sized once in the tree; before that it stretches to fit its text.
		label.set_deferred("size", Vector2(PAGE_SIZE.x - 34, CHECKLIST_SPACING - 4))
	page.draw.connect(func() -> void:
		for i in CHECKLIST.size():
			var box := Rect2(12, CHECKLIST_TOP + i * CHECKLIST_SPACING + 2, CHECKBOX, CHECKBOX)
			page.draw_rect(box.grow(-0.5), INK, false, 1.0))
	return page


func _set_page(page: int) -> void:
	_page = clampi(page, 0, LAST_PAGE)
	for node in _crafting_nodes:
		node.visible = _page == 0
	_checklist.visible = _page == 2
	_next_page.visible = _page < LAST_PAGE
	_previous_page.visible = _page > 0
	_tip_pinned = false
	_set_tip({})
	_book.queue_redraw()


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
	# The editor's Game tab ignores window mode changes, so say why it can't work.
	if Engine.is_embedded_in_editor():
		fullscreen.disabled = true
		fullscreen.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
		var note := _ink_label("(NOT IN THE EDITOR'S GAME TAB)", Vector2(70, 124), 240)
		note.add_theme_color_override("font_color", Color(INK, 0.6))
		panel.add_child(note)
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

	if _page == 1:
		_draw_effects(font)
		return
	if _page == 2:
		_page_text(font, "CHECKLIST", LEFT_PAGE + Vector2(0, TITLE_BASELINE), INK)
		return

	# Left page: crafting.
	_page_text(font, "BREWING", LEFT_PAGE + Vector2(0, 12), INK)
	var arrow_y := LEFT_PAGE.y + TABLE_AT.y + SLOT + GAP / 2.0
	_draw_arrow(_book, LEFT_PAGE.x + TABLE_AT.x + 2.0 * SLOT + GAP + 6.0, LEFT_PAGE.x + RESULT_AT.x - 6.0, arrow_y)
	if _status_alpha > 0.0:
		_page_text(font, _status, LEFT_PAGE + Vector2(0, STATUS_Y), Color(_status_color, _status_alpha))
	_draw_potion_counts(font)

	# Right page: the title; the list draws itself (_draw_recipes).
	_page_text(font, "RECIPES", RIGHT_PAGE + Vector2(0, TITLE_BASELINE), INK)


# --- Effects spread

## Left page: the four everyday potions and cleansing water. Right page: the
## SPECIAL ones, the Death potion and the secret potion, shown as a lock and
## "???" until discovered.
func _draw_effects(font: Font) -> void:
	_page_text(font, "EFFECTS", LEFT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	var y := LEFT_PAGE.y + EFFECTS_TOP
	for kind in [PotionData.FIRE, PotionData.KNOCKBACK, PotionData.FREEZE, PotionData.TRANSLUCENT, CLEANSING_WATER]:
		_draw_effect(font, kind, Vector2(LEFT_PAGE.x + 8, y))
		y += EFFECT_HEIGHT
	_page_text(font, "----- SPECIAL -----", RIGHT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	y = RIGHT_PAGE.y + EFFECTS_TOP
	for kind in [PotionData.DEATH, PotionData.SECRET]:
		_draw_effect(font, kind, Vector2(RIGHT_PAGE.x + 12, y))
		y += EFFECT_HEIGHT


## One entry: icon and name, and the hover description underneath.
func _draw_effect(font: Font, kind: StringName, at: Vector2) -> void:
	var known := kind == CLEANSING_WATER or (kind != PotionData.SECRET and SaveGame.is_potion_known(kind))
	var box := Rect2(at, Vector2(14, 14))
	_book.draw_rect(box, IngredientSlot.FILL)
	var icon_at := box.get_center() + Vector2(0, 1)
	var name := "???"
	var text := "???"
	if kind == CLEANSING_WATER:
		CleansingWater.draw_icon(_book, box.get_center())
		name = "CLEANSING WATER"
		text = CLEANSING_WATER_TEXT
	elif known:
		PotionData.draw_potion(_book, kind, icon_at)
		name = PotionData.NAMES[kind]
		text = PotionData.DESCRIPTIONS[kind]
	else:
		PotionData.draw_lock_icon(_book, icon_at, IngredientSlot.BORDER.lightened(0.4))
	var ink := INK if known else Color(INK, 0.6)
	_book.draw_string(font, at + Vector2(22, 11), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	_book.draw_string(font, at + Vector2(0, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(ink, ink.a * 0.75))


## "[potion] x N" for each potion held, greyed out at 0.
func _draw_potion_counts(font: Font) -> void:
	var kinds := PotionData.KINDS.filter(inventory.is_shown)
	# Spread to fit the page while a fifth potion (Death, when held) is listed.
	var step := minf(40.0, 166.0 / kinds.size())
	var x := LEFT_PAGE.x + (8.0 if step >= 40.0 else 4.0)
	var y := LEFT_PAGE.y + COUNTS_Y
	for kind in kinds:
		var amount := inventory.count(kind)
		var faded := 1.0 if amount > 0 else 0.35
		_book.draw_rect(Rect2(x, y - 8, 16, 16), Color(IngredientSlot.FILL, faded))
		var icon_at := Vector2(x + 8, y + 1)
		if amount > 0:
			PotionData.draw_potion(_book, kind, icon_at)
		else:
			_draw_grey_potion(icon_at)
		_book.draw_string(font, Vector2(x + 17, y + 4), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, faded))
		x += step


func _draw_grey_potion(at: Vector2) -> void:
	var grey := Color(0.55, 0.55, 0.55)
	_book.draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 3)), grey)
	_book.draw_circle(at, 3.0, grey)


# --- Recipe list

## Every recipe row in order: {ingredients, potion, known}. The secret recipe
## comes last.
func _recipe_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for potion in PotionData.KINDS:
		var ingredients := _death_preview if potion == PotionData.DEATH else _recipe_ingredients(potion)
		entries.append({"ingredients": ingredients, "potion": potion, "known": SaveGame.is_potion_known(potion)})
	entries.append({"ingredients": PotionData.INGREDIENTS, "potion": PotionData.SECRET, "known": false})
	return entries


## Where a row's parts sit, relative to the row's top-left: one box per
## ingredient, the arrow's ends, and the potion box plus its name.
func _recipe_layout(entry: Dictionary) -> Dictionary:
	var box_y := (RECIPE_ROW_HEIGHT - 1.0 - RECIPE_BOX) / 2.0
	var boxes: Array[Rect2] = []
	var x := 3.0
	for ingredient in entry.ingredients:
		boxes.append(Rect2(x, box_y, RECIPE_BOX, RECIPE_BOX))
		x += RECIPE_BOX + 1.0
	var title := _recipe_title(entry)
	var title_width := get_theme_font("font", "Label").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	return {
		"boxes": boxes,
		"arrow": Vector2(x + 2.0, x + 13.0),
		"potion_box": Rect2(x + 16.0, box_y, RECIPE_BOX, RECIPE_BOX),
		# The potion box and its name: the part that shows the description.
		"potion": Rect2(x + 16.0, box_y, RECIPE_BOX + 4.0 + title_width, RECIPE_BOX),
	}


func _recipe_title(entry: Dictionary) -> String:
	return PotionData.NAMES[entry.potion] if entry.known else "???"


func _draw_recipes() -> void:
	var font := get_theme_font("font", "Label")
	var entries := _recipe_entries()
	for row in entries.size():
		var entry: Dictionary = entries[row]
		var top := Vector2(0, row * RECIPE_ROW_HEIGHT)
		var layout := _recipe_layout(entry)
		_recipe_list.draw_rect(Rect2(top, Vector2(_recipe_list.size.x - 2.0, RECIPE_ROW_HEIGHT - 1.0)), PAGE_COLOR.darkened(0.06 if entry.known else 0.16))
		var mid_y: float = top.y + layout.boxes[0].get_center().y
		for i in layout.boxes.size():
			var box: Rect2 = layout.boxes[i]
			_recipe_list.draw_rect(Rect2(top + box.position, box.size), IngredientSlot.FILL)
			if entry.ingredients[i] != &"":
				PotionData.draw_ingredient(_recipe_list, entry.ingredients[i], top + box.get_center())
		_draw_arrow(_recipe_list, layout.arrow.x, layout.arrow.y, mid_y)
		var potion_box: Rect2 = layout.potion_box
		_recipe_list.draw_rect(Rect2(top + potion_box.position, potion_box.size), IngredientSlot.FILL)
		var icon_at := top + potion_box.get_center() + Vector2(0, 1)
		if entry.known:
			PotionData.draw_potion(_recipe_list, entry.potion, icon_at)
		else:
			PotionData.draw_lock_icon(_recipe_list, icon_at, IngredientSlot.BORDER.lightened(0.4))
		var title_at := Vector2(potion_box.end.x + 4.0, mid_y + 4.0)
		_recipe_list.draw_string(font, title_at, _recipe_title(entry), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK if entry.known else Color(INK, 0.6))


## The recipe part at a viewport position (from an input event), as
## {row, part}, or empty.
func _recipe_part_at(viewport_position: Vector2) -> Dictionary:
	if _settings.visible or _page != 0:
		return {}
	var in_view := _recipe_scroll.get_global_transform_with_canvas().affine_inverse() * viewport_position
	if not Rect2(Vector2.ZERO, _recipe_scroll.size).has_point(in_view):
		return {}
	var at := _recipe_list.get_global_transform_with_canvas().affine_inverse() * viewport_position
	var row := floori(at.y / RECIPE_ROW_HEIGHT)
	var entries := _recipe_entries()
	if row < 0 or row >= entries.size():
		return {}
	var entry: Dictionary = entries[row]
	var local := at - Vector2(0, row * RECIPE_ROW_HEIGHT)
	var layout := _recipe_layout(entry)
	for i in layout.boxes.size():
		if layout.boxes[i].has_point(local) and entry.ingredients[i] != &"":
			return {"row": row, "part": i}
	if layout.potion.has_point(local):
		return {"row": row, "part": -1}
	return {}


func _set_tip(part: Dictionary) -> void:
	if part != _tip:
		_tip = part
		_tip_layer.queue_redraw()


## Ingredient name or potion description for the current tip ("" for none).
## The Death row cycles, so this is worked out fresh each time.
func _tip_text() -> String:
	if _tip.is_empty():
		return ""
	var entry: Dictionary = _recipe_entries()[_tip.row]
	if _tip.part >= 0:
		return PotionData.INGREDIENT_NAMES.get(entry.ingredients[_tip.part], "")
	return PotionData.DESCRIPTIONS[entry.potion] if entry.known else "???"


## A small dark label just above what the tip points at (below it if that
## would cover the page title), kept inside the book.
func _draw_tip() -> void:
	var text := _tip_text()
	if text == "":
		return
	var font := get_theme_font("font", "Label")
	var entry: Dictionary = _recipe_entries()[_tip.row]
	var layout := _recipe_layout(entry)
	var target: Rect2 = layout.potion if _tip.part < 0 else layout.boxes[_tip.part]
	target.position += Vector2(0, _tip.row * RECIPE_ROW_HEIGHT) + _recipe_list.global_position - _book.global_position
	var box_size := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0, 13.0)
	var at := Vector2(target.get_center().x - box_size.x / 2.0, target.position.y - box_size.y - 2.0)
	if at.y < RIGHT_PAGE.y + RECIPES_TOP:
		at.y = target.end.y + 2.0
	at.x = clampf(at.x, 2.0, BOOK_SIZE.x - box_size.x - 2.0)
	at = at.round()
	_tip_layer.draw_rect(Rect2(at, box_size), TIP_COLOR)
	_tip_layer.draw_rect(Rect2(at, box_size).grow(-0.5), PAGE_COLOR, false)
	_tip_layer.draw_string(font, at + Vector2(4, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PAGE_COLOR)


## A recipe's ingredients as a flat list, one entry per box.
func _recipe_ingredients(potion: StringName) -> Array[StringName]:
	var recipe: Dictionary = inventory.recipes.get(potion, {})
	var list: Array[StringName] = []
	for ingredient in recipe:
		for n in recipe[ingredient]:
			list.append(ingredient)
	return list


## Picks a new random mix for the Death recipe: four boxes, each a random
## ingredient or empty, rerolled until it really would brew a Death potion.
func _roll_death_preview() -> void:
	var choices: Array[StringName] = PotionData.INGREDIENTS.duplicate()
	choices.append(&"")
	var mix: Array[StringName] = []
	while true:
		mix = []
		for i in 4:
			mix.append(choices.pick_random())
		if mix != _death_preview and inventory.match_recipe(mix).potion == PotionData.DEATH:
			break
	_death_preview = mix


func _draw_arrow(canvas: CanvasItem, from_x: float, to_x: float, y: float) -> void:
	canvas.draw_line(Vector2(from_x, y), Vector2(to_x - 3, y), INK, 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(to_x, y), Vector2(to_x - 5, y - 4), Vector2(to_x - 5, y + 4)]), INK)


func _page_text(font: Font, text: String, at: Vector2, color: Color) -> void:
	_book.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, PAGE_SIZE.x, 8, color)
