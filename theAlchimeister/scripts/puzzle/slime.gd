extends CharacterBody2D
## Patrolling slime. On the floor it walks back and forth, turning at walls,
## ledges and the edge of its patrol range; with `on_wall` it crawls up and
## down a wall instead. Touching it kills the player unless the slime is
## frozen, stunned or dead, or either of them is translucent.
## Fire: burns, keeps patrolling, dies after a while and drops its items.
## Freeze: stops dead and becomes harmless for a while.
## Knockback: flung away, dazed (still and harmless) for a moment, and drops
## its items. Wall slimes ignore knockback.
## Translucent: the player can pass through it.
## Death: dies at once and drops its items, wall slimes too.
## A slime drops its items only once, on whichever happens first.
## Stunned slimes are faded. A stun blinks for its whole length; a freeze or
## translucency blinks for its last WARN_TIME seconds. The blinking starts
## slow and speeds up until the effect wears off.

const FRAME_COUNT := 4
const STUNNED_ALPHA := 0.6
const TRANSLUCENT_ALPHA := 0.35
## Seconds before a freeze or translucency ends that it starts blinking.
const WARN_TIME := 3.0
## Blinks per second when the blinking starts, and just before the effect ends.
const BLINK_SLOW := 1.5
const BLINK_FAST := 6.0

## Walking speed. 0 makes an unmoving monster.
@export var speed := 30.0
## How far either side of its start it may wander (up and down on a wall).
## 0 means no limit.
@export var patrol_distance := 0.0
@export_enum("Back:-1", "Forward:1") var start_direction := 1
## Ingredient it drops. Empty for none.
@export var drop: StringName = &""
@export var drop_count := 1
## Crawls along a wall instead of the floor. Place it touching the wall face.
@export var on_wall := false
## Which side of the slime the wall is on.
@export_enum("Left:-1", "Right:1") var wall_side := 1
## Size of the box potions shatter on, centred over the slime. Bigger than its
## body so throws that clip the sprite count as hits.
@export var potion_hitbox_size := Vector2(20, 18)
@export var gravity := 800.0
@export var friction := 600.0
@export var anim_fps := 6.0

var _direction := 1
var _start := Vector2.ZERO
var _burn_left := 0.0
var _freeze_left := 0.0
var _translucent_left := 0.0
var _stun_left := 0.0
var _dead := false
var _dropped := false
var _anim_clock := 0.0
var _blink_phase := 0.0
## False during the "off" half of a warning blink.
var _blink_on := true
var _flames: CPUParticles2D
var _potion_hitbox: Area2D

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemies")
	_direction = start_direction
	_start = global_position
	if on_wall:
		# Rotate so the slime's feet face the wall.
		rotation = -PI / 2.0 * wall_side
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_flames = _make_flames()
	add_child(_flames)
	_potion_hitbox = _make_potion_hitbox()
	add_child(_potion_hitbox)


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
			if on_wall:
				return
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -5), origin)
			_stun_left = PotionData.STUN_TIME
			_drop_items()
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME
		PotionData.DEATH:
			_die()


func is_translucent() -> bool:
	return _translucent_left > 0.0


## Washes off every potion effect (the cleansing portal).
func clear_potion_effects() -> void:
	_burn_left = 0.0
	_freeze_left = 0.0
	_translucent_left = 0.0
	_stun_left = 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


func is_burning() -> bool:
	return _burn_left > 0.0


func is_stunned() -> bool:
	return _stun_left > 0.0


## Whether any potion effect is still running on it.
func has_effect() -> bool:
	return not _dead and (is_frozen() or is_burning() or is_stunned() or is_translucent())


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
	_stun_left = maxf(_stun_left - delta, 0.0)

	var held := is_frozen() or is_stunned()
	if on_wall:
		if held:
			velocity = Vector2.ZERO
		else:
			if patrol_distance > 0.0 and (global_position.y - _start.y) * _direction >= patrol_distance:
				_direction = -_direction
			velocity = Vector2(0, _direction * speed)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		if held:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		else:
			if _should_turn():
				_direction = -_direction
			velocity.x = _direction * speed
	move_and_slide()
	_hurt_overlapping_player()
	_animate(delta)


