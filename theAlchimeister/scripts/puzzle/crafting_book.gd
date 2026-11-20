extends Control
## The recipe book, which is also the game's pause menu. Opening it pauses
## the game (B or the book icon).
## A gear (opening a popup of RESUME / RESTART / LEVELS / SETTINGS / MAIN
## MENU) and HINT sit just above the book's top-right
## corner (only the gear while SETTINGS is open). HINT first asks whether to
## take one, warning in red what it costs (hint_warning), then asks the stage
## for Sheldon's hint (hint_requested); the dialogue dims and covers the book
## while he talks. On a stage with no hint, or with hints locked, it says so
## instead. A stage can turn HINT off (set_hint_enabled). The
## level number sits at the other end of that row, above the book's top-left
## corner.
## Left page: a 2x2 crafting table pointing at a result box, the potions you
## hold, and the ingredient storage.
## Right page: a scrolling list of every recipe. Hovering (or tapping) an
## ingredient shows its name, and a tapped tip stays until you tap somewhere
## else. Tapping a potion puts one batch of its recipe on the table. A potion
## whose recipe hasn't been found yet (PotionData.RECIPE_TO_FIND) isn't listed,
## and its mix shows a lock on the result and won't brew. Found but never
## brewed, it shows a "?" and "???" until it is. The Death recipe (any mix that
## isn't a recipe) cycles through random mixes. The secret recipe stays locked.
## Ingredients move by dragging or tapping, one per table box. Recipes are
## shapeless, and a table holding several copies of a recipe brews that many
## potions. Any other mix brews a Death potion. Tap the result, or press the
## interact key shown under it, to brew.
## Keyboard: WASD / Tab move between everything (slots, page arrows,
## buttons), Enter or Space presses, Page Up / Page Down turn pages, B or
## B or Esc closes (backing out of the pause menu, CONTROLS, then SETTINGS, first).
## During play, Esc opens the pause menu on its own, without the book.
## Arrows at the bottom corners turn the pages. Spread 2 lists what every
## potion (and cleansing water) does, with a SPECIAL section for the Death
## and secret potions (a lock until their recipe is found, a "?" until
## brewed). Spread 3 shows brewing in
## bulk: several copies of a recipe on the table brew that many potions.
## Typing the DebugCode (wwssadad) in the pause menu opens its DEBUG tools,
## and adds DEBUG to the list until the player goes back to the start menu.
## There, SKIP LEVEL (off to start with) adds SKIP LEVEL to the pause menu,
## and SPEED BOOST (off to start with) makes the knight run twice as fast.
## Spread 4 is a checklist of the story's goals (flavour only for now), with a
## WANTED poster of the Demon King beside it.

signal opened
## The player asked to skip this level (from the gear's popup).
signal skip_requested
signal closed
## The player asked Sheldon for this stage's hint.
signal hint_requested
## The player asked to restart the level (from the pause menu).
signal restart_requested
## The player asked for the main menu (from the pause menu).
signal main_menu_requested
## The player asked for the level select (from the pause menu).
signal levels_requested

const BOOK_SIZE := Vector2(360, 186)
const PAGE_SIZE := Vector2(174, 176)
const LEFT_PAGE := Vector2(5, 5)
const RIGHT_PAGE := Vector2(181, 5)
const SLOT := 22.0
## Points from the brewing table to the result.
const CRAFT_ARROW := preload("res://assets/ui/craft_arrow.png")
## Space between the slots (their 2 px shadow sits in it).
const GAP := 4.0
const STORAGE_COLUMNS := 6
const STORAGE_ROWS := 2
## Positions on the left page.
const TABLE_AT := Vector2(35, 18)
const RESULT_AT := Vector2(113, 28)
const RESULT_SIZE := 26.0
const STATUS_Y := 76.0
const COUNTS_Y := 88.0
const STORAGE_AT := Vector2(16, 100)
## Gap between the top buttons and the book.
const BUTTONS_GAP := 2.0
const PAGE_ARROW_SIZE := Vector2(18, 20)
const CHECKLIST := ["Meet the Demon Lord", "Use ??? potion on the Demon Lord", "Remove the curse"]
## Each checklist line's SaveGame item: ticked once it's done.
const CHECKLIST_ITEMS := [SaveGame.CHECK_MET, SaveGame.CHECK_SECRET, SaveGame.CHECK_CURSE]
const CHECKLIST_TOP := 26.0
const CHECKLIST_SPACING := 30.0
const CHECKBOX := 7.0
const LAST_PAGE := 3
## Page numbers of the spreads.
const PAGE_BREWING := 0
const PAGE_EFFECTS := 1
const PAGE_BULK := 2
const PAGE_CHECKLIST := 3
## The bulk brewing spread: examples on each page (ingredient, how many).
const BULK_LEFT := [[PotionData.EMBER, 1], [PotionData.EMBER, 2], [PotionData.EMBER, 4]]
const BULK_RIGHT := [[PotionData.FROST_SHARD, 3], [PotionData.GHOST_WISP, 2]]
const BULK_ROW_HEIGHT := 34.0
const BULK_BOX := 12.0
## The WANTED poster on the checklist spread.
const POSTER_COLOR := Color(0.86, 0.74, 0.52)
const POSTER_INK := Color(0.45, 0.1, 0.08)
## Seconds a note above the buttons stays up.
const NOTE_TIME := 2.0
## The effects spread: first entry's top, and each entry's height.
const EFFECTS_TOP := 20.0
const EFFECT_HEIGHT := 24.0
## Gap between the two lines of a wrapped description.
const EFFECT_LINE := 8.0
## Effect descriptions are a touch smaller than the names above them. Scaled
## rather than a smaller font size, which spaces this pixel font unevenly.
const EFFECT_TEXT_SCALE := 0.875
const DEMON_KING := preload("res://assets/portraits/demonking/dk_default.png")
const CLEANSING_WATER := &"cleansing_water"
const NO_HINT_NOTE := "NO HINT FOR THIS LEVEL"
## The popup HINT gives where hints are locked.
const HINTS_LOCKED_TITLE := "CAN'T USE HINTS"
const HINTS_LOCKED_TEXT := "YOU ALREADY USED HINTS IN THE PREVIOUS LEVEL. I WANNA RECHARGE MY BRAIN THIS TIME."
const HINTS_LOCKED_WIDTH := 190.0
const NO_HINT_COLOR := Color(1.0, 0.6, 0.5)
const WARNING_COLOR := Color(1.0, 0.4, 0.4)
const GOLD := Color(0.95, 0.85, 0.55)
## The SPECIAL page's line for a potion still to be found, and for one found
## but never brewed.
const RECIPE_TO_FIND_TEXT := "RECIPE TO BE FOUND"
const UNBREWED_TEXT := "TO BE BREWED"
const GEAR_MARGIN := 10.0
const GEAR_TITLE_HEIGHT := 13.0
const GEAR_BUTTON_HEIGHT := 16.0
const GEAR_TEETH := 8
const GEAR_OUTER := 5.0
const GEAR_INNER := 3.5
const GEAR_HOLE := 1.5
const CLEANSING_WATER_TEXT := "WASHES OFF ANY EFFECT"
## Top of the recipe list on the right page.
const RECIPES_TOP := 22.0
const RECIPE_ROW_HEIGHT := 20.0
## Space between a recipe's boxes.
const RECIPE_BOX_GAP := 3.0
const RECIPE_BOX := 14.0
## Baseline of the page titles.
const TITLE_BASELINE := 14.0
const TIP_COLOR := Color(0.16, 0.15, 0.22)
## Seconds between mixes shown on the Death recipe.
const CYCLE_TIME := 1.0
const SLIDE_TIME := 0.25
const COVER_COLOR := Color(0.42, 0.2, 0.14)
## The paper colour in notebook.png.
const PAGE_COLOR := Color8(255, 244, 205)
## The open book drawn behind the pages: assets/notebook.png, stretched to
## BOOK_SIZE as a nine-patch (one per page) so its corners, cover edges and the
## dips at the spine stay pixel for pixel, at the same scale as the text.
const NOTEBOOK := preload("res://assets/ui/notebook/notebook.png")
## Each page's part of the art, and how much of each edge stays unstretched
## (all of every corner and cover edge: only the plain straight middle
## stretches):
## [region, left, top, right, bottom].
const NOTEBOOK_PAGES := [
	[Rect2(0, 0, 40, 86), 14, 23, 10, 21],
	[Rect2(40, 0, 39, 86), 9, 23, 14, 21],
]
## notebook.png's other two frames (79 x 86 each, beside the book): the same
## book with its page-turn tabs, and the closing ribbon on its own. These are
## those parts, drawn 1:1 as the buttons, as far from the book's edges as in
## the art (so they stay in its corners however wide it's drawn). The ribbon
## lies on top of whatever's on the page.
const NOTEBOOK_FRAME := 79.0
const NOTEBOOK_HEIGHT := 86.0
const PREVIOUS_TAB := Rect2(79 + 7, 59, 18, 20)
const NEXT_TAB := Rect2(79 + 54, 59, 18, 20)
const CLOSE_TAB := Rect2(158 + 50, 0, 13, 29)
## Hovered or picked with the keys.
const TAB_LIT := Color(1.2, 1.2, 1.2)
const INK := Color(0.35, 0.22, 0.14)

