class_name Pickup
extends Area2D
## A floating ingredient. Touching it adds it to the inventory. With `falls`
## (dropped by something in the air) it first falls until it lands on a floor.

const FALL_GRAVITY := 600.0
const MAX_FALL_SPEED := 300.0
## How high above the floor it comes to rest.
const REST_HEIGHT := 8.0

var kind: StringName = PotionData.EMBER
var falls := false

var _clock := 0.0
var _fall_speed := 0.0


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not falls:
		return
	_fall_speed = minf(_fall_speed + FALL_GRAVITY * delta, MAX_FALL_SPEED)
	var step := _fall_speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, step + REST_HEIGHT), PotionData.LAYER_WORLD | PotionData.LAYER_PROPS)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		global_position.y = hit.position.y - REST_HEIGHT
		falls = false
	else:
		global_position.y += step


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, roundf(sin(_clock * 4.0) * 1.5))
	draw_circle(bob, 6.0, Color(PotionData.INGREDIENT_COLORS[kind], 0.15))
	draw_arc(bob, 6.5, 0.0, TAU, 20, Color.WHITE)
	PotionData.draw_ingredient(self, kind, bob)


func _on_body_entered(body: Node) -> void:
	var inventory := get_tree().get_first_node_in_group("inventory") as Inventory
	if inventory and body.has_method("die"):
		inventory.add_ingredient(kind)
		queue_free()
