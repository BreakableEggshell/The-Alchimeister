@tool
extends Node2D
## A sign in the world teaching a control, in the same look as the "TAP AND
## DRAG" sign (ThrowHint). `shows` picks which:
## - MOVE: the move-left and move-right keycaps under "MOVE".
## - JUMP: the jump keycap and "JUMP".
## The keycaps show the player's bindings. Origin is its centre. Drawn behind
## the knight and monsters, so they pass in front of it.

enum Shows { MOVE, JUMP }

@export var shows := Shows.MOVE:
	set(value):
		shows = value
		queue_redraw()

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const MOVE_HEIGHT := 36.0
const JUMP_HEIGHT := 24.0
const MARGIN := 8.0
const GAP := 6.0
const PANEL_COLOR := Color(0.1, 0.09, 0.14, 0.82)
const TEXT_COLOR := Color(0.95, 0.9, 0.8)
const KEY := 12.0
## How the keys read in the editor, where bindings aren't loaded.
const EDITOR_KEYS := {&"move_left": "A", &"move_right": "D", &"jump": "SPACE"}


func _ready() -> void:
	if not Engine.is_editor_hint():
		SaveGame.controls_changed.connect(queue_redraw)


func _draw() -> void:
	if shows == Shows.MOVE:
		_draw_move()
	else:
		_draw_jump()


func _draw_move() -> void:
	var left := _key_label(&"move_left")
	var right := _key_label(&"move_right")
	var left_width := _key_width(left)
	var right_width := _key_width(right)
	var width := maxf(left_width + GAP + right_width, _text_width("MOVE")) + MARGIN * 2.0
	var panel := _draw_panel(Vector2(width, MOVE_HEIGHT))
	draw_string(FONT, Vector2(panel.position.x, panel.position.y + 11), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 8, TEXT_COLOR)
	var x := -(left_width + GAP + right_width) / 2.0
	var y := panel.position.y + 17.0
	_draw_key(Rect2(x, y, left_width, KEY), left)
	_draw_key(Rect2(x + left_width + GAP, y, right_width, KEY), right)


func _draw_jump() -> void:
	var key := _key_label(&"jump")
	var key_width := _key_width(key)
	var label_width := _text_width("JUMP")
	var panel := _draw_panel(Vector2(key_width + GAP + label_width + MARGIN * 2.0, JUMP_HEIGHT))
	var x := panel.position.x + MARGIN
	var y := panel.position.y + 6.0
	_draw_key(Rect2(x, y, key_width, KEY), key)
	draw_string(FONT, Vector2(x + key_width + GAP, y + 9), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TEXT_COLOR)


func _draw_panel(size: Vector2) -> Rect2:
	var panel := Rect2(-size / 2.0, size)
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel.grow(-0.5), Color(TEXT_COLOR, 0.5), false)
	return panel


func _key_label(action: StringName) -> String:
	return EDITOR_KEYS[action] if Engine.is_editor_hint() else Controls.key_name(action)


func _text_width(text: String) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


## A key's width: a square for a letter, wider for a name like SPACE.
func _key_width(label: String) -> float:
	return maxf(KEY, _text_width(label) + 6.0)


func _draw_key(cap: Rect2, label: String) -> void:
	draw_rect(cap, Color(0.22, 0.2, 0.3))
	draw_rect(cap.grow(-0.5), Color(TEXT_COLOR, 0.8), false)
	draw_string(FONT, cap.position + Vector2(0, 9), label, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 8, TEXT_COLOR)