@export var inventory: Inventory
## False while dialogue plays or once the stage is over. The buttons above
## the book step away meanwhile (dialogue has its own in that corner).
var enabled := true:
	set(value):
		enabled = value
		if _buttons:
			_buttons.visible = value
			_note.visible = value
			_level_label.visible = value
			if not value:
				_gear_menu.hide()
				_hint_prompt.hide()
var is_open := false
## Whether this stage has a hint to give. If not, HINT says so.
var has_hint := true
## Hints are locked on this stage (one was taken on an earlier one).
var hints_locked := false
## What taking a hint costs, in red under HINT's question. Empty: nothing.
var hint_warning := ""
## Every hint here has been given: HINT just repeats them, without asking.
var hint_repeats := false

var _table: Array[StringName] = [&"", &"", &"", &""]
var _book: Control
var _table_slots: Array[IngredientSlot] = []
var _storage_slots: Array[IngredientSlot] = []
var _result_slot: IngredientSlot
var _settings: SettingsPanel
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
## See PAGE_BREWING, PAGE_EFFECTS, PAGE_BULK and PAGE_CHECKLIST.
var _page := PAGE_BREWING
## Everything on the brewing/recipes spread, hidden on the other one.
var _crafting_nodes: Array[Control] = []
var _checklist: Control
var _next_page: Button
var _previous_page: Button
var _buttons: HBoxContainer
var _gear_button: Button
## The gear's popup, dimming everything behind it, and its list of buttons.
var _gear_menu: Control
var _gear_panel: Panel
var _gear_list: VBoxContainer
var _gear_title: Label
## The current level, top left over the dim.
var _gear_level: Label
## The pause menu came up on its own, with the book hidden.
var _pause_only := false
var _skip_button: Button
## There's a level after this one to skip to.
var _can_skip := false
var _debug_button: Button
var _debug_menu: Control
var _debug_panel: Panel
var _debug_skip_toggle: Button
var _debug_speed_toggle: Button
var _locked_popup: Control
var _locked_ok: Button
var _code := DebugCode.new()
var _settings_button: Button
## "LEVEL 5 (2 - 2)", above the book's top-left corner.
var _level_label: Label
var _close_button: Button
## Red while hovered or focused: the X and the page arrows.
const ACTIVE_INK := Color(0.75, 0.25, 0.2)
var _hint_button: Button
## HINT's question: take a hint now, or later.
var _hint_prompt: Control
var _hint_panel: Panel
var _hint_title: Label
var _hint_warning: Label
var _hint_row: HBoxContainer
var _hint_yes: Button
var _hint_no: Button
## A short note above the buttons.
var _note: Label
var _note_tween: Tween


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
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
	# START on a controller ("pause") does as Esc does here.
	var escape := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	if event.is_action_pressed("toggle_book") or escape:
		if _hint_prompt.visible:
			_close_hint_prompt()
		elif _locked_popup.visible:
			_close_locked_popup()
		elif _debug_menu.visible:
			_close_debug_menu()
		elif _gear_menu.visible:
			_close_gear_menu()
		elif _settings.visible:
			_settings.back_out()
		elif escape and not is_open:
			_open_pause()
		else:
			toggle()
			if is_open:
				_focus_default()
		get_viewport().set_input_as_handled()
		return
	if not is_open or not enabled:
		return
	if event.is_action_pressed("ui_page_down") and not _popup_open():
		_set_page(_page + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_up") and not _popup_open():
		_set_page(_page - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and _on_brewing_page():
		_brew()
		get_viewport().set_input_as_handled()


## See UiFocus.
func focus_first() -> bool:
	if not is_open or not enabled:
		return false
	_focus_default()
	return true


## What keyboard focus starts on: the first storage (inventory) box on the
## brewing spread, otherwise the page arrow (or the X).
func _focus_default() -> void:
	if _hint_prompt.visible:
		_hint_no.grab_focus()
	elif _locked_popup.visible:
		_locked_ok.grab_focus()
	elif _debug_menu.visible:
		_debug_skip_toggle.grab_focus()
	elif _gear_menu.visible:
		_gear_list.get_child(0).grab_focus()
	elif _settings.visible:
		_settings.focus_first()
	elif _page == PAGE_BREWING:
		_storage_slots[0].grab_focus()
	elif _next_page.visible:
		_next_page.grab_focus()
	else:
		_previous_page.grab_focus()


## Back out of SETTINGS, onto its entry in the gear's list.
func _close_settings() -> void:
	_settings.hide()
	if _pause_only:
		_book.hide()
	_open_gear_menu()
	_settings_button.grab_focus()


## Where a word of the PAUSE MENU title is on screen (0 PAUSE, 1 MENU): on
## phones, tapping them as the DebugCode's taps (PAUSE left, MENU right, see
## DebugCode.feed_tap) opens the debug tools, as typing the code does. Clicks
## work the same on a PC.
func _gear_title_word(which: int) -> Rect2:
	var font := _gear_title.get_theme_font("font")
	var font_size := _gear_title.get_theme_font_size("font_size")
	var words := _gear_title.text.split(" ")
	var whole := font.get_string_size(_gear_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var before := 0.0 if which == 0 else font.get_string_size(words[0] + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := font.get_string_size(words[which], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var title := _gear_title.get_global_rect()
	var left := title.get_center().x - whole / 2.0 + before
	return Rect2(left, title.position.y, width, title.size.y).grow(2.0)


func _input(event: InputEvent) -> void:
	# Nothing in the book reacts while Sheldon talks over it.
	if not is_open or not enabled:
		return
	var tapped := _gear_menu.visible and _code.feed_tap(event, _gear_title_word(0), _gear_title_word(1))
	if (_code.feed(event) or tapped) and _gear_menu.visible:
		SaveGame.debug_unlocked = true
		_refresh_gear_buttons()
		_open_debug_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var part := _ingredient_at(event.position)
		if not part.is_empty() or not _tip_pinned:
			_tip_pinned = false
			_set_tip(part)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _recipe_part_at(event.position)
		if clicked.get("part", 0) < 0:
			_put_recipe_on_table(_recipe_entries()[clicked.row].potion)
		var part := _ingredient_at(event.position)
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
	_gear_menu.hide()
	_set_page(PAGE_BREWING)
	get_tree().paused = true
	_refresh()
	var viewport := get_viewport_rect().size
	_book.position = Vector2(roundf((viewport.x - BOOK_SIZE.x) / 2.0), viewport.y)
	_slide(viewport.y - BOOK_SIZE.y - 2.0, 0.45)
	opened.emit()


## Esc during play: the pause menu alone, without the book.
func _open_pause() -> void:
	if visible or not enabled:
		return
	is_open = true
	_pause_only = true
	show()
	_settings.hide()
	_set_page(PAGE_BREWING)
	_refresh()
	var viewport := get_viewport_rect().size
	_book.position = Vector2(roundf((viewport.x - BOOK_SIZE.x) / 2.0), viewport.y - BOOK_SIZE.y - 2.0)
	_book.hide()
	get_tree().paused = true
	_open_gear_menu()
	_gear_list.get_child(0).grab_focus()
	opened.emit()


## Closes the pause menu: back to the book or settings under it, or to the game
## if it came up on its own.
func _close_gear_menu() -> void:
	_gear_menu.hide()
	if _pause_only and not _settings.visible:
		close()
	elif _gear_button.is_visible_in_tree():
		_gear_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	_hint_prompt.hide()
	if _pause_only:
		is_open = false
		_pause_only = false
		_gear_menu.hide()
		_settings.hide()
		_book.show()
		hide()
		get_tree().paused = false
		closed.emit()
		return
	is_open = false
	_gear_menu.hide()
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
	if potion != &"" and not _recipe_found(potion):
		_flash_status("THE MIX WON'T SETTLE...", Color(INK, 0.8))
		return
	if potion == &"":
		return
	# The ingredients already left storage when they were placed on the table.
	_table.fill(&"")
	var discovered := PotionData.DISCOVERABLE.has(potion) and SaveGame.discover_potion(potion)
	inventory.brew(potion, result.amount)
	Sfx.play(Sfx.POTION_BREW, self)
	var text := "NEW: %s POTION!" % PotionData.NAMES[potion]
	if not discovered:
		var plural := "S" if result.amount > 1 else ""
		text = "+%d %s POTION%s" % [result.amount, PotionData.NAMES[potion], plural]
	_flash_status(text, PotionData.color_of(potion).darkened(0.35))


## One batch of `potion`'s recipe from storage onto the table. Anything else on
## the table goes back first, since it would spoil the mix.
func _put_recipe_on_table(potion: StringName) -> void:
	var recipe: Dictionary = inventory.recipes.get(potion, {})
	if potion == PotionData.SECRET and _recipe_found(potion):
		# The ??? potion: one of every ingredient.
		for ingredient in PotionData.INGREDIENTS:
			recipe[ingredient] = 1
	if recipe.is_empty():
		return
	for ingredient in recipe:
		if inventory.ingredient_count(ingredient) < recipe[ingredient]:
			_flash_status("NOT ENOUGH %s" % PotionData.INGREDIENT_NAMES[ingredient], Color(INK, 0.8))
			return
	for i in _table.size():
		if _table[i] != &"" and not recipe.has(_table[i]):
			inventory.return_ingredient(_table[i])
			_table[i] = &""
	var to_place: Array[StringName] = []
	for ingredient in recipe:
		for i in recipe[ingredient]:
			to_place.append(ingredient)
	if _table.count(&"") < to_place.size():
		_flash_status("THE TABLE IS FULL", Color(INK, 0.8))
		_refresh()
		return
	for ingredient in to_place:
		inventory.take_ingredient(ingredient)
		_table[_table.find(&"")] = ingredient
	_refresh()


func _on_brewing_page() -> bool:
	return _page == PAGE_BREWING and not _popup_open()


## SETTINGS, the pause menu or HINT's question is up over the pages.
func _popup_open() -> bool:
	return _settings.visible or _gear_menu.visible or _hint_prompt.visible or _debug_menu.visible or _locked_popup.visible


## Whether `potion` can be brewed: its recipe needn't be found, or has been. In
## the sandbox (unlimited ingredients) every recipe counts as found.
func _recipe_found(potion: StringName) -> bool:
	return inventory.unlimited or SaveGame.is_recipe_found(potion)


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
	# What's in storage, packed from the top-left box (no gaps where something
	# ran out), in the inventory's order.
	var held: Array[StringName] = []
	for kind in inventory.ingredient_order:
		if inventory.ingredient_count(kind) > 0:
			held.append(kind)
	for i in _storage_slots.size():
		var kind: StringName = held[i] if i < held.size() else &""
		_storage_slots[i].show_contents(kind, inventory.ingredient_count(kind) if kind != &"" else 0)
	var result := inventory.match_recipe(_table)
	var potion: StringName = result.potion
	# A lock until the recipe is found, then a "?" until it's first brewed.
	var locked := potion != &"" and not _recipe_found(potion)
	var unknown := not locked and potion != &"" and not SaveGame.is_potion_known(potion)
	_result_slot.show_contents(potion, result.amount, locked, unknown)
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
	_result_slot = _add_slot(IngredientSlot.Role.RESULT, 0, LEFT_PAGE + RESULT_AT, RESULT_SIZE)
	for row in STORAGE_ROWS:
		for column in STORAGE_COLUMNS:
			var cell := Vector2(column, row) * (SLOT + GAP)
			_storage_slots.append(_add_slot(IngredientSlot.Role.STORAGE, _storage_slots.size(), LEFT_PAGE + STORAGE_AT + cell, SLOT))

	# The bookmark with an X (CLOSE_TAB), at its place in the art.
	var close_button := Button.new()
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_ALL
	_close_button = close_button
	_label_close_button()
	SaveGame.controls_changed.connect(_label_close_button)
	SaveGame.controls_changed.connect(_book.queue_redraw)
	close_button.focus_entered.connect(close_button.queue_redraw)
	close_button.focus_exited.connect(close_button.queue_redraw)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.position = Vector2(BOOK_SIZE.x - (NOTEBOOK_FRAME - (CLOSE_TAB.position.x - 2.0 * NOTEBOOK_FRAME)), CLOSE_TAB.position.y)
	close_button.size = CLOSE_TAB.size
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(close_button.queue_redraw)
	close_button.mouse_exited.connect(close_button.queue_redraw)
	close_button.draw.connect(func() -> void:
		var lit := close_button.is_hovered() or close_button.has_focus()
		close_button.draw_texture_rect_region(NOTEBOOK, Rect2(Vector2.ZERO, CLOSE_TAB.size), CLOSE_TAB, TAB_LIT if lit else Color.WHITE))
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

	# The page-turn tabs, in the bottom corners as in the art.
	var tab_y := BOOK_SIZE.y - (NOTEBOOK_HEIGHT - NEXT_TAB.position.y)
	_next_page = _page_arrow(1, Vector2(BOOK_SIZE.x - (NOTEBOOK_FRAME - (NEXT_TAB.position.x - NOTEBOOK_FRAME)), tab_y))
	_previous_page = _page_arrow(-1, Vector2(PREVIOUS_TAB.position.x - NOTEBOOK_FRAME, tab_y))
	_checklist = _build_checklist()
	# The ribbon lies over the pages, whatever's on them.
	_close_button.move_to_front()

	# Above the book, lined up with its right edge; they slide with it.
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	_book.add_child(_buttons)
	_gear_button = _build_gear_button()
	_hint_button = _page_button("HINT", _buttons)
	_hint_button.tooltip_text = "ASK SHELDON FOR A HINT"
	_hint_button.pressed.connect(_on_hint_pressed)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_note.add_theme_constant_override("outline_size", 3)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.modulate.a = 0.0
	_book.add_child(_note)
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", Color.WHITE)
	_level_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_level_label.add_theme_constant_override("outline_size", 3)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_level_label)
	_place_buttons()

	_settings = SettingsPanel.new()
	_book.add_child(_settings)
	_settings.build(BOOK_SIZE)
	_settings.back_requested.connect(_close_settings)
	_settings.visibility_changed.connect(func() -> void:
		_show_page_buttons(not _settings.visible)
		_tip_pinned = false
		_set_tip({}))

	_gear_menu = _build_gear_menu()
	_hint_prompt = _build_hint_prompt()
	_debug_menu = _build_debug_menu()
	_locked_popup = _build_locked_popup()
	_refresh_gear_buttons()

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


func _label_close_button() -> void:
	_close_button.tooltip_text = "CLOSE (%s)" % Controls.key_name(&"toggle_book")


## The gear: a blank button with a cog drawn on it. Opens or closes its list.
func _build_gear_button() -> Button:
	var button := _page_button("  ", _buttons)
	button.tooltip_text = "PAUSE MENU"
	button.pressed.connect(func() -> void:
		_open_gear_menu()
		_gear_list.get_child(0).grab_focus())
	button.draw.connect(func() -> void:
		var center := (button.size / 2.0).round()
		var cog := PackedVector2Array()
		for i in GEAR_TEETH * 4:
			# Two points out on each tooth, two in on the gap after it.
			var angle := (i - 0.5) * TAU / (GEAR_TEETH * 4)
			var radius := GEAR_OUTER if i % 4 < 2 else GEAR_INNER
			cog.append(center + Vector2.from_angle(angle) * radius)
		button.draw_colored_polygon(cog, Color.WHITE)
		button.draw_circle(center, GEAR_HOLE, Color(0.1, 0.09, 0.14)))
	return button


## The gear's popup, in the middle of the screen over a dim. A click on the dim
## closes it; keyboard focus stays inside it until it closes.
func _build_gear_menu() -> Control:
	var modal := Control.new()
	modal.hide()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_gear_menu())
	_gear_level = Label.new()
	_gear_level.add_theme_color_override("font_color", Color.WHITE)
	_gear_level.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_gear_level.add_theme_constant_override("outline_size", 3)
	_gear_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(_gear_level)
	_gear_panel = Panel.new()
	# The menu frame (menu_bg.png, stretched by its middle).
	_gear_panel.add_theme_stylebox_override("panel", preload("res://scenes/ui/menu_bg_style.tres"))
	modal.add_child(_gear_panel)
	_gear_title = Label.new()
	_gear_title.text = "PAUSE MENU"
	_gear_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_gear_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gear_panel.add_child(_gear_title)
	_gear_title.position = Vector2(0, GEAR_MARGIN - 1.0)
	_gear_list = VBoxContainer.new()
	_gear_list.add_theme_constant_override("separation", 3)
	_gear_list.position = Vector2(GEAR_MARGIN, GEAR_MARGIN + GEAR_TITLE_HEIGHT)
	_gear_panel.add_child(_gear_list)
	var resume := _page_button("RESUME", _gear_list)
	resume.pressed.connect(close)
	var restart := _page_button("RESTART", _gear_list)
	restart.pressed.connect(_restart_level)
	var levels := _page_button("LEVELS", _gear_list)
	levels.pressed.connect(func() -> void:
		modal.hide()
		levels_requested.emit())
	_skip_button = _page_button("SKIP LEVEL", _gear_list)
	_skip_button.pressed.connect(skip_requested.emit)
	_settings_button = _page_button("SETTINGS", _gear_list)
	_settings_button.pressed.connect(func() -> void:
		modal.hide()
		_book.show()
		_settings.open())
	_debug_button = _page_button("DEBUG", _gear_list)
	_debug_button.pressed.connect(_open_debug_menu)
	var menu := _page_button("MAIN MENU", _gear_list)
	menu.pressed.connect(func() -> void:
		modal.hide()
		main_menu_requested.emit())
	# A little room above and below each label.
	for button in _gear_list.get_children():
		button.custom_minimum_size.y = GEAR_BUTTON_HEIGHT
	return modal


## SKIP LEVEL (debug, and only with a level to skip to) and DEBUG (once the
## code has been typed) come and go; keys step through what's shown.
func _refresh_gear_buttons() -> void:
	_skip_button.visible = _can_skip and SaveGame.debug_skip_level
	_debug_button.visible = SaveGame.debug_unlocked
	UiFocus.link_column(_gear_list.get_children().filter(func(button: Button) -> bool: return button.visible))
	if _gear_menu.visible:
		_open_gear_menu()


# --- DEBUG

## The pause menu's debug tools, in place of the pause menu.
func _build_debug_menu() -> Control:
	var modal := _popup_modal(_close_debug_menu)
	_debug_panel = Panel.new()
	_debug_panel.add_theme_stylebox_override("panel", _gear_panel.get_theme_stylebox("panel"))
	modal.add_child(_debug_panel)
	var title := Label.new()
	title.text = "DEBUG"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, GEAR_MARGIN - 3.0)
	_debug_panel.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.position = Vector2(GEAR_MARGIN, GEAR_MARGIN + GEAR_TITLE_HEIGHT)
	_debug_panel.add_child(list)
	_debug_skip_toggle = _page_button("", list)
	_debug_skip_toggle.pressed.connect(func() -> void:
		SaveGame.debug_skip_level = not SaveGame.debug_skip_level
		_label_debug_menu()
		_refresh_gear_buttons())
	_debug_speed_toggle = _page_button("", list)
	_debug_speed_toggle.pressed.connect(func() -> void:
		SaveGame.debug_speed_boost = not SaveGame.debug_speed_boost
		_label_debug_menu())
	var back := _page_button("BACK", list)
	back.pressed.connect(_close_debug_menu)
	for button in list.get_children():
		button.custom_minimum_size.y = GEAR_BUTTON_HEIGHT
	UiFocus.link_column(list.get_children())
	_label_debug_menu()
	list.reset_size()
	_debug_panel.size = list.size + Vector2(GEAR_MARGIN * 2.0, GEAR_MARGIN * 2.0 + GEAR_TITLE_HEIGHT)
	title.size = Vector2(_debug_panel.size.x, GEAR_TITLE_HEIGHT)
	return modal


func _label_debug_menu() -> void:
	# Both labels the same length, so the panel doesn't change size.
	_debug_skip_toggle.text = " SKIP LEVEL:  %s " % ("ON " if SaveGame.debug_skip_level else "OFF")
	_debug_speed_toggle.text = " SPEED BOOST: %s " % ("ON " if SaveGame.debug_speed_boost else "OFF")


func _open_debug_menu() -> void:
	_gear_menu.hide()
	_debug_menu.show()
	_debug_panel.position = ((get_viewport_rect().size - _debug_panel.size) / 2.0).round()
	_debug_skip_toggle.grab_focus()


func _close_debug_menu() -> void:
	_debug_menu.hide()
	_open_gear_menu()
	_debug_button.grab_focus()


## HINT's answer where hints are locked: why, and OK.
func _build_locked_popup() -> Control:
	var modal := _popup_modal(_close_locked_popup)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _gear_panel.get_theme_stylebox("panel"))
	modal.add_child(panel)
	var width := HINTS_LOCKED_WIDTH
	var title := Label.new()
	title.text = HINTS_LOCKED_TITLE
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var lines := _wrap(get_theme_font("font", "Label"), HINTS_LOCKED_TEXT, width - GEAR_MARGIN * 2.0)
	var text := Label.new()
	text.text = "\n".join(lines)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(text)
	_locked_ok = _page_button("OK", panel)
	_locked_ok.custom_minimum_size = Vector2(48, GEAR_BUTTON_HEIGHT)
	_locked_ok.pressed.connect(_close_locked_popup)
	var y := GEAR_MARGIN - 3.0
	title.position = Vector2(0, y)
	title.size = Vector2(width, 10)
	y += GEAR_TITLE_HEIGHT + 2.0
	text.position = Vector2(GEAR_MARGIN, y)
	text.size = Vector2(width - GEAR_MARGIN * 2.0, lines.size() * 10.0)
	y += lines.size() * 10.0 + 6.0
	_locked_ok.reset_size()
	_locked_ok.position = Vector2(roundf((width - _locked_ok.size.x) / 2.0), y)
	panel.size = Vector2(width, y + _locked_ok.size.y + GEAR_MARGIN)
	panel.position = ((get_viewport_rect().size - panel.size) / 2.0).round()
	return modal


func _open_locked_popup() -> void:
	_locked_popup.show()
	_locked_ok.grab_focus()


func _close_locked_popup() -> void:
	_locked_popup.hide()
	if _hint_button.is_visible_in_tree():
		_hint_button.grab_focus()


## A full-screen layer over a dim; a click on the dim calls `on_dismiss`.
func _popup_modal(on_dismiss: Callable) -> Control:
	var modal := Control.new()
	modal.hide()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			on_dismiss.call())
	return modal


