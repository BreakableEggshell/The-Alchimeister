@tool
extends Node2D
## A sign in the world showing the movement keys: a W / A S D keycap cluster
## with what each does beside it. S is greyed out, since it does nothing.
## Same look as the "TAP AND DRAG" sign (ThrowHint). Origin is its centre.
## Drawn behind the knight and monsters, so they pass in front of it.

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const SIZE := Vector2(100, 52)
const PANEL_COLOR := Color(0.1, 0.09, 0.14, 0.82)
const TEXT_COLOR := Color(0.95, 0.9, 0.8)
const KEY := 12.0
const KEY_GAP := 2.0
## Top-left of the A key, relative to the panel's top-left.
const KEYS_AT := Vector2(10, 32)


func _draw() -> void:
	var panel := Rect2(-SIZE / 2.0, SIZE)
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel.grow(-0.5), Color(TEXT_COLOR, 0.5), false)
	draw_string(FONT, Vector2(panel.position.x, panel.position.y + 11), "CONTROLS", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 8, TEXT_COLOR)

	var row := panel.position + KEYS_AT
	var step := KEY + KEY_GAP
	_draw_key(row + Vector2(step, -step), "W", true)
	_draw_key(row, "A", true)
	_draw_key(row + Vector2(step, 0), "S", false)
	_draw_key(row + Vector2(step * 2.0, 0), "D", true)
	var text_x := row.x + step * 3.0 + 6.0
	draw_string(FONT, Vector2(text_x, row.y - step + 9), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TEXT_COLOR)
	draw_string(FONT, Vector2(text_x, row.y + 9), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TEXT_COLOR)


## A keycap with its letter; dimmed when the key does nothing here.
func _draw_key(at: Vector2, letter: String, used: bool) -> void:
	var alpha := 1.0 if used else 0.35
	var cap := Rect2(at, Vector2(KEY, KEY))
	draw_rect(cap, Color(0.22, 0.2, 0.3, alpha))
	draw_rect(cap.grow(-0.5), Color(TEXT_COLOR, 0.8 * alpha), false)
	draw_string(FONT, at + Vector2(0, 9), letter, HORIZONTAL_ALIGNMENT_CENTER, KEY, 8, Color(TEXT_COLOR, alpha))
