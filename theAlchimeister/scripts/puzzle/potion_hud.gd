extends Control
## Stage HUD: one slot per potion kind (click it or press 1-5 to select;
## the Death potion's slot only appears while you hold one),
## short-lived messages, the recipe book button, the dialogue box, and the
## end-of-stage banner with its buttons.
## While dialogue plays, the potion slots and book button are hidden.

signal next_pressed
signal levels_pressed

const MAX_MESSAGES := 3
const MESSAGE_TIME := 1.6

@export var inventory: Inventory
@export var thrower: Node2D
@export var book: Control
@export var dialogue: Control

var _slots := {}
var _aiming := false
var _stage_over := false

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
	_book_button.pressed.connect(book.toggle)
	_book_button.draw.connect(func() -> void: PotionData.draw_book_icon(_book_button, _book_button.size / 2.0))
	thrower.aiming_changed.connect(func(aiming: bool) -> void:
		_aiming = aiming
		_update_visibility())
	book.opened.connect(func() -> void:
		thrower.cancel()
		_messages.hide())
	book.closed.connect(_messages.show)
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
	for i in PotionData.KINDS.size():
		var kind := PotionData.KINDS[i]
		if inventory.is_shown(kind) and event.is_action_pressed("potion_%d" % (i + 1)):
			inventory.select(kind)
			get_viewport().set_input_as_handled()


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
	book.close()
	_update_visibility()


func show_banner(title: String, subtitle: String, color: Color) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner.show()
	_banner_sub.visible = subtitle != ""


## Shows the end-of-stage buttons. NEXT STAGE only when there is one.
func show_end_buttons(has_next: bool) -> void:
	_next_button.visible = has_next
	_end_buttons.show()
	(_next_button if has_next else _levels_button).grab_focus()


func _update_visibility() -> void:
	var talking: bool = dialogue.is_playing
	_slot_row.visible = not talking
	_book_button.visible = not (talking or _aiming or _stage_over)
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