func _open_gear_menu() -> void:
	_gear_menu.show()
	_gear_list.reset_size()
	_gear_panel.size = _gear_list.size + Vector2(GEAR_MARGIN * 2.0, GEAR_MARGIN * 2.0 + GEAR_TITLE_HEIGHT)
	_gear_title.size = Vector2(_gear_panel.size.x, GEAR_TITLE_HEIGHT)
	# Exactly where the notebook shows it, so the two never show side by side.
	var viewport := get_viewport_rect().size
	_gear_level.position = Vector2(roundf((viewport.x - BOOK_SIZE.x) / 2.0), viewport.y - BOOK_SIZE.y - 2.0) + _level_label.position
	_gear_panel.position = ((get_viewport_rect().size - _gear_panel.size) / 2.0).round()


## RESTART: everything closes at once and the stage restarts.
func _restart_level() -> void:
	_gear_menu.hide()
	_settings.hide()
	_hint_prompt.hide()
	_return_table()
	is_open = false
	_pause_only = false
	_book.show()
	hide()
	get_tree().paused = false
	closed.emit()
	restart_requested.emit()


# --- HINT

## Gives the hint after asking (see _open_hint_prompt), or says why there isn't one.
func _on_hint_pressed() -> void:
	_settings.hide()
	_gear_menu.hide()
	if not has_hint:
		_show_note(NO_HINT_NOTE, NO_HINT_COLOR)
	elif hints_locked:
		_open_locked_popup()
	elif hint_repeats:
		hint_requested.emit()
	else:
		_open_hint_prompt()


