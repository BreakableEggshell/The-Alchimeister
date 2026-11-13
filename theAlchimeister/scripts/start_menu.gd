extends Control
## Start menu. START wipes progress (straight away, no question) and
## starts a new run from the first level (with a secret timer, see SaveGame),
## START blinks, the buttons slide off to the left and a black screen sweeps
## in from the right after them, then the first level opens with its iris (LEAVE_* timings).
## CONTINUE slides the buttons off the same way, then the level select slides
## in from the right (see LevelSelect). Coming back from the level select runs
## it all backwards (_arrive).
## SETTINGS opens the
## settings page, EXIT quits. Typing the DebugCode (wwssadad) on the menu opens
## the hidden DEBUG tools: ALL LEVELS (level select with everything unlocked),
## reset progress (after asking), unlock everything, every finished speedrun,
## a gallery of every level (LEVEL PREVIEW),
## a dialogue test and a sandbox.

const DIALOGUE_BOX := preload("res://scenes/ui/dialogue_box.tscn")
const PUZZLE_LEVEL := preload("res://scripts/puzzle/puzzle_level.gd")
const CHEST := preload("res://scripts/puzzle/chest.gd")
const NAME_PROMPT := preload("res://scripts/puzzle/name_prompt.gd")
const BACKGROUND := preload("res://assets/startmenu_bg.png")
const BUTTON_ART := preload("res://assets/btn.png")
## The menu's buttons are btn.png scaled up whole by this much (not stretched
## to some other shape), so its pixels stay square.
const MENU_BUTTON_SCALE := 2.0
## How each button state tints the art.
const MENU_BUTTON_TINTS := {
	"normal": Color(1, 1, 1),
	"hover": Color(1.15, 1.15, 1.15),
	"pressed": Color(0.8, 0.8, 0.8),
	"disabled": Color(0.55, 0.55, 0.6),
}
## Leaving the menu: how long START blinks (and how many times), how long each
## button takes to slide off, the gap before the next one goes, and how long
## the black screen takes to sweep in.
const LEAVE_BLINK_TIME := 0.5
const LEAVE_BLINKS := 3
const LEAVE_SLIDE_TIME := 0.3
const LEAVE_STAGGER := 0.06
const LEAVE_WIPE_TIME := 0.35
const SETTINGS_SIZE := Vector2(360, 186)
const DEBUG_SIZE := Vector2(190, 190)
const TIMES_SIZE := Vector2(280, 170)
## Room at the end of each times row for a run's delete button.
const DELETE_WIDTH := 10
const GOLD := Color(0.95, 0.85, 0.55)
## Every portrait there is to look at.
const TEST_LINES: Array[String] = [
	"SHELDON: This is my normal face.",
	"SHELDON (glasses): These are my explaining glasses.",
	"SHELDON (squint): And this is me thinking. Hmm.",
	"ALCHEMIST: This is the knight.",
	"ALCHEMIST (red_eye): This is the knight seeing red.",
	"ALCHEMIST (red_eye_rage): And this is the knight very angry.",
	"DEMON KING: AND I AM THE DEMON KING.",
	"DEMON KING (aura): FEEL MY AURA.",
	"SHELDON: He's in my spot.",
]

@onready var _start: Button = %StartButton
@onready var _continue: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit: Button = %ExitButton

var _settings: SettingsPanel
var _settings_modal: Control
var _debug: Control
var _debug_first: Button
var _debug_note: Label
var _reset_button: Button
var _dialogue_button: Button
var _times: Control
## LEVEL PREVIEW's gallery, made the first time it's opened.
var _preview: LevelPreview
var _preview_button: Button
var _times_list: VBoxContainer
var _times_button: Button
var _times_back: Button
var _times_scroll: ScrollContainer
var _per_level_button: Button
## Times screen: each run's per-level times listed under it.
var _per_level := false
var _dialogue: Control
var _confirm: Control
var _delete_confirm: Control
var _delete_question: Label
var _delete_no: Button
## The run the delete popup is asking about.
var _deleting: Dictionary
var _rename: Control
var _rename_field: LineEdit
var _rename_save: Button
## The run the rename popup is renaming.
var _renaming: Dictionary
var _confirm_no: Button
var _code := DebugCode.new()
## Leaving for a level or the level select: the menu no longer reacts.
var _leaving := false


