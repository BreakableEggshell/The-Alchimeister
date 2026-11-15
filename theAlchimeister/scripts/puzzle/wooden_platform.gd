@tool
class_name WoodenPlatform
extends Solid
## A wooden plank that a translucent potion turns ghostly for a while:
## everything on it (a rock, the knight) falls straight through. It blinks
## before it turns solid again, and waits until nothing is inside it.
## A blast (TNT, dynamite) splinters it for good.

## Fade while translucent, like translucent monsters.
const TRANSLUCENT_ALPHA := 0.35
## Seconds before turning solid again that it starts blinking.
const WARN_TIME := 1.5

var _translucent_left := 0.0
var _shape: CollisionPolygon2D
## Blown apart (see blast).
var _broken := false


func _init() -> void:
	one_way = true


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# A prop, so potions splash it.
	collision_layer = PotionData.LAYER_PROPS
	# Shape queries skip one-way shapes, so blasts look planks up by group.
	add_to_group("planks")
	for child in get_children():
		if child is CollisionPolygon2D:
			_shape = child


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.TRANSLUCENT:
		_translucent_left = PotionData.TRANSLUCENT_TIME
		_shape.set_deferred("disabled", true)


func is_translucent() -> bool:
	return _translucent_left > 0.0


## Caught in a blast (TNT or dynamite): splinters, gone for good.
func blast() -> void:
	if is_queued_for_deletion() or _broken:
		return
	_broken = true
	_shape.set_deferred("disabled", true)
	var splinters := CPUParticles2D.new()
	splinters.one_shot = true
	splinters.explosiveness = 0.9
	splinters.amount = 20
	splinters.lifetime = 0.7
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	splinters.position = bounds.get_center()
	splinters.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splinters.emission_rect_extents = bounds.size / 2.0
	splinters.direction = Vector2.UP
	splinters.spread = 80.0
	splinters.initial_velocity_min = 40.0
	splinters.initial_velocity_max = 110.0
	splinters.gravity = Vector2(0, 500)
	splinters.scale_amount_min = 1.0
	splinters.scale_amount_max = 2.0
	splinters.color = Color(0.6, 0.42, 0.26)
	add_child(splinters)
	splinters.emitting = true
	# The plank is gone at once; only the splinters (children) still show.
	self_modulate.a = 0.0
	await get_tree().create_timer(splinters.lifetime + 0.1).timeout
	queue_free()


func is_broken() -> bool:
	return _broken


## The plank's box on the stage, for blasts to check against.
func global_bounds() -> Rect2:
	var bounds := Rect2(to_global(points[0]), Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(to_global(point))
	return bounds


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _broken or not _shape.disabled:
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
