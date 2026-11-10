class_name Potion
extends Node2D
## A thrown potion: flies on a ballistic arc, spinning, through planks, and shatters on the
## first solid it hits; off jelly (Jelly) it bounces instead. A potion with a kind applies its effect to every body
## within PotionData.SPLASH_RADIUS that has an apply_potion(kind, origin) method.

const GLASS_COLOR := Color(0.85, 0.9, 1.0)
## Safety net: free the potion if it somehow never hits anything.
const MAX_LIFETIME := 5.0

## One of PotionData.KINDS, or empty for a plain potion with no effect.
var kind: StringName = &""
var velocity := Vector2.ZERO
var gravity := 400.0
var hit_mask := PotionData.POTION_HIT_MASK
## Physics bodies the potion flies through (the thrower).
var exclude: Array[RID] = []
var spin_speed := 12.0
## How hard the splash hits (PotionData.splash_power); a harder throw
## knocks things further.
var power := 1.0

var _age := 0.0
var _shattered := false
var _ring := 0.0


## Advances a potion one physics tick. Shared by real potions and the aim
## preview so the preview always matches the real flight.
## Returns {position, velocity, hit (bool), normal}, plus "collider" (what it
## hit) on a hit, or "bounced" (the Jelly) when it bounced this tick.
static func step(space: PhysicsDirectSpaceState2D, from: Vector2, vel: Vector2, grav: float, delta: float, excluded: Array[RID], mask: int) -> Dictionary:
	vel.y += grav * delta
	var to := from + vel * delta
	var skip := excluded.duplicate()
	# A few tries: each plank in the way is skipped and the ray cast again.
	for i in 4:
		var query := PhysicsRayQueryParameters2D.create(from, to, mask, skip)
		# Enemies' potion hitboxes are areas.
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if not hit:
			break
		if _flies_through(hit.collider):
			skip.append(hit.rid)
			continue
		if hit.collider is Jelly:
			# Mirrored off the face it hit, faster off springy jelly.
			var bounced: Vector2 = vel.bounce(hit.normal) * hit.collider.strength
			return {"position": hit.position + hit.normal * 0.5, "velocity": bounced, "hit": false, "normal": hit.normal, "bounced": hit.collider}
		return {"position": hit.position, "velocity": vel, "hit": true, "normal": hit.normal, "collider": hit.collider}
	return {"position": to, "velocity": vel, "hit": false, "normal": Vector2.ZERO}


## Planks (one-way platforms) don't stop potions, from above or below. A
## wooden platform that potions can fade (WoodenPlatform) still catches them.
static func _flies_through(collider: Object) -> bool:
	return collider is Solid and collider.one_way and not collider is WoodenPlatform


func _enter_tree() -> void:
	add_to_group("potions")


func _physics_process(delta: float) -> void:
	if _shattered:
		return
	_age += delta
	if _age > MAX_LIFETIME:
		queue_free()
		return
	var result := Potion.step(get_world_2d().direct_space_state, global_position, velocity, gravity, delta, exclude, hit_mask)
	global_position = result.position
	velocity = result.velocity
	if result.has("bounced"):
		result.bounced.wobble()
	rotation += spin_speed * delta * signf(velocity.x)
	if result.hit:
		_shatter(result.normal)


func _draw() -> void:
	if not _shattered:
		PotionData.draw_potion(self, kind, Vector2.ZERO)
	elif kind != &"" and _ring < 1.0:
		var color := PotionData.color_of(kind)
		draw_arc(Vector2.ZERO, PotionData.SPLASH_RADIUS * _ring, 0.0, TAU, 24, Color(color, 1.0 - _ring))


func _shatter(normal: Vector2) -> void:
	_shattered = true
	rotation = 0.0
	queue_redraw()
	_apply_splash()
	var splash := CPUParticles2D.new()
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 16
	splash.lifetime = 0.5
	splash.direction = normal
	splash.spread = 70.0
	splash.initial_velocity_min = 40.0
	splash.initial_velocity_max = 100.0
	splash.gravity = Vector2(0, 400)
	splash.scale_amount_min = 1.0
	splash.scale_amount_max = 2.0
	splash.color = PotionData.color_of(kind)
	add_child(splash)
	splash.emitting = true
	var ring := create_tween()
	ring.tween_method(func(t: float) -> void:
		_ring = t
		queue_redraw(), 0.0, 1.0, 0.35)
	await get_tree().create_timer(splash.lifetime + 0.2).timeout
	queue_free()


func _apply_splash() -> void:
	if kind == &"":
		return
	if kind == PotionData.KNOCKBACK:
		Sfx.play(Sfx.KNOCKBACK, self, global_position)
	var circle := CircleShape2D.new()
	circle.radius = PotionData.SPLASH_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = PotionData.SPLASH_MASK
	# Some props are areas (dynamite).
	query.collide_with_areas = true
	var touched := {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: Object = hit.collider
		if body and not touched.has(body) and body.has_method("apply_potion"):
			touched[body] = true
			body.apply_potion(kind, global_position, power)