func _ready() -> void:
	add_to_group(UiFocus.SCREENS)
	# The start menu picture and its drifting clouds, behind everything. Each
	# cloud comes back round at a new height.
	var background := MapBackground.new()
	background.picture = BACKGROUND
	background.new_heights = true
	# Dimmed a little, so the title and buttons stand out.
	background.modulate = Color(0.78, 0.78, 0.78)
	add_child(background)
	move_child(background, 0)
	# The pause menu's debug tools last until the player is back here.
	SaveGame.debug_unlocked = false
	SaveGame.debug_skip_level = false
	_start.pressed.connect(_start_new_run)
	_continue.pressed.connect(_continue_game)
	_settings_button.pressed.connect(_open_settings)
	_exit.pressed.connect(get_tree().quit)
	for button in [_start, _continue, _settings_button, _exit]:
		button.mouse_entered.connect(button.grab_focus)
		# btn.png scaled up whole, centred under the title.
		button.custom_minimum_size = BUTTON_ART.get_size() * MENU_BUTTON_SCALE
		for state in MENU_BUTTON_TINTS:
			var art := StyleBoxTexture.new()
			art.texture = BUTTON_ART
			art.modulate_color = MENU_BUTTON_TINTS[state]
			button.add_theme_stylebox_override(state, art)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_modal = _build_settings()
	_debug = _build_debug()
	_times = _build_times()
	_confirm = _build_confirm()
	_delete_confirm = _build_delete_confirm()
	_rename = _build_rename()
	_refresh()
	_start.grab_focus()
	if SaveGame.slide_in_start_menu:
		SaveGame.slide_in_start_menu = false
		_arrive()
	# Arriving from a level: its iris closed, so open it.
	if Iris.is_closed:
		Iris.cover()
		await get_tree().process_frame
		if is_inside_tree():
			Iris.open()


func _input(event: InputEvent) -> void:
	_watch_for_code(event)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _rename.visible:
		_close_rename()
	elif _delete_confirm.visible:
		_close_delete_confirm()
	elif _confirm.visible:
		_close_confirm()
	elif _settings_modal.visible:
		_settings.back_out()
	elif _preview and _preview.visible:
		_close_preview()
	elif _times.visible:
		_close_times()
	elif _debug.visible:
		_close_debug()
	else:
		return
	get_viewport().set_input_as_handled()


## See UiFocus.
func focus_first() -> bool:
	if _dialogue and _dialogue.is_playing:
		return false
	if _rename.visible:
		_rename_field.grab_focus()
	elif _delete_confirm.visible:
		_delete_no.grab_focus()
	elif _confirm.visible:
		_confirm_no.grab_focus()
	elif _settings_modal.visible:
		_settings.focus_first()
	elif _preview and _preview.visible:
		_preview.focus_first()
	elif _times.visible:
		_times_back.grab_focus()
	elif _debug.visible:
		_debug_first.grab_focus()
	else:
		_start.grab_focus()
	return true


## START: blink, slide away, then the first level opens from black.
func _start_new_run() -> void:
	if _leaving:
		return
	await _leave(true)
	SaveGame.start_new_run()
	# Forget this session's retries too, so first-attempt lines play again.
	PUZZLE_LEVEL._restarts.clear()
	PUZZLE_LEVEL._hint_part.clear()
	PUZZLE_LEVEL._hints_heard.clear()
	PUZZLE_LEVEL._hint_taken_at.clear()
	CHEST.forget_heard()
	# Straight in under the black: the level opens with its own iris.
	get_tree().change_scene_to_file(SaveGame.STAGE_SCENES[SaveGame.FIRST_STAGE])


## CONTINUE: slide away, then the level select.
func _continue_game() -> void:
	if _leaving:
		return
	await _leave(false)
	SaveGame.slide_in_level_select = true
	SaveGame.go_to(SaveGame.LEVEL_SELECT)


## Back from the level select, under its black screen: the black slides off to
## the right and the buttons slide back in from the left, one after another.
func _arrive() -> void:
	_leaving = true
	var buttons: Array[Button] = [_start, _continue, _settings_button, _exit]
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport_rect().size
	add_child(black)
	# Once the buttons are laid out, start them off the left edge.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var slide := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(black, "position:x", black.size.x, LEAVE_WIPE_TIME).set_trans(Tween.TRANS_QUAD)
	for i in buttons.size():
		var home := buttons[i].position.x
		buttons[i].position.x = home - (buttons[i].global_position.x + buttons[i].size.x) - 8.0
		slide.tween_property(buttons[i], "position:x", home, LEAVE_SLIDE_TIME).set_delay(LEAVE_WIPE_TIME * 0.4 + i * LEAVE_STAGGER)
	await slide.finished
	black.queue_free()
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	_leaving = false
	_start.grab_focus()


