@tool
class_name IcePillar
extends StaticBody2D
## A pillar of ice. Solid like a wall until fire melts it: a fire potion's
## splash, anything burning that walks into it (the knight or a slime), or a
## dynamite blast. It melts from the top down in MELT_TIME seconds, letting
## things through a little before it's all gone, and doesn't come back.
## Origin is the top-left corner.

@export var size := Vector2(16, 36):
	set(value):
		size = value
		queue_redraw()

const MELT_TIME := 0.6
## How far through melting it stops blocking.
const OPEN_AT := 0.6
const ICE := Color(0.62, 0.88, 1.0, 0.85)
const SHINE := Color(0.9, 0.98, 1.0, 0.9)
const CRACK := Color(0.38, 0.62, 0.8, 0.9)
const PUDDLE := Color(0.45, 0.75, 1.0, 0.7)

## 0 solid, 1 gone.
var _melt := 0.0
var _melting := false
var _shape: CollisionShape2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# A prop, so potion splashes reach it.
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.FIRE:
		melt()


## Caught in a dynamite blast.
func blast() -> void:
	melt()


func is_melting() -> bool:
	return _melting


func melt() -> void:
	if _melting:
		return
	_melting = true
	var drips := CPUParticles2D.new()
	drips.amount = 14
	drips.lifetime = 0.5
	drips.position = Vector2(size.x / 2.0, size.y / 2.0)
	drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drips.emission_rect_extents = size / 2.0
	drips.direction = Vector2.DOWN
	drips.spread = 15.0
	drips.gravity = Vector2(0, 300)
	drips.initial_velocity_min = 10.0
	drips.initial_velocity_max = 30.0
	drips.color = SHINE
	add_child(drips)
	var tween := create_tween()
	tween.tween_method(_set_melt, 0.0, 1.0, MELT_TIME)
	tween.tween_callback(func() -> void: drips.emitting = false)
	tween.tween_interval(drips.lifetime)
	tween.tween_callback(queue_free)


func _set_melt(amount: float) -> void:
	_melt = amount
	if amount >= OPEN_AT and not _shape.disabled:
		_shape.set_deferred("disabled", true)
	queue_redraw()


func _draw() -> void:
	var height := size.y * (1.0 - _melt)
	if height > 0.5:
		var body := Rect2(0, size.y - height, size.x, height)
		draw_rect(body, ICE)
		# Shine streaks and a crack or two, cut off where it has melted.
		for streak in [[3.0, 0.1, 0.55], [size.x - 5.0, 0.35, 0.9]]:
			var top := maxf(size.y * streak[1], body.position.y + 1.0)
			var bottom: float = size.y * streak[2]
			if bottom > top:
				draw_line(Vector2(streak[0], top), Vector2(streak[0], bottom), SHINE, 1.0)
		for crack in [[0.3, 0.45], [0.65, 0.75]]:
			var y: float = size.y * crack[0]
			if y > body.position.y + 2.0:
				draw_polyline(PackedVector2Array([Vector2(size.x * 0.25, y), Vector2(size.x * 0.5, y + 3), Vector2(size.x * 0.7, size.y * crack[1])]), CRACK)
		# White outline marks it as something the player can interact with.
		draw_rect(body.grow(-0.5), Color.WHITE, false)
	if _melt > 0.0:
		# A puddle spreading where it stood.
		var spread := size.x * (0.6 + 0.6 * _melt)
		draw_rect(Rect2((size.x - spread) / 2.0, size.y - 2.0, spread, 2.0), Color(PUDDLE, PUDDLE.a * (1.0 - _melt * 0.5)))
