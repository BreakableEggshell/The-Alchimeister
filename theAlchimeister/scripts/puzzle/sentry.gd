extends "res://scripts/puzzle/slime.gd"
## A lookout slime. It watches the way it faces (a pale cone, cut short by
## walls and crates), and the moment it sees the knight it raises the alarm:
## a "!" over its head, and every gate in `doors` slams shut. They stay shut
## while it can still see him, and for CALM_TIME after. It can't see a
## translucent knight, or anything at all while frozen or dazed. A patrolling
## lookout looks where it's going; with `turn_every`, a standing one looks the
## other way every so many seconds. Touching it is as deadly as any slime.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Seconds the alarm lasts after it last saw the knight.
const CALM_TIME := 2.0
## Where it looks from, relative to its feet.
const EYE := Vector2(0, -6)
## Rays making up the drawn cone.
const RAYS := 9
const CONE_COLOR := Color(1.0, 0.95, 0.55, 0.13)
const ALARM_CONE_COLOR := Color(1.0, 0.3, 0.3, 0.2)
const ALARM_COLOR := Color(1.0, 0.25, 0.25)
## Where on the knight it looks for him (from his feet): middle, head, feet.
const KNIGHT_POINTS: Array[Vector2] = [Vector2(0, -14), Vector2(0, -25), Vector2(0, -3)]

## Gates it slams shut when it sees the knight.
@export var doors: Array[Gate] = []
@export var view_range := 140.0
## Half the cone's width, in degrees.
@export var view_angle := 24.0
## How far below straight ahead it looks, in degrees.
@export var look_down := 0.0
## Seconds between turning to look the other way (standing lookouts). 0 never.
@export var turn_every := 0.0

var _alarm_left := 0.0
var _turn_clock := 0.0
## The cone's outline in local coordinates, from the eye.
var _cone := PackedVector2Array()


func _ready() -> void:
	super()
	for door in doors:
		door.add_watcher(self)


func is_alarmed() -> bool:
	return _alarm_left > 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if _dead:
		_set_alarm(false)
		return
	if turn_every > 0.0 and movement == Movement.STAY and not is_frozen() and not is_stunned():
		_turn_clock += delta
		if _turn_clock >= turn_every:
			_turn_clock = 0.0
			_direction = -_direction
	if _sees_knight():
		if not is_alarmed():
			var knight := _knight()
			knight.float_text("[SPOTTED!]", ALARM_COLOR)
		_alarm_left = CALM_TIME
	else:
		_alarm_left = maxf(_alarm_left - delta, 0.0)
	_set_alarm(is_alarmed())
	_update_cone()


func _set_alarm(on: bool) -> void:
	for door in doors:
		if is_instance_valid(door):
			door.set_alarm(self, on)


func _knight() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


## The way it's looking.
func _facing() -> Vector2:
	return Vector2(_direction, 0).rotated(deg_to_rad(look_down) * _direction)


func _can_see() -> bool:
	return not _dead and not is_frozen() and not is_stunned()


func _sees_knight() -> bool:
	if not _can_see():
		return false
	var knight := _knight()
	if not knight or knight._dead or knight.is_translucent():
		return false
	var eye := global_position + EYE
	var facing := _facing()
	for offset in KNIGHT_POINTS:
		var to: Vector2 = knight.global_position + offset - eye
		if to.length() > view_range or absf(facing.angle_to(to)) > deg_to_rad(view_angle):
			continue
		if _hit(eye, eye + to) == null:
			return true
	return false


## The cone, cut short by whatever it can't see through.
func _update_cone() -> void:
	_cone.clear()
	if not _can_see():
		return
	var eye := global_position + EYE
	_cone.append(EYE)
	var facing := _facing()
	for i in RAYS:
		var angle := deg_to_rad(lerpf(-view_angle, view_angle, float(i) / (RAYS - 1)))
		var end := eye + facing.rotated(angle) * view_range
		var query := PhysicsRayQueryParameters2D.create(eye, end, PotionData.LAYER_WORLD | PotionData.LAYER_PROPS, [get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		_cone.append(to_local(hit.position if hit else end))


func _draw() -> void:
	if _cone.size() >= 3:
		draw_colored_polygon(_cone, ALARM_CONE_COLOR if is_alarmed() else CONE_COLOR)
	super()
	if is_alarmed() and not _dead:
		var at := Vector2(-2, -20)
		draw_string_outline(FONT, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.05, 0.08))
		draw_string(FONT, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ALARM_COLOR)