## The menu's way out: START blinks first (`blink`), the buttons slide off to
## the left one after another, and a black screen sweeps in from the right
## behind them.
func _leave(blink: bool) -> void:
	_leaving = true
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	var buttons: Array[Button] = [_start, _continue, _settings_button, _exit]
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blink:
		var flash := create_tween()
		for i in LEAVE_BLINKS:
			flash.tween_property(_start, "modulate:a", 0.15, LEAVE_BLINK_TIME / LEAVE_BLINKS / 2.0)
			flash.tween_property(_start, "modulate:a", 1.0, LEAVE_BLINK_TIME / LEAVE_BLINKS / 2.0)
		await flash.finished
	var slide := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for i in buttons.size():
		var off := -(buttons[i].global_position.x + buttons[i].size.x) - 8.0
		slide.tween_property(buttons[i], "position:x", buttons[i].position.x + off, LEAVE_SLIDE_TIME).set_delay(i * LEAVE_STAGGER)
	# The black follows the buttons, sweeping in from the right.
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = get_viewport_rect().size
	black.position.x = black.size.x
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	slide.tween_property(black, "position:x", 0.0, LEAVE_WIPE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(LEAVE_SLIDE_TIME * 0.6 + (buttons.size() - 1) * LEAVE_STAGGER)
	await slide.finished


func _refresh() -> void:
	_continue.disabled = not SaveGame.can_continue()


func _open_settings() -> void:
	_settings_modal.show()
	_settings.open()


func _close_settings() -> void:
	_settings_modal.hide()
	_settings.hide()
	_settings_button.grab_focus()


## Opens the debug tools once the DebugCode has been typed on the main menu.
func _watch_for_code(event: InputEvent) -> void:
	if _code.feed(event) and _on_main_menu() and not _leaving:
		_open_debug()
		get_viewport().set_input_as_handled()


## Nothing open on top of the menu buttons.
func _on_main_menu() -> bool:
	for modal in [_settings_modal, _debug, _times, _confirm, _delete_confirm, _rename, _preview]:
		if modal and modal.visible:
			return false
	return not (_dialogue and _dialogue.is_playing)


func _open_debug() -> void:
	_debug_note.text = ""
	_debug.show()
	_debug_first.grab_focus()


func _close_debug() -> void:
	_debug.hide()
	_start.grab_focus()


## Every finished full run, fastest first.
func _open_times() -> void:
	_fill_times()
	# The debug list would show through behind it.
	_debug.hide()
	_times.show()
	_times_back.grab_focus()


## The list itself: every run, and with PER LEVEL on, its level times under it.
func _fill_times() -> void:
	for row in _times_list.get_children():
		row.free()
	_per_level_button.text = "PER LEVEL: %s" % ("ON" if _per_level else "OFF")
	var runs := SaveGame.playtesters.duplicate()
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return SaveGame.playable_seconds(a) < SaveGame.playable_seconds(b))
	if runs.is_empty():
		_times_row("", "NO FINISHED RUNS YET", "")
	var names: Array[Button] = []
	var deletes: Array[Button] = []
	for i in runs.size():
		var row := _times_row("%d." % (i + 1), runs[i].name, _run_time(SaveGame.playable_seconds(runs[i])), false, runs[i].get("date", "-"), runs[i])
		names.append(row.get_child(1))
		deletes.append(_delete_button(row, runs[i]))
		if not _per_level:
			continue
		var times := SaveGame.stage_times(runs[i])
		if times.is_empty():
			_times_row("", "  (NO LEVEL TIMES)", "", true)
		for entry in times:
			_times_row("", "  LEVEL %d (%s)" % [SaveGame.stage_number(entry[0]), SaveGame.stage_code(entry[0])], _run_time(entry[1]), true)
	_times_scroll.scroll_vertical = 0
	# Up and down step through the runs' names (left) or X buttons (right),
	# then on to the buttons below; left and right go between the two.
	for column in [[names, _per_level_button], [deletes, _times_back]]:
		var buttons: Array[Button] = column[0]
		var below_all: Button = column[1]
		for i in buttons.size():
			var above: Button = buttons[i - 1] if i > 0 else buttons[i]
			var below: Button = buttons[i + 1] if i + 1 < buttons.size() else below_all
			buttons[i].focus_neighbor_top = buttons[i].get_path_to(above)
			buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(below)
		below_all.focus_neighbor_top = below_all.get_path_to(buttons.back()) if buttons else NodePath()
		below_all.focus_neighbor_bottom = below_all.get_path_to(below_all)
	for i in names.size():
		names[i].focus_neighbor_left = names[i].get_path_to(names[i])
		names[i].focus_neighbor_right = names[i].get_path_to(deletes[i])
		deletes[i].focus_neighbor_left = deletes[i].get_path_to(names[i])
		deletes[i].focus_neighbor_right = deletes[i].get_path_to(deletes[i])


