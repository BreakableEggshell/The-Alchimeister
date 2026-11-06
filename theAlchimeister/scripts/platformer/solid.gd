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
## A wooden plank: solid from above, but you can jump up through it from below.
@export var one_way := false:
	set(value):
		one_way = value
		queue_redraw()

const PLANK_COLOR := Color(0.55, 0.38, 0.22)
const PLANK_DARK := Color(0.38, 0.25, 0.14)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	shape.one_way_collision = one_way
	add_child(shape)


func _draw() -> void:
	draw_colored_polygon(points, PLANK_COLOR if one_way else fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, PLANK_DARK if one_way else edge_color)
	if one_way:
		# Board seams every 12px.
		var bounds := Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		for x in range(int(bounds.position.x) + 12, int(bounds.end.x), 12):
			draw_line(Vector2(x, bounds.position.y + 1), Vector2(x, bounds.end.y - 1), PLANK_DARK)
