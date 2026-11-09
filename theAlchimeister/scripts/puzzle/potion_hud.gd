extends Control
## Stage HUD: one slot per potion kind (click it or press 1-5 to select;
## the Death potion's slot only appears while you hold one), with its key
## number underneath (and "B" under the book button),
## short-lived messages, the recipe book button, the dialogue box, the
## out-of-potions restart hint (tap it to restart), and the end-of-stage banner with its buttons
## (the stage dims behind them; WASD moves between them, Enter picks).
## While dialogue plays, the potion slots and book button are hidden.

signal next_pressed
signal levels_pressed
signal restart_pressed

const MAX_MESSAGES := 3
const MESSAGE_TIME := 1.6
const KEY_COLOR := Color(1, 1, 1, 0.75)
## Blinks per second of the slot highlight (see highlight_slots()).
const BLINK_RATE := 2.5
const END_DIM := Color(0, 0, 0, 0.55)

@export var inventory: Inventory
@export var thrower: Node2D
@export var book: Control
@export var dialogue: Control

var _slots := {}
var _aiming := false
var _stage_over := false
var _highlight: Control
var _potions_enabled := true
var _restart_hint: Button
var _end_dim: ColorRect

@onready var _slot_row: HBoxContainer = $Slots
@onready var _messages: VBoxContainer = $Messages
@onready var _banner: Label = $Banner
@onready var _banner_sub: Label = $BannerSub
@onready var _book_button: Button = $BookButton
@onready var _end_buttons: HBoxContainer = $EndButtons
@onready var _next_button: Button = $EndButtons/NextButton
@onready var _levels_button: Button = $EndButtons/LevelsButton


