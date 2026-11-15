@tool
class_name Tnt
extends Area2D
## A crate of TNT at the end of a long fuse. Fire lights the fuse wherever it
## touches it: a fire splash, anything burning that touches it, or another
## blast reaching part of it. A spark comes up there and, every `step_time`
## seconds, hops one big step towards the crate, landing on the fuse's knots
## (one every `step_length` pixels, counted from the crate). So lighting it
## nearer the crate gives less time. When the spark reaches the crate it
## blows up, and everything in `blast_area` is caught: the knight is BLOWN UP
## (unless hurts_knight is off), monsters die, cracked walls crumble
## (CrackedWall), wooden planks splinter (WoodenPlatform), ropes burn (Rope),
## dynamite and other TNT go off, and a fuse only partly in the blast is lit.
## A freeze splash on a burning fuse puts the spark out where it is; fire
## lights it again. Fuse that has burnt is ash, and doesn't carry fire.
## Origin is the floor under the crate's middle. `fuse` lists the fuse's
## points relative to it, from where it leaves the crate to its far end.
## In the editor, the blast area is outlined.

@export var fuse := PackedVector2Array([Vector2(-12, -3), Vector2(-108, -3)]):
	set(value):
		fuse = value
		queue_redraw()
@export var step_length := 16.0:
	set(value):
		step_length = maxf(value, 1.0)
		queue_redraw()
@export var step_time := 0.5
@export var blast_area := Rect2(-48, -64, 96, 64):
	set(value):
		blast_area = value
		queue_redraw()
## The blast kills the knight. Off for TNT that's only there to break things.
@export var hurts_knight := true

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const CRATE := Rect2(-12, -16, 24, 16)
const RED := Color(0.61, 0.2, 0.24)
const RED_DARK := Color(0.42, 0.12, 0.16)
const LETTERS := Color(1.0, 0.88, 0.72)
const FUSE_COLOR := Color(0.55, 0.31, 0.25)
const KNOT := Color(0.36, 0.2, 0.16)
const ASH := Color(0.25, 0.23, 0.24, 0.8)
const SPARK := Color(0.94, 0.76, 0.27)
const DANGER := Color(1.0, 0.3, 0.25)
const FLASH := Color(1.0, 0.85, 0.5)
## Seconds the flash takes to fade.
const BLAST_TIME := 0.6
## Seconds before TNT caught in a blast goes off too.
const CHAIN_DELAY := 0.15
## How thick the fuse is for potions and burning things to touch.
const FUSE_REACH := 6.0
## What a blast catches.
const BLAST_MASK := PotionData.LAYER_WORLD | PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES | PotionData.LAYER_PROPS

## Where the spark is, as a distance along the fuse from the crate; below 0
## while unlit.
var _spark := -1.0
## The spark is hopping (not put out).
var _burning := false
var _step_left := 0.0
## Fuse from the crate out to here still carries fire; past it, up to
## _ash_to, has burnt.
var _intact_to := 0.0
var _ash_to := 0.0
var _exploded := false
## Lit by a blast: goes off after CHAIN_DELAY.
var _chain_left := -1.0
## 1 at the blast, fading to 0.
var _flash := 0.0
var _clock := 0.0
## 1 just after a hop, fading: the spark flares as it lands.
var _hop_flare := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("tnt")
	_intact_to = fuse_length()
	# A prop (so potions hit and splash it), but nothing stands on it.
	collision_layer = PotionData.LAYER_PROPS
	collision_mask = PotionData.LAYER_PLAYER | PotionData.LAYER_ENEMIES
	var crate := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = CRATE.size
	crate.shape = box
	crate.position = CRATE.get_center()
	add_child(crate)
	# The fuse, a thin strip per stretch.
	for i in fuse.size() - 1:
		var from := fuse[i]
		var to := fuse[i + 1]
		var strip := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(from.distance_to(to) + FUSE_REACH, FUSE_REACH)
		strip.shape = rect
		strip.position = (from + to) / 2.0
		strip.rotation = (to - from).angle()
		add_child(strip)


## Fire lights the fuse at the point nearest the splash; ice puts it out.
func apply_potion(kind: StringName, origin: Vector2, _power := 1.0) -> void:
	if kind == PotionData.FIRE:
		light_at(origin)
	elif kind == PotionData.FREEZE:
		snuff()


## Lights the fuse at the point on it nearest `where` (global). Nothing
## happens if that's burnt already, or nearer the crate than the spark.
func light_at(where: Vector2) -> void:
	if _exploded:
		return
	var at := distance_along(to_local(where))
	if at > _intact_to + 0.5:
		return
	# Onto the nearest knot, so every hop is a whole step.
	at = minf(roundf(at / step_length) * step_length, _intact_to)
	if _burning and at >= _spark:
		return
	_spark = at
	_intact_to = _spark
	_ash_to = maxf(_ash_to, at)
	if not _burning:
		_burning = true
		_step_left = step_time
		add_to_group("lit_fuses")
	_hop_flare = 1.0
	queue_redraw()
	if _spark <= 0.0:
		_explode()