## The rename popup for `run`, with its name ready to type over.
func _ask_rename(run: Dictionary) -> void:
	_renaming = run
	_rename_field.text = run.name
	_rename.show()
	_rename_field.grab_focus()
	_rename_field.select_all()
	_rename_field.edit()
	_update_rename_save()


func _close_rename() -> void:
	_rename_field.unedit()
	_rename.hide()
	_times_back.grab_focus()


## SAVE (or Enter): the run takes the typed name, if there is one.
func _save_rename(_text := "") -> void:
	var player_name := _rename_field.text.strip_edges()
	if player_name == "":
		return
	SaveGame.rename_playtester(_renaming, player_name)
	_renaming = {}
	_fill_times()
	_close_rename()


func _update_rename_save(_text := "") -> void:
	_rename_save.disabled = _rename_field.text.strip_edges() == ""


## A small X at the end of a run's row that asks before deleting the run.
func _delete_button(row: HBoxContainer, run: Dictionary) -> Button:
	row.get_child(-1).queue_free()
	var button := Button.new()
	button.text = "X"
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(DELETE_WIDTH, 0)
	button.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
	button.add_theme_color_override("font_hover_color", Color(1, 0.55, 0.5))
	button.add_theme_color_override("font_focus_color", Color(1, 0.55, 0.5))
	var flat := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, flat)
	button.tooltip_text = "Delete this run"
	button.pressed.connect(_ask_delete.bind(run))
	button.mouse_entered.connect(button.grab_focus)
	row.add_child(button)
	return button


func _ask_delete(run: Dictionary) -> void:
	_deleting = run
	_delete_question.text = "DELETE %s'S RUN
(%s)?" % [run.name, _run_time(SaveGame.playable_seconds(run))]
	_delete_confirm.show()
	_delete_no.grab_focus()


func _close_delete_confirm() -> void:
	_delete_confirm.hide()
	_times_back.grab_focus()


func _delete_run() -> void:
	SaveGame.delete_playtester(_deleting)
	_deleting = {}
	_fill_times()
	_close_delete_confirm()


func _toggle_per_level() -> void:
	_per_level = not _per_level
	_fill_times()


## Every level pictured whole, over the debug menu.
func _open_preview() -> void:
	_debug.hide()
	if not _preview:
		_preview = LevelPreview.new()
		_preview.closed.connect(_close_preview)
		add_child(_preview)
	else:
		_preview.show()
		_preview.focus_first()


func _close_preview() -> void:
	_preview.hide()
	_debug.show()
	_preview_button.grab_focus()


func _close_times() -> void:
	_times.hide()
	_debug.show()
	_times_button.grab_focus()


## Minutes and seconds, to the hundredth.
func _run_time(seconds: float) -> String:
	return "%s.%02d" % [SaveGame.format_time(seconds), int(fmod(seconds, 1.0) * 100.0)]


## One row of the list. Ends in an empty gap where a run's X button goes, so
## the times line up. A run's row (`run`) has its name as a button that renames
## it.
func _times_row(rank: String, player_name: String, time: String, faint := false, date := "", run := {}) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if faint:
		row.modulate = Color(1, 1, 1, 0.6)
	_times_list.add_child(row)
	var place := Label.new()
	place.text = rank
	place.custom_minimum_size.x = 22
	place.add_theme_color_override("font_color", GOLD)
	row.add_child(place)
	if run.is_empty():
		var who := Label.new()
		who.text = player_name
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.clip_text = true
		row.add_child(who)
	else:
		row.add_child(_name_button(player_name, run))
	if date != "":
		# When the run was finished, faint so the times stand out.
		var day := Label.new()
		day.text = date
		# Same width on every row, so the dates line up.
		day.custom_minimum_size.x = 72
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		row.add_child(day)
	var clock := Label.new()
	clock.text = time
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(clock)
	var gap := Control.new()
	gap.custom_minimum_size.x = DELETE_WIDTH
	row.add_child(gap)
	return row