func _should_turn() -> bool:
	if is_on_wall() and get_wall_normal().x * _direction < 0.0:
		return true
	if patrol_distance > 0.0 and (global_position.x - _start.x) * _direction >= patrol_distance:
		return true
	if is_on_floor():
		var ahead := global_position + Vector2(_direction * 8.0, -2.0)
		var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 8), PotionData.LAYER_WORLD | PotionData.LAYER_PROPS, [get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _hurt_overlapping_player() -> void:
	if is_frozen() or is_stunned() or is_translucent():
		return
	for body in _hurtbox.get_overlapping_bodies():
		if body.has_method("die") and not body.is_translucent():
			body.die()


func _animate(delta: float) -> void:
	_anim_clock += delta
	if not is_frozen():
		_sprite.frame = int(_anim_clock * anim_fps) % FRAME_COUNT
	_sprite.flip_h = _direction < 0
	_update_blink(delta)
	var tint := Color.WHITE
	if _shows(_freeze_left):
		tint = Color(0.6, 0.85, 1.4)
	elif is_burning():
		tint = Color(1.5, 0.75, 0.45) if int(_anim_clock * 12.0) % 2 == 0 else Color(1.3, 0.5, 0.3)
	elif _shows(_stun_left, PotionData.STUN_TIME):
		tint = Color(1.15, 1.1, 0.75)
	tint.a = 1.0
	if _shows(_stun_left, PotionData.STUN_TIME):
		tint.a = STUNNED_ALPHA
	if _shows(_translucent_left):
		tint.a = TRANSLUCENT_ALPHA
	_sprite.modulate = tint
	_flames.emitting = is_burning()
	queue_redraw()


## Advances the warning blink. Its speed follows whichever blinking effect
## is closest to wearing off.
func _update_blink(delta: float) -> void:
	var blinking := false
	# 0 when the blinking starts, 1 as the effect ends.
	var urgency := 0.0
	for effect in [[_freeze_left, WARN_TIME], [_stun_left, PotionData.STUN_TIME], [_translucent_left, WARN_TIME]]:
		var left: float = effect[0]
		var warn: float = effect[1]
		if left > 0.0 and left <= warn:
			blinking = true
			urgency = maxf(urgency, 1.0 - left / warn)
	if not blinking:
		_blink_phase = 0.0
		_blink_on = true
		return
	_blink_phase += delta * lerpf(BLINK_SLOW, BLINK_FAST, urgency)
	_blink_on = fmod(_blink_phase, 1.0) < 0.5


## Whether an effect with `left` seconds to go, which blinks for its last
## `warn` seconds, should look applied right now.
func _shows(left: float, warn := WARN_TIME) -> bool:
	return left > 0.0 and (left > warn or _blink_on)


func _draw() -> void:
	if _dead:
		return
	if _shows(_freeze_left):
		var ice := Rect2(-9, -14, 18, 14)
		draw_rect(ice, Color(0.6, 0.9, 1.0, 0.3))
		draw_rect(ice, Color(0.8, 0.95, 1.0, 0.8), false)
	if _shows(_stun_left, PotionData.STUN_TIME):
		# Dizzy stars circling above the head.
		for i in 3:
			var angle := _anim_clock * 5.0 + TAU * i / 3.0
			var star := Vector2(cos(angle) * 7.0, -18.0 + sin(angle) * 2.5)
			draw_rect(Rect2(star - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.9, 0.3))


func _drop_items() -> void:
	if _dropped or drop == &"":
		return
	_dropped = true
	for i in drop_count:
		var pickup := Pickup.new()
		pickup.kind = drop
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector2((i - (drop_count - 1) / 2.0) * 12.0, -8)


func _die() -> void:
	_dead = true
	_flames.emitting = false
	collision_layer = 0
	_potion_hitbox.collision_layer = 0
	queue_redraw()
	_drop_items()
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.4)
	fade.tween_callback(queue_free)


func _make_potion_hitbox() -> Area2D:
	var area := Area2D.new()
	area.collision_layer = PotionData.LAYER_POTION_TARGETS
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = potion_hitbox_size
	shape.shape = rect
	shape.position = Vector2(0, -potion_hitbox_size.y / 2.0)
	area.add_child(shape)
	return area


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
