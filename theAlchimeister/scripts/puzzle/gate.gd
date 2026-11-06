@tool
class_name Gate
extends StaticBody2D
## A portcullis linked to pressure plates. Normally it opens while any linked
## plate is pressed; with open_when_pressed off it opens only while none are.
## It only lets things through once fully raised, but blocks again the moment
## it starts to close. Origin is the top-left corner.
## A wire runs from each linked button through the floor or wall to the
## gate, lit in the button's colour (green while free, red while pressed).

@export var size := Vector2(12, 192):
	set(value):
		size = value
		queue_redraw()
@export var plates: Array[PressurePlate] = []
@export var open_when_pressed := true
## Seconds to rise fully. Slow enough that a half-raised gate doesn't look passable.
@export var travel_time := 1.2
## Seconds to drop fully. Quicker than rising, so a plate that's only pressed
## briefly and repeatedly can't ratchet the gate open bit by bit.
@export var close_time := 0.25

var _is_open := false
var _open_amount := 0.0
var _shape: CollisionShape2D
var _tween: Tween
var _wires: Node2D

const WIRE_OUTLINE := Color(0.08, 0.07, 0.11)
const WIRE_ALPHA := 0.9
## How deep into the floor or wall the wires run.
const WIRE_DEPTH := 6.0


func _ready() -> void:
	_wires = Node2D.new()
	# In front of walls and floors, which the wires run through.
	_wires.z_index = 1
	_wires.draw.connect(_draw_wires)
	add_child(_wires)
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)
	for plate in plates:
		plate.toggled.connect(_update.unbind(1))
		plate.toggled.connect(_wires.queue_redraw.unbind(1))
	# Plates learn what's on them during the first physics frames. Gates start
	# closed; if something already holds one open, it opens at normal speed.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_update()


func _update() -> void:
	var any_pressed := plates.any(func(plate: PressurePlate) -> bool: return plate.pressed)
	var should_open := any_pressed == open_when_pressed
	if should_open == _is_open:
		return
	_is_open = should_open
	if _tween:
		_tween.kill()
	if not should_open:
		_shape.set_deferred("disabled", false)
	var target := 1.0 if should_open else 0.0
	_tween = create_tween()
	var full_time := travel_time if should_open else close_time
	_tween.tween_method(_set_open_amount, _open_amount, target, full_time * absf(target - _open_amount))
	if should_open:
		_tween.tween_callback(_shape.set_deferred.bind("disabled", true))


func _process(_delta: float) -> void:
	# In the editor, follow buttons and the gate as they're moved around.
	if Engine.is_editor_hint() and _wires:
		_wires.queue_redraw()


## Each button's wire: down into the floor (or wall) under the button, along
## inside it, then out into the middle of the gate's nearest edge.
func _draw_wires() -> void:
	var gate_rect := Rect2(Vector2.ZERO, size)
	for plate in plates:
		if not is_instance_valid(plate):
			continue
		var up := Vector2.UP.rotated(plate.global_rotation)
		var surface := to_local(plate.global_position)
		var buried := to_local(plate.global_position - up * WIRE_DEPTH)
		if gate_rect.has_point(buried):
			continue
		# The middle of whichever gate edge faces the wire.
		var end := Vector2(clampf(buried.x, 0.0, size.x), clampf(buried.y, 0.0, size.y))
		if buried.y > size.y or buried.y < 0.0:
			end.x = size.x / 2.0
		else:
			end.y = size.y / 2.0
		var along := Vector2.RIGHT.rotated(plate.global_rotation)
		var corner := Vector2(end.x, buried.y) if absf(along.x) >= absf(along.y) else Vector2(buried.x, end.y)
		var points := PackedVector2Array([surface.round(), buried.round(), corner.round(), end.round()])
		var color: Color = plate.PRESSED_COLOR if plate.pressed else plate.FREE_COLOR
		_wires.draw_polyline(points, WIRE_OUTLINE, 3.0)
		_wires.draw_polyline(points, Color(color, WIRE_ALPHA), 1.0)


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
