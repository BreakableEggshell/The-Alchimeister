extends CharacterBody2D
## A slime. It either stays in place or patrols: left and right on the floor,
## or up and down a wall with `on_wall`, turning back whenever it hits something
## or reaches a ledge (it stands still if it's blocked both ways). To keep one
## in an area, put walls or ledges around it. Touching it kills the player unless the slime is
## frozen, stunned or dead, or either of them is translucent.
## Fire: burns, patrols faster (FIRE_SPEED_BOOST), dies after a while and
## drops its items. Slimes still carrying drops sparkle.
## Freeze: stops dead, becomes harmless for a while, and drops its items.
## Knockback: flung away, dazed (still and harmless) for a moment, and drops
## its items. Wall slimes ignore knockback.
## Translucent: the player can pass through it.
## Death: dies at once and drops its items, wall slimes too.
## A slime drops its items only once, on whichever happens first.
## A flying slime (`flying`, see flyer.tscn) patrols back and forth in the air
## at the height it starts at, turning at walls (or `patrol_range` pixels
## either side of its start), out of the knight's reach. Frozen, the ice is
## too heavy to fly: it drops like a stone (counting as heavy, like anything
## frozen), and its items fall out of the sky. Once it thaws it flies back up.
## A burning slime runs straight through ice pillars, melting them.
## Stunned slimes are faded. A freeze or stun blinks slowly for its whole
## length; a translucency blinks for its last WARN_TIME seconds. In the last
## HURRY_TIME seconds the blinking speeds up. Only the slime itself blinks:
## the ice and the dizzy stars stay put until the effect ends.

const FRAME_COUNT := 4
## How far ahead of its middle it checks for walls and ledges (half its width,
## plus a little), and the height of its middle.
const LOOK_AHEAD := 8.0
const BODY_CENTER := 5.0
## The least room it needs behind it to bother turning back.
const ROOM_TO_TURN := 12.0
const STUNNED_ALPHA := 0.6
const SPARKLE_COUNT := 4
## Twinkles per second per sparkle.
const SPARKLE_RATE := 0.9
const SPARKLE_COLOR := Color(1.0, 0.95, 0.6)
const TRANSLUCENT_ALPHA := 0.35
## Seconds before a translucency ends that it starts blinking.
const WARN_TIME := 3.0
## Seconds before any effect ends that the blinking speeds up.
const HURRY_TIME := 1.5
## Blinks per second, before and after HURRY_TIME.
const BLINK_SLOW := 1.5
const BLINK_FAST := 3.5

enum Movement { STAY, PATROL }

## Flyers: how fast they climb back to their height, and their wings.
const CLIMB_SPEED := 40.0
const WING_COLOR := Color(0.32, 0.18, 0.4)
const WING_EDGE := Color(0.08, 0.05, 0.1)

@export var movement := Movement.PATROL
## Patrol speed.
@export var speed := 30.0
@export_enum("Back:-1", "Forward:1") var start_direction := 1
## Ingredient it drops. Empty for none.
@export var drop: StringName = &""
@export var drop_count := 1
## Crawls along a wall instead of the floor. Place it touching the wall face.
@export var on_wall := false
## Which side of the slime the wall is on.
@export_enum("Left:-1", "Right:1") var wall_side := 1
## Flies instead of walking (see the top of this script).
@export var flying := false
## Flyers only: how far either side of where it starts it patrols. 0 turns
## only at walls.
@export var patrol_range := 0.0
## Size of the box potions shatter on, centred over the slime. Bigger than its
## body so throws that clip the sprite count as hits.
@export var potion_hitbox_size := Vector2(20, 18)
@export var gravity := 800.0
@export var friction := 600.0
@export var anim_fps := 6.0