## The stage's HINT button works (or is greyed out and does nothing).
func set_hint_enabled(on: bool) -> void:
	_hint_button.disabled = not on
	_hint_button.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


## HINT's question, in the middle of the screen over a dim: HINT or LOOK AROUND
## FIRST, with what a hint costs in red between. A click on the dim closes it.
func _build_hint_prompt() -> Control:
	var modal := Control.new()
	modal.hide()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_hint_prompt())
	_hint_panel = Panel.new()
	_hint_panel.add_theme_stylebox_override("panel", _gear_panel.get_theme_stylebox("panel"))
	modal.add_child(_hint_panel)
	_hint_title = Label.new()
	_hint_title.text = "ASK SHELDON FOR A HINT?"
	_hint_title.add_theme_color_override("font_color", GOLD)
	_hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_title)
	_hint_warning = Label.new()
	_hint_warning.add_theme_color_override("font_color", WARNING_COLOR)
	_hint_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_warning)
	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override("separation", 6)
	_hint_panel.add_child(_hint_row)
	_hint_yes = _page_button("HINT", _hint_row)
	_hint_yes.pressed.connect(func() -> void:
		_close_hint_prompt()
		hint_requested.emit())
	_hint_no = _page_button("LATER", _hint_row)
	_hint_no.pressed.connect(_close_hint_prompt)
	UiFocus.link_row([_hint_yes, _hint_no])
	return modal


