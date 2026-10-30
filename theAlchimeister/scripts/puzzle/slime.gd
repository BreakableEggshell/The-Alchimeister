extends CharacterBody2D
## Patrolling slime. Walks back and forth, turning at walls, ledges and the
## edge of its patrol range. Touching it kills the player unless the slime is
## frozen or dead, or either of them is translucent.
## Fire: burns, panics (moves faster), dies after a while and drops `drop`.
## Freeze: stops dead and becomes harmless for a while.
## Knockback: flung away from the splash. Translucent: player can pass through.

const FRAME_COUNT := 4

@export var speed := 30.0
## How far either side of its start it may wander. 0 means no limit.
@export var patrol_distance := 0.0
@export_enum("Left:-1", "Right:1") var start_direction := 1
## Ingredient dropped when it dies. Empty for none.
@export var drop: StringName = &""
@export var gravity := 800.0
@export var friction := 600.0
@export var anim_fps := 6.0

var _direction := 1
var _start_x := 0.0
var _burn_left := 0.0
var _freeze_left := 0.0
var _translucent_left := 0.0
var _stagger_left := 0.0
var _dead := false
var _anim_clock := 0.0
var _flames: CPUParticles2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	_direction = start_direction
	_start_x = global_position.x
	_flames = _make_flames()
	add_child(_flames)


func apply_potion(kind: StringName, origin: Vector2) -> void:
	if _dead:
		return
	match kind:
		PotionData.FIRE:
			_freeze_left = 0.0
			_burn_left = PotionData.BURN_TIME
		PotionData.FREEZE:
			_burn_left = 0.0
			_freeze_left = PotionData.FREEZE_TIME
		PotionData.KNOCKBACK:
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -5), origin)
			_stagger_left = 0.4
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME


func is_translucent() -> bool:
	return _translucent_left > 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if is_burning():
		_burn_left -= delta
		if _burn_left <= 0.0:
			_die()
			return
	_freeze_left = maxf(_freeze_left - delta, 0.0)
	_translucent_left = maxf(_translucent_left - delta, 0.0)
	_stagger_left = maxf(_stagger_left - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta
	if is_frozen() or _stagger_left > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		if _should_turn():
			_direction = -_direction
		velocity.x = _direction * speed * (1.8 if is_burning() else 1.0)
	move_and_slide()
	_hurt_overlapping_player()
	_animate(delta)


func _should_turn() -> bool:
	if is_on_wall() and get_wall_normal().x * _direction < 0.0:
		return true
	if patrol_distance > 0.0 and (global_position.x - _start_x) * _direction >= patrol_distance:
		return true
	if is_on_floor():
		var ahead := global_position + Vector2(_direction * 8.0, -2.0)
		var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 8), PotionData.LAYER_WORLD | PotionData.LAYER_PROPS, [get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _hurt_overlapping_player() -> void:
	if is_frozen() or is_translucent():
		return
	for body in _hurtbox.get_overlapping_bodies():
		if body.has_method("die") and not body.is_translucent():
			body.die()


func _animate(delta: float) -> void:
	if not is_frozen():
		_anim_clock += delta
		_sprite.frame = int(_anim_clock * anim_fps) % FRAME_COUNT
	_sprite.flip_h = _direction < 0
	var tint := Color.WHITE
	if is_frozen():
		tint = Color(0.6, 0.85, 1.4)
	elif is_burning():
		tint = Color(1.5, 0.75, 0.45) if int(_anim_clock * 12.0) % 2 == 0 else Color(1.3, 0.5, 0.3)
	tint.a = 0.35 if is_translucent() else 1.0
	_sprite.modulate = tint
	_flames.emitting = is_burning()
	queue_redraw()


func _draw() -> void:
	if is_frozen() and not _dead:
		var ice := Rect2(-9, -14, 18, 14)
		draw_rect(ice, Color(0.6, 0.9, 1.0, 0.3))
		draw_rect(ice, Color(0.8, 0.95, 1.0, 0.8), false)


func _die() -> void:
	_dead = true
	_flames.emitting = false
	collision_layer = 0
	queue_redraw()
	if drop != &"":
		var pickup := Pickup.new()
		pickup.kind = drop
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector2(0, -6)
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.4)
	fade.tween_callback(queue_free)


func _make_flames() -> CPUParticles2D:
	var flames := CPUParticles2D.new()
	flames.emitting = false
	flames.amount = 10
	flames.lifetime = 0.45
	flames.position = Vector2(0, -6)
	flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flames.emission_rect_extents = Vector2(6, 3)
	flames.direction = Vector2.UP
	flames.spread = 20.0
	flames.gravity = Vector2(0, -60)
	flames.initial_velocity_min = 8.0
	flames.initial_velocity_max = 18.0
	flames.scale_amount_min = 1.0
	flames.scale_amount_max = 2.0
	flames.color = PotionData.color_of(PotionData.FIRE)
	return flames
