@tool
class_name CastleDoor
extends Area2D
## A door to somewhere else in the castle. Standing in front of it shows an
## "[E]Enter" tag; pressing E (or tapping the tag) closes the iris on the
## knight and opens it again at `target`, the door this one leads to. Doors
## usually come in pairs that lead to each other; a pair shares a `color` (the
## gem over the door), so they're easy to match up.
## Origin is the floor at its centre.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const WOOD := Color(0.45, 0.28, 0.16)
const WOOD_DARK := Color(0.3, 0.18, 0.1)
const FRAME := Color(0.42, 0.38, 0.55)
const IRON := Color(0.2, 0.19, 0.24)

@export var target: CastleDoor
@export var color := Color(0.9, 0.3, 0.3):
	set(value):
		color = value
		queue_redraw()

var _player: Node2D
var _prompt: Button
var _busy := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("doors")
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 24)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	add_child(shape)
	body_entered.connect(_on_body_moved.bind(true))
	body_exited.connect(_on_body_moved.bind(false))
	_prompt = _make_prompt()
	add_child(_prompt)
	SaveGame.controls_changed.connect(_label_prompt)
	_label_prompt.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _player and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		enter()


## Iris in on the knight, out again at the door this one leads to.
func enter() -> void:
	if _busy or not target or not _player or Iris.is_closed:
		return
	var knight := _player
	if knight.get("_dead"):
		return
	_busy = true
	var tree := get_tree()
	tree.paused = true
	await Iris.close(_screen_point(knight))
	if not is_instance_valid(knight) or not knight.is_inside_tree():
		return
	knight.global_position = target.global_position
	knight.velocity = Vector2.ZERO
	tree.paused = false
	# Let the camera catch up at once, rather than slide across the castle.
	var camera := knight.get_node_or_null("Camera") as Camera2D
	await tree.process_frame
	if camera:
		camera.reset_smoothing()
	await tree.process_frame
	if is_instance_valid(knight) and knight.is_inside_tree():
		Iris.open(_screen_point(knight))
	_busy = false


## The middle of the knight, on screen.
func _screen_point(knight: Node2D) -> Vector2:
	return knight.get_global_transform_with_canvas().origin + Vector2(0, -14)


func _on_body_moved(body: Node, entered: bool) -> void:
	if not body.has_method("die"):
		return
	_player = body if entered else null
	_prompt.visible = entered


func _make_prompt() -> Button:
	var prompt := Button.new()
	prompt.focus_mode = Control.FOCUS_NONE
	prompt.z_index = 5
	prompt.add_theme_font_override("font", FONT)
	prompt.add_theme_font_size_override("font_size", 8)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.14, 0.9)
	style.border_color = Color.WHITE
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
	prompt.pressed.connect(enter)
	return prompt


func _label_prompt() -> void:
	_prompt.text = "[%s]Enter" % Controls.key_name(&"interact")
	_prompt.size = Vector2.ZERO
	_prompt.position = Vector2(-roundf(_prompt.size.x / 2.0), -42.0 - _prompt.size.y)


func _draw() -> void:
	# A stone frame, an arched wooden door, and the gem that matches its pair.
	draw_rect(Rect2(-13, -30, 26, 30), FRAME)
	draw_circle(Vector2(0, -30), 13.0, FRAME)
	draw_rect(Rect2(-10, -30, 20, 30), WOOD)
	draw_circle(Vector2(0, -30), 10.0, WOOD)
	for x in [-5.0, 0.0, 5.0]:
		draw_line(Vector2(x, -38), Vector2(x, -1), WOOD_DARK)
	for y in [-26.0, -10.0]:
		draw_rect(Rect2(-10, y, 20, 2), IRON)
	draw_circle(Vector2(6, -14), 1.5, Color(0.85, 0.75, 0.4))
	# The gem.
	var gem := Vector2(0, -36)
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -4), gem + Vector2(3, 0), gem + Vector2(0, 4), gem + Vector2(-3, 0)]), color)
	draw_line(gem + Vector2(-1, -2), gem + Vector2(0, -3), Color(1, 1, 1, 0.8))
	# White outline: something the player can use.
	draw_arc(Vector2(0, -30), 13.5, PI, TAU, 16, Color.WHITE)
	for x in [-13.5, 13.5]:
		draw_line(Vector2(x, -30), Vector2(x, 0), Color.WHITE)
