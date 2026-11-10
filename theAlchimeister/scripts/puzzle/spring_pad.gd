@tool
class_name SpringPad
extends StaticBody2D
## A spring trap set into the floor: a plate held down on a coiled spring.
## A knockback splash trips its catch, and the plate snaps up, flinging
## whatever stands on it (the knight, a rock, a crate, a slime) straight up
## at `launch_speed`. The knight can steer on the way up and down; anything
## else just goes up and comes back down. It sets itself again after
## RESET_TIME. The plate is flush with the floor, so it's walked over like
## floor. Origin is the floor surface at its centre.

@export var width := 24.0:
	set(value):
		width = value
		queue_redraw()
## How fast it flings things up (420 is about 110 pixels high).
@export var launch_speed := 420.0

const RESET_TIME := 1.0
## How high above the plate things count as standing on it.
const SENSE_HEIGHT := 12.0
## How far the plate pops up when sprung (drawn only).
const POP_HEIGHT := 10.0
const PLATE := Color(0.62, 0.6, 0.68)
const PLATE_DARK := Color(0.3, 0.28, 0.36)
const HAZARD := Color(0.95, 0.8, 0.25)
const SLOT := Color(0.08, 0.07, 0.11)

var _sprung_left := 0.0
var _sense: Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# A prop, so potion splashes reach it; flush with the floor.
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 6)
	shape.shape = rect
	shape.position = Vector2(0, 3)
	add_child(shape)
	_sense = Area2D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES | PotionData.LAYER_PROPS
	var sense_shape := CollisionShape2D.new()
	var sense_rect := RectangleShape2D.new()
	sense_rect.size = Vector2(width - 2.0, SENSE_HEIGHT)
	sense_shape.shape = sense_rect
	sense_shape.position = Vector2(0, -SENSE_HEIGHT / 2.0 - 0.5)
	_sense.add_child(sense_shape)
	add_child(_sense)


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind != PotionData.KNOCKBACK or is_sprung():
		return
	_sprung_left = RESET_TIME
	queue_redraw()
	# After the splash: the fling replaces any knockback from the same potion.
	_launch.call_deferred(_sense.get_overlapping_bodies())


func is_sprung() -> bool:
	return _sprung_left > 0.0


func _launch(riders: Array) -> void:
	for body in riders:
		if is_instance_valid(body) and body is CharacterBody2D:
			body.velocity = Vector2(0, -launch_speed)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _sprung_left <= 0.0:
		return
	_sprung_left = maxf(_sprung_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var half := width / 2.0
	# The slot in the floor, with hazard stripes along its edges.
	draw_rect(Rect2(-half - 2.0, 0, width + 4.0, 5), SLOT)
	for x in range(int(-half - 2.0), int(half + 2.0), 4):
		draw_rect(Rect2(x, 0, 2, 2), HAZARD)
	# Up quickly, then sinking back as it sets itself again.
	var pop := 0.0
	if is_sprung():
		var t := 1.0 - _sprung_left / RESET_TIME
		pop = POP_HEIGHT * (1.0 - t * t)
	if pop > 0.5:
		# The coil between the slot and the raised plate.
		var coil := PackedVector2Array()
		var turns := 4
		for i in turns * 2 + 1:
			coil.append(Vector2(-half * 0.5 if i % 2 == 0 else half * 0.5, -pop * i / (turns * 2.0)))
		draw_polyline(coil, Color(0.8, 0.8, 0.85), 1.0)
	var plate := Rect2(-half, -2.0 - pop, width, 3)
	draw_rect(plate, PLATE)
	draw_rect(plate, PLATE_DARK, false)
	# Arrows: it throws things up.
	if pop <= 0.5:
		for x in [-half * 0.5, half * 0.5]:
			draw_line(Vector2(x - 2, -3), Vector2(x, -5), Color.WHITE)
			draw_line(Vector2(x + 2, -3), Vector2(x, -5), Color.WHITE)
