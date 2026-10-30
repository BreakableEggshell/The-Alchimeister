@tool
extends CharacterBody2D
## A heavy boulder. Too heavy to push by walking; a knockback splash sends it
## sliding until friction stops it. Origin is at the bottom centre.

@export var size := Vector2(22, 22):
	set(value):
		size = value
		queue_redraw()
@export var gravity := 800.0
@export var friction := 500.0
## Multiplier on knockback speed; below 1 because rocks are heavy.
@export var knockback_strength := 0.8


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if kind == PotionData.KNOCKBACK:
		velocity = PotionData.knockback_velocity(global_position + Vector2(0, -size.y / 2.0), origin, knockback_strength)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		velocity.y += gravity * delta
	move_and_slide()


func _draw() -> void:
	var w := size.x / 2.0
	var h := size.y
	var outline := PackedVector2Array([
		Vector2(-w, 0), Vector2(-w, -h * 0.55), Vector2(-w * 0.6, -h * 0.9), Vector2(0, -h),
		Vector2(w * 0.65, -h * 0.85), Vector2(w, -h * 0.45), Vector2(w, 0),
	])
	draw_colored_polygon(outline, Color(0.45, 0.43, 0.5))
	outline.append(outline[0])
	draw_polyline(outline, Color(0.7, 0.68, 0.75))
	draw_line(Vector2(-w * 0.3, -h * 0.6), Vector2(w * 0.1, -h * 0.4), Color(0.32, 0.3, 0.36))
	draw_line(Vector2(w * 0.2, -h * 0.75), Vector2(w * 0.5, -h * 0.55), Color(0.32, 0.3, 0.36))
