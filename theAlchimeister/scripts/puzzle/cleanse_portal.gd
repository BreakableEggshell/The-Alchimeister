@tool
extends Area2D
## A bubbling blue wall that washes off every potion effect from anything
## standing in it (the player and monsters), e.g. ending translucency.
## Origin is the floor at its centre; it rises `height` pixels.

@export var height := 192.0:
	set(value):
		height = value
		queue_redraw()
@export var width := 10.0:
	set(value):
		width = value
		queue_redraw()

const WATER := Color(0.3, 0.6, 1.0, 0.4)
const EDGE := Color(0.55, 0.85, 1.0, 0.9)
const BUBBLE := Color(0.8, 0.95, 1.0, 0.85)
const BUBBLE_COUNT := 10
## Bubble rise speed in pixels per second.
const RISE_SPEED := 24.0

var _clock := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Every frame, not just on entry, so a potion splashed inside it wears off too.
	for body in get_overlapping_bodies():
		if body.has_method("clear_potion_effects"):
			body.clear_potion_effects()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var half := width / 2.0
	draw_rect(Rect2(-half, -height, width, height), WATER)
	# Wavy bright edges.
	for side in [-half, half]:
		var points := PackedVector2Array()
		for y in range(0, int(height) + 1, 6):
			points.append(Vector2(side + sin(_clock * 4.0 + y * 0.3) * 1.0, -y))
		draw_polyline(points, EDGE)
	# Bubbles drifting upward, each in its own lane.
	for i in BUBBLE_COUNT:
		var lane := -half + 2.0 + fmod(i * 3.7, width - 4.0)
		var y := fmod(_clock * RISE_SPEED + i * height / BUBBLE_COUNT, height)
		var wobble := sin(_clock * 3.0 + i) * 1.0
		draw_circle(Vector2(lane + wobble, -y), 1.0 + (i % 2) * 0.5, BUBBLE)
