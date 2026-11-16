@tool
class_name Solid
extends StaticBody2D
## A piece of level geometry: draws its polygon and collides with it.
## Rectangles and ramps are both just polygons.
## Drawn with the tiles in castle_bricks_bg.png (`tiled`): the floor tile along every top
## surface something can stand on (not the very top of the stage, where walls
## hang from), and the brick (below-floor) tile everywhere else, walls hanging
## from the ceiling included. The wall tiles (15 of them) are for the room
## behind (Board).
## Tiles line up with the world, so pieces side by side join seamlessly.
## Planks (`one_way`) are drawn as wood instead.

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
## Drawn with the wall and floor tiles. Off: a flat fill_color.
@export var tiled := true:
	set(value):
		tiled = value
		queue_redraw()

const PLANK_COLOR := Color(0.55, 0.38, 0.22)
const PLANK_DARK := Color(0.38, 0.25, 0.14)
const TILES := preload("res://assets/tiles/castle_bricks_bg.png")
## Each tile's square size, and where it sits in the sheet (tiles 2 px apart).
const TILE_SIZE := 28
const TILE_STEP := 30
const FLOOR_AT := Vector2i(0, 0)
const BELOW_FLOOR_AT := Vector2i(0, 30)
## The wall tiles: 5 across, 3 down, right of the floor ones.
const WALL_COLUMNS := 5
const WALL_ROWS := 3
const WALLS_AT := Vector2i(30, 0)
## The outline around a tiled piece: the dark of the mortar.
const TILED_EDGE := Color(0.13, 0.11, 0.17)

## The tiles cut out of the sheet, each on its own so it can repeat.
static var _wall_tile: Texture2D
static var _wall_tiles: Array[Texture2D] = []
static var _floor_tile: Texture2D
static var _below_floor_tile: Texture2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if Engine.is_editor_hint():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	shape.one_way_collision = one_way
	add_child(shape)


func _notification(what: int) -> void:
	# In the editor, keep the tiles lined up with the world as pieces move.
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		queue_redraw()


func _enter_tree() -> void:
	set_notify_transform(Engine.is_editor_hint())


func _draw() -> void:
	if one_way:
		_draw_plank()
	elif tiled:
		_draw_tiled()
	else:
		draw_colored_polygon(points, fill_color)
		_draw_outline(edge_color)


func _draw_plank() -> void:
	draw_colored_polygon(points, PLANK_COLOR)
	_draw_outline(PLANK_DARK)
	# Board seams every 12px.
	var bounds := _bounds()
	for x in range(int(bounds.position.x) + 12, int(bounds.end.x), 12):
		draw_line(Vector2(x, bounds.position.y + 1), Vector2(x, bounds.end.y - 1), PLANK_DARK)


func _draw_tiled() -> void:
	_cut_tiles()
	var tops := _top_edges()
	# Ground (something to stand on) is filled with the below-floor tile;
	# walls with nothing on top with the wall tile.
	if tops:
		# Rows start right under the floor tile, so the two meet cleanly.
		draw_colored_polygon(points, Color.WHITE, _floor_uvs(points, tops[0][0].y), _below_floor_tile)
	else:
		draw_colored_polygon(points, Color.WHITE, _wall_uvs(), _below_floor_tile)
	# The floor tile along each top surface.
	for top in tops:
		var band := PackedVector2Array([top[0], top[1], top[1] + Vector2(0, TILE_SIZE), top[0] + Vector2(0, TILE_SIZE)])
		for piece in Geometry2D.intersect_polygons(points, band):
			draw_colored_polygon(piece, Color.WHITE, _floor_uvs(piece, top[0].y), _floor_tile)
	_draw_outline(TILED_EDGE)


## Wall texture coordinates, in tiles, lined up with the world so
## neighbouring pieces match.
func _wall_uvs() -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append((global_position + point) / TILE_SIZE)
	return uvs


## Floor texture coordinates for part of a band: lined up with the world
## across, and starting the tile at the band's top edge, `top`.
func _floor_uvs(piece: PackedVector2Array, top: float) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in piece:
		uvs.append(Vector2((global_position.x + point.x) / TILE_SIZE, (point.y - top) / TILE_SIZE))
	return uvs


## Level edges with the solid right under them and open air above: the
## surfaces something can stand on. Edges at the very top of the stage, where
## walls hang from, don't count. Each is [left, right] in local coordinates.
func _top_edges() -> Array:
	var tops := []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if absf(a.y - b.y) > 0.01 or absf(a.x - b.x) < 1.0 or global_position.y + a.y <= 0.0:
			continue
		var middle := (a + b) / 2.0
		if Geometry2D.is_point_in_polygon(middle + Vector2(0, 1), points) and not Geometry2D.is_point_in_polygon(middle - Vector2(0, 1), points):
			tops.append([Vector2(minf(a.x, b.x), a.y), Vector2(maxf(a.x, b.x), a.y)])
	return tops


func _draw_outline(color: Color) -> void:
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color)


func _bounds() -> Rect2:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


## The first wall tile on its own.
static func wall_texture() -> Texture2D:
	_cut_tiles()
	return _wall_tile


## Every wall tile, for the room backdrop (Board) to mix.
static func wall_textures() -> Array[Texture2D]:
	_cut_tiles()
	return _wall_tiles


## Splits the sheet into its tiles, once.
static func _cut_tiles() -> void:
	if _wall_tile:
		return
	var sheet := TILES.get_image()
	for row in WALL_ROWS:
		for column in WALL_COLUMNS:
			var at := WALLS_AT + Vector2i(column, row) * TILE_STEP
			_wall_tiles.append(ImageTexture.create_from_image(sheet.get_region(Rect2i(at, Vector2i(TILE_SIZE, TILE_SIZE)))))
	_wall_tile = _wall_tiles[0]
	_floor_tile = ImageTexture.create_from_image(sheet.get_region(Rect2i(FLOOR_AT, Vector2i(TILE_SIZE, TILE_SIZE))))
	_below_floor_tile = ImageTexture.create_from_image(sheet.get_region(Rect2i(BELOW_FLOOR_AT, Vector2i(TILE_SIZE, TILE_SIZE))))
