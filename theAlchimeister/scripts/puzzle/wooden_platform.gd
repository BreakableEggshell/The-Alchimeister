@tool
class_name WoodenPlatform
extends Solid
## A wooden plank that a translucent potion turns ghostly for a while:
## everything on it (a rock, the knight) falls straight through. It blinks
## before it turns solid again, and waits until nothing is inside it.

## Fade while translucent, like translucent monsters.
const TRANSLUCENT_ALPHA := 0.35
## Seconds before turning solid again that it starts blinking.
const WARN_TIME := 1.5

var _translucent_left := 0.0
var _shape: CollisionPolygon2D


func _init() -> void:
	one_way = true


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# A prop, so potions splash it.
	collision_layer = PotionData.LAYER_PROPS
	for child in get_children():
		if child is CollisionPolygon2D:
			_shape = child


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.TRANSLUCENT:
		_translucent_left = PotionData.TRANSLUCENT_TIME
		_shape.set_deferred("disabled", true)


func is_translucent() -> bool:
	return _translucent_left > 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _shape.disabled:
		return
	_translucent_left = maxf(_translucent_left - delta, 0.0)
	if _translucent_left == 0.0 and not _overlaps_something():
		_shape.disabled = false
	_update_look()


func _update_look() -> void:
	var alpha := 1.0
	if _shape.disabled:
		alpha = TRANSLUCENT_ALPHA
		# Blink before turning solid, faster near the end.
		if _translucent_left < WARN_TIME:
			var rate := 6.0 if _translucent_left > WARN_TIME / 2.0 else 12.0
			if int(_translucent_left * rate) % 2 == 0:
				alpha = 0.75
	modulate.a = alpha


## Anything (rock, knight, monster) still inside the plank.
func _overlaps_something() -> bool:
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = PotionData.SPLASH_MASK
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
