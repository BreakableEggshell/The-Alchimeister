class_name Board
extends Node2D
## The play grid. Knows its size, converts cells to pixel positions,
## and draws the room behind it (`tiled`): the plain wall tile repeated, with
## some bricks darker, whole bricks only, so the pattern runs on unbroken
## across the tiles. Which bricks are dark depends only on where they are, so
## it's the same on every retry and in every level. Or faint grid lines.

@export var columns := 16
@export var rows := 9
@export var cell_size := 24
@export var line_color := Color(1, 1, 1, 0.06)
## Wall tiles behind the room, instead of grid lines.
@export var tiled := true

## The wall tile's bricks: each row is BRICK_ROW_HEIGHT tall (6 of brick, 1 of
## mortar) and these are where its joints are, every 28 px.
const BRICK_JOINTS := [[7, 21], [0, 13], [6, 20], [12, 27]]
const BRICK_ROW_HEIGHT := 7
## The darker bricks: their colour, and how many of them (as in the art's
## variants, about one brick in six).
const DARK_BRICK := Color8(21, 20, 28)
const DARK_PERCENT := 16


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size + Vector2.ONE * cell_size / 2.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _draw() -> void:
	var width := columns * cell_size
	var height := rows * cell_size
	if tiled:
		draw_texture_rect(Solid.wall_texture(), Rect2(0, 0, width, height), true)
		_draw_dark_bricks(width, height)
		return
	for x in range(columns + 1):
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, height), line_color)
	for y in range(rows + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(width, y * cell_size), line_color)


## Darkens whole bricks, picked by where they are.
func _draw_dark_bricks(width: int, height: int) -> void:
	var tile := Solid.TILE_SIZE
	var row := 0
	for y in range(0, height, BRICK_ROW_HEIGHT):
		var joints: Array = BRICK_JOINTS[row % BRICK_JOINTS.size()]
		for x0 in range(-tile, width, tile):
			for i in joints.size():
				var start: int = x0 + joints[i]
				var end: int = x0 + (joints[i + 1] if i + 1 < joints.size() else joints[0] + tile)
				if end <= 0 or start >= width:
					continue
				if absi(hash(Vector2i(start, row))) % 100 < DARK_PERCENT:
					draw_rect(Rect2(start, y, end - start, BRICK_ROW_HEIGHT - 1), DARK_BRICK)
		row += 1
