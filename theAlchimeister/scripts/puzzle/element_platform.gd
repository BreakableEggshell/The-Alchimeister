@tool
class_name ElementPlatform
extends StaticBody2D
## A slab of ice or fire that potions turn into smoke and back.
## Fire melts ice, and a freeze potion puts fire out: either way it turns to
## smoke. Smoke can't be stood on (the knight and slimes go straight through),
## and it drifts slowly up until something stops it: a ceiling, a wall, another
## slab, or the top of the stage. Planks don't stop it. Potions still break on
## smoke: a freeze potion freezes it into ice right where it is, and a fire
## potion lights it into fire.
## Ice is solid. A burning knight that touches it melts it (as with an ice
## pillar), and so does a dynamite blast.
## Fire is solid too, but it sets whatever touches it burning: the knight, a
## slime, a rope, a fuse, or ice next to it.
## Origin is the top-left corner.

enum Form { ICE, FIRE, SMOKE }

@export var form := Form.ICE:
	set(value):
		form = value
		queue_redraw()
@export var size := Vector2(32, 8):
	set(value):
		size = value
		queue_redraw()

## Pixels a second that smoke rises.
const RISE_SPEED := 12.0
## Seconds a change of form takes to show (a puff, a flash).
const CHANGE_TIME := 0.3
## What stops smoke rising.
const BLOCK_MASK := PotionData.LAYER_WORLD | PotionData.LAYER_PROPS
## What fire sets burning by touch.
const BURN_MASK := PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES | PotionData.LAYER_PROPS
const ICE := Color(0.62, 0.88, 1.0, 0.85)
const ICE_SHINE := Color(0.9, 0.98, 1.0, 0.9)
const FIRE_BODY := Color(0.55, 0.12, 0.06)
const FIRE_GLOW := Color(1.0, 0.45, 0.12)
const FIRE_TIP := Color(1.0, 0.85, 0.35)
const SMOKE := Color(0.82, 0.84, 0.9, 0.55)
const SMOKE_DARK := Color(0.55, 0.55, 0.6, 0.45)

var _shape: CollisionShape2D
var _clock := 0.0
## 1 just after a change of form, fading to 0 (a flash in the new form).
var _change := 0.0
## What fire has set burning and is still touching (instance id -> true), so
## each is lit once per touch, not every frame.
var _lit := {}
var _wisps: CPUParticles2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("element_platforms")
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)
	_wisps = CPUParticles2D.new()
	_wisps.amount = maxi(4, int(size.x / 4.0))
	_wisps.lifetime = 0.8
	_wisps.position = Vector2(size.x / 2.0, 0)
	_wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wisps.emission_rect_extents = Vector2(size.x / 2.0, 1.0)
	_wisps.direction = Vector2.UP
	_wisps.spread = 20.0
	_wisps.gravity = Vector2.ZERO
	_wisps.initial_velocity_min = 6.0
	_wisps.initial_velocity_max = 16.0
	_wisps.scale_amount_min = 1.0
	_wisps.scale_amount_max = 2.0
	add_child(_wisps)
	_apply_form()


func apply_potion(kind: StringName, _origin: Vector2, _power := 1.0) -> void:
	match kind:
		PotionData.FIRE:
			if form == Form.ICE:
				_become(Form.SMOKE)
			elif form == Form.SMOKE:
				_become(Form.FIRE)
		PotionData.FREEZE:
			if form == Form.FIRE:
				_become(Form.SMOKE)
			elif form == Form.SMOKE:
				_become(Form.ICE)


## Touched by something burning (the knight) or by fire: ice melts.
func melt() -> void:
	if form == Form.ICE:
		_become(Form.SMOKE)


## Caught in a dynamite blast: ice melts.
func blast() -> void:
	melt()


func is_smoke() -> bool:
	return form == Form.SMOKE


## Its rectangle in the world.
func global_bounds() -> Rect2:
	return Rect2(global_position, size)


func _become(new_form: Form) -> void:
	form = new_form
	_change = 1.0
	_apply_form()
	_puff()


## Solid (on the props layer, so potions splash it) as ice or fire; as smoke,
## only a target for potions, which nothing collides with.
func _apply_form() -> void:
	collision_layer = PotionData.LAYER_POTION_TARGETS if form == Form.SMOKE else PotionData.LAYER_PROPS
	_lit.clear()
	if form != Form.SMOKE:
		_lift_knight_out()
	_wisps.emitting = form != Form.ICE
	_wisps.color = FIRE_TIP if form == Form.FIRE else SMOKE
	queue_redraw()


