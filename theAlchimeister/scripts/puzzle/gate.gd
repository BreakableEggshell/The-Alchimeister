@tool
class_name Gate
extends StaticBody2D
## A portcullis linked to pressure plates. Normally it opens while any linked
## plate is pressed; with open_when_pressed off it opens only while none are.
## It only lets things through once fully raised, but blocks again the moment
## it starts to close. Origin is the top-left corner.

@export var size := Vector2(12, 192):
	set(value):
		size = value
		queue_redraw()
@export var plates: Array[PressurePlate] = []
@export var open_when_pressed := true
## Seconds to rise or fall.
@export var travel_time := 0.6

var _is_open := false
var _open_amount := 0.0
var _shape: CollisionShape2D
var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)
	for plate in plates:
		plate.opens_gate = open_when_pressed
		plate.toggled.connect(_update.unbind(1))
	# Plates learn what's on them during the first physics frames; settle
	# without animating so the level doesn't start with a gate swinging.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_update(true)


func _update(instant := false) -> void:
	var any_pressed := plates.any(func(plate: PressurePlate) -> bool: return plate.pressed)
	var should_open := any_pressed == open_when_pressed
	if should_open == _is_open and not instant:
		return
	_is_open = should_open
	if _tween:
		_tween.kill()
	if not should_open:
		_shape.set_deferred("disabled", false)
	var target := 1.0 if should_open else 0.0
	if instant:
		_set_open_amount(target)
		_shape.set_deferred("disabled", should_open)
		return
	_tween = create_tween()
	_tween.tween_method(_set_open_amount, _open_amount, target, travel_time * absf(target - _open_amount))
	if should_open:
		_tween.tween_callback(_shape.set_deferred.bind("disabled", true))


func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	queue_redraw()


func _draw() -> void:
	var height := size.y * (1.0 - _open_amount)
	if height <= 0.5:
		return
	draw_rect(Rect2(0, 0, size.x, height), Color(0.12, 0.11, 0.16))
	for x in [2.0, size.x / 2.0, size.x - 2.0]:
		draw_line(Vector2(x, 0), Vector2(x, height), Color(0.55, 0.5, 0.62), 2.0)
	for y in range(12, int(height), 24):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.5, 0.62), 2.0)
	draw_rect(Rect2(0, height - 3, size.x, 3), Color(0.7, 0.65, 0.78))