## Lays the question out around the current warning and shows it. With a cost
## to warn about, LATER is the safe default.
func _open_hint_prompt() -> void:
	_hint_prompt.show()
	_hint_row.reset_size()
	var font := get_theme_font("font", "Label")
	var title_width := font.get_string_size(_hint_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var width := maxf(_hint_row.size.x, title_width) + GEAR_MARGIN * 2.0
	var y := GEAR_MARGIN - 3.0
	_hint_title.position = Vector2(0, y)
	_hint_title.size = Vector2(width, 10)
	y += GEAR_TITLE_HEIGHT + 2.0
	_hint_warning.visible = hint_warning != ""
	if _hint_warning.visible:
		var lines := _wrap(font, hint_warning, width - GEAR_MARGIN * 2.0)
		_hint_warning.text = "\n".join(lines)
		_hint_warning.position = Vector2(GEAR_MARGIN, y)
		_hint_warning.size = Vector2(width - GEAR_MARGIN * 2.0, lines.size() * 10.0)
		y += lines.size() * 10.0 + 6.0
	_hint_row.position = Vector2(roundf((width - _hint_row.size.x) / 2.0), y)
	_hint_panel.size = Vector2(width, y + _hint_row.size.y + GEAR_MARGIN)
	_hint_panel.position = ((get_viewport_rect().size - _hint_panel.size) / 2.0).round()
	(_hint_no if _hint_warning.visible else _hint_yes).grab_focus()


func _close_hint_prompt() -> void:
	_hint_prompt.hide()
	if _hint_button.is_visible_in_tree():
		_hint_button.grab_focus()


func set_level_label(text: String) -> void:
	_level_label.text = text
	_gear_level.text = text


## SKIP LEVEL only shows when there's a level to skip to (and the debug
## option is on).
func set_can_skip(can_skip: bool) -> void:
	_can_skip = can_skip
	_refresh_gear_buttons()


## HINT is no use on the settings page.
func _show_page_buttons(shown: bool) -> void:
	_hint_button.visible = shown
	_note.modulate.a = 0.0
	_place_buttons.call_deferred()


## Lines the button row up with the book's right edge, just above it.
func _place_buttons() -> void:
	_buttons.reset_size()
	_buttons.position = Vector2(BOOK_SIZE.x - _buttons.size.x, -_buttons.size.y - BUTTONS_GAP)
	_level_label.reset_size()
	_level_label.position = Vector2(0, _buttons.position.y + (_buttons.size.y - _level_label.size.y) / 2.0)


## A note just above the buttons that fades after a moment.
func _show_note(text: String, color: Color) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", color)
	_note.size = Vector2(BOOK_SIZE.x, 10)
	_note.position = Vector2(0, _buttons.position.y - 12)
	_note.modulate.a = 1.0
	if _note_tween:
		_note_tween.kill()
	_note_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_note_tween.tween_interval(NOTE_TIME)
	_note_tween.tween_property(_note, "modulate:a", 0.0, 0.4)


func _add_slot(role: IngredientSlot.Role, index: int, at: Vector2, side: float) -> IngredientSlot:
	var slot := IngredientSlot.new(role, index, Vector2(side, side))
	slot.position = at
	slot.tapped.connect(_on_slot_tapped)
	slot.dropped.connect(_on_slot_dropped)
	_book.add_child(slot)
	return slot


## The box around the X or a page arrow while the keyboard is on it.
## A page-turn tab (notebook.png's), `direction` 1 for the next page, -1 the previous.
func _page_arrow(direction: int, at: Vector2) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.focus_entered.connect(button.queue_redraw)
	button.focus_exited.connect(button.queue_redraw)
	button.tooltip_text = "NEXT PAGE (PG DN)" if direction > 0 else "PREVIOUS PAGE (PG UP)"
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.position = at
	button.size = PAGE_ARROW_SIZE
	button.pressed.connect(func() -> void: _set_page(_page + direction))
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)
	var tab := NEXT_TAB if direction > 0 else PREVIOUS_TAB
	button.draw.connect(func() -> void:
		var lit := button.is_hovered() or button.has_focus()
		button.draw_texture_rect_region(NOTEBOOK, Rect2(Vector2.ZERO, tab.size), tab, TAB_LIT if lit else Color.WHITE))
	_book.add_child(button)
	return button


