@tool
class_name Pebble
extends StaticBody2D
## A pebble that stops slimes: they turn back at it (see Slime._blocked). It's
## solid, so the knight hops over it. Drawn and shaped exactly as pebble.png.
## Origin is the middle of its flat bottom; turn it (rotation) to stop a slime
## crawling on a wall, flat side against the wall.

const ART := preload("res://assets/sprites/props/pebble.png")


func _ready() -> void:
	add_to_group("pebbles")
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = ART.get_size()
	shape.shape = rect
	shape.position = Vector2(0, -ART.get_height() / 2.0)
	add_child(shape)


func _draw() -> void:
	draw_texture(ART, Vector2(-ART.get_width() / 2.0, -ART.get_height()).round())
