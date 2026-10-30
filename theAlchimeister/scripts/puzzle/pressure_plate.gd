@tool
class_name PressurePlate
extends Area2D
## A floor button, pressed while the player, an enemy or a prop stands on it.
## Origin is the floor surface at its centre. Green means pressing it opens its
## gate, red means pressing it closes its gate (set by the gate).

signal toggled(pressed: bool)

@export var width := 20.0:
	set(value):
		width = value
		queue_redraw()

var pressed := false
var opens_gate := true:
	set(value):
		opens_gate = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PotionData.SPLASH_MASK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 8)
	shape.shape = rect
	shape.position = Vector2(0, -4)
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := has_overlapping_bodies()
	if now != pressed:
		pressed = now
		queue_redraw()
		toggled.emit(pressed)


func _draw() -> void:
	var color := Color(0.4, 0.9, 0.45) if opens_gate else Color(1.0, 0.4, 0.4)
	var height := 1.0 if pressed else 3.0
	draw_rect(Rect2(-width / 2.0 - 2.0, -1.0, width + 4.0, 1.0), Color(0.15, 0.14, 0.2))
	draw_rect(Rect2(-width / 2.0, -1.0 - height, width, height), color)
