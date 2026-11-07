@tool
class_name Gate
extends StaticBody2D
## A portcullis linked to pressure plates. Normally it opens while any linked
## plate is pressed (every one, with needs_all); with open_when_pressed off
## it opens only while none are.
## It rises and drops at the same slow speed, and blocks exactly what it
## shows: the bars that are down are solid, the gap under them is free. If
## something is in the way as it drops, it waits above it.
## Origin is the top-left corner. Keep doorways low (a wall above the gate),
## so a closing gate shuts the gap before anyone can dash under it.
## A wire runs from each linked button through the floor or wall to the
## gate, lit in the button's colour (green while free, red while pressed).

@export var size := Vector2(12, 24):
	set(value):
		size = value
		queue_redraw()
@export var plates: Array[PressurePlate] = []
@export var open_when_pressed := true
## Open only while every linked plate is pressed, not just any one.
@export var needs_all := false
## Seconds to rise or drop fully.
@export var travel_time := 1.2

## What a dropping gate stops for instead of crushing.
const BLOCKERS := PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES | PotionData.LAYER_PROPS

var _open_amount := 0.0
var _shape: CollisionShape2D
var _wires: Node2D
## Plates learn what's on them during the first physics frames; until then
## the gate stays shut.
var _settle_frames := 2

const WIRE_OUTLINE := Color(0.08, 0.07, 0.11)
const WIRE_ALPHA := 0.9
## How deep into the floor or wall the wires run; each further button's wire
## runs a little deeper, so wires sharing a path stay apart.
const WIRE_DEPTH := 6.0
const WIRE_SPACING := 4.0


func _ready() -> void:
	_wires = Node2D.new()
	# In front of walls and floors, which the wires run through.
	_wires.z_index = 1
	_wires.draw.connect(_draw_wires)
	add_child(_wires)
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_fit_shape()
	for plate in plates:
		plate.toggled.connect(_wires.queue_redraw.unbind(1))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _settle_frames > 0:
		_settle_frames -= 1
		return
	var is_pressed := func(plate: PressurePlate) -> bool: return plate.pressed
	var active := plates.all(is_pressed) if needs_all else plates.any(is_pressed)
	var target := 1.0 if active == open_when_pressed else 0.0
	if _open_amount == target:
		return
	var next := move_toward(_open_amount, target, delta / travel_time)
	# Dropping onto someone: hold here until they've moved.
	if next < _open_amount and _blocked_at(next):
		return
	_set_open_amount(next)


## How far down the bars reach at an open amount.
func _bars_height(amount: float) -> float:
	return size.y * (1.0 - amount)


## Whether a body would be inside the bars at this open amount.
func _blocked_at(amount: float) -> bool:
	var height := _bars_height(amount)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x, height)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.transform = global_transform * Transform2D(0.0, Vector2(size.x / 2.0, height / 2.0))
	query.collision_mask = BLOCKERS
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## The solid part is just the bars that are down.
func _fit_shape() -> void:
	var height := _bars_height(_open_amount)
	(_shape.shape as RectangleShape2D).size = Vector2(size.x, maxf(height, 0.5))
	_shape.position = Vector2(size.x / 2.0, height / 2.0)
	_shape.disabled = height < 0.5


func _process(_delta: float) -> void:
	# In the editor, follow buttons and the gate as they're moved around.
	if Engine.is_editor_hint() and _wires:
		_wires.queue_redraw()


## Each button's wire: down into the floor (or wall) under the button, along
## inside it, then out into the middle of the gate's nearest edge.
func _draw_wires() -> void:
	var gate_rect := Rect2(Vector2.ZERO, size)
	for i in plates.size():
		var plate := plates[i]
		if not is_instance_valid(plate):
			continue
		var up := Vector2.UP.rotated(plate.global_rotation)
		var surface := to_local(plate.global_position)
		var buried := to_local(plate.global_position - up * (WIRE_DEPTH + i * WIRE_SPACING))
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
	_fit_shape()
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
