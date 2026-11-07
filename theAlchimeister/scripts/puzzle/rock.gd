@tool
extends CharacterBody2D
## A heavy boulder. Too heavy to push by walking; a knockback splash sends it
## sliding until friction stops it, unless it's wedged under a low ceiling:
## then it can't lift, so knockback only makes it shudder. Other potions
## (translucent included) don't affect rocks. Falling onto the knight crushes
## him. Origin is at the bottom centre.

@export var size := Vector2(22, 22):
	set(value):
		size = value
		queue_redraw()
@export var gravity := 800.0
@export var friction := 500.0
## Multiplier on knockback speed; below 1 because rocks are heavy.
@export var knockback_strength := 0.8
## Falling at least this fast (px/s) onto the knight crushes him.
const CRUSH_SPEED := 60.0

## Seconds left of the shudder after a knockback it can't move from.
var _shake_left := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)


## Heavy enough to press a HeavyButton.
func is_heavy() -> bool:
	return true


## `power` scales knockback with how hard the potion was thrown.
func apply_potion(kind: StringName, origin: Vector2, power := 1.0) -> void:
	if kind == PotionData.KNOCKBACK:
		if is_wedged():
			_shake_left = 0.3
			return
		velocity = PotionData.knockback_velocity(global_position + Vector2(0, -size.y / 2.0), origin, knockback_strength * power)


## Pinned between the floor and a ceiling right on top of it.
func is_wedged() -> bool:
	return test_move(global_transform, Vector2(0, -2))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		queue_redraw()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		velocity.y += gravity * delta
	if velocity.y >= CRUSH_SPEED:
		_crush_below(velocity.y * delta)
	move_and_slide()


## Rocks fall straight through the knight (they don't collide with him), so
## look for him in the strip the rock is about to fall through, plus its own
## bottom edge.
func _crush_below(fall: float) -> void:
	var strip := RectangleShape2D.new()
	strip.size = Vector2(size.x - 4.0, fall + 4.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = strip
	query.transform = Transform2D(0.0, global_position + Vector2(0, (fall - 4.0) / 2.0 + 2.0))
	query.collision_mask = PotionData.LAYER_PLAYER
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 4):
		var body: Object = hit.collider
		if body.has_method("die"):
			body.die(GameOver.CRUSHED)


func _draw() -> void:
	if _shake_left > 0.0:
		draw_set_transform(Vector2(1.0 if int(_shake_left * 40.0) % 2 == 0 else -1.0, 0))
	var w := size.x / 2.0
	var h := size.y
	var outline := PackedVector2Array([
		Vector2(-w, 0), Vector2(-w, -h * 0.55), Vector2(-w * 0.6, -h * 0.9), Vector2(0, -h),
		Vector2(w * 0.65, -h * 0.85), Vector2(w, -h * 0.45), Vector2(w, 0),
	])
	draw_colored_polygon(outline, Color(0.45, 0.43, 0.5))
	outline.append(outline[0])
	# White outline marks it as something the player can interact with.
	draw_polyline(outline, Color.WHITE)
	draw_line(Vector2(-w * 0.3, -h * 0.6), Vector2(w * 0.1, -h * 0.4), Color(0.32, 0.3, 0.36))
	draw_line(Vector2(w * 0.2, -h * 0.75), Vector2(w * 0.5, -h * 0.55), Color(0.32, 0.3, 0.36))
