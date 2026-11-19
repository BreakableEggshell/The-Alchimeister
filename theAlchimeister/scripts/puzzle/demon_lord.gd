class_name DemonLord
extends Area2D
## The Demon King's giant form: a wall of darkness from floor to ceiling that
## fills everything behind (left of) its front edge and creeps right after the
## knight. Touching it is death. It closes in at `speed`, faster
## (`catch_up_speed`) while the knight is more than `catch_up_distance` ahead,
## so it always looms at the left of the screen, and stops at `stop_x`.
## Potions break on it, and nothing touches it (a "[NO EFFECT]" puff) except
## the ??? potion (`struck`) and a Death potion (`killed`).
## Drawn from its sheet (dk_potion_form.png: a looping animation), stretched
## to `height`, with its flat colour filling in behind.
## Origin is the front edge at the top of the stage; it reaches `height` down.
## It stops with the game (dialogue, the book).

signal struck
signal killed

@export var height := 324.0
@export var speed := 24.0
@export var catch_up_speed := 70.0
@export var catch_up_distance := 170.0
@export var stop_x := 100000.0

## How far behind its front it's drawn (and catches potions).
const DEPTH := 1400.0
const SHEET := preload("res://assets/dk_potion_form.png")
const FRAMES := 6
const FRAME_SIZE := Vector2(148, 300)
const FPS := 6.0
## Where the front edge (what catches the knight) is across a frame, in sheet
## pixels: past the body's jagged edge, among its spikes. The arms reach on
## beyond it.
const FRONT_IN_FRAME := 50.0
## The body's colour at the sheet's left edge, filling in behind it.
const FILL := Color8(35, 24, 33)
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")

var chasing := false
var _clock := 0.0
## 0 to 1 while growing out of the Demon King (see grow_at): drawn scaled
## from `_grow_anchor`.
var _grow := 1.0
var _grow_anchor := Vector2.ZERO
var _gone := false
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = 5
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = 0
	monitoring = false
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DEPTH, height)
	_shape.shape = rect
	_shape.position = Vector2(-DEPTH / 2.0, height / 2.0)
	add_child(_shape)


func start() -> void:
	if not _gone:
		chasing = true


func stop() -> void:
	chasing = false


func is_gone() -> bool:
	return _gone


## Grows out of a point (the Demon King's feet, global) into the wall, over
## `time` seconds, its front ending at the anchor.
func grow_at(anchor: Vector2, time: float) -> void:
	show()
	global_position = Vector2(anchor.x, global_position.y)
	_grow_anchor = Vector2(0, anchor.y - global_position.y)
	_grow = 0.05
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_grow", 1.0, time)
	await tween.finished


## Killed by a Death potion: shrinks and fades away for good.
func dissolve() -> void:
	_gone = true
	chasing = false
	_shape.set_deferred("disabled", true)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)
	tween.tween_property(self, "_grow", 0.3, 1.2)
	await tween.finished
	hide()


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if _gone or not visible:
		return
	match kind:
		PotionData.SECRET:
			struck.emit()
		PotionData.DEATH:
			killed.emit()
		_:
			_no_effect()


func _physics_process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if not chasing or _gone:
		return
	var knight := get_tree().get_first_node_in_group("player") as Node2D
	if not knight:
		return
	if knight.get("_dead"):
		chasing = false
		return
	var ahead := knight.global_position.x - global_position.x
	var pace := catch_up_speed if ahead > catch_up_distance else speed
	global_position.x = minf(global_position.x + pace * delta, stop_x)
	# Its front reaches him: caught.
	if knight.global_position.x - 6.0 < global_position.x:
		knight.die(GameOver.CAUGHT, Vector2(global_position.x - 8.0, knight.global_position.y - 14.0))


## "[NO EFFECT]" rising off its front.
func _no_effect() -> void:
	var label := Label.new()
	label.text = "[NO EFFECT]"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 6
	add_child(label)
	var knight := get_tree().get_first_node_in_group("player") as Node2D
	var y := (knight.global_position.y - global_position.y - 40.0) if knight else height / 2.0
	label.position = Vector2(4, y)
	var tween := create_tween()
	tween.tween_property(label, "position:y", y - 14.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _draw() -> void:
	if _grow < 1.0:
		# Growing: everything scaled about the anchor (the Demon King's feet).
		draw_set_transform(_grow_anchor * (1.0 - _grow), 0.0, Vector2(_grow, _grow))
	var scale_to := height / FRAME_SIZE.y
	var front := FRONT_IN_FRAME * scale_to
	# The body behind the sheet, flat (a pixel's overlap, so no seam shows).
	draw_rect(Rect2(-DEPTH, 0.0, DEPTH - front + 1.0, height), FILL)
	var frame := int(_clock * FPS) % FRAMES
	draw_texture_rect_region(SHEET, Rect2(Vector2(-front, 0.0), FRAME_SIZE * scale_to), Rect2(Vector2(frame * FRAME_SIZE.x, 0.0), FRAME_SIZE))
	draw_set_transform(Vector2.ZERO)