## A run's name, written like the rest of the row but clickable: it opens the
## rename popup. Underlined while picked, so it reads as editable.
func _name_button(player_name: String, run: Dictionary) -> Button:
	var button := Button.new()
	button.text = player_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "Rename this run"
	button.add_theme_constant_override("outline_size", 0)
	for color in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, Color.WHITE)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var plain := StyleBoxEmpty.new()
		button.add_theme_stylebox_override(state, plain)
	button.draw.connect(func() -> void:
		if button.has_focus() or button.is_hovered():
			var width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			button.draw_line(Vector2(0, button.size.y - 1), Vector2(minf(width, button.size.x), button.size.y - 1), GOLD))
	for signal_name in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
		button.connect(signal_name, button.queue_redraw)
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(_ask_rename.bind(run))
	return button


func _close_confirm() -> void:
	_confirm.hide()
	_reset_button.grab_focus()


func _unlock_all() -> void:
	SaveGame.unlock_all()
	_refresh()
	_debug_note.text = "ALL PROGRESS UNLOCKED"


## Every portrait in a row, in a real dialogue box.
func play_dialogue_test() -> void:
	if not _dialogue:
		_dialogue = DIALOGUE_BOX.instantiate()
		add_child(_dialogue)
	_dialogue.move_to_front()
	_dialogue.play(PackedStringArray(TEST_LINES))


# --- Layout

func _modal() -> Control:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.hide()
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	return modal


func _build_settings() -> Control:
	var modal := _modal()
	_settings = SettingsPanel.new()
	modal.add_child(_settings)
	_settings.build(SETTINGS_SIZE)
	_settings.position = ((get_viewport_rect().size - SETTINGS_SIZE) / 2.0).round()
	_settings.back_requested.connect(_close_settings)
	return modal


func _build_debug() -> Control:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -DEBUG_SIZE.x / 2.0
	panel.offset_right = DEBUG_SIZE.x / 2.0
	panel.offset_top = -DEBUG_SIZE.y / 2.0
	panel.offset_bottom = DEBUG_SIZE.y / 2.0
	modal.add_child(panel)
	var title := Label.new()
	title.text = "DEBUG"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(DEBUG_SIZE.x, 10)
	panel.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.position = Vector2(12, 18)
	list.size = Vector2(DEBUG_SIZE.x - 24, 0)
	panel.add_child(list)
	_reset_button = _list_button("RESET PROGRESS", list)
	_reset_button.pressed.connect(func() -> void:
		_debug_note.text = ""
		_confirm.show()
		_confirm_no.grab_focus())
	var all_levels := _list_button("ALL LEVELS", list)
	all_levels.pressed.connect(func() -> void:
		SaveGame.unlock_all_levels()
		SaveGame.go_to(SaveGame.LEVEL_SELECT))
	list.move_child(all_levels, 0)
	_debug_first = all_levels
	_list_button("UNLOCK ALL PROGRESS", list).pressed.connect(_unlock_all)
	_times_button = _list_button("SPEEDRUN TIMES", list)
	_times_button.pressed.connect(_open_times)
	_preview_button = _list_button("LEVEL PREVIEW", list)
	_preview_button.pressed.connect(_open_preview)
	_dialogue_button = _list_button("DIALOGUE TEST", list)
	_dialogue_button.pressed.connect(play_dialogue_test)
	_list_button("SANDBOX", list).pressed.connect(SaveGame.play_sandbox)
	_list_button("BACK", list).pressed.connect(_close_debug)
	_debug_note = Label.new()
	_debug_note.add_theme_color_override("font_color", GOLD)
	_debug_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_note.position = Vector2(0, 162)
	_debug_note.size = Vector2(DEBUG_SIZE.x, 10)
	panel.add_child(_debug_note)
	UiFocus.link_column(list.get_children())
	return modal


