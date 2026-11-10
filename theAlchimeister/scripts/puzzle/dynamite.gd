@tool
class_name Dynamite
extends Area2D
## A bundle of dynamite. Fire lights its fuse: a fire potion's splash, or
## anything burning that touches it. While the fuse burns, a countdown shows
## over it and the room it will take with it (`blast_area`) is outlined in
## red. Then it blows up, and everything in that area is caught: the knight is
## BLOWN UP, monsters die, ice melts, cracked walls crumble (CrackedWall) and
## other dynamite goes off too. In the editor the blast area is outlined.
## Origin is the floor at its centre; blast_area is relative to it.

@export var fuse_time := 3.0
@export var blast_area := Rect2(-96, -96, 192, 96):
	set(value):
		blast_area = value
		queue_redraw()

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Seconds the flash takes to fade.
const BLAST_TIME := 0.6
## Seconds before a neighbour caught in the blast goes off too.
const CHAIN_DELAY := 0.15
const STICK := Color(0.8, 0.2, 0.2)
const STICK_DARK := Color(0.5, 0.1, 0.12)
const BAND := Color(0.85, 0.75, 0.5)
const FUSE := Color(0.35, 0.3, 0.25)
const DANGER := Color(1.0, 0.3, 0.25)
const FLASH := Color(1.0, 0.85, 0.5)
## Height of the fuse above the sticks before it burns down.
const FUSE_LENGTH := 8.0
## What a blast catches.
const BLAST_MASK := PotionData.LAYER_WORLD | PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES | PotionData.LAYER_PROPS

## Seconds left on the fuse; below 0 while unlit.
var _fuse_left := -1.0
var _exploded := false
## 1 at the blast, fading to 0.
var _flash := 0.0
var _clock := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("dynamite")
	# A prop (so potions hit and splash it), but nothing stands on it.
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.FIRE:
		light()


## Caught in another blast: goes off almost at once.
func blast() -> void:
	if _exploded:
		return
	if not is_lit() or _fuse_left > CHAIN_DELAY:
		_light_for(CHAIN_DELAY)


func is_lit() -> bool:
	return _fuse_left >= 0.0 and not _exploded


func light() -> void:
	if not is_lit() and not _exploded:
		_light_for(fuse_time)


func _light_for(seconds: float) -> void:
	_fuse_left = seconds
	add_to_group("lit_fuses")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _exploded:
		return
	_clock += delta
	if not is_lit():
		for body in get_overlapping_bodies():
			if body.has_method("is_burning") and body.is_burning():
				light()
		return
	_fuse_left -= delta
	queue_redraw()
	if _fuse_left <= 0.0:
		_explode()


func _explode() -> void:
	_exploded = true
	remove_from_group("lit_fuses")
	remove_from_group("dynamite")
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	Sfx.play(Sfx.KNOCKBACK, self, global_position)
	_catch_everything()
	_burst()
	_shake_camera()
	var fade := create_tween()
	fade.tween_method(func(t: float) -> void:
		_flash = t
		queue_redraw(), 1.0, 0.0, BLAST_TIME)
	fade.tween_interval(0.5)
	fade.tween_callback(queue_free)


func _catch_everything() -> void:
	var shape := RectangleShape2D.new()
	shape.size = blast_area.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + blast_area.get_center())
	query.collision_mask = BLAST_MASK
	query.collide_with_areas = true
	var caught := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var thing: Object = hit.collider
		if thing == self or caught.has(thing):
			continue
		caught[thing] = true
		if thing.has_method("blast"):
			thing.blast()
		elif thing.has_method("die"):
			thing.die(GameOver.BLOWN_UP)
		elif thing is Node and thing.is_in_group("enemies"):
			thing.apply_potion(PotionData.DEATH, global_position)


func _burst() -> void:
	var debris := CPUParticles2D.new()
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 40
	debris.lifetime = 0.8
	debris.position = Vector2(0, -6)
	debris.direction = Vector2.UP
	debris.spread = 180.0
	debris.initial_velocity_min = 60.0
	debris.initial_velocity_max = 200.0
	debris.gravity = Vector2(0, 300)
	debris.scale_amount_min = 1.0
	debris.scale_amount_max = 3.0
	debris.color_ramp = Gradient.new()
	debris.color_ramp.set_color(0, Color(1.0, 0.9, 0.5))
	debris.color_ramp.set_color(1, Color(0.4, 0.2, 0.15, 0.0))
	add_child(debris)
	debris.emitting = true


func _shake_camera() -> void:
	var knight := get_tree().get_first_node_in_group("player")
	var camera := knight.get_node_or_null("Camera") as Camera2D if knight else null
	if not camera:
		return
	var shake := camera.create_tween()
	for i in 8:
		shake.tween_property(camera, "offset", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.04)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(blast_area, Color(DANGER, 0.08))
		draw_rect(blast_area, Color(DANGER, 0.5), false)
	if _exploded:
		_draw_blast()
		return
	if is_lit():
		_draw_danger()
	# Three sticks with a band round them.
	for i in 3:
		var stick := Rect2(-6 + i * 4, -12, 4, 12)
		draw_rect(stick, STICK)
		draw_line(stick.position + Vector2(3, 1), stick.position + Vector2(3, 11), STICK_DARK)
	draw_rect(Rect2(-6, -8, 12, 2), BAND)
	draw_rect(Rect2(-6.5, -12.5, 13, 12.5), Color.WHITE, false)
	# The fuse, burning down while lit.
	var left := FUSE_LENGTH
	if is_lit():
		left = FUSE_LENGTH * clampf(_fuse_left / fuse_time, 0.0, 1.0)
	var tip := Vector2(1.0, -12.0 - left)
	draw_line(Vector2(0, -12), tip, FUSE, 1.0)
	if is_lit():
		var spark := 1.5 + sin(_clock * 40.0)
		draw_circle(tip, spark + 1.0, Color(1.0, 0.6, 0.2, 0.8))
		draw_circle(tip, spark * 0.5, Color(1.0, 1.0, 0.7))


## The room it'll take with it, and the seconds left.
func _draw_danger() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * (8.0 if _fuse_left > 1.0 else 18.0))
	draw_rect(blast_area, Color(DANGER, 0.05 + 0.07 * pulse))
	draw_rect(blast_area, Color(DANGER, 0.5 + 0.4 * pulse), false)
	var count := str(ceili(_fuse_left))
	var at := Vector2(-20, -24)
	draw_string_outline(FONT, at, count, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, 3, Color(0.05, 0.05, 0.08))
	draw_string(FONT, at, count, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, DANGER.lerp(Color.WHITE, pulse * 0.5))


func _draw_blast() -> void:
	if _flash <= 0.0:
		return
	draw_rect(blast_area, Color(FLASH, 0.6 * _flash))
	var reach := maxf(blast_area.size.x, blast_area.size.y) * (1.0 - _flash * 0.6)
	draw_circle(Vector2(0, -8), reach * 0.35, Color(1.0, 0.55, 0.2, 0.7 * _flash))
	draw_circle(Vector2(0, -8), reach * 0.2, Color(1.0, 0.95, 0.7, _flash))
