extends "res://scripts/platformer/platformer_knight.gd"
## The platformer knight plus what the puzzle stages need: potion effects on
## the player, pushing crates, floating text above the head, and dying when
## caught.
## Fire: burns, and dies after PotionData.BURN_TIME unless washed off.
## Freeze: can't move, jump or throw for PotionData.PLAYER_FREEZE_TIME.
## Knockback: flung away. Translucent: monsters pass through. Death: dies.
## Fire and freeze cancel each other; the cleansing portal clears them all.

## `cause` is one of GameOver's causes; it picks the game over message.
signal died(cause: StringName)

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")

## Speed the knight pushes crates at, in pixels per second.
@export var push_speed := 45.0

var _translucent_left := 0.0
var _burn_left := 0.0
var _freeze_left := 0.0
var _flames: CPUParticles2D
var _dead := false
var _talking := false
var _float_label: Label
var _float_tween: Tween
var _chat_icon: Node2D
var _ice: Node2D


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if _dead:
		return
	match kind:
		PotionData.KNOCKBACK:
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -8), origin)
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME
		PotionData.FIRE:
			_freeze_left = 0.0
			_burn_left = PotionData.BURN_TIME
			float_text("[BURNING!]", PotionData.color_of(PotionData.FIRE))
		PotionData.FREEZE:
			_burn_left = 0.0
			_freeze_left = PotionData.PLAYER_FREEZE_TIME
			velocity.x = 0.0
			float_text("[FROZEN]", PotionData.color_of(PotionData.FREEZE))
		PotionData.DEATH:
			die(GameOver.DEATH_POTION)


func is_translucent() -> bool:
	return _translucent_left > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


## Washes off potion effects (the cleansing portal).
func clear_potion_effects() -> void:
	if is_translucent() or is_burning() or is_frozen():
		_translucent_left = 0.0
		_burn_left = 0.0
		_freeze_left = 0.0
		float_text("[EFFECTS CLEARED]", Color(0.55, 0.85, 1.0))


func die(cause: StringName = GameOver.CAUGHT) -> void:
	if _dead:
		return
	_dead = true
	if _flames:
		_flames.emitting = false
	set_physics_process(false)
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	_sprite.frame = 58  # Death row of the sheet.
	died.emit(cause)


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
	if is_burning():
		_burn_left -= delta
		if _burn_left <= 0.0:
			_burn_left = 0.0
			die(GameOver.BURNED)
			return
	if is_frozen():
		# Stuck in place: no running or jumping, but still falls.
		_freeze_left = maxf(_freeze_left - delta, 0.0)
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
		return
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
	if not _flames:
		_flames = _make_flames()
		add_child(_flames)
	_flames.emitting = is_burning()
	if not _ice:
		# An ice cube in front of the knight while frozen, like frozen monsters.
		_ice = Node2D.new()
		_ice.draw.connect(func() -> void:
			var cube := Rect2(-8, -22, 16, 22)
			_ice.draw_rect(cube, Color(0.6, 0.9, 1.0, 0.3))
			_ice.draw_rect(cube, Color(0.8, 0.95, 1.0, 0.8), false))
		add_child(_ice)
	_ice.visible = is_frozen()
	var tint := Color.WHITE
	if is_frozen():
		tint = Color(0.6, 0.85, 1.0)
	elif is_burning():
		tint = Color(1.0, 0.65, 0.45)
	_sprite.modulate = tint
	var alpha := 1.0
	if is_translucent():
		# Blink during the last second as a warning.
		var warning := _translucent_left < 1.0 and int(_translucent_left * 10.0) % 2 == 0
		alpha = 0.6 if warning else 0.35
	_sprite.modulate.a = alpha


func _make_flames() -> CPUParticles2D:
	var flames := CPUParticles2D.new()
	flames.emitting = false
	flames.amount = 12
	flames.lifetime = 0.45
	flames.position = Vector2(0, -9)
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flames.emission_rect_extents = Vector2(5, 7)
	flames.direction = Vector2.UP
	flames.spread = 20.0
	flames.gravity = Vector2(0, -60)
	flames.initial_velocity_min = 8.0
	flames.initial_velocity_max = 18.0
	flames.scale_amount_min = 1.0
	flames.scale_amount_max = 2.0
	flames.color = PotionData.color_of(PotionData.FIRE)
	return flames
