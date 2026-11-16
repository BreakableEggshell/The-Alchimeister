@tool
extends Area2D
## A treasure chest. When the player is close, an "[E]Open" prompt appears;
## pressing E or tapping the prompt opens it and gives its ingredients.
## With `open_lines`, opening it also pauses the game with a speech bubble
## over the player's head and plays that conversation, the first time only: it
## isn't repeated after a retry.
## Until it's opened, little sparkles twinkle around it.
## Origin is the floor surface at its centre.

## Emitted once it has been opened and its conversation (if any) is over.
signal opened

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Closed and open, side by side, 16 x 19 each, standing on their bottom edge.
const SHEET := preload("res://assets/sprites/props/chest.png")
## How far above the floor the "[E]Open" tag's bottom edge sits.
const PROMPT_RISE := 45.0
const FRAME_SIZE := Vector2(16, 19)
const OUTLINE := Color.WHITE
const SPARKLE := Color(1, 0.95, 0.65)
## Where each sparkle twinkles, relative to the origin, and when in the cycle.
const SPARKLES := [[Vector2(-11, -13), 0.0], [Vector2(10, -6), 0.33], [Vector2(4, -17), 0.66]]
## Seconds for one sparkle to come and go.
const SPARKLE_TIME := 1.4

@export_enum("ember", "gust_feather", "frost_shard", "ghost_wisp") var contents := "ember"
## How many of `contents` it gives.
@export var amount := 1
## An optional second ingredient it also gives.
@export_enum("none", "ember", "gust_feather", "frost_shard", "ghost_wisp") var extra_contents := "none"
## How many of `extra_contents` it gives.
@export var extra_amount := 1
## An optional third ingredient it also gives.
@export_enum("none", "ember", "gust_feather", "frost_shard", "ghost_wisp") var third_contents := "none"
## How many of `third_contents` it gives.
@export var third_amount := 1
## "SPEAKER: text" lines played after opening. Empty for none.
@export var open_lines: PackedStringArray
## What those lines teach, so skipping them warns the player.
@export_enum("none", "hint", "tutorial") var open_lines_teach := "none"

## Chests whose lines have been heard, until the next new game. Static, so it
## survives the stage reloading on a retry.
static var _heard := {}

var _opened := false
var _player_near := false
var _player: Node
var _prompt: Button
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("chests")
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 24)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	add_child(shape)
	body_entered.connect(_on_body_moved.bind(true))
	body_exited.connect(_on_body_moved.bind(false))
	_prompt = _make_prompt()
	add_child(_prompt)
	SaveGame.controls_changed.connect(_label_prompt)
	_place_prompt.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _opened:
		return
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and not _opened and event.is_action_pressed("interact"):
		open()
		get_viewport().set_input_as_handled()


static func forget_heard() -> void:
	_heard.clear()


func is_opened() -> bool:
	return _opened


func open() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory") as Inventory
	if _opened or not inventory:
		return
	_opened = true
	_prompt.hide()
	queue_redraw()
	var gifts := [[contents, amount], [extra_contents, extra_amount], [third_contents, third_amount]]
	gifts = gifts.filter(func(gift: Array) -> bool: return gift[0] != "none")
	for i in gifts.size():
		inventory.add_ingredient(StringName(gifts[i][0]), gifts[i][1])
		# Icons side by side, centred over the chest.
		_float_icon(StringName(gifts[i][0]), (i - (gifts.size() - 1) / 2.0) * 10.0)
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var key := String(get_path())
	if dialogue and not open_lines.is_empty() and not _heard.has(key):
		_heard[key] = true
		await dialogue.interrupt(open_lines, _player, &"" if open_lines_teach == "none" else StringName(open_lines_teach))
	opened.emit()


func _on_body_moved(body: Node, entered: bool) -> void:
	if body.has_method("die"):
		_player_near = entered
		_player = body
		_prompt.visible = entered and not _opened


## A small "[E]Open" tag up above the chest, clear of the knight's head. It's a button so it can
## be tapped on touch screens.
func _make_prompt() -> Button:
	var prompt := Button.new()
	prompt.text = _prompt_text()
	prompt.focus_mode = Control.FOCUS_NONE
	prompt.z_index = 5
	prompt.add_theme_font_override("font", FONT)
	# Same size as the potion slot numbers.
	prompt.add_theme_font_size_override("font_size", 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.14, 0.9)
	style.border_color = OUTLINE
	style.set_border_width_all(1)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	prompt.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.3, 0.25, 0.45, 0.95)
	prompt.add_theme_stylebox_override("hover", hover)
	prompt.add_theme_stylebox_override("pressed", hover)
	prompt.hide()
	prompt.pressed.connect(open)
	return prompt


## Shrinks the prompt to its text and centres it PROMPT_RISE above the floor. Runs once
## it's in the tree, when its small font is actually in effect.
func _prompt_text() -> String:
	return "[%s]Open" % Controls.key_name(&"interact")


func _label_prompt() -> void:
	_prompt.text = _prompt_text()
	_place_prompt()


func _place_prompt() -> void:
	_prompt.size = Vector2.ZERO
	_prompt.position = Vector2(-roundf(_prompt.size.x / 2.0), -PROMPT_RISE - _prompt.size.y)


## Shows an ingredient rising out of the chest and fading.
func _float_icon(kind: StringName, x: float) -> void:
	var icon := Node2D.new()
	icon.draw.connect(func() -> void: PotionData.draw_ingredient(icon, kind, Vector2.ZERO))
	icon.position = Vector2(x, -12)
	add_child(icon)
	var tween := icon.create_tween().set_parallel()
	tween.tween_property(icon, "position:y", -30.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(icon.queue_free)


func _draw() -> void:
	var frame := Rect2(Vector2(FRAME_SIZE.x if _opened else 0.0, 0), FRAME_SIZE)
	draw_texture_rect_region(SHEET, Rect2(Vector2(-FRAME_SIZE.x / 2.0, -FRAME_SIZE.y), FRAME_SIZE), frame)
	if not _opened:
		_draw_sparkles()


## Each sparkle grows into a little cross and shrinks away in turn.
func _draw_sparkles() -> void:
	for sparkle in SPARKLES:
		var phase := fposmod(_time / SPARKLE_TIME + sparkle[1], 1.0)
		# Shown for the first half of its cycle, biggest in the middle of that.
		if phase >= 0.5:
			continue
		var arm := roundf(sin(phase * 2.0 * PI) * 2.0)
		var at: Vector2 = sparkle[0]
		draw_rect(Rect2(at, Vector2.ONE), SPARKLE)
		if arm >= 1.0:
			draw_rect(Rect2(at - Vector2(arm, 0), Vector2(arm * 2 + 1, 1)), Color(SPARKLE, 0.8))
			draw_rect(Rect2(at - Vector2(0, arm), Vector2(1, arm * 2 + 1)), Color(SPARKLE, 0.8))