## Frozen or lit around the knight (smoke drifts through him): he ends up
## standing on top, rather than stuck inside.
func _lift_knight_out() -> void:
	var knight := get_tree().get_first_node_in_group("player") as Node2D
	if not knight or not knight.has_method("is_burning"):
		return
	var body := Rect2(knight.global_position + Vector2(-6, -28), Vector2(12, 28))
	if body.intersects(global_bounds()):
		knight.global_position.y = global_position.y
		knight.velocity.y = minf(knight.velocity.y, 0.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	if _change > 0.0:
		_change = maxf(_change - delta / CHANGE_TIME, 0.0)
	match form:
		Form.SMOKE:
			_rise(delta)
		Form.FIRE:
			_burn_touching()
	if form != Form.ICE or _change > 0.0:
		queue_redraw()


func _rise(delta: float) -> void:
	var step := RISE_SPEED * delta
	if not _blocked_above(step):
		position.y -= step


## Whether something solid is in the strip `step` pixels tall just above it
## (a pixel in from each side, so walls it slides past don't count).
func _blocked_above(step: float) -> bool:
	var strip := RectangleShape2D.new()
	strip.size = Vector2(maxf(size.x - 2.0, 1.0), maxf(step, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = strip
	query.transform = Transform2D(0.0, global_position + Vector2(size.x / 2.0, -strip.size.y / 2.0))
	query.collision_mask = BLOCK_MASK
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Fire sets burning whatever touches it, once per touch.
func _burn_touching() -> void:
	var reach := RectangleShape2D.new()
	reach.size = size + Vector2(2, 2)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = reach
	query.transform = Transform2D(0.0, global_position + size / 2.0)
	query.collision_mask = BURN_MASK
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var touching := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var thing: Object = hit.collider
		if not thing or not thing.has_method("apply_potion"):
			continue
		var id := thing.get_instance_id()
		touching[id] = true
		if thing.is_in_group("player"):
			# Lit again whenever he's been put out and touches it again.
			if not thing.is_burning() and not thing._dead:
				thing.apply_potion(PotionData.FIRE, global_position + size / 2.0)
		elif not _lit.has(id):
			thing.apply_potion(PotionData.FIRE, global_position + size / 2.0)
	_lit = touching


## A puff of the new form as it changes.
func _puff() -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = maxi(8, int(size.x / 2.0))
	puff.lifetime = 0.5
	puff.position = size / 2.0
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	puff.emission_rect_extents = size / 2.0
	puff.direction = Vector2.UP
	puff.spread = 60.0
	puff.gravity = Vector2(0, 40) if form == Form.ICE else Vector2(0, -20)
	puff.initial_velocity_min = 8.0
	puff.initial_velocity_max = 24.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	match form:
		Form.ICE:
			puff.color = ICE_SHINE
		Form.FIRE:
			puff.color = FIRE_GLOW
		Form.SMOKE:
			puff.color = SMOKE
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(puff.lifetime + 0.1).timeout.connect(puff.queue_free)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match form:
		Form.ICE:
			_draw_ice(box)
		Form.FIRE:
			_draw_fire(box)
		Form.SMOKE:
			_draw_smoke(box)
	if _change > 0.0:
		draw_rect(box.grow(1.0), Color(1, 1, 1, 0.5 * _change))


func _draw_ice(box: Rect2) -> void:
	draw_rect(box, ICE)
	draw_line(Vector2(2, 2), Vector2(minf(size.x * 0.4, size.x - 2.0), 2), ICE_SHINE, 1.0)
	draw_line(Vector2(size.x * 0.6, size.y - 2.0), Vector2(size.x - 3.0, size.y - 2.0), Color(ICE_SHINE, 0.5), 1.0)
	# White outline: something the player can do something with.
	draw_rect(box.grow(-0.5), Color.WHITE, false)


func _draw_fire(box: Rect2) -> void:
	draw_rect(box, FIRE_BODY)
	draw_rect(Rect2(1, 1, size.x - 2, maxf(size.y - 4, 1)), Color(FIRE_GLOW, 0.6 + 0.2 * sin(_clock * 9.0)))
	# Flames licking up off the top, flickering.
	var count := maxi(2, int(size.x / 6.0))
	for i in count:
		var x := (i + 0.5) * size.x / count
		var tall := 4.0 + 3.0 * absf(sin(_clock * 7.0 + i * 1.9))
		var half := size.x / count * 0.45
		draw_colored_polygon(PackedVector2Array([Vector2(x - half, 0), Vector2(x, -tall), Vector2(x + half, 0)]), FIRE_GLOW)
		draw_colored_polygon(PackedVector2Array([Vector2(x - half * 0.5, 0), Vector2(x, -tall * 0.6), Vector2(x + half * 0.5, 0)]), FIRE_TIP)
	draw_rect(box.grow(-0.5), Color.WHITE, false)


func _draw_smoke(box: Rect2) -> void:
	# Soft puffs that roll, over a faint body; no outline, nothing to stand on.
	draw_rect(box, Color(SMOKE, 0.2))
	var count := maxi(3, int(size.x / 7.0))
	for i in count:
		var x := (i + 0.5) * size.x / count + sin(_clock * 2.0 + i) * 1.5
		var y := size.y / 2.0 + cos(_clock * 2.6 + i * 1.3) * 1.5
		var r := size.y * 0.55 + 1.5 * sin(_clock * 3.0 + i * 2.1)
		draw_circle(Vector2(x, y + 1.0), r, SMOKE_DARK)
		draw_circle(Vector2(x, y), r, SMOKE)
	# Dashed edge so it reads as something you can still throw at.
	var dash := 3.0
	var x0 := 0.0
	while x0 < size.x:
		draw_line(Vector2(x0, -0.5), Vector2(minf(x0 + dash, size.x), -0.5), Color(1, 1, 1, 0.5), 1.0)
		draw_line(Vector2(x0, size.y + 0.5), Vector2(minf(x0 + dash, size.x), size.y + 0.5), Color(1, 1, 1, 0.5), 1.0)
		x0 += dash * 2.0