## The last spread: the story's goals as an unticked checklist on the left
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
			page.draw_rect(box.grow(-0.5), INK, false, 1.0)
			if SaveGame.is_checklist_done(CHECKLIST_ITEMS[i]):
				# A tick, reaching a little out of the box.
				var tick := PackedVector2Array([box.position + Vector2(1, 3.5), box.position + Vector2(3, 6), box.position + Vector2(8, -1)])
				page.draw_polyline(tick, INK, 1.5))
	return page


func _ink_label(text: String, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	label.position = at
	label.size = Vector2(width, 10)
	return label


func _set_page(page: int) -> void:
	_page = clampi(page, 0, LAST_PAGE)
	var focused := get_viewport().gui_get_focus_owner()
	for node in _crafting_nodes:
		node.visible = _page == PAGE_BREWING
	_checklist.visible = _page == PAGE_CHECKLIST
	_checklist.queue_redraw()
	_next_page.visible = _page < LAST_PAGE
	_previous_page.visible = _page > 0
	# Keep keyboard focus on the page: the arrow that turned it if it's still
	# there, else something on the new spread.
	if focused and is_open and (not is_instance_valid(focused) or not focused.is_visible_in_tree()):
		_focus_default()
	_tip_pinned = false
	_set_tip({})
	_book.queue_redraw()


func _page_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = " %s " % text
	button.focus_mode = Control.FOCUS_ALL
	# The btn.png look (see the HUD theme).
	button.theme_type_variation = &"WoodButton"
	parent.add_child(button)
	return button


## notebook.png across the whole book, each half stretched over its page.
func _draw_notebook() -> void:
	var half := BOOK_SIZE.x / 2.0
	for i in NOTEBOOK_PAGES.size():
		var part: Array = NOTEBOOK_PAGES[i]
		var style := StyleBoxTexture.new()
		style.texture = NOTEBOOK
		style.region_rect = part[0]
		style.texture_margin_left = part[1]
		style.texture_margin_top = part[2]
		style.texture_margin_right = part[3]
		style.texture_margin_bottom = part[4]
		_book.draw_style_box(style, Rect2(half * i, 0, half, BOOK_SIZE.y))


func _draw_book() -> void:
	var font := get_theme_font("font", "Label")
	_draw_notebook()

	if _page == PAGE_EFFECTS:
		_draw_effects(font)
		return
	if _page == PAGE_BULK:
		_draw_bulk(font)
		return
	if _page == PAGE_CHECKLIST:
		_page_text(font, "CHECKLIST", LEFT_PAGE + Vector2(0, TITLE_BASELINE), INK)
		_draw_wanted(font)
		return

	# Left page: crafting.
	_page_text(font, "BREWING", LEFT_PAGE + Vector2(0, 12), INK)
	var arrow_y := LEFT_PAGE.y + TABLE_AT.y + SLOT + GAP / 2.0
	# The arrow from the table to the result (craft_arrow.png), centred between them.
	var arrow_x := (LEFT_PAGE.x + TABLE_AT.x + 2.0 * SLOT + GAP + LEFT_PAGE.x + RESULT_AT.x) / 2.0
	_book.draw_texture(CRAFT_ARROW, (Vector2(arrow_x, arrow_y) - CRAFT_ARROW.get_size() / 2.0).round())
	if _status_alpha > 0.0:
		_page_text(font, _status, LEFT_PAGE + Vector2(0, STATUS_Y), Color(_status_color, _status_alpha))
	# The key that brews, under the result box.
	var result_ready: bool = _result_slot.kind != &"" and not _result_slot.locked
	var key_at := LEFT_PAGE + RESULT_AT + Vector2(-20, RESULT_SIZE + 10.0)
	_book.draw_string(font, key_at, Controls.key_name(&"interact"), HORIZONTAL_ALIGNMENT_CENTER, RESULT_SIZE + 40.0, 8, Color(INK, 1.0 if result_ready else 0.4))
	_draw_potion_counts(font)

	# Right page: the title; the list draws itself (_draw_recipes).
	_page_text(font, "RECIPES", RIGHT_PAGE + Vector2(0, TITLE_BASELINE), INK)


# --- Effects spread

## Left page: the four everyday potions and cleansing water. Right page: the
## SPECIAL ones, the Death potion and the secret potion: a lock and "???"
## until the recipe is found (the secret one stays that way), then a "?" until
## first brewed.
func _draw_effects(font: Font) -> void:
	_page_text(font, "EFFECTS", LEFT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	var y := LEFT_PAGE.y + EFFECTS_TOP
	for kind in [PotionData.FIRE, PotionData.KNOCKBACK, PotionData.FREEZE, PotionData.TRANSLUCENT, CLEANSING_WATER]:
		y += EFFECT_HEIGHT + _draw_effect(font, kind, Vector2(LEFT_PAGE.x + 8, y))
	_page_text(font, "----- SPECIAL -----", RIGHT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	y = RIGHT_PAGE.y + EFFECTS_TOP
	for kind in [PotionData.DEATH, PotionData.SECRET]:
		y += EFFECT_HEIGHT + _draw_effect(font, kind, Vector2(RIGHT_PAGE.x + 12, y))


## One entry: icon, name and a rough duration, and the description underneath, wrapped onto a
## second line if it's too wide for the page. Returns the extra height used.
func _draw_effect(font: Font, kind: StringName, at: Vector2) -> float:
	var found := _recipe_found(kind)
	var known := kind == CLEANSING_WATER or (found and SaveGame.is_potion_known(kind))
	var box := Rect2(at, Vector2(14, 14))
	PotionData.draw_box(_book, box)
	var icon_at := box.get_center()
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
	elif found:
		PotionData.draw_unknown_icon(_book, icon_at, IngredientSlot.BORDER.lightened(0.4))
		text = UNBREWED_TEXT
	else:
		PotionData.draw_lock_icon(_book, icon_at, IngredientSlot.BORDER.lightened(0.4))
		if kind != PotionData.SECRET:
			text = RECIPE_TO_FIND_TEXT
	var ink := INK if known else Color(INK, 0.6)
	_book.draw_string(font, at + Vector2(22, 11), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	# How long it lasts, roughly, at the end of the name line.
	var lasts := PotionData.duration_estimate(kind) if known else ""
	if lasts != "":
		var lasts_width := font.get_string_size(lasts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var right := (LEFT_PAGE.x + PAGE_SIZE.x - 8.0) if at.x < RIGHT_PAGE.x else (RIGHT_PAGE.x + PAGE_SIZE.x - 2.0)
		_book.draw_string(font, Vector2(right - lasts_width, at.y + 11), lasts, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(ink, ink.a * 0.75))
	# Up to the page edge (the entry is indented from the page by at.x),
	# keeping clear of the spine on the left page.
	var on_left := at.x < RIGHT_PAGE.x
	var page_x := LEFT_PAGE.x if on_left else RIGHT_PAGE.x
	var lines := _wrap(font, text, (PAGE_SIZE.x - (at.x - page_x) - (8.0 if on_left else 2.0)) / EFFECT_TEXT_SCALE)
	for i in lines.size():
		_book.draw_set_transform(at + Vector2(0, 22 + i * EFFECT_LINE), 0.0, Vector2.ONE * EFFECT_TEXT_SCALE)
		_book.draw_string(font, Vector2.ZERO, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(ink, ink.a * 0.75))
	_book.draw_set_transform(Vector2.ZERO)
	return (lines.size() - 1) * EFFECT_LINE


## `text` split into lines no wider than `width`, breaking at spaces. A lone
## last word takes one from the line before, so it isn't left on its own.
func _wrap(font: Font, text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var longer := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width:
			lines.append(line)
			line = word
		else:
			line = longer
	lines.append(line)
	var count := lines.size()
	if count > 1 and not lines[count - 1].contains(" ") and lines[count - 2].contains(" "):
		var cut := lines[count - 2].rfind(" ")
		lines[count - 1] = lines[count - 2].substr(cut + 1) + " " + lines[count - 1]
		lines[count - 2] = lines[count - 2].substr(0, cut)
	return lines


# --- Bulk brewing spread

## Left page: one, two and four embers on the table brew one, two and four
## fire potions. Right page: the same works for any recipe, and one tap on
## the result brews them all.
func _draw_bulk(font: Font) -> void:
	_page_text(font, "BULK BREWING", LEFT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	_page_text(font, "MORE OF ONE INGREDIENT,", LEFT_PAGE + Vector2(0, 30), Color(INK, 0.8))
	_page_text(font, "MORE OF ITS POTION.", LEFT_PAGE + Vector2(0, 41), Color(INK, 0.8))
	var y := LEFT_PAGE.y + 52.0
	for example in BULK_LEFT:
		_draw_bulk_row(font, example[0], example[1], Vector2(LEFT_PAGE.x + 34, y))
		y += BULK_ROW_HEIGHT
	_page_text(font, "ANY RECIPE WORKS", RIGHT_PAGE + Vector2(0, TITLE_BASELINE), INK)
	y = RIGHT_PAGE.y + 30.0
	for example in BULK_RIGHT:
		_draw_bulk_row(font, example[0], example[1], Vector2(RIGHT_PAGE.x + 34, y))
		y += BULK_ROW_HEIGHT
	_page_text(font, "ONE TAP ON THE RESULT", RIGHT_PAGE + Vector2(0, 112), Color(INK, 0.8))
	_page_text(font, "BREWS THEM ALL.", RIGHT_PAGE + Vector2(0, 123), Color(INK, 0.8))


## A small 2x2 table holding `count` of `ingredient`, an arrow, and the
## potion it brews with "xN". `at` is the table's top-left.
func _draw_bulk_row(font: Font, ingredient: StringName, count: int, at: Vector2) -> void:
	for i in 4:
		var cell := Rect2(at + Vector2(i % 2, floori(i / 2.0)) * (BULK_BOX + 1.0), Vector2(BULK_BOX, BULK_BOX))
		PotionData.draw_box(_book, cell)
		if i < count:
			PotionData.draw_ingredient(_book, ingredient, cell.get_center())
	var mid_y := at.y + BULK_BOX + 0.5
	var table_end := at.x + 2.0 * BULK_BOX + 1.0
	_draw_arrow(_book, table_end + 6.0, table_end + 26.0, mid_y)
	var result := Rect2(table_end + 32.0, mid_y - 9.0, 18.0, 18.0)
	PotionData.draw_box(_book, result)
	var potion := _potion_from(ingredient)
	PotionData.draw_potion(_book, potion, result.get_center())
	_book.draw_string(font, Vector2(result.end.x + 4.0, mid_y + 4.0), "x%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)


## The potion whose recipe is just this one ingredient.
func _potion_from(ingredient: StringName) -> StringName:
	for potion in PotionData.KINDS:
		var recipe: Dictionary = inventory.recipes.get(potion, {})
		if recipe.size() == 1 and recipe.has(ingredient):
			return potion
	return &""


# --- WANTED poster

## On the checklist spread's right page: the Demon King, dead or alive.
func _draw_wanted(font: Font) -> void:
	var poster := Rect2(RIGHT_PAGE + Vector2(24, 8), Vector2(126, 160))
	# A slight tilt would blur the pixel font, so it hangs straight from a pin.
	_book.draw_rect(poster.grow(1), POSTER_COLOR.darkened(0.35))
	_book.draw_rect(poster, POSTER_COLOR)
	for corner in [poster.position, Vector2(poster.end.x - 6, poster.position.y), Vector2(poster.position.x, poster.end.y - 6), poster.end - Vector2(6, 6)]:
		_book.draw_rect(Rect2(corner, Vector2(6, 6)), POSTER_COLOR.darkened(0.12))
	_book.draw_circle(Vector2(poster.get_center().x, poster.position.y + 4), 2.0, Color(0.55, 0.15, 0.12))
	var center_x := poster.position.x
	var width := poster.size.x
	_book.draw_string(font, Vector2(center_x, poster.position.y + 26), "WANTED", HORIZONTAL_ALIGNMENT_CENTER, width, 16, POSTER_INK)
	_book.draw_string(font, Vector2(center_x, poster.position.y + 40), "DEAD OR ALIVE", HORIZONTAL_ALIGNMENT_CENTER, width, 8, INK)
	var frame := Rect2(poster.get_center().x - 30, poster.position.y + 45, 60, 66)
	_book.draw_rect(frame, POSTER_COLOR.darkened(0.25))
	# The portrait, as tall as the frame allows, keeping its shape.
	var tall := frame.size.y - 2.0
	var wide := tall * DEMON_KING.get_width() / DEMON_KING.get_height()
	_book.draw_texture_rect(DEMON_KING, Rect2(frame.get_center().x - wide / 2.0, frame.position.y + 1.0, wide, tall), false)
	_book.draw_rect(frame.grow(-0.5), INK, false, 1.0)
	_book.draw_string(font, Vector2(center_x, poster.position.y + 123), "DEMON KING", HORIZONTAL_ALIGNMENT_CENTER, width, 8, INK)
	_book.draw_string(font, Vector2(center_x, poster.position.y + 138), "REWARD", HORIZONTAL_ALIGNMENT_CENTER, width, 8, Color(INK, 0.75))
	# Drawn twice, a pixel apart, to look bold.
	for dx in [0.0, 1.0]:
		_book.draw_string(font, Vector2(center_x + dx, poster.position.y + 152), "10,000,000 GOLD", HORIZONTAL_ALIGNMENT_CENTER, width, 8, POSTER_INK)


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
		PotionData.draw_box(_book, Rect2(x, y - 8, 16, 16), faded)
		var icon_at := Vector2(x + 8, y)
		# None held: the icon greyed out.
		PotionData.draw_potion(_book, kind, icon_at, Color.WHITE if amount > 0 else Color(0.45, 0.42, 0.4, 0.6))
		# Crowded (five or six potions held): just the number, so it never runs
		# under the next icon.
		var label := "x%d" % amount
		if 17.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > step - 1.0:
			label = str(amount)
		_book.draw_string(font, Vector2(x + 17, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, faded))
		x += step


# --- Recipe list

## Every recipe row in order: {ingredients, potion, known, locked}. Recipes
## still to be found are left out, the ??? one included: once it's been found
## (one of every ingredient), it comes last, a recipe like the rest.
func _recipe_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for potion in PotionData.KINDS:
		if potion == PotionData.SECRET or not _recipe_found(potion):
			continue
		var ingredients := _death_preview if potion == PotionData.DEATH else _recipe_ingredients(potion)
		entries.append({"ingredients": ingredients, "potion": potion, "known": SaveGame.is_potion_known(potion), "locked": false})
	if _recipe_found(PotionData.SECRET):
		entries.append({"ingredients": PotionData.INGREDIENTS, "potion": PotionData.SECRET, "known": SaveGame.is_potion_known(PotionData.SECRET), "locked": false})
	return entries


## Where a row's parts sit, relative to the row's top-left: one box per
## ingredient, the arrow's ends, and the potion box plus its name.
func _recipe_layout(entry: Dictionary) -> Dictionary:
	var box_y := (RECIPE_ROW_HEIGHT - 1.0 - RECIPE_BOX) / 2.0
	var boxes: Array[Rect2] = []
	var x := 3.0
	for ingredient in entry.ingredients:
		boxes.append(Rect2(x, box_y, RECIPE_BOX, RECIPE_BOX))
		x += RECIPE_BOX + RECIPE_BOX_GAP
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
			PotionData.draw_box(_recipe_list, Rect2(top + box.position, box.size))
			if entry.ingredients[i] != &"":
				PotionData.draw_ingredient(_recipe_list, entry.ingredients[i], top + box.get_center())
		_draw_arrow(_recipe_list, layout.arrow.x, layout.arrow.y, mid_y)
		var potion_box: Rect2 = layout.potion_box
		PotionData.draw_box(_recipe_list, Rect2(top + potion_box.position, potion_box.size))
		var icon_at := top + potion_box.get_center()
		if entry.known:
			PotionData.draw_potion(_recipe_list, entry.potion, icon_at)
		elif entry.locked:
			PotionData.draw_lock_icon(_recipe_list, icon_at, IngredientSlot.BORDER.lightened(0.4))
		else:
			PotionData.draw_unknown_icon(_recipe_list, icon_at, IngredientSlot.BORDER.lightened(0.4))
		var title_at := Vector2(potion_box.end.x + 4.0, mid_y + 4.0)
		_recipe_list.draw_string(font, title_at, _recipe_title(entry), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK if entry.known else Color(INK, 0.6))


## The recipe part at a viewport position (from an input event), as
## {row, part}, or empty.
func _recipe_part_at(viewport_position: Vector2) -> Dictionary:
	if not _on_brewing_page():
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


## Like _recipe_part_at, but only an ingredient box (potions have no tip).
func _ingredient_at(viewport_position: Vector2) -> Dictionary:
	var part := _recipe_part_at(viewport_position)
	return part if part.get("part", -1) >= 0 else {}


func _set_tip(part: Dictionary) -> void:
	if part != _tip:
		_tip = part
		_tip_layer.queue_redraw()


## Ingredient name for the current tip ("" for none). The Death row cycles, so
## this is worked out fresh each time.
func _tip_text() -> String:
	if _tip.is_empty():
		return ""
	var entry: Dictionary = _recipe_entries()[_tip.row]
	return PotionData.INGREDIENT_NAMES.get(entry.ingredients[_tip.part], "")


## A small dark label just above what the tip points at (below it if that
## would cover the page title), kept inside the book.
func _draw_tip() -> void:
	var text := _tip_text()
	if text == "":
		return
	var font := get_theme_font("font", "Label")
	var entry: Dictionary = _recipe_entries()[_tip.row]
	var layout := _recipe_layout(entry)
	var target: Rect2 = layout.boxes[_tip.part]
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
