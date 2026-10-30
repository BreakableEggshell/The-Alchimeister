@tool
class_name Solid
extends StaticBody2D
## A piece of level geometry: draws its polygon and collides with it.
## Rectangles and ramps are both just polygons.

@export var points := PackedVector2Array([Vector2(0, 0), Vector2(48, 0), Vector2(48, 12), Vector2(0, 12)]):
	set(value):
		points = value
		queue_redraw()
@export var fill_color := Color(0.2, 0.19, 0.27)
@export var edge_color := Color(0.42, 0.38, 0.55)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	add_child(shape)


func _draw() -> void:
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, edge_color)
