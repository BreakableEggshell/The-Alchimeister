class_name Pickup
extends Area2D
## A floating ingredient. Touching it adds it to the inventory.

var kind: StringName = PotionData.EMBER

var _clock := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = PotionData.LAYER_PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, roundf(sin(_clock * 4.0) * 1.5))
	draw_circle(bob, 6.0, Color(PotionData.INGREDIENT_COLORS[kind], 0.15))
	PotionData.draw_ingredient(self, kind, bob)


func _on_body_entered(body: Node) -> void:
	var inventory := get_tree().get_first_node_in_group("inventory") as Inventory
	if inventory and body.has_method("die"):
		inventory.add_ingredient(kind)
		queue_free()