func _build_times() -> Control:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -TIMES_SIZE.x / 2.0
	panel.offset_right = TIMES_SIZE.x / 2.0
	panel.offset_top = -TIMES_SIZE.y / 2.0
	panel.offset_bottom = TIMES_SIZE.y / 2.0
	modal.add_child(panel)
	var title := Label.new()
	title.text = "SPEEDRUN TIMES"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(TIMES_SIZE.x, 10)
	panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keeps the X button being picked with the keys in view.
	scroll.follow_focus = true
	scroll.position = Vector2(12, 22)
	scroll.size = Vector2(TIMES_SIZE.x - 24, TIMES_SIZE.y - 50)
	panel.add_child(scroll)
	_times_scroll = scroll
	_times_list = VBoxContainer.new()
	_times_list.add_theme_constant_override("separation", 1)
	_times_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_times_list)
	_per_level_button = Button.new()
	_per_level_button.focus_mode = Control.FOCUS_ALL
	_per_level_button.pressed.connect(_toggle_per_level)
	panel.add_child(_per_level_button)
	_per_level_button.position = Vector2(roundf((TIMES_SIZE.x - 176) / 2.0), TIMES_SIZE.y - 22)
	_per_level_button.size = Vector2(104, 16)
	_times_back = Button.new()
	_times_back.text = "BACK"
	_times_back.focus_mode = Control.FOCUS_ALL
	_times_back.pressed.connect(_close_times)
	panel.add_child(_times_back)
	_times_back.position = Vector2(roundf((TIMES_SIZE.x - 176) / 2.0) + 120, TIMES_SIZE.y - 22)
	_times_back.size = Vector2(56, 16)
	UiFocus.link_row([_per_level_button, _times_back])
	for button in [_per_level_button, _times_back]:
		button.mouse_entered.connect(button.grab_focus)
	return modal


func _list_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _build_confirm() -> Control:
	var buttons := _yes_no("RESET ALL PROGRESS
AND SETTINGS?", func() -> void:
		SaveGame.reset_all()
		_confirm.hide()
		_refresh()
		_debug_note.text = "PROGRESS RESET"
		_reset_button.grab_focus(), _close_confirm)
	_confirm_no = buttons.no
	return buttons.modal


## RENAME: a box with the run's name to type over, SAVE and CANCEL.
func _build_rename() -> Control:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -90
	panel.offset_right = 90
	panel.offset_top = -36
	panel.offset_bottom = 36
	modal.add_child(panel)
	var title := Label.new()
	title.text = "RENAME"
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(180, 10)
	panel.add_child(title)
	_rename_field = LineEdit.new()
	_rename_field.max_length = NAME_PROMPT.MAX_NAME_LENGTH
	_rename_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_field.add_theme_color_override("caret_color", GOLD)
	_rename_field.text_submitted.connect(_save_rename)
	_rename_field.text_changed.connect(_update_rename_save)
	panel.add_child(_rename_field)
	_rename_field.position = Vector2(20, 20)
	_rename_field.size = Vector2(140, 16)
	_rename_save = Button.new()
	_rename_save.text = "SAVE"
	_rename_save.pressed.connect(_save_rename)
	panel.add_child(_rename_save)
	_rename_save.position = Vector2(26, 46)
	_rename_save.size = Vector2(60, 16)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_rename)
	panel.add_child(cancel)
	cancel.position = Vector2(94, 46)
	cancel.size = Vector2(60, 16)
	UiFocus.link_row([_rename_save, cancel])
	_rename_field.focus_neighbor_bottom = _rename_field.get_path_to(_rename_save)
	return modal


func _build_delete_confirm() -> Control:
	var buttons := _yes_no("", _delete_run, _close_delete_confirm)
	_delete_no = buttons.no
	_delete_question = buttons.question
	return buttons.modal


## A question with YES and NO: {modal, no, question}.
func _yes_no(text: String, on_yes: Callable, on_no: Callable) -> Dictionary:
	var modal := _modal()
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -100
	panel.offset_right = 100
	panel.offset_top = -32
	panel.offset_bottom = 32
	modal.add_child(panel)
	var question := Label.new()
	question.text = text
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.position = Vector2(0, 8)
	question.size = Vector2(200, 20)
	panel.add_child(question)
	var yes := Button.new()
	yes.text = "YES"
	yes.pressed.connect(on_yes)
	panel.add_child(yes)
	# After add_child: a size set before then doesn't stick.
	yes.position = Vector2(36, 38)
	yes.size = Vector2(56, 16)
	var no := Button.new()
	no.text = "NO"
	no.pressed.connect(on_no)
	panel.add_child(no)
	no.position = Vector2(108, 38)
	no.size = Vector2(56, 16)
	UiFocus.link_row([yes, no])
	return {"modal": modal, "no": no, "question": question}
