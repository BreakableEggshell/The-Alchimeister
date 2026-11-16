@tool
class_name Rope
extends Area2D
## A rope that holds a gate shut (see Gate.ropes). Fire burns it: a fire
## splash, anything burning that touches it, or a blast. The flames climb it
## for BURN_TIME, then it snaps and the gates it held open.
## Origin is the top, where it's tied; it hangs `length` pixels down to a peg.

## It burnt through.
signal snapped

@export var length := 30.0:
	set(value):
		length = maxf(value, 4.0)
		queue_redraw()

## Seconds from catching fire to snapping.
const BURN_TIME := 0.5
const HEMP := Color(0.78, 0.64, 0.42)
const HEMP_DARK := Color(0.55, 0.42, 0.26)
const PEG := Color(0.45, 0.43, 0.5)
const CHAR := Color(0.2, 0.17, 0.16)
## How wide it is for potions and burning things to touch.
const REACH := 6.0

## Below 0 until it catches; then seconds burning.
var _burning := -1.0
var _snapped := false
var _flames: CPUParticles2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("ropes")
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(REACH, length)
	shape.shape = rect
	shape.position = Vector2(0, length / 2.0)
	add_child(shape)
	_flames = CPUParticles2D.new()
	_flames.emitting = false
	_flames.amount = 14
	_flames.lifetime = 0.4
	_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flames.emission_rect_extents = Vector2(1.5, 3)
	_flames.direction = Vector2.UP
	_flames.spread = 20.0
	_flames.gravity = Vector2(0, -60)
	_flames.initial_velocity_min = 10.0
	_flames.initial_velocity_max = 25.0
	_flames.scale_amount_min = 1.0
	_flames.scale_amount_max = 2.0
	_flames.color_ramp = Gradient.new()
	_flames.color_ramp.set_color(0, Color(1.0, 0.85, 0.4))
	_flames.color_ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	add_child(_flames)


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.FIRE:
		burn()


## Caught in a blast.
func blast() -> void:
	burn()


func burn() -> void:
	if _burning < 0.0 and not _snapped:
		_burning = 0.0
		_flames.emitting = true
		add_to_group("lit_fuses")


func is_snapped() -> bool:
	return _snapped


func is_burning() -> bool:
	return _burning >= 0.0 and not _snapped


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _snapped:
		return
	if _burning < 0.0:
		for body in get_overlapping_bodies():
			if body.has_method("is_burning") and body.is_burning():
				burn()
		return
	_burning += delta
	# The flames climb from the peg to the knot.
	_flames.position = Vector2(0, length * (1.0 - _burning / BURN_TIME))
	queue_redraw()
	if _burning >= BURN_TIME:
		_snap()


func _snap() -> void:
	_snapped = true
	_flames.emitting = false
	remove_from_group("lit_fuses")
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	queue_redraw()
	snapped.emit()


func _draw() -> void:
	# The knot it's tied from, and the peg at the bottom.
	draw_rect(Rect2(-2, -1, 4, 3), HEMP_DARK)
	draw_rect(Rect2(-3, length - 1, 6, 3), PEG)
	if _snapped:
		draw_rect(Rect2(-1, 1, 2, 2), CHAR)
		draw_rect(Rect2(-1, length - 3, 2, 2), CHAR)
		return
	# Burnt from the bottom up while it burns.
	var burnt := 0.0 if _burning < 0.0 else length * clampf(_burning / BURN_TIME, 0.0, 1.0)
	var bottom := length - burnt
	draw_rect(Rect2(-1, 1, 2, maxf(bottom - 1.0, 0.0)), HEMP)
	# Its twist: a dark notch every few pixels, alternating sides.
	var y := 3
	while y < bottom - 1.0:
		draw_rect(Rect2(-1 if (y / 3) % 2 == 0 else 0, y, 1, 1), HEMP_DARK)
		y += 3
	if burnt > 0.0:
		draw_rect(Rect2(-1, bottom, 2, burnt - 1.0), CHAR)
