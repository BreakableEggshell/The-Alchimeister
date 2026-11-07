@tool
class_name HeavyButton
extends PressurePlate
## A big, tall, solid button: things stand on top of it, and the knight has
## to jump up onto it (he can't walk through). Only something heavy presses
## it: a frozen body (the ice is heavy) or a rock. Light things (a slime, the
## knight) just make it dip a little; the knight is told "[TOO LIGHT]".
## It sinks slowly while weighed down, taking `press_time` seconds to go all
## the way, carrying whatever is on top down with it; if the weight comes off
## first, it rises back at the same speed. Once fully down it stays down for
## good (latches) and goes flat, so it can be walked over.
## With `needs` above 1 it only sinks while that many heavy things are on it
## at once; a row of marks on its face lights up one per heavy thing.
## Green while up, red once pressed. Origin is the floor at its centre.

@export var press_time := 1.5
## Heavy things that must be on it at the same time.
@export var needs := 1:
	set(value):
		needs = maxi(value, 1)
		queue_redraw()
## How far the top stands above the floor when up.
@export var cap_height := 14.0:
	set(value):
		cap_height = value
		queue_redraw()
## How far the top stands above the floor once fully pressed.
const PRESSED_HEIGHT := 4.0
## The frame around the bottom, drawn below the cap.
const BASE_HEIGHT := 2.0
## Seconds before the knight can be told "[TOO LIGHT]" again.
const TOO_LIGHT_COOLDOWN := 1.5

## 0 when up, 1 when fully pressed.
var progress := 0.0
var _weighed := false
## Heavy things on it right now.
var _heavy_count := 0
var _too_light_at := -INF
## The solid top; it moves with the button so riders go up and down with it.
var _cap: AnimatableBody2D
var _cap_shape: CollisionShape2D


func _init() -> void:
	width = 36.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Senses whoever stands on top, at any height the cap can be at. A little
	# narrower than the cap, so bodies pressed against its sides don't count.
	collision_layer = 0
	collision_mask = PotionData.SPLASH_MASK
	var sense := CollisionShape2D.new()
	var sense_rect := RectangleShape2D.new()
	sense_rect.size = Vector2(width - 4.0, cap_height + 6.0)
	sense.shape = sense_rect
	sense.position = Vector2(0, -(cap_height + 6.0) / 2.0 - 1.0)
	add_child(sense)
	body_entered.connect(_on_body_entered)

	_cap = AnimatableBody2D.new()
	_cap.collision_layer = PotionData.LAYER_WORLD
	_cap.collision_mask = 0
	_cap_shape = CollisionShape2D.new()
	var cap_rect := RectangleShape2D.new()
	cap_rect.size = Vector2(width, cap_height)
	_cap_shape.shape = cap_rect
	_cap_shape.position = Vector2(0, -cap_height / 2.0)
	_cap.add_child(_cap_shape)
	add_child(_cap)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or pressed:
		return
	var heavy_count := get_overlapping_bodies().filter(_is_heavy).size()
	var heavy := heavy_count >= needs
	var now_weighed := has_overlapping_bodies()
	if heavy_count != _heavy_count:
		_heavy_count = heavy_count
		queue_redraw()
	var next := move_toward(progress, 1.0 if heavy else 0.0, delta / press_time)
	if next != progress or now_weighed != _weighed:
		progress = next
		_weighed = now_weighed
		queue_redraw()
	# The cap's top sits at the drawn height; the rest of it is in the floor.
	_cap.position.y = cap_height - _top_height()
	# A hair short of 1 from float rounding still counts as all the way down.
	if progress >= 1.0 - 0.0001:
		progress = 1.0
		pressed = true
		# Flat now: nothing to jump over any more.
		_cap_shape.set_deferred("disabled", true)
		queue_redraw()
		toggled.emit(true)


## How high the top stands above the floor right now.
func _top_height() -> float:
	var height := lerpf(cap_height, PRESSED_HEIGHT, progress)
	# Something light on it pushes it down a touch, but no further.
	if _weighed and progress < 1.0:
		height = maxf(height - 1.0, PRESSED_HEIGHT)
	return height


## Frozen things are encased in heavy ice; rocks are heavy anyway.
func _is_heavy(body: Node) -> bool:
	if body.has_method("is_frozen") and body.is_frozen():
		return true
	return body.has_method("is_heavy") and body.is_heavy()


func _on_body_entered(body: Node) -> void:
	if pressed or _is_heavy(body) or not body.has_method("float_text"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _too_light_at >= TOO_LIGHT_COOLDOWN:
		_too_light_at = now
		body.float_text("[TOO LIGHT]", Color(1, 0.85, 0.5))


func _draw() -> void:
	var top := _top_height()
	var color := FREE_COLOR.lerp(PRESSED_COLOR, progress)
	var half := width / 2.0
	var cap := Rect2(-half, -top, width, top - BASE_HEIGHT)
	draw_rect(Rect2(-half - 3.0, -BASE_HEIGHT, width + 6.0, BASE_HEIGHT), Color(0.15, 0.14, 0.2))
	draw_rect(cap, color)
	draw_rect(Rect2(cap.position, Vector2(width, 1.0)), color.lightened(0.35))
	draw_rect(cap, color.darkened(0.45), false, 1.0)
	if needs > 1:
		# One mark per heavy thing needed, lit (ice blue) per one on it.
		var mark := 4.0
		var gap := 3.0
		var row := needs * mark + (needs - 1) * gap
		for i in needs:
			var at := Vector2(-row / 2.0 + i * (mark + gap), cap.get_center().y - mark / 2.0)
			var lit := pressed or i < _heavy_count
			draw_rect(Rect2(at, Vector2(mark, mark)), Color(0.75, 0.95, 1.0) if lit else color.darkened(0.35))