## A freeze splash: the spark goes out where it is.
func snuff() -> void:
	if not _burning or _exploded:
		return
	_burning = false
	remove_from_group("lit_fuses")
	_puff(_point_at(_spark), Color(0.75, 0.9, 1.0))
	queue_redraw()


func is_lit() -> bool:
	return _burning and not _exploded


func is_exploded() -> bool:
	return _exploded


## Caught in another blast covering `area` (global): with the crate in it,
## goes off almost at once; else the fuse lights where the blast reaches it.
func catch_blast(area: Rect2) -> void:
	if _exploded:
		return
	if area.intersects(Rect2(global_position + CRATE.position, CRATE.size)):
		if _chain_left < 0.0:
			_chain_left = CHAIN_DELAY
			add_to_group("lit_fuses")
		return
	# The point of the fuse nearest the crate that the blast reaches.
	var best := INF
	var length := 0.0
	for i in fuse.size() - 1:
		var from := global_position + fuse[i]
		var to := global_position + fuse[i + 1]
		for j in 9:
			var point := from.lerp(to, j / 8.0)
			if area.has_point(point):
				best = minf(best, length + from.distance_to(point))
		length += from.distance_to(to)
	if best < INF:
		light_at(global_position + _point_at(best))


## Something else's blast (dynamite): as if caught by TNT.
func blast() -> void:
	catch_blast(Rect2(global_position + CRATE.position, CRATE.size))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _exploded:
		return
	_clock += delta
	_hop_flare = maxf(_hop_flare - delta * 4.0, 0.0)
	if _chain_left >= 0.0:
		_chain_left -= delta
		if _chain_left <= 0.0:
			_explode()
			return
	# Anything burning that touches the fuse (or the crate) lights it.
	for body in get_overlapping_bodies():
		if body.has_method("is_burning") and body.is_burning():
			light_at(body.global_position + Vector2(0, -4))
			if _exploded:
				return
	if _burning:
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left += step_time
			_hop()
	queue_redraw()


## One big step towards the crate, onto the next knot.
func _hop() -> void:
	_spark = (ceilf(_spark / step_length - 0.001) - 1.0) * step_length
	_intact_to = maxf(_spark, 0.0)
	_hop_flare = 1.0
	if _spark <= 0.0:
		_explode()


func fuse_length() -> float:
	var length := 0.0
	for i in fuse.size() - 1:
		length += fuse[i].distance_to(fuse[i + 1])
	return length


## How far along the fuse (from the crate) its point nearest `local` is.
func distance_along(local: Vector2) -> float:
	var best := INF
	var best_at := 0.0
	var length := 0.0
	for i in fuse.size() - 1:
		var nearest := Geometry2D.get_closest_point_to_segment(local, fuse[i], fuse[i + 1])
		var off := nearest.distance_to(local)
		if off < best:
			best = off
			best_at = length + fuse[i].distance_to(nearest)
		length += fuse[i].distance_to(fuse[i + 1])
	return best_at


## The point `at` pixels along the fuse from the crate.
func _point_at(at: float) -> Vector2:
	if fuse.is_empty():
		return Vector2.ZERO
	var left := maxf(at, 0.0)
	for i in fuse.size() - 1:
		var piece := fuse[i].distance_to(fuse[i + 1])
		if left <= piece:
			return fuse[i].lerp(fuse[i + 1], left / piece if piece > 0.0 else 0.0)
		left -= piece
	return fuse[fuse.size() - 1]


## The stretch of fuse between two distances along it, as points.
func _stretch(from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array([_point_at(from)])
	var length := 0.0
	for i in range(1, fuse.size()):
		length += fuse[i - 1].distance_to(fuse[i])
		if length > from and length < to:
			points.append(fuse[i])
	points.append(_point_at(to))
	return points


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_burning = false
	_spark = -1.0
	remove_from_group("lit_fuses")
	remove_from_group("tnt")
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
	var area := Rect2(global_position + blast_area.position, blast_area.size)
	var shape := RectangleShape2D.new()
	shape.size = blast_area.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, area.get_center())
	query.collision_mask = BLAST_MASK
	query.collide_with_areas = true
	var caught := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var thing: Object = hit.collider
		if thing == self or caught.has(thing):
			continue
		caught[thing] = true
		if thing.has_method("catch_blast"):
			thing.catch_blast(area)
		elif thing.has_method("blast"):
			thing.blast()
		elif thing.has_method("die"):
			if hurts_knight:
				thing.die(GameOver.BLOWN_UP)
		elif thing is Node and thing.is_in_group("enemies"):
			thing.apply_potion(PotionData.DEATH, global_position)
	# Planks are one-way, which shape queries don't see.
	for plank in get_tree().get_nodes_in_group("planks"):
		if not caught.has(plank) and area.intersects(plank.global_bounds()):
			plank.blast()


