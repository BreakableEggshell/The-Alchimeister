extends "res://scripts/platformer/platformer_knight.gd"
## The platformer knight plus what the puzzle stages need: potion effects on
## the player (knockback and translucent; fire and freeze don't affect them),
## pushing crates, floating text above the head, and dying when caught.

signal died

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

## Speed the knight pushes crates at, in pixels per second.
@export var push_speed := 45.0

var _translucent_left := 0.0
var _dead := false
var _talking := false
var _float_label: Label
var _float_tween: Tween
var _chat_icon: Node2D


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if _dead:
		return
	match kind:
		PotionData.KNOCKBACK:
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -8), origin)
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME


func is_translucent() -> bool:
	return _translucent_left > 0.0


## Washes off potion effects (the cleansing portal).
func clear_potion_effects() -> void:
	if is_translucent():
		_translucent_left = 0.0
		float_text("[EFFECTS CLEARED]", Color(0.55, 0.85, 1.0))


func die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	_sprite.frame = 58  # Death row of the sheet.
	died.emit()


## Shows `text` just above the head; it drifts up and fades out.
func float_text(text: String, color: Color) -> void:
	if not _float_label:
		_float_label = Label.new()
		_float_label.add_theme_font_override("font", FONT)
		_float_label.add_theme_font_size_override("font_size", 8)
		_float_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
		_float_label.add_theme_constant_override("outline_size", 3)
		_float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_float_label.size = Vector2(120, 10)
		_float_label.z_index = 10
		add_child(_float_label)
	_float_label.text = text
	_float_label.add_theme_color_override("font_color", color)
	_float_label.position = Vector2(-60, -34)
	_float_label.modulate.a = 1.0
	_float_label.show()
	if _float_tween:
		_float_tween.kill()
	_float_tween = create_tween().set_parallel()
	_float_tween.tween_property(_float_label, "position:y", -44.0, 1.0).set_ease(Tween.EASE_OUT)
	_float_tween.tween_property(_float_label, "modulate:a", 0.0, 0.5).set_delay(0.5)


## Holds the knight still with a speech bubble over its head (during a chat).
func set_talking(talking: bool) -> void:
	_talking = talking
	if not _chat_icon:
		_chat_icon = Node2D.new()
		_chat_icon.position = Vector2(0, -26)
		_chat_icon.z_index = 10
		_chat_icon.draw.connect(_draw_chat_icon)
		add_child(_chat_icon)
	_chat_icon.visible = talking


func _draw_chat_icon() -> void:
	var bubble := Color.WHITE
	_chat_icon.draw_rect(Rect2(-7, -9, 14, 8), bubble)
	_chat_icon.draw_colored_polygon(PackedVector2Array([Vector2(-3, -1), Vector2(1, -1), Vector2(-3, 2)]), bubble)
	for x in [-4.0, 0.0, 4.0]:
		_chat_icon.draw_rect(Rect2(x - 1, -6, 2, 2), Color(0.1, 0.09, 0.14))


func _physics_process(delta: float) -> void:
	if _talking:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
		_animate(delta, 0.0)
		return
	super(delta)
	_push_crates()


## Pushes anything with a push() method that the knight walked into sideways.
func _push_crates() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		var side := -collision.get_normal().x
		if body and body.has_method("push") and absf(side) > 0.7 and signf(Input.get_axis("move_left", "move_right")) == signf(side):
			body.push(side * push_speed)
			# Keep leaning into the crate so contact isn't lost next frame.
			velocity.x = side * push_speed


func _process(delta: float) -> void:
	if _dead:
		return
	_translucent_left = maxf(_translucent_left - delta, 0.0)
	var alpha := 1.0
	if is_translucent():
		# Blink during the last second as a warning.
		var warning := _translucent_left < 1.0 and int(_translucent_left * 10.0) % 2 == 0
		alpha = 0.6 if warning else 0.35
	_sprite.modulate.a = alpha
