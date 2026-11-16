@tool
class_name CrackedWall
extends Solid
## A crumbling stretch of wall, bricked up and cracked all over. Solid, but a
## dynamite blast (Dynamite) brings it down for good.

const BRICK := Color(0.36, 0.33, 0.42)
const MORTAR := Color(0.22, 0.2, 0.28)
const CRACK := Color(0.08, 0.07, 0.11)
const BRICK_SIZE := Vector2(8, 6)

var _crumbled := false


func _init() -> void:
	# Its own lighter bricks, not the wall tiles, so it stands out as breakable.
	tiled = false
	fill_color = BRICK
	edge_color = Color(0.55, 0.5, 0.62)


## Caught in a dynamite blast: comes down.
func blast() -> void:
	if _crumbled:
		return
	_crumbled = true
	for child in get_children():
		if child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
	var rubble := CPUParticles2D.new()
	rubble.one_shot = true
	rubble.explosiveness = 0.9
	rubble.amount = 24
	rubble.lifetime = 0.7
	var bounds := _bounds()
	rubble.position = bounds.get_center()
	rubble.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rubble.emission_rect_extents = bounds.size / 2.0
	rubble.direction = Vector2.UP
	rubble.spread = 70.0
	rubble.initial_velocity_min = 30.0
	rubble.initial_velocity_max = 90.0
	rubble.gravity = Vector2(0, 500)
	rubble.scale_amount_min = 2.0
	rubble.scale_amount_max = 3.0
	rubble.color = BRICK.lightened(0.15)
	add_child(rubble)
	rubble.emitting = true
	queue_redraw()
	await get_tree().create_timer(rubble.lifetime + 0.1).timeout
	queue_free()


func is_crumbled() -> bool:
	return _crumbled


func _bounds() -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _draw() -> void:
	if _crumbled:
		return
	super()
	var bounds := _bounds()
	# Brick courses, each row offset by half a brick.
	for y in range(int(bounds.position.y + BRICK_SIZE.y), int(bounds.end.y), int(BRICK_SIZE.y)):
		draw_line(Vector2(bounds.position.x + 1, y), Vector2(bounds.end.x - 1, y), MORTAR)
	var row := 0
	for y in range(int(bounds.position.y), int(bounds.end.y), int(BRICK_SIZE.y)):
		var shift := BRICK_SIZE.x / 2.0 if row % 2 == 1 else 0.0
		for x in range(int(bounds.position.x + shift + BRICK_SIZE.x), int(bounds.end.x), int(BRICK_SIZE.x)):
			draw_line(Vector2(x, y + 1), Vector2(x, minf(y + BRICK_SIZE.y - 1, bounds.end.y - 1)), MORTAR)
		row += 1
	# Big cracks zig-zagging down it.
	var w := bounds.size.x
	var h := bounds.size.y
	var p := bounds.position
	draw_polyline(PackedVector2Array([p + Vector2(w * 0.3, 0), p + Vector2(w * 0.6, h * 0.25), p + Vector2(w * 0.35, h * 0.5), p + Vector2(w * 0.7, h * 0.75), p + Vector2(w * 0.45, h)]), CRACK, 1.0)
	draw_polyline(PackedVector2Array([p + Vector2(w * 0.35, h * 0.5), p + Vector2(w * 0.1, h * 0.62)]), CRACK, 1.0)
