@tool
extends CharacterBody2D
## A wooden crate the player can push by walking into it. It only moves while
## being pushed (or when a knockback splash hits it). Origin is the bottom centre.

@export var size := Vector2(20, 20):
	set(value):
		size = value
		queue_redraw()
@export var gravity := 800.0
## How quickly it stops once nobody is pushing.
@export var friction := 900.0

var _push_speed := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)


## Called by the player each frame they lean into the crate.
func push(speed_x: float) -> void:
	_push_speed = speed_x


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if kind == PotionData.KNOCKBACK:
		velocity = PotionData.knockback_velocity(global_position + Vector2(0, -size.y / 2.0), origin, 0.8)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _push_speed != 0.0:
		velocity.x = _push_speed
		_push_speed = 0.0
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()


func _draw() -> void:
	var box := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	draw_rect(box, Color(0.6, 0.4, 0.22))
	var plank := Color(0.45, 0.28, 0.15)
	draw_rect(Rect2(box.position + Vector2(2, 2), box.size - Vector2(4, 4)), plank, false)
	draw_line(box.position + Vector2(3, 3), box.end - Vector2(3, 3), plank, 2.0)
	# White outline marks it as something the player can interact with.
	draw_rect(box.grow(0.5), Color.WHITE, false)