func _burst() -> void:
	var debris := CPUParticles2D.new()
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 48
	debris.lifetime = 0.8
	debris.position = CRATE.get_center()
	debris.direction = Vector2.UP
	debris.spread = 180.0
	debris.initial_velocity_min = 60.0
	debris.initial_velocity_max = 220.0
	debris.gravity = Vector2(0, 300)
	debris.scale_amount_min = 1.0
	debris.scale_amount_max = 3.0
	debris.color_ramp = Gradient.new()
	debris.color_ramp.set_color(0, Color(1.0, 0.9, 0.5))
	debris.color_ramp.set_color(1, Color(0.4, 0.2, 0.15, 0.0))
	add_child(debris)
	debris.emitting = true


## A little cloud where the spark went out.
func _puff(at: Vector2, color: Color) -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 0.8
	puff.amount = 8
	puff.lifetime = 0.5
	puff.position = at
	puff.direction = Vector2.UP
	puff.spread = 60.0
	puff.initial_velocity_min = 10.0
	puff.initial_velocity_max = 30.0
	puff.gravity = Vector2.ZERO
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color = color
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(puff.lifetime + 0.1).timeout.connect(puff.queue_free)


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
		_draw_fuse(fuse_length(), fuse_length())
		_draw_crate()
		return
	if _exploded:
		_draw_blast()
		return
	if is_lit():
		var pulse := 0.5 + 0.5 * sin(_clock * 10.0)
		draw_rect(blast_area, Color(DANGER, 0.05 + 0.07 * pulse))
		draw_rect(blast_area, Color(DANGER, 0.5 + 0.4 * pulse), false)
	_draw_fuse(_intact_to, _ash_to)
	_draw_crate()
	if _spark >= 0.0:
		_draw_spark(_point_at(_spark))


## Fuse up to `intact`, ash from there to `ash`, and any fuse past that
## (cut off from the crate) as it was. Knots mark each step.
func _draw_fuse(intact: float, ash: float) -> void:
	var length := fuse_length()
	if fuse.size() < 2:
		return
	if intact > 0.0:
		draw_polyline(_stretch(0.0, intact), FUSE_COLOR, 2.0)
	if ash > intact:
		var burnt := _stretch(intact, ash)
		for i in burnt.size() - 1:
			draw_dashed_line(burnt[i], burnt[i + 1], ASH, 1.0, 2.0)
	var beyond := maxf(ash, intact)
	if length > beyond + 0.5:
		draw_polyline(_stretch(beyond, length), FUSE_COLOR, 2.0)
	var knot := step_length
	while knot < intact - 0.5:
		draw_rect(Rect2((_point_at(knot) - Vector2(1, 1)).round(), Vector2(2, 2)), KNOT)
		knot += step_length


func _draw_crate() -> void:
	draw_rect(CRATE.grow(0.5), Color.WHITE, false)
	draw_rect(CRATE, RED)
	draw_rect(Rect2(CRATE.position.x, CRATE.end.y - 3, CRATE.size.x, 3), RED_DARK)
	draw_rect(Rect2(CRATE.position.x, CRATE.position.y, CRATE.size.x, 2), RED.lightened(0.15))
	draw_string(FONT, Vector2(CRATE.position.x, CRATE.position.y + 11), "TNT", HORIZONTAL_ALIGNMENT_CENTER, CRATE.size.x, 8, LETTERS)


## The spark: a bright upright flicker, flaring as it lands from a hop.
func _draw_spark(at: Vector2) -> void:
	var tall := 6.0 + 2.0 * _hop_flare + (1.0 if sin(_clock * 40.0) > 0.0 else 0.0)
	var top := at + Vector2(-1.5, -tall + 2.0)
	if _burning:
		draw_circle(at + Vector2(0, -1), 3.0 + 2.0 * _hop_flare, Color(1.0, 0.55, 0.2, 0.45))
		draw_rect(Rect2(top.round(), Vector2(3, tall)), SPARK)
		draw_rect(Rect2((top + Vector2(1, 1)).round(), Vector2(1, tall - 2.0)), Color(1, 1, 0.85))
	else:
		# Put out: a dark stub where it stopped.
		draw_rect(Rect2((at - Vector2(1, 2)).round(), Vector2(2, 3)), Color(0.15, 0.13, 0.14))


func _draw_blast() -> void:
	if _flash <= 0.0:
		return
	draw_rect(blast_area, Color(FLASH, 0.6 * _flash))
	var reach := maxf(blast_area.size.x, blast_area.size.y) * (1.0 - _flash * 0.6)
	draw_circle(CRATE.get_center(), reach * 0.35, Color(1.0, 0.55, 0.2, 0.7 * _flash))
	draw_circle(CRATE.get_center(), reach * 0.2, Color(1.0, 0.95, 0.7, _flash))