var _direction := 1
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
var _sparkles: Node2D
## Where it started: a flyer's patrol height and the middle of its patrol.
var _home := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	add_to_group("enemies")
	_direction = start_direction
	_home = global_position
	if on_wall:
		# Rotate so the slime's feet face the wall.
		rotation = -PI / 2.0 * wall_side
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_flames = _make_flames()
	add_child(_flames)
	# In front of the sprite, so the twinkles show over the body.
	_sparkles = Node2D.new()
	_sparkles.draw.connect(_draw_sparkles)
	add_child(_sparkles)
	_potion_hitbox = _make_potion_hitbox()
	add_child(_potion_hitbox)


## `power` scales knockback with how hard the potion was thrown.
func apply_potion(kind: StringName, origin: Vector2, power := 1.0) -> void:
	if _dead:
		return
	match kind:
		PotionData.FIRE:
			_freeze_left = 0.0
			_burn_left = PotionData.BURN_TIME
		PotionData.FREEZE:
			_burn_left = 0.0
			_freeze_left = PotionData.FREEZE_TIME
			_drop_items()
		PotionData.KNOCKBACK:
			if on_wall:
				return
			velocity = PotionData.knockback_velocity(global_position + Vector2(0, -5), origin, power)
			_stun_left = PotionData.STUN_TIME
			_drop_items()
		PotionData.TRANSLUCENT:
			_translucent_left = PotionData.TRANSLUCENT_TIME
		PotionData.DEATH:
			_die()


func is_translucent() -> bool:
	return _translucent_left > 0.0


## Washes off every potion effect (cleansing water).
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

	var walking := movement == Movement.PATROL and not is_frozen() and not is_stunned() and _pick_direction()
	if on_wall:
		velocity = Vector2(0, _direction * _speed_now()) if walking else Vector2.ZERO
	elif flying and not is_frozen():
		_fly(delta, walking)
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		if walking:
			velocity.x = _direction * _speed_now()
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	_hurt_overlapping_player()
	_animate(delta)


func _speed_now() -> float:
	return speed * (PotionData.FIRE_SPEED_BOOST if is_burning() else 1.0)


## In the air: back to its flying height, patrolling, or (dazed) drifting to a
## stop.
func _fly(delta: float, walking: bool) -> void:
	if is_stunned():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return
	var climb := clampf((_home.y - global_position.y) * 3.0, -CLIMB_SPEED, CLIMB_SPEED)
	velocity.y = move_toward(velocity.y, climb, friction * delta)
	if walking:
		velocity.x = _direction * _speed_now()
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


## Turns back if the way ahead is blocked. False (stand still) if there's no
## room to walk back either, so it doesn't shuffle on the spot in a tight gap.
func _pick_direction() -> bool:
	if not _blocked(_direction, LOOK_AHEAD):
		return true
	if _blocked(-_direction, LOOK_AHEAD + ROOM_TO_TURN):
		return false
	_direction = -_direction
	return true


## Whether something solid is in the way in `direction` (1 or -1), or the floor
## or wall it's walking on ends there.
func _blocked(direction: int, reach: float) -> bool:
	if flying and patrol_range > 0.0 and (global_position.x - _home.x) * direction >= patrol_range:
		return true
	var along := Vector2(0, direction) if on_wall else Vector2(direction, 0)
	# Towards whatever it walks on.
	var down := Vector2(wall_side, 0) if on_wall else Vector2.DOWN
	var center := global_position - down * BODY_CENTER
	var wall := _hit(center, center + along * reach)
	if wall is IcePillar and is_burning():
		wall.melt()
	elif wall:
		return true
	if not on_wall and not is_on_floor():
		return false
	var ahead := global_position + along * reach
	return _hit(ahead - down * 2.0, ahead + down * 6.0) == null


## The first wall, floor or prop between two points, or null.
func _hit(from: Vector2, to: Vector2) -> Object:
	var query := PhysicsRayQueryParameters2D.create(from, to, PotionData.LAYER_WORLD | PotionData.LAYER_PROPS, [get_rid()])
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.collider if result else null


func _hurt_overlapping_player() -> void:
	if is_frozen() or is_stunned() or is_translucent():
		return
	for body in _hurtbox.get_overlapping_bodies():
		if body.has_method("die") and not body.is_translucent():
			body.die(GameOver.CAUGHT)