func _ready() -> void:
	# The book button shares the top-right corner with the throw-cancel box,
	# so it steps aside while a throw is being aimed.
	add_to_group(UiFocus.SCREENS)
	_book_button.pressed.connect(book.toggle)
	_book_button.draw.connect(func() -> void:
		PotionData.draw_book_icon(_book_button, _book_button.size / 2.0)
		_draw_key(_book_button, Controls.key_name(&"toggle_book")))
	SaveGame.controls_changed.connect(_on_controls_changed)
	thrower.aiming_changed.connect(func(aiming: bool) -> void:
		_aiming = aiming
		_update_visibility())
	# The open book has its own buttons, so the potion slots and book icon
	# step out of its way.
	book.opened.connect(func() -> void:
		thrower.cancel()
		_messages.hide()
		_update_visibility())
	book.closed.connect(func() -> void:
		_messages.show()
		_update_visibility())
	book.log_requested.connect(dialogue.show_log)
	dialogue.started.connect(func() -> void:
		thrower.cancel()
		_update_visibility())
	dialogue.finished.connect(_update_visibility)
	_next_button.pressed.connect(next_pressed.emit)
	_levels_button.pressed.connect(levels_pressed.emit)
	_end_buttons.hide()
	# Draw order: the open book covers the rest of the HUD, the potion counts
	# and book button stay visible above it, and dialogue goes over everything.
	book.move_to_front()
	_slot_row.move_to_front()
	_book_button.move_to_front()
	_highlight = Control.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.process_mode = Node.PROCESS_MODE_ALWAYS
	_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight.draw.connect(_draw_highlight)
	_highlight.hide()
	add_child(_highlight)
	var blink := Timer.new()
	blink.wait_time = 0.5 / BLINK_RATE
	blink.timeout.connect(_highlight.queue_redraw)
	_highlight.add_child(blink)
	blink.start()
	# A flat button, so touch players can tap it instead of pressing R.
	_restart_hint = Button.new()
	_restart_hint.text = _restart_text()
	_restart_hint.flat = true
	_restart_hint.focus_mode = Control.FOCUS_NONE
	_restart_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_restart_hint.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	_restart_hint.add_theme_color_override("font_hover_color", Color(1, 0.6, 0.6))
	_restart_hint.add_theme_color_override("font_pressed_color", Color(1, 0.75, 0.75))
	_restart_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_restart_hint.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "focus"]:
		_restart_hint.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_restart_hint.pressed.connect(restart_pressed.emit)
	_restart_hint.anchor_left = 0.5
	_restart_hint.anchor_right = 0.5
	_restart_hint.offset_left = -96.0
	_restart_hint.offset_right = 96.0
	_restart_hint.offset_top = 44.0
	_restart_hint.offset_bottom = 56.0
	_restart_hint.hide()
	add_child(_restart_hint)
	_end_dim = ColorRect.new()
	_end_dim.color = END_DIM
	_end_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_dim.hide()
	add_child(_end_dim)
	_end_buttons.move_to_front()
	dialogue.move_to_front()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for kind in PotionData.KINDS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(30, 20)
		slot.toggle_mode = true
		slot.button_group = group
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = "%s POTION" % PotionData.NAMES[kind]
		slot.pressed.connect(func() -> void: inventory.select(kind))
		slot.draw.connect(_draw_slot.bind(slot, kind))
		_slot_row.add_child(slot)
		_slots[kind] = slot
	inventory.changed.connect(_refresh)
	inventory.message.connect(show_message)
	_banner.hide()
	_banner_sub.hide()
	_refresh()
	_update_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if not _potions_enabled:
		return
	if event is InputEventMouseButton and event.pressed and not book.is_open and not dialogue.is_playing:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_potion(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_potion(1)
			get_viewport().set_input_as_handled()
		return
	for i in PotionData.KINDS.size():
		var kind := PotionData.KINDS[i]
		if inventory.is_shown(kind) and event.is_action_pressed("potion_%d" % (i + 1)):
			inventory.select(kind)
			get_viewport().set_input_as_handled()


## Picks the next potion along the bar (`step` 1) or the one before (-1),
## wrapping round. With none picked, starts from the matching end of the bar.
func _cycle_potion(step: int) -> void:
	var kinds := PotionData.KINDS.filter(inventory.is_shown)
	if kinds.is_empty():
		return
	var at := kinds.find(inventory.selected)
	if at < 0:
		at = -1 if step > 0 else 0
	inventory.select(kinds[posmod(at + step, kinds.size())])


## Shows or hides the potion bar (and turns its number keys on or off).
func set_potions_enabled(on: bool) -> void:
	_potions_enabled = on
	_update_visibility()


## Shows or hides the red "PRESS R TO RESTART THE LEVEL" line.
func show_restart_hint(on: bool) -> void:
	_restart_hint.visible = on and not _stage_over


## Makes the potion slot borders blink bright white (or stops it).
func highlight_slots(on: bool) -> void:
	_highlight.visible = on
	_highlight.queue_redraw()


func show_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	_messages.add_child(label)
	while _messages.get_child_count() > MAX_MESSAGES:
		_messages.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(MESSAGE_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


## Closes the book and removes its button, once the stage is over.
func disable_book() -> void:
	_stage_over = true
	_restart_hint.hide()
	book.close()
	_update_visibility()


func show_banner(title: String, subtitle: String, color: Color) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner.show()
	_banner_sub.visible = subtitle != ""


## Shows the end-of-stage buttons. The next button (labelled `next_label`)
## only when there is somewhere to go.
func show_end_buttons(has_next: bool, next_label := "NEXT STAGE") -> void:
	_next_button.text = next_label
	_next_button.visible = has_next
	# The stage dims behind the banner and buttons, and the potion bar goes.
	set_potions_enabled(false)
	_end_dim.modulate.a = 0.0
	_end_dim.show()
	for node in [_end_dim, _banner, _banner_sub, _end_buttons, dialogue]:
		node.move_to_front()
	create_tween().tween_property(_end_dim, "modulate:a", 1.0, 0.3)
	# Clear of the line under the banner, when there is one.
	if _banner_sub.visible:
		_end_buttons.position.y = _banner_sub.get_rect().end.y + 2.0
	_end_buttons.show()
	(_next_button if has_next else _levels_button).grab_focus()


## See UiFocus.
func focus_first() -> bool:
	if not _end_buttons.visible:
		return false
	(_next_button if _next_button.visible else _levels_button).grab_focus()
	return true


func _update_visibility() -> void:
	var talking: bool = dialogue.is_playing or dialogue.is_waiting
	_slot_row.visible = _potions_enabled and not talking and not book.is_open
	_highlight.modulate.a = 0.0 if talking else 1.0
	_book_button.visible = not (talking or _aiming or _stage_over or book.is_open)
	book.enabled = not (talking or _stage_over)


func _refresh() -> void:
	for kind in _slots:
		var slot: Button = _slots[kind]
		slot.visible = inventory.is_shown(kind)
		slot.set_pressed_no_signal(kind == inventory.selected)
		slot.modulate.a = 1.0 if inventory.count(kind) > 0 or kind == inventory.selected else 0.45
		slot.queue_redraw()


func _draw_slot(slot: Button, kind: StringName) -> void:
	PotionData.draw_potion(slot, kind, Vector2(9, 11))
	var font := slot.get_theme_font("font")
	var count := inventory.count(kind)
	var color := Color.WHITE if count > 0 else Color(1, 1, 1, 0.5)
	slot.draw_string(font, Vector2(16, 14), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
	_draw_key(slot, Controls.key_name("potion_%d" % (PotionData.KINDS.find(kind) + 1)))


## The keyboard key for a button, centred just below it.
func _restart_text() -> String:
	return "PRESS %s TO RESTART THE LEVEL" % Controls.key_name(&"restart")


func _on_controls_changed() -> void:
	_book_button.queue_redraw()
	for kind in _slots:
		_slots[kind].queue_redraw()
	_restart_hint.text = _restart_text()


func _draw_key(button: Control, key: String) -> void:
	var font := button.get_theme_font("font")
	button.draw_string(font, Vector2(0, button.size.y + 9), key, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 8, KEY_COLOR)


func _draw_highlight() -> void:
	var lit := fmod(Time.get_ticks_msec() / 1000.0 * BLINK_RATE, 1.0) < 0.5
	if not lit:
		return
	for kind in _slots:
		var slot: Button = _slots[kind]
		if not slot.is_visible_in_tree():
			continue
		var rect := Rect2(slot.global_position - global_position, slot.size)
		_highlight.draw_rect(rect.grow(1.0), Color(1, 1, 1, 0.35), false, 3.0)
		_highlight.draw_rect(rect, Color.WHITE, false, 1.0)
