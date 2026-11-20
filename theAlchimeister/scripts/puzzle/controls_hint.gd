@tool
extends Node2D
## A sign in the world teaching a control, in the same look as the "TAP AND
## DRAG" sign (ThrowHint). `shows` picks which:
## - MOVE: the move-left and move-right keycaps under "MOVE".
## - JUMP: the jump keycap and "JUMP".
## The keycaps show every key bound to the action (SPACE and W for jump, say),
## or on a phone, little copies of the on-screen buttons, or with a controller
## its arrows and button. Origin is its centre. Drawn behind
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
## Between a jump sign's keys.
const OR_WORD := "OR"
const EDITOR_KEYS := {&"move_left": "A", &"move_right": "D", &"jump": "SPACE"}


func _ready() -> void:
	if not Engine.is_editor_hint():
		SaveGame.controls_changed.connect(queue_redraw)


func _draw() -> void:
	if shows == Shows.MOVE:
		_draw_move()
	else:
		_draw_jump()


## Every key moving left, then every key moving right, under "MOVE".
func _draw_move() -> void:
	var caps: Array = _caps(&"move_left") + _caps(&"move_right")
	var row := _row_width(caps)
	var width := maxf(row, _text_width("MOVE")) + MARGIN * 2.0
	var panel := _draw_panel(Vector2(width, MOVE_HEIGHT))
	draw_string(FONT, Vector2(panel.position.x, panel.position.y + 11), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 8, TEXT_COLOR)
	_draw_row(caps, Vector2(-row / 2.0, panel.position.y + 17.0))


## The key that jumps, then "JUMP". With more than one (SPACE and W, say):
## "[SPACE] OR [W]", with "JUMP" under them.
func _draw_jump() -> void:
	var caps: Array = _caps(&"jump")
	if caps.size() > 1:
		var keys := _row_width(caps, OR_WORD)
		var panel_two := _draw_panel(Vector2(maxf(keys, _text_width("JUMP")) + MARGIN * 2.0, MOVE_HEIGHT))
		_draw_row(caps, Vector2(-keys / 2.0, panel_two.position.y + 6.0), OR_WORD)
		draw_string(FONT, Vector2(panel_two.position.x, panel_two.end.y - 6.0), "JUMP", HORIZONTAL_ALIGNMENT_CENTER, panel_two.size.x, 8, TEXT_COLOR)
		return
	var row := _row_width(caps)
	var label_width := _text_width("JUMP")
	var panel := _draw_panel(Vector2(row + GAP + label_width + MARGIN * 2.0, JUMP_HEIGHT))
	var x := panel.position.x + MARGIN
	var y := panel.position.y + 6.0
	_draw_row(caps, Vector2(x, y))
	draw_string(FONT, Vector2(x + row + GAP, y + 9), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TEXT_COLOR)


## `action`'s keycaps: [label, action] for each key bound to it. On a phone, or
## with a controller, one cap: the arrow ("" label), or for jump with a
## controller, its button.
func _caps(action: StringName) -> Array:
	if Engine.is_editor_hint():
		return [[EDITOR_KEYS[action], action]]
	if TouchControls.touch_on() and not Controls.using_pad:
		return [["", action]]
	if Controls.using_pad:
		return [[Controls.key_name(action) if action == &"jump" else "", action]]
	var caps := []
	for key in Controls.keys_of(action):
		caps.append([Controls.name_of(key), action])
	return caps if not caps.is_empty() else [["?", action]]


## A row of keycaps' width, with `between` (a word, like "OR") between each.
func _row_width(caps: Array, between := "") -> float:
	var width := 0.0
	for cap in caps:
		width += _key_width(cap[0])
	var join := GAP if between == "" else _text_width(between) + GAP * 2.0
	return width + join * maxi(caps.size() - 1, 0)


func _draw_row(caps: Array, at: Vector2, between := "") -> void:
	var x := at.x
	for i in caps.size():
		var cap: Array = caps[i]
		var width := _key_width(cap[0])
		_draw_key(Rect2(x, at.y, width, KEY), cap[0], cap[1])
		x += width + GAP
		if between != "" and i + 1 < caps.size():
			draw_string(FONT, Vector2(x, at.y + 9), between, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(TEXT_COLOR, 0.7))
			x += _text_width(between) + GAP


func _draw_panel(size: Vector2) -> Rect2:
	var panel := Rect2(-size / 2.0, size)
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel.grow(-0.5), Color(TEXT_COLOR, 0.5), false)
	return panel


func _text_width(text: String) -> float:
	return FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


## A key's width: a square for a letter, wider for a name like SPACE.
func _key_width(label: String) -> float:
	return maxf(KEY, _text_width(label) + 6.0)


func _draw_key(cap: Rect2, label: String, action: StringName) -> void:
	draw_rect(cap, Color(0.22, 0.2, 0.3))
	draw_rect(cap.grow(-0.5), Color(TEXT_COLOR, 0.8), false)
	if label == "":
		# The on-screen button's arrow, small.
		var c := cap.get_center().round()
		var arrow: PackedVector2Array
		match action:
			&"move_left": arrow = [c + Vector2(-3, 0), c + Vector2(2, -4), c + Vector2(2, 4)]
			&"move_right": arrow = [c + Vector2(3, 0), c + Vector2(-2, -4), c + Vector2(-2, 4)]
			_: arrow = [c + Vector2(0, -3), c + Vector2(-4, 2), c + Vector2(4, 2)]
		draw_colored_polygon(arrow, TEXT_COLOR)
		return
	draw_string(FONT, cap.position + Vector2(0, 9), label, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 8, TEXT_COLOR)
