@tool
extends Area2D
## A treasure chest. When the player is close, an "[E]Open" prompt appears;
## pressing E or tapping the prompt opens it and gives its ingredients.
## With `open_lines`, opening it also pauses the game with a speech bubble
## over the player's head and plays that conversation.
## Origin is the floor surface at its centre.

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const OUTLINE := Color.WHITE

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

var _opened := false
var _player_near := false
var _player: Node
var _prompt: Button


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
	_place_prompt.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and not _opened and event.is_action_pressed("interact"):
		open()
		get_viewport().set_input_as_handled()


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
	if dialogue and not open_lines.is_empty():
		dialogue.interrupt(open_lines, _player)


func _on_body_moved(body: Node, entered: bool) -> void:
	if body.has_method("die"):
		_player_near = entered
		_player = body
		_prompt.visible = entered and not _opened


## A small "[E]Open" tag sitting just above the lid. It's a button so it can
## be tapped on touch screens.
func _make_prompt() -> Button:
	var prompt := Button.new()
	prompt.text = "[E]Open"
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
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	prompt.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.3, 0.25, 0.45, 0.95)
	prompt.add_theme_stylebox_override("hover", hover)
	prompt.add_theme_stylebox_override("pressed", hover)
	prompt.hide()
	prompt.pressed.connect(open)
	return prompt


## Shrinks the prompt to its text and centres it just above the lid. Runs once
## it's in the tree, when its small font is actually in effect.
func _place_prompt() -> void:
	_prompt.size = Vector2.ZERO
	_prompt.position = Vector2(-roundf(_prompt.size.x / 2.0), -14.0 - _prompt.size.y)


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
	var wood := Color(0.55, 0.33, 0.18)
	var band := Color(0.95, 0.8, 0.35)
	draw_rect(Rect2(-8, -8, 16, 8), wood)
	draw_rect(Rect2(-8, -8, 16, 1), band)
	if _opened:
		draw_rect(Rect2(-8, -14, 16, 3), wood.darkened(0.2))
		draw_rect(Rect2(-6, -9, 12, 1), Color(1, 0.95, 0.6, 0.8))
		draw_rect(Rect2(-8.5, -14.5, 17, 3), OUTLINE, false)
		draw_rect(Rect2(-8.5, -8.5, 17, 8.5), OUTLINE, false)
	else:
		draw_rect(Rect2(-8, -12, 16, 4), wood.lightened(0.1))
		draw_rect(Rect2(-1, -10, 2, 3), band)
		draw_rect(Rect2(-8.5, -12.5, 17, 12.5), OUTLINE, false)
