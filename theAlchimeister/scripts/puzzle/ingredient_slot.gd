class_name IngredientSlot
extends Control
## One box in the crafting book: an ingredient stack in storage, one ingredient
## on the crafting table, or the brewed result. It only reports taps and drops;
## the book decides what they do. Keyboard: it takes focus (arrow keys move
## between slots) and Enter/Space taps it.

signal tapped(slot: IngredientSlot)
signal dropped(target: IngredientSlot, source: IngredientSlot)

enum Role { STORAGE, TABLE, RESULT }

const FILL := Color(0.25, 0.2, 0.18)
const BORDER := Color(0.5, 0.4, 0.32)
const HOVER_BORDER := Color(0.95, 0.85, 0.55)

var role := Role.STORAGE
## Position among slots of the same role.
var index := 0
## Ingredient kind (storage, table) or potion kind (result); empty when empty.
var kind: StringName = &""
## Stack size for storage slots; potions that will be brewed for the result slot.
var count := 0
## Result slot only: the potion is still a secret, so a lock is drawn instead.
var locked := false

var _hover := false
var _press_inside := false


func _init(slot_role: Role = Role.STORAGE, slot_index := 0, slot_size := Vector2(22, 22)) -> void:
	role = slot_role
	index = slot_index
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func show_contents(new_kind: StringName, new_count := 0, is_locked := false) -> void:
	kind = new_kind
	count = new_count
	locked = is_locked
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		tapped.emit(self)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_inside = true
		elif _press_inside:
			_press_inside = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				tapped.emit(self)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# A drag that started here is not a tap.
		_press_inside = false


func _get_drag_data(_at: Vector2) -> Variant:
	if role == Role.RESULT or kind == &"":
		return null
	var dragged := kind
	var preview := Control.new()
	preview.draw.connect(func() -> void: PotionData.draw_ingredient(preview, dragged, Vector2.ZERO))
	set_drag_preview(preview)
	return {"slot": self, "kind": dragged}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return role != Role.RESULT and data is Dictionary and data.has("slot") and data.slot != self


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(self, data.slot)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, FILL)
	var lit := (_hover and (role != Role.STORAGE or kind != &"")) or has_focus()
	draw_rect(box.grow(-0.5), HOVER_BORDER if lit else BORDER, false)
	if has_focus():
		draw_rect(box.grow(-1.5), Color(HOVER_BORDER, 0.5), false)
	var center := size / 2.0
	if locked:
		PotionData.draw_lock_icon(self, center + Vector2(0, 1), BORDER.lightened(0.4))
	elif kind != &"":
		if role == Role.RESULT:
			PotionData.draw_potion(self, kind, center + Vector2(0, 1))
		else:
			PotionData.draw_ingredient(self, kind, center)
	# Stack size in storage; potions to be brewed on the result.
	if role != Role.TABLE and count > 1:
		var font := get_theme_font("font", "Label")
		draw_string(font, Vector2(0, size.y - 1), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 1, 8, Color.WHITE)
