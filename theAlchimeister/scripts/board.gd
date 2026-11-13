class_name Board
extends Node2D
## The play grid. Knows its size, converts cells to pixel positions,
## and draws the room behind it: the wall tile, in its own colours (`tiled`),
## or faint grid lines.

@export var columns := 16
@export var rows := 9
@export var cell_size := 24
@export var line_color := Color(1, 1, 1, 0.06)
## Wall tiles behind the room, instead of grid lines.
@export var tiled := true


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
		return
	for x in range(columns + 1):
		draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, height), line_color)
	for y in range(rows + 1):
		draw_line(Vector2(0, y * cell_size), Vector2(width, y * cell_size), line_color)
