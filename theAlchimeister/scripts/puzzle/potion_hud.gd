extends Control
## Puzzle HUD: one slot per potion kind (click it or press 1-4 to select),
## short-lived messages, and the end-of-stage banner.

const MAX_MESSAGES := 3
const MESSAGE_TIME := 1.6

@export var inventory: Inventory

var _slots := {}

@onready var _slot_row: HBoxContainer = $Slots
@onready var _messages: VBoxContainer = $Messages
@onready var _banner: Label = $Banner
@onready var _banner_sub: Label = $BannerSub


func _ready() -> void:
	var group := ButtonGroup.new()
	for kind in PotionData.KINDS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(30, 20)
		slot.toggle_mode = true
		slot.button_group = group
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = "%s POTION" % PotionData.NAMES[kind]
		slot.pressed.connect(inventory.select.bind(kind))
		slot.draw.connect(_draw_slot.bind(slot, kind))
		_slot_row.add_child(slot)
		_slots[kind] = slot
	inventory.changed.connect(_refresh)
	inventory.message.connect(show_message)
	_banner.hide()
	_banner_sub.hide()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	for i in PotionData.KINDS.size():
		if event.is_action_pressed("potion_%d" % (i + 1)):
			inventory.select(PotionData.KINDS[i])
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


func show_banner(title: String, subtitle: String, color: Color) -> void:
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner.show()
	_banner_sub.show()


func _refresh() -> void:
	for kind in _slots:
		var slot: Button = _slots[kind]
		slot.set_pressed_no_signal(kind == inventory.selected)
		slot.modulate.a = 1.0 if inventory.count(kind) > 0 or kind == inventory.selected else 0.45
		slot.queue_redraw()


func _draw_slot(slot: Button, kind: StringName) -> void:
	PotionData.draw_potion(slot, kind, Vector2(9, 11))
	var font := slot.get_theme_font("font")
	var count := inventory.count(kind)
	var color := Color.WHITE if count > 0 else Color(1, 1, 1, 0.5)
	slot.draw_string(font, Vector2(16, 14), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