func _animate(delta: float) -> void:
	_anim_clock += delta
	if not is_frozen():
		_sprite.frame = int(_anim_clock * anim_fps) % FRAME_COUNT
	_sprite.flip_h = _direction < 0
	_update_blink(delta)
	var tint := Color.WHITE
	if _shows(_freeze_left, PotionData.FREEZE_TIME):
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
	_sparkles.visible = drop != &"" and not _dropped
	_sparkles.queue_redraw()
	queue_redraw()


## Advances the blink: slow, then fast once a blinking effect is in its last
## HURRY_TIME seconds.
func _update_blink(delta: float) -> void:
	var blinking := false
	var hurry := false
	for effect in [[_freeze_left, PotionData.FREEZE_TIME], [_stun_left, PotionData.STUN_TIME], [_translucent_left, WARN_TIME]]:
		var left: float = effect[0]
		var warn: float = effect[1]
		if left > 0.0 and left <= warn:
			blinking = true
			hurry = hurry or left <= HURRY_TIME
	if not blinking:
		_blink_phase = 0.0
		_blink_on = true
		return
	_blink_phase += delta * (BLINK_FAST if hurry else BLINK_SLOW)
	_blink_on = fmod(_blink_phase, 1.0) < 0.5


## Whether an effect with `left` seconds to go, which blinks for its last
## `warn` seconds, should look applied right now.
func _shows(left: float, warn := WARN_TIME) -> bool:
	return left > 0.0 and (left > warn or _blink_on)


func _draw() -> void:
	if _dead:
		return
	if flying and not is_frozen():
		_draw_wings()
	if is_frozen():
		var ice := Rect2(-9, -14, 18, 14)
		draw_rect(ice, Color(0.6, 0.9, 1.0, 0.3))
		draw_rect(ice, Color(0.8, 0.95, 1.0, 0.8), false)
	if is_stunned():
		# Dizzy stars circling above the head.
		for i in 3:
			var angle := _anim_clock * 5.0 + TAU * i / 3.0
			var star := Vector2(cos(angle) * 7.0, -18.0 + sin(angle) * 2.5)
			draw_rect(Rect2(star - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.9, 0.3))


## Bat wings either side, flapping (behind the sprite, which draws on top).
func _draw_wings() -> void:
	var flap := sin(_anim_clock * 16.0)
	for side in [-1.0, 1.0]:
		var root := Vector2(side * 4.0, -9.0)
		var wing := PackedVector2Array([root, root + Vector2(side * 9.0, -5.0 - flap * 4.0), root + Vector2(side * 7.0, 1.0 + flap), root + Vector2(side * 2.0, 2.0)])
		draw_colored_polygon(wing, WING_COLOR)
		wing.append(root)
		draw_polyline(wing, WING_EDGE)


## Little four-point twinkles popping in and out around a slime that still
## carries drops.
func _draw_sparkles() -> void:
	for i in SPARKLE_COUNT:
		# Each sparkle has its own spot and timing, and fades in and out.
		var phase := fmod(_anim_clock * SPARKLE_RATE + i * 0.37, 1.0)
		var glow := sin(phase * PI)
		if glow < 0.15:
			continue
		var spot := Vector2(-11.0 + fmod(i * 7.3, 22.0), -3.0 - fmod(i * 5.1, 17.0))
		var color := Color(SPARKLE_COLOR, glow)
		var arm := 1.0 + glow * 1.5
		_sparkles.draw_line(spot - Vector2(arm, 0), spot + Vector2(arm, 0), color)
		_sparkles.draw_line(spot - Vector2(0, arm), spot + Vector2(0, arm), color)


func _drop_items() -> void:
	if _dropped or drop == &"":
		return
	_dropped = true
	for i in drop_count:
		var pickup := Pickup.new()
		pickup.kind = drop
		# Out of the sky, they fall to the ground.
		pickup.falls = flying
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
