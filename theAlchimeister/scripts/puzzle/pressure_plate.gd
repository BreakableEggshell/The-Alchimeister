@tool
class_name PressurePlate
extends Area2D
## A floor button, pressed while the player, an enemy or a prop stands on it.
## Origin is the floor surface at its centre. Green while free, red while
## pressed. Drawn in front of whatever stands on it so it stays visible.

signal toggled(pressed: bool)

@export var width := 20.0:
	set(value):
		width = value
		queue_redraw()

const FREE_COLOR := Color(0.4, 0.9, 0.45)
const PRESSED_COLOR := Color(1.0, 0.35, 0.35)

var pressed := false


func _ready() -> void:
	# Above the knight (1) and the aim (2), so bodies on it don't hide it.
	z_index = 3
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
	var color := PRESSED_COLOR if pressed else FREE_COLOR
	var height := 2.0 if pressed else 3.0
	draw_rect(Rect2(-width / 2.0 - 2.0, -1.0, width + 4.0, 1.0), Color(0.15, 0.14, 0.2))
	draw_rect(Rect2(-width / 2.0, -1.0 - height, width, height), color)
